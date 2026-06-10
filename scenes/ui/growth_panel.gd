extends PanelContainer
## 成长面板

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const StarConfig = preload("res://data/blueprint_star_config.gd")
const ModRegistry = preload("res://scripts/systems/modification_registry.gd")
const ModSlotScene: PackedScene = preload("res://scenes/ui/mod_slot_item.tscn")

signal closed

var _anim_duration: float = 0.25
var _is_open: bool = false
var _selected_card: CardResource = null

var unit_name_label: Label
var unit_subtitle_label: Label
var era_badle: Label
var stat_tags: HBoxContainer
var star_count_label: Label
var star_row_container: HBoxContainer
var star_progress_bar: ProgressBar
var star_cost_text: Label
var section_enhance_label: Label
var enhance_progress_bar: ProgressBar
var stat_atk_label: Label
var stat_def_label: Label
var stat_hp_label: Label
var stat_misc_label: Label
var mod_count_label: Label
var mod_grid: GridContainer
var mod_open_btn: Button
var evo_target_icon: Label
var evo_target_name: Label
var evo_requirements_label: Label
var btn_apply: Button

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	unit_name_label = get_node_or_null("%UnitName")
	unit_subtitle_label = get_node_or_null("%Subtitle")
	era_badle = get_node_or_null("%EraBadge")
	stat_tags = get_node_or_null("%TagsContainer")
	star_count_label = get_node_or_null("%StarCountLabel")
	star_row_container = get_node_or_null("%StarRow")
	star_progress_bar = get_node_or_null("%StarProgress")
	star_cost_text = get_node_or_null("%StarCostText")
	section_enhance_label = get_node_or_null("%EnhanceLevel")
	enhance_progress_bar = get_node_or_null("%EnhanceProgress")
	stat_atk_label = get_node_or_null("%AtkValues")
	stat_def_label = get_node_or_null("%DefValues")
	stat_hp_label = get_node_or_null("%HpValues")
	stat_misc_label = get_node_or_null("%MiscValues")
	mod_count_label = get_node_or_null("%ModCountLabel")
	mod_grid = get_node_or_null("%ModGrid")
	mod_open_btn = get_node_or_null("%ModOpenBtn")
	evo_target_icon = get_node_or_null("%EvoTargetIcon")
	evo_target_name = get_node_or_null("%EvoTargetName")
	evo_requirements_label = get_node_or_null("%EvoRequirements")
	btn_apply = get_node_or_null("%ApplyBtn")
	if btn_apply:
		btn_apply.pressed.connect(_on_apply_pressed)
	if mod_open_btn:
		mod_open_btn.pressed.connect(_on_open_modification)
	print("[GrowthPanel] _ready OK")

func show_panel(card: CardResource) -> void:
	if _is_open:
		return
	_is_open = true
	_selected_card = card
	visible = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, _anim_duration).set_trans(Tween.TRANS_SINE)
	scale = Vector2(0.92, 0.92)
	tw.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), _anim_duration).set_trans(Tween.TRANS_BACK)
	_refresh_data()

func hide_panel() -> void:
	if not _is_open:
		return
	_is_open = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, _anim_duration).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "scale", Vector2(0.92, 0.92), _anim_duration).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func(): visible = false)
	closed.emit()

func _on_apply_pressed() -> void:
	print("[GrowthPanel] 应用保存(待实现)")
	var sb = get_node_or_null("/root/SignalBus")
	if sb and sb.has_signal("growth_panel_saved"):
		sb.growth_panel_saved.emit(_selected_card)
	hide_panel()

func _refresh_data() -> void:
	if not _selected_card:
		return
	_refresh_header()
	_refresh_star_section()
	_refresh_enhance_section()
	_refresh_mod_section()
	_refresh_evolution_section()

func select_card_by_id(card_id: String) -> void:
	if card_id.is_empty():
		return
	var card = DefaultCards.get_card_by_id(card_id)
	if card:
		_selected_card = card
		if visible:
			_refresh_data()

func select_card(card: CardResource) -> void:
	_selected_card = card
	if visible:
		_refresh_data()

