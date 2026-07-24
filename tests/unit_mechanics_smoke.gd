# v8 兵种固定机制 smoke test（无 GdUnit 依赖）
# 验证 apply_combat_kind_modifiers 注入的 8 个兵种固定机制字段正确写入
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/unit_mechanics_smoke.gd
extends SceneTree

const UnitStats = preload("res://resources/unit_stats.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const GC = preload("res://resources/game_constants.gd")

var _failures: int = 0


func _initialize() -> void:
	print("=== v8 兵种固定机制 smoke test ===")
	_test_infantry_urban_defense()
	_test_recon_stealth_mark()
	_test_armor_crush_bonus()
	_test_fort_shelter_aura()
	_test_artillery_counter_battery()
	_test_anti_air_blockade()
	_test_engineer_siege()
	_test_air_assault_mark()
	_test_recon_prefix_matching()
	_test_attack_vs_light_bonus()
	_test_attack_vs_air_bonus()
	if _failures == 0:
		print("\n[ALL PASS] 8 兵种固定机制 smoke test 全部通过")
		quit(0)
	else:
		print("\n[FAIL] %d 项断言失败" % _failures)
		quit(1)


## 构造一个最小 UnitStats 用于测试 apply_combat_kind_modifiers
func _make_stats(combat_kind: int, subtype: int, card_id: String) -> UnitStats:
	var s := UnitStats.new()
	s.combat_kind = combat_kind
	s.unit_subtype = subtype
	s.card_id = card_id
	s.max_hp = 100.0
	return s


func _check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  [PASS] %s %s" % [name, detail])
	else:
		print("  [FAIL] %s %s" % [name, detail])
		_failures += 1


## 机制1：步兵巷战掩蔽——非侦察 LIGHT/NONE 应写入 urban_defense_bonus 0.15
func _test_infantry_urban_defense() -> void:
	print("\n[1] 步兵巷战掩蔽")
	var s := _make_stats(GC.CombatKind.LIGHT, GC.UnitSubType.NONE, "ww1_inf_rifleman")
	UnitStatsTable.apply_combat_kind_modifiers(s)
	_check("步兵 urban_defense_bonus", is_equal_approx(s.urban_defense_bonus, 0.15),
		"got %s" % str(s.urban_defense_bonus))
	_check("步兵无潜入标记", not s.has_meta("is_recon_unit"))


## 机制2：侦察潜入开局——侦察前缀卡应设 is_recon_unit meta，不写 urban_defense_bonus
func _test_recon_stealth_mark() -> void:
	print("\n[2] 侦察潜入开局")
	for prefix in ["ww1_inf_cavalry", "cold_spetsnaz", "mod_ranger", "fut_spectre", "fut_inf_scout_mech", "mod_inf_scout_drone"]:
		var s := _make_stats(GC.CombatKind.LIGHT, GC.UnitSubType.NONE, prefix + "_test")
		UnitStatsTable.apply_combat_kind_modifiers(s)
		_check("侦察[%s] is_recon_unit meta" % prefix, bool(s.get_meta("is_recon_unit", false)))
		_check("侦察[%s] 无 urban_defense_bonus" % prefix, s.urban_defense_bonus < 0.001)


## 机制3：装甲碾压——ARMOR/NONE 应写入 attack_light_bonus 0.20
func _test_armor_crush_bonus() -> void:
	print("\n[3] 装甲碾压")
	var s := _make_stats(GC.CombatKind.ARMOR, GC.UnitSubType.NONE, "ww2_pz_panzer")
	UnitStatsTable.apply_combat_kind_modifiers(s)
	_check("装甲 attack_light_bonus", is_equal_approx(s.attack_light_bonus, 0.20),
		"got %s" % str(s.attack_light_bonus))


## 机制4：堡垒阵地坚守——FORT/FORT 应写 damage_reduction 0.30 + fort_shelter_aura 0.10
func _test_fort_shelter_aura() -> void:
	print("\n[4] 堡垒阵地坚守")
	var s := _make_stats(GC.CombatKind.FORT, GC.UnitSubType.FORT, "ww1_fort_bunker")
	UnitStatsTable.apply_combat_kind_modifiers(s)
	_check("堡垒 damage_reduction", is_equal_approx(s.damage_reduction, 0.30),
		"got %s" % str(s.damage_reduction))
	_check("堡垒 fort_shelter_aura", is_equal_approx(s.fort_shelter_aura, 0.10),
		"got %s" % str(s.fort_shelter_aura))
	_check("堡垒 fort_shelter_radius 默认", is_equal_approx(s.fort_shelter_radius, 250.0))


## 机制5：火炮反炮兵——SUPPORT/ARTILLERY 应写 has_counter_battery + counter_battery_shots=3
func _test_artillery_counter_battery() -> void:
	print("\n[5] 火炮反炮兵")
	var s := _make_stats(GC.CombatKind.SUPPORT, GC.UnitSubType.ARTILLERY, "ww1_art_howitzer")
	UnitStatsTable.apply_combat_kind_modifiers(s)
	_check("火炮 has_counter_battery", s.has_counter_battery)
	_check("火炮 counter_battery_shots", s.counter_battery_shots == 3,
		"got %d" % s.counter_battery_shots)


## 机制6：防空空域封锁——SUPPORT/ANTI_AIR 应写 attack_air_bonus 0.25 + is_anti_air_unit meta
func _test_anti_air_blockade() -> void:
	print("\n[6] 防空空域封锁")
	var s := _make_stats(GC.CombatKind.SUPPORT, GC.UnitSubType.ANTI_AIR, "ww2_aa_flak")
	UnitStatsTable.apply_combat_kind_modifiers(s)
	_check("防空 attack_air_bonus", is_equal_approx(s.attack_air_bonus, 0.25),
		"got %s" % str(s.attack_air_bonus))
	_check("防空 is_anti_air_unit meta", bool(s.get_meta("is_anti_air_unit", false)))


## 机制7：工兵爆破专精——SUPPORT/SUPPORT 应写 siege_bonus_pct 0.02
func _test_engineer_siege() -> void:
	print("\n[7] 工兵爆破专精")
	var s := _make_stats(GC.CombatKind.SUPPORT, GC.UnitSubType.SUPPORT, "ww1_eng_sapper")
	UnitStatsTable.apply_combat_kind_modifiers(s)
	_check("工兵 siege_bonus_pct", is_equal_approx(s.siege_bonus_pct, 0.02),
		"got %s" % str(s.siege_bonus_pct))


## 机制8：空中突袭击速——AIR 应设 is_air_assault meta
func _test_air_assault_mark() -> void:
	print("\n[8] 空中突袭击速")
	var s := _make_stats(GC.CombatKind.AIR, GC.UnitSubType.NONE, "ww2_air_fighter")
	UnitStatsTable.apply_combat_kind_modifiers(s)
	_check("空中 is_air_assault meta", bool(s.get_meta("is_air_assault", false)))


## 侦察前缀匹配——_RECON_PREFIXES 6 个前缀应命中，非侦察卡不命中
func _test_recon_prefix_matching() -> void:
	print("\n[9] 侦察前缀匹配 _is_recon_card")
	_check("ww1_inf_cavalry 命中", UnitStatsTable._is_recon_card("ww1_inf_cavalry_x"))
	_check("cold_spetsnaz 命中", UnitStatsTable._is_recon_card("cold_spetsnaz_e"))
	_check("mod_ranger 命中", UnitStatsTable._is_recon_card("mod_ranger_01"))
	_check("步兵卡不命中", not UnitStatsTable._is_recon_card("ww1_inf_rifleman"))
	_check("空 id 不命中", not UnitStatsTable._is_recon_card(""))


## get_attack_vs LIGHT 加成——装甲对 LIGHT 伤害应叠加 attack_light_bonus
func _test_attack_vs_light_bonus() -> void:
	print("\n[10] get_attack_vs LIGHT 加成")
	var attacker := UnitStats.new()
	attacker.attack_light = 100.0
	attacker.attack_light_bonus = 0.20  # 装甲碾压
	attacker.combat_kind = GC.CombatKind.ARMOR
	var dmg := preload("res://scripts/battle/attack_calculator.gd").get_attack_vs(attacker, GC.CombatKind.LIGHT)
	_check("装甲对LIGHT 100×1.2=120", is_equal_approx(dmg, 120.0), "got %s" % str(dmg))
	# SUPPORT 也走 attack_light（含加成）
	var dmg_sup := preload("res://scripts/battle/attack_calculator.gd").get_attack_vs(attacker, GC.CombatKind.SUPPORT)
	_check("装甲对SUPPORT 100×1.2=120", is_equal_approx(dmg_sup, 120.0), "got %s" % str(dmg_sup))


## get_attack_vs AIR 加成——防空对 AIR 伤害应叠加 attack_air_bonus
func _test_attack_vs_air_bonus() -> void:
	print("\n[11] get_attack_vs AIR 加成")
	var attacker := UnitStats.new()
	attacker.attack_air = 80.0
	attacker.attack_air_bonus = 0.25  # 防空空域封锁
	attacker.combat_kind = GC.CombatKind.SUPPORT
	var dmg := preload("res://scripts/battle/attack_calculator.gd").get_attack_vs(attacker, GC.CombatKind.AIR)
	_check("防空对AIR 80×1.25=100", is_equal_approx(dmg, 100.0), "got %s" % str(dmg))
