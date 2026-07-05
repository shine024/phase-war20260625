extends RefCounted
class_name ReconEvolution
## 侦察/特种进化路径
## 主线：骑兵斥候 → 幽灵特工
## v7.x: 删除原 SNIPER_BRANCH（cold_sniper/mod_m24/fut_nexus_archer 全部为 default_cards 不存在的死链）
## v7.x: 删除原 E1 ww2_motorcycle（死链），主线缩为骑兵斥候→阿尔法特种部队→游骑兵→幽灵特工

const MAIN_LINE: Dictionary = {
	E0 = {
		stage = 0, card_id = "ww1_cavalry", name = "骑兵斥候",
		era = "WW1", power = 15, max_hp = 85,
		attack_light = 20, attack_armor = 0, attack_air = 0,
		defense_light = 6, defense_armor = 4, defense_air = 2,
		inherit_multiplier = 0.0,
	},
	E1 = {
		stage = 1, card_id = "cold_spetsnaz", name = "阿尔法特种部队",
		era = "Cold", power = 180, max_hp = 220,
		attack_light = 100, attack_armor = 30, attack_air = 15,
		defense_light = 35, defense_armor = 25, defense_air = 15,
		inherit_multiplier = 0.30,
		requirements = {level = 5, mods_count = 2, intel_basic = 50, power_ratio = 0.8},
	},
	E2 = {
		stage = 2, card_id = "mod_ranger", name = "游骑兵",
		era = "Modern", power = 340, max_hp = 320,
		attack_light = 160, attack_armor = 20, attack_air = 10,
		defense_light = 55, defense_armor = 38, defense_air = 22,
		inherit_multiplier = 0.30,
		requirements = {level = 8, mods_count = 5, eom_count = 1, intel_basic = 75, power_ratio = 0.9},
	},
	E3 = {
		stage = 3, card_id = "fut_spectre", name = "幽灵特工",
		era = "Future", power = 530, max_hp = 350,
		attack_light = 220, attack_armor = 80, attack_air = 50,
		defense_light = 60, defense_armor = 50, defense_air = 40,
		inherit_multiplier = 0.30,
		special = {stealth_first_crit = true},
		requirements = {level = 10, mods_count = 9, eom_count = 3, intel_basic = 100, power_ratio = 1.1},
	},
}

static func get_main_line() -> Dictionary:
	return MAIN_LINE.duplicate(true)

## v7.x: 狙击手隐藏分支已移除（全部节点为死链）
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
