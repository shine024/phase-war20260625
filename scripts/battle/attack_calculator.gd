extends RefCounted
class_name AttackCalculator
## v5.0: 攻速分离计算 + 伤害公式

const GC = preload("res://resources/game_constants.gd")

## 根据目标类型获取攻击值
static func get_attack_vs(attacker_stats: UnitStats, target_combat_kind: int) -> float:
	match target_combat_kind:
		GC.CombatKind.LIGHT: return attacker_stats.attack_light
		GC.CombatKind.ARMOR: return attacker_stats.attack_armor
		GC.CombatKind.AIR: return attacker_stats.attack_air
		GC.CombatKind.SUPPORT: return attacker_stats.attack_light  # 支援按轻装算
		GC.CombatKind.FORT: return attacker_stats.attack_armor    # 堡垒按装甲算
		_: return attacker_stats.attack_light

## 根据攻击者类型获取对应防御值
static func get_defense_vs(target_stats: UnitStats, attacker_combat_kind: int) -> float:
	match attacker_combat_kind:
		GC.CombatKind.LIGHT: return target_stats.defense_light
		GC.CombatKind.ARMOR: return target_stats.defense_armor
		GC.CombatKind.AIR: return target_stats.defense_air
		GC.CombatKind.SUPPORT: return target_stats.defense_light
		GC.CombatKind.FORT: return target_stats.defense_armor
		_: return target_stats.defense_light

## 完整伤害计算
static func calculate_damage(
	attacker_stats: UnitStats,
	target_stats: UnitStats,
	distance: float,  # 格
	weapon_type: int,
	attacker_enhance_level: int = 0,
	attacker_mods: Array = []
) -> float:
	# 1. 根据目标类型选攻击值
	var base_damage = get_attack_vs(attacker_stats, target_stats.combat_kind)

	# 2. 击穿检查: attack <= defense → 伤害=0
	var def = get_defense_vs(target_stats, attacker_stats.combat_kind)
	if base_damage <= def:
		return 0.0

	# 3. 射程衰减(仅直射)
	if weapon_type == GC.WeaponType.DIRECT:
		var max_range = distance  # 调用方需传入正确的max_range
		var DamageAttenuation = preload("res://scripts/battle/damage_attenuation.gd")
		var sub_type = DamageAttenuation.infer_weapon_sub_type(
			attacker_stats.combat_kind, int(max_range),
			attacker_stats.attack_light, attacker_stats.attack_armor, attacker_stats.attack_air
		)
		# Note: caller should pass max_range separately; using a helper
		base_damage *= DamageAttenuation.calculate_attenuation(distance, max_range, sub_type)

	# 4. 防御减免: damage × 100/(100+def)
	var final_damage = base_damage * (100.0 / (100.0 + def))

	# 5. 强化加成(百分比)
	if attacker_enhance_level > 0:
		var enhance_mult = 1.0 + float(attacker_enhance_level) * 0.05
		if attacker_enhance_level >= 9:
			enhance_mult = 1.50  # Lv9 nonlinear
		elif attacker_enhance_level >= 10:
			enhance_mult = 1.60  # Lv10 nonlinear
		final_damage *= enhance_mult

	# 6. 改造加成 (placeholder - mod system in Phase 3)
	# final_damage *= get_mod_damage_multiplier(attacker_mods)

	return final_damage

## 完整伤害计算（带max_range参数版）
static func calculate_damage_with_range(
	attacker_stats: UnitStats,
	target_stats: UnitStats,
	distance: float,
	max_range: float,
	weapon_type: int,
	attacker_enhance_level: int = 0,
	attacker_mods: Array = []
) -> float:
	# 1. 根据目标类型选攻击值
	var base_damage = get_attack_vs(attacker_stats, target_stats.combat_kind)

	# 2. 击穿检查
	var def = get_defense_vs(target_stats, attacker_stats.combat_kind)
	if base_damage <= def:
		return 0.0

	# 3. 射程衰减(仅直射)
	if weapon_type == GC.WeaponType.DIRECT:
		var DamageAttenuation = preload("res://scripts/battle/damage_attenuation.gd")
		var sub_type = DamageAttenuation.infer_weapon_sub_type(
			attacker_stats.combat_kind, int(max_range),
			attacker_stats.attack_light, attacker_stats.attack_armor, attacker_stats.attack_air
		)
		base_damage *= DamageAttenuation.calculate_attenuation(distance, max_range, sub_type)

	# 4. 防御减免
	var final_damage = base_damage * (100.0 / (100.0 + def))

	# 5. 强化加成
	if attacker_enhance_level > 0:
		var enhance_mult = 1.0 + float(attacker_enhance_level) * 0.05
		if attacker_enhance_level >= 9:
			enhance_mult = 1.50
		elif attacker_enhance_level >= 10:
			enhance_mult = 1.60
		final_damage *= enhance_mult

	return final_damage

## 获取攻击计时参数（根据目标类型）
## 返回 { cycle, windup, active, cooldown }
static func get_attack_timing(attacker_stats: UnitStats, target_combat_kind: int) -> Dictionary:
	var speed: float = 1.0
	var windup: float = 0.2
	var active: float = 0.1

	match target_combat_kind:
		GC.CombatKind.LIGHT, GC.CombatKind.SUPPORT:
			speed = attacker_stats.attack_light_speed
			windup = attacker_stats.attack_light_windup
			active = attacker_stats.attack_light_active
		GC.CombatKind.ARMOR, GC.CombatKind.FORT:
			speed = attacker_stats.attack_armor_speed
			windup = attacker_stats.attack_armor_windup
			active = attacker_stats.attack_armor_active
		GC.CombatKind.AIR:
			speed = attacker_stats.attack_air_speed
			windup = attacker_stats.attack_air_windup
			active = attacker_stats.attack_air_active
		_:
			speed = attacker_stats.attack_light_speed
			windup = attacker_stats.attack_light_windup
			active = attacker_stats.attack_light_active

	if speed <= 0.0:
		speed = 1.0

	var cycle = 1.0 / speed
	return {
		"cycle": cycle,
		"windup": windup,
		"active": active,
		"cooldown": maxf(0.0, cycle - windup - active),
		"speed": speed,
	}
