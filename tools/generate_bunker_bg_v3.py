# -*- coding: utf-8 -*-
"""
generate_bunker_bg_v3.py —— 基地 v3 大底图烘焙（胶囊 + 一体外壳，720 单屏）
输入：docs/基地重设计/generated3/{shell_full, cap_*}.jpeg
输出：assets/bunker/v3/bunker_bg_v3.png（初始 3 亮 11 涂黑）
      assets/bunker/v3/bunker_bg_v3_lit.png（全亮）
      assets/bunker/v3/cap_*.png（透明底胶囊，留档复用）
流程：shell_full 缩放到 1280x720 做底 → 按 GRID 画嵌套暗腔 → 胶囊 aspect-fit 嵌入
      （锁定=舱内涂黑）→ 隧道/竖井 → 反应堆辉光。
用法：python tools/generate_bunker_bg_v3.py
"""
import os, random
from collections import deque
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

SRC = r"docs/基地重设计/generated3"
DST = r"assets/bunker/v3"
W, H = 1280, 720
SHAFT_X1, SHAFT_X2 = 615, 665
SHAFT_TOP, SHAFT_BOT = 262, 638

ROOMS = [
    # id, x, y, w, h, side(L/R/C), tunnel_y, via, initial_lit
    # 上5下5 原生比例布局（232×130 == 胶囊 1.79，零裁剪）；中央房为竖井直通中枢
    ("weather_station",  60, 232, 210, 110, "L", None, "monument",  False),
    ("monument",        270, 255, 170,  90, "L", None, "entry_hall", True),
    ("entry_hall",      440, 192, 350, 150, "C", 280, None,         True),
    ("observatory",     950, 231, 290, 127, "R", 352, None,         False),
    ("dormitory",        30, 364, 232, 130, "L", 429, None,         True),
    ("mess_hall",       282, 364, 232, 130, "L", 429, None,         False),
    ("archive",         534, 364, 232, 130, "C", 429, None,         False),
    ("medical",         786, 364, 232, 130, "R", 429, None,         False),
    ("depot",          1038, 364, 232, 130, "R", 429, None,         False),
    ("war_room",         30, 508, 232, 130, "L", None, "dormitory",  False),
    ("workshop",        282, 508, 232, 130, "L", None, "mess_hall",  False),
    ("reactor",         534, 508, 232, 130, "C", 573, None,         False),
    ("honor_hall",      786, 508, 232, 130, "R", None, "medical",   False),
    ("comms",          1038, 508, 232, 130, "R", None, "depot",     False),
]
INIT_LIT = {"monument", "entry_hall", "dormitory"}

def flood_white_to_alpha(im, thresh=238):
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    dq = deque()
    def white(p): return p[0] >= thresh and p[1] >= thresh and p[2] >= thresh
    for x in range(w):
        for y in (0, h - 1):
            if white(px[x, y]): dq.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if white(px[x, y]): dq.append((x, y))
    while dq:
        x, y = dq.popleft()
        if x < 0 or x >= w or y < 0 or y >= h: continue
        i = y * w + x
        if seen[i]: continue
        p = px[x, y]
        if not (p[0] >= thresh and p[1] >= thresh and p[2] >= thresh): continue
        seen[i] = 1
        px[x, y] = (0, 0, 0, 0)
        dq.append((x + 1, y)); dq.append((x - 1, y)); dq.append((x, y + 1)); dq.append((x, y - 1))
    return im

def autocrop(im, pad=4):
    bbox = im.getchannel("A").getbbox()
    if not bbox: return im
    x0, y0, x1, y1 = bbox
    return im.crop((max(0, x0 - pad), max(0, y0 - pad),
                    min(im.width, x1 + pad), min(im.height, y1 + pad)))

def load_cap(rid):
    p = os.path.join(DST, "cap_%s.png" % rid)
    return Image.open(p).convert("RGBA")

def aspect_fit(img, w, h):
    s = min(w / img.width, h / img.height)
    nw, nh = int(img.width * s + 0.5), int(img.height * s + 0.5)
    return img.resize((nw, nh), Image.LANCZOS)

def rounded_mask(w, h, r):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius=r, fill=255)
    return m

def build_base():
    shell = Image.open(os.path.join(SRC, "shell_full.jpeg")).convert("RGBA")
    s = H / shell.height
    shell = shell.resize((int(shell.width * s + 0.5), H), Image.LANCZOS)
    x0 = (shell.width - W) // 2
    canvas = shell.crop((x0, 0, x0 + W, H))
    # 外壳岩层里 AI 自画的空腔会从胶囊缝隙露出来（"多出一层"的根因）——
    # 用 v2 手绘岩层贴图把地下带（地表线以下）整片盖掉，顶部 36px 渐变融合
    rock_src = Image.open(r"assets/bunker/v2/bg_rock.png").convert("RGBA")
    rock = rock_src.resize((W, H - 330), Image.LANCZOS)
    # 压暗匹配外壳深色岩层（bg_rock 原图偏亮偏黄）
    rock = ImageEnhance.Brightness(rock).enhance(0.52)
    rock = ImageEnhance.Color(rock).enhance(0.82)
    mask = Image.new("L", (W, H - 330), 255)
    md = ImageDraw.Draw(mask)
    for i in range(36):
        md.line([(0, i), (W, i)], fill=int(255 * i / 36))
    canvas.alpha_composite(Image.composite(rock, Image.new("RGBA", rock.size), mask), (0, 330))
    return canvas

