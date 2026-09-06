extends Node
## v26.13 面板修复验收截图（临时）：成就/帮助/背包
const DIR := "res://.godot/agent_tools/"

func _ready() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("load_game"):
		sm.call("load_game")
		if sm.has_method("flush_deferred_manager_loads"):
			sm.call("flush_deferred_manager_loads")
	await _shot_panel("res://scenes/ui/achievement_panel.tscn", "panel_achievement", 40)
	await _shot_panel("res://scenes/ui/help_panel.tscn", "panel_help", 25)
	await _shot_panel("res://scenes/ui/backpack_panel.tscn", "panel_backpack", 45)
	get_tree().quit(0)

func _shot_panel(path: String, tag: String, frames: int) -> void:
	var ps: PackedScene = load(path)
	if ps == null:
		printerr("[PanelShot] load fail: " + path)
		return
	var panel: Node = ps.instantiate()
	if panel is Control:
		(panel as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
		(panel as Control).size = Vector2(1280, 720)
	get_tree().root.add_child.call_deferred(panel)
	for i in frames:
		await get_tree().process_frame
	if panel.has_method("show_panel"):
		panel.call("show_panel")
	elif panel.has_method("refresh"):
		panel.call("refresh")
	if panel is Control:
		(panel as Control).visible = true
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(ProjectSettings.globalize_path(DIR + "truckchk_%s.png" % tag))
		print("[PanelShot] saved ", tag)
	panel.call_deferred("queue_free")
	for i in 5:
		await get_tree().process_frame
