extends RefCounted
class_name UnitStatsTable
## 数值表：从 CardResource 战斗卡字段构建 UnitStats
##
## v3 重构：主入口 build_stats_from_card() 直接从 CardResource 读取 base_* 字段，
## 不再依赖 platform_type + weapon_type 二元查表。
## v6.0: 新增 apply_module_effects() 将强化词条效果应用到 UnitStats。
## 旧 build_stats / build_multi_stats 已改为内部构造 CardResource 后调用新入口，
## 保留函数签名做兼容。

const GC = preload("res://resources/game_constants.gd")
const BattleCardV3 = preload("res://data/battle_card_v3.gd")
const ModuleDefinitions = preload("res://data/module_definitions.gd")


# ─────────────────────────────────────────────
#  新主入口：从 CardResource 战斗卡直接构建
# ─────────────────────────────────────────────

## 从 CardResource 的战斗卡字段直接构建 UnitStats
## card: CardResource（必须是 COMBAT_UNIT 类型）
## era_override: 覆盖时代（-1=使用 card.era）
static func build_stats_from_card(card: CardResource, era_override: int = -1) -> UnitStats:
	var stats = UnitStats.new()
	var e: int = era_override if era_override >= 0 else card.era
	stats.era = e
	stats.combat_kind = card.combat_kind
	stats.weapon_label = card.weapon_label
	stats.card_id = card.card_id

	# 基础数值直接从卡牌读取
	stats.max_hp = card.base_hp
	# v3：使用新字段替代旧的base_interval/base_range
	# v5.0: 透传 per-target 攻速（替代旧的统一 attack_speed）
	stats.attack_light_speed = card.attack_light_speed
	stats.attack_armor_speed = card.attack_armor_speed
	stats.attack_air_speed = card.attack_air_speed
	# 旧兼容：用对轻装攻速作为统一 attack_interval
	stats.attack_interval = 1.0 / card.attack_light_speed if card.attack_light_speed > 0 else 1.0
	stats.attack_range = float(card.range_value * 100.0)  # 格转像素（1格=100px）
	stats.move_speed = card.base_speed
	stats.is_stationary = (card.base_speed <= 0.0)

	# v5.0 透传
	stats.power = card.power
	stats.enhance_level = card.enhance_level

	# 多维攻防
	stats.weapon_type = card.weapon_type
	stats.deploy_speed = card.deploy_speed
	stats.attack_light = card.attack_light
	stats.attack_armor = card.attack_armor
	stats.attack_air = card.attack_air
	stats.defense_light = card.defense_light
	stats.defense_armor = card.defense_armor
	stats.defense_air = card.defense_air

	# 时代缩放
	if e >= 0:
		stats.max_hp *= BattleCardV3.era_hp_multiplier(clampi(e, 0, 4))
		stats.attack_light *= BattleCardV3.era_damage_multiplier(clampi(e, 0, 4))
		stats.attack_armor *= BattleCardV3.era_damage_multiplier(clampi(e, 0, 4))
		stats.attack_air *= BattleCardV3.era_damage_multiplier(clampi(e, 0, 4))
		stats.attack_range *= BattleCardV3.era_range_multiplier(clampi(e, 0, 4))

	# 多武器（如果有）
	stats.weapons.clear()
	if card.multi_weapons.size() > 0:
		for w_entry in card.multi_weapons:
			var entry: Dictionary = w_entry.duplicate()
			entry["timer"] = 0.0
			if e >= 0:
				entry["damage"] = float(entry.get("damage", 0.0)) * BattleCardV3.era_damage_multiplier(clampi(e, 0, 4))
				entry["range"] = float(entry.get("range", 0.0)) * BattleCardV3.era_range_multiplier(clampi(e, 0, 4))
			stats.weapons.append(entry)

	# ═══════════════════════════════════════════════════════════
	# 武器槽位系统（新）— 无条件初始化
	# 旧逻辑：只有 card.multi_weapons.size() > 0 时才初始化，
	# 导致绝大多数默认战斗卡的 weapon_slots 始终为空，
	# ConstructUnitAI.get_weapon_for_target() 直接返回 null，
	# 战斗回退到陈旧路径，出现"不攻击"现象。
	# ═══════════════════════════════════════════════════════════
	stats.weapon_slots.clear()
	if card.has_method("_ensure_weapon_slots_initialized"):
		card._ensure_weapon_slots_initialized()

	var tmp_slots: Array[WeaponResource] = []
	for weapon in card.weapon_slots:
		if weapon is WeaponResource and weapon.enabled:
			var w_copy = weapon.clone()
			# 应用时代伤害缩放
			if e >= 0:
				w_copy.damage *= BattleCardV3.era_damage_multiplier(clampi(e, 0, 4))
				w_copy.range_value = int(float(w_copy.range_value) * BattleCardV3.era_range_multiplier(clampi(e, 0, 4)))
			tmp_slots.append(w_copy)
		else:
			# 添加空槽位占位
			tmp_slots.append(WeaponResource.create_empty_slot(tmp_slots.size()))

	# v6.0: 应用改造效果到武器槽位
	if card.mods and not card.mods.is_empty():
		if ModificationRegistry and ModificationRegistry.has_method("apply_to_weapon_slots"):
			tmp_slots = ModificationRegistry.apply_to_weapon_slots(tmp_slots, card.mods)

	stats.weapon_slots = tmp_slots

	# 旧字段兼容（写入旧字段让过渡期代码仍能工作）
	stats.platform_type = card.platform_type
	stats.legacy_weapon_type = card.legacy_weapon_type
	stats.platform_card_id = card.card_id

	# 战斗定位修正
	apply_combat_kind_modifiers(stats)

	# 综合防御：若未显式设置，从三维防御取最大值（格子战术护甲公式用）
	if stats.defense <= 0.0:
		stats.defense = maxf(stats.defense_light, maxf(stats.defense_armor, stats.defense_air))

	# v6.0: 应用强化词条效果（如有 module_slots）
	if card.module_slots.size() > 0:
		apply_module_effects(stats, card.module_slots, card.enhance_level)

	return stats


