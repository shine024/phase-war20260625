# -*- coding: utf-8 -*-
"""MK6 机械手术批（2026-10-04，卡图动画总审 marks「按提示改」第一批——无 API 修复）：
M1 mod_ah64 idle        f5 视角跳出→自 f0 重建 ±1px 微悬停环（用户：待机摆动太大）
M2 cold_spetsnaz idle   只测头顶位移不动刀（已是微呼吸，报数即可）
M3 ww2_thompson attack  火光平移到枪口线 + 头盔上方离体黑渣擦除（用户：错误描边）
M4 ww2_inf_hellcat attack 空中飘浮火光/烟团→炮口重贴（用户：错误描边[攻击]）
M5 ww1_fort_artillery attack f2 整车跳位→对齐地线（用户：clip）
M6 ww2_sup_gmc_truck    攻击=待机复用（用户：不用开火，用待的就好）
M7 卡图取帧             mod_arty_m270/mod_ranger/ww2_arm_garand_para/vis_xeno_dark_templar
                        敌侧(或共享)卡图 ← idle f0 派生（用户：卡图换/待机图做卡图）
旧件备份 .godot/art_backup_mk6_20261004/<unit>/。跑完须过导入门禁。
用法: python tools/_mk6_mech_batch.py
"""
import io
import json
import os
import shutil
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = os.path.join(ROOT, "assets", "effects", "unit_anims")
BAK = os.path.join(ROOT, ".godot", "art_backup_mk6_20261004")
STG = os.path.join(ROOT, ".godot", "unit_review", "mk6_staging")
os.makedirs(BAK, exist_ok=True)
os.makedirs(STG, exist_ok=True)


def backup(unit, *files):
    d = os.path.join(BAK, unit)
    os.makedirs(d, exist_ok=True)
    for f in files:
        p = os.path.join(UA, unit, f)
        if os.path.exists(p):
            shutil.copy2(p, os.path.join(d, f))


def load_frames(unit, anim):
    meta = json.load(open(os.path.join(UA, unit, "anim.json"), encoding="utf-8"))
    sp = os.path.join(UA, unit, "sheet_%s.png" % anim)
    sh = Image.open(sp).convert("RGBA")
    n = int(meta["counts"][anim])
    fs = int(meta.get("frame_size", 256))
    fw = sh.width // n
    frs = [sh.crop((i * fw, 0, (i + 1) * fw, sh.height)) for i in range(n)]
    if fw != fs:
        frs = [f.resize((fs, fs), Image.LANCZOS) for f in frs]
    return meta, fs, frs


def save_strip(unit, anim, frs, meta, fs):
    sh = Image.new("RGBA", (fs * len(frs), fs), (0, 0, 0, 0))
    for i, f in enumerate(frs):
        sh.paste(f, (i * fs, 0))
    sp = os.path.join(UA, unit, "sheet_%s.png" % anim)
    sh.save(sp)
    meta.setdefault("counts", {})[anim] = len(frs)
    json.dump(meta, open(os.path.join(UA, unit, "anim.json"), "w", encoding="utf-8"),
              ensure_ascii=False)
    print("  [save] %s/%s n=%d" % (unit, anim, len(frs)))


