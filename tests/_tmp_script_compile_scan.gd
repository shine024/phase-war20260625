## 全项目 .gd 编译扫描（--script 直跑）：load() 每个脚本触发完整编译，
## 等价覆盖 --check-only 的脚本语法面（本机 F 盘 I/O 慢，--check-only 超 20 分钟不实用）。
## 排除 .godot / addons 编辑器侧已排除目录不必要——全扫，宁可多报。
extends SceneTree

func _initialize() -> void:
	var stack: Array[String] = ["res://"]
	var files: Array[String] = []
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if name.begins_with("."):
				name = dir.get_next()
				continue
			var full := dir_path.path_join(name)
			if dir.current_is_dir():
				stack.push_back(full)
			elif name.ends_with(".gd"):
				files.append(full)
			name = dir.get_next()
		dir.list_dir_end()

	files.sort()
	var failed: Array[String] = []
	var ok := 0
	for f in files:
		var s = load(f)
		if s == null:
			failed.append(f)
		else:
			ok += 1

	print("=== SCRIPT COMPILE SCAN ===")
	print("total=%d compiled_ok=%d failed=%d" % [files.size(), ok, failed.size()])
	for f in failed:
		print("COMPILE_FAIL: " + f)
	print("SCRIPT_SCAN_OK" if failed.is_empty() else "SCRIPT_SCAN_FAIL")
	quit(0)
