# -*- coding: utf-8 -*-
"""2026-10-13 生图资源全面体检 v2（一次性审计脚本，不改任何资产）。

v2 校准（对 v1 误报的修正）：
  - fire 分桶：none/one/multi/pos_right，另加蓝白能量武器焰通道（v6.34 口径）
  - 截断判定改用剔焰烟主体掩码（火光贴帧缘≠主体截断）
  - 品红分两类：半透明渗色(100<α<250，键控残留) vs 实心品红(α≥250，可能主题色→目检)
  - 暂存部署判定：首帧主体 IoU≥0.98（部署链会烘描边，字节比对不可靠）
  - 缩略图新鲜度：内容级比对（源 LANCZOS 缩放 vs 现树图），mtime 仅参考
  - 新增卡图 512 自动项：截断/四角残留/光晕边/离群小连通块/主体占比
输出：.godot/full_audit_20261013.json + 控制台摘要
"""
import io, json, os, sys
from collections import Counter
import numpy as np
from PIL import Image
import cv2

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
HERE = os.path.dirname(os.path.abspath(__file__))
WS = os.path.abspath(os.path.join(HERE, ".."))
ANIM = os.path.join(WS, "assets", "effects", "unit_anims")
CARD = os.path.join(WS, "assets", "card_icons")
RS = os.path.join(WS, ".godot", "unit_review")
F = 256


def load_rgba(path):
    return np.asarray(Image.open(path).convert("RGBA")).astype(int)


def smoke_px(fr):
    r, g, b = fr[:, :, 0], fr[:, :, 1], fr[:, :, 2]
    mx = np.maximum(np.maximum(r, g), b); mn = np.minimum(np.minimum(r, g), b)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    return (np.abs(r - g) < 22) & (np.abs(g - b) < 22) & (mn > 135) & (sat < 0.15)


def mn_px(fr):
    return np.minimum(np.minimum(fr[:, :, 0], fr[:, :, 1]), fr[:, :, 2])


def fire_px(fr):
    r, g, b, al = fr[:, :, 0], fr[:, :, 1], fr[:, :, 2], fr[:, :, 3]
    core = (r > 190) & (g > 120) & (g < 220) & (b < 130) & (al > 100)
    if core.any():
        d = cv2.dilate(core.astype(np.uint8), np.ones((7, 7), np.uint8)) > 0
        white = (mn_px(fr) > 205) & (al > 100) & d
        core = core | white
    # 蓝白能量焰（v6.34 能量武器通道）
    blue = (b > 190) & (r > 120) & (r < 220) & (g < 190) & (al > 100)
    return core | blue


def body_mask(fr):
    a = fr[:, :, 3]
    return (a >= 128) & ~smoke_px(fr) & ~fire_px(fr)


def iou(a, b):
    if not a.any() or not b.any():
        return 0.0
    h = max(a.shape[0], b.shape[0]); w = max(a.shape[1], b.shape[1])
    pa = np.zeros((h, w), bool); pb = np.zeros((h, w), bool)
    pa[:a.shape[0], :a.shape[1]] = a
    pb[:b.shape[0], :b.shape[1]] = b
    return float((pa & pb).sum()) / max(1, (pa | pb).sum())


