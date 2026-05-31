# 📋 情报驱动系统 — 对现有系统的修订计划

> **目的**：详细列出每个需要修改的现有文件、修改范围、修改前后对比，
> 以及修改的依赖顺序。确保修订过程有序、可控、可回退。
>
> **创建日期**：2026-05-31
> **版本**：v6.0-revision-1
> **关联文档**：`docs/INTELLIGENCE_DRIVEN_PROGRESSION_PLAN.md`

---

## 一、修订总览

### 1.1 修订范围统计

| 类别 | 数量 | 详情 |
|------|------|------|
| 需修改的GDScript文件 | 10个 | intel_manual, battle_damage_system, battle_result_dialog, battle_result_panel, card_enhancement_panel, card_evolution_manager, battle_manager, intelligence_hub_panel, evolution_atlas_view, unit_progression_detail_view |
| 需修改的数据文件 | 2个 | unit_lineage_config, game_constants |
| 需新增的GDScript文件 | 11个 | 详见实现计划4.1节 |
| 需新增的场景文件 | 4个 | intel_harvest_display.tscn, intel_reveal_popup.tscn, enemy_origin_mod_slot_ui.tscn, intel_evolution_branch_overlay.tscn |
| 需修改的Autoload配置 | 项目设置 | 新增3个Autoload |
| 需修改的场景文件 | 2个 | card_enhancement_panel.tscn(添加D槽UI), battle_result_dialog.tscn(添加情报区域) |

### 1.2 修订依赖图

```
Phase 1（情报维度 + 战斗结算UI）
  │
  ├─ [R1] intel_manual.gd ────────────────────┐ (底层：情报数据模型)
  ├─ [R2] intel_dimensions.gd (新增) ──────────┤
  ├─ [R3] intel_reveal_events.gd (新增) ──────┤
  ├─ [R4] intel_discovery_manager.gd (新增) ──┤ (中层：情报发现逻辑)
  │                                             │
  ├─ [R5] battle_damage_system.gd ────────────┤ (战斗结算触发)
  │                                             │
  ├─ [R6] intel_harvest_display.gd (新增) ────┤ (UI组件)
  ├─ [R7] intel_reveal_popup.gd (新增) ───────┤
  ├─ [R8] battle_result_dialog.gd ────────────┘ (整合到结算界面)
  ├─ [R9] battle_result_panel.gd ──────────────┘
  │
Phase 2（敌源MOD系统）
  │
  ├─ [R10] game_constants.gd ──────────────────┐ (常量)
  ├─ [R11] enemy_origin_mods.gd (新增) ────────┤ (数据)
  ├─ [R12] enemy_origin_mod_manager.gd (新增) ┤ (逻辑)
  ├─ [R13] card_enhancement_panel.gd ──────────┘ (UI)
  ├─ [R14] card_enhancement_panel.tscn ────────┘
  │
Phase 3（情报进化分支）
  │
  ├─ [R15] intel_evolution_branches.gd (新增) ─┐ (数据)
  ├─ [R16] intel_evolution_manager.gd (新增) ──┤ (逻辑)
  ├─ [R17] card_evolution_manager.gd ──────────┤ (整合)
  ├─ [R18] evolution_atlas_view.gd ───────────┤ (UI)
  ├─ [R19] unit_progression_detail_view.gd ────┤
  └─ [R20] intelligence_hub_panel.gd ──────────┘
```

---

## 二、逐文件修订详情

### === Phase 1 修订 ===

---

#### [R1] `scripts/systems/intel_manual.gd` — 情报手册核心

**修订范围**：IntelEntry 内部类扩展 + `_add_intel` 方法重构 + 存档格式变更

**修改前（关键部分）**：
```gdscript
class IntelEntry:
    var card_id: String = ""
    var intel_progress: float = 0.0          # ← 单一进度
    var is_unlocked: bool = false
    var first_encounter: bool = false
    var defeat_count: int = 0
    var recon_bonus: float = 0.0
    var decompose_bonus: float = 0.0
```

**修改后**：
```gdscript
class IntelEntry:
    var card_id: String = ""
    var intel_progress: float = 0.0          # 保留：总情报（用于兼容，自动计算为4维平均值）
    var intel_dimensions: Dictionary = {}    # 🆕 4维情报 {"basic": 0.0, "tactical": 0.0, ...}
    var revealed_tiers: Dictionary = {}     # 🆕 已触发的揭示 {"basic": 1, "tactical": 0, ...}
    var is_unlocked: bool = false
    var first_encounter: bool = false
    var defeat_count: int = 0
    var recon_bonus: float = 0.0
    var decompose_bonus: float = 0.0
    var migrated: bool = false               # 🆕 是否已迁移
```

