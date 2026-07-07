class_name EnemyArchetypesDataTest
extends GdUnitTestSuite

const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")


func test_archetypes_dictionary_is_not_empty() -> void:
	assert_dict(EnemyArchetypes.ARCHETYPES).is_not_empty()


func test_archetype_entries_have_base_fields() -> void:
	# v7.x: ARCHETYPES 含 schema_version 等非实体 key，跳过它们，取第一个 Dictionary entry。
	var entry: Dictionary = {}
	for key in EnemyArchetypes.ARCHETYPES.keys():
		var v = EnemyArchetypes.ARCHETYPES[key]
		if v is Dictionary and v.size() > 0:
			entry = v
			break
	assert_dict(entry).is_not_empty()
	# v7.x: 实际 archetype entry 含 display_name（但 rarity 是部分 entry 才有），只断言核心字段。
	assert_dict(entry).contains_keys(["display_name"])
