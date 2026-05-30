# 势力卡牌生成系统 — 详细实施计划

> 版本：v1.0
> 日期：2025-07-12
> 状态：计划中

---

## 一、目标概述

在现有固定列表（110+基础战斗卡）的基础上，构建**势力特色卡牌变体系统**：

- **7个势力** × **10级** = 70种变体加成规则
- 每张基础卡可生成势力变体：`钢壁·虎式坦克 III型`
- 变体拥有**独立卡名**和**数值加成**
- 与已有养成系统（强化Lv1-10、进化E1-E3+势力分支、改造MOD、词条AFFIX）**完全兼容**
- 不修改基础数据，运行时通过 `clone()` + 叠加计算生成变体

---

## 二、现有架构分析

### 2.1 已有系统清单

| 系统 | 文件 | 职责 | 与本系统的关系 |
|------|------|------|---------------|
| 基础卡牌列表 | `data/default_cards.gd` | 110+ 固定战斗卡 + 7 能量卡 | **数据源**：基础 CardResource |
| 势力定义 | `data/company_definitions.gd` | 7 势力 ID / 名称 / 描述 | **读取**：势力标识 |
| 势力声望 | `managers/faction/faction_reputation.gd` | 声望 0-10000 → 等级 1-10 | **读取**：当前势力等级 |
| 势力管理 | `managers/faction_system_manager.gd` | 声望/商店/相位仪操作 | **集成点** |
| 强化系统 | `managers/card_enhancement_manager.gd` | Lv1-10 强化，5%-60% 属性加成 | **下游**：叠加在势力变体之上 |
| 进化系统 | `managers/evolution/card_evolution_manager.gd` | E1/E2 进化，势力分支（已有空框架） | **下游**：势力分支进化 |
| 进化链配置 | `data/unit_lineage_config.gd` | 9条主线进化路线 | **扩展**：填充势力分支 |
| 改造系统 | `managers/evolution/mod_manager.gd` | 9个MOD槽位 | **下游**：叠加计算 |
| 改造效果表 | `data/mod_effects.gd` | 20种MOD效果定义 | **下游**：叠加计算 |
| 词条系统 | `managers/affix_manager.gd` | 随机词条 | **下游**：叠加计算 |
| 战场部署 | `managers/battle/battle_spawn_system.gd` | 从 CardResource 构建 UnitStats → 部署单位 | **集成点**：在此注入势力变体 |
| 数值表 | `resources/unit_stats_table.gd` | build_stats_from_card() | **集成点**：可能需扩展 |
| 战斗数值公式 | `data/battle_card_v3.gd` | 时代缩放、星级倍率等 | **兼容**：无需修改 |

### 2.2 战场部署数据流（当前）

```
CardResource（基础卡）
  → UnitStatsTable.build_stats_from_card()     ← 基础属性 + 时代缩放
  → BlueprintManager.apply_growth_to_stats()  ← 星级成长 + 进化继承 + 军衔加成
  → AffixManager.apply_affixes_to_stats()    ← 词条加成
  → PhaseInstrument.apply_phase_field_bonus() ← 相位仪加成
  → 最终 UnitStats → 战场部署
```

### 2.3 目标数据流（势力变体注入后）

```
CardResource（基础卡）
  → [新增] FactionCardGenerator.apply_faction_bonus()  ← 势力变体加成 ★
  → UnitStatsTable.build_stats_from_card()     ← 基础属性 + 时代缩放
  → BlueprintManager.apply_growth_to_stats()    ← 星级成长 + 进化继承 + 军衔加成
  → AffixManager.apply_affixes_to_stats()       ← 词条加成
  → PhaseInstrument.apply_phase_field_bonus()   ← 相位仪加成
  → 最终 UnitStats → 战场部署
```

### 2.4 势力现状

已有 7 个势力定义（`company_definitions.gd`）：

| 势力ID | 名称 | 定位（提议） | 关系网络 |
|--------|------|-------------|---------|
| `iron_wall_corp` | 钢壁防务公司 | 防御/堡垒 | rival: nova_arms; enemy: frontier_union |
| `nova_arms` | 新星兵工制造 | 攻击/火力 | rival: iron_wall_corp, aether_dynamics |
| `aether_dynamics` | 以太动力重工 | 机动/能量效率 | rival: nova_arms; allied: quantum_logistics |
| `quantum_logistics` | 量子后勤集团 | 资源/补给/续航 | allied: aether_dynamics |
| `helix_recon` | 螺旋侦察系统 | 侦察/闪避/精准 | rival: void_research; allied: frontier_union |
| `void_research` | 虚空相位研究所 | 法则/特殊效果 | rival: helix_recon |
| `frontier_union` | 边境联合公司 | 多面手/通用加成 | allied: helix_recon; enemy: iron_wall_corp |

### 2.5 进化链现状

已有 9 条主线进化路线（`unit_lineage_config.gd`），37 个节点：

- **轻装线**：普通步兵(5节) / 反坦克(4节) / 特种(4节)
- **装甲线**：主战坦克(5节) / 重型坦克(5节)
- **空中线**：战斗机(3节) / 攻击机(2节)
- **支援线**：火炮(5节) / 防空(4节)

**所有 faction_branches 字段目前均为空 `{}`**，等待本系统填充。

---

## 三、势力特色设计

