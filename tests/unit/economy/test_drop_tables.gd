class_name DropTablesTest
extends GdUnitTestSuite

const DropTables = preload("res://resources/drop_tables.gd")


func test_generate_drops_returns_array() -> void:
	var drops := DropTables.generate_drops(1, 1, true, 2)
	assert_array(drops).is_not_null()


func test_generate_boss_drops_returns_array() -> void:
	var drops := DropTables.generate_boss_drops(1, "tutorial_boss")
	assert_array(drops).is_not_null()
