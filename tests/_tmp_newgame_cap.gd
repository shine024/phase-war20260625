extends Node
## 美术复核·新档全流程实拍 v2（临时工具，可删）：
## 槽 2 新游戏 → 漫画（空格翻格）→ DreamBattle（播 10s 后跳过）→ 基地苏醒 → 出击首战。
## 不触碰槽 1 主档。
## 运行：echo "newgame" > .godot/steam_cap_mode.txt 后窗口化跑本场景。

const SHOT_DIR := "res://_steam_assets/shots/"


func _ready() -> void:
	get_window().always_on_top = true
	var spec := "newgame"
	if FileAccess.file_exists("res://.godot/steam_cap_mode.txt"):
		spec = FileAccess.get_file_as_string("res://.godot/steam_cap_mode.txt").strip_edges()
	if spec.split(" ", false)[0] != "newgame":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	await _wait_frames(20)
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("set_slot"):
		sm.call("set_slot", 2)
	# v1 运行已给槽 2 落过档——先删干净，避免新游戏弹"覆盖确认"卡住驱动
	for f in ["user://save_slot_2.json", "user://save_slot_2.json.prior",
			"user://save_slot_2.json.tmp", "user://save_slot_2_backup.json"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
			print("[NewGameCap] removed ", f)
	await _wait_frames(10)
	var title: Node = _mount("res://scenes/title_screen.tscn")
	await _wait_frames(160)
	_shot("ng_000_title.png")
	var btn: Button = title.get_node_or_null("CenterContainer/MainVBox/ButtonsVBox/NewGameButton") as Button
	if btn == null:
		push_warning("[NewGameCap] NewGameButton 缺失")
		get_tree().quit(1)
		return
	btn.pressed.emit()
	print("[NewGameCap] new game pressed")
	var last_scene := ""
	var stuck := 0
	var sortie_pressed := false
	var main_shots := 0
	for i in range(1, 260):
		await _wait_frames(30)
		var cs := get_tree().current_scene
		var nm := String(cs.name) if cs != null else "?"
		_shot("ng_%03d_%s.png" % [i, nm])
		if nm != last_scene:
			print("[NewGameCap] %03d scene -> %s" % [i, nm])
			last_scene = nm
			stuck = 0
		else:
			stuck += 1
		if nm.begins_with("Comic"):
			if stuck >= 2:
				_send_space()
				stuck = 0
		elif nm.begins_with("Dream"):
			if stuck == 20:
				_press_skip(cs)
		elif nm.begins_with("Truck") or nm.begins_with("Bunker"):
			if stuck == 30 and not sortie_pressed:
				sortie_pressed = true
				var sbtn: Button = cs.get("_sortie_btn") as Button
				if sbtn != null:
					sbtn.pressed.emit()
					print("[NewGameCap] sortie pressed")
				else:
					print("[NewGameCap] sortie btn missing")
		elif nm == "Main":
			main_shots += 1
			# 教学战前面板（"开战"类按钮）出现后点掉，拍真实新手首战
			if main_shots == 6:
				var wb := _find_button_contains(cs, ["开战", "开始首战", "开始战斗"])
				if wb != null:
					wb.pressed.emit()
					print("[NewGameCap] battle-start pressed: ", wb.text)
			if main_shots > 45:
				print("[NewGameCap] battle captured, done")
				break
	get_tree().quit(0)



func _find_button_contains(root: Node, needles: Array) -> Button:
	if root is Button:
		var t := String((root as Button).text)
		for n in needles:
			if t.contains(n):
				return root as Button
	for ch in root.get_children():
		var r := _find_button_contains(ch, needles)
		if r != null:
			return r
	return null

func _send_space() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	Input.parse_input_event(ev)


func _press_skip(root: Node) -> void:
	var btn := _find_button_by_text(root, "跳过")
	if btn != null:
		btn.pressed.emit()
		print("[NewGameCap] skip pressed")


func _find_button_by_text(node: Node, needle: String) -> Button:
	if node is Button and String((node as Button).text).contains(needle):
		return node as Button
	for ch in node.get_children():
		var r := _find_button_by_text(ch, needle)
		if r != null:
			return r
	return null


func _shot(fname: String) -> void:
	var img: Image = get_tree().root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(SHOT_DIR + fname)


func _mount(path: String) -> Node:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	return inst


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
