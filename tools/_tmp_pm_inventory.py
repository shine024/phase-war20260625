# -*- coding: utf-8 -*-
"""P2-2 决策支持盘点：30 位相位师 master 的上场/立绘/帧动画状态。"""
import re
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES = [
    "enemy_phase_masters_ww1.gd", "enemy_phase_masters_ww2.gd",
    "enemy_phase_masters_cold.gd", "enemy_phase_masters_modern.gd",
    "enemy_phase_masters_future.gd",
]
GARRISON = os.path.join(ROOT, "data", "phase_master_garrison.gd")

g_txt = open(GARRISON, encoding="utf-8").read()
g_map = dict(re.findall(r'(\d+):\s*"(enemy_master_\d+)"', g_txt))
deployed = set(g_map.values())

masters = []
for fn in FILES:
    txt = open(os.path.join(ROOT, "data", fn), encoding="utf-8").read()
    for m in re.finditer(r'"id":\s*"(enemy_master_\d+)"[\s\S]{0,400}?"name":\s*"([^"]+)"', txt):
        masters.append((m.group(1), m.group(2), fn.replace("enemy_phase_masters_", "").replace(".gd", "")))

era_cn = {"ww1": "一战", "ww2": "二战", "cold": "冷战", "modern": "现代", "future": "近未来"}
print("total masters:", len(masters))
print("%-18s %-8s %-6s %-8s %s" % ("id", "name", "era", "deployed", "garrison_level"))
for mid, name, era in masters:
    lv = next((l for l, m in g_map.items() if m == mid), "")
    print("%-18s %-8s %-6s %-8s %s" % (mid, name, era_cn.get(era, era),
          "是" if mid in deployed else "否", lv))

never = [m for m in masters if m[0] not in deployed]
print("\n从未上场 (%d):" % len(never), ", ".join("%s(%s)" % (n, i[-3:]) for i, n, e in never))