### 3.1 七势力核心定位与加成方向

#### 🛡️ 钢壁防务公司 (iron_wall_corp)
- **核心定位**：钢铁防线，牺牲机动换取极致生存
- **适用卡型**：装甲(1)、堡垒(4)、支援(2) → 全类型但偏向高HP/高防
- **加成方向**：HP↑↑、三维防御↑↑、部署速度↓、攻击力↓
- **命名风格**：`钢壁·XX`
- **势力口号**：*「以钢铁铸就防线，以坚守赢得胜利」*

| 等级 | 名称后缀 | HP加成 | def_light | def_armor | def_air | atk惩罚 | deploy惩罚 |
|------|---------|--------|-----------|-----------|---------|---------|-----------|
| 1 | I型 | +8% | +8% | +8% | +8% | -3% | 0 |
| 2 | II型 | +12% | +12% | +12% | +12% | -5% | 0 |
| 3 | III型 | +18% | +15% | +15% | +15% | -5% | -1 |
| 4 | IV型 | +22% | +20% | +20% | +20% | -8% | -1 |
| 5 | V型 | +28% | +25% | +25% | +25% | -8% | -1 |
| 6 | VI型 | +35% | +30% | +30% | +30% | -10% | -2 |
| 7 | 精锐型 | +40% | +35% | +35% | +35% | -10% | -2 |
| 8 | 冠军型 | +50% | +42% | +42% | +42% | -12% | -2 |
| 9 | 英雄型 | +60% | +50% | +50% | +50% | -15% | -2 |
| 10 | 传奇型 | +75% | +60% | +60% | +60% | -18% | -3 |

#### 🔥 新星兵工制造 (nova_arms)
- **核心定位**：极致火力，不惜代价
- **适用卡型**：轻装(0)、装甲(1) → 偏向高攻击
- **加成方向**：三维攻击↑↑、攻击速度↑、HP↓、防御↓
- **命名风格**：`新星·XX`
- **势力口号**：*「火力即正义，口径即真理」*

| 等级 | 名称后缀 | atk_light | atk_armor | atk_air | atk_speed | HP惩罚 | def惩罚 |
|------|---------|-----------|-----------|---------|-----------|--------|---------|
| 1 | I型 | +10% | +8% | +5% | 0% | -5% | -5% |
| 2 | II型 | +15% | +12% | +8% | +3% | -8% | -8% |
| 3 | III型 | +22% | +18% | +12% | +5% | -10% | -10% |
| 4 | IV型 | +28% | +22% | +15% | +8% | -12% | -12% |
| 5 | V型 | +35% | +28% | +20% | +10% | -15% | -15% |
| 6 | VI型 | +42% | +35% | +25% | +12% | -18% | -18% |
| 7 | 精锐型 | +50% | +42% | +30% | +15% | -20% | -20% |
| 8 | 冠军型 | +60% | +50% | +38% | +18% | -25% | -25% |
| 9 | 英雄型 | +70% | +58% | +45% | +20% | -28% | -28% |
| 10 | 传奇型 | +85% | +70% | +55% | +25% | -35% | -35% |

#### ⚡ 以太动力重工 (aether_dynamics)
- **核心定位**：机动至上，快打快撤
- **适用卡型**：轻装(0)、空中(3)、装甲(1) → 偏向高机动/快部署
- **加成方向**：部署速度↑↑、能量消耗↓、攻击速度↑、HP↓
- **命名风格**：`以太·XX` / 希腊字母后缀 (α/β/γ/δ/ε...)
- **势力口号**：*「速度就是装甲，机动就是防御」*

| 等级 | 名称后缀 | energy_reduce | deploy_speed | atk_speed_bonus | HP惩罚 |
|------|---------|--------------|-------------|-----------------|--------|
| 1 | α型 | -5% | +1 | 0% | -3% |
| 2 | β型 | -8% | +1 | +3% | -5% |
| 3 | γ型 | -10% | +2 | +5% | -8% |
| 4 | δ型 | -12% | +2 | +8% | -10% |
| 5 | ε型 | -15% | +3 | +10% | -12% |
| 6 | ζ型 | -18% | +3 | +12% | -15% |
| 7 | η型 | -20% | +4 | +15% | -18% |
| 8 | θ型 | -23% | +4 | +18% | -20% |
| 9 | ι型 | -25% | +5 | +20% | -22% |
| 10 | Ω型 | -30% | +6 | +25% | -25% |

#### 📦 量子后勤集团 (quantum_logistics)
- **核心定位**：持久作战，战损修复
- **适用卡型**：全类型 → 偏向续航/回复
- **加成方向**：HP↑、生命回复↑、攻防均衡小幅提升、无惩罚
- **命名风格**：`量子·XX`
- **势力口号**：*「供给不断，战力不息」*

| 等级 | 名称后缀 | HP加成 | hp_regen | atk_light | def_light | def_armor |
|------|---------|--------|----------|-----------|-----------|-----------|
| 1 | I型 | +5% | 0.2%/s | +3% | +3% | +3% |
| 2 | II型 | +8% | 0.3%/s | +5% | +5% | +5% |
| 3 | III型 | +12% | 0.5%/s | +8% | +8% | +8% |
| 4 | IV型 | +15% | 0.8%/s | +10% | +10% | +10% |
| 5 | V型 | +20% | 1.0%/s | +12% | +12% | +12% |
| 6 | VI型 | +25% | 1.2%/s | +15% | +15% | +15% |
| 7 | 精锐型 | +30% | 1.5%/s | +18% | +18% | +18% |
| 8 | 冠军型 | +38% | 2.0%/s | +22% | +22% | +22% |
| 9 | 英雄型 | +45% | 2.5%/s | +25% | +25% | +25% |
| 10 | 传奇型 | +55% | 3.0%/s | +30% | +30% | +30% |