## v6.0: 将强化词条效果应用到 UnitStats（原地修改）
## module_slots: Array[ModuleSlot] — 词条槽位数组
## enhance_level: int — 强化等级（用于Lv10全属性加成判断）
static func apply_module_effects(stats: UnitStats, module_slots: Array, enhance_level: int = 0) -> void:
	if stats == null or module_slots.is_empty():
		return
	# 构建 base 字典
	var base_dict: Dictionary = {
		"max_hp": stats.max_hp,
		"attack_light": stats.attack_light,
		"attack_armor": stats.attack_armor,
		"attack_air": stats.attack_air,
		"attack_range": stats.attack_range,
		"attack_interval": stats.attack_interval,
		"defense": stats.defense,
		"deploy_speed": stats.deploy_speed,
		"damage_reduction": stats.damage_reduction,
		"crit_chance": stats.crit_chance,
		"crit_damage_bonus": stats.crit_damage_bonus,
		"lifesteal": stats.lifesteal,
		"splash_damage": stats.splash_damage,
		"armor_penetration": stats.armor_penetration,
		"chain_chance": stats.chain_chance,
		"shield_on_kill": stats.shield_on_kill,
		"hp_regen": stats.hp_regen,
		"dodge_chance": stats.dodge_chance,
	}
	# 将 ModuleSlot 数组转为字典数组
	var slots_data: Array = []
	for s in module_slots:
		if s is ModuleSlot:
			slots_data.append(s.to_dict())
		elif s is Dictionary:
			slots_data.append(s)
	# 应用词条效果
	var result: Dictionary = ModuleDefinitions.apply_modules_to_stats(base_dict, slots_data)
	# Lv10 全属性加成
	if enhance_level >= 10:
		result = ModuleDefinitions.apply_level10_bonus(result)
	# 写回 stats
	stats.max_hp = float(result.get("max_hp", stats.max_hp))
	stats.attack_light = float(result.get("attack_light", stats.attack_light))
	stats.attack_armor = float(result.get("attack_armor", stats.attack_armor))
	stats.attack_air = float(result.get("attack_air", stats.attack_air))
	stats.attack_range = float(result.get("attack_range", stats.attack_range))
	stats.attack_interval = float(result.get("attack_interval", stats.attack_interval))
	stats.defense = float(result.get("defense", stats.defense))
	stats.deploy_speed = int(result.get("deploy_speed", stats.deploy_speed))
	stats.damage_reduction = float(result.get("damage_reduction", 0.0))
	stats.crit_chance = float(result.get("crit_chance", 0.0))
	stats.crit_damage_bonus = float(result.get("crit_damage_bonus", 0.0))
	stats.lifesteal = float(result.get("lifesteal", 0.0))
	stats.splash_damage = float(result.get("splash_damage", 0.0))
	stats.armor_penetration = float(result.get("armor_penetration", 0.0))
	stats.chain_chance = float(result.get("chain_chance", 0.0))
	stats.shield_on_kill = float(result.get("shield_on_kill", 0.0))
	stats.hp_regen = float(result.get("hp_regen", 0.0))
	stats.dodge_chance = float(result.get("dodge_chance", 0.0))
	# 同步旧兼容字段
	stats.attack_damage = stats.attack_light


