extends SceneTree
## 临时校验：逐个 load 本批编辑的脚本/场景，解析失败立即暴露（--script 模式直跑）
func _initialize() -> void:
	var files := [
		"res://scenes/title_screen.gd",
		"res://scenes/title_screen.tscn",
		"res://scenes/ui/settings_panel.gd",
		"res://scenes/ui/afk_panel.gd",
		"res://scenes/bunker/truck_base.gd",
		"res://scenes/ui/faction_panel.gd",
		"res://scenes/ui/growth_panel.gd",
		"res://scenes/ui/backpack/backpack_presenter.gd",
		"res://tests/_tmp_art_cap.gd",
		"res://tests/_tmp_art_ui_cap.gd",
		"res://tests/_tmp_art_verify_cap.gd",
	]
	var fail := 0
	for f in files:
		var res: Resource = load(f)
		if res == null:
			print("LOAD_FAIL ", f)
			fail += 1
		else:
			print("LOAD_OK ", f)
	print("COMPILE_CHECK_DONE fail=", fail)
	quit(fail)
