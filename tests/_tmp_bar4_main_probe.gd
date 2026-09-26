extends Node
## 记录4#1 几何探针（主场景版）：main.tscn 背包态 BottomInstrumentBar 量测。
## 跑法同 _tmp_bar4_probe.tscn，换成 main.tscn + _open_overlay(backpack)。

func _ready() -> void:
	GameConfig.get_default().feature_gates_enabled = false
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		print("PROBE main.tscn 加载失败")
		get_tree().quit(1)
		return
	var main: Node = packed.instantiate()
	add_child(main)
	_run.call_deferred(main)

func _run(main: Node) -> void:
	await get_tree().process_frame
	for i in range(20):
		await get_tree().process_frame
	# 关掉可能弹出的引导窗（欢迎回来/show_once 链）
	for pnm in ["FeatureUnlockPopup", "AFKSettlementDialog"]:
		var pop := get_tree().root.find_child(pnm, true, false)
		if pop != null and pop.has_method("hide_all"):
			pop.call("hide_all")
	# 开背包
	var bp: Control = main.get("backpack_overlay")
	if bp == null:
		print("PROBE backpack_overlay 为 null")
		get_tree().quit(1)
		return
	main._open_overlay(bp, "backpack")
	for i in range(15):
		await get_tree().process_frame
	_dump(main)
	_shot()
	get_tree().quit(0)

func _dump(main: Node) -> void:
	var vp := get_viewport().get_visible_rect().size
	print("PROBE viewport=", vp)
	var bar: Control = main.get("bottom_instrument_bar")
	if bar == null:
		print("PROBE bottom_instrument_bar 为 null")
		return
	print("PROBE bar visible=", bar.visible, " rect=", bar.get_global_rect(), " min=", bar.get_combined_minimum_size())
	var bb: Control = main.get_node_or_null("HudLayer/BattleBottomBar") as Control
	if bb:
		print("PROBE battle_bottom_bar visible=", bb.visible, " rect=", bb.get_global_rect())
	var hbox: Control = bar.get_node_or_null("Margin/HBox")
	if hbox:
		print("PROBE hbox rect=", hbox.get_global_rect())
	print("PROBE _slot_width=", bar.get("_slot_width"))
	var slot_sec: Control = bar.get_node_or_null("Margin/HBox/InstrumentSection/SlotSection")
	if slot_sec == null:
		return
	var max_right := -1.0e9
	var min_left := 1.0e9
	var n := 0
	for child in slot_sec.get_children():
		var c := child as Control
		if c == null or not c.visible:
			continue
		var r := c.get_global_rect()
		n += 1
		min_left = minf(min_left, r.position.x)
		max_right = maxf(max_right, r.end.x)
	print("PROBE visible_children=", n, " min_left=", min_left, " max_right=", max_right)
	if max_right > vp.x + 1.0 or min_left < -1.0 or max_right > bar.get_global_rect().end.x + 1.0:
		print("BAR4_PROBE_OVERFLOW max_right=%.1f vp_x=%.1f bar_right=%.1f" % [max_right, vp.x, bar.get_global_rect().end.x])
	else:
		print("BAR4_PROBE_OK")

func _shot() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://.godot/agent_tools/bar4_main_probe.png")
	print("PROBE screenshot saved")
