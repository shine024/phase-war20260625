class_name EnergyManagerTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

const __source: String = 'res://managers/energy_manager.gd'
const GC = preload('res://resources/game_constants.gd')

var _manager: Node


func before_test() -> void:
	_manager = Node.new()
	var script = load(__source)
	_manager.set_script(script)
	add_child(_manager)
	# 手动初始化能量值（跳过 _ready 的 GC 依赖）
	_manager.current = 0.0
	_manager._max = GC.ENERGY_MAX
	_manager._base_start = GC.ENERGY_START
	_manager._in_battle = false


func after_test() -> void:
	remove_child(_manager)
	_manager.free()


## 初始能量值
func test_initial_energy() -> void:
	# _ready 未被调用（因为我们是手动添加子节点），手动设置
	_manager._reset_to_start()
	assert_float(_manager.get_current()).is_equal(GC.ENERGY_START)
	assert_float(_manager.get_max()).is_equal(GC.ENERGY_MAX)


## get_current 和 get_max 返回正确的值
func test_getters() -> void:
	_manager.current = 75.5
	_manager._max = 100.0
	assert_float(_manager.get_current()).is_equal(75.5)
	assert_float(_manager.get_max()).is_equal(100.0)


## can_afford 在足够时返回 true
func test_can_afford_true() -> void:
	_manager.current = 50.0
	_manager._max = 100.0
	assert_bool(_manager.can_afford(30.0)).is_true()


## can_afford 在不够时返回 false
func test_can_afford_false() -> void:
	_manager.current = 20.0
	_manager._max = 100.0
	assert_bool(_manager.can_afford(30.0)).is_false()


## can_afford 在恰好相等时返回 true
func test_can_afford_exact() -> void:
	_manager.current = 50.0
	_manager._max = 100.0
	assert_bool(_manager.can_afford(50.0)).is_true()


## spend 在足够时扣除能量并返回 true
func test_spend_success() -> void:
	_manager.current = 50.0
	_manager._max = 100.0
	var result = _manager.spend(20.0)
	assert_bool(result).is_true()
	assert_float(_manager.current).is_equal(30.0)


## spend 在不够时返回 false 且不扣除
func test_spend_insufficient() -> void:
	_manager.current = 10.0
	_manager._max = 100.0
	var result = _manager.spend(20.0)
	assert_bool(result).is_false()
	assert_float(_manager.current).is_equal(10.0)


## spend 不会让能量降到 0 以下
func test_spend_does_not_go_below_zero() -> void:
	_manager.current = 5.0
	_manager._max = 100.0
	_manager.spend(10.0)
	assert_float(_manager.current).is_equal(0.0)


## add_energy 增加能量
func test_add_energy() -> void:
	_manager.current = 30.0
	_manager._max = 100.0
	_manager.add_energy(20.0)
	assert_float(_manager.current).is_equal(50.0)


## add_energy 不超过 _max
func test_add_energy_clamps_to_max() -> void:
	_manager.current = 90.0
	_manager._max = 100.0
	_manager.add_energy(50.0)
	assert_float(_manager.current).is_equal(100.0)


## _add_energy 不会让能量低于 0
func test_add_negative_energy_clamps_to_zero() -> void:
	_manager.current = 10.0
	_manager._max = 100.0
	_manager._add_energy(-50.0)
	assert_float(_manager.current).is_equal(0.0)


## spend 花费 0 返回 true
func test_spend_zero() -> void:
	_manager.current = 10.0
	_manager._max = 100.0
	var result = _manager.spend(0.0)
	assert_bool(result).is_true()
	assert_float(_manager.current).is_equal(10.0)


## _reset_to_start 重置到默认值
func test_reset_to_start() -> void:
	_manager.current = 0.0
	_manager._max = 1.0
	_manager._base_start = 0.0
	_manager._reset_to_start()
	assert_float(_manager.current).is_equal(GC.ENERGY_START)
	assert_float(_manager._max).is_equal(GC.ENERGY_MAX)
	assert_float(_manager._base_start).is_equal(GC.ENERGY_START)


## start_battle 设置战斗状态
func test_start_battle() -> void:
	_manager._base_start = 80.0
	_manager._max = 120.0
	_manager.current = 0.0
	_manager.start_battle()
	assert_bool(_manager._in_battle).is_true()
	# start_battle 调用 _apply_equipped_energy_cards（依赖 autoload）
	# 当 PhaseInstrumentManager 不存在时，_base_start 被重置为 0
	# 然后 fallback 逻辑设置 _base_start = GC.ENERGY_START
	assert_float(_manager.current).is_equal(GC.ENERGY_START)


## start_battle 无能量卡时使用默认值
func test_start_battle_no_energy_cards_uses_defaults() -> void:
	# PhaseInstrumentManager 不存在时
	_manager.start_battle()
	assert_float(_manager.current).is_equal(GC.ENERGY_START)
	assert_float(_manager._max).is_equal(GC.ENERGY_MAX)


## end_battle 退出战斗状态
func test_end_battle() -> void:
	_manager._in_battle = true
	_manager.end_battle()
	assert_bool(_manager._in_battle).is_false()


## start_battle 确保 _base_start 不为 0
func test_start_battle_guarantees_base_start_positive() -> void:
	_manager._base_start = 0.0
	_manager.start_battle()
	# Fallback 逻辑会设置 _base_start = GC.ENERGY_START
	assert_float(_manager._base_start).is_greater(0.0)
