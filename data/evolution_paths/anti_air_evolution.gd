extends RefCounted
class_name AntiAirEvolution
## 防空兵进化路径
## 主线：37mm高射炮 → 防空悬浮车
## 隐藏分支：弹炮合一系统

const MAIN_LINE: Dictionary = {
	E0 = {
		stage = 0, card_id = "ww1_37mm", name = "37mm高射炮",
		era = "WW1", power = 23, max_hp = 70,
		attack_light = 15, attack_armor = 0, attack_air = 50,
		defense_light = 12, defense_armor = 10, defense_air = 18,
		inherit_multiplier = 0.0,
	},
	E1 = {
		stage = 1, card_id = "ww2_flak", name = "88mm防空塔",
		era = "WW2", power = 220, max_hp = 800,
		attack_light = 40, attack_armor = 30, attack_air = 200,
		defense_light = 60, defense_armor = 50, defense_air = 100,
		inherit_multiplier = 0.30,
		requirements = {level = 5, mods_count = 2, intel_basic = 50, power_ratio = 0.8},
	},
	E2 = {
		stage = 2, card_id = "cold_zsu23", name = "ZSU-23-4",
		era = "Cold", power = 240, max_hp = 350,
		attack_light = 30, attack_armor = 10, attack_air = 150,
		defense_light = 35, defense_armor = 25, defense_air = 50,
		inherit_multiplier = 0.30,
		requirements = {level = 8, mods_count = 5, eom_count = 1, intel_basic = 75, power_ratio = 0.9},
	},
	E3 = {
		stage = 3, card_id = "mod_m6", name = "M6自行高炮",
		era = "Modern", power = 480, max_hp = 300,
		attack_light = 40, attack_armor = 20, attack_air = 280,
		defense_light = 45, defense_armor = 35, defense_air = 60,
		inherit_multiplier = 0.30,
		requirements = {level = 10, mods_count = 8, eom_count = 2, intel_basic = 90, power_ratio = 1.0},
	},
	E4 = {
		stage = 4, card_id = "fut_aa_hover", name = "防空悬浮车",
		era = "Future", power = 780, max_hp = 350,
		attack_light = 60, attack_armor = 40, attack_air = 400,
		defense_light = 60, defense_armor = 50, defense_air = 100,
		inherit_multiplier = 0.30,
		requirements = {level = 10, mods_count = 9, eom_count = 3, intel_basic = 100, power_ratio = 1.1},
	},
}

## 隐藏分支：弹炮合一
const COMBINED_BRANCH: Dictionary = {
	E3_CB = {
		stage = 3, card_id = "pantsir", name = "铠甲-S1",
		era = "Modern", power = 500, max_hp = 320,
		attack_light = 50, attack_armor = 30, attack_air = 300,
		defense_light = 50, defense_armor = 40, defense_air = 70,
		inherit_multiplier = 0.40,
		special = {full_coverage = true},
		requirements = {level = 10, mods_count = 8, intel_air = 85, intel_tech = 85, power_ratio = 1.0},
	},
	E4_CB = {
		stage = 4, card_id = "fut_aa_mech", name = "防空机甲",
		era = "Future", power = 850, max_hp = 400,
		attack_light = 70, attack_armor = 50, attack_air = 450,
		defense_light = 70, defense_armor = 60, defense_air = 120,
		inherit_multiplier = 0.45,
		special = {intercept_barrage = true},
		requirements = {level = 10, mods_count = 9, intel_air = 100, intel_tech = 100, power_ratio = 1.2},
	},
}

static func get_main_line() -> Dictionary:
	return MAIN_LINE.duplicate(true)

static func get_hidden_branches() -> Dictionary:
	return {combined = COMBINED_BRANCH.duplicate(true)}

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