#### 🌀 螺旋侦察系统 (helix_recon)
- **核心定位**：精准打击，闪避制胜
- **适用卡型**：轻装(0)、空中(3) → 偏向高闪避/高命中/射程
- **加成方向**：闪避率↑、命中↑、射程↑、攻击↑(轻装)、防御↓
- **命名风格**：`螺旋·XX`
- **势力口号**：*「不被命中，便是无敌」*

| 等级 | 名称后缀 | dodge | accuracy | range_bonus | atk_light | def惩罚 |
|------|---------|-------|----------|-------------|-----------|---------|
| 1 | I型 | +3% | +5% | 0 | +5% | -3% |
| 2 | II型 | +5% | +8% | +1格 | +8% | -5% |
| 3 | III型 | +8% | +12% | +1格 | +12% | -8% |
| 4 | IV型 | +10% | +15% | +1格 | +15% | -10% |
| 5 | V型 | +13% | +18% | +2格 | +20% | -12% |
| 6 | VI型 | +16% | +22% | +2格 | +25% | -15% |
| 7 | 精锐型 | +20% | +25% | +2格 | +30% | -18% |
| 8 | 冠军型 | +24% | +30% | +3格 | +38% | -22% |
| 9 | 英雄型 | +28% | +35% | +3格 | +45% | -25% |
| 10 | 传奇型 | +35% | +42% | +4格 | +55% | -30% |

#### ✨ 虚空相位研究所 (void_research)
- **核心定位**：法则共鸣，特殊效果增强
- **适用卡型**：全类型 → 偏向法则/效果型增强
- **加成方向**：暴击↑、特效伤害↑、法则效率↑、基础攻防小幅提升
- **命名风格**：`虚空·XX`
- **势力口号**：*「超越物理的极限」*

| 等级 | 名称后缀 | crit_chance | crit_damage | effect_bonus | atk_light | HP加成 |
|------|---------|------------|-------------|-------------|-----------|--------|
| 1 | I型 | +3% | +5% | +5% | +3% | +3% |
| 2 | II型 | +5% | +10% | +8% | +5% | +5% |
| 3 | III型 | +8% | +15% | +12% | +8% | +8% |
| 4 | IV型 | +10% | +20% | +15% | +10% | +10% |
| 5 | V型 | +13% | +25% | +20% | +13% | +13% |
| 6 | VI型 | +16% | +32% | +25% | +16% | +16% |
| 7 | 精锐型 | +20% | +40% | +30% | +20% | +20% |
| 8 | 冠军型 | +25% | +50% | +38% | +25% | +25% |
| 9 | 英雄型 | +30% | +62% | +45% | +30% | +30% |
| 10 | 传奇型 | +38% | +80% | +55% | +38% | +38% |

#### 🏔️ 边境联合公司 (frontier_union)
- **核心定位**：万能手，无短板也无长板
- **适用卡型**：全类型 → 均衡加成，适合新手
- **加成方向**：全属性均衡小幅提升，无惩罚，数值低于专精势力
- **命名风格**：`边境·XX`
- **势力口号**：*「什么都做，什么都行」*

| 等级 | 名称后缀 | HP | atk_light | atk_armor | atk_air | def_light | def_armor | def_air |
|------|---------|-----|-----------|-----------|---------|-----------|-----------|---------|
| 1 | I型 | +4% | +4% | +4% | +4% | +4% | +4% | +4% |
| 2 | II型 | +6% | +6% | +6% | +6% | +6% | +6% | +6% |
| 3 | III型 | +9% | +9% | +9% | +9% | +9% | +9% | +9% |
| 4 | IV型 | +12% | +12% | +12% | +12% | +12% | +12% | +12% |
| 5 | V型 | +16% | +16% | +16% | +16% | +16% | +16% | +16% |
| 6 | VI型 | +20% | +20% | +20% | +20% | +20% | +20% | +20% |
| 7 | 精锐型 | +25% | +25% | +25% | +25% | +25% | +25% | +25% |
| 8 | 冠军型 | +32% | +32% | +32% | +32% | +32% | +32% | +32% |
| 9 | 英雄型 | +38% | +38% | +38% | +38% | +38% | +38% | +38% |
| 10 | 传奇型 | +48% | +48% | +48% | +48% | +48% | +48% | +48% |

### 3.2 势力加成的核心原则

1. **有得必有失**（除边境联合公司外）：每个势力有明确优势方向，同时牺牲其他维度
2. **等幂增长**：同一势力 Lv10 的总加成量是 Lv1 的约 7-8 倍（非线性递增）
3. **特色鲜明**：每个势力的加成维度和惩罚维度互不重叠
4. **上下限安全**：所有加成/惩罚都使用 `clamp` 保证不产生负数或溢出

---

## 四、系统架构设计

### 4.1 新增文件清单