**方法修改**：

| 方法 | 修改类型 | 修改内容 |
|------|----------|----------|
| `_add_intel()` | **重构** | 新增 `dimension` 参数，按维度添加情报；更新 `intel_progress` 为4维加权平均 |
| `register_first_encounter()` | **修改** | 传入 `{"basic": 0.25}` 维度权重 |
| `register_defeat()` | **修改** | 根据unit_rank传入不同维度权重 |
| `register_recon()` | **修改** | 偏向tactical维度 |
| `register_decompose()` | **修改** | 偏向material维度 |
| `to_dict()` / `from_dict()` | **扩展** | 序列化/反序列化新字段 |
| `load_data()` | **修改** | 加载后调用 `_migrate_legacy_intel()` |
| `get_intel_progress()` | **修改** | 返回加权平均；新增 `get_dimension_progress(card_id, dim)` |

**新增方法**：

| 方法 | 用途 |
|------|------|
| `get_dimension_progress(card_id, dimension)` | 获取特定维度情报 |
| `get_revealed_tier(card_id, dimension)` | 获取某维度的揭示等级 |
| `get_all_dimensions(card_id)` | 获取全部4维情报 |
| `add_dimensional_intel(card_id, amounts: Dictionary, source)` | 一次性添加多维度情报 |
| `_migrate_legacy_intel(raw)` | 存档迁移 |

**向后兼容保证**：
- `get_intel_progress()` 仍然返回单一浮点数（4维加权平均），现有调用者无需修改
- 旧存档加载时自动迁移，不会丢失数据

---

#### [R2] `data/intel_dimensions.gd` — 新增

**不修改现有文件，纯新增。** 参见实现计划3.1.1节。

---

#### [R3] `data/intel_reveal_events.gd` — 新增

**不修改现有文件，纯新增。** 定义所有揭示事件。

**结构**：
```gdscript
## key格式: "{enemy_type}_{dimension}_{threshold_pct}"
const REVEAL_EVENTS: Dictionary = {
    "infantry_basic_50": {
        "title": "侦察报告·步兵部队",
        "description": "通过多次侦察，已完整掌握步兵部队的基本参数...",
        "rewards": [{"type": "stat_visibility", "value": "full"}],
    },
    "infantry_tactical_75": {
        "title": "战术分析·步兵弱点",
        "description": "...",
        "rewards": [{"type": "weakness_bonus", "target_type": "infantry", "value": 0.25}],
    },
    # ... 更多
}
```

---

#### [R4] `scripts/systems/intel_discovery_manager.gd` — 新增

**职责**：
- 管理情报发现流程（4维度×4阈值 = 每卡16个揭示点）
- 在战斗结束时，计算情报增长并检测揭示事件
- 触发揭示信号，通知UI
- 缓存已触发的揭示事件避免重复触发

**关键接口**：
```gdscript
class_name IntelDiscoveryManager
extends Node

## 战斗结束时调用，生成情报收获数据
func generate_battle_intel_harvest(
    defeated_enemies: Array,    # [{"archetype_id": str, "rank": str}]
    victory_stars: int,
    has_recon_unit: bool,
    wave_env: Dictionary
) -> Dictionary:
    # 返回:
    # {
    #   "harvests": [
    #     {"card_id": str, "dimension": str, "old_val": float, "new_val": float, "delta": float},
    #     ...
    #   ],
    #   "reveal_events": [
    #     {"event_id": str, "title": str, "description": str, "rewards": Array},
    #     ...
    #   ],
    #   "newly_unlocked_eom": [str],  # 新解锁的敌源MOD ID列表
    #   "newly_discovered_branches": [str],  # 新发现的情报进化分支ID列表
    # }
```

---

#### [R5] `managers/battle/battle_damage_system.gd` — 战斗伤害系统

**修订范围**：`generate_battle_completion_drops()` 方法中新增情报收获生成

**修改位置**：`generate_battle_completion_drops()` 方法末尾，在返回前

**修改前**：
```gdscript
func generate_battle_completion_drops(...) -> Dictionary:
    # ... 现有逻辑 ...
    return battle_result
```