## 战斗定位固有修正（替代旧 apply_platform_innate_modifiers）
static func apply_combat_kind_modifiers(stats: UnitStats) -> void:
	if stats == null:
		return
	match stats.combat_kind:
		0:  # 轻装：高闪避
			stats.dodge_chance = maxf(stats.dodge_chance, 0.18)
		1:  # 装甲：高防御
			stats.defense_light += 4.0
			stats.defense_armor += 4.0
			stats.defense_air += 4.0
		2:  # 支援：加HP
			stats.max_hp *= 1.08
		3:  # 空中：高机动，可被防空攻击
			stats.dodge_chance = maxf(stats.dodge_chance, 0.12)
			stats.defense_light += 2.0
			stats.defense_armor += 2.0
		4:  # 堡垒：极高防御，不可移动（v5.0）
			stats.defense_light += 8.0
			stats.defense_armor += 8.0
			stats.defense_air += 8.0
			stats.max_hp *= 1.15


# ─────────────────────────────────────────────
#  战斗定位成长倾斜
# ─────────────────────────────────────────────

## 按战斗定位的星级成长倾斜（每星叠一层，与 BlueprintManager.apply_growth_to_stats 配合）
static func get_combat_kind_growth_bias(kind: int) -> Dictionary:
	match kind:
		0:  # 轻装
			return {"hp_bias": 0.04, "dmg_bias": 0.05, "dodge_bias": 0.03}
		1:  # 装甲
			return {"hp_bias": 0.06, "def_bias": 0.04, "dmg_bias": 0.04}
		2:  # 支援
			return {"hp_bias": 0.05, "heal_bias": 0.08}
		3:  # 空中
			return {"hp_bias": 0.03, "dmg_bias": 0.06, "speed_bias": 0.05}
		4:  # 堡垒（v5.0）
			return {"hp_bias": 0.08, "def_bias": 0.06, "dmg_bias": 0.02}
		_:
			return {"hp_bias": 0.04, "dmg_bias": 0.04}


# ─────────────────────────────────────────────
#  辅助：射程/攻速描述
# ─────────────────────────────────────────────

static func _describe_weapon_range(range_px: float) -> String:
	if range_px < 95.0:
		return "短"
	if range_px < 135.0:
		return "中"
	if range_px < 175.0:
		return "长"
	if range_px < 225.0:
		return "远"
	return "极远"

static func _describe_attack_speed(interval_sec: float) -> String:
	if interval_sec <= 0.32:
		return "极快"
	if interval_sec <= 0.5:
		return "快"
	if interval_sec <= 0.95:
		return "中"
	if interval_sec <= 1.55:
		return "慢"
	return "极慢"

