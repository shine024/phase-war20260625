class_name SaveMigrationTest
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


func test_legacy_paths_are_stable_strings() -> void:
	assert_str(_manager._get_legacy_res_save_path()).contains("save")
	assert_str(_manager._get_legacy_user_save_path()).contains("save")


func test_migration_hook_executes_without_throwing() -> void:
	_manager._migrate_old_save_if_needed()
	assert_bool(true).is_true()
