class_name DropTablesTest
extends GdUnitTestSuite

const DropTables = preload("res://resources/drop_tables.gd")
# v7.x: DropTables 的 generate_drops/generate_boss_drops 是实例方法（非 static），
# Godot 4.5 不允许 ClassName.method() 调用非静态函数。实例化复用。
var _tables := DropTables.new()


func test_generate_drops_returns_array() -> void:
	var drops := _tables.generate_drops(1, 1, true, 2)
	assert_array(drops).is_not_null()


func test_generate_boss_drops_returns_array() -> void:
	var drops := _tables.generate_boss_drops(1, "tutorial_boss")
	assert_array(drops).is_not_null()
