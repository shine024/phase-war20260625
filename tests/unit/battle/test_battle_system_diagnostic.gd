extends GdUnitTestSuite
## 战斗系统诊断（原 tests/battle_system_full_check.gd 正名入 gdunit 门禁）
##
## 原 Node 版诊断脚本只能游戏内手动跑、且曾被误用 --script 调用（Node 不是
## MainLoop，引擎半初始化上下文里编译依赖链时 autoload 全局标识符不可解析，
## 报"Identifier not found: ObjectPoolManager"级联假警报——2026-09-21 可玩性
## 审计 P3 核销）。现改为 gdunit 真断言：随全量门禁常跑。
## 数值探针基准（2026-09-21）：ww1_arty_m81 战斗卡数据 + 攻防选择 + 曲射伤害公式
## 135×100/(100+8)=125.0。

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const AttackCalculator = preload("res://scripts/battle/attack_calculator.gd")
const UnitStatsScript = preload("res://resources/unit_stats.gd")


func test_game_constants_enums_and_targeting() -> void:
	assert_int(GC.WeaponType.DIRECT).is_equal(0)
	assert_int(GC.WeaponType.INDIRECT).is_equal(1)
	assert_int(GC.CombatKind.LIGHT).is_equal(0)
	assert_int(GC.CombatKind.ARMOR).is_equal(1)
	assert_int(GC.CombatKind.SUPPORT).is_equal(2)
	for ck in [GC.CombatKind.LIGHT, GC.CombatKind.ARMOR, GC.CombatKind.SUPPORT]:
		var mode: int = GC.get_targeting_mode_for_combat_kind(ck)
		assert_int(mode).is_greater_equal(0)


func test_infer_weapon_type_branching() -> void:
	# 支援（火炮/迫击炮）优先判 INDIRECT
	assert_int(DefaultCards._infer_weapon_type(2, 99, 135, 90, 0)).is_equal(GC.WeaponType.INDIRECT)
	# 无攻击力 → SUPPORT
	assert_int(DefaultCards._infer_weapon_type(2, 5, 0, 0, 0)).is_equal(GC.WeaponType.SUPPORT)
	# 空中 → AERIAL
	assert_int(DefaultCards._infer_weapon_type(3, 4, 20, 20, 20)).is_equal(GC.WeaponType.AERIAL)
	# 步枪近程 → DIRECT
	assert_int(DefaultCards._infer_weapon_type(0, 5, 30, 10, 0)).is_equal(GC.WeaponType.DIRECT)


func test_artillery_card_data_complete() -> void:
	# 旧脚本以 ww1_77mm 为样本；本套件改用现役 ww1_arty_m81（81mm迫击炮组）做
	# 同类校验（旧 id 经数据驱动定义仍可解析，与火炮数据完整性无关，不再断言）
	var card = DefaultCards.get_card_by_id("ww1_arty_m81")
	assert_object(card).is_not_null()
	assert_int(card.combat_kind).is_equal(2)  # SUPPORT
	assert_int(card.range_value).is_greater(0)
	assert_float(card.attack_light).is_greater(0.0)


func test_attack_calculator_math() -> void:
	var attacker = UnitStatsScript.new()
	attacker.combat_kind = GC.CombatKind.SUPPORT
	attacker.attack_light = 135.0
	attacker.attack_armor = 90.0
	attacker.weapon_type = GC.WeaponType.INDIRECT
	var defender = UnitStatsScript.new()
	defender.combat_kind = GC.CombatKind.LIGHT
	defender.defense_light = 8.0
	defender.defense_armor = 5.0
	defender.defense_air = 3.0
	# 攻击值按目标类型选（目标轻装→attack_light）；防御按攻击者类型选（v6.2 对齐）
	assert_float(AttackCalculator.get_attack_vs(attacker, defender.combat_kind)).is_equal(135.0)
	assert_float(AttackCalculator.get_defense_vs(defender, attacker.combat_kind)).is_equal(8.0)
	# 完整公式：曲射无衰减，135 × 100/(100+8) = 125
	var dmg: float = AttackCalculator.calculate_damage(attacker, defender, 5.0, GC.WeaponType.INDIRECT, 0, [])
	assert_float(dmg).is_equal_approx(125.0, 0.01)
