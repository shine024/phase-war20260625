# -*- coding: utf-8 -*-
## Steam 商店胶囊图全家桶生成器（v26.9）
## 素材源：_steam_assets/screenshots/01_battle_storm.png（原生 1080p 战斗图）
## 输出：_steam_assets/capsules/（全部 Steamworks 规范尺寸 + 2x 版本）
## 尺寸规范：partner.steamgames.com/doc/store/assets（header 920×430 / small 462×174 /
##           main 616×353 / page bg 1438×810 / community icon 184×184 /
##           library capsule 600×900 / library hero 3840×1240 / library logo 1280×720）
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets/backgrounds/title_bg.png')  # v26.9 机甲 key art（左侧暗部天然放标题）
OUT = os.path.join(ROOT, '_steam_assets/capsules')
NOTO = os.path.join(ROOT, 'assets/fonts/NotoSansSC-Medium.ttf')
NOTO_R = os.path.join(ROOT, 'assets/fonts/NotoSansSC-Regular.ttf')
RAJ = os.path.join(ROOT, 'assets/fonts/Rajdhani-Bold.ttf')
os.makedirs(OUT, exist_ok=True)

TITLE = '相位战争'
SUB = 'PHASE WAR · CONSTRUCT ERA'
ACCENT = (110, 220, 245)
TITLE_COL = (222, 246, 255)

src = Image.open(SRC).convert('RGB')  # 1920×1080


def crop_band(w_ratio, y_anchor, x_anchor=0.5):
    """按目标宽高比从源图裁带：y/x_anchor=带中心在源图的相对位置(0..1)"""
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
    """底部自左向右下的暗化渐变（标题可读性）"""
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
    """中文标题 + 英文副题（返回底部 y）。plate=True 时给文字块垫半透明底板
    （v2：修 header 副标题压碎石对比度差 / small 缩略图标题过小）"""
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
    # 左对齐时 cx 为块左缘
    tx = cx if align == 'left' else cx - tw / 2
    sx = cx if align == 'left' else cx - sw / 2
    if plate:
        pad_x, pad_y = int(title_px * 0.32), int(title_px * 0.24)
        px0 = cx - pad_x if align == 'left' else cx - block_w / 2 - pad_x
        ov = Image.new('RGBA', im.size, (0, 0, 0, 0))
        po = ImageDraw.Draw(ov)
        po.rounded_rectangle(
            [px0, base_y - pad_y, px0 + block_w + pad_x * 2, base_y + block_h + pad_y],
            radius=max(8, int(title_px * 0.14)),
            fill=(7, 11, 21, 165), outline=(110, 220, 245, 80), width=2)
        comp = Image.alpha_composite(im.convert('RGBA'), ov).convert('RGB')
        im.paste(comp, (0, 0))
    d = ImageDraw.Draw(im)
    # 标题阴影 + 主体
    d.text((tx + 3, base_y + 3), TITLE, font=f1, fill=(5, 10, 18))
    d.text((tx, base_y), TITLE, font=f1, fill=TITLE_COL)
    if sub_px > 0:
        d.text((sx, y2), SUB, font=f2, fill=ACCENT)
        y2 += int(sub_px * 1.25)
    return y2


def save(im, name):
    im.save(os.path.join(OUT, name))
    print('  ✓', name, im.size)


# ── Header capsule 920×430（+2x 1840×860）────────────────────────
band = crop_band(920 / 430, 0.50)
band = bottom_gradient(band, 0.42)
h920 = band.resize((920, 430), Image.LANCZOS)
draw_title(h920, 920 * 0.27, 208, 96, 34)
save(h920, 'header_capsule_920x430.png')
save(h920.resize((1840, 860), Image.LANCZOS), 'header_capsule_2x_1840x860.png')

# ── Small capsule 462×174（+2x 924×348）──────────────────────────
# y 锚 0.37：取景带 y≈38-761，保住机甲头部（0.50 会把头切在带外）
band = crop_band(462 / 174, 0.37)
band = bottom_gradient(band, 0.45)
s462 = band.resize((462, 174), Image.LANCZOS)
draw_title(s462, 22, 46, 58, 15, align='left')
save(s462, 'small_capsule_462x174.png')
save(s462.resize((924, 348), Image.LANCZOS), 'small_capsule_2x_924x348.png')

# ── Main capsule 616×353（+2x 1232×706）──────────────────────────
band = crop_band(616 / 353, 0.50, 0.55)
band = bottom_gradient(band, 0.45)
m616 = band.resize((616, 353), Image.LANCZOS)
draw_title(m616, 616 * 0.27, 150, 68, 20)
save(m616, 'main_capsule_616x353.png')
save(m616.resize((1232, 706), Image.LANCZOS), 'main_capsule_2x_1232x706.png')

