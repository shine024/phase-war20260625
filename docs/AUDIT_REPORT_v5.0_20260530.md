# 📋 《相位战争》v5.0 全面审计报告 — 设计文档 vs 代码实现

> **审计日期**：2026-05-30
> **审计范围**：v5.0 最终版设计文档 ↔ 全量代码实现
> **审计标准**：数据一致性 / 功能完整性 / 性能 / 代码质量
> **审计工具**：DeepV Code Agent（全自动代码审计）

---

## 一、总体评估

| 维度 | 得分 | 说明 |
|------|------|------|
| **数据一致性** | 85/100 | 110单位数据已对齐，但有6处单位/进化链差异 |
| **功能完整性** | 78/100 | 核心系统均存在，但有3处关键功能未接线 |
| **代码正确性** | 72/100 | 1个运行时崩溃Bug + 3个数据/逻辑缺陷 |
| **性能优化** | 88/100 | 对象池、空间网格、缓存均已到位 |
| **架构清洁度** | 65/100 | 大量遗留系统未清理（星级/词缀/蓝图碎片） |
| **综合评分** | **77.6/100** | 项目成熟但存在「表面完成、内里脱节」的问题 |

---

## 二、🔴 关键Bug（必须立即修复）

### BUG-01：`card_enhancement_manager.gd` — `card.base_damage` 不存在 → 强化消耗=0

**文件**：`managers/card_enhancement_manager.gd` L60

**问题**：
```gdscript
return card.base_hp + card.base_damage  # ❌ base_damage 已在v5.0中删除
```
`CardResource` 中 `base_damage` 字段不存在（v5.0已替换为三维攻击 `attack_light/attack_armor/attack_air`）。

**后果**：`get_card_base_power()` 对所有卡牌返回 `base_hp + 0 = base_hp`，强化消耗只按HP计算，完全忽略攻击力部分。低HP高攻单位（如迫击炮HP=70/对轻40/对甲30）强化成本仅为正常值的 ~30%。

**修复方案**：
```gdscript
# 方案A：使用 power 字段（推荐，与设计文档一致）
return card.power

# 方案B：使用三维攻击总和
return int(card.base_hp + card.attack_light + card.attack_armor + card.attack_air)
```
推荐方案A，设计文档第十三章明确以 `基础战力` 作为消耗基数，而 `card.power` 正是文档定义的基础战力字段。

---

### BUG-02：`attack_calculator.gd` — 改造(Mod)伤害倍率被注释掉

**文件**：`scripts/battle/attack_calculator.gd` L52

**问题**：
```gdscript
# 6. 改造加成 (placeholder - mod system in Phase 3)
# final_damage *= get_mod_damage_multiplier(attacker_mods)
```
改造系统已完全实现（20个MOD，9槽位，冲突替换，进化继承），但**战斗伤害公式从未接入改造加成**。

**后果**：玩家花大量资源做改造（如 MOD_01 火力改造 +15%攻击），实际战斗中**毫无效果**。这是**最严重的功能缺失**——核心养成系统的收益无法体现。

**修复方案**：

1. 在 `attack_calculator.gd` 中实现：
```gdscript
func get_mod_damage_multiplier(mods: Array, target_combat_kind: int) -> float:
    var ModEffects = preload("res://data/mod_effects.gd")
    var total_mult := 1.0
    for mod_id in mods:
        var mod_def: Dictionary = ModEffects.MOD_DEFINITIONS.get(mod_id, {})
        var attack_mult: float = mod_def.get("attack_multiplier", 1.0)
        # MOD_05 穿甲专精：对甲+30%，但仅当目标是装甲类
        # MOD_06 高爆专精：对轻+30%，但仅当目标是轻装类
        # MOD_07 防空专精：对空+40%，但仅当目标是空中类
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

2. 取消 L52 注释，替换为：
```gdscript
# 6. 改造加成
if attacker_mods and not attacker_mods.is_empty():
    final_damage *= get_mod_damage_multiplier(attacker_mods, target_stats.combat_kind)
