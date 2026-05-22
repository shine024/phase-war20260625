class_name DamageCalculationTest
extends GdUnitTestSuite

const _SOURCE := "res://managers/battle/battle_damage_system.gd"

var _system: Node


func before_test() -> void:
	_system = Node.new()
	_system.set_script(load(_SOURCE))
	add_child(_system)


func after_test() -> void:
	remove_child(_system)
	_system.free()


func test_calculate_victory_stars_perfect_result_is_three() -> void:
	var stars := _system.calculate_victory_stars(8, 0, 25.0, 5, 8.0)
	assert_int(stars).is_equal(3)


func test_calculate_victory_stars_can_drop_on_losses() -> void:
	var stars := _system.calculate_victory_stars(8, 8, 180.0, 5, 8.0)
	assert_int(stars).is_less_equal(2)
