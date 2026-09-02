#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""balance-check：MOD 数值上限 + 进化路径增长审查"""
import json, re, os, glob
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ═══════════ MOD 审查 ═══════════
issues, warns, info = [], [], []

# GDScript 字典 value 语法：key = value（gdtoolkit 都不吃的，用正则）
def strip_comments(s):
    return re.sub(r"#.*", "", s)

mod_files = sorted(glob.glob(os.path.join(ROOT, "data", "modification_modules", "*_mods.gd")))
mod_stats = {}
atk_pct_max, interval_cut_max, hp_pct_max = {}, {}, {}
# v22: 带 float/int 类型感知的逐条记录（同键双语义——float=百分比/int=平加，写错类型=语义错误）
typed_hits = []          # (fname, mod_id, key, value, is_float)
era_band_hits = []       # (fname, mod_id, lo, hi)
entry_re = re.compile(r'\t+"([a-z0-9_]+)"\s*=\s*\{')
for f in mod_files:
    fname = os.path.basename(f)
    src = strip_comments(open(f, encoding="utf-8").read())
    # 顶层条目：某 id = { ... }（可能嵌套 level_effects）——按括号配对粗切
    for m in re.finditer(r'(\w+)\s*=\s*\{', src):
        pass  # 结构复杂，改为逐 key 扫描
    # 逐 key 扫描数值效果
    for km in re.finditer(r'(\w+)\s*=\s*(-?\d+(?:\.\d+)?)\b', src):
        k, v = km.group(1), float(km.group(2))
        mod_stats.setdefault(fname, defaultdict(list))[k].append(v)
    # v22: 类型感知扫描（按条目归属；条目=带引号 key 的 dict 开启，段截止到下一条目）
    for em in entry_re.finditer(src):
        mod_id = em.group(1)
        nxt = entry_re.search(src, em.end())
        seg = src[em.end(): nxt.start() if nxt else em.end() + 1400]
        for km in re.finditer(r'(\w+)\s*=\s*(-?\d+)(\.\d+)?\b', seg):
            typed_hits.append((fname, mod_id, km.group(1), float(km.group(2) + (km.group(3) or "")), km.group(3) is not None))
    for bm in re.finditer(r'era_band\s*=\s*\[\s*(\d)\s*,\s*(\d+)\s*\]', src):
        mod_id = "<%s@%d>" % (bm.group(0), bm.start())
        era_band_hits.append((fname, mod_id, int(bm.group(1)), int(bm.group(2))))

# 关注键：attack_light/armor/air 增量、attack_interval 减少、hp、attack_*_percent
for fname, kv in sorted(mod_stats.items()):
    # 攻击间隔减少（负值 = 加速）
    iv = kv.get("attack_interval", [])
    if iv:
        worst = min(iv)
        if worst < -0.40:
            issues.append(f"{fname}: attack_interval 减少 {worst} 超过 -0.40 上限(v6.1)")
        elif worst < -0.30:
            warns.append(f"{fname}: attack_interval 减少 {worst} 接近上限(-0.30~-0.40)")
    # 三维攻击增量上限（合理范围 < 500）
    for atk in ("attack_light", "attack_armor", "attack_air"):
        vals = [v for v in kv.get(atk, []) if v > 0]
        if vals and max(vals) > 400:
            warns.append(f"{fname}: {atk} 最大增量 {max(vals):.0f} 偏高(>400)")
    # hp 增量
    vals = [v for v in kv.get("hp", []) if v > 0]
    if vals and max(vals) > 800:
        warns.append(f"{fname}: hp 最大增量 {max(vals):.0f} 偏高(>800)")
    # 百分比键
    for k, vals in kv.items():
        if "percent" in k or "pct" in k:
            big = [v for v in vals if abs(v) > 60]
            if big:
                warns.append(f"{fname}: {k} 出现 |{max(big)}|>60%")

# ═══ v22 四通道语义 + era_band 检查 ═══
# 7 个双语义基础键：float=百分比乘区（|v| 必须 ≤1.0，>1.0 即"想写 0.30 写成 30.0"式错误）；
# int=平加（合理区间 0<v≤250；负 flat 攻击减益仅弹药类副作用，≤ -60 告警）。
DUAL_KEYS = {"attack_light", "attack_armor", "attack_air",
             "defense_light", "defense_armor", "defense_air", "max_hp"}
for fname, mod_id, k, v, is_float in typed_hits:
    if k in DUAL_KEYS:
        if is_float and abs(v) > 1.0:
            issues.append(f"{fname}:{mod_id} {k}={v} 为 float>1.0——float 走百分比乘区，疑为平加值误写（应写 int 或 <stat>_pct）")
        elif not is_float and v > 250:
            warns.append(f"{fname}:{mod_id} {k}={v:.0f} 平加值 >250 偏高")
        elif not is_float and v < -60:
            warns.append(f"{fname}:{mod_id} {k}={v:.0f} 平加负值 <-60 偏低")
    elif k.endswith("_pct"):
        if v > 1.0:
            issues.append(f"{fname}:{mod_id} {k}={v} >1.0——百分比键上限 1.0")
    elif k.endswith("_set"):
        # v25.1: 替换值域按 stat 维度分档——坦克对甲基数是步兵对轻的 3-7 倍
        # （era2 中位 atk_a 508 / era4 1865），attack_armor_set 上限放宽到 800
        cap = 800 if k == "attack_armor_set" else 400
        if v <= 0 or v > cap:
            issues.append(f"{fname}:{mod_id} {k}={v} 替换值超出 (0,{cap}] 合理区间")
