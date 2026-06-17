# 战斗攻防属性系统 — 统一基础属性表设计（v6.3）

## 概述

v6.3 重构建立了**统一基础属性表**（L0），让玩家卡和敌人卡共享同一份基础数据，各自叠加加成层。平衡时分两步：先调 L0 基础定位，再调各加成层。

## 5 层加成模型

```
L0 基础数据表（共享，确定的数值）—— data/base_unit_stats.gd
  ├─ 玩家卡 = L0 + L1(era) + L2(强化/继承/军衔/词条/MOD/势力) + L3(-) + L4(相位仪/光环/律法)
  └─ 敌人卡 = L0 + L1(level) + L2(master) + L3(wave/pressure) + L4(律法减益)
```

| 层 | 名称 | 玩家侧来源 | 敌人侧来源 | 运算 | 环节 |
|----|------|-----------|-----------|------|------|
| **L0** | 基础属性表 | `BaseUnitStats.BASE_ENTRIES`（共享） | `BaseUnitStats.BASE_ENTRIES`（共享） | 直接取值 | 构建 |
| **L1** | 全局缩放 | `BattleCardV3.era_hp/damage/range_multiplier` | `EnemyStatResolver.level_stat_multiplier`（当前1.0） | 乘算 | 构建 |
| **L2** | 个体养成 | 强化+继承+军衔+词条+MOD+势力（8子系统） | 相位师 master 加成 | 乘算为主 | 构建 |
| **L3** | 对位动态 | （无） | `wave_hp/dmg_mul` + `player_pressure` | 乘算 | 构建 |
| **L4** | 运行期 | 相位仪+光环+律法(buff) | 律法(debuff) | 乘算/加算 | 运行 |

## L0 基础属性表使用

### 文件
`data/base_unit_stats.gd`（class_name BaseUnitStats）

### 当前原型（20个，按 combat_kind 分组）
- **轻装（LIGHT=0）**：ww1/ww2/cold/modern/future_infantry（5个时代）
- **装甲（ARMOR=1）**：ww1_light_tank / ww2_medium_tank / ww2_heavy_tank / cold_mbt / modern_mbt / future_heavy_mech（6个）
- **空中（AIR=3）**：cold_fighter / modern_attack_helo / future_fighter（3个）
- **火炮/支援（SUPPORT=2）**：ww1_mortar / modern_mrl（2个）
- **防空特化（SUPPORT=2）**：ww1_aa_gun / modern_aa（2个）
- **堡垒（FORT=4）**：ww1_bunker / modern_citadel / future_ion_fort（3个）

### 查询接口
```gdscript
# 获取原型（深拷贝）
BaseUnitStats.get_entry("ww2_heavy_tank")

# 合并原型 + 覆盖字段（个体差异）
BaseUnitStats.resolve("ww2_heavy_tank", {"display_name": "虎式坦克", "hp": 480})

# 按 combat_kind 列出原型（平衡审查用）
BaseUnitStats.get_refs_by_combat_kind(GC.CombatKind.ARMOR)
```

## 平衡工作流（推荐顺序）

### 第1步：L0 基础定位
在 `base_unit_stats.gd` 调整原型数值。确保同星级的单位相对强弱合理：
- 坦克 vs 步兵：坦克应该赢（装甲防轻装高）
- 防空 vs 空中：防空应该赢（对空攻击高 + 穿透MOD）
- 火炮 vs 步兵：火炮应该赢（曲射射程远）

### 第2步：L1 全局缩放
- 玩家：`battle_card_v3.gd` 的 era_hp/damage/range_multiplier（时代倍率）
- 敌人：`enemy_stat_resolver.gd` 的 level_stat_multiplier（当前恒1.0，待启用关卡曲线）

