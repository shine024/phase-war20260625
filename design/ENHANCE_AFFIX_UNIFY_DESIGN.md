# 🎯 强化系统 v6.0 设计方案：强化 = 选择词条

> **提案日期**：2026-05-31
> **状态**：提案（待确认后执行）
> **前置版本**：设计文档 v5.0（强化=纯数值加成 + 词缀=RNG随机词条，两套系统并存）

---

## 一、设计动机

### 1.1 现有问题

| 问题 | 说明 |
|------|------|
| 强化体验无聊 | 每次强化只加"+5%全属性"，无玩家选择，无策略深度 |
| 两套系统混淆 | 强化(enhance_level)和词缀(affix)都修改HP/攻击，形成乘法膨胀 |
| 代码复杂 | 强化552处affix引用 + CardEnhancementManager + AffixManager，两个系统交叉 |
| 文档术语不一致 | 设计文档叫"模块化词条"，代码叫"affix"，设计文档又说"词缀已删除" |

### 1.2 设计目标

1. **每次强化都有意义** — "+5%"变"我选暴击还是吸血"，每次升级都有决策
2. **Build多样性** — 同一张MP18可以走暴击流/吸血流/溅射AOE流/坦克流
3. **减少系统数量** — 强化 + 词缀 合并为一个统一的"强化选词条"系统
4. **消除乘法膨胀** — 不再有"强化倍率×词条倍率"的双重叠乘

---

## 二、核心设计

### 2.1 一句话概括

> **强化 = 逐级选择词条，每次升级选择一个新词条或升级已有词条**

### 2.2 强化等级总览（Lv1-10）

| 等级 | 动作 | 词条池 | 说明 |
|------|------|--------|------|
| Lv1→2 | 🆕 **选择第1个词条** | 基础池（7个） | 初始词条，建立Build方向 |
| Lv2→3 | ⬆️ **升级已有词条** | — | Lv1→Lv2 |
| Lv3→4 | 🆕 **选择第2个词条** | 基础池（7个） | 丰富Build |
| Lv4→5 | ⬆️ **升级已有词条** | — | Lv1→Lv2 |
| Lv5→6 | 🆕 **选择第3个词条** | 基础池 + 进阶池（12个） | 解锁进阶词条 |
| Lv6→7 | ⬆️ **升级已有词条** | — | 含Lv3进阶词条升级 |
| Lv7→8 | 🆕 **选择第4个词条** | 基础池 + 进阶池（12个） | 继续完善 |
| Lv8→9 | ⬆️ **升级已有词条** | — | |
| Lv9→10 | 🆕 **选择第5个词条** + 🎁 **全属性+10%** | **全池解锁**（16个） | 终极词条 + 小额全属性奖励 |

**规律**：奇数级(Lv2/4/6/8/10) = 选新词条，偶数级(Lv3/5/7/9) = 升级词条
**最终**：Lv10 的卡牌拥有 **5个词条(最高Lv3)** + **+10%全属性**

### 2.3 词条升级规则

| 词条等级 | 所需强化等级 | 效果倍率 |
|---------|------------|---------|
| Lv1 | 初始获得 | 1.0× 基础值 |
| Lv2 | 升级1次 | 1.3× 基础值（+30%） |
| Lv3 | 升级2次 | 1.7× 基础值（+70%） |

**注**：旧系统的Lv1-5词条等级压缩为Lv1-3，因为强化只有10级，5个词条只能各升级2次（Lv1→Lv2→Lv3）

---

## 三、词条定义表（16个词条，统一为单轨）

### 3.1 基础池 — Lv2起可用（7个）

| 词条ID | 名称 | 效果 | 基础值(Lv1) | 最大值(Lv3) | 类型 |
|--------|------|------|------------|------------|------|
| `module_hp_up` | 铁甲强化 | HP +12% | +12% | +20.4% | 生存 |
| `module_dmg_up` | 穿透弹芯 | 攻击 +15% | +15% | +25.5% | 输出 |
| `module_def_up` | 纳米装甲 | 减伤 +8% | +8% | +13.6% | 生存 |
| `module_def_flat` | 复合装甲 | 防御 +2 | +2 | +3.4 | 生存 |
| `module_speed_up` | 疾行引擎 | 部署速度 +1 | +1 | +1.7 | 机动 |
| `module_range_up` | 延伸枪管 | 射程 +10% | +10% | +17% | 输出 |
| `module_atkspd_up` | 速射改装 | 攻击间隔 -10% | -10% | -17% | 输出 |