def bake(all_lit):
    random.seed(20260827)
    canvas = build_base()
    d = ImageDraw.Draw(canvas, "RGBA")
    # 嵌套暗腔（比房间矩形大 6px 的圆角暗槽，胶囊坐进去）
    for (rid, x, y, w, h, side, ty, via, init) in ROOMS:
        d.rounded_rectangle([x - 6, y - 6, x + w + 6, y + h + 6], radius=38,
                            fill=(10, 7, 5, 255), outline=(26, 20, 14, 255), width=3)
    # 竖井
    d.rectangle([SHAFT_X1, SHAFT_TOP, SHAFT_X2, SHAFT_BOT], fill=(5, 4, 3, 255))
    d.rectangle([SHAFT_X1, SHAFT_TOP, SHAFT_X2, SHAFT_BOT], outline=(28, 22, 15, 255), width=2)
    for (rid, x, y, w, h, side, ty, via, init) in ROOMS:
        if ty is None: continue
        d.rectangle([SHAFT_X1 - 2, ty - 3, SHAFT_X1 + 8, ty + 2], fill=(74, 65, 50, 255))
        d.rectangle([SHAFT_X2 - 8, ty - 3, SHAFT_X2 + 2, ty + 2], fill=(74, 65, 50, 255))
    # 隧道
    for (rid, x, y, w, h, side, ty, via, init) in ROOMS:
        if ty is None: continue
        tx0, tx1 = (x + w, SHAFT_X1) if side == "L" else (SHAFT_X2, x)
        if tx1 - tx0 < 8: continue
        d.rounded_rectangle([tx0, ty - 11, tx1, ty + 11], radius=8, fill=(7, 5, 3, 255))
        d.rounded_rectangle([tx0, ty - 11, tx1, ty + 11], radius=8, outline=(30, 24, 16, 255), width=2)
    # 胶囊嵌入：全部 aspect-fill 贴底（竖向裁顶保地面线与侧壁门洞；
    # 胶囊四边贴合房间矩形 → 房名/门位/隧道与胶囊逐边对齐，无黑边错位）
    for (rid, x, y, w, h, side, ty, via, init) in ROOMS:
        cap = load_cap(rid)
        s = max(w / cap.width, h / cap.height)
        nw, nh = int(cap.width * s + 0.5), int(cap.height * s + 0.5)
        cap = cap.resize((nw, nh), Image.LANCZOS)
        cap = cap.crop(((nw - w) // 2, nh - h, (nw - w) // 2 + w, nh))
        px_, py_ = x, y
        if not (all_lit or init):
            cap = ImageEnhance.Brightness(cap).enhance(0.32)   # 涂黑：留轮廓
            cap = ImageEnhance.Color(cap).enhance(0.4)
            tint = Image.new("RGBA", cap.size, (18, 14, 10, 110))
            cap = Image.alpha_composite(cap, tint)
        canvas.alpha_composite(cap, (px_, py_))
        if all_lit or init:  # 光池（仓库青 / 其余暖）
            lw, lh = int(w * .9), int(h * .78)
            pool = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
            pd = ImageDraw.Draw(pool)
            pc = (120, 229, 255, 44) if rid == "depot" else (255, 170, 90, 40)
            pd.ellipse([lw * .05, lh * .04, lw * .95, lh * .92], fill=pc)
            canvas.alpha_composite(pool.filter(ImageFilter.GaussianBlur(20)),
                                   (x + (w - lw) // 2, y + (h - lh) // 2))
    # 反应堆辉光 + 岩缝
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy = 650, 610
    for r, a in [(240, 15), (170, 22), (95, 34), (42, 50)]:
        gd.ellipse([cx - r, cy - int(r * .6), cx + r, cy + int(r * .6)], fill=(255, 120, 46, a))
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(24)))
    for (fx, fy, ang, ln) in [(560, 600, -24, 76), (740, 608, 20, 68), (648, 588, 4, 58)]:
        import math
        ck = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        cd = ImageDraw.Draw(ck)
        cd.line([fx, fy, fx + int(ln * math.cos(math.radians(ang))), fy - int(ln * math.sin(math.radians(ang)))],
                fill=(255, 130, 50, 110), width=4)
        canvas.alpha_composite(ck.filter(ImageFilter.GaussianBlur(3)))
    return canvas.convert("RGB")

if __name__ == "__main__":
    os.chdir(os.path.join(os.path.dirname(__file__), ".."))
    os.makedirs(DST, exist_ok=True)
    # 胶囊抠图落盘
    for f in sorted(os.listdir(SRC)):
        if f.startswith("cap_") and f.lower().endswith((".jpeg", ".jpg", ".png")):
            name = os.path.splitext(f)[0]
            out = os.path.join(DST, name + ".png")
            if not os.path.exists(out):
                autocrop(flood_white_to_alpha(Image.open(os.path.join(SRC, f)))).save(out)
                print("[cap ]", name)
    dark = bake(False); dark.save(os.path.join(DST, "bunker_bg_v3.png"))
    print("saved bunker_bg_v3.png", dark.size)
    lit = bake(True); lit.save(os.path.join(DST, "bunker_bg_v3_lit.png"))
    print("saved bunker_bg_v3_lit.png", lit.size)
