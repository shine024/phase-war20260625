extends RefCounted
class_name AttackCalculator
## v5.0: 攻速分离计算 + 伤害公式

const GC = preload("res://resources/game_constants.gd")
const DamageAttenuation = preload("res://scripts/battle/damage_attenuation.gd")
const ModEffects = preload("res://data/mod_effects.gd")

## 默认攻速值（当攻速为0或负数时使用）
const DEFAULT_ATTACK_SPEED: float = 1.0

## 根据目标类型获取攻击值
## 目标轻甲→attack_light, 装甲→attack_armor, 空中→attack_air
static func get_attack_vs(attacker_stats: UnitStats, target_combat_kind: int) -> float:
	match target_combat_kind:
		GC.CombatKind.LIGHT: return attacker_stats.attack_light
		GC.CombatKind.ARMOR: return attacker_stats.attack_armor
		GC.CombatKind.AIR: return attacker_stats.attack_air
		GC.CombatKind.SUPPORT: return attacker_stats.attack_light  # 支援按轻装算
		GC.CombatKind.FORT: return attacker_stats.attack_armor    # 堡垒按装甲算
		_: return attacker_stats.attack_light

## 根据武器类型（攻击方式）获取对应防御值
## 注意：当前使用旧的属性名（defense_light/armor/air）但含义已改变
## defense_light 现在表示对直射防御（防DIRECT武器）
## defense_armor 现在表示对曲射防御（防INDIRECT武器）
## defense_air 现在表示对空射防御（防AERIAL武器）
static func get_defense_vs(target_stats: UnitStats, weapon_type: int) -> float:
	match weapon_type:
		GC.WeaponType.DIRECT: return target_stats.defense_light
		GC.WeaponType.INDIRECT: return target_stats.defense_armor
		GC.WeaponType.AERIAL: return target_stats.defense_air
		_: return target_stats.defense_light  # 默认直射

## 完整伤害计算
static func calculate_damage(
	attacker_stats: UnitStats,
	target_stats: UnitStats,
	distance: float,  # 格
	weapon_type: int,
	attacker_enhance_level: int = 0,
	attacker_mods: Array = []
) -> float:
	# 1. 攻击值 = 根据目标类型选（目标轻甲→attack_light, 装甲→attack_armor, 空中→attack_air）
	var base_damage = get_attack_vs(attacker_stats, target_stats.combat_kind)

	# 2. 防御值 = 根据武器类型穿透（直射→defense_light, 曲射→defense_armor, 空射→defense_air）
	var def = get_defense_vs(target_stats, weapon_type)

	# 3. 射程衰减(仅直射)
	if weapon_type == GC.WeaponType.DIRECT:
		var max_range = distance  # 调用方需传入正确的max_range
		var sub_type = DamageAttenuation.infer_weapon_sub_type(
			attacker_stats.combat_kind, int(max_range),
			attacker_stats.attack_light, attacker_stats.attack_armor, attacker_stats.attack_air
		)
		# Note: caller should pass max_range separately; using a helper
		base_damage *= DamageAttenuation.calculate_attenuation(distance, max_range, sub_type)

	# 4. 防御减免: damage × 100/(100+def)
	var final_damage = base_damage * (100.0 / (100.0 + def))

	# 5. 强化加成(百分比)
	# Lv1-8: 1.0 + level × 0.05; Lv9: 1.50; Lv10: 1.60
	if attacker_enhance_level > 0:
		var enhance_mult: float
		if attacker_enhance_level >= 10:
			enhance_mult = 1.60  # Lv10
		elif attacker_enhance_level >= 9:
			enhance_mult = 1.50  # Lv9
		else:
			enhance_mult = 1.0 + float(attacker_enhance_level) * 0.05
		final_damage *= enhance_mult

	# 6. 改造加成
	if attacker_mods and not attacker_mods.is_empty():
		final_damage *= get_mod_damage_multiplier(attacker_mods, target_stats.combat_kind)

	return final_damage

## 计算改造伤害倍率
## 遍历已装配的 MOD 列表，累加 attack_multiplier（条件型仅当目标匹配时生效）
static func get_mod_damage_multiplier(mods: Array, target_combat_kind: int) -> float:
	var total_mult := 1.0
	for mod_id in mods:
		if mod_id is not String:
			continue
		var mod_def: Dictionary = ModEffects.get_mod_info(mod_id)
		if mod_def.is_empty():
			continue
		var attack_mult: float = float(mod_def.get("attack_multiplier", 1.0))
		# 条件型改造：仅当目标类型匹配时才生效
		var condition_type: String = String(mod_def.get("condition_type", ""))
		if condition_type == "vs_armor" and target_combat_kind != GC.CombatKind.ARMOR:
			attack_mult = 1.0
		elif condition_type == "vs_light" and target_combat_kind != GC.CombatKind.LIGHT:
			attack_mult = 1.0
		elif condition_type == "vs_air" and target_combat_kind != GC.CombatKind.AIR:
			attack_mult = 1.0
		total_mult *= attack_mult
	return total_mult

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
	# 1. 攻击值 = 根据目标类型选
	var base_damage = get_attack_vs(attacker_stats, target_stats.combat_kind)

	# 2. 击穿检查 — 防御值 = 根据武器类型穿透
	var def = get_defense_vs(target_stats, weapon_type)
	if base_damage <= def:
		return 0.0

	# 3. 射程衰减(仅直射)
	if weapon_type == GC.WeaponType.DIRECT:
		var sub_type = DamageAttenuation.infer_weapon_sub_type(
			attacker_stats.combat_kind, int(max_range),
			attacker_stats.attack_light, attacker_stats.attack_armor, attacker_stats.attack_air
		)
		base_damage *= DamageAttenuation.calculate_attenuation(distance, max_range, sub_type)

	# 4. 防御减免
	var final_damage = base_damage * (100.0 / (100.0 + def))

	# 5. 强化加成
	if attacker_enhance_level > 0:
		var enhance_mult: float
		if attacker_enhance_level >= 10:
			enhance_mult = 1.60
		elif attacker_enhance_level >= 9:
			enhance_mult = 1.50
		else:
			enhance_mult = 1.0 + float(attacker_enhance_level) * 0.05
		final_damage *= enhance_mult

	# 6. 改造加成
	if attacker_mods and not attacker_mods.is_empty():
		final_damage *= get_mod_damage_multiplier(attacker_mods, target_stats.combat_kind)

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
		speed = DEFAULT_ATTACK_SPEED

	var cycle = 1.0 / speed
	return {
		"cycle": cycle,
		"windup": windup,
		"active": active,
		"cooldown": maxf(0.0, cycle - windup - active),
		"speed": speed,
	}

