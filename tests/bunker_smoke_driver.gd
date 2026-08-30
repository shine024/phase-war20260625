extends Node
## 余烬要塞 P1 冒烟测试 v21
## 运行：godot --headless --rendering-driver opengl3 --path . res://tests/bunker_smoke_driver.tscn
## （场景模式跑——autoload 全量初始化；不用 --script 模式因其不加载 autoload）
##
## 覆盖：
##   Phase1 BunkerManager 逻辑：懒加载创建 / 调试资源 / 修复启动（资源校验+扣除）/
##     战斗推进（含反应堆电力冻结→解冻）/ 睡觉天数 / 精神值 / 信号发射
##   Phase2 主场景实例化：14 房间节点 / 光点 / HUD / 面板 / 点击→移动→开面板链路
##   Phase5 v22.3 接入收口：食堂每日配给 / 观星台终局抉择 / 信号实时接线

const BunkerRoomDefs = preload("res://data/bunker_room_defs.gd")

var _fail_count := 0

func _ready() -> void:
	print("═════════════════════════════════════════════════")
	print("  余烬要塞 P1+P2 冒烟测试（EMBER BUNKER SMOKE）")
	print("═════════════════════════════════════════════════")
	await _phase1_manager_logic()
	await _phase2_scene_instantiation()
	await _phase3_p2_features()
	await _phase4_p3_features()
	await _phase5_v223_features()
	await _phase6_v224_features()
	_finish()

func _fail(msg: String) -> void:
	_fail_count += 1
	push_error("[FAIL] " + msg)
	print("[FAIL] " + msg)

func _ok(msg: String) -> void:
	print("[ OK ] " + msg)

func _finish() -> void:
	if _fail_count == 0:
		print("═══════════ 全部通过（ALL PASS）═══════════")
		get_tree().quit(0)
	else:
		print("═══════════ 失败 %d 项 ═══════════" % _fail_count)
		get_tree().quit(1)

# ══════════════════ Phase 1：BunkerManager 逻辑 ══════════════════

