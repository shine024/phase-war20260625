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
	# v32.3 A1 关卡进入揭幕：战报补战区环境行（BattleEnvEffects 同源描述，与
	# TopHudBar"环境"chip 同一口径；无效果行时静默跳过，最多带 2 条防版面溢出）
	var env_level: int = int(GameManager.current_level) if GameManager != null else 1
	var env_descs: Array = BattleEnvEffects.describe_level_env(env_level)
	if not env_descs.is_empty():
		var env_parts: Array[String] = []
		for d in env_descs:
			env_parts.append(String(d))
			if env_parts.size() >= 2:
				break
		lines.append("战区环境：%s" % " · ".join(env_parts))
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
	# （truck_base._launch_battle / world_map._enter_level_from_popup），此处一次性消费
	# （v32.5：教程态也消费 meta 只是不播——防残留串场到下一场）；挂机推图（afk_mode_manager
	# 复用本函数）不带 meta，不触发。过场只是黑屏上的 UI 层：不切场景、不碰 battle_ended
	# 信号协议。
	var tutorial_active: bool = (
		TutorialProgressionManager != null
		and TutorialProgressionManager.has_method("should_show_tutorial")
		and TutorialProgressionManager.should_show_tutorial()
	)
	var interstitial_played := false
	if Engine.has_meta(SortieInterstitial.META_PENDING):
		Engine.remove_meta(SortieInterstitial.META_PENDING)
		# v32.5 复审修复：教程态也要消费 meta——原守卫只跳过不清除，教程首战
		# （truck_base 出击链写入）残留到下一场非教程战斗会误播一次战报
		if not tutorial_active:
			# v32.3 A4：战报与战备并行——不在这里 await，黑幕战报当遮罩，战场在幕后完成
			# show_battle/go_to_battle（见函数尾等待段）。玩家点击战报可随时跳过。
			SortieInterstitial.present(_sortie_dest_text(), _sortie_report_lines())
			interstitial_played = true
	# 批次3（流程缝合）：直开链入战揭幕——主界面"开始战斗"此前零过渡（面板一关
	# 战场同帧从静到动）。出击链已有 1.5s 战报不叠双层；挂机豁免（缩略图预览不受
	# 打扰）；教程有自己的引导节奏。压暗→亮起 + 「交战开始」横幅，波次刷在亮度
	# 爬坡里（go_to_battle 本就 call_deferred，战斗时序零改动）。
	var unveil: bool = not tutorial_active and not interstitial_played \
		and not (main._afk_manager != null and main._afk_manager.is_running)
	if unveil:
		await _dip_battlefield()
	# 压暗窗口内主场景被切走（回标题/基地竞态）：放弃开战序列
	if main == null or not is_instance_valid(main) or not main.is_inside_tree():
		return
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
	if unveil:
		_unveil_battlefield()
	# v34 C2：首机制关预告——本关首次出现的战术机制（L3 限时/L5 能量枯竭/L8 先手突袭等）
	# 开战节拍里插一句 StageBanner（数据驱动：level_information 首现关推导；重遇见不播）。
	# 教程（自有节奏）与挂机（横幅刷屏）豁免。
	if not tutorial_active and not (main._afk_manager != null and main._afk_manager.is_running):
		var mech_lvl := int(GameManager.current_level) if GameManager != null else 1
		var mech_lines: Array[String] = LevelInformation.get_shared().get_first_seen_mechanic_banner_lines(mech_lvl)
		if not mech_lines.is_empty():
			StageBanner.post_queue(mech_lines)
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
	# v32.3 A4：战报与战备并行——战场已在黑幕后开打，这里只等战报收尾再退出协程
	# （玩家点击/ESC 立即放行）。防挂起：主场景被切走即退出。
	if interstitial_played:
		var tree_ref := main.get_tree()
		while tree_ref != null and SortieInterstitial.is_showing():
			if main == null or not is_instance_valid(main) or not main.is_inside_tree():
				return
			await tree_ref.process_frame

## 延迟进入战斗（由 call_deferred 调用）
func deferred_go_to_battle() -> void:
	if GameManager:
		GameManager.go_to_battle()

## 批次3：入战揭幕——战场压暗 0.1s（await 侧用作节拍闸）
const UNVEIL_DIP_SEC := 0.10
const UNVEIL_DIP_LEVEL := 0.25
const UNVEIL_RISE_SEC := 0.30

func _dip_battlefield() -> void:
	if main.battle_container == null or not (main.battle_container is CanvasItem):
		return
	if DesignTokens.is_motion_reduce():
		return  # 减少动效：跳过压暗节拍（横幅自身也降档）
	var container: CanvasItem = main.battle_container
	var tw := container.create_tween()
	tw.tween_property(container, "modulate:a", UNVEIL_DIP_LEVEL, UNVEIL_DIP_SEC)
	# await 树定时器而非 tw.finished——极端窗口（0.1s 内切场景释放战场）下
	# tween 随节点死亡不发光，tw.finished 会挂起整条开战协程；定时器恒发
	if main.get_tree() != null:
		await main.get_tree().create_timer(UNVEIL_DIP_SEC).timeout


func _unveil_battlefield() -> void:
	# v30.2 R4（设计审查 F-08）：入战揭幕串——[时代仪式(首关·每会话一次)] →
	# [驻守相位师战前台词] → 交战开始。缺数据项静默跳过，普通关仍只播"交战开始"。
	var unveil_seq: Array[String] = []
	var lvl := 1
	if GameManager != null:
		lvl = int(GameManager.current_level)
	unveil_seq.append_array(CampaignNarrative.get_era_rite_lines(lvl))
	unveil_seq.append_array(CampaignNarrative.get_pre_battle_lines(lvl))
	unveil_seq.append("交战开始")
	StageBanner.post_queue(unveil_seq)
	if main.battle_container == null or not (main.battle_container is CanvasItem):
		return
	var container: CanvasItem = main.battle_container
	if DesignTokens.is_motion_reduce():
		container.modulate.a = 1.0
		return
	var tw := container.create_tween()
	tw.tween_property(container, "modulate:a", 1.0, UNVEIL_RISE_SEC)


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
