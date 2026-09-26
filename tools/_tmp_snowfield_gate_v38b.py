# -*- coding: utf-8 -*-
"""记录5#1 v38b: 雪原黑门重画（v38a 失败返工——擦除复用 v37 验证版 erase_gate，
门体改实心裂缝+强紫芯，弱雾罩）。

用法: 从 _art_backup 恢复 v37 原图后跑本脚本。
产出: assets/intro/wakeup_snowfield.png（直接替换）
"""
import os, sys, math, random, importlib.util

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BAK = os.path.join(ROOT, "assets", "intro", "_art_backup", "wakeup_snowfield_v37_20260924.png")
SRC = os.path.join(ROOT, "assets", "intro", "wakeup_snowfield.png")
OUT = os.path.join(ROOT, ".godot", "art_regen", "wakeup_snowfield_v38b.png")

# 挂 v37 脚本模块，复用其 erase_gate（左源克隆+噪声+羽化+低频亮度校正，实测无台阶）
spec = importlib.util.spec_from_file_location(
    "pushfar", os.path.join(ROOT, "tools", "_tmp_snowfield_gate_pushfar.py"))
pushfar = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pushfar)

GATE_CX = 958
GATE_BASE_Y = 410
GATE_TOP_Y = 314            # 高 96px ≈ 13.3%
W_BOTTOM = 30               # 底宽（实心裂缝，下宽上尖）
W_TOP = 6


def draw_gate(im: "Image.Image") -> "Image.Image":
    from PIL import Image, ImageDraw, ImageFilter
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

    # 1) 紫色辉光 halo（两层，先画）
    halo = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    mid_y = base_y - h * 0.42
    hd.ellipse([cx - 70*ss, mid_y - 95*ss, cx + 70*ss, base_y + 18*ss], fill=(140, 92, 225, 60))
    hd.ellipse([cx - 42*ss, mid_y - 70*ss, cx + 42*ss, base_y + 10*ss], fill=(155, 105, 240, 85))
    halo = halo.filter(ImageFilter.GaussianBlur(16 * ss))
    layer = Image.alpha_composite(layer, halo)

    # 2) 门体（实心近黑蓝裂缝）+ 内芯紫光
    body = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    core = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    cd = ImageDraw.Draw(core)
    for i in range(steps):
        t0, t1 = i / steps, (i + 1) / steps
        y0, y1 = base_y - h * t0, base_y - h * t1
        w0, w1 = half_w(t0), half_w(t1)
        x0a = cx - w0 + edge_wob(t0)
        x0b = cx + w0 + edge_wob(t0) * 0.7
        x1a = cx - w1 + edge_wob(t1)
        x1b = cx + w1 + edge_wob(t1) * 0.7
        bd.polygon([(x0a, y0), (x0b, y0), (x1b, y1), (x1a, y1)], fill=(16, 18, 32, 242))
        # 紫芯：中央 45%，底部亮顶部收
        ca = w0 * 0.45
        cb = w1 * 0.45
        glow_a = int(90 + 110 * (1.0 - t0))    # 底部 alpha≈200 → 顶部≈90
        cd.polygon([(cx - ca + edge_wob(t0)*0.5, y0), (cx + ca + edge_wob(t0)*0.4, y0),
                    (cx + cb + edge_wob(t1)*0.35, y1), (cx - cb + edge_wob(t1)*0.4, y1)],
                   fill=(168, 112, 250, glow_a))
    body = body.filter(ImageFilter.GaussianBlur(0.8 * ss))
    layer = Image.alpha_composite(layer, body)
    core = core.filter(ImageFilter.GaussianBlur(1.2 * ss))
    layer = Image.alpha_composite(layer, core)

    # 3) 仅顶段轻雾（距离感但不洗白）：顶部 30% 白 alpha ≤55 渐变
    mist = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    md = ImageDraw.Draw(mist)
    for i in range(steps + 1):
        t = i / steps
        if t < 0.70:
            continue
        y = base_y - h * t
        a = int(55 * ((t - 0.70) / 0.30) ** 1.2)
        w = half_w(t) + 2 * ss
        md.line([(cx - w, y), (cx + w, y)], fill=(205, 212, 225, a))
    mist = mist.filter(ImageFilter.GaussianBlur(2 * ss))
    layer = Image.alpha_composite(layer, mist)

    # 4) 底部雪地紫晕
    glow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([cx - 58*ss, base_y - 7*ss, cx + 58*ss, base_y + 17*ss], fill=(150, 100, 235, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(9 * ss))
    layer = Image.alpha_composite(layer, glow)

    layer = layer.resize((im.width, im.height), Image.LANCZOS)
    layer = layer.filter(ImageFilter.GaussianBlur(0.5))
    return Image.alpha_composite(im.convert("RGBA"), layer).convert("RGB")


def main() -> None:
    from PIL import Image
    im = Image.open(BAK).convert("RGB")     # 从 v37 备份出发（撤销 v38a 的坏补丁）
    # v38c: 不擦除——新门体(底宽30)完整盖住 v37 旧柱(x956-967)，零补丁带
    # im = pushfar.erase_gate(im)
    out = draw_gate(im)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT)
    out.save(SRC)
    cmp_img = Image.new("RGB", (im.width, im.height * 2 + 8), (30, 30, 30))
    cmp_img.paste(im, (0, 0))
    cmp_img.paste(out, (0, im.height + 8))
    cmp_img.save(os.path.join(ROOT, ".godot", "art_regen", "wakeup_snowfield_v38b_compare.png"))
    print("OK v38b ->", OUT)


if __name__ == "__main__":
    main()
