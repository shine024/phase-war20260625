# -*- coding: utf-8 -*-
"""
修复战斗背景图下半部近景道具比例失衡问题 v5（确定性后处理，纯原生像素拷贝）。

迭代历史：
  v2/v3 平滑掩码多层混合 → 过渡带部分平均 = 涂抹感（用户反馈）
  v4 行漂移动态拷贝 → 相位跳变剪切 = 行条纹
  （AI 重摄 100m/50m → 用户看过觉得不好，偏离原图）
v5 策略（保原图 + 无涂抹）：
  A. 每个抹除区用 **两片原生尺寸整拷贝** 填充：目标行 y 的像素 = 原图同一 y 行、
     干净 donor 列窗口 (x265-578) 的原生像素。所有抹除区宽 ≤295 < donor 宽 313，
     无需平铺、无需重采样、无需平均 —— 行色调/纹理/锐度天然与周围一致
  B. 两片窗口各随机取位，接缝 = 平滑噪声阈值路径（2-3px 硬过渡，无平均化）
  C. feather 8px 只做内侧边界；贴图像框的边全填充（防道具残影）
  D. donor 源内碎屑簇先清洗（同样整拷贝方式）
  E. 回植物/底边石子全部 1.0 原生分辨率
用法：python tools/bg_rework/fix_props.py [in] [out_fixed] [out_compare]
"""
import sys
import numpy as np
from PIL import Image, ImageDraw

src_path = sys.argv[1] if len(sys.argv) > 1 else "docs/重修背景图/bg_level_07.png"
out_path = sys.argv[2] if len(sys.argv) > 2 else "docs/重修背景图/bg_level_07_fixed.png"
cmp_path = sys.argv[3] if len(sys.argv) > 3 else "docs/重修背景图/bg_level_07_compare.png"

rng = np.random.default_rng(20260826)

orig = np.asarray(Image.open(src_path).convert("RGB")).astype(np.float64)
A = orig.copy()
H, W = A.shape[:2]
DX0, DX1 = 265, 578     # 干净 donor 列范围（避开水洼边缘与碎屑簇后仍宽 313）

# ---------- 区域定义 ----------
ERASE = [
    #  (name, x0, y0, x1, y1, feather_left, feather_right, feather_top, feather_bottom)
    ("R1_LEFT",   0,   505, 256, 720, False, True,  True, False),
    ("R2A_ROPE",  668, 522, 764, 592, True,  True,  True, True),
    ("R2_RIGHT",  755, 522, 1050, 720, True,  True,  True, False),
    ("R3_CORNER", 1024, 518, 1280, 720, True,  False, True, False),
]

TRANSPLANTS = [  # 原生小岩石，1.0 原生分辨率回植到底边装饰带
    (30, 678, 85, 716, 52, 686),
    (700, 650, 790, 700, 692, 660),
]
PEBBLE_SRC = (30, 690, 120, 716)

def feather_sided(w, h, f, fl, fr, ft, fb):
    ax = np.ones(w); ay = np.ones(h)
    if fl: ax = np.minimum(ax, (np.arange(w) + 1) / f)
    if fr: ax = np.minimum(ax, (w - np.arange(w)) / f)
    if ft: ay = np.minimum(ay, (np.arange(h) + 1) / f)
    if fb: ay = np.minimum(ay, (h - np.arange(h)) / f)
    return np.clip(np.minimum(ax[None, :], ay[:, None]), 0.0, 1.0)

