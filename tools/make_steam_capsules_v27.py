# -*- coding: utf-8 -*-
## Steam 商店合规胶囊图生成器（v27.x 修正版）
## 规则：
##   - 商店胶囊（header/small/main/vertical/page_bg）：纯 artwork，无任何文字
##   - Library Capsule/Header/Logo：只允许游戏名 "PHASE WAR"（官方标题），不允许营销文案
##   - Library Hero：严格无文字、无 logo overlay
##
## 素材源：title_bg.png（机甲 key art，1920x1080）
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets/backgrounds/title_bg.png')
OUT = os.path.join(ROOT, '_steam_assets/capsules')
FONT = os.path.join(ROOT, 'assets/fonts/Rajdhani-Bold.ttf')
os.makedirs(OUT, exist_ok=True)

src = Image.open(SRC).convert('RGB')
GAME_TITLE = 'PHASE WAR'  # 库资产允许的官方游戏名

print(f'[OK] Source: {src.size}')

def crop_band(w_ratio, y_anchor=0.5, x_anchor=0.5):
    cw = src.size[0]
    ch = int(round(cw / w_ratio))
    if ch <= src.size[1]:
        y0 = int(y_anchor * src.size[1] - ch / 2)
        y0 = max(0, min(src.size[1] - ch, y0))
        return src.crop((0, y0, cw, y0 + ch))
    ch = src.size[1]
    cw = int(round(ch * w_ratio))
    x0 = int(x_anchor * src.size[0] - cw / 2)
    x0 = max(0, min(src.size[0] - cw, x0))
    return src.crop((x0, 0, x0 + cw, ch))

def save(im, name):
    path = os.path.join(OUT, name)
    im.save(path)
    print(f'  OK {name}  {im.size}')

def bottom_gradient(im, frac=0.5, strength=180):
    w, h = im.size
    ov = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(ov)
    start = int(h * (1.0 - frac))
    for y in range(start, h):
        k = (y - start) / max(1, h - start)
        d.line([(0, y), (w, y)], fill=int(strength * (k ** 1.2)))
    dark = Image.new('RGB', (w, h), (4, 6, 14))
    return Image.composite(dark, im, ov)

def draw_title_only(im, text, cx, base_y, px, align='center', plate=True):
    """仅绘制游戏标题（无副标题、无营销文案）"""
    d = ImageDraw.Draw(im)
    try:
        f = ImageFont.truetype(FONT, px)
    except:
        f = ImageFont.load_default()
    tw = d.textlength(text, font=f)
    if plate:
        pad_x, pad_y = int(px * 0.35), int(px * 0.22)
        tx = cx - tw / 2 if align == 'center' else cx
        px0 = tx - pad_x
        ov = Image.new('RGBA', im.size, (0, 0, 0, 0))
        po = ImageDraw.Draw(ov)
        po.rounded_rectangle(
            [px0, base_y - pad_y, px0 + tw + pad_x * 2, base_y + int(px * 1.1) + pad_y],
            radius=max(6, int(px * 0.12)),
            fill=(8, 14, 26, 180), outline=(100, 200, 230, 100), width=2)
        im = Image.alpha_composite(im.convert('RGBA'), ov).convert('RGB')
        d = ImageDraw.Draw(im)
    d.text((cx - tw / 2 if align == 'center' else tx, base_y), text, font=f, fill=(230, 248, 255))
    return base_y + int(px * 1.1)


# ============================================================
#  商店胶囊：纯 artwork，零文字
# ============================================================

# Header Capsule 920x430
band = crop_band(920 / 430, 0.50)
band = bottom_gradient(band, 0.38, 150)
h920 = band.resize((920, 430), Image.LANCZOS)
save(h920, 'header_capsule_920x430.png')
save(h920.resize((1840, 860), Image.LANCZOS), 'header_capsule_2x_1840x860.png')