func _phase1_manager_logic() -> void:
	# 1) 房间定义完整性
	var rooms := BunkerRoomDefs.get_all_rooms()
	if rooms.size() != 15:
		_fail("房间定义应为 15，实际 %d" % rooms.size())
	else:
		_ok("房间定义 15 间齐备")
	var id_set := {}
	for r in rooms:
		var rid: String = r["id"]
		if id_set.has(rid):
			_fail("房间 id 重复: " + rid)
		id_set[rid] = true
		var rect: Rect2 = r["rect"]
		var world: Vector2 = BunkerRoomDefs.GRID["world_size"]
		if rect.position.x < 0.0 or rect.position.y < 0.0 \
				or rect.end.x > world.x or rect.end.y > world.y:
			_fail("房间 %s 矩形越界: %s" % [rid, rect])
		if r.has("via") and BunkerRoomDefs.get_room(str(r["via"])).is_empty():
			_fail("房间 %s 的 via 门连锁指向不存在的房间" % rid)
	if BunkerRoomDefs.get_room("war_room").is_empty():
		_fail("get_room(war_room) 查询失败")
	# 网格几何：14 矩形互不重叠；竖井在两翼之间
	var shaft: Dictionary = BunkerRoomDefs.GRID["shaft"]
	for i in rooms.size():
		for j in range(i + 1, rooms.size()):
			if (rooms[i]["rect"] as Rect2).intersects(rooms[j]["rect"]):
				_fail("房间矩形重叠: %s × %s" % [rooms[i]["id"], rooms[j]["id"]])
	_ok("房间几何：14 矩形在 1280×720 内且互不重叠（竖井 x=%.0f）" % [
		(float(shaft["x1"]) + float(shaft["x2"])) * 0.5])

	# 2) 懒加载创建（root 未就绪时 loader 延迟挂载，get_manager 直接拿实例引用）
	ManagerLazyLoader.ensure_loaded("bunker")
	var mgr: Node = ManagerLazyLoader.get_manager("bunker")
	if mgr == null:
		mgr = get_node_or_null("/root/BunkerManager")
	if mgr == null:
		_fail("BunkerManager 懒加载创建失败")
		return
	_ok("BunkerManager 懒加载创建成功")

	# 3) 初始状态
	if mgr.get_room_state("entry_hall") != BunkerRoomDefs.STATE_ACTIVE \
			or mgr.get_room_state("dormitory") != BunkerRoomDefs.STATE_ACTIVE:
		_fail("入口大厅/宿舍应为初始可用")
	# v22.1：兵棋室改初始可用（基地唯一出击入口，锁死=FTUE 无法进第一关）
	if mgr.get_room_state("war_room") != BunkerRoomDefs.STATE_ACTIVE:
		_fail("兵棋室初始应为可用（v22.1 FTUE 直达出击）")
	# v22.2：相位实验室改初始可用（用户定调：配卡/配相位仪属前期必备，不设修复门槛）
	if mgr.get_room_state("phase_lab") != BunkerRoomDefs.STATE_ACTIVE:
		_fail("相位实验室初始应为可用（v22.2 前期必备）")
	if mgr.get_day() != 1 or absf(mgr.get_sanity() - 100.0) > 0.01:
		_fail("初始天数/精神值应为 1/100")
	_ok("初始状态正确（大厅+宿舍+兵棋室+相位实验室可用，天数1，精神100）")

	# 4) 资源不足拒绝修复（v22.1 起验证对象换仓库——兵棋室已初始点亮）
	var poor: Dictionary = mgr.start_repair("depot")
	if poor.get("ok", true):
		_fail("资源不足时不应放行修复")
	# 5) 调试资源 → 修复放行 + 扣除（三次发放：仓库150+反应堆500合金/200能量 都够）
	mgr.debug_grant_resources()
	mgr.debug_grant_resources()
	mgr.debug_grant_resources()
	var alloy_before: int = BasicResourceManager.get_total(BunkerRoomDefs.res_full_id("alloy"))
	var res: Dictionary = mgr.start_repair("depot")
	if not res.get("ok", false):
		_fail("资源充足时修复应放行: " + str(res.get("reason", "")))
	if mgr.get_room_state("depot") != BunkerRoomDefs.STATE_REPAIRING:
		_fail("修复启动后状态应为修复中")
	var alloy_after: int = BasicResourceManager.get_total(BunkerRoomDefs.res_full_id("alloy"))
	if alloy_after != alloy_before - 150:
		_fail("修复应扣除合金150（前 %d 后 %d）" % [alloy_before, alloy_after])
	_ok("修复经济：资源校验/放行/扣除150合金 全链路正确")

	# 6) 信号发射计数
	var signal_hits := [0]
	var watcher := func(_rid: String, _st: int) -> void: signal_hits[0] += 1
	SignalBus.bunker_room_state_changed.connect(watcher)

	# 7) 战斗推进：depot battles=1 → 一场完成
	var completed: Array = mgr.advance_after_battle(true)
	if not completed.has("depot") or mgr.get_room_state("depot") != BunkerRoomDefs.STATE_ACTIVE:
		_fail("一场战斗后仓库应修复完成: " + str(completed))
	if absf(mgr.get_sanity() - 90.0) > 0.01:
		_fail("胜利应扣精神10（实际 %.0f）" % mgr.get_sanity())
	_ok("战斗推进：仓库 1 场修复完成，精神 100→90")

	# 8) 电力规则：上层（食堂）靠备用电池不冻结，1 场修复完成
	var res2: Dictionary = mgr.start_repair("mess_hall")
	if not res2.get("ok", false):
		_fail("食堂修复启动失败: " + str(res2.get("reason", "")))
	mgr.advance_after_battle(true)
	if mgr.get_room_state("mess_hall") != BunkerRoomDefs.STATE_ACTIVE:
		_fail("食堂（上层·备用电池）一场战斗应修复完成")
	_ok("电力规则：上层食堂靠备用电池供电，不冻结")

	# 9) 深层设施（通讯室 needs_power）在反应堆未上线时冻结
	var res2b: Dictionary = mgr.start_repair("comms")
	if not res2b.get("ok", false):
		_fail("通讯室修复启动失败: " + str(res2b.get("reason", "")))
	if not mgr.is_repair_frozen("comms"):
		_fail("反应堆未上线时通讯室（深层）进度应冻结")
	mgr.advance_after_battle(true)
	if mgr.get_room_progress("comms") > 0.001:
		_fail("冻结状态下通讯室进度不应推进（实际 %.2f）" % mgr.get_room_progress("comms"))
	_ok("反应堆电力：深层通讯室未上线时进度冻结正确")

	# 10) 修复反应堆（3 场）→ 解冻 → 通讯室推进
	var res3: Dictionary = mgr.start_repair("reactor")
	if not res3.get("ok", false):
		_fail("反应堆修复启动失败: " + str(res3.get("reason", "")))
	mgr.advance_after_battle(true)
	mgr.advance_after_battle(true)
	mgr.advance_after_battle(true)
	if mgr.get_room_state("reactor") != BunkerRoomDefs.STATE_ACTIVE:
		_fail("三场战斗后反应堆应上线")
	if not mgr.is_reactor_online():
		_fail("is_reactor_online 应为 true")
	mgr.advance_after_battle(true)
	if absf(mgr.get_room_progress("comms") - 0.5) > 0.01:
		_fail("解冻后通讯室进度应为 0.5（实际 %.2f）" % mgr.get_room_progress("comms"))
	_ok("反应堆 3 场上线 → 通讯室解冻推进至 50%")

	# 10) 终局房间不可修复
	var res4: Dictionary = mgr.start_repair("observatory")
	if res4.get("ok", true):
		_fail("观星台（终局）不应可修复")
	_ok("观星台终局门锁正确")

	# 11) 睡觉（P2 起返回日结算 dict）
	SignalBus.bunker_room_state_changed.disconnect(watcher)
	var day_summary: Dictionary = mgr.sleep()
	if int(day_summary.get("day", 0)) != 2 or mgr.get_day() != 2:
		_fail("睡觉后天数应为 2")
	if signal_hits[0] < 3:
		_fail("信号发射计数异常（%d 次，应≥3）" % signal_hits[0])
	_ok("睡觉：天数 1→2，日结算含 %d 项完工，修复信号累计 %d 次" % [
		(day_summary.get("completed_today", []) as Array).size(), signal_hits[0]])

	# 12) 状态序列化往返
	var snapshot: Dictionary = mgr.get_state_dict()
	var fresh_script: GDScript = load("res://managers/bunker_manager.gd")
	var fresh: Node = fresh_script.new()
	fresh._init_rooms_from_defs()
	fresh.load_state_dict(snapshot)
	if fresh.get_day() != 2 or fresh.get_room_state("reactor") != BunkerRoomDefs.STATE_ACTIVE:
		_fail("状态序列化往返失真")
	_ok("状态序列化往返一致（day=2 / reactor=ACTIVE）")
	fresh.free()