def preview(unit, anim, frs, fs, tag=""):
    g = Image.new("RGB", (min(6, len(frs)) * fs, ((len(frs) + 5) // 6) * fs), (38, 42, 50))
    for i, f in enumerate(frs):
        g.paste(f, (i % 6 * fs, i // 6 * fs), f)
    g.save(os.path.join(STG, "verify_%s_%s%s.png" % (unit, anim, tag)))


def components(arr):
    """alpha>40 的连通域（4邻接，BFS）。返回 [(mask_bool, bbox, area)]。"""
    a = arr[:, :, 3] > 40
    H, W = a.shape
    seen = np.zeros_like(a, dtype=bool)
    out = []
    for y0 in range(H):
        for x0 in range(W):
            if a[y0, x0] and not seen[y0, x0]:
                stack = [(y0, x0)]
                seen[y0, x0] = True
                pix = []
                while stack:
                    y, x = stack.pop()
                    pix.append((y, x))
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < H and 0 <= nx < W and a[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            stack.append((ny, nx))
                ys = [p[0] for p in pix]; xs = [p[1] for p in pix]
                out.append((pix, (min(xs), min(ys), max(xs), max(ys)), len(pix)))
    return out


def classify_ccs(fr):
    """帧 → (body_pix, shadows_pix列表, flashes_pix列表, junk_pix列表)。
    flashes=亮黄白离体；shadows=宽扁暗离体(贴地)；junk=其余暗离体。"""
    arr = np.asarray(fr)
    ccs = components(arr)
    if not ccs:
        return None, [], [], []
    ccs.sort(key=lambda c: -c[2])
    body = ccs[0][0]
    by_index = {id(c[0]): c for c in ccs}
    bottom = by_index[id(body)][1][3]
    cx = (by_index[id(body)][1][0] + by_index[id(body)][1][2]) / 2
    hsv = np.asarray(Image.fromarray(arr[:, :, :3].astype(np.uint8)).convert("HSV")).astype(int)
    flashes, shadows, junk = [], [], []
    for pix, bb, area in ccs[1:]:
        if area < 25:
            junk.append(pix); continue
        vs = hsv[:, :, 1][[p[0] for p in pix], [p[1] for p in pix]]
        vv = hsv[:, :, 2][[p[0] for p in pix], [p[1] for p in pix]]
        mv, ms = vv.mean(), vs.mean()
        w = bb[2] - bb[0] + 1; h = bb[3] - bb[1] + 1
        cxl = (bb[0] + bb[2]) / 2
        if mv > 140 and ms > 55:
            flashes.append(pix)
        elif bb[3] >= bottom - 14 and w > 2.5 * h:
            shadows.append(pix)  # 贴地宽扁=影子，保留
        else:
            junk.append(pix)
    return body, shadows, flashes, junk


def pix_mask(pix, shape):
    m = np.zeros(shape[:2], dtype=bool)
    ys = [p[0] for p in pix]; xs = [p[1] for p in pix]
    m[ys, xs] = True
    return m


def move_flash(fr, flash_pix, tip_xy, anchor="right"):
    """把火光 CC 平移到枪口 tip（anchor: right=火光右缘贴 tip 左侧向左伸）。
    返回新帧。"""
    arr = np.asarray(fr).copy()
    H, W = arr.shape[:2]
    m = pix_mask(flash_pix, arr.shape)
    ys, xs = np.nonzero(m)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    flash = arr[y0:y1 + 1, x0:x1 + 1].copy()
    arr[y0:y1 + 1, x0:x1 + 1][m[y0:y1 + 1, x0:x1 + 1]] = 0
    w, h = x1 - x0 + 1, y1 - y0 + 1
    tx, ty = tip_xy
    if anchor == "right":   # 朝左枪管：火光右缘略过枪口
        nx = int(round(tx - w * 0.7))
    else:                   # 朝右枪管：火光左缘略过枪口
        nx = int(round(tx - w * 0.3))
    ny = int(round(ty - h / 2))
    nx = max(0, min(W - w, nx)); ny = max(0, min(H - h, ny))
    sub = arr[ny:ny + h, nx:nx + w]
    fm = m[y0:y1 + 1, x0:x1 + 1]
    sub[fm] = np.maximum(sub[fm], flash[fm])
    return Image.fromarray(arr)


def muzzle_tip(body_pix, side, band=None):
    """body 主域在 barrel 突出带的尖端 (x, y)。side='L' 朝左 / 'R' 朝右。"""
    ys = np.array([p[0] for p in body_pix]); xs = np.array([p[1] for p in body_pix])
    if side == "L":
        xm = xs.min()
        sel = ys[xs <= xm + 6]
    else:
        xm = xs.max()
        sel = ys[xs >= xm - 6]
    if band is not None:
        sel = sel[(sel >= band[0]) & (sel <= band[1])]
    return (int(xm), int(np.median(sel)))


# ── M1 mod_ah64 idle：f0 重建 ±1px 微悬停环 ─────────────────────────────
def m1():
    unit = "mod_ah64"
    meta, fs, frs = load_frames(unit, "idle")
    backup(unit, "sheet_idle.png", "anim.json")
    a0 = np.asarray(frs[0]).copy()
    up = np.roll(a0, -1, axis=0); up[-1:, :] = 0
    loop = [a0, a0, up, up, a0, a0, a0, a0]
    save_strip(unit, "idle", [Image.fromarray(f) for f in loop], meta, fs)
    preview(unit, "idle", [Image.fromarray(f) for f in loop], fs)


# ── M2 cold_spetsnaz idle：头顶贴顶(8帧全 y=0)→97% 重锚定留出呼吸余量 ──
def m2():
    unit = "cold_spetsnaz"
    meta, fs, frs = load_frames(unit, "idle")
    a0 = np.asarray(frs[0])
    ys = np.nonzero(a0[:, :, 3] > 40)[0]
    top, bot = int(ys.min()), int(ys.max())
    if top > 4:
        print("  [skip] 头顶已有 %dpx 余量" % top)
        return
    backup(unit, "sheet_idle.png", "anim.json")
    ground = bot  # 脚线
    h = bot - top + 1
    sc = 0.97
    nh = int(round(h * sc))
    body = frs[0].crop((0, top, fs, bot + 1)).resize((fs, nh), Image.LANCZOS)
    out = []
    base = Image.new("RGBA", (fs, fs), (0, 0, 0, 0))
    base.paste(body, (0, ground - nh + 1), body)
    a0n = np.asarray(base).copy()
    up = np.roll(a0n, -2, axis=0); up[-2:, :] = 0
    loop = [a0n, a0n, up, up, a0n, a0n, a0n, a0n]
    save_strip(unit, "idle", [Image.fromarray(f) for f in loop], meta, fs)
    preview(unit, "idle", [Image.fromarray(f) for f in loop], fs)
    print("  [refit] 头顶 y=0 → 余量 %dpx，脚线保持 %d" % (ground - nh + 1, ground))


# ── M3 ww2_thompson attack ─────────────────────────────────────────────
def m3():
    unit = "ww2_thompson"
    meta, fs, frs = load_frames(unit, "attack")
    backup(unit, "sheet_attack.png", "anim.json")
    out = []
    for i, fr in enumerate(frs):
        body, shd, fls, junk = classify_ccs(fr)
        if body is None:
            out.append(fr); continue
        arr = np.asarray(fr).copy()
        # 擦 junk（离体暗渣）
        for pix in junk:
            arr[pix_mask(pix, arr.shape)] = 0
        fr2 = Image.fromarray(arr)
        # 火光平移到枪口线
        if fls:
            tip = muzzle_tip(body, "L", band=(30, fs // 2))
            for pix in fls:
                fr2 = move_flash(fr2, pix, tip, "right")
            print("  [f%d] 火光→枪口 %s" % (i, tip))
        elif junk:
            print("  [f%d] 擦除离体暗渣 %d 块" % (i, len(junk)))
        out.append(fr2)
    save_strip(unit, "attack", out, meta, fs)
    preview(unit, "attack", out, fs)


# ── M4 ww2_inf_hellcat attack（朝右） ─────────────────────────────────
def m4():
    unit = "ww2_inf_hellcat"
    meta, fs, frs = load_frames(unit, "attack")
    backup(unit, "sheet_attack.png", "anim.json")
    out = []
    for i, fr in enumerate(frs):
        body, shd, fls, junk = classify_ccs(fr)
        if body is None:
            out.append(fr); continue
        arr = np.asarray(fr).copy()
        for pix in junk:
            arr[pix_mask(pix, arr.shape)] = 0
        fr2 = Image.fromarray(arr)
        if fls:
            tip = muzzle_tip(body, "R", band=(30, fs // 2))
            for pix in fls:
                fr2 = move_flash(fr2, pix, tip, "left")
            print("  [f%d] 火光→炮口 %s" % (i, tip))
        elif junk:
            print("  [f%d] 擦除 %d 块" % (i, len(junk)))
        out.append(fr2)
    save_strip(unit, "attack", out, meta, fs)
    preview(unit, "attack", out, fs)


# ── M5 ww1_fort_artillery attack：f2 对齐地线 ─────────────────────────
def m5():
    unit = "ww1_fort_artillery"
    meta, fs, frs = load_frames(unit, "attack")
    backup(unit, "sheet_attack.png", "anim.json")
    bots = []
    for f in frs:
        body, shd, fls, junk = classify_ccs(f)
        if body is None:
            bots.append(None); continue
        bb_y = max(p[0] for p in body)
        bots.append(int(bb_y))
    med = int(np.median([b for b in bots if b is not None]))
    out = []
    for i, f in enumerate(frs):
        if bots[i] is None or bots[i] == med:
            out.append(f); continue
        dy = med - bots[i]
        arr = np.asarray(f).copy()
        arr = np.roll(arr, dy, axis=0)
        if dy > 0:
            arr[:dy, :, :] = 0
        else:
            arr[dy:, :, :] = 0
        out.append(Image.fromarray(arr))
        print("  [f%d] 底缘 %d → %d (平移 %+d)" % (i, bots[i], med, dy))
    save_strip(unit, "attack", out, meta, fs)
    preview(unit, "attack", out, fs)


# ── M6 ww2_sup_gmc_truck：攻击=待机复用 ───────────────────────────────
def m6():
    unit = "ww2_sup_gmc_truck"
    meta, fs, frs = load_frames(unit, "idle")
    backup(unit, "sheet_attack.png", "anim.json")
    save_strip(unit, "attack", [f.copy() for f in frs], meta, fs)
    preview(unit, "attack", frs, fs)


def facing(im):
    """枪管侧探测：上 2/3 带内，极端列里低占比列在左=L / 在右=R。None=不定。"""
    a = np.asarray(im.convert("RGBA"))[:, :, 3]
    H, W = a.shape
    band = a[: int(H * 0.66)]
    col = (band > 40).sum(axis=0).astype(float)
    if col.max() <= 0:
        return None
    thr = col.max() * 0.30
    thin = np.nonzero(col < thr)[0]
    if len(thin) == 0:
        return None
    return "L" if thin.min() < W - 1 - thin.max() else "R"


# ── M7 卡图取帧 ────────────────────────────────────────────────────────
def m7():
    # icon 源: idle f0（256²）。敌侧专属 vis_enemy_* 与玩家侧关系先探测（镜像?）
    CI = os.path.join(ROOT, "assets", "card_icons")
    jobs = [
        # (unit anim dir, 目标 icon 绝对路径, 侧)
        ("mod_arty_m270", os.path.join(CI, "enemy", "vis_enemy_060.png"), "enemy"),
        ("mod_ranger", os.path.join(CI, "enemy", "vis_enemy_061.png"), "enemy"),
        ("ww2_arm_garand_para", os.path.join(CI, "ww2_arm_garand_para.png"), "shared"),
        ("vis_xeno_dark_templar", os.path.join(CI, "vis_xeno_dark_templar.png"), "shared"),
    ]
    # 探测镜像关系
    pe = os.path.join(CI, "enemy", "vis_enemy_060.png")
    pp = os.path.join(CI, "player", "vis_player_060.png")
    if os.path.exists(pe) and os.path.exists(pp):
        ae = np.asarray(Image.open(pe).convert("L").resize((64, 64)))
        ap = np.asarray(Image.open(pp).convert("L").resize((64, 64)))
        same = float(np.abs(ae.astype(int) - ap.astype(int)).mean())
        mir = float(np.abs(ae.astype(int) - np.fliplr(ap).astype(int)).mean())
        print("  [probe] enemy060 vs player060: same=%.1f mirror=%.1f → %s" %
              (same, mir, "同图" if same < mir else "镜像"))
    for unit, dst, side in jobs:
        if not os.path.exists(dst):
            print("  [skip] 目标不存在 %s" % dst); continue
        meta, fs, frs = load_frames(unit, "idle")
        src = frs[0]
        iw, ih = Image.open(dst).size
        im = src.resize((iw, ih), Image.LANCZOS) if (iw, ih) != (fs, fs) else src
        d = os.path.join(BAK, "card_icons", os.path.basename(dst))
        os.makedirs(os.path.dirname(d), exist_ok=True)
        cur = Image.open(dst).convert("RGBA")
        if not os.path.exists(d):
            shutil.copy2(dst, d)
            print("  [bak] %s" % os.path.basename(dst))
        # 朝向保真：与被替换卡图同朝向（枪管/炮管侧一致），不符则镜像
        f_old = facing(cur)
        f_new = facing(im)
        if f_old and f_new and f_old != f_new:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
            print("  [flip] %s: 新图%s朝→旧图%s朝，已镜像" % (os.path.basename(dst), f_new, f_old))
        im.save(dst)
        pv = im.resize((192, 192), Image.LANCZOS)
        pv.save(os.path.join(STG, "verify_icon_%s.png" % unit))
        print("  [icon] %s ← %s idle f0 (%dx%d, %s)" % (os.path.basename(dst), unit, iw, ih, side))


def main():
    for fn in (m1, m2, m3, m4, m5, m6, m7):
        print("── %s" % fn.__name__)
        fn()
    print("完成。备份 → %s" % BAK)
    print("下一步: Godot --headless --path . --import")


if __name__ == "__main__":
    main()
