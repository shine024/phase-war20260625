# v27 排查用：分步加载，定位 --script 模式挂在哪个文件（临时工具）
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_rift_fx_bisect.gd
extends SceneTree


func _step(msg: String) -> void:
	print("[Bisect] ", msg)


func _initialize() -> void:
	_step("start")
	_step("load battle_env_effects")
	var r1 = load("res://data/battle_env_effects.gd")
	_step("  -> %s" % [r1 != null])
	_step("load endless_blackgate_manager")
	var r2 = load("res://managers/endless_blackgate_manager.gd")
	_step("  -> %s" % [r2 != null])
	_step("load endless_rift_ambience")
	var r3 = load("res://scripts/battle/endless_rift_ambience.gd")
	_step("  -> %s" % [r3 != null])
	_step("load endless_warp shader")
	var r4 = load("res://shaders/endless_warp.gdshader")
	_step("  -> %s" % [r4 != null])
	_step("load battlefield")
	var r5 = load("res://scenes/battlefield/battlefield.gd")
	_step("  -> %s" % [r5 != null])
	_step("load shot tool")
	var r6 = load("res://tests/_tmp_ui_battle_shot.gd")
	_step("  -> %s" % [r6 != null])
	_step("done")
	quit(0)
