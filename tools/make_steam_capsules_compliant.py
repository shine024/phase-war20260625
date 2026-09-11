# -*- coding: utf-8 -*-
## Steam 商店合规胶囊图生成器（v27.x 修复审核拒绝）
## 规则：
##   - 商店胶囊：只允许游戏名+官方副标题，不允许营销文案/描述性文字
##   - 库资产（Capsule/Header/Logo）：只允许游戏标题
##   - Library Hero：不允许任何文字/logo overlay
##
## 解法：全部输出纯 artwork 版本，游戏名"PHASE WAR"放 Steam 后台文本字段，
##       不在图片上加字。如需展示，可在 small/header/main 仅居中加 "PHASE WAR" 一行。
##
## 素材源：title_bg.png（机甲 key art，1920×1080）
from PIL import Image, ImageFilter
import os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets/backgrounds/title_bg.png')
OUT = os.path.join(ROOT, '_steam_assets/capsules')
os.makedirs(OUT, exist_ok=True)

src = Image.open(SRC).convert('RGB')  # 1920×1080

print(f'[OK] Source: {src.size}')

def crop_band(w_ratio, y_anchor=0.5, x_anchor=0.5, expand_h=False):
    """按目标宽高比从源图裁带"""
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
    return path


def bottom_gradient(im, frac=0.5, strength=180):
    """底部暗化渐变，增强机甲轮廓可读性（不含文字）"""
    w, h = im.size
    from PIL import ImageDraw
    ov = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(ov)
    start = int(h * (1.0 - frac))
    for y in range(start, h):
        k = (y - start) / max(1, h - start)
        d.line([(0, y), (w, y)], fill=int(strength * (k ** 1.2)))
    dark = Image.new('RGB', (w, h), (4, 6, 14))
    return Image.composite(dark, im, ov)


# ═══════════════════════════════════════════════════════════
#  商店胶囊（Store Capsules）—— 纯 artwork，无文字
#  Steam 允许：游戏名 + 官方副标题；不允许：营销文案、描述性文字
#  解法：不加任何文字，名字放 Steam 后台字段
# ═══════════════════════════════════════════════════════════

# ── Header Capsule 920×430 ───────────────────────────────
print('\n── Header Capsule ──')
band = crop_band(920 / 430, 0.50)
band = bottom_gradient(band, 0.38, 150)  # 轻度压暗
h920 = band.resize((920, 430), Image.LANCZOS)
save(h920, 'header_capsule_920x430.png')
save(h920.resize((1840, 860), Image.LANCZOS), 'header_capsule_2x_1840x860.png')

# ── Small Capsule 462×174 ────────────────────────────────
print('\n── Small Capsule ──')
# y=0.37：取景机甲头部区域
band = crop_band(462 / 174, 0.37)
band = bottom_gradient(band, 0.40, 140)
s462 = band.resize((462, 174), Image.LANCZOS)
save(s462, 'small_capsule_462x174.png')
save(s462.resize((924, 348), Image.LANCZOS), 'small_capsule_2x_924x348.png')

# ── Main Capsule 1232×706（现行规范，旧 616×353 已停用）──
print('\n── Main Capsule ──')
band = crop_band(1232 / 706, 0.50, 0.55)
band = bottom_gradient(band, 0.40, 140)
m1232 = band.resize((1232, 706), Image.LANCZOS)
save(m1232, 'main_capsule_1232x706.png')
save(m1232.resize((2464, 1412), Image.LANCZOS), 'main_capsule_2x_2464x1412.png')

# ── Vertical Capsule 748×896 ─────────────────────────────
print('\n── Vertical Capsule ──')
# x 锚右偏对准机甲主体
band = crop_band(748 / 896, 0.46, 0.62)
vc = band.resize((748, 896), Image.LANCZOS)
vc = bottom_gradient(vc, 0.35, 130)
save(vc, 'vertical_capsule_748x896.png')
save(vc.resize((1496, 1792), Image.LANCZOS), 'vertical_capsule_2x_1496x1792.png')

# ═══════════════════════════════════════════════════════════
#  库资产（Library Assets）—— 纯 artwork，无文字
#  Library Hero 严格不能有任何文字/logo overlay
# ═══════════════════════════════════════════════════════════

