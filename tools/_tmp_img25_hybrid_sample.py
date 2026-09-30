# -*- coding: utf-8 -*-
"""混合路线样本（2026-09-30）：锚点层 + 单帧生成 + 程序序列。

样本单位：fut_nano_drone（enemy 卡图朝左直用，能量? 防御? 从 R.U 查）。

流程（vs 旧 6 帧雪碧图）：
  1 锚生成   卡图 → 单帧中性"游戏锚"（正侧向/无特效/白底），目检身份
  2 开火帧   从锚 img2img 派生单帧开火图（唯一变化=武器开火），目检身份
  3 程序序列 idle = f0 程序浮动（零生成）；attack = f0 + 开火帧 + 程序后坐/过渡 → 回文拼帧
  4 产物只进 .godot/unit_review/img25_staging/hybrid/，不部署

用法：python tools/_tmp_img25_hybrid_sample.py            # 全流程
      python tools/_tmp_img25_hybrid_sample.py --review   # 只重拼对比图（生成已缓存）
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import img25_sprite_trial as P
import _tmp_img25_redo_88 as R

KEY = "fut_nano_drone"
FS = 256
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging", "hybrid", KEY)
os.makedirs(OUT, exist_ok=True)

UROW = [u for u in R.U if u[0] == KEY][0]
REL, WEAPON, ENERGY, DEFENSIVE = UROW[1], UROW[2], UROW[3], UROW[4]
FLASH = R.ENE_FLASH if ENERGY else R.KIN_FLASH
SUBJECT = R.SUBJECT_EN.get(KEY) or P.SUBJECT_OVERRIDES.get(KEY, P.subject_for(KEY))
# fut_nano_drone 主体锁死（subject_for 中文模糊描述会把生成带成战机，实测）
SUBJECT = ("the compact round hovering drone shown in Image 1: a ball-shaped blue-grey hull "
           "with a large dark front sensor visor, small side fins and thin landing legs — "
           "a floating orb drone, strictly NOT a jet, NOT a plane, no wings")

ANCHOR_PROMPT = """Intended use:
Create a single reference image (the game anchor) of a 2D game unit in exact side view.

Input images:
Image 1 is the identity anchor for %s. Preserve the exact identity, colors, proportions, silhouette, palette, and left-facing direction.

Primary request:
Redraw this exact subject as a clean game sprite in a neutral ready pose, facing LEFT in exact side view. Remove any baked-in effects (glow, fire, smoke, trails). This is the master reference that all animation frames will be derived from.

Background: pure flat white fills the entire canvas edge to edge; the subject floats freely in empty white space with nothing beneath or behind it; the only pixels in the whole image are the subject and white.

Style:
- 2D game sprite, clean volumetric color painting, no black outline, no contour line
- crisp edges, consistent lighting and palette, readable silhouette

Constraints:
- the subject faces LEFT in exact side view, never right, never toward the camera
- a single subject only; no effects, no ground, no shadow, no label, no border
- do not crop any part of the subject
""" % SUBJECT

FIRE_PROMPT = """Intended use:
Edit a 2D game sprite image to create a single attack frame.

Input images:
Image 1 is a game sprite of %s, facing LEFT in exact side view.

Primary request:
Edit Image 1: add a %s at the tip of its gun barrel. Keep everything else exactly the same: same hull shape, same light blue-grey colors, same panel lines, same front sensor eye, same side gun barrel, same landing legs, same scale, same left-facing side view, same pure white background. The only new pixels in the whole image are the small flash at the barrel tip.

Background: the same pure flat white as Image 1, edge to edge; no ground, no shadow, no label, no border.

Style:
- identical to Image 1 in every way except the flash
- crisp edges, consistent lighting and palette