### 3.2 进阶池 — Lv6起可用（5个）

| 词条ID | 名称 | 效果 | 基础值(Lv1) | 最大值(Lv3) | 类型 |
|--------|------|------|------------|------------|------|
| `module_crit` | 精准打击 | 暴击率 +8% | +8% | +13.6% | 输出 |
| `module_lifesteal` | 汲能吸血 | 吸血 +5% | +5% | +8.5% | 生存 |
| `module_splash` | 爆裂弹头 | 溅射 +15% | +15% | +25.5% | 输出 |
| `module_penetration` | 穿甲射击 | 穿甲 +10% | +10% | +17% | 输出 |
| `module_regen` | 纳米自愈 | 每秒回复 0.3% HP | 0.3% | 0.51% | 生存 |

### 3.3 特殊池 — Lv10起可用（4个）

| 词条ID | 名称 | 效果 | 基础值(Lv1) | 最大值(Lv3) | 类型 |
|--------|------|------|------------|------------|------|
| `module_chain` | 链式放电 | 闪电链 +8% | +8% | +13.6% | 输出 |
| `module_shield_kill` | 歼灭护盾 | 击杀获 3% HP护盾 | 3% | 5.1% | 生存 |
| `module_dodge` | 相位闪避 | 闪避 +5% | +5% | +8.5% | 生存 |
| `module_crit_dmg` | 致命一击 | 暴击倍率 +0.2× | +0.2× | +0.34× | 输出 |

### 3.4 词条效果上限（防极端叠加）

| 效果 | 上限 | 说明 |
|------|------|------|
| 减伤(damage_reduction) | ≤ 60% | 多个减伤词条叠加后封顶 |
| 暴击率(crit_chance) | ≤ 60% | |
| 吸血(lifesteal) | ≤ 50% | |
| 溅射(splash_damage) | ≤ 60% | |
| 穿甲(armor_penetration) | ≤ 60% | |
| 闪电链(chain_chance) | ≤ 50% | |
| 闪避(dodge_chance) | ≤ 40% | |
| HP总加成 | ≤ 基础×3.0 | 含词条+进化+全属性奖励 |
| 攻击总加成 | ≤ 基础×3.0 | 含词条+进化+全属性奖励 |

---

## 四、与其他系统的关系

### 4.1 成长路径总览

```
新卡获得 → 强化选词条(10级) → 改造装MOD(最多9个) → 情报100% → 进化(转职)
                ↕                     ↕
         每次升级选词条          数值增益(MOD不改机制)
              ↕
     词条完全继承进化          改造完全继承进化
```

### 4.2 与改造(MOD)系统的区分

| 维度 | 强化-词条 | 改造-MOD |
|------|----------|----------|
| **效果类型** | 机制效果（暴击/吸血/溅射/闪避/护盾） | 数值增益（+15%攻击/+20%防御） |
| **选择方式** | 每级从池中选择 | 消耗研究点+许可，可替换 |
| **数量上限** | 5个词条(Lv10满) | 9个MOD |
| **升级方式** | 通过强化升级(Lv1→Lv2→Lv3) | 不可升级（替换即替换） |
| **进化继承** | 完全继承 | 完全继承 |
| **代码实现** | `ModuleSlotManager`（新，替代AffixManager） | `ModManager`（已有） |

### 4.3 能量卡和法则卡的处理（✅ 已确认：不强化）

**能量卡和法则卡不做任何强化**：

| 卡牌类型 | 强化 | 词条 | 改造 | 进化 |
|---------|------|------|------|------|
| 战斗单位卡 | ✅ 选词条（Lv1-10） | ✅ 5个词条槽 | ✅ 最多9个 | ✅ |
| 能量卡 | ❌ 不可强化 | ❌ 无词条 | ❌ 不可改造 | ❌ 不可进化 |
| 法则卡 | ❌ 不可强化 | ❌ 无词条 | ❌ 不可改造 | ❌ 不可进化 |

