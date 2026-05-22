extends RefCounted
class_name UnitStatsTable
## 根据底盘类型+攻击类型返回 UnitStats（数值表）
## 时代对武器伤害/射程、对平台生命倍率与 docs/BATTLE_CARD_V3.md §1.3 一致（BattleCardV3）。

const GC = preload("res://resources/game_constants.gd")

# 平台基础：血量、是否固定（格子战不再使用移速）
static func get_platform_base(pt: int) -> Dictionary:
	match pt:
		GC.PlatformType.HOUND: return {"speed": 120.0, "hp": 60.0, "stationary": false}
		GC.PlatformType.GUARD: return {"speed": 80.0, "hp": 100.0, "stationary": false}
		GC.PlatformType.TITAN: return {"speed": 45.0, "hp": 180.0, "stationary": false}
		GC.PlatformType.FORTRESS: return {"speed": 0.0, "hp": 280.0, "stationary": true}  # 固定平台大幅提升HP
		GC.PlatformType.RADAR: return {"speed": 0.0, "hp": 200.0, "stationary": true}  # 固定雷达站
		GC.PlatformType.SCOUT: return {"speed": 140.0, "hp": 45.0, "stationary": false}
		GC.PlatformType.RAIDER: return {"speed": 95.0, "hp": 85.0, "stationary": false}
		GC.PlatformType.SIEGE: return {"speed": 25.0, "hp": 350.0, "stationary": true}  # 固定火炮大幅提升HP
		GC.PlatformType.CARRIER: return {"speed": 55.0, "hp": 130.0, "stationary": false}
		GC.PlatformType.MEDIC: return {"speed": 70.0, "hp": 90.0, "stationary": false}
		GC.PlatformType.STEALTH: return {"speed": 110.0, "hp": 55.0, "stationary": false}
		GC.PlatformType.OMEGA_PLATFORM: return {"speed": 35.0, "hp": 260.0, "stationary": false}
	return {"speed": 80.0, "hp": 100.0, "stationary": false}


static func get_platform_defense(pt: int) -> int:
	match pt:
		GC.PlatformType.SCOUT: return 4
		GC.PlatformType.HOUND: return 5
		GC.PlatformType.STEALTH: return 5
		GC.PlatformType.RAIDER: return 7
		GC.PlatformType.GUARD: return 8
		GC.PlatformType.MEDIC: return 7
		GC.PlatformType.CARRIER: return 9
		GC.PlatformType.TITAN: return 12
		GC.PlatformType.OMEGA_PLATFORM: return 14
		GC.PlatformType.RADAR: return 13
		GC.PlatformType.FORTRESS: return 16
		GC.PlatformType.SIEGE: return 15
	return 8


static func get_weapon_defense(wt: int) -> int:
	match wt:
		GC.WeaponType.RIFLE, GC.WeaponType.SHOTGUN, GC.WeaponType.LASER:
			return 1
		GC.WeaponType.MG, GC.WeaponType.FLAK:
			return 2
		GC.WeaponType.ROCKET, GC.WeaponType.MISSILE:
			return 1
		GC.WeaponType.OMEGA_CANNON, GC.WeaponType.RAIL_CANNON:
			return 2
	return 0


static func get_combined_defense(platform_type: int, weapon_type: int) -> int:
	return get_platform_defense(platform_type) + get_weapon_defense(weapon_type)


# 武器：伤害、射程、攻击间隔（表内 DPS 分档；爆炸/穿透等行为见 bullet.gd）
# era >= 0 时按关卡时代缩放（玩家/预览/与文案对齐的缴获卡摘要）
static func get_weapon_base(wt: int, era: int = -1) -> Dictionary:
	var base: Dictionary
	match wt:
		GC.WeaponType.SMG:
			base = {"damage": 7.0, "range": 90.0, "interval": 0.39}
		GC.WeaponType.PISTOL:
			base = {"damage": 5.0, "range": 80.0, "interval": 0.4}
		GC.WeaponType.RIFLE:
			base = {"damage": 12.0, "range": 150.0, "interval": 1.0}
		GC.WeaponType.SNIPER:
			base = {"damage": 17.0, "range": 230.0, "interval": 1.545}
		GC.WeaponType.MG:
			base = {"damage": 6.0, "range": 165.0, "interval": 0.24}
		GC.WeaponType.SHOTGUN:
			base = {"damage": 16.0, "range": 65.0, "interval": 1.0}
		GC.WeaponType.ROCKET:
			base = {"damage": 29.0, "range": 190.0, "interval": 1.8}
		GC.WeaponType.MISSILE:
			base = {"damage": 36.0, "range": 210.0, "interval": 2.0}
		GC.WeaponType.FLAK:
			base = {"damage": 8.0, "range": 120.0, "interval": 0.364}
		GC.WeaponType.LASER:
			base = {"damage": 11.0, "range": 180.0, "interval": 0.55}
		GC.WeaponType.OMEGA_CANNON:
			base = {"damage": 220.0, "range": 250.0, "interval": 2.2}
		GC.WeaponType.RAIL_CANNON:
			base = {"damage": 140.0, "range": 240.0, "interval": 1.65}
		_:
			base = {"damage": 10.0, "range": 120.0, "interval": 1.0}
	if era < 0:
		return base
	var scaled: Dictionary = base.duplicate()
	var e: int = clampi(era, 0, 4)
	scaled["damage"] = float(scaled["damage"]) * BattleCardV3.era_damage_multiplier(e)
	scaled["range"] = float(scaled["range"]) * BattleCardV3.era_range_multiplier(e)
	return scaled


