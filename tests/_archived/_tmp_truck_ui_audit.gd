extends Node
## v26.12c 移动基地全 UI 巡检（临时工具）：标题入口/内景三时代/热区尺寸/真面板/终端/简报/外景
## 跑法：godot --rendering-driver opengl3 --path . res://tests/_tmp_truck_ui_audit.tscn
## 截图输出 .godot/agent_tools/audit_*.png；退出码非 0 = 有断言失败

const DIR := "res://.godot/agent_tools/"
var _errs: Array[String] = []


func _ready() -> void:
	await _run()
	for e in _errs:
		printerr("[Audit] FAIL: " + e)
	if _errs.is_empty():
		print("[Audit] ALL PASS")
	get_tree().quit(0 if _errs.is_empty() else 1)


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(ProjectSettings.globalize_path(DIR + "audit_%s.png" % tag))
		print("[Audit] shot %s" % tag)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _run() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.call("load_game")
		if sm.has_method("flush_deferred_manager_loads"):
			sm.call("flush_deferred_manager_loads")

	# ── A. 标题屏：移动基地按钮存在 / 3v3 演练按钮已删 ──
	var title: Node = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(title)
	await _wait(70)
	var vb: Node = title.get_node_or_null("CenterContainer/MainVBox/ButtonsVBox")
	if vb == null:
		_errs.append("标题 ButtonsVBox 未找到")
	else:
		if vb.get_node_or_null("EnterTruckBaseButton") == null:
			_errs.append("标题缺 EnterTruckBaseButton")
		if vb.get_node_or_null("Arena3v3Button") != null:
			_errs.append("标题仍有 Arena3v3Button")
		if vb.get_node_or_null("EnterBunkerButton") == null:
			_errs.append("标题缺 EnterBunkerButton")
	await _shot("00_title")
	title.queue_free()
	await _wait(5)

	# ── B. 移动基地默认（剖面 era4）──
	var tb: Node = (load("res://scenes/bunker/truck_base.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(tb)
	get_tree().current_scene = tb
	await _wait(45)
	var tex_rect: TextureRect = tb.get("_tex_rect")
	if tex_rect == null or tex_rect.texture == null:
		_errs.append("剖面底图未加载")
	if String(tb.get("_view_mode")) != "interior":
		_errs.append("默认视图应为 interior")
	_check_hotspots(tb, "era4", 11)
	await _shot("01_interior_era4")

	# ── C. 时代切换（era1）：热区重建后必须全部有尺寸（回归锁）──
	tb.call("_on_era_pressed", 0)
	await _wait(5)
	if tex_rect.texture == null or not "truck_cut1" in tex_rect.texture.resource_path:
		_errs.append("切 era1 后底图未换")
	_check_hotspots(tb, "era1", 11)
	await _shot("02_interior_era1")

	# ── D. era3：9 热区 ──
	tb.call("_on_era_pressed", 2)
	await _wait(5)
	_check_hotspots(tb, "era3", 11)
	await _shot("03_interior_era3")

	# ── E. 热区点击 → 真面板（era3 售货机 → 商店）──
	var store_entry: Dictionary = {}
	for h in tb.get("HOTSPOTS").get("era3", []):
		if String(h.get("key", "")) == "store":
			store_entry = h
	if store_entry.is_empty():
		_errs.append("era3 热区表缺 store")
	else:
		tb.call("_on_hotspot", store_entry)
		await _wait(30)
		var wrappers: Dictionary = tb.get("_embed_wrappers")
		if not wrappers.has("store"):
			_errs.append("商店面板未实例化")
		else:
			var wr: Control = wrappers["store"]["wrapper"]
			if not wr.visible:
				_errs.append("商店面板 wrapper 不可见")
		await _shot("04_store_panel")
		# 关闭
		if wrappers.has("store"):
			wrappers["store"]["wrapper"].visible = false

	# ── F. 统计终端 ──
	tb.call("_open_terminal")
	await _wait(12)
	if tb.get("_modal_layer") == null:
		_errs.append("统计终端未打开")
	await _shot("05_terminal")
	tb.call("_close_modal")

	# ── G. 出击简报 ──
	tb.call("_open_sortie")
	await _wait(12)
	if tb.get("_briefing_layer") == null:
		_errs.append("出击简报未打开")
	await _shot("06_briefing")
	tb.call("_close_briefing")

	# ── H. 外景视图 ──
	tb.call("_set_view", "exterior", true)
	await _wait(55)
	var ext_bg: TextureRect = tb.get("_ext_bg")
	var ext_truck: TextureRect = tb.get("_ext_truck")
	if ext_bg == null or ext_bg.texture == null:
		_errs.append("外景背景未加载")
	if ext_truck == null or ext_truck.texture == null:
		_errs.append("外景卡车精灵未加载")
	if String(tb.get("_view_mode")) != "exterior":
		_errs.append("外景模式未生效")
	await _shot("07_exterior")

	# ── I. 回剖面：热区仍在 ──
	tb.call("_set_view", "interior", false)
	await _wait(5)
	_check_hotspots(tb, "era3", 11)


func _check_hotspots(tb: Node, era: String, expected: int) -> void:
	var layer: Control = tb.get("_hot_layer")
	if layer == null:
		_errs.append("%s 热区层为空" % era)
		return
	var kids: Array = layer.get_children()
	if kids.size() != expected:
		_errs.append("%s 热区数量 %d != %d" % [era, kids.size(), expected])
	var bad := 0
	for k in kids:
		var b: Control = k
		if b.size.x < 4.0 or b.size.y < 4.0:
			bad += 1
	if bad > 0:
		_errs.append("%s 有 %d 个热区尺寸为 0（布局循环被挤占？）" % [era, bad])
	print("[Audit] hotspots %s: count=%d zero_size=%d" % [era, kids.size(), bad])


func _find_recursive(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for c in root.get_children():
		var r := _find_recursive(c, node_name)
		if r != null:
			return r
	return null
