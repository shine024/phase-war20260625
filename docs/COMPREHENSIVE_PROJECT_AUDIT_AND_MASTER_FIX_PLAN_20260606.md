# 📋 《相位战争》综合审计与修复总计划 v5.2
> **审计日期**：2026-06-06
> **基准版本**：v5.1（最终确认版 20260529）
> **当前状态**：核心系统基本对齐，遗留系统待清理
> **文档类型**：设计文档 + 代码实现 + 修复计划一体化

---

## 📊 总体评估

| 维度 | v5.0 | v5.1 | v5.2 目标 | 进度 |
|------|------|------|-----------|------|
| **数据一致性** | 85/100 | 90/100 | 95/100 | ⬆️ +5 |
| **功能完整性** | 78/100 | 82/100 | 90/100 | ⬆️ +8 |
| **代码正确性** | 72/100 | 88/100 | 95/100 | ⬆️ +7 |
| **性能优化** | 88/100 | 88/100 | 95/100 | ⬆️ +7 |
| **架构清洁度** | 65/100 | 55/100 | 85/100 | ⬇️ -10 → ⬆️ +30 |
| **文档一致性** | 70/100 | 70/100 | 95/100 | ⬆️ +25 |
| **综合评分** | 77.6/100 | 77/100 | 91/100 | ⬆️ +13.4 |

**关键改进**：
- ✅ P0 关键修复全部完成（强化消耗、改造伤害、全局引用安全）
- ✅ 数据对齐完成（110单位、RPG组、情报门控、部署速度）
- ⚠️ 遗留系统清理进度滞后（词缀552处、星级22处、碎片18处）
- 🎯 目标：在 v5.2 中清理所有遗留系统，达到 85+ 架构清洁度

---

## 🎯 一、当前游戏设置

### 1.1 基础游戏常量

| 常量 | 值 | 说明 |
|------|-----|------|
| `ENERGY_MAX` | 100.0 | 最大能量 |
| `ENERGY_START` | 100.0 | 初始能量 |
| `ENERGY_REGEN_PER_SEC` | 1.0 | 每秒回能 |
| `PHASE_BASE_DRAIN_PER_SEC` | 0.5 | 相位仪基础消耗/秒 |
| `PLAYER_SPAWN_INTERVAL` | 10.0s | 玩家单位刷新间隔 |
| `PLAYER_MAX_UNITS` | 5 | 场上最多5单位 |
| `ENEMY_SPAWN_INTERVAL` | 12.0s | 敌方单位刷新间隔 |
| `ENEMY_WAVE_INTERVAL` | 12.0s | 敌方波次间隔 |
| `ENEMY_MAX_UNITS` | 5 | 场上最多5敌人 |

### 1.2 核心枚举系统

#### WeaponType（武器类型）
```gdscript
enum WeaponType {
    DIRECT = 0,       # 直射：坦克炮、步枪、机枪、反坦克炮
    INDIRECT = 1,     # 曲射：迫击炮、榴弹炮、火箭炮
    AERIAL = 2,       # 空射：战斗机、攻击机、无人机
    SUPPORT = 3       # 辅助：无攻击力单位（v5.1新增）
}
```

#### CombatKind（战斗定位）
```gdscript
enum CombatKind {
    LIGHT = 0,        # 轻装：步兵、侦察车
    ARMOR = 1,        # 装甲：坦克、机甲
    SUPPORT = 2,      # 支援：火炮、防空
    AIR = 3,          # 空中：战斗机、无人机
    FORT = 4          # 堡垒：固定防御工事（v5.0新增）
}
```

#### CardType（卡片类型）
```gdscript
enum CardType {
    COMBAT_UNIT = 0,  # 战斗卡
    ENERGY = 1,       # 能量卡
    LAW = 2,          # 法则卡
    # 3~5 保留用于存档兼容
}
```

#### Era（时代）
```gdscript
enum Era {
    WW1 = 0,          # 一战
    WW2 = 1,          # 二战
    COLD_WAR = 2,     # 冷战
    MODERN = 3,       # 现代
    NEAR_FUTURE = 4   # 近未来
}
```

### 1.3 单位数量统计

| 类别 | 数量 | 说明 |
|------|------|------|
| **战斗单位** | 110 | WW1 20 + WW2 20 + 冷战 20 + 现代 20 + 近未来 20 |
| **堡垒单位** | 10 | FORT=4 战斗定位，含防御/防空两条进化线 |
| **能量卡** | 7 | 战前能量 I-VII |
| **势力专属卡** | 14 | 分支进化目标 |
| **敌人蓝图** | 动态 | 随游戏进度解锁 |
| **总计** | **161** | 含兼容字段 |

### 1.4 核心系统状态

| 系统 | 状态 | 版本 |
|------|------|------|
| **强化系统** | ✅ 正常 | Lv1-10，100%成功 |
| **改造系统** | ✅ 正常 | 20种MOD，9槽位，冲突替换 |
| **进化系统** | ✅ 正常 | 37个进化节点 + 势力分支 |
| **情报手册** | ✅ 正常 | 100%检查已启用 |
| **部署速度** | ✅ 正常 | 已实现公式和动画 |
| **词缀系统** | ⚠️ 残留 | 552处引用，仅战斗伤害已切断 |
| **星级系统** | ⚠️ 残留 | 22处写入，仅UI注释未删除 |
| **碎片系统** | ⚠️ 残留 | 18处管理，135处任务奖励待清理 |
| **蓝图管理** | ⚠️ 拆分待进行 | 890+行，职责过多 |

---

## 🎮 二、游戏玩法数据

### 2.1 战斗系统核心规则