# Small Capsule 462x174
band = crop_band(462 / 174, 0.37)
band = bottom_gradient(band, 0.40, 140)
s462 = band.resize((462, 174), Image.LANCZOS)
save(s462, 'small_capsule_462x174.png')
save(s462.resize((924, 348), Image.LANCZOS), 'small_capsule_2x_924x348.png')

# Main Capsule 1232x706
band = crop_band(1232 / 706, 0.50, 0.55)
band = bottom_gradient(band, 0.40, 140)
m1232 = band.resize((1232, 706), Image.LANCZOS)
save(m1232, 'main_capsule_1232x706.png')
save(m1232.resize((2464, 1412), Image.LANCZOS), 'main_capsule_2x_2464x1412.png')

# Vertical Capsule 748x896
band = crop_band(748 / 896, 0.46, 0.62)
vc = band.resize((748, 896), Image.LANCZOS)
vc = bottom_gradient(vc, 0.35, 130)
save(vc, 'vertical_capsule_748x896.png')
save(vc.resize((1496, 1792), Image.LANCZOS), 'vertical_capsule_2x_1496x1792.png')

# ============================================================
#  库资产：Library Capsule/Header/Logo = 游戏名 "PHASE WAR"
#  Library Hero = 纯 artwork，无文字
# ============================================================

# Library Capsule 600x900
band = crop_band(600 / 900, 0.42, 0.62)
art = band.resize((600, 600), Image.LANCZOS)
lc = Image.new('RGB', (600, 900), (8, 12, 24))
lc.paste(art, (0, 0))
dl = ImageDraw.Draw(lc)
# 底部色带区（含游戏名）
dl.rectangle([0, 600, 600, 900], fill=(10, 16, 30))
dl.rectangle([0, 598, 600, 602], fill=(50, 120, 150))
draw_title_only(lc, GAME_TITLE, 300, 700, 52, align='center')
save(lc, 'library_capsule_600x900.png')
save(lc.resize((1200, 1800), Image.LANCZOS), 'library_capsule_2x_1200x1800.png')

# Library Header 920x430（同 header，加游戏名在底部）
lb = Image.open(os.path.join(OUT, 'header_capsule_920x430.png')).copy()
draw_title_only(lb, GAME_TITLE, 460, 340, 36, align='center')
save(lb, 'library_header.png')

# Library Logo 1280x720（透明底，仅游戏名）
lg = Image.new('RGBA', (1280, 720), (0, 0, 0, 0))
glow = Image.new('RGBA', lg.size, (0, 0, 0, 0))
dg = ImageDraw.Draw(glow)
try:
    f1 = ImageFont.truetype(FONT, 110)
except:
    f1 = ImageFont.load_default()
tw = dg.textlength(GAME_TITLE, font=f1)
# 发光
dg.text(((1280 - tw) / 2, 260), GAME_TITLE, font=f1, fill=(80, 180, 220, 60))
glow = glow.filter(ImageFilter.GaussianBlur(15))
lg = Image.alpha_composite(lg, glow)
# 主体
dl = ImageDraw.Draw(lg)
dl.text(((1280 - tw) / 2, 260), GAME_TITLE, font=f1, fill=(235, 250, 255))
save(lg, 'library_logo_1280x720.png')

# Library Hero 3840x1240：纯 artwork，无文字
base = src.resize((2204, 1240), Image.LANCZOS)
hero = Image.new('RGB', (3840, 1240))
hero.paste(base, (818, 0))
lp = base.crop((0, 0, 938, 1240)).transpose(Image.FLIP_LEFT_RIGHT).filter(ImageFilter.GaussianBlur(60))
lm = Image.new('L', lp.size, 255)
dlm = ImageDraw.Draw(lm)
for i in range(120):
    dlm.line([(818 + i, 0), (818 + i, 1240)], fill=int(255 * (1 - i / 119)))
hero.paste(lp, (0, 0), lm)
rp = base.crop((1266, 0, 2204, 1240)).transpose(Image.FLIP_LEFT_RIGHT).filter(ImageFilter.GaussianBlur(60))
rm = Image.new('L', rp.size, 255)
drm = ImageDraw.Draw(rm)
for i in range(120):
    drm.line([(i, 0), (i, 1240)], fill=int(255 * i / 119))
