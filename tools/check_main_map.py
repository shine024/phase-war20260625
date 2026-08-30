#!/usr/bin/env python3
"""主地图候选图量化检查 —— 对应《主地图图片需求_格陵兰.md》§8 可量化验收。

用法：
    python tools/check_main_map.py <候选图.png> [更多.png ...]

检查项（程序可测部分）：
  1. 轮廓相似度：生成图陆地 vs grl.geo.json 真实轮廓，bbox 对齐后算 IoU（§8.1，阈值 0.60）
  2. 海分布：中部铺装区（x25%~75%, y20%~80%）海占比（§8.5，<15% 及格）
  3. 青色约束：青色发光像素占比（§7 禁大面积纯青，<2% 及格）
  4. 饱和度：均值与 P99（§7 禁高饱和艳色）
  5. 黑门：东侧暗斑位置与真实东尖角偏差（§8.4，<8% 画布宽及格）+ 纯黑可辨（最低亮度<60）
  6. 年代渐变：陆地西/东三分之一条带明度差（西亮东暗大趋势，§4/§6）
  7. 分辨率：宽 ≥1312（§1）
"""
import json
import math
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = __import__("os").path.dirname(__file__) + "/.."
GEO = ROOT + "/docs/地图重设计/generated/greenland/grl.geo.json"
W_REF, H_REF = 2560, 1440
KM_DEG_LAT = 111.0
KM_DEG_LON = 111.0 * math.cos(math.radians(71.5))


def ref_land_mask(w=W_REF, h=H_REF) -> np.ndarray:
    d = json.load(open(GEO, encoding="utf-8"))
    ring = d["features"][0]["geometry"]["coordinates"][0]
    xc, yc = -42.75, 71.85
    sx = np.array([(yc - p[1]) * KM_DEG_LAT for p in ring])
    sy = np.array([(xc - p[0]) * KM_DEG_LON for p in ring])
    land_h = 640.0 * (w / 1312.0)
    scale = land_h / (sy.max() - sy.min())
    x0 = (w - (sx.max() - sx.min()) * scale) / 2 - sx.min() * scale
    y0 = (h - land_h) / 2 - sy.min() * scale
    from PIL import ImageDraw
    im = Image.new("L", (w, h), 0)
    ImageDraw.Draw(im).polygon([(x0 + x * scale, y0 + y * scale) for x, y in zip(sx, sy)], fill=255)
    return np.asarray(im) > 127


def bbox_of(mask: np.ndarray):
    ys, xs = np.nonzero(mask)
    return xs.min(), ys.min(), xs.max(), ys.max()


def shape_iou(gen_land: np.ndarray, ref: np.ndarray) -> float:
    """bbox 裁剪 → 统一 640×360 → IoU（形态含长宽比）。"""
    out = []
    for m in (gen_land, ref):
        x0, y0, x1, y1 = bbox_of(m)
        crop = Image.fromarray((m[y0:y1 + 1, x0:x1 + 1] * 255).astype(np.uint8))
        out.append(np.asarray(crop.resize((640, 360), Image.BILINEAR)) > 127)
    a, b = out
    return float((a & b).sum()) / max(1, (a | b).sum())


