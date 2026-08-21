# -*- coding: utf-8 -*-
"""新旧加成比率对照（v18 四源重构 · 校准分析）

对 30 个敌方相位师，计算产兵全局乘区的 旧 vs 新：
- 不变乘区（符文/序列/相位仪数值/配档/强化）两边相消，不参与比率
- 旧侧 = traits 8键 + 被动开局 buff 的【实际生效值】（复刻引擎子串匹配，含误路由）
- 新侧 = 技能树数值节点（仅语义正确项）+ 势力协同 + 元素维度 + 等级属性（待校准）
输出：逐 master 比率表 + 分档等级属性曲线建议

用法：python tools/compare_old_new_bonuses.py
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from classify_enemy_master_skills import passive_branch  # noqa: E402  复刻引擎分支判定

ROOT = os.path.normpath(os.path.join(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")))
BASELINE = os.path.join(ROOT, "docs", "migration_baseline.json")

# ── 新侧归类（修正后语义）──
# 元素类 effect → 元素维度（不再进通用攻击；值 = params.boost/damage_boost/bonus）
ELEMENT_EFFECTS = {"fire_damage_boost", "fire_mastery", "elemental_damage_boost",
                   "dual_element_boost", "goddess_mastery", "omni_mastery", "thunder_mastery"}
# B2 中语义正确的通用攻击类（保留为技能树数值节点）
ATK_CORRECT = {"formation_bonus", "global_damage_boost", "damage_boost_resistance"}
# B1 中语义正确的防御类
DEF_CORRECT = {"armor_boost"}
# traits 未支持 key 中的元素类（新侧进元素维度）
TRAIT_ELEMENT_KEYS = {"void_damage_boost", "fire_damage_boost", "thunder_mastery",
                      "goddess_mastery", "omni_mastery", "dual_element_boost"}
# 协同类（新侧进势力树；数值按 synergy 语义单列，不计通用攻防）
SYNERGY_EFFECTS = {"synergy_boost"}


def b2_boost(params: dict) -> float:
    return float(params.get("damage_boost", params.get("bonus", 0.20)))


def b1_bonus(params: dict) -> float:
    return float(params.get("bonus", 0.15))


def analyze(master: dict) -> dict:
    old_atk = old_def = old_hp = 1.0
    new_atk = new_def = new_hp = 1.0
    element_mult = 1.0
    synergy_val = 0.0
    detail = {"old_src": [], "removed": [], "element": [], "synergy": []}

    # ── traits ──
    fx_all = {}
    for tr in master.get("traits", []):
        fx = tr.get("effects", {}) or {}
        for k, v in fx.items():
            if isinstance(v, (int, float)):
                fx_all[k] = float(v)
    for k, v in fx_all.items():
        if k.startswith("atk_"):
            old_atk *= (1 + v); new_atk *= (1 + v)
        elif k.startswith("def_"):
            old_def *= (1 + v); new_def *= (1 + v)
        elif k == "hp":
            old_hp *= (1 + v); new_hp *= (1 + v)
        elif k in TRAIT_ELEMENT_KEYS:
            element_mult = min(element_mult * (1 + v), 2.0)
            detail["element"].append(f"trait.{k}+{v:.0%}")
        # crit/dodge/其他：非乘区维度，不计

    # ── passive_spells（旧=引擎实际生效；新=修正语义）──
    for sp in master.get("passive_spells", []):
        eff = str(sp.get("effect", "")).lower()
        params = sp.get("params", {}) or {}
        br = passive_branch(eff)
        if br is None:
            continue
        branch_name = br[0]
        if branch_name.startswith("B2"):
            old_atk *= (1 + b2_boost(params))
            detail["old_src"].append(f"{eff}+{b2_boost(params):.0%}攻")
            if eff in ATK_CORRECT:
                v = b2_boost(params)
                new_atk *= (1 + v)
            elif eff in ELEMENT_EFFECTS:
                v = float(params.get("boost", params.get("damage_boost", params.get("bonus", 0.2))))
                element_mult = min(element_mult * (1 + v), 2.0)
                detail["element"].append(f"{eff}+{v:.0%}元素")
            elif eff in SYNERGY_EFFECTS:
                synergy_val = b2_boost(params)
                detail["synergy"].append(f"{eff} {synergy_val:.0%}")
            else:
                detail["removed"].append(f"{eff} 误路由攻击+{b2_boost(params):.0%}→移除")
        elif branch_name.startswith("B1"):
            old_def *= (1 + b1_bonus(params))
            detail["old_src"].append(f"{eff}+{b1_bonus(params):.0%}防")
            if eff in DEF_CORRECT:
                new_def *= (1 + b1_bonus(params))
            else:
                detail["removed"].append(f"{eff} 误路由防御+{b1_bonus(params):.0%}→移除/改条件")
        # B3-B7：boss 自身/机制类，非产兵乘区，跳过

    return {"old": (old_atk, old_def, old_hp), "new": (new_atk, new_def, new_hp),
            "element": element_mult, "synergy": synergy_val, "detail": detail}


def main():
    data = json.load(open(BASELINE, encoding="utf-8"))
    masters = data["masters"]
    print("=" * 110)
    print("%-22s %-6s | %-21s | %-21s | 攻击比  防御比  血量比 | 元素" % ("master", "Lv", "旧(攻/防/血)", "新-无等级(攻/防/血)"))
    print("-" * 110)
    rows = []
    for m in sorted(masters, key=lambda x: int(x["id"].split("_")[-1])):
        r = analyze(m)
        oa, od, oh = r["old"]
        na, nd, nh = r["new"]
        em = r["element"]
        # 元素计入攻击比的口径：元素乘区作用在最终伤害（类似攻击），单列同时给"含元素"口径
        print("%-22s %-6d | %+7.1f%% /%+6.1f%% /%+6.1f%% | %+7.1f%% /%+6.1f%% /%+6.1f%% | %.3f  %.3f  %.3f | %s" % (
            m["id"].replace("enemy_master_", "m") + " " + m["name"][:6], m["level"],
            (oa - 1) * 100, (od - 1) * 100, (oh - 1) * 100,
            (na - 1) * 100, (nd - 1) * 100, (nh - 1) * 100,
            (na * em) / oa, nd / od, nh / oh,
            ("×%.2f" % em) if em > 1.0 else "—"))
        rows.append({"id": m["id"], "lv": m["level"], "old": r["old"], "new": r["new"],
                     "element": em, "detail": r["detail"]})

    # ── 等级属性曲线建议：按档位取 攻击缺口 中位数 ──
    print("\n" + "=" * 110)
    print("等级属性曲线建议（目标：新总攻击 ≈ 旧总攻击 → 档位加成 = 攻击缺口中位数）")
    tiers = [(5, 10), (11, 20), (21, 25), (26, 30)]
    for lo, hi in tiers:
        grp = [r for r in rows if lo <= r["lv"] <= hi]
        if not grp:
            continue
        gaps_atk = sorted(r["old"][0] / (r["new"][0] * r["element"]) - 1.0 for r in grp)
        gaps_def = sorted(r["old"][1] / r["new"][1] - 1.0 for r in grp)
        gaps_hp = sorted(r["old"][2] / r["new"][2] - 1.0 for r in grp)
        med = lambda g: g[len(g) // 2]
        print("  Lv%-2d-%-2d (%d师): 攻击缺口中位 %+6.1f%% | 防御 %+6.1f%% | 血量 %+6.1f%%" % (
            lo, hi, len(grp), med(gaps_atk) * 100, med(gaps_def) * 100, med(gaps_hp) * 100))

    # 整体
    all_gap_atk = [r["old"][0] / (r["new"][0] * r["element"]) - 1.0 for r in rows]
    all_gap_atk.sort()
    print("  全体中位: %+6.1f%%（负=新侧偏强，正=新侧偏弱需等级属性补）" % (all_gap_atk[len(all_gap_atk) // 2] * 100))

    # 误路由移除明细（前 12 条示例）
    print("\n误路由移除明细（新侧不再生效的旧意外加成，抽样）:")
    shown = 0
    for r in rows:
        for item in r["detail"]["removed"]:
            if shown >= 12:
                break
            print("  %s: %s" % (r["id"], item))
            shown += 1


if __name__ == "__main__":
    main()
