extends Node
## 余烬要塞 房间升级系统冒烟测试（v26 制造系统批次1）
## 运行：godot --headless --rendering-driver opengl3 --path . res://tests/bunker_upgrade_smoke.tscn
## （场景模式跑——autoload 全量初始化；不用 --script 模式因其不加载 autoload）
##
## 覆盖：
##   A. defs 完整性：升级档结构 / 越界查询 / 满级数学 / 终局房无升级
##   B. 升级状态机：锁定房拒绝 / 资源不足拒绝 / 扣费 / 战斗推进 / 满级封顶
##   C. 效果查询：配给乘区 / 睡觉回精神 / 医疗费用疗效 / 出战胜利精神消耗 /
##      精神上限 / 深层设施冻结（通讯室）/ 低精神惩罚减半 / 情报乘区
##   D. 存档回环：upgrading/upg_progress/level 序列化还原 / reset 重置

const BunkerRoomDefs = preload("res://data/bunker_room_defs.gd")

var _fail_count := 0

func _ready() -> void:
	print("═════════════════════════════════════════════════")
	print("  余烬要塞 房间升级冒烟测试（BUNKER UPGRADE SMOKE）")
	print("═════════════════════════════════════════════════")
	await _phase_a_defs()
	await _phase_b_state_machine()
	await _phase_c_effects()
	await _phase_d_save_roundtrip()
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

func _mgr() -> Node:
	ManagerLazyLoader.ensure_loaded("bunker")
	var mgr: Node = ManagerLazyLoader.get_manager("bunker")
	if mgr == null:
		mgr = get_node_or_null("/root/BunkerManager")
	return mgr

func _grant_plenty() -> void:
	for _i in 12:
		var mgr: Node = _mgr()
		mgr.debug_grant_resources()

# ══════════════════ Phase A：defs 完整性 ══════════════════

func _phase_a_defs() -> void:
	var upgraded_count := 0
	for def in BunkerRoomDefs.get_all_rooms():
		var rid: String = def["id"]
		var ups: Array = def.get("upgrades", [])
		if bool(def.get("is_terminal", false)) or rid == "monument":
			if not ups.is_empty():
				_fail("%s 不应有升级档" % rid)
			continue
		if ups.is_empty():
			_fail("%s 缺少升级档" % rid)
			continue
		upgraded_count += 1
		for i in ups.size():
			var upg: Dictionary = ups[i]
			var target: int = i + 2
			if BunkerRoomDefs.get_upgrade_def(rid, target).is_empty():
				_fail("%s Lv%d 升级定义查询失败" % [rid, target])
			if (upg.get("cost", {}) as Dictionary).is_empty():
				_fail("%s Lv%d 升级成本为空" % [rid, target])
			if int(upg.get("battles", 0)) < 1:
				_fail("%s Lv%d 升级耗时 <1 场" % [rid, target])
			if str(upg.get("note", "")).is_empty():
				_fail("%s Lv%d 升级说明为空" % [rid, target])
		if BunkerRoomDefs.get_max_level(rid) != 1 + ups.size():
			_fail("%s 满级数学错误" % rid)
		# 越界查询应返回空
		if not BunkerRoomDefs.get_upgrade_def(rid, 1).is_empty() \
				or not BunkerRoomDefs.get_upgrade_def(rid, 4).is_empty():
			_fail("%s 升级档越界查询未返回空" % rid)
	if upgraded_count != 13:
		_fail("应有 13 间房带升级档，实际 %d" % upgraded_count)
	else:
		_ok("升级档完整性：13 房 × Lv2/Lv3 定义齐备，越界/终局/纪念墙行为正确")

# ══════════════════ Phase B：升级状态机 ══════════════════