```
data/
  faction_card_bonuses.gd          ← [新建] 势力卡牌加成配置表
managers/
  faction/
    faction_card_generator.gd      ← [新建] 势力变体卡牌生成器
```

### 4.2 修改文件清单

```
managers/battle/battle_spawn_system.gd    ← [修改] 注入势力变体到战场部署流
managers/faction_system_manager.gd       ← [修改] 新增势力变体相关接口
data/unit_lineage_config.gd              ← [扩展] 填充 faction_branches
resources/unit_stats_table.gd             ← [可选] 支持势力变体卡牌
resources/card_resource.gd                ← [扩展] 新增势力元数据字段
```

### 4.3 新增数据文件：`data/faction_card_bonuses.gd`

```gdscript
## 职责：
## 1. 定义 7 势力 × 10 级的加成规则
## 2. 提供查询接口：根据 (faction_id, level) 获取加成字典
## 3. 提供工具函数：卡名格式化、战力重算

## 数据结构：
## FACTION_BONUS_TABLE[faction_id][level] = {
##     "name_prefix": "钢壁",          # 变体卡名前缀
##     "name_suffix": "III型",         # 变体卡名后缀（与前缀二选一）
##     "hp_bonus": 0.18,               # HP加成比例（正=增，负=减）
##     "atk_light_bonus": 0.10,        # 对轻装攻击加成
##     "atk_armor_bonus": 0.10,        # 对装甲攻击加成
##     "atk_air_bonus": 0.05,          # 对空攻击加成
##     "def_light_bonus": 0.15,        # 防轻装武器加成
##     "def_armor_bonus": 0.15,        # 防装甲武器加成
##     "def_air_bonus": 0.15,          # 防空武器加成
##     "energy_cost_reduce": 0.10,      # 能量消耗减少（正=减）
##     "deploy_speed_bonus": 2,        # 部署速度加成（整数）
##     "attack_speed_bonus": 0.05,     # 攻击速度加成
##     "range_bonus": 1,               # 射程加成（格数）
##     "dodge_bonus": 0.10,            # 闪避率加成
##     "crit_chance_bonus": 0.10,     # 暴击率加成
##     "crit_damage_bonus": 0.20,      # 暴击伤害加成
##     "accuracy_bonus": 0.10,          # 命中精度加成
##     "hp_regen_pct": 0.01,            # 每秒HP回复百分比
##     "damage_reduction_bonus": 0.10,   # 减伤加成
##     "effect_bonus": 0.10,            # 法则效果加成
##     "power_mult_override": 0.0,      # 战力倍率覆盖（0=自动计算）
## }
```

### 4.4 新增管理器：`managers/faction/faction_card_generator.gd`

```gdscript
## 职责：
## 1. generate_faction_variant(base_card_id, faction_id, faction_level)
##    → 返回 CardResource（cloned + 势力加成）
## 2. format_faction_card_name(base_name, faction_id, level)
##    → 返回变体卡名
## 3. calculate_faction_power(base_power, bonus_dict)
##    → 返回变体战力
## 4. is_faction_variant(card_resource)
##    → 判断是否为势力变体卡
## 5. get_variant_meta(card_resource)
##    → 获取变体元数据 (faction_id, level, base_card_id)
```

### 4.5 CardResource 扩展字段

```gdscript
## 在 card_resource.gd 中新增：

# 势力变体元数据（运行时，非序列化）
var faction_id: String = ""           # 势力ID（空=非变体）
var faction_level: int = 0            # 势力等级（0=非变体）
var base_card_id: String = ""         # 原始基础卡ID（空=非变体）
var is_faction_variant: bool = false   # 是否为势力变体
```

---

## 五、集成点详细设计

### 5.1 战场部署集成

**文件**：`managers/battle/battle_spawn_system.gd`
**修改位置**：`_build_platform_stats_with_cache()` 函数（约 L705）

**当前代码**：
```gdscript
var stats = UnitStatsTable.build_stats_from_card(platform_card, battle_era)
var bm_growth: Node = _get_autoload_node("BlueprintManager")
if bm_growth and bm_growth.has_method("apply_growth_to_stats"):
    bm_growth.apply_growth_to_stats(stats, platform_card, weapon_cards)
var am: Node = _get_autoload_node("AffixManager")
if am and am.has_method("apply_affixes_to_stats"):
    am.apply_affixes_to_stats(stats, platform_card, weapon_cards)
```

**修改后代码**：
```gdscript
# === 势力变体注入（新增） ===
var effective_card: CardResource = platform_card
if platform_card.is_faction_variant:
    # 变体卡已经包含势力加成，直接使用
    effective_card = platform_card
else:
    # 检查玩家当前是否选择了某个势力
    var fsm: Node = _get_autoload_node("FactionSystemManager")
    if fsm and fsm.has_method("get_active_faction"):
        var active_faction: String = fsm.get_active_faction()
        if not active_faction.is_empty():
            var faction_level: int = fsm.get_faction_level(active_faction)
            if faction_level > 0:
                effective_card = FactionCardGenerator.generate_faction_variant(
                    platform_card.card_id, active_faction, faction_level
                )

var stats = UnitStatsTable.build_stats_from_card(effective_card, battle_era)
# ... 后续不变
```

### 5.2 进化链势力分支填充

**文件**：`data/unit_lineage_config.gd`
**修改内容**：将所有 `faction_branches: {}` 填充为势力专属进化目标

