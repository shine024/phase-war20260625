extends Node
## v26.x UI 整编临时校验场景（编辑器 run.scene_headless 跑，有完整 autoload 上下文）

func _ready() -> void:
	var fails: Array[String] = []

	# 1) 批次一：短名链路
	var UCT = load("res://data/unified_card_table.gd")
	var Strip = load("res://scripts/card_grid_name_strip.gd")
	var with_short := 0
	for id in UCT.get_all_card_ids():
		var c = UCT.build_card_resource(id)
		if c == null:
			fails.append("build null: " + str(id))
			continue
		if not c.short_name.is_empty():
			with_short += 1
			if not Strip.text_fits(c.short_name, 64.0, 11):
				fails.append("short too wide: " + str(id))
			if Strip.battlefield_display_name(c) != c.short_name:
				fails.append("short resolve fail: " + str(id))
	if with_short != 76:  # v26.x 短名总数（第二轮校准后）
		fails.append("short_name count=%d expect 58" % with_short)

	# 2) 改动脚本在完整上下文可编译加载
	for p in ["res://scripts/card_grid_unit_visuals.gd", "res://scripts/card_grid_name_strip.gd",
			"res://scenes/ui/ultimate_cast_bar.gd", "res://scenes/ui/top_hud_bar.gd",
			"res://scenes/ui/bottom_instrument_bar.gd", "res://scenes/ui/battle_status_strip.gd",
			"res://scenes/ui/bottom_function_bar.gd"]:
		var s = load(p)
		if s == null or not (s as Script).can_instantiate():
			fails.append("script load/instantiate fail: " + p)

	# 3) main.tscn 结构断言
	var ps = load("res://scenes/main.tscn")
	if ps == null:
		fails.append("main.tscn load fail")
	else:
		var main = ps.instantiate()
		for n in ["HudLayer/BattleTopStatusBar/BattleInfoDisplay", "HudLayer/TopHudBar",
				"HudLayer/BattleStatusStrip", "HudLayer/BattleBottomBar/UltimateCastBar",
				"HudLayer/BattleBottomBar/BottomInstrumentBar", "HudLayer/BattleLogBar"]:
			if main.get_node_or_null(NodePath(n)) == null:
				fails.append("node missing: " + n)
		if main.get_node_or_null(NodePath("HudLayer/TopLeftMeta")) != null:
			fails.append("TopLeftMeta should be deleted")
		var cast_bar = main.get_node_or_null(NodePath("HudLayer/BattleBottomBar/UltimateCastBar"))
		if cast_bar != null and int(cast_bar.custom_minimum_size.y) != 50:
			fails.append("cast bar height=%s expect 50" % str(cast_bar.custom_minimum_size))
		main.free()

	# 4) 头顶栈基准函数
	var V = load("res://scripts/card_grid_unit_visuals.gd")
	for m in ["overhead_hp_bar_y", "overhead_buff_strip_y", "overhead_mod_strip_y", "overhead_buff_labels_y"]:
		if not V.has_method(m):
			fails.append("missing " + m)

	print("short_name cards: ", with_short)
	if fails.is_empty():
		print("UI BATCH CHECK: ALL PASS")
	else:
		for f in fails: print("FAIL: ", f)
	get_tree().quit(0 if fails.is_empty() else 1)
