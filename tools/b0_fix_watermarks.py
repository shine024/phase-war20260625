#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批次④批0：徽章 AI 水印 inpaint + bg_default 四角星水印修复（2026-09-09）。

审计依据：docs/统一化/资产分档审计-2026-09-08.md
  - 相位仪徽章 20/30 张 C 档主因=右下角「图片由AI生成」合规水印。
    实测 94 张中该水印位置完全固定：x 803-1002, y 971-1002（同管线产物）。
    该区域为深色径向渐变背景（角落最暗），用同列上方采样 copy + 羽化可无缝修复。
  - bg_default ≡ bg_02（逐字节相同），右下角白色四角星水印。
    像素风泥地纹理用邻域 patch 平移填充；正式替换待批1 bg_02 重生成后同步。

用法：
  python tools/b0_fix_watermarks.py --scan    # 只扫描，报告哪些文件含水印
  python tools/b0_fix_watermarks.py --apply   # 修复（输出到 _b0_fixed/ 临时目录）
  python tools/b0_fix_watermarks.py --deploy  # 抽检通过后，把 _b0_fixed/ 覆盖回 assets/

前置备份（已完成）：_art_backup/phase-war-art-backup-b0-watermark-2026-09-09.zip
"""
import argparse
import os
import shutil

from PIL import Image, ImageFilter
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INSTRUMENTS_DIR = os.path.join(ROOT, "assets", "ui", "instruments")
BG_DEFAULT = os.path.join(ROOT, "assets", "backgrounds", "bg_default.png")
FIXED_DIR = os.path.join(ROOT, "docs", "统一化", "_b0_fixed")

# 徽章中文水印 bbox（实测 7 张一致）+ 外扩余量
WM_BOX = (795, 960, 1012, 1012)  # x0, y0, x1, y1
# 灰字亮度区间（背景 ~20-60，文字 ~90-180）
WM_LUM_LO = 70
WM_LUM_HI = 200
WM_MIN_PX = 300  # 该区域灰字像素数下限

# 采样偏移：从 bbox 上方多远取干净像素（bbox 高 52px，上方 64px 处必然干净）
SAMPLE_SHIFT = 64


def detect_badge_watermark(arr: np.ndarray) -> bool:
    """检测徽章右下角是否存在固定位置中文水印。"""
    x0, y0, x1, y1 = WM_BOX
    region = arr[y0:y1, x0:x1]
    lum = region.mean(axis=2)
    mask = (lum > WM_LUM_LO) & (lum < WM_LUM_HI)
    return int(mask.sum()) >= WM_MIN_PX


def inpaint_badge(arr: np.ndarray) -> np.ndarray:
    """同列上方采样 copy + 高斯羽化混合。

    背景=径向渐变，垂直方向 64px 尺度上梯度极小；
    copy 后在边界做羽化 alpha 混合避免硬接缝。
    采样窗口自适应：固定偏移处若被主体污染（亮度 >WM_LUM_LO），
    向上逐行扫描找第一条连续干净带。
    """
    x0, y0, x1, y1 = WM_BOX
    h = y1 - y0
    out = arr.copy().astype(np.float64)

    lum = arr.mean(axis=2)
    src_y = y0 - SAMPLE_SHIFT  # 默认固定偏移
    col_lum = lum[:, x0:x1]
    if col_lum[src_y:src_y + h].max() > WM_LUM_LO:
        # 自适应：只在水印上方邻近区（y0 起 300px 内）从近到远找连续干净行段，
        # 段高不足 h 时取整段并垂直拉伸到 h。径向渐变下越近的行颜色越接近水印区，
        # 禁止全图搜索（远处「干净」区可能是顶部装饰，色阶完全不同）。
        clean = col_lum[:y0].max(axis=1) <= WM_LUM_LO  # y0 以上每行是否干净
        best_len, best_end = 0, 0
        run = 0
        for i in range(max(0, y0 - 300), y0):
            run = run + 1 if clean[i] else 0
            if run >= best_len:
                best_len, best_end = run, i + 1
        if best_len < 24:
            # 无干净带（水印压边框/装饰线）：逐列延伸法——
            # 每列用 y0 上方 4 行均值垂直填充。竖直边框线自动延续，
            # 背景渐变在 52px 内垂直梯度≈2-3 级不可见。叠加轻噪声防条带感。
            colsrc = arr[y0 - 4:y0, x0:x1].astype(np.float64).mean(axis=0)
            rng = np.random.default_rng(7)
            for i in range(h):
                out[y0 + i, x0:x1] = colsrc + rng.normal(0, 1.2, colsrc.shape)
            # 羽化上边界
            for i in range(8):
                wgt = (i + 1) / 9
                out[y0 + i, x0:x1] = (
                    out[y0 + i, x0:x1] * wgt + arr[y0 + i, x0:x1] * (1 - wgt)
                )
            return out.astype(np.uint8)
        seg = arr[best_end - best_len:best_end, x0:x1].astype(np.float64)
        seg_img = Image.fromarray(seg.astype(np.uint8)).resize((x1 - x0, h), Image.LANCZOS)
        src = np.array(seg_img).astype(np.float64)
    else:
        src = arr[src_y:src_y + h, x0:x1].astype(np.float64)

    # 羽化 mask：内部全 1，边缘 8px 线性过渡到 0（把源图与原图平滑混合）
    feather = 8
    alpha = np.ones((h, x1 - x0))
    for i in range(feather):
        w = (i + 1) / (feather + 1)
        alpha[i, :] = np.minimum(alpha[i, :], w)
        alpha[h - 1 - i, :] = np.minimum(alpha[h - 1 - i, :], w)
        alpha[:, i] = np.minimum(alpha[:, i], w)
        alpha[:, -(i + 1)] = np.minimum(alpha[:, -(i + 1)], w)
    alpha3 = alpha[:, :, None]

    out[y0:y1, x0:x1] = src * alpha3 + out[y0:y1, x0:x1] * (1 - alpha3)
    return out.astype(np.uint8)


# ---------- bg_default 四角星 ----------

def detect_star_watermark(arr: np.ndarray):
    """在右下角找白色四角星（亮白像素簇，>150 亮度，实测星体 max≈177）。返回 bbox 或 None。"""
    h, w, _ = arr.shape
    region = arr[int(h * 0.80):, int(w * 0.80):w]
    lum = region.mean(axis=2)
    mask = lum > 150
    ys, xs = np.where(mask)
    if len(ys) < 40:
        return None
    pad = 6
    return (
        int(w * 0.80) + xs.min() - pad,
        int(h * 0.80) + ys.min() - pad,
        int(w * 0.80) + xs.max() + pad,
        int(h * 0.80) + ys.max() + pad,
    )


def inpaint_star(arr: np.ndarray, box) -> np.ndarray:
    """噪声纹理区四角星：左侧同行 patch 水平 copy（泥地纹理各向近似）。"""
    x0, y0, x1, y1 = box
    bw = x1 - x0
    out = arr.copy()

    # 从左侧 bw 处取同行 patch（泥地噪声纹理水平方向统计特性一致）
    src = arr[y0:y1, x0 - bw:x0].copy()
    # 水平翻转使接缝侧纹理延续更自然
    src = src[:, ::-1]

    # 羽化混合
    feather = 4
    h = y1 - y0
    alpha = np.ones((h, bw))
    for i in range(feather):
        wgt = (i + 1) / (feather + 1)
        alpha[:, i] = np.minimum(alpha[:, i], wgt)
        alpha[:, -(i + 1)] = np.minimum(alpha[:, -(i + 1)], wgt)
        alpha[i, :] = np.minimum(alpha[i, :], wgt)
        alpha[h - 1 - i, :] = np.minimum(alpha[h - 1 - i], wgt)
    alpha3 = alpha[:, :, None]
    out[y0:y1, x0:x1] = (
        src.astype(np.float64) * alpha3 + out[y0:y1, x0:x1].astype(np.float64) * (1 - alpha3)
    ).astype(np.uint8)

    # patch 内轻度模糊消除 copy 痕迹（像素风容忍度高，只糊 1px）
    region = Image.fromarray(out[y0:y1, x0:x1]).filter(ImageFilter.GaussianBlur(0.6))
    out[y0:y1, x0:x1] = np.array(region)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scan", action="store_true")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--deploy", action="store_true")
    args = ap.parse_args()

    badges = sorted(
        f for f in os.listdir(INSTRUMENTS_DIR)
        if f.startswith("pi_") and f.endswith(".png")
    )

    if args.deploy:
        if not os.path.isdir(FIXED_DIR):
            print("no _b0_fixed/ dir")
            return 1
        n = 0
        for f in os.listdir(FIXED_DIR):
            src = os.path.join(FIXED_DIR, f)
            if f == "bg_default.png":
                dst = BG_DEFAULT
            else:
                dst = os.path.join(INSTRUMENTS_DIR, f)
            shutil.copy2(src, dst)
            n += 1
            print("deployed", f)
        print("total", n)
        return 0

    dirty = []
    for f in badges:
        arr = np.array(Image.open(os.path.join(INSTRUMENTS_DIR, f)).convert("RGB"))
        if detect_badge_watermark(arr):
            dirty.append(f)

    bg_arr = np.array(Image.open(BG_DEFAULT).convert("RGB"))
    star_box = detect_star_watermark(bg_arr)

    print("=== scan ===")
    print("badge watermark: %d / %d" % (len(dirty), len(badges)))
    for f in dirty:
        print("  ", f)
    print("bg_default star:", star_box)

    if args.apply:
        os.makedirs(FIXED_DIR, exist_ok=True)
        for f in dirty:
            im = Image.open(os.path.join(INSTRUMENTS_DIR, f)).convert("RGB")
            arr = np.array(im)
            fixed = inpaint_badge(arr)
            # 复检：水印应消失
            if detect_badge_watermark(fixed):
                print("  !! STILL DIRTY after fix:", f)
                continue
            Image.fromarray(fixed).save(os.path.join(FIXED_DIR, f))
            print("  fixed ->", f)
        if star_box:
            fixed_bg = inpaint_star(bg_arr, star_box)
            Image.fromarray(fixed_bg).save(os.path.join(FIXED_DIR, "bg_default.png"))
            print("  fixed -> bg_default.png (star)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