func _on_open_modification() -> void:
	if not _selected_card:
		return
	var lazy = get_node_or_null("/root/UILazyLoader")
	if lazy == null:
		return
	var mod_panel = lazy.call("get_panel", "modification")
	if mod_panel == null:
		return
	if mod_panel.has_method("set_selected_card"):
		mod_panel.set_selected_card(_selected_card)
	var overlay = get_node_or_null("PopupLayer/ModificationOverlay")
	if overlay:
		overlay.visible = true
		overlay.modulate.a = 1.0

func _refresh_header() -> void:
	var c := _selected_card
	if not c:
		return
	if unit_name_label:
		unit_name_label.text = c.card_id.to_upper()
	if unit_subtitle_label:
		unit_subtitle_label.text = c.display_name
	if era_badle:
		era_badle.text = ""
	if stat_tags:
		for child in stat_tags.get_children():
			child.queue_free()
		var kind_tag := Label.new()
		kind_tag.text = CardResource.get_combat_kind_name(c.combat_kind) if c.card_type == GC.CardType.COMBAT_UNIT else ""
		kind_tag.add_theme_font_size_override("font_size", 11)
		kind_tag.add_theme_stylebox_override("normal", _get_tag_stylebox())
		stat_tags.add_child(kind_tag)
		if c.card_type == GC.CardType.COMBAT_UNIT:
			var wt_tag := Label.new()
			if c.weapon_type == GC.WeaponType.DIRECT:
				wt_tag.text = "直射"
			elif c.weapon_type == GC.WeaponType.INDIRECT:
				wt_tag.text = "曲射"
			elif c.weapon_type == GC.WeaponType.AERIAL:
				wt_tag.text = "空射"
			else:
				wt_tag.text = "辅助"
			wt_tag.add_theme_font_size_override("font_size", 11)
			wt_tag.add_theme_stylebox_override("normal", _get_tag_stylebox())
			stat_tags.add_child(wt_tag)
			if c.range_value > 0:
				var rng_tag := Label.new()
				rng_tag.text = "射程 %d" % c.range_value
				rng_tag.add_theme_font_size_override("font_size", 11)
				rng_tag.add_theme_stylebox_override("normal", _get_tag_stylebox())
				stat_tags.add_child(rng_tag)
			var e_cost := Label.new()
			e_cost.text = "能量 %.0f" % c.energy_cost
			e_cost.add_theme_font_size_override("font_size", 11)
			e_cost.add_theme_stylebox_override("normal", _get_tag_stylebox())
			stat_tags.add_child(e_cost)

func _refresh_star_section() -> void:
	if not _selected_card:
		return
	var star: int = _calculate_star()
	if star_row_container:
		for child in star_row_container.get_children():
			child.queue_free()
		for idx in range(5):
			var s := Label.new()
			s.add_theme_font_size_override("font_size", 18)
			s.custom_minimum_size = Vector2(32, 32)
			s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if idx < star:
				s.text = "\u2605"
				s.modulate = Color(1.0, 0.84, 0.0)
				s.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
			else:
				s.text = "\u2606"
				s.modulate = Color(0.333, 0.4, 0.467)
			star_row_container.add_child(s)
	if star_count_label:
		star_count_label.text = "%d/5 星级" % star
	if star_progress_bar:
		star_progress_bar.value = (float(mini(star, 4)) / 4.0) * 100.0
	if star_cost_text:
		var next_cost := StarConfig.get_research_cost_for_next_star(star, _selected_card.rarity)
		star_cost_text.text = "下一星所需: 合金×%d · 晶体×%d" % [int(next_cost / 5.0), int(next_cost / 7.0)]

func _refresh_enhance_section() -> void:
	var c := _selected_card
	if not c:
		return
	if section_enhance_label:
		section_enhance_label.text = "LV.%d / 10" % c.enhance_level
	if enhance_progress_bar:
		enhance_progress_bar.value = (float(c.enhance_level) / 10.0) * 100.0
	var stats := _get_enhanced_stats()
	if stat_atk_label:
		stat_atk_label.text = "轻%.0f / 甲%.0f / 空%.0f" % [
			float(stats.get("atk_light", 0)), float(stats.get("atk_armor", 0)), float(stats.get("atk_air", 0))]
	if stat_def_label:
		stat_def_label.text = "轻%.0f / 甲%.0f / 空%.0f" % [
			float(stats.get("def_light", 0)), float(stats.get("def_armor", 0)), float(stats.get("def_air", 0))]
	if stat_hp_label:
		stat_hp_label.text = "%.0f" % float(stats.get("hp", 0))
	if stat_misc_label:
		stat_misc_label.text = "射程 %d | 攻速 %.1f | 移速 %.1f" % [
			int(stats.get("range", _selected_card.range_value)),
			float(stats.get("atk_speed", _selected_card.attack_speed)),
			float(stats.get("speed", _selected_card.base_speed))]

