extends RefCounted
class_name AirEvolution
## 空中单位进化路径
## 主线一：米格-21 → 空天战斗机（制空路线）
## 主线二：AH-1 → 蜂群无人机（对地攻击路线）
## 隐藏分支：隐形轰炸机

const AIR_SUPERIORITY_LINE: Dictionary = {
	E0 = {
		stage = 0, card_id = "cold_mig21", name = "米格-21战斗机",
		era = "Cold", power = 400, max_hp = 250,
		attack_light = 60, attack_armor = 50, attack_air = 160,
		defense_light = 20, defense_armor = 15, defense_air = 40,
		inherit_multiplier = 0.0,
	},
	E1 = {
		stage = 1, card_id = "mod_f16", name = "F-16战隼",
		era = "Modern", power = 600, max_hp = 280,
		attack_light = 80, attack_armor = 70, attack_air = 200,
		defense_light = 25, defense_armor = 20, defense_air = 45,
		inherit_multiplier = 0.30,
		requirements = {level = 5, mods_count = 2, intel_basic = 50, power_ratio = 0.8},
	},
	E2 = {
		stage = 2, card_id = "fut_f22", name = "F-22猛禽",
		era = "Future", power = 1000, max_hp = 350,
		attack_light = 100, attack_armor = 90, attack_air = 300,
		defense_light = 35, defense_armor = 30, defense_air = 60,
		inherit_multiplier = 0.30,
		requirements = {level = 8, mods_count = 5, eom_count = 1, intel_basic = 75, power_ratio = 0.9},
	},
	E3 = {
		stage = 3, card_id = "fut_space_fighter", name = "空天战斗机",
		era = "Ultimate", power = 1325, max_hp = 450,
		attack_light = 120, attack_armor = 100, attack_air = 350,
		defense_light = 40, defense_armor = 35, defense_air = 80,
		inherit_multiplier = 0.30,
		requirements = {level = 10, mods_count = 8, eom_count = 2, intel_basic = 90, power_ratio = 1.0},
	},
}

## 主线二：对地攻击路线
const GROUND_ATTACK_LINE: Dictionary = {
	E0 = {
		stage = 0, card_id = "mod_ah1", name = "AH-1眼镜蛇",
		era = "Modern", power = 780, max_hp = 320,
		attack_light = 140, attack_armor = 250, attack_air = 80,
		defense_light = 30, defense_armor = 25, defense_air = 35,
		inherit_multiplier = 0.0,
	},
	E1 = {
		stage = 1, card_id = "mod_ah64", name = "AH-64阿帕奇",
		era = "Modern", power = 800, max_hp = 350,
		attack_light = 160, attack_armor = 280, attack_air = 100,
		defense_light = 35, defense_armor = 30, defense_air = 40,
		inherit_multiplier = 0.30,
		requirements = {level = 5, mods_count = 2, intel_basic = 50, power_ratio = 0.8},
	},
	E2 = {
		stage = 2, card_id = "fut_attack_drone", name = "攻击无人机",
		era = "Future", power = 1300, max_hp = 280,
		attack_light = 150, attack_armor = 280, attack_air = 100,
		defense_light = 25, defense_armor = 20, defense_air = 30,
		inherit_multiplier = 0.30,
		requirements = {level = 8, mods_count = 5, eom_count = 1, intel_basic = 75, power_ratio = 0.9},
	},
	E3 = {
		stage = 3, card_id = "fut_swarm", name = "蜂群无人机",
		era = "Ultimate", power = 1200, max_hp = 200,
		attack_light = 100, attack_armor = 60, attack_air = 80,
		defense_light = 20, defense_armor = 15, defense_air = 25,
		inherit_multiplier = 0.30,
		special = {swarm_intel = true},
		requirements = {level = 10, mods_count = 8, eom_count = 2, intel_basic = 90, power_ratio = 1.0},
	},
}

## 隐藏分支：隐形轰炸机
const STEALTH_BRANCH: Dictionary = {
	E2_STEALTH = {
		stage = 2, card_id = "fut_b2", name = "B-2幽灵",
		era = "Future", power = 950, max_hp = 300,
		attack_light = 120, attack_armor = 200, attack_air = 0,
		defense_light = 40, defense_armor = 35, defense_air = 50,
		inherit_multiplier = 0.40,
		special = {stealth_first_crit = true},
		requirements = {level = 10, mods_count = 8, intel_air = 85, intel_stealth = 85, power_ratio = 1.0},
	},
	E3_STEALTH = {
		stage = 3, card_id = "fut_stealth_bomber", name = "隐身轰炸机",
		era = "Ultimate", power = 1400, max_hp = 350,
		attack_light = 180, attack_armor = 300, attack_air = 0,
		defense_light = 50, defense_armor = 45, defense_air = 65,
		inherit_multiplier = 0.45,
		special = {plasma_stealth = true},
		requirements = {level = 10, mods_count = 9, intel_air = 100, intel_stealth = 100, power_ratio = 1.2},
	},
}

static func get_main_line() -> Dictionary:
	return AIR_SUPERIORITY_LINE.duplicate(true)

static func get_secondary_line() -> Dictionary:
	return GROUND_ATTACK_LINE.duplicate(true)

static func get_hidden_branches() -> Dictionary:
	return {stealth = STEALTH_BRANCH.duplicate(true)}

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
