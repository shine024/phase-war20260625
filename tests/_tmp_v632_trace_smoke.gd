extends SceneTree
## v6.32 最小冒烟：只验证 TraceLog 会话轮转行为（不 load 游戏大文件——
## battle_manager 全链编译在 --script 下分钟级，语法层由 gdparse 覆盖）
## 跑法：godot --headless --path . --script tests/_tmp_v632_trace_smoke.gd

func _init() -> void:
	print("step1: prepare old trace.log")
	var f = FileAccess.open("user://trace.log", FileAccess.WRITE)
	f.store_line("=== OLD SESSION ===")
	f.store_line("[0.000 f0] old_mark probe")
	f.flush()
	f.close()

	print("step2: ensure_open (rotate) + mark")
	var tl = load("res://scripts/systems/trace_log.gd")
	tl._ensure_open()
	print("step3: opened, calling mark")
	tl.mark("probe_event", "rotation_test")
	tl._file.flush()
	print("step4: mark done, verify files")

	var nf = FileAccess.open("user://trace.log", FileAccess.READ)
	var new_content := nf.get_as_text()
	nf.close()
	var new_ok := new_content.contains("trace session") and new_content.contains("probe_event")
	print("  ok  new session: " + str(new_ok))

	var pf = FileAccess.open("user://trace.prev.log", FileAccess.READ)
	var prev_ok := pf != null and pf.get_as_text().contains("OLD SESSION")
	if pf != null:
		pf.close()
	print("  ok  prev preserved: " + str(prev_ok))

	tl._file.close()
	tl._file = null

	print("step5: clean probe artifacts")
	var dir := DirAccess.open("user://")
	if dir != null:
		if dir.file_exists("trace.log"):
			dir.remove("trace.log")
		if dir.file_exists("trace.prev.log"):
			dir.remove("trace.prev.log")

	if new_ok and prev_ok:
		print("V632_TRACE_OK")
		quit(0)
	else:
		print("V632_TRACE_FAIL")
		quit(1)