def smooth_noise(w, h, scale, seed):
    g = np.random.default_rng(seed)
    n = g.random((max(2, int(h / scale)), max(2, int(w / scale))))
    img = Image.fromarray((n * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(img).astype(np.float64) / 255.0

def pick_windows(rw, seed, n=2):
    """在 donor 范围内取 n 个互不重叠的窗口左端。窗口不足时允许重叠。"""
    g = np.random.default_rng(seed)
    lo, hi = DX0, DX1 - rw
    if hi - lo < 8:
        return [lo] * n
    if rw * n <= (DX1 - DX0):
        # 互不重叠：把 donor 切 n 段，每段内随机偏移
        seg = (DX1 - DX0) // n
        wins = []
        for i in range(n):
            slo, shi = DX0 + i * seg, min(DX0 + (i + 1) * seg - rw, DX1 - rw)
            if shi <= slo:
                shi = slo = DX0 + i * seg
            wins.append(int(g.integers(slo, max(slo + 1, shi + 1))))
        return wins
    return [int(g.integers(lo, hi + 1)) for _ in range(n)]

def two_piece_copy(y0, rh, rw, seed):
    """两片 donor 整拷贝 + 一条有机硬接缝。全部原生像素，零重采样零平均。"""
    wA, wB = pick_windows(rw, seed)
    pieceA = orig[y0:y0 + rh, wA:wA + rw]
    pieceB = orig[y0:y0 + rh, wB:wB + rw]
    n = smooth_noise(rw, rh, 42.0, seed)
    g = np.random.default_rng(seed + 1)
    split = 0.3 + 0.4 * g.random()
    path = split * rw + (n - 0.5) * 56.0          # 接缝路径：缓慢游走 ±28px，(h,w)
    d = np.arange(rw)[None, :] - path             # (h,w)
    m = 1.0 / (1.0 + np.exp(-d * 0.8))            # 2-3px 硬过渡
    return pieceA * (1 - m[..., None]) + pieceB * m[..., None]

# ---------- 0) 清洗 donor 源内碎屑簇 (300,565)-(500,640)：同样整拷贝 ----------
_cx0, _cy0, _cx1, _cy1 = 300, 565, 500, 640
_cl = two_piece_copy(_cy0, _cy1 - _cy0, _cx1 - _cx0, int(rng.integers(1 << 30)))
_al = feather_sided(_cx1 - _cx0, _cy1 - _cy0, 10, True, True, True, True)[..., None]
orig[_cy0:_cy1, _cx0:_cx1] = orig[_cy0:_cy1, _cx0:_cx1] * (1 - _al) + _cl * _al
A[_cy0:_cy1, _cx0:_cx1] = orig[_cy0:_cy1, _cx0:_cx1]

# ---------- 1) 抹除 + 整块拷贝填充 ----------
FE = 8
for (name, x0, y0, x1, y1, fl, fr, ft, fb) in ERASE:
    x0c, y0c, x1c, y1c = max(x0, 0), max(y0, 0), min(x1, W), min(y1, H)
    rw, rh = x1c - x0c, y1c - y0c

    fill = two_piece_copy(y0c, rh, rw, int(rng.integers(1 << 30)))

    al = feather_sided(rw, rh, FE, fl, fr, ft, fb)[..., None]
    A[y0c:y1c, x0c:x1c] = orig[y0c:y1c, x0c:x1c] * (1 - al) + fill * al

    def grad_e(b):
        l = b.mean(axis=2)
        return np.abs(np.diff(l, axis=1)).mean() + np.abs(np.diff(l, axis=0)).mean()
    def lap_var(b):
        l = b.mean(axis=2)
        lap = (np.roll(l, 1, 0) + np.roll(l, -1, 0) + np.roll(l, 1, 1) + np.roll(l, -1, 1) - 4 * l)
        return lap[2:-2, 2:-2].var()
    def band_e(b):
        return np.abs(np.diff(b.mean(axis=(1, 2)), 2)).mean()
    dn = orig[y0c:y1c, 320:560]
    print("%-10s grad f=%.2f d=%.2f | lapvar f=%.1f d=%.1f | band f=%.3f d=%.3f" % (
        name, grad_e(A[y0c:y1c, x0c:x1c]), grad_e(dn),
        lap_var(A[y0c:y1c, x0c:x1c]), lap_var(dn),
        band_e(A[y0c:y1c, x0c:x1c]), band_e(dn)))

# ---------- 2) 回植小岩石（1.0 原生分辨率） ----------
for (x0, y0, x1, y1, px, py) in TRANSPLANTS:
    patch = orig[y0:y1, x0:x1]
    ph, pw = patch.shape[:2]
    px = int(np.clip(px, 0, W - pw)); py = int(np.clip(py, 0, H - ph))
    al = feather_sided(pw, ph, 4, True, True, True, True)[..., None]
    tgt = A[py:py + ph, px:px + pw]
    A[py:py + ph, px:px + pw] = tgt * (1 - al) + patch * al

# ---------- 3) 底边小石子（8 处，原生分辨率抠取） ----------
for i in range(8):
    pw = int(rng.integers(10, 22)); ph = int(rng.integers(6, 12))
    sx = int(rng.integers(PEBBLE_SRC[0], PEBBLE_SRC[0] + 90 - pw))
    sy = int(rng.integers(PEBBLE_SRC[1], PEBBLE_SRC[1] + 26 - ph))
    patch = orig[sy:sy + ph, sx:sx + pw]
    px = int(rng.integers(20, W - 60)); py = int(rng.integers(692, 718 - ph))
    al = feather_sided(pw, ph, 3, True, True, True, True)[..., None] * 0.95
    tgt = A[py:py + ph, px:px + pw]
    A[py:py + ph, px:px + pw] = tgt * (1 - al) + patch * al

# ---------- 输出 ----------
out = Image.fromarray(np.clip(A, 0, 255).astype(np.uint8))
out.save(out_path)
print("fixed saved:", out_path)

# 对比图：全图缩略 + 3 个关键区放大（左=before 右=after）
orig_im = Image.open(src_path).convert("RGB")
zones = [(0, 490, 266, 720, 2), (660, 500, 1060, 720, 2), (1014, 500, 1280, 720, 2)]
rows = [[orig_im.resize((640, 360)), out.resize((640, 360))]]
for zx0, zy0, zx1, zy1, sc in zones:
    pair = []
    for img in (orig_im, out):
        c = img.crop((zx0, zy0, zx1, zy1))
        c = c.resize((c.width * sc, c.height * sc), Image.LANCZOS)
        pair.append(c)
    rows.append(pair)
pad = 6
row_dims = [(max(i.height for i in r), sum(i.width for i in r) + pad * (len(r) + 1)) for r in rows]
sheet = Image.new("RGB", (max(w for _, w in row_dims) + pad * 2, sum(h for h, _ in row_dims) + pad * (len(rows) + 1)), (24, 24, 28))
y = pad
for r, (hh, _) in zip(rows, row_dims):
    x = pad
    for i in r:
        sheet.paste(i, (x, y)); x += i.width + pad
    y += hh + pad
sheet.save(cmp_path)
print("compare saved:", cmp_path)
