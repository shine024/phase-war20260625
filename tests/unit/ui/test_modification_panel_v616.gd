class_name ModificationPanelV616Test
extends GdUnitTestSuite
## v6.16 改造面板运行时回归锁：真实实例化 modification_panel.tscn（autoload 上下文），
## 实跑三条 v6.16 新路径——攻速断点行渲染 / 门槛件标签 / 槽位过滤动态化。
## （ui_p1_validation 只做编译级检查；本套补运行时行为。）

const DefaultCards = preload("res://data/default_cards.gd")
const ModRegistry = preload("res://scripts/systems/modification_registry.gd")


func _panel() -> Control:
	var scene: PackedScene = load("res://scenes/ui/modification_panel.tscn")
	assert_object(scene).is_not_null()
	var panel: Control = scene.instantiate()
	add_child(panel)
	return panel


func _t72_with_speed_mods() -> CardResource:
	# cold_t72（rare 装甲 7+1=8 槽）+ 两件攻速改造：art_06(-30%) × art_09(-20%)
	# → 聚合 1.3×1.2=1.56 → 增益 0.56 → 断点 II 连射
	var base: CardResource = DefaultCards.get_card_by_id("cold_t72")
	assert_object(base).is_not_null()
	var card: CardResource = base.clone()
	card.mods = [{"id": "art_06_fire_computer", "level": 1}, {"id": "art_09_rapid_fire", "level": 1}]
	return card


func _find_label_text(root: Node, prefix: String) -> String:
	if root is Label and String((root as Label).text).begins_with(prefix):
		return String((root as Label).text)
	for ch in root.get_children():
		var hit: String = _find_label_text(ch, prefix)
		if not hit.is_empty():
			return hit
	return ""


func test_breakpoint_line_renders() -> void:
	var panel := _panel()
	panel.selected_card = _t72_with_speed_mods()
	panel._update_card_info()
	var line: String = _find_label_text(panel.unit_panel, "⚡ 攻速断点")
	assert_str(line).is_not_empty()
	assert_str(line).contains("II 连射")


func test_breakpoint_line_hidden_without_speed_mods() -> void:
	var panel := _panel()
	var card: CardResource = DefaultCards.get_card_by_id("cold_t72").clone()
	card.mods = []
	panel.selected_card = card
	panel._update_card_info()
	assert_str(_find_label_text(panel.unit_panel, "⚡ 攻速断点")).is_empty()


func test_keystone_tag_in_mod_item() -> void:
	var panel := _panel()
	panel.selected_card = _t72_with_speed_mods()
	ModRegistry.register_all()
	# 门槛件行：金色 [门槛] 标签必须渲染（gen_unified_splash = keystone）
	var row: Control = panel._create_mod_item("gen_unified_splash", ModRegistry.get_data("gen_unified_splash"))
	add_child(row)
	assert_str(_find_label_text(row, "[门槛]")).is_not_empty()
	# 非门槛件行：不得出现 [门槛]
	var plain: Control = panel._create_mod_item("art_06_fire_computer", ModRegistry.get_data("art_06_fire_computer"))
	add_child(plain)
	assert_str(_find_label_text(plain, "[门槛]")).is_empty()


func test_filter_uses_dynamic_slot_budget() -> void:
	var panel := _panel()
	# common 轻装卡：6/6 槽 → FILTER_MOD（有空槽）false / FILTER_MAX（满槽）true
	var full := CardResource.new()
	full.rarity = "common"
	full.combat_kind = 0
	full.card_type = 0
	full.mods = [{"id": "inf_05_ap_ammo"}, {"id": "inf_05b"}, {"id": "x3"},
		{"id": "x4"}, {"id": "x5"}, {"id": "x6"}]
	panel._filter_mode = panel.FILTER_MOD
	assert_bool(panel._passes_filter(full)).is_false()
	panel._filter_mode = panel.FILTER_MAX
	assert_bool(panel._passes_filter(full)).is_true()
	# 同一张卡删 1 件 → 5/6 → FILTER_MOD true / FILTER_MAX false
	full.mods.remove_at(full.mods.size() - 1)
	panel._filter_mode = panel.FILTER_MOD
	assert_bool(panel._passes_filter(full)).is_true()
	panel._filter_mode = panel.FILTER_MAX
	assert_bool(panel._passes_filter(full)).is_false()


func test_installed_header_shows_dynamic_max() -> void:
	var panel := _panel()
	panel.selected_card = _t72_with_speed_mods()
	panel._update_card_info()
	# cold_t72 = rare 装甲 → 7+1=8；区段标题「◆ 已装改造」右侧 "2 / 8"
	assert_bool(_label_contains(panel.unit_panel, "◆ 已装改造")).is_true()
	assert_bool(_label_contains(panel.unit_panel, "2 / 8")).is_true()


func _label_contains(node: Node, needle: String) -> bool:
	if node is Label and String((node as Label).text).contains(needle):
		return true
	for ch in node.get_children():
		if _label_contains(ch, needle):
			return true
	return false