# ── Library Capsule 600×900 ──────────────────────────────
print('\n── Library Capsule ──')
# 竖版构图：机甲全身+标题留白区（底部纯色块，无文字）
band = crop_band(600 / 900 * (600/600), 0.42, 0.62)
art = band.resize((600, 600), Image.LANCZOS)  # 上部艺术区
# 创建完整 600×900 画布
lc = Image.new('RGB', (600, 900), (8, 12, 24))
lc.paste(art, (0, 0))
# 底部色带（无文字，纯色装饰）
from PIL import ImageDraw
dl = ImageDraw.Draw(lc)
dl.rectangle([0, 600, 600, 900], fill=(10, 16, 32))
# 青蓝分隔线
dl.rectangle([0, 598, 600, 602], fill=(50, 120, 150))
save(lc, 'library_capsule_600x900.png')
save(lc.resize((1200, 1800), Image.LANCZOS), 'library_capsule_2x_1200x1800.png')

# ── Library Header 920×430（复用 header 同构图）──────────
print('\n── Library Header ──')
lib_header = Image.open(os.path.join(OUT, 'header_capsule_920x430.png'))
save(lib_header, 'library_header.png')

# ── Library Logo 1280×720 ────────────────────────────────
# 纯透明底，无任何文字（文字放后台字段）
print('\n── Library Logo ──')
lg = Image.new('RGBA', (1280, 720), (0, 0, 0, 0))
save(lg, 'library_logo_1280x720.png')

# ── Library Hero 3840×1240 ───────────────────────────────
# 严格无文字、无 logo overlay
print('\n── Library Hero ──')
base = src.resize((2204, 1240), Image.LANCZOS)
hero = Image.new('RGB', (3840, 1240))
hero.paste(base, (818, 0))
# 两侧镜像延展 + 大模糊补宽
lp = base.crop((0, 0, 938, 1240)).transpose(Image.FLIP_LEFT_RIGHT).filter(ImageFilter.GaussianBlur(60))
from PIL import ImageDraw
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
# 左中轻压暗（供 logo 叠放处自然暗化，但无文字）
grad = Image.new('L', hero.size, 0)
dg = ImageDraw.Draw(grad)
for x in range(0, hero.size[0], 8):
    k = max(0.0, 1.0 - abs(x - hero.size[0] * 0.33) / (hero.size[0] * 0.42))
    dg.rectangle([x, 0, x + 8, hero.size[1]], fill=int(80 * k))
hero = Image.composite(Image.new('RGB', hero.size, (4, 7, 16)), hero, grad)
save(hero, 'library_hero_3840x1240.png')

# ═══════════════════════════════════════════════════════════
#  Page Background（页面背景，无文字，压暗让商店文案可读）
# ═══════════════════════════════════════════════════════════
print('\n── Page Background ──')
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

# ═══════════════════════════════════════════════════════════
#  Icons（徽记，无文字，纯几何图形）
# ═══════════════════════════════════════════════════════════
print('\n── Icons ──')
ACCENT = (110, 220, 245)
def make_icon(size):
    ic = Image.new('RGB', (size, size), (10, 16, 28))
    di = ImageDraw.Draw(ic)
    k = size / 184.0
    di.ellipse([10 * k, 10 * k, (size - 10) * k, (size - 10) * k], outline=ACCENT, width=max(2, round(7 * k)))
    di.ellipse([24 * k, 24 * k, (size - 24) * k, (size - 24) * k], outline=(60, 120, 145), width=2)
    # 中心青色点（替代原"相"字）
    r = max(3, round(12 * k))
    di.ellipse([(size/2 - r)*k/k, (size/2 - r)*k/k, (size/2 + r)*k/k, (size/2 + r)*k/k], fill=ACCENT)
    return ic

save(make_icon(256), 'shortcut_icon_256x256.png')
make_icon(184).save(os.path.join(OUT, 'app_icon_184x184.jpg'), quality=95)
print(f'  OK app_icon_184x184.jpg  (184, 184)')

print('\n[OK] all compliant assets generated ->', OUT)
print('\nNOTES:')
print('  - All capsules/library assets are pure artwork, no text overlays')
print('  - Game title "PHASE WAR" must be entered in Steam backend text fields')
print('  - Short desc / long desc / tags also go in Steam backend')
print('  - Old text-bearing files have been overwritten')
