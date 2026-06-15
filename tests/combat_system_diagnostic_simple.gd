extends Node

## 战斗系统诊断脚本

func _ready() -> void:
	print("=== 战斗系统诊断 ===")
	print("1. 检查 GameConstants 类...")
	test_game_constants()

	print("\n2. 检查野战炮数据...")
	test_ww1_77mm_data()

	print("\n3. 测试索敌方式...")
	test_targeting_mode()

func test_game_constants() -> void:
	var GC = preload("res://resources/game_constants.gd")
	print("  ✅ GameConstants 加载成功")

	print("  TargetingMode.NEAREST_FIRST = ", GC.TargetingMode.NEAREST_FIRST)
	print("  TargetingMode.FARTHEST_FIRST = ", GC.TargetingMode.FARTHEST_FIRST)

	print("  CombatKind.LIGHT = ", GC.CombatKind.LIGHT)
	print("  CombatKind.SUPPORT = ", GC.CombatKind.SUPPORT)

	# 测试索敌方式
	if GC.has_method("get_targeting_mode_for_combat_kind"):
		print("  ✅ get_targeting_mode_for_combat_kind 方法存在")
		print("    LIGHT 索敌模式: ", GC.get_targeting_mode_for_combat_kind(GC.CombatKind.LIGHT))
		print("    ARMOR 索敌模式: ", GC.get_targeting_mode_for_combat_kind(GC.CombatKind.ARMOR))
		print("    SUPPORT 索敌模式: ", GC.get_targeting_mode_for_combat_kind(GC.CombatKind.SUPPORT))
		print("    AIR 索敌模式: ", GC.get_targeting_mode_for_combat_kind(GC.CombatKind.AIR))
		print("    FORT 索敌模式: ", GC.get_targeting_mode_for_combat_kind(GC.CombatKind.FORT))
	else:
		print("  ❌ get_targeting_mode_for_combat_kind 方法不存在！")

func test_ww1_77mm_data() -> void:
	var DefaultCards = preload("res://data/default_cards.gd")
	var card = DefaultCards.get_card_by_id("ww1_77mm")

	if card == null:
		print("  ❌ ww1_77mm 卡牌不存在！")
		return

	print("  ✅ ww1_77mm 卡牌存在")
	print("    combat_kind: ", card.combat_kind)
	print("    weapon_type: ", card.weapon_type)
	print("    attack_light: ", card.attack_light)
	print("    attack_armor: ", card.attack_armor)
	print("    attack_air: ", card.attack_air)
	print("    attack_light_speed: ", card.attack_light_speed)
	print("    range_value: ", card.range_value)

	# 检查武器类型
	var GC = preload("res://resources/game_constants.gd")
	print("    武器类型: ", GC.WeaponType.find_key(card.weapon_type))

func test_targeting_mode() -> void:
	var GC = preload("res://resources/game_constants.gd")

	# 创建一个模拟的野战炮
	var mock_stats = {
		"combat_kind": GC.CombatKind.SUPPORT
	}

	print("  模拟野战炮索敌方式:")
	if GC.has_method("get_targeting_mode_for_combat_kind"):
		var mode = GC.get_targeting_mode_for_combat_kind(mock_stats.combat_kind)
		print("    结果: ", GC.TargetingMode.find_key(mode))
	else:
		print("    ❌ 方法不存在")