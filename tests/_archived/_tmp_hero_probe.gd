extends Node
## v6.14 探针：同伴档案面板（布局重排后目检）
func _ready() -> void:
	ManagerLazyLoader.ensure_loaded("bunker")
	var mgr: Node = ManagerLazyLoader.get_manager("bunker")
	for mid in ["enemy_master_001", "enemy_master_007", "enemy_master_015", "enemy_master_023"]:
		mgr.record_hero_fragment(mid)
	var inst: Control = load("res://scenes/bunker/ui/hero_archive_panel.gd").new()
	add_child(inst)
	inst.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	await get_tree().process_frame
	inst.call("_select", "enemy_master_001")
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image()\
		.save_png("res://.godot/agent_tools/hero_archive_probe_final.png")
	print("[probe] saved final")
	get_tree().quit(0)
