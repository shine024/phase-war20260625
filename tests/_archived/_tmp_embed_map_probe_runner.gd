extends Node
## 内嵌地图（main.tscn MapOverlay 内的 WorldMapPanel 实例）真实点击探针
## 跑法：godot --rendering-driver opengl3 --path . res://tests/_tmp_embed_map_probe_boot.tscn
## 路径：载档 → main.tscn（等价"继续游戏"）→ 打开地图 overlay → 真实点击关卡节点
## 这是从未验证过的用户路径——独立 world_map 场景已验证通过，本探针专测内嵌实例。

var _fails: Array[String] = []


func _ready() -> void:
	await _run()
	print("[EmbedProbe] " + ("ALL PASS" if _fails.is_empty() else "HAS FAILURES: " + str(_fails)))
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
	print("[EmbedProbe] parked=", bm.get_parked_level() if bm != null else -1,
		" traveling=", bm.is_traveling() if bm != null else "?")

	SceneTransition.change(get_tree(), "res://scenes/main.tscn")
	await _wait(90)
	var main: Node = get_tree().current_scene
	if main == null or not String(main.scene_file_path).contains("main"):
		_fails.append("未进入 main.tscn: " + str(get_tree().current_scene))
		return
	await _wait(30)

	# v26.24 验证①：离线奖励弹窗完整性——必须有"领取"按钮，然后 ESC 关闭
	await get_tree().create_timer(1.5).timeout
	var off: Control = null
	for c in main.get_node("PopupLayer").get_children():
		if c.get_script() != null and String(c.get_script().resource_path).contains("offline_reward_dialog"):
			off = c
	if off == null:
		print("[EmbedProbe] 离线奖励弹窗未弹（无离线时长，跳过①）")
	else:
		var has_claim := false
		for b in off.find_children("*", "Button", true, false):
			if String(b.text).contains("领取"):
				has_claim = true
		if not has_claim:
			_fails.append("离线奖励弹窗缺「领取」按钮（空壳复现）")
		else:
			print("[EmbedProbe] 离线奖励弹窗内容完整（领取按钮在位）")
		await _shot("offline_dialog")
		# ESC 关闭（真实键盘事件）
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.pressed = true
		Input.parse_input_event(ev)
		await _wait(10)
		if is_instance_valid(off) and not off.is_queued_for_deletion():
			_fails.append("ESC 未关闭离线奖励弹窗")
		else:
			print("[EmbedProbe] ESC 关闭离线弹窗 OK")

	# 打开地图 overlay（与玩家点顶栏地图按钮同链路）
	main.call("_on_world_map")
	await _wait(60)
	var wmp: Node = main.get_node_or_null("PopupLayer/MapOverlay/CenterContainer/WorldMapPanel") \
		if main.has_node("PopupLayer") else null
	if wmp == null:
		# 递归找
		wmp = main.find_child("WorldMapPanel", true, false)
	if wmp == null:
		_fails.append("WorldMapPanel 未找到（MapOverlay 结构变了？）")
		await _shot("embed_fail")
		return
	var wm: Node = wmp.get("world_map_content")
	if wm == null or not is_instance_valid(wm):
		_fails.append("world_map_content 未实例化（懒加载未触发）")
		await _shot("embed_fail")
		return
	# 二分：开地图前 root 直属匿名 CanvasLayer 清单
	var _pre: Array[String] = []
	for c in get_tree().root.get_children():
		if c is CanvasLayer:
			_pre.append("%s(layer=%d)" % [c.name, (c as CanvasLayer).layer])
	print("[EmbedProbe] 开图前 root CanvasLayers: ", ", ".join(_pre))
	await _wait(30)

	# 开图后再列一次（对比谁新出现）
	var _post: Array[String] = []
	for c in get_tree().root.get_children():
		if c is CanvasLayer:
			_post.append("%s(layer=%d)" % [c.name, (c as CanvasLayer).layer])
	print("[EmbedProbe] 开图后 root CanvasLayers: ", ", ".join(_post))
	# PopupLayer 全子节点审计：谁在 MapOverlay 之上、谁拦截鼠标、矩形在哪
	var pl: CanvasLayer = main.get_node("PopupLayer")
	var _idx := 0
	for c in pl.get_children():
		if c is Control:
			var cr: Control = c as Control
			var kids: Array[String] = []
			for k in cr.get_children():
				if k is Control:
					kids.append("%s[mf=%d vis=%s]" % [k.name, (k as Control).mouse_filter, (k as Control).is_visible_in_tree()])
			print("[EmbedProbe] PopupLayer[%d] %s mf=%d visible=%s kids={%s}" % [
				_idx, c.name, cr.mouse_filter, cr.is_visible_in_tree(), ", ".join(kids)])
		else:
			print("[EmbedProbe] PopupLayer[%d] %s (非Control)" % [_idx, c.name])
		_idx += 1
	# 匿名遮罩层身份直查：script 路径 + ColorRect 颜色 + 尺寸
	for c in pl.get_children():
		if String(c.name).begins_with("@") and c is Control:
			var scr: GDScript = (c as Control).get_script() as GDScript
			print("[EmbedProbe] 匿名层身份: ", c.name,
				" script=", (scr.resource_path if scr != null else "（无脚本=纯场景节点）"),
				" script_name=", (scr.get_class() if scr != null else ""),
				" scene=", ((c as Control).scene_file_path if c is Node and c.has_method("get_scene_file_path") else ""))
			for k in c.get_children():
				if k is ColorRect:
					var cr2: ColorRect = k as ColorRect
					print("[EmbedProbe]   遮罩 ColorRect: color=", cr2.color, " rect=", cr2.get_global_rect())
	var scroll: Control = wm.get_node_or_null("Margin/VBox/ScrollContainer")
	var canvas: Control = scroll.get_node_or_null("MapCanvas") if scroll else null
	if canvas == null:
		_fails.append("内嵌实例缺 MapCanvas")
		return
	await _shot("embed_map_view")
	for probe_level in [2, 5]:
		var btn: BaseButton = canvas.get_node_or_null("LevelButton%d" % probe_level)
		if btn == null:
			_fails.append("内嵌 LevelButton%d 未找到" % probe_level)
			continue
		# 正确换算：按钮自身全局矩形（含全部祖先变换/缩放/滚动），手动拼公式在内嵌布局下会错
		var screen_pt: Vector2 = btn.get_global_rect().get_center()
		print("[EmbedProbe] 关", probe_level, " 按钮 global_rect=", btn.get_global_rect(),
			" scroll_vp_rect=", scroll.get_global_rect(),
			" scroll_scroll=", Vector2(scroll.scroll_horizontal, scroll.scroll_vertical))
		print("[EmbedProbe] 关", probe_level, " 屏幕=", screen_pt,
			" visible=", btn.is_visible_in_tree(), " disabled=", btn.disabled,
			" btn_pos=", btn.position, " btn_size=", btn.size, " canvas_scale=", canvas.scale)
		var mv := InputEventMouseMotion.new()
		mv.position = screen_pt
		mv.global_position = screen_pt
		Input.parse_input_event(mv)
		await _wait(3)
		# 悬停命中审计：视口认为鼠标下是哪个控件（吃点击的真凶就在这条链上）
		var hov: Control = get_viewport().gui_get_hovered_control() if get_viewport().has_method("gui_get_hovered_control") else null
		var chain: Array[String] = []
		var n: Node = hov
		while n != null and chain.size() < 10:
			chain.append("%s[mf=%d%s]" % [n.name, n.mouse_filter if n is Control else -1, "" if not (n is Control) else " vis"])
			n = n.get_parent()
		print("[EmbedProbe] 悬停命中链: ", " < ".join(chain) if chain.size() > 0 else "空")
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
		await _wait(10)
		var popup: Window = wm.get("_level_info_popup")
		if popup == null:
			# 输入层未达 → 直接 emit 信号二分：信号链 vs 输入路由
			btn.pressed.emit()
			await _wait(10)
			var popup2: Window = wm.get("_level_info_popup")
			if popup2 == null:
				_fails.append("内嵌关%d：emit 直发也无弹窗（信号链断）" % probe_level)
			else:
				_fails.append("内嵌关%d：emit 有弹窗，真实点击没有（输入被拦）" % probe_level)
				wm.call("_close_popup_safe", popup2)
			await _shot("embed_click_fail_%d" % probe_level)
		else:
			print("[EmbedProbe] 真实点击关", probe_level, " → 弹窗: ", popup.title)
			wm.call("_close_popup_safe", popup)
			await _wait(4)
	await _shot("embed_end")


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(ProjectSettings.globalize_path("res://.godot/agent_tools/embed_%s.png" % tag))
		print("[EmbedProbe] shot ", tag)
