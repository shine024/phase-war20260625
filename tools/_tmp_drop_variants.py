# -*- coding: utf-8 -*-
"""v36 A4：战场掉落小贴图家族生成（可重跑）。

输入母图：assets/resources/basic_nano.png（RGB 1024，银环+蓝晶石+浅灰卡底）
         assets/resources/energy_block.png（RGBA 1024，电池）
输出：
  1) basic_nano.png 原位抠透明底（HUD 图标与掉落共用；近白卡底→alpha）
  2) assets/resources/drops/drop_{nano,battery}_{1,2,3}.png —— 数量分档变体
     （256×256 透明底，内容高统一 ~190px，GDScript 侧 scale = 目标px/190）
原图备份：F:/godot fair duet/_art_backup/basic_nano_original_20260916.png
"""
from PIL import Image, ImageFilter
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "assets", "resources")
DROPS = os.path.join(RES, "drops")
BACKUP = r"F:\godot fair duet\_art_backup"
os.makedirs(DROPS, exist_ok=True)

# ── 工具 ────────────────────────────────────────────────────────────

def flood_remove_bg(im, seed_l=236, sat_max=30, feather=1.0):
    """从四角+边中点泛洪移除浅色低饱和背景（返回 RGBA）。"""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    luma = lambda p: (p[0] * 299 + p[1] * 587 + p[2] * 114) // 1000
    sat = lambda p: max(p[0], p[1], p[2]) - min(p[0], p[1], p[2])
    from collections import deque
    mask = [[False] * w for _ in range(h)]
    dq = deque()
    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1),
             (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)]
    for s in seeds:
        p = px[s]
        if luma(p) >= seed_l and sat(p) <= sat_max and not mask[s[1]][s[0]]:
            mask[s[1]][s[0]] = True
            dq.append(s)
    while dq:
        x, y = dq.popleft()
        for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
            if 0 <= nx < w and 0 <= ny < h and not mask[ny][nx]:
                p = px[nx, ny]
                if luma(p) >= seed_l and sat(p) <= sat_max:
                    mask[ny][nx] = True
                    dq.append((nx, ny))
    alpha = Image.new("L", (w, h), 255)
    ap = alpha.load()
    for y in range(h):
        row = mask[y]
        for x in range(w):
            if row[x]:
                ap[x, y] = 0
    if feather > 0:
        alpha = alpha.filter(ImageFilter.GaussianBlur(feather))
    im.putalpha(alpha)
    return im


def autocrop(im, pad=2):
    bbox = im.getchannel("A").getbbox()
    if not bbox:
        return im
    x0, y0, x1, y1 = bbox
    x0 = max(0, x0 - pad); y0 = max(0, y0 - pad)
    x1 = min(im.width, x1 + pad); y1 = min(im.height, y1 + pad)
    return im.crop((x0, y0, x1, y1))


def extract_gem(nano_im):
    """从抠底后的纳米图标中心区提纯晶石（去银环）：
    紧裁剪 + 从裁剪边缘泛洪剔除低饱和灰（银环任意明暗）——晶石内部高光被蓝面包裹，保留。"""
    w, h = nano_im.size
    crop = nano_im.crop((int(w*0.33), int(h*0.22), int(w*0.68), int(h*0.68))).convert("RGBA")
    px = crop.load()
    w2, h2 = crop.size
    sat = lambda p: max(p[0], p[1], p[2]) - min(p[0], p[1], p[2])
    from collections import deque
    mask = [[False] * w2 for _ in range(h2)]
    dq = deque()
    for x in range(w2):
        for y in (0, h2 - 1):
            if not mask[y][x] and sat(px[x, y]) < 45:
                mask[y][x] = True; dq.append((x, y))
    for y in range(h2):
        for x in (0, w2 - 1):
            if not mask[y][x] and sat(px[x, y]) < 45:
                mask[y][x] = True; dq.append((x, y))
    while dq:
        x, y = dq.popleft()
        for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
            if 0 <= nx < w2 and 0 <= ny < h2 and not mask[ny][nx]:
                if sat(px[nx, ny]) < 45:
                    mask[ny][nx] = True
                    dq.append((nx, ny))
    for y in range(h2):
        for x in range(w2):
            if mask[y][x]:
                p = px[x, y]
                px[x, y] = (p[0], p[1], p[2], 0)
    # 清小噪 + 轻羽化
    a = crop.getchannel("A").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    a = a.filter(ImageFilter.GaussianBlur(0.6))
    crop.putalpha(a)
    return autocrop(crop)


