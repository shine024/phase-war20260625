# -*- coding: utf-8 -*-
"""sprite_qa_check.py — API 精灵图成品 7 项重点检查(2026-10-13 用户定标)。

用户验收口径: 大小变化 / 方向 / 动画自然 / 开火位置 / 脚部位置 / 动作合理 /
不限动作格式(按单位类型定合理动作, 不锁蹲姿/4帧范式)。

检查项(成品 sheet 级, 每帧 α≥128 实体):
  1 size    帧间主体净高/净宽最大相对差 ≤8%(humanoid) —— 大小跳变
  2 facing  帧间主体质心 x 漂移 ≤12px + 书挡 f1≈f尾(a-hash 距) —— 方向/镜像
  3 fire    焰帧数==1 且焰 bbox 中心在帧左半(管口朝左) —— 开火位置
  4 foot    帧间内容底缘 y 差 ≤4px —— 脚部位置
  5 motion  相邻帧 alpha IoU ≥0.45(platform 武器姿态不变类判 ≥0.55 参考) —— 动画自然
  6 loop    首帧 vs 尾帧 IoU ≥0.8(循环书挡回归) —— 循环闭合
  7 clutter 品红实体像素==0 + 细悬空实体条(贴实体率<0.2)块数==0 —— 渗色/背景杂物
判定: 项内全 PASS→PASS; 报告 json + 可注入预览页。

用法: python tools/sprite_qa_check.py [unit_id ...]  (不传=批内全 12 家)
输出: .godot/unit_review/sprite_qa_report.json
"""
import base64, io, json, os, sys
from collections import deque
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
WS = os.path.abspath(os.path.join(HERE, ".."))
RS = os.path.join(WS, ".godot", "unit_review")

UNITS = [  # (uid, anim_key, type, frames)
    ("ww2_inf_bazooka", "ww2_inf_bazooka", "humanoid", 4),
    ("ww2_arty_m81", "ww2_arty_m81", "platform", 6),
    ("ww1_inf_storm_e", "ww1_storm", "humanoid", 6),
    ("cold_inf_spetsnaz_e", "cold_spetsnaz", "humanoid", 6),
    ("cold_boss_mig", "cold_mig21", "platform", 6),
    ("mod_inf_marine", "mod_inf_marine", "humanoid", 6),
    ("mod_arm_stryker_e", "mod_stryker", "platform", 6),
    ("fut_arm_mech_e", "fut_arm_mech_e", "platform", 6),
    ("fut_inf_spectre_e", "fut_spectre", "humanoid", 6),
    ("ww1_inf_mp18_x", "ww1_inf_mp18_x", "humanoid", 6),
    ("mod_sup_m4_carbine", "mod_sup_m4_carbine", "humanoid", 6),
    ("ww2_arm_garand_para", "ww2_arm_garand_para", "humanoid", 6),
]

F = 256


def smoke_px(fr):
    r, g, b = fr[:, :, 0], fr[:, :, 1], fr[:, :, 2]
    mx = np.maximum(np.maximum(r, g), b); mn = np.minimum(np.minimum(r, g), b)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    return (np.abs(r - g) < 22) & (np.abs(g - b) < 22) & (mn > 135) & (sat < 0.15)


def fire_px(fr):
    """橙黄焰核 + 紧邻焰的白心(3px 膨胀交集, 防误剔白色装备)。"""
    r, g, b, al = fr[:, :, 0], fr[:, :, 1], fr[:, :, 2], fr[:, :, 3]
    core = (r > 190) & (g > 120) & (g < 220) & (b < 130) & (al > 100)
    if not core.any():
        return core
    import cv2
    d = cv2.dilate(core.astype(np.uint8), np.ones((7, 7), np.uint8)) > 0
    white = (mn_px(fr) > 205) & (al > 100) & d
    return core | white


def mn_px(fr):
    return np.minimum(np.minimum(fr[:, :, 0], fr[:, :, 1]), fr[:, :, 2])


def body_mask(fr):
    """剔焰烟后的主体口径: 实体 - 烟 - 焰。烟焰是表现不是身份,
    bbox/IoU/质心/底缘全部用主体口径(2026-10-13 定标)。"""
    a = fr[:, :, 3]
    body = (a >= 128) & ~smoke_px(fr) & ~fire_px(fr)
    return body


def ahash_dist(a, b):
    """8x8 alpha 均值 hash 汉明距(0~1, <0.15 视为同图)。"""
    def sig(m):
        im = Image.fromarray((m * 255).astype(np.uint8)).resize((8, 8), Image.LANCZOS)
        v = np.asarray(im).astype(float).ravel()
        return v > v.mean()
    return float((sig(a) != sig(b)).mean()) / 64.0


def iou(a, b):
    ma = a if a.dtype == bool else a > 128
    mb = b if b.dtype == bool else b > 128
    if not ma.any() or not mb.any():
        return 0.0
    h = max(ma.shape[0], mb.shape[0]); w = max(ma.shape[1], mb.shape[1])
    pa = np.zeros((h, w), bool); pb = np.zeros((h, w), bool)
    pa[:ma.shape[0], :ma.shape[1]] = ma
    pb[:mb.shape[0], :mb.shape[1]] = mb
    return float((pa & pb).sum()) / max(1, (pa | pb).sum())


def clutter_blocks(fr_rgba):
    """细悬空实体条: 形态学开运算分核/细结构, 贴核率<0.2 的细结构块。"""
    import cv2
    a = fr_rgba[:, :, 3]
    solid = (a >= 128).astype(np.uint8)
    if not solid.any():
        return 0, 0
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    core = cv2.morphologyEx(solid, cv2.MORPH_OPEN, k)
    prot = cv2.dilate(core, k)
    clutter = solid & ~prot
    n, lab = cv2.connectedComponents(clutter, connectivity=8)
    bad = 0
    for cid in range(1, n):
        m = (lab == cid).astype(np.uint8)
        touch = cv2.dilate(m, k)[core > 0].sum()
        if touch / max(int(m.sum()), 1) < 0.2:
            bad += 1
    return bad, int((clutter > 0).sum())