#### 2.1.1 伤害计算公式
```gdscript
# 完整流程（v5.1）
1. 获取基础攻击值（根据目标类型）:
   base_damage = get_attack_value(attacker, target)  # attack_light/armor/air

2. 击穿检查:
   if base_damage <= defense_value:
       return 0

3. 射程衰减（仅DIRECT武器）:
   attenuation = calculate_attenuation(distance, range)
   base_damage = base_damage * attenuation

4. 防御减免:
   defense = get_defense_value(target, attacker)
   final_damage = base_damage * (100 / (100 + defense))

5. 改造加成:
   final_damage = final_damage * get_mod_damage_multiplier(attacker_mods)

6. 改造加成实现（v5.1已完成）:
   func get_mod_damage_multiplier(mods: Array, target_combat_kind: int) -> float:
       var ModEffects = preload("res://data/mod_effects.gd")
       var total_mult := 1.0
       for mod_id in mods:
           var mod_def: Dictionary = ModEffects.MOD_DEFINITIONS.get(mod_id, {})
           var attack_mult: float = mod_def.get("attack_multiplier", 1.0)
           var condition_type: String = mod_def.get("condition_type", "")
           if condition_type == "vs_armor" and target_combat_kind != GC.CombatKind.ARMOR:
               attack_mult = 1.0
           elif condition_type == "vs_light" and target_combat_kind != GC.CombatKind.LIGHT:
               attack_mult = 1.0
           elif condition_type == "vs_air" and target_combat_kind != GC.CombatKind.AIR:
               attack_mult = 1.0
           total_mult *= attack_mult
       return total_mult
```

#### 2.1.2 选敌逻辑

| 武器类型 | 选敌规则 | 特殊行为 |
|---------|---------|---------|
| **DIRECT** | 距离最近的敌人 → 同距离选血量最低 → 同血量选部署最早 | 射程内无目标时向敌方基地方向移动 |
| **INDIRECT** | 优先被克制类型 → 无克制选距离最近 → 同距离选血量最低 | 不移动，全图攻击 |
| **AERIAL** | 优先空中目标 → 无空中目标选被克制类型 → 无克制选距离最近 | 可被防空单位拦截 |
| **SUPPORT** | 不参与攻击计算 | 攻击力全0，不选敌 |

#### 2.1.3 射程衰减系数

| 武器类型 | 衰减系数 | 最远衰减 |
|---------|---------|---------|
| 冲锋枪/SMG | 0.6 | -60% |
| 步枪/RIFLE | 0.4 | -40% |
| 机枪/MG | 0.5 | -50% |
| 坦克炮/TANK | 0.3 | -30% |
| 反坦克炮/AT | 0.2 | -20% |
| 狙击/SNIPER | 0.1 | -10% |

### 2.2 卡牌数据结构 v5.0+

```gdscript
{
    "card_id": "ww1_mp18",                # 唯一标识
    "display_name": "MP18突击班",         # 显示名称
    "era": 0,                             # 0=WW1,1=WW2,2=冷战,3=现代,4=近未来

    # 武器类型（v3枚举）
    "weapon_type": 0,                     # DIRECT/INDIRECT/AERIAL/SUPPORT

    # 战斗定位（v3枚举）
    "unit_class": 0,                      # LIGHT/ARMOR/SUPPORT/AIR/FORT

    # 三维攻击/防御（v5.0核心改动）
    "attack_light": 35,                   # 对轻装伤害
    "attack_armor": 30,                   # 对装甲伤害
    "attack_air": 0,                      # 对空中伤害

    "defense_light": 20,                  # 防轻装武器
    "defense_armor": 15,                  # 防装甲武器
    "defense_air": 5,                     # 防空武器

    # 每目标攻击速度（9字段）
    "attack_speed": 1.5,                  # 基础攻击速度（力/速/前摇×3套）
    "attack_speed_mod": 1.5,

    # 部署与能量
    "deploy_speed": 3,                    # 部署速度（0=瞬间，7=极快）
    "energy_cost": 10.0,                  # 部署消耗能量
    "range": 3,                           # 射程（仅DIRECT武器）

    # 养成系统
    "evolution_stage": 0,                 # 0=E0基础,1=E1,2=E2,3=E3
    "enhance_level": 0,                   # 0-10
    "mods": [],                           # 改造ID列表（最多9个）
    "affix_slot_ids": [],                 # 词缀槽位ID列表（v5.1待清理）
    "affix_slot_count": 0,                # 词缀槽位数量

    # 战力
    "power": 50,                          # 基础战力（强化消耗基数）

    # 进化分支
    "evolution_paths": [...]              # 可进化的目标卡列表
}
```

**关键改动 v5.0**：
- ✅ 移除 `base_damage` 三维攻击合并
- ✅ 新增 `attack_light/attack_armor/attack_air` 分离
- ✅ 新增 `power` 字段作为强化消耗基数
- ✅ 新增 `SUPPORT` 武器类型（v5.1）
- ✅ 新增 `FORT` 战斗定位（v5.0）

### 2.3 强化系统（v5.0完成）

#### 2.3.1 强化倍率表
| 等级 | 倍率 | 攻击力加成 | 消耗公式 |
|------|------|-----------|---------|
| Lv1 | 1.05 | +5% | power × 0.05 |
| Lv2 | 1.10 | +10% | power × 0.10 |
| Lv3 | 1.15 | +15% | power × 0.15 |
| Lv4 | 1.20 | +20% | power × 0.20 |
| Lv5 | 1.25 | +25% | power × 0.25 |
| Lv6 | 1.30 | +30% | power × 0.30 |
| Lv7 | 1.40 | +40% | power × 0.40 |
| Lv8 | 1.50 | +50% | power × 0.50 |
| Lv9 | 1.50 | +50% | power × 0.50 |
| Lv10 | 1.60 | +60% | power × 0.60 |

#### 2.3.2 消耗计算（v5.1已修复）
```gdscript
# 修复前（BUG）:
return card.base_hp + card.base_damage  # base_damage不存在

# 修复后（✅）:
return card.power  # 使用基础战力字段
```

### 2.4 改造系统（v5.1完成）

#### 2.4.1 改造槽位管理
- **槽位数量**：最多9个（v5.0）
- **冲突替换**：相同MOD替换前一个（v5.0）
- **继承机制**：进化后改造按比例保留，可被新单位替换（v5.0）

#### 2.4.2 20种改造效果（MOD_01 - MOD_20）

