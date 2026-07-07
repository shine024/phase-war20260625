class_name EnergyEconomyLoopTest
extends GdUnitTestSuite

const _SOURCE := "res://managers/energy_manager.gd"

var _manager: Node


func before_test() -> void:
	_manager = Node.new()
	_manager.set_script(load(_SOURCE))
	add_child(_manager)
	_manager.current = 20.0
	_manager._max = 100.0


func after_test() -> void:
	# v7.x: 守卫 remove_child（manager _ready 异常时 parent 关系可能未建立），queue_free 更安全。
	if _manager != null and is_instance_valid(_manager):
		if _manager.is_inside_tree():
			remove_child(_manager)
		_manager.queue_free()
	_manager = null


func test_spend_then_add_returns_expected_balance() -> void:
	assert_bool(_manager.spend(5.0)).is_true()
	_manager.add_energy(7.0)
	assert_float(_manager.current).is_equal(22.0)


func test_spend_insufficient_preserves_balance() -> void:
	# v7.x: Godot 4.5 无法从动态 _manager 属性推断类型，显式标注 float。
	var before: float = _manager.current
	assert_bool(_manager.spend(999.0)).is_false()
	assert_float(_manager.current).is_equal(before)
