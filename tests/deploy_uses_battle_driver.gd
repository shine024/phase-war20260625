extends Node
## v20.16 部署次数真实战斗驱动（复现"死一次就不让上场"报告 → 按实例分池修复回归）
## 场景模式跑（autoload 全量初始化）：godot --headless --rendering-driver opengl3 --path . res://tests/deploy_uses_battle_driver.tscn
##
## 流程：实例化 main.tscn → InstanceRegistry 真实例装备（含 2× 同名卡）→ 真实 go_to_battle →
##       部署→击杀→重部署循环 → 断言：每实例恰好各自满额度；同名两实例池独立（v20.16 回归点）

## 装备计划：base id 列表（ww1_mp18 出现两次 = 两张独立实例）
const TEST_CARDS: Array = ["ww1_mp18", "ww1_arm_ft17", "ww1_mauser", "ww1_mp18"]

## 部署身份键列表（setup 阶段由实例填充），与 _test_entries 一一对应
var _test_keys: Array = []

var _log: Array = []
var _errs: Array[String] = []
var _uses_events: Array = []  # 所有 deploy_uses_changed 信号（抓隐藏消耗者）


func _ready() -> void:
	await _run()
	_report()
	get_tree().quit(0 if _errs.is_empty() else 1)


func _pl(s: String) -> void:
	_log.append(s)


func _fail(s: String) -> void:
	_errs.append(s)
	_pl("[FAIL] " + s)


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _run() -> void:
	# ── 1. 主场景实例化（真实 init：autoload + save + 面板） ──
	var main_packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if main_packed == null:
		_fail("main.tscn 加载失败")
		return
	var main: Node = main_packed.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait_frames(90)

	var gm: Node = get_tree().root.get_node_or_null("/root/GameManager")
	var bm: Node = get_tree().root.get_node_or_null("/root/BattleManager")
	var pim: Node = get_tree().root.get_node_or_null("/root/PhaseInstrumentManager")
	var ir: Node = get_tree().root.get_node_or_null("/root/InstanceRegistry")
	if ir == null:
		_fail("InstanceRegistry autoload 缺失")
		return
	if gm == null or bm == null or pim == null:
		_fail("autoload 缺失 gm=%s bm=%s pim=%s" % [gm != null, bm != null, pim != null])
		return
	if gm.get("battle_scene") == null:
		await _wait_frames(90)
	if gm.get("battle_scene") == null:
		_fail("battle_scene 未就绪")
		return

	# ── 2. 信号监听（抓所有次数变化 + 部署失败原因） ──
	var sb: Node = get_tree().root.get_node_or_null("/root/SignalBus")
	if sb != null:
		if sb.has_signal("deploy_uses_changed"):
			sb.deploy_uses_changed.connect(func(cid, rem, tot):
				_uses_events.append("%s → %d/%d @%.1fs" % [cid, rem, tot, Time.get_ticks_msec() / 1000.0]))
		if sb.has_signal("player_deploy_failed"):
			sb.player_deploy_failed.connect(func(reason, msg):
				_pl("  [deploy_failed] %s: %s" % [reason, msg]))

	# ── 3. 装备测试卡（清空现有绿槽再装模板卡） ──
	gm.set("current_level", 1)
	var greens: Array = []
	if "instrument_slots" in pim:
		greens = pim.instrument_slots.get("green", [])
	_pl("绿槽数=%d" % greens.size())
	for i in range(greens.size()):
		if greens[i] != null:
			pim.unequip_card(i)
	for i in range(mini(TEST_CARDS.size(), greens.size())):
		var inst: CardResource = ir.create_instance(TEST_CARDS[i])
		if inst == null:
			_fail("测试卡 %s 实例创建失败" % TEST_CARDS[i])
			continue
		_test_keys.append(inst.instance_id)
		if not pim.equip_card(i, inst):
			_pl("  装备 %s 到槽 %d 失败（可能已有占用）" % [inst.instance_id, i])

	# ── 4. 开战（真实链路） ──
	gm.go_to_battle()
	await _wait_frames(30)
	if not bool(bm.get("battle_active")):
		await _wait_frames(60)
	if not bool(bm.get("battle_active")):
		_fail("battle_active 未置位")
		return
	if bool(bm.get("_is_phase_master_battle")):
		_fail("第1关意外触发相位师战（应在保护期），测试环境不纯——结果仅供参考")
	var bss = bm.get("_spawn_system")
	if bss == null:
		_fail("_spawn_system 不可达")
		return
	var bf: Node = gm.get("battle_scene")
	_pl("战斗开始：is_pm=%s" % [str(bool(bm.get("_is_phase_master_battle")))])
	_pl("初始次数表: %s" % [str(bss.get("_deploy_uses_remaining"))])

	# ── 5. 每张卡：部署→杀→重部署循环（cid = 部署身份键 instance_id） ──
	# 前两张跑满额度（耗时 ~10s/张）；后两张只跑 1 轮（部署→杀→重部署），
	# 避免整场测试超过敌波拆基地时限导致战斗提前结束。
	for ki in range(_test_keys.size()):
		var full: bool = ki < 2
		await _test_card_cycle(_test_keys[ki], gm, bm, bss, bf, full)

	# v20.16 回归断言：同名两实例池独立——第二个 mp18 实例保持独立额度未被第一个动用
	if _test_keys.size() >= 4 and _test_keys[0].begins_with("ww1_mp18#") and _test_keys[3].begins_with("ww1_mp18#"):
		var pool_a: int = int(bss.get_deploy_uses_remaining(_test_keys[0]))
		var pool_b: int = int(bss.get_deploy_uses_remaining(_test_keys[3]))
		if pool_a != 0:
			_fail("同名实例回归：%s 终态=%d（应=0，满额度耗尽）" % [_test_keys[0], pool_a])
		elif pool_b != 6:
			_fail("同名实例回归：%s 剩余=%d（应=6——独立池 8 减去自己快检的 2 次，与 #1 无关）" % [_test_keys[3], pool_b])
		else:
			_pl("  ✓ 同名两实例独立池：#1 耗尽=0，#2 仍=6（分池生效，互不干扰）" % pool_b)

	# ── 6. 第二场战斗：验证次数重置 ──
	_pl("")
	_pl("──── 第二场战斗（次数应重置）────")
	if bm.has_method("end_battle"):
		bm.end_battle(true)
	await _wait_sec(1.0)
	gm.go_to_battle()
	await _wait_frames(45)
	if bool(bm.get("battle_active")):
		_pl("第二场初始次数表: %s" % [str(bss.get("_deploy_uses_remaining"))])
		if not _test_keys.is_empty():
			var rem2: int = int(bss.get_deploy_uses_remaining(_test_keys[0]))
			if rem2 <= 0:
				_fail("第二场战斗 %s 次数未重置（remaining=%d）" % [_test_keys[0], rem2])
			else:
				_pl("  %s 第二场剩余=%d ✓ 重置正常" % [_test_keys[0], rem2])


