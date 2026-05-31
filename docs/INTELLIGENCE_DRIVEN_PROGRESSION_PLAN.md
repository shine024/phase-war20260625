# 📋 情报驱动的强化与进化系统 — 详细实现计划

> **目标**：打破现有"格式化"的强化/进化流程，使玩家通过与不同敌人战斗获取情报，
> 解锁**各具特色的强化路线和进化分支**，让每张卡的成长路径都充满探索感和惊喜。
>
> **创建日期**：2026-05-31
> **版本**：v6.0-plan-1

---

## 一、现状分析与核心问题

### 1.1 现有系统概览

| 系统 | 位置 | 当前机制 | 问题 |
|------|------|----------|------|
| **情报系统** | `scripts/systems/intel_manual.gd` | 4个阶梯(25/50/75/100%)，仅作为进化前置门槛 | **情报内容空洞**——只解锁"可见性"，不解锁实际玩法内容 |
| **进化系统** | `managers/evolution/card_evolution_manager.gd` | 9条固定路线(37个节点)，条件：战力+情报100%+星级+改造满+资源 | **路线僵化**——每张卡的进化路径完全固定，无探索空间 |
| **强化系统** | `scenes/ui/card_enhancement_panel.gd` | 升星(1-9) + 改装(3槽ABC) + 强化等级(Lv.1-10) | **千篇一律**——所有卡都用相同的20种MOD，强化只是数值堆叠 |
| **战斗掉落** | `managers/battle/battle_damage_system.gd` | 纳米材料 + 蓝图碎片 + 法则知识 + 词条奖励 | **掉落无差异化**——不与情报进度关联，掉落物无惊喜感 |
| **战斗结算UI** | `scenes/ui/battle_result_dialog.gd` / `battle_result_panel.gd` | 胜负 → 星级 → 奖励列表 → 领取 | **情报收获不突出**——情报进度只是后台数值变化，玩家无感知 |

### 1.2 核心设计矛盾

**现有系统的"格式化"体现在：**
1. **进化路径完全可预测**：打开 `UnitLineageConfig.LINEAGES` 就能一览无遗，无探索价值
2. **强化选项完全通用**：20种MOD适用于所有卡，没有"从特定敌人获得专属强化"的感觉
3. **情报只是进度条**：从0%到100%只是数值累加，没有任何阶段性"发现"的爽感
4. **战斗掉落与情报无关**：打同一个敌人10次和1次，掉落体验完全相同

---

## 二、设计理念：情报 = 解锁钥匙

### 2.1 核心原则

```
战斗敌人 → 获取情报 → 逐层解锁信息 → 根据情报发现专属强化/进化分支
```

**类比**：就像考古学家发掘遗址——每获得一部分情报，就能拼凑出更多关于敌人弱点、
专属材料、秘密进化路径的信息，最终解锁"只有打过这个敌人才能获得"的独特成长选项。

### 2.2 三大设计支柱

| 支柱 | 描述 | 玩家体验 |
|------|------|----------|
| **情报发现** | 情报不再是进度条，而是分层揭示的"发现" | "我发现了这个敌人居然隐藏着……" |
| **敌源强化** | 打特定敌人获得的情报能解锁专属强化MOD | "只有击败过突击炮兵才能安装穿甲热能弹" |
| **情报进化分支** | 特定敌人的情报组合能解锁隐藏进化路径 | "原来把侦察兵情报和工程师情报组合起来，能进化出特种工兵！" |

---

## 三、系统详细设计

### 3.1 情报发现系统 (Intel Discovery)

#### 3.1.1 情报类型扩展

**现有**：每张卡的情报只有一个统一的 `intel_progress` (0.0-1.0)

**新增**：情报分为 **4个维度**，每个维度独立积累

