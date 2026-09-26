# -*- coding: utf-8 -*-
"""记录1#7: 刺刀突击班卡图白块清除。

病灶（v6.26.3 当时裁决保留的"接地地面阴影"，记录1 用户点名=白块，推翻）：
  1. 两腿之间白色楔形残底（泛洪抠底时腿间浅灰甄别失败被保留）
  2. 脚线下方横向地面阴影条

处置：限定区域内低饱和亮色连通块泛洪 -> alpha=0。不全局清，
军服/头盔等高饱和黄绿褐不受影响。player + enemy 镜像两份同步。
原图备份 .godot/art_backup_lance_wedge_20260926/。
缩略图刷新由调用方负责（铁律：动原图必刷 _thumb256/_thumb384 两棵树）。
"""
import os, shutil
from PIL import Image
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKUP = os.path.join(ROOT, ".godot", "art_backup_lance_wedge_20260926")

TARGETS = [
    "assets/card_icons/player/drop_phase_lance.png",
    "assets/card_icons/enemy/drop_phase_lance.png",
]

# 检查区（图内病灶可能出现的范围，留余量）：腿间楔形 + 底部地面条
# player 与 enemy 互为镜像，病灶 x 区间互补；y 区间相同。
REGIONS = {
    "player": [(100, 260, 215, 440), (0, 440, 512, 512)],    # 腿间带 + 底带
    "enemy":  [(297, 260, 412, 440), (0, 440, 512, 512)],
}

def is_brightish_low_sat(px):
    r, g, b, a = px
    if a == 0:
        return False
    mx, mn = max(r, g, b), min(r, g, b)
    # 白/浅灰：亮 + 低饱和（色散小）。二轮收紧：150/28 -> 118/45
    # （第一轮后腿间楔形边缘残留 mn 118-150 的白-衣色过渡带渐变）
    return mn >= 118 and (mx - mn) <= 45

def flood_clear(im, region):
    """区域内从所有低饱和亮色种子泛洪，连通块整体转透明。返回清除像素数。"""
    x0, y0, x1, y1 = region
    w, h = im.size
    px = im.load()
    seen = set()
    cleared = 0
    for sy in range(y0, min(y1, h)):
        for sx in range(x0, min(x1, w)):
            if (sx, sy) in seen:
                continue
            if not is_brightish_low_sat(px[sx, sy]):
                continue
            # BFS 连通（4邻域，全局图范围可走——楔形可跨出预选框边界）
            comp = []
            q = deque([(sx, sy)])
            seen.add((sx, sy))
            while q:
                cx, cy = q.popleft()
                comp.append((cx, cy))
                for nx, ny in ((cx-1, cy), (cx+1, cy), (cx, cy-1), (cx, cy+1)):
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen \
                            and is_brightish_low_sat(px[nx, ny]):
                        seen.add((nx, ny))
                        q.append((nx, ny))
            if len(comp) >= 40:  # 噪点保护：连通块太小不动
                for cx, cy in comp:
                    r, g, b, a = px[cx, cy]
                    px[cx, cy] = (r, g, b, 0)
                    cleared += 1
    return cleared

def main():
    os.makedirs(BACKUP, exist_ok=True)
    for rel in TARGETS:
        path = os.path.join(ROOT, rel)
        im = Image.open(path).convert("RGBA")
        side = "player" if "player" in rel else "enemy"
        total = 0
        for region in REGIONS[side]:
            total += flood_clear(im, region)
        bak = os.path.join(BACKUP, os.path.basename(rel))
        if not os.path.exists(bak):
            shutil.copy2(path, bak)
        im.save(path)
        print(f"[{rel}] cleared {total} px")

if __name__ == "__main__":
    main()
