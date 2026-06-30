extends Control
class_name IntelRevealPopup
## v6.7: 揭示事件弹窗（单维度化）
## 在战斗结算中，当情报揭示事件触发时弹出
## 支持多个揭示事件排队显示
##
## 使用方式：
##   var popup = IntelRevealPopup.new(parent_node)
##   popup.show_reveals(reveal_events_array)
##
## 注意：IntelDimensions preload 保留以兼容潜在的外部调用，单维度化后弹窗
## 展示的揭示事件已不含 dimension 区分（每敌人每档仅1条事件）。

const IntelDimensions = preload("res://data/intel_dimensions.gd")
const EnemyOriginMods = preload("res://data/enemy_origin_mods.gd")

signal all_reveals_shown()

var _parent_node: Node = null
var _reveal_queue: Array = []
var _current_reveal_index: int = 0
var _auto_close_timer: Timer = null
var _is_showing: bool = false

func _ready() -> void:
	## 默认隐藏
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

## 静态工厂：创建并添加到父节点
static func create(parent: Node) -> IntelRevealPopup:
	var popup := IntelRevealPopup.new()
	popup._parent_node = parent
	parent.add_child(popup)
	return popup

func _build_ui() -> void:
	## 暗色遮罩
	var dim := ColorRect.new()
	dim.name = "DimRect"
	dim.color = Color(0.0, 0.0, 0.0, 0.3)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	## 中央弹窗容器
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "RevealPanel"
	panel.custom_minimum_size = Vector2(360, 200)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.04, 0.14, 0.97)
	panel_style.border_color = Color(0.65, 0.3, 0.95, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.shadow_color = Color(0.5, 0.2, 0.9, 0.3)
	panel_style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	## 图标行
	var icon_row := HBoxContainer.new()
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon_lbl := Label.new()
	icon_lbl.name = "IconLabel"
	icon_lbl.text = "✦"
	icon_lbl.add_theme_font_size_override("font_size", 24)
	icon_lbl.add_theme_color_override("font_color", Color(0.9, 0.6, 1.0, 1.0))
	icon_row.add_child(icon_lbl)
	vbox.add_child(icon_row)

	## 标题
	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = ""
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.8, 1.0, 1.0))
	vbox.add_child(title_lbl)

	## 描述
	var desc_lbl := Label.new()
	desc_lbl.name = "DescLabel"
	desc_lbl.text = ""
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.7, 0.85, 1.0))
	vbox.add_child(desc_lbl)

	## 奖励区
	var reward_box := VBoxContainer.new()
	reward_box.name = "RewardBox"
	reward_box.add_theme_constant_override("separation", 4)
	reward_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(reward_box)

	## 关闭按钮
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "知道了"
	close_btn.custom_minimum_size = Vector2(100, 28)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.3, 0.15, 0.5, 0.9)
	btn_style.set_border_width_all(1)
	btn_style.set_border_color(Color(0.6, 0.3, 0.9, 0.6))
	btn_style.set_corner_radius_all(6)
	close_btn.add_theme_stylebox_override("normal", btn_style)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0, 1.0))
	close_btn.pressed.connect(_on_close_pressed)
	close_row.add_child(close_btn)
	vbox.add_child(close_row)

	center.add_child(panel)

	## 进度指示
	var page_row := HBoxContainer.new()
	page_row.name = "PageRow"
	page_row.alignment = BoxContainer.ALIGNMENT_CENTER
	page_row.anchor_top = 1.0
	page_row.anchor_bottom = 1.0
	page_row.offset_top = -24
	var page_lbl := Label.new()
	page_lbl.name = "PageLabel"
	page_lbl.text = ""
	page_lbl.add_theme_font_size_override("font_size", 10)
	page_lbl.add_theme_color_override("font_color", Color(0.55, 0.5, 0.65, 1.0))
	page_row.add_child(page_lbl)
	add_child(page_row)

	## 自动关闭计时器
	_auto_close_timer = Timer.new()
	_auto_close_timer.name = "AutoCloseTimer"
	_auto_close_timer.wait_time = 4.0
	_auto_close_timer.one_shot = true
	_auto_close_timer.timeout.connect(_on_auto_close)
	add_child(_auto_close_timer)

## 显示揭示事件队列
func show_reveals(events: Array) -> void:
	_reveal_queue.clear()
	for e in events:
		if e is Dictionary and not e.is_empty():
			_reveal_queue.append(e)
	if _reveal_queue.is_empty():
		return
	_current_reveal_index = 0
	_show_current_reveal()

