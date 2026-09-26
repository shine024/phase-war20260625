# -*- coding: utf-8 -*-
"""记录5#1 v38d: 雪原黑门定稿——三件事：
1) 修 v37 存量补丁带（x895-1015/y95-393 竖向亮度台阶）：频率分离——减去低频偏差、
   保留中高频云纹理，无新台阶无糊块；
2) 新黑门就地覆盖 v37 小柱（底宽30 > 柱宽11，cx=958 全盖，零擦除补丁）；
3) halo/紫晕减淡收小、去顶段雾罩（v38c 紫晕过艳+横切线露馅）。
"""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BAK = os.path.join(ROOT, "assets", "intro", "_art_backup", "wakeup_snowfield_v37_20260924.png")
SRC = os.path.join(ROOT, "assets", "intro", "wakeup_snowfield.png")
OUT = os.path.join(ROOT, ".godot", "art_regen", "wakeup_snowfield_v38d.png")

BAND = (893, 93, 1017, 395)     # 补丁带（v37 擦除区外扩一点）

GATE_CX = 958
GATE_BASE_Y = 410
GATE_TOP_Y = 318
W_BOTTOM = 30
W_TOP = 7


def fix_band(im: Image.Image) -> Image.Image:
    """频率分离修补丁带：target=左右均值行内线性插值；diff=带-target 的低频分量被减除。"""
    x0, y0, x1, y1 = BAND
    px = im.load()
    # 每行左右基准（带外各 26px 均值）
    for y in range(y0, y1):
        la = sum(sum(px[x, y]) / 3 for x in range(x0 - 26, x0 - 2)) / 24.0
        rb = sum(sum(px[x, y]) / 3 for x in range(x1 + 2, x1 + 26)) / 24.0
        # 目标低频场 + 当前低频场 → 偏差场
        for x in range(x0, x1):
            t = (x - x0) / float(x1 - 1 - x0)
            t = t * t * (3 - 2 * t)
            target = la + (rb - la) * t
            r, g, b = px[x, y]
            cur = (r + g + b) / 3.0
            if cur < 1:
                continue
            # 目标减当前=需要补的低频偏差；存进 alpha 通道图后面统一 blur
            px[x, y] = (int(target - cur), 0, 0)   # 暂存 R=偏差
    # 偏差场高斯模糊（低频化）
    diff_img = im.crop((x0, y0, x1, y1)).filter(ImageFilter.GaussianBlur(22))
    dpx = diff_img.load()
    # 回写：原图恢复 + 减去低频偏差
    src_copy = Image.open(BAK).convert("RGB").load()   # 从备份拿原始像素
    for y in range(y0, y1):
        la = sum(sum(src_copy[x, y]) / 3 for x in range(x0 - 26, x0 - 2)) / 24.0
        rb = sum(sum(src_copy[x, y]) / 3 for x in range(x1 + 2, x1 + 26)) / 24.0
        for x in range(x0, x1):
            t = (x - x0) / float(x1 - 1 - x0)
            t = t * t * (3 - 2 * t)
            target = la + (rb - la) * t
            cur = sum(src_copy[x, y]) / 3.0
            dev = dpx[x - x0, y - y0][0]     # blur 后的偏差低频
            g = 1.0 + (dev / max(1.0, cur)) * -1.0 if cur > 1 else 1.0
            g = min(1.06, max(0.94, g))
            # 带边缘 20px 线性淡出校正量，防新台阶
            fade = min(1.0, (x - x0) / 20.0, (x1 - 1 - x) / 20.0)
            g = 1.0 + (g - 1.0) * fade
            r, gg, b = src_copy[x, y]
            px[x, y] = (int(min(255, max(0, r * g))), int(min(255, max(0, gg * g))), int(min(255, max(0, b * g))))
    return im


