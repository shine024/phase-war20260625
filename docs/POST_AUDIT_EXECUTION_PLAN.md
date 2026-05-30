# 📋 《相位战争》v5.0 后续执行计划

> **生成日期**：2026-05-30
> **基于**：AUDIT_REPORT_v5.0_20260530.md 全量扫描 + 用户决策确认
> **执行前提**：v5.0修订计划(Phase1-4) + P0-1/P0-2/P0-3 已完成
> **用户决策**：
>   - C-1 词缀系统：**方案A — 保留，更名为"模块化词条"**
>   - C-2 星级系统：**方案A — 保留为"蓝图等级"**

---

## 一、当前项目状态总结

### ✅ 已完成（上次审计计划）

| # | 任务 | 状态 |
|---|------|------|
| P0-1 | 强化基础战力计算 → `card.power` | ✅ |
| P0-2 | 改造伤害加成接入战斗公式 | ✅ |
| P0-3 | `battle_damage_system.gd` autoload 安全引用 | ✅（局部） |
| Phase1 | 数据结构升级（110单位、三维攻防、FORT） | ✅ |
| Phase2 | 战斗系统重写（选敌/衰减/伤害公式） | ✅ |
| Phase3 | 养成系统重构（强化/改造/品质） | ✅ |
| Phase4 | 进化系统升级 | ✅ |
| Phase5 | 情报手册系统 | ✅ |
| BlueprintManager 新UI拆分 | ✅（facade模式） |

### ❌ 未完成（本计划覆盖）

| # | 任务 | 优先级 | 工作量 |
|---|------|--------|--------|
| A-1 | PhaseLawManager 75处直接引用 → 安全引用 | 🔴 P0 | 2-3h |
| B-1 | deploy_speed 部署延迟系统 | 🟡 P1 | 4h |
| B-2 | 启用情报100%进化门控 | 🟡 P1 | 1h |
| B-3 | 补充缺失单位 cold_rpg + 修复进化链 | 🟡 P1 | 2h |
| B-4 | 势力分支UI空区域隐藏 | 🟡 P1 | 0.5h |
| C-1 | 词缀系统 → 更名为"模块化词条" + 文档更新 | 🟠 P2 | 1h |
| C-2 | 星级系统 → 文档更新为"蓝图等级" | 🟠 P2 | 0.5h |
| C-3 | BlueprintManager 进一步拆分 | 🟠 P2 | 12h |
| C-4 | 自动化测试套件 | 🟠 P2 | 4h |

---

## 二、🔴 Phase A：Autoload 安全引用清零（1-2天）

### A-1：PhaseLawManager 75处直接引用 → `_resolve_autoload("PhaseLawManager")`

**目标**：消除所有直接引用 `PhaseLawManager` 全局名的位置，统一使用安全引用模式。

**统一模式**：
```gdscript
# 在文件顶部或类内增加 helper
var _plm: Node

func _ensure_plm() -> Node:
    if _plm == null or not is_instance_valid(_plm):
        _plm = get_node_or_null("/root/PhaseLawManager")
    return _plm
```

对于静态/工具函数场景：
```gdscript
var plm: Node = get_node_or_null("/root/PhaseLawManager")
if plm and plm.has_method("xxx"):
    plm.xxx()
```

**逐文件改动清单**（75处，按文件分组）：

---

#### 文件1：`managers/phase_instrument_manager.gd`（~20处）

| 行号 | 当前代码 | 改为 |
|------|---------|------|
| L361 | `if PhaseLawManager == null or not PhaseLawManager.has_method("set_equipped_laws"):` | 加 `_ensure_plm()`，用 `if not _plm or not _plm.has_method("set_equipped_laws"):` |
| L364 | `if not PhaseLawManager.is_inside_tree():` | `if not _plm.is_inside_tree():` |
| L368-372 | 4处 `PhaseLawManager.ensure_law_unlocked(...)` | `_plm.ensure_law_unlocked(...)` |
| L373 | `PhaseLawManager.battle_nano_budget` | `_plm.battle_nano_budget` |
| L374 | `PhaseLawManager.set_equipped_laws(...)` | `_plm.set_equipped_laws(...)` |
| L375-376 | `PhaseLawManager.force_sync_instrument_law_slots(...)` | `_plm.force_sync_instrument_law_slots(...)` |
| L389-390 | `PhaseLawManager.equipped_active_laws` / `equipped_passive_laws` | `_plm.equipped_active_laws` |
| L476-490 | 同上模式（`_try_equip_card_to_slot` 函数内重复逻辑） | 同上替换 |
| L856-857 | `PhaseLawManager.equipped_active_laws` / `equipped_passive_laws` | `_plm.equipped_active_laws` |

