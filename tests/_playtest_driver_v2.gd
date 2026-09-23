extends Node
## 试玩驱动器（发行前全功能矩阵测试专用，用完归档）
## 跨场景存活：按 AGENTS.md agent_tools#8 范式 add_child + current_scene 赋值，
## 游戏自身 SceneTransition.change 释放的是 target 而非本驱动器。
## 用法: godot --path . --resolution 1280x720 res://tests/_playtest_driver.tscn -- --scenario=<名>

var _cfg: Dictionary = {}
var _steps: Array = []
var _idx := 0
var _started := false
var _frame := 0
var _fail := 0
var _step_frames_left := 0
var _wait_kind := ""        # "", "scene", "node", "node_gone", "sig"
var _wait_arg := ""
var _wait_timeout_left := 0
var _last_scene_path := ""
var _sig_fired := false


func _ready() -> void:
	var scenario := "s2_newplayer"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenario="):
			scenario = a.get_slice("=", 1)
	var Scenarios = load("res://tests/_playtest_scenarios_v2.gd")
	_cfg = Scenarios.get_scenario(scenario)
	if _cfg.is_empty():
		# v3 P2-11: 曲线场景独立文件（Task 1.1c），主表查不到时回退
		var CurveScenarios = load("res://tests/_playtest_scenarios_curve.gd")
		_cfg = CurveScenarios.get_scenario(scenario)
	_steps = _cfg.get("steps", [])
	if _steps.is_empty():
		print("[pt] FAIL no scenario '%s'" % scenario)
		get_tree().quit(2)
		return
	var start_scene: String = _cfg.get("start", "res://scenes/title_screen.tscn")
	var ps = load(start_scene)
	if ps == null:
		print("[pt] FAIL cannot load start scene %s" % start_scene)
		get_tree().quit(2)
		return
	var inst = ps.instantiate()
	get_tree().root.add_child.call_deferred(inst)
	await get_tree().process_frame
	if not inst.is_inside_tree():
		await get_tree().process_frame
	get_tree().current_scene = inst
	_started = true
	print("[pt] DRIVER scenario=%s start=%s steps=%d" % [scenario, start_scene, _steps.size()])


func _process(_delta: float) -> void:
	if not _started:
		return
	_frame += 1
	_watch_scene_change()
	if _step_frames_left > 0:
		_step_frames_left -= 1
		if _step_frames_left == 0:
			_advance()
		return
	if _wait_kind != "":
		if _check_wait():
			_wait_kind = ""
			_advance()
		else:
			_wait_timeout_left -= 1
			if _wait_timeout_left <= 0:
				_fail += 1
				print("[pt] FAIL wait_%s '%s' timeout at frame %d" % [_wait_kind, _wait_arg, _frame])
				_wait_kind = ""
				_advance()
		return
	_exec_next()


func _watch_scene_change() -> void:
	var cs := get_tree().current_scene
	if cs == null:
		return
	var p := cs.scene_file_path
	if p != _last_scene_path and _last_scene_path != "":
		print("[pt] SCENE -> %s (frame %d)" % [p, _frame])
	_last_scene_path = p


func _advance() -> void:
	_idx += 1
	if _idx >= _steps.size():
		_finish()


func _finish() -> void:
	if _fail == 0:
		print("[pt] DONE all_steps_ok frames=%d" % _frame)
		get_tree().quit(0)
	else:
		print("[pt] DONE with %d failures frames=%d" % [_fail, _frame])
		get_tree().quit(1)


func _exec_next() -> void:
	if _idx >= _steps.size():
		_finish()
		return
	var s: Dictionary = _steps[_idx]
	match s.get("t", ""):
		"frames":
			_step_frames_left = int(s.get("n", 1))
		"click":
			_do_click(float(s.get("x", 0)), float(s.get("y", 0)))
			print("[pt] click (%d,%d) frame=%d" % [int(s.x), int(s.y), _frame])
			_advance()
		"click_text":
			_do_click_text(str(s.get("text", "")), bool(s.get("soft", false)))
			_advance()
		"key":
			_do_key(str(s.get("code", "Escape")))
			print("[pt] key %s frame=%d" % [s.get("code"), _frame])
			_advance()
		"wait_scene":
			_wait_kind = "scene"
			_wait_arg = str(s.get("match", ""))
			_wait_timeout_left = int(s.get("timeout", 900))
		"wait_node":
			_wait_kind = "node"
			_wait_arg = str(s.get("path", ""))
			_wait_timeout_left = int(s.get("timeout", 600))
		"wait_node_gone":
			_wait_kind = "node_gone"
			_wait_arg = str(s.get("path", ""))
			_wait_timeout_left = int(s.get("timeout", 600))
		"wait_sig":
			_wait_kind = "sig"
			_wait_arg = str(s.get("name", ""))
			_wait_timeout_left = int(s.get("timeout", 3600))
			_sig_fired = false
			var sb := _resolve("/root/SignalBus")
			if sb != null and sb.has_signal(_wait_arg):
				sb.connect(_wait_arg, _on_bus_signal, CONNECT_ONE_SHOT)
			else:
				_fail += 1
				print("[pt] FAIL wait_sig no signal %s" % _wait_arg)
				_wait_kind = ""
				_advance()
		"fps":
			print("[pt] FPS %s = %d (frame %d)" % [s.get("label", ""), Engine.get_frames_per_second(), _frame])
			_advance()
		"probe":
			_do_probe(str(s.get("label", "?")), str(s.get("path", "")), str(s.get("prop", "")))
			_advance()
		"call":
			_do_call(str(s.get("path", "")), str(s.get("method", "")), s.get("args", []))
			_advance()
		"shot":
			_do_shot(str(s.get("path", "")))
			_advance()
		"dump":
			_do_dump(int(s.get("depth", 7)))
			_advance()
		"quit_ok":
			print("[pt] explicit quit_ok at frame %d" % _frame)
			get_tree().quit(0)
		_:
			_fail += 1
			print("[pt] FAIL unknown step %s" % str(s))
			_advance()