def analyze(path: str) -> dict:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    arr = np.asarray(im, np.float32)
    hsv = np.asarray(im.convert("HSV"), np.float32)
    Hh, S, V = hsv[..., 0] * 360 / 255.0, hsv[..., 1] / 255.0, hsv[..., 2] / 255.0

    rep = {"file": path, "size": [w, h]}
    rep["resolution_ok"] = w >= 1312

    # ── 海/陆分类：深蓝低明度=海（阈值在合成图真值上标定 IoU=0.997）──
    sea = (Hh >= 190) & (Hh <= 250) & (S > 0.30) & (V < 0.85)
    land = ~sea
    lab, n = ndimage.label(land)
    if n > 0:
        sizes = ndimage.sum(land, lab, range(1, n + 1))
        land = lab == (1 + int(np.argmax(sizes)))
    rep["land_fraction"] = round(float(land.mean()), 3)

    # ── 1. 轮廓 IoU ──
    try:
        iou = shape_iou(land, ref_land_mask())
    except Exception as exc:
        iou = -1.0
        rep["iou_error"] = str(exc)
    rep["shape_iou"] = round(iou, 3)

    # ── 2. 铺装区连贯性：中段列（bbox 25%~75%）逐列检查海是否切断陆地 ──
    lx0b, ly0b, lx1b, ly1b = bbox_of(land)
    cx0 = lx0b + int((lx1b - lx0b) * 0.25)
    cx1 = lx0b + int((lx1b - lx0b) * 0.75)
    col_land = land[:, cx0:cx1]
    row_density = col_land.mean(axis=1)
    rows = np.nonzero(row_density > 0.05)[0]
    if len(rows):
        ry0 = int(np.percentile(rows, 12))
        ry1 = int(np.percentile(rows, 88))
    else:
        ry0, ry1 = ly0b, ly1b
    rep["front_zone_sea"] = round(float(sea[ry0:ry1, cx0:cx1].mean()), 3)  # 信息值
    broken = total = 0
    for cxx in range(cx0, cx1, 4):
        col = land[:, cxx]
        rows_c = np.nonzero(col)[0]
        if len(rows_c) < 30:
            continue
        a = int(np.percentile(rows_c, 8))
        b = int(np.percentile(rows_c, 92))
        seg = col[a:b + 1]
        total += 1
        if (1.0 - seg.mean()) > 0.30:
            broken += 1
    rep["front_broken_cols"] = round(broken / max(1, total), 3)
    top_sea = float(sea[: int(h * 0.12), :].mean())
    bot_sea = float(sea[int(h * 0.88):, :].mean())
    rep["edge_sea_fraction"] = round((top_sea + bot_sea) / 2, 3)

    # ── 3. 青色占比（黑门系统专用；窗口在合成图上标定：好图≈0.06%）──
    cyan = (Hh >= 175) & (Hh <= 200) & (S > 0.35) & (V > 0.45)
    rep["cyan_fraction"] = round(float(cyan.mean()) * 100, 2)  # %

    # ── 4. 色度（低饱和沉稳；合成图基准 mean=0.278 p99=0.373）──
    chroma = (arr.max(axis=2) - arr.min(axis=2)) / 255.0
    rep["chroma_mean"] = round(float(chroma.mean()), 3)
    rep["chroma_p99"] = round(float(np.percentile(chroma, 99)), 3)

    # ── 5. 黑门：陆 bbox 东 15% 内找最暗团 ──
    lx0, ly0, lx1, ly1 = bbox_of(land)
    ref_mask = ref_land_mask()
    rx0, ry0, rx1, ry1 = bbox_of(ref_mask)
    gx = int(np.max(np.nonzero(ref_mask)[1]))
    gtip = (1.0, float(np.argmax(ref_mask[:, gx]) / H_REF))  # 归一化 (x, y)
    sx0 = lx1 - int((lx1 - lx0) * 0.15)
    region = V[ly0:ly1, sx0:lx1]
    if region.size:
        thr = np.percentile(region, 0.5)
        ys, xs = np.nonzero(region <= max(thr, 12.0))
        if len(xs):
            px = (sx0 + xs.mean() - lx0) / max(1, lx1 - lx0)
            py = (ly0 + ys.mean() - ly0) / max(1, ly1 - ly0)
            rep["gate_offset_frac"] = round(float(abs(px - gtip[0]) * (lx1 - lx0) / w * (w / w)), 3)
            rep["gate_offset_frac_w"] = round(float(abs((sx0 + xs.mean()) / w - (rx1) / W_REF)), 3)
            rep["gate_min_lum"] = round(float(region.min()), 1)
            rep["gate_dark_px"] = int((region < 40).sum())

    # ── 6. 年代渐变：陆地上西/东三分之一明度与色温 ──
    ly, lx = np.nonzero(land)
    xs = lx - lx0
    span = max(1, lx1 - lx0)
    west = (xs < span / 3)
    east = (xs > span * 2 / 3)
    lum = V[ly, lx] * 255
    r, g, b = arr[ly, lx, 0], arr[ly, lx, 1], arr[ly, lx, 2]
    rep["west_lum"] = round(float(lum[west].mean()), 1)
    rep["east_lum"] = round(float(lum[east].mean()), 1)
    rep["west_warm"] = round(float((r[west] - b[west]).mean()), 1)
    rep["east_warm"] = round(float((r[east] - b[east]).mean()), 1)

    # ── 判定 ──
    checks = {
        "resolution": rep["resolution_ok"],
        "shape_iou>=0.60": rep["shape_iou"] >= 0.60,
        "front_coherent": rep["front_broken_cols"] <= 0.10,
        "cyan<2%": rep["cyan_fraction"] < 2.0,
        "chroma_ok": rep["chroma_mean"] < 0.40 and rep["chroma_p99"] < 0.60,
        "gate_dark": rep.get("gate_min_lum", 255) < 60 and rep.get("gate_dark_px", 0) > 30,
        "gate_pos<8%w": rep.get("gate_offset_frac_w", 1.0) < 0.08,
        "west_lighter": rep["west_lum"] > rep["east_lum"],
    }
    rep["checks"] = checks
    rep["pass_count"] = f"{sum(checks.values())}/{len(checks)}"
    return rep


def main() -> int:
    all_ok = True
    for p in sys.argv[1:]:
        try:
            rep = analyze(p)
        except Exception as exc:
            print(f"✗ {p}: 检查失败 {exc}")
            all_ok = False
            continue
        print(f"\n══ {rep['file']}  {rep['size'][0]}×{rep['size'][1]}")
        for k, v in rep.items():
            if k not in ("file", "size", "checks", "pass_count"):
                print(f"   {k:22s} {v}")
        for k, v in rep["checks"].items():
            print(f"   [{'✓' if v else '✗'}] {k}")
        print(f"   ⇒ 通过 {rep['pass_count']}")
        all_ok &= all(rep["checks"].values())
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
