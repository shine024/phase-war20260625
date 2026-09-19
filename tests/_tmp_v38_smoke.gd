extends SceneTree
## v38 实机验收批5 冒烟：12 项修复的编译 + 行为断言（--script 模式）。
## 纪律（v37 同款）：_initialize()（autoload 全局名已注册）+ 零 await。
## 覆盖：紫框弹窗成员引用 / 跳过按钮移除 / 背包入队去重 / 下一关门槛放宽 /
## 情报卡详细情报 Tab + 模式门控 / 战斗抽屉竖排 / 开场演出跳过按钮 / 地图常驻进关键 /
## 炮弹缩幅 / 掉落坠落入场。

const MODIFIED := [
	"res://scenes/ui/intel_reveal_popup.gd",
	"res://scenes/ui/top_hud_bar.gd",
	"res://managers/save_manager.gd",
	"res://managers/phase_instrument_manager.gd",
	"res://scenes/ui/mvp_panel.gd",
	"res://scenes/ui/card_info_panel.gd",
	"res://scenes/ui/bottom_function_bar.gd",
	"res://scenes/bunker/truck_base.gd",
	"res://managers/tutorial_progression_manager.gd",
	"res://scenes/ui/backpack_panel.gd",
	"res://scenes/world_map.gd",
	"res://scripts/weapon_projectile_vfx.gd",
	"res://scripts/battle/ground_loot_layer.gd",
]

