# -*- coding: utf-8 -*-
"""余烬要塞 · 整体大背景图生成器
产出 assets/bunker/bunker_bg.png（1280×720，全不透明）：
  深空底 + 星云/星空 + 地球弧 + HUD 底条 + 地表带渐变 +
  6 行 14 房间（可用=暖亮墙+全彩家具；锁定=深色剪影）+ 电梯井。
运行时 bunker_main 只需一个 TextureRect 铺底，家具即背景小图标。

v6 精致度批次（2026-08-26，识图评审 7.9 分短板修复）：
  1. 墙面斑驳——砖缝隔行错位 + 水渍/锈迹柔化斑块 + 地板溅渍
  2. 辉光扩散——状态灯/电梯井/顶灯点光源全部加径向柔光（alpha_composite）
  3. 星空分层——两团星云底 + 亮星微晕
"""
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter
import random, math, os

random.seed(20260826)

W, H = 1280, 720
ROW_Y = [80, 184, 288, 392, 496, 600]
COL_X = [40, 445, 850]
ROOM_W, ROOM_H = 390, 88
WIDE_W = 420
ELEV_X = 640
HUD_H = 44

ACTIVE = {"entry_hall", "dormitory", "monument"}
FURN = {
    "weather_station": "fur_antenna", "depot": "fur_depot", "monument": "fur_monument",
    "dormitory": "fur_bed", "medical": "fur_medbay", "mess_hall": "fur_table",
    "war_room": "fur_wartable", "workshop": "fur_workbench", "archive": "fur_archive",
    "comms": "fur_comms", "reactor": "fur_reactor", "honor_hall": "fur_memorial",
    "observatory": "fur_observatory",
}
ROOMS = [
    ("weather_station", 0, 0), ("depot", 0, 1), ("monument", 0, 2),
    ("entry_hall", 1, -1),
    ("dormitory", 2, 0), ("mess_hall", 2, 1), ("medical", 2, 2),
    ("war_room", 3, 0), ("workshop", 3, 1), ("archive", 3, 2),
    ("comms", 4, 0), ("reactor", 4, 1), ("honor_hall", 4, 2),
    ("observatory", 5, -1),
]

img = Image.new("RGBA", (W, H), (10, 15, 30, 255))
d = ImageDraw.Draw(img)

# ── HUD 底条（y=0..44，纯色+底边青线；文字留给运行时节点） ──
d.rectangle([0, 0, W, HUD_H], fill=(6, 8, 14, 255))
d.line([0, HUD_H - 1, W, HUD_H - 1], fill=(0, 240, 255, 90), width=1)

# ── 地表带（y=44..80：HUD 到 Row0 之间的过渡渐变） ──────────
for y in range(HUD_H, 80):
    t = (y - HUD_H) / 36.0
    d.line([0, y, W, y], fill=(int(8 + 14 * t), int(12 + 22 * t), int(22 + 26 * t), 255))

