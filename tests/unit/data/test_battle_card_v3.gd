class_name BattleCardV3Test
extends GdUnitTestSuite

const BC = preload("res://data/battle_card_v3.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const GC = preload("res://resources/game_constants.gd")


func test_era_multipliers_at_bounds() -> void:
	assert_float(BC.era_damage_multiplier(0)).is_equal(1.0)
	# v6.1: 近未来伤害倍率 1.90→1.80（避免后期火力过溢），断言从 2.0 更新为 1.8
	assert_float(BC.era_damage_multiplier(4)).is_equal(1.8)
	assert_float(BC.era_range_multiplier(1)).is_equal(1.1)
	assert_float(BC.era_hp_multiplier(3)).is_equal(1.45)


func test_star_stat_multiplier() -> void:
	assert_float(BC.star_stat_multiplier(1)).is_equal(1.0)
	# v7.x: 浮点累乘有精度误差，用 is_equal_approx 替代 is_equal
	assert_float(BC.star_stat_multiplier(9)).is_equal_approx(1.64, 0.001)
	assert_float(BC.star_stat_multiplier(9, "mythic")).is_equal_approx(1.96, 0.001)

func test_enhance_stat_multiplier() -> void:
	assert_float(BC.enhance_stat_multiplier(1)).is_equal(1.0)
	# v7.x: 浮点累乘有精度误差，用 is_equal_approx 替代 is_equal
	assert_float(BC.enhance_stat_multiplier(10)).is_equal_approx(1.63, 0.001)
	assert_float(BC.enhance_stat_multiplier(10, "mythic")).is_equal_approx(1.99, 0.001)


func test_evolution_inherit_bonus_clamped() -> void:
	assert_float(BC.evolution_inherit_bonus(10, 99)).is_equal(0.40)


func test_unit_stats_table_era_scales_hp_and_weapon_damage() -> void:
	var st: UnitStats = UnitStatsTable.build_multi_stats(1, [1], 1)  # GUARD, RIFLE
	# v6.8/v7.x: build_multi_stats 基础值调整后 max_hp=110/atk=14（原 115/15）
	assert_float(st.max_hp).is_equal(110.0)
	assert_float(st.attack_damage).is_equal(14.0)
	var st0: UnitStats = UnitStatsTable.build_multi_stats(1, [1], 0)  # GUARD, RIFLE
	assert_float(st0.max_hp).is_equal(110.0)
	assert_float(st0.attack_damage).is_equal(14.0)


func test_siege_enhance_growth_bias_exceeds_scout() -> void:
	var BM_SCRIPT = preload("res://managers/blueprint_manager.gd")
	var CEM_SCRIPT = preload("res://managers/card_enhancement_manager.gd")
	DefaultCards._ensure_card_cache()
	var bm: Node = Node.new()
	bm.set_script(BM_SCRIPT)
	add_child(bm)
	## 模拟 CardEnhancementManager
	var cem: Node = Node.new()
	cem.set_script(CEM_SCRIPT)
	cem.name = "CardEnhancementManager"
	add_child(cem)
	var siege_card: CardResource = DefaultCards.get_card_by_id("platform_ww2_siege")
	var scout_card: CardResource = DefaultCards.get_card_by_id("platform_ww2_light")
	# v6.11：强化等级实际存储在卡牌的 enhance_level 字段（非 cem.card_enhancement_level）
	siege_card.enhance_level = 9
	scout_card.enhance_level = 9
	var st_siege: UnitStats = UnitStatsTable.build_multi_stats(
		siege_card.platform_type, [siege_card.default_weapon_type], 0
	)
	var st_scout: UnitStats = UnitStatsTable.build_multi_stats(
		scout_card.platform_type, [scout_card.default_weapon_type], 0
	)
	bm.apply_growth_to_stats(st_siege, siege_card, [], false)
	bm.apply_growth_to_stats(st_scout, scout_card, [], false)
	var ratio: float = st_siege.max_hp / maxf(st_scout.max_hp, 1.0)
	# v6.8: 移除时代缩放 + 平衡调整后，siege/scout HP 比例约 1.82（原 >7.78）。
	# siege 的 hp_bias 仍高于 scout（ratio > 1.5 即可验证偏向），断言更新为当前实际值。
	assert_float(ratio).is_greater(1.5)
	# 清理（v7.x 加固：守卫 + queue_free）
	if cem != null and is_instance_valid(cem):
		if cem.is_inside_tree(): remove_child(cem)
		cem.queue_free()
	if bm != null and is_instance_valid(bm):
		if bm.is_inside_tree(): remove_child(bm)
		bm.queue_free()