**改动建议**：此文件使用频率最高。建议：
1. 在类头部加 `var _plm: Node`
2. 加 `_ensure_plm()` helper
3. 批量替换所有 `PhaseLawManager.` → `_plm.`（前置 null check）

---

#### 文件2：`scenes/ui/phase_law_panel.gd`（~18处）

| 行号 | 当前代码 | 改为 |
|------|---------|------|
| L45 | `if not PhaseLawManager or not PhaseLawManager.has_method("get_current_env"):` | `var plm := get_node_or_null("/root/PhaseLawManager")` + guard |
| L49 | `PhaseLawManager.get_current_env()` | `plm.get_current_env()` |
| L69 | `PhaseLawManager.has_method(...)` (3个方法) | `plm.has_method(...)` |
| L71 | `PhaseLawManager.get_all_law_status_for_current_env()` | `plm.get_all_law_status_for_current_env()` |
| L75-76 | `PhaseLawManager.equipped_passive_laws` / `equipped_active_laws` | `plm.equipped_passive_laws` |
| L144,147 | 同上模式 | 同上替换 |
| L152-153 | 同上 | 同上替换 |
| L244 | `PhaseLawManager.KNOWLEDGE_KEYS` | `plm.KNOWLEDGE_KEYS` |
| L248 | `PhaseLawManager.get_knowledge(k)` | `plm.get_knowledge(k)` |
| L281-282 | `PhaseLawManager.research_law(law_id)` | `plm.research_law(law_id)` |
| L323-327 | 同上模式 | 同上替换 |
| L338-339 | `PhaseLawManager.equipped_passive_laws` / `equipped_active_laws` | `plm.equipped_passive_laws` |

**改动建议**：此文件有多个函数（`_refresh`、`_build_law_row`等）各自独立引用。建议每个函数入口处获取一次 `plm`，函数内复用。

---

#### 文件3：`scenes/ui/battle_click_overlay.gd`（~8处）

| 行号 | 当前代码 | 改为 |
|------|---------|------|
| L239 | `if PhaseLawManager and PhaseLawManager.has_method("can_cast")` | `var plm := get_node_or_null("/root/PhaseLawManager")` + guard |
| L256 | `PhaseLawManager.can_cast(law_id, ...)` | `plm.can_cast(law_id, ...)` |
| L280 | `PhaseLawManager._resolve_equipped_active_key(...)` | `plm._resolve_equipped_active_key(...)` |
| L290 | `PhaseLawManager.active_law_states` | `plm.active_law_states` |

---

#### 文件4：`managers/blueprint_manager.gd`（~6处）

| 行号 | 当前代码 | 改为 |
|------|---------|------|
| L219-220 | `PhaseLawManager.has_method("ensure_law_unlocked")` + 调用 | 加 `_ensure_plm()` helper，用 `_plm.ensure_law_unlocked()` |
| L329-330 | 同上 | 同上 |
| L1233 | `if PhaseLawManager == null or not PhaseLawManager.has_method("add_knowledge"):` | `_plm` + guard |
| L1243-1244 | `PhaseLawManager.knowledge_key_for_law_id(...)` + `add_knowledge(...)` | `_plm.knowledge_key_for_law_id(...)` + `_plm.add_knowledge(...)` |

---

#### 文件5：`scenes/ui/unit_info_panel.gd`（~3处）

| 行号 | 当前代码 | 改为 |
|------|---------|------|
| L643 | `var law_ids: Array = PhaseLawManager.equipped_passive_laws` | ⚠️ **无 null guard！** 加 `var plm := get_node_or_null("/root/PhaseLawManager")` + `if not plm: return ""` |
| L671 | `var law_ids: Array = PhaseLawManager.equipped_active_laws` | 同上 |

---

#### 文件6：`managers/game_manager.gd`（~4处）

