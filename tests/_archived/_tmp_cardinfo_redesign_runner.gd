# 临时定向 runner（v6.14.8 情报卡改版验证用，验证完可删）
# 用法：godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_cardinfo_redesign_runner.gd
extends SceneTree

const _GdUnitTestCIRunner := preload("res://addons/gdunit4/src/core/runners/GdUnitTestCIRunner.gd")


func _initialize() -> void:
	var runner = _GdUnitTestCIRunner.new()
	var injected: PackedStringArray = [
		"res://addons/gdunit4/bin/GdUnitCmdTool.gd", "--ignoreHeadlessMode", "-c",
		"-a", "res://tests/unit/ui/test_card_info_panel_redesign.gd",
	]
	@warning_ignore("unsafe_property_access")
	runner._debug_cmd_args = injected
	root.add_child(runner)