for fname, mod_id, lo, hi in era_band_hits:
    if not (0 <= lo <= hi <= 4):
        issues.append(f"{fname}:{mod_id} era_band [{lo},{hi}] 非法（须 0≤lo≤hi≤4）")
banded = len(era_band_hits)
info.append(f"era_band 覆盖 {banded} 条（其余为全时代 [0,4]）")

print("MOD_FILES", len(mod_files))
print("MOD_ISSUES", json.dumps(issues, ensure_ascii=False))
print("MOD_WARNS", json.dumps(warns, ensure_ascii=False))
print("MOD_INFO", json.dumps(info, ensure_ascii=False))

# level_effects 单调性：1→2→3 应递增（同键）
mono_issues = []
for f in mod_files:
    src = strip_comments(open(f, encoding="utf-8").read())
    for lm in re.finditer(r"level_effects\s*=\s*\{(.{0,800}?)\}\s*\}", src, re.S):
        blob = lm.group(1)
        # 抽每级同键值
        per_level = defaultdict(dict)
        for lev_m in re.finditer(r"(\d)\s*:\s*\{([^}]*)\}", blob):
            lv = int(lev_m.group(1))
            for km in re.finditer(r"(\w+)\s*=\s*(-?\d+(?:\.\d+)?)", lev_m.group(2)):
                per_level[lv][km.group(1)] = float(km.group(2))
        for k in ("attack_light", "attack_armor", "attack_air", "hp", "defense_armor",
                  "attack_light_set", "attack_armor_set", "attack_air_set", "defense_armor_pct"):
            seq = [per_level.get(l, {}).get(k) for l in (1, 2, 3)]
            seq = [x for x in seq if x is not None]
            if len(seq) == 3 and not (seq[0] < seq[1] < seq[2]):
                mono_issues.append(f"{os.path.basename(f)}: level_effects {k} 非递增 {seq}")
print("MOD_MONO_ISSUES", json.dumps(mono_issues, ensure_ascii=False))

# ═══════════ 进化路径审查 ═══════════
evo_issues, evo_warns = [], []
for f in sorted(glob.glob(os.path.join(ROOT, "data", "evolution_paths", "*_evolution.gd"))):
    fname = os.path.basename(f)
    src = strip_comments(open(f, encoding="utf-8").read())
    stages = {}
    for sm in re.finditer(r"(E\d)\s*=\s*\{([^{}]*)\}", src):
        sid, body = sm.group(1), sm.group(2)
        d = {}
        for km in re.finditer(r"(\w+)\s*=\s*(-?\d+(?:\.\d+)?)", body):
            d[km.group(1)] = float(km.group(2))
        if d:
            stages[sid] = d
    order = sorted(stages.keys(), key=lambda s: int(s[1:]))
    for a, b in zip(order, order[1:]):
        sa, sb = stages[a], stages[b]
        for k in ("max_hp", "power", "attack_light", "attack_armor", "attack_air"):
            va, vb = sa.get(k), sb.get(k)
            if va is not None and vb is not None:
                if vb < va:
                    evo_issues.append(f"{fname}: {a}->{b} {k} 退化 {va:.0f}→{vb:.0f}")
                elif va > 0 and vb / va < 1.15:
                    evo_warns.append(f"{fname}: {a}->{b} {k} 增长不足 +{vb/va*100-100:.0f}%（<15%）")
        # 等级门槛递进
        la, lb = sa.get("level"), sb.get("level")
        if la is not None and lb is not None and lb <= la:
            evo_issues.append(f"{fname}: {a}->{b} 等级门槛不递进 {la:.0f}→{lb:.0f}")
print("EVO_ISSUES", json.dumps(evo_issues, ensure_ascii=False))
print("EVO_WARNS", json.dumps(evo_warns, ensure_ascii=False))

# ═══════════ 制造品质池审查（v26 批次4）═══════════
# 数据源 data/manufacture_pools.gd：GATE / POOLS / COSTS / CAPTURED_ROLL_WEIGHTS /
# ANALYZER_YIELD / PITY_*。检查：权重和、档位间稀有度单调、成本递增、
# 产量表对齐、暗保底参数。
mf_issues, mf_warns = [], []
mf_path = os.path.join(ROOT, "data", "manufacture_pools.gd")
mf = strip_comments(open(mf_path, encoding="utf-8").read())

RARITY_ORDER = ["common", "uncommon", "rare", "epic", "legendary", "mythic"]

def _parse_weight_dict(block):
    """解析 {\"rare\": 12, ...} 或 {"rare": 12, ...} 形态的权重字典 → dict"""
    return {k: float(v) for k, v in re.findall(r'"(\w+)"\s*:\s*(-?\d+(?:\.\d+)?)', block)
            if k in RARITY_ORDER}

