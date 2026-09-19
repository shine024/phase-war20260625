extends Node
## 临时视觉探针 v3：v6.14.8 情报卡改版五态截图（SubViewport 精确 1280×720 内容像素，
## 免受窗口 DPI 缩放影响）。运行：godot --path . res://tests/_tmp_cardinfo_visual_probe.tscn
## 输出：.godot/agent_tools/cardinfo_*.png（验证完可删）

const PANEL := preload("res://scenes/ui/card_info_panel.tscn")
const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")

var _vp: SubViewport = null
var _panel: Node = null


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.transparent_bg = false
	add_child(_vp)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05)
	bg.size = Vector2(1280, 720)
	_vp.add_child(bg)
	_panel = PANEL.instantiate()
	_vp.add_child(_panel)
	_run()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	# 1) 背包模式战斗卡（克隆+2 改造：验证改造槽砖块）
	_panel.set_panel_mode(0)
	var c1: CardResource = DefaultCards.get_card_by_id("cold_t72").clone()
	c1.mods = [{"id": "inf_14_knee_pads"}, {"id": "inf_19_radio"}]
	_panel.show_card_info(c1, Vector2(370, 20))
	await _shot("cardinfo_s1_backpack_t72.png")
	# 1b) 滚动区滚到底：验证改造槽砖块
	var sc: ScrollContainer = _panel.get_node("Margin/VBox/TabBar/TabDetail/AffixScroll")
	await get_tree().process_frame
	await get_tree().process_frame
	sc.ensure_control_visible(_panel.get_node("Margin/VBox/TabBar/TabDetail/AffixScroll/AffixList/ModsBlock"))
	await _shot("cardinfo_s1b_scrolled.png")
	# 1c) 改造 Tab 基线截图（懒加载链实例化 modification_panel）
	_panel._tab_container.current_tab = 2
	for i in 12:
		await get_tree().process_frame
	await _shot("cardinfo_s1c_modify_tab.png")
	_panel._tab_container.current_tab = 0
	# 2) 背包模式能量卡（非战斗卡降级）
	var en := CardResource.new()
	en.card_id = "test_energy_probe"
	en.card_type = GC.CardType.ENERGY
	en.display_name = "测试充能卡"
	en.era = 1
	en.rarity = "common"
	en.energy_cost = 1.0
	en.energy_grant = 3.0
	en.summary_line = "提供 3 能量"
	en.description = "测试用"
	_panel.show_card_info(en, Vector2(370, 20))
	await _shot("cardinfo_s2_energy.png")
	# 3) 相位仪模式（底部出现"卸下此卡"操作钮）
	_panel.set_panel_mode(1)
	_panel.show_card_info(DefaultCards.get_card_by_id("cold_t72"), Vector2(370, 20))
	await _shot("cardinfo_s3_instrument.png")
	# 4) 战场模式我方单位
	# 4) 战场模式我方单位（锁定敌方目标 → 目标对比条 + 战场底行动态）
	var foe0 := Node2D.new()
	foe0.set_script(load("res://tests/_tmp_cardinfo_fake_unit.gd"))
	foe0.stats = UnitStatsTable.build_stats_from_card(DefaultCards.get_card_by_id("cold_t72"), -1)
	# 拉开数值差，让对比条不对称（我 130/580/-- vs 目标 90/420/60 防 60）
	foe0.stats.attack_light = 90.0
	foe0.stats.attack_armor = 420.0
	foe0.stats.attack_air = 60.0
	foe0.stats.defense_armor = 60.0
	foe0.archetype_id = "ww1_inf_rifle"
	foe0.hp = 120.0
	foe0.max_hp = 120.0
	foe0.position = Vector2(250, 0)
	foe0.add_to_group("enemy_units")
	_vp.add_child(foe0)
	var unit := Node2D.new()
	unit.set_script(load("res://tests/_tmp_cardinfo_fake_unit.gd"))
	unit.stats = UnitStatsTable.build_stats_from_card(DefaultCards.get_card_by_id("cold_t72"), -1)
	unit.add_to_group("player_units")
	unit.target = foe0
	_vp.add_child(unit)
	_panel.set_panel_mode(2)
	_panel.show_unit_info(unit, true, Vector2(370, 20))
	# 探针环境无进行中战斗：直接调内层助手可视化动态底行 + 目标对比（目标未揭示 vis=0 → ???）
	_panel._fill_battle_bottom(4, 12, 45.0, 2)
	_panel._fill_unit_hp_bar(300.0, 763.0)
	_panel._refresh_target_compare_for_unit(unit)
	_panel._refresh_threat_block(unit)
	await _shot("cardinfo_s4_battle_unit.png")
	# 4b) 滚动区滚到威胁块
	var sc4: ScrollContainer = _panel.get_node("Margin/VBox/TabBar/TabDetail/AffixScroll")
	var threat_block: Control = _panel.get_node("Margin/VBox/TabBar/TabDetail/AffixScroll/AffixList/ThreatBlock")
	await get_tree().process_frame
	await get_tree().process_frame
	sc4.scroll_vertical = int(threat_block.position.y) - 4
	await _shot("cardinfo_s4b_threat.png")
	# 5) 战场模式未揭示敌方（情报掩码 ???）+ archetype 立绘兜底
	var foe := Node2D.new()
	foe.set_script(load("res://tests/_tmp_cardinfo_fake_unit.gd"))
	foe.archetype_id = "ww1_inf_rifle"
	foe.hp = 120.0
	foe.max_hp = 120.0
	foe.add_to_group("enemy_units")
	_vp.add_child(foe)
	_panel.show_unit_info(foe, false, Vector2(370, 20))
	await _shot("cardinfo_s5_enemy_masked.png")
	get_tree().quit()


func _shot(fname: String) -> void:
	_panel.position = Vector2(370, 20)
	for i in 4:
		await get_tree().process_frame
	var img := _vp.get_texture().get_image()
	img.save_png("res://.godot/agent_tools/" + fname)
	print("SAVED ", fname, " ", img.get_width(), "x", img.get_height())