**修改后**：
```gdscript
func generate_battle_completion_drops(...) -> Dictionary:
    # ... 现有逻辑 ...

    # 🆕 生成情报收获数据
    var idm: Node = _get_autoload_node("IntelDiscoveryManager")
    if idm != null and idm.has_method("generate_battle_intel_harvest"):
        var defeated_list: Array = _collect_defeated_enemy_info()  # 🆕 辅助方法
        var intel_harvest: Dictionary = idm.generate_battle_intel_harvest(
            defeated_list, victory_stars,
            _get_recon_fragment_bonus_multiplier() > 0.0,
            current_env if current_env else {}
        )
        battle_result["intel_harvest"] = intel_harvest

        # 🆕 如果有敌源MOD碎片掉落
        if intel_harvest.get("eom_fragments", {}).size() > 0:
            battle_result["eom_fragments"] = intel_harvest["eom_fragments"]

    return battle_result
```

**新增辅助方法**：

| 方法 | 用途 |
|------|------|
| `_collect_defeated_enemy_info()` | 收集本局击败的所有敌人信息（archetype_id + rank） |

---

#### [R6] `scenes/ui/intel_harvest_display.gd` — 新增

**UI组件**：在战斗结算面板中显示情报收获

**功能**：
- 显示4个维度的进度条（带增长动画）
- 显示每个维度的当前百分比和增长量
- 如果触发了揭示，显示揭示标题（点击可展开详情）
- 使用情报维度的主题色（蓝/橙/绿/紫）

**预期尺寸**：约 380×200px，可滚动

---

#### [R7] `scenes/ui/intel_reveal_popup.gd` — 新增

**UI组件**：揭示事件弹窗

**功能**：
- 从结算面板底部弹出
- 显示揭示标题 + 描述 + 奖励列表
- 带有光效/粒子动画（紫色主题）
- 自动3秒后关闭，或点击关闭
- 多个揭示事件可排队显示

---

#### [R8] `scenes/ui/battle_result_dialog.gd` — 战斗结果对话框

**修订范围**：`create()` 静态方法中，在奖励列表之前插入情报收获区域

**修改位置**：`create()` 方法中，在遍历 blueprints 掉落循环之前

**修改前**：
```gdscript
# 相位场经验结算
# ...（约第100行）
# 掉落展示
for bp_info in blueprints:
    # ...
```

**修改后**：
```gdscript
# 相位场经验结算
# ...（保持不变）

# 🆕 情报收获展示
var intel_harvest: Dictionary = reward_summary.get("intel_harvest", {})
if not intel_harvest.is_empty():
    var IntelHarvestScene = preload("res://scenes/ui/intel_harvest_display.tscn")
    var harvest_ui: Control = IntelHarvestScene.instantiate()
    harvest_ui.set_data(intel_harvest)
    content_box.add_child(harvest_ui)

# 🆕 揭示事件弹窗（延迟0.8秒显示，在奖励列表展示后）
var reveal_events: Array = intel_harvest.get("reveal_events", [])
if reveal_events.size() > 0:
    var RevealPopupScene = preload("res://scenes/ui/intel_reveal_popup.tscn")
    # 通过Timer延迟显示

# 掉落展示（保持不变）
for bp_info in blueprints:
    # ...
```

**新增import**：
```gdscript
const IntelHarvestScene = preload("res://scenes/ui/intel_harvest_display.tscn")
const IntelRevealPopupScene = preload("res://scenes/ui/intel_reveal_popup.tscn")
```

---

#### [R9] `scenes/ui/battle_result_panel.gd` — 战斗结算面板（备用）

**修订范围**：与 R8 类似，在 `_fetch_drops()` 之后插入情报收获区域

**修改位置**：`set_battle_result()` 方法中，在 `_fetch_drops()` 调用之后

**修改内容**：与 R8 相同的情报收获UI + 揭示事件弹窗，适配 Panel 布局

---

### === Phase 2 修订 ===

---

#### [R10] `resources/game_constants.gd` — 游戏常量

**新增常量**：

```gdscript
## 🆕 敌源MOD系统
const ENEMY_ORIGIN_MOD_SLOT_NAME: String = "D"        # 敌源MOD槽位名
const ENEMY_ORIGIN_MOD_SLOT_UNLOCK_INTEL: float = 0.30  # D槽解锁所需最低素材情报
const ENEMY_ORIGIN_MOD_MAX_TIER: int = 3                # 敌源MOD最大等级
const EOM_FRAGMENT_DROP_CHANCE: float = 0.25            # 敌源MOD碎片掉落基础概率
const EOM_FRAGMENT_PER_DROP: int = 1                    # 每次掉落数量

## 🆕 情报维度权重（计算总情报时使用）
const INTEL_DIMENSION_WEIGHTS: Dictionary = {
    "basic": 0.30,
    "tactical": 0.30,
    "material": 0.25,
    "secret": 0.15,
}
```

