extends SceneTree
## tests/card_data_reorg_verify_20260817.gd
## 2026-08-17 数据全面整理验证：飞机链重标/子类推断修复/ECM前缀收紧/power重标。
## 运行：godot --headless --path . --script tests/card_data_reorg_verify_20260817.gd

const UCT = preload("res://data/unified_card_table.gd")
const GC = preload("res://resources/game_constants.gd")
const UST = preload("res://resources/unit_stats_table.gd")

var fails: int = 0
var passes: int = 0

func _check(desc: String, cond: bool) -> void:
	if cond:
		passes += 1
	else:
		fails += 1
		push_error("[FAIL] " + desc)
	print(("[PASS] " if cond else "[FAIL] ") + desc)

func _initialize() -> void:
	print("===== 1. 表完整性 =====")
	var all: Array = UCT.get_all_entries()
	_check("统一表条目数 223（无丢失）", all.size() == 223)
	var ids: Array = UCT.get_all_card_ids()
	var seen: Dictionary = {}
	var dup: bool = false
	for i in ids:
		if seen.has(i):
			dup = true
		seen[i] = true
	_check("card_id 无重复", not dup and ids.size() == 223)

	print("===== 2. 子类推断修复（玩家/缴获卡路径）=====")
	var sub_expect := {
		"ww1_37mm": GC.UnitSubType.ANTI_AIR,
		"cold_sup_zsu23": GC.UnitSubType.ANTI_AIR,
		"mod_sup_m6": GC.UnitSubType.ANTI_AIR,
		"mod_inf_patriot": GC.UnitSubType.ANTI_AIR,
		"fut_aa_hover": GC.UnitSubType.ANTI_AIR,
		"ww1_105mm": GC.UnitSubType.ARTILLERY,
		"mod_arty_m270": GC.UnitSubType.ARTILLERY,
		"fut_howitzer": GC.UnitSubType.ARTILLERY,
		"ww1_sup_engineer": GC.UnitSubType.SUPPORT,
		"ww1_mg08": GC.UnitSubType.SUPPORT,
		"ww2_mg42": GC.UnitSubType.SUPPORT,
		"ww1_sup_mg_nest": GC.UnitSubType.SUPPORT,
		"ww1_mp18": GC.UnitSubType.NONE,
		"cold_mig21": GC.UnitSubType.NONE,
		"ww1_fort_pillbox": GC.UnitSubType.FORT,
	}
	for cid: String in sub_expect:
		var c = UCT.build_card_resource(cid)
		if c == null:
			_check("build_card_resource(%s) 非空" % cid, false)
			continue
		var label := {0: "NONE", 1: "ARTILLERY", 2: "SUPPORT", 3: "FORT", 4: "ANTI_AIR"}
		_check("%s 子类=%s（工兵/机枪例外+防空/火炮分流生效）" % [cid, label[sub_expect[cid]]],
			c.unit_subtype == sub_expect[cid])

	print("===== 3. 固定机制经 build_stats_from_card 落地 =====")
	var s_zsu = UST.build_stats_from_card(UCT.build_card_resource("cold_sup_zsu23"))
	_check("zsu23 防空封锁 +25% 对空（attack_air_bonus）", is_equal_approx(float(s_zsu.attack_air_bonus), 0.25))
	_check("zsu23 is_anti_air_unit meta", bool(s_zsu.get_meta("is_anti_air_unit", false)))
	var s_arty = UST.build_stats_from_card(UCT.build_card_resource("ww1_105mm"))
	_check("105mm榴弹炮 反炮兵标记（has_counter_battery）", s_arty.has_counter_battery == true)
	var s_eng = UST.build_stats_from_card(UCT.build_card_resource("ww1_sup_engineer"))
	_check("工兵班 爆破专精 2%（siege_bonus_pct）", is_equal_approx(float(s_eng.siege_bonus_pct), 0.02))
	_check("工兵班 无反炮兵（子类误判已修）", s_eng.has_counter_battery == false)
	var s_mg = UST.build_stats_from_card(UCT.build_card_resource("ww1_mg08"))
	_check("MG08机枪巢 辅助子类（爆破2%而非反炮兵）",
		is_equal_approx(float(s_mg.siege_bonus_pct), 0.02) and s_mg.has_counter_battery == false)
	var s_inf = UST.build_stats_from_card(UCT.build_card_resource("ww1_mp18"))
	_check("步兵巷战掩蔽 15%（urban_defense_bonus）", is_equal_approx(float(s_inf.urban_defense_bonus), 0.15))

	print("===== 4. ECM 前缀收紧 =====")
	var s_grow = UST.build_stats_from_card(UCT.build_card_resource("mod_sup_growler"))
	_check("EA-18G 电子战小组 获得 is_ecm（原零机制白板）", bool(s_grow.get_meta("is_ecm", false)))
	var s_nano = UST.build_stats_from_card(UCT.build_card_resource("fut_nano_drone"))
	_check("纳米修复机 不再误挂 is_ecm（治疗单位）", not bool(s_nano.get_meta("is_ecm", false)))
	var s_scout = UST.build_stats_from_card(UCT.build_card_resource("mod_inf_scout_drone"))
	_check("侦察无人机 不再误挂 is_ecm", not bool(s_scout.get_meta("is_ecm", false)))

	print("===== 5. 空天战机/飞机链数据 =====")
	var sf = UCT.get_entry("fut_space_fighter")
	_check("空天战机武器标签=空天导弹/粒子炮（原错为地狱火/舰炮）", String(sf.get("weapon_label")) == "空天导弹/粒子炮")
	_check("空天战机 w_armor=粒子炮/激光（原空空导弹打装甲）", String(sf.get("w_armor")) == "粒子炮/激光")
	_check("空天战机攻速 1.0/0.8/1.2（时序代差）",
		float(sf.get("atk_l_speed")) == 1.0 and float(sf.get("atk_a_speed")) == 0.8 and float(sf.get("atk_air_speed")) == 1.2)
	_check("空天战机移速 185（原160）", float(sf.get("base_speed")) == 185.0)
	var mg21 = UCT.get_entry("cold_mig21")
	_check("米格-21 w_air=空空导弹（原错为地狱火导弹/127mm舰炮）", String(mg21.get("w_air")) == "空空导弹")
	var ad = UCT.get_entry("fut_air_drone")
	_check("无人机群 HP 460（原240≈米格21）", int(ad.get("base_hp")) == 460)
	_check("无人机群 atk 135/115（原72/32）",
		int(ad.get("atk_l")) == 135 and int(ad.get("atk_a")) == 115)

	print("===== 6. power 重标 + 稀有度/能耗联动 =====")
	var power_expect := {
		"fut_air_heavy_carrier": 1250, "fut_air_regen_frame": 850, "fut_arm_titan_mk2": 1450,
		"fut_sup_bulwark": 950, "fut_inf_storm_rider": 800, "fut_swarm": 650,
	}
	for cid: String in power_expect:
		var e = UCT.get_entry(cid)
		_check("%s power=%d" % [cid, power_expect[cid]], int(e.get("power", -1)) == power_expect[cid])
	var c_titan = UCT.build_card_resource("fut_arm_titan_mk2")
	_check("泰坦Mk.II 稀有度保持 legendary（power≤1500）", c_titan.rarity == "legendary")
	_check("泰坦Mk.II 能耗=14（随power联动，原4）", int(c_titan.energy_cost) == 14)
	var c_swarm = UCT.build_card_resource("fut_swarm")
	_check("蜂群无人机 能耗=7（原13，比空天战机还贵的bug已修）", int(c_swarm.energy_cost) == 7)

	print("===== 7. 全表构建 + 时序合法性（windup+active < 1/speed）=====")
	var bad_timing: Array = []
	var build_fail: Array = []
	for cid: String in UCT.get_all_card_ids():
		var card = UCT.build_card_resource(cid)
		if card == null:
			build_fail.append(cid)
			continue
		var pairs := [
			[card.attack_light_speed, card.attack_light_windup, card.attack_light_active],
			[card.attack_armor_speed, card.attack_armor_windup, card.attack_armor_active],
			[card.attack_air_speed, card.attack_air_windup, card.attack_air_active],
		]
		for p in pairs:
			var spd: float = float(p[0])
			if spd <= 0.0:
				continue
			if float(p[1]) + float(p[2]) >= 1.0 / spd:
				bad_timing.append("%s(speed=%.2f w+a=%.3f)" % [cid, spd, float(p[1]) + float(p[2])])
	_check("223 卡全部可构建 CardResource", build_fail.is_empty())
	_check("全表攻击时序合法（windup+active < 周期）", bad_timing.is_empty())
	if not bad_timing.is_empty():
		print("  违规: ", bad_timing.slice(0, 10))

	print("===== 8. 死数据删除确认 =====")
	_check("base_unit_stats.gd 已删除", not FileAccess.file_exists("res://data/base_unit_stats.gd"))

	print("")
	print("========== 结果: %d PASS / %d FAIL ==========" % [passes, fails])
	quit(1 if fails > 0 else 0)
