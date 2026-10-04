extends GdUnitTestSuite
## v6.42 回归锁：行军可取消 + 渗透遭遇生成口守卫（记录6）。
## ① 未在途时取消=拒绝（不误清停靠态）；
## ② 取消清空在途态、车队留在出发关、本次燃料全额返还——实机主诉"移动过程中无法取消"
##    （原实现一旦启程只能等到站，被拽离第 100 关后黑门停靠门控直接锁死）；
## ③ EBM.spawn_incursion_at 守卫：未解锁/已通关（黑门关闭世界状态）恒拒绝——
##    行军遭遇链不得绕过渗透停刷口径。

const BunkerManagerScript = preload("res://managers/bunker_manager.gd")
const EBMScript = preload("res://managers/endless_blackgate_manager.gd")


func _fresh_bunker() -> Node:
	# 不挂树：避免 _ready/._process 副作用（实时到站结算不会抢跑），字段手工摆
	return BunkerManagerScript.new()


func _arm_traveling(bm: Node, parked: int, dest: int, fuel: float, spent: int) -> void:
	bm._parked_level = parked
	bm._fuel = fuel
	bm._travel_dest = dest
	bm._travel_days_total = 5
	bm._travel_started_unix = Time.get_unix_time_from_system()
	bm._travel_ends_unix = bm._travel_started_unix + 60.0
	bm._travel_fuel_spent = spent


func test_cancel_travel_rejected_when_not_traveling() -> void:
	var bm := _fresh_bunker()
	var res: Dictionary = bm.cancel_travel()
	assert_bool(bool(res.get("ok", true))).is_false()
	assert_int(bm._travel_dest).is_equal(0)
	bm.free()  # 不挂树的裸实例手动回收（防 GdUnit 孤儿告警）


func test_cancel_travel_clears_state_and_refunds_fuel() -> void:
	var bm := _fresh_bunker()
	_arm_traveling(bm, 100, 12, 40.0, 30)
	var res: Dictionary = bm.cancel_travel()
	assert_bool(bool(res.get("ok", false))).is_true()
	assert_bool(bm.is_traveling()).is_false()
	assert_int(bm._travel_dest).is_equal(0)
	assert_int(bm._travel_days_total).is_equal(0)
	assert_int(bm._parked_level).is_equal(100)  # 车队留在出发关
	assert_float(bm.get_fuel()).is_equal_approx(70.0, 0.5)  # 40 + 30 返还
	assert_int(bm._travel_fuel_spent).is_equal(0)
	bm.free()


func test_second_cancel_after_first_is_rejected() -> void:
	var bm := _fresh_bunker()
	_arm_traveling(bm, 100, 12, 40.0, 30)
	assert_bool(bool(bm.cancel_travel().get("ok", false))).is_true()
	assert_bool(bool(bm.cancel_travel().get("ok", true))).is_false()
	# 燃料不被二次返还
	assert_float(bm.get_fuel()).is_equal_approx(70.0, 0.5)
	bm.free()


func test_spawn_incursion_at_refuses_when_gate_closed() -> void:
	var e: Node = EBMScript.new()
	e.gate_cleared_once = true  # 黑门已通关=世界状态关闭，渗透停刷
	assert_bool(e.spawn_incursion_at(12)).is_false()
	assert_array(e.incursions).is_empty()
	e.free()


func test_spawn_incursion_at_refuses_when_unlock_gate_not_met() -> void:
	# 干净测试环境未通关第 100 关（level_stars 无 100 键）→ 未解锁恒拒绝
	var e: Node = EBMScript.new()
	e.gate_cleared_once = false
	assert_bool(e.spawn_incursion_at(12)).is_false()
	assert_array(e.incursions).is_empty()
	e.free()
