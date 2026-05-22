extends PanelContainer
## 顶部资源栏：显示关键资源（战斗能量、纳米材料、蓝图碎片等）

const GC = preload("res://resources/game_constants.gd")
const BasicResources = preload("res://data/basic_resources.gd")

var _energy_label: Label
var _basic_nano_label: Label
var _nano_material_label: Label
var _alloy_label: Label
var _crystal_label: Label
var _blueprint_count_label: Label
var _lore_count_label: Label

#region agent log
func _agent_log(hypothesis_id: String, message: String, data: Dictionary) -> void:
	var f := FileAccess.open("debug-8fcb79.log", FileAccess.READ_WRITE)
	if f == null:
		return
	f.seek_end()
	var payload := {
		"sessionId": "8fcb79",
		"runId": "energy_visibility_v1",
		"hypothesisId": hypothesis_id,
		"location": "scenes/ui/resource_bar.gd",
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion

func _ready() -> void:
	custom_minimum_size = Vector2(0, 40)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_build_ui()
	_connect_signals()
	_refresh_all()
	#region agent log
	var em := EnergyManager
	var sb := SignalBus
	_agent_log("H1_ui_not_connected", "_ready_post", {
		"has_energy_label": _energy_label != null,
		"energy_label_text": _energy_label.text if _energy_label else "",
		"EnergyManager_null": em == null,
		"EnergyManager_has_energy_changed_signal": (em != null and em.has_signal("energy_changed")),
		"EnergyManager_has_get_energy": (em != null and em.has_method("get_energy")),
		"EnergyManager_has_get_current": (em != null and em.has_method("get_current")),
		"EnergyManager_has_get_max": (em != null and em.has_method("get_max")),
		"SignalBus_null": sb == null,
		"SignalBus_has_energy_changed": (sb != null and sb.has_signal("energy_changed")),
	})
	#endregion

func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.name = "ResourceBar"
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	# 战斗能量
	_energy_label = _create_resource_item(hbox, "⚡", "战斗能量", Color(1.0, 0.85, 0.3, 1.0))

	# 基本纳米颗粒
	_basic_nano_label = _create_resource_item(hbox, "🔷", "基本纳米", Color(0.3, 0.8, 1.0, 1.0))

	# 纳米材料
	_nano_material_label = _create_resource_item(hbox, "🔷", "纳米材料", Color(0.3, 0.8, 1.0, 1.0))

	# 合金
	_alloy_label = _create_resource_item(hbox, "🔶", "合金", Color(1.0, 0.6, 0.2, 1.0))

	# 晶体
	_crystal_label = _create_resource_item(hbox, "💎", "晶体", Color(0.6, 0.3, 1.0, 1.0))

	# 蓝图碎片
	_blueprint_count_label = _create_resource_item(hbox, "📜", "蓝图碎片", Color(0.4, 0.7, 1.0, 1.0))

	# 情报
	_lore_count_label = _create_resource_item(hbox, "📖", "情报", Color(0.9, 0.7, 0.2, 1.0))

func _create_resource_item(parent: Container, icon: String, tooltip: String, color: Color) -> Label:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	parent.add_child(vbox)

	var icon_lbl = Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_font_size_override("font_size", 14)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.modulate = color
	vbox.add_child(icon_lbl)

	var value_lbl = Label.new()
	value_lbl.name = "ValueLabel"
	value_lbl.text = "0"
	value_lbl.add_theme_font_size_override("font_size", 10)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_lbl.modulate = color
	vbox.add_child(value_lbl)

	# 添加tooltip
	var tooltip_panel = TooltipPanel.new()
	tooltip_panel._custom_tooltip = tooltip
	vbox.add_child(tooltip_panel)

	return value_lbl

func _connect_signals() -> void:
	#region agent log
	_agent_log("H1_ui_not_connected", "_connect_signals_entry", {
		"EnergyManager_null": EnergyManager == null,
		"EnergyManager_has_energy_changed_signal": (EnergyManager != null and EnergyManager.has_signal("energy_changed")),
		"SignalBus_null": SignalBus == null,
		"SignalBus_has_energy_changed": (SignalBus != null and SignalBus.has_signal("energy_changed")),
	})
	#endregion
	if EnergyManager and EnergyManager.has_signal("energy_changed"):
		EnergyManager.energy_changed.connect(_on_energy_changed)

	if BasicResourceManager and BasicResourceManager.has_signal("resources_changed"):
		BasicResourceManager.resources_changed.connect(_on_resources_changed)

	if BlueprintManager and BlueprintManager.has_signal("fragments_changed"):
		BlueprintManager.fragments_changed.connect(_on_blueprint_fragments_changed)

	var lm = get_node_or_null("/root/LoreManager")
	if lm and lm.has_signal("lore_unlocked"):
		lm.lore_unlocked.connect(_on_lore_unlocked)

	var sbm = get_node_or_null("/root/StatBoostManager")
	if sbm and sbm.has_signal("stat_boost_applied"):
		sbm.stat_boost_applied.connect(_on_stat_boost_applied)

func _refresh_all() -> void:
	_refresh_energy()
	_refresh_resources()
	_refresh_blueprint_count()
	_refresh_lore_count()

func _refresh_energy() -> void:
	if _energy_label == null:
		return
	var em = EnergyManager
	if em and em.has_method("get_energy"):
		var energy = em.get_energy()
		_energy_label.text = str(energy)
	#region agent log
	_agent_log("H4_wrong_energy_source", "_refresh_energy", {
		"EnergyManager_null": em == null,
		"used_get_energy": (em != null and em.has_method("get_energy")),
		"label": _energy_label.text if _energy_label else "",
	})
	#endregion

func _refresh_resources() -> void:
	if BasicResourceManager == null or not BasicResourceManager.has_method("get_all_totals"):
		return

	var totals = BasicResourceManager.get_all_totals()

	if _basic_nano_label:
		var basic_nano = int(totals.get("basic_nano", 0))
		_basic_nano_label.text = _format_number(basic_nano)

	if _nano_material_label:
		var nano = int(totals.get("nano_materials", 0))
		_nano_material_label.text = _format_number(nano)

	if _alloy_label:
		var alloy = int(totals.get("alloy", 0))
		_alloy_label.text = _format_number(alloy)

	if _crystal_label:
		var crystal = int(totals.get("crystal", 0))
		_crystal_label.text = _format_number(crystal)

func _refresh_blueprint_count() -> void:
	if _blueprint_count_label == null:
		return

	var total_fragments = 0
	if BlueprintManager and BlueprintManager.has_method("get_total_fragment_count"):
		total_fragments = BlueprintManager.get_total_fragment_count()

	_blueprint_count_label.text = str(total_fragments)

func _refresh_lore_count() -> void:
	if _lore_count_label == null:
		return

	var lore_count = 0
	var lm = get_node_or_null("/root/LoreManager")
	if lm and lm.has_method("get_unlocked_lore"):
		var lore_data = lm.get_unlocked_lore()
		lore_count = lore_data.size()

	_lore_count_label.text = str(lore_count)

func _format_number(num: int) -> String:
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	else:
		return str(num)

## 信号回调
func _on_energy_changed(_new_energy: float) -> void:
	_refresh_energy()

func _on_resources_changed() -> void:
	_refresh_resources()

func _on_blueprint_fragments_changed() -> void:
	_refresh_blueprint_count()

func _on_lore_unlocked(_lore_id: String, _lore_name: String) -> void:
	_refresh_lore_count()

func _on_stat_boost_applied(_boost_id: String, _boost_name: String, _total_count: int) -> void:
	pass  # 属性提升显示在背包中，这里暂不显示

## 简单的TooltipPanel类
class TooltipPanel extends Control:
	var _custom_tooltip: String = ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		connect("mouse_entered", _on_mouse_entered)
		connect("mouse_exited", _on_mouse_exited)

	func _on_mouse_entered() -> void:
		if not _custom_tooltip.is_empty():
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	func _on_mouse_exited() -> void:
		pass