func _test_card_cycle(cid: String, gm: Node, bm: Node, bss, bf: Node, full: bool = true) -> void:
	_pl("")
	_pl("──── %s：部署→击杀→重部署循环%s ────" % [cid, "" if full else "（1轮快检）"])
	var total_start: int = int(bss.get_deploy_uses_remaining(cid))
	_pl("  战斗内实际初始化次数=%d" % total_start)
	if total_start <= 0:
		_fail("%s 初始化次数=%d（≤0，首部署就会被拒）" % [cid, total_start])
		return
	var deploys_ok: int = 0
	var first_redeploy_after_death: int = -1  # 记录第1次死亡后重部署结果
	var max_cycles: int = (total_start + 3) if full else 1
	for cycle in range(max_cycles):
		if not bool(bm.get("battle_active")):
			_pl("  战斗已提前结束（敌波拆基地），停止本卡循环（已成功 %d 次）" % deploys_ok)
			if full and deploys_ok < total_start:
				_fail("%s 因战斗提前结束未跑满（%d/%d）——缩短 full 范围或前移本卡" % [cid, deploys_ok, total_start])
			break
		var pos: Variant = _slot_pos(bf, cycle)
		if pos == null:
			_fail("%s cycle%d 取槽位坐标失败" % [cid, cycle])
			return
		var ok: bool = bool(bm.request_player_deploy_at(cid, pos))
		var rem: int = int(bss.get_deploy_uses_remaining(cid))
		if not ok:
			_pl("  cycle%d 部署失败（剩余=%d）——失败原因见上方 deploy_failed 日志" % [cycle, rem])
			_dump_alive_state(bm, cid, bss)
			if deploys_ok < total_start:
				_fail("%s 仅成功部署 %d 次就失败（初始化=%d）" % [cid, deploys_ok, total_start])
			break
		deploys_ok += 1
		_pl("  cycle%d 部署成功 剩余=%d" % [cycle, rem])
		await _wait_frames(3)
		# 击杀刚部署的单位
		var killed: bool = await _kill_latest_unit_of(bm, cid)
		if not killed:
			_pl("  cycle%d 未找到 %s 的存活单位（可能还在虚影/已被清）——等下一帧重试" % [cycle, cid])
			await _wait_sec(0.3)
			killed = await _kill_latest_unit_of(bm, cid)
			if not killed:
				_pl("  cycle%d 仍未找到单位，跳过击杀直接继续" % cycle)
		# 等淡出完成（0.5s 动画 + 余量）与可能的补阵冷却
		await _wait_sec(0.9)
		if cycle == 0:
			var pos2: Variant = _slot_pos(bf, 9)
			var reok: bool = pos2 != null and bool(bm.request_player_deploy_at(cid, pos2))
			first_redeploy_after_death = 1 if reok else 0
			_pl("  ▶ 首次死亡后立即重部署：%s（剩余=%d）" % ["成功" if reok else "失败", int(bss.get_deploy_uses_remaining(cid))])
			if reok:
				deploys_ok += 1
				await _wait_frames(3)
				await _kill_latest_unit_of(bm, cid)
				await _wait_sec(0.9)
	_pl("  ★ %s 实际可部署次数=%d（初始化=%d%s）" % [cid, deploys_ok, total_start, "" if full else "，快检模式"])
	if full and deploys_ok != total_start:
		_fail("%s 实际可部署 %d 次 ≠ 初始化 %d 次" % [cid, deploys_ok, total_start])
	if first_redeploy_after_death == 0:
		_fail("%s 首次死亡后重部署被拒——复现用户报告！" % cid)


