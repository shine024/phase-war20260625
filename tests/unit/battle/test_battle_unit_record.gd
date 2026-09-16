extends GdUnitTestSuite
## v32.0 B1-3 每单位战斗记录单测：显示名鸭子链（card→display_name→archetype_id→空）、
## 输出/承伤/击杀聚合、Top 提取、重置、空值/零值防御。
## 静态状态跨用例共享，before/after 强制重置。

const BUR = preload("res://scripts/battle/battle_unit_record.gd")


class FakeCard extends Resource:
	var display_name: String = ""


class FakeUnit extends Node:
	var card: Resource = null
	var display_name: String = ""
	var archetype_id: String = ""


var _nodes: Array = []


func before_test() -> void:
	BUR.reset_battle_record()


func after_test() -> void:
	BUR.reset_battle_record()
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _mk_unit() -> FakeUnit:
	var u := FakeUnit.new()
	_nodes.append(u)
	return u


func test_label_prefers_card_display_name() -> void:
	var u := _mk_unit()
	var c := FakeCard.new()
	c.display_name = "毛瑟步枪班"
	u.card = c
	u.display_name = "不应被用"
	u.archetype_id = "ww1_mauser"
	assert_str(BUR._unit_label(u)).is_equal("毛瑟步枪班")


func test_label_fallback_chain() -> void:
	var u := _mk_unit()
	u.display_name = "T-72"
	u.archetype_id = "cold_t72"
	assert_str(BUR._unit_label(u)).is_equal("T-72")
	var u2 := _mk_unit()
	u2.archetype_id = "cold_spetsnaz"
	assert_str(BUR._unit_label(u2)).is_equal("cold_spetsnaz")
	var u3 := _mk_unit()
	assert_str(BUR._unit_label(u3)).is_empty()


func test_record_damage_aggregates_by_label() -> void:
	var a := _mk_unit()
	a.display_name = "毛瑟步枪班"
	var v := _mk_unit()
	v.archetype_id = "ww1_ft17"
	BUR.record_damage(a, v, 100.0)
	BUR.record_damage(a, v, 50.0)
	var mvp: Dictionary = BUR.get_top_entries()
	assert_float(mvp["top_dealer"]["value"]).is_equal(150.0)
	assert_str(mvp["top_dealer"]["label"]).is_equal("毛瑟步枪班")
	assert_float(mvp["top_tank"]["value"]).is_equal(150.0)
	assert_str(mvp["top_tank"]["label"]).is_equal("ww1_ft17")


func test_zero_and_null_ignored() -> void:
	BUR.record_damage(null, null, 100.0)
	BUR.record_damage(null, null, 0.0)
	BUR.record_kill(null, null)
	assert_dict(BUR.get_top_entries()).is_empty()


func test_kill_counting_and_top_killer() -> void:
	var k1 := _mk_unit()
	k1.display_name = "M1A2"
	var k2 := _mk_unit()
	k2.display_name = "A-10"
	var v := _mk_unit()
	v.archetype_id = "ww1_ft17"
	BUR.record_kill(k1, v)
	BUR.record_kill(k1, v)
	BUR.record_kill(k2, v)
	var mvp: Dictionary = BUR.get_top_entries()
	assert_int(int(mvp["top_killer"]["value"])).is_equal(2)
	assert_str(mvp["top_killer"]["label"]).is_equal("M1A2")


func test_reset_clears_everything() -> void:
	var a := _mk_unit()
	a.display_name = "毛瑟步枪班"
	BUR.record_damage(a, a, 500.0)
	BUR.record_kill(a, a)
	assert_bool(BUR.get_top_entries().is_empty()).is_false()
	BUR.reset_battle_record()
	assert_dict(BUR.get_top_entries()).is_empty()


func test_top_picks_max_not_first() -> void:
	var lo := _mk_unit()
	lo.display_name = "低输出"
	var hi := _mk_unit()
	hi.display_name = "高输出"
	var v := _mk_unit()
	BUR.record_damage(lo, v, 10.0)
	BUR.record_damage(hi, v, 999.0)
	var mvp: Dictionary = BUR.get_top_entries()
	assert_str(mvp["top_dealer"]["label"]).is_equal("高输出")
	assert_int(int(mvp["total_dealt"])).is_equal(1009)