```gdscript
## 新增情报维度定义（data/intel_dimensions.gd）
class IntelDimensions:
    const DIM_BASIC: String = "basic"       # 基础属性情报（HP/攻击/防御数值）
    const DIM_TACTICAL: String = "tactical" # 战术情报（行为模式/技能类型/弱点）
    const DIM_MATERIAL: String = "material" # 素材情报（可掉落的专属材料信息）
    const DIM_SECRET: String = "secret"     # 秘密情报（隐藏进化线索/传奇配方）

    ## 情报维度对应的中文名
    const DIM_NAMES: Dictionary = {
        "basic": "基础侦察",
        "tactical": "战术分析",
        "material": "素材研究",
        "secret": "机密档案",
    }

    ## 情报维度对应的颜色主题
    const DIM_COLORS: Dictionary = {
        "basic": Color(0.5, 0.7, 0.9),      # 蓝色
        "tactical": Color(0.9, 0.6, 0.2),   # 橙色
        "material": Color(0.3, 0.85, 0.5),  # 绿色
        "secret": Color(0.8, 0.3, 0.9),    # 紫色
    }
```

#### 3.1.2 情报获取规则

| 情报来源 | 基础情报(B) | 战术情报(T) | 素材情报(M) | 秘密情报(S) |
|----------|------------|------------|------------|------------|
| 首次遭遇 | +25% | +0% | +0% | +0% |
| 击败普通 | +5-8% | +3-6% | +2-4% | +0% |
| 击败精英 | +8-12% | +8-15% | +5-10% | +0-3% |
| 击败BOSS | +10-15% | +12-20% | +10-18% | +5-12% |
| 侦察单位 | +3-5% | +5-10% | +2-5% | +0% |
| 分解重复卡 | +3-5% | +3-5% | +5-8% | +2-4% |
| 3星胜利加成 | +10% | +10% | +10% | +5% |

#### 3.1.3 情报揭示事件 (Intel Reveal Events)

当某个维度达到阈值时，触发**揭示事件**——在战斗结算界面和情报中心展示：

```gdscript
## 揭示事件定义结构
var reveal_event: Dictionary = {
    "dimension": "tactical",
    "threshold": 0.50,           # 50%时揭示
    "title": "战术分析·初级报告",
    "description": "通过多次交战，我方分析出突击炮兵的攻击模式存在明显间隔，
                    在开火后的1.5秒内是其弱点窗口。",
    "reward_type": "weakness_hint",  # 弱点提示
    "reward_data": {"weakness": "post_reload_vulnerability", "bonus_damage": 0.25},
    "icon": "⚔️",
}
```

**揭示等级表：**

| 维度 | 25%揭示 | 50%揭示 | 75%揭示 | 100%揭示 |
|------|---------|---------|---------|----------|
| 基础 | 名称+类型可见 | 完整属性数值 | 隐藏属性公开 | 解锁图鉴百科 |
| 战术 | 行为模式概要 | 技能列表+弱点 | 详细AI逻辑 | **解锁弱点词条(战斗中对该敌人+25%伤害)** |
| 素材 | 素材类型可见 | 专属掉落列表 | **解锁敌源MOD** | **解锁敌源进化材料** |
| 秘密 | 暗示文字 | **解锁隐藏进化线索** | 秘密配方碎片1 | **解锁完整秘密进化路线** |

---

### 3.2 敌源强化系统 (Enemy-Origin Modifications)

#### 3.2.1 核心概念

**敌源MOD**：只有通过战斗特定敌人并获取足够素材情报后才能解锁的**专属改造选项**。

与现有20种通用MOD不同，敌源MOD具有：
- **唯一性**：每种敌源MOD只对应1-2种敌人
- **特色效果**：效果直接关联敌人的战斗特色（如击败火焰兵获得"热能抗性"）
- **成长性**：素材情报越高，敌源MOD的效果越强（1级→3级）

#### 3.2.2 敌源MOD数据结构