**理由**（已确认）：
- 能量卡和法则卡不参与战斗数值计算，词条的战斗机制（暴击/溅射等）无意义
- 能量卡提供的是能量回复/起始能量等固定功能，数值提升空间有限
- 法则卡的技能效果由 PhaseLawManager 管理，不应通过强化叠加
- 简化系统：只有战斗单位卡需要养成，降低玩家认知负担

**代码改动**：
- `CardEnhancementPanel` 中能量卡/法则卡点击强化按钮时提示"此卡牌无法强化"
- 移除能量卡/法则卡的 enhance_level 相关UI显示

---

## 五、强化消耗公式（保留v5.0不变）

```gdscript
# 单次强化消耗 = 基础战力 × 等级系数
# 总消耗（Lv1→10）= 基础战力 × 29

var enhance_costs = {
    1: 0.5,   # Lv0→1
    2: 1.0,   # Lv1→2  🆕 选第1个词条
    3: 1.5,   # Lv2→3  ⬆️ 升级词条
    4: 2.0,   # Lv3→4  🆕 选第2个词条
    5: 2.5,   # Lv4→5  ⬆️ 升级词条
    6: 3.0,   # Lv5→6  🆕 选第3个词条（进阶池解锁）
    7: 3.5,   # Lv6→7  ⬆️ 升级词条
    8: 4.0,   # Lv7→8  🆕 选第4个词条
    9: 5.0,   # Lv8→9  ⬆️ 升级词条
    10: 6.0,  # Lv9→10 🆕 选第5个词条（全池解锁）+ 🎁 +10%全属性
}
```

**消耗资源**：纳米材料（同v5.0）

---

## 六、词条重置机制

### 6.1 单个词条重置

- 玩家可以选择**重置单个词条**，恢复为空槽位
- 消耗纳米材料（按词条等级递增）
- 重置后可以重新从当前解锁池中选择

### 6.2 全部重置

- 一次重置所有词条，恢复为初始状态
- 消耗纳米材料（总消耗 = 单个重置之和 × 0.7 折扣）
- 强化等级不变（Lv10还是Lv10，只是词条槽位清空可重选）

### 6.3 重置消耗表

| 词条等级 | 单个重置(纳米) |
|---------|--------------|
| Lv1 | 基础战力 × 0.5 |
| Lv2 | 基础战力 × 1.0 |
| Lv3 | 基础战力 × 2.0 |

---

## 七、UI设计概要

### 7.1 强化面板布局

```
┌──────────────────────────────────────────────────┐
│  📋 卡牌名称（Lv.X / 10）        ⚡ 基础战力 XXX │
│                                                    │
│  ── 词条槽位 ──────────────────────────────────  │
│                                                    │
│  [🟢 铁甲强化 Lv2]  [🟢 穿透弹芯 Lv3]  [🟢 精准打击 Lv1] │
│  [⬜ 空]            [🔒 未解锁(Lv10)]             │
│                                                    │
│  ── 属性预览 ──────────────────────────────────  │
│  HP:    800 → 1,056  (+32%)  [词条HP +20.4%]    │
│  攻击:  120 →  186  (+55%)  [词条ATK +25.5% + 暴击] │
│  减伤:    0 →  13.6%         [词条DEF +13.6%]   │
│  暴击:    0 →  13.6%         [词条暴击 +13.6%]  │
│                                                    │
│  ════════════════════════════════════════════════  │
│  🔄 升级词条      🆕 选新词条      🔙 重置词条    │
│                                                    │
│  消耗: 💎 纳米 1,500                              │
│  [          强化升级          ]                      │
└──────────────────────────────────────────────────┘
```

### 7.2 选词条弹窗

```
┌──────────────────────────────────────┐
│  选择一个词条                         │
│                                       │
│  📊 属性方向   🎯 战斗机制              │
│  ┌──────────┐ ┌──────────┐            │
│  │ 🛡️ 铁甲强化│ │ ⚔️ 精准打击│            │
│  │ HP +20.4% │ │ 暴击 +13.6%│          │
│  └──────────┘ └──────────┘            │
│  ┌──────────┐ ┌──────────┐            │
│  │ 💥 穿透弹芯│ │ 🩸 汲能吸血│            │
│  │ ATK +25.5%│ │ HP回复 8.5%│          │
│  └──────────┘ └──────────┘            │
│  ┌──────────┐ ┌──────────┐            │
│  │ 🛡️ 纳米装甲│ │ 💥 爆裂弹头│            │
│  │ 减伤 +13.6%│ │ 溅射 +25.5%│          │
│  └──────────┘ └──────────┘            │
│                                       │
│  🔒 进阶词条 (Lv6解锁)                │
│  🔒 特殊词条 (Lv10解锁)               │
│                                       │
│        [确认选择]                      │
└──────────────────────────────────────┘
```

