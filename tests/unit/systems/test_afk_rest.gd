extends GdUnitTestSuite
## v6.28（记录2#1）回归锁：挂机精神耗尽原地休整（RESTING）。
## 不变式：①休整不退出挂机（is_running 保持）；②60s 倒计时窗口；
## ③stop_afk 可打断（代际守卫作废在途回调）；④rest_recover_full 只回满精神、
## 不推天数不回燃料（与 sleep() 副产物划界）。测试不真等 60s——打断路径验证。

const AFKModeManagerScript = preload("res://scripts/systems/afk_mode_manager.gd")


func test_rest_constants() -> void:
	assert_float(AFKModeManagerScript.REST_SECONDS).is_equal(60.0)
	assert_bool("RESTING" in AFKModeManagerScript.State).is_true()
	assert_int(AFKModeManagerScript.State.RESTING) \
		.is_not_equal(AFKModeManagerScript.State.RUNNING)


func _make_manager() -> AFKModeManager:
	var m: AFKModeManager = AFKModeManagerScript.new()
	# battle_setup 传 null：休整链路不触战斗启动；get_node_or_null 走 /root autoload 兜底
	m.init(get_tree().root, null)
	return m


func test_begin_rest_enters_resting_with_countdown() -> void:
	var m := _make_manager()
	m.is_running = true
	m._begin_sanity_rest(true)
	assert_int(m.state).is_equal(AFKModeManagerScript.State.RESTING)
	# 挂机主链路未退出——休整是"原地歇"，不是 stop
	assert_bool(m.is_running).is_true()
	var remain := m.get_rest_remaining_seconds()
	assert_float(remain).is_greater(0.0)
	assert_float(remain).is_less_equal(60.0)
	# 收尾：打断休整并断开信号（60s timer 回调因 gen 代际被作废）
	m.shutdown()
	assert_int(m.state).is_equal(AFKModeManagerScript.State.IDLE)
	assert_float(m.get_rest_remaining_seconds()).is_equal(0.0)


func test_stop_interrupts_rest() -> void:
	var m := _make_manager()
	m.is_running = true
	m._begin_sanity_rest(false)
	assert_int(m.state).is_equal(AFKModeManagerScript.State.RESTING)
	# 手动停止 = 打断休整（stop_afk bump _travel_gen 作废 60s 恢复回调）
	m.stop_afk("manual")
	assert_bool(m.is_running).is_false()
	assert_int(m.state).is_equal(AFKModeManagerScript.State.IDLE)
	m.shutdown()


func test_rest_recover_full_restores_cap() -> void:
	var bunker: Node = get_node_or_null("/root/BunkerManager")
	if bunker == null or not bunker.has_method("rest_recover_full"):
		# 懒加载 manager：ensure 后重试；仍缺则跳过（环境无基地模块）
		ManagerLazyLoader.ensure_loaded("bunker")
		bunker = get_node_or_null("/root/BunkerManager")
	assert_object(bunker).is_not_null()
	var original: float = bunker.get_sanity()
	var original_fuel: float = float(bunker.get("_fuel"))
	var original_day: int = int(bunker.get("_day"))
	# 打到 0 → 休整恢复 → 恰为上限
	bunker.adjust_sanity(-1_000_000.0)
	assert_float(bunker.get_sanity()).is_equal(0.0)
	bunker.rest_recover_full()
	assert_float(bunker.get_sanity()).is_equal(bunker.get_sanity_cap())
	# 只回精神：天数/燃料原值不动（sleep() 的副产物一个都不许有）
	assert_float(float(bunker.get("_fuel"))).is_equal(original_fuel)
	assert_int(int(bunker.get("_day"))).is_equal(original_day)
	# 还原（内存态，不主动落盘）
	bunker.set("_sanity", original)
