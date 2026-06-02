extends RefCounted
class_name ReconEvolution
## 侦察/特种进化路径
## 主线：骑兵斥候 → 幽灵特工
## 隐藏分支：狙击手路线

const MAIN_LINE: Dictionary = {
	E0 = {
		stage = 0, card_id = "ww1_cavalry", name = "骑兵斥候",
		era = "WW1", power = 15, max_hp = 85,
		attack_light = 20, attack_armor = 0, attack_air = 0,
		defense_light = 6, defense_armor = 4, defense_air = 2,
		inherit_multiplier = 0.0,
	},
	E1 = {
		stage = 1, card_id = "ww2_motorcycle", name = "侦察摩托",
		era = "WW2", power = 50, max_hp = 100,
		attack_light = 25, attack_armor = 5, attack_air = 0,
		defense_light = 12, defense_armor = 8, defense_air = 5,
		inherit_multiplier = 0.30,
		requirements = {level = 5, mods_count = 2, intel_basic = 50, power_ratio = 0.8},
	},
	E2 = {
		stage = 2, card_id = "cold_spetsnaz", name = "阿尔法特种部队",
		era = "Cold", power = 180, max_hp = 220,
		attack_light = 100, attack_armor = 30, attack_air = 15,
		defense_light = 35, defense_armor = 25, defense_air = 15,
		inherit_multiplier = 0.30,
		requirements = {level = 8, mods_count = 5, eom_count = 1, intel_basic = 75, power_ratio = 0.9},
	},
	E3 = {
		stage = 3, card_id = "mod_ranger", name = "游骑兵",
		era = "Modern", power = 340, max_hp = 320,
		attack_light = 160, attack_armor = 20, attack_air = 10,
		defense_light = 55, defense_armor = 38, defense_air = 22,
		inherit_multiplier = 0.30,
		requirements = {level = 10, mods_count = 8, eom_count = 2, intel_basic = 90, power_ratio = 1.0},
	},
	E4 = {
		stage = 4, card_id = "fut_spectre", name = "幽灵特工",
		era = "Future", power = 530, max_hp = 350,
		attack_light = 220, attack_armor = 80, attack_air = 50,
		defense_light = 60, defense_armor = 50, defense_air = 40,
		inherit_multiplier = 0.30,
		special = {stealth_first_crit = true},
		requirements = {level = 10, mods_count = 9, eom_count = 3, intel_basic = 100, power_ratio = 1.1},
	},
}

## 隐藏分支：狙击手路线
const SNIPER_BRANCH: Dictionary = {
	E2_SNIPER = {
		stage = 2, card_id = "cold_sniper", name = "SVD狙击组",
		era = "Cold", power = 175, max_hp = 160,
		attack_light = 85, attack_armor = 15, attack_air = 0,
		defense_light = 25, defense_armor = 20, defense_air = 15,
		inherit_multiplier = 0.35,
		special = {attack_range = 100, crit_chance = 0.10},
		requirements = {level = 8, mods_count = 5, combat_rating = "A+", intel_recon = 80, power_ratio = 1.0},
	},
	E3_SNIPER = {
		stage = 3, card_id = "mod_m24", name = "M24狙击组",
		era = "Modern", power = 350, max_hp = 240,
		attack_light = 130, attack_armor = 30, attack_air = 0,
		defense_light = 45, defense_armor = 30, defense_air = 25,
		inherit_multiplier = 0.40,
		special = {attack_range = 150, crit_damage = 0.3},
		requirements = {level = 10, mods_count = 8, combat_rating = "S", intel_recon = 90, power_ratio = 1.1},
	},
	E4_SNIPER = {
		stage = 4, card_id = "fut_nexus_archer", name = "虚空射手",
		era = "Future", power = 580, max_hp = 300,
		attack_light = 200, attack_armor = 100, attack_air = 0,
		defense_light = 70, defense_armor = 60, defense_air = 50,
		inherit_multiplier = 0.50,
		special = {always_hit = true},
		requirements = {level = 10, mods_count = 9, combat_rating = "S+", intel_recon = 100, power_ratio = 1.2},
	},
}

static func get_main_line() -> Dictionary:
	return MAIN_LINE.duplicate(true)

static func get_hidden_branches() -> Dictionary:
	return {sniper = SNIPER_BRANCH.duplicate(true)}

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
