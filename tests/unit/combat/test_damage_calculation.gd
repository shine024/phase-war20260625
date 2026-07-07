class_name DamageCalculationTest
extends GdUnitTestSuite

const _SOURCE := "res://managers/battle/battle_damage_system.gd"

# v7.x: battle_damage_system.gd extends RefCounted，不能 set_script 到 Node（Godot 4.5 严格检查）。
# 直接 .new() 作 RefCounted 使用，无需 add_child。
var _system: RefCounted


func before_test() -> void:
	_system = load(_SOURCE).new()


func after_test() -> void:
	# RefCounted 由引用计数自动释放，无需 free。
	_system = null


func test_calculate_victory_stars_perfect_result_is_three() -> void:
	# v7.x: Godot 4.5 无法从动态 _system 方法推断返回类型，显式标注 int。
	var stars: int = _system.calculate_victory_stars(8, 0, 25.0, 5, 8.0)
	assert_int(stars).is_equal(3)


func test_calculate_victory_stars_can_drop_on_losses() -> void:
	# v7.x: Godot 4.5 无法从动态 _system 方法推断返回类型，显式标注 int。
	var stars: int = _system.calculate_victory_stars(8, 8, 180.0, 5, 8.0)
	assert_int(stars).is_less_equal(2)
