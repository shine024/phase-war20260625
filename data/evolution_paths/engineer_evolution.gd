extends RefCounted
class_name EngineerEvolution
## 工程/支援进化路径
## 主线：工兵班 → 纳米修复蜂群

const MAIN_LINE: Dictionary = {
	E0 = {
		stage = 0, card_id = "ww1_engineer", name = "工兵班",
		era = "WW1", power = 20, max_hp = 90,
		attack_light = 15, attack_armor = 5, attack_air = 0,
		defense_light = 10, defense_armor = 8, defense_air = 5,
		inherit_multiplier = 0.0,
	},
	E1 = {
		stage = 1, card_id = "ww2_engineer", name = "战斗工兵",
		era = "WW2", power = 80, max_hp = 150,
		attack_light = 25, attack_armor = 15, attack_air = 0,
		defense_light = 20, defense_armor = 15, defense_air = 10,
		inherit_multiplier = 0.30,
		requirements = {level = 5, mods_count = 2, intel_basic = 50, power_ratio = 0.8},
	},
	E2 = {
		stage = 2, card_id = "cold_avlb", name = "装甲架桥车",
		era = "Cold", power = 300, max_hp = 400,
		attack_light = 10, attack_armor = 20, attack_air = 0,
		defense_light = 40, defense_armor = 35, defense_air = 15,
		inherit_multiplier = 0.30,
		requirements = {level = 8, mods_count = 5, eom_count = 1, intel_basic = 75, power_ratio = 0.9},
	},
	E3 = {
		stage = 3, card_id = "mod_m9ace", name = "M9 ACE工程车",
		era = "Modern", power = 500, max_hp = 600,
		attack_light = 20, attack_armor = 30, attack_air = 0,
		defense_light = 55, defense_armor = 45, defense_air = 20,
		inherit_multiplier = 0.30,
		requirements = {level = 10, mods_count = 8, eom_count = 2, intel_basic = 90, power_ratio = 1.0},
	},
	E4 = {
		stage = 4, card_id = "fut_nano_drone", name = "纳米修复蜂群",
		era = "Future", power = 1000, max_hp = 180,
		attack_light = 30, attack_armor = 10, attack_air = 0,
		defense_light = 15, defense_armor = 10, defense_air = 10,
		inherit_multiplier = 0.30,
		special = {self_repair = 0.02},
		requirements = {level = 10, mods_count = 9, eom_count = 3, intel_basic = 100, power_ratio = 1.1},
	},
}

static func get_main_line() -> Dictionary:
	return MAIN_LINE.duplicate(true)

static func get_hidden_branches() -> Dictionary:
	return {}

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