# ══════════════════ Phase 2：主场景实例化 ══════════════════

func _phase2_scene_instantiation() -> void:
	var packed: PackedScene = load("res://scenes/bunker/bunker_main.tscn")
	if packed == null:
		_fail("bunker_main.tscn 加载失败")
		return
	var inst := packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame

	# 1) 核心子结构
	var room_nodes: Dictionary = inst.get("_room_rects")
	if room_nodes.size() != 15:
		_fail("主场景房间矩形应为 15，实际 %d" % room_nodes.size())
	if inst.get("_dot") == null:
		_fail("光点主角未创建")
	if inst.get("_hud") == null or inst.get("_panel") == null:
		_fail("HUD/房间面板未创建")
	_ok("主场景结构：15 房间 + 光点 + HUD + 面板 齐备")

	# 2) 跨场景状态保留（Phase1 修好的反应堆在场景里仍为可用）
	if inst.get("_manager") == null:
		_fail("主场景未取到 BunkerManager")
	else:
		var m: Node = inst.get("_manager")
		if m.get_room_state("reactor") != BunkerRoomDefs.STATE_ACTIVE:
			_fail("BunkerManager 常驻状态跨场景失真（reactor 应 ACTIVE）")
		_ok("BunkerManager 常驻 root：Phase1 状态在场景中保留")

	# 3) 点击→光点移动→面板打开（宿舍：已可用，穿门+电梯路径）
	inst._on_room_clicked("dormitory")
	await get_tree().create_timer(2.2).timeout
	var panel: Node = inst.get("_panel")
	if panel == null or not panel.call("is_open"):
		_fail("点击宿舍后房间面板未打开")
	else:
		var title: String = panel.get("_title_label").text
		if title != "陈末的宿舍":
			_fail("面板标题应为 陈末的宿舍，实际 " + title)
	_ok("交互链路：点击宿舍 → 光点移动 → 面板打开（标题正确）")

	# 4) 跨层路径：从宿舍（地下一排）点反应堆（地下三排）→ 穿门+电梯+隧道
	inst._on_room_clicked("reactor")
	await get_tree().create_timer(2.2).timeout
	if not panel.call("is_open"):
		_fail("跨层点击后面板未打开")
	else:
		_ok("跨层移动：宿舍→反应堆 经电梯井路径完成")
	inst.queue_free()

# ══════════════════ Phase 3：P2 功能 ══════════════════

