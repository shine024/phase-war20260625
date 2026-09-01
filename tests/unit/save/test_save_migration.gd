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


## v25.3: v8 档 → v9 升级——原 v9 迁移补的 mod_unlock_state / production_points 已随
## 解锁集/产能点整链退役（迁移体 no-op，版本号保留不回退）；迁移只 bump 版本，不动数据。
func test_v8_save_migrates_to_v9_with_defaults() -> void:
	var SaveMigrationScript: GDScript = load("res://scripts/systems/save_migration.gd")
	var data: Dictionary = {
		"__schema_version": 8,
		"basic_resources": {"total_alloy": 123, "total_nano_materials": 456},
		"blueprint": {"blueprint_mods": {}},
	}
	SaveMigrationScript.migrate_save_data(data, 8)
	assert_int(int(data["__schema_version"])).is_equal(9)
	# v25.3 起迁移不再补退役键；既有资源字段原样保留
	assert_bool(data.has("mod_unlock_state")).is_false()
	var br: Dictionary = data["basic_resources"]
	assert_bool(br.has("production_points")).is_false()
	assert_int(int(br["total_alloy"])).is_equal(123)
	assert_int(int(br["total_nano_materials"])).is_equal(456)


## v25.3: v9 档既有数据不被迁移覆盖（退役前旧档残留的 mod_unlock_state / production_points
## key 原样保留在数据里——读写两侧均已无消费方，下一次存档自然落盘丢弃）。
func test_v9_existing_values_not_overwritten_and_fresh_defaults() -> void:
	var SaveMigrationScript: GDScript = load("res://scripts/systems/save_migration.gd")
	var data: Dictionary = {
		"__schema_version": 9,
		"mod_unlock_state": {"gen_05_shield": true, "first_kill_enemy_master_002": true},
		"basic_resources": {"production_points": 250},
	}
	SaveMigrationScript.migrate_save_data(data, 9)  # 已是最新，恒等
	assert_int(int(data["__schema_version"])).is_equal(9)
	var br: Dictionary = data["basic_resources"]
	assert_int(int(br["production_points"])).is_equal(250)
	assert_bool((data["mod_unlock_state"] as Dictionary).has("gen_05_shield")).is_true()
