#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
检测未抠图的卡图。

判定原理：
- 已抠图：主体四周是透明的（alpha=0），四角和边缘大量透明像素。
- 未抠图：有纯色或不透明背景，四角和边缘几乎无透明像素。

指标：
- edge_transparent_ratio：边缘(外圈2px)透明像素占比。>0.9 视为已抠图，<0.1 视为未抠图。
- corner_transparent：四个角(8x8)是否全透明。
- has_alpha：是否有 alpha 通道。

输出未抠图清单（按 edge_transparent_ratio 升序，最可疑的在前）。
"""
import sys
import os
from pathlib import Path
from PIL import Image

IOError = (OSError, ValueError)

def analyze_image(path: Path) -> dict:
    """分析单张图片，返回判定指标。"""
    try:
        img = Image.open(path)
        img.load()
    except IOError as e:
        return {"path": str(path), "error": str(e)}

    # 转 RGBA 统一处理
    if img.mode != "RGBA":
        # 无 alpha 通道 → 必然未抠图（整图不透明）
        return {
            "path": str(path),
            "has_alpha": False,
            "edge_transparent_ratio": 0.0,
            "corner_transparent": False,
            "size": img.size,
            "mode": img.mode,
            "verdict": "NO_ALPHA",
        }

    w, h = img.size
    alpha = img.split()[3]

    # 边缘像素：外圈 2px
    edge_pixels = []
    # 上下边
    for x in range(0, w, max(1, w // 100)):
        for y in range(2):
            edge_pixels.append(alpha.getpixel((x, y)))
            edge_pixels.append(alpha.getpixel((x, h - 1 - y)))
    # 左右边
    for y in range(0, h, max(1, h // 100)):
        for x in range(2):
            edge_pixels.append(alpha.getpixel((x, y)))
            edge_pixels.append(alpha.getpixel((w - 1 - x, y)))

    edge_total = len(edge_pixels)
    edge_transparent = sum(1 for a in edge_pixels if a < 16)  # alpha<16 视为透明
    edge_ratio = edge_transparent / edge_total if edge_total > 0 else 0.0

    # 四角 8x8 是否全透明
    corner_transparent = True
    for cx, cy in [(0, 0), (w - 8, 0), (0, h - 8), (w - 8, h - 8)]:
        for dx in range(8):
            for dy in range(8):
                if alpha.getpixel((min(cx + dx, w - 1), min(cy + dy, h - 1))) >= 16:
                    corner_transparent = False
                    break
            if not corner_transparent:
                break
        if not corner_transparent:
            break

    # 判定
    if not img.mode.endswith("A"):
        verdict = "NO_ALPHA"
    elif edge_ratio > 0.9 and corner_transparent:
        verdict = "CUT"  # 已抠图
    elif edge_ratio < 0.1:
        verdict = "UNCUT"  # 未抠图（有背景）
    else:
        verdict = "PARTIAL"  # 部分透明（可能边缘有阴影/光晕，需人工确认）

    return {
        "path": str(path),
        "has_alpha": True,
        "edge_transparent_ratio": round(edge_ratio, 3),
        "corner_transparent": corner_transparent,
        "size": img.size,
        "mode": img.mode,
        "verdict": verdict,
    }


def main():
    roots = [
        Path(r"F:\godot fair duet\create\phase-war\assets\card_icons"),
    ]
    exts = {".png", ".webp", ".jpg", ".jpeg"}
    results = []
    for root in roots:
        if not root.exists():
            continue
        for f in sorted(root.rglob("*")):
            if f.suffix.lower() in exts and ".import" not in f.name:
                results.append(analyze_image(f))

    # 按目录分组统计
    uncut = [r for r in results if r.get("verdict") in ("UNCUT", "NO_ALPHA")]
    partial = [r for r in results if r.get("verdict") == "PARTIAL"]
    cut = [r for r in results if r.get("verdict") == "CUT"]
    errors = [r for r in results if "error" in r]

    print("=" * 70)
    print("卡图抠图状态检测报告")
    print("=" * 70)
    print(f"总计扫描: {len(results)} 张")
    print(f"  已抠图(CUT):     {len(cut)}")
    print(f"  未抠图(UNCUT):   {len(uncut)}")
    print(f"  部分(PARTIAL):   {len(partial)}")
    print(f"  错误:            {len(errors)}")
    print()

    if uncut:
        print("=" * 70)
        print(f"【未抠图清单】(共 {len(uncut)} 张) — 优先处理")
        print("=" * 70)
        # 按 edge_ratio 升序（最不透明的在前）
        uncut.sort(key=lambda r: r.get("edge_transparent_ratio", 0))
        for r in uncut:
            name = Path(r["path"]).name
            ratio = r.get("edge_transparent_ratio", 0)
            print(f"  {name:40s} edge_alpha={ratio:.3f} {r.get('size','')} {r['verdict']}")
        print()

    if partial:
        print("=" * 70)
        print(f"【部分透明/需人工确认】(共 {len(partial)} 张)")
        print("=" * 70)
        partial.sort(key=lambda r: r.get("edge_transparent_ratio", 0))
        for r in partial:
            name = Path(r["path"]).name
            ratio = r.get("edge_transparent_ratio", 0)
            corner = "角透明" if r.get("corner_transparent") else "角不透明"
            print(f"  {name:40s} edge_alpha={ratio:.3f} {corner} {r.get('size','')}")
        print()

    if errors:
        print("=" * 70)
        print(f"【读取错误】(共 {len(errors)} 张)")
        print("=" * 70)
        for r in errors:
            print(f"  {Path(r['path']).name}: {r['error']}")


if __name__ == "__main__":
    main()