func _phase3_p2_features() -> void:
	var mgr: Node = ManagerLazyLoader.get_manager("bunker")
	if mgr == null:
		_fail("Phase3：BunkerManager 不可用")
		return

	# 1) 医疗室治疗（先重置到已知基数：精神100）
	mgr.reset_to_defaults()
	mgr.adjust_sanity(-60.0)                      # 100→40
	mgr.debug_grant_resources()
	var nano_pre: int = BasicResourceManager.get_total(BunkerRoomDefs.res_full_id("nano"))
	var treat: Dictionary = mgr.medical_treatment()
	if not treat.get("ok", false):
		_fail("医疗治疗应成功: " + str(treat.get("reason", "")))
	var nano_post: int = BasicResourceManager.get_total(BunkerRoomDefs.res_full_id("nano"))
	if nano_post != nano_pre - 50:
		_fail("治疗应扣纳米50（前 %d 后 %d）" % [nano_pre, nano_post])
	if absf(mgr.get_sanity() - 80.0) > 0.01:
		_fail("治疗后精神应 80（实际 %.0f）" % mgr.get_sanity())
	mgr.adjust_sanity(20.0)                       # 拉满
	var treat_full: Dictionary = mgr.medical_treatment()
	if treat_full.get("ok", true):
		_fail("精神满时应拒绝治疗")
	_ok("医疗室：扣50纳米+40精神 / 满精神拒绝")

	# 2) 存档往返（SaveManager 段协议：save_state/load_state/reset_to_defaults）
	mgr.adjust_sanity(-30.0)
	var snap: Dictionary = mgr.save_state()
	if not snap.has("day") or not snap.has("rooms") or not snap.has("sanity"):
		_fail("save_state 缺少必需字段: " + str(snap.keys()))
	mgr.reset_to_defaults()
	if mgr.get_day() != 1 or absf(mgr.get_sanity() - 100.0) > 0.01 \
			or mgr.get_room_state("reactor") != BunkerRoomDefs.STATE_LOCKED:
		_fail("reset_to_defaults 未回到初始态")
	mgr.load_state(snap)
	if mgr.get_day() != int(snap["day"]) or absf(mgr.get_sanity() - float(snap["sanity"])) > 0.01:
		_fail("load_state 未恢复快照")
	mgr.sleep()                                   # day+1，随后用空字典重置验证新游戏语义
	mgr.load_state({})
	if mgr.get_day() != 1:
		_fail("load_state({}) 应触发全重置（新游戏语义）")
	# SaveManager 通用收集管道探针（不写盘，不触发 save_game 节流/真实存档污染）
	var collect_probe: Dictionary = {}
	SaveManager._collect_manager_state(collect_probe, "/root/BunkerManager", "bunker_state")
	if not collect_probe.has("bunker_state"):
		_fail("SaveManager 收集管道未产出 bunker_state 段")
	_ok("存档协议：save_state/reset_to_defaults/load_state/空字典重置 + 收集管道探针")

	# 3) 日结算面板
	var bunker_packed: PackedScene = load("res://scenes/bunker/bunker_main.tscn")
	var inst: Control = bunker_packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var summary_ui: Control = inst.get("_day_summary")
	if summary_ui == null:
		_fail("日结算面板未创建")
	else:
		var fake := {"day": 9, "sanity_before": 40.0, "sanity_after": 60.0,
			"completed_today": ["war_room", "reactor"], "stage": 2}
		summary_ui.call("open", fake)
		if not summary_ui.visible:
			_fail("日结算面板 open 后应可见")
		summary_ui.call("close")
		if summary_ui.visible:
			_fail("日结算面板 close 后应隐藏")
	_ok("日结算面板：open/close 正常")

	# 4) 嵌入面板（7 个现有面板场景懒挂载；v22.3：afk 死键已移除，换 quest）
	var panel_ids := ["backpack", "modification", "evolution", "growth", "store", "faction", "quest"]
	for pid in panel_ids:
		inst._open_embedded_panel(pid)
		await get_tree().process_frame
		if not inst._embed_wrappers.has(pid):
			_fail("嵌入面板 %s 懒挂载失败" % pid)
		else:
			var w: Control = inst._embed_wrappers[pid]["wrapper"]
			if not w.visible:
				_fail("嵌入面板 %s 打开后应可见" % pid)
			w.visible = false
	_ok("嵌入面板 ×7：宿舍=背包 / 工坊=改造·进化·成长 / 通讯=商店·势力 / 兵棋=任务")

	# 5) 精神归零强制回宿舍（延后帧触发 _check_sanity_zero）
	mgr.reset_to_defaults()
	mgr.adjust_sanity(-100.0)
	var inst2: Control = bunker_packed.instantiate()
	add_child(inst2)
	await get_tree().create_timer(0.6).timeout
	var panel2: Control = inst2.get("_panel")
	var dorm_center: Vector2 = (inst2.get("_room_rects") as Dictionary)["dormitory"].get_center()
	var dot2: Node2D = inst2.get("_dot")
	if dot2 == null or dot2.position.distance_to(dorm_center) > 1.0:
		_fail("精神归零后光点应瞬移至宿舍")
	if panel2 == null or not panel2.call("is_open"):
		_fail("精神归零后宿舍面板应自动打开")
	_ok("精神归零：光点瘫回宿舍 + 面板自动弹出")
	inst2.queue_free()
	inst.queue_free()

# ══════════════════ Phase 4：P3 叙事功能 ══════════════════