| 行号 | 当前代码 | 改为 |
|------|---------|------|
| L354-355 | `if PhaseLawManager.has_method("update_env_for_level"): PhaseLawManager.update_env_for_level(...)` | 加 `_ensure_plm()` + guard |
| L587-588 | `PhaseLawManager.get_knowledge_snapshot()` | `_plm.get_knowledge_snapshot()` |
| L612-615 | 3处 `PhaseLawManager` 引用 | `_plm` 替换 |

---

#### 文件7-13：其余各1-2处

| 文件 | 行号 | 改动 |
|------|------|------|
| `scenes/main.gd` | L839-840 | `PhaseLawManager.record_cast()` → 安全引用 |
| `scenes/units/construct_unit.gd` | L516-518 | `PhaseLawManager.get_passive_runtime_tags_for_side()` → 安全引用 |
| `scenes/units/enemy_unit.gd` | L202-204 | 同上 |
| `scenes/units/swarm_enemy_slot.gd` | L100-102 | 同上 |
| `scenes/ui/equipped_passives_box.gd` | L61-62 | `PhaseLawManager.equipped_passive_laws` → 安全引用 |
| `scenes/ui/active_law_cast_panel.gd` | L37-38 | `PhaseLawManager.equipped_active_laws` → 安全引用 |
| `scenes/ui/manufacture_panel.gd` | L271-272 | `PhaseLawManager.ensure_law_unlocked()` → 安全引用 |

**注意**：`construct_unit.gd` 已有 `_resolve_autoload()` helper（L35），可直接复用：
```gdscript
var plm: Node = _resolve_autoload(&"PhaseLawManager")
```

---

### A-2：其他 autoload 直接引用扫雷（顺手处理）

以下位置也使用直接引用且 **无 null guard**，建议在 A-1 时顺手修复：

| 文件 | 行号 | autoload | 风险 |
|------|------|----------|------|
| `scenes/ui/unit_info_panel.gd` | L643, L671 | PhaseLawManager | 无guard → 崩溃 |
| `managers/game_manager.gd` | L354 | PhaseLawManager | 无guard → 崩溃 |
| `managers/phase_instrument_manager.gd` | L364 | PhaseLawManager | `is_inside_tree()` 无前置null check → 崩溃 |
| `managers/phase_instrument_manager.gd` | L856-857 | PhaseLawManager | 无guard → 崩溃 |

---

## 三、🟡 Phase B：功能接线补全（3-5天）

### B-1：deploy_speed 部署延迟系统（⏱️~4h）

**现状**：`construct_unit.gd` `start_as_deploy_ghost(materialize_after_sec)` 接受外部固定参数，所有单位部署时间一样。

**目标**：部署延迟 = `(8.0 - deploy_speed) × 1.5` 秒。

#### 改动文件1：`scenes/units/construct_unit.gd`

**改动1**：修改 `start_as_deploy_ghost` 或增加计算方法
```gdscript
## 根据单位 deploy_speed 计算实际部署延迟
## 公式：delay = (8.0 - deploy_speed) × 1.5
## deploy_speed=0 → 0秒（堡垒/要塞瞬间部署）
## deploy_speed=7 → 0.5秒
func _calculate_deploy_delay() -> float:
    if stats == null:
        return 1.0
    var speed: int = stats.deploy_speed
    if speed <= 0:
        return 0.0  # 堡垒/要塞瞬间部署
    if speed >= 7:
        return 0.5
    return (8.0 - float(speed)) * 1.5

## 修改 start_as_deploy_ghost — 如果未传入自定义时间，用 deploy_speed 计算
func start_as_deploy_ghost(materialize_after_sec: float = -1.0) -> void:
    is_deploy_ghost = true
    var actual_delay: float = materialize_after_sec
    if actual_delay < 0.0:
        actual_delay = _calculate_deploy_delay()
    _ghost_materialize_time_left = maxf(0.05, actual_delay)
    _ghost_total_time = _ghost_materialize_time_left
    # ... 后续不变
```

**改动2**：`deploy_speed=0` 的单位跳过部署幽灵，直接实例化
```gdscript
# 在部署回调中：
var delay := _calculate_deploy_delay()
if delay <= 0.01:
    # 瞬间部署（堡垒等），跳过幽灵阶段
    _setup_with_stats(...)
    _materialize_deploy_ghost()
else:
    start_as_deploy_ghost(delay)
```