---

## 八、战斗效果接入

### 8.1 新的 UnitStats 字段

```gdscript
# UnitStats 中需要支持的词条效果字段（与现有字段合并）
var crit_chance: float = 0.0        # 暴击率
var crit_damage_bonus: float = 0.0  # 暴击伤害倍率（加在1.5×基础上）
var lifesteal: float = 0.0          # 吸血比例
var splash_damage: float = 0.0       # 溅射比例
var armor_penetration: float = 0.0   # 穿甲比例
var chain_chance: float = 0.0       # 闪电链概率
var shield_on_kill: float = 0.0      # 击杀护盾(% HP)
var hp_regen: float = 0.0            # 每秒HP回复(%)
var dodge_chance: float = 0.0        # 闪避率
var damage_reduction: float = 0.0    # 减伤比例
```

### 8.2 战斗触发点

| 触发时机 | 处理词条 | 处理逻辑 |
|---------|---------|---------|
| 弹道命中 | crit_chance, crit_dmg_up | 暴击判定 → 伤害 ×1.5+bonus |
| 弹道命中 | lifesteal | 造成伤害后回复 HP |
| 弹道命中 | splash_damage | 对周围敌人溅射 |
| 弹道命中 | armor_penetration | 降低目标防御 |
| 弹道命中后 | chain_chance | 闪电链到附近敌人 |
| 敌人死亡 | shield_on_kill | 给自己加护盾 |
| 持续 | hp_regen | 每秒回复HP |
| 受击时 | dodge_chance | 闪避判定 |
| 受击时 | damage_reduction | 减伤计算 |

### 8.3 统一的词条效果应用器

替换旧的 `AffixCombatHandler` 为新的 `ModuleEffectHandler`：

```gdscript
class_name ModuleEffectHandler
## 统一词条效果处理器（替代 AffixCombatHandler）
## 在战斗中按触发点调用

static func on_bullet_hit(attacker: Node, target: Node, base_damage: int) -> int:
    var stats: UnitStats = attacker.get("stats")
    if not stats:
        return base_damage
    var final_damage := base_damage

    # 1. 穿甲
    final_damage = _apply_penetration(final_damage, stats)

    # 2. 暴击
    final_damage = _apply_crit(final_damage, stats)

    # 3. 减伤（目标侧）
    final_damage = _apply_target_reduction(final_damage, target)

    # 4. 闪避（目标侧）
    if _check_dodge(target):
        return 0

    # 5. 吸血
    _apply_lifesteal(attacker, final_damage, stats)

    # 6. 溅射
    _apply_splash(attacker, target, final_damage, stats)

    # 7. 闪电链
    _apply_chain(attacker, target, final_damage, stats)

    return final_damage

static func on_kill(attacker: Node, stats: UnitStats):
    if stats.shield_on_kill > 0.0:
        var shield_amount = attacker.max_hp * stats.shield_on_kill
        attacker.add_shield(shield_amount)
```

---

## 九、数据结构

### 9.1 ModuleSlot 数据结构（替代 AffixResource）

```gdscript
class_name ModuleSlot
## 词条槽位（替代 AffixResource）

var module_id: String = ""      # 词条ID（如 "module_crit"）
var module_name: String = ""   # 显示名（如 "精准打击"）
var level: int = 1             # 词条等级 1-3
var slot_index: int = 0        # 槽位编号 0-4

## 计算当前效果值
func get_effect_value() -> float:
    var base: float = ModuleDefinitions.get_base_value(module_id)
    var factor := 1.0
    match level:
        1: factor = 1.0
        2: factor = 1.3
        3: factor = 1.7
    return base * factor

## 获取效果描述
func get_effect_description() -> String:
    return ModuleDefinitions.get_effect_description(module_id, level)
```

### 9.2 CardResource 中的词条字段