---

#### [R11] `data/enemy_origin_mods.gd` — 新增

纯新增文件。参见实现计划3.2.2节。

---

#### [R12] `scripts/systems/enemy_origin_mod_manager.gd` — 新增

**职责**：
- 管理敌源MOD的解锁状态、碎片进度
- 处理敌源MOD装备/卸载
- 处理敌源MOD等级提升（随素材情报自动升级）

**关键接口**：
```gdscript
class_name EnemyOriginModManager
extends Node

## 获取所有已解锁的敌源MOD
func get_unlocked_mods() -> Array[Dictionary]

## 获取某张卡当前装备的敌源MOD
func get_equipped_eom(card_id: String) -> String

## 装备敌源MOD
func equip_eom(card_id: String, mod_id: String, bpm_ref: Node) -> bool

## 检查敌源MOD是否可装备到某卡
func can_equip_eom(card_id: String, mod_id: String) -> bool

## 获取敌源MOD当前有效等级（基于素材情报）
func get_effective_tier(mod_id: String) -> int

## 添加敌源MOD碎片
func add_fragment(mod_id: String, amount: int) -> int  # 返回当前碎片总数
```

---

#### [R13] `scenes/ui/card_enhancement_panel.gd` — 卡牌强化面板

**修订范围**：新增D槽（敌源MOD槽位）UI + 相关交互逻辑

**修改位置**：在现有ModSection之后，新增一个EnemyOriginModSection

**新增UI元素**：
```
现有ModSection（A/B/C槽）
    ↓
🆕 EnemyOriginModSection（D槽）
    ├── 标题："敌源改造 (D槽)"
    ├── 当前装备显示（图标 + 名称 + 等级）
    ├── 效果预览
    ├── "更换敌源改造" 按钮 → 弹出选择器
    └── 碎片进度条（如果未解锁）
```

**新增方法**：

| 方法 | 用途 |
|------|------|
| `_update_enemy_origin_mod_section()` | 更新D槽UI显示 |
| `_on_eom_select_pressed()` | 打开敌源MOD选择器 |
| `_show_eom_selector_popup()` | 弹窗显示可装备的敌源MOD列表 |
| `_on_eom_equipped(mod_id)` | 装备选中的敌源MOD |

**修改的方法**：

| 方法 | 修改内容 |
|------|----------|
| `_update_detail_panel()` | 新增调用 `_update_enemy_origin_mod_section()` |
| `_ready()` | 新增连接敌源MOD相关信号 |
| `_clear_detail_panel()` | 清除D槽UI |

---

#### [R14] `scenes/ui/card_enhancement_panel.tscn` — 场景文件

**修改内容**：在DetailPanel的ModSection下方新增：
- `EnemyOriginModSection` (VBoxContainer)
  - `EomStatusLabel` (Label)
  - `EomIcon` (TextureRect)
  - `EomNameLabel` (Label)
  - `EomTierLabel` (Label)
  - `EomEffectLabel` (RichTextLabel)
  - `EomChangeButton` (Button)
  - `EomFragmentBar` (ProgressBar)

---

### === Phase 3 修订 ===

---

#### [R15] `data/intel_evolution_branches.gd` — 新增

纯新增文件。参见实现计划3.3.2节。

---

#### [R16] `scripts/systems/intel_evolution_manager.gd` — 新增

**职责**：
- 检查情报进化分支是否可发现
- 管理已发现/已领取的分支状态
- 提供查询接口

**关键接口**：
```gdscript
class_name IntelEvolutionManager
extends Node

## 检查并发现新的情报进化分支
func check_and_discover_branches() -> Array:
    # 返回新发现的分支列表

## 获取某张卡的所有进化选项（含情报分支）
func get_evolution_options_for_card(card_id: String, bpm_ref: Node) -> Array[Dictionary]:
    # 合并常规路线 + 已发现的情报分支

## 领取情报进化分支
func claim_branch(card_id: String, branch_id: String) -> bool

## 获取已发现的分支列表
func get_discovered_branches() -> Array[Dictionary]
```

