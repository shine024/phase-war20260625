extends GutTest
## 军衔系统测试

var UnifiedRankSystem = preload("res://data/military_titles/unified_rank_system.gd")
var TitleDisplayNames = preload("res://data/military_titles/title_display_names.gd")

func test_get_rank_by_power_ratio() -> void:
	# 测试战力倍率到军衔等级的映射
	assert_eq(UnifiedRankSystem.get_rank_by_power_ratio(1.00), 1, "1.00倍率应为Lv1")
	assert_eq(UnifiedRankSystem.get_rank_by_power_ratio(1.05), 2, "1.05倍率应为Lv2")
	assert_eq(UnifiedRankSystem.get_rank_by_power_ratio(1.10), 3, "1.10倍率应为Lv3")
	assert_eq(UnifiedRankSystem.get_rank_by_power_ratio(1.50), 9, "1.50倍率应为Lv9")
	assert_eq(UnifiedRankSystem.get_rank_by_power_ratio(1.60), 10, "1.60倍率应为Lv10")
	assert_eq(UnifiedRankSystem.get_rank_by_power_ratio(2.00), 10, "2.00倍率应为Lv10（上限）")

func test_rank_data_completeness() -> void:
	# 测试所有等级数据完整性
	for level in range(1, 11):
		var data = UnifiedRankSystem.get_rank_data(level)
		assert_not_empty(data, "Lv%d数据不应为空" % level)
		assert_eq(data.level, level, "Lv%d的level字段应为%d" % [level, level])
		assert_true(data.has("power_ratio_min"), "Lv%d应有power_ratio_min" % level)
		assert_true(data.has("cost_multiplier"), "Lv%d应有cost_multiplier" % level)

func test_title_display_names() -> void:
	# 测试各兵种称号数据
	var unit_types = [0, 1, 2, 3, 4]  # LIGHT, ARMOR, SUPPORT, AIR, FORT

	for unit_type in unit_types:
		for level in range(1, 11):
			var title_info = TitleDisplayNames.get_title_info(unit_type, level)
			assert_not_empty(title_info, "单位类型%d的Lv%d称号不应为空" % [unit_type, level])
			assert_true(title_info.has("name"), "应有name字段")
			assert_true(title_info.has("name_en"), "应有name_en字段")
			assert_true(title_info.has("desc"), "应有desc字段")

func test_cost_multiplier_progression() -> void:
	# 测试消耗倍率递增
	var prev_cost = 0.0
	for level in range(1, 11):
		var cost = UnifiedRankSystem.get_cost_multiplier(level)
		assert_true(cost >= prev_cost, "Lv%d消耗应>=Lv%d" % [level, level - 1])
		prev_cost = cost
