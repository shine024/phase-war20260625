# -*- coding: utf-8 -*-
"""一次性视觉审计探针（v6.14 排障用，可删）：
① assets/effects/unit_anims/*/ 160 套动画逐帧体检
② assets/card_icons/{enemy,player}/ 360 张卡图体检
检出：空帧/缺帧、帧数对账（sheet 宽 vs anim.json counts）、双主体（连通行+中缝分割）、
占比/宽高比离群。输出 .godot/visual_audit_report.json + 拼图到 .godot/audit_sheets/。
"""
import json, os, sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
ICONS = os.path.join(ROOT, "assets", "card_icons")
OUT_JSON = os.path.join(ROOT, ".godot", "visual_audit_report.json")
SHEETS = os.path.join(ROOT, ".godot", "audit_sheets")
os.makedirs(SHEETS, exist_ok=True)

CELL = 200          # 拼图单元像素
GRID = (6, 5)       # 6 列 × 5 行 = 30/张

def load_rgba(path):
    im = Image.open(path).convert("RGBA")
    return im

def alpha_mask_small(im, size=128):
    """降采样 + alpha 二值化 + 3px 膨胀（桥小缝）"""
    a = im.getchannel("A").resize((size, size), Image.BILINEAR)
    m = np.asarray(a) > 40
    if not m.any():
        return m, m
    # 简易膨胀 3px
    md = m.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            md |= np.roll(np.roll(m, dy, 0), dx, 1)
    return m, md

def components(mask):
    """4 邻接连通域标记（BFS，128×128 足够快），返回 [(area, bbox)] 列表"""
    h, w = mask.shape
    lab = np.zeros((h, w), dtype=np.int32)
    cur = 0
    comps = []
    for y in range(h):
        xs = np.nonzero(mask[y] & (lab[y] == 0))[0]
        for x in xs:
            if lab[y, x]:
                continue
            cur += 1
            stack = [(y, x)]
            lab[y, x] = cur
            area = 0
            y0, y1, x0, x1 = y, y, x, x
            while stack:
                cy, cx = stack.pop()
                area += 1
                if cy < y0: y0 = cy
                if cy > y1: y1 = cy
                if cx < x0: x0 = cx
                if cx > x1: x1 = cx
                for ny, nx in ((cy-1,cx),(cy+1,cx),(cy,cx-1),(cy,cx+1)):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and lab[ny, nx] == 0:
                        lab[ny, nx] = cur
                        stack.append((ny, nx))
            comps.append((area, (x0, y0, x1, y1)))
    return comps

def white_metrics(im):
    """白底残留三指标（2026-09-19 用户复查项：白底/白边未抠完）：
    corner_white  四角 12×12 块内 近白不透明占比（≥0.5 判白底块）
    border_white  边框 3px 环 近白不透明占比（≥0.35 判白底环）
    fringe_white  轮廓带（不透明且 4 邻有透明的像素）近白占比（≥0.45 判白边）
    近白 = min(r,g,b)≥210 且 alpha≥140（角点用 ≥235/≥200 严格档）。
    全部在原分辨率算（降采样会糊掉 1-2px 白边）。"""
    W, H = im.size
    arr = np.asarray(im).astype(np.int16)
    rgb = arr[..., :3]
    a = arr[..., 3]
    mn = rgb.min(axis=2)
    res = {"corner_white": 0.0, "border_white": 0.0, "fringe_white": 0.0}
    if W < 24 or H < 24:
        return res
    # 角点 12×12（两档：≥235/alpha≥200 白底块；≥210/alpha>0 含半透明白雾）
    cmax = 0.0
    hmax = 0.0
    for cy in (0, H - 12):
        for cx in (0, W - 12):
            blk_mn = mn[cy:cy+12, cx:cx+12]
            blk_a = a[cy:cy+12, cx:cx+12]
            cmax = max(cmax, float(((blk_mn >= 235) & (blk_a >= 200)).mean()))
            hmax = max(hmax, float(((blk_mn >= 210) & (blk_a > 0)).mean()))
    res["corner_white"] = round(cmax, 3)
    res["corner_haze"] = round(hmax, 3)
    # 边框 3px 环
    ring = np.ones((H, W), dtype=bool)
    ring[3:-3, 3:-3] = False
    res["border_white"] = round(float(((mn >= 225) & (a >= 140) & ring).mean()), 3)
    # 轮廓带：不透明像素且 4 邻至少一个透明
    op = a >= 140
    tr = a < 60
    nb_tr = np.zeros_like(op)
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        shifted = np.zeros_like(tr)
        if dy == -1: shifted[:-1, :] = tr[1:, :]
        elif dy == 1: shifted[1:, :] = tr[:-1, :]
        elif dx == -1: shifted[:, :-1] = tr[:, 1:]
        else: shifted[:, 1:] = tr[:, :-1]
        nb_tr |= shifted
    band = op & nb_tr
    n = int(band.sum())
    if n >= 30:
        res["fringe_white"] = round(float(((mn >= 210) & band).sum()) / n, 3)
    return res


