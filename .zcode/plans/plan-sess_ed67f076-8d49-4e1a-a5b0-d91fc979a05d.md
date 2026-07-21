# 相位师战力公式重构：单分量「卡战力之和」

## 核心思路（已与用户确认全部决策点）

**新公式（敌我同口径）**：
```
相位师总战力 = Σ 每张装备卡经过完整加成链路后的实战力
```

- **删除** A 维（相位仪本体分）、H 维（符文分）—— 相位仪/符文的价值已经通过加成体现在卡战力里，再加独立分是重复计算。
- **玩家侧**：green 槽每张战斗卡 → 走完整 7 层战场加成链路（强化/改造/进化/军衔/词条/相位仪+相位场/符文之语）→ `combat_power_from_unit_stats` → 求和。
- **敌方侧**：`equipment.platforms` 每张平台卡 → `_build_stats_from_archetype` + 敌方固有加成链路（相位师属性/符文/相位仪/配档 tier，**不含战场波动项** wave/level/faction/elite-boss/词缀）→ `combat_power_from_unit_stats` → 求和。
- **敌方 tier**：UI/排行榜用 HIGH（满配），战斗时仍由 game_manager 注入真实派生 tier。

## 为什么这样设计（关键决策记录）

1. **只算卡战力之和**：用户明确要求，相位仪/符文贡献已在卡加成里体现，相位仪槽位多→装更多卡→战力高，星级差异自然体现。
2. **玩家 7 层全加成**：完全复用 `_build_stats_cached` 的战场真实链路，战力=真实战斗力精确反映。
3. **敌方 platforms 长度**：与玩家侧"装几张卡"口径完全对称。
4. **敌方不含波动项**：战力应该是"相位师固有威胁"，wave/level 是战场临时难度、elite/boss 是出兵序列标记，不属于相位师本身。保留这 4 项会让"同一相位师在不同关卡战力差好几倍"，违背"相位师战力"的语义。
5. **UI tier=HIGH**：UI 查看/排行榜反映"敌方满配威胁"，保守评估。

## 文件改动清单（8 处）

### 1. `scripts/master_power_evaluator.gd`（核心重写）

**evaluate() 改为单分量**：
```gdscript
static func evaluate(master: Dictionary) -> Dictionary:
    var scores: Dictionary = {}
    scores.equipment_slots = _eval_equipment_slots(master)  # 唯一维度：卡战力之和
    var total: float = scores.equipment_slots
    # ... star_info / details 同步简化
```

**`_eval_equipment_slots` 改造**：
- 玩家侧：读 `master._player_platform_powers`（已是加成后战力，由 assembler 注入）→ 求和
- 敌方侧：对 `equipment.platforms` 每个平台 id 调**新静态函数** `_compute_enemy_platform_power`（见改动 3）→ 求和
- 删除旧 `UCT.get_entry(id).power` 静态读取（那是裸值，不含加成）

**删除死代码**（约 440 行 → 约 250 行）：
- `_eval_instrument`（A 维）— 删
- `_eval_runes`（H 维）— 删
- `_eval_engravings` / `_eval_traits` / `_eval_active_spells` / `_eval_passive_spells` / `_eval_master_stats` / `_eval_runewords` — 删
- 常量块：`REF_*/SW_*`（A 维）、`TRAIT_EFFECT_WEIGHTS/TRAIT_COUNT_BONUS`（C 维）、`SPELL_*/SPELL_DAMAGE_FACTOR`（D 维）、`PASSIVE_*/HIGH_VALUE_PASSIVES`（E 维）、`PLATFORM/WEAPON/ENERGY_CARD_BONUS/INSTRUMENT_RARITY_SCORE`（F 旧维）、`MASTER_REF_*/MSW_*`（G 维）、`RUNE_RARITY_POWER/RUNEWORD_TIER_BASE/RUNE_STAT_WEIGHT/RUNEWORD_EFFECT_WEIGHT`（H/I 维）、`EnergyFieldEngravings/EnemyPhaseEquipment/RuneDefinitions/RunewordDefinitions/RunewordMatcher` preload — 全删
- `_build_details` 简化：只输出 `equipment_slots_score` + 保留 `master_name/faction/platform_count` 等基础展示字段（移除 instrument/hp/atk 等 A 维遗留字段或保留供 UI 兼容——见改动 6）
- 保留 `STAR_TIERS / _score_to_stars / get_stars / get_stars_display / evaluate_ranking` 工具函数