**改动3**：`DeployProgressBar` 已存在（L100），已接入进度显示（L258-260），无需额外改动。

#### 改动文件2：`scenes/units/enemy_unit.gd`

敌军单位也需要 deploy_speed 延迟。检查敌军部署流程，在创建时加入类似延迟逻辑。

#### 改动文件3：`scenes/battlefield/`（部署点/卡牌拖拽处）

找到调用 `start_as_deploy_ghost(materialize_after_sec)` 的地方，改为不传参或传 -1.0，让 construct_unit 自己计算。

---

### B-2：启用情报100%进化门控（⏱️~1h）

#### 改动文件1：`data/unit_lineage_config.gd`

**L255**，将注释取消：
```gdscript
# 修改前：
# 5. 情报100%（Phase 5 启用 — 当前跳过）
# TODO(Phase 5): 取消注释以启用情报检查
# if target_intel < 1.0:
#     return {"ok": false, "reason": "intel_not_full"}

# 修改后：
# 5. 情报100%
var IntelManual = preload("res://scripts/systems/intel_manual.gd")
var target_intel: float = IntelManual.get_intel_progress(target_card_id)
if target_intel < 1.0:
    return {"ok": false, "reason": "intel_not_full"}
```

**注意**：需要在函数签名中确认 `target_card_id` 已可用（从调用链看，`check_evolution_conditions` 已接收此参数）。

#### 改动文件2：`managers/blueprint_manager.gd`

**L804**，将注释取消：
```gdscript
# 修改前：
## TODO(Phase 5): 取消下方注释以启用情报检查
# var target_intel: float = _get_card_intel_progress(target_card_id)
# if target_intel < 1.0:
#     return _evolve_check_denied("intel_not_full")

# 修改后：
var target_intel: float = _get_card_intel_progress(target_card_id)
if target_intel < 1.0:
    return _evolve_check_denied("intel_not_full")
```

**需确认**：`_get_card_intel_progress()` 是否已实现。若未实现，需新建：
```gdscript
func _get_card_intel_progress(card_id: String) -> float:
    var im: Node = get_node_or_null("/root/IntelManual")
    if im and im.has_method("get_intel_progress"):
        return im.get_intel_progress(card_id)
    return 0.0
```

#### 改动文件3：`scripts/systems/intel_manual.gd`

确认 `get_intel_progress(card_id)` 已存在。当前扫描显示 L130 有 `entry.get("intel_progress", 0.0)`，需确认是否有公开函数。若没有，增加：
```gdscript
func get_intel_progress(card_id: String) -> float:
    if _entries.has(card_id):
        return _entries[card_id].intel_progress
    return 0.0
```

---

### B-3：补充缺失单位 cold_rpg + 修复进化链（⏱️~2h）

#### 改动文件1：`data/default_cards.gd`

在 `ww2_panzerschrek` 之后新增 `cold_rpg`：

```gdscript
# 新增 RPG组（冷战时代，反坦克线第2阶段）
list.append(_unit("cold_rpg", "RPG火箭筒组", 2, 0, 170, 3, 2, 12, 180, 18, 0.8, 0.2, 0.1, 120, 0.5, 0.4, 0.2, 0, 0, 0, 0, 14, 15, 5))
```

**数据依据**（设计文档 v5.0 §7）：
- era=2（冷战），combat_kind=0（轻装），power=170
- HP=180，deploy_speed=3，range=2，energy=14
- 对轻=18，对甲=120，对空=0（反坦克定位）
- 防轻=15，防甲=5，防空=5（低防御）

#### 改动文件2：`data/unit_lineage_config.gd`

修改反坦克进化链，插入 RPG 组节点：

```gdscript
# 修改前：
#   反坦克:   ww2_panzerschrek(65) → mod_javelin(330) → fut_cyborg(500)

# 修改后：
#   反坦克:   ww2_panzerschrek(65) → cold_rpg(170) → mod_javelin(330) → fut_cyborg(500)

"ww2_panzerschrek": {
    "evolution_1": "cold_rpg",     # ← 改为 cold_rpg
    "faction_branches": {},
},
"cold_rpg": {                      # ← 新增节点
    "evolution_1": "mod_javelin",
    "faction_branches": {},
},
"mod_javelin": {
    "evolution_1": "fut_cyborg",   # 保持不变
    "faction_branches": {},
},
```

