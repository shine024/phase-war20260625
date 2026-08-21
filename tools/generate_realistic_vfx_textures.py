#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
v18-R9 摄影感粒子贴图生成（numpy 距离场 + 值噪声 + 黑体色序）
================================================================
用户感知否决：火星/火花/火焰/金属碎片"假"。病根不是形状选择（v17e 棱角已被否决，
v9.2 软圆也素），而是【几何形状没有摄影感】——纯楔形/锥形边缘太规则、色温太线性。
真实感三要素（本生成器核心）：
  1. 黑体辐射色序：白热(255,255,245)→亮黄→橙→深橙红→暗红，非线性幂衰减
  2. 值噪声边缘：多倍频 value-noise 扰动距离场，边缘不再"矢量图形般"规则
  3. 簇状结构：火花=多颗熔滴聚簇；碎块=多块暗金属，不是单一"大形状"
产物（assets/effects/particle_textures/，全为新文件名，旧贴图保留兼容）：
  spark_drop.png    128×128  簇状熔融金属滴（命中火花/火星）
  metal_chunk.png   128×128  暗金属碎块簇（爆炸破片——大部分暗色+局部炽热边）
  flame_puff.png    160×96   火焰团（枪口/爆炸火焰粒子）
  flame_jet_v2.png  160×56   方向性火舌（对称±X，重型枪口）