## 显示当前揭示事件
func _show_current_reveal() -> void:
	if _current_reveal_index >= _reveal_queue.size():
		_hide_popup()
		all_reveals_shown.emit()
		return

	var event: Dictionary = _reveal_queue[_current_reveal_index]
	_is_showing = true
	visible = true

	## 更新内容
	var icon_lbl: Label = get_node_or_null("CenterContainer/RevealPanel/MarginContainer/ContentVBox/HBoxContainer/IconLabel")
	var title_lbl: Label = get_node_or_null("CenterContainer/RevealPanel/MarginContainer/ContentVBox/TitleLabel")
	var desc_lbl: Label = get_node_or_null("CenterContainer/RevealPanel/MarginContainer/ContentVBox/DescLabel")
	var reward_box: VBoxContainer = get_node_or_null("CenterContainer/RevealPanel/MarginContainer/ContentVBox/RewardBox")
	var page_lbl: Label = get_node_or_null("PageRow/PageLabel")

	if icon_lbl:
		icon_lbl.text = event.get("icon", "✦")
	if title_lbl:
		title_lbl.text = event.get("title", "情报揭示")
	if desc_lbl:
		desc_lbl.text = event.get("desc", "")

	## 奖励文本
	if reward_box:
		for child in reward_box.get_children():
			child.queue_free()
		var rewards: Array = event.get("rewards", [])
		for reward in rewards:
			if not reward is Dictionary:
				continue
			var r_text: String = _reward_to_text(reward)
			if not r_text.is_empty():
				var r_lbl := Label.new()
				r_lbl.text = "→ " + r_text
				r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				r_lbl.add_theme_font_size_override("font_size", 11)
				r_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5, 1.0))
				reward_box.add_child(r_lbl)

	## 页码
	if page_lbl:
		if _reveal_queue.size() > 1:
			page_lbl.text = "%d / %d" % [_current_reveal_index + 1, _reveal_queue.size()]
		else:
			page_lbl.text = ""

	## 入场动画
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)

	## 重启自动关闭计时器
	_auto_close_timer.stop()
	_auto_close_timer.start()

func _hide_popup() -> void:
	_is_showing = false
	_auto_close_timer.stop()
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.3)
	tween.tween_callback(func(): visible = false)

func _on_close_pressed() -> void:
	_current_reveal_index += 1
	if _current_reveal_index >= _reveal_queue.size():
		_hide_popup()
		all_reveals_shown.emit()
	else:
		_show_current_reveal()

func _on_auto_close() -> void:
	_current_reveal_index += 1
	if _current_reveal_index >= _reveal_queue.size():
		_hide_popup()
		all_reveals_shown.emit()
	else:
		_show_current_reveal()

## 奖励转文本
func _reward_to_text(reward: Dictionary) -> String:
	match reward.get("type", ""):
		"stat_visibility":
			var val: String = reward.get("value", "")
			match val:
				"name_and_type": return "名称与类型已识别"
				"full_stats": return "完整参数已获取"
				"hidden_stats": return "隐藏属性已公开"
				"behavior_summary": return "行为模式已分析"
				"skill_list": return "技能列表已解析"
				"equipment_type": return "装备类型已确认"
				_: return "属性信息已解锁"
		"eom_unlock":
			var mod_id: String = reward.get("mod_id", "")
			# v6.7: mod_id 是英文 ID（如 EOM_INFANTRY_01），转中文名避免显示原始 ID
			var mod_name: String = _eom_display_name(mod_id)
			return "解锁敌源改造【%s】" % mod_name
		"eom_unlock_hint":
			return "发现敌源改造线索"
		"intel_branch_hint":
			return "发现进化线索"
		"intel_branch_unlock":
			var bid: String = reward.get("branch_id", "")
			return "解锁隐藏进化分支！"
		"lore_page":
			return "解锁世界观情报"
		_:
			return ""

## 是否正在显示
func is_showing() -> bool:
	return _is_showing

## v6.7: 敌源改造 mod_id 转中文名（原代码直接显示英文 ID）
func _eom_display_name(mod_id: String) -> String:
	if mod_id.is_empty():
		return "未知改造"
	var def: Dictionary = EnemyOriginMods.ENEMY_ORIGIN_MODS.get(mod_id, {})
	if not def.is_empty():
		return String(def.get("name", mod_id))
	return mod_id