func _check_wait() -> bool:
	match _wait_kind:
		"scene":
			var cs := get_tree().current_scene
			return cs != null and str(cs.scene_file_path).contains(_wait_arg)
		"node":
			return _resolve(_wait_arg) != null
		"node_gone":
			return _resolve(_wait_arg) == null
		"sig":
			return _sig_fired
	return false


func _on_bus_signal(a = null, b = null, c = null) -> void:
	_sig_fired = true
	print("[pt] SIG %s fired (args: %s, %s) frame=%d" % [_wait_arg, str(a), str(b), _frame])


## 路径以 /root/ 开头按绝对解析，其余相对当前场景根
func _resolve(path: String) -> Node:
	if path == "":
		return null
	if path.begins_with("/root/"):
		return get_tree().root.get_node_or_null(path.trim_prefix("/root/"))
	var cs := get_tree().current_scene
	return cs.get_node_or_null(path) if cs != null else null


func _do_click(x: float, y: float) -> void:
	# 视口坐标 → 窗口坐标（expand 拉伸下窗口/视口可能不同尺寸）
	var vp_size := get_viewport().get_visible_rect().size
	var win_size := get_window().size
	var pos := Vector2(x * float(win_size.x) / vp_size.x, y * float(win_size.y) / vp_size.y)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	Input.parse_input_event(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	Input.parse_input_event(up)


## 按文本找可见按钮并点中心（子串匹配，取树序第一个）；soft=true 找不到不计失败
func _do_click_text(text: String, soft := false) -> void:
	var btn := _find_button_by_text(get_tree().current_scene, text)
	if btn == null:
		if not soft:
			_fail += 1
			print("[pt] click_text '%s' FAIL not-found frame=%d" % [text, _frame])
		else:
			print("[pt] click_text '%s' miss (soft) frame=%d" % [text, _frame])
		return
	var r: Rect2 = (btn as Control).get_global_rect()
	var cx := r.position.x + r.size.x / 2.0
	var cy := r.position.y + r.size.y / 2.0
	print("[pt] click_text '%s' -> (%d,%d) frame=%d" % [text, int(cx), int(cy), _frame])
	_do_click(cx, cy)


func _find_button_by_text(n: Node, text: String) -> Control:
	if n is Button and n.visible and n.get_global_rect().size.x > 0:
		var t := str(n.get("text"))
		if t != "" and t.contains(text):
			return n as Control
	for ch in n.get_children():
		var found := _find_button_by_text(ch, text)
		if found != null:
			return found
	return null


func _do_key(code: String) -> void:
	var kc := OS.find_keycode_from_string(code)
	for pressed in [true, false]:
		var ek := InputEventKey.new()
		ek.physical_keycode = kc
		ek.pressed = pressed
		Input.parse_input_event(ek)


func _do_probe(label: String, path: String, prop: String) -> void:
	var n := _resolve(path)
	if n == null:
		_fail += 1
		print("[pt] PROBE %s FAIL node-not-found %s" % [label, path])
		return
	if prop == "":
		print("[pt] PROBE %s = <node %s>" % [label, n.get_class()])
		return
	var v = n.get(prop)
	if v == null and not (prop in n):
		_fail += 1
		print("[pt] PROBE %s FAIL prop-missing %s" % [label, prop])
	else:
		print("[pt] PROBE %s = %s" % [label, str(v)])


func _do_call(path: String, method: String, args: Array) -> void:
	var n := _resolve(path)
	if n == null:
		_fail += 1
		print("[pt] CALL FAIL node-not-found %s.%s" % [path, method])
		return
	if not n.has_method(method):
		_fail += 1
		print("[pt] CALL FAIL method-missing %s.%s" % [path, method])
		return
	var v = n.callv(method, args)
	print("[pt] CALL %s.%s -> %s" % [path, method, str(v)])


## 打印场景树中所有 Control 节点（路径/类/全局矩形/文本），用于推导点击坐标
func _do_dump(depth: int) -> void:
	var cs := get_tree().current_scene
	if cs == null:
		print("[pt] DUMP FAIL no current_scene")
		return
	print("[pt] DUMP begin scene=%s" % cs.scene_file_path)
	_dump_walk(cs, 0, depth)
	print("[pt] DUMP end")


func _dump_walk(n: Node, d: int, max_d: int) -> void:
	if d > max_d:
		return
	var line := "[pt] DUMP %s%s [%s]" % ["  ".repeat(d), n.name, n.get_class()]
	if n is Control:
		var c := n as Control
		line += " rect=(%.0f,%.0f %.0fx%.0f)" % [c.global_position.x, c.global_position.y, c.size.x, c.size.y]
		if "text" in n:
			@warning_ignore("unsafe_property_access")
			line += " text='%s'" % str(n.text)
		if not c.visible:
			line += " HIDDEN"
	print(line)
	for ch in n.get_children():
		if ch is CanvasItem or ch is Node3D or ch is Control or ch is CanvasLayer or ch is Window:
			_dump_walk(ch, d + 1, max_d)


func _do_shot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(path)
		print("[pt] SHOT %s (frame %d)" % [path, _frame])
	else:
		_fail += 1
		print("[pt] SHOT FAIL %s" % path)
