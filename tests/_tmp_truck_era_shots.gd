extends Node
## v26.12 移动基地全时代全工位巡检（临时工具）：5 时代 × 11 热区功能断言 + 全量截图
## 跑法：godot --rendering-driver opengl3 --path . res://tests/_tmp_truck_era_shots.tscn
## 截图输出 .godot/agent_tools/truckchk_*.png；退出码非 0 = 有断言失败
## ⚠️ 末尾会点一次"铺位"（真实 BunkerManager.sleep 推进天数并存档）——
##     跑前必须备份 save_slot_1.json，跑后由外部恢复。

const DIR := "res://.godot/agent_tools/"
var _fails: Array[String] = []
var _tb: Node


func _ready() -> void:
	await _run()
	for f in _fails:
		printerr("[TruckChk] FAIL: " + f)
	if _fails.is_empty():
		print("[TruckChk] ALL PASS")
	get_tree().quit(0 if _fails.is_empty() else 1)


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(ProjectSettings.globalize_path(DIR + "truckchk_%s.png" % tag))
		print("[TruckChk] shot %s" % tag)
	else:
		_fails.append("截图失败: " + tag)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _err(msg: String) -> void:
	_fails.append(msg)


func _run() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.call("load_game")
		if sm.has_method("flush_deferred_manager_loads"):
			sm.call("flush_deferred_manager_loads")

	# ── A. 标题屏入口 ──
	var title: Node = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(title)
	await _wait(60)
	var vb: Node = title.get_node_or_null("CenterContainer/MainVBox/ButtonsVBox")
	if vb == null or vb.get_node_or_null("EnterTruckBaseButton") == null:
		_err("标题缺 EnterTruckBaseButton")
	await _shot("00_title")
	title.queue_free()
	await _wait(5)

	# ── B. 移动基地入场态（默认 era4 + 真实进度）──记录 caption 供人工核对 ──
	_tb = (load("res://scenes/bunker/truck_base.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_tb)
	get_tree().current_scene = _tb
	await _wait(45)
	await _shot("01_entry_default")
	print("[TruckChk] entry caption: ", _tb.get("_caption").text,
		" | view=", _tb.get("_view_mode"), " | era_idx=", _tb.get("_era_idx"))

	# ── C. 五时代 × 全工位 ──
	for e in range(5):
		await _check_era(e)

	# ── D. 睡觉（真实推进一天；外部恢复存档）──
	await _test_sleep()


func _check_era(e: int) -> void:
	var eras: Array = _tb.get("ERAS")
	var era_lvl := int(eras[e]["level"])
	var era_id := String(eras[e]["id"])
	# 先设关卡再 set_era：caption/剖面底图/外景图与该时代一致
	if GameManager != null:
		GameManager.call("set_current_level", era_lvl)
	_tb.call("set_era", e, false)
	await _wait(8)

	# 底图与热区
	var tex_rect: TextureRect = _tb.get("_tex_rect")
	if tex_rect == null or tex_rect.texture == null:
		_err("%s 剖面底图未加载" % era_id)
	elif not era_id.contains("era") or not String(tex_rect.texture.resource_path).contains("truck_cut%d" % (e + 1)):
		_err("%s 剖面底图不符: %s" % [era_id, tex_rect.texture.resource_path])
	var hotspots: Array = (_tb.get("HOTSPOTS") as Dictionary).get(era_id, [])
	if hotspots.size() != 11:
		_err("%s 热区数 %d != 11" % [era_id, hotspots.size()])
	var layer: Control = _tb.get("_hot_layer")
	var kids: Array = layer.get_children()
	if kids.size() != hotspots.size():
		_err("%s 热区按钮数 %d != 表 %d" % [era_id, kids.size(), hotspots.size()])
	for k in kids:
		if k.size.x < 4.0 or k.size.y < 4.0:
			_err("%s 存在零尺寸热区" % era_id)
			break
	print("[TruckChk] era%d caption: %s" % [e + 1, _tb.get("_caption").text])
	await _shot("%02d_interior_era%d" % [e + 2, e + 1])

	# 工位逐个打开断言（按钮走同一 _on_hotspot 路径）
	for i in kids.size():
		var h: Dictionary = hotspots[i]
		var kind := String(h.get("kind", "info"))
		var name_s := String(h.get("name", "?"))
		match kind:
			"panel":
				var key := String(h.get("key", ""))
				_tb.call("_on_hotspot", h)
				await _wait(25)
				var wrappers: Dictionary = _tb.get("_embed_wrappers")
				if not wrappers.has(key):
					_err("era%d %s → 面板 %s 未实例化" % [e + 1, name_s, key])
				else:
					var wr: Control = wrappers[key]["wrapper"]
					if not wr.visible:
						_err("era%d %s → 面板 %s 不可见" % [e + 1, name_s, key])
					var p: Control = wrappers[key]["panel"]
					if not p.has_signal("closed"):
						_err("面板 %s 缺 closed 信号（无法关闭）" % key)
					# 面板截图只在 era1 轮做（各时代同面板）
					if e == 0:
						await _shot("10_panel_%s" % key)
					wr.visible = false
			"terminal":
				_tb.call("_on_hotspot", h)
				await _wait(12)
				if _tb.get("_modal_layer") == null:
					_err("era%d 统计终端未打开" % (e + 1))
				if e == 0:
					await _shot("11_terminal")
				_tb.call("_close_modal")
			"sortie":
				_tb.call("_on_hotspot", h)
				await _wait(12)
				if _tb.get("_briefing_layer") == null:
					_err("era%d 出击简报未打开" % (e + 1))
				await _shot("12_briefing_era%d" % (e + 1))
				_tb.call("_close_briefing")
			"sleep":
				# 真实睡觉只在末尾做一次（推进天数）；此处只断言热区存在
				pass
			_:
				_tb.call("_on_hotspot", h)
				await _wait(8)
				if _tb.get("_modal_layer") == null:
					_err("era%d %s（info）信息卡未打开" % [e + 1, name_s])
				if e == 0:
					await _shot("13_info_%s" % name_s)
				_tb.call("_close_modal")

	# 外景视图
	_tb.call("_set_view", "exterior", false)
	await _wait(40)
	var ext_bg: TextureRect = _tb.get("_ext_bg")
	var ext_truck: TextureRect = _tb.get("_ext_truck")
	if ext_bg == null or ext_bg.texture == null:
		_err("era%d 外景背景未加载" % (e + 1))
	if ext_truck == null or ext_truck.texture == null:
		_err("era%d 外景卡车精灵未加载" % (e + 1))
	await _shot("%02d_exterior_era%d" % [e + 2, e + 1])
	_tb.call("_set_view", "interior", false)
	await _wait(4)


func _test_sleep() -> void:
	var hotspots: Array = (_tb.get("HOTSPOTS") as Dictionary).get("era1", [])
	var sleep_h: Dictionary = {}
	for h in hotspots:
		if String(h.get("kind", "")) == "sleep":
			sleep_h = h
			break
	if sleep_h.is_empty():
		_err("era1 表缺 sleep 热区")
		return
	_tb.call("_on_hotspot", sleep_h)
	await _wait(12)
	if _tb.get("_modal_layer") == null:
		_err("睡觉结算卡未打开")
	await _shot("14_sleep")
	_tb.call("_close_modal")
