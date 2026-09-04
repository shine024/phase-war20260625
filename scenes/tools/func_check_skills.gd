extends Node

## 四系统技能效果链功能验证（敌我双方）
## A 玩家相位师技能树：解锁 → 合并效果 → 战斗侧消费函数数值
## B 玩家改造：安装 → 属性通道（防御 flat+pct / 攻速武器槽同步）
## C 势力技能：解锁 → 激活效果 → 注入函数数值
## D 敌方配装（敌侧改造）：全表数据有效性 + 通道数值
## E 敌方相位师：30 位战力计算 + 套路识别 + 效果键全被演出引擎识别
## 运行：godot --headless --rendering-driver opengl3 --path . res://scenes/tools/func_check_skills.tscn

const UST := preload("res://resources/unit_stats_table.gd")
const MPP := preload("res://scripts/master_platform_power.gd")
const EFL := preload("res://data/enemy_fixed_loadouts.gd")
const EPM := preload("res://data/enemy_phase_masters.gd")
const EPat := preload("res://data/enemy_phase_master_patterns.gd")
const EMST := preload("res://data/enemy_master_skill_tree.gd")
const EMI := preload("res://data/enemy_master_instruments.gd")
const BSS := preload("res://managers/battle/battle_spawn_system.gd")
const EMSE := preload("res://managers/battle/enemy_master_skill_engine.gd")

var passes := 0
var fails: Array = []

func _ready() -> void:
	await _run()
	print("════════════════════════════════════")
	print("[FuncCheck] PASS=%d FAIL=%d" % [passes, fails.size()])
	if not fails.is_empty():
		for f in fails:
			print("  ✗ ", f)
	print("════════════════════════════════════")
	get_tree().quit(1 if not fails.is_empty() else 0)

func check(cname: String, cond: bool, detail: String = "") -> void:
	if cond:
		passes += 1
		print("[PASS] ", cname)
	else:
		fails.append(cname + ((" :: " + detail) if detail != "" else ""))
		print("[FAIL] ", cname, " :: ", detail)

func _approx(a: float, b: float, tol: float = 0.01) -> bool:
	return absf(a - b) <= tol

