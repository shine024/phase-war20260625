# GdUnit4 test runner — invoked by CI and /smoke-check
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/gdunit4_runner.gd
# 等价 CLI：godot ... -s res://addons/gdunit4/bin/GdUnitCmdTool.gd -- --ignoreHeadlessMode -c -a res://tests/unit
extends SceneTree

const _GdUnitTestCIRunner := preload("res://addons/gdunit4/src/core/runners/GdUnitTestCIRunner.gd")


func _initialize() -> void:
	if not DirAccess.dir_exists_absolute("res://tests/unit"):
		push_error("Missing tests/unit directory.")
		quit(1)
		return
	if not DirAccess.dir_exists_absolute("res://tests/integration"):
		push_warning("tests/integration directory not found; only unit tests will run.")

	var runner = _GdUnitTestCIRunner.new()
	# 首参必须是含工具名的脚本路径：CmdArgumentParser.parse 会弹空参数直到遇见
	# 含工具名的项——缺了它则全部参数被弹光 → 空结果 → 打帮助退出 0（假绿，零测试跑过）
	var injected: PackedStringArray = ["res://addons/gdunit4/bin/GdUnitCmdTool.gd", "--ignoreHeadlessMode", "-c", "-a", "res://tests/unit"]
	if DirAccess.dir_exists_absolute("res://tests/integration"):
		injected.append_array(["-a", "res://tests/integration"])
	@warning_ignore("unsafe_property_access")
	runner._debug_cmd_args = injected
	root.add_child(runner)
