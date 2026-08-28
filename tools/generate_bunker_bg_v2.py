# -*- coding: utf-8 -*-
"""
generate_bunker_bg_v2.py —— 基地 v2 大底图烘焙（暗/亮双版本）
产出：assets/bunker/v2/bunker_bg_v2.png（初始 3 亮 11 暗）
      assets/bunker/v2/bunker_bg_v2_lit.png（全亮）
世界：1280x1560，地表废土层 + 地下五层，主竖井 x615-665
坐标与 docs/基地重设计/bunker_redesign_mockup.html 的 GRID 一致
（⚠️ 单源化 TODO：GRID 落地 data/bunker_room_defs.gd 后本脚本改为解析该文件）
用法：python tools/generate_bunker_bg_v2.py
"""
import os, random
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

SRC = r"assets/bunker/v2"
OUT_DARK = os.path.join(SRC, "bunker_bg_v2.png")
OUT_LIT = os.path.join(SRC, "bunker_bg_v2_lit.png")
W, H = 1280, 1560
SURF_Y0, SURF_Y1 = 258, 298
ROCK_Y = 300
SHAFT_X1, SHAFT_X2 = 615, 665
SHAFT_TOP, SHAFT_BOT = 420, 1360

# ---- GRID（与设计稿一致）----
ROOMS = [
    # id, x, y, w, h, side(L/R/C), tunnel_y, initial_lit
    ("weather_station",  60, 300, 240, 145, "L", 426, False),
    ("monument",        340, 450, 120, 100, "L", 500, True),
    ("entry_hall",      470, 290, 340, 130, "C", 360, True),
    ("observatory",     950, 380, 280, 110, "R", 435, False),
    ("dormitory",        60, 515, 270, 190, "L", 565, True),
    ("mess_hall",       365, 605, 225, 115, "L", 690, False),
    ("medical",         700, 520, 230, 160, "R", 580, False),
    ("depot",           960, 590, 270, 160, "R", 715, False),
    ("war_room",         60, 820, 290, 210, "L", 925, False),
    ("workshop",        690, 810, 270, 155, "R", 888, False),
    ("archive",        1000, 840, 230, 185, "R", 980, False),
    ("comms",            60,1120, 240, 160, "L",1200, False),
    ("honor_hall",      700,1130, 260, 160, "R",1210, False),
    ("reactor",         480,1360, 330, 160, "C",1440, False),
]
# 地表件：name, (x, y_bottom, max_w, max_h)
SURFACE_PROPS = [
    ("s_gatehouse",       549, 298, 196, 172),
    ("s_observatory_dome",945, 272, 312, 172),
    ("s_watchtower",      330, 290,  64, 114),
    ("s_tank_wreck",       55, 292, 100,  46),
    ("s_ruined_walls",    792, 290, 146,  76),
    ("s_power_pole",      426, 292,  24, 188),
    ("s_sandbags",        760, 296,  44,  22),
    ("s_weather_mast",     70, 296,  78,  62),   # QC：三脚架仪器，放气象站旁地面
    ("s_balloon",         212, 120,  50,  62),
]
CAV_PAD = 8          # 腔体相对房间的内缩
CAV_TOP = 20         # 顶部让出房名区

def load(name):
    return Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")

def vgrad(w, h, c_top, c_bot):
    g = Image.new("RGBA", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        g.putpixel((0, y), tuple(int(c_top[i] + (c_bot[i] - c_top[i]) * t) for i in range(3)) + (255,))
    return g.resize((w, h))

def rounded_mask(w, h, r):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius=r, fill=255)
    return m

def aspect_fill(img, w, h):
    """等比放大铺满 w×h，垂直贴底裁切（保地面线），水平居中。"""
    s = max(w / img.width, h / img.height)
    nw, nh = int(img.width * s + 0.5), int(img.height * s + 0.5)
    img = img.resize((nw, nh), Image.LANCZOS)
    x0 = (nw - w) // 2
    y0 = nh - h                      # 贴底
    return img.crop((x0, y0, x0 + w, y0 + h))

def fit_bottom(img, max_w, max_h):
    """等比缩放到 max 框内（不放大超过 1.6x），返回 (img, w, h)。"""
    s = min(max_w / img.width, max_h / img.height, 1.6)
    w, h = int(img.width * s + 0.5), int(img.height * s + 0.5)
    return img.resize((w, h), Image.LANCZOS), w, h