**示例**（虎式坦克 → 势力分支进化）：
```gdscript
"ww2_tiger": {
    "evolution_1": "cold_t72",
    "faction_branches": {
        "iron_wall_corp": "fut_heavy_mech",      # 钢壁路线：重装机甲
        "nova_arms": "mod_m1a2sep",                 # 新星路线：M1A2 SEP
        "aether_dynamics": "fut_hovertank",         # 以太路线：悬浮坦克
        "frontier_union": "mod_leo2a6",             # 边境路线：豹2A6
        # quantum_logistics: 暂无（后勤不做战斗专精进化）
        # helix_recon: 暂无（侦察不做坦克进化）
        # void_research: "fut_stormcore"            # 虚空路线：风暴核心原型
    },
},
```

### 5.3 势力商店集成

**文件**：`managers/faction/faction_shop.gd`
**修改内容**：势力商店可出售势力变体蓝图

- 当势力等级 >= 3 时，商店中出现该势力变体的基础卡蓝图
- 变体蓝图使用 `faction:{faction_id}:{base_card_id}` 格式存储
- 购买后解锁该变体，可在卡组中选择使用

### 5.4 存档兼容

**存档格式**：
```gdscript
# 新增字段（在 SaveManager 的存档中）
{
    "faction_active": "iron_wall_corp",         # 当前激活势力
    "faction_variants_unlocked": [               # 已解锁势力变体
        "faction:iron_wall_corp:ww2_tiger",
        "faction:nova_arms:mod_marine",
    ],
}
```

**向后兼容**：
- 新增字段使用 `get("key", default)` 读取
- 旧存档无 `faction_active` → 默认无势力激活
- 旧存档无 `faction_variants_unlocked` → 默认空数组

---

## 六、完整属性计算管线

### 6.1 最终属性计算顺序

```
┌──────────────────────────────────────────────────────────────────┐
│ 步骤 0: 选择基础卡                                                 │
│   CardResource from default_cards.gd                              │
│   基础字段: base_hp, attack_light, attack_armor, attack_air,     │
│            defense_light, defense_armor, defense_air,            │
│            energy_cost, deploy_speed, range_value, power         │
├──────────────────────────────────────────────────────────────────┤
│ 步骤 1: 势力变体加成 ★ [新增]                                      │
│   FactionCardGenerator.apply_faction_bonus()                      │
│   修改: base_hp × (1 + hp_bonus)                                 │
│         attack_X × (1 + atk_X_bonus)                             │
│         defense_X × (1 + def_X_bonus)                             │
│         energy_cost × (1 - energy_cost_reduce)                   │
│         deploy_speed += deploy_speed_bonus                        │
│   特殊: dodge, crit_chance, crit_damage, accuracy, hp_regen       │
│   结果: 势力变体 CardResource                                      │
├──────────────────────────────────────────────────────────────────┤
│ 步骤 2: 时代缩放                                                    │
│   UnitStatsTable.build_stats_from_card()                           │
│   era_damage_multiplier / era_hp_multiplier / era_range_multiplier│
├──────────────────────────────────────────────────────────────────┤
│ 步骤 3: 星级成长 + 稀有度倍率                                        │
│   BattleCardV3.star_stat_multiplier()                              │
│   EvolutionHelpers.get_effective_power_multiplier()               │
│   EvolutionHelpers.apply_growth_to_stats()                        │
│   HP × star_mul, DMG × star_mul                                   │
├──────────────────────────────────────────────────────────────────┤
│ 步骤 4: 进化继承                                                    │
│   blueprint_inherit_bonus (0.0 ~ 0.40)                            │
│   HP × (1 + inherit_bonus), DMG × (1 + inherit_bonus)            │
│   进化HP下限: max(calculated_hp, evolution_hp_floor × era_mul)    │
├──────────────────────────────────────────────────────────────────┤
│ 步骤 5: 军衔加成                                                    │
│   RankRules.get_rank_bonus(rank_id)                                │
│   HP × rank_hp_mul, DMG × rank_dmg_mul                            │
├──────────────────────────────────────────────────────────────────┤
│ 步骤 6: 词条加成                                                    │
│   AffixManager.apply_affixes_to_stats()                            │
│   各词条效果叠加到 UnitStats                                       │
├──────────────────────────────────────────────────────────────────┤
│ 步骤 7: 相位仪加成                                                  │
│   PhaseInstrument.apply_phase_field_bonus_to_unit_stats()           │
│   相位场环境修正                                                    │
├──────────────────────────────────────────────────────────────────┤
│ 步骤 8: 改造(MOD)加成                                               │
│   ModManager (已嵌入 BlueprintManager 流程)                        │
│   20种MOD效果: attack_mult, defense_mult, speed_mult 等           │
├──────────────────────────────────────────────────────────────────┤
│ 结果: 最终 UnitStats → 战场部署                                      │
└──────────────────────────────────────────────────────────────────┘
```

### 6.2 势力变体在 UnitStats 中的体现

势力变体的特殊加成（dodge, crit, hp_regen, damage_reduction 等）需在 `UnitStats` 中新增字段：

