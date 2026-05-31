# 📋 战场信息显示统一 + 删除攻防状态选择 — 详细执行计划

> **日期**：2026-05-31
> **目标**：
> 1. 战场点击单位时，统一使用 `BackpackPanel.CardDetailPopup`（背包同款弹窗）显示信息
> 2. 删除进攻/防守（field_stance）状态选择系统
> 3. 所有单位默认进攻姿态，自动推进

---

## 一、现状分析

### 1.1 当前战场信息显示方式

**触发流程**：
```
点击战场单位 → battle_click_overlay._do_unit_pick()
  → SignalBus.unit_selected.emit(unit, is_player, pos)
  → unit_info_panel.gd._on_unit_selected()
  → 显示 unit_info_panel（战场专用面板）
```

**问题**：`unit_info_panel` 是战场专用的独立面板，与背包/相位仪使用的 `CardDetailPopup` 样式不一致。

### 1.2 背包/相位仪信息显示方式

**背包**：`backpack_panel.gd` → `show_card_detail()` → `CardDetailPopup`（PopupPanel 弹窗）
**相位仪**：`bottom_instrument_bar.gd` → `_show_instrument_slot_card_detail()` → `BackpackPanelScript.open_card_detail()` → 同一个 `CardDetailPopup`

**两者共用同一个弹窗**，样式统一。

### 1.3 攻防状态选择系统（待删除）

**涉及文件**（仅3个，范围小）：

| 文件 | 引用位置 | 说明 |
|------|---------|------|
| `scenes/units/construct_unit.gd` | L74（变量）、L171（初始化）、L251/318（调用）、L906-927（函数定义） | `_field_stance_attack` 变量 + `set_field_stance_attack/defend()` + `is_field_stance_attack()` |
| `scenes/ui/unit_info_panel.gd` | L16-17（节点）、L35-38（信号）、L456-475（按钮同步+回调） | StanceRow UI + 进攻/防守按钮 |
| `scripts/battle/construct_unit_deploy.gd` | L43（初始化姿态） | 实体化时设置姿态 |
| `scenes/ui/unit_info_panel.tscn` | L80-101（StanceRow 节点树） | StanceRow/StanceHint/StanceAttackBtn/StanceDefendBtn |

**设计文档**：v5.0 文档 **没有** 攻防状态选择。核心设计原则是「自动对战，战前决策」。攻防选择是战中操作，违反设计意图。

---

## 二、执行计划

### Phase 1：删除攻防状态选择系统

#### Step 1.1：修改 `construct_unit.gd`

**文件**：`scenes/units/construct_unit.gd`（1155行）

**修改 A** — 删除 stance 变量（L74）：
```gdscript
# 删除此行：
var _field_stance_attack: bool = true
```

**修改 B** — 删除 stance 初始化（L171）：
```gdscript
# 在 _ready() 或初始化函数中删除：
_field_stance_attack = true
```

**修改 C** — 删除 stance 调用（L251）：
```gdscript
# 在 apply_card_grid_combat_started() 中删除：
set_field_stance_defend()
```
注意：`apply_card_grid_combat_started()` 函数本身需要保留（可能还有其他逻辑），仅删除 stance 调用那一行。

**修改 D** — 删除 stance 调用（L318）：
```gdscript
# 在 _on_unit_ready() 或类似函数中删除：
set_field_stance_defend()
```

**修改 E** — 删除 3 个 stance 函数（L906-927）：
```gdscript
# 删除整个函数：
func set_field_stance_attack() -> void:
	...
func set_field_stance_defend() -> void:
	...
func is_field_stance_attack() -> bool:
	...
```

**修改 F** — 搜索 `_field_stance_attack` 在物理过程或 AI 中的引用：
如果 `_field_stance_attack` 在移动逻辑中被检查（如"只有进攻姿态才向敌方推进"），需要移除该检查，让所有单位始终推进。

```gdscript
# 如果有这样的代码：
if _field_stance_attack:
    _move_toward_enemy()
# 改为：
_move_toward_enemy()  # 始终推进
```

**修改 G** — 删除 `_should_card_grid_defend_stance()` 函数（L239）：
```gdscript
# 删除整个函数
```

**修改 H** — 修改 `apply_card_grid_combat_started()`（L248-254）：
```gdscript
# 修改前：
func apply_card_grid_combat_started() -> void:
	if not is_player:
		return
	if GameManager and GameManager.is_card_grid_battle():
		set_field_stance_defend()       # ← 删除此行
		_enforce_card_grid_lane_alignment()

# 修改后：
func apply_card_grid_combat_started() -> void:
	if not is_player:
		return
	if GameManager and GameManager.is_card_grid_battle():
		_enforce_card_grid_lane_alignment()
```

#### Step 1.2：修改 `construct_unit_deploy.gd`

**文件**：`scripts/battle/construct_unit_deploy.gd`

