extends GdUnitTestSuite
## v6.14.8 情报卡改版回归锁：六分区版式（design/ux/card-info-panel.md）。
## 覆盖：节点解析 / 战术格填充（含敌方情报三档掩码与 "--" 不可攻击）/ 非战斗卡降级 /
## 词条行化（旧版 for 循环缩进死代码 bug 的防回归）/ 底行 / 三模式打开零报错。

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const PANEL_SCENE := "res://scenes/ui/card_info_panel.tscn"

var _panel: Node = null


func before_test() -> void:
	_panel = (load(PANEL_SCENE) as PackedScene).instantiate()
	add_child(_panel)


func after_test() -> void:
	if is_instance_valid(_panel):
		_panel.free()
	_panel = null


func _t72() -> CardResource:
	return DefaultCards.get_card_by_id("cold_t72")


func _energy_card() -> CardResource:
	var c := CardResource.new()
	c.card_id = "test_energy_probe"
	c.card_type = GC.CardType.ENERGY
	c.display_name = "测试充能卡"
	c.era = 1
	c.rarity = "common"
	c.energy_cost = 1.0
	c.energy_grant = 3.0
	c.summary_line = "提供 3 能量"
	c.description = "测试用"
	c.flavor_text = ""
	return c


func test_nodes_resolved() -> void:
	for n: String in ["name_label", "star_label", "type_badge_label", "rarity_label", "cost_label",
			"portrait_rect", "portrait_placeholder", "power_value_label", "hp_value_label",
			"range_value_label", "move_value_label", "slash_label", "core_row", "matrix_row",
			"era_label", "weight_label", "terrain_label", "affix_label", "_affix_flow",
			"nurture_label", "_card_skill_label", "_bonus_label", "status_label", "desc_label",
			"flavor_label", "action_buttons_container", "close_button", "_tab_container"]:
		assert_object(_panel.get(n)).is_not_null()
	assert_int(_panel.matrix_value_labels.size()).is_equal(4)


func test_combat_card_fills_cells() -> void:
	var card := _t72()
	assert_object(card).is_not_null()
	_panel.show_card_info(card)
	# 标题行与徽章
	assert_str(_panel.name_label.text).is_not_empty()
	assert_str(_panel.type_badge_label.text).is_not_empty()
	# 战术格：战力/耐久/射程为正数文本
	assert_str(_panel.power_value_label.text).is_not_empty()
	assert_int(int(_panel.power_value_label.text)).is_greater(0)
	assert_int(int(_panel.hp_value_label.text)).is_greater(0)
	assert_int(int(_panel.range_value_label.text)).is_greater(0)
	# 克制矩阵四格均非空；t72 对空很低但不该是空串
	for i in 4:
		var lbl: Label = _panel.matrix_value_labels[i]
		assert_str(lbl.text).is_not_empty()
	# 底行：时代 = 冷战（cold_t72，era 2）
	assert_str(_panel.era_label.text).contains("冷战")
	# 底行能耗位 = 部署能耗
	assert_str(_panel.weight_label.text).contains("⚡")
	# 立绘加载成功（t72 有卡图）
	assert_object(_panel.portrait_rect.texture).is_not_null()
	# 词条区有行（武装行或词条行；旧死代码 bug 下 Flow 会恒空）
	assert_int(_panel._affix_flow.get_child_count()).is_greater(0)
	# 状态区（战场专用）在卡牌模式隐藏
	assert_bool(_panel.status_section.visible).is_false()


func test_energy_card_degrades_cells() -> void:
	var card := _energy_card()
	_panel.show_card_info(card)
	assert_bool(_panel.core_row.visible).is_false()
	assert_bool(_panel.matrix_row.visible).is_false()
	assert_bool(_panel.slash_label.visible).is_false()
	# 能量卡预览行走 summary 行
	assert_bool(_panel.summary_label.visible).is_true()
	assert_str(_panel.summary_label.text).is_not_empty()
	# 徽章 = 充能槽
	assert_str(_panel.type_badge_label.text).is_equal("充能槽")


func test_fill_cells_masks_by_visibility() -> void:
	var card := _t72()
	var stats: UnitStats = UnitStatsTable.build_stats_from_card(card, -1)
	# 精确档（vis=2）
	_panel._fill_combat_cells(stats, -1.0, 2)
	assert_str(_panel.hp_value_label.text).is_equal(str(int(stats.max_hp)))
	assert_str(_panel.range_value_label.text).is_equal(str(int(stats.attack_range)))
	# 隐藏档（vis=0）→ "???"；攻值 -- 语义不变（零=不可攻击）
	_panel._fill_combat_cells(stats, 40.0, 0)
	assert_str(_panel.hp_value_label.text).is_equal("???/???")
	for i in 3:
		var v: float = [stats.attack_light, stats.attack_armor, stats.attack_air][i]
		if v <= 0.001:
			assert_str(_panel.matrix_value_labels[i].text).is_equal("--")
		else:
			assert_str(_panel.matrix_value_labels[i].text).is_equal("???")
	# 区间档（vis=1）→ "x–y"
	_panel._fill_combat_cells(stats, -1.0, 1)
	assert_str(_panel.hp_value_label.text).contains("–")