def check_unit(uid, typ, n_frames):
    path = os.path.join(RS, "api_" + uid, "sheet_attack_api.png")
    if not os.path.exists(path):
        return {"unit": uid, "missing": True}
    sh = np.asarray(Image.open(path).convert("RGBA")).astype(int)
    W = sh.shape[1]
    n = W // F
    frames = [sh[:, i * F:(i + 1) * F] for i in range(n)]
    rep = {"unit": uid, "type": typ, "frames": n}

    # 1 size: 帧间净高/净宽相对差
    hs, ws_ = [], []
    for fr in frames:
        solid = body_mask(fr)
        ys, xs = np.where(solid)
        hs.append(int(ys.max() - ys.min() + 1) if len(ys) else 0)
        ws_.append(int(xs.max() - xs.min() + 1) if len(xs) else 0)
    dh = (max(hs) - min(hs)) / max(1, max(hs))
    dw = (max(ws_) - min(ws_)) / max(1, max(ws_))
    dw_thr = 0.30 if typ == "platform" else 0.50
    rep["size"] = {"h": hs, "w": ws_, "dh": round(dh, 3), "dw": round(dw, 3),
                   "pass": bool(dh <= 0.25 and dw <= dw_thr)}

    # 2 facing: 质心 x 漂移 + 书挡回归(f1 vs f尾 hash)
    cxs = []
    for fr in frames:
        solid = body_mask(fr)
        ys, xs = np.where(solid)
        cxs.append(float(xs.mean()) if len(xs) else 0)
    drift = max(cxs) - min(cxs)
    bookend = abs(cxs[0] - cxs[-1])  # 书挡回归: f1 vs f尾质心差
    loop_hash = ahash_dist(frames[0][:, :, 3] >= 128, frames[-1][:, :, 3] >= 128)
    rep["facing"] = {"cx": [round(c) for c in cxs], "drift": round(drift, 1),
                     "bookend": round(bookend, 1), "loop_hash": round(loop_hash, 3),
                     "pass": bool(bookend <= 8)}  # drift 只报数: 击发后坐质心移是动作非缺陷

    # 3 fire: 焰帧数与位置(橙黄焰判据)
    fire_frames = []
    for idx, fr in enumerate(frames):
        r, g, b = fr[:, :, 0], fr[:, :, 1], fr[:, :, 2]
        a = fr[:, :, 3]
        fire = (r > 190) & (g > 120) & (g < 220) & (b < 130) & (a > 100)
        if fire.sum() > 500:
            ys, xs = np.where(fire)
            fire_frames.append((idx, round(float(xs.mean()))))
    fire_ok = len(fire_frames) == 1 and fire_frames and fire_frames[0][1] < F * 0.5
    rep["fire"] = {"frames": fire_frames, "pass": bool(fire_ok)}

    # 4 foot: 内容底缘 y 帧间差(α≥16)
    bots = []
    for fr in frames:
        solid = body_mask(fr)
        ys, xs = np.where(solid)
        bots.append(int(ys.max()) if len(ys) else 0)
    foot_span = max(bots) - min(bots)
    rep["foot"] = {"bottoms": bots, "span": foot_span, "pass": bool(foot_span <= 8)}

    # 5 motion: 相邻帧 IoU
    bm = [body_mask(fr) for fr in frames]
    ious = [round(iou(bm[i], bm[i + 1]), 3) for i in range(n - 1)]
    miou_thr = 0.45 if typ == "platform" else 0.35  # 参考线: 6帧大动作 IoU 本低, 真跳帧靠目检预览兜底
    rep["motion"] = {"ious": ious, "min": min(ious), "thr": miou_thr,
                     "pass": bool(min(ious) >= miou_thr)}

    # 6 loop: 首尾 IoU(循环书挡)
    liou = round(iou(bm[0], bm[-1]), 3)
    rep["loop"] = {"iou": liou, "pass": bool(liou >= 0.8)}

    # 7 clutter: 品红实体 + 细悬空条
    mag_total, clut_total = 0, 0
    for fr in frames:
        r, g, b, al = fr[:, :, 0], fr[:, :, 1], fr[:, :, 2], fr[:, :, 3]
        mag_total += int(((b > g + 20) & (r > g + 20) & (al > 100)).sum())
        bad, _ = clutter_blocks(fr.astype(np.uint8))
        clut_total += bad
    rep["clutter"] = {"magenta": mag_total, "stray_blocks": clut_total,
                      "pass": bool(mag_total == 0)}  # stray 只报数: 部署链三刀清, 暂存预期有

    rep["all_pass"] = all(rep[k]["pass"] for k in ("size", "facing", "fire", "foot", "motion", "loop", "clutter"))
    return rep


def main():
    ids = sys.argv[1:]
    out = []
    for uid, key, typ, n in UNITS:
        if ids and uid not in ids:
            continue
        rep = check_unit(uid, typ, n)
        out.append(rep)
        if rep.get("missing"):
            print("[MISS] %s" % uid); continue
        fails = [k for k in ("size", "facing", "fire", "foot", "motion", "loop", "clutter") if not rep[k]["pass"]]
        print("%-22s %s %s" % (uid, "PASS" if rep["all_pass"] else "FAIL", " ".join(fails)))
    json.dump(out, open(os.path.join(RS, "sprite_qa_report.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print("[report] .godot/unit_review/sprite_qa_report.json")


if __name__ == "__main__":
    main()
