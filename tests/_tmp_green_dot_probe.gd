extends Node
## 改造瓷砖绿方块（装配状态点）视觉探针（临时工具，可删）：
## 复现用户实机状态——负重背心已装配 1 张卡（绿点 + "1 卡"徽章），消焰器未装配（无点无徽章）。
## 运行（窗口化，非 headless）：$GODOT --path . res://tests/_tmp_green_dot_probe.tscn

const SHOT_PATH := "res://.godot/agent_tools/green_dot_probe.png"


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

	# 注入数据：背包里两块改造图纸，负重背心装在 1 张卡上
	var bag: Node = get_node_or_null("/root/IntelItemBag")
	var bpm: Node = get_node_or_null("/root/BlueprintManager")
	if bag == null or bpm == null:
		push_error("[probe] bag/bpm missing")
		get_tree().quit(1)
		return
	bag.call("add_item", "blueprint_inf_30_load_vest", 1)
	bag.call("add_item", "blueprint_inf_31_flash_suppressor", 1)
	bpm.set("blueprint_mods", {"ww1_mp18": [{"id": "inf_30_load_vest"}]})
	print("[probe] injected: load_vest installed x1, flash_suppressor loose")

	var truck: Node = _mount("res://scenes/bunker/truck_base.tscn")
	await _wait_frames(30)
	if truck.has_method("_finish_wakeup"):
		truck.call("_finish_wakeup")
		await _wait_frames(10)
	truck.call("_open_panel", "backpack")
	await _wait_frames(10)
	var skip := _find_button_by_text(get_tree().root, "跳过")
	if skip != null:
		skip.pressed.emit()
		print("[probe] intro popup dismissed")

	var panel: Node = _find_backpack_panel(get_tree().root)
	if panel == null:
		print("[probe] backpack panel NOT FOUND")
		get_tree().quit(1)
		return
	# 切到改造 Tab（TabIndex.INTEL=1），注入发生在开面板后→签名比对必不一致会重建
	var tc: TabContainer = panel.get("_tab_container") as TabContainer
	if tc == null:
		print("[probe] _tab_container null")
		get_tree().quit(1)
		return
	tc.current_tab = 1
	await _wait_frames(20)

	_dump_tiles(panel)
	_shot()
	print("[probe] DONE")
	get_tree().quit(0)


func _dump_tiles(panel: Node) -> void:
	var grid: GridContainer = panel.get("_intel_grid") as GridContainer
	if grid == null:
		print("[probe] _intel_grid null")
		return
	print("[probe] intel grid children=%d" % grid.get_child_count())
	for child in grid.get_children():
		if not child.has_method("set_data"):
			continue
		var deco: Control = child.get_node_or_null("DecorationLayer") as Control
		var dot_info := "no-deco"
		var badge_info := ""
		if deco != null:
			var dot: Control = deco.get_node_or_null("ModStatusDot") as Control
			if dot != null:
				dot_info = "dot visible=%s rect=%s" % [str(dot.visible), str(dot.get_global_rect())]
			else:
				dot_info = "dot absent"
			var badge: Control = deco.get_node_or_null("ModInstallBadge") as Control
			if badge != null:
				badge_info = " badge visible=%s rect=%s" % [str(badge.visible), str(badge.get_global_rect())]
		print("  tile name=%s global_rect=%s %s%s" % [
			str(child.get("display_name")).left(12), str((child as Control).get_global_rect()), dot_info, badge_info])


func _find_backpack_panel(root: Node) -> Node:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var s := n.get_script() as Script
		if s != null and s.resource_path.ends_with("backpack_panel.gd"):
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
