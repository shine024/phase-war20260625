extends RefCounted
class_name FortEvolution
## 堡垒单位进化路径
## 主线一：碉堡 → 离子炮台（防御路线）
## 主线二：防空塔 → 能量护盾（防空路线）
## 隐藏分支：雷达站（情报路线）

const DEFENSE_LINE: Dictionary = {
	E0 = {
		stage = 0, card_id = "fort_ww1_pillbox", name = "机枪碉堡",
		era = "WW1", power = 80, max_hp = 600,
		attack_light = 60, attack_armor = 0, attack_air = 40,
		defense_light = 50, defense_armor = 40, defense_air = 30,
		inherit_multiplier = 0.0,
	},
	E1 = {
		stage = 1, card_id = "fort_ww2_bunker", name = "混凝土碉堡",
		era = "WW2", power = 200, max_hp = 1000,
		attack_light = 80, attack_armor = 0, attack_air = 60,
		defense_light = 80, defense_armor = 70, defense_air = 50,
		inherit_multiplier = 0.30,
		requirements = {level = 5, mods_count = 2, intel_basic = 50, power_ratio = 0.8},
	},
	E2 = {
		stage = 2, card_id = "fort_cold_missile", name = "导弹发射井",
		era = "Cold", power = 500, max_hp = 1200,
		attack_light = 120, attack_armor = 200, attack_air = 100,
		defense_light = 100, defense_armor = 90, defense_air = 70,
		inherit_multiplier = 0.30,
		requirements = {level = 8, mods_count = 5, eom_count = 1, intel_basic = 75, power_ratio = 0.9},
	},
	E3 = {
		stage = 3, card_id = "fort_modern_citadel", name = "要塞核心",
		era = "Modern", power = 800, max_hp = 2000,
		attack_light = 120, attack_armor = 150, attack_air = 80,
		defense_light = 150, defense_armor = 140, defense_air = 100,
		inherit_multiplier = 0.30,
		requirements = {level = 10, mods_count = 8, eom_count = 2, intel_basic = 90, power_ratio = 1.0},
	},
	E4 = {
		stage = 4, card_id = "fort_future_ion", name = "离子炮台",
		era = "Future", power = 1200, max_hp = 2500,
		attack_light = 200, attack_armor = 300, attack_air = 150,
		defense_light = 200, defense_armor = 180, defense_air = 130,
		inherit_multiplier = 0.30,
		requirements = {level = 10, mods_count = 9, eom_count = 3, intel_basic = 100, power_ratio = 1.1},
	},
}

## 主线二：防空路线
const SHIELD_LINE: Dictionary = {
	E0 = {
		stage = 0, card_id = "fort_ww2_flak", name = "88mm防空塔",
		era = "WW2", power = 220, max_hp = 800,
		attack_light = 40, attack_armor = 30, attack_air = 200,
		defense_light = 60, defense_armor = 50, defense_air = 100,
		inherit_multiplier = 0.0,
	},
	E1 = {
		stage = 1, card_id = "fort_modern_phalanx", name = "近防炮系统",
		era = "Modern", power = 600, max_hp = 1000,
		attack_light = 50, attack_armor = 20, attack_air = 300,
		defense_light = 80, defense_armor = 60, defense_air = 120,
		inherit_multiplier = 0.30,
		requirements = {level = 8, mods_count = 5, eom_count = 1, intel_basic = 75, power_ratio = 0.9},
	},
	E2 = {
		stage = 2, card_id = "fort_future_shield", name = "能量护盾发生器",
		era = "Future", power = 1000, max_hp = 3000,
		attack_light = 0, attack_armor = 0, attack_air = 0,
		defense_light = 200, defense_armor = 180, defense_air = 200,
		inherit_multiplier = 0.30,
		special = {force_field = true},
		requirements = {level = 10, mods_count = 9, eom_count = 3, intel_basic = 100, power_ratio = 1.1},
	},
}

## 隐藏分支：雷达站
const RADAR_BRANCH: Dictionary = {
	E2_RADAR = {
		stage = 2, card_id = "fort_cold_radar", name = "雷达站",
		era = "Cold", power = 350, max_hp = 500,
		attack_light = 0, attack_armor = 0, attack_air = 0,
		defense_light = 40, defense_armor = 30, defense_air = 40,
		inherit_multiplier = 0.40,
		special = {full_map_warning = true, recon_bonus = 0.30},
		requirements = {level = 8, mods_count = 5, intel_recon = 80, intel_stealth = 80, power_ratio = 1.0},
	},
}

static func get_main_line() -> Dictionary:
	return DEFENSE_LINE.duplicate(true)

static func get_secondary_line() -> Dictionary:
	return SHIELD_LINE.duplicate(true)

static func get_hidden_branches() -> Dictionary:
	return {radar = RADAR_BRANCH.duplicate(true)}

static func check_requirements(card: Dictionary, target_stage: String) -> Dictionary:
	return {passed = true, missing = []}

static func calculate_evolved_stats(old_card: Dictionary, target_node: Dictionary) -> Dictionary:
	return {
		max_hp = target_node.max_hp,
		attack_light = target_node.attack_light,
		attack_armor = target_node.attack_armor,
		attack_air = target_node.attack_air,
		defense_light = target_node.defense_light,
		defense_armor = target_node.defense_armor,
		defense_air = target_node.defense_air,
	}
