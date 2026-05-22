class_name SaveIntegrityTest
extends GdUnitTestSuite

const _SOURCE := "res://managers/save_manager.gd"

var _manager: Node


func before_test() -> void:
	_manager = Node.new()
	_manager.set_script(load(_SOURCE))
	add_child(_manager)


func after_test() -> void:
	remove_child(_manager)
	_manager.free()


func test_slot_set_and_get_roundtrip() -> void:
	_manager.set_slot(2)
	assert_int(_manager.get_slot()).is_equal(2)


func test_slot_file_path_contains_slot_number() -> void:
	var path := _manager._slot_file(3)
	assert_str(path).contains("slot_3")