def build_base():
    canvas = Image.new("RGBA", (W, H), (5, 7, 12, 255))
    # 天空带：取缩放后底部 272px（保住残城剪影贴带底）
    sky = load("bg_sky")
    sky = sky.resize((1280, int(1280 * sky.height / sky.width)), Image.LANCZOS)
    band = sky.crop((0, sky.height - 272, 1280, sky.height))
    canvas.alpha_composite(band, (0, 0))
    # 岩层
    rock = load("bg_rock").resize((1280, H - ROCK_Y), Image.LANCZOS)
    canvas.alpha_composite(rock, (0, ROCK_Y))
    # 地表土带
    strip = vgrad(1280, SURF_Y1 - SURF_Y0, (46, 39, 30), (40, 34, 26))
    canvas.alpha_composite(strip, (0, SURF_Y0))
    d = ImageDraw.Draw(canvas, "RGBA")
    for _ in range(140):  # 碎石点
        x = random.randint(0, 1279); y = random.randint(SURF_Y0 + 4, SURF_Y1 - 3)
        v = random.randint(28, 52)
        d.point((x, y), fill=(v, v - 4, v - 9, 255))
    # 反应堆辉光（底部橙晕）
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy, r0, r1 = 645, 1435, 40, 330
    for r, a in [(r1, 18), (int(r1 * .75), 26), (int(r1 * .5), 36), (r0, 60)]:
        gd.ellipse([cx - r, cy - int(r * .62), cx + r, cy + int(r * .62)], fill=(255, 120, 46, a))
    glow = glow.filter(ImageFilter.GaussianBlur(26))
    canvas.alpha_composite(glow)
    # 岩缝透光
    for (fx, fy, ang, ln) in [(540, 1338, -24, 90), (742, 1348, 20, 80), (640, 1322, 4, 70)]:
        crack = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        cd = ImageDraw.Draw(crack)
        import math
        x2 = fx + int(ln * math.cos(math.radians(ang))); y2 = fy - int(ln * math.sin(math.radians(ang)))
        cd.line([fx, fy, x2, y2], fill=(255, 130, 50, 120), width=4)
        crack = crack.filter(ImageFilter.GaussianBlur(3))
        canvas.alpha_composite(crack)
    return canvas

def carve_tunnels_shaft(canvas):
    d = ImageDraw.Draw(canvas, "RGBA")
    # 竖井
    d.rectangle([SHAFT_X1, SHAFT_TOP, SHAFT_X2, SHAFT_BOT], fill=(5, 4, 3, 255))
    d.line([SHAFT_X1 + 6, SHAFT_TOP, SHAFT_X1 + 6, SHAFT_BOT], fill=(58, 50, 38, 255), width=3)
    d.line([SHAFT_X2 - 6, SHAFT_TOP, SHAFT_X2 - 6, SHAFT_BOT], fill=(58, 50, 38, 255), width=3)
    d.rectangle([SHAFT_X1, SHAFT_TOP, SHAFT_X2, SHAFT_BOT], outline=(28, 22, 15, 255), width=2)
    for (_, _, _, _, _, side, ty, _) in ROOMS:
        if side == "C": continue
        d.rectangle([SHAFT_X1 - 2, ty - 3, SHAFT_X1 + 8, ty + 2], fill=(74, 65, 50, 255))
        d.rectangle([SHAFT_X2 - 8, ty - 3, SHAFT_X2 + 2, ty + 2], fill=(74, 65, 50, 255))
    # 隧道
    for (rid, x, y, w, h, side, ty, _) in ROOMS:
        if side == "C": continue
        if side == "L": tx0, tx1 = x + w, SHAFT_X1
        else:           tx0, tx1 = SHAFT_X2, x
        if tx1 - tx0 < 8: continue
        d.rounded_rectangle([tx0, ty - 11, tx1, ty + 11], radius=8, fill=(7, 5, 3, 255))
        d.rounded_rectangle([tx0, ty - 11, tx1, ty + 11], radius=8, outline=(30, 24, 16, 255), width=2)

def paste_surface_props(canvas):
    for (name, x, ybot, mw, mh) in SURFACE_PROPS:
        img = load(name)
        img, w, h = fit_bottom(img, mw, mh)
        canvas.alpha_composite(img, (x, ybot - h))
    # 程序补一根细气象桅杆（生成图是三脚架仪器，桅杆由代码画：x168, 顶 y60）
    d = ImageDraw.Draw(canvas, "RGBA")
    d.line([170, 62, 170, 298], fill=(75, 70, 60, 255), width=4)
    d.line([148, 70, 192, 70], fill=(75, 70, 60, 255), width=3)
    for cx in (148, 192, 170):
        d.ellipse([cx - 5, 84, cx + 5, 94], outline=(92, 86, 74, 255), width=2)
    d.ellipse([166, 52, 174, 60], fill=(255, 90, 74, 255))
    # 气球系绳
    d.line([214, 118, 202, 92, 176, 74], fill=(75, 70, 60, 220), width=3)

