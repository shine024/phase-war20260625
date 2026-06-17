extends Node

## 战斗系统完全修复脚本

func _ready() -> void:
	print("=== 战斗系统全面诊断与修复 ===")

	print("\n1. 检查 GameConstants...")
	check_game_constants()

	print("\n2. 检查 DefaultCards...")
	check_default_cards()

	print("\n3. 检查野战炮数据...")
	check_ww1_77mm()

	print("\n4. 检查 WeaponResource...")
	check_weapon_resource()

	print("\n5. 检查伤害计算...")
	check_damage_calculation()

func check_game_constants() -> void:
	var GC = preload("res://resources/game_constants.gd")
	print("  ✅ GameConstants 加载成功")

	print("  WeaponType 枚举:")
	print("    DIRECT = ", GC.WeaponType.DIRECT)
	print("    INDIRECT = ", GC.WeaponType.INDIRECT)
	print("    AERIAL = ", GC.WeaponType.AERIAL)

	print("  CombatKind 枚举:")
	print("    LIGHT = ", GC.CombatKind.LIGHT)
	print("    ARMOR = ", GC.CombatKind.ARMOR)
	print("    SUPPORT = ", GC.CombatKind.SUPPORT)

	print("  索敌方式:")
	if GC.has_method("get_targeting_mode_for_combat_kind"):
		print("    ✅ get_targeting_mode_for_combat_kind 存在")
		print("      LIGHT → ", GC.TargetingMode.find_key(GC.get_targeting_mode_for_combat_kind(GC.CombatKind.LIGHT)))
		print("      ARMOR → ", GC.TargetingMode.find_key(GC.get_targeting_mode_for_combat_kind(GC.CombatKind.ARMOR)))
		print("      SUPPORT → ", GC.TargetingMode.find_key(GC.get_targeting_mode_for_combat_kind(GC.CombatKind.SUPPORT)))
	else:
		print("    ❌ get_targeting_mode_for_combat_kind 不存在")

func check_default_cards() -> void:
	var DefaultCards = preload("res://data/default_cards.gd")

	# 检查 _infer_weapon_type 函数
	if DefaultCards.has_method("_infer_weapon_type"):
		print("  ✅ _infer_weapon_type 方法存在")

		# 测试野战炮的武器类型推断
		var weapon_type = DefaultCards._infer_weapon_type(2, 99, 135, 90, 0)
		print("    野战炮(射程99) → weapon_type = ", weapon_type)
		print("      0=DIRECT, 1=INDIRECT, 2=AERIAL")
	else:
		print("  ❌ _infer_weapon_type 方法不存在")

func check_ww1_77mm() -> void:
	var DefaultCards = preload("res://data/default_cards.gd")
	var card = DefaultCards.get_card_by_id("ww1_77mm")

	if card == null:
		print("  ❌ ww1_77mm 卡牌不存在")
		return

	print("  ✅ ww1_77mm 卡牌存在")
	print("    combat_kind = ", card.combat_kind, " (2=SUPPORT)")
	print("    range_value = ", card.range_value)
	print("    attack_light = ", card.attack_light)
	print("    attack_armor = ", card.attack_armor)
	print("    attack_air = ", card.attack_air)
	print("    weapon_type = ", card.weapon_type, " (0=DIRECT, 1=INDIRECT, 2=AERIAL)")
	print("    defense_light = ", card.defense_light)
	print("    defense_armor = ", card.defense_armor)
	print("    defense_air = ", card.defense_air)

	# 检查武器槽位
	print("\n  武器槽位:")
	if card.weapon_slots.is_empty():
		print("    ⚠️  weapon_slots 为空，需要调用 initialize_weapon_slots()")
		# 尝试初始化
		if card.has_method("initialize_weapon_slots"):
			card.initialize_weapon_slots()
			print("    ✅ 已调用 initialize_weapon_slots()")
		else:
			print("    ❌ initialize_weapon_slots() 方法不存在")
	else:
		for i in range(card.weapon_slots.size()):
			var slot = card.weapon_slots[i]
			if slot != null:
				print("    槽位", i, ":")
				print("      slot_type = ", slot.slot_type, " (0=轻装, 1=装甲, 2=对空)")
				print("      damage = ", slot.damage)
				print("      weapon_type = ", slot.weapon_type, " (0=DIRECT, 1=INDIRECT, 2=AERIAL)")
				print("      enabled = ", slot.enabled)

func check_weapon_resource() -> void:
	var WeaponRes = load("res://resources/weapon_resource.gd")
	if WeaponRes == null:
		print("  ❌ WeaponResource 类不存在")
		return

	print("  ✅ WeaponResource 类存在")

	# 创建一个测试实例
	var test_weapon = WeaponRes.new()
	test_weapon.slot_type = 1
	test_weapon.damage = 135.0
	test_weapon.weapon_type = 1  # INDIRECT
	test_weapon.range_value = 99
	test_weapon.enabled = true

	print("  测试武器实例:")
	print("    slot_type = ", test_weapon.slot_type)
	print("    damage = ", test_weapon.damage)
	print("    weapon_type = ", test_weapon.weapon_type)
	print("    enabled = ", test_weapon.enabled)

func check_damage_calculation() -> void:
	var AttackCalculator = preload("res://scripts/battle/attack_calculator.gd")
	var UnitStats = load("res://resources/unit_stats.gd")
	var GC = preload("res://resources/game_constants.gd")

	print("  ✅ AttackCalculator 加载成功")

	# 创建测试用的攻击者和防御者
	var attacker = UnitStats.new()
	attacker.combat_kind = GC.CombatKind.SUPPORT
	attacker.attack_light = 135.0
	attacker.attack_armor = 90.0
	attacker.weapon_type = GC.WeaponType.INDIRECT

	var defender = UnitStats.new()
	defender.combat_kind = GC.CombatKind.LIGHT
	defender.defense_light = 8.0
	defender.defense_armor = 5.0
	defender.defense_air = 3.0

	print("\n  伤害计算测试:")
	print("    攻击者:")
	print("      combat_kind = SUPPORT")
	print("      attack_light = 135")
	print("      weapon_type = INDIRECT")
	print("    防御者:")
	print("      combat_kind = LIGHT")
	print("      defense_light = 8 (防轻装)")
	print("      defense_armor = 5 (防装甲)")
	print("      defense_air = 3 (防空中)")

	# 测试 get_attack_vs
	var attack_vs = AttackCalculator.get_attack_vs(attacker, defender.combat_kind)
	print("\n  get_attack_vs(攻击者, LIGHT) = ", attack_vs, " (应该=135)")

	# 测试 get_defense_vs（v6.2: 按攻击者单位类型选，SUPPORT→防轻装 defense_light）
	var defense_vs = AttackCalculator.get_defense_vs(defender, attacker.combat_kind)
	print("  get_defense_vs(防御者, 攻击者=SUPPORT) = ", defense_vs, " (应该=8, SUPPORT归入LIGHT→defense_light)")

	# 完整伤害计算
	var damage = AttackCalculator.calculate_damage(
		attacker, defender, 500.0, GC.WeaponType.INDIRECT, 0, []
	)
	print("\n  calculate_damage() = ", damage)
	print("    公式: attack × 100/(100+defense)")
	print("    135 × 100/(100+8) = ", 135.0 * 100.0 / 108.0)