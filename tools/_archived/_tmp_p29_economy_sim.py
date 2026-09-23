#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P2-9 经济面离线模拟：击杀掉真卡通道（generic capture）掉率档位扫描。

hermes 计划 Task 2.1。零游戏代码改动——本脚本只读 res:// 数据真身 + 离线蒙特卡洛，
产出 docs/P2-9经济模拟_p29_economy_sim.md（三张对照表 + 假设清单 + M4 拍板选项）。

复跑：python tools/_archived/_tmp_p29_economy_sim.py
（自动重生成报告全文；固定随机种子，结果可复现。）

数据真身对照（全部 2026-09-22 核对）：
  data/level_eras.gd            ERA_WAVES / ERA_SPAWN_COUNT / ERA_DROP_MULTIPLIER(WW1=0.70, v37)
  data/level_spawn_sequences.gd 波次 composition 公式（elite 0.15+0.25p，末波 boss 0.40+0.30p）
  managers/battle/battle_damage_system.gd
                                GENERIC_CAPTURE_NORMAL_CHANCE=0.02 / ELITE=0.15 / MAX_PER_BATTLE=2（v27.18 现行档）
                                chance × drop_mult（ERA_DROP_MULTIPLIER，clamp ≤1）
  data/enemy_archetypes_*.gd    显式 drops 表 6 条（先例卡 ww1_saint@0.2 / ww2_panther@0.25 /
                                ww2_kingtiger@1.0 / ww1_a7v@1.0 / cold_t72@0.3 / abrams_mk2@0.4）
                                + roll_nano_materials_on_kill 默认档（boss 18-38@1.0 / elite 5-12@0.88 /
                                basic 2-7@0.42）
  resources/drop_tables.gd      战后掉落表（保底 nano / 随机 1-3~1-4 抽 / 三星 era_N 卡 /
                                _REFINED_ALLOY_BASE / boss 表）
  data/first_clear_rewards.gd   首通公式（晶体 20+2L，L%20 ×2.5；纳米 200+30L；合金 15+2L；能量 5+L/2）
  data/basic_resources.gd       get_drops_for_level（纳米 (50+10L)×mult 等）
  managers/save_manager.gd:947  起始纳米 1500；起始三卡 ww1_mauser/ww1_arty_m81/ww1_arm_ft17
  data/unified_card_table.gd    玩家卡 117（era0-4 = 23/23/24/24/23）；131 = 117 + 14 势力卡（default_cards.gd:182）
