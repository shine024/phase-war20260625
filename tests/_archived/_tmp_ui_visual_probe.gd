extends Node2D
## v26.x UI 整编可视化探针（编辑器 capture_screenshot 用，勿提交）
## 摆 4 个假单位（长名/短名/变体后缀/势力前缀）+ 底部两条实例，验证名牌/头顶栈/底板。

func _ready() -> void:
	var UCT = load("res://data/unified_card_table.gd")
	var V = load("res://scripts/card_grid_unit_visuals.gd")
	# 底色板
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.19, 0.15)
	bg.size = Vector2(1280, 720)
	bg.z_index = -10
	add_child(bg)
	# 4 个测试单位：短名卡 / 长名无短名卡 / ·精锐变体 / 5字无短名卡
	var ids := ["ww1_fort_pillbox", "ww1_arty_77mm", "ww1_arty_m81", "guardian_ww1_ironclad"]
	for i in ids.size():
		var card = UCT.build_card_resource(ids[i])
		if card == null:
			continue
		var host := Node2D.new()
		host.position = Vector2(160.0 + 160.0 * i, 220.0)
		add_child(host)
		var spr := Sprite2D.new()
		host.add_child(spr)
		var tex: Texture2D = load("res://assets/card_icons/enemy/cold_arm_p18.png")
		var is_player := i % 2 == 0
		V.apply_battle_unit_presentation(host, spr, card, tex, not is_player, 3, host)
		# 血条（与 construct_unit 挂法同式）
		var hb = load("res://scenes/units/unit_hp_bar.tscn").instantiate()
		hb.name = "HpBar"
		host.add_child(hb)
		hb.z_index = V.OVERHEAD_UI_Z
		hb.position = Vector2(0.0, V.overhead_hp_bar_y(spr))
		if hb.has_method("set_max_hp"):
			hb.set_max_hp(100.0)
		if hb.has_method("set_hp"):
			hb.set_hp(76.0)
		V.sync_buff_strip(host, host, spr)
		V.sync_mod_strip(host, host, spr)
		V.sync_buff_labels(host, spr, host)
	# 大招条 + 相位仪栏实例（底部实景）
	var cast_bar = load("res://scenes/ui/ultimate_cast_bar.gd").new()
	cast_bar.name = "UltimateCastBar"
	cast_bar.position = Vector2(0, 560)
	cast_bar.size = Vector2(1280, 50)
	add_child(cast_bar)
	# 伪造战斗态：cast bar 的 _process 按 BattleManager.battle_active 显隐
	BattleManager.set("battle_active", true)
	cast_bar.visible = true
	cast_bar._refresh_buttons()
	cast_bar.queue_redraw()
	var inst_bar = load("res://scenes/ui/bottom_instrument_bar.tscn").instantiate()
	inst_bar.position = Vector2(16, 620)
	add_child(inst_bar)


var _frames := 0
func _process(_d: float) -> void:
	_frames += 1
	if _frames == 30:
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://.godot/agent_tools/ui_visual_probe.png")
		print("[Probe] screenshot saved")
		get_tree().quit()
