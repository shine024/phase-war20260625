extends Node
## v26.12c 移动基地外景视图实拍（临时工具）：外景=当前关战场地图+卡车精灵
const OUT := "res://.godot/agent_tools/truck_base_ext.png"
func _ready() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.call("load_game")
	Engine.set_meta("truck_base_view", "exterior")
	var main: Node = (load("res://scenes/bunker/truck_base.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main)
	get_tree().current_scene = main
	for i in 50:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(ProjectSettings.globalize_path(OUT))
		print("[ExtShot] saved ", OUT)
	get_tree().quit(0)