# ── 天空带（y=46..78，可见区！旧版画在 y≤38 被 HUD 底条盖死） ──
# 星云：两团柔和大渐变
neb = Image.new("RGBA", (W, 40), (0, 0, 0, 0))
nd = ImageDraw.Draw(neb)
for nx, ny, nr, col in ((250, 22, 95, (36, 56, 118, 34)), (940, 14, 72, (92, 52, 128, 24)),
                        (620, 28, 115, (28, 48, 96, 18))):
    nd.ellipse([nx - nr, ny - nr // 2, nx + nr, ny + nr // 2], fill=col)
neb = neb.filter(ImageFilter.GaussianBlur(14))
img.alpha_composite(neb, (0, 44))

rng = random.Random(99)
for _ in range(56):
    x = rng.randint(4, W - 5)
    y = rng.randint(50, 76)
    if 1080 < x < 1230:
        continue  # 让开地球弧区
    r = rng.choice([1, 1, 2])
    a = rng.randint(90, 230)
    if r >= 2 and a > 175:
        # 亮星：微光晕 + 十字辉光
        halo = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
        ImageDraw.Draw(halo).ellipse([2, 2, 10, 10], fill=(200, 220, 255, 42))
        halo = halo.filter(ImageFilter.GaussianBlur(1.6))
        img.alpha_composite(halo, (x - 6, y - 6))
        d.line([(x - 4, y), (x + 4, y)], fill=(205, 225, 255, 70), width=1)
        d.line([(x, y - 4), (x, y + 4)], fill=(205, 225, 255, 70), width=1)
    d.ellipse([x - r, y - r, x + r, y + r], fill=(205, 225, 255, a))

# 地球弧：地平线上升起的行星（大圆心在带下方，只露顶部弧；
# 下半部分被 Row0 房间自然盖住，无遮挡泄漏）
ex, ey = 1150, 96
for rad, col in ((52, (77, 140, 217, 60)), (44, (64, 115, 191, 215)),
                 (36, (110, 165, 225, 235)), (27, (150, 195, 240, 225))):
    d.ellipse([ex - rad, ey - rad, ex + rad, ey + rad], fill=col)

def noise_rect(x0, y0, w, h, br, bg_, bb, var):
    px = img.load()
    for yy in range(y0, y0 + h):
        for xx in range(x0, x0 + w):
            n = random.randint(-var, var)
            px[xx, yy] = (max(0, br + n), max(0, bg_ + n), max(0, bb + n), 255)

def radial_glow_overlay(size, color, rings):
    """柔光贴片：同心 alpha 圆 + 高斯模糊，供点光源辉光复用。
    rings = [(半径比例, alpha), ...] 从外到内递增。"""
    ov = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    c = size // 2
    for frac, aa in rings:
        rr = int(size * frac)
        od.ellipse([c - rr, c - rr, c + rr, c + rr], fill=(color[0], color[1], color[2], aa))
    return ov.filter(ImageFilter.GaussianBlur(max(1.0, size / 14.0)))

def draw_room_frame(x, y, w, h, active, deep):
    """墙 + 地板 + 边框（可用=暖亮，锁定=深剪影）"""
    if active:
        br, bg_, bb, var = (108, 95, 74, 10)          # 暖混凝土
        if deep: br, bg_, bb = (92, 86, 78)
    elif deep:
        br, bg_, bb, var = (34, 33, 40, 6)            # 深层锁定：蓝黑
    else:
        br, bg_, bb, var = (40, 36, 32, 6)            # 上层锁定：棕黑
    noise_rect(x, y, w, h, br, bg_, bb, var)
    # 砖缝：横缝通长 + 竖缝隔行错位（砖砌感）
    line_dark = 26 if active else 8
    joint = (max(0, br - line_dark), max(0, bg_ - line_dark), max(0, bb - line_dark), 255)
    course = 0
    for yy in range(y, y + h, 11):
        d.line([x, yy, x + w, yy], fill=joint, width=1)
        off = 0 if course % 2 == 0 else 19
        for xx in range(x + off, x + w, 39):
            y2 = min(yy + 10, y + h - 1)
            if y2 > yy:
                d.line([(xx, yy + 1), (xx, y2)], fill=joint, width=1)
        course += 1
    # 地板条（底部 6px）
    fbr, fbg, fbb = ((58, 50, 40) if active else (26, 24, 22))
    noise_rect(x, y + h - 6, w, 6, fbr, fbg, fbb, 6)
    # 边框
    border = (184, 140, 92, 235) if active else (66, 60, 52, 200)
    d.rectangle([x, y, x + w - 1, y + h - 1], outline=border, width=2)
    # 墙面斑驳：水渍/锈迹柔化斑块 + 地板溅渍（可用房=暖锈色调，锁定房=冷暗渍）
    stain = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(stain)
    srng = random.Random((x * 31 + y * 17) & 0xFFFF)
    for _ in range(srng.randint(3, 5)):
        cx, cy = srng.randint(8, w - 9), srng.randint(6, h - 12)
        rw, rh = srng.randint(8, 26), srng.randint(5, 13)
        if active and srng.random() < 0.4:
            col = (152, 126, 92, srng.randint(12, 24))     # 干燥浅渍（提亮）
        elif active:
            col = (44, 34, 22, srng.randint(24, 42))       # 水渍（压暗）
        else:
            col = (10, 12, 18, srng.randint(20, 38))
        sd.ellipse([cx - rw, cy - rh, cx + rw, cy + rh], fill=col)
    for _ in range(2):
        bx = srng.randint(4, w - 24)
        bw = srng.randint(8, 20)
        scol = (40, 30, 20, srng.randint(20, 36)) if active else (8, 10, 14, srng.randint(18, 30))
        sd.rectangle([bx, h - 15 - srng.randint(0, 5), bx + bw, h - 7], fill=scol)
    img.alpha_composite(stain.filter(ImageFilter.GaussianBlur(2.2)), (x, y))

def paste_furniture(room_id, x, y, w, h, active):
    """家具贴图按比例放入房间下半区（y=30%..96%），锁定房压暗（亮度45%——保留断电剪影感但家具可辨）"""
    name = FURN.get(room_id)
    if not name:
        return
    path = os.path.join("assets/bunker", name + ".png")
    if not os.path.exists(path):
        return
    fur = Image.open(path).convert("RGBA")
    area_w = int(w * 0.86)
    area_h = int(h * 0.62)
    scale = min(area_w / fur.width, area_h / fur.height)
    fur = fur.resize((max(1, int(fur.width * scale)), max(1, int(fur.height * scale))), Image.LANCZOS)
    if not active:
        fur = ImageEnhance.Brightness(fur).enhance(0.45)
        fur = ImageEnhance.Color(fur).enhance(0.45)
        # 断电剪影保边：压暗拉灰后轮廓易糊，对比度回拉 + 轻锐化让形状可辨
        fur = ImageEnhance.Contrast(fur).enhance(1.35)
        fur = fur.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
    fx = x + (w - fur.width) // 2
    fy = y + int(h * 0.94) - fur.height               # 落地摆放
    img.alpha_composite(fur, (fx, fy))

def warm_glow(x, y, w, h):
    """可用房顶部暖光（叠加提亮，不透明合成）"""
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for yy in range(h):
        a = int(70 * (1 - yy / h * 0.9))
        gd.line([0, yy, w, yy], fill=(255, 214, 150, a))
    img.alpha_composite(glow, (x, y))

def ceiling_lamp(cx, cy, warm=True):
    """顶灯点光源：亮核 + 径向柔光（可用房暖白 / 锁定房冷灰）"""
    col = (255, 230, 185) if warm else (150, 160, 175)
    halo = radial_glow_overlay(26, col, ((0.46, 52), (0.30, 78), (0.16, 110)) if warm
                               else ((0.40, 22), (0.24, 34)))
    img.alpha_composite(halo, (cx - 13, cy - 13))
    d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=(col[0], col[1], col[2], 235))

# ── 房间主体 ────────────────────────────────────────────────
BASE = img.copy()   # 公共底（天空/HUD/地表带），两版本共用


def bake(active_set, out_name):
    """从公共底烘焙一版房间区（active_set=视为可用的房间集合）并保存。
    每版重置全局随机种子 → 同一房间在两版中像素一致（初始3亮房无跳变）。"""
    global img, d
    random.seed(20260826)
    img = BASE.copy()
    d = ImageDraw.Draw(img)

    for rid, row, col in ROOMS:
        x = (W - WIDE_W) // 2 if col < 0 else COL_X[col]
        w = WIDE_W if col < 0 else ROOM_W
        y = ROW_Y[row]; h = ROOM_H
        act = rid in active_set
        deep = row >= 4
        draw_room_frame(x, y, w, h, act, deep)
        if act:
            warm_glow(x + 2, y + 2, w - 4, h - 4)
        paste_furniture(rid, x, y, w, h, act)
        # 顶灯（可用房两盏暖白 / 锁定房一盏冷灰残灯）：位于房间名文字与右角标之间的空档
        if act:
            ceiling_lamp(x + int(w * 0.34), y + 5, True)
            ceiling_lamp(x + int(w * 0.64), y + 5, True)
        else:
            ceiling_lamp(x + int(w * 0.50), y + 5, False)
        # 状态灯（右上角内侧）+ 辉光扩散
        lamp_core = (0, 239, 255, 235) if act else (120, 110, 95, 160)
        lamp_col = (0, 239, 255) if act else (120, 110, 95)
        lx, ly = x + w - 12, y + 9
        lamp_halo = radial_glow_overlay(24, lamp_col,
            ((0.44, 40), (0.28, 66), (0.14, 96)) if act else ((0.36, 18), (0.20, 28)))
        img.alpha_composite(lamp_halo, (lx - 12, ly - 12))
        d.ellipse([lx - 3, ly - 3, lx + 3, ly + 3], fill=lamp_core)

    # ── 电梯井（Row1..Row5 中心，穿过入口大厅/观星台中缝间隙） ──
    top = ROW_Y[1] + ROOM_H // 2
    bot = ROW_Y[5] + ROOM_H // 2
    # 辉光预 pass：柔光晕染（外晕→内晕→核心，三层叠出体积感）
    shaft = Image.new("RGBA", (18, bot - top), (0, 0, 0, 0))
    shd = ImageDraw.Draw(shaft)
    for wdt, aa in ((7, 16), (4, 32)):
        shd.line([(9 - wdt // 2, 0), (9 + wdt // 2, 0)], fill=(0, 239, 255, aa), width=wdt)
    shaft = shaft.filter(ImageFilter.GaussianBlur(1.4))
    img.alpha_composite(shaft, (ELEV_X - 9, top))
    for yy in range(top, bot):
        a = 78
        d.line([(ELEV_X - 1, yy), (ELEV_X + 1, yy)], fill=(0, 239, 255, a))
        if yy % 3 == 0:
            d.point((ELEV_X - 5, yy), fill=(0, 239, 255, 48))
            d.point((ELEV_X + 5, yy), fill=(0, 239, 255, 48))
    for row in range(1, 6):
        cy = ROW_Y[row] + ROOM_H // 2
        # 楼层节点环：辉光底 + 加亮环 + 内核亮点，纵向动线在房间间隙也清晰可读
        img.alpha_composite(radial_glow_overlay(34, (0, 239, 255), ((0.42, 34), (0.26, 56))),
                            (ELEV_X - 17, cy - 17))
        d.ellipse([ELEV_X - 7, cy - 7, ELEV_X + 7, cy + 7], outline=(0, 239, 255, 200), width=2)
        d.ellipse([ELEV_X - 3, cy - 3, ELEV_X + 3, cy + 3], fill=(0, 239, 255, 110))

    out = os.path.join("assets/bunker", out_name)
    img.save(out)
    print("saved", out, img.size)


# 版本一：初始态（3 亮 11 暗）——运行时铺底图
bake(ACTIVE, "bunker_bg.png")
# 版本二：全亮态——运行时房间覆盖层按 region 取用（修复完成点亮）
bake({rid for rid, _, _ in ROOMS}, "bunker_bg_lit.png")

# 抽查
for label, x, y in [("dorm_wall", 235, 310), ("dorm_fur", 235, 360), ("lock_wall", 100, 100), ("hud", 640, 20)]:
    print(" ", label, img.getpixel((x, y)))
