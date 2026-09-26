extends SceneTree
## 记录7 临时单文件 gdunit 跑法：只跑 attack_f0 一致性/朝向双门禁（全量套件太重）。

const _GdUnitTestCIRunner := preload("res://addons/gdunit4/src/core/runners/GdUnitTestCIRunner.gd")


func _initialize() -> void:
	var runner = _GdUnitTestCIRunner.new()
	var injected: PackedStringArray = [
		"res://addons/gdunit4/bin/GdUnitCmdTool.gd", "--ignoreHeadlessMode", "-c",
		"-a", "res://tests/unit/data/test_attack_f0_consistency.gd",
	]
	@warning_ignore("unsafe_property_access")
	runner._debug_cmd_args = injected
	root.add_child(runner)
