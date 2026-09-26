# -*- coding: utf-8 -*-
"""记录5#1: 雪原远处黑门 v38——v37 的 46px 小柱辨识度归零（实机读感=污点）。

改型：参照序章漫画 b2_invasion 的黑门语汇（黑裂缝 + 透出相位紫光），
在雪原地平线画一道竖向黑裂缝剪影、内芯渗紫光、底部雪地紫晕反光——
远但可读，一眼是"超自然的门"，不是烟柱脏点。PIL 局部改图，基地车不动。

产出: .godot/art_regen/wakeup_snowfield_v38.png（直接可替换）
      .godot/art_regen/wakeup_snowfield_v38_compare.png（左右对比）
备份: assets/intro/_art_backup/wakeup_snowfield_v37_20260924.png
"""
from PIL import Image, ImageDraw, ImageFilter
import os, math, random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "intro", "wakeup_snowfield.png")
OUT = os.path.join(ROOT, ".godot", "art_regen", "wakeup_snowfield_v38.png")
CMP = os.path.join(ROOT, ".godot", "art_regen", "wakeup_snowfield_v38_compare.png")
BAK = os.path.join(ROOT, "assets", "intro", "_art_backup", "wakeup_snowfield_v37_20260924.png")

ERASE_BOX = (910, 100, 1016, 472)   # v37 门体+接地阴影（同 _tmp_snowfield_gate_pushfar.py）

# 新门：黑裂缝 + 紫光
GATE_CX = 952
GATE_BASE_Y = 408          # 贴地平线（地平线 ~y396-418）
GATE_TOP_Y = 316           # 高 ~92px ≈ 画面高 12.8%（v37 46px 的 2 倍，仍处远景带）
W_BOTTOM = 22              # 底部宽（裂缝下宽上尖）
W_TOP = 8


def erase_gate(im: Image.Image) -> Image.Image:
    """v37 同款擦除：左源平移克隆填入，右接缝窄窗 cross-fade。"""
    x0, y0, x1, y1 = ERASE_BOX
    y1 = min(y1, im.height)
    w_src = x1 - x0
    src = im.crop((x0 - w_src - 4, y0, x0 - 4, y1)).copy()
    im.paste(src, (x0, y0))
    # 右接缝 cross-fade 消台阶
    fade_w = 10
    seam_x = x1 - fade_w
    right = im.crop((x1 + 2, y0, x1 + 2 + fade_w, y1)).filter(ImageFilter.GaussianBlur(2))
    im.paste(right, (seam_x, y0))
    return im


def _crack_edge(t: float, rng: random.Random, amp: float) -> float:
    """裂缝边缘扰动：低频正弦 + 细噪声，t∈[0,1] 沿高度。"""
    return amp * (0.6 * math.sin(t * 7.3 + 1.1) + 0.3 * math.sin(t * 17.7 + 4.2) + 0.4 * (rng.random() - 0.5))


def draw_gate(im: Image.Image) -> Image.Image:
    rng = random.Random(20260924)
    # ── 画在 2x 超采样层再缩小，边缘平滑 ──
    ss = 2
    layer = Image.new("RGBA", (im.width * ss, im.height * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    cx = GATE_CX * ss
    base_y = GATE_BASE_Y * ss
    top_y = GATE_TOP_Y * ss
    h = base_y - top_y

    # 1) 外围紫色辉光 halo（大椭圆高斯模糊，先画、被门体压住中心）
    halo = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    for i, (rw, rh, a) in enumerate([(64, 130, 26), (44, 96, 40), (28, 64, 55)]):
        hd.ellipse([cx - rw*ss, base_y - rh*ss*0.62 - rh*ss*0.38, cx + rw*ss, base_y + rh*ss*0.38],
                   fill=(150, 100, 230, a))
    halo = halo.filter(ImageFilter.GaussianBlur(18 * ss))
    layer = Image.alpha_composite(layer, halo)
    d = ImageDraw.Draw(layer)

    # 2) 门体（裂缝形：下宽上尖、边缘扰动）+ 内芯紫光竖条
    steps = 160
    poly_left, poly_right, core_left, core_right = [], [], [], []
    for i in range(steps + 1):
        t = i / steps
        y = base_y - h * t
        half_w = (W_BOTTOM + (W_TOP - W_BOTTOM) * (t ** 0.85)) / 2.0 * ss
        wob = _crack_edge(t, rng, 3.2 * ss)
        poly_left.append((cx - half_w + wob, y))
        poly_right.append((cx + half_w + wob * 0.7, y))
        core_half = half_w * 0.32
        core_left.append((cx - core_half + wob * 0.5, y))
        core_right.append((cx + core_half + wob * 0.35, y))

    body_poly = poly_left + list(reversed(poly_right))
    d.polygon(body_poly, fill=(10, 12, 22, 235))          # 近黑蓝门体
    core_poly = core_left + list(reversed(core_right))
    d.polygon(core_poly, fill=(165, 110, 245, 150))        # 内芯紫光

    # 3) 门体上段雾罩（距离感）：白色 alpha 随高度渐增
    mist = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    md = ImageDraw.Draw(mist)
    for i in range(steps + 1):
        t = i / steps
        y = base_y - h * t
        if t < 0.35:
            continue
        a = int(90 * ((t - 0.35) / 0.65) ** 1.4)
        half_w = (W_BOTTOM + (W_TOP - W_BOTTOM) * (t ** 0.85)) / 2.0 * ss + 2 * ss
        md.line([(cx - half_w, y), (cx + half_w, y)], fill=(205, 210, 220, a))
    mist = mist.filter(ImageFilter.GaussianBlur(3 * ss))
    layer = Image.alpha_composite(layer, mist)

    # 4) 底部雪地紫晕反光（接地椭圆，糊开）
    glow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([cx - 52*ss, base_y - 8*ss, cx + 52*ss, base_y + 16*ss], fill=(140, 95, 220, 46))
    glow = glow.filter(ImageFilter.GaussianBlur(10 * ss))
    layer = Image.alpha_composite(layer, glow)

    layer = layer.resize((im.width, im.height), Image.LANCZOS)
    layer = layer.filter(ImageFilter.GaussianBlur(0.6))    # 远景空气感
    return Image.alpha_composite(im.convert("RGBA"), layer).convert("RGB")


def main() -> None:
    im = Image.open(SRC).convert("RGB")
    out = draw_gate(erase_gate(im))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT)
    # 对比图
    cmp_img = Image.new("RGB", (im.width, im.height * 2 + 8), (30, 30, 30))
    cmp_img.paste(im, (0, 0))
    cmp_img.paste(out, (0, im.height + 8))
    cmp_img.save(CMP)
    # 备份 + 替换
    os.makedirs(os.path.dirname(BAK), exist_ok=True)
    im.save(BAK)
    out.save(SRC)
    print("OK v38 ->", OUT)
    print("compare ->", CMP)
    print("backup v37 ->", BAK)


if __name__ == "__main__":
    main()