def frames_of(sheet):
    return [sheet[:, i * F:(i + 1) * F] for i in range(sheet.shape[1] // F)]


def bbox_hw(mask):
    ys, xs = np.where(mask)
    if not len(ys):
        return 0, 0, 0.0, 0.0
    return (int(ys.max() - ys.min() + 1), int(xs.max() - xs.min() + 1),
            float(xs.mean()), float(ys.max()))


def shift_overlap(m_a, m_b):
    if not m_a.any() or not m_b.any():
        return 0.0
    pad = 8
    h, w = m_a.shape
    canvas = np.zeros((h + 2 * pad, w + 2 * pad), np.uint8)
    canvas[pad:pad + h, pad:pad + w] = m_b.astype(np.uint8)
    res = cv2.matchTemplate(canvas, m_a.astype(np.uint8), cv2.TM_CCORR)
    return int(res.max()) / max(1, int(m_a.sum()), int(m_b.sum()))


def edge_touch(mask, m=2):
    band = np.zeros(mask.shape, bool)
    band[:m, :] = band[-m:, :] = True
    band[:, :m] = band[:, -m:] = True
    return int((mask & band).sum())


def faint_edge(fr, m=12):
    a = fr[:, :, 3]
    band = np.zeros(a.shape, bool)
    band[:m, :] = band[-m:, :] = True
    band[:, :m] = band[:, -m:] = True
    return int(((a >= 16) & (a < 128) & band).sum())


def magenta_split(fr):
    r, g, b, al = fr[:, :, 0], fr[:, :, 1], fr[:, :, 2], fr[:, :, 3]
    m = (b > g + 20) & (r > g + 20) & (al > 100)
    soft = int((m & (al < 250)).sum())
    solid = int((m & (al >= 250)).sum())
    return soft, solid


def stray_islands(mask, min_sz=8, max_sz=500):
    """离主体远的小连通块（背景杂物）。主体=最大连通块膨胀 24px。"""
    u8 = mask.astype(np.uint8)
    n, lab = cv2.connectedComponents(u8, connectivity=8)
    if n <= 2:
        return 0
    sizes = [(int((lab == i).sum()), i) for i in range(1, n)]
    sizes.sort(reverse=True)
    main = (lab == sizes[0][1]).astype(np.uint8)
    near = cv2.dilate(main, np.ones((49, 49), np.uint8)) > 0
    cnt = 0
    for sz, i in sizes[1:]:
        if min_sz <= sz <= max_sz and not ((lab == i) & near).any():
            cnt += 1
    return cnt


def qa_attack(fr_list, typ):
    n = len(fr_list)
    bm = [body_mask(fr) for fr in fr_list]
    hs, ws_, cxs, bots = [], [], [], []
    for m in bm:
        h, w, cx, bot = bbox_hw(m)
        hs.append(h); ws_.append(w); cxs.append(cx); bots.append(bot)
    dh = (max(hs) - min(hs)) / max(1, max(hs))
    dw = (max(ws_) - min(ws_)) / max(1, max(ws_))
    dw_thr = 0.30 if typ == "platform" else 0.50
    bookend = abs(cxs[0] - cxs[-1]) if n > 1 else 0.0
    fire_frames = []
    for idx, fr in enumerate(fr_list):
        f = fire_px(fr)
        if f.sum() > 500:
            ys, xs = np.where(f)
            fire_frames.append((idx, round(float(xs.mean()))))
    foot_span = max(bots) - min(bots)
    ious = [iou(bm[i], bm[i + 1]) for i in range(n - 1)] if n > 1 else [1.0]
    liou = iou(bm[0], bm[-1]) if n > 1 else 1.0
    miou_thr = 0.45 if typ == "platform" else 0.35
    dw_thr_s = 0.30 if typ == "platform" else 0.50
    return {
        "frames": n,
        "size": {"dh": round(dh, 3), "dw": round(dw, 3), "h": hs,
                 "pass": bool(dh <= 0.25 and dw <= dw_thr_s)},
        "facing": {"bookend": round(bookend, 1), "drift": round(max(cxs) - min(cxs), 1),
                   "pass": bool(bookend <= 8)},
        "fire": {"frames": fire_frames,
                 "cat": ("none" if not fire_frames else
                         "multi" if len(fire_frames) > 1 else
                         "pos_right" if fire_frames[0][1] >= F * 0.5 else "ok"),
                 "pass": bool(len(fire_frames) == 1 and fire_frames[0][1] < F * 0.5)},
        "foot": {"span": int(foot_span), "pass": bool(foot_span <= 8)},
        "motion": {"min_iou": round(min(ious), 3), "thr": miou_thr,
                   "pass": bool(min(ious) >= miou_thr)},
        "loop": {"iou": round(liou, 3), "pass": bool(liou >= 0.8)},
        "cx": [round(c) for c in cxs],
    }


def check_card_png(path):
    """卡图 512 自动项：截断/四角残留/光晕边/离群杂物/主体占比。"""
    im = Image.open(path)
    fr = np.asarray(im.convert("RGBA")).astype(int)
    a = fr[:, :, 3]
    h, w = a.shape
    solid = a >= 128
    rec = {"size": "%dx%d" % (w, h)}
    if not solid.any():
        rec["empty"] = True
        return rec
    rec["edge_solid"] = edge_touch(solid, 2)
    corners = [a[:24, :24].max(), a[:24, -24:].max(), a[-24:, :24].max(), a[-24:, -24:].max()]
    rec["corner_alpha_max"] = int(max(corners))
    # 光晕边：近透明(16≤α<128)像素占比
    rec["halo_frac"] = round(float(((a >= 16) & (a < 128)).sum()) / (w * h), 4)
    # 白底残留：近白且不透明、且在外围（距主体 bbox 外）
    ys, xs = np.where(solid)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    rec["content_frac"] = round(float((y1 - y0 + 1) * (x1 - x0 + 1)) / (w * h), 3)
    white = (mn_px(fr) > 235) & solid
    inner = np.zeros_like(solid)
    pad_in = 20
    inner[max(0, y0 + pad_in):y1 - pad_in, max(0, x0 + pad_in):x1 - pad_in] = True
    rec["white_outside"] = int((white & ~inner).sum())
    rec["stray_islands"] = stray_islands(solid)
    return rec


def main():
    rows = json.load(open(os.path.join(WS, ".godot", "audit_map.json"), encoding="utf-8"))["rows"]
    key_info = {}
    for r in rows:
        k = r["key"]
        if not k:
            continue
        if k not in key_info:
            key_info[k] = {"name": r["name"], "kind": r["kind"], "era": r["era"],
                           "ids": [], "sides": set()}
        key_info[k]["ids"].append(r["id"])
        key_info[k]["sides"].add(r["side"])
    used_keys = set(key_info.keys())
    all_dirs = sorted(d for d in os.listdir(ANIM) if os.path.isdir(os.path.join(ANIM, d)))
    orphans = [d for d in all_dirs if d not in used_keys]

    # ── 动画逐目录 ──────────────────────────────────────────────
    units = []
    for d in all_dirs:
        info = key_info.get(d, {"name": "(孤儿·无id引用)", "kind": "orphan", "era": "-",
                                "ids": [], "sides": set()})
        typ = "humanoid" if info["kind"] == "light" else "platform"
        rec = {"dir": d, "name": info["name"], "kind": info["kind"], "type": typ,
               "ids": info["ids"][:4], "side": "/".join(sorted(info["sides"])) or "-",
               "issues": [], "qa": None, "metrics": {}}
        dd = os.path.join(ANIM, d)
        jp = os.path.join(dd, "anim.json")
        si, sa = os.path.join(dd, "sheet_idle.png"), os.path.join(dd, "sheet_attack.png")
        if not os.path.exists(jp):
            rec["issues"].append("no_anim_json")
        if os.path.exists(si) and not os.path.exists(si + ".import"):
            rec["issues"].append("idle_no_import")
        if os.path.exists(sa) and not os.path.exists(sa + ".import"):
            rec["issues"].append("attack_no_import")
        j = {}
        if os.path.exists(jp):
            try:
                j = json.load(open(jp, encoding="utf-8"))
            except Exception:
                rec["issues"].append("anim_json_parse_fail")
        counts = j.get("counts", {})
        ni, na = int(counts.get("idle", 0)), int(counts.get("attack", 0))
        if j and j.get("fps") != 8:
            rec["issues"].append("fps_%s" % j.get("fps"))
        if j and "foot_frac" not in j:
            rec["issues"].append("no_foot_frac")
        if j and "subject" not in j:
            rec["issues"].append("no_subject_block")

        idle_fr, att_fr = None, None
        for tag, path, cnt in (("idle", si, ni), ("attack", sa, na)):
            if not os.path.exists(path):
                rec["issues"].append("no_sheet_" + tag)
                continue
            sh = load_rgba(path)
            if sh.shape[0] != F:
                rec["issues"].append("%s_height_%d" % (tag, sh.shape[0]))
            if sh.shape[1] % F != 0:
                rec["issues"].append("%s_width_%d_not_multiple" % (tag, sh.shape[1]))
            n_actual = sh.shape[1] // F
            if cnt and n_actual != cnt:
                rec["issues"].append("%s_counts_%d_vs_sheet_%d" % (tag, cnt, n_actual))
            if tag == "idle":
                idle_fr = frames_of(sh)
            else:
                att_fr = frames_of(sh)

        if idle_fr:
            mags = [magenta_split(fr) for fr in idle_fr]
            soft = sum(m[0] for m in mags); solid = sum(m[1] for m in mags)
            rec["metrics"]["idle_mag_soft"], rec["metrics"]["idle_mag_solid"] = soft, solid
            body_edge = sum(edge_touch(body_mask(fr)) for fr in idle_fr)
            rec["metrics"]["idle_body_edge"] = body_edge
            rec["metrics"]["idle_faint_edge"] = sum(faint_edge(fr) for fr in idle_fr)
            if body_edge > 50:
                rec["issues"].append("idle_truncated(主体贴边%dpx)" % body_edge)
            if soft > 50:
                rec["issues"].append("idle_magenta_seep_%dpx" % soft)
            if solid > 2000:
                rec["issues"].append("idle_magenta_solid_%dpx(目检:主题色?)" % solid)
            ious = [iou(body_mask(idle_fr[i]), body_mask(idle_fr[i + 1]))
                    for i in range(len(idle_fr) - 1)]
            rec["metrics"]["idle_min_iou"] = round(min(ious), 3) if ious else 1.0
            if ious and min(ious) >= 0.999:
                rec["issues"].append("idle_static(全帧相同=静画)")
            ih, iw, _, _ = bbox_hw(body_mask(idle_fr[0]))
            rec["metrics"]["idle0_h"], rec["metrics"]["idle0_w"] = ih, iw

        if att_fr:
            mags = [magenta_split(fr) for fr in att_fr]
            soft = sum(m[0] for m in mags); solid = sum(m[1] for m in mags)
            rec["metrics"]["attack_mag_soft"], rec["metrics"]["attack_mag_solid"] = soft, solid
            body_edge = sum(edge_touch(body_mask(fr)) for fr in att_fr)
            rec["metrics"]["attack_body_edge"] = body_edge
            rec["metrics"]["attack_faint_edge"] = sum(faint_edge(fr) for fr in att_fr)
            if body_edge > 50:
                rec["issues"].append("attack_truncated(主体贴边%dpx)" % body_edge)
            if soft > 50:
                rec["issues"].append("attack_magenta_seep_%dpx" % soft)
            if solid > 2000:
                rec["issues"].append("attack_magenta_solid_%dpx(目检:主题色?)" % solid)

            rec["qa"] = qa_attack(att_fr, typ)
            qf = [k for k in ("size", "facing", "fire", "foot", "motion", "loop")
                  if not rec["qa"][k]["pass"]]
            rec["qa_fails"] = qf

            if idle_fr:
                base = body_mask(idle_fr[0])
                syn = [round(shift_overlap(body_mask(fr), base), 3) for fr in att_fr]
                rec["metrics"]["attack_vs_idle0_shift"] = syn
                nonfire = [i for i, fr in enumerate(att_fr) if fire_px(fr).sum() <= 500]
                syn_nf = [syn[i] for i in nonfire]
                if syn_nf and max(syn_nf) >= 0.95:
                    rec["issues"].append("attack_SYNTHETIC(纯平移=%.2f)" % max(syn_nf))
                ah, aw, _, _ = bbox_hw(body_mask(att_fr[0]))
                ih = rec["metrics"].get("idle0_h", 0)
                if ih and ah:
                    rh = abs(ah / ih - 1)
                    rec["metrics"]["subject_resid_h"] = round(rh, 3)
                    if rh >= 0.15:
                        rec["issues"].append("subject_resid_h=%.0f%%(≥15重生成档)" % (rh * 100))
                    elif rh >= 0.12:
                        rec["issues"].append("subject_resid_h=%.0f%%(12~15美术债档)" % (rh * 100))
        units.append(rec)

    # ── 卡图卫生 + 缩略图内容级比对 ────────────────────────────
    card_issues = {"stale_thumbs_content": [], "missing_thumbs": [], "missing_import": [],
                   "root_strays": [], "card_flags": {}}
    expected_dirs = {"_thumb256", "_thumb384", "player", "enemy"}
    for fn in os.listdir(CARD):
        p = os.path.join(CARD, fn)
        if os.path.isfile(p) and fn.endswith(".png"):
            card_issues["root_strays"].append(fn)
        elif os.path.isdir(p) and fn not in expected_dirs:
            card_issues["root_strays"].append(fn + "/")
    for tree in ("_thumb256", "_thumb384"):
        td = os.path.join(CARD, tree)
        for fn in os.listdir(td):
            if fn.endswith(".png"):
                card_issues["root_strays"].append("%s/%s" % (tree, fn))

    for sub in ("player", "enemy"):
        src_dir = os.path.join(CARD, sub)
        if not os.path.isdir(src_dir):
            continue
        for fn in sorted(os.listdir(src_dir)):
            if not fn.endswith(".png"):
                continue
            src_path = os.path.join(src_dir, fn)
            rel = "%s/%s" % (sub, fn)
            if not os.path.exists(src_path + ".import"):
                card_issues["missing_import"].append(rel)
            src = load_rgba(src_path)
            flags = []
            crec = check_card_png(src_path)
            if crec.get("edge_solid", 0) > 60:
                flags.append("截断贴边%dpx" % crec["edge_solid"])
            if crec.get("corner_alpha_max", 0) > 40:
                flags.append("四角残留α=%d" % crec["corner_alpha_max"])
            if crec.get("halo_frac", 0) > 0.15:
                flags.append("光晕占比%.0f%%" % (crec["halo_frac"] * 100))
            if crec.get("white_outside", 0) > 400:
                flags.append("白底残留%dpx" % crec["white_outside"])
            if crec.get("stray_islands", 0) > 0:
                flags.append("离群杂物%d块" % crec["stray_islands"])
            cf = crec.get("content_frac", 0)
            if cf and (cf < 0.30 or cf > 0.92):
                flags.append("主体bbox占比%.2f" % cf)
            if flags:
                card_issues["card_flags"][rel] = flags
            for tree, tsz in (("_thumb256", 256), ("_thumb384", 384)):
                th = os.path.join(CARD, tree, sub, fn)
                if not os.path.exists(th):
                    card_issues["missing_thumbs"].append("%s/%s" % (tree, rel))
                    continue
                ref = np.asarray(Image.fromarray(src.astype(np.uint8)).resize(
                    (tsz, tsz), Image.LANCZOS)).astype(int)
                cur = load_rgba(th)
                if cur.shape != ref.shape or int(np.abs(cur - ref).max()) > 8:
                    card_issues["stale_thumbs_content"].append("%s/%s" % (tree, rel))

    # ── 暂存管线 ────────────────────────────────────────────────
    staging = []
    for d in sorted(os.listdir(RS)):
        if not d.startswith("api_"):
            continue
        sp = os.path.join(RS, d, "sheet_attack_api.png")
        entry = {"dir": d}
        if not os.path.exists(sp):
            entry["status"] = "no_sheet"
            staging.append(entry)
            continue
        sh = load_rgba(sp)
        fr_list = frames_of(sh)
        entry["frames"] = len(fr_list)
        uid = d[4:]
        dep = os.path.join(ANIM, uid, "sheet_attack.png")
        entry["deployed"] = False
        if os.path.exists(dep) and fr_list:
            dfr = frames_of(load_rgba(dep))
            if dfr:
                entry["deployed"] = iou(body_mask(fr_list[0]), body_mask(dfr[0])) >= 0.98
                if entry["deployed"]:
                    entry["deploy_note"] = "首帧主体与现役一致(counts=%d)" % len(dfr)
        typ = "humanoid" if key_info.get(uid, {}).get("kind") == "light" else "platform"
        entry["qa"] = qa_attack(fr_list, typ)
        entry["qa_fails"] = [k for k in ("size", "facing", "fire", "foot", "motion", "loop")
                             if not entry["qa"][k]["pass"]]
        staging.append(entry)

    # ── 用户标记对账 ────────────────────────────────────────────
    marks = {}
    mp = os.path.join(WS, "tools", "card_anim_review_marks (要修改的).json")
    if os.path.exists(mp):
        marks = json.load(open(mp, encoding="utf-8")).get("marks", {})
    unit_by_dir = {u["dir"]: u for u in units}
    mark_rows = []
    for mk, mv in sorted(marks.items()):
        key = mk.split("|", 1)[1] if "|" in mk else mk
        u = unit_by_dir.get(key)
        row = {"mark": mk, "problems": mv.get("p", []), "note": mv.get("n", ""),
               "alt": mv.get("a", "")}
        if u is None:
            row["status"] = "dir_missing(键无目录)"
        else:
            row["auto_issues"] = u["issues"]
            row["qa_fails"] = u.get("qa_fails", [])
            row["status"] = ("auto_clean(自动项全过,余目检)" if not u["issues"] and not u.get("qa_fails")
                             else "still_flagged")
        mark_rows.append(row)

    out = {"units": units, "orphans": orphans, "card_issues": card_issues,
           "staging": staging, "marks": mark_rows}

    def _sanitize(o):
        if isinstance(o, np.bool_):
            return bool(o)
        if isinstance(o, np.integer):
            return int(o)
        if isinstance(o, np.floating):
            return float(o)
        return str(o)

    json.dump(out, open(os.path.join(WS, ".godot", "full_audit_20261013.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1, default=_sanitize)

    print("=== 全量体检 v2 摘要 ===")
    print("动画目录: %d（引用 %d，孤儿 %d）" % (len(all_dirs), len(used_keys), len(orphans)))
    cnt = Counter()
    for u in units:
        for i in u["issues"]:
            cnt[i.split("(")[0]] += 1
        for k in u.get("qa_fails", []):
            cnt["qa_" + k] += 1
    print("动画问题分布:", dict(cnt.most_common(24)))
    fc = Counter(u["qa"]["fire"]["cat"] for u in units if u.get("qa"))
    print("fire 分桶:", dict(fc))
    print("卡图: 内容过期缩略图=%d 缺缩略图=%d 缺import=%d 根散物=%d 卡图自动flag=%d" % (
        len(card_issues["stale_thumbs_content"]), len(card_issues["missing_thumbs"]),
        len(card_issues["missing_import"]), len(card_issues["root_strays"]),
        len(card_issues["card_flags"])))
    pend = [s["dir"] for s in staging if not s.get("deployed")]
    print("暂存 %d 家: 未部署 %d %s" % (len(staging), len(pend), pend))
    mk_stat = Counter(r["status"].split("(")[0] for r in mark_rows)
    print("用户标记42项对账:", dict(mk_stat))
    print("明细 → .godot/full_audit_20261013.json")


if __name__ == "__main__":
    main()
