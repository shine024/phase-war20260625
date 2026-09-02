class_name DroneMarkUniformTest
extends GdUnitTestSuite

## v26.6 批3 回归锁：无人机标记时间戳口径统一秒制 + 过期清理全局节流
##
## 背景：_drone_marked_until 原有两条写入口径分裂（manager 写毫秒 / construct_unit 写秒），
## 消费端一半按毫秒比一半按秒比 → 机制7 标记的易伤/连锁加成从未生效、manager 标记显示
## 成永久标记。统一秒制后此锁防回退。

const CAM := preload("res://managers/card_ability_manager.gd")


func _mk_unit(pos: Vector2) -> Node2D:
	var u := Node2D.new()
	u.position = pos
	return auto_free(u)


func _reset_sweep_throttle() -> void:
	# 测试内多次调 update_drone_mark_expiry 需重置 250ms 全局节流守卫
	CAM._last_mark_sweep_msec = -1000000


func test_auto_mark_writes_second_scale_timestamp() -> void:
	var shooter := _mk_unit(Vector2.ZERO)
	add_child(shooter)
	# _has_tag 从 meta 缓存读——直接注入 attack_drone 标签
	shooter.set_meta("_ability_tags", ["attack_drone"])
	var enemy := _mk_unit(Vector2(100, 0))
	add_child(enemy)
	enemy.add_to_group("enemy_units")
	var before_sec: float = Time.get_ticks_msec() / 1000.0
	# 大 delta 直接耗尽 12s CD 触发标记
	CAM.update_drone_auto_mark(shooter, 999.0)
	assert_bool(enemy.has_meta("_drone_marked_until")).is_true()
	var until: float = float(enemy.get_meta("_drone_marked_until", 0.0))
	# 秒制判据：until ≈ before+8（毫秒制残留会是 before*1000+8000 量级，必大于 before+10）
	assert_float(until).is_greater(before_sec + 7.0)
	assert_float(until).is_less(before_sec + 10.0)


func test_vuln_multiplier_reads_second_scale_mark() -> void:
	var target := _mk_unit(Vector2.ZERO)
	add_child(target)
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	# 模拟 construct_unit 机制7 写侧（秒制）
	target.set_meta("_drone_marked_until", now_sec + 5.0)
	target.set_meta("_drone_mark_vuln", 0.25)
	# 原毫秒比较下秒值恒判过期、乘数恒 1.0——统一后必须读到 1.25
	assert_float(CAM.get_drone_mark_vuln_multiplier(target)).is_equal(1.25)
	# 过期标记乘数回归 1.0
	target.set_meta("_drone_marked_until", now_sec - 1.0)
	assert_float(CAM.get_drone_mark_vuln_multiplier(target)).is_equal(1.0)


func test_expiry_sweep_keeps_live_and_clears_expired() -> void:
	var live := _mk_unit(Vector2.ZERO)
	add_child(live)
	live.add_to_group("enemy_units")  # 清理扫描只覆盖 enemy_units/player_units 两组
	var expired := _mk_unit(Vector2(50, 0))
	add_child(expired)
	expired.add_to_group("enemy_units")
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	live.set_meta("_drone_marked_until", now_sec + 5.0)
	live.set_meta("_drone_mark_vuln", 0.25)
	expired.set_meta("_drone_marked_until", now_sec - 1.0)
	expired.set_meta("_drone_mark_vuln", 0.25)
	_reset_sweep_throttle()
	CAM.update_drone_mark_expiry(0.016)
	# 未过期标记不得被清（原毫秒比较把秒值标记当帧清掉）
	assert_bool(live.has_meta("_drone_marked_until")).is_true()
	assert_bool(live.has_meta("_drone_mark_vuln")).is_true()
	# 过期标记被清
	assert_bool(expired.has_meta("_drone_marked_until")).is_false()
	assert_bool(expired.has_meta("_drone_mark_vuln")).is_false()


func test_expiry_sweep_throttled_within_interval() -> void:
	var u := _mk_unit(Vector2.ZERO)
	add_child(u)
	u.add_to_group("enemy_units")
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	u.set_meta("_drone_marked_until", now_sec - 1.0)  # 已过期
	_reset_sweep_throttle()
	CAM.update_drone_mark_expiry(0.016)  # 首调：执行清理
	assert_bool(u.has_meta("_drone_marked_until")).is_false()
	# 节流窗口内的第二次调用被拦（守卫生效——N×M/帧 扫描降为 4 次/秒）
	CAM._last_mark_sweep_msec = Time.get_ticks_msec()
	u.set_meta("_drone_marked_until", now_sec - 1.0)
	CAM.update_drone_mark_expiry(0.016)
	assert_bool(u.has_meta("_drone_marked_until")).is_true()  # 未清=节流拦截成功
