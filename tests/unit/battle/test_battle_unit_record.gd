extends GdUnitTestSuite
## v32.0 B1-3 每单位战斗记录单测 + 2026-09-21 核销批修订。
## 显示名鸭子链：card → display_name → stats.card_id/platform_card_id →
## EnemyArchetypes 中文名（foe_ 剥前缀/映射玩家卡）→ 裸 id 兜底。
## 侧别契约（2026-09-20 报告 P3 核销）：本场最佳只记 player_units 组——
## 敌方攻击者/被击方不进榜。FakeUnit 用真实 add_to_group 模拟侧别。
## 静态状态跨用例共享，before/after 强制重置。

const BUR = preload("res://scripts/battle/battle_unit_record.gd")
const EnemyArchetypesRef = preload("res://data/enemy_archetypes.gd")
const DefaultCardsRef = preload("res://data/default_cards.gd")


class FakeCard extends Resource:
	var display_name: String = ""


class FakeStats extends Object:
	var card_id: String = ""
	var platform_card_id: String = ""


class FakeUnit extends Node:
	var card: Resource = null
	var display_name: String = ""
	var archetype_id: String = ""
	var stats: Object = null

	func _init(player_side: bool = false) -> void:
		if player_side:
			add_to_group("player_units")


var _nodes: Array = []


func before_test() -> void:
	BUR.reset_battle_record()


func after_test() -> void:
	BUR.reset_battle_record()
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _mk_player() -> FakeUnit:
	var u := FakeUnit.new(true)
	_nodes.append(u)
	return u


func _mk_enemy() -> FakeUnit:
	var u := FakeUnit.new(false)
	_nodes.append(u)
	return u


func test_label_prefers_card_display_name() -> void:
	var u := _mk_player()
	var c := FakeCard.new()
	c.display_name = "毛瑟步枪班"
	u.card = c
	u.display_name = "不应被用"
	u.archetype_id = "ww1_mauser"
	assert_str(BUR._unit_label(u)).is_equal("毛瑟步枪班")


func test_label_via_display_name_then_stats_card_id() -> void:
	var u := _mk_player()
	u.display_name = "T-72"
	assert_str(BUR._unit_label(u)).is_equal("T-72")
	var u2 := _mk_player()
	var st := FakeStats.new()
	st.card_id = "ww1_mauser#3"
	u2.stats = st
	var expected := ""
	var tpl := DefaultCardsRef.get_card_by_id("ww1_mauser")
	if tpl != null:
		expected = tpl.display_name
	assert_str(BUR._unit_label(u2)).is_equal(expected)


func test_label_fallback_enemy_archetype_then_raw_id() -> void:
	# 已知敌方原型 → EnemyArchetypes 中文名（数据驱动断言，不锁具体字面量）
	var u := _mk_enemy()
	u.archetype_id = "cold_spetsnaz"
	var expected := String(EnemyArchetypesRef.get_config("cold_spetsnaz").get("display_name", ""))
	if expected.is_empty():
		expected = "cold_spetsnaz"
	assert_str(BUR._unit_label(u)).is_equal(expected)
	# 未知原型 → 裸 id 兜底
	var u2 := _mk_enemy()
	u2.archetype_id = "zz_unknown_archetype"
	assert_str(BUR._unit_label(u2)).is_equal("zz_unknown_archetype")
	var u3 := _mk_player()
	assert_str(BUR._unit_label(u3)).is_empty()


func test_record_damage_aggregates_player_side_only() -> void:
	var a := _mk_player()
	a.display_name = "毛瑟步枪班"
	var v := _mk_player()
	v.display_name = "FT-17"
	BUR.record_damage(a, v, 100.0)
	BUR.record_damage(a, v, 50.0)
	var mvp: Dictionary = BUR.get_top_entries()
	assert_float(mvp["top_dealer"]["value"]).is_equal(150.0)
	assert_str(mvp["top_dealer"]["label"]).is_equal("毛瑟步枪班")
	assert_float(mvp["top_tank"]["value"]).is_equal(150.0)
	assert_str(mvp["top_tank"]["label"]).is_equal("FT-17")


func test_enemy_side_attacker_and_victim_not_recorded() -> void:
	var enemy_atk := _mk_enemy()
	enemy_atk.display_name = "敌方步兵"
	var enemy_victim := _mk_enemy()
	enemy_victim.archetype_id = "cold_spetsnaz"
	var my_unit := _mk_player()
	my_unit.display_name = "我方坦克"
	BUR.record_damage(enemy_atk, enemy_victim, 500.0)
	BUR.record_damage(enemy_atk, my_unit, 500.0)
	BUR.record_kill(enemy_atk, my_unit)
	var mvp: Dictionary = BUR.get_top_entries()
	assert_bool(mvp.has("top_dealer")).is_false()
	assert_bool(mvp.has("top_killer")).is_false()
	# 我方承伤仍记账；敌方互殴不记
	assert_float(mvp["top_tank"]["value"]).is_equal(500.0)
	assert_str(mvp["top_tank"]["label"]).is_equal("我方坦克")


func test_zero_and_null_ignored() -> void:
	BUR.record_damage(null, null, 100.0)
	BUR.record_damage(null, null, 0.0)
	BUR.record_kill(null, null)
	assert_dict(BUR.get_top_entries()).is_empty()


func test_kill_counting_and_top_killer() -> void:
	var k1 := _mk_player()
	k1.display_name = "M1A2"
	var k2 := _mk_player()
	k2.display_name = "A-10"
	var v := _mk_enemy()
	v.archetype_id = "zz_unknown_archetype"
	BUR.record_kill(k1, v)
	BUR.record_kill(k1, v)
	BUR.record_kill(k2, v)
	var mvp: Dictionary = BUR.get_top_entries()
	assert_int(int(mvp["top_killer"]["value"])).is_equal(2)
	assert_str(mvp["top_killer"]["label"]).is_equal("M1A2")


func test_reset_clears_everything() -> void:
	var a := _mk_player()
	a.display_name = "毛瑟步枪班"
	BUR.record_damage(a, a, 500.0)
	BUR.record_kill(a, a)
	assert_bool(BUR.get_top_entries().is_empty()).is_false()
	BUR.reset_battle_record()
	assert_dict(BUR.get_top_entries()).is_empty()


func test_top_picks_max_not_first() -> void:
	var lo := _mk_player()
	lo.display_name = "低输出"
	var hi := _mk_player()
	hi.display_name = "高输出"
	var v := _mk_enemy()
	BUR.record_damage(lo, v, 10.0)
	BUR.record_damage(hi, v, 999.0)
	var mvp: Dictionary = BUR.get_top_entries()
	assert_str(mvp["top_dealer"]["label"]).is_equal("高输出")
	assert_int(int(mvp["total_dealt"])).is_equal(1009)