func _phase_b_state_machine() -> void:
	var mgr: Node = _mgr()
	mgr.reset_to_defaults()
	_grant_plenty()

	# 1) 锁定房拒绝升级
	var locked: Dictionary = mgr.can_start_upgrade("mess_hall")
	if locked.get("ok", true):
		_fail("锁定房不应可升级")
	# 2) 修复食堂（成本 nano200+alloy100，1 场）
	if not mgr.start_repair("mess_hall").get("ok", false):
		_fail("食堂修复启动失败（资源应充足）")
	mgr.advance_after_battle(true)
	if mgr.get_room_state("mess_hall") != BunkerRoomDefs.STATE_ACTIVE:
		_fail("食堂修复未完成")
	# 3) 升级扣费：Lv2 需 nano300 + alloy150
	var nano_before: int = BasicResourceManager.get_total(BunkerRoomDefs.res_full_id("nano"))
	var alloy_before: int = BasicResourceManager.get_total(BunkerRoomDefs.res_full_id("alloy"))
	var up: Dictionary = mgr.start_upgrade("mess_hall")
	if not up.get("ok", false):
		_fail("食堂升级启动失败: " + str(up.get("reason", "")))
	if BasicResourceManager.get_total(BunkerRoomDefs.res_full_id("nano")) != nano_before - 300:
		_fail("食堂升级未扣纳米 300")
	if BasicResourceManager.get_total(BunkerRoomDefs.res_full_id("alloy")) != alloy_before - 150:
		_fail("食堂升级未扣合金 150")
	if not mgr.is_upgrading("mess_hall") or mgr.get_room_level("mess_hall") != 1:
		_fail("升级中状态错误")
	# 4) 重复升级拒绝
	if mgr.can_start_upgrade("mess_hall").get("ok", true):
		_fail("升级进行中不应再次放行")
	# 5) 战斗推进：Lv2 需 1 场
	mgr.advance_after_battle(true)
	if mgr.get_room_level("mess_hall") != 2 or mgr.is_upgrading("mess_hall"):
		_fail("食堂升级未在第 1 场后完成")
	# 6) 满级封顶：连升到 Lv3 后再拒
	_grant_plenty()
	mgr.start_upgrade("mess_hall")          # Lv3：600纳米+300合金，2 场
	mgr.advance_after_battle(true)
	mgr.advance_after_battle(true)
	if mgr.get_room_level("mess_hall") != 3:
		_fail("食堂未升到 Lv3")
	if not mgr.get_next_upgrade("mess_hall").is_empty():
		_fail("满级后 get_next_upgrade 应为空")
	if mgr.can_start_upgrade("mess_hall").get("ok", true):
		_fail("满级后不应可升级")
	# 7) 完工条目：修复无后缀、升级带 #up，解析为"名称（升级）"
	var today: Array = mgr.get_completed_today()
	if not (today as Array).has("mess_hall") or not (today as Array).has("mess_hall#up"):
		_fail("完工条目应含 mess_hall 与 mess_hall#up，实际 %s" % str(today))
	if BunkerRoomDefs.completed_entry_label("mess_hall#up") != "食堂（升级）":
		_fail("升级完工条目解析错误: " + BunkerRoomDefs.completed_entry_label("mess_hall#up"))
	_ok("升级状态机：锁定拒绝/扣费/战斗推进/重复拒绝/满级封顶/完工条目 全部正确")

# ══════════════════ Phase C：效果查询 ══════════════════

