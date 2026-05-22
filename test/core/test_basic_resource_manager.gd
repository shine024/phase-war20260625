class_name BasicResourceManagerTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

const __source: String = 'res://managers/basic_resource_manager.gd'
const BasicResources = preload('res://data/basic_resources.gd')

var _manager: Node


func before_test() -> void:
	_manager = Node.new()
	var script = load(__source)
	_manager.set_script(script)
	add_child(_manager)


func after_test() -> void:
	remove_child(_manager)
	_manager.free()


## 初始状态所有资源为 0
func test_initial_state_all_zero() -> void:
	assert_int(_manager.total_nano_materials).is_equal(0)
	assert_int(_manager.total_alloy).is_equal(0)
	assert_int(_manager.total_crystal).is_equal(0)
	assert_int(_manager.total_energy_block).is_equal(0)


## add_resource 增加纳米材料
func test_add_resource_nano_materials() -> void:
	_manager.add_resource(BasicResources.ID_NANO_MATERIALS, 100)
	assert_int(_manager.total_nano_materials).is_equal(100)


## add_resource 增加合金
func test_add_resource_alloy() -> void:
	_manager.add_resource(BasicResources.ID_ALLOY, 50)
	assert_int(_manager.total_alloy).is_equal(50)


## add_resource 增加晶体
func test_add_resource_crystal() -> void:
	_manager.add_resource(BasicResources.ID_CRYSTAL, 30)
	assert_int(_manager.total_crystal).is_equal(30)


## add_resource 增加能量块
func test_add_resource_energy_block() -> void:
	_manager.add_resource(BasicResources.ID_ENERGY_BLOCK, 20)
	assert_int(_manager.total_energy_block).is_equal(20)


## add_resource 数量为 0 时不变化
func test_add_resource_zero_does_nothing() -> void:
	_manager.add_resource(BasicResources.ID_NANO_MATERIALS, 100)
	_manager.add_resource(BasicResources.ID_NANO_MATERIALS, 0)
	assert_int(_manager.total_nano_materials).is_equal(100)


## add_resource 未知 ID 不影响任何资源
func test_add_resource_unknown_id_ignored() -> void:
	_manager.add_resource("unknown_resource", 999)
	assert_int(_manager.total_nano_materials).is_equal(0)
	assert_int(_manager.total_alloy).is_equal(0)


## add_resource 负数不会低于 0
func test_add_resource_negative_clamps_to_zero() -> void:
	_manager.add_resource(BasicResources.ID_NANO_MATERIALS, 10)
	_manager.add_resource(BasicResources.ID_NANO_MATERIALS, -999)
	assert_int(_manager.total_nano_materials).is_equal(0)


## get_total 返回正确的值
func test_get_total_returns_correct_value() -> void:
	_manager.add_resource(BasicResources.ID_NANO_MATERIALS, 200)
	_manager.add_resource(BasicResources.ID_ALLOY, 150)
	assert_int(_manager.get_total(BasicResources.ID_NANO_MATERIALS)).is_equal(200)
	assert_int(_manager.get_total(BasicResources.ID_ALLOY)).is_equal(150)


## get_total 未知 ID 返回 0
func test_get_total_unknown_id_returns_zero() -> void:
	assert_int(_manager.get_total("nonexistent")).is_equal(0)


## get_total 兼容旧 ID "basic_nano"
func test_get_total_legacy_id_basic_nano() -> void:
	_manager.add_resource(BasicResources.ID_NANO_MATERIALS, 77)
	assert_int(_manager.get_total("basic_nano")).is_equal(77)


## add_resource 兼容旧 ID "basic_nano"
func test_add_resource_legacy_id_basic_nano() -> void:
	_manager.add_resource("basic_nano", 55)
	assert_int(_manager.total_nano_materials).is_equal(55)
	assert_int(_manager.total_basic_nano).is_equal(55)


