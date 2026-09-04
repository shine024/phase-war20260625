class_name DeployCommandTest
extends GdUnitTestSuite
## v26.13(D-2) 数据锁：指令轮盘的索敌语义。
## 集火：_take_focus_target（target_selection 静态函数，纯逻辑可直接测）——
##   目标在候选中必选 / 不在候选回退 null / 死亡失效 / 无指令 null。
## 守住：消费点源码存在性锁（find_target 门）。

const TargetSelection = preload("res://scripts/battle/target_selection.gd")


func _mk_unit(pos: Vector2) -> Node2D:
	var u := Node2D.new()
	u.position = pos
	add_child(u)
	return u


func _wrap(u: Node2D) -> WeakRef:
	return weakref(u)


func test_focus_target_in_candidates_wins() -> void:
	var attacker := _mk_unit(Vector2.ZERO)
	var enemy_a := _mk_unit(Vector2(100, 0))
	var enemy_b := _mk_unit(Vector2(200, 0))
	attacker.set_meta("_focus_target_ref", _wrap(enemy_b))
	var picked: Node2D = TargetSelection._take_focus_target(attacker, [enemy_a, enemy_b])
	assert_object(picked).is_equal(enemy_b)


func test_focus_target_outside_candidates_falls_back() -> void:
	var attacker := _mk_unit(Vector2.ZERO)
	var enemy_a := _mk_unit(Vector2(100, 0))
	var outsider := _mk_unit(Vector2(500, 0))
	attacker.set_meta("_focus_target_ref", _wrap(outsider))
	# 集火目标不在候选（超射程被上游过滤）→ 返回 null，回退正常索敌
	assert_object(TargetSelection._take_focus_target(attacker, [enemy_a])).is_null()


func test_focus_target_freed_is_ignored() -> void:
	var attacker := _mk_unit(Vector2.ZERO)
	var doomed := _mk_unit(Vector2(100, 0))
	attacker.set_meta("_focus_target_ref", _wrap(doomed))
	doomed.free()  # 模拟目标被击杀释放
	var candidates := [_mk_unit(Vector2(100, 0))]
	assert_object(TargetSelection._take_focus_target(attacker, candidates)).is_null()


func test_no_command_returns_null() -> void:
	var attacker := _mk_unit(Vector2.ZERO)
	var enemy := _mk_unit(Vector2(100, 0))
	assert_object(TargetSelection._take_focus_target(attacker, [enemy])).is_null()


func test_command_consumers_present() -> void:
	# 守住门（AI 侧）与轮盘 UI 存在性锁
	var ai_src: String = FileAccess.get_file_as_string("res://scripts/battle/construct_unit_ai.gd")
	assert_bool(ai_src.contains("_cmd_hold")).is_true()
	var wheel_src: String = FileAccess.get_file_as_string("res://scenes/ui/deploy_command_wheel.gd")
	assert_bool(wheel_src.contains('"focus"')).is_true()
	assert_bool(wheel_src.contains('"hold"')).is_true()
	var overlay_src: String = FileAccess.get_file_as_string("res://scenes/ui/battle_click_overlay.gd")
	assert_bool(overlay_src.contains("_MAX_ACTIVE_COMMANDS")).is_true()
	assert_bool(overlay_src.contains("_focus_pick")).is_true()