```gdscript
## UnitStats 新增字段
var dodge_bonus: float = 0.0           # 闪避率加成
var crit_chance_bonus: float = 0.0      # 暴击率加成
var crit_damage_bonus: float = 0.0      # 暴击伤害加成
var accuracy_bonus: float = 0.0         # 命中精度加成
var hp_regen_pct: float = 0.0           # 每秒HP回复百分比
var damage_reduction_bonus: float = 0.0 # 减伤加成
```

---

## 七、势力变体进化分支设计

### 7.1 分支设计原则

- **势力分支进化**是 E1（主线进化）的**替代选项**，不是额外进化
- 玩家在 E2 阶段选择：继续 E1 直线进化 **或** 走势力分支
- 势力分支的目标必须是**已有基础卡牌**（不新增卡牌数据）
- 分支目标通常比直线进化的目标**更偏向该势力特色**

### 7.2 完整分支表（需填充到 unit_lineage_config.gd）

#### 轻装线分支

| 源卡 | 直线E1 | iron_wall | nova_arms | aether | quantum | helix | void | frontier |
|------|--------|-----------|-----------|--------|---------|-------|------|----------|
| ww1_mp18 | ww2_thompson | — | — | mod_marine | — | mod_ranger | fut_spectre | cold_ak47 |
| ww2_thompson | cold_ak47 | mod_ranger | mod_marine | cold_spetsnaz | mod_marine | mod_ranger | fut_spectre | cold_ak47 |
| cold_ak47 | mod_marine | mod_ranger | fut_cyborg | mod_ranger | mod_marine | fut_spectre | fut_cyborg | mod_marine |
| mod_marine | fut_cyborg | fut_heavy_trooper | fut_cyborg | fut_scout_mech | fut_cyborg | fut_spectre | fut_nexus | fut_cyborg |
| ww2_panzerschrek | cold_rpg | — | mod_javelin | mod_javelin | — | mod_ranger | — | cold_rpg |
| cold_rpg | mod_javelin | — | mod_javelin | mod_javelin | — | — | — | mod_javelin |
| mod_javelin | fut_cyborg | fut_heavy_trooper | fut_assault_mech | fut_scout_mech | fut_cyborg | fut_spectre | fut_nexus | fut_cyborg |
| ww1_storm | cold_spetsnaz | mod_ranger | mod_ranger | mod_ranger | mod_ranger | mod_ranger | fut_spectre | cold_spetsnaz |
| cold_spetsnaz | mod_ranger | mod_ranger | mod_ranger | mod_ranger | mod_ranger | mod_ranger | fut_spectre | mod_ranger |

#### 装甲线分支

| 源卡 | 直线E1 | iron_wall | nova_arms | aether | quantum | helix | void | frontier |
|------|--------|-----------|-----------|--------|---------|-------|------|----------|
| ww1_ft17 | ww2_pz3 | ww2_tiger | ww2_panther | cold_t55 | ww2_t34_85 | cold_t62 | fut_hovertank | cold_t55 |
| ww2_pz3 | cold_t55 | cold_t72 | cold_leo1 | cold_t55 | cold_t72 | cold_chieftain | fut_hovertank | cold_t72 |
| cold_t55 | mod_m1a1 | mod_m1a2sep | mod_m1a2sep | mod_m1a1 | mod_m1a1 | mod_leo2a6 | fut_hovertank | mod_m1a1 |
| mod_m1a1 | fut_hovertank | fut_heavy_mech | fut_assault_mech | fut_hovertank | fut_hovertank | fut_prism | fut_colossus | fut_hovertank |
| ww1_saint | ww2_tiger | ww2_kingtiger | ww2_panther | ww2_tiger | cold_t72 | cold_chieftain | fut_heavy_mech | cold_t72 |
| ww2_tiger | cold_t72 | cold_t72 | mod_m1a2sep | cold_t72 | mod_m1a2sep | mod_leo2a6 | fut_heavy_mech | mod_m1a2sep |
| cold_t72 | mod_m1a2sep | mod_m1a2sep | mod_m1a2sep | mod_m1a1 | mod_m1a1 | mod_leo2a6 | fut_heavy_mech | mod_m1a2sep |
| mod_m1a2sep | fut_heavy_mech | fut_colossus | fut_assault_mech | fut_hovertank | fut_heavy_mech | fut_prism | fut_nexus | fut_heavy_mech |

#### 空中线分支

| 源卡 | 直线E1 | iron_wall | nova_arms | aether | quantum | helix | void | frontier |
|------|--------|-----------|-----------|--------|---------|-------|------|----------|
| cold_mig21 | mod_ah64 | mod_ah64 | mod_ah64 | fut_space_fighter | mod_uh60 | fut_space_fighter | fut_space_fighter | mod_ah64 |
| mod_ah64 | fut_space_fighter | fut_space_fighter | fut_stealth_bomber | fut_space_fighter | fut_attack_drone | fut_space_fighter | fut_stealth_bomber | fut_space_fighter |
| mod_ah1 | fut_attack_drone | fut_attack_drone | fut_attack_drone | fut_space_fighter | fut_scout_drone | fut_attack_drone | fut_stealth_bomber | fut_attack_drone |

#### 支援线分支

