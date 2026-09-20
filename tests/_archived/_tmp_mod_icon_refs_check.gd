extends SceneTree
## 改造图标引用完整性检查（2026-09-02 图标修复轮）。
## 断言：①注册表总数 202 不变；②每条改造的 icon 字段指向真实存在的文件。
## 用法：godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_mod_icon_refs_check.gd

func _init() -> void:
	var MR = load("res://scripts/systems/modification_registry.gd")
	var ids: Array = MR.get_all_ids()
	var total := ids.size()
	var missing: Array = []
	var empty_icon: Array = []
	for mid in ids:
		var data: Dictionary = MR.get_data(mid)
		var icon: String = data.get("icon", "")
		if icon.is_empty():
			empty_icon.append(mid)
		elif not FileAccess.file_exists(icon):
			missing.append("%s -> %s" % [mid, icon])
	print("[mod_icon_check] total=%d (expect 202)" % total)
	print("[mod_icon_check] empty_icon=%d missing_file=%d" % [empty_icon.size(), missing.size()])
	for m in missing:
		print("  MISSING: ", m)
	for e in empty_icon:
		print("  EMPTY: ", e)
	var ok := total == 202 and missing.is_empty() and empty_icon.is_empty()
	if ok:
		print("[mod_icon_check] ALL PASS")
	else:
		print("[mod_icon_check] FAIL")
	quit(0 if ok else 1)