```gdscript
## data/enemy_origin_mods.gd
class_name EnemyOriginMods

## 敌源改造定义表
const ENEMY_ORIGIN_MODS: Dictionary = {
    # ─── 轻装线敌人相关 ───
    "EOM_INFANTRY_01": {
        "id": "EOM_INFANTRY_01",
        "name": "步兵战术套件",
        "desc": "从步兵交战中学来的阵地战术",
        "source_enemy_type": "infantry",       # 关联敌人类型
        "required_material_intel": 0.50,       # 需要50%素材情报
        "tiers": [
            {
                "tier": 1,
                "effects": {"hp_flat": 15, "defense_pct": 0.05},
                "desc": "生命+15, 防御+5%",
            },
            {
                "tier": 2,
                "effects": {"hp_flat": 30, "defense_pct": 0.10, "cover_bonus": 0.15},
                "desc": "生命+30, 防御+10%, 掩体加成+15%",
                "required_material_intel": 0.75,
            },
            {
                "tier": 3,
                "effects": {"hp_flat": 50, "defense_pct": 0.15, "cover_bonus": 0.25, "entrenchment": true},
                "desc": "生命+50, 防御+15%, 掩体加成+25%, 可挖掘阵地",
                "required_material_intel": 1.00,
            },
        ],
        "compatible_combat_kinds": [0, 2],    # 适用于轻装和支援
        "slot_type": "enemy_origin",            # 独立槽位，不占用A/B/C
    },
    "EOM_FLAME_01": {
        "id": "EOM_FLAME_01",
        "name": "热能抗性装甲",
        "desc": "研究火焰喷射兵后开发的热防护",
        "source_enemy_type": "flame",
        "required_material_intel": 0.50,
        "tiers": [
            {
                "tier": 1,
                "effects": {"fire_resist": 0.20, "hp_regen_pct": 0.005},
                "desc": "火焰抗性+20%, 每秒回复0.5%HP",
            },
            {
                "tier": 2,
                "effects": {"fire_resist": 0.40, "hp_regen_pct": 0.01, "reflect_fire": 0.10},
                "desc": "火焰抗性+40%, 每秒回复1%HP, 反射10%火焰伤害",
                "required_material_intel": 0.75,
            },
            {
                "tier": 3,
                "effects": {"fire_resist": 0.60, "hp_regen_pct": 0.02, "reflect_fire": 0.20, "fire_immunity": true},
                "desc": "火焰抗性+60%, 反射20%火焰伤害, 火焰免疫",
                "required_material_intel": 1.00,
            },
        ],
        "compatible_combat_kinds": [0, 1, 2, 3],
        "slot_type": "enemy_origin",
    },
    # ─── 装甲线敌人相关 ───
    "EOM_ARMOR_01": {
        "id": "EOM_ARMOR_01",
        "name": "反应装甲模块",
        "desc": "从坦克残骸中逆向工程得到的装甲技术",
        "source_enemy_type": "heavy_armor",
        "required_material_intel": 0.50,
        "tiers": [
            {"tier": 1, "effects": {"armor_pct": 0.15, "explosion_resist": 0.10}, "desc": "装甲+15%, 爆炸抗性+10%"},
            {"tier": 2, "effects": {"armor_pct": 0.25, "explosion_resist": 0.20, "reflect_proj": 0.08}, "desc": "装甲+25%, 爆炸抗性+20%, 反弹8%弹道", "required_material_intel": 0.75},
            {"tier": 3, "effects": {"armor_pct": 0.40, "explosion_resist": 0.35, "reflect_proj": 0.15, "adaptive_armor": true}, "desc": "装甲+40%, 自适应装甲, 反弹15%弹道", "required_material_intel": 1.00},
        ],
        "compatible_combat_kinds": [1],
        "slot_type": "enemy_origin",
    },
    "EOM_ARTILLERY_01": {
        "id": "EOM_ARTILLERY_01",
        "name": "弹道校准系统",
        "desc": "从火炮阵地获取的射击诸元数据",
        "source_enemy_type": "artillery",
        "required_material_intel": 0.50,
        "tiers": [
            {"tier": 1, "effects": {"accuracy_pct": 0.15, "range_flat": 1}, "desc": "命中+15%, 射程+1"},
            {"tier": 2, "effects": {"accuracy_pct": 0.25, "range_flat": 1, "crit_bonus": 0.10}, "desc": "命中+25%, 射程+1, 暴击+10%", "required_material_intel": 0.75},
            {"tier": 3, "effects": {"accuracy_pct": 0.35, "range_flat": 2, "crit_bonus": 0.15, "precision_strike": true}, "desc": "命中+35%, 射程+2, 精确打击", "required_material_intel": 1.00},
        ],
        "compatible_combat_kinds": [2, 3],
        "slot_type": "enemy_origin",
    },
    # ─── 特殊敌人相关 ───
    "EOM_STEALTH_01": {
        "id": "EOM_STEALTH_01",
        "name": "光学迷彩涂层",
        "desc": "从隐形单位残骸中提取的光学伪装技术",
        "source_enemy_type": "stealth",
        "required_material_intel": 0.50,
        "tiers": [
            {"tier": 1, "effects": {"dodge_pct": 0.10, "enemy_accuracy_penalty": 0.05}, "desc": "闪避+10%, 敌人命中-5%"},
            {"tier": 2, "effects": {"dodge_pct": 0.18, "enemy_accuracy_penalty": 0.10, "first_strike_bonus": 0.20}, "desc": "闪避+18%, 敌人命中-10%, 先手+20%", "required_material_intel": 0.75},
            {"tier": 3, "effects": {"dodge_pct": 0.25, "enemy_accuracy_penalty": 0.15, "first_strike_bonus": 0.30, "cloak_deploy": true}, "desc": "闪避+25%, 部署隐身3秒", "required_material_intel": 1.00},
        ],
        "compatible_combat_kinds": [0],
        "slot_type": "enemy_origin",
    },
    "EOM_BOSS_NANO": {
        "id": "EOM_BOSS_NANO",
        "name": "纳米再生核心",
        "desc": "从纳米核心BOSS中提取的自修复技术",
        "source_enemy_type": "boss_nano",
        "required_material_intel": 0.75,  # BOSS级需要更高门槛
        "tiers": [
            {"tier": 1, "effects": {"hp_regen_pct": 0.03, "revive_chance": 0.05}, "desc": "每秒回复3%HP, 5%概率战斗中复活"},
            {"tier": 2, "effects": {"hp_regen_pct": 0.05, "revive_chance": 0.10, "nano_surge": true}, "desc": "每秒回复5%HP, 10%复活, 纳米脉冲", "required_material_intel": 0.90},
            {"tier": 3, "effects": {"hp_regen_pct": 0.08, "revive_chance": 0.15, "nano_surge": true, "resurrect_full": true}, "desc": "每秒回复8%HP, 15%满血复活, 纳米脉冲", "required_material_intel": 1.00},
        ],
        "compatible_combat_kinds": [0, 1, 2, 3],
        "slot_type": "enemy_origin",
    },
}
```

