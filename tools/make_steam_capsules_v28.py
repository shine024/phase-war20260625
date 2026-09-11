# -*- coding: utf-8 -*-
## Steam 胶囊图生成器 v28（2026-09-07）—— 审核被拒后的修正版
##
## 【被拒原因 · 视觉审计结论】
##   旧图文字 = 「相位战争」+「PHASE WAR · CONSTRUCT ERA」(+库胶囊营销语「百关战术卡牌战役」)
##   规则（拒信原文）：
##   - 商店胶囊：可含 game artwork + the game name + any official subtitle
##     → "CONSTRUCT ERA" 是自造标语非官方副标题 = additional text ❌（被拒的就是它）
##   - Library Capsule/Header/Logo：仅可含 the game's title
##     → 营销语 ❌；游戏名 ✅
##   - Library Hero：不得有任何文字/logo → 旧版本来就干净 ✅（拒信更新清单里确实没有 Hero）
##
## 【v28 修正】
##   - 副标题 SUB 从 'PHASE WAR · CONSTRUCT ERA' 改为 'PHASE WAR'（纯游戏名，双语名合规）
##   - 库胶囊删除营销语「百关战术卡牌战役」
##   - 商店胶囊恢复游戏名 lockup（规则明确允许 game name，全删是过度矫正）
##   - 修 make_icon 圆环越界 bug（(size-10)*k → size-10*k），恢复「相」字徽记
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets/backgrounds/title_bg.png')
OUT = os.path.join(ROOT, '_steam_assets/capsules')
NOTO = os.path.join(ROOT, 'assets/fonts/NotoSansSC-Medium.ttf')
NOTO_R = os.path.join(ROOT, 'assets/fonts/NotoSansSC-Regular.ttf')
RAJ = os.path.join(ROOT, 'assets/fonts/Rajdhani-Bold.ttf')
os.makedirs(OUT, exist_ok=True)

TITLE = '相位战争'
SUB = 'PHASE WAR'            # v28: 仅游戏名（原 'PHASE WAR · CONSTRUCT ERA' 是被拒根因）
ACCENT = (110, 220, 245)
TITLE_COL = (222, 246, 255)

src = Image.open(SRC).convert('RGB')  # 1920×1080
print('[OK] source', src.size)


def crop_band(w_ratio, y_anchor, x_anchor=0.5):
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


def bottom_gradient(im, frac=0.62, strength=200):
    w, h = im.size
    ov = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(ov)
    start = int(h * (1.0 - frac))
    for y in range(start, h):
        k = (y - start) / max(1, h - start)
        d.line([(0, y), (w, y)], fill=int(strength * (k ** 1.4)))
    dark = Image.new('RGB', (w, h), (6, 10, 20))
    return Image.composite(dark, im, ov)


def draw_title(im, cx, base_y, title_px, sub_px, align='center', plate=True):
    """中文游戏名 + 英文游戏名（仅名称，无任何营销文案）。
    plate=True 垫半透明底板。注意：合成结果必须 paste 回原 im（v27 曾因局部重赋值丢标题）。"""
    d = ImageDraw.Draw(im)
    f1 = ImageFont.truetype(NOTO, title_px)
    tw = d.textlength(TITLE, font=f1)
    f2 = None
    sw = 0.0
    if sub_px > 0:
        f2 = ImageFont.truetype(RAJ, sub_px)
        sw = d.textlength(SUB, font=f2)
    block_w = max(tw, sw)
    y2 = base_y + title_px + int(title_px * 0.18)
    block_h = title_px
    if sub_px > 0:
        block_h = y2 + int(sub_px * 1.25) - base_y
    tx = cx - tw / 2 if align == 'center' else cx
    sx = cx - sw / 2 if align == 'center' else cx
    if plate:
        pad_x, pad_y = int(title_px * 0.32), int(title_px * 0.24)
        px0 = (cx - block_w / 2 - pad_x) if align == 'center' else (cx - pad_x)
        ov = Image.new('RGBA', im.size, (0, 0, 0, 0))
        po = ImageDraw.Draw(ov)
        po.rounded_rectangle(
            [px0, base_y - pad_y, px0 + block_w + pad_x * 2, base_y + block_h + pad_y],
            radius=max(8, int(title_px * 0.14)),
            fill=(7, 11, 21, 165), outline=(110, 220, 245, 80), width=2)
        comp = Image.alpha_composite(im.convert('RGBA'), ov).convert('RGB')
        im.paste(comp, (0, 0))          # ← v28 修复：paste 回原对象
        d = ImageDraw.Draw(im)
    d.text((tx + 3, base_y + 3), TITLE, font=f1, fill=(5, 10, 18))
    d.text((tx, base_y), TITLE, font=f1, fill=TITLE_COL)
    if sub_px > 0:
        d.text((sx, y2), SUB, font=f2, fill=ACCENT)
        y2 += int(sub_px * 1.25)
    return y2


