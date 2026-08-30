# v21 P2 搭档协同 + 角色归一化 smoke test（不依赖 GdUnit，extends SceneTree 直跑）
# 验证：
#   1) 9 角色归一化三源（combat_kind 直映射 / unit_subtype 分流 / card_id 前缀 + card_tags 工程证据）
#   2) 5 对搭档 激活/失活（事件驱动 refresh；numeric 对称记账 + onetime 守卫 + 激活态查询）
#   3) PAIR_SYNERGIES 数据完整性
#   4) --script 环境静态查询安全（query_pair_active 无 BattleManager → false）
#
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/unit/pair_synergy_smoke.gd
extends SceneTree

const UnitRoles = preload("res://data/unit_roles.gd")
const PairEngineScript = preload("res://scripts/battle/pair_synergy_engine.gd")
const ComboTactics = preload("res://data/combo_tactics.gd")


## 测试用假 stats（带 meta 的 Resource；字段覆盖角色归一化 + 数值记账所需）
class DummyStats extends Resource:
	var card_id: String = ""
	var platform_card_id: String = ""
	var combat_kind: int = 0
	var unit_subtype: int = 0
	var attack_air_speed: float = 1.0
	var defense_light: float = 10.0
	var deploy_delay_bonus: float = 0.0
	var weapon_slots: Array = []

	func _init(p_card: String = "", p_kind: int = 0, p_sub: int = 0) -> void:
		card_id = p_card
		platform_card_id = p_card
		combat_kind = p_kind
		unit_subtype = p_sub


## 测试用假单位（真 Node，带 stats 属性，可入组被引擎扫描）
class DummyUnit extends Node:
	var stats: Resource = null
	var hp: float = 100.0
	var is_player: bool = true

	func _init(p_stats: Resource = null) -> void:
		stats = p_stats