func test_fill_cells_null_stats_only_hp() -> void:
	# 相位场驱动器等基地单位：仅耐久格有值，战术格其余降级
	_panel._fill_combat_cells(null, 320.0, 2)
	assert_str(_panel.hp_value_label.text).is_equal("320/—")
	assert_str(_panel.power_value_label.text).is_equal("—")
	assert_str(_panel.hp_value_label.text).is_not_equal("--")
	assert_bool(_panel.matrix_row.visible).is_false()
	assert_bool(_panel.slash_label.visible).is_false()


func test_bottom_row_terrain_modifier() -> void:
	var card := _t72()
	var stats: UnitStats = UnitStatsTable.build_stats_from_card(card, -1)
	stats.urban_defense_bonus = 0.15
	_panel._refresh_bottom_row(stats, 1, "8⚡")
	assert_str(_panel.terrain_label.text).is_equal("巷战减伤 15%")
	stats.urban_defense_bonus = 0.0
	_panel._refresh_bottom_row(stats, 1, "")
	assert_str(_panel.terrain_label.text).is_equal("—")
	assert_str(_panel.weight_label.text).is_equal("—")


func test_three_modes_open_without_error() -> void:
	var card := _t72()
	# 背包 / 相位仪 / 战场三模式（v26.11 语义：战场点选卡牌也走 show_card_info）
	for mode: int in [0, 1, 2]:
		_panel.set_panel_mode(mode)
		_panel.show_card_info(card)
		assert_bool(_panel.visible).is_true()
		assert_object(_panel.current_card).is_not_null()
		assert_str(_panel.power_value_label.text).is_not_empty()
	# 战场单位模式入口（show_unit_info 走 _refresh_unit_display，无真实单位时直接返回不崩溃）
	_panel.show_unit_info(null, true)
	assert_bool(_panel.visible).is_true()


func test_mods_tiles_build_and_click_jumps_to_modify_tab() -> void:
	# C 版模块槽情报化（只加不减）：槽位砖块 + 悬停 + 点击直跳改造 Tab
	# v38 契约：背包/战场模式隐藏改造/制造 Tab（独立解锁功能），砖块点击不跳转；
	# 相位仪模式（MODE_PHASE_INSTRUMENT）保留直跳链。
	var card := _t72().clone()
	card.mods = [{"id": "inf_14_knee_pads"}]
	_panel.show_card_info(card)
	assert_bool(_panel._mods_block.visible).is_true()
	# v6.16 槽位预算：砖块数随卡品质+兵种动态（cold_t72=rare 装甲 → 7+1=8）
	var expect_max: int = ModManager.get_max_mod_slots_for_card(card)
	assert_int(expect_max).is_equal(8)
	assert_str(_panel._mods_caption.text).contains("改造 1/%d" % expect_max)
	assert_int(_panel._mods_tiles.get_child_count()).is_equal(expect_max)
	var tile0 := _panel._mods_tiles.get_child(0) as Button
	assert_str(tile0.tooltip_text).contains("槽位 1")
	assert_str(tile0.tooltip_text).contains("护膝")
	var tile2 := _panel._mods_tiles.get_child(2) as Button
	assert_str(tile2.tooltip_text).contains("空槽")
	# 背包模式（默认）：改造/制造 Tab 隐藏，详细情报 Tab 显示，点击砖块不跳转
	assert_bool(_panel._tab_container.is_tab_hidden(2)).is_true()
	assert_bool(_panel._tab_container.is_tab_hidden(3)).is_true()
	assert_bool(not _panel._tab_container.is_tab_hidden(1)).is_true()
	tile0.pressed.emit()
	assert_int(_panel._tab_container.current_tab).is_equal(0)
	# 相位仪模式：改造 Tab 显示，点击已装槽 → 切到改造 Tab（既有懒加载链）
	_panel.set_panel_mode(1)
	_panel.show_card_info(card)
	assert_bool(not _panel._tab_container.is_tab_hidden(2)).is_true()
	tile0 = _panel._mods_tiles.get_child(0) as Button
	tile0.pressed.emit()
	assert_int(_panel._tab_container.current_tab).is_equal(2)