func _slot_pos(bf: Node, cycle: int) -> Variant:
	# 依次用 0..8 号槽；循环轮换避免撞上残留占用
	if bf == null or not bf.has_method("get_card_grid_player_slot_global"):
		return null
	return bf.get_card_grid_player_slot_global(cycle % 9)


func _kill_latest_unit_of(bm: Node, cid: String) -> bool:
	var target: Node = _find_alive_unit_of(bm, cid)
	if target == null:
		return false
	# 确定性击杀：循环补刀直到 hp<=0（规避闪避随机性），断言进入 dying
	for attempt in range(30):
		if not is_instance_valid(target):
			break
		var hp_now: float = float(target.get("hp"))
		if hp_now <= 0.0 and (bool(target.get("_is_dying")) if "_is_dying" in target else true):
			break
		target.take_damage(1.0e12, null)
		await get_tree().create_timer(0.05).timeout
	if is_instance_valid(target):
		var hp_end: float = float(target.get("hp"))
		var dying: bool = bool(target.get("_is_dying")) if "_is_dying" in target else false
		var ghost: bool = bool(target.get("is_deploy_ghost")) if "is_deploy_ghost" in target else false
		_pl("    击杀 %s：hp=%.1f dying=%s ghost=%s" % [cid, hp_end, str(dying), str(ghost)])
		if hp_end > 0.0 and not dying:
			_fail("击杀失败：%s 单位 hp=%.1f 仍存活（30 次补刀无效——疑似无敌/闪避链异常）" % [cid, hp_end])
			return false
	else:
		_pl("    击杀 %s：节点已释放" % cid)
	return true


## 单位-键匹配：实例键（含#）按 source_instance_id meta，裸键按 source_card_id meta
func _unit_matches_key(u: Node, key: String) -> bool:
	if key.contains("#"):
		return String(u.get_meta("source_instance_id", "")) == key
	return String(u.get_meta("source_card_id", "")) == key


func _find_alive_unit_of(bm: Node, key: String) -> Node:
	var pu: Node = bm.get("player_units_node")
	if pu == null:
		return null
	var target: Node = null
	for u in pu.get_children():
		if u == null or not is_instance_valid(u):
			continue
		if _unit_matches_key(u, key):
			var dying: bool = bool(u.get("_is_dying")) if "_is_dying" in u else false
			if not dying:
				target = u
	return target


func _dump_alive_state(bm: Node, key: String, bss) -> void:
	# 部署被拒时：列出该键所有战场单位状态 + 存活计数，定位是哪一门在拦
	var pu: Node = bm.get("player_units_node")
	var lines: Array = []
	if pu != null:
		for u in pu.get_children():
			if u == null or not is_instance_valid(u):
				continue
			if not _unit_matches_key(u, key):
				continue
			var dying: bool = bool(u.get("_is_dying")) if "_is_dying" in u else false
			var ghost: bool = bool(u.get("is_deploy_ghost")) if "is_deploy_ghost" in u else false
			var preview: bool = bool(u.get("is_preview_mode")) if "is_preview_mode" in u else false
			lines.append("hp=%.1f dying=%s ghost=%s preview=%s pos=%s" % [
				float(u.get("hp")), str(dying), str(ghost), str(preview), str(u.get("global_position"))])
	_pl("    [%s 在场单位 %d 个] %s" % [key, lines.size(), " | ".join(lines)])
	var base_id: String = key.split("#")[0]
	if bss != null and bss.has_method("_count_alive_player_units_from_card"):
		_pl("    BSS 存活计数(base=%s)=%d" % [base_id, int(bss._count_alive_player_units_from_card(base_id))])


func _report() -> void:
	print("═════════════════════════════════════════════════")
	print("  部署次数真实战斗驱动报告")
	print("═════════════════════════════════════════════════")
	for l in _log:
		print(l)
	print("")
	print("── deploy_uses_changed 全量事件（抓隐藏消耗）──")
	for e in _uses_events:
		print("  " + e)
	print("")
	if _errs.is_empty():
		print("═══════ ALL PASS ═══════")
	else:
		print("═══════ FAILED %d 项 ═══════" % _errs.size())
		for e in _errs:
			print("  - " + e)