def room_interior(rid, x, y, w, h, lit):
    """房间景箱：fur 图 aspect-fill + 圆角蒙版；未点亮则压暗去饱和。"""
    try:
        fur = load("fur_%s_v2" % rid)
    except FileNotFoundError:
        return None
    iw, ih = w - 2 * CAV_PAD, h - CAV_TOP - CAV_PAD
    inner = aspect_fill(fur, iw, ih)
    if not lit:
        inner = ImageEnhance.Brightness(inner).enhance(0.44)
        inner = ImageEnhance.Color(inner).enhance(0.5)
    inner.putalpha(rounded_mask(iw, ih, 34))
    return inner

def carve_rooms(canvas, all_lit):
    # 先挖腔（暗腔底 + 内阴影 + 地板线）
    cav = ImageDraw.Draw(canvas, "RGBA")
    for (rid, x, y, w, h, side, ty, init) in ROOMS:
        x0, y0 = x + CAV_PAD, y + CAV_TOP
        x1, y1 = x + w - CAV_PAD, y + h - CAV_PAD
        cav.rounded_rectangle([x0 - 2, y0 - 2, x1 + 2, y1 + 2], radius=40, fill=(14, 10, 7, 255))
        grad = vgrad(x1 - x0, y1 - y0, (36, 28, 18), (18, 13, 9))
        grad.putalpha(rounded_mask(x1 - x0, y1 - y0, 38))
        canvas.alpha_composite(grad, (x0, y0))
        cav.line([x0 + 14, y1 - 3, x1 - 14, y1 - 3], fill=(70, 57, 40, 200), width=3)
        cav.arc([x0 + 30, y0 - 26, x1 - 30, y0 + 40], start=200, end=340, fill=(96, 78, 52, 120), width=5)
    # 再贴景箱
    for (rid, x, y, w, h, side, ty, init) in ROOMS:
        lit = all_lit or init
        inner = room_interior(rid, x, y, w, h, lit)
        if inner is None: continue
        canvas.alpha_composite(inner, (x + CAV_PAD, y + CAV_TOP))
        if lit:  # 光池：卡墙仓库用青光（呼应卡槽点亮），其余暖光
            lw, lh = int(w * .84), int(h * .7)
            pool = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
            pd = ImageDraw.Draw(pool)
            pc = (120, 229, 255, 46) if rid == "depot" else (255, 170, 90, 44)
            pd.ellipse([lw*.08, lh*.06, lw*.92, lh*.9], fill=pc)
            pool = pool.filter(ImageFilter.GaussianBlur(22))
            canvas.alpha_composite(pool, (x + (w - lw)//2, y + int(h*.08)))
    # 隧道灯（点亮房暖光外溢）
    d = ImageDraw.Draw(canvas, "RGBA")
    for (rid, x, y, w, h, side, ty, init) in ROOMS:
        if side == "C" or not (all_lit or init): continue
        if side == "L":
            d.rounded_rectangle([x + w, ty - 9, SHAFT_X1, ty + 9], radius=8,
                                fill=(255, 170, 80, 26))
        else:
            d.rounded_rectangle([SHAFT_X2, ty - 9, x, ty + 9], radius=8,
                                fill=(255, 170, 80, 26))
    # 光柱：闸门暖光下行 / 观星缝冷光下行
    beams = [(604, 298, 92, 132, (255, 176, 92, 34)), (1089, 272, 24, 106, (160, 200, 255, 30))]
    for (bx, by, bw, bh, col) in beams:
        bm = vgrad(bw, bh, col, (col[0], col[1], col[2], 0))
        canvas.alpha_composite(bm, (bx, by))

def build(all_lit):
    random.seed(20260827)
    canvas = build_base()
    carve_tunnels_shaft(canvas)
    paste_surface_props(canvas)
    carve_rooms(canvas, all_lit)
    return canvas.convert("RGB")

if __name__ == "__main__":
    os.chdir(os.path.join(os.path.dirname(__file__), ".."))
    dark = build(False); dark.save(OUT_DARK)
    print("saved", OUT_DARK, dark.size)
    lit = build(True); lit.save(OUT_LIT)
    print("saved", OUT_LIT, lit.size)