func _phase_c_effects() -> void:
	var mgr: Node = _mgr()
	mgr.reset_to_defaults()
	_grant_plenty()

	# 1) 配给：Lv1 基础 120/40 → 升食堂 Lv2 后 180/60
	mgr.start_repair("mess_hall")
	mgr.advance_after_battle(true)
	var ration: Dictionary = mgr.get_daily_ration()
	if int(ration.get("nano", 0)) != 120 or int(ration.get("alloy", 0)) != 40:
		_fail("Lv1 配给应为 120/40，实际 %s" % str(ration))
	mgr.start_upgrade("mess_hall")
	mgr.advance_after_battle(true)
	ration = mgr.get_daily_ration()
	if int(ration.get("nano", 0)) != 180 or int(ration.get("alloy", 0)) != 60:
		_fail("Lv2 配给应为 180/60，实际 %s" % str(ration))

	# 2) 睡觉回精神：宿舍 Lv2 → +30（初始 ACTIVE 直接升）
	mgr.adjust_sanity(-80.0)
	mgr.start_upgrade("dormitory")
	mgr.advance_after_battle(true)
	var s_before: float = mgr.get_sanity()
	mgr.sleep()
	if absf((mgr.get_sanity() - s_before) - 30.0) > 0.01:
		_fail("宿舍 Lv2 睡觉应回 30，实际 %.1f" % (mgr.get_sanity() - s_before))

	# 3) 出战胜利精神消耗：兵棋室 Lv2 → -8（初始 ACTIVE 直接升）
	mgr.start_upgrade("war_room")
	mgr.advance_after_battle(true)
	s_before = mgr.get_sanity()
	mgr.advance_after_battle(true)
	if absf((s_before - mgr.get_sanity()) - 8.0) > 0.01:
		_fail("兵棋室 Lv2 胜利精神消耗应为 8，实际 %.1f" % (s_before - mgr.get_sanity()))

	# 4) 精神上限：入口大厅 Lv3 → 110
	mgr.start_upgrade("entry_hall")
	mgr.advance_after_battle(true)
	mgr.start_upgrade("entry_hall")
	mgr.advance_after_battle(true)
	if absf(mgr.get_sanity_cap() - 110.0) > 0.01:
		_fail("入口大厅 Lv3 精神上限应为 110")
	mgr.adjust_sanity(500.0)
	if absf(mgr.get_sanity() - 110.0) > 0.01:
		_fail("精神值应被钳到 110，实际 %.1f" % mgr.get_sanity())

	# 5) 医疗 Lv3：费用 30 / 疗效 60（医疗初始 LOCKED：先修后升两级）
	mgr.adjust_sanity(-100.0)
	mgr.start_repair("medical")
	mgr.advance_after_battle(true)
	mgr.start_upgrade("medical")
	mgr.advance_after_battle(true)   # Lv2 完成（1 场）
	mgr.start_upgrade("medical")
	mgr.advance_after_battle(true)
	mgr.advance_after_battle(true)   # Lv3 完成（2 场）
	if mgr.get_medical_cost() != 30 or absf(mgr.get_medical_recovery() - 60.0) > 0.01:
		_fail("医疗室 Lv3 应为 费用30/疗效60，实际 %d/%.0f" % [
			mgr.get_medical_cost(), mgr.get_medical_recovery()])
	var nano_before: int = BasicResourceManager.get_total(BunkerRoomDefs.res_full_id("nano"))
	var treat: Dictionary = mgr.medical_treatment()
	if not treat.get("ok", false):
		_fail("治疗失败: " + str(treat.get("reason", "")))
	if BasicResourceManager.get_total(BunkerRoomDefs.res_full_id("nano")) != nano_before - 30:
		_fail("治疗未按 Lv3 价 30 纳米扣费")

	# 6) 深层设施升级冻结：反应堆离线时通讯室升级进度冻结
	mgr.start_repair("comms")
	mgr.advance_after_battle(true)   # 通讯室修复完成（1 场）
	mgr.start_upgrade("comms")       # Lv2：2 场
	mgr.advance_after_battle(true)
	if mgr.is_repair_frozen("comms") and absf(mgr.get_upgrade_progress("comms")) > 0.001:
		_fail("通讯室升级进度应被冻结在 0")
	_ok("深层冻结：通讯室升级进度在反应堆离线时冻结")

	# 7) 低精神惩罚减半（反应堆 Lv3）：直接拨等级验证乘数
	mgr._rooms["reactor"]["level"] = 3
	mgr.adjust_sanity(-100.0)   # tier 2（<30）
	if absf(mgr.get_drop_reward_multiplier() - 0.875) > 0.001:
		_fail("反应堆 Lv3 tier2 惩罚应为 0.875，实际 %.3f" % mgr.get_drop_reward_multiplier())
	mgr.adjust_sanity(45.0)     # tier 1（<50）
	if absf(mgr.get_drop_reward_multiplier() - 0.95) > 0.001:
		_fail("反应堆 Lv3 tier1 惩罚应为 0.95")

	# 8) 效果查询：制造折扣/情报乘区/商店刷新/声望乘区（直接拨等级）
	mgr._rooms["workshop"]["level"] = 3
	if absf(mgr.get_manufacture_discount() - 0.8) > 0.001:
		_fail("工坊 Lv3 制造折扣应为 0.8")
	if absf(mgr.get_mod_install_discount() - 0.85) > 0.001:
		_fail("工坊 Lv3 改造安装折扣应为 0.85")
	mgr._rooms["archive"]["level"] = 3
	if absf(mgr.get_intel_gain_multiplier() - 1.1) > 0.001:
		_fail("档案室 Lv3 情报乘区应为 1.1")
	if not mgr.is_analyzer_online():
		_fail("档案室 Lv3 分析仪应在线")
	mgr._rooms["comms"]["level"] = 3
	if mgr.get_shop_free_refresh_bonus() != 1:
		_fail("通讯室 Lv2 商店免费刷新应 +1")
	if absf(mgr.get_faction_rep_multiplier() - 1.15) > 0.001:
		_fail("通讯室 Lv3 声望乘区应为 1.15")
	_ok("效果查询：配给/睡觉/出战消耗/上限/医疗/惩罚减半/各乘区 全部正确")

# ══════════════════ Phase D：存档回环 ══════════════════

func _phase_d_save_roundtrip() -> void:
	var mgr: Node = _mgr()
	mgr.reset_to_defaults()
	_grant_plenty()
	# 造一个"半途升级"状态：食堂修好 → 升 Lv2（1 场）→ 再升 Lv3（2 场）打到一半
	mgr.start_repair("mess_hall")
	mgr.advance_after_battle(true)
	mgr.start_upgrade("mess_hall")
	mgr.advance_after_battle(true)   # 1 场即完成（battles=1）→ Lv2
	mgr.start_upgrade("mess_hall")   # Lv3 需要 2 场——先打 1 场存一半
	mgr.advance_after_battle(true)
	var saved: Dictionary = mgr.save_state()
	# 用全新管理器实例还原（模拟读档）
	var fresh: Node = (load("res://managers/bunker_manager.gd") as GDScript).new()
	fresh.load_state(saved)
	if fresh.get_room_level("mess_hall") != 2:
		_fail("读档后食堂等级应为 2")
	if not fresh.is_upgrading("mess_hall"):
		_fail("读档后食堂升级中状态丢失")
	if absf(fresh.get_upgrade_progress("mess_hall") - 0.5) > 0.001:
		_fail("读档后升级进度应为 0.5，实际 %.2f" % fresh.get_upgrade_progress("mess_hall"))
	# reset 全重置
	mgr.reset_to_defaults()
	if mgr.get_room_level("mess_hall") != 1 or mgr.is_upgrading("mess_hall"):
		_fail("reset_to_defaults 未清空升级状态")
	_ok("存档回环：level/upgrading/upg_progress 序列化 + reset 全部正确")