func _run() -> void:
	await get_tree().process_frame
	var pmsm: Node = get_node_or_null("/root/PhaseMasterSkillManager")
	var bpm: Node = get_node_or_null("/root/BlueprintManager")
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	var brm: Node = get_node_or_null("/root/BasicResourceManager")
	var bag: Node = get_node_or_null("/root/IntelItemBag")
	check("ENV autoloads", pmsm != null and bpm != null and ir != null and fsm != null and brm != null and bag != null)
	if fails.size() > 0:
		return

	# ═══ A 玩家相位师技能树 ═══
	pmsm.add_bonus_points(30)
	var fx0: Dictionary = pmsm.get_active_effects()
	var cmd_ok: bool = pmsm.unlock_node("pms_cmd_0")
	var int_ok: bool = pmsm.unlock_node("pms_int_0")
	var exp_ok: bool = pmsm.unlock_node("pms_int_1a")
	check("A1 解锁成功(cmd_0/int_0/int_1a)", cmd_ok and int_ok and exp_ok,
		"%s/%s/%s" % [cmd_ok, int_ok, exp_ok])
	var fx: Dictionary = pmsm.get_active_effects()
	var sb: Dictionary = fx.get("stat_bonus", {})
	check("A2 stat_bonus 合并 atk×3=+5%",
		_approx(float(sb.get("atk_light", 0)), 0.05) and _approx(float(sb.get("atk_armor", 0)), 0.05)
		and _approx(float(sb.get("atk_air", 0)), 0.05), str(sb))
	check("A3 暴击 +5%", _approx(float(sb.get("crit_chance", 0)), 0.05), str(sb))
	check("A4 经验加成 +30%", _approx(float(fx.get("experience_bonus", 0)), 0.30), str(fx.get("experience_bonus")))
	# A5 战斗侧消费函数（出兵 _build_stats_cached 同款调用）
	var card_a: CardResource = ir.create_instance("cold_t72")
	var stats_a0: UnitStats = UST.build_stats_from_card(card_a, 2)
	var stats_a1: UnitStats = UST.build_stats_from_card(card_a, 2)
	var bss: RefCounted = BSS.new()
	bss._cached_autoload_phase_master_skill = pmsm
	bss._apply_skill_tree_stat_bonus(stats_a1)
	check("A5 战斗侧攻击乘区 ×1.05", _approx(stats_a1.attack_armor, stats_a0.attack_armor * 1.05, 0.51),
		"%.1f → %.1f" % [stats_a0.attack_armor, stats_a1.attack_armor])
	check("A6 战斗侧暴击 +0.05", _approx(stats_a1.crit_chance, minf(0.75, stats_a0.crit_chance + 0.05), 0.001),
		"%.3f → %.3f" % [stats_a0.crit_chance, stats_a1.crit_chance])

	# ═══ B 玩家改造 ═══
	brm.add_resource("nano_materials", 100000)
	bag.add_item("blueprint_arm_01_sloped_armor", 2)
	bag.add_item("blueprint_arm_08_autoloader", 2)
	var card_b: CardResource = ir.create_instance("cold_t72")
	var b0: UnitStats = UST.build_stats_from_card(card_b, 2)
	var r1: Dictionary = bpm.install_modification(card_b, "arm_01_sloped_armor")
	check("B1 倾斜装甲安装成功", bool(r1.get("success", false)), str(r1))
	var b1: UnitStats = UST.build_stats_from_card(card_b, 2)
	var expect_def: float = floorf((float(b0.defense_armor) + 15.0) * 1.08)
	check("B2 防御通道 flat+15 再 pct×1.08（int 截断）", _approx(float(b1.defense_armor), expect_def, 0.01),
		"%.1f → %.1f (期望 %.1f)" % [float(b0.defense_armor), float(b1.defense_armor), expect_def])
	var r2: Dictionary = bpm.install_modification(card_b, "arm_08_autoloader")
	check("B3 自动装弹机安装成功", bool(r2.get("success", false)), str(r2))
	var b2: UnitStats = UST.build_stats_from_card(card_b, 2)
	var spd0: float = _max_weapon_speed(b0)
	var spd2: float = _max_weapon_speed(b2)
	var iv0: float = _min_attack_interval(b0)
	var iv2: float = _min_attack_interval(b2)
	check("B4 攻速通道（武器槽提速或攻击间隔缩短）",
		spd2 > spd0 + 0.0001 or iv2 < iv0 - 0.0001,
		"spd %.3f→%.3f, interval %.3f→%.3f" % [spd0, spd2, iv0, iv2])
	check("B5 mods 记录 2 条改造", card_b.mods.size() == 2, str(card_b.mods.size()))

	# ═══ C 势力技能 ═══
	fsm.set_active_faction("iron_wall_corp")
	fsm.add_faction_skill_bonus_points("iron_wall_corp", 10)
	fsm.unlock_faction_skill("iron_wall_corp", "sk_iron_def1")
	var ffx: Dictionary = fsm.get_active_faction_skill_effects()
	check("C1 激活效果含 hp+8%", _approx(float(ffx.get("stat_bonus", {}).get("hp", 0)), 0.08), str(ffx))
	var c0: UnitStats = UST.build_stats_from_card(card_b, 2)
	var hp0: float = float(c0.max_hp)
	MPP._apply_faction_stat_bonus(c0, ffx.get("stat_bonus", {}))
	check("C2 HP 注入 ×1.08", _approx(float(c0.max_hp), hp0 * 1.08, 0.51),
		"%.1f → %.1f" % [hp0, float(c0.max_hp)])

	# ═══ C2+ 势力技能补验（deploy additive / reputation_bonus / shop_discount / xp_bonus）═══
	fsm.add_faction_skill_bonus_points("iron_wall_corp", 20)
	var dep_ok: bool = fsm.unlock_faction_skill("iron_wall_corp", "sk_iron_def2")
	var res3_ok: bool = fsm.unlock_faction_skill("iron_wall_corp", "sk_iron_res3")
	check("F1 快速部署+军工效率解锁", dep_ok and res3_ok, "%s/%s" % [dep_ok, res3_ok])
	var ffx2: Dictionary = fsm.get_active_faction_skill_effects()
	check("F2 deploy 桶并入 stat_bonus additive", int(ffx2.get("stat_bonus", {}).get("deploy_speed_add", 0)) == 1,
		str(ffx2.get("stat_bonus", {})))
	var c3: UnitStats = UST.build_stats_from_card(card_b, 2)
	var c3b: UnitStats = UST.build_stats_from_card(card_b, 2)
	bss._apply_active_faction_stat_bonus(c3b, ffx2.get("stat_bonus", {}))
	check("F3 部署速度 additive 3→4", int(c3b.deploy_speed) == int(c3.deploy_speed) + 1,
		"%d → %d" % [int(c3.deploy_speed), int(c3b.deploy_speed)])
	check("F4 shop_discount 读取 0.10",
		_approx(float(load("res://managers/faction/faction_skill_manager.gd").get_resource_value(fsm.faction_skill_states["iron_wall_corp"], "iron_wall_corp", "shop_discount")), 0.10, 0.001))
	var rep_before: int = fsm.get_faction_reputation("iron_wall_corp")
	fsm.add_faction_reputation("iron_wall_corp", 100)
	var rep_gain: int = fsm.get_faction_reputation("iron_wall_corp") - rep_before
	check("F5 声望加成 +25% 实效（100→125）", rep_gain == 125, "gained %d" % rep_gain)
	# xp_bonus（frontier_union 多方经营；不切换 active 势力，只验 resource 桶读取）
	fsm.add_faction_skill_bonus_points("frontier_union", 20)
	fsm.unlock_faction_skill("frontier_union", "sk_front_res2")
	check("F6 xp_bonus 读取 0.15",
		_approx(float(load("res://managers/faction/faction_skill_manager.gd").get_resource_value(fsm.faction_skill_states["frontier_union"], "frontier_union", "xp_bonus")), 0.15, 0.001))

	# ═══ G 技能树词条池 / unit_ability / set 通道 / 敌方 trait 数值 ═══
	var am: Node = get_node_or_null("/root/AffixManager")
	check("G0 AffixManager 可用", am != null)
	var card_g: CardResource = ir.create_instance("cold_t72")  # 先建实例（grant 遍历全实例）
	var int2_ok: bool = pmsm.unlock_node("pms_int_2")
	check("G1a pms_int_2 解锁", int2_ok)
	await get_tree().process_frame
	await get_tree().process_frame
	var gkey: String = "%s_0" % String(card_g.instance_id)
	check("G1b 实例获得基础词条（池 id 修复后）", int(am.get_affix_count(gkey)) > 0,
		"count=%d" % int(am.get_affix_count(gkey)))
	# G2 unit_ability：轻装暴击（先拍基线再解锁）。可构建池运行时挑 light 单位——
	# UCT 全集 231 行 ≠ DefaultCards 启动构建池 131 张，硬编码 id 会踩"找不到模板"。
	var DC := preload("res://data/default_cards.gd")
	var light_id := ""
	for bid in DC.get_all_blueprint_ids():
		var tpl: CardResource = DC.get_card_by_id(String(bid))
		if tpl != null and int(tpl.combat_kind) == 0:
			light_id = String(bid)
			break
	check("G2a 找到可构建轻装单位", light_id != "", light_id)
	var inf_card: CardResource = ir.create_instance(light_id)
	var st_pre: UnitStats = UST.build_stats_from_card(inf_card, 0)
	pmsm.unlock_node("pms_fp_0")
	var fp1b_ok: bool = pmsm.unlock_node("pms_fp_1b")
	var st_post: UnitStats = UST.build_stats_from_card(inf_card, 0)
	check("G2 轻装暴击 +0.10", fp1b_ok and _approx(float(st_post.crit_chance), minf(0.75, float(st_pre.crit_chance) + 0.10), 0.001),
		"%.3f → %.3f (ok=%s)" % [float(st_pre.crit_chance), float(st_post.crit_chance), fp1b_ok])
	# G3 敌方相位师 trait 数值落地（master_001 max_hp 2900 → ×1.435 clamp 前）
	var ESR := preload("res://data/enemy_stat_resolver.gd")
	var m1: Dictionary = EPM.get_master_by_id("enemy_master_001")
	var g3s: UnitStats = UST.build_stats_from_card(card_g, 2)
	var hp_pre: float = float(g3s.max_hp)
	ESR.apply_phase_master_to_unit_stats(g3s, m1.get("stats", {}))
	var hp_ratio: float = float(g3s.max_hp) / hp_pre
	check("G3 敌方 master stats 落地 HP×1.43±", hp_ratio > 1.30 and hp_ratio < 1.55,
		"ratio=%.3f" % hp_ratio)
	# G4 set 替换通道：更优才生效
	var reg_g: Node = get_node_or_null("/root/ModificationRegistry")
	var set_low: Dictionary = reg_g.apply_with_level({"attack_armor": 100.0}, [{"id": "arm_05_smoothbore", "level": 2, "enabled": true}], {"era": 2})
	var set_high: Dictionary = reg_g.apply_with_level({"attack_armor": 900.0}, [{"id": "arm_05_smoothbore", "level": 2, "enabled": true}], {"era": 2})
	check("G4a set 通道 100→620（更优生效）", _approx(float(set_low.get("attack_armor", 0)), 620.0, 1.0),
		"→ %.1f" % float(set_low.get("attack_armor", 0)))
	check("G4b set 通道 900 保持（不更优不生效）", _approx(float(set_high.get("attack_armor", 0)), 900.0, 1.0),
		"→ %.1f" % float(set_high.get("attack_armor", 0)))
	# G5 时代门行为存档：后端 install 不设时代硬门（UI get_installable_mods_for_card 过滤为准）
	var ww1_card: CardResource = ir.create_instance("ww1_arm_ft17")
	bag.add_item("blueprint_arm_08_autoloader", 1)
	var era_res: Dictionary = bpm.install_modification(ww1_card, "arm_08_autoloader")
	print("[FuncCheck][存档] 跨时代直装 arm_08→ft17 success=%s（时代带无独立硬门，被稀有度战力档门槛间接拦下；时代过滤以 UI get_installable_mods_for_card 为准）" % bool(era_res.get("success", false)))

	# ═══ D 敌方配装（敌侧改造）═══
	var ids: Array = EFL.LOADOUTS.keys()
	check("D1 配装表非空(117 档)", ids.size() >= 100, str(ids.size()))
	var bad_ids: Array = []
	var bad_keys: Array = []
	var empty_cut3: Array = []
	for mid in ids:
		for mid_mod in EFL.get_mods_for_tier(String(mid), 3):
			var md: Dictionary = load("res://scripts/systems/modification_registry.gd").get_data(String(mid_mod))
			if md.is_empty():
				bad_ids.append(String(mid_mod))
				continue
			var eff: Dictionary = md.get("effects", {})
			if eff.is_empty():
				var le: Dictionary = md.get("level_effects", {})
				var lks: Array = le.keys()
				if not lks.is_empty():
					eff = le[int(lks[lks.size() - 1])]
			var hit := false
			for k in eff.keys():
				if EFL.LOADOUT_MOD_SUPPORTED_KEYS.has(String(k)):
					hit = true
					break
			if not hit:
				bad_keys.append(String(mid) + ":" + String(mid_mod))
		if EFL.get_mods_for_tier(String(mid), 3).is_empty():
			empty_cut3.append(String(mid))
	check("D2 配装 mod id 全部注册", bad_ids.is_empty(), str(bad_keys.size()) + str(bad_ids))
	check("D3 每档条目至少 1 个受支持效果键", bad_keys.is_empty() and empty_cut3.is_empty(),
		"badkeys=%d empty=%s" % [bad_keys.size(), str(empty_cut3)])
	# D4 通道数值：敌方同款 apply_with_level（era 上下文）
	var reg: Node = get_node_or_null("/root/ModificationRegistry")
	var base: Dictionary = {"defense_armor": 100.0}
	var applied: Dictionary = reg.apply_with_level(base, [{"id": "arm_01_sloped_armor", "level": 2, "enabled": true}], {"era": 2})
	check("D4 敌方通道 level2 flat25+pct12 → 140", _approx(float(applied.get("defense_armor", 0)), 140.0, 1.5),
		"100 → %.1f" % float(applied.get("defense_armor", 0)))

	# ═══ E 敌方相位师 ═══
	var masters: Array = EPM.ENEMY_MASTERS
	check("E1 相位师 30 位", masters.size() == 30, str(masters.size()))
	var engine: RefCounted = EMSE.new()
	var no_power: Array = []
	var bad_pattern: Array = []
	var unknown_spells: Array = []
	var unknown_traits: Array = []
	# v26.14: 特性键消费方白名单——数值键走 driver trait 战斗化（get_trait_stat_mods），
	# 机制键走 engine（_apply_passive_buffs/_tick_aura_damage/_tick_aura_heal/on_boss_destroyed）。
	# self_damage_aura / life_energy_drain / time_based_hp_drain 本轮补齐了引擎分支。
	var TRAIT_KNOWN: Array = [
		"atk_light", "atk_armor", "atk_air", "def_light", "def_armor", "def_air",
		"hp", "crit_chance", "dodge_chance", "attack_speed", "attack_interval",
		"lightning_thorn", "lightning_aura"]
	var MECH_KNOWN: Array = [
		"damage_aura", "max_hp_drain", "entropy_drain", "self_damage_aura",
		"life_energy_drain", "time_based_hp_drain", "massive_heal_aura", "healing_aura",
		"death_explosion", "cheat_death", "death_shield", "high_energy_bonus",
		"overcharge", "high_energy_attack_speed", "thorn",
		"energy_shield", "dome_barrier", "plate_shield", "ward_bulwark"]
	TRAIT_KNOWN.append_array(MECH_KNOWN)  # trait 收集器会并入 mech 节点效果名
	for m in masters:
		var mid: String = String(m.get("id", ""))
		if mid.is_empty():
			continue
		var pat: String = EPat.get_pattern(m)
		if not (pat in ["iron_bastion", "inferno_furnace", "thunder_cataclysm", "void_devour", "synergy_hybrid", "omni_ultimate"]):
			bad_pattern.append(mid + ":" + pat)
		for k in EPat._collect_spell_effect_keys(m):
			var ks: String = String(k)
			var recognized: bool = engine._is_cinematic_apocalypse(ks) or engine._is_cinematic_inferno(ks) or engine._is_cinematic_chain(ks) or engine._is_single_target_effect(ks) or engine._is_summon_effect(ks) or engine._is_debuff_effect(ks) or engine._is_shield_effect(ks)
			if not recognized and not (ks in MECH_KNOWN):
				unknown_spells.append(mid + ":" + ks)
		for k2 in EPat._collect_trait_effect_keys(m):
			if not (String(k2) in TRAIT_KNOWN):
				unknown_traits.append(mid + ":" + String(k2))
	check("E2 套路识别全覆盖", bad_pattern.is_empty(), str(bad_pattern))
	check("E3a 大招效果键全被演出引擎识别", unknown_spells.is_empty(), str(unknown_spells))
	check("E3b 特性键全有消费方", unknown_traits.is_empty(), str(unknown_traits))
	# E4 战力计算抽样（platforms 来自 equipment.platforms，era 派生同 evaluator）
	for i in range(mini(5, masters.size())):
		var m2: Dictionary = masters[i]
		var mid2: String = String(m2.get("id", ""))
		var era2: int = int(m2.get("era", -1))
		if era2 < 0:
			var us2: int = mid2.rfind("_")
			era2 = clampi((int(mid2.substr(us2 + 1)) - 1) / 6, 0, 4) if us2 >= 0 else 0
		var plats: Array = m2.get("equipment", {}).get("platforms", [])
		if plats.is_empty():
			plats = EPM.get_enriched_equipment(mid2).get("platforms", [])
		var pwr: float = 0.0
		for pid in plats:
			pwr += MPP.compute_enemy_platform_power(String(pid), m2, era2)
		if pwr <= 0.0:
			no_power.append(mid2)
	check("E4 战力计算抽样>0", no_power.is_empty(), str(no_power))

func _max_weapon_speed(stats: UnitStats) -> float:
	var mx := 0.0
	for ws in stats.weapon_slots:
		if ws != null and ws.enabled and "attack_speed" in ws:
			mx = maxf(mx, float(ws.attack_speed))
	return mx

func _min_attack_interval(stats: UnitStats) -> float:
	var mn := INF
	for ws in stats.weapon_slots:
		if ws != null and "attack_interval" in ws:
			mn = minf(mn, float(ws.attack_interval))
	return mn