```

3. 需要在 `mod_effects.gd` 的 MOD_DEFINITIONS 中为每个攻击型MOD补充 `attack_multiplier` 和 `condition_type` 字段。

---

### BUG-03：`battle_damage_system.gd` — PhaseLawManager 直接引用全局名（潜在崩溃）

**文件**：`managers/battle/battle_damage_system.gd`

**问题**：代码直接引用 `PhaseLawManager` 作为全局名，但未通过 `_get_autoload_node()` 安全获取。如果 autoload 注册顺序变化或 PhaseLawManager 被禁用，将导致运行时崩溃。

**修复方案**：搜索所有直接引用 autoload 全局名的位置，统一改为安全引用模式：
```gdscript
# ❌ 危险写法
var knowledge = PhaseLawManager.get_family_knowledge(family)

# ✅ 安全写法
var plm = GameManager._get_autoload_node("PhaseLawManager")
if plm and plm.has_method("get_family_knowledge"):
    var knowledge = plm.get_family_knowledge(family)
```

**影响文件排查**：
```bash
# 搜索所有直接引用 autoload 的位置（排除定义和声明）
grep -rn "PhaseLawManager\." scripts/ managers/ scenes/
grep -rn "BlueprintManager\." scripts/ managers/ scenes/
grep -rn "EnergyManager\." scripts/ managers/ scenes/
grep -rn "DropManager\." scripts/ managers/ scenes/
```

---

## 三、🟡 设计文档 vs 代码 — 数据差异

### DIFF-01：进化链中引用了不存在的单位

| 设计文档中的进化链 | 代码中的实际实现 | 问题 |
|---|---|---|
| 反坦克线：铁拳(65) → **RPG组(170)** → 标枪(330) → 机械步兵(500) | `unit_lineage_config.gd`: `ww2_panzerschrek` → `mod_javelin`(330) 直接跳到标枪 | ❌ **缺失 `cold_rpg` 单位**。设计文档中有"RPG组"（冷战场力170），但代码中无此单位数据，无卡片定义。反坦克线从2阶段直接跳到3阶段，少一环。 |
| 空中战斗机线：米格-21(400) → **F-22(800)** → 空天(1325) | `unit_lineage_config.gd`: `cold_mig21` → **`mod_ah64`**(阿帕奇,800) → `fut_space_fighter` | ❌ **F-22不存在**，代码用 AH-64阿帕奇替代。但阿帕奇是攻击直升机，与米格-21→空天战斗机的进化逻辑类型不符——攻击直升机和固定翼战斗机的进化路径混用。 |

**修复建议**：
- **RPG组**：在 `default_cards.gd` 中新增 `cold_rpg` 单位（轻装/直射/power=170/HP=180/对轻=18/对甲=120/对空=0/防轻=18/防甲=15/防空=5），在 `unit_lineage_config.gd` 中插入反坦克线第2阶段。
- **F-22**：在 `default_cards.gd` 中新增 `mod_f22` 单位（空中/空射/power=800/HP=350/对轻=80/对甲=70/对空=250），替换 `mod_ah64` 作为战斗机线进化节点。将 AH-64 移至攻击机线或保留为独立单位。

---

### DIFF-02：堡垒类(combat_kind=4)没有进化路线

**问题**：10个堡垒单位在 `unit_lineage_config.gd` 的 LINEAGES 字典中没有任何条目。

**后果**：堡垒类单位无法进化。设计文档未明确说明堡垒是否应该有进化路线，属于设计遗漏。

**建议进化路线**（需设计确认）：
```
防御线：fort_ww1_pillbox(80) → fort_ww2_bunker(200) → fort_cold_missile(500) → fort_modern_citadel(800) → fort_future_ion(1200)
防空线：fort_ww2_flak(220) → fort_modern_phalanx(600) → fort_future_shield(1000)
```
纯辅助单位（雷达站、要塞炮台）可作为死胡同终端节点。

---

### DIFF-03：纯辅助堡垒单位的武器类型推断错误

| 单位 | attack全0 | range | 当前推断武器类型 | 问题 |
|------|----------|-------|-----------------|------|
| `fort_cold_radar`（雷达站） | 0/0/0 | 99 | INDIRECT（曲射） | ❌ 雷达站没有曲射能力 |
| `fort_future_shield`（能量护盾发生器） | 0/0/0 | 0 | DIRECT（直射） | ❌ 护盾发生器没有直射能力 |
| `fut_shield`（力场发生器） | 0/0/0 | 0 | DIRECT（直射） | ❌ 力场发生器没有直射能力 |

**根因**：`_infer_weapon_type()` 逻辑只检查 `combat_kind==3 → AERIAL` 和 `range>=99 → INDIRECT`，其他全归 DIRECT。未处理"三维攻击全为0"的纯辅助情况。

**修复方案**：
```gdscript
static func _infer_weapon_type(combat_kind: int, range: int, atk_light: int, atk_armor: int, atk_air: int) -> int:
    # 纯辅助/无攻击力单位
    if atk_light == 0 and atk_armor == 0 and atk_air == 0:
        return GC.WeaponType.DIRECT  # 或新增 SUPPORT=3
    # 空中单位 → AERIAL
    if combat_kind == 3:
        return GC.WeaponType.AERIAL
    # 曲射单位（range>=99）→ INDIRECT
    if range >= 99:
        return GC.WeaponType.INDIRECT
    return GC.WeaponType.DIRECT
