extends PanelContainer
## 左上角常驻资源面板：基础资源 + 情报数量。

var _labels: Dictionary = {}
var _row_nodes: Dictionary = {}
var _compact_mode: bool = true
const COMPACT_RESOURCE_KEYS: Array[String] = ["energy", "nano_materials"]
var _toggle_button: Button = null

func _ready() -> void:
	# 确保面板不阻止子元素点击，但阻止传递到背景
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_style()
	_build_ui()
	_connect_signals()
	_refresh_all()

func _setup_style() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.75)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.3, 0.4, 0.5)
	add_theme_stylebox_override("panel", style)

func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	var title = Label.new()
	title.text = "资源"
	title.add_theme_font_size_override("font_size", 12)
	title.modulate = Color(0.9, 0.95, 1.0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_toggle_button = Button.new()
	_toggle_button.text = "展开"
	_toggle_button.custom_minimum_size = Vector2(70, 32)
	_toggle_button.add_theme_font_size_override("font_size", 13)
	
	# 添加明显的按钮样式
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.3, 0.5, 0.8, 0.8)
	btn_style.set_corner_radius_all(4)
	_toggle_button.add_theme_stylebox_override("normal", btn_style)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.4, 0.6, 0.9, 0.9)
	hover_style.set_corner_radius_all(4)
	_toggle_button.add_theme_stylebox_override("hover", hover_style)
	
	_toggle_button.focus_mode = Control.FOCUS_NONE
	_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle_button.z_index = 10  # 确保按钮在最上层
	_toggle_button.tooltip_text = "点击展开/收起资源列表"  # 添加提示文本
	
	# 验证信号连接
	if not _toggle_button.pressed.is_connected(_on_toggle_pressed):
		_toggle_button.pressed.connect(_on_toggle_pressed)
		print("资源面板：已连接展开/收起按钮信号")
	
	header.add_child(_toggle_button)

	_add_resource_row(vbox, "energy", "⚡", "能量块", Color(1.0, 0.85, 0.3))
	_add_resource_row(vbox, "nano_materials", "📦", "纳米材料", Color(0.3, 0.8, 1.0))
	_add_resource_row(vbox, "research_points", "🔬", "研究点", Color(0.75, 0.55, 1.0))
	_add_resource_row(vbox, "alloy", "🔶", "合金", Color(1.0, 0.6, 0.2))
	_add_resource_row(vbox, "crystal", "💎", "晶体", Color(0.6, 0.3, 1.0))
	_add_resource_row(vbox, "lore", "📖", "情报", Color(0.9, 0.7, 0.2))
	_update_row_visibility()

func _add_resource_row(parent: Control, key: String, icon: String, name: String, color: Color) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)

	var icon_label = Label.new()
	icon_label.text = icon
	icon_label.add_theme_font_size_override("font_size", 12)
	icon_label.modulate = color
	icon_label.custom_minimum_size = Vector2(20, 0)
	hbox.add_child(icon_label)

	var name_label = Label.new()
	name_label.text = name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.modulate = Color(0.85, 0.85, 0.9)
	name_label.custom_minimum_size = Vector2(60, 0)
	hbox.add_child(name_label)

	var value_label = Label.new()
	value_label.name = key + "_value"
	value_label.text = "0"
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.modulate = color
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(value_label)

	_labels[key] = value_label
	_row_nodes[key] = hbox

func _on_toggle_pressed() -> void:
	_compact_mode = not _compact_mode
	_update_row_visibility()

func _update_row_visibility() -> void:
	for key in _row_nodes.keys():
		var row: Control = _row_nodes[key]
		if row == null:
			continue
		var should_show: bool = true
		if _compact_mode:
			should_show = COMPACT_RESOURCE_KEYS.has(String(key))
		row.visible = should_show
	
	if _toggle_button != null:
		_toggle_button.text = "展开" if _compact_mode else "收起"

func _connect_signals() -> void:
	if BasicResourceManager and BasicResourceManager.has_signal("resources_changed"):
		BasicResourceManager.resources_changed.connect(_on_resources_changed)

	if BlueprintManager and BlueprintManager.has_signal("fragments_changed"):
		BlueprintManager.fragments_changed.connect(_on_resources_changed)

	var lm = get_node_or_null("/root/LoreManager")
	if lm and lm.has_signal("lore_unlocked"):
		lm.lore_unlocked.connect(_on_lore_changed)

func _refresh_all() -> void:
	_refresh_basic_resources()
	_refresh_lore()

func _refresh_basic_resources() -> void:
	if not BasicResourceManager or not BasicResourceManager.has_method("get_all_totals"):
		return

	var totals = BasicResourceManager.get_all_totals()

	_update_label("nano_materials", int(totals.get("nano_materials", 0)))
	_update_label("energy", int(totals.get("energy_block", 0)))
	_update_label("research_points", int(totals.get("research_points", 0)))
	_update_label("alloy", int(totals.get("alloy", 0)))
	_update_label("crystal", int(totals.get("crystal", 0)))

func _refresh_lore() -> void:
	var lm = get_node_or_null("/root/LoreManager")
	if lm and lm.has_method("get_unlocked_lore"):
		var lore_data = lm.get_unlocked_lore()
		_update_label("lore", lore_data.size())

func _update_label(key: String, value: int) -> void:
	if _labels.has(key):
		_labels[key].text = _format_number(value)

func _format_number(num: int) -> String:
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	else:
		return str(num)

func _on_resources_changed() -> void:
	_refresh_basic_resources()

func _on_lore_changed(_lore_id: String, _lore_name: String) -> void:
	_refresh_lore()