#### 3.2.3 敌源MOD槽位设计

每张卡拥有 **1个独立敌源MOD槽位**（不与现有A/B/C槽冲突）：

```
卡牌改造槽位布局:
┌──────────────────────────────────────┐
│  A槽(通用MOD)  B槽(通用MOD)  C槽(通用MOD)  🆕 D槽(敌源MOD)  │
│  现有系统                              新增系统                │
└──────────────────────────────────────┘
```

- D槽解锁条件：该卡素材情报总进度(对任何敌人均有的M维度) ≥ 30%
- D槽可随时更换已解锁的敌源MOD（不消耗资源）
- 敌源MOD的"等级"随素材情报自动提升（无需额外操作）

---

### 3.3 情报进化分支系统 (Intel-Driven Evolution Branches)

#### 3.3.1 核心概念

**隐藏进化路线**：只有当玩家拥有特定敌人的**秘密情报**达到阈值后，才会揭示新的进化分支。

这些分支不在 `UnitLineageConfig.LINEAGES` 的常规路线中，而是作为**情报发现奖励**动态添加。

#### 3.3.2 隐藏进化路线数据

```gdscript
## data/intel_evolution_branches.gd
class_name IntelEvolutionBranches

## 情报进化分支定义
## 每条分支由"情报钥匙"(多个敌人的秘密情报组合)解锁
const INTEL_BRANCHES: Dictionary = {
    # ─── 轻装线隐藏分支 ───
    "IB_INFANTRY_SPECIAL": {
        "branch_id": "IB_INFANTRY_SPECIAL",
        "name": "特种作战路线",
        "description": "结合步兵战术与隐匿技术的混合进化",
        "source_card_ids": ["ww1_mp18", "cold_ak47", "mod_marine"],
        "target_card_id": "fut_spectre",       # 目标卡（可以是现有卡的捷径）
        "intel_requirements": {
            # 需要同时满足多个敌人的秘密情报
            "infantry_elite": {"dimension": "secret", "threshold": 0.75},
            "stealth_boss":   {"dimension": "secret", "threshold": 0.50},
        },
        "unique_bonus": {
            "inherit_ratio": 0.45,              # 比正常0.30更高
            "extra_mod_slot": true,             # 进化后额外获得1个改造槽
            "special_ability": "tactical_cloak", # 解锁特殊能力
        },
        "cost_modifier": 1.3,                   # 消耗是正常的1.3倍（稀有路线）
        "is_hidden": true,                      # 未解锁时不可见
    },
    "IB_ARMOR_BREAKER": {
        "branch_id": "IB_ARMOR_BREAKER",
        "name": "破甲猎手路线",
        "description": "研究重装甲弱点的反坦克专家进化",
        "source_card_ids": ["ww2_panzerschrek", "cold_rpg", "mod_javelin"],
        "target_card_id": "fut_cyborg",
        "intel_requirements": {
            "heavy_armor_boss": {"dimension": "tactical", "threshold": 0.80},
            "heavy_armor_elite": {"dimension": "material", "threshold": 0.75},
        },
        "unique_bonus": {
            "inherit_ratio": 0.50,
            "special_ability": "armor_pierce_ult",
        },
        "cost_modifier": 1.2,
        "is_hidden": true,
    },
    # ─── 装甲线隐藏分支 ───
    "IB_ADAPTIVE_ARMOR": {
        "branch_id": "IB_ADAPTIVE_ARMOR",
        "name": "自适应装甲路线",
        "description": "融合纳米技术的主战坦克进化",
        "source_card_ids": ["ww2_pz3", "cold_t55", "mod_m1a1"],
        "target_card_id": "fut_heavy_mech",
        "intel_requirements": {
            "boss_nano":    {"dimension": "material", "threshold": 0.80},
            "flame_elite":  {"dimension": "secret", "threshold": 0.60},
        },
        "unique_bonus": {
            "inherit_ratio": 0.40,
            "extra_mod_slot": true,
            "special_ability": "adaptive_shield",
        },
        "cost_modifier": 1.4,
        "is_hidden": true,
    },
    # ─── 跨线隐藏分支（极稀有） ───
    "IB_CROSS_ARTILLERY_AIR": {
        "branch_id": "IB_CROSS_ARTILLERY_AIR",
        "name": "空中炮艇路线",
        "description": "将火炮装载到飞行平台的跨类型进化",
        "source_card_ids": ["mod_m270", "fut_howitzer"],
        "target_card_id": "fut_space_fighter",
        "intel_requirements": {
            "artillery_boss":  {"dimension": "secret", "threshold": 1.00},
            "air_boss":        {"dimension": "secret", "threshold": 0.75},
            "stealth_elite":   {"dimension": "tactical", "threshold": 0.80},
        },
        "unique_bonus": {
            "inherit_ratio": 0.55,
            "extra_mod_slot": true,
            "special_ability": "aerial_bombardment",
            "cross_class": true,    # 允许跨类型！
        },
        "cost_modifier": 1.8,       # 极高消耗
        "is_hidden": true,
    },
}
```

