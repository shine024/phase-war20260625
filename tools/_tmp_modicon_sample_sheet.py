# -*- coding: utf-8 -*-
"""_tmp_modicon_sample_sheet.py —— 改造图标样张对比表（PIL 拼版）

四方向样张各出：128px 原图 + 44px / 26px 小尺寸存活测试（深色面板底），
并给每方向首张模拟 v37.1 稀有度发光底座（圆角描边+外溢辉光近似）。

输出：docs/待生成徽章_改造图标样张_20260917/样张对比表.png
用法：python tools/_tmp_modicon_sample_sheet.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "docs", "待生成徽章_改造图标样张_20260917", "raw")
OUT = os.path.join(ROOT, "docs", "待生成徽章_改造图标样张_20260917", "样张对比表.png")

BG = (10, 18, 31)          # 深空黑 #0A121F（面板底）
PANEL = (21, 27, 43)       # 面板灰蓝
TXT = (225, 230, 240)
DIM = (140, 148, 165)

ROWS = [
    ("B 霓虹纹章·族徽（相位仪徽章同源）", "epic",
     ["b_badge_armor_cyan", "b_badge_arty_amber", "b_badge_recon_violet"]),
    ("A 军械剪影（Tarkov/WoT 路数）", "rare",
     ["a_silhouette_scope", "a_silhouette_apshell"]),
    ("C 双色扁平功能标（game-icons/Destiny 路数）", "uncommon",
     ["c_flat_wrench", "c_flat_helmet"]),
    ("D 厚涂特写（卡面同源·英雄图标路线）", "legendary",
     ["d_painted_apfsds"]),
]
RARITY = {
    "common": (107, 118, 145), "uncommon": (34, 197, 94), "rare": (56, 189, 248),
    "epic": (192, 132, 252), "legendary": (245, 158, 11), "mythic": (239, 68, 68),
}

FONT = None
for p in [r"C:\Windows\Fonts\msyh.ttc", r"C:\Windows\Fonts\simhei.ttf",
          r"C:\Windows\Fonts\msyhbd.ttc"]:
    if os.path.exists(p):
        FONT = p
        break


def font(sz):
    return ImageFont.truetype(FONT, sz) if FONT else ImageFont.load_default()


def tile_mock(icon_128, rarity):
    """模拟 v37.1 ModIconTile：稀有度描边 + 外溢辉光 + 内衬深底。输入 128px 图，输出 148px 图。"""
    S, PAD = 148, 10
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    col = RARITY[rarity] + (255,)
    box = (PAD, PAD, S - PAD, S - PAD)
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.rounded_rectangle(box, radius=8, outline=col, width=4)
    glow = glow.filter(ImageFilter.GaussianBlur(5))
    canvas.alpha_composite(glow)
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle(box, radius=8, fill=(8, 12, 22, 255), outline=col, width=2)
    inner = icon_128.resize((S - 2 * PAD - 8, S - 2 * PAD - 8), Image.LANCZOS)
    canvas.alpha_composite(inner, (PAD + 4, PAD + 4))
    return canvas


def load(id_):
    p = os.path.join(SRC, id_ + ".png")
    if not os.path.exists(p):
        return None
    try:
        return Image.open(p).convert("RGBA")
    except Exception:
        return None


def sized(img, px, bg_panel=True):
    """px 缩放 + 贴面板色小方块（模拟 UI 里的深底呈现）"""
    cell = Image.new("RGBA", (px + 8, px + 8), PANEL + (255,) if bg_panel else (0, 0, 0, 0))
    small = img.resize((px, px), Image.LANCZOS)
    cell.alpha_composite(small, (4, 4))
    return cell


def main():
    big, small_px = 128, [44, 26]
    f_title, f_lbl, f_tiny = font(22), font(15), font(12)
    col_w = 1340
    row_h = 190
    H = 70 + len(ROWS) * row_h + 20
    sheet = Image.new("RGBA", (col_w, H), BG + (255,))
    d = ImageDraw.Draw(sheet)
    d.text((20, 18), "改造图标重设计样张对比（agnes 样张 · 非最终资产）", font=f_title, fill=TXT)
    y = 70
    for title, rar, ids in ROWS:
        d.text((20, y), title, font=f_lbl, fill=DIM)
        x = 20
        for i, sid in enumerate(ids):
            img = load(sid)
            if img is None:
                d.text((x + 4, y + 30), sid + "（缺图）", font=f_lbl, fill=(200, 80, 80))
                x += 240
                continue
            base = img.resize((big, big), Image.LANCZOS)
            sheet.alpha_composite(base, (x, y + 26))
            d.text((x, y + 26 + big + 2), sid, font=f_tiny, fill=DIM)
            # 小尺寸存活条（面板底）
            sx = x + big + 14
            for px in small_px:
                sheet.alpha_composite(sized(img, px), (sx, y + 26 + (big - px) // 2 - 4))
                d.text((sx, y + 26 + big + 2), "%dpx" % px, font=f_tiny, fill=DIM)
                sx += px + 22
            # 首张：稀有度底座模拟
            if i == 0:
                mx = sx + 6
                sheet.alpha_composite(tile_mock(base, rar), (mx, y + 26 - 10))
                d.text((mx, y + 26 + big + 2), "+%s底座" % rar, font=f_tiny, fill=DIM)
            x += 430
        y += row_h
    sheet.convert("RGB").save(OUT)
    print("saved:", OUT)


if __name__ == "__main__":
    main()
