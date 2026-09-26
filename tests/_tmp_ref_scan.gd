## 全项目 .tscn/.tres 外部引用完整性扫描（--script 直跑，不实例化任何场景）。
## 扫描所有文本资源里的 [ext_resource path="res://..."] 引用，核对目标文件存在。
## 用途：替代 agent_tools refs.validate_project（编辑器离线时的兜底）。
extends SceneTree

func _initialize() -> void:
	var missing: Array = []
	var scanned := 0
	var refs := 0
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
				if not name.begins_with("addons") and name != ".godot" and name != "_art_backup":
					stack.push_back(full)
			else:
				if name.ends_with(".tscn") or name.ends_with(".tres"):
					files.append(full)
			name = dir.get_next()
		dir.list_dir_end()

	var regex := RegEx.new()
	regex.compile("\\[ext_resource[^\\]]*?path=\"(res://[^\"]+)\"")
	for f in files:
		scanned += 1
		var text := FileAccess.get_file_as_string(f)
		if text.is_empty():
			continue
		for m in regex.search_all(text):
			var target: String = m.get_string(1)
			refs += 1
			if not FileAccess.file_exists(target):
				missing.append("%s -> %s" % [f, target])

	print("=== REF SCAN ===")
	print("scanned_files=%d total_ext_refs=%d missing=%d" % [scanned, refs, missing.size()])
	for line in missing:
		print("MISSING: " + line)
	print("REF_SCAN_OK" if missing.is_empty() else "REF_SCAN_FAIL")
	quit(0)