def analyze(im):
    """返回 dict: content_frac, bbox(x0,y0,x1,y1) 归一化, aspect, split_gap, multi_subject,
    corner_white/border_white/fringe_white（v6.17 白底三指标）"""
    m, md = alpha_mask_small(im)
    res = {"content_frac": 0.0, "bbox": None, "aspect": 0.0,
           "split_gap": 0.0, "multi_subject": 0, "empty": True}
    wm = white_metrics(im)
    res.update(wm)
    res["white_flag"] = (wm["corner_white"] >= 0.5 or wm["border_white"] >= 0.30
                         or wm["fringe_white"] >= 0.35
                         or res.get("corner_haze", 0.0) >= 0.40)
    if not m.any():
        return res
    res["empty"] = False
    res["content_frac"] = float(m.mean())
    ys, xs = np.nonzero(m)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    res["bbox"] = [float(v)/128 for v in (x0, y0, x1, y1)]
    bw, bh = max(1, x1-x0+1), max(1, y1-y0+1)
    res["aspect"] = round(bw / bh, 2)
    # 中缝分割：bbox 内部最长的全空竖缝
    colocc = m[y0:y1+1, x0:x1+1].any(axis=0)
    gap = best = 0
    for v in colocc:
        gap = 0 if v else gap + 1
        best = max(best, gap)
    res["split_gap"] = round(best / bw, 3)
    # 连通行：≥10% 面积的连通域个数
    big = [c for c in components(md) if c[0] >= 0.10 * 128 * 128]
    res["multi_subject"] = len(big)
    return res

def audit_anims():
    report = {}
    for d in sorted(os.listdir(ANIM)):
        p = os.path.join(ANIM, d)
        if not os.path.isdir(p):
            continue
        jp = os.path.join(p, "anim.json")
        if not os.path.isfile(jp):
            # v6.17 补盲区：AttackPoseAnim 姿态目录（attack_f0.png，无 anim.json）——
            # 2026-09-19 体检发现此类从未进过审计（多人/白底双漏）
            ap = os.path.join(p, "attack_f0.png")
            if os.path.isfile(ap):
                a = analyze(load_rgba(ap))
                report[d] = {"mode": "pose", "anims": {"attack_f0": {
                    "white_flag": a.get("white_flag", False),
                    "corner": a["corner_white"], "border": a["border_white"],
                    "fringe": a["fringe_white"],
                    "multi_subject": a["multi_subject"]}}}
            else:
                report[d] = {"error": "no anim.json"}
            continue
        meta = json.load(open(jp, encoding="utf-8"))
        fs = int(meta.get("frame_size", 256))
        counts = meta.get("counts", {})
        entry = {"fps": meta.get("fps"), "frame_size": fs, "counts": counts, "anims": {}}
        # v6.17: boss 散帧模式（idle_f0..N.png，BossIdleAnim 加载链）——同指标逐帧审
        loose = sorted(f for f in os.listdir(p)
                       if f.startswith("idle_f") and f.endswith(".png"))
        if loose and not os.path.isfile(os.path.join(p, "sheet_idle.png")):
            le = {"mode": "loose", "frames": [], "white_frames": [], "empty_frames": [],
                  "multi_frames": []}
            for i, fn in enumerate(loose):
                a = analyze(load_rgba(os.path.join(p, fn)))
                a["idx"] = i
                le["frames"].append(a)
                if a["empty"]:
                    le["empty_frames"].append(i)
                if a["multi_subject"] >= 2:
                    le["multi_frames"].append(i)
                if a.get("white_flag"):
                    le["white_frames"].append(
                        {"idx": i, "corner": a["corner_white"],
                         "border": a["border_white"], "fringe": a["fringe_white"]})
            entry["anims"]["loose_idle"] = le
            report[d] = entry
            continue
        for anim_name in ("idle", "attack"):
            sp = os.path.join(p, f"sheet_{anim_name}.png")
            if not os.path.isfile(sp):
                entry["anims"][anim_name] = {"error": "missing sheet"}
                continue
            im = load_rgba(sp)
            W, H = im.size
            n = int(counts.get(anim_name, 0))
            ae = {"sheet": [W, H], "declared": n,
                  "width_ok": (H == fs and W == fs * n)}
            frames = []
            if H == fs and n > 0 and W >= fs * n:
                for i in range(n):
                    fr = im.crop((i * fs, 0, (i + 1) * fs, fs))
                    a = analyze(fr)
                    a["idx"] = i
                    frames.append(a)
                    if a.get("white_flag"):
                        ae.setdefault("white_frames", []).append(
                            {"idx": i, "corner": a["corner_white"],
                             "border": a["border_white"], "fringe": a["fringe_white"]})
                ae["frames"] = frames
                ae["empty_frames"] = [f["idx"] for f in frames if f["empty"]]
                ae["multi_frames"] = [f["idx"] for f in frames if f["multi_subject"] >= 2]
                ae["split_frames"] = [f["idx"] for f in frames
                                      if f["split_gap"] >= 0.18 and not f["empty"]]
                frs = [f["content_frac"] for f in frames if not f["empty"]]
                ae["frac_range"] = [round(min(frs), 3), round(max(frs), 3)] if frs else None
                ars = [f["aspect"] for f in frames if not f["empty"]]
                ae["aspect_max"] = max(ars) if ars else 0
            entry["anims"][anim_name] = ae
        report[d] = entry
    return report

