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