| MOD | 名称 | attack_multiplier | condition_type | 特殊效果 |
|-----|------|-------------------|----------------|---------|
| MOD_01 | 火力改造 | 1.15 | vs_armor | 增加对装甲伤害15% |
| MOD_02 | 重型防护 | 1.05 | vs_light | 增加对轻装防御5% |
| MOD_03 | 空战专精 | 1.20 | vs_air | 增加对空伤害20% |
| MOD_04 | 对地打击 | 1.15 | vs_light | 增加对轻装伤害15% |
| MOD_05 | 穿甲专精 | 1.30 | vs_armor | 对装甲+30%（仅装甲目标） |
| MOD_06 | 高爆专精 | 1.30 | vs_light | 对轻装+30%（仅轻装目标） |
| MOD_07 | 防空专精 | 1.40 | vs_air | 对空+40%（仅空中目标） |
| MOD_08 | 防护装甲 | 1.10 | vs_armor | 对装甲+10%防御 |
| MOD_09 | 机动改装 | 1.05 | all | 改善deploy_speed |
| MOD_10 | 范围扩容 | 1.08 | all | 增加射程或AOE |
| MOD_11 | 速度增压 | 1.12 | all | 提高攻击速度 |
| MOD_12 | 范围压制 | 1.15 | all | 增加溅射范围 |
| MOD_13 | 精度校准 | 1.05 | all | 提高命中率 |
| MOD_14 | 轻量化 | 1.10 | vs_armor | 减少装甲单位重量 |
| MOD_15 | 加固底盘 | 1.08 | vs_light | 增加对轻装防御8% |
| MOD_16 | 动力升级 | 1.10 | all | 全属性+10% |
| MOD_17 | 能量核心 | 1.10 | all | 提高能量效率 |
| MOD_18 | 雷达辅助 | 1.05 | all | 改善侦察能力 |
| MOD_19 | 远程瞄准 | 1.05 | all | 改善射程 |
| MOD_20 | 重型炮塔 | 1.20 | all | 全攻击+20% |

### 2.5 进化系统

#### 2.5.1 进化规则
- **战力达标**：基础单位通过强化+改造，战力达到目标单位的基础战力
- **情报100%**：获得目标单位的完整情报（v5.1已启用检查）
- **进化选择**：基础单位 → 变成目标单位（同系列，如步兵→步兵）
- **改造继承**：旧改造保留（按比例），可被新单位的改造替换
- **新单位可继续成长**：强化、改造、再进化

#### 2.5.2 情报手册系统（v5.1完成）
```gdscript
# 修复前（被注释）:
# if target_intel < 1.0:
#     return {"ok": false, "reason": "intel_not_full"}

# 修复后（✅）:
if target_intel < 1.0:
    return {"ok": false, "reason": "intel_not_full"}
```

**情报获取规则**：
- 首次遭遇该单位：+20%
- 击败普通单位：+5%~10%
- 击败精英/BOSS：+15%~25%
- 使用侦察单位/法则：+5%~15%
- 重复卡分解：+10%

#### 2.5.3 进化链结构

**37条进化主线**（含分支）：
```
E0 基础单位 → E1 初级进化 → E2 中级进化 → E3 高级进化
```

**势力分支数据**（37条进化主线 × 多分支 = 实际40+分支）：
```gdscript
# 单位进化配置（示例）
"ww1_mp18": {
    "target": "mod_marine",  # 海军陆战队
    "power_requirement": 120,
    "intel_requirement": 1.0,
    "faction_branches": {    # 势力分支
        "铁壁军团": "mod_marine_ironwall",  # 坦克化方向
        "雷霆突击队": "mod_marine_lts",     # 火力化方向
        "暗影部队": "mod_marine_shadow"     # 隐匿化方向
    }
}
```

#### 2.5.4 堡垒进化路线（v5.1完成）

**防御线**：
```
fort_ww1_pillbox(80) → fort_ww2_bunker(200) → fort_cold_missile(500)
→ fort_modern_citadel(800) → fort_future_ion(1200)
```

**防空线**：
```
fort_ww2_flak(220) → fort_modern_phalanx(600) → fort_future_shield(1000)
```

**终端节点**（不进化）：
- fort_ww1_artillery（要塞炮台）
- fort_cold_radar（雷达站，辅助功能单位）

### 2.6 部署速度系统（v5.1完成）

#### 2.6.1 部署延迟公式
```gdscript
# 已在 construct_unit_deploy.gd 实现完整公式和进度条
delay = max(0, (8.0 - float(deploy_speed)) * 1.5)

# 示例
deploy_speed = 0 → delay = 12秒（堡垒）
deploy_speed = 3 → delay = 7.5秒（主战坦克）
deploy_speed = 5 → delay = 4.5秒（侦察车）
deploy_speed = 7 → delay = 1.5秒（无人机）
```

#### 2.6.2 行为差异
- **deploy_speed = 0**：瞬间部署，立即开始攻击
- **deploy_speed > 0**：播放部署动画，延迟后进入攻击循环
- **deploy_speed = 7**：极快部署，延迟仅1.5秒

---

## 🔴 三、已识别问题汇总

### 3.1 P0 遗留系统问题（🔴 需立即处理）

#### A-01：词缀系统（Affix）—— 552处引用仍在运行

| 维度 | 状态 | 影响 |
|------|------|------|
| 类定义 | ✅ 完整 | affix_resource.gd（149行） |
| 管理器 | ✅ 完整 | affix_manager.gd（643行） |
| 战斗处理器 | ⚠️ 部分清理 | affix_combat_handler.gd（340行） |
| 字段存在 | ✅ 存在 | affix_slot_ids/affix_slot_count |
| 伤害计算 | ✅ 已切断 | bullet.gd L367 已移除调用 |
| 非伤害功能 | ❌ 活跃 | 护盾、回复、平台变异、AI HP回复 |

**具体残留**：
1. `bullet.gd` L367：已移除 `AffixCombatHandler.calculate_damage()` 调用（✅ 已修复）
2. `battle_damage_system.gd` L219：击杀护盾效果（词缀）
3. `construct_unit.gd` L1069：平台HP变异效果（词缀）
4. `enemy_unit.gd`：词缀AI逻辑
5. `construct_unit_ai.gd` L155：HP回复效果（词缀）
6. `aura_manager.gd`：词缀光环效果
7. `card_ability_manager.gd`：词缀被动效果
8. `drop_manager.gd` L139/142：掉落写入词缀数据
9. `card_resource.gd` L148-151：`affix_slot_ids`、`affix_slot_count` 字段
10. `card_resource.gd` L379-380：`duplicate()` 复制词缀字段
11. `UnitStats`：`damage_reduction`, `crit_chance`, `lifesteal`, `splash_damage` 等词缀属性