**修改** — L43，删除 stance 设置：
```gdscript
# 删除此行：
u._field_stance_attack = not should_card_grid_defend_stance()
```

如果 `materialize_deploy_ghost()` 中有引用 `_field_stance_attack` 的地方也需要一并删除：
```gdscript
# 删除此行（L43 原始位置附近）：
u._field_stance_attack = not should_card_grid_defend_stance()
```

#### Step 1.3：修改 `unit_info_panel.gd`

**文件**：`scenes/ui/unit_info_panel.gd`（749行）

**修改 A** — 删除 stance 相关节点引用（L16-17）：
```gdscript
# 删除：
@onready var stance_row: HBoxContainer = $Margin/VBox/StanceRow
@onready var stance_attack_btn: Button = $Margin/VBox/StanceRow/StanceAttackBtn
@onready var stance_defend_btn: Button = $Margin/VBox/StanceRow/StanceDefendBtn
```

**修改 B** — 删除 stance 信号连接（L35-38）：
```gdscript
# 删除：
if stance_attack_btn and not stance_attack_btn.pressed.is_connected(_on_stance_attack_pressed):
	stance_attack_btn.pressed.connect(_on_stance_attack_pressed)
if stance_defend_btn and not stance_defend_btn.pressed.is_connected(_on_stance_defend_pressed):
	stance_defend_btn.pressed.connect(_on_stance_defend_pressed)
```

**修改 C** — 删除 _ready() 中的 stance 初始化（L28-30）：
```gdscript
# 删除：
if stance_row:
	stance_row.visible = false
```

**修改 D** — 删除 base_desc 中的攻防描述（L416）：
```gdscript
# 修改前：
var base_desc := "可选「进攻」向敌侧推进，或「防守」固守原位（仍可射击）；选中后点地面可沿 X 轴微调站位。"

# 修改后：
var base_desc := "自动向敌侧推进，在射程内交战。选中后可点击地面微调站位。"
```

**修改 E** — 删除 4 个 stance 函数（L456-475）：
```gdscript
# 删除整个函数：
func _set_stance_row_for_unit(unit: Node) -> void:
	...

func _sync_stance_buttons(unit: Node) -> void:
	...

func _on_stance_attack_pressed() -> void:
	...

func _on_stance_defend_pressed() -> void:
	...
```

**修改 F** — 搜索 `_set_stance_row_for_unit()` 的调用点并删除：
```gdscript
# 在 _show_player_unit() 中删除：
_set_stance_row_for_unit(unit)
```

#### Step 1.4：修改 `unit_info_panel.tscn`

**文件**：`scenes/ui/unit_info_panel.tscn`

**操作** — 删除 StanceRow 节点（L80-101）：
```
删除以下节点（Godot编辑器中右键删除）：
- StanceRow (HBoxContainer)
  - StanceHint (Label, text="场上姿态")
  - StanceAttackBtn (Button, text="进攻")
  - StanceDefendBtn (Button, text="防守")
```

---

### Phase 2：战场信息显示统一为 CardDetailPopup

**核心思路**：点击战场单位时，不再显示 `unit_info_panel`，而是弹出 `BackpackPanel.CardDetailPopup`（背包同款弹窗）。

#### Step 2.1：修改 `battle_click_overlay.gd`

**文件**：`scenes/ui/battle_click_overlay.gd`

**修改** — `_do_unit_pick()` 函数中，点击我方单位后弹出 CardDetailPopup：

在 `_do_unit_pick()` 的单位选中分支中（`SignalBus.unit_selected.emit(...)` 附近），添加卡牌详情弹窗逻辑：

```gdscript
# 在现有的 unit_selected.emit 之后，添加：
if result.is_player and result.unit.has_method("get_stats"):
	var stats = result.unit.get_stats()
	if stats and not stats.platform_card_id.is_empty():
		var card: CardResource = DefaultCardsData.get_card_by_id(stats.platform_card_id)
		if card != null:
			BackpackPanelScript.open_card_detail(card, null)
```

**注意**：需要确认 `DefaultCardsData` 在此文件中是否已 preload 或可用。如果未引入，需要添加：
```gdscript
const BackpackPanelScript = preload("res://scenes/ui/backpack_panel.gd")
const DefaultCardsData = preload("res://data/default_cards.gd")
```

#### Step 2.2：决定 unit_info_panel 的处置方式

**方案A（推荐）**：保留 `unit_info_panel` 但不再显示攻防行，用于显示**敌方单位**的信息（因为敌方单位没有 CardResource，需要专用面板）。

**方案B**：完全删除 `unit_info_panel`，敌方单位信息也用 CardDetailPopup 展示（需要为敌方创建临时的 CardResource 或改用通用弹窗）。

**推荐方案A**：
- 我方单位：用 `CardDetailPopup`（同背包/相位仪）
- 敌方单位：保留 `unit_info_panel`（已无攻防行，显示敌方信息）
- 点击空白区域：关闭所有弹窗

