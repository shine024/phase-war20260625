# GdUnit4 教程相关测试过滤运行器 — v5 教程整合批
extends SceneTree

const _GdUnitTestCIRunner := preload("res://addons/gdunit4/src/core/runners/GdUnitTestCIRunner.gd")

func _initialize() -> void:
	var runner = _GdUnitTestCIRunner.new()
	var injected: PackedStringArray = ["res://addons/gdunit4/bin/GdUnitCmdTool.gd", "--ignoreHeadlessMode", "-c",
		"-a", "res://tests/unit/managers/test_tutorial_step_integration.gd",
		"-a", "res://tests/unit/managers/test_tutorial_pointer_flow.gd",
		"-a", "res://tests/unit/managers/test_tutorial_battle_focus.gd",
		"-a", "res://tests/unit/ui/test_tutorial_overlay_z_order.gd",
		"-a", "res://tests/unit/ui/test_tutorial_pointer_lifecycle.gd",
		"-a", "res://tests/unit/systems/test_tutorial_save_fresh.gd"]
	@warning_ignore("unsafe_property_access")
	runner._debug_cmd_args = injected
	root.add_child(runner)