"""
import json
import os
import re
import sys
from collections import defaultdict

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT_DOC = os.path.join(ROOT, "docs", "P2-9经济模拟_p29_economy_sim.md")

SEED = 20260922
N_RUNS = 2000          # 蒙特卡洛场次：2000 条完整 60 关推图线（=120k 场战斗，满足 N≥1000）
LEVEL_MAX = 60         # L1→L60（era0-2：一战/二战/冷战）
STAR3_PROB = 0.5       # 假设：胜利局中 3 星概率 0.5（三星=+1 张时代随机真卡）

rng = np.random.default_rng(SEED)          # 公共流：出怪/纳米/材料/战后滚卡（口径不变量，各场景逐位同）
rng_card = np.random.default_rng(SEED + 1) # 卡通道流：击杀掉真卡发放（各场景独立，互不污染材料曲线）

# ════════════════════════ 1) 解析数据真身 ════════════════════════

def read(p):
    with open(os.path.join(ROOT, p), encoding="utf-8") as f:
        return f.read()

def strip_comments(s):
    return re.sub(r"#.*", "", s)

# --- unified_card_table.gd：玩家卡池（图鉴分母） ---
uct = strip_comments(read("data/unified_card_table.gd"))
player_cards_by_era = defaultdict(list)
for m in re.finditer(r"\{([^{}]*)\}", uct):
    body = m.group(1)
    cid = re.search(r'"card_id"\s*:\s*"([^"]+)"', body)
    if not cid:
        continue
    if re.search(r'"enemy_only"\s*:\s*true', body):
        continue
    era = re.search(r'"era"\s*:\s*(\d)', body)
    if era is None:
        continue
    player_cards_by_era[int(era.group(1))].append(cid.group(1))
N_PLAYER_UCT = sum(len(v) for v in player_cards_by_era.values())   # 117
N_FACTION_CARDS = 14                                               # default_cards.gd:182（fe_* 势力专属）
N_COLLECTION_TOTAL = N_PLAYER_UCT + N_FACTION_CARDS                # 131

# --- drop_tables.gd：ERA_BLUEPRINT_IDS（击杀缴获/随机滚卡真池）+ 时代随机掉落池 ---
dt = strip_comments(read("resources/drop_tables.gd"))
era_pool_ids = {}
blk = re.search(r"const ERA_BLUEPRINT_IDS:.*?(?=\n\tvar |\nfunc )", dt, re.S).group(0)
for m in re.finditer(r"(\d):\s*\[([^\]]*)\]", blk):
    era_pool_ids[int(m.group(1))] = re.findall(r'"([a-z0-9_]+)"', m.group(2))

DROP_TYPE_OF = {"BLUEPRINT_FRAGMENT": "card", "CARD_DATA": "card", "MATERIAL": "material"}
era_random_pools = {}
for fn, var in [("ww1_common_drops", 0), ("ww2_common_drops", 1), ("cold_war_common_drops", 2)]:
    seg = re.search(r"%s\s*=\s*\[(.*?)\n\t\]" % fn, dt, re.S).group(1)
    entries = []
    for em in re.finditer(
            r'DropEntry\.new\("([a-z0-9_]+)",\s*DropType\.(\w+),\s*([\d.]+),\s*(\d+),\s*(\d+)\)', seg):
        entries.append({"id": em.group(1), "kind": DROP_TYPE_OF.get(em.group(2), "other"),
                        "w": float(em.group(3)), "lo": int(em.group(4)), "hi": int(em.group(5))})
    era_random_pools[var] = entries

# --- 敌方原型显式掉落占比（按时代；来源 enemy_archetypes_ww/_cold_modern/_future 2026-09-22 解析）：
#   era0 elite 2 种(1 显式 saint@0.2) boss 显式 a7v@1.0；era1 elite 2(1: panther@0.25) boss kingtiger@1.0；
#   era2 elite 2(1: t72@0.3) boss 无表；era3 elite 3(1: abrams@0.4) boss 无表；era4 elite 2(0 显式)。
ELITE_EXPLICIT_SHARE = {0: 1 / 2, 1: 1 / 2, 2: 1 / 2, 3: 1 / 3, 4: 0.0}
ELITE_FLAGSHIP = {0: ("ww1_saint", 0.20), 1: ("ww2_panther", 0.25),
                  2: ("cold_t72", 0.30)}                          # (旗舰卡 id, chance)，×drop_mult
BOSS_FLAGSHIP = {0: ("ww1_a7v", 1.0), 1: ("ww2_kingtiger", 1.0)}  # 其余时代 boss 无显式表
# boss 唯一性：同名 boss 战场上只能存在 1 个（battle_spawn_system v8.x 限制，
# 每时代恰 1 种 boss）→ 每场 boss 击杀钳 1（末波倾向才是唯一 boss 来源）。

# --- level_eras.gd 常量（照抄真身；L1-60 只用前三时代） ---
ERA_WAVES = {0: (3, 5), 1: (4, 7), 2: (5, 8)}
ERA_SPAWN = {0: (1, 2), 1: (2, 3), 2: (2, 3)}
ERA_DROP_MULT = {0: 0.70, 1: 1.0, 2: 1.15}              # v37：WW1 0.85→0.70
REFINED_ALLOY_BASE = {0: 8, 1: 12, 2: 16}               # drop_tables._REFINED_ALLOY_BASE
TIER_PCT = {1: 0.30, 2: 0.46, 3: 0.66}                  # enemy_loadout_tiers atk_pct（老兵/精英/传奇）

# ════════════════════════ 2) 场景定义 ════════════════════════
# A  = 任务口径基线：无任何击杀掉真卡（显式先例表也关）
# B1 = 现行线上档（v27.18 已上线）：显式 + 通用缴获 normal 2% / elite 15% / 每场上限 2
# B2 = 中档：显式 + 通用 5% / 25% / 上限 3
# B3 = 高档：显式 + 通用 10% / 40% / 上限 4
SCENARIOS = {
    "A_基线(无击杀掉卡)":       {"explicit": False, "p_norm": 0.00, "p_elite": 0.00, "cap": 0},
    "B1_现行档(2%/15%,场限2)": {"explicit": True,  "p_norm": 0.02, "p_elite": 0.15, "cap": 2},
    "B2_中档(5%/25%,场限3)":   {"explicit": True,  "p_norm": 0.05, "p_elite": 0.25, "cap": 3},
    "B3_高档(10%/40%,场限4)":  {"explicit": True,  "p_norm": 0.10, "p_elite": 0.40, "cap": 4},
}

# ════════════════════════ 3) 模拟 ════════════════════════

def wave_total(level):
    era = min((level - 1) // 20, 4)
    in_era = (level - 1) % 20 + 1
    lo, hi = ERA_WAVES[era]
    return int(lo + (hi - lo) * ((in_era - 1) / 19.0))

def spawn_range(level):
    era = min((level - 1) // 20, 4)
    lo, hi = ERA_SPAWN[era]
    return max(2, lo), min(9, max(lo + 1, hi + 1))   # get_spawn_count_for_wave_card_grid 口径

def binom(n, p, gen=None):
    gen = gen if gen is not None else rng
    n = np.asarray(n, dtype=np.int64)
    if n.size == 0 or np.all(n == 0) or p <= 0:
        return np.zeros(n.shape, dtype=np.int64)
    return gen.binomial(n, min(max(p, 0.0), 1.0))

def run_scenario(cfg):
    global rng, rng_card
    # 每场景重置公共流：出怪/材料各场景逐位重放 → 表 2 的 Δ(B3−A) 恒等于 0（模型必然），
    # 档位差异全部落在卡通道（rng_card），不污染材料曲线。
    rng = np.random.default_rng(SEED)
    rng_card = np.random.default_rng(SEED + 1)
    acc = {k: np.zeros(N_RUNS) for k in ("nano", "alloy", "crystal", "energy", "cards")}
    distinct = [set() for _ in range(N_RUNS)]        # 每条线获得过的卡 id（图鉴口径）
    snap = {}                                        # 快照：L20/L40/L60
    battle_generic = []                              # 每场通用缴获张数（诊断）

    for level in range(1, LEVEL_MAX + 1):
        era = min((level - 1) // 20, 4)
        in_era = (level - 1) % 20 + 1
        progress = (in_era - 1) / 19.0
        lvl_mult = 1.0 + progress * 0.5
        drop_mult = ERA_DROP_MULT[era]
        is_pm = (level % 20 == 0)                    # 相位师驻守关
        pool = era_pool_ids[era]
        rp = era_random_pools[era]
        cum = np.cumsum([e["w"] for e in rp]) / sum(e["w"] for e in rp)

        waves = wave_total(level)
        sp_lo, sp_hi = spawn_range(level)

        # ── 出怪与击杀（胜利=全歼，假设见报告） ──
        basic_k = np.zeros(N_RUNS)
        elite_k = np.zeros(N_RUNS)                   # 精英击杀（显式/通用份额在发放时按概率合并）
        boss_k = np.zeros(N_RUNS)
        for w in range(1, waves + 1):
            base = rng.integers(sp_lo, sp_hi + 1, size=N_RUNS)
            cnt = np.clip(base + min((w - 1) // 2, 2), 2, 9)
            elite_p = min(0.15 + 0.25 * progress, 0.70)
            if w > 1 and w % 3 == 0:
                elite_p = min(elite_p + 0.30, 0.70)
            boss_p = 0.0
            if w == waves and waves > 3 and not is_pm:
                boss_p = 0.40 + 0.30 * progress
                elite_p = min(elite_p * 0.5, 0.30)
            maxc = int(cnt.max())
            active = np.repeat(cnt.reshape(-1, 1), maxc, 1) > np.arange(maxc).reshape(1, -1)
            ub = rng.random((N_RUNS, maxc))
            is_b = (ub < boss_p) & active
            ue = rng.random((N_RUNS, maxc))
            is_e = (ue < elite_p) & active & ~is_b
            boss_k += np.minimum(is_b.sum(1), 1)   # boss 唯一性钳 1（见头注）
            elite_k += is_e.sum(1)
            basic_k += (cnt - is_b.sum(1) - is_e.sum(1))

        # ── 击杀纳米（两口径一致——材料流不受卡通道影响） ──
        nano = np.zeros(N_RUNS)
        nano += binom(boss_k, min(1.0, 1.0 * drop_mult)) * rng.integers(18, 39, size=N_RUNS)
        nano += binom(elite_k, min(1.0, 0.88 * drop_mult)) * rng.integers(5, 13, size=N_RUNS)
        nano += binom(basic_k, min(1.0, 0.42 * drop_mult)) * rng.integers(2, 8, size=N_RUNS)
        acc["nano"] += nano

        # ── 击杀掉真卡（P2-9 变量通道） ──
        new_cards_by_run = defaultdict(int)          # run -> 本关卡牌入账（副本数）

        def grant(counts_arr, fixed_id=None):
            tot = int(counts_arr.sum())
            if tot == 0:
                return
            idx = None if fixed_id is not None else rng_card.integers(0, len(pool), size=tot)
            pos = np.repeat(np.arange(N_RUNS), counts_arr.astype(np.int64))
            for k, p in enumerate(pos):
                cid = fixed_id if fixed_id is not None else pool[int(idx[k])]
                new_cards_by_run[int(p)] += 1
                distinct[int(p)].add(cid)

        if cfg["explicit"]:
            if era in ELITE_FLAGSHIP:
                fid, ch = ELITE_FLAGSHIP[era]
                # 显式精英击杀 ×(种类占比×chance×drop_mult)——占比与掉率的合并概率精确等价
                p_eff = min(1.0, ELITE_EXPLICIT_SHARE[era] * ch * drop_mult)
                grant(binom(elite_k, p_eff, rng_card), fid)
            if era in BOSS_FLAGSHIP:
                fid, ch = BOSS_FLAGSHIP[era]
                grant(binom(boss_k, min(1.0, ch * drop_mult), rng_card), fid)
        if cfg["cap"] > 0:
            share_e = ELITE_EXPLICIT_SHARE[era]
            raw = (binom(basic_k, min(1.0, cfg["p_norm"] * drop_mult), rng_card)
                   + binom(elite_k, min(1.0, (1 - share_e) * cfg["p_elite"] * drop_mult), rng_card))
            got = np.minimum(raw, cfg["cap"])
            battle_generic.extend(int(x) for x in got)
            grant(got)

        # ── 战后掉落表（两口径一致） ──
        guar_lo, guar_hi = {0: (30, 50), 1: (50, 80), 2: (70, 100)}[era]
        acc["nano"] += rng.integers(guar_lo, guar_hi + 1, size=N_RUNS) * lvl_mult
        if era == 2:
            acc["alloy"] += rng.integers(15, 21, size=N_RUNS) * lvl_mult
        tier = 1 if progress < 0.55 else (2 if progress < 0.87 else 3)   # 老兵/精英/传奇
        acc["alloy"] += np.maximum(
            1, np.round(REFINED_ALLOY_BASE[era] * lvl_mult * TIER_PCT[tier]))
        n_draws = rng.integers(1, (4 if progress < 0.5 else 5), size=N_RUNS)
        for d in range(int(n_draws.max())):
            active = n_draws > d
            u = rng.random(N_RUNS)
            ei = np.clip(np.searchsorted(cum, u, side="right"), 0, len(rp) - 1)
            for run in np.nonzero(active)[0]:
                e = rp[int(ei[run])]
                amt = int(rng.integers(e["lo"], e["hi"] + 1))
                if e["kind"] == "material":
                    acc["alloy" if e["id"] == "alloy" else
                        ("crystal" if e["id"] == "crystal" else "nano")][run] += amt
                elif e["kind"] == "card":
                    new_cards_by_run[int(run)] += amt
                    distinct[int(run)].add(e["id"])
        s3 = rng.random(N_RUNS) < STAR3_PROB          # 三星奖励：+1 时代随机真卡
        for run in np.nonzero(s3)[0]:
            cid = pool[int(rng.integers(0, len(pool)))]
            new_cards_by_run[int(run)] += 1
            distinct[int(run)].add(cid)
        # 基础资源路径 get_drops_for_level（蓝图侧纳米另账不计，见假设 e）
        acc["nano"] += (50 + 10 * level) * drop_mult
        acc["alloy"] += (15 + 3 * level) * drop_mult
        acc["crystal"] += (5 + 2 * level) * drop_mult
        acc["energy"] += (20 + 5 * level) * drop_mult
        # 首通奖励（推图每关必发一次）
        acc["crystal"] += (20 + 2 * level) * (2.5 if is_pm else 1.0)
        acc["nano"] += 200 + 30 * level
        acc["alloy"] += 15 + 2 * level
        acc["energy"] += 5 + level // 2
        # 相位师关：boss 掉落表（纳米 300 固定 + random_boss 卡 + 精材料 60×0.66 + 2-4 抽 boss_drops）
        if is_pm:
            acc["nano"] += 300
            acc["alloy"] += 60 * 0.66
            cid = pool[int(rng.integers(0, len(pool)))]
            for run in range(N_RUNS):
                new_cards_by_run[run] += 1
                distinct[run].add(cid)
            rolls = rng.integers(2, 5, size=N_RUNS)
            for run in range(N_RUNS):
                for _ in range(int(rolls[run])):
                    u = rng.random()
                    if u < 3 / 7.3:
                        acc["alloy"][run] += int(rng.integers(40, 81))
                    elif u < 5 / 7.3:
                        acc["crystal"][run] += int(rng.integers(15, 36))
                    else:
                        acc["energy"][run] += int(rng.integers(8, 16))

        for run, n in new_cards_by_run.items():
            acc["cards"][run] += n

        if level in (20, 40, 60):
            snap[level] = {
                "nano": acc["nano"].copy(), "alloy": acc["alloy"].copy(),
                "crystal": acc["crystal"].copy(), "energy": acc["energy"].copy(),
                "cards": acc["cards"].copy(),
                "distinct": np.array([len(s) for s in distinct]),
            }
    return {"snap": snap, "acc": acc,
            "battle_generic": battle_generic}

# ════════════════════════ 4) 汇总与报告 ════════════════════════

def ms(arr):
    return float(np.mean(arr))

results = {}
for name, cfg in SCENARIOS.items():
    print(f"[sim] running {name} ...", file=sys.stderr)
    results[name] = run_scenario(cfg)

era_union = set().union(*[set(era_pool_ids[e]) for e in (0, 1, 2)])
reachable = len(era_union)          # L1-60 战斗可触达卡种（era0-2 掉落池并集）

KA = "A_基线(无击杀掉卡)"
KB1 = "B1_现行档(2%/15%,场限2)"
KB2 = "B2_中档(5%/25%,场限3)"
KB3 = "B3_高档(10%/40%,场限4)"

a_tot = ms(results[KA]["snap"][60]["cards"])
b1_tot = ms(results[KB1]["snap"][60]["cards"])
b2_tot = ms(results[KB2]["snap"][60]["cards"])
b3_tot = ms(results[KB3]["snap"][60]["cards"])
a_d60 = ms(results[KA]["snap"][60]["distinct"])
b1_d60 = ms(results[KB1]["snap"][60]["distinct"])
b2_d60 = ms(results[KB2]["snap"][60]["distinct"])
b3_d60 = ms(results[KB3]["snap"][60]["distinct"])
bg1 = float(np.mean(results[KB1]["battle_generic"]))
bg2 = float(np.mean(results[KB2]["battle_generic"]))
bg3 = float(np.mean(results[KB3]["battle_generic"]))

def fmt(x):
    return f"{x:,.0f}"

L = []
L.append("# P2-9 经济面离线模拟：击杀掉真卡通道（hermes Task 2.1）")
L.append("")
L.append("> 生成：`python tools/_archived/_tmp_p29_economy_sim.py`（种子 %d，N=%d 条完整 L1-60 推图线 = %s 场战斗，每关 1 次胜利）。"
         % (SEED, N_RUNS, fmt(N_RUNS * LEVEL_MAX)))
L.append("> 数据一律读 res:// 真身（ERA_DROP_MULTIPLIER WW1=0.70 v37 口径、v27.18 现行通用缴获常量等），零游戏代码改动。模型假设见文末。")
L.append("")
L.append("**口径说明**：A=任务口径基线（无任何击杀掉真卡，显式先例表也关闭）；B1=现行线上档"
         "（v27.18 已上线：显式先例表 + 通用缴获 2%/15%/场限 2）；B2/B3=扫描档。"
         "先例卡 = ww1_saint / ww2_panther / ww2_kingtiger（显式 drops 表）。")
L.append("")

# ── 表 1 ──
L.append("## 表 1：真卡获取量对比（张数 = 含重复的卡牌副本数）")
L.append("")
L.append("| 口径 | L1-20 累计 | L21-40 累计 | L41-60 累计 | L60 总计 | 场均缴获(通用通道) | 通用通道占总卡 |")
L.append("|---|---|---|---|---|---|---|")
for name in SCENARIOS:
    s = results[name]["snap"]
    c20 = ms(s[20]["cards"])
    c40 = ms(s[40]["cards"]) - c20
    c60 = ms(s[60]["cards"]) - ms(s[40]["cards"])
    tot = ms(s[60]["cards"])
    bg = float(np.mean(results[name]["battle_generic"])) if results[name]["battle_generic"] else 0.0
    share = (bg * LEVEL_MAX) / tot * 100 if tot else 0.0
    L.append("| %s | %s | %s | %s | **%s** | %.2f | %.1f%% |"
             % (name, fmt(c20), fmt(c40), fmt(c60), fmt(tot), bg, share))
L.append("")
L.append("(「场均缴获」只统计通用缴获通道张数；显式旗舰卡与战后随机滚卡不计入该列。)")
L.append("")

# ── 表 2 ──
L.append("## 表 2：资源累计曲线（A vs B3；B1/B2 与 B3 材料流逐位相同，略）")
L.append("")
L.append("| 资源（含起始纳米 1500） | 关卡 | A 基线 | B3 高档 | Δ(B3−A) |")
L.append("|---|---|---|---|---|")
for res_key, label in [("nano", "纳米材料"), ("energy", "能量块"), ("alloy", "合金"), ("crystal", "晶体")]:
    for lv in (20, 40, 60):
        va = ms(results[KA]["snap"][lv][res_key]) + (1500 if res_key == "nano" else 0)
        vb = ms(results[KB3]["snap"][lv][res_key]) + (1500 if res_key == "nano" else 0)
        L.append("| %s | L%d | %s | %s | %+.0f |" % (label, lv, fmt(va), fmt(vb), vb - va))
L.append("")
L.append("要点：**通用缴获通道是纯增量（additive）**——它只发卡、不动任何材料掉落，四档位材料曲线逐位相同"
         "（Δ 恒 0 是模型必然，也是设计事实：`_roll_generic_capture` 与纳米/材料掉落互不触碰）。"
         "经济风险不在货币通胀，而在卡牌图鉴与养成入口的注水速度（表 1/表 3）。")
L.append("")

# ── 表 3 ──
L.append("## 表 3：卡牌收集进度（战斗掉落口径）")
L.append("")
L.append("| 口径 | L20 新卡种 | L40 新卡种 | L60 新卡种 | L60 完成度 / 战斗可触达 %d 种 | L60 / 全图鉴 %d 种 | 副本:新卡比 |"
         % (reachable, N_COLLECTION_TOTAL))
L.append("|---|---|---|---|---|---|---|")
for name in SCENARIOS:
    s = results[name]["snap"]
    d20, d40, d60 = ms(s[20]["distinct"]), ms(s[40]["distinct"]), ms(s[60]["distinct"])
    ratio = ms(s[60]["cards"]) / d60 if d60 else 0.0
    L.append("| %s | %.1f | %.1f | %.1f | %.1f%% | %.1f%% | %.2f |"
             % (name, d20, d40, d60, d60 / reachable * 100, d60 / N_COLLECTION_TOTAL * 100, ratio))
L.append("")
L.append("- 战斗可触达池 %d 种 = era0/1/2 掉落池并集（%d / %d / %d 种，`drop_tables.ERA_BLUEPRINT_IDS`）。时代 3/4 卡与 14 张势力卡（fe_*）在本模拟区间（L1-60）外。"
         % (reachable, len(era_pool_ids[0]), len(era_pool_ids[1]), len(era_pool_ids[2])))
L.append("- 全图鉴 %d = UCT 玩家卡 %d + 势力专属 %d（`data/default_cards.gd:182` 注：131 = 117 + 14）。制造/势力商店/进化路径获取不在本模拟范围，两口径同受影响。"
         % (N_COLLECTION_TOTAL, N_PLAYER_UCT, N_FACTION_CARDS))
L.append("- 起始三卡（ww1_mauser / ww1_arty_m81 / ww1_arm_ft17）均在 era0 池内。")
L.append("")

# ── 假设清单 ──
L.append("## 模拟假设清单（按\"代码真身照抄 → 简化近似\"排列）")
L.append("")
L.append("**直接照抄代码（无近似）**：")
L.append("1. 波次数 `LevelEras.get_wave_total_for_level`（时代内线性：WW1 3-5 / WW2 4-7 / 冷战 5-8）。")
L.append("2. 波次出怪 `get_spawn_count_for_wave_card_grid`（base∈[max(2,r0), min(9,max(r0+1,r1+1))] + 每 2 波 +1 上限 +2，钳 2-9）。")
L.append("3. 波次构成 `LevelSpawnSequences._make_wave_spec`（elite=0.15+0.25×进度，精英波(w%3==0) +0.30，末波 boss=0.40+0.30×进度且 elite 减半；相位师关无末波 boss 倾向）。")
L.append("4. 掉率乘区 `ERA_DROP_MULTIPLIER`：era0=0.70（v37 收口）/ era1=1.0 / era2=1.15；所有击杀掉率 chance×mult 后钳 ≤1（`roll_blueprint_drops` 同款）。")
L.append("5. 通用缴获现行档 = `battle_damage_system.gd` v27.18 常量（normal 2% / elite 15% / 每场上限 2，boss 不参与，显式表非空的原型跳过）。")
L.append("6. 显式 drops 表 6 条先例（saint 0.2 / panther 0.25 / t72 0.3 / abrams 0.4 / a7v 1.0 / kingtiger 1.0），按\"显式精英种类占比\"摊入精英击杀。")
L.append("7. 击杀纳米 `roll_nano_materials_on_kill` 默认档（boss 18-38@1.0 / elite 5-12@0.88 / basic 2-7@0.42）。")
L.append("8. 战后掉落表 `drop_tables.generate_drops`（保底纳米×lvl_mult、随机 1-3/1-4 抽、精材料=tier atk_pct、三星 era_N 卡、era2 保底合金）。")
L.append("9. 首通公式 `first_clear_rewards.get_first_clear_reward`（L%20==0 晶体 ×2.5）+ `get_drops_for_level` 基础资源路径 + 起始纳米 1500（save_manager.gd:947）。")
L.append("10. 相位师关（L20/40/60）追加 boss 表：纳米 300 固定 + 1 张 random_boss（近似=时代池均匀）+ 60×0.66 精材料 + 2-4 抽 boss_drops（合金/晶体/能量块权重 3:2:1.8）。")
L.append("")
L.append("**简化近似（偏差已评估为次要，且两口径同受影响、档位间差值形状不变）**：")
L.append("a. **胜利=全歼**：击杀数=全部出怪数。实战漏怪会等比压低所有击杀通道（含纳米）。")
L.append("b. **缴获卡=时代池均匀**：真身按 combat_kind 过滤时代池（`get_random_card_for_era_kind`，空命中回退全池）——近似影响\"图鉴偏科\"分布，不影响总量。")
L.append("c. **精英类型均匀混编**：显式表精英按种类占比摊入精英击杀；实际按波次 bias_tags 抽取。")
L.append("d. **三星概率 0.5**；swarm 单位纳米档（1-2@0.24）、侦察碎片加成（×1.0-1.3）、挂机/黑门/势力/制造收入全部不计。")
L.append("e. 蓝图侧纳米（`_grant_basic_resources_for_current_level` 的 `add_nano_materials` 分支，独立钱包）不计入表 2。")
L.append("")

# ── M4 拍板选项 ──
L.append("## 给 M4 的拍板选项")
L.append("")
L.append("| 选项 | 内容 | 数据支撑（L60） |")
L.append("|---|---|---|")
L.append("| ① 维持现行 | 通道已上线（v27.18 保守档），不再调参 | 通用通道场均 %.2f 张；L60 总卡 %s（比基线 +%.0f%%）；图鉴新卡 +%.1f 种 |"
         % (bg1, fmt(b1_tot), (b1_tot / a_tot - 1) * 100, b1_d60 - a_d60))
L.append("| ② 收口 | 关闭通用缴获，只留显式先例表（≈A 口径） | 总卡回落 %s（现行 −%.0f%%）；图鉴新卡 −%.1f 种 |"
         % (fmt(a_tot), (1 - a_tot / b1_tot) * 100, b1_d60 - a_d60))
L.append("| ③ 升中档 | 5%%/25%%/场限 3 | 总卡 %s（比现行 +%.0f%%）；图鉴 L60 +%.1f 种；场均缴获 %.2f |"
         % (fmt(b2_tot), (b2_tot / b1_tot - 1) * 100, b2_d60 - b1_d60, bg2))
L.append("| ④ 升高档 | 10%%/40%%/场限 4 | 总卡 %s（比现行 +%.0f%%）；图鉴 L60 +%.1f 种；副本:新卡比 %.2f（重复感显著） |"
         % (fmt(b3_tot), (b3_tot / b1_tot - 1) * 100, b3_d60 - b1_d60,
            b3_tot / b3_d60 if b3_d60 else 0))
L.append("")

# ── 结论建议 ──
L.append("## 结论建议（由模拟数据生成，供 M4 参考；审美/节奏裁决归用户）")
L.append("")
L.append("""1. **通道本身值得保留（建议不开倒车）**：B1（现行档）相对 A 基线，L60 总卡 {b1} vs {a}（+{d} 张 / +{b1p:.0f}%）、
   图鉴新卡 +{b1d:.1f} 种，场均缴获仅 {bg:.2f} 张——v27.18 保守档的"低频惊喜"定位在数据上成立，
   材料流水零变化（表 2），没有货币通胀副作用。""".format(
    b1=fmt(b1_tot), a=fmt(a_tot), d=fmt(b1_tot - a_tot), b1p=(b1_tot / a_tot - 1) * 100,
    b1d=b1_d60 - a_d60, bg=bg1))
L.append("")
L.append("""2. **不建议直升高档（B3）**：通用通道占比升到 {b3sh:.0f}%，副本:新卡比 {dup:.2f}（现行 {dup1:.2f}）——击杀掉卡的主体验会从
   "图鉴发现"退化为"重复卡洪水"，与 v37"首关掉卡偏多"收口方向相逆。""".format(
    b3sh=(bg3 * LEVEL_MAX) / b3_tot * 100,
    dup=b3_tot / b3_d60 if b3_d60 else 0,
    dup1=b1_tot / b1_d60 if b1_d60 else 0))
L.append("")
L.append("""3. **若 M4 要强化"击杀出真卡"感知**：优先升 B2（中档 5%/25%/场限 3）而非 B3——总卡 +{b2p:.0f}%、
   图鉴 +{b2d:.1f} 种，量级仍温和；同时考虑把 era0 的 drop_mult=0.70 与通用档解绑（0.70 同时压先例卡与纳米，
   若要保前期惊喜可单抬通用缴获不受 drop_mult 乘）。""".format(
    b2p=(b2_tot / b1_tot - 1) * 100, b2d=b2_d60 - b1_d60))
L.append("")
L.append("""4. **图鉴瓶颈不在掉率**：L60 战斗口径完成度天花板 = {reach}/{total}（{rp:.0f}%）——时代 3/4 卡与势力卡
   本区间不可达；就算 B3 也只到 {b3r:.0f}%。真卡通道的边际收益在图鉴维度很小，拍板权重应放在"击杀反馈手感"
   而非"收集推进"。""".format(reach=reachable, total=N_COLLECTION_TOTAL,
                            rp=reachable / N_COLLECTION_TOTAL * 100,
                            b3r=b3_d60 / N_COLLECTION_TOTAL * 100))

with open(OUT_DOC, "w", encoding="utf-8") as f:
    f.write("\n".join(L) + "\n")
print("WROTE", OUT_DOC)
print("KEY:", json.dumps({
    "A_total_L60": round(a_tot), "B1_total_L60": round(b1_tot),
    "B2_total_L60": round(b2_tot), "B3_total_L60": round(b3_tot),
    "A_distinct_L60": round(a_d60), "B1_distinct_L60": round(b1_d60),
    "B2_distinct_L60": round(b2_d60), "B3_distinct_L60": round(b3_d60),
    "reachable_pool": reachable, "generic_per_battle": [round(bg1, 3), round(bg2, 3), round(bg3, 3)],
    "collection_total": N_COLLECTION_TOTAL, "uct_players": N_PLAYER_UCT,
}, ensure_ascii=False))
