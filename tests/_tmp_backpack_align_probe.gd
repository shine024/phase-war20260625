extends Node
## 卡仓空格未对齐复现探针（临时工具，可删）：
## 槽 2 新档 → 直接挂 truck_base → 跳过苏醒 → _open_panel("backpack")
## 分四个阶段 dump 战斗卡网格子节点（类/尺寸/meta/可见性），定位错位来源。
## 运行（窗口化，非 headless）：$GODOT --path . res://tests/_tmp_backpack_align_probe.tscn

const SHOT_PATH := "res://.godot/agent_tools/bp_align_probe.png"


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
	var truck: Node = _mount("res://scenes/bunker/truck_base.tscn")
	await _wait_frames(30)
	if truck.has_method("_finish_wakeup"):
		truck.call("_finish_wakeup")
		await _wait_frames(10)
	truck.call("_open_panel", "backpack")
	await _wait_frames(10)
	# 序章弹窗（_finish_wakeup 补弹的"欢迎登车"）会盖住网格区，点掉再拍
	var skip := _find_button_by_text(get_tree().root, "跳过")
	if skip != null:
		skip.pressed.emit()
		print("[probe] intro popup dismissed")
	for stage in 4:
		await _wait_frames(25)
		_dump("stage%d" % stage)
	_shot()
	print("[probe] DONE")
	get_tree().quit(0)


func _dump(tag: String) -> void:
	var panel: Node = _find_backpack_panel(get_tree().root)
	if panel == null:
		print("[probe][%s] panel NOT FOUND" % tag)
		return
	var grid: GridContainer = panel.get("_combat_cards_grid") as GridContainer
	if grid == null:
		print("[probe][%s] grid null" % tag)
		return
	var parent_node: Node = grid.get_parent()
	var psize: Vector2 = (parent_node as Control).size if parent_node is Control else Vector2.ZERO
	var vsb_visible := false
	if parent_node is ScrollContainer:
		vsb_visible = (parent_node as ScrollContainer).get_v_scroll_bar().is_visible_in_tree()
	print("[probe][%s] panel=%s grid.columns=%d grid.size=%s parent=%s size=%s vsb=%s children=%d" % [
		tag, panel.get_instance_id(), grid.columns, grid.size, parent_node.get_class(), psize, vsb_visible, grid.get_child_count()])
	var i := 0
	for child in grid.get_children():
		var meta_bits := ""
		for m in ["is_empty_slot", "is_resource_slot", "is_empty_hint", "is_loading_indicator", "_grid_placeholder"]:
			if child.has_meta(m) and bool(child.get_meta(m)):
				meta_bits += m + " "
		var card_desc := ""
		if child.has_method("set_card"):
			var card = child.get("card")
			card_desc = " card=%s" % (str(card.get("display_name")) if card != null else "NULL")
		print("  [%s][%02d] %s name=%s visible=%s size=%s min=%s pos=%s %s%s" % [
			tag, i, child.get_class(), str(child.name).left(18), str(child.visible),
			child.size, child.custom_minimum_size, child.position, meta_bits, card_desc])
		i += 1


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
