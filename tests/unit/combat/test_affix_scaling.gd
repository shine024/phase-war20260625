class_name AffixScalingTest
extends GdUnitTestSuite

const _SOURCE := "res://managers/affix_manager.gd"

var _manager: Node


func before_test() -> void:
	_manager = Node.new()
	_manager.set_script(load(_SOURCE))
	add_child(_manager)


func after_test() -> void:
	# v7.x: 守卫 remove_child（manager _ready 异常时 parent 关系可能未建立），queue_free 更安全。
	if _manager != null and is_instance_valid(_manager):
		if _manager.is_inside_tree():
			remove_child(_manager)
		_manager.queue_free()
	_manager = null


func test_enhance_count_grows_with_level() -> void:
	# v7.x: Godot 4.5 无法从动态 _manager 方法推断返回类型，显式标注 int。
	var low: int = _manager._get_enhance_count_for_level(1)
	var high: int = _manager._get_enhance_count_for_level(60)
	assert_int(high).is_greater_equal(low)


func test_apply_affixes_to_stats_accepts_empty_cards() -> void:
	var dummy_stats = UnitStats.new()
	_manager.apply_affixes_to_stats(dummy_stats, null, [])
	assert_object(dummy_stats).is_not_null()
