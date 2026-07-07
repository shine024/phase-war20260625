class_name LevelInformationDataTest
extends GdUnitTestSuite

const LevelInformation = preload("res://data/level_information.gd")
# v7.x: LevelInformation 是非静态类（extends RefCounted），Godot 4.5 不允许直接 ClassName.method()
# 调用非静态函数。实例化一次复用，模拟运行时行为。
var _info := LevelInformation.new()


func test_level_info_returns_dictionary() -> void:
	var info = _info.get_level_info(1)
	assert_dict(info).is_not_null()


func test_level_info_contains_expected_fields() -> void:
	var info = _info.get_level_info(1)
	assert_dict(info).is_not_empty()
	# v7.x: 实际字段名是 display_name（非 name）；description/faction_id 是 v6.9 势力系统加的。
	assert_dict(info).contains_keys(["display_name", "description"])