#### 3.3.3 情报进化分支的UI揭示流程

```
1. 玩家在情报中心查看某张卡的进化图谱
2. 图谱上显示已知路线(实线) + 已暗示的隐藏路线(虚线/锁图标)
3. 当满足情报条件时:
   - 闪烁提示："发现新的进化可能性！"
   - 虚线变实线 + 动画展开
   - 显示分支描述和额外奖励
4. 玩家确认后，该分支永久添加到该卡的进化选项中
```

---

### 3.4 战斗后掉落增强 (Enhanced Battle Drops)

#### 3.4.1 情报掉落重新设计

**现有问题**：情报只是在后台默默增加，玩家没有获得感。

**新设计**：战斗结算时，情报获取成为**掉落列表中最醒目的部分**。

#### 3.4.2 战斗结算界面重新布局

```
┌─────────────────────────────────────────────────┐
│              ⭐ 战斗胜利！ ⭐                     │
│            ★★★ 完美表现！                         │
├─────────────────────────────────────────────────┤
│ 📊 相位场经验  +120 XP  →  Level 15             │
├─────────────────────────────────────────────────┤
│                                                   │
│  ┌── 🆕 情报收获 ──────────────────────────┐     │
│  │                                          │     │
│  │  🔵 基础侦察  ██████████░░  80% (+12%)   │     │
│  │     → 揭示：完整属性数据已获取！         │     │
│  │                                          │     │
│  │  🟠 战术分析  ██████░░░░░  55% (+18%)   │     │
│  │     → 发现：攻击后1.5秒存在弱点窗口     │     │
│  │     🆕 解锁：战斗中对突击炮兵+25%伤害    │     │
│  │                                          │     │
│  │  🟢 素材研究  ████░░░░░░░  35% (+8%)    │     │
│  │                                          │     │
│  │  🟣 机密档案  █░░░░░░░░░░  10% (+3%)    │     │
│  │     → 暗示："……似乎与纳米核心有关……"    │     │
│  │                                          │     │
│  └──────────────────────────────────────────┘     │
│                                                   │
│  ┌── 材料掉落 ─────────────────────────────┐     │
│  │  🔩 纳米材料 ×35                         │     │
│  │  📄 蓝图碎片：突击炮兵 ×2                │     │
│  │  📖 法则知识：雷电系 ×4                   │     │
│  │  🏷️ 相位仪器掉落                          │     │
│  │  🆕 🧬 敌源MOD碎片：热能抗性 (15/50)     │     │
│  └──────────────────────────────────────────┘     │
│                                                   │
│  ┌── 🆕 揭示事件 ─────────────────────────┐     │
│  │  ⚔️ 战术分析·中级报告                    │     │
│  │  "通过多次交战，分析出突击炮兵在开火     │     │
│  │   后的1.5秒内防御显著降低，利用此窗口     │     │
│  │   可造成额外25%伤害。"                    │     │
│  └──────────────────────────────────────────┘     │
│                                                   │
│              [ 继续 ]                              │
└─────────────────────────────────────────────────┘
```

