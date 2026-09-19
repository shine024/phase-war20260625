# -*- coding: utf-8 -*-
"""_tmp_gen_modicon_supp.py —— 主跑批缺项补齐：inf_24_urban_warfare（巷战教范）
3 掷 → 审计选优 → 胜者并入 full_winners + full_report，并重出 infantry 族对比表。
"""
import json
import os
import shutil
import sys
import concurrent.futures

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from _tmp_modicon_audit import audit as icon_audit  # noqa: E402
from _tmp_gen_modicon_pilot import ANCHOR, call_api, KEYS  # noqa: E402
from _tmp_gen_modicon_full import RAW, WIN, BASE, valid, select_best, SYM_FIX  # noqa: E402

MID = "inf_24_urban_warfare"
LINE, HUE, RARITY = "橄榄绿色", 80, "rare"
SUBJECT = "一段城镇街巷楼群与交叉弹道弧线组成的徽记"
PROMPT = ANCHOR.format(line=LINE, subject=SUBJECT)


def roll(tag):
    out = os.path.join(RAW, "%s_%s.png" % (MID, tag))
    if valid(out):
        return True
    for attempt in range(2):
        if call_api(PROMPT, KEYS[(attempt + 1) % len(KEYS)], out):
            return True
    return False


def main():
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex:
        list(ex.map(roll, ["r1", "r2", "r3"]))
    best = select_best(MID, HUE)
    fix = []
    if best and not best[0]["pass"]:
        for k in range(1, 4):
            tag = "fix%d" % k
            out = os.path.join(RAW, "%s_%s.png" % (MID, tag))
            if call_api(PROMPT + SYM_FIX, KEYS[k % len(KEYS)], out) and valid(out):
                m = icon_audit(out, sym=True, hue=HUE)
                m["tag"] = tag
                fix.append(m)
                if m["pass"]:
                    best = [m] + best
                    break
    if not best:
        print("SUPP FAIL: no image")
        return
    w = best[0]
    shutil.copyfile(os.path.join(RAW, "%s_%s.png" % (MID, w["tag"])),
                    os.path.join(WIN, MID + ".png"))
    rp = os.path.join(BASE, "full_report.json")
    report = json.load(open(rp, encoding="utf-8"))
    report[MID] = {"name": "巷战教范", "family": "infantry", "rarity": RARITY,
                   "best_tag": w["tag"], "best": w, "repaired": w["tag"].startswith("fix"),
                   "fix_rolls": fix}
    json.dump(report, open(rp, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("SUPP OK %s best=%s pass=%s %s" % (MID, w["tag"], w["pass"],
          ",".join(w["fails"]) or ""))


if __name__ == "__main__":
    main()