## 用于战斗单位卡文案
static func summarize_weapon_stats_from_card(card: CardResource, era_override: int = -1) -> String:
	var e: int = era_override if era_override >= 0 else card.era
	var atk_light: float = card.attack_light
	var atk_armor: float = card.attack_armor
	var atk_air: float = card.attack_air
	# v3：使用新字段
	var rng: float = float(card.range_value * 100.0)  # 格转像素
	var ivl: float = 1.0 / card.attack_speed if card.attack_speed > 0 else 1.0
	if e >= 0:
		var multiplier = BattleCardV3.era_damage_multiplier(clampi(e, 0, 4))
		atk_light *= multiplier
		atk_armor *= multiplier
		atk_air *= multiplier
		rng *= BattleCardV3.era_range_multiplier(clampi(e, 0, 4))
	var total_dmg = atk_light + atk_armor + atk_air
	return "伤害 %d｜射程 %s｜攻速 %s" % [int(round(total_dmg)), _describe_weapon_range(rng), _describe_attack_speed(ivl)]


# ─────────────────────────────────────────────
#  PlatformType → combat_kind / 行为映射
# ─────────────────────────────────────────────

## PlatformType → combat_kind 映射（0=轻装, 1=装甲, 2=支援, 3=空中）
const PLATFORM_TO_COMBAT_KIND: Dictionary = {
	0: 0,    # HOUND → 轻装
	1: 1,    # GUARD → 装甲
	2: 1,    # TITAN → 装甲
	3: 2,    # FORTRESS → 支援
	4: 2,    # RADAR → 支援
	5: 0,    # SCOUT → 轻装
	6: 0,    # RAIDER → 轻装
	7: 2,    # SIEGE → 支援
	8: 3,    # CARRIER → 空中
	9: 2,    # MEDIC → 支援
	10: 0,   # STEALTH → 轻装
	11: 1,   # OMEGA_PLATFORM → 装甲
	12: 2,   # COMMAND → 支援
}

## PlatformType → 旧基础数据（HP, 速度, 是否固定）
const _PLATFORM_BASE: Dictionary = {
	0:  {"speed": 115.0, "hp": 65.0, "stationary": false},   # HOUND
	1:  {"speed": 75.0,  "hp": 110.0, "stationary": false},  # GUARD
	2:  {"speed": 40.0,  "hp": 200.0, "stationary": false},  # TITAN
	3:  {"speed": 0.0,   "hp": 260.0, "stationary": true},   # FORTRESS
	4:  {"speed": 0.0,   "hp": 180.0, "stationary": true},   # RADAR
	5:  {"speed": 135.0, "hp": 50.0,  "stationary": false},  # SCOUT
	6:  {"speed": 100.0, "hp": 90.0,  "stationary": false},  # RAIDER
	7:  {"speed": 0.0,   "hp": 300.0, "stationary": true},   # SIEGE
	8:  {"speed": 50.0,  "hp": 140.0, "stationary": false},  # CARRIER
	9:  {"speed": 75.0,  "hp": 80.0,  "stationary": false},  # MEDIC
	10: {"speed": 115.0, "hp": 50.0,  "stationary": false},  # STEALTH
	11: {"speed": 30.0,  "hp": 240.0, "stationary": false},  # OMEGA_PLATFORM
	12: {"speed": 0.0,   "hp": 150.0, "stationary": true},   # COMMAND
}

## 旧 WeaponType → 武器基础数据（damage, range, interval）
const _WEAPON_BASE: Dictionary = {
	0:  {"damage": 8.0,  "range": 95.0,  "interval": 0.38},   # SMG
	1:  {"damage": 14.0, "range": 155.0, "interval": 0.95},   # RIFLE
	2:  {"damage": 7.0,  "range": 160.0, "interval": 0.25},   # MG
	3:  {"damage": 30.0, "range": 195.0, "interval": 1.70},   # ROCKET
	4:  {"damage": 7.0,  "range": 85.0,  "interval": 0.45},   # PISTOL
	5:  {"damage": 22.0, "range": 60.0,  "interval": 0.85},   # SHOTGUN
	6:  {"damage": 28.0, "range": 240.0, "interval": 1.60},   # SNIPER
	7:  {"damage": 9.0,  "range": 125.0, "interval": 0.35},   # FLAK
	8:  {"damage": 13.0, "range": 185.0, "interval": 0.50},   # LASER
	9:  {"damage": 38.0, "range": 215.0, "interval": 2.00},   # MISSILE
	10: {"damage": 220.0,"range": 250.0, "interval": 2.20},   # OMEGA_CANNON
	11: {"damage": 140.0,"range": 240.0, "interval": 1.65},   # RAIL_CANNON
}