---

#### [R17] `managers/evolution/card_evolution_manager.gd` — 进化管理器

**修订范围**：`get_evolution_options()` 方法扩展

**修改前**：
```gdscript
static func get_evolution_options(card_id: String) -> Dictionary:
    var evo_1: String = UnitLineageConfig.get_evolution_1_target(card_id)
    var branches: Dictionary = UnitLineageConfig.get_all_faction_targets(card_id)
    return {
        "base_card_id": card_id,
        "evolution_1": evo_1,
        "faction_branches": branches,
    }
```

**修改后**：
```gdscript
static func get_evolution_options(card_id: String) -> Dictionary:
    var evo_1: String = UnitLineageConfig.get_evolution_1_target(card_id)
    var branches: Dictionary = UnitLineageConfig.get_all_faction_targets(card_id)

    # 🆕 查询情报进化分支
    var intel_branches: Array = []
    var iem: Node = _get_autoload_node("IntelEvolutionManager")
    if iem != null and iem.has_method("get_evolution_options_for_card"):
        intel_branches = iem.get_evolution_options_for_card(card_id, bpm_ref)

    return {
        "base_card_id": card_id,
        "evolution_1": evo_1,
        "faction_branches": branches,
        "intel_branches": intel_branches,  # 🆕 情报进化分支
    }
```

**同步修改**：
- `can_evolve_blueprint()`：新增对情报分支 `intel_branches` 的检查
- `evolve_blueprint()`：新增处理情报分支特殊奖励（extra_mod_slot, special_ability, cross_class）

---

#### [R18] `scenes/ui/evolution_atlas_view.gd` — 进化总览图

**修订范围**：支持隐藏分支的可视化

**修改内容**：

| 修改点 | 说明 |
|--------|------|
| `_build_ui()` | 无需修改 |
| `refresh()` | 新增查询情报进化分支，用虚线+锁图标显示未发现的分支 |
| 新增 `_draw_hidden_branches()` | 在已知路线旁边绘制"?"提示 |
| 新增 `_animate_branch_reveal()` | 分支发现时的展开动画 |
| `card_selected` 信号 | 无需修改 |

**新增视觉元素**：
- 未发现的隐藏分支：虚线 + 紫色锁图标
- 刚发现的分支：金色闪光动画 + "新发现！"标签
- 已领取的分支：与常规路线一致的实线

---

#### [R19] `scenes/ui/unit_progression_detail_view.gd` — 单位详情

**修订范围**：进化路线展示区域新增情报分支

**修改位置**：`_rebuild_content()` 方法中，进化路线列表之后

**修改内容**：
```gdscript
# 现有进化路线展示
# ...

# 🆕 情报进化分支展示
var intel_branches: Array = []
var iem: Node = get_node_or_null("/root/IntelEvolutionManager")
if iem and iem.has_method("get_evolution_options_for_card"):
    var bpm = get_node_or_null("/root/BlueprintManager")
    intel_branches = iem.get_evolution_options_for_card(_card_id, bpm)

for ib in intel_branches:
    var branch_box := _create_intel_branch_entry(ib)
    _content.add_child(branch_box)
```

---

#### [R20] `scenes/ui/intelligence_hub_panel.gd` — 情报中心

**修订范围**：进化图谱Tab中集成隐藏分支提示

**修改位置**：`_setup_evolution_tab()` 方法

**修改内容**：
```gdscript
func _setup_evolution_tab() -> void:
    # ... 现有代码 ...
    _atlas = EvolutionAtlasView.new()
    _atlas.name = "EvolutionAtlas"
    # 🆕 连接分支发现信号
    var iem: Node = get_node_or_null("/root/IntelEvolutionManager")
    if iem and iem.has_signal("intel_branch_discovered"):
        iem.intel_branch_discovered.connect(_on_intel_branch_discovered)
    # ...
```

---

## 三、回退策略

### 3.1 功能开关

在每个Phase中，所有新功能通过一个**功能开关**控制：

```gdscript
## resources/game_constants.gd
const ENABLE_INTEL_DIMENSIONS: bool = true   # Phase 1
const ENABLE_ENEMY_ORIGIN_MODS: bool = true   # Phase 2
const ENABLE_INTEL_EVOLUTION: bool = true     # Phase 3
```

**回退操作**：只需将对应开关设为 `false`，所有新代码路径都会被跳过，
系统回退到修改前的行为。