func _phase4_p3_features() -> void:
	var HeroArchiveTexts = preload("res://data/hero_archive_texts.gd")
	var mgr: Node = ManagerLazyLoader.get_manager("bunker")
	if mgr == null:
		_fail("Phase4：BunkerManager 不可用")
		return
	mgr.reset_to_defaults()

	# 1) 文案层：30 位全 bespoke / 时代与系别显示
	var t1: Dictionary = HeroArchiveTexts.get_texts("enemy_master_001", "steel")
	if not t1.get("bespoke", false) or str(t1.get("deed", "")).is_empty() \
			or str(t1.get("last_words", "")).is_empty():
		_fail("001 应有 bespoke 文案")
	# 2026-08-26 人物志补齐：011-030 已全部 bespoke，逐一断言
	for i in range(1, 31):
		var tx: Dictionary = HeroArchiveTexts.get_texts(
			"enemy_master_%03d" % i, "steel")
		if not tx.get("bespoke", false) or str(tx.get("deed", "")).is_empty() \
				or str(tx.get("last_words", "")).is_empty():
			_fail("%03d 应有 bespoke 文案（人物志补齐批次）" % i)
	if HeroArchiveTexts.era_display("enemy_master_007") != "二战回响" \
			or HeroArchiveTexts.era_display("enemy_master_025") != "近未来回响":
		_fail("era_display 时代映射错误")
	if HeroArchiveTexts.faction_display("void").is_empty():
		_fail("faction_display 空")
	_ok("文案层：bespoke×30 全量 + 时代/系别映射")

	# 2) 碎片记录：去重 + 信号 + 计数
	var frag_hits := [0]
	var fw := func(_mid: String) -> void: frag_hits[0] += 1
	SignalBus.hero_archive_unlocked.connect(fw)
	if not mgr.record_hero_fragment("enemy_master_005"):
		_fail("首次记录碎片应返回 true")
	if mgr.record_hero_fragment("enemy_master_005"):
		_fail("重复记录碎片应返回 false（去重）")
	if not mgr.has_hero_fragment("enemy_master_005") or mgr.get_hero_fragment_count() != 1:
		_fail("碎片计数错误")
	SignalBus.hero_archive_unlocked.disconnect(fw)
	_ok("碎片记录：入账/去重/信号（%d 次）" % frag_hits[0])

	# 3) 战斗掉落链路（mock GameManager 相位师状态，直调 _on_battle_ended 不发全局信号）
	GameManager.set("_is_phase_master_battle", true)
	GameManager.set("_current_phase_master", {"id": "enemy_master_007", "name": "雷神之子·索尔"})
	mgr._on_battle_ended(true)
	GameManager.set("_is_phase_master_battle", false)
	GameManager.set("_current_phase_master", {})
	if not mgr.has_hero_fragment("enemy_master_007"):
		_fail("相位师战斗胜利应掉落碎片")
	# 非相位师战斗不掉
	mgr._on_battle_ended(true)
	if mgr.get_hero_fragment_count() != 2:
		_fail("普通战斗不应掉碎片（实际 %d）" % mgr.get_hero_fragment_count())
	_ok("战斗掉落链路：相位师胜利掉碎片 / 普通战斗不掉")

	# 4) 荣誉室碎片门槛（<10 拒绝，补齐放行）
	mgr.debug_grant_resources()
	var gate_res: Dictionary = mgr.start_repair("honor_hall")
	if gate_res.get("ok", true):
		_fail("荣誉室碎片不足应拒绝修复")
	for mid in ["enemy_master_001", "enemy_master_002", "enemy_master_003",
			"enemy_master_004", "enemy_master_006", "enemy_master_008",
			"enemy_master_009", "enemy_master_010"]:
		mgr.record_hero_fragment(mid)
	var gate_ok: Dictionary = mgr.start_repair("honor_hall")
	if not gate_ok.get("ok", false):
		_fail("碎片补齐后荣誉室应放行: " + str(gate_ok.get("reason", "")))
	_ok("荣誉室门槛：10 碎片前拒绝 / 补齐后放行")

	# 5) 情感阶段切换消费
	if mgr.consume_stage_transition() != 0:
		_fail("初始阶段无跃迁应返回 0")
	mgr.sleep()  # day2（仍在阶段1）
	var jumped: int = 0
	for i in range(50):
		mgr.sleep()
		jumped = mgr.consume_stage_transition()
		if jumped == 2:
			break
	if jumped != 2:
		_fail("天数跨过 16 应触发阶段 1→2 跃迁")
	if mgr.consume_stage_transition() != 0:
		_fail("同一跃迁只应消费一次")
	_ok("情感阶段：天数驱动 1→2 跃迁且只播报一次")

	# 6) 观星台条件接口
	var cond: Dictionary = mgr.is_observatory_unlockable()
	if cond.get("ok", true) or (cond.get("reasons", []) as Array).is_empty():
		_fail("观星台条件未满足应返回原因列表")
	_ok("观星台条件接口：返回 %d 条未满足原因" % (cond.get("reasons", []) as Array).size())

	# 7) 档案面板 + 纪念墙（嵌入挂载 + 打开）
	var packed: PackedScene = load("res://scenes/bunker/bunker_main.tscn")
	var inst: Control = packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	inst._open_embedded_panel("hero_archive")
	await get_tree().process_frame
	if not inst._embed_wrappers.has("hero_archive") \
			or not (inst._embed_wrappers["hero_archive"]["wrapper"] as Control).visible:
		_fail("英雄档案面板嵌入打开失败")
	inst._open_embedded_panel("memorial")
	await get_tree().process_frame
	var mw: Control = inst._embed_wrappers.get("memorial", {}).get("panel")
	if mw == null:
		_fail("纪念墙嵌入失败")
	else:
		var lamp_count: int = (mw.get("_lamp_masters") as Array).size()
		if lamp_count != 30:
			_fail("纪念墙灯阵应为 30 盏（实际 %d）" % lamp_count)
		mw.call("refresh")
		await get_tree().process_frame
	_ok("档案面板 + 纪念墙：嵌入挂载打开正常（碎片 %d/30）" % mgr.get_hero_fragment_count())

	# 8) 阶段字幕演出（主动制造未播报的跃迁）
	mgr.set("_narrative_stage", 3)
	inst._check_stage_transition()
	await get_tree().create_timer(1.5).timeout
	var stage_label: Label = inst.get("_stage_label")
	if stage_label == null or stage_label.text.is_empty() or stage_label.modulate.a <= 0.05:
		_fail("阶段字幕演出未生效")
	_ok("阶段切换字幕：全屏渐黑 + 字幕浮现正常")

	inst.queue_free()

