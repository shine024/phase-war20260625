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
	assert_bool(UnitLineageConfig.has_lineage("platform_ww1_medium")).is_true()
	assert_str(UnitLineageConfig.get_evolution_1_target("platform_ww1_medium")).is_equal("platform_ww2_medium")


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
	const EvolutionGraphBuilder = preload("res://scripts/progression/evolution_graph_builder.gd")
	var preds: Array[Dictionary] = EvolutionGraphBuilder.get_predecessors("platform_ww2_light")
	assert_int(preds.size()).is_greater_equal(1)
	var found_ww1: bool = false
	for p in preds:
		if String(p.get("from_id", "")) == "platform_ww1_light":
			found_ww1 = true
			assert_str(String(p.get("kind", ""))).is_equal("e1")
	assert_bool(found_ww1).is_true()
