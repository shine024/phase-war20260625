# -*- coding: utf-8 -*-
"""按 b5_decisions.json 的 deletes 字段移走废卷（2026-10-04 用户导出）。
所有 grid 攻击卷（R1-R3）→ staging/_b5_backup_gridrolls_20261004/。不硬删。"""
import io
import json
import os
import shutil
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
BK = os.path.join(OUT, "_b5_backup_gridrolls_20261004")
os.makedirs(BK, exist_ok=True)

with open(os.path.join(OUT, "b5_decisions.json"), encoding="utf-8") as f:
    j = json.load(f)

total = 0
for key, cands in (j.get("deletes") or {}).items():
    for cd in cands:
        names = [key + "_attack_raw_%s.png" % cd.split("_")[-1]] if cd.startswith(key + "_R") else []
        names += ["%s_attack_sheet_832.png" % cd, "%s_attack_cells.png" % cd,
                  "%s_attack_cells_dark.png" % cd, "%s_attack_anim.gif" % cd,
                  "%s_attack_anim_pal8.gif" % cd]
        for f in names:
            src = os.path.join(OUT, f)
            if os.path.exists(src):
                shutil.move(src, os.path.join(BK, f))
                total += 1
print("moved %d files → %s" % (total, os.path.relpath(BK, ROOT)))

# 拍板 idle 采纳清单落盘（部署段用）
with open(os.path.join(OUT, "b5_adopted_idle.txt"), "w", encoding="utf-8") as f:
    for k, v in (j.get("decisions") or {}).items():
        if v == "idle":
            f.write(k + "\n")
print("idle 采纳：", [k for k, v in (j.get("decisions") or {}).items() if v == "idle"])
