"""程序化重生成爆炸帧（v2 密度场版）——修复 v1 两个缺陷：

v1 缺陷：
  1. 同心圆层叠 → "洋葱圈"几何感，无真实火焰的湍流形态
  2. 火星是小圆点 → 缩放数字化后呈菱柱形

v2 算法：
  火焰 = 随机高斯亮斑叠加密度场（中心大而密、外围小而疏，位置大小全随机），
        色彩由密度连续映射（白热核→亮橙→暗红→透明），密度场不规则 ⇒ 火焰形态
        不规则，天然无同心圆；帧间亮斑漂移 ⇒ 播放时有翻腾感。
  火星 = 径向流线（沿离心方向拉长的渐变条：头亮粗、尾暗细），像高速飞出的
        真实火花，杜绝任何颗粒/菱形感。
  烟尘 = 后期帧淡入的大尺度低密度灰斑，中心上移。
"""
import math
import os
import random

import numpy as np
from PIL import Image

out_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "assets", "effects", "explosion_frames")
SIZE = 256
HALF = SIZE // 2


def build_grid():
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    dx = x - HALF
    dy = y - HALF
    dist = np.sqrt(dx * dx + dy * dy)
    return dx, dy, dist


DX, DY, DIST = build_grid()


def add_blob(field, cx, cy, sigma, weight):
    """往密度场叠加一个高斯亮斑"""
    d2 = (DX - cx) ** 2 + (DY - cy) ** 2
    field += weight * np.exp(-d2 / (2.0 * sigma * sigma))


def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def density_to_color(density, is_energy):
    """密度 → RGBA。连续插值色带（无离散分层 ⇒ 无洋葱圈）"""
    # 色带锚点：密度 0 → 1.0+
    if is_energy:
        stops = [
            (0.00, (0, 0, 0, 0)),
            (0.10, (30, 60, 160, 60)),      # 淡蓝边缘
            (0.25, (60, 130, 235, 130)),    # 蓝
            (0.45, (120, 195, 255, 200)),   # 亮蓝
            (0.65, (200, 240, 255, 240)),   # 白青
            (1.00, (255, 255, 255, 255)),   # 白热核
        ]
    else:
        stops = [
            (0.00, (0, 0, 0, 0)),
            (0.10, (170, 45, 12, 55)),      # 暗红边缘
            (0.25, (225, 85, 20, 120)),     # 暗橙
            (0.45, (255, 150, 40, 190)),    # 橙
            (0.65, (255, 215, 105, 240)),   # 亮黄橙
            (1.00, (255, 250, 225, 255)),   # 白热核
        ]
    d = np.clip(density, 0.0, 1.0)
    out = np.zeros(density.shape + (4,), dtype=np.float32)
    for i in range(len(stops) - 1):
        d0, c0 = stops[i]
        d1, c1 = stops[i + 1]
        mask = (d >= d0) & (d <= d1)
        t = np.zeros_like(d)
        t[mask] = (d[mask] - d0) / max(d1 - d0, 1e-6)
        for ch in range(4):
            out[..., ch][mask] = c0[ch] + (c1[ch] - c0[ch]) * t[mask]
    return out


