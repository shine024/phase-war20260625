# -*- coding: utf-8 -*-
"""v37 实机验收三轮：雪原黑门"还是太近"——PIL 局部改图压远压小（不重生成）。

v37 版 agnes 生图虽已按 prompt"高度只占画面很小一部分"生成，实测门仍占画面高 ~40%
（~290px）、近纯黑高对比，距离感不足。且整图重生成会连带改变基地车（v37 按
truck_tier1 特征锁定，不能变）。门是宽仅 3-4% 的细长纯色剪影、背景为平缓云雾
→ 本工具走局部改图：擦旧门（横向插值修补）+ 重画极远小剪影（深蓝灰低对比 +
雾化渐隐）。产出对比图供人工过目，确认后替换 assets/intro/wakeup_snowfield.png
并跑 --headless --editor --quit 重导入。
"""
from PIL import Image, ImageDraw, ImageFilter
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "intro", "wakeup_snowfield.png")
OUT_DIR = os.path.join(ROOT, ".godot", "art_regen")

# 擦除区（原图实测：门体 x≈935-985，接地阴影扩到 x 915-1014 / y 到 ~415；
# y>430 的暗点是雪地自然脏点，克隆源同款存在，不追）
ERASE_BOX = (910, 100, 1016, 472)

# 新门参数：极远地平线小剪影
GATE_CX = 962          # 水平中心（75% 处，与车拉开横向距离）
GATE_BASE_Y = 411      # 底部贴地平线下沿（地平线 55-58% ≈ 396-418）
GATE_H = 46            # 高度 ≈ 画面高 6.4%（旧 290px 的 ~1/6）
GATE_W = 11            # 宽度 ≪ 画面宽 1%


def detect_gate_bbox(im: Image.Image) -> tuple:
    """右侧 40% 区域找近纯黑像素 bbox（自动核对 ERASE_BOX 是否套准）。

    注：x≈768 起的近黑像素是地平线远处树丛碎点（不是门），不纳入擦除目标。
    """
    px = im.convert("RGB")
    w, h = px.size
    xs, ys = [], []
    for y in range(60, 480, 2):
        for x in range(int(w * 0.60), w, 2):
            r, g, b = px.getpixel((x, y))
            if r < 50 and g < 50 and b < 55:
                xs.append(x)
                ys.append(y)
    if not xs:
        return ()
    return (min(xs), min(ys), max(xs), max(ys))


def erase_gate(im: Image.Image) -> Image.Image:
    """单一左源平移克隆：紧邻左侧等宽条带整体右移填入擦除区（云纹理连续、
    无镜像对称伪影、无左右混合浑浊感）；仅右接缝做窄窗 cross-fade 消台阶。"""
    import random
    x0, y0, x1, y1 = ERASE_BOX
    y1 = min(y1, im.height)
    w_src = x1 - x0
    src = im.crop((x0 - w_src - 4, y0, x0 - 4, y1))
    right_src = im.crop((x1 + 4, y0, x1 + w_src + 4, y1))
    rng = random.Random(42)
    fill = src.copy()
    fpx = fill.load()
    rpx = right_src.load()
    for y in range(fill.height):
        for x in range(fill.width):
            r0, g0, b0 = fpx[x, y]
            n = rng.uniform(-1.5, 1.5)
            if x > fill.width - 16:            # 右接缝窄窗渐变到右侧原背景
                t = (x - (fill.width - 16)) / 16.0
                t = t * t * (3 - 2 * t)
                r0 = r0 * (1 - t) + rpx[x, y][0] * t
                g0 = g0 * (1 - t) + rpx[x, y][1] * t
                b0 = b0 * (1 - t) + rpx[x, y][2] * t
            fpx[x, y] = (int(max(0, min(255, r0 + n))),
                         int(max(0, min(255, g0 + n))),
                         int(max(0, min(255, b0 + n))))
    fill = fill.filter(ImageFilter.GaussianBlur(0.5))
    # 羽化 mask：上边接云羽化 12px；左右仅天空段（y<400）羽化——雪地段不羽化，
    # 防旧门接地阴影从低 alpha 边缘透回；下边满值（克隆源同为雪地自然纹理）
    mask = Image.new("L", fill.size, 255)
    mpx = mask.load()
    edge = 12
    for y in range(fill.height):
        for x in range(fill.width):
            a = 1.0
            if y < edge:
                a = min(a, y / edge)
            if y < 300:                      # 天空段左右羽化
                if x < edge:
                    a = min(a, x / edge)
                if fill.width - 1 - x < edge:
                    a = min(a, (fill.width - 1 - x) / edge)
            mpx[x, y] = int(255 * a)
    im.paste(fill, (x0, y0), mask)
    # 低频亮度梯度校正：克隆内容基准偏左侧云，与右侧云有 ~10 灰度台阶——
    # 逐行把擦除区亮度基线对齐"左邻区→右邻区"线性过渡（保纹理，只修台阶）
    px2 = im.load()
    for y in range(y0, min(y0 + 300, y1)):          # 仅天空段（雪地段已实测无台阶）
        la = sum(sum(px2[x, y]) / 3 for x in range(x0 - 58, x0 - 8)) / 50
        rb = sum(sum(px2[x, y]) / 3 for x in range(x1 + 8, x1 + 58)) / 50
        for x in range(x0, x1):
            t = (x - x0) / max(1, x1 - 1 - x0)
            t = t * t * (3 - 2 * t)
            target = la + (rb - la) * t
            cur = sum(px2[x, y]) / 3
            if cur < 1:
                continue
            g = min(1.10, max(0.92, target / cur))
            # 左右端平滑淡入淡出，防新台阶
            g = 1.0 + (g - 1.0) * min(1.0, min((x - x0) / 25.0, (x1 - 1 - x) / 25.0))
            r0, g0, b0 = px2[x, y]
            px2[x, y] = (int(min(255, r0 * g)), int(min(255, g0 * g)), int(min(255, b0 * g)))
    return im