# ── POOLS：五档品质池 ──
pools_m = re.search(r"POOLS\s*(?::=|=)\s*\{(.*?)\n\}", mf, re.S)
if not pools_m:
    mf_issues.append("manufacture_pools.gd: 找不到 POOLS 定义")
else:
    pools_src = pools_m.group(1)
    tier_blocks = re.findall(r'(\d)\s*:\s*\[(.*?)\]', pools_src, re.S)
    parsed = {}
    for tier_str, arr_src in tier_blocks:
        tier = int(tier_str)
        entries = re.findall(r'\{\s*"r"\s*:\s*"(\w+)"\s*,\s*"w"\s*:\s*(\d+(?:\.\d+)?)\s*\}', arr_src)
        d = {r: float(w) for r, w in entries}
        parsed[tier] = d
        if not d:
            mf_issues.append(f"POOL 档位 {tier} 无有效条目")
            continue
        total = sum(d.values())
        if abs(total - 100.0) > 0.01:
            mf_issues.append(f"POOL 档位 {tier} 权重和 {total:.1f} ≠ 100")
    # 档位间方向性：common 应随档位单调递减（情报档提升 = 池子变好）；
    # epic+ 应单调不降；uncommon/rare 允许驼峰（中期上升、后期让位史诗，设计意图）。
    for a, b in zip(sorted(parsed), sorted(parsed)[1:]):
        for r in RARITY_ORDER:
            wa, wb = parsed.get(a, {}).get(r), parsed.get(b, {}).get(r)
            if wa is None or wb is None:
                continue
            if r == "common" and wb > wa:
                mf_issues.append(f"POOL 档 {a}→{b} common 反常上升 {wa:.0f}→{wb:.0f}")
            if r in ("epic", "legendary", "mythic") and wb < wa:
                mf_issues.append(f"POOL 档 {a}→{b} 高稀有度 {r} 退化 {wa:.0f}→{wb:.0f}")

# ── COSTS：各档制造成本应递增 ──
costs_m = re.search(r"COSTS\s*(?::=|=)\s*\[(.*?)\n\]", mf, re.S)
if costs_m:
    cost_rows = re.findall(r'\{([^{}]*)\}', costs_m.group(1))
    cost_dicts = []
    for row in cost_rows:
        d = {k: float(v) for k, v in re.findall(r'"(\w+)"\s*:\s*(-?\d+(?:\.\d+)?)', row)}
        if d:
            cost_dicts.append(d)
    for a, b in zip(cost_dicts, cost_dicts[1:]):
        for res in ("nano", "energy", "alloy", "crystal"):
            va, vb = a.get(res), b.get(res)
            if va is not None and vb is not None and vb < va:
                mf_issues.append(f"COSTS {res} 档 {len(cost_dicts)} 档位间退化 {va:.0f}→{vb:.0f}")

# ── CAPTURED_ROLL_WEIGHTS：缴获品质（无神话）──
cap_m = re.search(r'CAPTURED_ROLL_WEIGHTS\s*(?::=|=)\s*\{([^{}]*)\}', mf)
if cap_m:
    cap = _parse_weight_dict(cap_m.group(1))
    total = sum(cap.values())
    if abs(total - 100.0) > 0.01:
        mf_issues.append(f"CAPTURED_ROLL_WEIGHTS 权重和 {total:.1f} ≠ 100")
    if "mythic" in cap and cap["mythic"] > 0:
        mf_issues.append("缴获品质不应出神话（制造专属）")

# ── ANALYZER_YIELD：按稀有度单调递增 ──
ay_m = re.search(r"ANALYZER_YIELD\s*(?::=|=)\s*\[(.*?)\]", mf, re.S)
if ay_m:
    yields = [float(x) for x in re.findall(r'-?\d+(?:\.\d+)?', ay_m.group(1))]
    if len(yields) != len(RARITY_ORDER):
        mf_warns.append(f"ANALYZER_YIELD {len(yields)} 项 ≠ 稀有度轴 {len(RARITY_ORDER)} 档")
    for a, b in zip(yields, yields[1:]):
        if b < a:
            mf_issues.append(f"ANALYZER_YIELD 非单调 {a}→{b}（高品质产出应 ≥ 低品质）")

# ── 暗保底参数 ──
pity_th = re.search(r'PITY_THRESHOLD\s*(?::=|=)\s*(\d+)', mf)
pity_bo = re.search(r'PITY_BOOST\s*(?::=|=)\s*(\d+(?:\.\d+)?)', mf)
if pity_th and int(pity_th.group(1)) < 1:
    mf_issues.append("PITY_THRESHOLD 应 ≥ 1（连续未出稀有次数阈值）")
if pity_bo and float(pity_bo.group(1)) < 1.0:
    mf_issues.append("PITY_BOOST 应 ≥ 1.0（保底倍率必须放大权重）")

print("MF_ISSUES", json.dumps(mf_issues, ensure_ascii=False))
print("MF_WARNS", json.dumps(mf_warns, ensure_ascii=False))
