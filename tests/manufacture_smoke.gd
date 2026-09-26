extends Node
## 制造系统冒烟测试（v26 批次2）
## 运行：godot --headless --rendering-driver opengl3 --path . res://tests/manufacture_smoke.tscn
##
## 覆盖：
##   A. 品质池纯函数：档位映射 / 暗保底权重放大 / roll 边界 / 时代消耗表 / 文本
##   B. 配方目录：数量级 / captured_ 剔除 / 无敌形卡拒绝
##   C. 资格判定：情报门 / 时代授权门（era0 豁免 + 技能树解锁）/ 资源门
##   D. 执行制造：扣费 / 实例创建 + 品质覆盖 / 入包信号 / 暗保底记账 / 工坊折扣

const ManufacturePools = preload("res://data/manufacture_pools.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const ManufactureManagerScript = preload("res://managers/manufacture_manager.gd")

var _fail_count := 0

func _ready() -> void:
	print("═════════════════════════════════════════════════")
	print("  制造系统冒烟测试（MANUFACTURE SMOKE）")
	print("═════════════════════════════════════════════════")
	# 懒加载管理器（ManufactureManager/BunkerManager）需一帧才挂进 root——
	# 否则其内部 get_node 绝对路径会"outside the active scene tree"
	ManagerLazyLoader.ensure_loaded("manufacture")
	ManagerLazyLoader.ensure_loaded("bunker")
	await get_tree().process_frame
	await _phase_a_pools()
	await _phase_b_catalog()
	await _phase_c_gates()
	await _phase_d_manufacture()
	_finish()

## 情报条目硬清零（load_state({}) 对空字典是静默跳过，不清真实存档残留——
## 冒烟进程会读用户存档，必须直接清私有表）
func _reset_intel() -> void:
	var intel: Node = get_node_or_null("/root/IntelManual")
	intel._entries.clear()
	intel._completed_cache.clear()

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
	ManagerLazyLoader.ensure_loaded("manufacture")
	return ManagerLazyLoader.get_manager("manufacture")

# ══════════════════ Phase A：品质池纯函数 ══════════════════

func _phase_a_pools() -> void:
	var cases := [[0.1, 0], [0.25, 1], [0.49, 1], [0.5, 2], [0.74, 2], [0.75, 3], [0.99, 3], [1.0, 4]]
	for c in cases:
		var got := ManufacturePools.get_pool_tier(float(c[0]))
		if got != int(c[1]):
			_fail("档位映射 %.2f 应为 %d，实际 %d" % [float(c[0]), int(c[1]), got])
	# 暗保底：pity≥3 时 rare 以上权重 ×2
	var base_pool := ManufacturePools.get_effective_pool(0.6, 0)
	var boosted := ManufacturePools.get_effective_pool(0.6, 3)
	var base_rare: float = _pool_weight(base_pool, "rare")
	var boost_rare: float = _pool_weight(boosted, "rare")
	if absf(boost_rare - base_rare * 2.0) > 0.001:
		_fail("暗保底 rare 权重应 ×2（%.1f → %.1f）" % [base_rare, boost_rare])
	if absf(_pool_weight(boosted, "common") - _pool_weight(base_pool, "common")) > 0.001:
		_fail("暗保底不应放大 common 权重")
	# roll 边界
	if ManufacturePools.roll_rarity(0.1, 0) != "":
		_fail("未达 25% 门槛 roll 应返回空串")
	for _i in 20:
		if ManufacturePools.roll_rarity(0.3, 0) != "common":
			_fail("档位 1（普通100%）roll 出非普通")
	# 消耗表
	var c0 := ManufacturePools.get_cost_for_era(0)
	var c4 := ManufacturePools.get_cost_for_era(4)
	if int(c0.get("nano_materials", 0)) != 100 or int(c0.get("energy_block", 0)) != 20:
		_fail("era0 消耗应为 纳米100+能量块20")
	if int(c4.get("crystal", 0)) != 40:
		_fail("era4 消耗应含水晶40")
	if ManufacturePools.cost_text(c0).is_empty():
		_fail("cost_text 不应为空")
	_ok("品质池纯函数：档位/暗保底/roll边界/消耗表 全部正确")

func _pool_weight(pool: Array, rarity: String) -> float:
	for e in pool:
		if String(e["r"]) == rarity:
			return float(e["w"])
	return -1.0

# ══════════════════ Phase B：配方目录 ══════════════════

func _phase_b_catalog() -> void:
	var mgr: Node = _mgr()
	if mgr == null:
		_fail("ManufactureManager 懒加载失败")
		return
	mgr._recipe_built = false   # 强制重建（防同进程旧缓存）
	mgr._recipe_cache.clear()
	var recipes: Array = mgr.get_recipe_ids()
	if recipes.size() < 30:
		_fail("配方数量应 ≥30，实际 %d" % recipes.size())
	for rid in recipes:
		if str(rid).begins_with("captured_"):
			_fail("配方目录混入缴获卡: %s" % str(rid))
	if not mgr.is_manufacturable("ww1_mp18"):
		_fail("ww1_mp18 应可制造（情报冒烟确认其存在敌形原型）")
	if mgr.is_manufacturable("captured_ww1_mp18"):
		_fail("缴获卡不应出现在配方目录")
	# 找一张不在目录里的卡（能量卡/专属卡等）
	var outsider := ""
	for id in DefaultCards.get_all_blueprint_ids():
		var cid := str(id)
		if not mgr.is_manufacturable(cid):
			outsider = cid
			break
	if outsider.is_empty():
		_fail("卡池中未找到不可制造样本（目录可能误收全池）")
	else:
		var res: Dictionary = mgr.can_manufacture(outsider)
		if res.get("ok", true):
			_fail("无敌形卡 %s 不应通过制造资格" % outsider)
	_ok("配方目录：%d 个配方，captured_/无敌形卡处理正确" % recipes.size())

# ══════════════════ Phase C：资格判定 ══════════════════

func _phase_c_gates() -> void:
	var mgr: Node = _mgr()
	# 复位情报与资源到干净态
	_reset_intel()
	var intel: Node = get_node_or_null("/root/IntelManual")
	var bunker: Node = get_node_or_null("/root/BunkerManager")
	ManagerLazyLoader.ensure_loaded("bunker")
	bunker = ManagerLazyLoader.get_manager("bunker")
	bunker.reset_to_defaults()
	bunker.debug_grant_resources()
	bunker.debug_grant_resources()

	# 1) 情报门：0% → 拒（intel 条件未达）
	var r0: Dictionary = mgr.can_manufacture("ww1_mp18")
	if r0.get("ok", true):
		_fail("情报 0% 不应通过制造资格")
	_condition_has(r0, "intel", false)
	# 2) 情报抬到 50%（获取下限同款通道，注意情报记在原型域）→ intel 达标
	intel.set_acquired_base_progress("ww1_inf_mp18")
	if absf(mgr.get_intel_base("ww1_mp18") - 0.5) > 0.001:
		_fail("获取抬底后 base 应为 0.5，实际 %.2f" % mgr.get_intel_base("ww1_mp18"))
	var r1: Dictionary = mgr.can_manufacture("ww1_mp18")
	if not r1.get("ok", false):
		_fail("情报 50% + era0 豁免 + 资源充足应通过，实际: %s" % str(r1.get("reason_zh", "")))
	_condition_has(r1, "intel", true)
	_condition_has(r1, "skill_tree_era", true)
	_condition_has(r1, "resources", true)

	# 3) 时代授权门：era≥1 卡在技能树未解锁时拒绝
	var ww2_id := ""
	for rid in mgr.get_recipe_ids():
		if str(rid).begins_with("ww2_"):
			ww2_id = str(rid)
			break
	if ww2_id.is_empty():
		_fail("配方目录中未找到 ww2_ 时代样本")
	else:
		var r2: Dictionary = mgr.can_manufacture(ww2_id)
		_condition_has(r2, "skill_tree_era", false)
		if r2.get("ok", true):
			_fail("era≥1 未授权不应通过（%s）" % ww2_id)
		# 解锁 pms_cw_4（全时代授权节点，v8_extension）→ 放行
		var pmsm: Node = get_node_or_null("/root/PhaseMasterSkillManager")
		if pmsm == null:
			_fail("PhaseMasterSkillManager 不存在")
		else:
			pmsm._unlocked_nodes.append("pms_cw_4")
			var r3: Dictionary = mgr.can_manufacture(ww2_id)
			_condition_has(r3, "skill_tree_era", true)
			# 记录4#2：逐时代链——只解锁 pms_evo_era1（二战授权）也应放行 ww2
			pmsm._unlocked_nodes.clear()
			pmsm._unlocked_nodes.append("pms_evo_era1")
			var r4: Dictionary = mgr.can_manufacture(ww2_id)
			_condition_has(r4, "skill_tree_era", true)
			# 近未来卡在只有二战授权时仍应拒绝（分账到逐时代的回归面）
			var near_id := ""
			for rid in mgr.get_recipe_ids():
				if str(rid).begins_with("bp_near_") or str(rid).begins_with("near_"):
					near_id = str(rid)
					break
			if not near_id.is_empty():
				var r5: Dictionary = mgr.can_manufacture(near_id)
				_condition_has(r5, "skill_tree_era", false)
	_ok("资格判定：情报门/era0豁免/时代授权门 全部正确")

func _condition_has(result: Dictionary, key: String, met: bool) -> void:
	for c in result.get("conditions", []):
		if c is Dictionary and String(c.get("key", "")) == key:
			if bool(c.get("met", false)) != met:
				_fail("条件 %s 的 met 应为 %s" % [key, str(met)])
			return
	_fail("条件快照缺少 %s" % key)

# ══════════════════ Phase D：执行制造 ══════════════════

func _phase_d_manufacture() -> void:
	var mgr: Node = _mgr()
	var intel: Node = get_node_or_null("/root/IntelManual")
	var bunker: Node = ManagerLazyLoader.get_manager("bunker")

	# 1) 基础制造：扣费 + 实例 + 品质合法 + 入包信号
	_reset_intel()
	intel.set_acquired_base_progress("ww1_inf_mp18")
	var nano_id := "nano_materials"
	var energy_id := "energy_block"
	var nano_before: int = BasicResourceManager.get_total(nano_id)
	var energy_before: int = BasicResourceManager.get_total(energy_id)
	var backpack_hits: Array = []
	var spy := func(card: CardResource) -> void:
		backpack_hits.append(card)
	var sb: Node = get_node_or_null("/root/SignalBus")
	sb.card_added_to_backpack.connect(spy)
	var result: Dictionary = mgr.manufacture("ww1_mp18")
	if not result.get("ok", false):
		_fail("制造失败: %s" % str(result.get("reason_zh", "")))
		return
	if BasicResourceManager.get_total(nano_id) != nano_before - 100:
		_fail("制造未扣纳米 100（%d → %d）" % [nano_before, BasicResourceManager.get_total(nano_id)])
	if BasicResourceManager.get_total(energy_id) != energy_before - 20:
		_fail("制造未扣能量块 20")
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	var inst: CardResource = ir.get_instance(String(result.get("instance_id", "")))
	if inst == null:
		_fail("制造出的实例不在注册表")
	elif inst.rarity != String(result.get("rarity", "")):
		_fail("实例稀有度与掷出结果不一致")
	elif not ["common", "uncommon", "rare"].has(inst.rarity):
		_fail("档位2 掷出越界稀有度: %s" % inst.rarity)
	if backpack_hits.size() != 1:
		_fail("card_added_to_backpack 应广播 1 次，实际 %d" % backpack_hits.size())
	# 暗保底记账方向
	var expected_pity := 0 if ManufacturePools.is_high_rarity(String(result.get("rarity"))) else 1
	if mgr.get_pity("ww1_mp18") != expected_pity:
		_fail("暗保底计数应为 %d，实际 %d" % [expected_pity, mgr.get_pity("ww1_mp18")])

	# 2) 工坊 Lv3 折扣：era0 消耗 100→80 / 20→16
	bunker._rooms["workshop"]["level"] = 3
	var disc: Dictionary = mgr.get_cost("ww1_mp18")
	if int(disc.get("nano_materials", 0)) != 80 or int(disc.get("energy_block", 0)) != 16:
		_fail("工坊 Lv3 折扣消耗应为 80/16，实际 %s" % str(disc))
	bunker._rooms["workshop"]["level"] = 1

	# 3) 存档回环：pity 序列化
	mgr._pity["ww1_mp18"] = 3
	var saved: Dictionary = mgr.save_state()
	var fresh: Node = ManufactureManagerScript.new()
	fresh.load_state(saved)
	if fresh.get_pity("ww1_mp18") != 3:
		_fail("pity 读档应保留 3")
	fresh.load_state({})
	if fresh.get_pity("ww1_mp18") != 0:
		_fail("load_state({}) 应清空 pity")
	_ok("执行制造：扣费/实例+品质/入包信号/暗保底/折扣/存档回环 全部正确")
