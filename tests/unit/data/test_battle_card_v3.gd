class_name BattleCardV3Test
extends GdUnitTestSuite

const BC = preload("res://data/battle_card_v3.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const GC = preload("res://resources/game_constants.gd")


func test_era_multipliers_at_bounds() -> void:
	assert_float(BC.era_damage_multiplier(0)).is_equal(1.0)
	assert_float(BC.era_damage_multiplier(4)).is_equal(2.0)
	assert_float(BC.era_range_multiplier(1)).is_equal(1.1)
	assert_float(BC.era_hp_multiplier(3)).is_equal(1.45)


func test_star_stat_multiplier() -> void:
	assert_float(BC.star_stat_multiplier(1)).is_equal(1.0)
	assert_float(BC.star_stat_multiplier(9)).is_equal(1.64)
	assert_float(BC.star_stat_multiplier(9, "mythic")).is_equal(1.96)


func test_evolution_inherit_bonus_clamped() -> void:
	assert_float(BC.evolution_inherit_bonus(10, 99)).is_equal(0.40)


func test_unit_stats_table_era_scales_hp_and_weapon_damage() -> void:
	var st: UnitStats = UnitStatsTable.build_multi_stats(1, [1], 1)  # GUARD, RIFLE
	assert_float(st.max_hp).is_equal(115.0)
	assert_float(st.attack_damage).is_equal(15.0)
	var st0: UnitStats = UnitStatsTable.build_multi_stats(1, [1], 0)  # GUARD, RIFLE
	assert_float(st0.max_hp).is_equal(100.0)
	assert_float(st0.attack_damage).is_equal(12.0)


func test_siege_star_growth_bias_exceeds_scout() -> void:
	var BM_SCRIPT = preload("res://managers/blueprint_manager.gd")
	DefaultCards._ensure_card_cache()
	var bm: Node = Node.new()
	bm.set_script(BM_SCRIPT)
	add_child(bm)
	var siege_card: CardResource = DefaultCards.get_card_by_id("platform_ww2_siege")
	var scout_card: CardResource = DefaultCards.get_card_by_id("platform_ww2_light")
	bm.blueprint_stars[siege_card.card_id] = 9
	bm.blueprint_stars[scout_card.card_id] = 9
	var st_siege: UnitStats = UnitStatsTable.build_multi_stats(
		siege_card.platform_type, [siege_card.default_weapon_type], 0
	)
	var st_scout: UnitStats = UnitStatsTable.build_multi_stats(
		scout_card.platform_type, [scout_card.default_weapon_type], 0
	)
	bm.apply_growth_to_stats(st_siege, siege_card, [], false)
	bm.apply_growth_to_stats(st_scout, scout_card, [], false)
	var ratio: float = st_siege.max_hp / maxf(st_scout.max_hp, 1.0)
	assert_float(ratio).is_greater(7.78)
	remove_child(bm)
	bm.free()
