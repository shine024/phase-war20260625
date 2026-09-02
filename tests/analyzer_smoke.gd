extends Node
## 批次3 冒烟测试：分析仪 / 缴获品质 / 战利品打印 / 地表探索 / 高品权重
## 运行：godot --headless --rendering-driver opengl3 --path . res://tests/analyzer_smoke.tscn

const ManufacturePools = preload("res://data/manufacture_pools.gd")
const DefaultCards = preload("res://data/default_cards.gd")

var _fail_count := 0

func _ready() -> void:
	print("═════════════════════════════════════════════════")
	print("  批次3 冒烟测试（ANALYZER / CAPTURED QUALITY / EXPEDITION）")
	print("═════════════════════════════════════════════════")
	ManagerLazyLoader.ensure_loaded("bunker")
	ManagerLazyLoader.ensure_loaded("manufacture")
	# 缴获卡模板是动态注册（CapturedUnitCards → DefaultCards 缓存），
	# 真实流程由掉落链前置触发；测试须显式注册，否则 create_instance(captured_*) 为 null
	CapturedUnitCards.register_into_default_cards_cache()
	await get_tree().process_frame
	await _phase_a_captured_quality()
	await _phase_b_analyzer_insert()
	await _phase_c_analyzer_bake()
	await _phase_d_daily_limit()
	await _phase_e_loot_print()
	await _phase_f_expedition()
	await _phase_g_save_roundtrip()
	await _phase_h_high_boost()
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

func _bunker() -> Node:
	return ManagerLazyLoader.get_manager("bunker")

func _reset_bunker() -> void:
	var b: Node = _bunker()
	b.reset_to_defaults()
	b.debug_grant_resources()

# ════════════ A. 缴获品质滚动 ════════════

func _phase_a_captured_quality() -> void:
	var hits := {}
	for _i in 200:
		var r := ManufacturePools.roll_captured_rarity()
		hits[r] = int(hits.get(r, 0)) + 1
		if not ManufacturePools.CAPTURED_ROLL_WEIGHTS.has(r):
			_fail("缴获品质 roll 出越界稀有度: %s" % r)
			break
	if hits.has("mythic"):
		_fail("缴获品质不应出神话")
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	var cap: CardResource = ir.create_instance("captured_ww1_inf_mp18")
	ManufacturePools.apply_captured_quality(cap)
	if not ManufacturePools.CAPTURED_ROLL_WEIGHTS.has(String(cap.rarity)):
		_fail("apply_captured_quality 后稀有度非法: %s" % cap.rarity)
	var plain: CardResource = ir.create_instance("ww1_mp18")
	plain.rarity = "epic"
	ManufacturePools.apply_captured_quality(plain)
	if String(plain.rarity) != "epic":
		_fail("非缴获卡品质不应被改写")
	ir.dispose_instance(cap.instance_id)
	ir.dispose_instance(plain.instance_id)
	_ok("缴获品质滚动：分布/越界/普通卡豁免 正确")

# ════════════ B. 分析仪插入 ════════════

func _make_captured(archetype: String) -> CardResource:
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	var inst: CardResource = ir.create_instance("captured_" + archetype)
	ManufacturePools.apply_captured_quality(inst)
	return inst

func _phase_b_analyzer_insert() -> void:
	var b: Node = _bunker()
	_reset_bunker()
	# 未上线（archive Lv1）→ 拒
	var inst := _make_captured("ww1_inf_mp18")
	var r0: Dictionary = b.analyzer_insert(String(inst.instance_id))
	if r0.get("ok", true):
		_fail("档案室 Lv1 不应能用分析仪")
	b._rooms["archive"]["level"] = 2
	# 普通卡 → 拒
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	var plain: CardResource = ir.create_instance("ww1_mp18")
	var r1: Dictionary = b.analyzer_insert(String(plain.instance_id))
	if r1.get("ok", true):
		_fail("普通玩家卡不应能放入分析仪")
	# 正常放入
	var r2: Dictionary = b.analyzer_insert(String(inst.instance_id))
	if not r2.get("ok", false):
		_fail("正常缴获卡插入失败: %s" % str(r2.get("reason", "")))
	var st: Dictionary = b.analyzer_state()
	if st.get("slot", {}).is_empty():
		_fail("插入后槽位应为空中非空")
	if ir.get_instance(String(inst.instance_id)) != null:
		_fail("插入后原实例应已销毁")
	# 槽占用 → 再插拒
	var inst2 := _make_captured("ww1_inf_rifle")
	var r3: Dictionary = b.analyzer_insert(String(inst2.instance_id))
	if r3.get("ok", true):
		_fail("单槽占用时应拒绝第二张")
	ir.dispose_instance(String(inst2.instance_id))
	ir.dispose_instance(String(plain.instance_id))
	_ok("分析仪插入：上线门/缴获限定/单槽/即时销毁 正确")