def draw_far_gate(im: Image.Image) -> Image.Image:
    """重画极远小门：深蓝灰（非纯黑）、顶部略淡（大气透视）、底部渐隐进地平线雾。"""
    top_y = GATE_BASE_Y - GATE_H
    cx = GATE_CX
    hw = GATE_W // 2
    # 颜色基调：与冷蓝灰云雾同色系、低对比（比纯黑亮 3 倍，读作远物）
    base = (70, 76, 88)
    px = im.load()
    for y in range(top_y, GATE_BASE_Y + 1):
        t = (y - top_y) / max(1, GATE_H)          # 0=顶 1=底
        fade_top = 0.42 + 0.58 * min(1.0, t * 2.2)   # 顶部淡入（远景大气）
        fade_bot = 1.0 if t < 0.60 else max(0.0, 1.0 - (t - 0.60) / 0.40)  # 底部 40% 被雾吞
        # 方尖形：顶窄底宽
        wrow = max(1, int(round(hw * (0.45 + 0.55 * t))))
        for x in range(cx - wrow, cx + wrow + 1):
            a = fade_top * fade_bot
            r0, g0, b0 = px[x, y]
            r = r0 + (base[0] - r0) * a
            g = g0 + (base[1] - g0) * a
            b = b0 + (base[2] - b0) * a
            px[x, y] = (int(r), int(g), int(b))
    # 整体柔化：门区高斯模糊，边缘与雾融合（远物无硬轮廓）
    region = im.crop((cx - hw - 4, top_y - 4, cx + hw + 5, GATE_BASE_Y + 5))
    region = region.filter(ImageFilter.GaussianBlur(1.4))
    im.paste(region, (cx - hw - 4, top_y - 4))
    return im


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    src = Image.open(SRC).convert("RGB")
    bbox = detect_gate_bbox(src)
    print("detected near-black bbox:", bbox if bbox else "NONE (fallback to ERASE_BOX)")
    if bbox:
        b = bbox
        print("ERASE_BOX covers detect:", b[0] >= ERASE_BOX[0] and b[1] >= ERASE_BOX[1]
              and b[2] <= ERASE_BOX[2] and b[3] <= ERASE_BOX[3])

    im = src.copy()
    im = erase_gate(im)
    im = draw_far_gate(im)

    out_path = os.path.join(OUT_DIR, "snowfield_v3_gatefar_1280x720.png")
    im.save(out_path)
    print("saved:", out_path)

    # 对比图：上=原版 下=改后
    cmp_im = Image.new("RGB", (1280, 720 * 2 + 8), (20, 20, 24))
    cmp_im.paste(src, (0, 0))
    cmp_im.paste(im, (0, 728))
    cmp_path = os.path.join(OUT_DIR, "snowfield_v3_compare.png")
    cmp_im.save(cmp_path)
    print("compare:", cmp_path)

    # 门区放大对比（细节核验用）
    zoom = 4
    zx, zy, zw, zh = 880, 80, 340, 380
    z = Image.new("RGB", (zw * zoom, zh * zoom * 2 + 6), (20, 20, 24))
    z.paste(src.crop((zx, zy, zx + zw, zy + zh)).resize((zw * zoom, zh * zoom), Image.NEAREST), (0, 0))
    z.paste(im.crop((zx, zy, zx + zw, zy + zh)).resize((zw * zoom, zh * zoom), Image.NEAREST), (0, zh * zoom + 6))
    z_path = os.path.join(OUT_DIR, "snowfield_v3_gatefar_zoom.png")
    z.save(z_path)
    print("zoom:", z_path)


if __name__ == "__main__":
    main()
