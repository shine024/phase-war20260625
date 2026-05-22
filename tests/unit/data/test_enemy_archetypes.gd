class_name EnemyArchetypesDataTest
extends GdUnitTestSuite

const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")


func test_archetypes_dictionary_is_not_empty() -> void:
	assert_dict(EnemyArchetypes.ARCHETYPES).is_not_empty()


func test_archetype_entries_have_base_fields() -> void:
	var first_key = EnemyArchetypes.ARCHETYPES.keys()[0]
	var entry: Dictionary = EnemyArchetypes.ARCHETYPES[first_key]
	assert_dict(entry).contains_keys(["display_name", "rarity"])