func _refresh_mod_section() -> void:
	if not mod_grid or not _selected_card:
		return
	for child in mod_grid.get_children():
		if child.name != "PlaceholderSlot":
			child.queue_free()
	var mod_list: Array = _selected_card.mods
	var filled: int = mini(mod_list.size(), 9)
	if mod_count_label:
		mod_count_label.text = "%d/9 已装配" % filled
	for idx in range(9):
		var slot: Control = ModSlotScene.instantiate()
		slot.custom_minimum_size = Vector2(80, 100)
		slot.modulate.a = 1.0
		mod_grid.add_child(slot)
		if slot.has_method("set_slot_index"):
			slot.set_slot_index(idx + 1)
		var mod_data: Dictionary = {}
		if idx < filled:
			var entry = mod_list[idx]
			if entry is Dictionary:
				mod_data = entry
			elif entry is String:
				var entry_str: String = String(entry)
				var md: Dictionary = ModRegistry.get_data(entry_str)
				mod_data = {"id": entry_str, "name": md.get("display_name", entry_str), "level": 1, "tier": "A"}
		if slot.has_method("set_mod"):
			slot.set_mod(mod_data)

func _refresh_evolution_section() -> void:
	var c := _selected_card
	if not c:
		return
	var evo_paths: Array = c.evolution_paths
	if evo_target_icon:
		if evo_paths.is_empty():
			evo_target_icon.text = "🔒"
		else:
			evo_target_icon.text = "⚔"
	if evo_target_name:
		if evo_paths.is_empty():
			evo_target_name.text = "未解锁进化路线"
		else:
			var target_id: String = String(evo_paths[0])
			var target = DefaultCards.get_card_by_id(target_id)
			if target:
				evo_target_name.text = target.display_name
			else:
				evo_target_name.text = target_id
	if evo_requirements_label:
		var lines: PackedStringArray = []
		lines.append("✓ 素材情报 ≥ 2/2")
		var current_power := c.get_current_power()
		var target_power_val: int = maxi(int(c.power * 2.0), 800)
		if current_power >= target_power_val:
			lines.append("✓ 战力 ≥ %d (当前 %d)" % [target_power_val, current_power])
		else:
			lines.append("✗ 战力 ≥ %d (当前 %d)" % [target_power_val, current_power])
		var evo_star := _calculate_star()
		if evo_star >= 4:
			lines.append("✓ 星级 ≥ 4")
		else:
			lines.append("✗ 星级 ≥ 4")
		lines.append("✗ 合金 500")
		evo_requirements_label.text = "\n".join(lines)

func _calculate_star() -> int:
	return StarConfig.calculate_star(_selected_card.enhance_level * 2, _selected_card.rarity)

func _get_enhanced_stats() -> Dictionary:
	var c := _selected_card
	var mult := 1.0 + (float(c.enhance_level) * 0.08)
	return {
		"atk_light": c.attack_light * mult,
		"atk_armor": c.attack_armor * mult,
		"atk_air": c.attack_air * mult,
		"def_light": c.defense_light * mult,
		"def_armor": c.defense_armor * mult,
		"def_air": c.defense_air * mult,
		"hp": c.base_hp * mult,
		"range": c.range_value,
		"atk_speed": c.attack_speed,
		"speed": c.base_speed,
	}

func _get_tag_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.29, 0.561, 0.851, 0.1)
	sb.border_color = Color(0.29, 0.561, 0.851, 0.25)
	sb.set_corner_radius_all(2)
	sb.content_left = 6
	sb.content_top = 1
	sb.content_right = 6
	sb.content_bottom = 1
	return sb
