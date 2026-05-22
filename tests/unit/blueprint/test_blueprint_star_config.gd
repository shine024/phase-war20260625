class_name BlueprintStarConfigTest
extends GdUnitTestSuite

const StarConfig = preload("res://data/blueprint_star_config.gd")


func test_next_star_research_common_matches_v3_table_total() -> void:
	var total: int = 0
	for star in range(1, StarConfig.MAX_STAR_LEVEL):
		total += StarConfig.get_research_cost_for_next_star(star, "common")
	assert_int(total).is_equal(3310)


func test_next_star_research_mythic_matches_v3_table_total() -> void:
	var total: int = 0
	for star in range(1, StarConfig.MAX_STAR_LEVEL):
		total += StarConfig.get_research_cost_for_next_star(star, "mythic")
	assert_int(total).is_equal(26480)


func test_next_star_at_max_returns_zero() -> void:
	assert_int(StarConfig.get_research_cost_for_next_star(StarConfig.MAX_STAR_LEVEL, "common")).is_equal(0)


func test_mod_research_flat_v3() -> void:
	assert_int(StarConfig.get_mod_cost("common", 0)).is_equal(200)
	assert_int(StarConfig.get_mod_cost("legendary", 1)).is_equal(400)
	assert_int(StarConfig.get_mod_cost("mythic", 2)).is_equal(800)


func test_mod_permit_third_requires_two_general() -> void:
	var rule: Dictionary = StarConfig.get_mod_permit_rule(2)
	assert_int(int(rule.get("general", 0))).is_equal(2)
	assert_int(int(rule.get("category", 0))).is_equal(1)
	assert_int(int(rule.get("specific", 0))).is_equal(1)


func test_max_mod_times_is_three_for_common() -> void:
	assert_int(StarConfig.get_max_mod_times("common")).is_equal(3)