#### 3.4.3 掉落与情报的联动机制

| 情报进度 | 掉落变化 |
|----------|----------|
| 0-25% 基础情报 | 只掉落通用材料 |
| 25-50% 基础情报 | 开始掉落该敌人的蓝图碎片 |
| 50%+ 素材情报 | 开始掉落**敌源MOD碎片** |
| 75%+ 战术情报 | 掉落数量+30% |
| 100% 任意维度 | **掉落率整体+50%**（保留现有机制，增强感知） |
| 秘密情报50%+ | 小概率掉落**秘密配方碎片** |

---

## 四、文件修改与新增清单

### 4.1 新增文件

| 文件路径 | 描述 | 优先级 |
|----------|------|--------|
| `data/intel_dimensions.gd` | 情报维度定义（4维度+阈值+揭示事件表） | P0 |
| `data/intel_reveal_events.gd` | 所有揭示事件的详细定义（per敌人类型） | P0 |
| `data/enemy_origin_mods.gd` | 敌源MOD定义表（15-20种） | P0 |
| `data/intel_evolution_branches.gd` | 情报进化分支定义表 | P1 |
| `scripts/systems/intel_discovery_manager.gd` | 情报发现管理器（处理4维情报+揭示事件） | P0 |
| `scripts/systems/enemy_origin_mod_manager.gd` | 敌源MOD管理器（解锁/装备/升级逻辑） | P0 |
| `scripts/systems/intel_evolution_manager.gd` | 情报进化管理器（检查/解锁隐藏分支） | P1 |
| `scenes/ui/intel_harvest_display.gd` | 战斗结算中的情报收获展示组件 | P0 |
| `scenes/ui/intel_reveal_popup.gd` | 揭示事件弹窗动画 | P0 |
| `scenes/ui/enemy_origin_mod_slot_ui.gd` | 卡牌详情中的D槽敌源MOD UI | P0 |
| `scenes/ui/intel_evolution_branch_overlay.gd` | 进化图谱中的隐藏分支揭示UI | P1 |