def audit_icons():
    report = {}
    for side in ("enemy", "player"):
        sd = os.path.join(ICONS, side)
        for fn in sorted(os.listdir(sd)):
            if not fn.endswith(".png"):
                continue
            im = load_rgba(os.path.join(sd, fn))
            a = analyze(im)
            report[f"{side}/{fn[:-4]}"] = a
    return report


def audit_extra():
    """v6.17 追加扫角点白底：mod 图标 / 掉落物（同 analyze 白三指标，全量）"""
    report = {}
    for rel in (os.path.join("assets", "ui", "icons", "mod_icons"),
                os.path.join("assets", "resources", "drops")):
        sd = os.path.join(ROOT, rel)
        if not os.path.isdir(sd):
            continue
        for fn in sorted(os.listdir(sd)):
            if not fn.endswith(".png"):
                continue
            try:
                im = load_rgba(os.path.join(sd, fn))
            except Exception:
                continue
            report[os.path.basename(rel) + "/" + fn[:-4]] = analyze(im)
    return report


def _save_on_gray(im, out, gray=(96, 98, 104)):
    """RGBA 合成到中灰底保存（白底残留在中灰上一眼可见）"""
    bg = Image.new("RGBA", im.size, gray + (255,))
    bg.paste(im, (0, 0), im)
    bg.convert("RGB").save(out)


def gen_white_evidence(rep, cap=72):
    """白标证据裁切：动画帧从 sheet 裁原帧、图标整图，合成中灰底后拼图"""
    ev_dir = os.path.join(SHEETS, "white_ev")
    os.makedirs(ev_dir, exist_ok=True)
    paths, labels, flags = [], [], []
    if "anims" in rep:
        for u, e in rep["anims"].items():
            fs = int(e.get("frame_size", 256))
            for an, ae in e.get("anims", {}).items():
                for wf in ae.get("white_frames", []):
                    if len(paths) >= cap:
                        break
                    i = int(wf["idx"])
                    if an == "loose_idle":  # boss 散帧模式：单文件即帧
                        sp = os.path.join(ANIM, u, f"idle_f{i}.png")
                        if not os.path.isfile(sp):
                            continue
                        fr = load_rgba(sp)
                    else:
                        sp = os.path.join(ANIM, u, f"sheet_{an}.png")
                        if not os.path.isfile(sp):
                            continue
                        im = load_rgba(sp)
                        if im.size[0] < fs * (i + 1) or im.size[1] < fs:
                            continue
                        fr = im.crop((i * fs, 0, (i + 1) * fs, fs))
                    out = os.path.join(ev_dir, f"{u}_{an}_f{i}.png")
                    _save_on_gray(fr, out)
                    paths.append(out)
                    labels.append(f"{u}/{an}#f{i} c{wf['corner']} b{wf['border']} f{wf['fringe']}")
                    flags.append(["◈W"])
    if "icons" in rep:
        for k, a in rep["icons"].items():
            if not a.get("white_flag") or len(paths) >= cap:
                continue
            side, name = k.split("/", 1)
            p = os.path.join(ICONS, side, name + ".png")
            if not os.path.isfile(p):
                continue
            out = os.path.join(ev_dir, "icon_" + k.replace("/", "_") + ".png")
            _save_on_gray(load_rgba(p), out)
            paths.append(out)
            labels.append(f"{k} c{a['corner_white']} b{a['border_white']} f{a['fringe_white']}")
            flags.append(["◈W"])
    if paths:
        sheet_paths(paths, labels, "white_offenders.png", flags)
    return len(paths)

