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
	remove_child(_manager)
	_manager.free()


func test_spend_then_add_returns_expected_balance() -> void:
	assert_bool(_manager.spend(5.0)).is_true()
	_manager.add_energy(7.0)
	assert_float(_manager.current).is_equal(22.0)


func test_spend_insufficient_preserves_balance() -> void:
	var before := _manager.current
	assert_bool(_manager.spend(999.0)).is_false()
	assert_float(_manager.current).is_equal(before)
