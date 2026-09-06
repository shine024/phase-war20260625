extends Node
## SceneTransition 泄漏检测：各用户路径切换后，root 直属匿名 CanvasLayer(layer=500) 是否残留
## 跑法：godot --rendering-driver opengl3 --path . res://tests/_tmp_leak_probe_boot.tscn
## LEAK_PATH=main|title_main|base_map 选择路径；输出每条路径的泄漏判定

var _fails: Array[String] = []


func _ready() -> void:
	await _run()
	print("[Leak] " + ("ALL PASS" if _fails.is_empty() else "HAS FAILURES"))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _leak_report(tag: String) -> void:
	# 等 2.5s 让转场清理彻底跑完再判
	await get_tree().create_timer(2.5).timeout
	var root := get_tree().root
	var leaks: Array[String] = []
	for c in root.get_children():
		if c is CanvasLayer and String(c.name).begins_with("@"):
			var layer_no: int = (c as CanvasLayer).layer
			var kids: Array[String] = []
			for k in c.get_children():
				kids.append("%s[mf=%d]" % [k.name, k.mouse_filter if k is Control else -1])
			leaks.append("%s layer=%d {%s}" % [c.name, layer_no, ", ".join(kids)])
	print("[Leak] ", tag, " → ", ("泄漏: " + " ; ".join(leaks)) if leaks.size() > 0 else "干净")
	await _shot(tag)


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(ProjectSettings.globalize_path("res://.godot/agent_tools/leak_%s.png" % tag))
		print("[Leak] shot ", tag)


func _run() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.call("load_game")
	var mode := OS.get_environment("LEAK_PATH")
	match mode:
		"main":
			SceneTransition.change(get_tree(), "res://scenes/main.tscn")
			await _wait(60)
			await _leak_report("direct_main")
		"title_main":
			SceneTransition.change(get_tree(), "res://scenes/title_screen.tscn")
			await _wait(50)
			# 模拟"继续游戏"：找按钮并真实点击
			var title: Node = get_tree().current_scene
			var vbox: Node = title.get_node_or_null("CenterContainer/MainVBox/ButtonsVBox")
			var cont: BaseButton = vbox.get_node_or_null("ContinueButton") if vbox != null else null
			if cont == null:
				_fails.append("ContinueButton 未找到")
			else:
				var gp: Vector2 = cont.get_global_rect().get_center()
				var mv := InputEventMouseMotion.new()
				mv.position = gp
				mv.global_position = gp
				Input.parse_input_event(mv)
				await _wait(3)
				var dn := InputEventMouseButton.new()
				dn.button_index = MOUSE_BUTTON_LEFT
				dn.pressed = true
				dn.position = gp
				dn.global_position = gp
				Input.parse_input_event(dn)
				await _wait(2)
				var up := InputEventMouseButton.new()
				up.button_index = MOUSE_BUTTON_LEFT
				up.pressed = false
				up.position = gp
				up.global_position = gp
				Input.parse_input_event(up)
				await _wait(90)
			await _leak_report("title_continue_main")
		"base_map":
			SceneTransition.change(get_tree(), "res://scenes/bunker/truck_base.tscn")
			await _wait(60)
			var tb: Node = get_tree().current_scene
			tb.call("_open_world_map")
			await _wait(90)
			await _leak_report("base_to_map")
		_:
			print("[Leak] 未知 LEAK_PATH：", mode)