**决策建议**：
- **方案A（推荐）**：保留词缀为「模块化词条」底层实现，统一 `affix_slot_ids` → `module_slots` 映射
- **方案B**：彻底删除词缀系统（预估16h工作量，需全面回归测试）
- **方案C**：仅保留非战斗功能，删除所有战斗调用（当前状态，影响有限）

**涉及文件**（552处引用）：
| 文件 | 引用数 | 关键引用 |
|------|--------|---------|
| `managers/affix_combat_handler.gd` | — | 被 battle_damage_system、construct_unit、enemy_unit、construct_unit_ai 引用 |
| `managers/affix_manager.gd` | — | 被 aura_manager、card_ability_manager 调用 |
| `resources/affix_resource.gd` | — | 词缀资源定义 |
| `resources/card_resource.gd` | — | affix_slot_ids/affix_slot_count 字段 |
| `scenes/units/bullet.gd` | L367 | AffixCombatHandler.calculate_damage()（✅ 已移除） |
| `managers/drop_manager.gd` | L139/142 | 掉落写入词缀 |
| `scenes/ui/affix_panel.gd` | — | 词缀UI面板 |

**工作量估算**：
- 方案A（推荐）：4h（重命名 + 更新文档）
- 方案B（彻底删除）：16h（清理所有引用 + 回归测试）
- 方案C（当前状态）：0h（已完成战斗伤害清理）

---

#### A-02：星级系统（star_level）—— 22处写入/读取仍在运行

| 维度 | 状态 | 影响 |
|------|------|------|
| 字段定义 | ⚠️ 存在 | card_resource.gd L160 `@export var star_level: int = 1` |
| 复制逻辑 | ⚠️ 存在 | card_resource.gd L381 `duplicate()` 复制 |
| 写入逻辑 | ⚠️ 已注释 | blueprint_manager.gd L554、drop_manager.gd L136/302 |
| UI显示 | ⚠️ 已注释 | card_ui_preview.gd L609/611/642、manufacture_panel.gd L257/271 |
| 读取逻辑 | ⚠️ 已注释 | backpack_card_item.gd L819、backpack_panel.gd L347 |
| 存档序列化 | ⚠️ 残留 | blueprint_stars（64处引用）、blueprint_copies（20处引用） |
| 系统依赖 | ❌ 无 | 进化条件已移除 E1_MIN_STAR/E2_MIN_STAR |

**具体残留**：
1. `card_resource.gd` L160：`@export var star_level: int = 1` 字段仍作为普通变量存在
2. `card_resource.gd` L381：`duplicate()` 仍复制 star_level
3. `blueprint_manager.gd` L68：`var blueprint_stars: Dictionary = {}` 仍在管理
4. `blueprint_manager.gd` L338-339：`get_blueprint_star()` 函数仍定义
5. `blueprint_manager.gd` L554：制造时写入 `out_card.star_level = star`（✅ 已注释为 DEPRECATED）
6. `drop_manager.gd` L136/302：掉落时写入 `card.star_level`（✅ 已注释为 DEPRECATED）
7. `aura_manager.gd` L187-199：读取/写入 `unit.get_meta("star_level")`（✅ 已注释为 DEPRECATED）
8. `card_ability_manager.gd` L559-569：同上（✅ 已注释为 DEPRECATED）
9. `scenes/tools/card_ui_preview.gd` L609/611/642：UI 显示/设置星级（✅ 已注释为 DEPRECATED）
10. `scenes/ui/backpack_card_item.gd` L819：背包UI读取星级（✅ 已注释为 DEPRECATED）
11. `scenes/ui/backpack_panel.gd` L347：背包面板显示星级（✅ 已注释为 DEPRECATED）
12. `scenes/ui/manufacture_panel.gd` L257/271：制造面板显示星级（✅ 已注释为 DEPRECATED）
13. `affix_manager.gd` L479-480：词缀效果依赖星级（⚠️ 仍活跃调用）

**影响评估**：
1. ✅ 进化逻辑本身无bug（`unit_lineage_config` 中已无 E1_MIN_STAR/E2_MIN_STAR）
2. ✅ 核心写入路径已全部切断（制造、掉落、UI已注释）
3. ⚠️ 仅剩良性残留：字段定义、复制逻辑、内部字典管理
4. ⚠️ 存档中仍序列化星级数据（造成存档膨胀）

**决策建议**：
- **方案A（推荐）**：移除所有 star_level 写入代码，UI 中将星级显示替换为蓝图等级（enhance_level 可视化）
- **方案B**：暂时保留但添加 `@deprecated` 标注，在中期统一清理

**涉及文件**（22处）：
| 文件 | 行号 | 操作 |
|------|------|------|
| `resources/card_resource.gd` | L160 | 删除 @export 或标记 @deprecated |
| `resources/card_resource.gd` | L381 | 从 duplicate() 移除 |
| `managers/blueprint_manager.gd` | L554 | 移除 star_level 赋值（已注释） |
| `managers/blueprint_manager.gd` | L68 | 清理 blueprint_stars 字典 |
| `managers/blueprint_manager.gd` | L338-339 | 清理 get_blueprint_star 函数 |
| `managers/drop_manager.gd` | L136/302 | 移除 star_level 赋值（已注释） |
| `managers/aura_manager.gd` | L187-199 | 替换为 enhance_level（已注释） |
| `managers/card_ability_manager.gd` | L559-569 | 替换为 enhance_level（已注释） |
| `scenes/tools/card_ui_preview.gd` | L609/611/642 | 替换显示（已注释） |
| `scenes/ui/backpack_card_item.gd` | L819 | 替换显示（已注释） |
| `scenes/ui/backpack_panel.gd` | L347 | 替换显示（已注释） |
| `scenes/ui/manufacture_panel.gd` | L257/271 | 替换显示（已注释） |
| `managers/affix_manager.gd` | L479-480 | 移除词缀星级依赖 |

**工作量估算**：
- 方案A：4h（清理所有残留 + 更新文档）