```gdscript
# CardResource 中的字段（替代旧的 affix_slot_ids / affix_slot_count）
@export var module_slots: Array[ModuleSlot] = []  # 最多5个词条槽
```

### 9.3 CardEnhancementManager 数据结构

```gdscript
# CardEnhancementManager 中管理的强化数据
var card_enhancement_level: Dictionary = {}  # { card_id: int (1-10) }
var card_module_slots: Dictionary = {}       # { card_id: Array[ModuleSlot] }
```

---

## 十、存档迁移方案

### 10.1 旧存档 → 新存档映射

```gdscript
# 旧字段                              → 新字段
card.enhance_level (0-10)            → card.enhance_level (0-10，不变)
card.affix_slot_ids: Array             → card.module_slots: Array[ModuleSlot]
card.affix_slot_count: int            → card.module_slots.size()
# AffixManager._card_affixes Dict      → CardEnhancementManager.card_module_slots Dict
```

### 10.2 迁移逻辑

```gdscript
func migrate_save_data(save_data: Dictionary) -> Dictionary:
    for card_data in save_data.get("cards", []):
        # 1. 转换 affix_slot_ids → module_slots
        if card_data.has("affix_slot_ids"):
            var old_ids: Array = card_data["affix_slot_ids"]
            var new_slots: Array = []
            for i in old_ids.size():
                var old_affix = AffixResource.from_dict(old_ids[i])
                var new_slot = ModuleSlot.new()
                new_slot.module_id = "module_" + old_affix.affix_id.replace("platform_", "hp_").replace("weapon_", "dmg_")
                new_slot.level = mini(old_affix.level, 3)  # 旧Lv5→新Lv3
                new_slot.slot_index = i
                new_slots.append(new_slot)
            card_data["module_slots"] = new_slots
            card_data.erase("affix_slot_ids")
            card_data.erase("affix_slot_count")

        # 2. 星级相关字段清理
        if card_data.has("star_level"):
            card_data.erase("star_level")

    # 3. AffixManager → CardEnhancementManager 迁移
    if save_data.has("affix_data"):
        save_data["module_data"] = migrate_affix_to_module(save_data["affix_data"])
        save_data.erase("affix_data")

    return save_data
```

---

## 十一、与v5.0的对比

### 11.1 系统变化

| 维度 | v5.0 | v6.0（本方案） |
|------|------|---------------|
| 系统数量 | 2个（强化 + 词缀） | 1个（强化=选词条） |
| 强化体验 | 按一下"+5%全属性" | 每次选词条，有策略 |
| 词条数量 | 16个词条 × 5级 × 4稀有度 = 320种组合 | 16个词条 × 3级 = 48种组合 |
| 词条获得 | RNG随机（重铸/锁定） | 玩家主动选择（重置可改） |
| 代码引用 | 552处affix + N处enhancement | 仅enhancement引用 |
| 管理器 | AffixManager(643行) + CardEnhancementManager | CardEnhancementManager（合并） |
| 战斗处理器 | AffixCombatHandler(340行) | ModuleEffectHandler（新建，~200行） |

### 11.2 数值平衡对比

**v5.0 极端案例**：Legendary Lv5 `weapon_dmg_up` = 0.15 × 2.2 × 2.5 = **+82.5%攻击**
加上Lv10强化倍率 ×1.93 = 总攻击 **×3.54**

**v6.0 满配案例**：Lv3 `module_dmg_up` = 0.15 × 1.7 = **+25.5%攻击**
加上Lv10全属性+10% = 总攻击 **×1.38**
如果叠加MOD_01火力改造+15% = 总攻击 **×1.59**

**结论**：v6.0的数值膨胀显著降低，更容易平衡。

---

## 十二、详细修订项目计划

### Phase 1：数据层（预估2天）

#### 任务 1.1：新建 `data/module_definitions.gd` ⏱️ 4h

**内容**：
- 定义16个词条的静态数据（ID、名称、效果key、基础值、池层级、效果上限）
- 词条效果应用方法（`apply_module_to_stats(stats, module_id, level)`）
- 池层级查询方法（`get_available_modules(enhance_level)`）
- 效果上限检查方法（`check_cap(effect_key, current_value)`）

