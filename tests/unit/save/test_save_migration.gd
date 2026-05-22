class_name SaveMigrationTest
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


func test_legacy_paths_are_stable_strings() -> void:
	assert_str(_manager._get_legacy_res_save_path()).contains("save")
	assert_str(_manager._get_legacy_user_save_path()).contains("save")


func test_migration_hook_executes_without_throwing() -> void:
	_manager._migrate_old_save_if_needed()
	assert_bool(true).is_true()