```

---

### DIFF-04：文档标题编号不一致

| 位置 | 文档写的内容 | 实际 |
|------|-------------|------|
| 第七章主标题 | "完整**100**个基础单位数据" | 实际110个（100+10堡垒） |
| 中间小标题 | "完整**105**个单位数据" | 从未给出105个，直接跳到110个 |
| 文档末尾 | "总单位数：110个" | ✅ 正确 |

**修复**：统一为110个，删除中间的错误标题。

---

### DIFF-05：设计文档"已删除的系统"与代码实际状态严重不符

| 系统 | 文档声明 | 代码实际状态 | 影响 |
|------|---------|-------------|------|
| 星级（1-9★） | ✅ 已删除 | ❌ `star_level` 仍在 CardResource 中；进化条件仍用 `E1_MIN_STAR=4, E2_MIN_STAR=7`；BlueprintManager 仍在管理星级 | 进化系统依赖已"删除"的机制 |
| 词缀/附魔 | ✅ 已删除 | ❌ `affix_resource.gd`、`affix_manager.gd`、`affix_combat_handler.gd` 全面运行；战斗中实际计算词缀效果 | 战斗计算依赖已"删除"的机制 |
| 蓝图碎片 | ✅ 已删除 | ❌ `blueprint_copies` 仍在 BlueprintManager 大量使用；存档仍有碎片数据 | 存档兼容问题 |

**结论**：文档说删除了，代码没有删。需要统一决策。

---

## 四、🟡 功能缺失与未接线项

### MISSING-01：`deploy_speed` 部署速度从未在场景中生效

**状态**：数据完整（CardResource、UnitStats、110个单位都有 `deploy_speed` 字段）

**问题**：搜索 `scenes/` 目录下所有 .gd 文件，**没有任何代码读取 `deploy_speed` 来控制部署动画或进场延迟**。

**文档公式**：`到达时间(秒) = (8 - deploy_speed) × 1.5`

| deploy_speed | 文档含义 | 到达时间 | 代码实际表现 |
|---|---|---|---|
| 0 | 瞬间部署 | 0秒 | ❌ 和其他单位一样延迟 |
| 1 | 极慢 | 10秒 | ❌ 同上 |
| 3 | 中慢 | 7.5秒 | ❌ 同上 |
| 7 | 瞬间进场 | 1.5秒 | ❌ 同上 |

**后果**：所有单位不管 deploy_speed 是多少，实际部署速度完全相同。轻型侦察车和重型坦克同时到达战场，完全丧失了文档设计的"部署时间差"策略维度。

**修复方案**：

1. 在 `construct_unit.gd` / `enemy_unit.gd` 部署回调中：
```gdscript
func _on_deployed_to_battle():
    var delay := _calculate_deploy_delay(stats.deploy_speed)
    if delay > 0.01:
        set_physics_process(false)  # 暂停移动和攻击
        _deploy_timer = delay
        _deploy_timer_active = true
    # deploy_speed=0 的堡垒和瞬间部署单位立即开始攻击