# ══════════════════ Phase 5：v22.3 接入收口 ══════════════════

func _phase5_v223_features() -> void:
	var mgr: Node = ManagerLazyLoader.get_manager("bunker")
	if mgr == null:
		_fail("Phase5：BunkerManager 不可用")
		return
	mgr.reset_to_defaults()

	# 1) 每日配给：未修复拒绝 → 修复后发放 → 同日去重 → 睡觉重置 → 序列化
	var locked_ration: Dictionary = mgr.claim_daily_ration()
	if locked_ration.get("ok", true):
		_fail("食堂未修复时配给应拒绝")
	mgr.debug_grant_resources()
	mgr.start_repair("mess_hall")
	mgr.advance_after_battle(true)
	if mgr.get_room_state("mess_hall") != BunkerRoomDefs.STATE_ACTIVE:
		_fail("Phase5 前置失败：食堂应已修复")
		return
	var nano_pre: int = BasicResourceManager.get_total(BunkerRoomDefs.res_full_id("nano"))
	var alloy_pre: int = BasicResourceManager.get_total(BunkerRoomDefs.res_full_id("alloy"))
	var ration: Dictionary = mgr.claim_daily_ration()
	if not ration.get("ok", false):
		_fail("食堂修复后配给应成功: " + str(ration.get("reason", "")))
	if BasicResourceManager.get_total(BunkerRoomDefs.res_full_id("nano")) != nano_pre + 120 \
			or BasicResourceManager.get_total(BunkerRoomDefs.res_full_id("alloy")) != alloy_pre + 40:
		_fail("配给应发纳米120+合金40")
	if not mgr.is_ration_claimed_today():
		_fail("领取后 is_ration_claimed_today 应为 true")
	if mgr.claim_daily_ration().get("ok", true):
		_fail("同一天二次领取应拒绝")
	mgr.sleep()   # day+1 → 配给重置
	if mgr.is_ration_claimed_today():
		_fail("睡觉推进天数后配给应可再领")
	if not mgr.claim_daily_ration().get("ok", false):
		_fail("第二天配给应成功")
	_ok("每日配给：未修复拒绝 / 发放120+40 / 同日去重 / 睡觉重置")

	# 2) 观星台终局：未知 id 拒绝 / 抉择持久化 / 不可反悔 / 序列化 / 重置
	if mgr.choose_ending("nonexistent").get("ok", true):
		_fail("未知结局 id 应拒绝")
	if not mgr.choose_ending("rewrite").get("ok", false):
		_fail("首次抉择应成功")
	var chosen: Dictionary = mgr.get_chosen_ending()
	if str(chosen.get("id", "")) != "rewrite" or str(chosen.get("emblem", "")).is_empty():
		_fail("get_chosen_ending 应含 id/emblem: " + str(chosen))
	if mgr.choose_ending("keep").get("ok", true):
		_fail("结局已定后二次抉择应拒绝")
	var snap5: Dictionary = mgr.save_state()
	if not snap5.has("ending_id") or not snap5.has("ration_day"):
		_fail("save_state 应含 v22.3 新字段 ending_id/ration_day")
	var fresh5: Node = (load("res://managers/bunker_manager.gd") as GDScript).new()
	fresh5._init_rooms_from_defs()
	fresh5.load_state_dict(snap5)
	if str(fresh5.get_chosen_ending().get("id", "")) != "rewrite" or not fresh5.is_ration_claimed_today():
		_fail("v22.3 新字段序列化往返失真")
	fresh5.free()
	mgr.reset_to_defaults()
	if not mgr.get_chosen_ending().is_empty() or mgr.is_ration_claimed_today():
		_fail("reset_to_defaults 应清空结局与配给记录")
	_ok("观星台终局：抉择 / 不可反悔 / 序列化 / 重置 全链路")

	# 3) 终局面板：intro → choice(三卡) → confirm → resolution(徽记) 演出流
	var end_panel: Control = (load("res://scenes/bunker/ui/observatory_ending_panel.gd") as GDScript).new()
	add_child(end_panel)
	await get_tree().process_frame
	var content: VBoxContainer = end_panel.get("_content")
	if content == null or content.get_child_count() == 0:
		_fail("终局面板内容未构建")
		return
	var intro_seen := false
	for c in content.get_children():
		if c is Label and str((c as Label).text).contains("门开了"):
			intro_seen = true
	if not intro_seen:
		_fail("未抉择时应显示导语页")
	end_panel.call("_show_choice")
	await get_tree().process_frame
	var card_count := -1
	for c in (end_panel.get("_content") as VBoxContainer).get_children():
		if c is HBoxContainer:
			card_count = (c as HBoxContainer).get_child_count()
	if card_count != 3:
		_fail("三选一应有三张卡（实际 %d）" % card_count)
	end_panel.call("_show_confirm", "keep")
	end_panel.call("_on_confirm_pressed")
	await get_tree().process_frame
	if str(mgr.get_chosen_ending().get("id", "")) != "keep":
		_fail("确认后应记录结局 keep")
	var emblem_seen := false
	for c in (end_panel.get("_content") as VBoxContainer).get_children():
		if c is Label and str((c as Label).text).contains("徽记"):
			emblem_seen = true
	if not emblem_seen:
		_fail("结算页应显示结局徽记")
	_ok("终局面板：导语 → 三选一 → 确认 → 徽记结算 演出流正常")
	end_panel.queue_free()

	# 4) 信号接线（v22.3：两信号此前全项目零监听）+ 碎片解锁实时点亮纪念墙
	var packed: PackedScene = load("res://scenes/bunker/bunker_main.tscn")
	var inst: Control = packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	if not SignalBus.bunker_day_ended.is_connected(inst._on_bunker_day_ended):
		_fail("bunker_day_ended 应已接线到 bunker_main")
	if not SignalBus.hero_archive_unlocked.is_connected(inst._on_hero_archive_unlocked):
		_fail("hero_archive_unlocked 应已接线到 bunker_main")
	inst._open_embedded_panel("memorial")
	await get_tree().process_frame
	var memorial: Control = (inst.get("_embed_wrappers") as Dictionary).get("memorial", {}).get("panel")
	if memorial == null:
		_fail("纪念墙嵌入失败（信号实时刷新前置）")
	else:
		mgr.record_hero_fragment("enemy_master_011")
		await get_tree().process_frame
		var count_text: String = str((memorial.get("_count_label") as Label).text)
		if not count_text.contains("1 / 30"):
			_fail("信号驱动刷新后纪念墙计数应实时为 1/30（实际 %s）" % count_text)
	_ok("信号接线：day_ended/hero_archive_unlocked → bunker_main；碎片解锁实时点亮纪念墙")
	inst.queue_free()

