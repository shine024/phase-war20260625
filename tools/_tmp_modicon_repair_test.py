# -*- coding: utf-8 -*-
"""_tmp_modicon_repair_test.py —— 修复队列测试：审计未过张 → 加强对称措辞重掷 → 复审 → 过线替换

目标：试点中 R4 对称越线的两张（爆反装甲 37 / 增程弹 36，阈值 34）。
修复策略 = 原映射 prompt + 对称强化尾缀，重掷至多 3 版，过线即替换 pilot_winners。
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from _tmp_modicon_audit import audit as icon_audit  # noqa: E402
from _tmp_gen_modicon_pilot import ANCHOR, PILOT, call_api, KEYS, RAW, WIN, BASE  # noqa: E402

SYM_FIX = "，整体画面完全左右对称，主体严格位于正中轴线，两侧元素完全镜像一致"

TARGETS = ["ARM_03_REACTIVE_ARMOR", "ART_02_EXTENDED_RANGE"]


def main():
    report = {}
    for mod in TARGETS:
        name, line, hue, rarity, subject = PILOT[mod]
        prompt = ANCHOR.format(line=line, subject=subject) + SYM_FIX
        rolls = []
        winner = None
        for roll in range(1, 4):
            out = os.path.join(RAW, "%s_fix%d.png" % (mod, roll))
            if not call_api(prompt, KEYS[roll % len(KEYS)], out):
                continue
            m = icon_audit(out, sym=True, hue=hue)
            m["roll"] = "fix%d" % roll
            rolls.append(m)
            if m["pass"]:
                winner = (roll, m)
                break
        if winner:
            import shutil
            shutil.copyfile(os.path.join(RAW, "%s_fix%d.png" % (mod, winner[0])),
                            os.path.join(WIN, mod + ".png"))
        report[mod] = {"rolls": rolls, "repaired": winner is not None,
                       "best": winner[1] if winner else (rolls[-1] if rolls else None)}
        print(mod, "->", "REPAIRED fix%d" % winner[0] if winner else "STILL FAILING",
              flush=True)
        for m in rolls:
            print("   ", m["roll"], "sym=%s" % m.get("sym_rmse"), "pass=", m["pass"], flush=True)
    with open(os.path.join(BASE, "repair_test_report.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