def paste_center(base, spr, cx, cy, rot=0.0, scale=1.0):
    s = spr
    if scale != 1.0:
        s = spr.resize((max(1, int(spr.width * scale)), max(1, int(spr.height * scale))), Image.LANCZOS)
    if rot != 0.0:
        s = s.rotate(rot, expand=True, resample=Image.BICUBIC)
    base.alpha_composite(s, (int(cx - s.width / 2), int(cy - s.height / 2)))


def make_canvas(items, size=256, target_h=190, shadow=True):
    """items: [(spr, cx, cy, rot, scale_rel)]，按 target_h 归一内容高后居中。"""
    board = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    for spr, cx, cy, rot, sr in items:
        paste_center(board, spr, cx, cy, rot, sr)
    bbox = board.getchannel("A").getbbox()
    if bbox:
        board = board.crop(bbox)
    k = target_h / board.height
    board = board.resize((max(1, int(board.width * k)), target_h), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(board, ((size - board.width) // 2, (size - board.height) // 2))
    return canvas


# ── 1. 备份 + 抠底 basic_nano ──────────────────────────────────────
import shutil
src = os.path.join(RES, "basic_nano.png")
bak = os.path.join(BACKUP, "basic_nano_original_20260916.png")
if not os.path.exists(bak):
    shutil.copy2(src, bak)
    print("备份原图 ->", bak)
nano_cut = flood_remove_bg(Image.open(src))
nano_cut.save(src)
print("basic_nano.png 抠底完成", nano_cut.size)

# ── 2. 提取晶石单体 ────────────────────────────────────────────────
gem = extract_gem(nano_cut)
gem.save(os.path.join(DROPS, "_gem_debug.png"))
print("晶石单体", gem.size)

# ── 3. 纳米三档变体 ────────────────────────────────────────────────
gw, gh = gem.size
nano_variants = {
    "drop_nano_1.png": [(gem, 512, 512, 0.0, 1.0)],
    "drop_nano_2.png": [
        (gem, 512 - gw * 0.34, 512 + gh * 0.10, 9.0, 0.82),
        (gem, 512 + gw * 0.30, 512 - gh * 0.06, -8.0, 0.95),
    ],
    "drop_nano_3.png": [
        (gem, 512 - gw * 0.62, 512 + gh * 0.42, 7.0, 0.72),
        (gem, 512 + gw * 0.05, 512 + gh * 0.46, -6.0, 0.80),
        (gem, 512 + gw * 0.66, 512 + gh * 0.38, 10.0, 0.68),
        (gem, 512 - gw * 0.28, 512 - gh * 0.10, -9.0, 0.88),
        (gem, 512 + gw * 0.30, 512 - gh * 0.34, 5.0, 0.95),
    ],
}
for name, items in nano_variants.items():
    make_canvas(items).save(os.path.join(DROPS, name))
    print("生成", name)

# ── 4. 电池三档变体 ────────────────────────────────────────────────
bat = autocrop(Image.open(os.path.join(RES, "energy_block.png")).convert("RGBA"))
bw, bh = bat.size
bat_variants = {
    "drop_battery_1.png": [(bat, 512, 512, 0.0, 1.0)],
    "drop_battery_2.png": [
        (bat, 512 - bw * 0.30, 512 + bh * 0.06, 7.0, 0.80),
        (bat, 512 + bw * 0.28, 512 - bh * 0.05, -6.0, 0.95),
    ],
    "drop_battery_3.png": [
        (bat, 512 - bw * 0.52, 512 + bh * 0.30, 6.0, 0.68),
        (bat, 512 + bw * 0.48, 512 + bh * 0.26, -7.0, 0.72),
        (bat, 512, 512 - bh * 0.22, 3.0, 0.90),
    ],
}
for name, items in bat_variants.items():
    make_canvas(items).save(os.path.join(DROPS, name))
    print("生成", name)

print("全部完成")