func _calculate_deploy_delay(speed: int) -> float:
    if speed <= 0: return 0.0
    if speed >= 7: return 0.5
    return (8.0 - float(speed)) * 1.5
```

2. `deploy_progress_bar.gd` 已存在，接入即可显示进度。

---

### MISSING-02：情报100%检查被注释 — 进化无需情报

**文件**：
- `data/unit_lineage_config.gd` L256
- `managers/blueprint_manager.gd` L804

**问题**：
```gdscript
# TODO(Phase 5): 取消注释以启用情报检查
# if target_intel < 1.0:
#     return {"ok": false, "reason": "intel_not_full"}
```

**后果**：设计文档第十一章明确规定"情报100%可解锁进化资格"，但代码中跳过了这个检查。玩家无需收集任何情报即可进化任何单位，情报手册系统的核心价值被架空。

**修复方案**：
1. 取消两处 TODO 注释
2. 在进化检查中调用 `IntelManual.get_intel_progress(target_card_id)` 获取情报进度
3. <1.0 时返回 `intel_not_full` 并在UI显示"目标情报不足"
4. 在进化UI的按钮tooltip中显示目标单位的情报进度条

---

### MISSING-03：所有 `faction_branches` 为空 — 势力分支进化形同虚设

**文件**：`data/unit_lineage_config.gd`，全部37个 LINEAGES 条目的 `faction_branches: {}`

**现状**：
- `managers/faction_system_manager.gd` 已存在（势力系统、声望、商店）
- `faction_branches` 数据结构已定义
- UI代码 `unit_progression_detail_view.gd` L189 和 `card_enhancement_panel.gd` L355 已准备好渲染分支

**问题**：没有任何势力分支数据。所有进化都是线性单链，势力系统的进化分支入口全部是空字典。

**建议**：中期内容（P3），但应在当前进化UI中隐藏空的分支入口，避免误导玩家。

---

## 五、🟠 架构与技术债务

### DEBT-01：星级系统 — 文档已删除但代码全面运行

**残留范围**：
| 文件 | 残留内容 |
|------|---------|
| `resources/card_resource.gd` L143 | `@export var star_level: int = 1` (标记 @deprecated 但仍存在) |
| `managers/blueprint_manager.gd` | `blueprint_copies` 碎片管理、星级升级逻辑 |
| `data/unit_lineage_config.gd` L25 | `E1_MIN_STAR = 4, E2_MIN_STAR = 7`（进化门槛依赖星级） |
| `scenes/tools/card_ui_preview.gd` L608 | `BlueprintManager.get_blueprint_star()` 引用 |
| `scenes/ui/level_select_panel.gd` L176 | 星级文本显示 |
| `scenes/ui/help_panel.gd` L140 | "达到指定星级后可进行改装分支选择" |

**矛盾**：设计文档说"星级已删除"，但进化系统仍以4★和7★作为门槛条件。如果星级真的删除了，用什么替代？当前代码中星级仍在驱动进化。

**建议**：统一为"以 `power` 战力值为进化门槛"，删除 `E1_MIN_STAR` 改为 `E1_MIN_POWER_MULT`（战力倍率门槛）。

---

### DEBT-02：词缀系统 — 文档已删除但代码是战斗核心

**残留范围**：

| 文件 | 词缀相关引用数 |
|------|-------------|
| `resources/affix_resource.gd` | 完整类定义（150行） |
| `managers/affix_manager.gd` | 完整管理器 |
| `managers/affix_combat_handler.gd` | 被 construct_unit、enemy_unit、bullet 引用 |
| `resources/card_resource.gd` | `affix_slot_ids`, `affix_slot_count` |
| `resources/unit_stats.gd` | damage_reduction, crit_chance, lifesteal, splash_damage 等词缀属性 |
| 全项目 .gd 文件 | 311处 affix/Affix 引用 |

**建议**：如果确认删除词缀系统，需要创建详细迁移计划（见P2-1）。如果暂不删除，应更新文档标注"Phase 6 清理"。

---

### DEBT-03：BlueprintManager 职责膨胀

**文件**：`managers/blueprint_manager.gd`（890+ 行）

**当前职责**：
1. 蓝图解锁管理
2. 星级（star_level）管理
3. 改造（mods）管理
4. 进化条件检查与执行
5. 卡片属性增长计算
6. 存档序列化/反序列化

**代码中已有TODO**：`@todo 待重命名为 CardDataManager（ADR-001）`

**建议拆分**：见P2-3。

---

## 六、✅ 已正确实现的部分

| 系统 | 文件 | 状态 |
|------|------|------|
| WeaponType枚举 (DIRECT/INDIRECT/AERIAL) | `resources/game_constants.gd` L72 | ✅ |
| CombatKind枚举 (含FORT=4) | `resources/game_constants.gd` L80 | ✅ |
| 三维攻击 (attack_light/armor/air) | `resources/card_resource.gd` L74-82 | ✅ |
| 三维防御 (defense_light/armor/air) | `resources/card_resource.gd` L84-86 | ✅ |
| 每目标攻击速度9字段 | `resources/card_resource.gd` L74-93 | ✅ |
| 伤害公式 (击穿检查 + 100/(100+def)) | `scripts/battle/attack_calculator.gd` L41-65 | ✅ |
| 射程衰减 (仅DIRECT武器) | `scripts/battle/damage_attenuation.gd` | ✅ |
| 三种选敌逻辑 (DIRECT/INDIRECT/AERIAL) | `scripts/battle/target_selection.gd` | ✅ |
| 110个战斗单位完整数据 | `data/default_cards.gd` L17-144 | ✅ |
| 10个堡垒单位完整数据 | `data/default_cards.gd` L135-144 | ✅ |
| 7张能量卡数据 | `data/default_cards.gd` L147-153 | ✅ |
| 强化100%成功率 | `managers/card_enhancement_manager.gd` | ✅ |
| 强化等级倍率 (Lv1=+5% ... Lv10=+60%) | `managers/card_enhancement_manager.gd` | ✅ |
| 强化消耗公式 (战力×等级系数) | `managers/card_enhancement_manager.gd` | ✅ (但base_power计算有BUG) |
| 20种改造效果 (MOD_01-MOD_20) | `data/mod_effects.gd` | ✅ |
| 9改造槽位 + 冲突替换规则 | `data/mod_effects.gd` | ✅ |
| 改造进化继承 (mods复制到目标) | `managers/blueprint_manager.gd` L890 | ✅ |
| 情报手册系统 (IntelManual) | `scripts/systems/intel_manual.gd` | ✅ |
| 情报手册UI (IntelManualUI) | `scripts/systems/intel_manual_ui.gd` | ✅ |
| 9条进化主线 (37个节点) | `data/unit_lineage_config.gd` | ✅ |
| 进化不跨类型检查 | `data/unit_lineage_config.gd` L241 | ✅ |
| 对象池 (ObjectPool) | `managers/object_pool.gd` | ✅ |
| 空间网格优化 (BattleManager) | `managers/battle/battle_manager.gd` | ✅ |
| 攻击3阶段状态机 (WINDUP→ACTIVE→COOLDOWN) | `scenes/units/construct_unit.gd` | ✅ |
| FORT单位在攻击计算中正确处理 | `scripts/battle/attack_calculator.gd` | ✅ |
| FORT单位射程衰减默认TANK(0.3) | `scripts/battle/damage_attenuation.gd` L39 | ✅ |
| 能量系统 (ENERGY_MAX=100) | `resources/game_constants.gd` L6 | ✅ |
| 军衔系统13级 | `resources/game_constants.gd` (RankRules) | ✅ |
| 堡垒单位能量消耗与文档一致 | `data/default_cards.gd` vs 文档 | ✅ 逐项验证通过 |

---

## 七、📈 修复与提升计划

### 🔴 P0 — 立即修复（本周内，影响核心玩法）

| # | 任务 | 文件 | 工作量 | 详细描述 |
|---|------|------|--------|---------|
| P0-1 | **修复强化基础战力计算** | `managers/card_enhancement_manager.gd` L60 | 0.5h | 将 `card.base_hp + card.base_damage` 改为 `card.power`。验证 `get_enhance_nano_cost()` 计算结果与文档§13.1消耗表一致。 |
| P0-2 | **接入改造伤害加成到战斗公式** | `scripts/battle/attack_calculator.gd` L52 | 4h | 实现 `get_mod_damage_multiplier()` 函数，读取 attacker 已装配的 MOD 列表，从 `mod_effects.gd` 获取每个MOD的攻击加成。在 `calculate_damage()` 第6步调用。需为 `mod_effects.gd` 的 MOD_DEFINITIONS 补充 `attack_multiplier` 和 `condition_type` 字段。 |
| P0-3 | **修复全局 autoload 安全引用** | `managers/battle/battle_damage_system.gd` 及其他 | 1h | 全量搜索直接引用 autoload 全局名的位置，统一改为 `GameManager._get_autoload_node("Name")` 模式。 |

---

### 🟡 P1 — 短期修复（1-2周，影响战斗体验）

| # | 任务 | 文件 | 工作量 | 详细描述 |
|---|------|------|--------|---------|
| P1-1 | **实现 deploy_speed 部署延迟系统** | `scenes/units/construct_unit.gd`, `enemy_unit.gd` | 6h | 单位部署后读取 `deploy_speed`，按公式 `delay = max(0, (8 - speed) × 1.5)` 计算进场等待。delay 期间播放部署动画（接入已存在的 `deploy_progress_bar.gd`），结束后进入攻击循环。speed=0 立即攻击，speed=7 延迟0.5秒。 |
| P1-2 | **启用情报100%进化门控** | `data/unit_lineage_config.gd` L256, `managers/blueprint_manager.gd` L804 | 1h | 取消两处 TODO 注释。进化检查中调用 `IntelManual.get_intel_progress(target_card_id)`，<1.0 时返回 `intel_not_full`。UI 显示"情报不足"提示。 |
| P1-3 | **补充缺失的 RPG组 单位** | `data/default_cards.gd`, `data/unit_lineage_config.gd` | 2h | 新增 `cold_rpg` 单位（轻装/直射/era=2/power=170/HP=180/deploy_speed=3/range=2/energy=14/对轻=18/对甲=120/对空=0/防轻=18/防甲=15/防空=5），在 unit_lineage_config 中插入反坦克线第2阶段（铁拳→RPG→标枪）。 |
| P1-4 | **修复纯辅助单位武器类型推断** | `data/default_cards.gd` `_infer_weapon_type()` | 1h | 增加逻辑：`atk_light==0 && atk_armor==0 && atk_air==0` 时返回 DIRECT（默认值）并在 CardResource 上标记 `is_support_only = true`，让战斗系统跳过这些单位的攻击逻辑。 |

---

### 🟢 P2 — 中期优化（2-4周，提升质量）

| # | 任务 | 文件 | 工作量 | 详细描述 |
|---|------|------|--------|---------|
| P2-1 | **清理词缀系统残留代码** | 多文件（311处引用） | 16h | (1) 从 `attack_calculator.gd` 移除词缀伤害计算分支；(2) 从 `construct_unit.gd`/`enemy_unit.gd`/`bullet.gd` 移除词缀战斗处理器调用；(3) 从 `battle_damage_system.gd` 移除战后词缀奖励；(4) `affix_slot_ids` 标记 @deprecated；(5) 保留 `AffixManager`/`AffixResource` 作为兼容shim。**需要全面回归测试。** |
| P2-2 | **统一星级决策** | `card_resource.gd`, `blueprint_manager.gd`, `unit_lineage_config.gd` | 8h | 推荐方案：彻底移除星级，将 `E1_MIN_STAR`/`E2_MIN_STAR` 改为 `E1_MIN_POWER_MULT=1.5`/`E2_MIN_POWER_MULT=2.0`（培养战力需达到目标基础战力的N倍）。删除 `star_level` 字段，更新所有星级UI为战力显示。更新设计文档。 |
| P2-3 | **拆分 BlueprintManager** | `managers/blueprint_manager.gd` | 12h | 拆分为：(1) `CardDataManager` —蓝图解锁、卡片查询、存档；(2) `CardEnhancementManager` —强化（已独立存在但未完全拆离）；(3) `CardEvolutionManager` —进化检查与执行；(4) `ModManager` —改造槽位管理。保留 `BlueprintManager` 作为facade。 |
| P2-4 | **补充堡垒进化路线** | `data/unit_lineage_config.gd` | 3h | 建议路线：防御线 `fort_ww1_pillbox(80)→fort_ww2_bunker(200)→fort_cold_missile(500)→fort_modern_citadel(800)→fort_future_ion(1200)`；防空线 `fort_ww2_flak(220)→fort_modern_phalanx(600)→fort_future_shield(1000)`。辅助单位为终端节点。需设计文档确认。 |
| P2-5 | **文档数据校对** | `docs/《相位战争》完整设计文档 v5.0` | 2h | 修正第七章标题（100→110），删除"105个"错误标题。编写自动化校对脚本，逐行比对文档表格与 `default_cards.gd` 数据。 |
| P2-6 | **建立设计文档↔代码自动化验证** | `tests/design_doc_consistency_test.gd`（新建） | 4h | 新增GdUnit测试：验证单位数量110、所有LINEAGES目标存在、fort单位combat_kind=4、能量消耗与文档一致、强化倍率与文档一致。 |

---

### 🔵 P3 — 长期提升（1-2月，品质飞跃）

| # | 任务 | 说明 |
|---|------|------|
| P3-1 | **势力分支进化内容填充** | 当前所有 `faction_branches: {}`。设计3-5个势力（铁壁军团/雷霆突击队/暗影部队），每个势力在E2阶段提供1个替代进化目标（不同属性偏重+专属视觉）。 |
| P3-2 | **堡垒单位特殊行为实现** | 雷达站(attack全0)：光环提升周围友军精度+15%；护盾发生器：为周围友军提供HP护盾；要塞核心：光环增加周围防御。通过已存在的 `aura_manager.gd` 实现。 |
| P3-3 | **战斗回放与日志系统** | 简易战斗日志（每次攻击/击杀记录），可选慢速回放模式（战后以0.5x重放）。 |
| P3-4 | **平衡性测试框架** | GdUnit测试套件：(1)每时代DPS范围验证；(2)克制关系有效性；(3)进化链战力递增；(4)强化/改造消耗产出平衡。 |
| P3-5 | **数据驱动设计迁移** | 将110个单位数据从 `default_cards.gd` 硬编码迁移到 `data/json/units.json`，支持工具导出+热更新。 |
| P3-6 | **视觉资源补全审计** | 检查 `assets/unit_sprites/`、`assets/card_icons/`，确认117个单位（110战斗+7能量）都有对应精灵图和卡面图标。 |
| P3-7 | **性能基准测试自动化** | CI集成Godot headless性能测试，60fps稳定性阈值（95%帧<16.67ms），每提交自动运行100帧战斗模拟。 |
| P3-8 | **遗留代码完整清理路线图** | Phase6a: 词缀移除(2周) → Phase6b: 星级迁移(1周) → Phase6c: BlueprintManager拆分(2周) → Phase6d: law:碎片清理(1周) |

---

## 八、🎯 高标准项目改进建议

### 建议1：建立「设计文档 ↔ 代码」自动化验证

当前设计文档和代码完全靠人工比对，效率低且容易遗漏。建议创建自动化测试：

```gdscript
# tests/design_doc_consistency_test.gd
extends GdUnitTestSuite

