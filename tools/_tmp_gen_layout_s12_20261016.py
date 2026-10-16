#!/usr/bin/env python3
"""v6.71 s12 布局生成（数学后处理路线）。

原管线（prototype_level_layout.py）依赖底图 docs/地图重设计/generated/大地图2_2560.png
——该文件从未入库、本地已失，管线断供。改从 prototype_level_layout.html（s11 定稿原型，
内嵌 100 点坐标 + 簇质心 cx/cy）提取 s11 点集，按计划要求对簇间距做 +28% 外扩：
    新点 = 簇质心 + (旧点 - 簇质心) × 1.28
链序/链拓扑/黑门/出生点全部不动；导出 data/world_map_layout_s12.gd。
"""
import json
import math
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HTML = os.path.join(ROOT, "docs", "地图重设计", "prototype_level_layout.html")
OUT = os.path.join(ROOT, "data", "world_map_layout_s12.gd")
S11 = os.path.join(ROOT, "data", "world_map_layout_s11.gd")

SPREAD = 1.28
W, H = 2560, 1440

html = open(HTML, encoding="utf-8").read()
pts = json.loads(re.search(r"const P = (\[.*?\]);", html, re.S).group(1))
home = json.loads(re.search(r"const HOME = (\{.*?\})", html).group(1))
gate = json.loads(re.search(r"const GATE = (\{.*?\})", html).group(1))
assert len(pts) == 100, len(pts)

# s11 相邻间距基线（链序 = 排序后 i 序，含首尾接 home/gate）
seq11 = [(home["x"], home["y"])] + [(p["x"], p["y"]) for p in sorted(pts, key=lambda q: q["i"])] + [(gate["x"], gate["y"])]
g11 = [math.hypot(seq11[i+1][0]-seq11[i][0], seq11[i+1][1]-seq11[i][1]) for i in range(len(seq11)-1)]

# 簇间距外扩
new = []
for p in pts:
    nx = p["cx"] + (p["x"] - p["cx"]) * SPREAD
    ny = p["cy"] + (p["y"] - p["cy"]) * SPREAD
    new.append({"i": p["i"], "x": int(round(max(0.0, min(float(W), nx)))),
                "y": int(round(max(0.0, min(float(H), ny))))})

# 全对重叠消解（外扩后相邻簇侵入；纯数学版无陆地掩膜，越界 clamp）
for _r in range(12):
    fixed = 0
    for i in range(100):
        for j in range(i + 1, 100):
            a, b = new[i], new[j]
            dx, dy = b["x"] - a["x"], b["y"] - a["y"]
            d = math.hypot(dx, dy)
            if d >= 52:
                continue
            if d < 1e-6:
                dx, dy, d = 0.0, -1.0, 1.0
            push = (58.0 - d) * 0.5
            a["x"] = int(max(0, min(W - 1, a["x"] - dx / d * push)))
            a["y"] = int(max(0, min(H - 1, a["y"] - dy / d * push)))
            b["x"] = int(max(0, min(W - 1, b["x"] + dx / d * push)))
            b["y"] = int(max(0, min(H - 1, b["y"] + dy / d * push)))
            fixed += 1
    if fixed == 0:
        break
print("重叠消解轮数: %d" % (_r + 1))

seq12 = [(home["x"], home["y"])] + [(p["x"], p["y"]) for p in sorted(new, key=lambda q: q["i"])] + [(gate["x"], gate["y"])]
g12 = [math.hypot(seq12[i+1][0]-seq12[i][0], seq12[i+1][1]-seq12[i][1]) for i in range(len(seq12)-1)]

print("s11 相邻间距: min %.0f max %.0f 平均 %.0f 中位 %.0f" %
      (min(g11), max(g11), sum(g11)/len(g11), sorted(g11)[len(g11)//2]))
print("s12 相邻间距: min %.0f max %.0f 平均 %.0f 中位 %.0f" %
      (min(g12), max(g12), sum(g12)/len(g12), sorted(g12)[len(g12)//2]))
# 燃料公式 clamp(距离px/48, 4, 60)（truck_travel.gd）触顶审计：>2880px 的边燃料封顶
print("燃料封顶边(px>2880): s11=%d s12=%d" %
      (sum(1 for g in g11 if g > 2880), sum(1 for g in g12 if g > 2880)))
# 重叠审计（全对 <52px）
rem = sum(1 for i in range(100) for j in range(i+1, 100)
          if math.hypot(new[i]["x"]-new[j]["x"], new[i]["y"]-new[j]["y"]) < 52)
print("s12 全对重叠(<52px): %d 处（s11 基线 %d 处）" % (rem, sum(
    1 for i in range(100) for j in range(i+1, 100)
    if math.hypot(pts[i]["x"]-pts[j]["x"], pts[i]["y"]-pts[j]["y"]) < 52)))

lines = [
    "# 自动生成：tools/_tmp_gen_layout_s12_20261016.py（v6.71 布局 s12）",
    "# 方案12 主地图布点：坐标 = 2560×1440 画布像素",
    "# 来源：s11 点集（prototype_level_layout.html 定稿原型内嵌数据，底图已失、",
    "# 原管线断供）按簇质心 cx/cy 外扩 %.2f（簇间距 +28%%，链拓扑不变）。" % SPREAD,
    "class_name WorldMapLayoutS12",
    "",
    "const HOME := Vector2(%d, %d)" % (home["x"], home["y"]),
    "const GATE := Vector2(%d, %d)" % (gate["x"], gate["y"]),
    "const POINTS: Array[Vector2] = [",
]
lines += ["\tVector2(%d, %d)," % (p["x"], p["y"]) for p in sorted(new, key=lambda q: q["i"])]
lines += ["]"]
open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
print("GD →", OUT)