func test_unit_hp_bar_and_threat_block() -> void:
	# D 版剩余元素：标题行实时血条 + 威胁提示块
	_panel._fill_unit_hp_bar(30.0, 100.0)
	assert_bool(_panel._unit_hp_bar.visible).is_true()
	assert_float(_panel._unit_hp_bar.value).is_equal(30.0)
	_panel._fill_unit_hp_bar(-1.0, 0.0)
	assert_bool(_panel._unit_hp_bar.visible).is_false()
	# 威胁收集：敌方射程 400、距离 300 → 1 条威胁行；挪出射程 → 0 条且整块隐藏
	var my := Node2D.new()
	my.set_script(load("res://tests/_tmp_cardinfo_fake_unit.gd"))
	my.add_to_group("player_units")
	add_child(my)
	var foe := Node2D.new()
	foe.set_script(load("res://tests/_tmp_cardinfo_fake_unit.gd"))
	foe.stats = UnitStatsTable.build_stats_from_card(_t72(), -1)
	foe.stats.attack_range = 400.0
	foe.hp = 100.0
	foe.position = Vector2(300, 0)
	foe.add_to_group("enemy_units")
	add_child(foe)
	var lines: Array[String] = _panel._collect_threat_lines(my)
	assert_int(lines.size()).is_equal(1)
	assert_str(lines[0]).contains("距 300")
	assert_str(lines[0]).contains("射程 400")
	_panel._refresh_threat_block(my)
	assert_bool(_panel._threat_block.visible).is_true()
	foe.position = Vector2(2000, 0)
	assert_int(_panel._collect_threat_lines(my).size()).is_equal(0)
	_panel._refresh_threat_block(my)
	assert_bool(_panel._threat_block.visible).is_false()
	# 阵亡敌人不计威胁
	foe.position = Vector2(300, 0)
	foe.hp = 0.0
	assert_int(_panel._collect_threat_lines(my).size()).is_equal(0)


func test_close_and_reopen_clears_state() -> void:
	_panel.show_card_info(_t72())
	_panel.hide_panel()
	assert_bool(_panel.visible).is_false()
	assert_object(_panel.current_card).is_null()
	# 重开不残留
	_panel.show_card_info(_energy_card())
	assert_str(_panel.name_label.text).is_equal("测试充能卡")


func test_battle_bottom_dynamic_fill() -> void:
	# §7 战场底行动态：波次/能量/剩余部署
	_panel._fill_battle_bottom(3, 12, 45.0, 2)
	assert_str(_panel.era_label.text).is_equal("波次 3/12")
	assert_str(_panel.weight_label.text).is_equal("能量 45")
	assert_str(_panel.terrain_label.text).is_equal("剩余部署 ×2")
	# 无限次（-1）显示 "—"；波次钳制不倒挂
	_panel._fill_battle_bottom(5, 3, 0.0, -1)
	assert_str(_panel.era_label.text).is_equal("波次 5/5")
	assert_str(_panel.terrain_label.text).is_equal("—")


func test_target_compare_fill_and_hide() -> void:
	var card := _t72()
	var mine: UnitStats = UnitStatsTable.build_stats_from_card(card, -1)
	var its: UnitStats = UnitStatsTable.build_stats_from_card(card, -1)
	# 双方有 stats → 块显示，行值按掩码填充
	_panel._fill_target_compare(mine, its, 2, "T-72")
	assert_bool(_panel._target_compare_block.visible).is_true()
	assert_str(_panel._target_compare_caption.text).contains("T-72")
	assert_str(_panel._target_compare_rows[0]["my_val"].text).is_equal(str(int(mine.attack_light)))
	assert_str(_panel._target_compare_rows[0]["it_val"].text).is_equal(str(int(its.attack_light)))
	# 零值维（t72 对空中 0）显示 "--"
	assert_str(_panel._target_compare_rows[2]["my_val"].text).is_equal("--")
	# 目标侧未揭示（vis=0）→ 数值 "???"，条长固定示意值（0.4 比例）防泄漏
	_panel._fill_target_compare(mine, its, 0, "未揭示敌人")
	assert_str(_panel._target_compare_rows[0]["it_val"].text).is_equal("???")
	assert_float(_panel._target_compare_rows[0]["it_bar"].value).is_equal(
		_panel._target_compare_rows[0]["it_bar"].max_value * 0.4)
	# 任一方缺 stats → 整块隐藏（相位场基地不参与对比）
	_panel._fill_target_compare(null, its, 2, "X")
	assert_bool(_panel._target_compare_block.visible).is_false()
	# 切回卡牌模式 → 对比块恒隐藏
	_panel._fill_target_compare(mine, its, 2, "T-72")
	_panel.show_card_info(card)
	assert_bool(_panel._target_compare_block.visible).is_false()