def sheet_paths(paths, labels, out, flags=None):
    """拼图：每格 = 图 fit 到 CELL + 底部标签；flags 提供警示标记"""
    cols, rows = GRID
    per = cols * rows
    os.makedirs(SHEETS, exist_ok=True)
    made = []
    for s in range(0, len(paths), per):
        chunk = paths[s:s+per]
        lab = labels[s:s+per]
        flg = (flags or [""] * len(paths))[s:s+per]
        W, H = cols * CELL, rows * (CELL + 22)
        canvas = Image.new("RGB", (W, H), (24, 26, 30))
        from PIL import ImageDraw
        dr = ImageDraw.Draw(canvas)
        for i, (p, lb) in enumerate(zip(chunk, lab)):
            cx, cy = (i % cols) * CELL, (i // cols) * (CELL + 22)
            try:
                im = Image.open(p).convert("RGBA")
                im.thumbnail((CELL - 4, CELL - 4))
                bg = Image.new("RGBA", (CELL, CELL), (60, 62, 68, 255))
                bg.paste(im, ((CELL - im.width)//2, (CELL - im.height)//2), im)
                canvas.paste(bg.convert("RGB"), (cx, cy))
            except Exception as e:
                dr.text((cx+4, cy+4), f"ERR {e}", fill=(255, 80, 80))
            mark = " ".join(flg[i]) if flg[i] else ""
            dr.text((cx+4, cy+CELL+4), f"{lb} {mark}".strip()[:46],
                    fill=(255, 210, 80) if flg[i] else (200, 200, 200))
        op = os.path.join(SHEETS, out)
        canvas.save(op)
        made.append(op)
        print("sheet:", op)
    return made

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    rep = {}
    if mode in ("all", "anim"):
        print("== 审计动画 ==")
        rep["anims"] = audit_anims()
    if mode in ("all", "icons"):
        print("== 审计卡图 ==")
        rep["icons"] = audit_icons()
    if mode in ("all", "extra"):
        print("== 审计 mod 图标/掉落物 ==")
        rep["extra"] = audit_extra()
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(rep, f, ensure_ascii=False)
    print("report ->", OUT_JSON)
    # 摘要
    if "anims" in rep:
        bad_w, bad_e, bad_m, bad_s = [], [], [], []
        for u, e in rep["anims"].items():
            for an, ae in e.get("anims", {}).items():
                k = f"{u}/{an}"
                if ae.get("error"):
                    bad_w.append((k, ae["error"])); continue
                if not ae.get("width_ok", True):
                    bad_w.append((k, f"sheet={ae['sheet']} declared={ae['declared']}"))
                if ae.get("empty_frames"):
                    bad_e.append((k, ae["empty_frames"]))
                if ae.get("multi_frames"):
                    bad_m.append((k, ae["multi_frames"]))
                if ae.get("split_frames"):
                    bad_s.append((k, ae["split_frames"]))
        print(f"\n[动画] 宽度/声明不符 {len(bad_w)} | 空帧 {len(bad_e)} | 双主体帧 {len(bad_m)} | 中缝分割 {len(bad_s)}")
        for lst, name in ((bad_w, "WIDTH"), (bad_e, "EMPTY"), (bad_m, "MULTI"), (bad_s, "SPLIT")):
            for k, v in lst[:40]:
                print(f"  [{name}] {k}: {v}")
    if "icons" in rep:
        bad_m, bad_e = [], []
        for k, a in rep["icons"].items():
            if a["empty"]:
                bad_e.append(k)
            elif a["multi_subject"] >= 2:
                bad_m.append((k, a["multi_subject"], a["split_gap"]))
        print(f"\n[卡图] 空图 {len(bad_e)} | 双主体 {len(bad_m)}")
        for k in bad_e[:20]:
            print(f"  [EMPTY] {k}")
        for k, n, g in bad_m[:40]:
            print(f"  [MULTI] {k}: comps={n} gap={g}")
    # v6.17 白底残留汇总 + 证据拼图
    for grp, tag in (("anims", "动画"), ("icons", "卡图"), ("extra", "extra")):
        if grp not in rep:
            continue
        hits = []
        for k, v in rep[grp].items():
            if grp == "anims":
                for an, ae in v.get("anims", {}).items():
                    for wf in ae.get("white_frames", []):
                        hits.append(f"{u_name(k, an)}#f{wf['idx']}"
                                    f" c{wf['corner']} b{wf['border']} f{wf['fringe']}")
            else:
                if v.get("white_flag"):
                    hits.append(f"{k} c{v['corner_white']} b{v['border_white']} f{v['fringe_white']}")
        print(f"\n[白底 {tag}] 命中 {len(hits)}")
        for h in hits[:60]:
            print(f"  [WHITE] {h}")
    if mode in ("all", "anim", "icons"):
        n = gen_white_evidence(rep)
        print(f"\n白标证据 -> {os.path.join(SHEETS, 'white_offenders.png')}（{n} 例）")


def u_name(unit, anim):
    return f"{unit}/{anim}"
