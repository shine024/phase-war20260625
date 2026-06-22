# 无 GdUnit 依赖的快速校验：main.tscn 能否被引擎正确解析加载。
# 验证目标：ext_resource 声明无语法错误（如行尾逗号 / 多余 ]）。
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/main_scene_parse_smoke.gd
extends SceneTree


func _initialize() -> void:
	var code := 0
	var packed = load("res://scenes/main.tscn")
	if packed == null:
		push_error("main.tscn load failed (returned null) — likely a parse error in the scene file")
		code = 1
	elif not (packed is PackedScene):
		push_error("main.tscn loaded but is not a PackedScene: %s" % str(packed))
		code = 1
	else:
		print("main_scene_parse_smoke: OK — main.tscn parsed cleanly")
	quit(code)