## 旧 PlatformType → 防御值
const _PLATFORM_DEFENSE: Dictionary = {
	0: 5,   # HOUND
	1: 9,   # GUARD
	2: 13,  # TITAN
	3: 20,  # FORTRESS
	4: 11,  # RADAR
	5: 4,   # SCOUT
	6: 7,   # RAIDER
	7: 14,  # SIEGE
	8: 8,   # CARRIER
	9: 6,   # MEDIC
	10: 5,  # STEALTH
	11: 15, # OMEGA_PLATFORM
	12: 10, # COMMAND
}

## 旧 WeaponType → 防御值
const _WEAPON_DEFENSE: Dictionary = {
	1: 1,   # RIFLE
	5: 1,   # SHOTGUN
	8: 1,   # LASER
	2: 2,   # MG
	7: 2,   # FLAK
	3: 1,   # ROCKET
	9: 1,   # MISSILE
	10: 2,  # OMEGA_CANNON
	11: 2,  # RAIL_CANNON
}


# ─────────────────────────────────────────────
#  旧接口兼容桥接
# ─────────────────────────────────────────────

## 获取平台基础数据（旧接口兼容）
static func get_platform_base(pt: int) -> Dictionary:
	var d: Dictionary = _PLATFORM_BASE.get(pt, {})
	if d.is_empty():
		return {"speed": 80.0, "hp": 100.0, "stationary": false}
	return d.duplicate()


## 获取平台防御值（旧接口兼容）
static func get_platform_defense(pt: int) -> int:
	return int(_PLATFORM_DEFENSE.get(pt, 8))


## 获取武器防御值（旧接口兼容）
static func get_weapon_defense(wt: int) -> int:
	return int(_WEAPON_DEFENSE.get(wt, 0))


## 获取组合防御值（旧接口兼容）
static func get_combined_defense(platform_type: int, weapon_type: int) -> int:
	return get_platform_defense(platform_type) + get_weapon_defense(weapon_type)


## 获取武器基础数据（旧接口兼容）
static func get_weapon_base(wt: int, era: int = -1) -> Dictionary:
	var base: Dictionary = _WEAPON_BASE.get(wt, {"damage": 10.0, "range": 120.0, "interval": 1.0}).duplicate()
	if era < 0:
		return base
	var e: int = clampi(era, 0, 4)
	base["damage"] = float(base["damage"]) * BattleCardV3.era_damage_multiplier(e)
	base["range"] = float(base["range"]) * BattleCardV3.era_range_multiplier(e)
	return base


## 旧接口：武器统计摘要
static func summarize_weapon_stats_weapon_row(wt: int, era: int = -1) -> String:
	var w: Dictionary = get_weapon_base(wt, era)
	var dmg: int = int(round(float(w["damage"])))
	return "伤害 %d｜射程 %s｜攻速 %s" % [dmg, _describe_weapon_range(float(w["range"])), _describe_attack_speed(float(w["interval"]))]


