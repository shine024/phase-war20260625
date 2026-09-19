class_name StarterIntelFloorTest
extends GdUnitTestSuite
## v37 节奏轮回归锁：新档情报地板（IntelManual.grant_intel_floor，2026-09-16）
##
## 背景（用户拍板）：制造中心提前到通关第 1 关解锁后，新档在
## SaveManager._enqueue_starter_backpack_cards 末段给起始三卡（毛瑟步枪班/81mm迫击炮组/
## FT-17坦克）的敌形原型赠 25% 情报地板——进制造中心即可立刻制造同族补战力。
##
## 契约：
## - grant_intel_floor 只抬不降：低于地板抬到地板，已高于地板保持原值
## - 入账走 _add_intel 正门：base 单调同步、档位跨档信号语义与交战路径一致
## - 地板 = ManufacturePools.GATE_RECIPE(0.25) → 池档 1（白板档，普通 100% 可造）
## - floor 超界钳到 [0,1]

const IntelManualScript = preload("res://scripts/systems/intel_manual.gd")
const ManufacturePoolsRef = preload("res://data/manufacture_pools.gd")

var _im: Node = null


func before_test() -> void:
	_im = IntelManualScript.new()


func after_test() -> void:
	if _im != null and is_instance_valid(_im):
		_im.free()
	_im = null


func test_floor_lifts_to_target() -> void:
	_im.grant_intel_floor("pw_test_arch", 0.25)
	assert_float(float(_im.get_intel_progress("pw_test_arch"))).is_equal_approx(0.25, 0.0001)


func test_floor_never_lowers() -> void:
	_im.grant_intel_floor("pw_test_arch", 0.25)
	_im.grant_intel_floor("pw_test_arch", 0.10)
	assert_float(float(_im.get_intel_progress("pw_test_arch"))).is_equal_approx(0.25, 0.0001)
	# 交战/侦察路径推进后地板不回退（高于地板时 grant 是 no-op）
	_im.grant_intel_floor("pw_test_arch", 0.5)
	assert_float(float(_im.get_intel_progress("pw_test_arch"))).is_equal_approx(0.5, 0.0001)


func test_base_monotonic_sync() -> void:
	_im.grant_intel_floor("pw_test_arch", 0.25)
	assert_float(float(_im.get_base_progress("pw_test_arch"))).is_equal_approx(0.25, 0.0001)


func test_floor_matches_recipe_gate() -> void:
	assert_float(float(ManufacturePoolsRef.GATE_RECIPE)).is_equal(0.25)
	# 25% 恰过配方门 → 池档 1（白板档：普通 100% 起步，品质阶梯留给后续交战推进）
	assert_int(ManufacturePoolsRef.get_pool_tier(0.25)).is_equal(1)
	assert_int(ManufacturePoolsRef.get_pool_tier(0.24)).is_equal(0)


func test_floor_clamped_to_unit_range() -> void:
	_im.grant_intel_floor("pw_test_arch", 2.0)
	assert_float(float(_im.get_intel_progress("pw_test_arch"))).is_equal_approx(1.0, 0.0001)