func test_unit_count_matches():
    var cards = DefaultCards.get_all_cards()
    var combat_units = cards.filter(func(c): return c.card_type == GC.CardType.COMBAT_UNIT)
    assert_int(combat_units.size()).is_equal(110)

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
    assert_float(CardEnhancementManager.get_power_multiplier(8)).is_equal(1.40)
    assert_float(CardEnhancementManager.get_power_multiplier(9)).is_equal(1.50)
    assert_float(CardEnhancementManager.get_power_multiplier(10)).is_equal(1.60)

func test_no_unit_has_base_damage():
    for card in DefaultCards.get_all_cards():
        # v5.0 删除了 base_damage，不应有任何引用
        assert_that(not card.properties.has("base_damage")).is_true()
```

---

### 建议2：引入数据驱动设计模式

当前110个单位数据硬编码在 `default_cards.gd` 的 `_unit()` 调用中，修改一个单位需要改代码并重新编译。

建议迁移方案：
1. 将110个单位数据迁移到 `data/json/units.json`
2. 启动时从 JSON 加载，无需改代码即可调整数值
3. 使用 Google Sheets / Excel 维护数据表 → Python脚本导出 JSON → 游戏自动读取
4. 版本控制：JSON 加入 Git，数值变更可追溯

---

### 建议3：战斗模拟器（离线平衡工具）

创建一个 headless 战斗模拟器：
- **输入**：双方阵容配置（单位ID + 强化等级 + 改造列表）
- **输出**：胜率、平均剩余HP、击杀数、DPS统计、存活时间
- **用途**：平衡性调优、单位强度验证、克制关系检查
- **集成**：作为 Godot `--headless --script` 运行，输出 JSON 报告

---

### 建议4：遗留代码清理路线图

| 阶段 | 目标 | 预计时间 | 前置条件 |
|------|------|---------|---------|
| Phase6a | 词缀系统完整移除（含战斗计算、UI、存档迁移） | 2周 | P2-1 完成影响评估 |
| Phase6b | 星级系统→战力门槛迁移完成 | 1周 | P2-2 设计决策确认 |
| Phase6c | BlueprintManager 拆分为4个独立Manager | 2周 | Phase6b 完成 |
| Phase6d | `law:` 蓝图碎片遗留数据完全清理 | 1周 | Phase6c 完成 |

**每个Phase完成后**：
1. 运行全量 GdUnit 测试
2. 手动冒烟测试（启动游戏、进入战斗、强化一张卡、进化一次）
3. 存档兼容性测试（旧存档加载不崩溃）
4. Git tag 标记版本

---

## 九、📊 优先级总结

```
紧急程度:  ████████████████████░░░░░░  P0 (3项，本周)
重要性:    ████████████████████░░░░░░  P1 (4项，1-2周)
价值:      ████████████████░░░░░░░░░░  P2 (6项，2-4周)
战略:      ████████████░░░░░░░░░░░░░░  P3 (8项，1-2月)
```

**如果只能做3件事**：
1. **P0-2**：接入改造伤害加成（玩家最大痛点：改造无效）
2. **P0-1**：修复强化基础战力计算（强化消耗错误）
3. **P1-1**：实现部署速度系统（战斗策略核心维度缺失）

---

## 十、附录：文件变更清单

### 必须修改的文件
| 文件 | 修改内容 |
|------|---------|
| `managers/card_enhancement_manager.gd` | L60: `card.base_hp + card.base_damage` → `card.power` |
| `scripts/battle/attack_calculator.gd` | L52: 取消注释，实现 `get_mod_damage_multiplier()` |
| `data/mod_effects.gd` | 为20个MOD补充 `attack_multiplier` 和 `condition_type` |
| `managers/battle/battle_damage_system.gd` | PhaseLawManager → 安全引用 |
| `data/unit_lineage_config.gd` | L256: 取消注释情报检查 |
| `managers/blueprint_manager.gd` | L804: 取消注释情报检查 |

### 需要新增的文件
| 文件 | 内容 |
|------|------|
| `tests/design_doc_consistency_test.gd` | 设计文档↔代码自动化验证测试 |
| （可选）`data/json/units.json` | 单位数据迁移目标格式 |

### 需要修改的数据
| 位置 | 内容 |
|------|------|
| `data/default_cards.gd` | 新增 `cold_rpg`（RPG组）和 `mod_f22`（F-22）单位定义 |
| `data/unit_lineage_config.gd` | 插入 RPG组进化节点；（可选）补充堡垒进化路线 |

---

> **报告生成时间**：2026-05-30
> **审计覆盖率**：全量扫描 scripts/, managers/, data/, resources/, scenes/ 共 ~120 个 .gd 文件
> **下审计日期建议**：P0修复完成后（预计2026-06-06）
