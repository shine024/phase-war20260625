class_name MainBattleSetup
extends RefCounted
## 战前准备/战斗启动逻辑（从 scenes/main.gd 提取）

## 主场景引用，由 main.gd 在 _ready 中赋值
var main: Control = null

## 处理开始战斗按钮点击
func on_start_battle() -> void:
	run_start_battle_sequence()

## 批次③ Task 1：出征战报目的地行（军语克制体，数值取真实系统）
func _sortie_dest_text() -> String:
	var lvl := 1
	if GameManager != null:
		lvl = int(GameManager.current_level)
	return "第 %d 关 · %s" % [lvl, LevelEras.get_era_name(LevelEras.get_era(lvl))]

## 批次③ Task 1：出征战报正文。卡组张数=绿槽实际装备的战斗卡数（get_loadouts），
## 相位仪具数=已解锁相位仪数；任一取不到（≤0）即降级为不含数值行的两行版，禁止虚构。
func _sortie_report_lines() -> Array[String]:
	var lines: Array[String] = ["车队向目标阵地开进。"]
	var pim: Node = PhaseInstrumentManager
	var card_count := 0
	var instrument_count := 0
	if pim != null:
		if pim.has_method("get_loadouts"):
			card_count = pim.get_loadouts().size()
		instrument_count = pim.unlocked_instrument_ids.size()
	if card_count > 0 and instrument_count > 0:
		lines.append("携行 %d 张卡牌 · 相位仪 %d 具。" % [card_count, instrument_count])
	# v27.15（TODO#8 用户裁决 G1）：相位师关战报加驻守者情报行——名号+威胁度+驻防平台。
	# 取不到数据即静默降级为普通战报（与上文"禁止虚构"口径一致），AFK/教程不带 meta 不受影响。
	var boss_level: int = 1
	if GameManager != null:
		boss_level = int(GameManager.current_level)
	if PhaseMasterGarrison.is_garrison_level(boss_level):
		var master: Dictionary = EnemyPhaseMasters.get_master_by_id(
			PhaseMasterGarrison.get_garrison_master_id(boss_level))
		if not master.is_empty():
			var threat: String = {"easy": "威胁·低", "normal": "威胁·中", "hard": "威胁·高"}.get(
				String(master.get("difficulty", "")), "威胁·评估中")
			lines.append("⚠ 相位师驻守：%s「%s」— %s。" % [
				master.get("name", "?"), master.get("title", ""), threat])
			var plat_names: Array[String] = []
			var equip: Dictionary = master.get("equipment", {})
			for pid in equip.get("platforms", []):
				var plat: Dictionary = EnemyPhaseEquipment.get_war_platform(String(pid))
				if not plat.is_empty():
					plat_names.append(String(plat.get("name", String(pid))))
			if not plat_names.is_empty():
				lines.append("情报：驻防平台 %s。" % "、".join(plat_names))
	return lines

## 执行战斗开始序列
func run_start_battle_sequence() -> void:
	main._play_sfx("button")
	# 批次③ Task 2：清掉上一场可能未消费的撤退标记（防串场——撤退 meta 只该
	# 影响它自己那场的结算面板）
	Engine.remove_meta("battle_retreated")
	# 批次③ Task 1：出征过场拍点（裁决 A2 黑屏战报）。meta 由出征入口写入
	# （truck_base._launch_battle / world_map._enter_level_from_popup），此处一次性消费——
	# 挂机推图（afk_mode_manager 复用本函数）与教程首战不带 meta，不触发。过场只是
	# 黑屏上的 UI 层：不切场景、不碰 battle_ended 信号协议。
	var tutorial_active: bool = (
		TutorialProgressionManager != null
		and TutorialProgressionManager.has_method("should_show_tutorial")
		and TutorialProgressionManager.should_show_tutorial()
	)
	if not tutorial_active and Engine.has_meta(SortieInterstitial.META_PENDING):
		Engine.remove_meta(SortieInterstitial.META_PENDING)
		await SortieInterstitial.present(_sortie_dest_text(), _sortie_report_lines())
	# 关闭所有弹出面板
	main._close_all_overlays()
	if main.bottom_function_bar:
		var phase_master_ui: bool = (
			GameManager
			and GameManager.has_method("is_phase_master_battle")
			and GameManager.is_phase_master_battle()
		)
		if phase_master_ui:
			main.bottom_function_bar.set_start_battle_text("战斗中")
		else:
			main.bottom_function_bar.set_start_battle_text("格子布阵")
	var tree := main.get_tree()
	if tree:
		tree.paused = false
		if main.bottom_function_bar:
			main.bottom_function_bar.set_pause_text("暂停")
	show_battle()
	var battlefield: Node2D = main._get_battlefield()
	if not battlefield:
		if main.bottom_function_bar:
			main.bottom_function_bar.set_start_battle_text("开始战斗")
		return
	# v9.x（P2-7范围B）：PLM 装配法则读取已随法则系统退役移除
	main._blueprints_unlocked_this_battle.clear()
	var pim: Node = PhaseInstrumentManager
	if pim and pim.has_method("get_phase_field_xp_progress"):
		var phase_prog: Dictionary = pim.get_phase_field_xp_progress()
		main._phase_field_xp_before_battle = int(phase_prog.get("xp", 0))
		main._phase_field_level_before_battle = int(phase_prog.get("level", 1))
	if GameManager:
		GameManager.set_battle_scene(battlefield)
		main.call_deferred("_deferred_go_to_battle")

## 延迟进入战斗（由 call_deferred 调用）
func deferred_go_to_battle() -> void:
	if GameManager:
		GameManager.go_to_battle()

## 显示战场、清理上一场残留
func show_battle() -> void:
	if main.battle_container:
		main.battle_container.visible = true
	# 性能优化：只在战斗时持续渲染 SubViewport
	var viewport: Node = main.get_node_or_null("BattleContainer/SubViewportContainer/SubViewport")
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var battlefield: Node2D = main._get_battlefield()
	if battlefield:
		if battlefield.has_method("ensure_phase_driver"):
			battlefield.ensure_phase_driver()
		var pu: Node = battlefield.get_node_or_null("PlayerUnits")
		var eu: Node = battlefield.get_node_or_null("EnemyUnits")
		if pu:
			for c in pu.get_children():
				c.queue_free()
		if eu:
			for c in eu.get_children():
				c.queue_free()
		var enemy_driver: Node = battlefield.get_node_or_null("EnemyPhaseFieldDriver")
		if enemy_driver != null and is_instance_valid(enemy_driver):
			if enemy_driver.has_method("stop_production"):
				enemy_driver.stop_production()
			enemy_driver.queue_free()
