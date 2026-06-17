extends SceneTree
## v6.2 攻防维度对齐验证：确认 defense 按攻击者 combat_kind 选取 + 子类标记工作正常

const GC = preload("res://resources/game_constants.gd")

func _init() -> void:
	print("=== v6.2 攻防维度对齐验证 ===\n")
	var ok: bool = true

	# 1. GameConstants.UnitSubType 枚举存在
	var sub_vals: Array = [GC.UnitSubType.NONE, GC.UnitSubType.ARTILLERY, GC.UnitSubType.SUPPORT, GC.UnitSubType.FORT, GC.UnitSubType.ANTI_AIR]
	if sub_vals.size() != 5:
		print("❌ UnitSubType 枚举异常: ", sub_vals)
		ok = false
	else:
		print("✅ UnitSubType 枚举: NONE=%d ARTILLERY=%d SUPPORT=%d FORT=%d ANTI_AIR=%d" % [GC.UnitSubType.NONE, GC.UnitSubType.ARTILLERY, GC.UnitSubType.SUPPORT, GC.UnitSubType.FORT, GC.UnitSubType.ANTI_AIR])

	# 2. AttackCalculator.get_defense_vs 按 attacker combat_kind 选取
	var AttackCalculator = load("res://scripts/battle/attack_calculator.gd")
	var UnitStats = load("res://resources/unit_stats.gd")
	var target = UnitStats.new()
	target.defense_light = 10.0
	target.defense_armor = 20.0
	target.defense_air = 30.0

	# 攻击者=LIGHT → defense_light; ARMOR → defense_armor; AIR → defense_air
	var d_l = AttackCalculator.get_defense_vs(target, GC.CombatKind.LIGHT)
	var d_a = AttackCalculator.get_defense_vs(target, GC.CombatKind.ARMOR)
	var d_air = AttackCalculator.get_defense_vs(target, GC.CombatKind.AIR)
	# SUPPORT 归入 LIGHT，FORT 归入 ARMOR
	var d_sup = AttackCalculator.get_defense_vs(target, GC.CombatKind.SUPPORT)
	var d_fort = AttackCalculator.get_defense_vs(target, GC.CombatKind.FORT)

	if d_l == 10.0 and d_a == 20.0 and d_air == 30.0 and d_sup == 10.0 and d_fort == 20.0:
		print("✅ get_defense_vs 维度对齐: LIGHT/SUPPORT→%d, ARMOR/FORT→%d, AIR→%d" % [d_l, d_a, d_air])
	else:
		print("❌ get_defense_vs 错误: LIGHT=%d ARMOR=%d AIR=%d SUPPORT=%d FORT=%d" % [d_l, d_a, d_air, d_sup, d_fort])
		ok = false

	# 3. DefaultCards 子类推断：抽样校验
	# 注：DefaultCards.create_all() 依赖 ModificationRegistry autoload，
	# 在纯 SceneTree 脚本模式下 autoload 未初始化，故此处仅校验推断函数本身。
	var DefaultCards = load("res://data/default_cards.gd")
	var checks := {
		"ww1_mp18步兵": [GC.UnitSubType.NONE, DefaultCards._infer_unit_subtype(GC.CombatKind.LIGHT, 2, 35, 0, 0, "", "", "")],
		"ww1_m81火炮": [GC.UnitSubType.ARTILLERY, DefaultCards._infer_unit_subtype(GC.CombatKind.SUPPORT, 99, 120, 60, 0, "", "", "")],
		"ww1_37mm防空": [GC.UnitSubType.ANTI_AIR, DefaultCards._infer_unit_subtype(GC.CombatKind.SUPPORT, 5, 10, 24, 150, "", "", "")],
		"堡垒": [GC.UnitSubType.FORT, DefaultCards._infer_unit_subtype(GC.CombatKind.FORT, 7, 200, 0, 0, "", "", "")],
		"装甲": [GC.UnitSubType.NONE, DefaultCards._infer_unit_subtype(GC.CombatKind.ARMOR, 4, 25, 130, 0, "", "", "")],
	}
	var sample_ok := true
	for label in checks:
		var expected: int = checks[label][0]
		var actual: int = checks[label][1]
		if actual != expected:
			print("❌ 子类推断错误 %s: 期望=%d 实际=%d" % [label, expected, actual])
			sample_ok = false
	if sample_ok:
		print("✅ 子类推断: 步兵=NONE, 火炮(range99)=ARTILLERY, 防空(atk_air主)=ANTI_AIR, 堡垒=FORT, 装甲=NONE")
	ok = ok and sample_ok

	# 4. apply_combat_kind_modifiers 校验（直接调用静态函数，不需 autoload）
	var UnitStatsTable = load("res://resources/unit_stats_table.gd")
	# 4a 堡垒：defense_armor 应显著高于 defense_light
	var fort_stats = UnitStats.new()
	fort_stats.combat_kind = GC.CombatKind.FORT
	fort_stats.unit_subtype = GC.UnitSubType.FORT
	fort_stats.defense_armor = 60.0
	fort_stats.defense_light = 60.0
	fort_stats.max_hp = 1000.0
	var fort_hp_before = fort_stats.max_hp
	UnitStatsTable.apply_combat_kind_modifiers(fort_stats)
	if fort_stats.defense_armor > fort_stats.defense_light and fort_stats.max_hp > fort_hp_before:
		print("✅ 堡垒修正: defense_armor(%.0f) > defense_light(%.0f), HP %.0f→%.0f" % [fort_stats.defense_armor, fort_stats.defense_light, fort_hp_before, fort_stats.max_hp])
	else:
		print("❌ 堡垒修正异常: def_armor=%.0f def_light=%.0f HP=%.0f" % [fort_stats.defense_armor, fort_stats.defense_light, fort_stats.max_hp])
		ok = false
	# 4b 装甲：defense_armor 应加成（+4），defense_light 不变
	var armor_stats = UnitStats.new()
	armor_stats.combat_kind = GC.CombatKind.ARMOR
	armor_stats.unit_subtype = GC.UnitSubType.NONE
	armor_stats.defense_armor = 50.0
	armor_stats.defense_light = 50.0
	UnitStatsTable.apply_combat_kind_modifiers(armor_stats)
	if armor_stats.defense_armor == 54.0 and armor_stats.defense_light == 50.0:
		print("✅ 装甲修正: defense_armor 50→54 (+4), defense_light 保持 50")
	else:
		print("❌ 装甲修正异常: def_armor=%.1f def_light=%.1f" % [armor_stats.defense_armor, armor_stats.defense_light])
		ok = false
	# 4c 火炮子类：不应获得闪避（dodge 保持0）
	var arty_stats = UnitStats.new()
	arty_stats.combat_kind = GC.CombatKind.LIGHT
	arty_stats.unit_subtype = GC.UnitSubType.ARTILLERY
	UnitStatsTable.apply_combat_kind_modifiers(arty_stats)
	var inf_stats = UnitStats.new()
	inf_stats.combat_kind = GC.CombatKind.LIGHT
	inf_stats.unit_subtype = GC.UnitSubType.NONE
	UnitStatsTable.apply_combat_kind_modifiers(inf_stats)
	if arty_stats.dodge_chance == 0.0 and inf_stats.dodge_chance == 0.18:
		print("✅ 闪避差异化: 火炮=0.0(无闪避), 普通步兵=0.18")
	else:
		print("❌ 闪避差异化异常: 火炮=%.2f 步兵=%.2f" % [arty_stats.dodge_chance, inf_stats.dodge_chance])
		ok = false

	print("\n%s" % ("✅ v6.2 验证全部通过" if ok else "❌ v6.2 验证有失败"))
	quit(0 if ok else 1)
