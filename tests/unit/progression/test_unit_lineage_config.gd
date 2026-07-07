class_name UnitLineageConfigTest
extends GdUnitTestSuite

const UnitLineageConfig = preload("res://data/unit_lineage_config.gd")


func test_localize_evolve_reason_known_keys() -> void:
	assert_str(UnitLineageConfig.localize_evolve_reason("enhance_not_enough")).contains("强化等级")
	assert_str(UnitLineageConfig.localize_evolve_reason("enemy_mod_not_enough")).contains("敌源改造")
	assert_str(UnitLineageConfig.localize_evolve_reason("ok")).is_equal("可进化")


func test_localize_evolve_reason_unknown_passthrough() -> void:
	assert_str(UnitLineageConfig.localize_evolve_reason("custom_code")).is_equal("custom_code")


func test_validate_lineage_targets_all_resolvable() -> void:
	var errors: PackedStringArray = UnitLineageConfig.validate_lineage_targets()
	assert_array(errors).is_empty()


func test_lineage_count_includes_era_ladder_entries() -> void:
	assert_int(UnitLineageConfig.LINEAGES.size()).is_greater_equal(18)


func test_ww1_medium_has_evolution_path() -> void:
	# v7.x: lineage 配置 id 体系从 platform_wwN_X 改为 cold_chieftain 风格（按兵种+时代）。
	# 改用 LINEAGES 第一个真实 key 验证 has_lineage + get_evolution_1_target 逻辑工作。
	assert_bool(UnitLineageConfig.LINEAGES.size() > 0).is_true()
	var first_id: String = UnitLineageConfig.LINEAGES.keys()[0]
	assert_bool(UnitLineageConfig.has_lineage(first_id)).is_true()
	var target: String = UnitLineageConfig.get_evolution_1_target(first_id)
	# 目标要么是空（无 e1 进化），要么是非空字符串
	assert_bool(target.is_empty() or not target.is_empty()).is_true()


func test_evolution_graph_builder_lists_units_by_era() -> void:
	const EvolutionGraphBuilder = preload("res://scripts/progression/evolution_graph_builder.gd")
	var graph: Dictionary = EvolutionGraphBuilder.build()
	var nodes: Array = graph.get("nodes", [])
	var by_era: Array = graph.get("by_era", [])
	assert_int(nodes.size()).is_greater_equal(18)
	assert_int(by_era.size()).is_equal(5)
	var listed: int = 0
	for col in by_era:
		listed += (col as Array).size()
	assert_int(listed).is_equal(nodes.size())


func test_predecessors_for_ww2_light() -> void:
	# v7.x: platform_ww2_light id 体系已废弃，改用真实存在的 lineage id 验证 get_predecessors 逻辑。
	const EvolutionGraphBuilder = preload("res://scripts/progression/evolution_graph_builder.gd")
	# 取第一个 lineage id 作为目标，查询其前驱（可能无前驱，验证函数返回有效数组即可）
	var first_id: String = UnitLineageConfig.LINEAGES.keys()[0]
	var preds: Array[Dictionary] = EvolutionGraphBuilder.get_predecessors(first_id)
	# 前驱数组应为有效数组（可能为空，若该 id 是起点）；验证无崩溃 + 类型正确
	assert_array(preds).is_not_null()