def save(im, name):
    im.save(os.path.join(OUT, name))
    print('  OK', name, im.size)


# ── Header capsule 920×430（+2x）──────────────────────────────
band = crop_band(920 / 430, 0.50)
band = bottom_gradient(band, 0.42)
h920 = band.resize((920, 430), Image.LANCZOS)
draw_title(h920, 920 * 0.27, 208, 96, 34)
save(h920, 'header_capsule_920x430.png')
save(h920.resize((1840, 860), Image.LANCZOS), 'header_capsule_2x_1840x860.png')

# ── Small capsule 462×174（+2x）───────────────────────────────
band = crop_band(462 / 174, 0.37)
band = bottom_gradient(band, 0.45)
s462 = band.resize((462, 174), Image.LANCZOS)
draw_title(s462, 22, 46, 58, 15, align='left')
save(s462, 'small_capsule_462x174.png')
save(s462.resize((924, 348), Image.LANCZOS), 'small_capsule_2x_924x348.png')

# ── Main capsule 1232×706（现行规范）─────────────────────────
band = crop_band(616 / 353, 0.50, 0.55)
band = bottom_gradient(band, 0.45)
m1232 = band.resize((1232, 706), Image.LANCZOS)
draw_title(m1232, 1232 * 0.27, 300, 136, 40)
save(m1232, 'main_capsule_1232x706.png')

# ── Vertical capsule 748×896 ─────────────────────────────────
band = crop_band(748 / 896, 0.46, 0.62)
vc = band.resize((748, 896), Image.LANCZOS)
vc = bottom_gradient(vc, 0.40)
draw_title(vc, 748 / 2, 690, 88, 26)
save(vc, 'vertical_capsule_748x896.png')

# ── Page background 1438×810（无文字，压暗）──────────────────
band = crop_band(1438 / 810, 0.50)
pb = band.resize((1438, 810), Image.LANCZOS)
pb = Image.eval(pb, lambda v: int(v * 0.72))
vig = Image.new('L', pb.size, 0)
dv = ImageDraw.Draw(vig)
dv.ellipse([-pb.size[0] * 0.25, -pb.size[1] * 0.35, pb.size[0] * 1.25, pb.size[1] * 1.35], fill=90)
vig = vig.filter(ImageFilter.GaussianBlur(120))
dark = Image.new('RGB', pb.size, (8, 12, 22))
pb = Image.composite(pb, dark, vig)
save(pb, 'page_background_1438x810.png')

# ── 图标（青环 + 「相」徽记；v28 修圆环越界 + 恢复文字徽记）──
def make_icon(size):
    ic = Image.new('RGB', (size, size), (10, 16, 28))
    di = ImageDraw.Draw(ic)
    k = size / 184.0
    m = 10 * k                                   # v28 修复：原 (size-10)*k 在 size≠184 时越界
    di.ellipse([m, m, size - m, size - m], outline=ACCENT, width=max(2, round(7 * k)))
    m2 = 24 * k
    di.ellipse([m2, m2, size - m2, size - m2], outline=(60, 120, 145), width=2)
    fi = ImageFont.truetype(NOTO, round(92 * k))
    t = '相'
    tw = di.textlength(t, font=fi)
    bb = fi.getbbox(t)
    di.text(((size - tw) / 2, (size - (bb[3] - bb[1])) / 2 - bb[1]), t, font=fi, fill=(225, 248, 255))
    return ic

save(make_icon(256), 'shortcut_icon_256x256.png')
make_icon(184).save(os.path.join(OUT, 'app_icon_184x184.jpg'), quality=95)
print('  OK app_icon_184x184.jpg (184, 184)')

