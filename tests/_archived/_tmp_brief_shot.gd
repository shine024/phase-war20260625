extends Node
func _ready() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("load_game"):
		sm.call("load_game")
		if sm.has_method("flush_deferred_manager_loads"):
			sm.call("flush_deferred_manager_loads")
	GameManager.call("set_current_level", 5)
	var tb: Node = (load("res://scenes/bunker/truck_base.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(tb)
	get_tree().current_scene = tb
	for i in 45:
		await get_tree().process_frame
	tb.call("_open_sortie")
	for i in 15:
		await get_tree().process_frame
	# 清掉首启引导弹层（探针新档环境会再弹），露出编队行
	var popup: Node = get_tree().root.find_child("FeatureUnlockLayer", true, false)
	if popup != null:
		popup.get_parent().call("queue_free")
		for i in 6:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(ProjectSettings.globalize_path("res://.godot/agent_tools/truckchk_briefing_loadout.png"))
		print("[BriefShot] saved")
	get_tree().quit(0)