### 3.2 分支策略

建议为每个Phase创建独立的Git分支：

```
main
  └── feature/intel-dimensions       (Phase 1)
  └── feature/enemy-origin-mods       (Phase 2)
  └── feature/intel-evolution         (Phase 3)
```

每个Phase完成后合并回main，确保每个Phase可独立回退。

### 3.3 存档版本标记

```gdscript
## 存档文件头新增版本字段
var _save_version: int = 2  # v1=旧格式, v2=4维情报+敌源MOD
```

如果需要回退，存档加载时根据 `_save_version` 字段决定是否使用新逻辑。

---

## 四、测试检查清单

### Phase 1 测试

| # | 测试项 | 预期结果 | 优先级 |
|---|--------|----------|--------|
| 1 | 旧存档加载 | 自动迁移，4维情报正确分配 | P0 |
| 2 | 战斗后情报维度增长 | 4个维度各自正确增长 | P0 |
| 3 | 首次遭遇情报 | basic维度+25% | P0 |
| 4 | 击败精英情报 | 战术+8-15%，素材+5-10% | P0 |
| 5 | 3星胜利加成 | 所有维度+10% | P1 |
| 6 | 战斗结算UI显示 | 4维进度条正确渲染 | P0 |
| 7 | 揭示事件触发 | 50%战术情报触发弱点揭示 | P0 |
| 8 | 揭示事件弹窗 | 动画正确播放，3秒自动关闭 | P1 |
| 9 | 情报100%触发 | evolution解锁信号正确发出 | P0 |
| 10 | 功能开关关闭 | 所有新逻辑被跳过，行为与修改前一致 | P0 |

### Phase 2 测试

| # | 测试项 | 预期结果 | 优先级 |
|---|--------|----------|--------|
| 11 | 敌源MOD解锁 | 素材情报50%时触发解锁 | P0 |
| 12 | 敌源MOD装备 | D槽正确显示，效果生效 | P0 |
| 13 | 敌源MOD等级 | 素材情报75%/100%时自动升级 | P0 |
| 14 | 敌源MOD碎片掉落 | 战斗中有概率掉落 | P1 |
| 15 | D槽UI显示 | card_enhancement_panel正确展示 | P0 |
| 16 | 敌源MOD更换 | 可自由更换已解锁的敌源MOD | P1 |

### Phase 3 测试

| # | 测试项 | 预期结果 | 优先级 |
|---|--------|----------|--------|
| 17 | 隐藏分支发现 | 满足情报条件时自动发现 | P0 |
| 18 | 隐藏分支在图谱显示 | 未发现=虚线，已发现=实线 | P0 |
| 19 | 隐藏分支进化 | 可通过情报分支执行进化 | P0 |
| 20 | 额外奖励生效 | extra_mod_slot / special_ability 正确应用 | P1 |
| 21 | 跨类型进化 | 跨类型分支的cross_class标记生效 | P1 |
| 22 | 进化确认对话框 | 显示分支名称和额外奖励 | P1 |

---

## 五、工作量估算

| Phase | 预计工时 | 关键路径 | 风险点 |
|-------|----------|----------|--------|
| Phase 1 | 3-4天 | intel_manual.gd重构 + 战斗结算UI | 存档迁移 |
| Phase 2 | 4-5天 | 敌源MOD数据定义 + card_enhancement_panel改造 | 战力平衡 |
| Phase 3 | 3-4天 | 情报进化分支数据 + 进化图谱UI | 与现有路线冲突 |
| Phase 4 | 2-3天 | 数据填充 + 平衡调优 + 存档兼容 | 数据量 |
| **总计** | **12-16天** | | |

---

## 六、里程碑验收标准

| 里程碑 | 验收标准 |
|--------|----------|
| **M1: Phase 1 完成** | 战斗结束后，结算界面显示4维情报进度条；首次达到50%战术情报时弹出揭示事件；旧存档可正常加载 |
| **M2: Phase 2 完成** | 击败火焰兵后素材情报达50%，解锁"热能抗性装甲"MOD；在强化面板D槽中可装备；战力计算包含敌源MOD效果 |
| **M3: Phase 3 完成** | 满足特定情报组合后，进化图谱中出现新的虚线分支；分支发现时有展开动画；可通过情报分支执行进化 |
| **M4: 全部完成** | 60+敌人类型都有揭示事件；20种敌源MOD可获取；8条情报进化分支可发现；新手引导包含情报系统教学 |