## ─── 武器槽位系统支持 ───

## 根据目标类型获取对应武器
static func get_weapon_for_target(attacker_stats: UnitStats, target_combat_kind: int) -> WeaponResource:
	if attacker_stats == null or attacker_stats.weapon_slots.is_empty():
		return null

	# 优先使用新槽位系统
	if attacker_stats.has_method("get_weapon_for_target"):
		return attacker_stats.get_weapon_for_target(target_combat_kind)

	# 回退到旧系统（按索引映射）
	match target_combat_kind:
		GC.CombatKind.LIGHT, GC.CombatKind.SUPPORT:
			return attacker_stats.weapon_slots[0] if attacker_stats.weapon_slots.size() > 0 else null
		GC.CombatKind.ARMOR, GC.CombatKind.FORT:
			return attacker_stats.weapon_slots[1] if attacker_stats.weapon_slots.size() > 1 else null
		GC.CombatKind.AIR:
			return attacker_stats.weapon_slots[2] if attacker_stats.weapon_slots.size() > 2 else null
		_:
			return attacker_stats.weapon_slots[0] if attacker_stats.weapon_slots.size() > 0 else null

## 使用槽位武器计算伤害
## skip_defense_reduction: 跳过防御减免（格子战模式下，防御由CardGridDamage处理）
static func calculate_damage_with_weapon(
	attacker_stats: UnitStats,
	target_stats: UnitStats,
	distance: float,
	weapon: WeaponResource,
	attacker_enhance_level: int = 0,
	attacker_mods: Array = [],
	skip_defense_reduction: bool = false
) -> float:
	if weapon == null or not weapon.enabled:
		return 0.0

	var base_damage = weapon.damage

	# 射程衰减（仅直射）
	if weapon.weapon_type == GC.WeaponType.DIRECT:
		var max_range = float(weapon.range_value) * 100.0
		var sub_type = DamageAttenuation.infer_weapon_sub_type(
			attacker_stats.combat_kind, weapon.range_value,
			base_damage, base_damage, base_damage
		)
		base_damage *= DamageAttenuation.calculate_attenuation(distance, max_range, sub_type)

	# 防御减免（非格子战模式）
	var final_damage = base_damage
	if not skip_defense_reduction:
		# 用武器的 weapon_type 决定穿透哪个防御值（配对）
		var def = get_defense_vs(target_stats, weapon.weapon_type)
		final_damage = base_damage * (100.0 / (100.0 + def))

	# 强化加成
	if attacker_enhance_level > 0:
		var enhance_mult: float
		if attacker_enhance_level >= 10:
			enhance_mult = 1.60
		elif attacker_enhance_level >= 9:
			enhance_mult = 1.50
		else:
			enhance_mult = 1.0 + float(attacker_enhance_level) * 0.05
		final_damage *= enhance_mult

	# 改造加成
	if attacker_mods and not attacker_mods.is_empty():
		final_damage *= get_mod_damage_multiplier(attacker_mods, target_stats.combat_kind)

	return final_damage

## 获取槽位武器的攻击计时参数
static func get_weapon_attack_timing(weapon: WeaponResource) -> Dictionary:
	if weapon == null or not weapon.enabled:
		return {"cycle": 1.0, "windup": 0.2, "active": 0.1, "cooldown": 0.7, "speed": 1.0}

	var speed = weapon.attack_speed if weapon.attack_speed > 0 else DEFAULT_ATTACK_SPEED
	var cycle = 1.0 / speed
	return {
		"cycle": cycle,
		"windup": weapon.windup,
		"active": weapon.active,
		"cooldown": maxf(0.0, cycle - weapon.windup - weapon.active),
		"speed": speed,
	}

## 获取槽位武器的射程（米）
static func get_weapon_range(weapon: WeaponResource) -> float:
	if weapon == null:
		return 120.0
	return float(weapon.range_value) * 100.0

## 获取武器每秒射速（用于弹道路由决策）
static func get_weapon_speed(attacker_stats: UnitStats, weapon_resource: WeaponResource) -> float:
	if weapon_resource and weapon_resource.enabled:
		return float(weapon_resource.attack_speed) if weapon_resource.attack_speed > 0 else DEFAULT_ATTACK_SPEED
	if attacker_stats == null:
		return 1.0
	var speed: float = attacker_stats.attack_light_speed
	match attacker_stats.combat_kind:
		GC.CombatKind.ARMOR, GC.CombatKind.FORT:
			speed = attacker_stats.attack_armor_speed
		GC.CombatKind.AIR:
			speed = attacker_stats.attack_air_speed
	return speed if speed > 0.0 else DEFAULT_ATTACK_SPEED