## add_resource 同步更新 total_basic_nano 兼容变量
func test_add_nano_syncs_basic_nano_compat_var() -> void:
	_manager.add_resource(BasicResources.ID_NANO_MATERIALS, 42)
	assert_int(_manager.total_basic_nano).is_equal(42)


## add_basic_resource 同样正常工作
func test_add_basic_resource_works() -> void:
	_manager.add_basic_resource("nano_materials", 80)
	assert_int(_manager.total_nano_materials).is_equal(80)


## 多次累加正确
func test_add_resource_multiple_times() -> void:
	_manager.add_resource(BasicResources.ID_ENERGY_BLOCK, 10)
	_manager.add_resource(BasicResources.ID_ENERGY_BLOCK, 15)
	_manager.add_resource(BasicResources.ID_ENERGY_BLOCK, 5)
	assert_int(_manager.total_energy_block).is_equal(30)


## get_all_totals 返回所有资源的字典
func test_get_all_totals() -> void:
	_manager.add_resource(BasicResources.ID_NANO_MATERIALS, 100)
	_manager.add_resource(BasicResources.ID_ALLOY, 50)
	_manager.add_resource(BasicResources.ID_CRYSTAL, 25)
	_manager.add_resource(BasicResources.ID_ENERGY_BLOCK, 10)
	var all = _manager.get_all_totals()
	assert_int(all[BasicResources.ID_NANO_MATERIALS]).is_equal(100)
	assert_int(all[BasicResources.ID_ALLOY]).is_equal(50)
	assert_int(all[BasicResources.ID_CRYSTAL]).is_equal(25)
	assert_int(all[BasicResources.ID_ENERGY_BLOCK]).is_equal(10)
	assert_int(all["basic_nano"]).is_equal(100)


## save_state 返回正确的快照
func test_save_state() -> void:
	_manager.add_resource(BasicResources.ID_NANO_MATERIALS, 300)
	_manager.add_resource(BasicResources.ID_ENERGY_BLOCK, 5)
	var state = _manager.save_state()
	assert_int(state["total_nano_materials"]).is_equal(300)
	assert_int(state["total_energy_block"]).is_equal(5)
	assert_int(state["total_basic_nano"]).is_equal(300)


## load_state 正确恢复资源
func test_load_state() -> void:
	_manager.add_resource(BasicResources.ID_NANO_MATERIALS, 999)
	var data = {
		"total_nano_materials": 500,
		"total_alloy": 200,
		"total_crystal": 100,
		"total_energy_block": 50,
	}
	_manager.load_state(data)
	assert_int(_manager.total_nano_materials).is_equal(500)
	assert_int(_manager.total_alloy).is_equal(200)
	assert_int(_manager.total_crystal).is_equal(100)
	assert_int(_manager.total_energy_block).is_equal(50)


## load_state 缺失字段时使用默认值 0
func test_load_state_missing_fields_default_to_zero() -> void:
	_manager.load_state({"total_nano_materials": 10})
	assert_int(_manager.total_alloy).is_equal(0)
	assert_int(_manager.total_crystal).is_equal(0)
	assert_int(_manager.total_energy_block).is_equal(0)


## load_state 回退到兼容字段 total_basic_nano
func test_load_state_fallback_to_basic_nano_field() -> void:
	_manager.load_state({"total_basic_nano": 123})
	assert_int(_manager.total_nano_materials).is_equal(123)


## resources_changed 信号在 add_resource 后发射
func test_resources_changed_signal_emitted() -> void:
	var signal_watcher = watch_signals(_manager)
	_manager.add_resource(BasicResources.ID_NANO_MATERIALS, 10)
	assert_signal(_manager, 'resources_changed').is_emitted(1)


## resources_changed 信号在 add_resource(0) 时不发射
func test_resources_changed_not_emitted_for_zero() -> void:
	var signal_watcher = watch_signals(_manager)
	_manager.add_resource(BasicResources.ID_NANO_MATERIALS, 0)
	assert_signal(_manager, 'resources_changed').is_not_emitted()