| 源卡 | 直线E1 | iron_wall | nova_arms | aether | quantum | helix | void | frontier |
|------|--------|-----------|-----------|--------|---------|-------|------|----------|
| ww1_m81 | ww2_m81 | ww2_m120 | ww2_m81 | ww2_m81 | ww2_m120 | ww2_m81 | ww2_m120 | ww2_m81 |
| ww2_m81 | cold_m113 | cold_m113 | cold_bmp1 | cold_bmp1 | cold_m113 | cold_bmp1 | cold_m113 | cold_m113 |
| cold_m113 | mod_m270 | mod_m270 | mod_m270 | mod_m270 | mod_m270 | mod_m270 | mod_m270 | mod_m270 |
| mod_m270 | fut_howitzer | fut_ion | fut_howitzer | fut_howitzer | fut_howitzer | fut_howitzer | fut_ion | fut_howitzer |
| ww1_37mm | cold_zsu23 | cold_zsu23 | mod_m6 | cold_zsu23 | cold_zsu23 | mod_m6 | mod_m6 | cold_zsu23 |
| cold_zsu23 | mod_m6 | mod_m6 | mod_m6 | mod_m6 | mod_m6 | mod_m6 | mod_m6 | mod_m6 |
| mod_m6 | fut_aa_hover | fut_aa_hover | fut_aa_hover | fut_aa_hover | fut_aa_hover | fut_aa_hover | fut_shield | fut_aa_hover |

> **注**：`—` 表示该势力对该卡没有特色分支（使用直线进化）。
> **注2**：分支目标均为已有的 `default_cards.gd` 中的基础卡ID，不新增卡牌。

---

## 八、实施分阶段计划

### Phase 1：数据层（核心配置）

**预计工作量**：2-3 小时
**优先级**：🔴 P0

#### 任务清单：
- [ ] **1.1** 创建 `data/faction_card_bonuses.gd`
  - 完整 7 势力 × 10 级加成表（参考 §3.1）
  - 查询接口：`get_bonus(faction_id, level) -> Dictionary`
  - 工具函数：`format_name(base_name, faction_id, level) -> String`
  - 工具函数：`calculate_power(base_power, bonus) -> int`
  - 校验函数：`validate_all_bonuses() -> PackedStringArray`

- [ ] **1.2** 创建 `managers/faction/faction_card_generator.gd`
  - `generate_faction_variant(base_card_id, faction_id, level) -> CardResource`
  - 依赖 `default_cards.gd` + `faction_card_bonuses.gd`
  - 内部：clone CardResource → 叠加加成 → 设置元数据
  - 静态缓存机制（同 default_cards 的 _ensure_card_cache 模式）

- [ ] **1.3** 扩展 `resources/card_resource.gd`
  - 新增势力变体元数据字段（运行时，非 @export）
  - 在 `clone()` 中复制新字段

### Phase 2：集成层（战场部署）

**预计工作量**：1-2 小时
**优先级**：🔴 P0
**依赖**：Phase 1

#### 任务清单：
- [ ] **2.1** 修改 `managers/battle/battle_spawn_system.gd`
  - 在 `_build_platform_stats_with_cache()` 中注入势力变体
  - 需要获取当前激活势力（Phase 3 提供 API）
  - 缓存 key 需要包含势力变体信息

- [ ] **2.2** 扩展 `resources/unit_stats_table.gd`
  - 新增势力特殊属性字段（dodge_bonus, crit_chance_bonus 等）
  - `build_stats_from_card()` 读取势力元数据并写入 UnitStats

- [ ] **2.3** 扩展 `resources/unit_stats.gd`（如果存在）
  - 新增字段与上述对应

### Phase 3：势力管理集成

**预计工作量**：1-2 小时
**优先级**：🟡 P1
**依赖**：Phase 1

#### 任务清单：
- [ ] **3.1** 修改 `managers/faction_system_manager.gd`
  - 新增 `active_faction: String` 字段（当前激活势力）
  - 新增 `set_active_faction(faction_id)` / `get_active_faction()` 接口
  - 新增 `get_faction_variant_card(base_card_id) -> CardResource`
  - 信号：`active_faction_changed(faction_id)`

- [ ] **3.2** 存档集成
  - `save_state()` 中新增 `active_faction` 和 `faction_variants_unlocked`
  - `load_state()` 中兼容旧存档

- [ ] **3.3** 势力面板 UI 适配
  - `faction_panel.gd` 中显示势力变体预览
  - 新增"激活势力"按钮
  - 显示当前势力加成效果预览

### Phase 4：进化分支填充

**预计工作量**：2-3 小时
**优先级**：🟡 P1
**依赖**：Phase 1, Phase 3

#### 任务清单：
- [ ] **4.1** 填充 `data/unit_lineage_config.gd` 的 `faction_branches`
  - 参考 §7.2 分支表
  - 每个有进化链的节点都需填充势力分支
  - 部分势力-卡牌组合可留空（无特色分支时使用直线进化）

- [ ] **4.2** 验证进化分支
  - `UnitLineageConfig.validate_lineage_targets()` 确认所有目标有效
  - 确认不跨 combat_kind 类型

### Phase 5：UI 展示层

**预计工作量**：3-4 小时
**优先级**：🟢 P2
**依赖**：Phase 1-4

#### 任务清单：
- [ ] **5.1** 卡牌信息面板适配
  - `card_info_panel.gd`：显示势力变体名称和加成标签
  - 势力变体卡使用势力颜色边框

- [ ] **5.2** 背包面板适配
  - `backpack_card_item.gd`：势力变体卡显示势力图标
  - 变体卡与基础卡在同一列表中展示

