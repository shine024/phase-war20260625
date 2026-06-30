extends Control
## 相位仪选择面板：全屏遮罩 + 居中面板（避免 AcceptDialog/Window 在 CanvasLayer 下无法显示）

signal instrument_selected(instrument_id: String)

const PhaseInstruments = preload("res://data/phase_instruments.gd")
const CompanyDefs = preload("res://data/company_definitions.gd")

@onready var _backdrop: ColorRect = $Backdrop
@onready var close_button: Button = $Center/DialogPanel/Margin/VBox/Header/CloseButton
@onready var instrument_list: VBoxContainer = $Center/DialogPanel/Margin/VBox/Body/ScrollContainer/InstrumentList

var _instrument_items: Array = []

func _ready() -> void:
	add_to_group("phase_instrument_selector")
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _backdrop:
		_backdrop.gui_input.connect(_on_backdrop_gui_input)
	if close_button:
		close_button.pressed.connect(_on_close)
		UiAssetLoader.apply_button_icon(close_button, "icon_close")
	_refresh_instrument_list()

func _on_backdrop_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		queue_free()

## 刷新相位仪列表
func _refresh_instrument_list() -> void:
	for child in instrument_list.get_children():
		child.queue_free()
	_instrument_items.clear()

	if PhaseInstrumentManager == null:
		_show_empty_message("相位仪管理器未找到")
		return

	var current_instrument_id: String = ""
	if PhaseInstrumentManager.has_method("get_current_instrument"):
		var current_cfg = PhaseInstrumentManager.get_current_instrument()
		current_instrument_id = String(current_cfg.get("id", ""))

	var unlocked_ids: Array = []
	if PhaseInstrumentManager.has_method("get_unlocked_instrument_ids"):
		unlocked_ids = PhaseInstrumentManager.get_unlocked_instrument_ids()

	if unlocked_ids.is_empty():
		_show_empty_message("暂无已解锁的相位仪")
		return

	var phase_field_info := _create_phase_field_info_item()
	if phase_field_info != null:
		instrument_list.add_child(phase_field_info)

	var sorted_instruments: Array = []
	for iid in unlocked_ids:
		var cfg = PhaseInstruments.get_by_id(iid)
		if not cfg.is_empty():
			sorted_instruments.append(cfg)

	sorted_instruments.sort_custom(func(a, b): return int(a.get("star", 0)) > int(b.get("star", 0)))

	for inst_cfg in sorted_instruments:
		var item = _create_instrument_item(inst_cfg, inst_cfg.get("id", "") == current_instrument_id)
		instrument_list.add_child(item)
		_instrument_items.append(item)

func _create_phase_field_info_item() -> Control:
	if PhaseInstrumentManager == null:
		return null
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 88)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.16, 0.20, 0.95)
	style.border_color = Color(0.35, 0.82, 0.95, 0.75)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "相位场属性（独立于相位仪加成）"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0, 1.0))
	vbox.add_child(title)

	var unspent: int = 0
	if PhaseInstrumentManager.has_method("get_unspent_phase_field_points"):
		unspent = int(PhaseInstrumentManager.get_unspent_phase_field_points())
	var alloc: Dictionary = {}
	if PhaseInstrumentManager.has_method("get_phase_field_allocations"):
		alloc = PhaseInstrumentManager.get_phase_field_allocations()
	var total_bonus: Dictionary = {}
	if PhaseInstrumentManager.has_method("get_phase_field_total_bonus"):
		total_bonus = PhaseInstrumentManager.get_phase_field_total_bonus()

	var line := Label.new()
	line.add_theme_font_size_override("font_size", 11)
	line.add_theme_color_override("font_color", Color(0.80, 0.92, 1.0, 0.95))
	var alloc_parts: Array[String] = []
	for key in alloc.keys():
		# v6.2 修复 L1：用中文 label 显示（原直接显示英文 key 如 atk_pct）
		# PHASE_FIELD_GROWTH_RULES 是 PhaseInstrumentManager 的 const，通过 autoload 单例访问
		var rule: Dictionary = PhaseInstrumentManager.PHASE_FIELD_GROWTH_RULES.get(key, {}) if PhaseInstrumentManager != null else {}
		var label: String = String(rule.get("label", key))
		alloc_parts.append("%s+%s" % [label, String(alloc[key])])
	alloc_parts.sort()
	var alloc_text: String = "未分配"
	if not alloc_parts.is_empty():
		alloc_text = "已分配: " + " / ".join(PackedStringArray(alloc_parts))
	line.text = "可分配点: %d  |  %s" % [unspent, alloc_text]
	vbox.add_child(line)

	var growth_title := Label.new()
	growth_title.text = "等级提升属性增长明细"
	growth_title.add_theme_font_size_override("font_size", 11)
	growth_title.add_theme_color_override("font_color", Color(0.58, 0.88, 1.0, 0.95))
	vbox.add_child(growth_title)

	var detail_lines: Array[String] = []
	if PhaseInstrumentManager.has_method("get_phase_field_growth_detail_lines"):
		detail_lines = PhaseInstrumentManager.get_phase_field_growth_detail_lines()
	for detail in detail_lines:
		var detail_label := Label.new()
		detail_label.text = "  - %s" % detail
		detail_label.add_theme_font_size_override("font_size", 10)
		detail_label.add_theme_color_override("font_color", Color(0.76, 0.9, 1.0, 0.92))
		vbox.add_child(detail_label)

	if not total_bonus.is_empty():
		var total_bonus_line := Label.new()
		var bonus_parts: Array[String] = []
		for key in total_bonus.keys():
			var val: float = float(total_bonus[key])
			var rules: Dictionary = {}
			if PhaseInstrumentManager.has_method("get_phase_field_growth_rules"):
				rules = PhaseInstrumentManager.get_phase_field_growth_rules()
			var rule: Dictionary = rules.get(key, {})
			var label: String = String(rule.get("label", key))
			bonus_parts.append("%s +%.0f%%" % [label, val * 100.0])
		bonus_parts.sort()
		total_bonus_line.text = "当前总加成: " + " / ".join(PackedStringArray(bonus_parts))
		total_bonus_line.add_theme_font_size_override("font_size", 10)
		total_bonus_line.add_theme_color_override("font_color", Color(0.70, 0.95, 0.90, 0.95))
		vbox.add_child(total_bonus_line)
	return panel