**数据定义**：
```gdscript
const MODULE_TABLE: Dictionary = {
    # ── 基础池（Lv2起可用）──
    "module_hp_up": {
        "name": "铁甲强化", "category": "survival",
        "effect_key": "max_hp", "base_value": 0.12,
        "pool_tier": 0, "cap_key": "hp_total_mult", "cap_value": 3.0,
    },
    "module_dmg_up": {
        "name": "穿透弹芯", "category": "damage",
        "effect_key": "attack_damage", "base_value": 0.15,
        "pool_tier": 0, "cap_key": "dmg_total_mult", "cap_value": 3.0,
    },
    # ... 其余14个词条
}
```

#### 任务 1.2：新建 `resources/module_slot.gd` ⏱️ 2h

**内容**：
- ModuleSlot 类定义（替代 AffixResource）
- `get_effect_value()`、`get_effect_description()` 方法
- 序列化/反序列化（`to_dict()` / `from_dict()`）

#### 任务 1.3：修改 `resources/card_resource.gd` ⏱️ 2h

**改动**：
```gdscript
# 新增
@export var module_slots: Array[ModuleSlot] = []

# 标记废弃（保留兼容）
# @export var affix_slot_ids: Array = []     # [DEPRECATED v6.0]
# @export var affix_slot_count: int = 4       # [DEPRECATED v6.0]

# duplicate() 中添加 module_slots 复制逻辑
```

#### 任务 1.4：修改 `resources/unit_stats.gd` ⏱️ 1h

**改动**：
- 确认以下字段存在且正确：`crit_chance`, `crit_damage_bonus`, `lifesteal`, `splash_damage`, `armor_penetration`, `chain_chance`, `shield_on_kill`, `hp_regen`, `dodge_chance`, `damage_reduction`
- 新增缺失字段（当前 `dodge_chance`, `crit_damage_bonus`, `defense` flat 在 apply_affixes 中未实现，需补全）

#### 任务 1.5：修改 `data/affix_definitions.gd` → 标记废弃 ⏱️ 1h

**改动**：
- 文件顶部添加 `[DEPRECATED v6.0 — 被 module_definitions.gd 替代]`
- 保留文件但不再被新代码引用

---

### Phase 2：逻辑层（预估4天）

#### 任务 2.1：修改 `managers/card_enhancement_manager.gd` ⏱️ 8h

**核心改动**：

1. **强化升级逻辑重写**：
```gdscript
# 旧：enhance_level++ → attribute_bonus +5%~+60%
# 新：enhance_level++ → 选词条或升级词条

func enhance_card(card_id: String) -> Dictionary:
    var level := get_enhance_level(card_id)
    if level >= 10:
        return {"ok": false, "reason": "max_level"}

    var cost := calculate_enhance_cost(card_id, level + 1)
    if not BasicResourceManager.can_afford("nano_materials", cost):
        return {"ok": false, "reason": "insufficient_resources"}

    BasicResourceManager.consume("nano_materials", cost)
    level += 1
    set_enhance_level(card_id, level)

    # 奇数级(Lv2/4/6/8/10) = 获得新词条槽
    if _is_new_slot_level(level):
        return {"ok": true, "action": "choose_module", "level": level}
    # 偶数级(Lv3/5/7/9) = 升级已有词条
    else:
        return {"ok": true, "action": "upgrade_module", "level": level}

func apply_module_choice(card_id: String, module_id: String, slot_index: int) -> bool:
    var slots := get_module_slots(card_id)
    if slot_index >= slots.size():
        slots.resize(slot_index + 1)
    var slot := ModuleSlot.new()
    slot.module_id = module_id
    slot.level = 1
    slot.slot_index = slot_index
    slots[slot_index] = slot
    set_module_slots(card_id, slots)
    return true

func upgrade_module(card_id: String, slot_index: int) -> bool:
    var slots := get_module_slots(card_id)
    if slot_index >= slots.size() or slots[slot_index].level >= 3:
        return false
    slots[slot_index].level += 1
    set_module_slots(card_id, slots)
    return true
```

2. **统计接口**：
```gdscript
func get_card_effective_stats(card_id: String) -> Dictionary:
    # 计算词条效果总值 + 全属性奖励（Lv10）
    var result := {
        "hp_mult": 1.0, "dmg_mult": 1.0,
        "crit_chance": 0.0, "lifesteal": 0.0,
        # ... 所有词条效果
    }
    var level := get_enhance_level(card_id)
    if level >= 10:
        result.hp_mult += 0.10
        result.dmg_mult += 0.10
    for slot in get_module_slots(card_id):
        var value := slot.get_effect_value()
        # 按 effect_key 累加/乘加到 result
    return result
```

