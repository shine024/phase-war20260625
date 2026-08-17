extends RefCounted
class_name ArtilleryEvolution
## 炮兵进化路径
## 主线：81mm迫击炮 → 悬浮自行火炮
## 隐藏分支：空中炮艇（跨兵种）

const MAIN_LINE: Dictionary = {
	E0 = {
		stage = 0, card_id = "ww1_arty_m81", name = "81mm迫击炮组",
		era = "WW1", power = 23, max_hp = 70,
		attack_light = 40, attack_armor = 20, attack_air = 0,
		defense_light = 10, defense_armor = 8, defense_air = 5,
		inherit_multiplier = 0.0,
	},
	E1 = {
		stage = 1, card_id = "ww2_arty_m81", name = "81mm迫击炮",
		era = "WW2", power = 90, max_hp = 85,
		attack_light = 55, attack_armor = 30, attack_air = 0,
		defense_light = 15, defense_armor = 12, defense_air = 8,
		inherit_multiplier = 0.30,
		requirements = {level = 5, mods_count = 2, intel_basic = 50, power_ratio = 0.8},
	},
	E2 = {
		stage = 2, card_id = "cold_sup_m113", name = "M113迫击炮车",
		era = "Cold", power = 240, max_hp = 300,
		attack_light = 40, attack_armor = 30, attack_air = 20,
		defense_light = 30, defense_armor = 25, defense_air = 15,
		inherit_multiplier = 0.30,
		requirements = {level = 8, mods_count = 5, eom_count = 1, intel_basic = 75, power_ratio = 0.9},
	},
	E3 = {
		stage = 3, card_id = "mod_arty_m270", name = "M270火箭炮",
		era = "Modern", power = 480, max_hp = 320,
		attack_light = 180, attack_armor = 120, attack_air = 0,
		defense_light = 40, defense_armor = 30, defense_air = 20,
		inherit_multiplier = 0.30,
		requirements = {level = 10, mods_count = 8, eom_count = 2, intel_basic = 90, power_ratio = 1.0},
	},
	E4 = {
		stage = 4, card_id = "fut_howitzer", name = "悬浮自行火炮",
		era = "Future", power = 795, max_hp = 380,
		attack_light = 280, attack_armor = 200, attack_air = 0,
		defense_light = 60, defense_armor = 50, defense_air = 30,
		inherit_multiplier = 0.30,
		requirements = {level = 10, mods_count = 9, eom_count = 3, intel_basic = 100, power_ratio = 1.1},
	},
}

## v7.x: 空中炮艇隐藏分支已移除（ac130/fut_gunship 全部为 default_cards 不存在的死链）

static func get_main_line() -> Dictionary:
	return MAIN_LINE.duplicate(true)

static func get_hidden_branches() -> Dictionary:
	return {}

## @deprecated v9.x 权威判定见 BlueprintManager.can_evolve_blueprint /
## EvolutionPathRegistry.check_evolution_requirements。遗留存根恒 passed=false（fail-closed），
## 防止误用绕过进化门槛。
static func check_requirements(card: Dictionary, target_stage: String) -> Dictionary:
	push_warning("[ArtilleryEvolution] check_requirements 为废弃存根，请改用 BlueprintManager.can_evolve_blueprint / EvolutionPathRegistry.check_evolution_requirements")
	return {passed = false, missing = ["deprecated_entry_point: 权威判定见 EvolutionPathRegistry.check_evolution_requirements"]}

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