#### 关于 F-22 问题

战斗机线当前：`cold_mig21(400) → mod_ah64(800) → fut_space_fighter(1325)`

设计文档写的是 F-22，但代码用 AH-64（阿帕奇攻击直升机）替代。**建议**：暂时保持 AH-64 作为正式方案（功能完整，替换有风险），更新文档将 F-22 改为 AH-64 的描述，或在文档中标注"战斗机线使用AH-64攻击直升机作为替代进化节点"。

#### 改动文件3：`data/default_cards.gd` `_infer_weapon_type()`

在纯辅助单位处理中增加守卫：
```gdscript
# 三维攻击全为0的纯辅助单位
if atk_light == 0 and atk_armor == 0 and atk_air == 0:
    return GC.WeaponType.DIRECT  # 默认值，但标记为不可攻击
```

同时在 `UnitStats` 或 `CardResource` 中确保纯辅助单位在战斗中不尝试攻击（已有逻辑：attack 全 0 → 无攻击目标 → 自然跳过）。

---

### B-4：势力分支UI空区域隐藏（⏱️~0.5h）

#### 改动文件1：`scenes/ui/unit_progression_detail_view.gd`

**L189** 附近：
```gdscript
var branches: Dictionary = opts.get("faction_branches", {})
# 增加判断：如果为空则隐藏分支区域
if branches.is_empty():
    faction_branch_container.visible = false  # 或不创建分支UI
    return
```

#### 改动文件2：`scenes/ui/card_enhancement_panel.gd`

**L355** 附近：
```gdscript
var branches: Dictionary = options.get("faction_branches", {})
if branches.is_empty():
    # 隐藏空的势力分支入口
    faction_branch_section.visible = false
```

---

## 四、🟠 Phase C：技术债务决策执行（1-2周）

### C-1：词缀系统 → 更名为"模块化词条"（⏱️~1h）

**决策**：保留词缀系统，但更新文档和代码注释消除矛盾。

#### 改动文件1：设计文档更新

在 `docs/《相位战争》完整设计文档 v5.0` 中找到"已删除的系统"部分，将词缀系统描述改为：

```
词缀/附魔系统 → 保留，更名为"模块化词条"（Module Slot）
- 与改造(MOD)系统共存
- 模块化词条提供战斗内被动效果（暴击、吸血、溅射、护盾等）
- 改造(MOD)提供数值增益（攻击/防御/速度等）
- 两者互不冲突，可叠加
```

#### 改动文件2：`resources/affix_resource.gd`

更新类注释：
```gdscript
## 模块化词条资源（原称"词缀/附魔"）
## 提供战斗内被动效果：暴击、吸血、溅射、护盾等
## 与改造(MOD)系统共存
```

#### 改动文件3：`managers/affix_manager.gd`

更新注释（不改逻辑）：
```gdscript
## 模块化词条管理器（原称 AffixManager）
extends Node
```

#### 改动文件4：`managers/affix_combat_handler.gd`

更新注释：
```gdscript
## 模块化词条战斗效果处理器
## 负责在战斗中应用模块化词条的特殊效果
```

#### 改动文件5：`resources/card_resource.gd`

更新字段注释：
```gdscript
## 模块化词条槽位（原 affix_slot_ids）
## 不要直接修改此字段，使用 AffixManager 的接口操作。
@export var affix_slot_ids: Array = []
@export var affix_slot_count: int = 4
```

---

### C-2：星级系统 → 文档更新为"蓝图等级"（⏱️~0.5h）

**决策**：保留星级，在文档中更新为正式机制名称"蓝图等级"。

#### 改动文件1：设计文档更新

在"已删除的系统"部分移除星级：
```
星级系统 → 保留，正式名称"蓝图等级"（Blueprint Star Level）
- 1-9★，通过研究点升级
- 作为进化门槛条件之一（E1需≥4★，E2需≥7★）
- 与强化等级(enhance_level 0-10)并行存在
  - 蓝图等级：整体蓝图成长，影响进化资格
  - 强化等级：单卡属性加成，影响战斗数值
```

