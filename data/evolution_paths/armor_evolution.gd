extends RefCounted
class_name ArmorEvolution
## 装甲兵进化路径
## 主线一：FT-17 → 悬浮坦克（机动路线）
## 主线二：圣沙蒙 → 重装机甲（重甲路线）
## 隐藏分支：自适应装甲（豹系路线）

## 主线一：机动路线
const MOBILE_LINE: Dictionary = {
	E0 = {
		stage = 0, card_id = "ww1_ft17", name = "FT-17轻型坦克",
		era = "WW1", power = 45, max_hp = 200,
		attack_light = 28, attack_armor = 40, attack_air = 0,
		defense_light = 20, defense_armor = 25, defense_air = 5,
		inherit_multiplier = 0.0,
	},
	E1 = {
		stage = 1, card_id = "ww2_pz3", name = "三号坦克",
		era = "WW2", power = 180, max_hp = 350,
		attack_light = 40, attack_armor = 80, attack_air = 0,
		defense_light = 40, defense_armor = 55, defense_air = 10,
		inherit_multiplier = 0.30,
		requirements = {level = 5, mods_count = 2, intel_basic = 50, power_ratio = 0.8},
	},
	E2 = {
		stage = 2, card_id = "cold_t55", name = "T-55坦克",
		era = "Cold", power = 480, max_hp = 700,
		attack_light = 60, attack_armor = 140, attack_air = 0,
		defense_light = 60, defense_armor = 85, defense_air = 15,
		inherit_multiplier = 0.30,
		requirements = {level = 8, mods_count = 5, eom_count = 1, intel_basic = 75, power_ratio = 0.9},
	},
	E3 = {
		stage = 3, card_id = "mod_m1a1", name = "M1A1坦克",
		era = "Modern", power = 950, max_hp = 1100,
		attack_light = 70, attack_armor = 280, attack_air = 0,
		defense_light = 90, defense_armor = 140, defense_air = 20,
		inherit_multiplier = 0.30,
		requirements = {level = 10, mods_count = 8, eom_count = 2, intel_basic = 90, power_ratio = 1.0},
	},
	E4 = {
		stage = 4, card_id = "fut_hovertank", name = "悬浮坦克",
		era = "Future", power = 1500, max_hp = 1300,
		attack_light = 100, attack_armor = 420, attack_air = 0,
		defense_light = 80, defense_armor = 140, defense_air = 30,
		inherit_multiplier = 0.30,
		requirements = {level = 10, mods_count = 9, eom_count = 3, intel_basic = 100, power_ratio = 1.1},
	},
}

## 主线二：重甲路线
const HEAVY_LINE: Dictionary = {
	E0 = {
		stage = 0, card_id = "ww1_saint", name = "圣沙蒙坦克",
		era = "WW1", power = 50, max_hp = 280,
		attack_light = 20, attack_armor = 50, attack_air = 0,
		defense_light = 25, defense_armor = 35, defense_air = 8,
		inherit_multiplier = 0.0,
	},
	E1 = {
		stage = 1, card_id = "ww2_tiger", name = "虎式坦克",
		era = "WW2", power = 180, max_hp = 480,
		attack_light = 35, attack_armor = 130, attack_air = 0,
		defense_light = 55, defense_armor = 80, defense_air = 15,
		inherit_multiplier = 0.30,
		requirements = {level = 5, mods_count = 2, intel_basic = 50, power_ratio = 0.8},
	},
	E2 = {
		stage = 2, card_id = "cold_t72", name = "T-72坦克",
		era = "Cold", power = 480, max_hp = 850,
		attack_light = 55, attack_armor = 180, attack_air = 0,
		defense_light = 65, defense_armor = 100, defense_air = 20,
		inherit_multiplier = 0.30,
		requirements = {level = 8, mods_count = 5, eom_count = 1, intel_basic = 75, power_ratio = 0.9},
	},
	E3 = {
		stage = 3, card_id = "mod_m1a2sep", name = "M1A2 SEP",
		era = "Modern", power = 960, max_hp = 1250,
		attack_light = 75, attack_armor = 320, attack_air = 0,
		defense_light = 100, defense_armor = 160, defense_air = 30,
		inherit_multiplier = 0.30,
		requirements = {level = 10, mods_count = 8, eom_count = 2, intel_basic = 90, power_ratio = 1.0},
	},
	E4 = {
		stage = 4, card_id = "fut_heavy_mech", name = "重装机甲",
		era = "Future", power = 1580, max_hp = 1800,
		attack_light = 80, attack_armor = 500, attack_air = 0,
		defense_light = 140, defense_armor = 220, defense_air = 40,
		inherit_multiplier = 0.30,
		requirements = {level = 10, mods_count = 9, eom_count = 3, intel_basic = 100, power_ratio = 1.1},
	},
}

## 隐藏分支：豹系自适应装甲
const LEOPARD_BRANCH: Dictionary = {
	E2_LEO = {
		stage = 2, card_id = "cold_leo1", name = "豹1坦克",
		era = "Cold", power = 460, max_hp = 600,
		attack_light = 65, attack_armor = 130, attack_air = 0,
		defense_light = 55, defense_armor = 75, defense_air = 15,
		inherit_multiplier = 0.40,
		special = {move_speed = 15},
		requirements = {level = 8, mods_count = 5, intel_stealth = 80, intel_basic = 75, power_ratio = 1.0},
	},
	E3_LEO = {
		stage = 3, card_id = "mod_leo2a6", name = "豹2A6",
		era = "Modern", power = 980, max_hp = 1200,
		attack_light = 80, attack_armor = 310, attack_air = 0,
		defense_light = 100, defense_armor = 160, defense_air = 25,
		inherit_multiplier = 0.45,
		special = {crit_chance = 0.15},
		requirements = {level = 10, mods_count = 8, intel_stealth = 90, intel_basic = 85, power_ratio = 1.1},
	},
	E4_LEO = {
		stage = 4, card_id = "fut_prism", name = "光棱坦克",
		era = "Future", power = 1450, max_hp = 1000,
		attack_light = 120, attack_armor = 400, attack_air = 0,
		defense_light = 100, defense_armor = 130, defense_air = 50,
		inherit_multiplier = 0.50,
		special = {adaptive_armor = true},
		requirements = {level = 10, mods_count = 9, intel_stealth = 100, intel_basic = 100, power_ratio = 1.2},
	},
}

static func get_main_line() -> Dictionary:
	return MOBILE_LINE.duplicate(true)

static func get_secondary_line() -> Dictionary:
	return HEAVY_LINE.duplicate(true)

static func get_hidden_branches() -> Dictionary:
	return {leopard = LEOPARD_BRANCH.duplicate(true)}

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