#### 任务 2.2：新建 `scripts/battle/module_effect_handler.gd` ⏱️ 6h

**替代** `managers/affix_combat_handler.gd`

**内容**：
- `on_bullet_hit()` — 弹道命中时处理暴击、穿甲、闪避、吸血、溅射、闪电链
- `on_kill()` — 击杀时处理护盾
- `on_tick()` — 持续效果（HP回复）
- `on_damage_taken()` — 受击时处理闪避、减伤
- 所有效果值从 UnitStats 读取（由 CardEnhancementManager 计算）

#### 任务 2.3：修改 `scripts/battle/` 中的调用点 ⏱️ 4h

**改动文件**：
- `scenes/units/bullet.gd` — L367 `AffixCombatHandler.calculate_damage()` → `ModuleEffectHandler.on_bullet_hit()`
- `managers/battle/battle_damage_system.gd` — L219 击杀护盾 → `ModuleEffectHandler.on_kill()`
- `scenes/units/construct_unit.gd` — L1069 平台HP变异 → `ModuleEffectHandler.on_tick()`
- `scenes/units/enemy_unit.gd` — HP回复 → `ModuleEffectHandler.on_tick()`

#### 任务 2.4：修改 `managers/evolution/evolution_helpers.gd` ⏱️ 2h

**改动**：
- `apply_growth_to_stats()` 中接入 ModuleDefinitions 的效果应用
- 替换旧的 `AffixManager.apply_affixes_to_stats()` 调用

---

### Phase 3：UI层（预估3天）

#### 任务 3.1：修改 `scenes/ui/card_enhancement_panel.gd` ⏱️ 12h

**核心改动**：

1. 强化面板改为"选词条"流程：
   - Lv2/4/6/8/10 → 弹出词条选择弹窗
   - Lv3/5/7/9 → 弹出升级选择弹窗
   - 显示当前5个词条槽（已装备/空/未解锁）

2. 新建词条选择弹窗 `ModuleSelectPopup.tscn`：
   - 显示当前解锁池中所有可用词条
   - 每个词条显示名称、效果值、简要说明
   - 点击选择后确认

3. 词条预览面板：
   - 显示已选词条的详细效果
   - 显示属性变化预览（HP/攻击/防御变化量）

#### 任务 3.2：标记废弃 UI ⏱️ 1h

**改动文件**：
- `scenes/ui/affix_panel.gd` → 添加 `[DEPRECATED v6.0]` 标记
- 不再从主界面入口进入旧词缀面板

#### 任务 3.3：修改卡牌详情UI ⏱️ 4h

**改动**：
- 在卡牌详情/预览中显示词条槽和效果
- 替换旧的星级显示为强化等级+词条数（如"Lv7 🔵🔵🔵⬜⬜"）
- 属性预览中标注词条贡献值

---

### Phase 4：清理层（预估2天）

#### 任务 4.1：标记 AffixManager 为废弃 ⏱️ 2h

**改动**：
- `managers/affix_manager.gd` → 顶部添加 `[DEPRECATED v6.0 — 被 CardEnhancementManager 替代]`
- 保留文件但注释所有外部调用入口
- `managers/affix_combat_handler.gd` → 同上

#### 任务 4.2：清理旧引用 ⏱️ 4h

**改动**：
- 全项目搜索 `affix_slot_ids`、`affix_slot_count` → 替换为 `module_slots`
- 全项目搜索 `AffixCombatHandler` → 替换为 `ModuleEffectHandler`
- 全项目搜索 `AffixManager` → 替换为 `CardEnhancementManager`（词条相关调用）
- 从 `drop_manager.gd` 移除词缀掉落逻辑

#### 任务 4.3：存档迁移 ⏱️ 4h

**改动**：
- `managers/save_manager.gd` 中新增 `migrate_v5_to_v6()` 方法
- 读取旧存档中的 `affix_slot_ids` → 转换为 `module_slots`
- `star_level` 字段清除
- `blueprint_stars/copies` 数据清除

#### 任务 4.4：更新设计文档 ⏱️ 2h

