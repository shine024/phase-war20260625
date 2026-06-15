extends Node
## 战斗系统诊断脚本
## 用于验证三攻三防系统和索敌系统是否正确工作

func _ready() -> void:
	print("=== 战斗系统诊断 ===")

	# 测试 TargetingMode 枚举
	const GC = preload("res://resources/game_constants.gd")
	print("TargetingMode.NEAREST_FIRST = ", GC.TargetingMode.NEAREST_FIRST)
	print("TargetingMode.FARTHEST_FIRST = ", GC.TargetingMode.FARTHEST_FIRST)

	# 测试 get_targeting_mode_for_combat_kind
	print("LIGHT 索敌模式: ", GC.get_targeting_mode_for_combat_kind(GC.CombatKind.LIGHT))
	print("ARMOR 索敌模式: ", GC.get_targeting_mode_for_combat_kind(GC.CombatKind.ARMOR))
	print("AIR 索敌模式: ", GC.get_targeting_mode_for_combat_kind(GC.CombatKind.AIR))
	print("SUPPORT 索敌模式: ", GC.get_targeting_mode_for_combat_kind(GC.CombatKind.SUPPORT))

	# 测试 UnitStats 防御属性
	var stats = UnitStats.new()
	stats.defense_light = 10
	stats.defense_armor = 20
	stats.defense_air = 5
	print("设置防御值后：")
	print("  defense_light = ", stats.defense_light)
	print("  defense_armor = ", stats.defense_armor)
	print("  defense_air = ", stats.defense_air)

	# 测试 attack_calculator
	const AttackCalculator = preload("res://scripts/battle/attack_calculator.gd")
	print("测试 get_defense_vs:")
	print("  DIRECT → ", AttackCalculator.get_defense_vs(stats, GC.WeaponType.DIRECT))
	print("  INDIRECT → ", AttackCalculator.get_defense_vs(stats, GC.WeaponType.INDIRECT))
	print("  AERIAL → ", AttackCalculator.get_defense_vs(stats, GC.WeaponType.AERIAL))

	print("=== 诊断完成 ===")