生成后打印内容 bbox（消费方按实寸标定 scale 的依据）。
"""
import os
import numpy as np
from PIL import Image, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "effects", "particle_textures")

RNG = np.random.default_rng(20260819)


def value_noise(w, h, octaves=(4, 8, 16), amp=(0.5, 0.3, 0.2), seed=0):
    """多倍频值噪声 [0,1]——小随机阵上采样+模糊叠加（无 scipy 依赖的简易 Perlin 替代）"""
    rng = np.random.default_rng(seed)
    total = np.zeros((h, w), dtype=np.float64)
    norm = 0.0
    for i, cells in enumerate(octaves):
        small = rng.random((cells, cells))
        im = Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR)
        arr = np.asarray(im, dtype=np.float64) / 255.0
        total += arr * amp[i]
        norm += amp[i]
    return total / norm


def blob_field(w, h, cx, cy, rx, ry, power, noise, noise_seed, rot=0.0):
    """噪声扰动的椭圆距离场 → [0,1] 强度（1=核，0=外缘）"""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    x = (xx - cx) * np.cos(rot) + (yy - cy) * np.sin(rot)
    y = -(xx - cx) * np.sin(rot) + (yy - cy) * np.cos(rot)
    d = np.sqrt((x / rx) ** 2 + (y / ry) ** 2)
    if noise > 0:
        n = value_noise(w, h, seed=noise_seed)
        d = d * (1.0 + (n - 0.5) * 2.0 * noise)
    return np.clip(1.0 - d, 0.0, 1.0) ** power


def blackbody(t):
    """黑体色序插值。t: 0=白热核 → 1=暗红边缘。返回 RGB [0,255]"""
    stops = np.array([
        (255, 255, 248),  # 白热
        (255, 243, 195),  # 亮黄
        (255, 196, 92),   # 金橙
        (255, 128, 38),   # 橙
        (216, 62, 18),    # 深橙红
        (142, 30, 10),    # 暗红
    ], dtype=np.float64)
    n = len(stops) - 1
    f = np.clip(t, 0, 1) * n
    i = np.minimum(f.astype(int), n - 1)
    frac = (f - i)[..., None] if isinstance(t, np.ndarray) else (f - i)
    if isinstance(t, np.ndarray):
        return stops[i] * (1 - frac) + stops[i + 1] * frac
    return stops[i] * (1 - frac) + stops[i + 1] * frac


def tint(color_rgb, field, extra_alpha=None):
    """强度场 → RGBA 图层。color_rgb: (H,W,3) 或 tuple；field: (H,W)"""
    h, w = field.shape
    if np.isscalar(color_rgb) or isinstance(color_rgb, tuple):
        col = np.zeros((h, w, 3), dtype=np.float64)
        col[..., 0], col[..., 1], col[..., 2] = color_rgb
    else:
        col = color_rgb
    a = field if extra_alpha is None else field * extra_alpha
    layer = np.zeros((h, w, 4), dtype=np.float64)
    layer[..., :3] = col
    layer[..., 3] = a
    return layer


def composite(base, layer, mode="screen"):
    """ premultiplied 风格叠加：亮度取 max/相加，alpha 相加裁剪"""
    a = np.clip(layer[..., 3:4], 0, 1)
    if mode == "screen":
        rgb = np.maximum(base[..., :3] * (1 - a), layer[..., :3] * a)
        # 亮部相加提过曝（白热核 >255 裁剪）
        rgb = np.minimum(rgb + layer[..., :3] * a * 0.5, 255)
    else:
        rgb = base[..., :3] * (1 - a) + layer[..., :3] * a
    alpha = np.clip(base[..., 3:4] + a, 0, 1)
    out = np.zeros_like(base)
    out[..., :3] = rgb * (alpha > 0)  # 避免透明区留残色
    out[..., 3] = alpha[..., 0]  # (H,W,1) → (H,W) 广播赋值
    return out


def to_image(arr, blur=0.6):
    out = np.zeros_like(arr)
    out[..., :3] = np.clip(arr[..., :3], 0, 255)       # RGB 0-255
    out[..., 3] = np.clip(arr[..., 3] * 255.0, 0, 255) # alpha 0-1 → 0-255
    img = Image.fromarray(out.astype(np.uint8), "RGBA")
    if blur > 0:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    return img


# ── 1. spark_drop：簇状熔融金属滴（4-6 颗，随机大小/拉长/亮度）──
def gen_spark_drop():
    W, H = 128, 128
    canvas = np.zeros((H, W, 4), dtype=np.float64)
    rng = np.random.default_rng(41)
    n_drops = 5
    # 主滴居中偏右（粒子质心稳定），其余环绕
    specs = [(64, 64, 14, 10, 0.0)]  # cx, cy, rx, ry, rot
    for i in range(n_drops - 1):
        ang = rng.uniform(0, np.pi * 2)
        dist = rng.uniform(18, 42)
        r = rng.uniform(4, 9)
        specs.append((64 + np.cos(ang) * dist, 64 + np.sin(ang) * dist,
                      r * rng.uniform(1.0, 1.9), r, rng.uniform(-0.6, 0.6)))
    for k, (cx, cy, rx, ry, rot) in enumerate(specs):
        f = blob_field(W, H, cx, cy, rx, ry, 1.6, 0.55, noise_seed=100 + k, rot=rot)
        # 黑体渐变：t 随强度反向（核=白热）
        t = 1.0 - f
        col = blackbody(np.clip(t * 1.35, 0, 1))
        # 核心提亮到近白
        core = blob_field(W, H, cx, cy, rx * 0.35, ry * 0.35, 1.0, 0.3, noise_seed=200 + k, rot=rot)
        col = col * (1 - core[..., None]) + np.array([255, 255, 252]) * core[..., None]
        canvas = composite(canvas, tint(col, np.clip(f * 1.6, 0, 1)))
    to_image(canvas, 0.4).save(os.path.join(OUT, "spark_drop.png"))


# ── 2. metal_chunk：暗金属碎块簇（2-3 块暗色 + 受光面 + 局部炽热边）──
def gen_metal_chunk():
    W, H = 128, 128
    rng = np.random.default_rng(77)
    canvas = np.zeros((H, W, 4), dtype=np.float64)
    specs = [
        (56, 60, 34, 24, 0.3),
        (88, 80, 18, 14, -0.5),
        (44, 92, 12, 9, 0.9),
    ]
    for k, (cx, cy, rx, ry, rot) in enumerate(specs):
        # 块体：暗钢蓝灰，边缘噪声强（碎裂不规则）
        body = blob_field(W, H, cx, cy, rx, ry, 2.2, 0.7, noise_seed=300 + k, rot=rot)
        base_col = np.array([64, 70, 82], dtype=np.float64)
        # 受光面（左上偏移的次级椭圆，更亮的中性灰）
        lit = blob_field(W, H, cx - rx * 0.3, cy - ry * 0.35, rx * 0.6, ry * 0.55,
                         1.5, 0.5, noise_seed=400 + k, rot=rot)
        lit_col = np.array([132, 140, 155], dtype=np.float64)
        col = base_col[None, None, :] * (1 - lit[..., None]) + lit_col[None, None, :] * lit[..., None]
        # 炽热边：边缘薄层（body 的中等强度带）混入橙红——刚从爆炸撕下的高温断面
        edge = np.clip(body - blob_field(W, H, cx, cy, rx * 0.72, ry * 0.72, 2.0, 0.5,
                                         noise_seed=500 + k, rot=rot), 0, 1)
        hot = np.array([255, 150, 60], dtype=np.float64)
        col = col * (1 - edge[..., None] * 0.8) + hot[None, None, :] * edge[..., None] * 0.8
        # 高光闪烁点
        gx, gy = cx - rx * 0.2, cy - ry * 0.25
        glint = blob_field(W, H, gx, gy, 2.5, 2.0, 1.0, 0.0, noise_seed=1, rot=0)
        col = col * (1 - glint[..., None]) + np.array([225, 232, 245])[None, None, :] * glint[..., None]
        canvas = composite(canvas, tint(col, np.clip(body * 1.3, 0, 1)), mode="normal")
    to_image(canvas, 0.35).save(os.path.join(OUT, "metal_chunk.png"))


# ── 3. flame_puff：火焰团（多层黑体渐变 + 强噪声边缘，用于枪口/爆炸火焰粒子）──
def gen_flame_puff():
    W, H = 160, 96
    canvas = np.zeros((H, W, 4), dtype=np.float64)
    layers = [
        # (cx, cy, rx, ry, power, noise, t_scale) 由外到内
        (80, 52, 74, 42, 1.5, 0.55, 1.00),  # 外焰暗红
        (80, 50, 60, 33, 1.5, 0.48, 0.78),
        (78, 48, 44, 25, 1.4, 0.40, 0.52),  # 中焰橙
        (76, 47, 30, 17, 1.4, 0.35, 0.30),
        (75, 46, 18, 10, 1.3, 0.28, 0.12),   # 内焰亮黄
        (74, 46, 10, 5.5, 1.3, 0.22, 0.00),  # 白热核
    ]
    for k, (cx, cy, rx, ry, pw, nz, ts) in enumerate(layers):
        f = blob_field(W, H, cx, cy, rx, ry, pw, nz, noise_seed=600 + k)
        t = np.clip((1.0 - f) * ts + ts * 0.15, 0, 1)
        col = blackbody(t)
        canvas = composite(canvas, tint(col, np.clip(f * 1.5, 0, 1)))
    to_image(canvas, 0.7).save(os.path.join(OUT, "flame_puff.png"))


# ── 4. flame_jet_v2：方向性火舌（对称±X，噪声渐变替代三角楔）──
def gen_flame_jet_v2():
    W, H = 160, 56
    canvas = np.zeros((H, W, 4), dtype=np.float64)
    cy = H // 2
    # 双侧三层舌（由外到内），每层独立噪声
    for sgn in (1, -1):
        for k, (L, ry, pw, nz, ts) in enumerate([
                (76, 11, 1.8, 0.60, 1.00),
                (54, 15, 1.6, 0.48, 0.55),
                (32, 19, 1.5, 0.38, 0.22)]):
            # 椭圆长轴沿 X，中心外移让舌根在核心附近
            cx = 80 + sgn * (L * 0.55)
            f = blob_field(W, H, cx, cy, L * 0.62, ry, pw, nz, noise_seed=700 + k + (3 if sgn < 0 else 0))
            # 单侧裁剪（只保留发射方向一侧）+ 核心侧羽化
            side = np.clip(sgn * (np.arange(W)[None, :] - 76), 0, 1) ** 0.5
            f = f * side
            t = np.clip((1.0 - f) * ts, 0, 1)
            col = blackbody(t)
            canvas = composite(canvas, tint(col, np.clip(f * 1.6, 0, 1)))
    # 白热核（中心，双层）
    core = blob_field(W, H, 78, cy, 16, 12, 1.3, 0.22, noise_seed=60)
    canvas = composite(canvas, tint(np.array([255, 255, 250])[None, None, :].repeat(H, 0).repeat(W, 1),
                                    np.clip(core * 1.7, 0, 1)))
    to_image(canvas, 0.5).save(os.path.join(OUT, "flame_jet_v2.png"))


def report(name):
    im = Image.open(os.path.join(OUT, name))
    bbox = im.getbbox()
    print("%-20s canvas=%s content=%s" % (name, im.size, bbox))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    gen_spark_drop()
    gen_metal_chunk()
    gen_flame_puff()
    gen_flame_jet_v2()
    for n in ["spark_drop.png", "metal_chunk.png", "flame_puff.png", "flame_jet_v2.png"]:
        report(n)
    print("done →", OUT)