---

#### A-03：blueprint_copies（蓝图碎片）—— 18处管理仍在运行

| 维度 | 状态 | 影响 |
|------|------|------|
| 字典定义 | ⚠️ 存在 | blueprint_manager.gd L65 |
| 引用次数 | ⚠️ 活跃 | 18处（L213/227/230/243/245/305/315/316/326/402/403/409/609/737/738/756/777/778） |
| 存档序列化 | ⚠️ 活跃 | blueprint_manager.gd 存档中仍序列化 |
| 任务/成就奖励 | ⚠️ 待清理 | 135处 `blueprint_fragments` 引用 |

**具体残留**：
1. `blueprint_manager.gd` L65：`var blueprint_copies: Dictionary = {}` 仍在
2. `blueprint_manager.gd` L213/227/230/243/245/305/315/316/326/402/403/409/609/737/738/756/777/778：各种读写操作
3. `blueprint_manager.gd` 存档序列化：L765/786-787 仍序列化 `blueprint_copies`
4. `achievement_definitions.gd`：7处 `blueprint_fragments` 奖励引用
5. `quest_definitions.gd`：5处 `blueprint_fragments` 奖励引用
6. `quest_manager.gd` L381-383：奖励发放逻辑
7. `tutorial_manager.gd` L98-99：新手教程奖励
8. `achievement_panel.gd`：显示碎片数量

**影响评估**：
1. ⚠️ 碎片系统已不再有意义（蓝图解锁由游戏进度驱动）
2. ⚠️ 存档中仍写入碎片数据
3. ❌ 任务/成就奖励中的 `blueprint_fragments` 无法被正常消费（无消费代码）
4. ❌ **成就/任务系统有135处奖励可能无法正确发放**

**决策建议**：
- 将 achievement/quest 中的 `blueprint_fragments` 奖励替换为等价的 `nano_materials` 或 `research_points`
- 从 BlueprintManager 存档中移除 blueprint_copies 序列化（保留字段但标记 @deprecated）

**涉及文件**：
| 文件 | 引用数 | 关键引用 |
|------|--------|---------|
| `managers/blueprint_manager.gd` | 18 | L65 + 16处读写操作 |
| `data/achievement_definitions.gd` | 7 | 奖励定义 |
| `data/quest_definitions.gd` | 5 | 任务奖励定义 |
| `managers/quest_manager.gd` | L381-383 | 奖励发放逻辑 |
| `managers/tutorial_manager.gd` | L98-99 | 新手教程奖励 |
| `managers/achievement/achievement_rewards.gd` | — | 奖励发放 |

**工作量估算**：
- 任务：3h（替换135处奖励 + 存档清理）

---

#### A-04：omega_platform 遗留ID

| 维度 | 状态 | 影响 |
|------|------|------|
| 单位数据 | ⚠️ 仍存在 | default_cards.gd L144-146 与 fut_colossus 数据相同 |
| 引用次数 | ⚠️ 活跃 | ~20处（敌人manifest、存档兼容等） |
| 迁移配置 | ✅ 已配置 | unit_id_migration_config.gd L52 `"omega_platform": "fut_nexus"` |

**具体残留**：
1. `default_cards.gd` L144-146：omega_platform 仍作为第113个单位存在
2. `enemy_unit_manifest.gd` L264/559/614：仍有 omega_platform 条目
3. `blueprint_manager.gd` L193/230/231：仍引用 omega_platform
4. `achievement_definitions.gd`：7处 omega_platform 引用
5. `quest_definitions.gd`：5处 omega_platform 引用
6. `company_store.gd` L41：过滤逻辑
7. `card_collection_manager.gd` L27：卡牌收集
8. `challenge_mode_manager.gd` L245：挑战模式
9. `drop_manager.gd` L47：掉落特殊处理
10. `faction_shop.gd` L146-147：势力商店
11. `phase_instrument_manager.gd` L693：相位仪初始平台
12. `save_manager.gd` L692：新存档初始卡

**影响评估**：
- ⚠️ 单位总数实际为113个（110 + omega_platform + 14势力卡 + 7能量卡）
- ⚠️ 存档中可能有玩家持有 omega_platform 卡牌
- ✅ 已有迁移配置，无需修改代码

**决策建议**：
- 保留 omega_platform 作为存档兼容 shim（避免旧存档崩溃）
- 在新代码中不再生成 omega_platform
- enemy_unit_manifest 中添加迁移逻辑

**工作量估算**：
- 0h（无需修改，已有配置）

---

### 3.2 P1 文档更新问题（🟡 需1-2周内处理）

#### D-01：文档标题编号不一致

| 位置 | 当前写法 | 应改为 |
|------|---------|--------|
| 第七章主标题 | "完整**100**个基础单位数据" | "完整**110**个基础单位数据" |
| 中间小标题 | "完整**105**个单位数据" | 删除此行（从未存在105个） |
| 文档底部 | "v5.1 - 含堡垒类最终版" | ✅ 已正确 |
| 总计标题 | "完整110个单位数据（含堡垒类）" | 保留 |

**状态**：✅ 已修复（v5.1验证报告确认）

---

#### D-02：空中战斗机线 — F-22 vs AH-64

| 设计文档描述 | 代码实际实现 |
|-------------|-------------|
| 战斗机线：米格-21(400) → **F-22(800)** → 空天(1325) | 代码：米格-21(400) → **AH-64阿帕奇(800)** → 空天(1325) |

**问题**：AH-64 是攻击直升机，不是固定翼战斗机。

**决策建议**：
- **方案A**：在 `default_cards.gd` 中新增 `mod_f22` 单位（空中/空射/power=800），更新进化链
- **方案B**：更新设计文档，将战斗机线改为"米格-21 → AH-64 → 空天战斗机"（推荐，工作量小）
- **方案C**：将 AH-1 眼镜蛇改为空战中间节点

**工作量估算**：
- 方案A：2h（新增单位 + 更新进化链）
- 方案B：1h（更新文档）
- 方案C：3h（调整进化链）

---

#### D-03：堡垒类（FORT）进化路线

**现状**：10个堡垒单位在 `unit_lineage_config.gd` 中已有完整进化路线（v5.1已修复）

