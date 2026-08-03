"""核爆 VFX 纹理抠图（flood fill 版）：从边缘洪水填充去除连通背景。

上一版用"色彩距离"抠图，对 missile（灰金属主体+灰背景）严重误抠——
主体颜色和背景接近时，单像素色彩判断分不开。

flood fill 方案：只去除"从图像边缘能连通到达"的背景区域。
被主体轮廓包围的背景块保留（即使颜色和背景一样）。
这样导弹主体只要形成大致封闭的轮廓就能保住。

算法：
  1. 采样边缘背景色
  2. BFS 从四条边所有像素开始，色彩距离 < tol 的标记为"外部背景"
  3. 外部背景 alpha 设 0；非外部背景的像素保持原 alpha（255）
  4. 可选：边缘羽化（对外部背景邻接的主体像素做半透明，去锯齿）

对大图(1024x1024)用纯 Python BFS 较慢，用扫描线 flood fill 加速。
"""
import os
from PIL import Image
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NUKE_DIR = os.path.join(ROOT, "assets", "effects", "nuclear")

# 每张图 flood fill 容差（色彩距离）——主体和背景越接近，tol 越小
CONFIG = {
    "nuke_fireball.png":  {"tol": 55},  # 暗灰底，亮火光主体（差异大，tol 可大）
    "nuke_shockwave.png": {"tol": 50},  # 暗灰底，亮环主体
    "nuke_mushroom.png":  {"tol": 40},  # 浅灰底，深烟柱
    "nuke_burn.png":      {"tol": 40},  # 浅灰底，深焦痕
    "nuke_missile.png":   {"tol": 28},  # 中灰底，灰金属主体（最接近，tol 最小防穿透）
}


def color_dist_sq(p1, p2):
    return (p1[0] - p2[0]) ** 2 + (p1[1] - p2[1]) ** 2 + (p1[2] - p2[2]) ** 2


def flood_fill_outside(px, w, h, tol):
    """扫描线 flood fill：标记所有从边缘连通、且色彩接近边缘背景的像素为外部背景。
    返回 set of (x,y) 外部背景像素。
    用 tol_sq（平方距离）避免开方。
    """
    tol_sq = tol * tol
    # 采样四条边的平均色作为背景基准（边缘像素彼此可能有色差，用宽容差判断）
    # 改进：不用单一基准色，而是"和当前种子像素色彩接近"就扩散——适应渐变背景
    outside = bytearray(w * h)  # 0=未访问, 1=外部背景
    q = deque()
    # 种子：四条边所有像素
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        idx = y * w + x
        if outside[idx]:
            continue
        cur = px[x, y]
        outside[idx] = 1
        # 扫描线：向左右扩展同行连续的可填充像素
        # 先把当前点左移到行最左
        lx = x
        while lx > 0 and not outside[idx - (x - lx)]:
            pass  # 标准扫描线较复杂，这里用朴素4邻接 BFS（清晰优先于性能）
        # 朴素 4 邻接扩散（1024x1024 约 1M 像素，边缘 flood fill 通常覆盖大半，几秒完成）
        for nx, ny in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]:
            if 0 <= nx < w and 0 <= ny < h:
                nidx = ny * w + nx
                if not outside[nidx]:
                    np = px[nx, ny]
                    if color_dist_sq((cur[0], cur[1], cur[2]), (np[0], np[1], np[2])) <= tol_sq:
                        q.append((nx, ny))
    return outside


def process(fname, tol):
    path = os.path.join(NUKE_DIR, fname)
    if not os.path.exists(path):
        print("跳过(不存在):", fname)
        return
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()
    print(f"{fname}: flood fill 中 (tol={tol}, {w}x{h})...", end=" ", flush=True)
    outside = flood_fill_outside(px, w, h, tol)
    # 外部背景设透明，主体保持不透明
    removed = 0
    for y in range(h):
        for x in range(w):
            if outside[y * w + x]:
                p = px[x, y]
                px[x, y] = (p[0], p[1], p[2], 0)
                removed += 1
    img.save(path)
    print(f"去除背景 {removed*100//(w*h)}%")


def main():
    print("=" * 50)
    print("核爆 VFX 纹理抠图（flood fill 版）")
    print("=" * 50)
    for fname, cfg in CONFIG.items():
        process(fname, cfg["tol"])
    print("=" * 50)
    print("完成。Godot 会自动重导入（或用 Agent Tools editor.reload_filesystem 触发）")


if __name__ == "__main__":
    main()