func _initialize() -> void:
	var fails: Array[String] = []

	# 1) 全部改动文件可编译加载
	for p in MODIFIED:
		if load(p) == null:
			fails.append("加载失败: " + p)

	# 2) 紫框弹窗：成员引用存在（不再依赖匿名节点路径）
	var IRP = load("res://scenes/ui/intel_reveal_popup.gd")
	var probe: Control = IRP.new()
	probe._build_ui()
	if probe._title_lbl == null or probe._desc_lbl == null or probe._reward_box == null or probe._page_lbl == null:
		fails.append("IntelRevealPopup 成员引用为 null")
	probe.free()

	# 3) 跳过按钮已移除：top_hud_bar 源码不再含跳过按钮代码
	var thb_src := FileAccess.get_file_as_string("res://scenes/ui/top_hud_bar.gd")
	if thb_src.contains("func _build_skip_btn") or thb_src.contains("func _on_skip_pressed") 			or thb_src.contains('var _skip_btn'):
		fails.append("top_hud_bar 仍含跳过按钮代码")

	# 4) 背包入队去重：同 id 二次入队不重复
	var sm = root.get_node_or_null("SaveManager")
	if sm == null:
		fails.append("SaveManager autoload 缺失")
	else:
		sm.set("_pending_backpack_ids", [])
		sm.set("_last_known_extra_ids", [])
		sm.enqueue_backpack_card_id("v38_probe#1")
		sm.enqueue_backpack_card_id("v38_probe#1")
		if (sm.get("_pending_backpack_ids") as Array).size() != 1:
			fails.append("enqueue 去重失效（pending 仍重复）")
		if (sm.get("_last_known_extra_ids") as Array).size() != 1:
			fails.append("enqueue 去重失效（last_known 仍重复）")
		(sm.get("_pending_backpack_ids") as Array).clear()
		(sm.get("_last_known_extra_ids") as Array).clear()

	# 5) 教程"过首战步"查询存在；下一关门槛不再用 should_show_tutorial
	var tpm = root.get_node_or_null("TutorialProgressionManager")
	if tpm == null or not tpm.has_method("is_past_first_battle"):
		fails.append("教程管理器缺 is_past_first_battle")
	var mvp_src := FileAccess.get_file_as_string("res://scenes/ui/mvp_panel.gd")
	if mvp_src.contains("tpm.should_show_tutorial()"):
		fails.append("mvp_panel 仍用全教程门槛")

	# 6) 情报卡：详细情报 Tab + 模式门控
	var CIPC = load("res://scenes/ui/card_info_panel.tscn") as PackedScene
	var panel = CIPC.instantiate()
	root.add_child(panel)
	# --script 模式 _initialize 阶段 _ready 不随 add_child 派发（等首帧）——手动触发一次
	panel._ready()
	var DC = load("res://data/default_cards.gd")
	var t72 = DC.get_card_by_id("cold_t72")
	if t72 == null:
		fails.append("cold_t72 取卡失败")
	else:
		panel.set_panel_mode(0)  # MODE_BACKPACK
		panel.show_card_info(t72)
		if panel._tab_container.is_tab_hidden(0):
			fails.append("背包态情报 Tab 被隐藏")
		if not panel._tab_container.is_tab_hidden(2) or not panel._tab_container.is_tab_hidden(3):
			fails.append("背包态改造/制造 Tab 未隐藏")
		if panel._tab_container.is_tab_hidden(1):
			fails.append("详细情报 Tab 未显示")
		if panel.get_node_or_null("Margin/VBox/TabBar/TabDetail/AffixScroll") == null:
			fails.append("AffixScroll 未迁入 TabDetail")
		if panel.get_node_or_null("Margin/VBox/TabBar/TabInfo/AffixScroll") != null:
			fails.append("TabInfo 下仍残留 AffixScroll")
		panel.set_panel_mode(1)  # MODE_PHASE_INSTRUMENT
		panel.show_card_info(t72)
		if panel._tab_container.is_tab_hidden(2):
			fails.append("相位仪式改造 Tab 未恢复")
	# 战场单位模式：详细情报 Tab 显示
	panel._apply_unit_tab_visibility()
	if panel._tab_container.is_tab_hidden(1):
		fails.append("单位模式详细情报 Tab 未显示")
	panel.queue_free()

	# 7) v38.2 抽屉恒竖排：_ready 即建竖列（8 键全量）；战斗态只过滤键集（5 键），
	#    battle_ended 恢复 8 键——布局不再切换（无横竖互变）
	var BFB = load("res://scenes/ui/bottom_function_bar.tscn") as PackedScene
	var bar = BFB.instantiate()
	root.add_child(bar)
	bar._ready()
	var col = bar.get_node_or_null("Margin/Column")
	if col == null:
		fails.append("竖排列 Column 未创建（恒竖排契约破坏）")
	else:
		var base_cnt := 0
		for c in col.get_children():
			if c.visible:
				base_cnt += 1
		if base_cnt != 8:
			fails.append("常态竖排列键数 != 8（实际 %d）" % base_cnt)
	bar._on_battle_started_layout()
	if bar.get("_battle_mode") != true:
		fails.append("战斗态未置位")
	for key in ["progression", "modification", "evolution"]:
		var b = (bar.get("_btn_map") as Dictionary).get(key)
		if b != null and b.visible:
			fails.append("战斗态 %s 键未隐藏" % key)
	if col != null:
		var battle_cnt := 0
		for c in col.get_children():
			if c.visible:
				battle_cnt += 1
		if battle_cnt != 5:
			fails.append("战斗态竖排列键数 != 5（实际 %d）" % battle_cnt)
	bar._on_battle_ended_layout(true)
	if bar.get("_battle_mode") != false:
		fails.append("battle_ended 未退出战斗态")
	if col != null:
		var restored_cnt := 0
		for c in col.get_children():
			if c.visible:
				restored_cnt += 1
		if restored_cnt != 8:
			fails.append("战后键数 != 8（实际 %d）" % restored_cnt)
	if (bar.get("_btn_map") as Dictionary).get("backpack") == null:
		fails.append("键映射缺失")
	bar.queue_free()

	# 8) 开场演出：任意点击跳过已撤、显式跳过按钮存在
	var tb_src := FileAccess.get_file_as_string("res://scenes/bunker/truck_base.gd")
	if tb_src.contains("点击跳过 ▸"):
		fails.append("truck_base 仍含'点击跳过'提示")
	if not tb_src.contains("跳过 ›"):
		fails.append("truck_base 缺显式跳过按钮")

	# 9) 地图常驻进关按钮
	var wm_src := FileAccess.get_file_as_string("res://scenes/world_map.gd")
	if not wm_src.contains("_on_enter_parked_level_pressed") or not wm_src.contains("进入本关"):
		fails.append("world_map 缺常驻进入按钮")

	# 10) 炮弹缩幅：INDIRECT 基准 0.45 + 弹体宽小于单位基准 58.9px
	var WPV = load("res://scripts/weapon_projectile_vfx.gd")
	if absf(float(WPV.PROJ_TEX_SCALE.get(1, 0.0)) - 0.45) > 0.001:
		fails.append("PROJ_TEX_SCALE[1] != 0.45")
	var quad: Vector2 = WPV.proj_quad_size(1)
	if quad.x > 58.9:
		fails.append("曲射弹体宽 %.1fpx 仍大于单位基准 58.9px" % quad.x)
	var howitzer_scale: float = WPV.indirect_body_scale(WPV.IndirectFlavor.HOWITZER)
	if absf(howitzer_scale - 1.0) > 0.001:
		fails.append("榴弹 flavor 未归一（HOWITZER=%.2f）" % howitzer_scale)

	# 11) v38.2 掉落=散放：随机方向/距离甩出 + 本体随机倾角；无坠落入场（用户否决）
	var gll_src := FileAccess.get_file_as_string("res://scripts/battle/ground_loot_layer.gd")
	if not gll_src.contains("Vector2.from_angle(eject_dir)"):
		fails.append("掉落层缺散放弹出（from_angle）")
	if not gll_src.contains("_body.rotation = randf_range"):
		fails.append("掉落层缺随机倾角（散放感）")
	if gll_src.contains("TRANS_QUAD"):
		fails.append("掉落层仍含坠落入场")
	var landed_pos := gll_src.find("func _on_landed")
	var sfx_pos := gll_src.find("_play_drop_sfx()", landed_pos)
	if landed_pos < 0 or sfx_pos < 0:
		fails.append("掉落音效未在落地链")

	# 12) v38.1：结算再战本关直通键 + 地图动作/图例分离
	if not mvp_src.contains("func _compute_replay_level") or not mvp_src.contains("func _on_replay_pressed") 			or not mvp_src.contains("↻ 再战本关"):
		fails.append("mvp_panel 缺再战本关直通键")
	if not wm_src.contains("MapChromeStack") or not wm_src.contains("MapActions") 			or not wm_src.contains("再战本关"):
		fails.append("world_map 缺动作/图例分离或通关态文案")

	if fails.is_empty():
		print("V38_SMOKE_OK")
	else:
		print("V38_SMOKE_FAIL x%d:" % fails.size())
		for f in fails:
			print("  - ", f)
		print("V38_SMOKE_FAILED")
	quit(0 if fails.is_empty() else 1)