### 2. 新建 `scripts/master_platform_power.gd`（卡战力计算器，纯静态）

抽取两个核心静态函数，供 evaluator + UI 共用：

```gdscript
class_name MasterPlatformPower
extends RefCounted

## 玩家单卡战力（7 层加成，复用 _build_stats_cached 链路）
static func compute_player_card_power(card: CardResource, pm: Node, bpm: Node) -> float:
    # 1. effective_card 解析（实例卡直用，非实例卡查 CardEnhancementManager）
    # 2. stats = UnitStatsTable.build_stats_from_card(effective_card, era)
    # 3. BlueprintManager.apply_growth_to_stats（稀有度/强化/改造/进化HP下限/军衔）
    # 4. 势力技能 stat_bonus（若激活）
    # 5. AffixManager.apply_affixes_to_stats
    # 6. PhaseInstrumentManager.apply_phase_field_bonus_to_unit_stats（相位仪+相位场+星级系数）
    # 7. 符文之语加成（复用 _apply_rune_bonus_to_stats 逻辑）
    # return EvolutionHelpers.combat_power_from_unit_stats(stats)

## 敌方单平台卡战力（archetype + 固有加成，不含波动项）
static func compute_enemy_platform_power(platform_id: String, master: Dictionary, era: int, tier: String = "HIGH") -> float:
    # 1. 构造 CardResource from archetype（复用 enemy_phase_field_driver._build_stats_from_archetype 逻辑）
    # 2. EnemyStatResolver.apply_phase_master_to_unit_stats（相位师属性）
    # 3. 符文加成（master.equipment.runes，按 tier 限量，复用 _apply_master_rune_bonus 逻辑）
    # 4. 相位仪加成（master.equipment.phase_instrument，复用 _apply_enemy_phase_instrument_bonus 逻辑）
    # 5. 配档 tier bonus（atk_pct/hp_pct/def_pct，不含 wave/level）
    # return EvolutionHelpers.combat_power_from_unit_stats(stats)
```

**为什么不复用 `_build_stats_cached`**：它是 battle_spawn_system 的实例方法（依赖 `self._phase_instrument` / `self._stats_cache` / `self._get_autoload_node`），战力公式在非战斗场景（UI/排行榜）也要调用。抽取静态函数复用其逻辑链但解耦实例状态。

**为什么不全抽到 enemy_phase_field_driver**：它的加成函数都是实例方法（读 `self._master_stats` / `self._master_runes` / `self._pm_tier` / `self._equipment`），静态化会破坏产兵路径。在 `MasterPlatformPower` 里**复刻**这些加成的核心逻辑（百分比乘区，约 60 行），driver 保持不动（产兵路径不变）。

### 3. `scripts/master_player_assembler.gd`（改注入）

`build_player_master_dict`：
- 删除 `_player_inst_bonus_total`（A 维预算，已废）
- 改 `_player_platform_powers`：从 `plat.get_current_power()`（仅强化+改造）改为调 `MasterPlatformPower.compute_player_card_power(plat, pm, bpm)`（7 层全加成）
- 注入 `_player_card_breakdown`（每张卡 `[{name, power}]` 供 UI 显示卡战力分解）

### 4. `data/enemy_phase_masters.gd`（改 compute_display_level）

`compute_display_level(master)`：
- 区间校准：新公式量级变化（旧 3 分量含符文 5000-7000/个 + 仪器分 + 卡静态 power；新公式只有加成后卡战力，量级会显著下降）。
- 先用 `MasterPlatformPower.compute_enemy_platform_power` 对每个 platform 求和得到 `total`，再按新分布标定 `RAW_LO_FOR_LV` / `RAW_HI_FOR_LV`（在测试里跑 30 个 master 确定实际分布后填入，预估区间 500-5000）。

### 5. STAR_TIERS 阈值重标定（master_power_evaluator.gd）

旧阈值（基于旧 3 分量）：`0/800/1600/3200/6000/9500/20000`

新公式量级会变化（单张卡加成后战力约 200-5000，敌方装 2-4 张 = 500-15000；玩家满配 6 张 = 上不封顶）。**先在测试里跑真实分布**，再按分位数标定新阈值，确保：
- 一战相位师 ≈ 2-3★
- 近未来相位师 ≈ 4-5★  
- 玩家中配 ≈ 4★
- 玩家满配 ≈ 6-7★