## 从 PlatformType + WeaponType 构造临时 CardResource，再调用 build_stats_from_card
static func _make_compat_card(platform_type: int, weapon_type: int, era: int) -> CardResource:
	var p: Dictionary = _PLATFORM_BASE.get(platform_type, {"speed": 80.0, "hp": 100.0, "stationary": false})
	var w: Dictionary = _WEAPON_BASE.get(weapon_type, {"damage": 10.0, "range": 120.0, "interval": 1.0})
	var c := CardResource.new()
	c.card_type = GC.CardType.COMBAT_UNIT
	c.era = era
	c.combat_kind = int(PLATFORM_TO_COMBAT_KIND.get(platform_type, 1))
	c.platform_type = platform_type
	c.legacy_weapon_type = weapon_type
	c.weapon_type = weapon_type
	c.base_hp = float(p.get("hp", 100.0))
	c.base_speed = float(p.get("speed", 80.0))
	c.range_value = max(1, int(round(float(w.get("range", 120.0)) / 100.0)))
	c.attack_speed = 1.0 / maxf(0.001, float(w.get("interval", 1.0)))
	var dmg: float = float(w.get("damage", 10.0))
	c.attack_light = dmg
	c.attack_armor = dmg * 0.8
	c.attack_air = dmg * 0.7
	var pd: float = float(_PLATFORM_DEFENSE.get(platform_type, 8))
	c.defense_light = pd
	c.defense_armor = pd * 1.2
	c.defense_air = pd * 0.6
	return c


## @deprecated 旧 build_stats(platform_type, weapon_type, era)，内部已转为调用 build_stats_from_card
static func build_stats(platform_type: int, weapon_type: int, era: int = -1) -> UnitStats:
	var card := _make_compat_card(platform_type, weapon_type, era)
	var stats := build_stats_from_card(card, era)
	stats.platform_type = platform_type
	return stats


## @deprecated 旧 build_multi_stats，内部已转为调用 build_stats_from_card
static func build_multi_stats(platform_type: int, weapon_types: Array, era: int = -1) -> UnitStats:
	var p: Dictionary = _PLATFORM_BASE.get(platform_type, {"speed": 80.0, "hp": 100.0, "stationary": false})
	# 取第一个武器做主武器
	var main_wt: int = int(weapon_types[0]) if weapon_types.size() > 0 else 1  # RIFLE=1
	var w: Dictionary = _WEAPON_BASE.get(main_wt, {"damage": 10.0, "range": 120.0, "interval": 1.0})

	var c := CardResource.new()
	c.card_type = GC.CardType.COMBAT_UNIT
	c.era = era
	c.combat_kind = int(PLATFORM_TO_COMBAT_KIND.get(platform_type, 1))
	c.platform_type = platform_type
	c.legacy_weapon_type = main_wt
	c.weapon_type = main_wt
	c.base_hp = float(p.get("hp", 100.0))
	c.base_speed = float(p.get("speed", 80.0))
	c.range_value = max(1, int(round(float(w.get("range", 120.0)) / 100.0)))
	c.attack_speed = 1.0 / maxf(0.001, float(w.get("interval", 1.0)))
	var dmg: float = float(w.get("damage", 10.0))
	c.attack_light = dmg
	c.attack_armor = dmg * 0.8
	c.attack_air = dmg * 0.7
	var pd: float = float(_PLATFORM_DEFENSE.get(platform_type, 8))
	c.defense_light = pd
	c.defense_armor = pd * 1.2
	c.defense_air = pd * 0.6

	var stats := build_stats_from_card(c, era)
	stats.platform_type = platform_type

	# 多武器槽
	stats.weapons.clear()
	var max_range: float = 0.0
	for wt in weapon_types:
		var we: Dictionary = _WEAPON_BASE.get(int(wt), {"damage": 10.0, "range": 120.0, "interval": 1.0}).duplicate()
		var entry: Dictionary = {
			"weapon_type": int(wt),
			"damage": float(we.get("damage", 10.0)),
			"range": float(we.get("range", 120.0)),
			"interval": float(we.get("interval", 1.0)),
			"timer": 0.0,
		}
		stats.weapons.append(entry)
		if float(we.get("range", 0.0)) > max_range:
			max_range = float(we.get("range", 0.0))

	if stats.weapons.size() > 0:
		stats.attack_range = maxf(stats.attack_range, max_range)

	return stats


## @deprecated 旧 get_platform_growth_bias，映射到新 get_combat_kind_growth_bias
static func get_platform_growth_bias(pt: int) -> Dictionary:
	var kind: int = int(PLATFORM_TO_COMBAT_KIND.get(pt, 0))
	return get_combat_kind_growth_bias(kind)
