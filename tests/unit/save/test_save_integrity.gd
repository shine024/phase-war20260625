class_name SaveIntegrityTest
extends GdUnitTestSuite

const _SOURCE := "res://managers/save_manager.gd"

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


func test_slot_set_and_get_roundtrip() -> void:
	_manager.set_slot(2)
	assert_int(_manager.get_slot()).is_equal(2)


func test_slot_file_path_contains_slot_number() -> void:
	# v7.x: Godot 4.5 无法从动态 _manager 方法推断类型，显式标注 String。
	var path: String = _manager._slot_file(3)
	assert_str(path).contains("slot_3")