### 4.2 修改文件

| 文件路径 | 修改内容 | 优先级 |
|----------|----------|--------|
| `scripts/systems/intel_manual.gd` | 扩展IntelEntry支持4维情报，修改_add_intel为分维度添加 | P0 |
| `managers/battle/battle_damage_system.gd` | 战斗结束时调用情报发现系统，生成情报维度掉落数据 | P0 |
| `scenes/ui/battle_result_dialog.gd` | 整合情报收获展示组件 + 揭示事件弹窗 | P0 |
| `scenes/ui/battle_result_panel.gd` | 同上（备用结算面板） | P0 |
| `scenes/ui/card_enhancement_panel.gd` | 添加D槽敌源MOD UI + 敌源MOD选择/装备逻辑 | P0 |
| `managers/evolution/card_evolution_manager.gd` | 进化选项查询时整合情报进化分支 | P1 |
| `scenes/ui/intelligence_hub_panel.gd` | 进化图谱Tab中集成隐藏分支揭示 | P1 |
| `scenes/ui/evolution_atlas_view.gd` | 支持隐藏分支的虚线显示 + 揭示动画 | P1 |
| `scenes/ui/unit_progression_detail_view.gd` | 详情中显示已解锁的情报进化分支 | P1 |
| `data/unit_lineage_config.gd` | 添加跨类型进化例外标记 | P1 |
| `managers/battle/battle_manager.gd` | 战斗结束信号中传递敌人类型列表（供情报系统使用） | P0 |

### 4.3 修改项目配置

| 文件路径 | 修改内容 |
|----------|----------|
| 项目Autoload列表 | 新增 `IntelDiscoveryManager`、`EnemyOriginModManager`、`IntelEvolutionManager` |
| `resources/game_constants.gd` | 新增敌源MOD相关常量 |

---

## 五、分阶段实现路线图

### Phase 1：情报维度 + 战斗结算UI（核心感知层）
**预计工作量**：3-4天
**目标**：让玩家在战斗后看到4维情报进度和揭示事件

1. 创建 `data/intel_dimensions.gd` + `data/intel_reveal_events.gd`
2. 修改 `intel_manual.gd`：IntelEntry扩展为4维度
3. 创建 `scripts/systems/intel_discovery_manager.gd`
4. 创建 `scenes/ui/intel_harvest_display.gd`（情报收获展示组件）
5. 创建 `scenes/ui/intel_reveal_popup.gd`（揭示事件弹窗）
6. 修改 `battle_damage_system.gd`：战斗结束时生成分维情报数据
7. 修改 `battle_result_dialog.gd` / `battle_result_panel.gd`：整合情报UI

### Phase 2：敌源MOD系统（差异化强化）
**预计工作量**：4-5天
**目标**：引入从特定敌人获取的专属MOD

1. 创建 `data/enemy_origin_mods.gd`（15种敌源MOD）
2. 创建 `scripts/systems/enemy_origin_mod_manager.gd`
3. 创建 `scenes/ui/enemy_origin_mod_slot_ui.gd`
4. 修改 `card_enhancement_panel.gd`：添加D槽UI
5. 修改 `battle_damage_system.gd`：情报足够时掉落敌源MOD碎片
6. 修改 `game_constants.gd`：D槽相关常量

### Phase 3：情报进化分支（隐藏路线）
**预计工作量**：3-4天
**目标**：情报组合解锁隐藏进化路线

1. 创建 `data/intel_evolution_branches.gd`
2. 创建 `scripts/systems/intel_evolution_manager.gd`
3. 修改 `card_evolution_manager.gd`：整合隐藏分支查询
4. 创建 `scenes/ui/intel_evolution_branch_overlay.gd`
5. 修改 `evolution_atlas_view.gd`：隐藏分支显示/揭示动画
6. 修改 `unit_progression_detail_view.gd`：详情中展示分支
7. 修改 `intelligence_hub_panel.gd`：进化图谱集成

### Phase 4：数据填充 + 平衡调优 + 存档兼容
**预计工作量**：2-3天
**目标**：填充完整数据，存档兼容迁移

