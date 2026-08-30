#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""balance-check skill：卡牌表数值审查（unified_card_table 解析 + 四维检查）"""
import json, re, sys, os
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TBL = os.path.join(ROOT, "data", "unified_card_table.gd")

def parse_entries(path):
    src = open(path, encoding="utf-8").read()
    # 去注释（行注释）
    src = re.sub(r"#.*", "", src)
    entries = []
    for m in re.finditer(r"\{([^{}]*)\}", src):
        body = m.group(1)
        if '"card_id"' not in body:
            continue
        e = {}
        for km in re.finditer(r'"(\w+)"\s*:\s*("(?:[^"\\]|\\.)*"|-?\d+(?:\.\d+)?|true|false|\[[^\]]*\]|Tier\.\w+)', body):
            k, v = km.group(1), km.group(2)
            if v.startswith('"'):
                e[k] = v.strip('"')
            elif v.startswith('['):
                e[k] = v
            elif v in ('true', 'false'):
                e[k] = (v == 'true')
            elif v.startswith('Tier.'):
                e[k] = TIER_NAMES.get(v[5:], -1)
            else:
                e[k] = float(v) if '.' in v else int(v)
        if e.get('card_id'):
            entries.append(e)
    return entries

TIER_NAMES = {}
# Tier 枚举顺序：GRUNT=0? 从文件头抓
src = open(TBL, encoding="utf-8").read()
m = re.search(r"enum Tier\s*\{([^}]*)\}", re.sub(r"#.*", "", src))
if m:
    for i, name in enumerate([s.strip() for s in m.group(1).split(",") if s.strip()]):
        TIER_NAMES[name.split("=")[0].strip()] = i

EraName = ["WW1", "WW2", "Cold", "Modern", "NearFuture"]
KindName = ["轻装", "装甲", "支援", "空中", "堡垒"]
CK_BY_ERA_HP_ORDER = None  # skill: 装甲HP > 步兵HP > 其他

entries = parse_entries(TBL)
players = [e for e in entries if not e.get("enemy_only", False)]
enemies = [e for e in entries if e.get("enemy_only", False)]
out = {"total": len(entries), "player": len(players), "enemy": len(entries) - len(players)}
print("PARSED", json.dumps(out))

issues = []
warns = []

# ── 1) tier 枚举解析 ──
print("TIER_MAP", json.dumps(TIER_NAMES))

# ── 2) 同 (era, kind) 内 tier 递进：HP 与主攻（取三维攻击最大值）──
groups = defaultdict(list)
for e in players:
    groups[(e["era"], e["combat_kind"])].append(e)
