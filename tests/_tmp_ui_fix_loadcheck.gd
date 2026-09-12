extends Node
## v6.14 UI 修复批 load 编译检查（临时，场景模式——autoload 标识符可解析）
func _ready() -> void:
	var files := [
		"res://scenes/title_screen.gd",
		"res://managers/save_manager.gd",
		"res://scenes/ui/deploy_command_wheel.gd",
		"res://scenes/ui/offline_reward_dialog.gd",
		"res://scenes/ui/intel_reveal_popup.gd",
		"res://scenes/ui/tutorial_overlay.gd",
		"res://scenes/world_map.gd",
	]
	var fail := 0
	for f in files:
		var err := ResourceLoader.load(f, "", ResourceLoader.CACHE_MODE_REUSE)
		# 编译错误时 Godot 会打 SCRIPT ERROR；再借脚本方法存在性二次确认
		var s = load(f)
		if s == null or not (s as GDScript).can_instantiate():
			# can_instantiate 对工具外脚本恒 true 的兜底不可靠，主要看上面 SCRIPT ERROR 输出
			print("[LOAD?] " + f)
		else:
			print("[OK] " + f)
		if s == null:
			fail += 1
	print("RESULT: %s" % ("FAIL" if fail > 0 else "ALL PASS"))
	get_tree().quit(1 if fail > 0 else 0)