hero.paste(rp, (2902, 0), rm)
grad = Image.new('L', hero.size, 0)
dg = ImageDraw.Draw(grad)
for x in range(0, hero.size[0], 8):
    k = max(0.0, 1.0 - abs(x - hero.size[0] * 0.33) / (hero.size[0] * 0.42))
    dg.rectangle([x, 0, x + 8, hero.size[1]], fill=int(80 * k))
hero = Image.composite(Image.new('RGB', hero.size, (4, 7, 16)), hero, grad)
save(hero, 'library_hero_3840x1240.png')

# Page Background（纯 artwork）
band = crop_band(1438 / 810, 0.50)
pb = band.resize((1438, 810), Image.LANCZOS)
pb = Image.eval(pb, lambda v: int(v * 0.72))
vig = Image.new('L', pb.size, 0)
dv = ImageDraw.Draw(vig)
dv.ellipse([-pb.size[0] * 0.25, -pb.size[1] * 0.35, pb.size[0] * 1.25, pb.size[1] * 1.35], fill=90)
vig = vig.filter(ImageFilter.GaussianBlur(120))
dark = Image.new('RGB', pb.size, (6, 10, 20))
pb = Image.composite(pb, dark, vig)
save(pb, 'page_background_1438x810.png')

# Icons
ACCENT = (110, 220, 245)
def make_icon(size):
    ic = Image.new('RGB', (size, size), (10, 16, 28))
    di = ImageDraw.Draw(ic)
    k = size / 184.0
    di.ellipse([10 * k, 10 * k, (size - 10) * k, (size - 10) * k], outline=ACCENT, width=max(2, round(7 * k)))
    di.ellipse([24 * k, 24 * k, (size - 24) * k, (size - 24) * k], outline=(60, 120, 145), width=2)
    r = max(3, round(12 * k))
    di.ellipse([(size/2 - r)*k/k, (size/2 - r)*k/k, (size/2 + r)*k/k, (size/2 + r)*k/k], fill=ACCENT)
    return ic

save(make_icon(256), 'shortcut_icon_256x256.png')
make_icon(184).save(os.path.join(OUT, 'app_icon_184x184.jpg'), quality=95)
print(f'  OK app_icon_184x184.jpg  (184, 184)')

# Copy to upload folders
UPLOAD = os.path.join(ROOT, '_steam_assets/upload')
dst1 = os.path.join(UPLOAD, '1a_商店胶囊_拖拽区')
dst2 = os.path.join(UPLOAD, '2_库资产')
dstb = os.path.join(UPLOAD, '1b_图标_专用字段')

import shutil
for name in ['header_capsule_920x430.png', 'main_capsule_1232x706.png', 'small_capsule_462x174.png',
             'vertical_capsule_748x896.png', 'page_background_1438x810.png']:
    shutil.copy2(os.path.join(OUT, name), os.path.join(dst1, name))

for name in ['library_capsule_600x900.png', 'library_header.png', 'library_hero_3840x1240.png', 'library_logo_1280x720.png']:
    shutil.copy2(os.path.join(OUT, name), os.path.join(dst2, name))

shutil.copy2(os.path.join(OUT, 'shortcut_icon_256x256.png'), os.path.join(dstb, 'shortcut_icon_256x256.png'))
shutil.copy2(os.path.join(OUT, 'app_icon_184x184.jpg'), os.path.join(dstb, 'app_icon_184x184.jpg'))

print('\n[OK] All compliant assets generated and synced to upload/')
print('\nRULES SUMMARY:')
print('  Store capsules: pure artwork, NO text')
print('  Library capsule/header/logo: GAME TITLE only (PHASE WAR)')
print('  Library hero: pure artwork, NO text')
print('  All game metadata goes in Steam backend text fields')
