#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批次④ 批 4（二）：B 档卡图外科处置轮（2026-09-09）。

处置项取自 资产分档审计-2026-09-08 §卡图立绘 处置列（LUT 已在（一）完成，本脚本做：
  tighten   微缩放补白——内容 bbox 最长维 ≥86% 画布时收缩到 82% 居中（占比 80-95% 微超）
  grounding 底部接地暗部微抠——底缘连通的暗/半透明阴影清除（禁则 7）
  rim       背光缘补窄 rim——player 朝右=左缘 / enemy 朝左=右缘；写实系冰天青/科幻系青
执行顺序：grounding → rim → tighten（几何变化最后做）。全部完成后重跑脚锚+导入。
原图备份 _art_backup/*-preS2-2026-09-09.png。
"""
import os
import sys
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "assets", "card_icons")
BACKUP_DIR = r"F:\godot fair duet\_art_backup"

RIM_REAL = (150, 200, 230)   # 冰天青（写实系）
RIM_SCIFI = (100, 220, 230)  # 青（科幻系：fe/fut/drop）

# (rel_path, {treatments}, rim_side/色由前缀推)
JOBS = [
    ("player/ww1_sup_ford_ambulance", {"rim"}),
    ("player/ww2_inf_kar98k", {"rim"}),
    ("player/vis_player_072", {"grounding", "rim"}),
    ("player/vis_player_008", {"rim"}),
    ("player/cold_air_strike_fighter", {"tighten"}),
    ("player/mod_inf_patriot", {"tighten"}),
    ("player/mod_air_multirole", {"tighten"}),
    ("player/mod_sup_growler", {"tighten"}),
    ("player/vis_player_022", {"tighten"}),
    ("player/vis_player_113", {"tighten"}),
    ("player/vis_player_064", {"grounding"}),
    ("player/vis_player_063", {"grounding"}),
    ("player/fe_void_dimensional_soldier", {"grounding"}),
    ("player/fut_arm_hk07", {"grounding"}),
    ("player/vis_player_027", {"grounding"}),
    ("player/vis_player_114", {"grounding"}),
    ("player/drop_railgun", {"grounding", "rim", "tighten"}),
    ("player/fut_swarm", {"tighten"}),
    ("enemy/vis_enemy_049", {"rim"}),
    ("enemy/vis_enemy_056", {"tighten"}),
    ("enemy/vis_enemy_093", {"tighten"}),
]


def grounding_clear(img):
    """底缘连通的暗/半透明阴影清除（底部 22% 区域内）。"""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    y0 = int(h * 0.78)
    def shadow_like(x, y):
        r, g, b, a = px[x, y]
        if a == 0:
            return False
        bright = (r + g + b) / 3
        return (a < 235 and bright < 90) or bright < 42
    visited = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (h - 1, h - 2, h - 3):
            if y >= y0 and shadow_like(x, y) and not visited[y * w + x]:
                visited[y * w + x] = 1
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and y0 <= ny < h and not visited[ny * w + nx] and shadow_like(nx, ny):
                visited[ny * w + nx] = 1
                q.append((nx, ny))
    n = 0
    for y in range(y0, h):
        for x in range(w):
            if visited[y * w + x]:
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, 0)
                n += 1
    return img, n


def add_rim(img, rel):
    """背光缘补窄 rim：player 朝右=左缘扫描 / enemy 朝左=右缘扫描。科幻系前缀用青。"""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    is_scifi = any(k in rel for k in ("fe_", "fut_", "drop_"))
    rim = RIM_SCIFI if is_scifi else RIM_REAL
    from_left = not rel.startswith("enemy/")
    for y in range(h):
        rng = range(w) if from_left else range(w - 1, -1, -1)
        depth = 0
        for x in rng:
            r, g, b, a = px[x, y]
            if a < 60:
                if depth > 0:
                    break   # 已进轮廓又出缘（下一轮廓），停
                continue
            depth += 1
            if depth > 3:
                break
            k = (0.55, 0.38, 0.22)[depth - 1]
            nr = int(r * (1 - k) + rim[0] * k)
            ng = int(g * (1 - k) + rim[1] * k)
            nb = int(b * (1 - k) + rim[2] * k)
            px[x, y] = (nr, ng, nb, a)
    return img


def content_ratio(img):
    bbox = img.getbbox()
    if not bbox:
        return 0.0, None
    bw, bh = bbox[2] - bbox[0], bbox[3] - bbox[1]
    return max(bw / img.size[0], bh / img.size[1]), bbox


def tighten(img, target=0.82):
    img = img.convert("RGBA")
    ratio, bbox = content_ratio(img)
    if bbox is None or ratio < 0.86:
        return img, ratio, ratio
    w, h = img.size
    bw, bh = bbox[2] - bbox[0], bbox[3] - bbox[1]
    scale = min(target * w / bw, target * h / bh, 1.0)
    content = img.crop(bbox)
    nw, nh = max(1, int(bw * scale)), max(1, int(bh * scale))
    content = content.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.paste(content, ((w - nw) // 2, (h - nh) // 2), content)
    return canvas, ratio, content_ratio(canvas)[0]


def main() -> int:
    os.makedirs(BACKUP_DIR, exist_ok=True)
    for rel, treats in JOBS:
        path = os.path.join(BASE, rel + ".png")
        img = Image.open(path).convert("RGBA")
        bdst = os.path.join(BACKUP_DIR, os.path.basename(rel) + "-preS2-2026-09-09.png")
        if not os.path.exists(bdst):
            with open(path, "rb") as fi, open(bdst, "wb") as fo:
                fo.write(fi.read())
        log = []
        if "grounding" in treats:
            img, n = grounding_clear(img)
            log.append("接地清%dpx" % n)
        if "rim" in treats:
            img = add_rim(img, rel)
            log.append("rim补")
        if "tighten" in treats:
            r0, r1 = None, None
            img, r0, r1 = tighten(img)
            log.append("收紧%.0f%%->%.0f%%" % (r0 * 100, r1 * 100))
        img.save(path, "PNG")
        print("%-34s %s" % (rel, "  ".join(log)), flush=True)
    print("[SUMMARY] %d files done" % len(JOBS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
