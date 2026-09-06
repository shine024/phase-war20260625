extends Node
## v26.23 真实点击诊断（执行体直挂 /root）
## 跑法：godot --rendering-driver opengl3 --path . res://tests/_tmp_click_probe_boot.tscn
## 与 runner 直呼 _on_level_selected 不同：本工具把关卡节点的屏幕坐标算出来后
## 发"真实鼠标点击事件"（Input.parse_input_event），走完整 input 管线——
## 能暴露"直呼函数没问题、真点没反应"一类的输入路由/遮挡问题。
## 不改任何游戏状态（不 start_travel、不 sleep、不存档）。

var _fails: Array[String] = []


func _ready() -> void:
	await _run()
	print("[ClickProbe] " + ("ALL PASS" if _fails.is_empty() else "HAS FAILURES: " + str(_fails)))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _run() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.call("load_game")
		if sm.has_method("flush_deferred_manager_loads"):
			sm.call("flush_deferred_manager_loads")
	if ManagerLazyLoader != null and ManagerLazyLoader.has_method("ensure_loaded"):
		ManagerLazyLoader.ensure_loaded("bunker")
	var bm: Node = get_node_or_null("/root/BunkerManager")
	print("[ClickProbe] parked=", bm.get_parked_level() if bm != null else -1,
		" traveling=", bm.is_traveling() if bm != null else "?",
		" fuel=", bm.get_fuel() if bm != null else -1)

	# 完整用户路径：标题屏 → 进移动基地 → 顶栏战区地图按钮（与用户操作一致）
	if OS.get_environment("CLICK_PATH") == "full":
		SceneTransition.change(get_tree(), "res://scenes/bunker/truck_base.tscn")
		await _wait(60)
		var tb: Node = get_tree().current_scene
		if tb == null or not String(tb.scene_file_path).contains("truck_base"):
			_fails.append("未进入 truck_base")
			return
		tb.call("_open_world_map")
		await _wait(90)
	else:
		SceneTransition.change(get_tree(), "res://scenes/world_map.tscn")
		await _wait(80)
	var map: Node = get_tree().current_scene
	if map == null or map.get_script() == null:
		_fails.append("world_map 未加载或脚本未挂载")
		return
	await _wait(20)

	# 找关卡节点按钮（LevelButton5=未解锁远点，LevelButton2=前沿邻点）
	var canvas: Control = map.get_node_or_null("Margin/VBox/ScrollContainer/MapCanvas")
	if canvas == null:
		_fails.append("MapCanvas 未找到")
		return
	for probe_level in [2, 5]:
		var btn: BaseButton = canvas.get_node_or_null("LevelButton%d" % probe_level)
		if btn == null:
			_fails.append("LevelButton%d 未找到" % probe_level)
			continue
		var center: Vector2 = btn.position + btn.size * 0.5
		# 画布坐标 → 屏幕坐标（含缩放/平移）
		var scroll: Control = canvas.get_parent() as Control
		var local: Vector2 = canvas.position + center * canvas.scale.x
		var screen_pt: Vector2 = scroll.get_global_transform() * local
		print("[ClickProbe] 关", probe_level, " 节点屏幕坐标=", screen_pt,
			" btn_visible=", btn.is_visible_in_tree(), " btn_disabled=", btn.disabled)
		# 真实点击：move + press + release
		var mv := InputEventMouseMotion.new()
		mv.position = screen_pt
		mv.global_position = screen_pt
		Input.parse_input_event(mv)
		await _wait(3)
		var dn := InputEventMouseButton.new()
		dn.button_index = MOUSE_BUTTON_LEFT
		dn.pressed = true
		dn.position = screen_pt
		dn.global_position = screen_pt
		Input.parse_input_event(dn)
		await _wait(2)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = screen_pt
		up.global_position = screen_pt
		Input.parse_input_event(up)
		await _wait(8)
		var popup: Window = map.get("_level_info_popup")
		if popup == null:
			_fails.append("真实点击关%d 无任何弹窗" % probe_level)
		else:
			print("[ClickProbe] 真实点击关", probe_level, " → 弹窗: ", popup.title)
			map.call("_close_popup_safe", popup)
			await _wait(4)
		# 遮挡审计：该点位上 GUI 拾取命中的到底是谁（从最顶层往下）
		var vp := get_viewport()
		var picked := []
		for c in canvas.get_children():
			if c is Control and c.is_visible_in_tree():
				var cr := Rect2(c.get_global_position() * canvas.scale.x, c.size * canvas.scale.x)
				if cr.has_point(screen_pt):
					picked.append("%s(%s mf=%d)" % [c.name, c.get_class(), c.mouse_filter])
		print("[ClickProbe] 关", probe_level, " 命中画布子控件: ", ", ".join(picked) if picked.size() > 0 else "无")
	await _shot("click_probe_map")


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(ProjectSettings.globalize_path("res://.godot/agent_tools/%s.png" % tag))
		print("[ClickProbe] shot ", tag)
