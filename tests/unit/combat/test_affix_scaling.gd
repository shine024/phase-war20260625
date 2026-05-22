class_name AffixScalingTest
extends GdUnitTestSuite

const _SOURCE := "res://managers/affix_manager.gd"

var _manager: Node


func before_test() -> void:
	_manager = Node.new()
	_manager.set_script(load(_SOURCE))
	add_child(_manager)


func after_test() -> void:
	remove_child(_manager)
	_manager.free()


func test_enhance_count_grows_with_level() -> void:
	var low := _manager._get_enhance_count_for_level(1)
	var high := _manager._get_enhance_count_for_level(60)
	assert_int(high).is_greater_equal(low)


func test_apply_affixes_to_stats_accepts_empty_cards() -> void:
	var dummy_stats = UnitStats.new()
	_manager.apply_affixes_to_stats(dummy_stats, null, [])
	assert_object(dummy_stats).is_not_null()