### 第3步：L2 个体养成
玩家侧8个子系统（按应用顺序）：
1. 强化词条 Module（`unit_stats_table.gd:apply_module_effects`）
2. 强化+稀有度（`evolution_helpers.gd:get_effective_power_multiplier`）
3. 进化继承（`evolution_helpers.gd` inherit_bonus）
4. 军衔（`rank_rules.gd` RANK_BONUS，1.00~1.07）
5. 成长倾斜（`unit_stats_table.gd:get_combat_kind_growth_bias`）
6. 进化HP下限
7. MOD改造穿甲（`unit_stats_table.gd:_apply_mod_stat_effects`）
8. 势力技能树（`battle_spawn_system.gd`）

敌人侧：相位师 master 加成（`enemy_stat_resolver.gd:apply_phase_master_to_unit_stats`）

### 第4步：L3 对位动态（敌人专属）
- 波次：`wave_hp_mul = 1 + 0.12*(wave-1)`，`wave_dmg_mul = 1 + 0.08*(wave-1)`
- 压力：`player_pressure`（当前未启用）

### 第5步：L4 运行期
- 玩家：相位仪/光环/律法（buff）
- 敌人：律法（debuff）

## 敌人三维化（v6.3 阶段1成果）

敌人现在走与玩家**同一套三维战斗逻辑**：
- 三维攻击（attack_light/armor/air）：`enemy_stat_resolver.gd:resolve_classic_enemy` 输出三维
- 三维防御（defense_light/armor/air）：`derive_defense_by_unit_type` 统一派生
- 三维武器槽位：`enemy_unit.gd:_build_enemy_unit_stats` 构建
- 条件穿甲：相克MOD按目标 combat_kind 激活（`get_effective_armor_penetration`）

### 敌人数据流
```
enemy_unit_manifest.gd（三维数据，不再坍缩）
  → EnemyArchetypes.get_config（三维 archetype_config）
  → EnemyStatResolver.resolve_classic_enemy（三维输出 + wave/level/master 缩放）
  → enemy_unit.gd:_build_enemy_unit_stats（构建 UnitStats + 武器槽位）
  → _do_attack（走 stats != null 三维路径，复用 AttackCalculator）
```

## 统一 power 计算（v6.3）

敌我双方现在用对齐的 power 公式（`enemy_unit.gd:154`）：
```
power = max_hp × 0.28 + best_dps × 2.2 + attack_range × 0.22
```
其中 `best_dps` 取三维攻击中DPS最高的维度。这与玩家的 `combat_power_from_unit_stats` 口径一致，可用于军衔判定和相对平衡比较。

## 关键文件清单

| 文件 | 角色 |
|---|---|
| `data/base_unit_stats.gd` | **L0 基础属性表**（共享数据层） |
| `resources/unit_stats_table.gd` | 玩家 L0→L2 派生（含 derive_defense_by_unit_type） |
| `data/enemy_stat_resolver.gd` | 敌人 L0→L3 解析（三维输出） |
| `data/enemy_unit_manifest.gd` | 敌人数据源（三维透传） |
| `scenes/units/enemy_unit.gd` | 敌人节点（构建UnitStats + 三维攻击） |
| `scripts/battle/attack_calculator.gd` | 统一三维伤害计算（敌我共用） |
| `resources/unit_stats.gd` | UnitStats 定义（三维字段 + 条件穿甲） |
| `data/battle_card_v3.gd` | 玩家 L1 时代缩放 |
| `managers/evolution/evolution_helpers.gd` | 玩家 L2 养成管线 |

## 后续工作（渐进式）

1. **逐步迁移**：现有112张玩家卡 + 109条敌人数据逐步改为引用 L0 表（`base_ref` + 覆盖字段）
2. **启用敌人 L1**：`level_stat_multiplier` 接入关卡曲线（当前恒1.0）
3. **统一加成管线**：抽象 `resolve_unit_stats(base, context)` 让敌我共用同一条乘算链
4. **清理死字段**：manifest 中被覆盖的旧三维数据、captured_unit_cards 的兼容路径
