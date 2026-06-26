extends Control
class_name AFKSettlementDialog
## 挂机结算弹窗 — 停止/失败时显示累计奖励总账与战绩
## 仿 OfflineRewardDialog 的静态 create 模式，运行时动态构建 UI
## result 结构：
##   wins: int, losses: int, battles: int,
##   rewards: Dictionary ({item_id: count})

signal closed()

const _BG_PANEL := Color(0.03, 0.05, 0.10, 0.98)
const _BORDER := Color(0, 0.65, 1, 0.4)
const _ACCENT := Color(0, 0.94, 0.7, 1.0)
const _WARN := Color(1.0, 0.45, 0.35, 1.0)
const _TEXT := Color(0.8, 0.88, 1.0, 0.95)
const _TEXT_DIM := Color(0.6, 0.7, 0.85, 0.8)
const _BTN_BG := Color(0, 0.5, 0.38, 1.0)

const _DefaultCards = preload("res://data/default_cards.gd")
const _BasicResources = preload("res://data/basic_resources.gd")

var _result: Dictionary = {}


## 静态构造：parent 通常是 PopupLayer；result 见类注释
static func create(parent: Node, result: Dictionary) -> AFKSettlementDialog:
	var dialog := AFKSettlementDialog.new()
	dialog._result = result
	dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(dialog)
	dialog._build_ui()
	return dialog


func _build_ui() -> void:
	# 半透明遮罩（铺满整个屏幕）
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Panel 固定宽度 480 + 固定高度 580（720 视口留上下 70px 边距）。
	# 关键：用固定 custom_minimum_size 高度，让 ScrollContainer 在固定区域内滚动，
	# 而非让 VBox 内容把 Panel 撑到超出屏幕。
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(480, 580)
	var style := StyleBoxFlat.new()
	style.bg_color = _BG_PANEL
	style.border_color = _BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	# 根 VBox：铺满 Panel，标题/战绩（顶部）→ 奖励列表（中间弹性+滚动）→ 合计/按钮（底部）
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# 标题（失败用警示色，停止用强调色）
	var title := Label.new()
	var failed: bool = bool(_result.get("failed", false))
	title.text = "挂机结算" if not failed else "挂机结束（失败）"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", _WARN if failed else _ACCENT)
	vbox.add_child(title)

	# 战绩行
	var wins: int = int(_result.get("wins", 0))
	var losses: int = int(_result.get("losses", 0))
	var battles: int = wins + losses
	var info := Label.new()
	info.text = "共 %d 场  ·  胜 %d  ·  负 %d" % [battles, wins, losses]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", _TEXT_DIM)
	info.add_theme_font_size_override("font_size", 13)
	vbox.add_child(info)

	vbox.add_child(_make_separator())

	# 奖励明细 —— 放进 ScrollContainer，占据中间弹性空间，物品多时可滚动
	var rewards: Dictionary = _result.get("rewards", {})
	# ScrollContainer 弹性占据 VBox 中间区域，size_flags_vertical = EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	# 列表容器：ScrollContainer 的内容须有且仅一个 Control 子节点
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var total_count: int = 0
	if rewards.is_empty():
		var empty := Label.new()
		empty.text = "本次挂机无掉落奖励"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", _TEXT_DIM)
		list.add_child(empty)
	else:
		var rew_title := Label.new()
		rew_title.text = "累计掉落"
		rew_title.add_theme_color_override("font_color", _TEXT)
		rew_title.add_theme_font_size_override("font_size", 15)
		list.add_child(rew_title)

		# 按数量降序排列，便于一眼看到主力掉落
		var sorted_keys: Array = rewards.keys()
		sorted_keys.sort_custom(func(a, b): return int(rewards[a]) > int(rewards[b]))
		for key in sorted_keys:
			var cnt: int = int(rewards[key])
			total_count += cnt
			list.add_child(_make_reward_line(_display_name(String(key)), cnt))

	# 合计行（底部固定，在 ScrollContainer 之外）
	if not rewards.is_empty():
		vbox.add_child(_make_separator())
		var total := Label.new()
		total.text = "合计 %d 种 / %d 件" % [rewards.size(), total_count]
		total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		total.add_theme_color_override("font_color", _ACCENT)
		total.add_theme_font_size_override("font_size", 14)
		vbox.add_child(total)

	# 确认按钮（底部固定）
	vbox.add_child(_make_separator())
	var ok_btn := Button.new()
	ok_btn.text = "确认"
	ok_btn.custom_minimum_size = Vector2(0, 42)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = _BTN_BG
	btn_style.border_color = _ACCENT
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(8)
	ok_btn.add_theme_stylebox_override("normal", btn_style)
	ok_btn.add_theme_stylebox_override("hover", btn_style)
	ok_btn.add_theme_stylebox_override("pressed", btn_style)
	ok_btn.add_theme_color_override("font_color", Color.WHITE)
	ok_btn.add_theme_font_size_override("font_size", 16)
	ok_btn.pressed.connect(_on_ok)
	vbox.add_child(ok_btn)


func _on_ok() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	# ESC / 回车同样关闭
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_ok()


# ── UI 辅助 ──

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	return sep


func _make_reward_line(label_text: String, amount: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_lbl := Label.new()
	name_lbl.text = "· " + label_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", _TEXT_DIM)
	row.add_child(name_lbl)
	var amt_lbl := Label.new()
	amt_lbl.text = "×%d" % amount
	amt_lbl.add_theme_color_override("font_color", _TEXT)
	amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(amt_lbl)
	return row


## 掉落 item_id → 显示名解析
## accumulated_rewards 的 key 来自 DropEntry.item_id，可能是：
##   - 蓝图碎片 card_id（ww1_mp18 等）→ DefaultCards 解析
##   - 材料 id（nano/alloy/crystal 等）→ 货币名映射
##   - 其它 → 原样返回
func _display_name(item_id: String) -> String:
	# 基础货币材料
	match item_id:
		_BasicResources.ID_NANO_MATERIALS, "nano", "nano_material":
			return "纳米材料"
		_BasicResources.ID_ALLOY, "alloy":
			return "合金"
		_BasicResources.ID_CRYSTAL, "crystal":
			return "晶体"
		_BasicResources.ID_ENERGY_BLOCK, "energy_block":
			return "能量块"
		_BasicResources.ID_RESEARCH_POINTS, "research_points":
			return "研究点"
	# afk_mode_manager 对无 item_id 的掉落用占位 key "other" 累计，这里映射显示名
	match item_id:
		"other":
			return "其它"
	# 蓝图碎片/卡牌——复用 battle_result_dialog 的解析路径
	return _DefaultCards.get_safe_display_name(item_id)
