# GdUnit4 定向 runner — 2026-09-19 经济/掉落修复批回归
# 用法: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_gdunit_econ_runner.gd -- <test_dir>
# 例:   ... -- res://tests/unit/economy
# （gdunit CLI 的 -a 重复传参只生效最后一个——每轮只跑一个目录，分多次调用）
extends SceneTree

const _GdUnitTestCIRunner := preload("res://addons/gdunit4/src/core/runners/GdUnitTestCIRunner.gd")

func _initialize() -> void:
	var user_args := OS.get_cmdline_user_args()
	var target := "res://tests/unit/economy"
	if user_args.size() > 0:
		target = user_args[0]
	print("[econ-runner] target=", target)
	var runner = _GdUnitTestCIRunner.new()
	var injected: PackedStringArray = ["res://addons/gdunit4/bin/GdUnitCmdTool.gd", "--ignoreHeadlessMode", "-c", "-a", target]
	@warning_ignore("unsafe_property_access")
	runner._debug_cmd_args = injected
	root.add_child(runner)
