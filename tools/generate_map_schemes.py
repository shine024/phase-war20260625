# -*- coding: utf-8 -*-
"""
generate_map_schemes.py —— 百灯群岛竞品方案布局示意图（10 方案各一张 + 3×3 对照表）
输出：docs/地图重设计/示意图/scheme_01..10.png + overview.png
用法：python tools/generate_map_schemes.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

OUT = r"docs/地图重设计/示意图"
W, H = 1240, 780

BG = (6, 8, 15)
INK = (210, 220, 235)
DIM = (130, 140, 160)
CYAN = (0, 229, 255)
AMBER = (255, 180, 94)
ERAS = [
    ("一战", (224, 162, 60)),
    ("二战", (126, 224, 106)),
    ("冷战", (106, 168, 255)),
    ("现代", (53, 216, 232)),
    ("近未来", (200, 107, 255)),
]

_font_cache = {}


def font(size, bold=False):
    key = (size, bold)
    if key not in _font_cache:
        cands = [
            "C:/Windows/Fonts/msyhbd.ttc" if bold else "C:/Windows/Fonts/msyh.ttc",
            "C:/Windows/Fonts/simhei.ttf",
            "C:/Windows/Fonts/simsun.ttc",
        ]
        for c in cands:
            if os.path.exists(c):
                _font_cache[key] = ImageFont.truetype(c, size)
                break
        else:
            _font_cache[key] = ImageFont.load_default()
    return _font_cache[key]


def new_canvas(title, sub):
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    d.text((60, 34), title, font=font(30, True), fill=INK)
    d.text((60, 76), sub, font=font(16), fill=DIM)
    d.line([(60, 108), (W - 60, 108)], fill=(40, 50, 70), width=1)
    return im, d


def legend(d, extra=""):
    x = 60
    for name, col in ERAS:
        d.rectangle([x, 742, x + 16, 758], fill=col)
        d.text((x + 22, 741), name, font=font(14), fill=DIM)
        x += 22 + d.textlength(name, font=font(14)) + 26
    if extra:
        d.text((W - 60 - d.textlength(extra, font=font(14)), 741), extra,
               font=font(14), fill=(90, 100, 120))


def dot(d, xy, col, r=5):
    x, y = xy
    d.ellipse([x - r, y - r, x + r, y + r], fill=col)


def base_mark(d, xy, label="家"):
    x, y = xy
    s = 11
    d.polygon([(x, y - s), (x + s, y), (x, y + s), (x - s, y)], fill=AMBER,
              outline=(255, 230, 180))
    d.text((x + 16, y - 10), label, font=font(15, True), fill=AMBER)


def gate_mark(d, xy, r=46, label="黑门", wide=False):
    x, y = xy
    if wide:  # 横置巨门（裂缝之井底部用）
        d.ellipse([x - r * 2, y - r * 0.45, x + r * 2, y + r * 0.45],
                  fill=(2, 2, 4), outline=CYAN, width=3)
    else:
        d.ellipse([x - r, y - r, x + r, y + r], fill=(2, 2, 4), outline=CYAN, width=3)
        for a in range(0, 360, 30):
            a1 = math.radians(a)
            d.line([(x + math.cos(a1) * (r + 6), y + math.sin(a1) * (r + 6)),
                    (x + math.cos(a1) * (r + 14), y + math.sin(a1) * (r + 14))],
                   fill=(0, 120, 140), width=2)
    d.text((x - r - 4, y + r + 10), label, font=font(15, True), fill=CYAN)


def arrow(d, frm, to, col=CYAN):
    d.line([frm, to], fill=col, width=3)
    ang = math.atan2(to[1] - frm[1], to[0] - frm[0])
    for da in (2.5, -2.5):
        d.line([to, (to[0] - 14 * math.cos(ang + da), to[1] - 14 * math.sin(ang + da))],
               fill=col, width=3)


def zone_label(d, xy, era_idx, extra=""):
    name, col = ERAS[era_idx]
    txt = name + extra
    d.text((xy[0] - d.textlength(txt, font=font(14)) / 2, xy[1]), txt,
           font=font(14), fill=col)


def ring_pts(cx, cy, r, n, phase=0.0, squish=1.0):
    return [(cx + math.cos(2 * math.pi * i / n + phase) * r,
             cy + math.sin(2 * math.pi * i / n + phase) * r * squish) for i in range(n)]


# ---------- 方案 1 壁垒玫瑰 ----------
def scheme1():
    im, d = new_canvas("方案 1 · 壁垒玫瑰「同心环防区」",
                       "基地居中心小行星城 · 每环 20 关一个时代 · 由内向外突围 · 黑门悬于最外圈天穹（黑色日蚀）")
    cx, cy = 560, 430
    for k in range(5):
        r = 92 + k * 62
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=ERAS[k][1] + (0,) if False else (*ERAS[k][1],), width=1)
    count = 0
    for k in range(5):
        r = 92 + k * 62
        pts = ring_pts(cx, cy, r, 20, phase=-math.pi / 2 + k * 0.3)
        for p in pts:
            dot(d, p, ERAS[k][1])
            count += 1
        zone_label(d, (cx + r * math.cos(math.radians(200)), cy + r * math.sin(math.radians(200))), k, f" {k * 20 + 1}-{k * 20 + 20}")
    base_mark(d, (cx, cy))
    gate_mark(d, (1080, 190), 72, "黑色日蚀")
    arrow(d, (cx + 20, cy - 20), (1000, 250))
    d.text((620, 300), "向外突围 ↗", font=font(16), fill=CYAN)
    assert count == 100
    legend(d)
    return im


# ---------- 方案 2 逆流之眼 ----------
def scheme2():
    im, d = new_canvas("方案 2 · 逆流之眼「螺旋星臂」",
                       "基地在旋臂尾端流浪小行星 · 沿旋臂逆流而上 · 黑门=星系核心被门框包裹的眼睛")
    cx, cy = 700, 430
    pts = []
    for i in range(100):
        t = i / 99.0
        ang = t * math.pi * 3.6 - math.pi * 0.1
        r = 340 - t * 270
        pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r * 0.86))
    d.line(pts, fill=(45, 55, 80), width=2)
    for i, p in enumerate(pts):
        dot(d, p, ERAS[i // 20][1], r=6)
    for k in range(5):
        zone_label(d, pts[k * 20 + 10], k)
    base_mark(d, pts[0], "流浪小行星")
    gate_mark(d, (cx, cy), 64, "核心之眼")
    arrow(d, pts[78], pts[88])
    d.text((860, 620), "沿旋臂推进 →", font=font(16), fill=CYAN)
    legend(d)
    return im


# ---------- 方案 3 泪之环带 ----------
def scheme3():
    im, d = new_canvas("方案 3 · 泪之环带「破碎星球」",
                       "基地在最大碎片上的漂浮城市废墟 · 100 关散布碎片环带 · 黑门悬于原行星核心位置")
    ccx, ccy, R = 660, 1100, 980  # 环带圆心在画面外下方
    pts = []
    for i in range(100):
        t = i / 99.0
        ang = math.radians(118 + t * 124)  # 上弧
        rr = R + math.sin(i * 2.7) * 46
        pts.append((ccx + math.cos(ang) * rr, ccy + math.sin(ang) * rr))
    for i, p in enumerate(pts):
        era = i // 20
        dot(d, p, ERAS[era][1], r=6)
        if i % 20 == 10:
            zone_label(d, (p[0], p[1] - 26), era)
    # 碎片多边形
    frags = [(150, 470, 80, 30), (420, 250, 55, -20), (700, 170, 45, 10),
             (950, 230, 60, -14), (1120, 430, 50, 24)]
    for fx, fy, fr, rot in frags:
        poly = [(fx + math.cos(math.radians(a + rot)) * fr * (1 + 0.3 * math.sin(a * 2.3)),
                 fy + math.sin(math.radians(a + rot)) * fr * 0.55) for a in range(0, 360, 36)]
        d.polygon(poly, fill=(30, 34, 44), outline=(80, 88, 104))
    base_mark(d, (150, 440), "漂浮城市废墟")
    gate_mark(d, (660, 560), 78, "原行星核心")
    arrow(d, (1030, 380), (760, 500))
    d.text((250, 620), "沿碎片环带清扫 →", font=font(16), fill=CYAN)
    legend(d)
    return im


# ---------- 方案 4 方舟走廊 ----------
def scheme4():
    im, d = new_canvas("方案 4 · 方舟走廊「巨舰坟场」",
                       "基地=玩家的小型星舰（会移动的家）· 100 关=100 艘时代舰队残骸 · 黑门在旗舰断裂舰艏")
    x0, y0 = 120, 240
    hull_w, hull_h = 176, 88
    for k in range(5):
        hx = x0 + k * (hull_w + 14)
        hy = y0 + (k % 2) * 46
        c = ERAS[k][1]
        d.rounded_rectangle([hx, hy, hx + hull_w, hy + hull_h], radius=26,
                            outline=c, width=2, fill=(16, 19, 28))
        d.polygon([(hx + hull_w, hy + hull_h * 0.5), (hx + hull_w + 26, hy + hull_h * 0.3),
                   (hx + hull_w + 26, hy + hull_h * 0.7)], fill=(16, 19, 28), outline=c)
        for j in range(20):
            dot(d, (hx + 18 + (j % 5) * 32, hy + 26 + (j // 5) * 18), c, r=5)
        d.text((hx + 10, hy - 24), f"{ERAS[k][0]}舰队 {k * 20 + 1}-{k * 20 + 20}",
               font=font(13), fill=c)
    bx = x0 - 84
    d.polygon([(bx, 300), (bx + 54, 282), (bx + 54, 318)], outline=AMBER, width=2)
    d.text((bx - 8, 326), "玩家星舰", font=font(14, True), fill=AMBER)
    gate_mark(d, (1130, 300), 60, "旗舰艏框门")
    arrow(d, (1010, 300), (1052, 300))
    d.text((430, 560), "逐舰跳帮推进 →（每推进一个时代，星舰前挪一站泊在新残骸旁）",
           font=font(16), fill=CYAN)
    legend(d)
    return im


# ---------- 方案 5 裂缝之井 ----------
def scheme5():
    im, d = new_canvas("方案 5 · 裂缝之井「垂直深渊」",
                       "基地悬在裂谷口的漂浮城市废墟 · 100 关沿谷壁之字下行 · 黑门横卧井底（竖版滚动）")
    # 谷壁
    for side in (0, 1):
        pts = []
        for yy in range(140, 700, 30):
            jitter = math.sin(yy * 0.05 + side * 2) * 22
            pts.append(((W / 2 - 250 + side * 500) + jitter, yy))
        d.line(pts, fill=(70, 76, 92), width=4)
    # 之字路径
    pts = []
    for i in range(100):
        seg, k = divmod(i, 20)
        t = k / 19.0
        y = 190 + seg * 96 + t * 84
        x = 420 + t * 400 if seg % 2 == 0 else 820 - t * 400
        pts.append((x, y))
    d.line(pts, fill=(45, 55, 80), width=2)
    for i, p in enumerate(pts):
        dot(d, p, ERAS[i // 20][1], r=5)
    for seg in range(5):
        zone_label(d, (300, 190 + seg * 96 + 40), seg, f" 层 {seg * 20 + 1}-{seg * 20 + 20}")
    base_mark(d, (620, 150), "漂浮城市废墟")
    gate_mark(d, (620, 690), 56, "井底巨门", wide=True)
    arrow(d, (700, 560), (700, 620))
    d.text((960, 430), "向下\n行军\n↓", font=font(20, True), fill=CYAN)
    legend(d)
    return im


# ---------- 方案 6 百灯群岛（当前实现） ----------
def scheme6():
    im, d = new_canvas("方案 6 · 百灯群岛「空间泡群」（当前已实现 v22.2）",
                       "灯塔要塞居中 · 5 星座泡群绕岛 · 100 泡缓慢漂向远处巨环 · 自由拓扑可分叉")
    cx, cy = 620, 440
    anchors = [(360, 260), (260, 560), (560, 700), (860, 640), (1000, 340)]
    radii = [(150, 90), (150, 90), (150, 90), (150, 90), (140, 90)]
    rnd = 7.0
    import random
    rng = random.Random(20260827)
    allpts = []
    for k in range(5):
        ax, ay = anchors[k]
        rx, ry = radii[k]
        pts = []
        while len(pts) < 20:
            a = rng.random() * math.pi * 2
            r = math.sqrt(rng.random())
            p = (ax + math.cos(a) * r * rx * 1.6, ay + math.sin(a) * r * ry * 1.6)
            if all((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 > 42 ** 2 for q in pts):
                pts.append(p)
        for p in pts:
            dot(d, p, ERAS[k][1], r=6)
            allpts.append(p)
        zone_label(d, (ax, ay - ry * 1.6 - 34), k)
    # 桥
    for k in range(4):
        d.line([allpts[k * 20 + 19], allpts[(k + 1) * 20]], fill=(40, 50, 72), width=1)
    base_mark(d, (cx, cy), "灯塔要塞")
    gate_mark(d, (1090, 200), 58, "远处巨环")
    arrow(d, (1020, 300), (1072, 258))
    d.text((700, 220), "全部泡缓慢漂向巨环", font=font(15), fill=CYAN)
    legend(d, "★ 当前实现")
    return im


# ---------- 方案 7 晨昏线远征 ----------
def scheme7():
    im, d = new_canvas("方案 7 · 晨昏线远征「潮汐锁定行星」",
                       "基地在晨昏带掩体城（唯一宜居带）· 从永昼走向永夜 · 黑日钉在夜半极点")
    # 昼→夜渐变
    for x in range(100, W - 100):
        t = (x - 100) / (W - 200)
        col = (int(90 - 80 * t), int(64 - 56 * t), int(30 - 24 * t))
        d.line([(x, 150), (x, 660)], fill=col)
    bands = 5
    for k in range(bands):
        y = 170 + k * 98
        for j in range(20):
            dot(d, (150 + j * 46 + (k % 2) * 10, y + 40), ERAS[k][1], r=6)
        d.text((126, y + 6), f"{ERAS[k][0]} {k * 20 + 1}-{k * 20 + 20}",
               font=font(13), fill=ERAS[k][1])
    base_mark(d, (120, 400), "晨昏带掩体城")
    gate_mark(d, (1120, 400), 66, "夜极黑日")
    arrow(d, (980, 400), (1040, 400))
    d.text((330, 130), "永昼 ☀", font=font(18, True), fill=(255, 200, 120))
    d.text((W - 160, 130), "永夜 ☾", font=font(18, True), fill=(150, 170, 210))
    d.text((480, 690), "向西向东推进 · 天光即进度条", font=font(16), fill=CYAN)
    legend(d)
    return im


# ---------- 方案 8 相位两仪 ----------
def scheme8():
    im, d = new_canvas("方案 8 · 相位两仪「沙漏双界」",
                       "上界现实 50 关下打到相位缝 · 下界镜像世界 50 关继续向下 · 黑门在下界底极（贴游戏名）")
    cx = 620
    # 上三角
    d.polygon([(cx, 190), (cx - 330, 160), (cx - 330, 460), (cx, 400)], outline=(90, 100, 130))
    d.polygon([(cx, 190), (cx + 330, 160), (cx + 330, 460), (cx, 400)], outline=(90, 100, 130))
    # 下镜像
    d.polygon([(cx, 560), (cx - 330, 700), (cx - 330, 590), (cx, 500)], outline=(60, 130, 150))
    d.polygon([(cx, 560), (cx + 330, 700), (cx + 330, 590), (cx, 500)], outline=(60, 130, 150))
    n = 0
    for k in range(5):  # 上界 5 行 × 10
        y = 210 + k * 46
        half = 250 - k * 30
        for j in range(10):
            dot(d, (cx - half + j * (2 * half / 9), y), ERAS[k][1], r=6)
            n += 1
    for k in range(5):  # 下界
        y = 530 + k * 36
        half = 60 + k * 56
        for j in range(10):
            dot(d, (cx - half + j * (2 * half / 9), y), ERAS[k][1], r=6)
            n += 1
    assert n == 100
    zone_label(d, (cx - 300, 180), 0, " 现实界 1-50")
    zone_label(d, (cx + 200, 680), 4, " 相位界 51-100")
    # 相位缝
    d.line([(cx - 120, 462), (cx + 120, 462)], fill=CYAN, width=4)
    d.text((cx - 44, 468), "相位缝（50→51 章节爆点）", font=font(14, True), fill=CYAN)
    base_mark(d, (cx - 290, 195), "漂浮岛掩体")
    gate_mark(d, (cx, 730), 40, "下界底极黑门", wide=True)
    arrow(d, (cx, 420), (cx, 455))
    legend(d)
    return im


# ---------- 方案 9 焚轨天梯 ----------
def scheme9():
    im, d = new_canvas("方案 9 · 焚轨天梯「环日轨道链」",
                       "基地在最外轨小行星站城 · 每层轨道 20 关绕一圈 · 推进=轨道半径收缩 · 黑星即门")
    cx, cy = 640, 430
    for k in range(5):
        rx = 400 - k * 74
        ry = rx * 0.46
        pts = ring_pts(cx, cy, rx, 20, phase=k * 0.5)
        pts = [(p[0], cy + (p[1] - cy) * 0.46) for p in pts]
        for p in pts:
            dot(d, p, ERAS[k][1], r=6)
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], outline=(50, 58, 78), width=1)
        d.text((cx + rx * 0.71 + 6, cy - ry * 0.71 - 20),
               f"{ERAS[k][0]}轨 {k * 20 + 1}-{k * 20 + 20}", font=font(13), fill=ERAS[k][1])
    base_mark(d, (cx, cy - 184), "外轨站城")
    gate_mark(d, (cx, cy), 52, "坍缩黑星")
    arrow(d, (cx + 240, cy - 110), (cx + 150, cy - 62))
    d.text((880, 640), "向内收缩 ↓", font=font(16), fill=CYAN)
    legend(d)
    return im


# ---------- 方案 10 末日前线 ----------
def scheme10():
    im, d = new_canvas("方案 10 · 末日前线「大陆战线」",
                       "基地在西侧山脉地下掩体 · 战线横贯大陆五区 · 黑色裂缝在大陆尽头海平线（手绘画风最同源）")
    # 大陆
    land = [(110, 240), (360, 190), (620, 210), (860, 180), (1120, 230),
            (1150, 480), (1000, 620), (700, 660), (400, 630), (140, 520)]
    d.polygon(land, fill=(24, 27, 36), outline=(96, 104, 122))
    # 山脉
    for mx, my in ((210, 330), (260, 300), (310, 335)):
        d.polygon([(mx, my), (mx + 26, my - 34), (mx + 52, my)], fill=(40, 45, 58))
    # 五区蛇形战线
    x0, x1, y0, dy = 260, 1010, 270, 84
    n = 0
    for k in range(5):
        y = y0 + k * dy
        for j in range(20):
            t = j / 19.0
            wave = math.sin(t * math.pi) * (26 if k % 2 else -26)
            dot(d, (x0 + t * (x1 - x0), y + wave + 16), ERAS[k][1], r=5.5)
            n += 1
        d.text((x0 - 10, y - 22), f"{ERAS[k][0]} {k * 20 + 1}-{k * 20 + 20}",
               font=font(13), fill=ERAS[k][1])
    assert n == 100
    base_mark(d, (240, 360), "山脉地下掩体")
    # 尽头裂缝
    gx = 1160
    crack = [(gx, 260), (gx + 14, 330), (gx - 8, 400), (gx + 12, 470), (gx - 4, 540)]
    d.line(crack, fill=CYAN, width=4)
    for cy2 in (300, 380, 460):
        d.line([(gx - 14, cy2), (gx + 18, cy2)], fill=(0, 120, 140), width=1)
    d.text((gx - 46, 560), "海平线黑缝", font=font(14, True), fill=CYAN)
    arrow(d, (1020, 300), (1120, 300))
    d.text((500, 700), "战线自西向东推进（西线堑壕→焚化区）", font=font(16), fill=CYAN)
    legend(d)
    return im



# ---------- 方案 11 晨昏大陆（7+10 杂交） ----------
def _lerp3(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def scheme11():
    im, d = new_canvas("方案 11 · 晨昏大陆「黑日战线」（7 光照 + 10 骨架）",
                       "大陆横跨晨昏线 · 天色即进度（每 20 关暗一档）· 黑日三幕：暗星→黑日→巨门")
    # 光照渐变长卷（穿过大陆剪影）
    warm, midc, dark = (150, 105, 60), (70, 78, 100), (10, 12, 20)
    grad = Image.new("RGB", (W, H), BG)
    gd = ImageDraw.Draw(grad)
    for x in range(90, W - 60):
        t = (x - 90) / (W - 150)
        c = _lerp3(warm, midc, t / 0.55) if t < 0.55 else _lerp3(midc, dark, (t - 0.55) / 0.45)
        gd.line([(x, 150), (x, 660)], fill=c)
    land = [(110, 240), (360, 190), (620, 210), (860, 180), (1120, 230),
            (1150, 480), (1000, 620), (700, 660), (400, 630), (140, 520)]
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(land, fill=255)
    im.paste(grad, (0, 0), mask)
    d.polygon(land, outline=(120, 130, 150), width=2)
    # 天光标签
    d.text((150, 122), "西 · 永昼（金黄）", font=font(14, True), fill=(255, 210, 140))
    d.text((560, 122), "中 · 晨昏（蓝灰）", font=font(14, True), fill=(170, 185, 215))
    d.text((980, 122), "东 · 极夜", font=font(14, True), fill=(150, 170, 210))
    # 山脉 + 基地
    for mx, my in ((210, 330), (260, 300), (310, 335)):
        d.polygon([(mx, my), (mx + 26, my - 34), (mx + 52, my)], fill=(46, 40, 34))
    base_mark(d, (240, 360), "山脉地下掩体（余烬要塞）")
    # 五区蛇形战线（同 10）
    x0, x1, y0, dy = 260, 1010, 270, 84
    n = 0
    for k in range(5):
        y = y0 + k * dy
        for j in range(20):
            t = j / 19.0
            wave = math.sin(t * math.pi) * (26 if k % 2 else -26)
            dot(d, (x0 + t * (x1 - x0), y + wave + 16), ERAS[k][1], r=5.5)
            n += 1
        d.text((x0 - 10, y - 22), f"{ERAS[k][0]} {k * 20 + 1}-{k * 20 + 20}",
               font=font(13), fill=ERAS[k][1])
    assert n == 100
    # 黑日三幕：随战线升高变大（同一颗，三个进度档位）
    suns = [(1085, 500, 7, "1-49 暗星"), (1115, 400, 20, "50-89 黑日"), (1148, 290, 42, "90-100 巨门")]
    arc = [(1085, 500), (1100, 450), (1115, 400), (1130, 345), (1148, 290)]
    for i in range(len(arc) - 1):
        d.line([arc[i], arc[i + 1]], fill=(0, 120, 140), width=1)
    for sx, sy, sr, lab in suns:
        d.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=(2, 2, 4), outline=CYAN, width=2)
        d.text((sx - 18, sy + sr + 6), lab, font=font(12), fill=CYAN)
    arrow(d, (1040, 300), (1100, 300))
    d.text((430, 690), "战线自西向东推进 · 天色随进度变暗 · 门在吞光", font=font(16), fill=CYAN)
    legend(d)
    return im

SCHEMES = [scheme1, scheme2, scheme3, scheme4, scheme5, scheme6, scheme7, scheme8, scheme9, scheme10, scheme11]


def main():
    os.makedirs(OUT, exist_ok=True)
    thumbs = []
    for i, fn in enumerate(SCHEMES, 1):
        im = fn()
        path = os.path.join(OUT, f"scheme_{i:02d}.png")
        im.save(path)
        thumbs.append((i, im))
        print(f"[ok] {path}")
    # 对照表 2 列动态行
    tw, th = 610, 390
    rows = (len(thumbs) + 1) // 2
    sheet = Image.new("RGB", (tw * 2 + 60, th * (rows + 1) // 2 + 130 + (rows - 2) * (th // 2 + 7)), BG)
    ds = ImageDraw.Draw(sheet)
    ds.text((60, 28), "百灯群岛 · 方案布局对照", font=font(30, True), fill=INK)
    for idx, (i, im) in enumerate(thumbs):
        row, col = divmod(idx, 2)
        x, y = 40 + col * (tw + 20), 90 + row * (th + 14)
        t = im.resize((tw - 60, int((tw - 60) * H / W)))
        sheet.paste(t, (x, y))
    sheet.save(os.path.join(OUT, "overview.png"))
    print(f"[ok] {os.path.join(OUT, 'overview.png')}")


if __name__ == "__main__":
    main()