### 6. UI 显示更新（3 文件）

**`scenes/ui/player_master_panel.gd`**：
- 删除 `DIM_ORDER/DIM_LABELS/DIM_WEIGHTS`（3 分量已废）
- 改为"卡战力分解"：`═══ 战斗卡战力 ═══` + 逐张 `  FT17 +5强化 → 战力 3200`（复用已有 `_append_platform_lines`，数据源改为 `master._player_card_breakdown`）
- 删除 `_append_instrument_lines` 的相位场行（相位仪/相位场加成已体现在卡战力里，保留相位仪名/星级基础信息）

**`scenes/ui/bottom_instrument_bar.gd`** `_append_player_master_tooltip_lines`：
- 删除 3 分量分解块（L1091-1103）
- 改为卡战力简表：`  总战力:12500 | FT17:3200 | T72:4800 | ...`（限制最多显示前 3-4 张 + 省略号）

**`scenes/ui/card_info_panel.gd`**（敌方相位师显示 3 处：L1358/L1461/L1705）：
- 总战力数字会自动变（evaluate() 内部改了）—— 无需改代码，自动跟随
- 可选：L1704 增加卡战力分解行（如果有 master.equipment.platforms 可展开）

### 7. `tests/master_power_smoke.gd`（测试更新）

- 删除引用 `RUNE_RARITY_POWER` 的断言（常量已删）
- 改为验证新单分量公式：
  - master_001 战力 > 0 且为 2-3 张 platform 加成之和的量级
  - master_030 战力 > master_001（近未来更强）
  - 玩家侧 6 张卡 > 2 张卡（装更多卡战力更高，验证"槽位数影响战力"）
  - 加成生效验证：同一张卡在 7 星相位仪下战力 > 在 1 星下（验证相位仪加成进入卡战力）

### 8. Godot --check-only 验证

最终 `--headless --check-only` 跑通确认无语法错误。

## 不动的部分（向后兼容）

- **敌方产兵路径**（enemy_phase_field_driver 的 7 层加成）—— 完全不动，战斗实际数值不受影响
- **战斗中的战力**（game_manager.gd 的 `_MPE.evaluate(...)` 星级映射 Tier）—— evaluate() 签名不变，自动跟随新公式
- **玩家侧 `_build_stats_cached`**（战场部署 stats）—— 不动，MasterPlatformPower 是独立静态函数
- **敌方 master JSON 数据**（platforms/spawn_sequence/runes）—— 不动
- **STAR_TIERS 接口、get_stars / get_stars_display** —— 接口保留，只改阈值

## 风险与缓解

1. **新公式量级未知** → 先在 smoke test 跑 30 个 master 真实分布，再标定 STAR_TIERS 和 compute_display_level 阈值。
2. **敌方单卡加成逻辑复刻可能与产兵路径漂移** → 加注释明确"与 enemy_phase_field_driver 保持同步"，在产兵路径加 `# NOTE: 改动需同步 MasterPlatformPower` 注释。
3. **UI 删除 DIM_ORDER 等可能影响其他引用** → grep 确认这些常量只在 player_master_panel 内部使用。
4. **master_power_smoke.gd 可能因 --script 模式 autoload 限制无法跑全链路** → 已有 `EnemyPhaseMasters.LEGACY_ENEMY_MASTERS` 静态 var 跨类初始化 bug 的先例，测试改为手动构造 master dict 验证公式逻辑。

## 验证策略

1. `godot --headless --check-only` 确认编译通过
2. `master_power_smoke.gd` 单独跑确认公式正确
3. Grep 静态核对：`_player_inst_bonus_total` / `RUNE_RARITY_POWER` / `_eval_instrument` / `_eval_runes` 删除后全项目无残留引用
4. 实机验证（用户侧）：进入战场看敌方相位师信息卡总战力、玩家相位师档案面板卡战力分解

## 改动顺序

1. 新建 `master_platform_power.gd`（卡战力计算器）
2. 重写 `master_power_evaluator.gd`（单分量 + 删死代码）
3. 改 `master_player_assembler.gd`（注入加成后卡战力）
4. 跑 smoke test 确定 30 master 真实分布 → 标定 `STAR_TIERS` + `compute_display_level`
5. 改 3 个 UI 文件（卡战力分解）
6. 改 smoke test
7. 最终 --check-only 验证