# ── Library capsule 600×900（+2x）— 仅游戏名，无营销语 ───────
band = crop_band(600 / 620, 0.42, 0.62)
art = band.resize((600, 620), Image.LANCZOS)
lc = Image.new('RGB', (600, 900), (10, 14, 26))
lc.paste(art, (0, 0))
dl = ImageDraw.Draw(lc)
dl.rectangle([0, 618, 600, 621], fill=(45, 105, 128))
draw_title(lc, 300, 690, 88, 30)
# v28: 删除营销语「百关战术卡牌战役」（被拒根因之一）
save(lc, 'library_capsule_600x900.png')
save(lc.resize((1200, 1800), Image.LANCZOS), 'library_capsule_2x_1200x1800.png')

# ── Library header 920×430（复用带标题 header，同 v2 口径）──
lh = Image.open(os.path.join(OUT, 'header_capsule_920x430.png'))
save(lh, 'library_header.png')

# ── Library hero 3840×1240：纯 artwork，无文字（保持原设计）─
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
    dg.rectangle([x, 0, x + 8, hero.size[1]], fill=int(110 * k))
hero = Image.composite(Image.new('RGB', hero.size, (6, 10, 20)), hero, grad)
save(hero, 'library_hero_3840x1240.png')

# ── Library logo 1280×720（透明底，仅游戏名双语 lockup）─────
lg = Image.new('RGBA', (1280, 720), (0, 0, 0, 0))
glow = Image.new('RGBA', lg.size, (0, 0, 0, 0))
dgw = ImageDraw.Draw(glow)
f1 = ImageFont.truetype(NOTO, 190)
f2 = ImageFont.truetype(RAJ, 56)
tw = dgw.textlength(TITLE, font=f1)
dgw.text(((1280 - tw) / 2, 200), TITLE, font=f1, fill=(110, 220, 245, 160))
sw = dgw.textlength(SUB, font=f2)
dgw.text(((1280 - sw) / 2, 430), SUB, font=f2, fill=(110, 220, 245, 120))
glow = glow.filter(ImageFilter.GaussianBlur(18))
lg = Image.alpha_composite(lg, glow)
dl = ImageDraw.Draw(lg)
dl.text(((1280 - tw) / 2, 200), TITLE, font=f1, fill=(225, 246, 255, 255))
dl.text(((1280 - sw) / 2, 430), SUB, font=f2, fill=(150, 225, 245, 235))
dl.rectangle([(1280 - tw) / 2, 530, (1280 + tw) / 2, 533], fill=(110, 220, 245, 220))
save(lg, 'library_logo_1280x720.png')

# ── 同步到 upload 目录 ──────────────────────────────────────
import shutil
UPLOAD = os.path.join(ROOT, '_steam_assets/upload')
dst1 = os.path.join(UPLOAD, '1a_商店胶囊_拖拽区')
dst2 = os.path.join(UPLOAD, '2_库资产')
dstb = os.path.join(UPLOAD, '1b_图标_专用字段')
for name in ['header_capsule_920x430.png', 'main_capsule_1232x706.png',
             'small_capsule_462x174.png', 'vertical_capsule_748x896.png',
             'page_background_1438x810.png']:
    shutil.copy2(os.path.join(OUT, name), os.path.join(dst1, name))
for name in ['library_capsule_600x900.png', 'library_header.png',
             'library_hero_3840x1240.png', 'library_logo_1280x720.png']:
    shutil.copy2(os.path.join(OUT, name), os.path.join(dst2, name))
shutil.copy2(os.path.join(OUT, 'shortcut_icon_256x256.png'), os.path.join(dstb, 'shortcut_icon_256x256.png'))
shutil.copy2(os.path.join(OUT, 'app_icon_184x184.jpg'), os.path.join(dstb, 'app_icon_184x184.jpg'))
# 清理 upload 里遗留的旧命名 main capsule（避免误传）
old_main = os.path.join(dst1, 'main_capsule_2x_1232x706.png')
if os.path.exists(old_main):
    os.remove(old_main)
    print('  removed stale upload/main_capsule_2x_1232x706.png')

print('\n[OK] v28 all done -> capsules/ + upload/ synced')
