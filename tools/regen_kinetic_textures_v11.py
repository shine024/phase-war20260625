#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v11 动能命中贴图重生 —— 解决"火花读成圆点"的根本问题。

根因(实测):旧 spark_metal 在 32px 画布上 streak 仅 3px 高,显示缩放后变亚像素 →
读成圆点。impact_metal 是均匀圆斑,缺星芒。本次用 PIL 程序化生成【更大、更亮、更厚】
的精确热条纹 + 星芒爆点(可控制,无 API 抖动)。

输出(覆盖 assets/effects/particle_textures/):
  spark_metal.png   64x64 横向锥形热条纹(白热核→金黄→橙尖,清晰可见的细长火花)
  impact_metal.png  64x64 六角星芒爆点(白热中心+锐利尖刺,命中瞬时闪光锚)
  impact_scorch.png 48x48 弹痕锚点(暗凹陷中心+放射刮擦线+焦黑环)——持久贴在命中点

原件备份到 particle_textures_backup_v11/。生成后需在 Godot 重导(编辑器会自动)。
"""
import os
import math
import random
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "assets", "effects", "particle_textures")
BACKUP = os.path.join(DIR, "particle_textures_backup_v11")
SIZE = 64
CX = CY = SIZE / 2.0


def backup(names):
    os.makedirs(BACKUP, exist_ok=True)
    for n in names:
        src = os.path.join(DIR, n + ".png")
        if os.path.exists(src):
            dst = os.path.join(BACKUP, n + ".png")
            if not os.path.exists(dst):
                Image.open(src).save(dst)


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def lerp(a, b, t):
    return a + (b - a) * t


def lerp_color(c1, c2, t):
    return tuple(lerp(c1[i], c2[i], t) for i in range(3))


def spark_streak():
    """横向锥形热条纹:中心白热,向两端过渡到金黄→橙,厚度中间粗两端尖。"""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    random.seed(1337)
    x0, x1 = 6, 58           # 条纹横向范围(52px 长)
    half_len = (x1 - x0) / 2.0
    # 沿 x 的色温:中心最热(白),向外金黄,尖端橙
    def color_along(frac):  # frac 0..1, 0.5=中心
        d = abs(frac - 0.5) * 2.0  # 0 中心 .. 1 尖端
        if d < 0.18:        # 白热核
            return (255, 252, 235)
        if d < 0.45:        # 亮黄白
            t = (d - 0.18) / 0.27
            return lerp_color((255, 252, 235), (255, 215, 110), t)
        if d < 0.78:        # 金黄
            t = (d - 0.45) / 0.33
            return lerp_color((255, 215, 110), (255, 150, 40), t)
        return lerp_color((255, 150, 40), (220, 90, 20), clamp((d - 0.78) / 0.22, 0, 1))
    for x in range(x0, x1 + 1):
        frac = (x - x0) / (x1 - x0)
        d = abs(frac - 0.5) * 2.0
        # 厚度:中心 sigma~3.4,尖端 sigma~0.9(v11b:更细长,aspect~5,读起来更像火花条而非圆点)
        sigma = lerp(3.4, 0.9, d ** 1.3)
        base = color_along(frac)
        # 亮度峰值(中心更亮,用于 alpha 与 RGB 提亮)
        bright = 1.0 - d * 0.55
        for y in range(SIZE):
            dy = y - CY
            g = math.exp(-(dy * dy) / (2 * sigma * sigma))
            if g < 0.04:
                continue
            # 轻微噪声让边缘不规则(熔融金属感)
            n = 1.0 + random.uniform(-0.10, 0.10)
            r = clamp(int(base[0] * bright * n), 0, 255)
            gg = clamp(int(base[1] * bright * n), 0, 255)
            b = clamp(int(base[2] * bright * n), 0, 255)
            a = clamp(int(255 * g * (0.85 if d < 0.8 else (1.0 - d) * 2.0)), 0, 255)
            px[x, y] = (r, gg, b, a)
    return img


def impact_star():
    """六角星芒爆点:白热中心圆 + 6 条锐利尖刺向外渐淡(命中瞬时闪光锚)。"""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    # 先画中心热核(径向)
    core_r = 7.0
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x - CX, y - CY
            dist = math.hypot(dx, dy)
            if dist < core_r + 6:
                # 中心白热→金黄
                t = clamp(dist / (core_r + 6), 0, 1)
                col = lerp_color((255, 253, 240), (255, 190, 70), t ** 1.5)
                g = math.exp(-(dist / (core_r * 0.9)) ** 2)
                a = clamp(int(255 * g), 0, 255)
                if a > 8:
                    px[x, y] = (clamp(int(col[0]), 0, 255), clamp(int(col[1]), 0, 255),
                                clamp(int(col[2]), 0, 255), a)
    # 6 条尖刺(从中心向 6 个方向)
    spikes = 6
    spike_len = 27.0
    for s in range(spikes):
        ang = s * (math.tau / spikes) + math.radians(0)
        ux, uy = math.cos(ang), math.sin(ang)
        # 沿尖刺长度累绘
        for step in range(1, int(spike_len)):
            t = step / spike_len  # 0 近端 .. 1 尖端
            cxp = CX + ux * step
            cyp = CY + uy * step
            # 尖刺宽度近端粗尖端细
            w = lerp(2.6, 0.6, t)
            col = lerp_color((255, 230, 150), (255, 120, 30), t)
            alpha = clamp(int(255 * (1.0 - t) ** 1.4), 0, 255)
            for oy in range(-3, 4):
                for ox in range(-3, 4):
                    # 垂直尖刺方向的距离
                    px_x = cxp + ox
                    px_y = cyp + oy
                    if 0 <= px_x < SIZE and 0 <= px_y < SIZE:
                        perp = abs(-uy * (px_x - cxp) + ux * (px_y - cyp))
                        if perp <= w:
                            falloff = math.exp(-(perp / max(w * 0.6, 0.4)) ** 2)
                            a = clamp(int(alpha * falloff), 0, 255)
                            if a > 8:
                                cur = px[px_x, px_y]
                                # 叠加(取更亮)
                                if a > cur[3]:
                                    px[px_x, px_y] = (clamp(int(col[0]), 0, 255),
                                                       clamp(int(col[1]), 0, 255),
                                                       clamp(int(col[2]), 0, 255), a)
    return img


def impact_scorch():
    """弹痕锚点贴图:中心暗凹陷 + 暗金属刮擦线辐射 + 外圈焦黑环 + 中心余热暗红。
    持久贴在命中点,给"打中了"明确的视觉定位(报告反复要求的'弹孔/凹陷视觉锚点')。"""
    S = 48
    cx = cy = S / 2.0
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = img.load()
    random.seed(99)
    # 外圈焦黑环 + 中心凹陷
    for y in range(S):
        for x in range(S):
            dist = math.hypot(x - cx, y - cy)
            if dist < 16:
                # 中心凹陷:最暗(近黑)+ 边缘略亮金属高光
                t = dist / 16.0
                if dist < 4.5:
                    # 弹孔中心:深黑 + 极暗红余热
                    heat = (4.5 - dist) / 4.5
                    r = int(60 + heat * 90)
                    g = int(25 + heat * 25)
                    b = int(15 + heat * 10)
                    a = 235
                else:
                    # 焦黑环:深棕黑
                    r = int(45 - t * 15)
                    g = int(38 - t * 13)
                    b = int(33 - t * 11)
                    a = int(210 - t * 60)
                px[x, y] = (max(0, r), max(0, g), max(0, b), max(0, a))
    # 放射刮擦线(6-7 条暗线从中心向外)
    nscr = 7
    for i in range(nscr):
        ang = i * (math.tau / nscr) + random.uniform(-0.2, 0.2)
        length = random.uniform(15, 21)
        ux, uy = math.cos(ang), math.sin(ang)
        for step in range(3, int(length)):
            t = step / length
            sx = cx + ux * step
            sy = cy + uy * step
            # 刮擦线带轻微金属高光(暗灰 + 偶尔亮线)
            bright = random.random() < 0.25
            col = (160, 150, 135, 180) if bright else (70, 62, 55, 150)
            alpha = int(col[3] * (1.0 - t * 0.8))
            for oy in range(-1, 2):
                for ox in range(-1, 2):
                    px_x = int(sx + ox); px_y = int(sy + oy)
                    if 0 <= px_x < S and 0 <= px_y < S:
                        if random.random() < 0.55:
                            cur = px[px_x, px_y]
                            if alpha > cur[3] - 40:
                                px[px_x, px_y] = (col[0], col[1], col[2], max(alpha, cur[3] // 3))
    return img


def main():
    names = ["spark_metal", "impact_metal", "impact_scorch"]
    backup(names)
    print("备份 ->", BACKUP)
    spark_streak().save(os.path.join(DIR, "spark_metal.png"))
    print("[OK] spark_metal.png  (64x64 锥形热条纹)")
    impact_star().save(os.path.join(DIR, "impact_metal.png"))
    print("[OK] impact_metal.png (64x64 六角星芒爆点)")
    impact_scorch().save(os.path.join(DIR, "impact_scorch.png"))
    print("[OK] impact_scorch.png (48x48 弹痕锚点)")
    # 自检:报告亮区 bbox/aspect
    import numpy as np
    for n in names:
        im = Image.open(os.path.join(DIR, n + ".png")).convert("RGBA")
        a = np.array(im); al = a[:, :, 3]
        ys, xs = np.where(al > 30)
        if len(xs):
            print("  %s: bbox=%dx%d aspect=%.1f bright_core=%d" % (
                n, xs.max() - xs.min(), ys.max() - ys.min(),
                (xs.max() - xs.min()) / max(ys.max() - ys.min(), 1),
                int(((a[:, :, :3].max(axis=2) > 200) & (al > 200)).sum())))


if __name__ == "__main__":
    main()
