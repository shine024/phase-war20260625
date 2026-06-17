extends RefCounted
class_name BattleSystemValidator
## 战斗系统验证器：用于快速检查战斗系统是否正常工作

const GC = preload("res://resources/game_constants.gd")

## 验证三攻三防系统
static func validate_three_attack_three_defense() -> Dictionary:
	var result: Dictionary = {
		"success": true,
		"errors": [],
		"warnings": [],
		"details": {}
	}

	# 1. 检查 GameConstants 枚举
	result.details["weapon_types"] = {
		"DIRECT": GC.WeaponType.DIRECT,
		"INDIRECT": GC.WeaponType.INDIRECT,
		"AERIAL": GC.WeaponType.AERIAL
	}

	result.details["combat_kinds"] = {
		"LIGHT": GC.CombatKind.LIGHT,
		"ARMOR": GC.CombatKind.ARMOR,
		"SUPPORT": GC.CombatKind.SUPPORT,
		"AIR": GC.CombatKind.AIR,
		"FORT": GC.CombatKind.FORT
	}

	# 2. 检查默认卡牌
	var DefaultCards = preload("res://data/default_cards.gd")
	var card_77mm = DefaultCards.get_card_by_id("ww1_77mm")

	if card_77mm == null:
		result.success = false
		result.errors.append("ww1_77mm 卡牌不存在")
		return result

	# 3. 验证野战炮数据
	result.details["ww1_77mm"] = {
		"combat_kind": card_77mm.combat_kind,
		"weapon_type": card_77mm.weapon_type,
		"attack_light": card_77mm.attack_light,
		"attack_armor": card_77mm.attack_armor,
		"defense_light": card_77mm.defense_light,
		"defense_armor": card_77mm.defense_armor,
		"defense_air": card_77mm.defense_air
	}

	# 验证武器类型
	if card_77mm.weapon_type != GC.WeaponType.INDIRECT:
		result.warnings.append("野战炮 weapon_type 不是 INDIRECT，实际值: %d" % card_77mm.weapon_type)

	# 4. 检查武器槽位
	if card_77mm.weapon_slots.is_empty():
		result.warnings.append("野战炮 weapon_slots 为空，需要调用 initialize_weapon_slots()")

		# 尝试初始化
		if card_77mm.has_method("initialize_weapon_slots"):
			card_77mm.initialize_weapon_slots()
			result.warnings.append("已调用 initialize_weapon_slots()")

	# 验证槽位武器类型
	if not card_77mm.weapon_slots.is_empty():
		var slot_1 = card_77mm.weapon_slots[1] if card_77mm.weapon_slots.size() > 1 else null
		if slot_1 != null:
			if slot_1.weapon_type != GC.WeaponType.INDIRECT:
				result.errors.append("槽位1 weapon_type 不是 INDIRECT，实际值: %d" % slot_1.weapon_type)
				result.success = false

	# 5. 测试伤害计算
	var UnitStats = load("res://resources/unit_stats.gd")
	var AttackCalculator = preload("res://scripts/battle/attack_calculator.gd")

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

	var damage = AttackCalculator.calculate_damage(
		attacker, defender, 500.0, GC.WeaponType.INDIRECT, 0, []
	)

	result.details["damage_test"] = {
		"attack_vs": AttackCalculator.get_attack_vs(attacker, GC.CombatKind.LIGHT),
		"defense_vs": AttackCalculator.get_defense_vs(defender, attacker.combat_kind),
		"calculated_damage": damage,
		"expected_damage": 135.0 * 100.0 / (100.0 + 8.0)
	}

	# 验证伤害计算
	var expected = 135.0 * 100.0 / (100.0 + 8.0)
	if absf(damage - expected) > 0.01:
		result.errors.append("伤害计算不正确: 实际=%.2f, 预期=%.2f" % [damage, expected])
		result.success = false

	return result

## 打印验证结果
static func print_validation_result(result: Dictionary) -> void:
	print("\n=== 战斗系统验证结果 ===")

	if result.success:
		print("✅ 验证通过")
	else:
		print("❌ 验证失败")

	print("\n详细信息:")
	for key in result.details:
		print("  %s: %s" % [key, str(result.details[key])])

	if not result.warnings.is_empty():
		print("\n⚠️  警告:")
		for w in result.warnings:
			print("  - ", w)

	if not result.errors.is_empty():
		print("\n❌ 错误:")
		for e in result.errors:
			print("  - ", e)

## 快速验证（可以在控制台直接调用）
static func quick_validate() -> bool:
	var result = validate_three_attack_three_defense()
	print_validation_result(result)
	return result.success