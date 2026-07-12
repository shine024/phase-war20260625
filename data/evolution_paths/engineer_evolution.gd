extends RefCounted
class_name EngineerEvolution
## 工程/支援进化路径
## 主线：工兵班 → 纳米修复蜂群
## v7.x: 删除原 E1 ww2_engineer/E2 cold_avlb/E3 mod_m9ace（全部为 default_cards 不存在的死链）
##       主线缩为 工兵班→纳米修复蜂群（与执行层 lineage_config/supplement 对齐：工程兵无真正中段进化）

const MAIN_LINE: Dictionary = {
	E0 = {
		stage = 0, card_id = "ww1_sup_engineer", name = "工兵班",
		era = "WW1", power = 20, max_hp = 90,
		attack_light = 15, attack_armor = 5, attack_air = 0,
		defense_light = 10, defense_armor = 8, defense_air = 5,
		inherit_multiplier = 0.0,
	},
	E1 = {
		stage = 1, card_id = "fut_nano_drone", name = "纳米修复蜂群",
		era = "Future", power = 1000, max_hp = 180,
		attack_light = 30, attack_armor = 10, attack_air = 0,
		defense_light = 15, defense_armor = 10, defense_air = 10,
		inherit_multiplier = 0.30,
		special = {self_repair = 0.02},
		requirements = {level = 8, mods_count = 5, eom_count = 1, intel_basic = 75, power_ratio = 0.9},
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
