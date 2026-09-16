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

def analyze(im):
    """返回 dict: content_frac, bbox(x0,y0,x1,y1) 归一化, aspect, split_gap, multi_subject"""
    m, md = alpha_mask_small(im)
    res = {"content_frac": 0.0, "bbox": None, "aspect": 0.0,
           "split_gap": 0.0, "multi_subject": 0, "empty": True}
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
            report[d] = {"error": "no anim.json"}
            continue
        meta = json.load(open(jp, encoding="utf-8"))
        fs = int(meta.get("frame_size", 256))
        counts = meta.get("counts", {})
        entry = {"fps": meta.get("fps"), "frame_size": fs, "counts": counts, "anims": {}}
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
