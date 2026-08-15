#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
改造图标透明度精修：用四角泛洪去底替换全局亮度键控。
问题背景：全局键控（亮度>200 渐变透明）会把主体内部的亮色高光/白色部件也打半透明，
导致图标内容发虚。泛洪只移除与画布边缘连通的近白背景，主体内部亮色不受影响。
"""
import os
import sys
from collections import deque
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "assets", "ui", "icons", "mod_icons")
BACKUP = os.path.join(ROOT, "assets", "ui", "icons", "_modicons_pre_flood")
os.makedirs(BACKUP, exist_ok=True)

NEAR_WHITE_T = 236  # 与背景连通的近白判定阈值（亮度）


def flood_alpha(arr: np.ndarray) -> np.ndarray:
    """从四角 BFS 泛洪近白连通区 → alpha=0；返回新 alpha 通道。"""
    h, w = arr.shape[:2]
    brightness = arr[:, :, :3].astype(np.int16).sum(axis=2) / 3.0
    near_white = brightness >= NEAR_WHITE_T
    visited = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near_white[y, x] and not visited[y, x]:
                visited[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if near_white[y, x] and not visited[y, x]:
                visited[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for ny, nx in ((y-1, x), (y+1, x), (y, x-1), (y, x+1)):
            if 0 <= ny < h and 0 <= nx < w and near_white[ny, nx] and not visited[ny, nx]:
                visited[ny, nx] = True
                q.append((ny, nx))
    alpha = arr[:, :, 3].astype(np.int16).copy()
    # 泛洪区 alpha→0；泛洪区边缘做 2px 羽化（部分像素按距离淡化）
    alpha[visited] = 0
    return np.clip(alpha, 0, 255).astype(np.uint8), visited


def feather(arr: np.ndarray, visited: np.ndarray, radius: int = 2) -> np.ndarray:
    """对 visited 边界外侧的半白像素做羽化，避免硬锯齿。"""
    h, w = visited.shape
    alpha = arr[:, :, 3].astype(np.float32)
    brightness = arr[:, :, :3].astype(np.float32).sum(axis=2) / 3.0
    # 与 visited 相邻且亮度 210~NEAR_WHITE_T 的像素按亮度比例降 alpha
    dil = np.zeros((h, w), dtype=bool)
    dil[1:, :] |= visited[:-1, :]
    dil[:-1, :] |= visited[1:, :]
    dil[:, 1:] |= visited[:, :-1]
    dil[:, :-1] |= visited[:, 1:]
    band = dil & (~visited) & (brightness >= 205)
    if band.any():
        t = (brightness[band] - 205.0) / float(NEAR_WHITE_T - 205)
        alpha[band] = alpha[band] * (1.0 - 0.85 * np.clip(t, 0, 1))
    return np.clip(alpha, 0, 255).astype(np.uint8)


def main() -> None:
    dry = "--dry-run" in sys.argv
    changed = 0
    for f in sorted(os.listdir(D)):
        if not f.endswith(".png"):
            continue
        p = os.path.join(D, f)
        im = Image.open(p).convert("RGBA")
        arr = np.array(im)
        # 若已存在透明底且背景区（亮度>阈值的边缘连通）已空，跳过
        new_alpha, visited = flood_alpha(arr)
        removed = int(visited.sum())
        if removed == 0:
            continue
        changed += 1
        if dry:
            print("would clean:", f, removed, "px")
            continue
        import shutil
        shutil.copy2(p, os.path.join(BACKUP, f))
        alpha = feather(arr, visited)
        # 泛洪区强置 0（feather 只处理边界带）
        alpha[visited] = 0
        out = np.dstack([arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], alpha])
        Image.fromarray(out, "RGBA").save(p, "PNG")
    print(f"\n{'[dry-run] ' if dry else ''}cleaned {changed} icons (backup in _modicons_pre_flood)")


if __name__ == "__main__":
    main()
