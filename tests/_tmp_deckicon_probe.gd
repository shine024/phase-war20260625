extends Node
## 操作台 DeckIcon 拉长修复视觉探针（临时工具，可删）：
## 打开改造舱 → 选中 目标指示器（epic 机制型，同用户实机）→ 断言 DeckIcon 不再被
## 垂直拉伸（应 36×36 顶对齐）→ 截图目检。
## 运行（窗口化）：$GODOT --path . res://tests/_tmp_deckicon_probe.tscn

const SHOT_PATH := "res://.godot/agent_tools/deckicon_probe.png"
const MOD_ID := "rec_13_target_designator"


func _ready() -> void:
	await _wait_frames(20)
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm == null:
		push_error("[probe] SaveManager missing")
		get_tree().quit(1)
		return
	sm.call("set_slot", 2)
	for f in ["user://save_slot_2.json", "user://save_slot_2.json.prior",
			"user://save_slot_2.json.tmp", "user://save_slot_2_backup.json"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	await _wait_frames(10)
	sm.call("start_new_game")
	await _wait_frames(40)
	# v6.51 探针铁律：懒加载晚到覆盖——先 flush，再重取节点抬解锁等级
	# （v34 门控：新档 modification 锁到 L6，_open_panel 会静默拒绝）
	if sm.has_method("flush_deferred_manager_loads"):
		sm.call("flush_deferred_manager_loads")
		await _wait_frames(5)
	var lpm: Node = get_node_or_null("/root/LevelProgressManager")
	if lpm != null:
		lpm.set("max_unlocked_level", 99)
		print("[probe] max_unlocked_level -> ", str(lpm.get("max_unlocked_level")))

	var truck: Node = _mount("res://scenes/bunker/truck_base.tscn")
	await _wait_frames(30)
	if truck.has_method("_finish_wakeup"):
		truck.call("_finish_wakeup")
		await _wait_frames(10)
	truck.call("_open_panel", "modification")
	await _wait_frames(15)
	var skip := _find_button_by_text(get_tree().root, "跳过")
	if skip != null:
		skip.pressed.emit()
		print("[probe] intro popup dismissed")
		await _wait_frames(8)
		# 欢迎→确认 二段弹窗：ConfirmationDialog「跳过教程」按钮文本搜索不可靠，
		# 按节点名 SkipConfirmDialog 定位后直按 OK
		var dlg: Window = _find_node_by_name(get_tree().root, "SkipConfirmDialog") as Window
		if dlg != null:
			var ok_btn: Button = dlg.call("get_ok_button")
			if ok_btn != null:
				ok_btn.pressed.emit()
				print("[probe] tutorial confirm dismissed")
				await _wait_frames(8)

	var panel: Node = _find_panel_by_script(get_tree().root, "modification_panel.gd")
	if panel == null:
		print("[probe] modification panel NOT FOUND")
		get_tree().quit(1)
		return
	var reg: Node = get_node_or_null("/root/ModificationRegistry")
	var mod_data: Dictionary = reg.call("get_data", MOD_ID) if reg else {}
	if mod_data.is_empty():
		print("[probe] mod data empty for ", MOD_ID)
		get_tree().quit(1)
		return
	panel.call("_on_mod_selected", MOD_ID, mod_data)
	await _wait_frames(20)
	# 面板首开 intro 弹窗（show_once）会盖操作台，点掉再拍
	var ok_btn := _find_button_by_text(get_tree().root, "知道了")
	if ok_btn != null:
		ok_btn.pressed.emit()
		await _wait_frames(5)

	_dump(panel)
	_shot()
	print("[probe] DONE")
	get_tree().quit(0)


func _dump(panel: Node) -> void:
	var icon: Control = panel.get_node_or_null("%DeckIcon") as Control
	if icon == null:
		print("[probe] %DeckIcon NOT FOUND")
		return
	var r := icon.get_global_rect()
	print("[probe] DeckIcon global_rect=%s size=%s min=%s vflag=%d" % [str(r), str(icon.size), str(icon.custom_minimum_size), icon.size_flags_vertical])
	# 拉长判定：高显著大于 36 即拉伸
	var stretched := r.size.y > 50.0
	print("[probe] stretched=%s (h=%.1f)" % [str(stretched), r.size.y])
	var tex: TextureRect = icon.get_node_or_null("DeckIconTex") as TextureRect
	if tex != null:
		print("[probe] DeckIconTex visible=%s texture=%s" % [str(tex.visible), "set" if tex.texture != null else "null"])
	# 名字行位置（图标应与其顶部对齐）
	var name_lbl: Label = panel.get_node_or_null("%DeckNameLabel") as Label
	if name_lbl != null:
		print("[probe] DeckNameLabel global_rect=%s" % str(name_lbl.get_global_rect()))


func _find_panel_by_script(root: Node, script_name: String) -> Node:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var s := n.get_script() as Script
		if s != null and s.resource_path.ends_with(script_name):
			return n
		stack.append_array(n.get_children())
	return null


func _find_button_by_text(node: Node, needle: String) -> Button:
	if node is Button and String((node as Button).text).contains(needle):
		return node as Button
	for ch in node.get_children():
		var r := _find_button_by_text(ch, needle)
		if r != null:
			return r
	return null


func _find_node_by_name(root: Node, target: String) -> Node:
	if String(root.name) == target:
		return root
	for ch in root.get_children():
		var r := _find_node_by_name(ch, target)
		if r != null:
			return r
	return null


func _shot() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/agent_tools"))
	var img: Image = get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(SHOT_PATH)
		print("[probe] shot -> ", SHOT_PATH)


func _mount(path: String) -> Node:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	return inst


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