# ══════════════════ Phase 6：v22.4 循环闭合 ══════════════════

func _phase6_v224_features() -> void:
	var mgr: Node = ManagerLazyLoader.get_manager("bunker")
	if mgr == null:
		_fail("Phase6：BunkerManager 不可用")
		return

	# 1) 遭遇选人"未收集优先"（P0-1 碎片可达性核心）
	var cands: Array = [
		{"id": "a", "level": 10},
		{"id": "b", "level": 26},
		{"id": "c", "level": 25},
	]
	var pick_none: Dictionary = GameManager._pick_master_candidate(cands, 24, [])
	if str(pick_none.get("id", "")) != "c":
		_fail("全部未收集时应取距目标最近者（期望 c，实际 %s）" % str(pick_none.get("id", "")))
	var pick_bias: Dictionary = GameManager._pick_master_candidate(cands, 24, ["a", "c"])
	if str(pick_bias.get("id", "")) != "b":
		_fail("未收集优先应压过等级距离（期望 b，实际 %s）" % str(pick_bias.get("id", "")))
	if not GameManager._pick_master_candidate([], 24, []).is_empty():
		_fail("空候选应返回空字典")
	_ok("遭遇选人：未收集优先压过等级距离 / 空候选兜底")

	# 2) 精神档位掉落惩罚（P1-4）
	mgr.reset_to_defaults()
	if absf(mgr.get_drop_reward_multiplier() - 1.0) > 0.001:
		_fail("精神 100 惩罚系数应为 1.0")
	mgr.adjust_sanity(-60.0)   # 100→40（tier1）
	if absf(mgr.get_drop_reward_multiplier() - 0.9) > 0.001:
		_fail("精神 40 惩罚系数应为 0.9（实际 %.2f）" % mgr.get_drop_reward_multiplier())
	mgr.adjust_sanity(-20.0)   # →20（tier2）
	if absf(mgr.get_drop_reward_multiplier() - 0.75) > 0.001:
		_fail("精神 20 惩罚系数应为 0.75（实际 %.2f）" % mgr.get_drop_reward_multiplier())
	_ok("精神档位惩罚：1.0 / 0.9 / 0.75 三档正确")

	# 3) 今日完工列表（P0-2 结算面板数据源）
	mgr.reset_to_defaults()
	mgr.debug_grant_resources()
	mgr.start_repair("depot")
	mgr.advance_after_battle(true)
	if not (mgr.get_completed_today() as Array).has("depot"):
		_fail("完工房间应出现在 get_completed_today")
	_ok("今日完工列表：完工房间可查询")

	# 4) 首次引导旗标持久化（P1-5）
	if mgr.is_intro_shown():
		_fail("重置后引导旗标应为 false")
	mgr.mark_intro_shown()
	if not mgr.is_intro_shown() or not bool(mgr.save_state().get("intro_shown", false)):
		_fail("引导旗标应可标记并随存档持久化")
	mgr.reset_to_defaults()
	if mgr.is_intro_shown():
		_fail("重置应清空引导旗标")
	_ok("首次引导旗标：标记/存档/重置 全链路")

	# 5) 每日任务领取链路（P0-3：此前 claim_task_reward 全项目零调用）
	ManagerLazyLoader.ensure_loaded("daily_task")
	var dtm: Node = get_node_or_null("/root/DailyTaskManager")
	if dtm == null:
		_fail("DailyTaskManager 懒加载失败")
		return
	dtm.force_refresh()
	var tasks: Array = dtm.get_daily_tasks()
	if tasks.size() != 7:
		_fail("每日任务应生成 7 个（实际 %d）" % tasks.size())
	dtm.update_task_progress(DailyTaskManager.TaskType.BATTLE_VICTORY, 99)
	var claimable_id := ""
	for t in dtm.get_daily_tasks():
		if int(t.get("type", -1)) == DailyTaskManager.TaskType.BATTLE_VICTORY \
				and t.get("completed", false) and not t.get("claimed", false):
			claimable_id = str(t.get("id", ""))
			break
	if claimable_id.is_empty():
		_fail("推进 99 场胜利后应存在可领取的每日任务")
	else:
		var nano_pre6: int = BasicResourceManager.get_total(BunkerRoomDefs.res_full_id("nano"))
		if not dtm.claim_task_reward(claimable_id):
			_fail("claim_task_reward 应成功")
		if dtm.claim_task_reward(claimable_id):
			_fail("重复领取应被拒绝")
		var claimed_seen := false
		for t in dtm.get_daily_tasks():
			if str(t.get("id", "")) == claimable_id and t.get("claimed", false):
				claimed_seen = true
		if not claimed_seen:
			_fail("领取后任务应标记 claimed")
		if BasicResourceManager.get_total(BunkerRoomDefs.res_full_id("nano")) <= nano_pre6:
			_fail("领取奖励应发放纳米材料（奖励池每档必含）")
	_ok("每日任务：生成 7 个 / 进度完成 / 领取发奖 / 重复拒绝")

	# 6) quest_panel 日常 Tab 每日挑战区渲染（P0-3 UI 接入）
	var qp: PackedScene = load("res://scenes/ui/quest_panel.tscn")
	var qinst: Control = qp.instantiate()
	add_child(qinst)
	await get_tree().process_frame
	qinst.call("_refresh_list")
	await get_tree().process_frame
	var dl: VBoxContainer = qinst.get("daily_list")
	var header_seen := false
	if dl == null or dl.get_child_count() == 0:
		_fail("quest_panel 日常列表未构建")
	else:
		for c in dl.get_children():
			if c is Label and str((c as Label).text).contains("每日挑战"):
				header_seen = true
				break
		if not header_seen:
			_fail("日常 Tab 应包含'每日挑战'区块标题")
		elif dl.get_child_count() < 8:
			_fail("每日挑战区应含标题 + 7 任务行（实际 %d 行）" % dl.get_child_count())
	_ok("quest_panel：每日挑战区（标题 + 7 任务行）渲染正常")
	qinst.queue_free()