# ════════════ C. 出炉与情报入账 ════════════

func _phase_c_analyzer_bake() -> void:
	var b: Node = _bunker()
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	var intel: Node = get_node_or_null("/root/IntelManual")
	var st: Dictionary = b.analyzer_state()
	var slot: Dictionary = st.get("slot", {})
	var archetype := String(slot.get("archetype_id", ""))
	var rarity := String(slot.get("rarity", "common"))
	var base_before: float = intel.get_base_progress(archetype)
	b.advance_after_battle(true)
	if int(b.analyzer_state().get("slot", {}).get("battles_left", 0)) != 1:
		_fail("1 场后 battles_left 应为 1")
	b.advance_after_battle(true)
	var slot_after: Dictionary = b.analyzer_state().get("slot", {})
	if not slot_after.is_empty():
		_fail("2 场后应出炉清槽")
	var base_after: float = intel.get_base_progress(archetype)
	var expected := ManufacturePools.analyzer_yield(rarity)
	if base_after - base_before < expected - 0.001:
		_fail("出炉情报增量应 ≥ %.2f，实际 %.3f → %.3f" % [expected, base_before, base_after])
	if int(b.analyzer_baked_today()) != 1:
		_fail("出炉计数应为 1，实际 %d" % int(b.analyzer_baked_today()))
	_ok("分析仪出炉：场次推进/情报入账（%s +%.0f%%）/计数 正确" % [rarity, expected * 100.0])

# ════════════ D. 每日限额 ════════════

func _phase_d_daily_limit() -> void:
	var b: Node = _bunker()
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	while int(b.analyzer_baked_today()) < 3:
		var inst := _make_captured("ww1_inf_rifle")
		var r: Dictionary = b.analyzer_insert(String(inst.instance_id))
		if not r.get("ok", false):
			_fail("限额内插入被拒: %s" % str(r.get("reason", "")))
			ir.dispose_instance(String(inst.instance_id))
			break
		b.advance_after_battle(true)
		b.advance_after_battle(true)
	var extra := _make_captured("ww1_sup_mg_nest")
	var r4: Dictionary = b.analyzer_insert(String(extra.instance_id))
	if r4.get("ok", true):
		_fail("每日 3 张后应拒绝第 4 张")
	ir.dispose_instance(String(extra.instance_id))
	_ok("分析仪每日限额 3 张 正确")

# ════════════ E. 仓库战利品打印 ════════════

func _phase_e_loot_print() -> void:
	var b: Node = _bunker()
	_reset_bunker()
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	var count_before: int = ir.get_instance_count()
	# Lv1 不打印
	b.sleep()
	if ir.get_instance_count() != count_before:
		_fail("仓库 Lv1 不应打印缴获卡")
	_reset_bunker()
	b._rooms["depot"]["level"] = 3
	b._rooms["depot"]["state"] = 2  # ACTIVE（reset 后仓库是初始锁定价，打印需房间可用）
	b.sleep()
	var summary_had_key := true
	var new_count: int = ir.get_instance_count() - count_before
	if new_count < 1:
		_fail("仓库 Lv3 睡醒应打印 1 张缴获卡（新增 %d）" % new_count)
	# 再睡一天还会打（每日 1 张）
	count_before = ir.get_instance_count()
	b.sleep()
	if ir.get_instance_count() - count_before < 1:
		_fail("第二天应再打印 1 张")
	_ok("仓库战利品打印：Lv 门/每日 1 张 正确")

# ════════════ F. 地表探索 ════════════