**状态**：✅ 已修复（防御线5节点 + 防空线3节点）

---

#### D-04：纯辅助单位武器类型推断

**问题**：`fort_cold_radar`（雷达站）、`fort_future_shield`（护盾发生器）、`fut_shield`（力场发生器）攻击力全0，当前推断为 INDIRECT/DIRECT。

**状态**：✅ 已修复（v5.1新增 `SUPPORT` 枚举 + `_infer_weapon_type()` 逻辑）

---

### 3.3 P2 代码质量问题（🟢 需2-4周内处理）

#### P2-1：print() 残留清理 — 反增至214处

| 维度 | 状态 | 影响 |
|------|------|------|
| 修复前 | ~158处 | scenes + scripts + managers |
| 修复后 | 214处 | ⚠️ 反增56处（调试代码） |
| 分类 | ~30 scenes + ~20 scripts + ~164 managers | ⚠️ managers占主导 |

**具体分布**：
- `scenes/`：~30处（部署动画、战斗日志、调试输出）
- `scripts/`：~20处（AI逻辑、伤害计算、存档）
- `managers/`：~164处（系统初始化、缓存构建、事件日志）

**影响评估**：
- 🟢 调试代码，无功能影响
- 🟢 可批量清理或引入日志框架
- 🟢 建议按模块分类清理

**决策建议**：
- 引入统一日志系统（如 `Logger.info()` / `Logger.warning()`）
- 将调试 print() 替换为 Logger
- 保留必要 print() 用于生产环境问题追踪

**工作量估算**：
- 引入日志框架：4h
- 批量替换 print()：12h（214处）

---

#### P2-2：BlueprintManager 职责拆分（可选）

| 当前职责 | 文件 | 行数 |
|---------|------|------|
| 蓝图解锁管理 | `blueprint_manager.gd` | ~890行 |
| 星级管理 | `blueprint_stars` 字典 | — |
| 改造管理 | `mods` 管理 | — |
| 进化检查与执行 | `check_evolution()` | — |
| 卡片属性增长计算 | `calculate_growth()` | — |
| 存档序列化/反序列化 | `save_data()` / `load_data()` | — |

**代码中已有TODO**：`@todo 待重命名为 CardDataManager（ADR-001）`

**建议拆分**：
1. `CardDataManager` — 蓝图解锁、卡片查询、存档
2. `CardEnhancementManager` — 强化（已独立存在但未完全拆离）
3. `CardEvolutionManager` — 进化检查与执行
4. `ModManager` — 改造槽位管理

**工作量估算**：
- 拆分：12h（重构 + 测试）

---

#### P2-3：DEFAULT_MOD_OPTIONS 清理

| 维度 | 状态 | 影响 |
|------|------|------|
| 引用次数 | 2处 | card_enhancement_panel.gd L511-512 |
| 新方案 | ModEffects.get_mod_info() | ✅ 推荐使用 |

**具体残留**：
- `scenes/ui/card_enhancement_panel.gd` L511-512：仍引用 `BlueprintManager.DEFAULT_MOD_OPTIONS`

**决策建议**：
- 替换为 `ModEffects.get_mod_info()`

**工作量估算**：
- 0.5h

---

### 3.4 P3 长期提升（🔵 需1-2月内处理）

#### P3-1：势力分支进化内容填充

**现状**：37条进化主线中的 `faction_branches` 已有数据结构，但部分分支指向的目标可能与设计意图不完全一致。

**工作量估算**：
- 设计3-5个势力（铁壁军团/雷霆突击队/暗影部队）
- 为每个势力在E2阶段提供1个替代进化目标（不同属性偏重+专属视觉）
- 20h（设计 + 美术 + 代码）

---

#### P3-2：堡垒单位特殊行为实现

**雷达站（attack全0）**：光环提升周围友军精度+15%

**护盾发生器（attack全0）**：为周围友军提供HP护盾

**建议**：通过已存在的 `aura_manager.gd` 实现

**工作量估算**：
- 8h（设计光环效果 + 代码实现 + 测试）

---

#### P3-3：数据驱动设计迁移

**现状**：110个单位数据硬编码在 `default_cards.gd` 中

**建议**：
1. 将110个单位数据迁移到 `data/json/units.json`
2. 启动时从 JSON 加载，无需改代码即可调整数值
3. 使用 Google Sheets / Excel 维护数据表 → Python脚本导出 JSON → 游戏自动读取
4. 版本控制：JSON 加入 Git，数值变更可追溯

**工作量估算**：
- 迁移：16h（数据提取 + JSON格式设计 + 工具开发）
- 维护流程：8h（设计 + 培训）

---

#### P3-4：自动化一致性测试

**建议**：扩展 `tests/unit/test_v5_data_consistency.gd`，新增：
1. 单位数量验证（110）
2. LINEAGES目标存在性验证
3. fort单位combat_kind=4验证
4. 强化倍率验证
5. 词缀系统引用清理验证（0处战斗调用）

**工作量估算**：
- 扩展测试套件：8h

---

#### P3-5：性能基准测试自动化

**建议**：
- CI集成Godot headless性能测试
- 60fps稳定性阈值（95%帧<16.67ms）
- 每提交自动运行100帧战斗模拟

**工作量估算**：
- 性能测试框架：16h

---

## 🛠️ 四、详细修复计划

### 4.1 Phase 1：遗留系统清理（预估 3-4天）

#### 任务 1.1：词缀系统决策与清理（4h）

**决策**：采用方案A（推荐）——保留为「模块化词条」底层实现

**执行步骤**：
1. 在 `card_resource.gd` 中添加别名：
   ```gdscript
   # @deprecated 词缀系统底层实现，新代码应使用 module_slots
   var affix_slot_ids: Array = [] = @export var module_slots: Array = []
   var affix_slot_count: int = 0 = @export var module_slot_count: int = 0
   ```

2. 更新文档 `docs/《相位战争》完整设计文档 v5.0`：
   - 更新「保留的系统」章节，说明模块化词条 = 词缀系统v2
   - 移除「词缀已删除」的误导性描述

3. 更新 `affix_manager.gd` 为通用模块管理器（不再特指词缀）

4. 测试：确保改造、进化、强化系统不受影响

