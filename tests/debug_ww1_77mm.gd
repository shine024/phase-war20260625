extends Node

## 野战炮问题调试脚本

func _ready() -> void:
	print("=== 野战炮问题调试 ===")
	print("\n1. 检查 GameConstants...")
	check_game_constants()

	print("\n2. 检查 DefaultCards...")
	check_default_cards()

	print("\n3. 检查 AttackCalculator...")
	check_attack_calculator()

	print("\n4. 检查 ConstructUnitAI...")
	check_construct_unit_ai()

func check_game_constants() -> void:
	print("  尝试加载 GameConstants...")
	var err = load("res://resources/game_constants.gd")
	if err == null:
		print("  ❌ GameConstants 加载失败！")
	else:
		print("  ✅ GameConstants 加载成功")
		print("  类型: ", err.get_class())

		var GC = ClassDB.instantiate(err.get_class())
		print("  实例化: ", GC)

		# 检查枚举
		print("\n  检查枚举:")
		print("    TargetingMode: ", GC.get("TargetingMode"))
		print("    CombatKind: ", GC.get("CombatKind"))
		print("    WeaponType: ", GC.get("WeaponType"))

		# 检查方法
		print("\n  检查方法:")
		var methods = GC.get_method_list()
		for m in methods:
			if "get_targeting" in m.name:
				print("    ✅ 找到方法: ", m.name)

func check_default_cards() -> void:
	print("  尝试加载 DefaultCards...")
	var err = load("res://data/default_cards.gd")
	if err == null:
		print("  ❌ DefaultCards 加载失败！")
	else:
		print("  ✅ DefaultCards 加载成功")

		var DefaultCards = ClassDB.instantiate(err.get_class())
		var card = DefaultCards.get_card_by_id("ww1_77mm")

		if card == null:
			print("  ❌ ww1_77mm 卡牌不存在！")
		else:
			print("  ✅ ww1_77mm 卡牌存在")
			print("    card_id: ", card.card_id)
			print("    combat_kind: ", card.combat_kind)
			print("    weapon_type: ", card.weapon_type)
			print("    attack_light: ", card.attack_light)
			print("    attack_armor: ", card.attack_armor)
			print("    range_value: ", card.range_value)

func check_attack_calculator() -> void:
	print("  尝试加载 AttackCalculator...")
	var err = load("res://scripts/battle/attack_calculator.gd")
	if err == null:
		print("  ❌ AttackCalculator 加载失败！")
	else:
		print("  ✅ AttackCalculator 加载成功")

func check_construct_unit_ai() -> void:
	print("  尝试加载 ConstructUnitAI...")
	var err = load("res://scripts/battle/construct_unit_ai.gd")
	if err == null:
		print("  ❌ ConstructUnitAI 加载失败！")
	else:
		print("  ✅ ConstructUnitAI 加载成功")