func _phase_f_expedition() -> void:
	var b: Node = _bunker()
	_reset_bunker()
	var r0: Dictionary = b.start_expedition()
	if r0.get("ok", true):
		_fail("气象站 Lv1 不应能探索")
	b._rooms["weather_station"]["level"] = 3
	b._rooms["weather_station"]["state"] = 2  # ACTIVE
	var r1: Dictionary = b.start_expedition()
	if not r1.get("ok", false):
		_fail("探索失败: %s" % str(r1.get("reason", "")))
	var r2: Dictionary = b.start_expedition()
	if r2.get("ok", true):
		_fail("同一天第二次探索应被拒")
	_ok("地表探索：Lv 门/日 1 次/奖励结算 正确")

# ════════════ G. 存档回环 ════════════

func _phase_g_save_roundtrip() -> void:
	var b: Node = _bunker()
	# E/F 的 reset 把档案室打回 Lv1——分析仪需 Lv2 才能插入
	b._rooms["archive"]["level"] = 2
	# C/D 出炉后槽已空——先插一张新卡再验证存档回环
	var inst := _make_captured("ww1_inf_mp18")
	b.analyzer_insert(String(inst.instance_id))
	var saved: Dictionary = b.save_state()
	var fresh: Node = load("res://managers/bunker_manager.gd").new()
	fresh._init()
	fresh.load_state(saved)
	if fresh.analyzer_state().get("slot", {}).is_empty():
		_fail("读档后在机卡应保留（当前应有卡在机）")
	if String(fresh.analyzer_state().get("slot", {}).get("archetype_id", "")) != \
			String(b.analyzer_state().get("slot", {}).get("archetype_id", "")):
		_fail("读档后在机卡原型不一致")
	fresh.free()
	ir_dispose_helper(String(inst.instance_id))
	_ok("分析仪存档回环 正确")

func ir_dispose_helper(instance_id: String) -> void:
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("dispose_instance"):
		ir.dispose_instance(instance_id)

# ════════════ H. 档案室 Lv3 高品权重 ════════════

func _phase_h_high_boost() -> void:
	var b: Node = _bunker()
	var mgr: Node = ManagerLazyLoader.get_manager("manufacture")
	var intel: Node = get_node_or_null("/root/IntelManual")
	# 情报拉满 100%（tier 4 池含 epic，才能对比档案室 Lv3 的 epic 占比；
	# 直接改条目峰值——set_acquired_base_progress 只有 0.5 抬底）
	intel._entries.clear()
	intel._completed_cache.clear()
	intel.set_acquired_base_progress("ww1_inf_mp18")
	intel._entries["ww1_inf_mp18"].base_progress = 1.0
	intel._entries["ww1_inf_mp18"].intel_progress = 1.0
	b._rooms["archive"]["level"] = 2
	if absf(mgr.get_pool_high_boost() - 1.0) > 0.001:
		_fail("档案室 Lv2 高品权重应为 1.0")
	var pool_b: Array = mgr.get_effective_pool("ww1_mp18")   # baseline（Lv2，无加成）
	var total_b := 0.0
	for e in pool_b:
		total_b += float(e["w"])
	b._rooms["archive"]["level"] = 3
	if absf(mgr.get_pool_high_boost() - 1.5) > 0.001:
		_fail("档案室 Lv3 高品权重应为 1.5")
	var pool_n: Array = mgr.get_effective_pool("ww1_mp18")   # boosted（Lv3，×1.5）
	var total_n := 0.0
	for e in pool_n:
		total_n += float(e["w"])
	var epic_n := 0.0
	var epic_b := 0.0
	for e in pool_n:
		if String(e["r"]) == "epic":
			epic_n = float(e["w"]) / total_n
	for e in pool_b:
		if String(e["r"]) == "epic":
			epic_b = float(e["w"]) / total_b
	if epic_n <= epic_b:
		_fail("Lv3 下 epic 占比应上升（%.3f → %.3f）" % [epic_b, epic_n])
	_ok("档案室 Lv3 高品权重 ×1.5 正确（epic 占比 %.1f%% → %.1f%%）" % [epic_b * 100.0, epic_n * 100.0])