#### 改动文件2：`resources/card_resource.gd`

更新注释：
```gdscript
## 蓝图等级 1-9★（Blueprint Star Level，影响进化门槛）
@export var star_level: int = 1
```

#### 改动文件3：`managers/blueprint_manager.gd`

更新注释：
```gdscript
## ─────────── 蓝图等级系统（研究点升星，影响进化门槛） ───────────
## 星级是蓝图的整体成长度，影响进化资格检查（E1≥4★，E2≥7★）
## 注意：与 enhance_level（强化等级，0-10）是不同概念
```

---

### C-3：BlueprintManager 进一步拆分（⏱️~12h）

**目标**：将 `blueprint_manager.gd`（1268行）拆分为更小的模块。

#### 拆分方案

| 新文件 | 从 BlueprintManager 提取的内容 | 预估行数 |
|--------|-------------------------------|---------|
| `managers/evolution/card_evolution_manager.gd` | 进化条件检查、进化执行、进化消耗计算 | ~200行 |
| `managers/evolution/mod_manager.gd` | 改造槽位管理、MOD装配/替换/冲突检测 | ~200行 |
| `managers/evolution/evolution_helpers.gd` | 战力估算、属性增长计算等辅助函数 | ~100行 |
| `managers/blueprint_manager.gd`（保留） | 蓝图解锁、副本管理、星级、存档序列化、facade API | ~700行 |

#### 步骤

1. **创建目录** `managers/evolution/`
2. **新建 `card_evolution_manager.gd`** — 从 `blueprint_manager.gd` 提取：
   - `check_evolution_eligibility()` (L780-815)
   - `execute_evolution()` (L850+)
   - `get_evolution_costs()`
   - 进化条件相关辅助函数
3. **新建 `mod_manager.gd`** — 从 `blueprint_manager.gd` 提取：
   - `get_modification_count()`
   - `add_modification()`
   - `remove_modification()`
   - `get_equipped_mods()`
   - MOD冲突检测逻辑
4. **新建 `evolution_helpers.gd`** — 从 `blueprint_manager.gd` 提取：
   - `_estimate_power_score()`
   - `_calculate_card_attribute_growth()`
   - 战力倍率计算
5. **BlueprintManager 保留 facade** — 所有现有 API 保持兼容：
   - `check_evolution_eligibility()` 委托给 `CardEvolutionManager`
   - `get_modification_count()` 委托给 `ModManager`
   - 其余不变

#### 兼容性保障

- BlueprintManager 保留所有公开方法签名
- 内部委托给新 Manager
- 所有调用方（UI面板、战斗系统等）无需修改
- 存档格式不变

---

### C-4：自动化测试套件（⏱️~4h）

**目标**：创建 GdUnit 测试，验证设计文档与代码的一致性。

#### 新建文件：`tests/unit/test_v5_data_consistency.gd`

```gdscript
class_name V5DataConsistencyTest
extends GdUnitTestSuite

const DefaultCards = preload("res://data/default_cards.gd")
const UnitLineageConfig = preload("res://data/unit_lineage_config.gd")
const GC = preload("res://resources/game_constants.gd")

## 验证总单位数 = 110（100战斗 + 10堡垒）
func test_total_combat_unit_count():
    var cards = DefaultCards.get_all_cards()
    var combat_units = cards.filter(func(c): return c.card_type == GC.CardType.COMBAT_UNIT)
    assert_int(combat_units.size()).is_equal(110)

## 验证所有进化链目标单位存在
func test_all_lineage_targets_exist():
    for source_id in UnitLineageConfig.LINEAGES:
        var cfg: Dictionary = UnitLineageConfig.LINEAGES[source_id]
        var target_id: String = cfg.get("evolution_1", "")
        if target_id.is_empty():
            continue
        var target_card = DefaultCards.get_card_by_id(target_id)
        assert_that(target_card != null).is_true()

## 验证堡垒单位 combat_kind = 4
func test_fort_units_have_combat_kind_4():
    for card in DefaultCards.get_all_cards():
        if card.card_id.begins_with("fort_"):
            assert_int(card.combat_kind).is_equal(GC.CombatKind.FORT)

## 验证无单位使用旧的 base_damage 字段
func test_no_unit_has_base_damage():
    for card in DefaultCards.get_all_cards():
        assert_that(card.properties.has("base_damage")).is_false()

## 验证强化倍率与文档一致
func test_enhance_power_multiplier():
    var CEM = preload("res://managers/card_enhancement_manager.gd")
    # Lv1=1.05, Lv5=1.25, Lv8=1.40, Lv9=1.50, Lv10=1.60
    assert_float(CEM.get_power_multiplier(1)).is_equal(1.05)
    assert_float(CEM.get_power_multiplier(5)).is_equal(1.25)
    assert_float(CEM.get_power_multiplier(8)).is_equal(1.40)
    assert_float(CEM.get_power_multiplier(9)).is_equal(1.50)
    assert_float(CEM.get_power_multiplier(10)).is_equal(1.60)
```