#### Step 2.3：修改信号处理逻辑

**修改** — `battle_click_overlay.gd` 的 `_do_unit_pick()`：

```gdscript
func _do_unit_pick(viewport_pos: Vector2) -> bool:
	# ... 现有的法则施法和部署逻辑保持不变 ...

	var result: Dictionary = bf.get_unit_at_position(viewport_pos)
	if not result.is_empty():
		if result.is_player:
			# 我方单位：用 CardDetailPopup 显示（同背包/相位仪）
			var unit = result.unit
			if unit and is_instance_valid(unit) and unit.has_method("get_stats"):
				var stats = unit.get_stats()
				if stats and not stats.platform_card_id.is_empty():
					var card: CardResource = DefaultCardsData.get_card_by_id(stats.platform_card_id)
					if card != null:
						BackpackPanelScript.open_card_detail(card, null)
			# 同时发射信号给其他监听者（如选中高亮）
			if SignalBus:
				SignalBus.unit_selected.emit(result.unit, true, Vector2.ZERO)
		else:
			# 敌方单位：保留 unit_info_panel 显示
			if SignalBus:
				SignalBus.unit_selected.emit(result.unit, false, Vector2.ZERO)
		return true
	# ... 现有的移动逻辑保持不变 ...
```

#### Step 2.4：关闭弹窗逻辑

确保 `battle_click_overlay.gd` 中已有"点击空白区域关闭"的逻辑：

```gdscript
# 已有逻辑（L164-172）— 确认 CardDetailPopup 也会被关闭
if panel != null and panel.visible:
	var panel_rect = panel.get_global_rect()
	if not panel_rect.has_point(mb.global_position):
		panel.hide()
		# 新增：同时关闭 CardDetailPopup
		var bp = NodeFinder.get_backpack_panel()
		if bp and bp.has_method("hide_card_detail"):
			bp.hide_card_detail()
		_safe_set_input_handled()
		return
```

---

## 三、文件变更清单

| # | 文件 | 操作 | 修改量 |
|---|------|------|--------|
| 1 | `scenes/units/construct_unit.gd` | 删除 stance 变量/函数/调用 | ~30行删除 |
| 2 | `scripts/battle/construct_unit_deploy.gd` | 删除 stance 赋值 | 1行删除 |
| 3 | `scenes/ui/unit_info_panel.gd` | 删除 stance 节点引用/信号/函数/描述 | ~30行删除 |
| 4 | `scenes/ui/unit_info_panel.tscn` | 删除 StanceRow 节点 | ~22行删除 |
| 5 | `scenes/ui/battle_click_overlay.gd` | 添加 CardDetailPopup 调用逻辑 | ~10行新增 |

**总计**：5个文件，~100行变更（以删除为主）

---

## 四、执行顺序

```
Step 1.1  → 修改 construct_unit.gd（删除 stance）
Step 1.2  → 修改 construct_unit_deploy.gd（删除 stance 赋值）
Step 1.3  → 修改 unit_info_panel.gd（删除 stance UI + 修改描述）
Step 1.4  → 修改 unit_info_panel.tscn（删除 StanceRow 节点）  [Godot编辑器]
Step 2.1  → 修改 battle_click_overlay.gd（我方单位改用 CardDetailPopup）
Step 2.2  → 验证敌方单位仍用 unit_info_panel
Step 2.3  → 确保关闭弹窗逻辑正确
```

**建议**：先执行 Phase 1（删除 stance），运行游戏验证无编译错误和战斗异常后，再执行 Phase 2（统一信息显示）。

---

## 五、验证清单

- [ ] 编译无错误（`--check-only`）
- [ ] 战斗中点击我方单位 → 弹出 CardDetailPopup（同背包样式）
- [ ] 战斗中点击敌方单位 → 弹出 unit_info_panel（无攻防行）
- [ ] 点击空白区域 → 关闭所有弹窗
- [ ] 所有单位始终向敌方推进（无防守固守行为）
- [ ] 背包中点击卡牌 → CardDetailPopup（不变）
- [ ] 相位仪中点击卡牌 → CardDetailPopup（不变）
- [ ] 格子战术（card_grid_battle）模式下战斗正常

---

## 六、风险评估

| 风险 | 概率 | 缓解措施 |
|------|------|---------|
| `_field_stance_attack` 在移动AI中有引用但被遗漏 | 低 | grep 确认仅3个文件引用，已全部覆盖 |
| CardDetailPopup 依赖 BackpackPanel 可用性 | 中 | BackpackPanel 在 Main 场景常驻，战斗中始终可用 |
| 敌方单位无法用 CardDetailPopup | 无 | 敌方保留 unit_info_panel，不受影响 |
| 删除 StanceRow 节点后 .tscn 中 parent path 失效 | 无 | 上下文节点不受影响 |

---

> **生成日期**：2026-05-31
> **预估工作量**：30-45分钟
