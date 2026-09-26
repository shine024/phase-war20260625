extends Node

func _ready() -> void:
	GameConfig.get_default().feature_gates_enabled = false
	var tpm := get_node_or_null("/root/TutorialProgressionManager")
	if tpm != null:
		tpm.set("current_step", 99)
	_dbg.call_deferred()

func _dbg() -> void:
	await _settle(5)
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Node = packed.instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await _settle(10)
	_dump_layers(main)
	var ov: Control = main.get_node_or_null("PopupLayer/SettingsOverlay")
	print("DBG ov=", ov, " visible=", ov.visible if ov else false)
	if ov != null:
		main._open_overlay(ov, "settings")
	for i in range(40):
		await get_tree().process_frame
	if ov != null:
		var panel: Control = ov.find_child("SettingsPanel", true, false) as Control
		print("DBG panel=", panel, " visible=", panel.visible if panel else false,
			" rect=", panel.get_global_rect() if panel else Rect2())
	_dump_layers(main)
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://.godot/agent_tools/dbg_settings2.png")
	print("DBG saved")
	get_tree().quit(0)

func _dump_layers(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasLayer:
			print("DBG layer ", (n as CanvasLayer).layer, " ", String(n.get_path()))
		for i in range(n.get_child_count() - 1, -1, -1):
			stack.push_back(n.get_child(i))

func _settle(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame
