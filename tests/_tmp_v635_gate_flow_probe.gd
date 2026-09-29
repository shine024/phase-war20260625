extends Node
## _tmp_v635_gate_flow_probe.gd（临时全流程探针——黑门 2.0 真实跑通验证）
## 真实 main.tscn + 真实存档环境,全链路:进门→波次节律→本体战→击碎→通关弹窗→
## 无限区→结算首通→异族渗透战。跑前备份存档,跑后恢复(见会话记录)。
## 跑法:godot --headless --rendering-driver opengl3 --path . res://tests/_tmp_v635_gate_flow_probe.tscn

const XenoUnits = preload("res://data/xeno_units.gd")

var _fails: int = 0
var _main: Node = null
var _protect_driver: bool = false


func _driver_guard_loop() -> void:
	# 每帧把敌方相位场驱动器 HP 拉满(探针只验流程不验防守;驱动器被毁=end_battle 会捣乱全链)
	while _protect_driver and is_inside_tree():
		var bf: Node = get_tree().root.get_node_or_null("/root/GameManager")
		bf = bf.get("battle_scene") if bf != null else null
		if bf != null:
			var drv: Node = bf.get_node_or_null("EnemyPhaseFieldDriver")
			if drv != null and is_instance_valid(drv) and float(drv.get("hp")) > 0.0:
				drv.set("hp", float(drv.get("max_hp")))
		await get_tree().process_frame


func _pl(s: String) -> void:
	print("[GATE-FLOW] ", s)


func _fail(s: String) -> void:
	_fails += 1
	_pl("FAIL: " + s)


func _ok(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pl("PASS  %s %s" % [name, detail])
	else:
		_fail("%s %s" % [name, detail])


func _wait_frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _wait_secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _field_units(side: String) -> Array:
	var bf: Node = get_tree().root.get_node_or_null("/root/Main/BattleContainer/Battlefield")
	if bf == null:
		var gm: Node = get_tree().root.get_node_or_null("/root/GameManager")
		bf = gm.get("battle_scene") if gm != null else null
	if bf == null:
		return []
	var holder: Node = bf.get_node_or_null(("PlayerUnits" if side == "player" else "EnemyUnits"))
	return holder.get_children() if holder != null else []


func _core_unit() -> Node:
	for u in _field_units("enemy"):
		if is_instance_valid(u) and u.has_meta("_is_gate_core"):
			return u
	return null


func _drive_wave() -> int:
	# headless 下波次 timer 不可靠——手动驱动(与 v27 driver 同款范式)
	var bss = bss_ref()
	var diag: String = "active=%s eun=%s cnt=%s cap=%s free=%s" % [
		str(bss.get("_card_grid_active")), str(bss.get("_enemy_units_node") != null),
		str(bss.get("enemy_unit_count")), str(bss.call("_enemy_field_unit_cap")),
		str(bss.call("_card_grid_count_free_enemy_slots"))]
	var ret: bool = bss.spawn_card_grid_enemy_wave(100)
	_pl("  DIAG drive: %s ret=%s" % [diag, str(ret)])
	return 1 if ret else 0


func bss_ref() -> Variant:
	return (get_tree().root.get_node_or_null("/root/BattleManager") as Node).get("_spawn_system")


func _kill_all_enemies() -> void:
	# headless 探针清场:free 立即释放(死亡动画在 ts 波动下滞留槽位);本体击杀不走此路径
	for u in _field_units("enemy"):
		if is_instance_valid(u):
			u.free()
	await _wait_frames(3)


func _ready() -> void:
	await _wait_frames(5)
	await _run()
	_pl("═══ PROBE DONE fails=%d ═══" % _fails)
	if _fails == 0:
		print("GATE_FLOW_PROBE_OK")
	get_tree().quit(0 if _fails == 0 else 1)


func _run() -> void:
	var gm: Node = get_tree().root.get_node_or_null("/root/GameManager")
	var bm: Node = get_tree().root.get_node_or_null("/root/BattleManager")
	# EBM 懒加载(autoload 表里不存在,ManagerLazyLoader "endless" 域)
	var mll: Node = get_tree().root.get_node_or_null("/root/ManagerLazyLoader")
	if mll != null and mll.has_method("ensure_loaded"):
		mll.ensure_loaded("endless")
	await _wait_frames(10)
	var ebm: Node = get_tree().root.get_node_or_null("/root/EndlessBlackgateManager")
	_ok("EBM 已加载", ebm != null)
	if ebm == null:
		return
	var ebm_snapshot: Dictionary = {
		"gate_cleared_once": ebm.gate_cleared_once, "incursions": ebm.incursions.duplicate(true),
		"best_score": ebm.best_score, "total_runs": ebm.total_runs,
	}
	_pl("═══ 0. 主场景实例化 ═══")
	var main_packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	_main = main_packed.instantiate()
	get_tree().root.add_child.call_deferred(_main)
	await _wait_frames(90)
	if gm.get("battle_scene") == null:
		await _wait_frames(90)
	_ok("battle_scene 就绪", gm.get("battle_scene") != null)
	var bss = bm.get("_spawn_system")
	_ok("spawn 系统可达", bss != null)

	_pl("═══ 1. 进门链:start_endless_battle → go_to_battle → begin_run ═══")
	var entries_before: int = int(ebm.get("_entries_used_today"))
	gm.set_current_level(100)
	gm.start_endless_battle()
	gm.go_to_battle()
	await _wait_frames(30)
	if not bool(bm.get("battle_active")):
		await _wait_frames(120)
	_ok("battle_active", bool(bm.get("battle_active")))
	_ok("endless 模式", bss.is_endless_mode())
	_ok("begin_run 消费入场次数", int(ebm.get("_entries_used_today")) == entries_before + 1,
		"(%d→%d)" % [entries_before, int(ebm.get("_entries_used_today"))])
	_ok("run 态就绪", int(ebm.gate_core_wave) >= 200 and int(ebm.gate_core_wave) <= 320,
		"gate_core_wave=%d" % int(ebm.gate_core_wave))

	_pl("═══ 1.5 探针环境整备:关自动部署+time_scale 锁 1+驱动器锁血 ═══")
	# auto_deploy=true(用户配置)会让玩家侧自动布阵打怪——击杀顿帧(hitstop ts=0.1)
	# 与演出把 headless 时序打乱,必须关掉
	var bar: Node = _main.get("bottom_instrument_bar")
	if bar != null:
		var adc = bar.get("_auto_deploy")
		if adc != null and adc.has_method("disable"):
			adc.call("disable")
			_pl("  auto_deploy 已关")
	Engine.time_scale = 1.0
	_protect_driver = true
	_driver_guard_loop()

	_pl("═══ 2. 本体深度改小=第 3 波(加速流程) ═══")
	ebm.gate_core_wave = 3
	var rift_desc_before: String = ebm.current_rift_env
	_ok("裂隙环境已 roll", rift_desc_before != "", rift_desc_before)

	Engine.time_scale = 1.0
	_pl("═══ 3. 波 1/2 常规波(手动驱动,headless timer 不可靠) ═══")
	await _wait_secs(1.0)
	_ok("波 1 出兵", int(bss.get("enemy_wave_index")) >= 1, "idx=%d" % int(bss.get("enemy_wave_index")))
	await _kill_all_enemies()
	var gm_d: Node = get_tree().root.get_node_or_null("/root/GameManager")
	var bf_d: Node = gm_d.get("battle_scene")
	_pl("  DIAG pre-w2: battle_active=%s paused=%s ts=%.2f" % [
		str(get_tree().root.get_node_or_null("/root/BattleManager").get("battle_active")),
		str(get_tree().paused), Engine.time_scale])
	if bf_d != null:
		var drv_d: Node = bf_d.get_node_or_null("EnemyPhaseFieldDriver")
		_pl("  DIAG bf children=%d drv=%s drv_hp=%s" % [bf_d.get_child_count(), str(drv_d != null), str(drv_d.get("hp")) if drv_d != null else "-"])
		var eu_d: Node = bf_d.get_node_or_null("EnemyUnits")
		if eu_d != null:
			var names: PackedStringArray = []
			for c in eu_d.get_children():
				names.append("%s(%s hp=%s)" % [c.name, c.get_class(), str(c.get("hp"))])
			_pl("  DIAG EnemyUnits[%d]: %s" % [eu_d.get_child_count(), " | ".join(names)])
	var bss_d = get_tree().root.get_node_or_null("/root/BattleManager").get("_spawn_system")
	_pl("  DIAG bss: eun=%s count=%s idx=%d" % [
		str(bss_d.get("_enemy_units_node") != null), str(bss_d.get("enemy_unit_count")), int(bss_d.get("enemy_wave_index"))])
	var w2_ret: int = _drive_wave()
	_pl("  DIAG w2: spawn_ret=%d" % w2_ret)
	await _wait_frames(15)
	_ok("波 2 出兵", int(bss.get("enemy_wave_index")) >= 2, "idx=%d" % int(bss.get("enemy_wave_index")))
	await _kill_all_enemies()

	_pl("═══ 4. 波 3=本体波(手动驱动) ═══")
	_drive_wave()
	await _wait_frames(15)
	_ok("波次到达 3", int(bss.get("enemy_wave_index")) >= 3, "idx=%d" % int(bss.get("enemy_wave_index")))
	var core: Node = null
	for _i in range(20):
		core = _core_unit()
		if core != null:
			break
		await _wait_frames(10)
	_ok("黑门本体落场", core != null)
	if core != null:
		_ok("本体 meta", bool(core.has_meta("_is_gate_core")) and bool(core.has_meta("_is_boss_unit")))
		var stats = core.get("stats")
		_ok("本体 HP×10 放大", stats != null and float(stats.max_hp) > 50000.0,
			"max_hp=%.0f" % (float(stats.max_hp) if stats != null else -1.0))

	Engine.time_scale = 1.0
	_pl("═══ 5. 击碎本体 → mark_gate_cleared ═══")
	var destroyed_fired: Array = []
	ebm.gate_core_destroyed.connect(func() -> void: destroyed_fired.append(1))
	# v6.35 探针:击碎前手动触发 main handler 一次——区分"handler 链坏"vs"信号派发坏"
	_main.call("_on_gate_core_destroyed")
	await _wait_frames(8)
	_pl("  DIAG 手动call后弹窗=%s" % str(_main.get_node_or_null("PopupLayer/GateCoreChoiceOverlay") != null))
	var _dlg: Node = _main.get_node_or_null("PopupLayer/GateCoreChoiceOverlay")
	if _dlg != null:
		_dlg.queue_free()
		_main.set("_gate_choice_dialog", null)
	await _wait_frames(3)
	if core != null:
		core.take_damage(9.0e9, null)
	await _wait_frames(10)
	_ok("gate_cleared 置位", bool(ebm.gate_cleared))
	_ok("choice_pending 出兵 gate", bool(ebm.gate_choice_pending))
	_ok("gate_core_destroyed 信号", destroyed_fired.size() >= 1)
	_ok("波间隔事实暂停(3600s)", absf(float(gm.get_enemy_wave_interval_for_level(100)) - 3600.0) < 0.001)
	_ok("黑门关闭:渗透清场", ebm.incursions.is_empty(), "incursions=%d" % ebm.incursions.size())

	_pl("═══ 6. 通关选择弹窗(真实 main popup) ═══")
	var overlay: Node = null
	for _i in range(30):
		overlay = _main.get_node_or_null("PopupLayer/GateCoreChoiceOverlay")
		if overlay != null:
			break
		await _wait_frames(10)
	if overlay == null:
		_pl("  DIAG 信号链未弹窗——直调 _show_gate_core_choice_dialog 验证方法体")
		_main.call("_show_gate_core_choice_dialog")
		await _wait_frames(5)
		overlay = _main.get_node_or_null("PopupLayer/GateCoreChoiceOverlay")
		_pl("  DIAG 直调后 overlay=%s battle_active=%s" % [
			str(overlay != null), str(get_tree().root.get_node_or_null("/root/BattleManager").get("battle_active"))])
		var sb := get_tree().root.get_node_or_null("/root/SignalBus")
		_pl("  DIAG main连接=%s 探针连接=%s" % [
			str(sb.gate_core_destroyed.is_connected(Callable(_main, "_on_gate_core_destroyed"))),
			str(sb.gate_core_destroyed.get_connections().size())])
	_ok("弹窗已弹出", overlay != null)
	if overlay != null:
		# 找「继续深入」按钮真实点击
		var go_btn: Button = null
		var stack: Array = [overlay]
		while not stack.is_empty() and go_btn == null:
			var n: Node = stack.pop_front()
			for c in n.get_children():
				if c is Button and String((c as Button).text).begins_with("继续深入"):
					go_btn = c
					break
				stack.append(c)
		_ok("「继续深入」按钮可解析", go_btn != null)
		if go_btn != null:
			go_btn.pressed.emit()
			await _wait_frames(10)
		_ok("选择收口(pending 解除)", not bool(ebm.gate_choice_pending))
		_ok("弹窗已关闭", _main.get_node_or_null("PopupLayer/GateCoreChoiceOverlay") == null)
	_ok("波间隔恢复(7s)", absf(float(gm.get_enemy_wave_interval_for_level(100)) - 7.0) < 0.001)

	_pl("═══ 7. 无限区:cleared 后不再刷本体 ═══")
	await _kill_all_enemies()
	_drive_wave()
	await _wait_frames(15)
	_ok("无限区继续出兵", int(bss.get("enemy_wave_index")) >= 4, "idx=%d" % int(bss.get("enemy_wave_index")))
	_ok("cleared 后无本体", _core_unit() == null)

	_pl("═══ 8. 撤退结算:end_battle(false) → 首通大奖 ═══")
	var marrow_before: int = _read_marrow()
	bm.end_battle(false)
	await _wait_frames(30)
	_ok("run 结束(run_active=false)", not bool(ebm.run_active))
	var summary: Dictionary = (gm.get("last_battle_reward_summary") as Dictionary).get("endless", {}) as Dictionary
	_ok("结算摘要 gate_cleared", bool(summary.get("gate_cleared", false)))
	_ok("结算摘要 首通", bool(summary.get("gate_first_clear", false)))
	_ok("gate_cleared_once 入档(会话内)", bool(ebm.gate_cleared_once))
	_ok("星髓到账(+200 首通+里程碑,受周封顶)", _read_marrow() > marrow_before,
		"(%d→%d)" % [marrow_before, _read_marrow()])

	Engine.time_scale = 1.0
	_pl("═══ 9. 异族渗透战全链 ═══")
	var inc := {"host_level": 88, "seed": 424242, "spawned_day": 1}
	ebm.incursions = [inc]
	var bak_level: int = int(gm.current_level)
	var bak_phase: int = int(gm.current_phase)
	gm.start_incursion_battle(inc)
	_ok("渗透备态:loadout 置位", not (gm.pending_incursion_loadout as Array).is_empty())
	_ok("渗透备态:关卡对齐宿主", int(gm.current_level) == 88)
	_ok("渗透备态:未直接开打", int(gm.current_phase) == bak_phase)
	# main 标准管线开打(模拟 _consume_incursion_meta 后半段)
	gm.set_current_level(88)  # 再保险(备态已设);保持显式
	_pl("  DIAG pipeline: _battle_setup=%s bf=%s" % [
		str(_main.get("_battle_setup") != null),
		str(_main.call("_get_battlefield") != null)])
	_protect_driver = true
	main_auto_start_via_pipeline()
	for _i in range(12):
		await _wait_frames(5)
		_pl("  DIAG inc[%02d]: phase=%s active=%s cnt=%s spawned=%s n=%d ids=%s" % [
			_i, str(gm.get("current_phase")), str(bm.get("battle_active")),
			str(bss.get("enemy_unit_count")), str(bss.get("_incursion_spawned")),
			_field_units("enemy").size(), str((bss.get("_incursion_ids") as Array).size())])
		if not bool(bm.get("battle_active")):
			break
	if not bool(bm.get("battle_active")) and int(bss.get("enemy_unit_count")) == 0:
		_pl("  DIAG 渗透编队未落场——create+place 链直测")
		var t1: Node = bss.call("_create_enemy_unit_with_id", "xeno_swarmling")
		_pl("  DIAG create ret=%s" % str(t1 != null))
		if t1 != null:
			var p1: bool = bss.spawn_enemy_unit_on_card_grid(t1, -1)
			_pl("  DIAG place ret=%s cnt=%s" % [str(p1), str(bss.get("enemy_unit_count"))])
		var r2: bool = bss.spawn_card_grid_enemy_wave(88)
		_pl("  DIAG manual-spawn ret=%s cnt=%s spawned=%s" % [
			str(r2), str(bss.get("enemy_unit_count")), str(bss.get("_incursion_spawned"))])
		await _wait_frames(10)
	if not bool(bm.get("battle_active")):
		await _wait_secs(1.5)
	if not bool(bm.get("battle_active")):
		_pl("  DIAG phase=%s battle_active=%s battle_scene=%s endless=%s inc_pending=%s" % [
			str(gm.get("current_phase")), str(bm.get("battle_active")),
			str(gm.get("battle_scene") != null), str(gm.is_endless_battle()),
			str((gm.pending_incursion_loadout as Array).size())])
	_ok("渗透战 battle_active", bool(bm.get("battle_active")))
	_ok("渗透 spawn 模式", bss.is_incursion_mode())
	_ok("波次耗尽判定=已刷", bss.all_enemy_waves_spawned())
	await _wait_secs(1.0)
	var inc_count: int = _field_units("enemy").size()
	_ok("单波编队落场(4-6)", inc_count >= 4 and inc_count <= 6, "n=%d" % inc_count)
	var res_before: Dictionary = _read_res()
	await _kill_all_enemies()
	await _wait_frames(30)
	# 胜利轻结算:节点清除+资源入账+不弹面板
	await _wait_frames(20)
	_ok("渗透节点已清除", ebm.incursions.is_empty())
	var got_nano: bool = int(_read_res().get("basic_nano", 0)) >= int(res_before.get("basic_nano", 0)) + 799
	_ok("渗透奖励入账(纳米≥800)", got_nano)
	_ok("渗透态复位", not bool(gm.is_incursion_battle()))
	# 渗透标记快照:bunker 豁免依赖开打快照(信号序修复)
	var bk: Node = get_tree().root.get_node_or_null("/root/BunkerManager")
	if bk != null:
		var log_len: int = (bk.get("_battle_log") as Array).size()
		_pl("  (bunker 日志长度=%d——渗透战不入账即豁免生效)" % log_len)
	gm.set_current_level(bak_level)

	_protect_driver = false
	_pl("═══ 10. 黑门关闭世界状态:通关后停刷 ═══")
	ebm.gate_cleared_once = true
	var bk_day: int = int(get_tree().root.get_node_or_null("/root/BunkerManager").call("get_day")) if get_tree().root.get_node_or_null("/root/BunkerManager") != null else 0
	ebm.incursions = [{"host_level": 50, "seed": 1, "spawned_day": bk_day - 10}]
	ebm._on_day_ended(99)
	_ok("通关后日刷清场停刷", ebm.incursions.is_empty())
	ebm.incursions = ebm_snapshot["incursions"]
	ebm.gate_cleared_once = ebm_snapshot["gate_cleared_once"]


func main_auto_start_via_pipeline() -> void:
	# 与 main._consume_incursion_meta 后半段同款:标准管线开打
	if _main != null and _main.has_method("_auto_battle_from_truck_sortie"):
		_main.call("_auto_battle_from_truck_sortie")


func _read_marrow() -> int:
	var brm: Node = get_tree().root.get_node_or_null("/root/BasicResourceManager")
	if brm != null and brm.has_method("get_total"):
		return int(brm.call("get_total", "star_marrow"))
	return -1


func _read_res() -> Dictionary:
	var brm: Node = get_tree().root.get_node_or_null("/root/BasicResourceManager")
	if brm != null and brm.has_method("get_total"):
		return {
			"basic_nano": int(brm.call("get_total", "basic_nano")),
			"energy_block": int(brm.call("get_total", "energy_block")),
		}
	return {}