#### 新建文件：`tests/unit/test_attack_calculator.gd`

```gdscript
class_name AttackCalculatorTest
extends GdUnitTestSuite

const AttackCalculator = preload("res://scripts/battle/attack_calculator.gd")
const GC = preload("res://resources/game_constants.gd")

## 测试击穿检查：attack <= defense → 伤害=0
func test_penetration_check_zero_damage():
    var attacker = UnitStats.new()
    attacker.attack_armor = 50  # 对甲攻击50
    var defender = UnitStats.new()
    defender.defense_armor = 60  # 对甲防御60
    var damage = AttackCalculator.calculate_damage(attacker, defender, 1.0, GC.WeaponType.DIRECT)
    assert_float(damage).is_equal(0.0)

## 测试防御减免公式：damage × 100/(100+def)
func test_defense_reduction():
    var attacker = UnitStats.new()
    attacker.attack_light = 100  # 对轻100
    var defender = UnitStats.new()
    defender.defense_light = 100  # 对轻防御100
    var damage = AttackCalculator.calculate_damage(attacker, defender, 1.0, GC.WeaponType.DIRECT)
    # 100 × 100/(100+100) = 50
    assert_float(damage).is_equal(50.0)

## 测试改造加成
func test_mod_damage_multiplier():
    var mods = ["MOD_01"]  # 火力改造 +15%
    var mult = AttackCalculator.get_mod_damage_multiplier(mods, GC.CombatKind.LIGHT)
    assert_float(mult).is_equal(1.15)
```

---

## 五、执行顺序与依赖关系

```
Phase A-1 (Autoload安全引用) ─────→ 立即开始
    ↓
Phase B-1 (deploy_speed) ─────────→ A-1完成后
    ↓
Phase B-2 (情报门控) ───────────→ 可与B-1并行
Phase B-3 (缺失单位) ───────────→ 可与B-2并行
Phase B-4 (势力分支UI) ─────────→ 可独立
    ↓
Phase C-1 (词缀文档) ───────────→ B阶段完成后
Phase C-2 (星级文档) ───────────→ 可与C-1并行
    ↓
Phase C-3 (BlueprintManager拆分) → C-1/C-2完成后
    ↓
Phase C-4 (自动化测试) ─────────→ 所有代码改动完成后
```

## 六、文件变更汇总

### 必须修改的文件