- [ ] **5.3** 进化图鉴适配
  - `evolution_atlas_view.gd`：显示势力分支选项
  - `unit_progression_detail_view.gd`：显示势力分支进化目标

- [ ] **5.4** 势力商店适配
  - `faction_store_panel.gd`：显示势力变体蓝图
  - `faction_shop.gd`：新增势力变体商品

### Phase 6：平衡调优

**预计工作量**：2-4 小时
**优先级**：🟢 P2
**依赖**：Phase 1-5

#### 任务清单：
- [ ] **6.1** 数值平衡测试
  - 每个势力 Lv1/Lv5/Lv10 的代表性变体卡战力对比
  - 确保无势力在所有维度上碾压其他势力
  - 确保无势力完全无用

- [ ] **6.2** 战斗模拟
  - 同等战力下，不同势力变体的战斗表现对比
  - 修正极端情况（如新星Lv10变体HP为负数）

- [ ] **6.3** 代码调优
  - 缓存策略优化（避免每次部署都 clone）
  - 内存管理（变体卡的生命周期）

---

## 九、风险与注意事项

### 9.1 技术风险

| 风险 | 级别 | 缓解措施 |
|------|------|---------|
| clone() 性能开销 | 中 | 使用静态缓存 + 懒加载 |
| 势力变体导致战斗数值崩坏 | 高 | 所有加成使用 clamp，Phase 6 平衡测试 |
| 存档兼容性 | 中 | 使用 .get(key, default)，旧存档不崩溃 |
| 进化分支目标不存在 | 中 | validate_lineage_targets() 校验 |
| 战场部署流改动引入bug | 高 | 保留原始流程，势力变体为可选注入 |

### 9.2 设计风险

| 风险 | 级别 | 缓解措施 |
|------|------|---------|
| 势力间不平衡 | 高 | Phase 6 平衡测试 + 迭代调优 |
| 变体卡名冲突 | 低 | 统一使用 `{prefix}·{base_name} {suffix}` 格式 |
| 玩家困惑（基础卡 vs 变体卡） | 中 | UI 明确标注势力标签 + 颜色区分 |
| 进化分支过多导致选择瘫痪 | 低 | 每个势力最多 1 个分支，显示推荐标记 |

### 9.3 后续扩展方向

1. **势力专属卡**：仅在该势力下可使用的特殊卡牌
2. **势力技能树**：类似天赋树，势力等级解锁被动技能
3. **势力战争事件**：动态事件影响势力间关系和加成
4. **势力合成台**：跨势力卡牌合成产生混血变体

---

## 十、验收标准

### Phase 1 验收：
- [ ] `faction_card_bonuses.gd` 包含完整 7×10 加成表
- [ ] `faction_card_generator.gd` 能生成正确的变体卡
- [ ] 变体卡名称格式正确（如 `钢壁·虎式坦克 III型`）
- [ ] 数值加成计算正确（对照 §3.1 表格验证）

### Phase 2 验收：
- [ ] 战场部署中使用势力变体卡
- [ ] UnitStats 包含势力特殊属性
- [ ] 缓存机制工作正常

### Phase 3 验收：
- [ ] 可设置/切换激活势力
- [ ] 存档保存/加载势力选择
- [ ] 势力面板显示变体预览

### Phase 4 验收：
- [ ] 所有进化节点包含势力分支
- [ ] 分支目标全部有效
- [ ] 进化流程不跨类型

### Phase 5 验收：
- [ ] 卡牌面板显示势力信息
- [ ] 进化图鉴显示势力分支
- [ ] 势力商店出售变体蓝图

### Phase 6 验收：
- [ ] 无势力完全碾压
- [ ] 无势力完全无用
- [ ] 战斗模拟数值合理

---

## 附录A：文件依赖关系图

```
                         company_definitions.gd
                                │
                                ▼
faction_card_bonuses.gd ◄────────── faction_system_manager.gd
        │                              │
        ▼                              ▼
faction_card_generator.gd ◄───── unit_lineage_config.gd
        │                              │
        ▼                              ▼
    card_resource.gd ◄─────── card_evolution_manager.gd
        │
        ▼
    unit_stats_table.gd
        │
        ▼
    battle_spawn_system.gd ◄─── blueprint_manager.gd
                                    │
                              mod_manager.gd
                              mod_effects.gd
                              affix_manager.gd
```

## 附录B：接口速查

```gdscript
# === FactionCardBonuses (data/faction_card_bonuses.gd) ===
static func get_bonus(faction_id: String, level: int) -> Dictionary
static func format_name(base_name: String, faction_id: String, level: int) -> String
static func calculate_power(base_power: int, bonus: Dictionary) -> int
static func validate_all_bonuses() -> PackedStringArray

# === FactionCardGenerator (managers/faction/faction_card_generator.gd) ===
static func generate_faction_variant(base_card_id: String, faction_id: String, level: int) -> CardResource
static func is_faction_variant(card: CardResource) -> bool
static func get_variant_meta(card: CardResource) -> Dictionary

# === FactionSystemManager (managers/faction_system_manager.gd) 扩展 ===
func set_active_faction(faction_id: String) -> void
func get_active_faction() -> String
func get_faction_variant_card(base_card_id: String) -> CardResource
signal active_faction_changed(faction_id: String)
```