# ── Vertical capsule 748×896（2024 规范改版新增必填；x 锚右偏对准机甲）──
band = crop_band(748 / 896, 0.46, 0.62)
vc = band.resize((748, 896), Image.LANCZOS)
vc = bottom_gradient(vc, 0.40)
draw_title(vc, 748 / 2, 690, 88, 26)
save(vc, 'vertical_capsule_748x896.png')

# ── Main capsule：现行规范 1232×706（旧 616×353 已停用）─────────────
# 1232×706 即原 2x 版本，上面已输出 main_capsule_2x_1232x706.png 直接当 Main Capsule 用。

# ── Page background 1438×810（无文字，整体压暗让商店文案可读）────
band = crop_band(1438 / 810, 0.50)
pb = band.resize((1438, 810), Image.LANCZOS)
pb = Image.eval(pb, lambda v: int(v * 0.72))
# 四周轻晕影
vig = Image.new('L', pb.size, 0)
dv = ImageDraw.Draw(vig)
dv.ellipse([-pb.size[0] * 0.25, -pb.size[1] * 0.35, pb.size[0] * 1.25, pb.size[1] * 1.35], fill=90)
vig = vig.filter(ImageFilter.GaussianBlur(120))
dark = Image.new('RGB', pb.size, (8, 12, 22))
pb = Image.composite(pb, dark, vig)
save(pb, 'page_background_1438x810.png')

# ── 徽记（青环 + 「相」）：Shortcut Icon 256×256 .png + App Icon 184×184 .jpg ──
# 2024 规范：社区图标改 .jpg 格式，新增 256×256 客户端快捷方式图标
def make_icon(size):
	ic = Image.new('RGB', (size, size), (10, 16, 28))
	di = ImageDraw.Draw(ic)
	k = size / 184.0
	di.ellipse([10 * k, 10 * k, (size - 10) * k, (size - 10) * k], outline=ACCENT, width=max(2, round(7 * k)))
	di.ellipse([24 * k, 24 * k, (size - 24) * k, (size - 24) * k], outline=(60, 120, 145), width=2)
	fi = ImageFont.truetype(NOTO, round(92 * k))
	t = '相'
	tw = di.textlength(t, font=fi)
	bb = fi.getbbox(t)
	di.text(((size - tw) / 2, (size - (bb[3] - bb[1])) / 2 - bb[1]), t, font=fi, fill=(225, 248, 255))
	return ic

save(make_icon(256), 'shortcut_icon_256x256.png')
make_icon(184).save(os.path.join(OUT, 'app_icon_184x184.jpg'), quality=95)
print('  ✓ app_icon_184x184.jpg (184, 184)')

# ── Library capsule 600×900（+2x 1200×1800）──────────────────────
band = crop_band(600 / 620, 0.42, 0.62)   # 上部艺术区裁切（x 锚右偏对准机甲）
art = band.resize((600, 620), Image.LANCZOS)
lc = Image.new('RGB', (600, 900), (10, 14, 26))
lc.paste(art, (0, 0))
dl = ImageDraw.Draw(lc)
dl.rectangle([0, 618, 600, 621], fill=(45, 105, 128))
draw_title(lc, 300, 690, 88, 30)
f3 = ImageFont.truetype(NOTO_R, 26)
tag = '百关战术卡牌战役'
tw3 = dl.textlength(tag, font=f3)
dl.text(((600 - tw3) / 2, 850), tag, font=f3, fill=(150, 165, 185))
save(lc, 'library_capsule_600x900.png')
save(lc.resize((1200, 1800), Image.LANCZOS), 'library_capsule_2x_1200x1800.png')

# ── Library hero 3840×1240：全身 blur-pad 横幅 ──
# 源图 16:9 比横幅 3.10:1 窄得多，任何等比裁带都必然切头或切腿；
# 改为整图缩放到高 1240 居中放置，两侧镜像延展+大模糊补宽，接缝 120px 渐变融合。
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
# 左中区域轻压暗（logo 叠放处）
grad = Image.new('L', hero.size, 0)
dg = ImageDraw.Draw(grad)
for x in range(0, hero.size[0], 8):
    k = max(0.0, 1.0 - abs(x - hero.size[0] * 0.33) / (hero.size[0] * 0.42))
    dg.rectangle([x, 0, x + 8, hero.size[1]], fill=int(110 * k))
hero = Image.composite(Image.new('RGB', hero.size, (6, 10, 20)), hero, grad)
save(hero, 'library_hero_3840x1240.png')

# ── Library logo 1280×720（透明底标题 lockup）────────────────────
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

print('all capsules →', OUT)