Constraints:
- do NOT redraw the subject; do NOT change its shape, colors, details, pose or direction
- it is NOT a jet aircraft, NOT a plane — no wings, no long fuselage
- the flash is small and brief at the weapon only
- a single subject only
- do not crop any part of the subject
""" % (SUBJECT, FLASH)


def uri(img, size=512):
    t = img.convert("RGB")
    if max(t.size) != size:
        t = t.resize((size, size), Image.LANCZOS)
    import base64
    import io
    buf = io.BytesIO()
    t.save(buf, "PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def gen_single(name, prompt, img_inputs):
    """单帧生成（带缓存）。返回 raw bytes 或 None。"""
    rawp = os.path.join(OUT, "%s_raw.png" % name)
    if os.path.exists(rawp):
        return open(rawp, "rb").read()
    pf = os.path.join(OUT, "%s_payload.json" % name)
    open(pf, "w", encoding="utf-8").write(json.dumps({
        "model": "agnes-image-2.5-flash", "prompt": prompt,
        "size": "2K", "ratio": "16:9",
        "extra_body": {"image": img_inputs, "response_format": "b64_json"}}, ensure_ascii=False))
    raw = R.gen_payload(pf)
    if raw:
        open(rawp, "wb").write(raw)
    return raw


def _flood_bg(cand):
    """连通背景判定：缩 4x BFS（纯 numpy/PIL，无 scipy）→ 放大回原尺寸。

    cand=背景候选（近白/中性浅灰影）。只认与图外连通的候选为 bg——
    机身内部亮区与背景隔着轮廓暗边，BFS 进不去，不会被打穿。
    """
    from collections import deque
    h, w = cand.shape
    s = 4
    hs, ws = (h + s - 1) // s, (w + s - 1) // s
    small = cand[:hs * s, :ws * s].reshape(hs, s, ws, s).any(axis=(1, 3))
    bg_s = np.zeros_like(small, dtype=bool)
    q = deque()
    for x in range(ws):
        for y in (0, hs - 1):
            if small[y, x] and not bg_s[y, x]:
                bg_s[y, x] = True; q.append((y, x))
    for y in range(hs):
        for x in (0, ws - 1):
            if small[y, x] and not bg_s[y, x]:
                bg_s[y, x] = True; q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            yy, xx = y + dy, x + dx
            if 0 <= yy < hs and 0 <= xx < ws and small[yy, xx] and not bg_s[yy, xx]:
                bg_s[yy, xx] = True; q.append((yy, xx))
    big = np.kron(bg_s, np.ones((s, s), dtype=bool))[:h, :w]
    return big


def matte_centered(raw_bytes, flip_if_needed=True):
    """单帧白底图抠底 v2：连通背景 flood + 边缘 defringe 去白雾。

    v1 全局色键 alpha=(235-mn)*255//40 两大病（fut_nano_drone raise 实测 3296 半透 px）：
      ① 机身亮灰高光 mn≈200-235 被判半透明 → 内部打穿
      ② 半透明边缘像素保留白底混合 RGB → 深底上白雾边
    v2：bg=flood 连通背景（内部亮区不打穿）；bg 全透明；bg 外缘 1-2px 环走
    色键渐变+反 premultiply 还原真实色；其余一律实心。
    """
    if not raw_bytes:
        return None
    import io
    im = Image.open(io.BytesIO(raw_bytes)).convert("RGB")
    a = np.asarray(im).astype(np.int16)
    mn = a.min(axis=2)
    mx = a.max(axis=2)
    cand = (mn > 200) & ((mx - mn) < 26)          # 近白 + 中性浅灰影（主体蓝灰有色彩差）
    bg = _flood_bg(cand)
    alpha = np.where(bg, 0, 255).astype(np.int16)
    # bg 外缘 2px 环：色键渐变做软过渡（AA 环在此处理，内部不受影响）
    from PIL import ImageFilter
    bgi = Image.fromarray((bg * 255).astype(np.uint8), "L")
    ring = np.asarray(bgi.filter(ImageFilter.MaxFilter(5))).astype(np.int16) > 0
    band = ring & ~bg
    ab = np.clip((235 - mn) * 255 // 40, 0, 255)
    alpha[band] = ab[band]
    # defringe：半透明像素按 alpha 反 premultiply（白底混合 → 真实色）
    af = alpha.astype(np.float32) / 255.0
    semi = (alpha > 0) & (alpha < 255)
    for c in range(3):
        ch = a[:, :, c].astype(np.float32)
        a[:, :, c] = np.where(semi, np.clip((ch - (1 - af) * 255) / np.maximum(af, 1e-3), 0, 255), ch)
    out = np.dstack([a.astype(np.uint8), alpha.astype(np.uint8)])
    m = Image.fromarray(out, "RGBA")
    ys, xs = np.where(alpha > 30)
    if len(ys) < 200:
        return None
    m = m.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    if flip_if_needed:
        # 朝向判定 v2：优先火光侧（炮口方向），质心只做无焰兜底。
        # 旧"质心偏右=朝右"对炮向左/球体质量在右的单位误翻（fut_nano_drone raise 实测）。
        hsv = np.asarray(im.convert("HSV")).astype(np.int16)
        fl = (hsv[:, :, 0] >= 5) & (hsv[:, :, 0] <= 58) & (hsv[:, :, 1] > 70) & (hsv[:, :, 2] > 120)
        fys, fxs = np.where(fl)
        flip = False
        if len(fxs) >= 50:
            body_x = float(np.median(xs))  # alpha>30 主体（含焰，焰占比小不偏_median）
            flip = float(np.median(fxs)) > body_x  # 焰在主体右侧 → 生成朝右 → 翻转朝左
        else:
            cx = float(xs.mean()) - im.width / 2.0
            flip = cx > im.width * 0.04
        if flip:
            m = m.transpose(Image.FLIP_LEFT_RIGHT)
    return m


def anchor_to_512(m):
    """matte 主体贴 512 白底（居中、底部留边）——作为下一级生成的 Image1。"""
    t = m.copy()
    s = min(460.0 / max(1, t.height), 460.0 / max(1, t.width))
    t = t.resize((max(1, int(t.width * s)), max(1, int(t.height * s))), Image.LANCZOS)
    base = Image.new("RGBA", (512, 512), (255, 255, 255, 255))
    base.alpha_composite(t, ((512 - t.width) // 2, 512 - t.height - 24))
    return base


def align_to_f0(m, f0):
    """生成帧主体对齐 f0 锚：同内容高上限/同脚底/同质心 x。返回 256 帧。"""
    a = np.asarray(f0)
    ys, xs = np.where(a[:, :, 3] > 8)
    TH = int(ys.max() - ys.min() + 1)
    BASE = int(ys.max())
    fh = P.body_hull(f0)
    s2 = min(TH / float(m.height), 248.0 / max(1, m.width))
    nw, nh = max(1, int(round(m.width * s2))), max(1, int(round(m.height * s2)))
    bd = m.resize((nw, nh), Image.LANCZOS)
    tmp = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    tmp.alpha_composite(bd, (FS // 2 - nw // 2, BASE - nh))
    gh = P.body_hull(tmp)
    if fh is not None and gh is not None:
        dx = int(round(fh[0] - gh[0]))
        dx = min(max(dx, -(FS - nw) // 2), (FS - nw) // 2)
        if dx:
            tmp = tmp.transform((FS, FS), Image.AFFINE, (1, 0, -dx, 0, 1, 0))
    return tmp


def shift(fr, dx, dy):
    if dx == 0 and dy == 0:
        return fr
    return fr.transform((FS, FS), Image.AFFINE, (1, 0, -dx, 0, 1, -dy))


def _largest_blob(mask):
    """最大连通域像素坐标列表（8 邻接 BFS）。"""
    from collections import deque
    lab = np.zeros(mask.shape, dtype=np.int32)
    best, best_n, cur = None, 0, 0
    for y0, x0 in zip(*np.where(mask)):
        if lab[y0, x0]:
            continue
        cur += 1
        q = deque([(y0, x0)])
        lab[y0, x0] = cur
        pts = []
        while q:
            y, x = q.popleft()
            pts.append((y, x))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < mask.shape[0] and 0 <= xx < mask.shape[1] \
                            and mask[yy, xx] and not lab[yy, xx]:
                        lab[yy, xx] = cur
                        q.append((yy, xx))
        if len(pts) > best_n:
            best_n, best = len(pts), pts
    return best or []


def extract_flash(fire_al, scale=2.3):
    """从生成的开火帧抠火光贴片：炮口侧橙黄色域最大连通块 + 软边 + 放大。

    生成图火光画得小（prompt small flash），放大 scale 倍到游戏可视尺寸。
    """
    a = np.asarray(fire_al).astype(np.int16)
    hsv = np.asarray(fire_al.convert("HSV")).astype(np.int16)
    mask = (hsv[:, :, 0] >= 5) & (hsv[:, :, 0] <= 58) & (hsv[:, :, 1] > 70) & (hsv[:, :, 2] > 120)
    pts = _largest_blob(mask)
    if len(pts) < 25:
        return None
    ys_ = np.array([p[0] for p in pts]); xs_ = np.array([p[1] for p in pts])
    if a[ys_, xs_, :3].mean() < 150:
        return None  # 平均亮度低=机体橙色涂装不是火光
    # 补白热核心：焰 bbox 扩 8px 内的低饱和高亮像素（否则焰心被滤成暗环）
    bx0, bx1 = int(xs_.min()) - 8, int(xs_.max()) + 9
    by0, by1 = int(ys_.min()) - 8, int(ys_.max()) + 9
    hot = (hsv[:, :, 2] > 185) & (hsv[:, :, 1] <= 90)
    hot[:max(by0, 0), :] = False; hot[by1:, :] = False
    hot[:, :max(bx0, 0)] = False; hot[:, bx1:] = False
    mask = mask | hot
    ys = np.array([p[0] for p in pts]); xs = np.array([p[1] for p in pts])
    x0, x1 = min(int(xs.min()), bx0 + 8), max(int(xs.max()) + 1, bx1 - 8)
    y0, y1 = min(int(ys.min()), by0 + 8), max(int(ys.max()) + 1, by1 - 8)
    bmask = np.zeros(mask.shape, dtype=np.uint8)
    bmask[mask] = 255
    alpha = Image.fromarray(bmask, "L").filter(__import__("PIL.ImageFilter", fromlist=["GaussianBlur"]).GaussianBlur(0.8))
    rgb = a[:, :, :3].astype(np.uint8)
    flash = Image.fromarray(np.dstack([rgb, np.asarray(alpha)]), "RGBA").crop((x0, y0, x1, y1))
    if scale != 1.0:
        flash = flash.resize((max(1, int(flash.width * scale)), max(1, int(flash.height * scale))), Image.LANCZOS)
    return flash


# 炮口人工标定表（自动定位会被机翼/天线/起落架干扰，fut_nano_drone 实测）：
# 批量时每单位出标定图目测一次，填这里
MUZZLE_OVERRIDE = {
    "fut_nano_drone": (4, 149),  # 2026-09-30 重标：候选卡图炮管切线 x=300 后新 f0 炮口
}


def muzzle_pos(f0):
    """f0 炮口位置：标定表优先；否则最左端不透明像素带 y 质心（兜底）。"""
    if KEY in MUZZLE_OVERRIDE:
        return MUZZLE_OVERRIDE[KEY]
    a = np.asarray(f0)
    ys, xs = np.where(a[:, :, 3] > 8)
    x0 = int(xs.min())
    band = ys[xs <= x0 + 3]
    return x0, int(band.mean())


def overlay(base, patch, cx, cy):
    """火光贴片合成（支持负坐标，焰心 35% 越过炮口向前、65% 盖炮管尖）。numpy 手动 alpha。"""
    out = base.copy()
    a = np.asarray(out).astype(np.uint8).copy()
    p = np.asarray(patch.convert("RGBA"))
    px, py = int(cx - p.shape[1] * 0.35), int(cy - p.shape[0] / 2)
    h, w = p.shape[:2]
    x0, y0 = max(px, 0), max(py, 0)
    x1, y1 = min(px + w, FS), min(py + h, FS)
    if x1 <= x0 or y1 <= y0:
        return out
    ps = p[y0 - py:y1 - py, x0 - px:x1 - px].astype(np.float32)
    region = a[y0:y1, x0:x1].astype(np.float32)
    alpha = ps[:, :, 3:4] / 255.0
    a[y0:y1, x0:x1, :3] = np.clip(ps[:, :, :3] * alpha + region[:, :, :3] * (1 - alpha), 0, 255)
    a[y0:y1, x0:x1, 3] = np.maximum(region[:, :, 3], (alpha[:, :, 0] * 255).astype(np.uint8))
    return Image.fromarray(a, "RGBA")


def prog_flash(S=110, seed=7):
    """程序枪口焰：白黄核心 + 8 针星芒 + 橙辉光（additive 观感）。"""
    import math
    import random
    rnd = random.Random(seed)
    yy, xx = np.mgrid[0:S, 0:S]
    cx = cy = (S - 1) / 2.0
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    r = d / (S / 2.0)
    a = np.zeros((S, S), dtype=np.float32)
    a += np.exp(-(d / (S * 0.16)) ** 2) * 1.0          # 核心辉光
    for k in range(8):                                   # 星芒针
        ang = math.radians(k * 45 + rnd.uniform(-8, 8))
        L = (S * (0.46 if k % 2 == 0 else 0.30)) * rnd.uniform(0.85, 1.1)
        w = S * (0.035 if k % 2 == 0 else 0.025)
        ux, uy = math.cos(ang), math.sin(ang)
        t = (xx - cx) * ux + (yy - cy) * uy
        s = -(xx - cx) * uy + (yy - cy) * ux
        m = (t > 0) & (t < L) & (np.abs(s) < w * (1 - t / max(L, 1)))
        a += m * (1.0 - t / max(L, 1)) * 0.9
    a = np.clip(a, 0, 1)
    core = np.exp(-(d / (S * 0.055)) ** 2)               # 白热核心
    rgb = np.zeros((S, S, 3), dtype=np.float32)
    for i, (cf, ff) in enumerate([(255, 255), (235, 190), (170, 70)]):  # 核心 RGB / 焰 RGB
        rgb[:, :, i] = np.where(core > 0.45, cf, ff)
    alpha = (a * 255).astype(np.uint8)
    out = np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), alpha])
    return Image.fromarray(out, "RGBA")


def build_sheets(f0, fire_al):
    """程序序列：idle8 纯浮动；attack12 = f0 本体 + 火光（生成抠取优先，程序焰兜底）→ 回文。

    主体像素全部来自 f0（卡图本体）——身份零漂移是硬保证。
    """
    idle_srcs = [f0, shift(f0, 0, -1), shift(f0, 0, -2), shift(f0, 0, -1),
                 f0, shift(f0, 0, 1), shift(f0, 0, 2), shift(f0, 0, 1)]
    fl = extract_flash(fire_al) or prog_flash()
    mx, my = muzzle_pos(f0)
    s_fire = overlay(f0, fl, mx + 2, my)
    fl_half = fl.point(lambda v: int(v * 0.55))
    s_decay = overlay(f0, fl_half, mx + 1, my)
    atk_srcs = [f0, f0, s_fire, shift(s_decay, 2, 1), shift(f0, 1, 0), f0]
    order = [0, 1, 2, 3, 4, 5, 5, 4, 3, 2, 1, 0]
    atk_frames = [atk_srcs[i] for i in order]
    for name, frames in (("idle", idle_srcs), ("attack", atk_frames)):
        sheet = Image.new("RGBA", (FS * len(frames), FS), (0, 0, 0, 0))
        for i, fr in enumerate(frames):
            sheet.alpha_composite(fr, (i * FS, 0))
        sheet.save(os.path.join(OUT, "sheet_%s.png" % name))
    return len(idle_srcs), len(atk_frames)


def review_grid():
    """对比图：卡图 | 锚 | 开火帧 | idle8 | attack12（128px）。"""
    H = 128
    card = Image.open(os.path.join(ROOT, "assets", "card_icons", REL)).convert("RGBA")
    card.thumbnail((H, H), Image.LANCZOS)
    pieces = [("卡图", card)]
    for name in ("anchor", "fire"):
        p = os.path.join(OUT, "%s_al.png" % name)
        if os.path.exists(p):
            im = Image.open(p).convert("RGBA")
            im.thumbnail((H, H), Image.LANCZOS)
            pieces.append((name, im))
    for name, n in (("idle", 8), ("attack", 12)):
        p = os.path.join(OUT, "sheet_%s.png" % name)
        if os.path.exists(p):
            im = Image.open(p).convert("RGBA")
            im = im.resize((FS * n * H // FS, H), Image.LANCZOS)
            pieces.append(("%s x%d" % (name, n), im))
    W = sum(p.width + 12 for _, p in pieces) + 20
    img = Image.new("RGB", (W, H + 26), (24, 26, 32))
    d = ImageDraw.Draw(img)
    x = 8
    for label, p in pieces:
        img.paste(p, (x, 18), p)
        d.text((x, 3), label, fill=(255, 210, 120))
        x += p.width + 12
    img.save(os.path.join(OUT, "_review.png"))
    print("对比图:", os.path.join(OUT, "_review.png"))


def main():
    do_gen = "--review" not in sys.argv
    f0, ref = R.load_card(REL)
    # player 卡图一律镜像的规则对本单位翻反（其卡图本来朝左）——再翻回抵消
    if REL.startswith("player/") and KEY in ("fut_nano_drone",):
        f0 = f0.transpose(Image.FLIP_LEFT_RIGHT)
        ref = ref.transpose(Image.FLIP_LEFT_RIGHT)
    f0.save(os.path.join(OUT, "f0.png"))
    report = {}
    if do_gen:
        # 1 锚
        raw = gen_single("anchor", ANCHOR_PROMPT, [uri(ref)])
        am = matte_centered(raw)
        if am is None:
            print("锚生成失败"); return
        anchor512 = anchor_to_512(am)
        anchor512.convert("RGB").save(os.path.join(OUT, "anchor_al.png"))
        # 2 开火帧（从卡图 ref 直派——劣化锚锚定力不足会跑身份，fut_nano_drone 实测）
        raw2 = gen_single("fire", FIRE_PROMPT, [uri(ref)])
        fm = matte_centered(raw2)
        if fm is None:
            print("开火帧生成失败"); return
        fm.save(os.path.join(OUT, "fire_matte.png"))
        report["gen"] = "anchor+fire"
    else:
        am = Image.open(os.path.join(OUT, "anchor_al.png")).convert("RGB")
        am = None  # review 模式不再用锚
        fm = matte_centered(open(os.path.join(OUT, "fire_raw.png"), "rb").read())
    fire_al = align_to_f0(fm, f0)
    fire_al.save(os.path.join(OUT, "fire_al.png"))
    ni, na = build_sheets(f0, fire_al)
    print("idle %d 帧 / attack %d 帧（零额外生成）" % (ni, na))
    review_grid()
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