def make_frame(progress, is_energy, seed):
    rnd = random.Random(seed)
    fire_r = 34.0 + 66.0 * min(progress / 0.55, 1.0)          # 火焰成长半径
    fade = 1.0 if progress < 0.6 else 1.0 - (progress - 0.6) / 0.4 * 0.85

    # ── 火焰密度场：随机高斯亮斑叠加 ──
    density = np.zeros((SIZE, SIZE), dtype=np.float32)
    # 核心大斑（白热区）
    for _ in range(5):
        ang = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(0, fire_r * 0.3)
        add_blob(density, math.cos(ang) * r, math.sin(ang) * r,
                 rnd.uniform(fire_r * 0.22, fire_r * 0.38), rnd.uniform(0.55, 0.9))
    # 中层橙焰斑
    for _ in range(10):
        ang = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(fire_r * 0.2, fire_r * 0.7)
        add_blob(density, math.cos(ang) * r, math.sin(ang) * r,
                 rnd.uniform(fire_r * 0.16, fire_r * 0.3), rnd.uniform(0.3, 0.55))
    # 外缘暗焰斑（小而多，形成舔舐锯齿）
    for _ in range(14):
        ang = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(fire_r * 0.6, fire_r * 0.95)
        add_blob(density, math.cos(ang) * r, math.sin(ang) * r,
                 rnd.uniform(fire_r * 0.08, fire_r * 0.18), rnd.uniform(0.18, 0.38))
    # 径向衰减：离火球中心越远密度越低（保证有界不撑框）
    density *= 1.0 - smoothstep(fire_r * 0.75, fire_r * 1.15, DIST)
    density *= fade

    rgba = density_to_color(density, is_energy)

    # ── 烟尘（progress>0.45 淡入）：大尺度低密度灰斑，中心上移 ──
    if progress > 0.45:
        smoky = (progress - 0.45) / 0.55
        smoke = np.zeros((SIZE, SIZE), dtype=np.float32)
        for _ in range(8):
            ang = rnd.uniform(0, 2 * math.pi)
            r = rnd.uniform(0, fire_r * 0.8)
            cy_off = -smoky * 26.0                            # 热浮上升
            add_blob(smoke, math.cos(ang) * r, math.sin(ang) * r + cy_off,
                     rnd.uniform(26, 44), rnd.uniform(0.5, 0.9))
        smoke *= 1.0 - smoothstep(fire_r * 1.05, fire_r * 1.45, DIST)
        smoke_alpha = np.clip(smoke, 0, 1) * smoky * (1.0 - smoky * 0.35) * 0.85
        smoke_rgb = (130, 118, 105) if not is_energy else (115, 135, 170)
        # 烟在火焰下层：火焰 alpha 已高的地方少叠烟
        room = np.clip(1.0 - rgba[..., 3] / 255.0, 0, 1)
        sa = smoke_alpha * room
        for ch in range(3):
            rgba[..., ch] = rgba[..., ch] * (1 - sa) + smoke_rgb[ch] * sa
        rgba[..., 3] = np.maximum(rgba[..., 3], sa * 235)

    # ── 火星：径向流线（头亮粗→尾暗细），真实火花形态 ──
    n_sparks = 16 if progress < 0.35 else 9
    for _ in range(n_sparks):
        ang = rnd.uniform(0, 2 * math.pi)
        r0 = fire_r * rnd.uniform(0.7, 0.95)                  # 起点（火球边）
        r1 = r0 + rnd.uniform(18, 52)                         # 流向外的长度
        head_x = math.cos(ang) * r0
        head_y = math.sin(ang) * r0
        tail_x = math.cos(ang) * r1
        tail_y = math.sin(ang) * r1
        n_seg = 7
        for s in range(n_seg):
            t = s / (n_seg - 1)                               # 0=头 1=尾
            sx = head_x + (tail_x - head_x) * t
            sy = head_y + (tail_y - head_y) * t
            sigma = 2.6 * (1.0 - t * 0.65)                    # 头粗尾细
            weight = 0.95 * (1.0 - t) ** 1.4                  # 头亮尾暗
            add_blob(density, sx, sy, sigma, 0)               # noop 保持 API 一致性
            # 直接往颜色场写亮斑（走白→黄橙，压过底色）
            d2 = (DX - sx) ** 2 + (DY - sy) ** 2
            g = np.exp(-d2 / (2.0 * sigma * sigma)) * weight
            g *= fade
            col = (255, 245, 200) if not is_energy else (235, 250, 255)
            for ch in range(3):
                rgba[..., ch] = np.maximum(rgba[..., ch], g * col[ch])
            rgba[..., 3] = np.maximum(rgba[..., 3], g * 255)

    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")


def main():
    for i in range(6):
        progress = i / 5
        for kind, is_energy in (("explosion_conv", False), ("explosion_energy", True)):
            img = make_frame(progress, is_energy, seed=i * 31 + (99 if is_energy else 7))
            img.save(os.path.join(out_dir, f"{kind}_f{i}.png"))
        print(f"f{ i }: progress={progress:.1f} OK")

    # 验证：硬边=0 + 内容边距
    print("\n=== 验证 ===")
    for prefix in ("explosion_conv", "explosion_energy"):
        for i in range(6):
            f = f"{prefix}_f{i}.png"
            arr = np.array(Image.open(os.path.join(out_dir, f)).convert("RGBA"))
            alpha = arr[..., 3]
            cols = (alpha > 40).sum(axis=0)
            rows = (alpha > 40).sum(axis=1)
            xs = np.nonzero(cols)[0]
            hard = 0
            dc = np.diff(cols)
            hard += int(((dc < -cols[:-1] * 0.7) & (cols[:-1] > SIZE * 0.3)).sum())
            dr = np.diff(rows)
            hard += int(((dr < -rows[:-1] * 0.7) & (rows[:-1] > SIZE * 0.3)).sum())
            margin = int(min(xs[0], SIZE - 1 - xs[-1])) if len(xs) else SIZE
            print(f"{f}: 边距={margin}px 硬边={hard}")


if __name__ == "__main__":
    main()
