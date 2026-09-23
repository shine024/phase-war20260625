extends Control
## v6.23 实机验收截图探针（临时）：改造舱操作台 + 补给舱特购卡行
## 对应 build/记录.txt 主诉⑨（改造情报溢出）与⑪（买卡面板退化）。
## 截图 .godot/agent_tools/v623_{mod_deck,store_extra}.png，自退出。
## 运行：godot --rendering-driver opengl3 --path . res://tests/_tmp_v623_ui_shots.tscn

const DIR := "res://.godot/agent_tools/"
const ModRegistry = preload("res://scripts/systems/modification_registry.gd")


func _ready() -> void:
	await _shot_evo_control()
	await _shot_mod_deck()
	await _shot_store_extra()
	get_tree().quit(0)


## 对照组：evo 面板已知能出图——验证探针结构本身没坏
func _shot_evo_control() -> void:
	var panel: Control = load("res://scenes/ui/evolution_panel.tscn").instantiate()
	add_child(panel)
	for i in 4:
		await get_tree().process_frame
	print("[V623SHOT] evo visible=", panel.visible, " rect=", panel.get_global_rect())
	_shot(self, "v623_evo_control.png")
	await get_tree().process_frame
	panel.queue_free()
	await get_tree().process_frame


func _shot_mod_deck() -> void:
	var host := self
	var panel: Control = load("res://scenes/ui/modification_panel.tscn").instantiate()
	host.add_child(panel)
	panel.visible = true
	if panel.has_method("on_overlay_opened"):
		panel.call("on_overlay_opened")
	for i in 6:
		await get_tree().process_frame
	# 直调操作台填充（跳过选卡链）：挑一个多效果模块
	var mod_id := ""
	var best_n := -1
	for mid in ModRegistry.get_all_ids():
		var md: Dictionary = ModRegistry.get_data(String(mid))
		var le: Variant = md.get("level_effects")
		var n: int = (le as Array).size() if le is Array else 0
		if int(n) > best_n:
			best_n = int(n)
			mod_id = String(mid)
	print("[V623SHOT] mod=", mod_id, " level_effects=", best_n)
	if mod_id != "":
		panel.call("_show_mod_details", ModRegistry.get_data(mod_id))
	for i in 6:
		await get_tree().process_frame
	_shot(host, "v623_mod_deck.png")
	print("[V623SHOT] panel visible=", panel.visible, " rect=", panel.get_global_rect(),
		" modulate=", panel.modulate, " in_tree=", panel.is_inside_tree())
	for c in panel.get_children():
		if c is Control:
			print("[V623TREE] ", c.get_class(), " '", c.name, "' visible=", c.visible,
				" rect=", (c as Control).get_global_rect())
	panel.queue_free()
	await get_tree().process_frame


func _shot_store_extra() -> void:
	var host := self
	var panel: Control = load("res://scenes/ui/store_panel.tscn").instantiate()
	host.add_child(panel)
	panel.position = Vector2(160, 60)  # 960×600 min 居中于 1280×720
	panel.visible = true
	if panel.has_method("on_overlay_opened"):
		panel.call("on_overlay_opened")
	for i in 8:
		await get_tree().process_frame
	_shot(host, "v623_store_extra.png")
	panel.queue_free()
	await get_tree().process_frame


func _shot(host: Node, fname: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(ProjectSettings.globalize_path(DIR + fname))
		print("[V623SHOT] saved ", fname)