| 文件 | 改动内容 | Phase |
|------|---------|-------|
| `managers/phase_instrument_manager.gd` | PhaseLawManager → 安全引用（~20处） | A-1 |
| `scenes/ui/phase_law_panel.gd` | PhaseLawManager → 安全引用（~18处） | A-1 |
| `scenes/ui/battle_click_overlay.gd` | PhaseLawManager → 安全引用（~8处） | A-1 |
| `managers/blueprint_manager.gd` | PhaseLawManager → 安全引用（~6处）+ 情报门控取消注释 | A-1, B-2 |
| `scenes/ui/unit_info_panel.gd` | PhaseLawManager → 安全引用（~3处，**含无guard崩溃点**） | A-1 |
| `managers/game_manager.gd` | PhaseLawManager → 安全引用（~4处） | A-1 |
| `scenes/main.gd` | PhaseLawManager → 安全引用（1处） | A-1 |
| `scenes/units/construct_unit.gd` | PhaseLawManager → 安全引用（1处）+ deploy_speed计算 | A-1, B-1 |
| `scenes/units/enemy_unit.gd` | PhaseLawManager → 安全引用（1处）+ deploy_speed计算 | A-1, B-1 |
| `scenes/units/swarm_enemy_slot.gd` | PhaseLawManager → 安全引用（1处） | A-1 |
| `scenes/ui/equipped_passives_box.gd` | PhaseLawManager → 安全引用（1处） | A-1 |
| `scenes/ui/active_law_cast_panel.gd` | PhaseLawManager → 安全引用（1处） | A-1 |
| `scenes/ui/manufacture_panel.gd` | PhaseLawManager → 安全引用（1处） | A-1 |
| `data/unit_lineage_config.gd` | 情报门控取消注释 + 插入cold_rpg节点 | B-2, B-3 |
| `data/default_cards.gd` | 新增cold_rpg单位 | B-3 |
| `scenes/ui/unit_progression_detail_view.gd` | 空势力分支UI隐藏 | B-4 |
| `scenes/ui/card_enhancement_panel.gd` | 空势力分支UI隐藏 | B-4 |
| `scripts/systems/intel_manual.gd` | 确认/新增 get_intel_progress() 公开函数 | B-2 |
| `resources/affix_resource.gd` | 注释更新：词缀→模块化词条 | C-1 |
| `managers/affix_manager.gd` | 注释更新 | C-1 |
| `managers/affix_combat_handler.gd` | 注释更新 | C-1 |
| `resources/card_resource.gd` | 注释更新（星级+词缀） | C-1, C-2 |
| `managers/blueprint_manager.gd` | 注释更新（星级） | C-2 |

### 需要新建的文件

| 文件 | 内容 | Phase |
|------|------|-------|
| `managers/evolution/card_evolution_manager.gd` | 进化检查与执行（从BlueprintManager拆出） | C-3 |
| `managers/evolution/mod_manager.gd` | 改造槽位管理（从BlueprintManager拆出） | C-3 |
| `managers/evolution/evolution_helpers.gd` | 战力估算等辅助函数 | C-3 |
| `tests/unit/test_v5_data_consistency.gd` | 设计文档↔代码一致性测试 | C-4 |
| `tests/unit/test_attack_calculator.gd` | 伤害公式测试 | C-4 |

### 需要修改的设计文档

| 文件 | 改动 | Phase |
|------|------|-------|
| `docs/《相位战争》完整设计文档 v5.0` | 词缀系统"已删除"→"保留，更名模块化词条" | C-1 |
| `docs/《相位战争》完整设计文档 v5.0` | 星级系统"已删除"→"保留，正式名称蓝图等级" | C-2 |
| `docs/《相位战争》完整设计文档 v5.0` | 战斗机线F-22→AH-64标注或替换 | B-3 |
| `docs/《相位战争》完整设计文档 v5.0` | 反坦克线补充RPG组节点 | B-3 |

---

## 七、工作量估算

| Phase | 任务数 | 预估总工时 | 风险等级 |
|-------|--------|-----------|---------|
| A（Autoload安全） | 2 | 3h | 🟢 低（机械替换，无逻辑变更） |
| B（功能接线） | 4 | 7.5h | 🟡 中（deploy_speed需测试，进化链修改需验证） |
| C（技术债） | 4 | 17.5h | 🟡 中（BlueprintManager拆分需严格保持API兼容） |
| **合计** | **10** | **~28h** | — |

---

## 八、里程碑

| 里程碑 | 完成标志 | 预计日期 |
|--------|---------|---------|
| **M1**：安全清零 | 全部 autoload 直接引用改为安全引用，Godot --check-only 通过 | 2026-06-01 |
| **M2**：功能接线 | deploy_speed生效、情报门控启用、cold_rpg单位可用 | 2026-06-04 |
| **M3**：文档统一 | 词缀/星级系统文档与代码一致 | 2026-06-06 |
| **M4**：架构优化 | BlueprintManager拆分完成，API兼容测试通过 | 2026-06-13 |
| **M5**：质量保障 | GdUnit 测试全部通过，设计文档↔代码0差异 | 2026-06-15 |

---

> **文档版本**：v1.0
> **生成工具**：DeepV Code Agent
> **状态**：待执行
