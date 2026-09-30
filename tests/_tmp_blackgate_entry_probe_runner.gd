extends Node
## v6.35.2 确定性取证探针（无合成输入，全部直调）：
## ① 真档开图 → 直开黑门弹窗截图（目检无尽口径）
## ② 直开 L100 关卡情报弹窗截图（目检黑门区块/波数/通关/掉落/踏入钮）
## ③ 直开 main 场景 → 组合技条 vs TopHudBar Capsule 矩形测量 + HUD 截图（重叠复查）
## ⚠️ 在隔离 APPDATA 沙箱跑。

func _ready() -> void:
	_run()

func _run() -> void:
	print("[probe4] phase=load_save")
	if not SaveManager.load_game():
		print("[probe4] VERDICT=FAIL_LOAD")
		get_tree().quit(1)
		return
	for i in range(30):
		await get_tree().process_frame

	var wm: Control = (load("res://scenes/world_map.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(wm)
	for i in range(5):
		await get_tree().process_frame

	# ① 黑门弹窗（直开）
	wm.call("_show_blackgate_popup")
	await get_tree().create_timer(0.3).timeout
	var gate_popup: Window = wm.get("_level_info_popup")
	print("[probe4] gate_popup=", gate_popup.title if gate_popup != null and is_instance_valid(gate_popup) else "<null>")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/agent_tools/gate_popup_direct.png")
	print("[probe4] shot -> gate_popup_direct.png")
	wm.call("_close_popup_safe", gate_popup)
	wm.set("_level_info_popup", null)
	for i in range(4):
		await get_tree().process_frame

	# ② L100 关卡情报弹窗（直开）
	wm.call("_show_level_info_popup", 100)
	await get_tree().create_timer(0.3).timeout
	var lv: Window = wm.get("_level_info_popup")
	print("[probe4] L100popup=", lv.title if lv != null and is_instance_valid(lv) else "<null>")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/agent_tools/level100_popup.png")
	print("[probe4] shot -> level100_popup.png")
	wm.call("_close_popup_safe", lv)
	wm.set("_level_info_popup", null)
	for i in range(4):
		await get_tree().process_frame
	wm.queue_free()
	await get_tree().process_frame

	# ③ main HUD 矩形测量（HudLayer 属 main.tscn；战斗外强制亮出测量元素）
	print("[probe4] phase=main_hud")
	var main_scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main_scene)
	for i in range(8):
		await get_tree().process_frame
	var hud: CanvasLayer = main_scene.get_node_or_null("HudLayer")
	if hud != null:
		hud.visible = true
		var combo: Control = hud.get_node_or_null("ComboStatusStrip")
		var topbar: Control = hud.get_node_or_null("TopHudBar")
		if combo != null:
			combo.visible = true
		var combo_rect: Rect2 = combo.get_global_rect() if combo != null else Rect2()
		print("[probe4] combo rect=", combo_rect, " min=", combo.custom_minimum_size if combo else Vector2())
		var overlap_found := false
		if topbar != null:
			for c in topbar.get_children():
				if c is Control and c.visible:
					var r: Rect2 = c.get_global_rect()
					print("[probe4] topbarchild ", c.name, " rect=", r)
					if r.intersects(combo_rect):
						overlap_found = true
						print("[probe4] !! OVERLAP with ", c.name)
		print("[probe4] combo_overlap=", overlap_found)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/agent_tools/main_hud_check.png")
		print("[probe4] shot -> main_hud_check.png")
	print("[probe4] VERDICT=DONE")
	get_tree().quit(0)
