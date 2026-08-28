extends Node
## 临时探针：open_room 后面板可见性/位置诊断

func _ready() -> void:
	ManagerLazyLoader.ensure_loaded("bunker")
	var mgr: Node = ManagerLazyLoader.get_manager("bunker")
	mgr.reset_to_defaults()
	var inst: Control = load("res://scenes/bunker/bunker_main.tscn").instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: Control = inst.get("_panel")
	var defs: Dictionary = inst.get("_room_rects")
	var pd: Dictionary = BunkerRoomDefs_preload().get_room("dormitory")
	panel.call("open_room", pd, mgr)
	await get_tree().process_frame
	print("[probe] panel.visible=", panel.visible,
		" global_rect=", panel.get_global_rect(),
		" size=", panel.size)
	print("[probe] anchors L/T/R/B=", panel.anchor_left, "/", panel.anchor_top, "/",
		panel.anchor_right, "/", panel.anchor_bottom,
		" offsets L/T/R/B=", panel.offset_left, "/", panel.offset_top, "/",
		panel.offset_right, "/", panel.offset_bottom)
	var pc: Control = panel.get("_panel")
	print("[probe] inner _panel.visible=", pc.visible, " rect=", pc.get_global_rect())
	var ab: Control = panel.get("_action_box")
	print("[probe] action_box rect=", ab.get_global_rect())
	var inner_p := pc.get_child(0) as Control
	print("[probe] inner container rect=", inner_p.get_global_rect())
	var stage: Control = inst.get("_ui_stage")
	print("[probe] stage rect=", stage.get_global_rect() if stage else "null")
	print("[probe] panel parent=", panel.get_parent().name)
	get_tree().quit(0)

func BunkerRoomDefs_preload() -> GDScript:
	return load("res://data/bunker_room_defs.gd")