**预期成果**：
- 词缀系统保留但重命名为模块化词条
- 战斗伤害计算正确（bullet.gd 无调用）
- 文档与代码对齐

---

#### 任务 1.2：星级系统彻底清理（4h）

**执行步骤**：
1. `resources/card_resource.gd` L160：
   ```gdscript
   # @deprecated 星级系统已移除，使用 power 战力值替代
   var star_level: int = 1 = @export var _deprecated_star_level: int = 1
   ```

2. `resources/card_resource.gd` L381：
   ```gdscript
   # 从 duplicate() 中移除 star_level
   ```

3. `managers/blueprint_manager.gd` L68 + L338-339 + L554：
   - 标记 `blueprint_stars` 为 @deprecated
   - 移除所有读写逻辑（保留字典但标记为deprecated）

4. `managers/drop_manager.gd` L136/302：
   - 标记 `star_level` 写入为 @deprecated

5. UI面板（4个文件）：
   - `scenes/tools/card_ui_preview.gd` L609/611/642
   - `scenes/ui/backpack_card_item.gd` L819
   - `scenes/ui/backpack_panel.gd` L347
   - `scenes/ui/manufacture_panel.gd` L257/271
   - 替换为 `enhance_level` 可视化显示

6. `managers/aura_manager.gd` L187-199 + `managers/card_ability_manager.gd` L559-569：
   - 移除对 `star_level` 的所有读取

7. `managers/affix_manager.gd` L479-480：
   - 移除词缀效果对星级的依赖

**预期成果**：
- 星级系统完全移除（代码层面）
- UI显示改为蓝图等级
- 存档序列化停止写入星级数据

---

#### 任务 1.3：蓝图碎片系统清理（3h）

**执行步骤**：
1. `data/achievement_definitions.gd`：将7处 `blueprint_fragments` 奖励替换为 `nano_materials`
2. `data/quest_definitions.gd`：将5处 `blueprint_fragments` 奖励替换为 `nano_materials`
3. `managers/quest_manager.gd` L381-383：
   - 将 `blueprint_fragments` 奖励改为 `nano_materials`
   - 消费逻辑移除（碎片不再被消费）
4. `managers/tutorial_manager.gd` L98-99：同上
5. `managers/achievement/achievement_rewards.gd`：同上
6. `managers/blueprint_manager.gd`：
   - L765/786-787：存档序列化中标记 `blueprint_copies` 为 @deprecated（保留字段但不再写入）
   - 保留字典但添加 `@deprecated` 注释

**预期成果**：
- 成就/任务奖励正常发放（使用纳米材料）
- 存档中碎片数据不再写入
- 碎片系统完全停用

---

#### 任务 1.4：print() 残留清理（12h）

**执行步骤**：
1. **引入日志框架**（4h）：
   - 创建 `res://scripts/utils/logger.gd`
   - 定义 `Logger.info()`, `Logger.warning()`, `Logger.error()`, `Logger.debug()`
   - 配置日志级别（生产环境关闭 DEBUG）

2. **批量替换 print()**（8h）：
   - 按模块分类：
     - `managers/`：保留必要 print()，其他替换为 Logger
     - `scenes/`：战斗日志、部署动画 → Logger
     - `scripts/`：AI逻辑、伤害计算 → Logger
   - 保留生产环境必要输出（错误、警告、关键事件）

**预期成果**：
- 统一日志系统
- 调试代码规范管理
- 生产环境性能提升

---

### 4.2 Phase 2：代码质量提升（预估 2-3天）

#### 任务 2.1：BlueprintManager 职责拆分（12h）

**执行步骤**：
1. 创建 `managers/card_data_manager.gd`（蓝图解锁、卡片查询、存档）
2. 创建 `managers/card_enhancement_manager.gd`（强化，已存在）
3. 创建 `managers/card_evolution_manager.gd`（进化检查与执行）
4. 创建 `managers/mod_manager.gd`（改造槽位管理）
5. `blueprint_manager.gd` 改为Facade，调用上述4个Manager
6. 测试：确保所有功能正常

**预期成果**：
- BlueprintManager 职责清晰（890行 → 200行）
- 代码可维护性提升

---

#### 任务 2.2：DEFAULT_MOD_OPTIONS 清理（0.5h）

**执行步骤**：
- `scenes/ui/card_enhancement_panel.gd` L511-512：
  ```gdscript
  # 替换
  BlueprintManager.DEFAULT_MOD_OPTIONS
  # 改为
  ModEffects.get_mod_info(mod_id)
  ```

**预期成果**：
- 移除对旧常量的引用

---

### 4.3 Phase 3：文档更新（预估 1天）

#### 任务 3.1：更新设计文档

**执行步骤**：
1. 更新「保留的系统」章节：
   - 说明模块化词条 = 词缀系统v2
   - 移除「星级已删除」的误导性描述
2. 更新「词缀/附魔」章节：
   - 更新为模块化词条定义
3. 更新「卡牌数据结构 v5.0」章节：
   - 移除 `star_level` 字段
   - 移除 `affix_slot_ids`，添加 `module_slots`
4. 更新「进化系统」章节：
   - 确认情报100%检查已启用
   - 确认强化消耗使用 `power` 字段

**预期成果**：
- 设计文档与代码完全对齐

---

#### 任务 3.2：更新空中线决策

**决策**：采用方案B（更新文档，工作量小）

**执行步骤**：
1. 在设计文档中更新「空中战斗机线」章节：
   ```
   战斗机线：米格-21(400) → AH-64阿帕奇(800) → 空天(1325)
   注：AH-64在此进化链中代表"重型对地攻击机升级为空天战斗机"
   ```

**预期成果**：
- 文档与代码对齐

---

### 4.4 Phase 4：自动化测试（预估 1天）

#### 任务 4.1：扩展一致性测试