for (era, ck), es in sorted(groups.items()):
    tiers = defaultdict(list)
    for e in es:
        tiers[e.get("tier", -1)].append(e)
    tk = sorted(tiers.keys())
    if len(tk) < 2:
        continue
    med = {}
    for t in tk:
        hps = sorted(x["base_hp"] for x in tiers[t])
        atks = sorted(max(x.get("atk_l",0), x.get("atk_a",0), x.get("atk_air",0)) for x in tiers[t])
        med[t] = (hps[len(hps)//2], atks[len(atks)//2])
    for a, b in zip(tk, tk[1:]):
        if med[a][0] and med[b][0] and med[b][0] < med[a][0] * 0.98:
            issues.append(f"HP递进倒挂 era{era}({EraName[era]}) kind{ck}({KindName[ck]}) tier{a}={med[a][0]} > tier{b}={med[b][0]}")
        if med[a][1] and med[b][1] < med[a][1] * 0.85:
            warns.append(f"ATK递进平/倒 era{era} kind{ck} tier{a}={med[a][1]} -> tier{b}={med[b][1]}")

# ── 3) 装甲 vs 步兵 HP 关系（per era, GRUNT 档）──
for era in range(5):
    inf = [e for e in players if e["era"]==era and e["combat_kind"]==0 and e.get("tier")==min(TIER_NAMES.values()) if isinstance(min(TIER_NAMES.values()), int)]
# 简化：每时代比较 轻装 vs 装甲 的中位 HP（全部 tier 合并会受 tier 混淆，用 GRUNT）
for era in range(5):
    g = [e for e in players if e["era"]==era]
    grunts = [e for e in g if e.get("tier",0)==0]
    inf = [e["base_hp"] for e in grunts if e["combat_kind"]==0]
    arm = [e["base_hp"] for e in grunts if e["combat_kind"]==1]
    if inf and arm:
        mi, ma = sorted(inf)[len(inf)//2], sorted(arm)[len(arm)//2]
        if ma <= mi:
            issues.append(f"GRUNT装甲HP({ma}) <= 轻装HP({mi}) @era{era}({EraName[era]})")

# ── 4) DPS 一致性：主 DPS = max_atk × 对应攻速；按 (era,kind,tier) 看离散度 ──
dps_out = []
for (era, ck), es in sorted(groups.items()):
    for e in es:
        spds = {"l": e.get("atk_l_speed",1.0), "a": e.get("atk_a_speed",1.0), "air": e.get("atk_air_speed",1.0)}
        main_atk = max(e.get("atk_l",0), e.get("atk_a",0), e.get("atk_air",0))
        main_key = ["l","a","air"][[e.get("atk_l",0), e.get("atk_a",0), e.get("atk_air",0)].index(main_atk)]
        e["_dps"] = main_atk * spds[main_key]
# per (era, ck, tier) 离散度
disp = defaultdict(list)
for e in players:
    disp[(e["era"], e["combat_kind"], e.get("tier",0))].append(e)
for k, es in sorted(disp.items()):
    if len(es) < 2:
        continue
    ds = [e["_dps"] for e in es if e["_dps"] > 0]
    if len(ds) >= 2 and min(ds) > 0 and max(ds)/min(ds) > 3.0:
        names = [(e["card_id"], round(e["_dps"],1)) for e in es]
        warns.append(f"DPS同档离散>3x era{k[0]} kind{k[1]} tier{k[2]}: {names}")

# ── 5) 攻速/前摇 sanity ──
for e in entries:
    for pre in ("atk_l","atk_a","atk_air"):
        sp = e.get(pre+"_speed", None)
        if sp is not None and (sp <= 0 or sp > 4.0):
            issues.append(f"攻速异常 {e['card_id']} {pre}_speed={sp}")
        wu = e.get(pre+"_windup")
        ac = e.get(pre+"_active")
        if wu is not None and (wu < 0 or wu > 3.0):
            issues.append(f"前摇异常 {e['card_id']} {pre}_windup={wu}")
        if ac is not None and (ac < 0 or ac > 3.0):
            issues.append(f"动作异常 {e['card_id']} {pre}_active={ac}")

# ── 6) HP/攻防零值与防御合理性 ──
for e in entries:
    if e["base_hp"] <= 0:
        issues.append(f"HP<=0: {e['card_id']}")
    for d in ("def_l","def_a","def_air"):
        v = e.get(d)
        if v is not None and (v < 0 or v > 500):
            warns.append(f"防御越界 {e['card_id']} {d}={v}")

# ── 7) 时代间同 kind 同 tier 中位递进（跨 era 单调性）──
era_med = defaultdict(dict)
for era in range(5):
    for ck in range(5):
        es = [e for e in players if e["era"]==era and e["combat_kind"]==ck and e.get("tier",0)==0]
        if es:
            hp = sorted(e["base_hp"] for e in es)
            era_med[ck][era] = hp[len(hp)//2]
for ck, m in sorted(era_med.items()):
    eras = sorted(m.keys())
    seq = [m[x] for x in eras]
    for a, b in zip(eras, eras[1:]):
        if m[b] < m[a]:
            issues.append(f"GRUNT HP 时代倒挂 kind{ck}({KindName[ck]}): era{a}={m[a]} > era{b}={m[b]}")

print("ISSUES", json.dumps(issues, ensure_ascii=False))
print("WARNS", json.dumps(warns, ensure_ascii=False))

# 附：DPS 明细导出供参考
dump = [{k: e.get(k) for k in ("card_id","display_name","era","combat_kind","tier","base_hp","power","atk_l","atk_a","atk_air","atk_l_speed","atk_a_speed","atk_air_speed","def_l","def_a","def_air","_dps","enemy_only","range_value","deploy_speed")} for e in entries]
with open(os.path.join(ROOT, "docs", "_balance_dump_cards.json"), "w", encoding="utf-8") as f:
    json.dump(dump, f, ensure_ascii=False)
print("DUMPED docs/_balance_dump_cards.json")