**改动**：
- 更新《相位战争》完整设计文档 v5.0 → v6.0
- 第九章"强化系统"重写为本方案的词条选择系统
- 删除"模块化词条"独立章节（已合并到强化系统）
- 更新《相位战争》关键设计决策汇总.md

---

### Phase 5：测试与验证（预估2天）

#### 任务 5.1：冒烟测试 ⏱️ 4h

**测试清单**：
- [ ] 启动游戏不崩溃
- [ ] 强化一张战斗卡到Lv10，每级都能选择词条
- [ ] 词条效果在战斗中正确生效（暴击/吸血/溅射/闪避）
- [ ] 进化后词条完全继承
- [ ] 旧存档加载不崩溃
- [ ] 能量卡/法则卡强化仍为简单模式

#### 任务 5.2：数值平衡检查 ⏱️ 4h

**检查项**：
- [ ] Lv10满配词条 + 3个MOD 的总攻击倍率 ≤ 3.0
- [ ] 减伤上限60%正确生效
- [ ] 暴击率上限60%正确生效
- [ ] 不同Build（暴击流/坦克流/吸血流）战力差异在合理范围

#### 任务 5.3：GdUnit 自动化测试 ⏱️ 4h

**新增测试**：
- `test_module_definitions_complete()` — 16个词条定义完整
- `test_module_effect_values()` — Lv1/2/3效果值正确
- `test_module_pool_tiers()` — 解锁层级正确
- `test_enhance_level_module_slots()` — 每级获得/升级正确
- `test_save_migration()` — 旧存档转换不丢数据

---

## 十三、工作量汇总

| Phase | 任务数 | 预估时间 | 前置条件 |
|-------|--------|---------|---------|
| Phase 1: 数据层 | 5 | 2天 | 无 |
| Phase 2: 逻辑层 | 4 | 4天 | Phase 1 |
| Phase 3: UI层 | 3 | 3天 | Phase 2 |
| Phase 4: 清理层 | 4 | 2天 | Phase 3 |
| Phase 5: 测试 | 3 | 2天 | Phase 4 |
| **合计** | **19** | **~13天** | |

### 关键里程碑

| 日期 | 里程碑 | 交付物 |
|------|--------|--------|
| Day 2 | 数据层完成 | `module_definitions.gd` + `module_slot.gd` |
| Day 6 | 逻辑层完成 | `card_enhancement_manager.gd` 改造 + `module_effect_handler.gd` |
| Day 9 | UI层完成 | 词条选择弹窗 + 强化面板改造 |
| Day 11 | 清理层完成 | AffixManager 废弃 + 存档迁移 |
| Day 13 | 测试通过 | 全流程冒烟 + 数值平衡 + 自动化测试 |

---

## 十四、风险与缓解

| 风险 | 等级 | 缓解措施 |
|------|------|---------|
| 存档迁移丢失数据 | 🔴 高 | Phase 4.3 专门处理，迁移后保留旧字段（不删除，只标记DEPRECATED） |
| 词条数值不平衡 | 🟡 中 | Phase 5.2 数值平衡检查 + 所有词条有上限封顶 |
| UI改造工作量大 | 🟡 中 | 可分阶段：先最小可用（文字弹窗），后美化（图标/动画） |
| 552处affix引用清理遗漏 | 🟡 中 | Phase 4.2 全项目搜索 + 编译警告兜底 |
| 与改造(MOD)系统冲突 | 🟢 低 | 词条=机制效果，MOD=数值增益，两者完全不重叠 |
| 能量卡/法则卡强化移除后玩家体验变化 | 🟢 低 | 能量卡/法则卡本身数值固定，强化收益有限，移除影响极小 |

---

> **提案版本**：v1.0
> **提案日期**：2026-05-31
> **确认日期**：2026-05-31
> **状态**：✅ 已确认，待执行
> **预计完成**：2026-06-13
>
> **决策确认记录**：
> 1. ✅ 词条池分层解锁方案 — **接受**
> 2. ✅ 词条上限（HP×3.0/攻击×3.0）— **合适**
> 3. ✅ 能量卡和法则卡 — **不强化**（移除能量卡/法则卡的强化功能）
>
> **补充说明**：能量卡/法则卡完全不强化，移除相关UI入口和代码逻辑。