def draw_gate(im: Image.Image) -> Image.Image:
    rng = random.Random(20260924)
    ss = 2
    layer = Image.new("RGBA", (im.width * ss, im.height * ss), (0, 0, 0, 0))
    cx = GATE_CX * ss
    base_y = GATE_BASE_Y * ss
    top_y = GATE_TOP_Y * ss
    h = base_y - top_y
    steps = 160

    def half_w(t: float) -> float:
        return (W_BOTTOM + (W_TOP - W_BOTTOM) * (t ** 0.8)) / 2.0 * ss

    def edge_wob(t: float) -> float:
        return 2.6 * ss * (0.6 * math.sin(t * 6.1 + 0.7) + 0.3 * math.sin(t * 15.3 + 3.9) + 0.3 * (rng.random() - 0.5))

    # 1) 紫色辉光（减淡收小，糊更开——像空气辉光不是紫块）
    halo = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    mid_y = base_y - h * 0.45
    hd.ellipse([cx - 44*ss, mid_y - 60*ss, cx + 44*ss, base_y + 12*ss], fill=(140, 96, 225, 34))
    hd.ellipse([cx - 26*ss, mid_y - 44*ss, cx + 26*ss, base_y + 6*ss], fill=(155, 108, 240, 46))
    halo = halo.filter(ImageFilter.GaussianBlur(20 * ss))
    layer = Image.alpha_composite(layer, halo)

    # 2) 门体（实心近黑蓝裂缝）+ 内芯紫光（底亮顶弱）
    body = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    core = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    cd = ImageDraw.Draw(core)
    for i in range(steps):
        t0, t1 = i / steps, (i + 1) / steps
        y0, y1 = base_y - h * t0, base_y - h * t1
        w0, w1 = half_w(t0), half_w(t1)
        bd.polygon([(cx - w0 + edge_wob(t0), y0), (cx + w0 + edge_wob(t0) * 0.7, y0),
                    (cx + w1 + edge_wob(t1) * 0.7, y1), (cx - w1 + edge_wob(t1), y1)],
                   fill=(16, 18, 32, 244))
        ca, cb = w0 * 0.42, w1 * 0.42
        glow_a = int(80 + 115 * (1.0 - t0))
        cd.polygon([(cx - ca + edge_wob(t0) * 0.5, y0), (cx + ca + edge_wob(t0) * 0.4, y0),
                    (cx + cb + edge_wob(t1) * 0.35, y1), (cx - cb + edge_wob(t1) * 0.4, y1)],
                   fill=(168, 112, 250, glow_a))
    body = body.filter(ImageFilter.GaussianBlur(0.8 * ss))
    layer = Image.alpha_composite(layer, body)
    core = core.filter(ImageFilter.GaussianBlur(1.1 * ss))
    layer = Image.alpha_composite(layer, core)

    # 3) 底部雪地紫晕（扁、淡）
    glow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([cx - 46*ss, base_y - 5*ss, cx + 46*ss, base_y + 13*ss], fill=(150, 100, 235, 48))
    glow = glow.filter(ImageFilter.GaussianBlur(11 * ss))
    layer = Image.alpha_composite(layer, glow)

    layer = layer.resize((im.width, im.height), Image.LANCZOS)
    layer = layer.filter(ImageFilter.GaussianBlur(0.5))
    return Image.alpha_composite(im.convert("RGBA"), layer).convert("RGB")


def main() -> None:
    im = Image.open(BAK).convert("RGB")     # 从 v37 备份出发
    im = fix_band(im)                        # 频率分离修 v37 存量补丁带
    out = draw_gate(im)                      # 就地覆盖画新门
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT)
    out.save(SRC)
    cmp_img = Image.new("RGB", (im.width, im.height * 2 + 8), (30, 30, 30))
    cmp_img.paste(im, (0, 0))
    cmp_img.paste(out, (0, im.height + 8))
    cmp_img.save(os.path.join(ROOT, ".godot", "art_regen", "wakeup_snowfield_v38d_compare.png"))
    print("OK v38d ->", OUT)


if __name__ == "__main__":
    main()