func _initialize() -> void:
	var code := [0]
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		code[0] = 1
	var ok := func(msg: String) -> void:
		print("  [PASS] " + msg)

	print("═══════════════════════════════════════════════════════════")
	print("  v21 P2 搭档协同 + 角色归一化验证")
	print("═══════════════════════════════════════════════════════════")

	# ══════════ 1. 角色归一化三源 ══════════
	print("\n=== 1. resolve_role 三源归一化 ===")
	if UnitRoles.resolve_role("x_any", 1, 0) == UnitRoles.ROLE_ARMOR:
		ok.call("kind=ARMOR → ARMOR")
	else:
		fail.call("kind=ARMOR 归一失败")
	if UnitRoles.resolve_role("x_any", 3, 0) == UnitRoles.ROLE_AIR:
		ok.call("kind=AIR → AIR（子类不覆盖主类）")
	else:
		fail.call("kind=AIR 归一失败")
	if UnitRoles.resolve_role("x_any", 4, 0) == UnitRoles.ROLE_FORT:
		ok.call("kind=FORT → FORT")
	else:
		fail.call("kind=FORT 归一失败")
	if UnitRoles.resolve_role("art_heavy_mortar", 2, 1) == UnitRoles.ROLE_ARTILLERY:
		ok.call("支援主类+炮兵子类 → ARTILLERY")
	else:
		fail.call("炮兵子类归一失败")
	if UnitRoles.resolve_role("aa_flak_turret", 0, 4) == UnitRoles.ROLE_ANTI_AIR:
		ok.call("轻装主类+防空子类 → ANTI_AIR")
	else:
		fail.call("防空子类归一失败")
	if UnitRoles.resolve_role("ww1_inf_cavalry", 0, 0) == UnitRoles.ROLE_RECON:
		ok.call("前缀 ww1_inf_cavalry → RECON")
	else:
		fail.call("侦察前缀归一失败")
	if UnitRoles.resolve_role("mod_inf_scout_drone", 0, 0) == UnitRoles.ROLE_RECON:
		ok.call("前缀 mod_inf_scout_drone → RECON")
	else:
		fail.call("侦察无人机前缀归一失败")
	if UnitRoles.resolve_role("ww1_sup_engineer", 2, 2, {"card_tags": ["engineer"]}) == UnitRoles.ROLE_ENGINEER:
		ok.call("支援子类+engineer 标签 → ENGINEER")
	else:
		fail.call("工程标签归一失败")
	if UnitRoles.resolve_role("ww1_sup_engineer", 2, 2, {"is_engineer": true}) == UnitRoles.ROLE_ENGINEER:
		ok.call("支援子类+is_engineer meta → ENGINEER")
	else:
		fail.call("工程 meta 归一失败")
	if UnitRoles.resolve_role("ww1_sup_engineer", 2, 2) == UnitRoles.ROLE_ENGINEER:
		ok.call("硬前缀 ww1_sup_engineer → ENGINEER")
	else:
		fail.call("工程硬前缀归一失败")
	if UnitRoles.resolve_role("sup_medic", 2, 2) == UnitRoles.ROLE_UNIVERSAL:
		ok.call("支援子类无工程证据 → UNIVERSAL（兜底）")
	else:
		fail.call("支援兜底归一失败")
	if UnitRoles.resolve_role("plain_rifle", 0, 0) == UnitRoles.ROLE_INFANTRY:
		ok.call("轻装无前缀 → INFANTRY")
	else:
		fail.call("步兵归一失败")
	if UnitRoles.resolve_role("unknown", 9, 9) == UnitRoles.ROLE_UNIVERSAL:
		ok.call("未知 kind → UNIVERSAL（保守兜底）")
	else:
		fail.call("未知 kind 兜底失败")
	# resolve_role_cached 缓存
	var cached_st := DummyStats.new("ww1_inf_cavalry", 0, 0)
	var r1: int = UnitRoles.resolve_role_cached(cached_st)
	if r1 == UnitRoles.ROLE_RECON and int(cached_st.get_meta(UnitRoles.META_UNIT_ROLE, -1)) == UnitRoles.ROLE_RECON:
		ok.call("resolve_role_cached 写缓存 meta")
	else:
		fail.call("resolve_role_cached 缓存失败，role=%d" % r1)
	cached_st.combat_kind = 1
	if UnitRoles.resolve_role_cached(cached_st) == UnitRoles.ROLE_RECON:
		ok.call("缓存命中（建卡后属性变更不影响已缓存角色）")
	else:
		fail.call("缓存未生效")

	# ══════════ 2. PAIR_SYNERGIES 数据完整性 ══════════
	print("\n=== 2. PAIR_SYNERGIES 数据 ===")
	if ComboTactics.PAIR_SYNERGIES.size() == 5:
		ok.call("5 对搭档定义")
	else:
		fail.call("搭档数量应为 5，实得 %d" % ComboTactics.PAIR_SYNERGIES.size())
	for pid in ["pair_recon_artillery", "pair_engineer_infantry", "pair_aa_air", "pair_armor_infantry", "pair_fort_support"]:
		var d: Dictionary = ComboTactics.PAIR_SYNERGIES.get(pid, {})
		if d.is_empty() or String(d.get("name", "")).is_empty() or (d.get("pair", []) as Array).size() != 2 or String(d.get("kind", "")).is_empty():
			fail.call("搭档 %s 定义不完整" % pid)
		else:
			ok.call("搭档 %s（%s / %s）" % [pid, d.get("name"), d.get("kind")])

	# ══════════ 3. 静态查询 --script 安全性 ══════════
	print("\n=== 3. 静态查询安全（无 BattleManager 环境）===")
	if PairEngineScript.query_pair_active("pair_aa_air") == false:
		ok.call("query_pair_active 无 BattleManager → false")
	else:
		fail.call("query_pair_active 在测试环境应返回 false")
	if PairEngineScript.get_pair_deploy_delay_bonus(null) == 0.0:
		ok.call("get_pair_deploy_delay_bonus(null) → 0.0")
	else:
		fail.call("get_pair_deploy_delay_bonus 应安全返回 0")

	# ══════════ 4. 五对搭档 激活/失活 ══════════
	print("\n=== 4. 搭档激活/失活（事件驱动 refresh）===")
	# v21 P2 教训：--script 模式 _initialize 期间 root 尚未入树（add_child 的节点
	# 组不注册）。等一帧让场景树激活后再挂载测试节点。
	await process_frame

	# —— 4.1 防空×空中（numeric：attack_air_speed ×1.15，对称撤销）——
	var eng := PairEngineScript.new()
	eng.setup(null)
	var aa_st := DummyStats.new("aa_flak_a", 0, 4)        # ANTI_AIR
	var air_st := DummyStats.new("air_plane_a", 3, 0)     # AIR
	var aa_base: float = 1.0
	var aa_node := _mount(DummyUnit.new(aa_st))
	var air_node := _mount(DummyUnit.new(air_st))
	eng.refresh(null)
	if eng.is_pair_active("pair_aa_air"):
		ok.call("防空×空中 激活")
	else:
		fail.call("防空×空中未激活")
	if absf(float(aa_st.attack_air_speed) - aa_base * 1.15) < 0.0001:
		ok.call("AA 攻速 ×1.15 已应用（1.0 → %.4f）" % float(aa_st.attack_air_speed))
	else:
		fail.call("AA 攻速未正确应用，实得 %.4f" % float(aa_st.attack_air_speed))
	if aa_st.has_meta(PairEngineScript.META_PAIR_BUFF):
		ok.call("H11 记账 meta 已写（_pair_buff_applied）")
	else:
		fail.call("记账 meta 缺失")
	# 拆散（空中单位死亡下场）→ 对称撤销
	root.remove_child(air_node)
	air_node.free()
	eng.refresh(null)
	if not eng.is_pair_active("pair_aa_air") and absf(float(aa_st.attack_air_speed) - aa_base) < 0.0001:
		ok.call("搭档拆散 → 激活态清除 + 攻速对称恢复原值")
	else:
		fail.call("撤销失败：active=%s speed=%.4f" % [str(eng.is_pair_active("pair_aa_air")), float(aa_st.attack_air_speed)])
	root.remove_child(aa_node)
	aa_node.free()

	# —— 4.2 工程×步兵（onetime：步兵 defense_light +20%，单单位一次性守卫）——
	var eng2 := PairEngineScript.new()
	eng2.setup(null)
	var inf_st := DummyStats.new("inf_rifle_a", 0, 0)     # INFANTRY
	var eng_st := DummyStats.new("ww1_sup_engineer", 2, 2)  # ENGINEER
	var inf_node := _mount(DummyUnit.new(inf_st))
	var eng_node := _mount(DummyUnit.new(eng_st))
	var inf_base: float = 10.0
	eng2.refresh(null)
	if eng2.is_pair_active("pair_engineer_infantry"):
		ok.call("工程×步兵 激活")
	else:
		fail.call("工程×步兵未激活")
	if absf(float(inf_st.defense_light) - inf_base * 1.2) < 0.0001:
		ok.call("步兵 defense_light +20pct（10 → %.2f）" % float(inf_st.defense_light))
	else:
		fail.call("步兵防御未应用，实得 %.2f" % float(inf_st.defense_light))
	# 重复 refresh 不叠加（一次性守卫）
	eng2.refresh(null)
	eng2.refresh(null)
	if absf(float(inf_st.defense_light) - inf_base * 1.2) < 0.0001:
		ok.call("重复 refresh 不叠加（onetime 守卫生效）")
	else:
		fail.call("onetime 被重复叠加，实得 %.2f" % float(inf_st.defense_light))
	root.remove_child(inf_node)
	inf_node.free()
	root.remove_child(eng_node)
	eng_node.free()

	# —— 4.3 装甲×轻装（deploy 延迟走消费点静态查询；不写数值记账）——
	var eng3 := PairEngineScript.new()
	eng3.setup(null)
	var arm_st := DummyStats.new("arm_tank_a", 1, 0)      # ARMOR
	var inf2_st := DummyStats.new("inf_smg_a", 0, 0)      # INFANTRY
	var arm_node := _mount(DummyUnit.new(arm_st))
	var inf2_node := _mount(DummyUnit.new(inf2_st))
	eng3.refresh(null)
	if eng3.is_pair_active("pair_armor_infantry"):
		ok.call("装甲×轻装 激活")
	else:
		fail.call("装甲×轻装未激活")
	if not arm_st.has_meta(PairEngineScript.META_PAIR_BUFF):
		ok.call("deploy 对不改写 stats（消费点读取语义）")
	else:
		fail.call("deploy 对不应写 stats 记账")
	# 静态查询在测试环境（无 BattleManager）恒 0——语义见报告
	if PairEngineScript.get_pair_deploy_delay_bonus(arm_st) == 0.0:
		ok.call("deploy 加成静态查询测试环境安全返回 0")
	else:
		fail.call("deploy 静态查询应返回 0（无 BattleManager）")
	root.remove_child(arm_node)
	arm_node.free()
	root.remove_child(inf2_node)
	inf2_node.free()

	# —— 4.4 堡垒×支援（aura_range 声明型：仅激活态）——
	var eng4 := PairEngineScript.new()
	eng4.setup(null)
	var fort_st := DummyStats.new("for_bunker_a", 4, 0)   # FORT
	var sup_st := DummyStats.new("sup_medic_a", 2, 2)     # UNIVERSAL（支援非工程）
	var fort_node := _mount(DummyUnit.new(fort_st))
	var sup_node := _mount(DummyUnit.new(sup_st))
	eng4.refresh(null)
	if eng4.is_pair_active("pair_fort_support"):
		ok.call("堡垒×支援 激活（FORT × UNIVERSAL）")
	else:
		fail.call("堡垒×支援未激活")
	# 拆散
	root.remove_child(sup_node)
	sup_node.free()
	eng4.refresh(null)
	if not eng4.is_pair_active("pair_fort_support"):
		ok.call("堡垒×支援 拆散 → 失活")
	else:
		fail.call("堡垒×支援失活失败")
	root.remove_child(fort_node)
	fort_node.free()

	# —— 4.5 侦察×火炮（mark：激活态 + 测试环境静态消费安全）——
	var eng5 := PairEngineScript.new()
	eng5.setup(null)
	var rec_st := DummyStats.new("ww1_inf_cavalry", 0, 0)   # RECON
	var art_st := DummyStats.new("art_howell_a", 2, 1)      # ARTILLERY
	var rec_node := _mount(DummyUnit.new(rec_st))
	var art_node := _mount(DummyUnit.new(art_st))
	eng5.refresh(null)
	if eng5.is_pair_active("pair_recon_artillery"):
		ok.call("侦察×火炮 激活")
	else:
		fail.call("侦察×火炮未激活")
	# 标记写入走静态查询（测试环境无 BattleManager → false，安全跳过）
	var tgt := _mount(DummyUnit.new(DummyStats.new("enemy_x", 1, 0)))
	tgt.get("stats").combat_kind = 1
	if PairEngineScript.try_apply_recon_artillery_mark(rec_node, tgt) == false:
		ok.call("标记写入静态查询无引擎实例 → false（安全跳过）")
	else:
		fail.call("标记写入应被静态查询拦截")
	if PairEngineScript.is_artillery_mark_crit(art_node, tgt) == false:
		ok.call("火炮必暴判定无标记 → false")
	else:
		fail.call("无标记不应判必暴")
	root.remove_child(rec_node)
	rec_node.free()
	root.remove_child(art_node)
	art_node.free()
	root.remove_child(tgt)
	tgt.free()

	# ══════════ 收尾 ══════════
	print("\n═══════════════════════════════════════════════════════════")
	if code[0] == 0:
		print("  ✅ 全部通过")
	else:
		print("  ❌ 存在失败项（见 [FAIL]）")
	print("═══════════════════════════════════════════════════════════")
	quit(int(code[0]))


## 挂到场景树根（组扫描要求节点在树内注册组）
func _mount(u: Node) -> Node:
	root.add_child(u)
	u.add_to_group("player_units")
	return u