## 创建相位仪列表项
func _create_instrument_item(cfg: Dictionary, is_equipped: bool) -> Control:
	var container = PanelContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(0, 100)

	var style = StyleBoxFlat.new()
	if is_equipped:
		style.bg_color = Color(0.15, 0.25, 0.35, 0.95)
		style.border_color = Color(0.4, 0.85, 1.0, 0.9)
	else:
		style.bg_color = Color(0.08, 0.10, 0.15, 0.92)
		style.border_color = Color(0.3, 0.35, 0.45, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	container.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	container.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var header_row = HBoxContainer.new()
	vbox.add_child(header_row)

	var name_label = Label.new()
	var inst_name = String(cfg.get("name", "未知相位仪"))
	var star = int(cfg.get("star", 0))
	if is_equipped:
		name_label.text = "✓ %s ★%d" % [inst_name, star]
		name_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6, 1.0))
	else:
		name_label.text = "%s ★%d" % [inst_name, star]
		name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7, 1.0))
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(name_label)

	var faction_id = String(cfg.get("faction_id", ""))
	var is_generic = bool(cfg.get("is_generic", false))
	if not is_generic:
		var faction_cfg = CompanyDefs.get_by_id(faction_id)
		if not faction_cfg.is_empty():
			var faction_label = Label.new()
			faction_label.text = String(faction_cfg.get("name", ""))
			faction_label.add_theme_font_size_override("font_size", 11)
			faction_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95, 0.9))
			header_row.add_child(faction_label)
	else:
		var generic_label = Label.new()
		generic_label.text = "通用"
		generic_label.add_theme_font_size_override("font_size", 11)
		generic_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7, 0.9))
		header_row.add_child(generic_label)

	var slot_row = HBoxContainer.new()
	vbox.add_child(slot_row)

	var slot_counts = cfg.get("slot_counts", {})
	var green_count = int(slot_counts.get("green", 0))
	var yellow_count = int(slot_counts.get("yellow", 0))
	var rune_count = int(slot_counts.get("rune", 0))   # v6.2: red/blue 法则槽已废弃，改 rune 符文槽
	# 兼容旧数据：若无 rune 字段则回退读 red/blue（渐进迁移）
	if rune_count == 0:
		rune_count = int(slot_counts.get("red", 0)) + int(slot_counts.get("blue", 0))
	var total_slots = green_count + yellow_count + rune_count

	var config_label = Label.new()
	config_label.text = "槽位配置: "
	config_label.add_theme_font_size_override("font_size", 11)
	config_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85, 0.9))
	slot_row.add_child(config_label)

	if green_count > 0:
		var green_label = Label.new()
		green_label.text = "绿%d " % green_count
		green_label.add_theme_font_size_override("font_size", 11)
		green_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5, 1.0))
		slot_row.add_child(green_label)

	if yellow_count > 0:
		var yellow_label = Label.new()
		yellow_label.text = "黄%d " % yellow_count
		yellow_label.add_theme_font_size_override("font_size", 11)
		yellow_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.2, 1.0))
		slot_row.add_child(yellow_label)

	if rune_count > 0:
		var rune_label = Label.new()
		rune_label.text = "符%d " % rune_count
		rune_label.add_theme_font_size_override("font_size", 11)
		rune_label.add_theme_color_override("font_color", Color(0.75, 0.55, 0.95, 1.0))
		slot_row.add_child(rune_label)

	var total_label = Label.new()
	total_label.text = "(总计: %d)" % total_slots
	total_label.add_theme_font_size_override("font_size", 11)
	total_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85, 0.9))
	slot_row.add_child(total_label)

	var stats_row = HBoxContainer.new()
	vbox.add_child(stats_row)

	# v7.x: 移除 energy_output_rate 显示，仅保留能量恢复
	var recovery_rate = float(cfg.get("energy_recovery_rate", 0.3))
	var spawn_ratio = float(cfg.get("spawn_range_ratio", 0.3))

	var actual_recovery = recovery_rate * 3.0

	var stats_parts: Array = []
	stats_parts.append("可上场: %d单位" % green_count)
	stats_parts.append("能量恢复: %.2f (实际: %.1f/秒)" % [recovery_rate, actual_recovery])
	stats_parts.append("部署范围: %.0f%%" % (spawn_ratio * 100))

	var stats_label = Label.new()
	stats_label.text = "  |  ".join(PackedStringArray(stats_parts))
	stats_label.add_theme_font_size_override("font_size", 10)
	stats_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 0.85))
	stats_row.add_child(stats_label)

	var advanced_parts: Array = []
	var props: Array = cfg.get("properties", [])
	if props is Array and not props.is_empty():
		for p in props:
			if p is Dictionary:
				var display: String = String((p as Dictionary).get("display", ""))
				if not display.is_empty():
					advanced_parts.append("[相位仪] " + display)
	else:
		if cfg.has("card_damage_bonus") and float(cfg.card_damage_bonus) > 0:
			advanced_parts.append("[相位仪] 卡伤+%.0f%%" % (float(cfg.card_damage_bonus) * 100))
		if cfg.has("defense_bonus") and float(cfg.defense_bonus) > 0:
			advanced_parts.append("[相位仪] 防御+%.0f%%" % (float(cfg.defense_bonus) * 100))
		if cfg.has("xp_bonus") and float(cfg.xp_bonus) > 0:
			advanced_parts.append("[相位仪] 相位场经验+%.0f%%" % (float(cfg.xp_bonus) * 100))
		if cfg.has("energy_cost_reduction") and int(cfg.energy_cost_reduction) > 0:
			advanced_parts.append("[相位仪] 能耗-%d" % int(cfg.energy_cost_reduction))

	if not advanced_parts.is_empty():
		var advanced_row = HBoxContainer.new()
		vbox.add_child(advanced_row)
		var advanced_label = Label.new()
		advanced_label.text = "  |  ".join(PackedStringArray(advanced_parts.slice(0, 5)))
		advanced_label.add_theme_font_size_override("font_size", 10)
		advanced_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35, 0.9))
		advanced_row.add_child(advanced_label)

	if cfg.has("special_traits"):
		var traits: Array = cfg.get("special_traits", [])
		if not traits.is_empty():
			var trait_row = HBoxContainer.new()
			vbox.add_child(trait_row)
			var trait_label = Label.new()
			trait_label.text = "✦ " + "  |  ".join(PackedStringArray(traits))
			trait_label.add_theme_font_size_override("font_size", 10)
			trait_label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0, 0.95))
			trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			trait_label.custom_minimum_size = Vector2(400, 0)
			trait_row.add_child(trait_label)

	# v6.6: 主动特殊能力（active_ability）— 与特性区分高亮，让玩家看到这把相位仪还带一个独立的主动能力
	if cfg.has("active_ability"):
		var ability: Dictionary = cfg.get("active_ability", {})
		if not ability.is_empty():
			var ability_name: String = String(ability.get("name", ""))
			var ability_desc: String = String(ability.get("description", ""))
			var ability_row = HBoxContainer.new()
			vbox.add_child(ability_row)
			var ability_label = Label.new()
			if not ability_name.is_empty() and not ability_desc.is_empty():
				ability_label.text = "⚡ %s：%s" % [ability_name, ability_desc]
			elif not ability_desc.is_empty():
				ability_label.text = "⚡ %s" % ability_desc
			else:
				ability_label.text = "⚡ %s" % ability_name
			ability_label.add_theme_font_size_override("font_size", 10)
			# 金色高亮，区别于普通特性（青色）
			ability_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
			ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			ability_label.custom_minimum_size = Vector2(400, 0)
			ability_row.add_child(ability_label)

	if is_equipped:
		var equipped_label = Label.new()
		equipped_label.text = "当前装备中"
		equipped_label.add_theme_font_size_override("font_size", 11)
		equipped_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.5, 1.0))
		vbox.add_child(equipped_label)
	else:
		var equip_btn = Button.new()
		equip_btn.text = "装备此相位仪"
		equip_btn.add_theme_font_size_override("font_size", 12)
		equip_btn.custom_minimum_size = Vector2(120, 32)
		vbox.add_child(equip_btn)

		var iid_copy = String(cfg.get("id", ""))
		equip_btn.pressed.connect(func():
			_on_equip_pressed(iid_copy)
		)

	return container

func _show_empty_message(msg: String) -> void:
	var label = Label.new()
	label.text = msg
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.8))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	instrument_list.add_child(label)

func _on_equip_pressed(instrument_id: String) -> void:
	if PhaseInstrumentManager == null:
		return

	if PhaseInstrumentManager.has_method("equip_instrument"):
		var success = PhaseInstrumentManager.equip_instrument(instrument_id)
		if success:
			instrument_selected.emit(instrument_id)

func _on_close() -> void:
	queue_free()
