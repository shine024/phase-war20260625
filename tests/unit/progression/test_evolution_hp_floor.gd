class_name EvolutionHpFloorTest
extends GdUnitTestSuite

const GC = preload("res://resources/game_constants.gd")
const BM_SCRIPT = preload("res://managers/blueprint_manager.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")

var _bm: Node


func before_test() -> void:
	_bm = Node.new()
	_bm.set_script(BM_SCRIPT)
	add_child(_bm)
	DefaultCards._ensure_card_cache()


func after_test() -> void:
	remove_child(_bm)
	_bm.free()


func test_evolution_hp_floor_applied_after_growth() -> void:
	var dst_id: String = "platform_ww2_light"
	var dst_card: CardResource = DefaultCards.get_card_by_id(dst_id)
	var wt: int = dst_card.default_weapon_type
	_bm.blueprint_evolution_hp_floor[dst_id] = 120.0
	var stats: UnitStats = UnitStatsTable.build_multi_stats(dst_card.platform_type, [wt], 0)
	_bm.apply_growth_to_stats(stats, dst_card, [], false)
	assert_float(stats.max_hp).is_greater_equal(120.0)


func test_ww1_to_ww2_evolve_floor_not_below_prior_effective_hp() -> void:
	var src_id: String = "platform_ww1_light"
	var dst_id: String = "platform_ww2_light"
	var old_hp: float = _bm._compute_platform_preview_hp(src_id, 0)
	_bm.blueprint_evolution_hp_floor[dst_id] = old_hp * 1.10
	var dst_card: CardResource = DefaultCards.get_card_by_id(dst_id)
	var wt: int = dst_card.default_weapon_type
	var stats: UnitStats = UnitStatsTable.build_multi_stats(dst_card.platform_type, [wt], 0)
	_bm.apply_growth_to_stats(stats, dst_card, [], false)
	assert_float(stats.max_hp).is_greater_equal(old_hp * 1.10 - 0.01)
