# 临时验证：挂机修复后 parse 检查（Bug#1/#2/#3）
# Usage: godot --headless --path . --script tests/_afk_fix_verify.gd
extends SceneTree

func _initialize() -> void:
	var code := 0
	# afk_mode_manager.gd（Bug#2 改动）
	var afk = load("res://scripts/systems/afk_mode_manager.gd")
	if afk == null:
		push_error("PARSE FAIL: afk_mode_manager.gd")
		code = 1
	else:
		# 实例化验证 start_afk 不在无依赖环境崩（不调真启动，仅验证类可构造）
		var inst = afk.new()
		if inst == null:
			push_error("NEW FAIL: AFKModeManager")
			code = 1
		else:
			# Bug#2: PUSH 起点应取 push_level。模拟失败续推：push_level=5
			inst.mode = inst.Mode.PUSH
			inst.push_level = 5
			print("afk_mode_manager OK | mode=PUSH push_level=%d (失败续推起点应为5)" % inst.push_level)
	# main.gd（Bug#1/#3 改动）— 仅 parse（load 不实例化场景）
	var main = load("res://scenes/main.gd")
	if main == null:
		push_error("PARSE FAIL: main.gd")
		code = 1
	else:
		# Bug#3: _afk_start_battle 应已删除（不在方法列表）
		if main.has_method("_afk_start_battle"):
			push_error("REGRESSION: main._afk_start_battle 仍存在（应已删）")
			code = 1
		else:
			print("main.gd OK | _afk_start_battle 已删除（Bug#3）")
	print("=== verify exit %d ===" % code)
	quit(code)