1. 为所有60+敌人类型填写揭示事件
2. 扩展敌源MOD到20-25种
3. 设计8-12条情报进化分支
4. 存档迁移：旧存档中单一intel_progress → 4维度（按权重分配）
5. 新手引导更新：情报系统教学
6. 性能测试：4维情报查询性能

---

## 六、存档兼容方案

### 6.1 情报数据迁移

```gdscript
## 存档迁移逻辑（在IntelManual.load_data中执行）
func _migrate_legacy_intel(raw: Dictionary) -> Dictionary:
    var migrated: Dictionary = {}
    for card_id in raw:
        var data: Dictionary = raw[card_id]
        if data is Dictionary:
            if data.has("intel_progress") and not data.has("intel_dimensions"):
                ## 旧版存档：单一intel_progress → 4维度分配
                var old_progress: float = float(data.get("intel_progress", 0.0))
                data["intel_dimensions"] = {
                    "basic": clampf(old_progress * 1.1, 0.0, 1.0),      # 基础略高
                    "tactical": clampf(old_progress * 0.85, 0.0, 1.0),    # 战术略低
                    "material": clampf(old_progress * 0.75, 0.0, 1.0),   # 素材更低
                    "secret": clampf(old_progress * 0.3, 0.0, 1.0),       # 秘密最低
                }
                data["migrated"] = true
            migrated[card_id] = data
    return migrated
```

### 6.2 敌源MOD数据存储

```gdscript
## 在BlueprintManager中新增
var blueprint_enemy_origin_mod: Dictionary = {}  # card_id -> EOM_xxx ID
```

---

## 七、信号与事件流

### 7.1 新增信号

```gdscript
# IntelDiscoveryManager 信号
signal intel_dimension_changed(card_id, dimension, old_val, new_val)
signal intel_reveal_triggered(card_id, dimension, event_data)
signal intel_harvest_generated(harvest_data)    # 战斗结算情报数据

# EnemyOriginModManager 信号
signal enemy_origin_mod_unlocked(mod_id)
signal enemy_origin_mod_tier_upgraded(mod_id, old_tier, new_tier)
signal enemy_origin_mod_equipped(card_id, mod_id)
signal enemy_origin_mod_fragment_dropped(mod_id, amount, total)

# IntelEvolutionManager 信号
signal intel_branch_discovered(branch_id, branch_data)
signal intel_branch_available(card_id, branch_id)
signal intel_branch_claimed(card_id, branch_id)
```

### 7.2 完整事件流

```
战斗胜利
  ↓
BattleManager.end_battle()
  ↓
BattleDamageSystem.generate_battle_completion_drops()
  ├── 现有掉落逻辑（纳米材料、碎片、法则知识）
  ├── 🆕 IntelDiscoveryManager.generate_battle_intel_harvest()
  │     ├── 计算每个被击败敌人的4维情报增长
  │     ├── 检查是否触发揭示事件
  │     ├── 检查是否满足敌源MOD解锁条件
  │     └── 检查是否满足情报进化分支条件
  └── 🆕 EnemyOriginModManager.roll_enemy_origin_mod_fragments()
  ↓
BattleResultDialog.create()
  ├── 现有UI：胜负、星级、奖励
  ├── 🆕 IntelHarvestDisplay：4维情报进度条 + 增长动画
  ├── 🆕 IntelRevealPopup：揭示事件弹窗（如果有新揭示）
  └── 🆕 敌源MOD碎片显示（如果有掉落）
```

---

## 八、风险评估与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 存档迁移导致数据丢失 | 中 | 高 | 旧存档自动备份 + 详细迁移日志 + 单元测试 |
| 4维情报增加计算复杂度 | 低 | 中 | 情报查询批量处理 + 缓存机制 |
| 敌源MOD破坏现有战力平衡 | 高 | 高 | 初始敌源MOD效果保守，通过Phase 4调优 |
| 情报进化分支与现有路线冲突 | 中 | 中 | 分支目标卡ID与现有路线严格对齐，不创建新卡 |
| UI复杂度增加导致加载变慢 | 中 | 中 | 情报UI组件懒加载 + 对象池复用 |
