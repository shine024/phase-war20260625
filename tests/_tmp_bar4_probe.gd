extends Node
## 记录4#1 几何探针：基地背包内嵌相位仪栏超屏复现。
## 跑法：run_scene_headless（带 screenshot 参数走真窗口）→ tests/_tmp_bar4_probe.tscn
## 输出：PROBE 前缀几何行 + BAR4_PROBE_OK / BAR4_PROBE_OVERFLOW 收尾断言。

func _ready() -> void:
	GameConfig.get_default().feature_gates_enabled = false
	var packed: PackedScene = load("res://scenes/bunker/truck_base.tscn")
	if packed == null:
		print("PROBE truck_base 加载失败")
		get_tree().quit(1)
		return
	var base: Node = packed.instantiate()
	add_child(base)
	_run.call_deferred(base)

func _run(base: Node) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	# 记录4#4 视觉检查准备：往绿槽塞三张起始卡，让信息条有内容可渲染
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim != null and pim.has_method("equip_card"):
		var dc := load("res://data/default_cards.gd")
		for i in range(3):
			var cid: String = ["ww1_mauser", "ww1_arty_m81", "ww1_arm_ft17"][i]
			var card: CardResource = dc.get_card_by_id(cid)
			if card != null:
				pim.equip_card(i, card)
	# 序列复现：开背包（首次）→ 关 → 改窗口尺寸 → 再开（记录4 用户序列：背包超屏→战斗→回基地再开正常）
	if base.has_method("_open_panel"):
		base._open_panel("backpack")
	for i in range(15):
		await get_tree().process_frame
	print("== PASS1 first-open ==")
	_dump(base)
	# 关闭
	var wr0: Dictionary = base._embed_wrappers.get("backpack", {})
	var wrapper0: Control = wr0.get("wrapper")
	if wrapper0 != null:
		wrapper0.visible = false
	await get_tree().process_frame
	# 改窗口物理尺寸（stretch=expand 下视口逻辑宽随动）
	for wsize in [Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(1366, 768)]:
		get_window().size = wsize
		await get_tree().process_frame
		await get_tree().process_frame
		if wrapper0 != null:
			wrapper0.visible = true
		for i in range(12):
			await get_tree().process_frame
		print("== PASS window=", get_window().size, " viewport=", get_viewport().get_visible_rect().size, " ==")
		_dump(base)
	# 大字号档（settings_panel.apply_ui_scale_at_boot 同款）：content_scale_factor=1.25
	# 逻辑视口缩到 ~1024，是记录4#1 唯一没测过的窄幅区
	get_window().size = Vector2i(1280, 720)
	get_tree().root.content_scale_factor = 1.25
	await get_tree().process_frame
	await get_tree().process_frame
	if wrapper0 != null:
		wrapper0.visible = true
	for i in range(12):
		await get_tree().process_frame
	print("== PASS large_type viewport=", get_viewport().get_visible_rect().size, " ==")
	_dump(base)
	_shot()
	get_tree().quit(0)

func _dump_inst_tab(bp: Control) -> void:
	var vp := get_viewport().get_visible_rect().size
	print("PROBE_TAB viewport=", vp)
	# 找相位仪列表容器（成员 _phase_inst_list）
	var list: Control = bp.get("_phase_inst_list")
	if list == null:
		print("PROBE_TAB _phase_inst_list 为 null")
		return
	print("PROBE_TAB list rect=", list.get_global_rect())
	var max_right := -1.0e9
	var n := 0
	for child in list.get_children():
		var c := child as Control
		if c == null:
			continue
		n += 1
		var r := c.get_global_rect()
		max_right = maxf(max_right, r.end.x)
		print("PROBE_TAB item ", c.get_class(), " rect=", r)
	print("PROBE_TAB items=", n, " max_right=", max_right)
	if max_right > vp.x + 1.0:
		print("TAB4_PROBE_OVERFLOW max_right=%.1f vp_x=%.1f" % [max_right, vp.x])
	else:
		print("TAB4_PROBE_OK")

func _dump(base: Node) -> void:
	var vp := get_viewport().get_visible_rect().size
	print("PROBE viewport=", vp)
	var wr: Dictionary = base._embed_wrappers.get("backpack", {})
	var wrapper: Control = wr.get("wrapper")
	if wrapper == null:
		print("PROBE backpack wrapper 未创建")
		return
	print("PROBE wrapper rect=", wrapper.get_global_rect())
	var bar: Control = wrapper.get_node_or_null("EmbedInstrumentBar")
	if bar == null:
		print("PROBE EmbedInstrumentBar 缺失")
		return
	print("PROBE bar rect=", bar.get_global_rect(), " min=", bar.get_combined_minimum_size())
	var hbox: Control = bar.get_node_or_null("Margin/HBox")
	if hbox:
		print("PROBE hbox rect=", hbox.get_global_rect())
	var sec: Control = bar.get_node_or_null("Margin/HBox/InstrumentSection")
	if sec:
		print("PROBE instrument_section rect=", sec.get_global_rect())
	var slot_sec: Control = bar.get_node_or_null("Margin/HBox/InstrumentSection/SlotSection")
	if slot_sec:
		print("PROBE slot_section rect=", slot_sec.get_global_rect())
	print("PROBE _slot_width=", bar.get("_slot_width"))
	var max_right := -1.0e9
	var min_left := 1.0e9
	var n_visible := 0
	for child in slot_sec.get_children():
		var c := child as Control
		if c == null or not c.visible:
			continue
		var r := c.get_global_rect()
		n_visible += 1
		min_left = minf(min_left, r.position.x)
		max_right = maxf(max_right, r.end.x)
		print("PROBE slot ", c.name, " rect=", r)
	print("PROBE visible_children=", n_visible, " min_left=", min_left, " max_right=", max_right)
	if max_right > vp.x + 1.0 or min_left < -1.0:
		print("BAR4_PROBE_OVERFLOW max_right=%.1f vp_x=%.1f" % [max_right, vp.x])
	else:
		print("BAR4_PROBE_OK")

func _shot() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://.godot/agent_tools/bar4_probe.png")
	print("PROBE screenshot saved")