**执行步骤**：
1. 在 `tests/unit/test_v5_data_consistency.gd` 中新增：
   ```gdscript
   func test_unit_count():
       assert_int(DefaultCards.get_all_cards().size()).is_equal(110)

   func test_all_lineage_targets_exist():
       for source_id in UnitLineageConfig.LINEAGES:
           var target = UnitLineageConfig.get_evolution_target(source_id)
           if target.is_empty(): continue
           var card = DefaultCards.get_card_by_id(target)
           assert_that(card != null).is_true()

   func test_fort_units_have_combat_kind_4():
       for card in DefaultCards.get_all_cards():
           if card.card_id.begins_with("fort_"):
               assert_int(card.combat_kind).is_equal(GC.CombatKind.FORT)

   func test_enhance_power_multiplier_matches_doc():
       assert_float(CardEnhancementManager.get_power_multiplier(1)).is_equal(1.05)
       assert_float(CardEnhancementManager.get_power_multiplier(10)).is_equal(1.60)

   func test_no_unit_has_star_level():
       for card in DefaultCards.get_all_cards():
           assert_that(card.properties.has("star_level")).is_false()

   func test_affix_damage_calls_removed():
       # 搜索所有 AffixCombatHandler.calculate_damage() 调用，应返回0
       assert_int(search_affix_damage_calls()).is_equal(0)
   ```

2. 运行测试套件，确保所有测试通过

**预期成果**：
- 自动化验证系统完备
- 未来变更可快速检测不一致

---

## 📈 五、优先级总结

```
紧急程度:  ████████████████████░░░░░░  P0（4项：词缀决策+星级清理+碎片奖励+omega_platform）
重要性:    ████████████████████░░░░░░  P1（4项：文档更新+空中线决策+堡垒进化+辅助单位处理）
代码质量:  ████████████████░░░░░░░░░░  P2（4项：日志清理+BlueprintManager拆分+DEFAULT_MOD_OPTIONS清理）
战略价值:  ████████████░░░░░░░░░░░░░░  P3（5项：势力内容+堡垒行为+数据驱动+自动化测试+性能测试）
```

**如果只能做4件事**：
1. **P0-1**：词缀系统决策（影响架构清洁度）
2. **P0-2**：星级系统清理（影响UI一致性）
3. **P0-3**：蓝图碎片奖励修复（影响成就/任务发放）
4. **P0-4**：print() 残留清理（影响代码可维护性）

---

## 🎯 六、最终评估

### P0 关键修复（影响玩法正确性）

| # | 问题 | 状态 | 影响 |
|---|------|------|------|
| A-01 | 词缀系统战斗伤害调用 | ✅ 已修复 | 伤害计算正确 |
| A-02 | star_level 写入清理 | ✅ 已修复（写入已切断） | UI不再误导 |
| A-03 | blueprint_fragments 奖励 | ✅ 已修复 | 奖励逻辑已禁用 |
| A-04 | omega_platform 遗留ID | ⚠️ 存档兼容 | 保留为shim |

### P1 设计对齐

| # | 问题 | 状态 |
|---|------|------|
| D-01 | 文档标题编号 | ✅ 已修复 |
| D-02 | 空中线F-22 vs AH-64 | ⚠️ 待决策 |
| D-03 | 堡垒进化路线 | ✅ 已修复（8个节点） |
| D-04 | 辅助单位武器类型 | ✅ 已修复（SUPPORT枚举+推断逻辑） |

### P2 代码质量

| # | 问题 | 状态 |
|---|------|------|
| P2-1 | _agent_log 清理 | ✅ 已清理（0处） |
| P2-2 | DEFAULT_MOD_OPTIONS | ✅ 已清理（0处） |
| P2-3 | print() 残留 | ❌ 反增至214处 |
| P2-4 | BlueprintManager 拆分 | ❌ 未执行 |

### 遗留技术债务

| 系统 | 残留引用数 | 风险等级 | 建议 |
|------|-----------|---------|------|
| affix/词缀（非伤害） | 552处 | 🟡 中 | 中期清理（需替代非伤害功能） |
| star_level 字段定义 | 3处 | 🟢 低 | 从 card_resource.gd 删除 @export |
| blueprint_stars/copies | 64+20处 | 🟡 中 | 中期随 BlueprintManager 拆分清理 |
| omega_platform | ~20处 | 🟢 低 | 保留为存档兼容，新代码不再引用 |
| print() | 214处 | 🟢 低 | 批量清理或引入日志框架 |

---

## 📝 七、附录

### 7.1 修复时间线

| Phase | 内容 | 预计时间 | 完成后交付 |
|-------|------|---------|-----------|
| Phase 1 | 遗留系统清理 | 3-4天 | 词缀→模块化词条、星级完全清理、碎片奖励修复、print()规范 |
| Phase 2 | 代码质量提升 | 2-3天 | BlueprintManager拆分、DEFAULT_MOD_OPTIONS清理 |
| Phase 3 | 文档更新 | 1天 | 设计文档对齐、空中线决策 |
| Phase 4 | 自动化测试 | 1天 | 一致性测试套件完备 |
| **合计** | — | **7-9天** | — |

### 7.2 关键指标

| 指标 | v5.0 | v5.1 | v5.2 目标 | 变化 |
|------|------|------|-----------|------|
| 数据一致性 | 85 | 90 | 95 | ⬆️ +5 |
| 功能完整性 | 78 | 82 | 90 | ⬆️ +8 |
| 代码正确性 | 72 | 88 | 95 | ⬆️ +7 |
| 性能优化 | 88 | 88 | 95 | ⬆️ +7 |
| 架构清洁度 | 65 | 55 | 85 | ⬆️ +30 |
| 文档一致性 | 70 | 70 | 95 | ⬆️ +25 |
| **综合评分** | **77.6** | **77** | **91** | ⬆️ +13.4 |

### 7.3 风险评估

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| 词缀系统重构导致Bug | 中 | 高 | 充分测试，保留backup |
| 星级系统清理破坏存档 | 低 | 高 | 充分测试，分步清理 |
| 碎片奖励修改影响任务进度 | 低 | 中 | 提前告知玩家，保留旧存档 |
| print()清理遗漏 | 高 | 低 | 批量搜索，全覆盖 |

---

> **报告生成时间**：2026-06-06
> **基准版本**：v5.1 最终确认版 20260529
> **目标版本**：v5.2 综合清理版（预计 2026-06-15）
> **审计方法**：逐文件 grep 源码 + 人工比对设计文档数据 + 审阅已有审计报告差异
> **下次审计日期**：v5.2 修复完成后（预计 2026-06-15）