## 按平台类型的星级成长倾斜（每星叠一层，与 BlueprintManager.apply_growth_to_stats 配合）
static func get_platform_growth_bias(pt: int) -> Dictionary:
	match pt:
		GC.PlatformType.SIEGE:
			return {"hp_bias": 0.10, "dmg_bias": 0.08, "range_bias": 0.05}
		GC.PlatformType.FORTRESS:
			return {"hp_bias": 0.12, "def_bias": 0.10}
		GC.PlatformType.TITAN:
			return {"hp_bias": 0.08, "def_bias": 0.06}
		GC.PlatformType.SCOUT, GC.PlatformType.STEALTH:
			return {"dodge_bias": 0.05, "dmg_bias": 0.06}
		GC.PlatformType.RAIDER:
			return {"dmg_bias": 0.08, "speed_bias": 0.05}
		GC.PlatformType.RADAR:
			return {"range_bias": 0.08, "def_bias": 0.04}
		GC.PlatformType.CARRIER:
			return {"hp_bias": 0.06, "heal_bias": 0.10}
		GC.PlatformType.MEDIC:
			return {"heal_bias": 0.12, "hp_bias": 0.04}
		GC.PlatformType.OMEGA_PLATFORM:
			return {"hp_bias": 0.10, "dmg_bias": 0.10, "def_bias": 0.08}
		_:
			return {"hp_bias": 0.04, "dmg_bias": 0.04}


## 平台固有数值修正（与 CardAbilityManager 光环互补，在 build_stats 末尾调用）
static func apply_platform_innate_modifiers(stats: UnitStats) -> void:
	if stats == null:
		return
	match stats.platform_type:
		GC.PlatformType.SIEGE:
			stats.attack_range *= 1.15
		GC.PlatformType.FORTRESS:
			stats.max_hp *= 1.10
		GC.PlatformType.RADAR:
			stats.attack_range *= 1.10
		GC.PlatformType.TITAN:
			stats.defense += 3.0
		GC.PlatformType.SCOUT, GC.PlatformType.STEALTH:
			stats.dodge_chance = maxf(stats.dodge_chance, 0.15)
	for i in range(stats.weapons.size()):
		var w: Dictionary = stats.weapons[i] as Dictionary
		if not w.has("range"):
			continue
		var scaled_range: float = float(w["range"])
		match stats.platform_type:
			GC.PlatformType.SIEGE:
				scaled_range *= 1.15
			GC.PlatformType.RADAR:
				scaled_range *= 1.10
		w["range"] = scaled_range
		stats.weapons[i] = w
	if stats.platform_type == GC.PlatformType.SIEGE or stats.platform_type == GC.PlatformType.RADAR:
		var max_r: float = stats.attack_range
		for w2 in stats.weapons:
			if w2 is Dictionary and float(w2.get("range", 0.0)) > max_r:
				max_r = float(w2["range"])
		stats.attack_range = max_r


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


## 用于战斗单位卡文案，与 get_weapon_base 数值一致
static func summarize_weapon_stats_weapon_row(wt: int, era: int = -1) -> String:
	var w: Dictionary = get_weapon_base(wt, era)
	var dmg: int = int(round(float(w["damage"])))
	return "伤害 %d｜射程 %s｜攻速 %s" % [dmg, _describe_weapon_range(float(w["range"])), _describe_attack_speed(float(w["interval"]))]


static func build_stats(platform_type: int, weapon_type: int, era: int = -1) -> UnitStats:
	var stats = UnitStats.new()
	var p = get_platform_base(platform_type)
	var w = get_weapon_base(weapon_type, era)
	stats.platform_type = platform_type
	stats.weapon_type = weapon_type
	stats.max_hp = float(p["hp"])
	if era >= 0:
		stats.max_hp *= BattleCardV3.era_hp_multiplier(clampi(era, 0, 4))
	stats.move_speed = 0.0
	stats.is_stationary = true
	stats.defense = float(get_combined_defense(platform_type, weapon_type))
	stats.attack_damage = w["damage"]
	stats.attack_range = w["range"]
	stats.attack_interval = w["interval"]
	stats.weapons.clear()
	apply_platform_innate_modifiers(stats)
	return stats

# 多武器版本：同一平台挂载多把武器
static func build_multi_stats(platform_type: int, weapon_types: Array, era: int = -1) -> UnitStats:
	var stats: UnitStats = UnitStats.new()
	var p = get_platform_base(platform_type)
	stats.platform_type = platform_type
	stats.max_hp = float(p["hp"])
	if era >= 0:
		stats.max_hp *= BattleCardV3.era_hp_multiplier(clampi(era, 0, 4))
	stats.move_speed = 0.0
	stats.is_stationary = true

	stats.weapons.clear()
	var max_range: float = 0.0
	for wt in weapon_types:
		var w = get_weapon_base(int(wt), era)
		var entry: Dictionary = {
			"weapon_type": int(wt),
			"damage": w["damage"],
			"range": w["range"],
			"interval": w["interval"],
			"timer": 0.0,
		}
		stats.weapons.append(entry)
		if float(w["range"]) > max_range:
			max_range = float(w["range"])

	if stats.weapons.size() > 0:
		var main = stats.weapons[0]
		stats.weapon_type = main["weapon_type"]
		stats.attack_damage = main["damage"]
		stats.attack_range = max_range
		stats.attack_interval = main["interval"]
	else:
		stats.weapon_type = 0
		stats.attack_damage = 0.0
		stats.attack_range = 0.0
		stats.attack_interval = 9999.0

	var main_wt: int = stats.weapon_type if stats.weapons.size() > 0 else int(GC.WeaponType.RIFLE)
	stats.defense = float(get_combined_defense(platform_type, main_wt))
	apply_platform_innate_modifiers(stats)
	return stats
