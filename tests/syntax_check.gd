extends SceneTree
## 快速语法检查，不依赖任何管理器

func _init() -> void:
	print("=== 语法检查 ===\n")
	
	# 测试加载关键脚本
	var scripts_to_check = [
		"res://scenes/ui/backpack_combat_preview.gd",
		"res://scenes/ui/unit_info_panel.gd",
		"res://scenes/ui/phase_slot.gd",
		"res://data/unit_id_migration_config.gd",
	]
	
	var all_ok = true
	for script_path in scripts_to_check:
		var script = load(script_path)
		if script == null:
			print("❌ 加载失败: %s" % script_path)
			all_ok = false
		else:
			print("✅ 加载成功: %s" % script_path)
	
	if all_ok:
		print("\n✅ 所有脚本语法检查通过")
	else:
		print("\n❌ 有脚本加载失败")
	
	quit(0 if all_ok else 1)
