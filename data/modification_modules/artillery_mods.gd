extends RefCounted
class_name ArtilleryModifications
## 炮兵改造模块定义（12个）

const ART_01_RIFLING = "art_01_rifling"
const ART_02_EXTENDED_RANGE = "art_02_extended_range"
const ART_03_GUIDED_SHELL = "art_03_guided_shell"
const ART_04_CLUSTER_MUNITION = "art_04_cluster_munition"
const ART_05_COUNTER_BATTERY_RADAR = "art_05_counter_battery_radar"
const ART_06_FIRE_COMPUTER = "art_06_fire_computer"
const ART_07_AMMO_SUPPLY = "art_07_ammo_supply"
const ART_08_UAV = "art_08_uav"
const ART_09_RAPID_FIRE = "art_09_rapid_fire"
const ART_10_AUTO_NAV = "art_10_auto_nav"
const ART_11_THERMOBARIC = "art_11_thermobaric"
const ART_12_FORTIFICATION = "art_12_fortification"

const DATA: Dictionary = {
	"art_01_rifling" = {
		id = ART_01_RIFLING,
		name = "膛线强化",
		name_en = "Enhanced Rifling",
		icon = "res://assets/ui/icons/mod_icons/mod_barrel.png",
		prototype = "莱茵金属L55",
		description = "加长炮管+膛线优化，射程和精度提升",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 160,
		cost_install = 80,
		slot_type = "barrel",
		conflict_group = "barrel",
		effects = {attack_range = 60, attack_light = 0.10},
		unlock_conditions = {required_level = 2}
	},

	"art_02_extended_range" = {
		id = ART_02_EXTENDED_RANGE,
		name = "增程弹",
		name_en = "Extended Range Munition",
		icon = "res://assets/ui/icons/mod_icons/mod_ammunition.png",
		prototype = "M549火箭增程弹",
		description = "火箭增程，射程大幅提升，威力略降",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 180,
		cost_install = 90,
		slot_type = "ammunition",
		conflict_group = "ammunition",
		effects = {attack_range = 90, attack_light = -0.10},
		unlock_conditions = {required_level = 3}
	},

	"art_03_guided_shell" = {
		id = ART_03_GUIDED_SHELL,
		name = "精确制导炮弹",
		name_en = "Guided Shell",
		icon = "res://assets/ui/icons/mod_icons/mod_guidance.png",
		prototype = "M982神剑",
		description = "GPS制导，命中率大幅提升",
		rarity = "legendary",
	power_mult = 2.0,
		cost_research = 400,
		cost_install = 200,
		slot_type = "guidance",
		conflict_group = "guidance",
		effects = {accuracy_bonus = 0.50, crit_chance = 0.15, weapon_type = 9},  # v6.5 MISSILE,
		unlock_conditions = {required_level = 6}
	},

	"art_04_cluster_munition" = {
		id = ART_04_CLUSTER_MUNITION,
		name = "子母弹",
		name_en = "Cluster Munition",
		icon = "res://assets/ui/icons/mod_icons/mod_ammunition.png",
		prototype = "M26火箭弹",
		description = "范围伤害增加，单目标伤害略降",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 280,
		cost_install = 140,
		slot_type = "ammunition",
		conflict_group = "ammunition",
		effects = {splash_radius = 0.50, single_target_penalty = -0.20, weapon_type = 9},  # v6.5 MISSILE,
		unlock_conditions = {required_level = 5}
	},

	"art_05_counter_battery_radar" = {
		id = ART_05_COUNTER_BATTERY_RADAR,
		name = "反炮兵雷达",
		name_en = "Counter-Battery Radar",
		icon = "res://assets/ui/icons/mod_icons/mod_radar.png",
		prototype = "AN/TPQ-53",
		description = "反击时火力大幅提升",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 300,
		cost_install = 150,
		slot_type = "radar",
		conflict_group = "radar",
		effects = {counter_bonus = 0.30},
		unlock_conditions = {required_level = 5}
	},

	"art_06_fire_computer" = {
		id = ART_06_FIRE_COMPUTER,
		name = "射击计算机",
		name_en = "Fire Control Computer",
		icon = "res://assets/ui/icons/mod_icons/mod_fire_control.png",
		prototype = "M18弹道计算机",
		description = "自动计算弹道，射速大幅提升",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 320,
		cost_install = 160,
		slot_type = "fire_control",
		conflict_group = "fire_control",
		effects = {attack_interval = -0.30},  # v6.0 平衡性调整: -40% → -30%
		unlock_conditions = {required_level = 5}
	},

	"art_07_ammo_supply" = {
		id = ART_07_AMMO_SUPPLY,
		name = "弹药运输车",
		name_en = "Ammo Supply Vehicle",
		icon = "res://assets/ui/icons/mod_icons/mod_logistics.png",
		prototype = "补给车",
		description = "持续射击时间大幅延长",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 200,
		cost_install = 100,
		slot_type = "logistics",
		conflict_group = "logistics",
		effects = {sustained_fire = 0.50},
		unlock_conditions = {required_level = 4}
	},

	"art_08_uav" = {
		id = ART_08_UAV,
		name = "炮兵侦察无人机",
		name_en = "Artillery UAV",
		icon = "res://assets/ui/icons/mod_icons/mod_recon.png",
		prototype = "RQ-7影子",
		description = "无人机校射，命中提升+炮兵攻速提升",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 350,
		cost_install = 175,
		slot_type = "recon",
		conflict_group = "recon",
		effects = {accuracy_bonus = 0.20, attack_interval = -0.15},
		unlock_conditions = {required_level = 6}
	},

	"art_09_rapid_fire" = {
		id = ART_09_RAPID_FIRE,
		name = "急速射系统",
		name_en = "Rapid Fire System",
		icon = "res://assets/ui/icons/mod_icons/mod_autoloader.png",
		prototype = "立楔式炮闩",
		description = "优化装填流程，射速提升",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 220,
		cost_install = 110,
		slot_type = "autoloader",
		conflict_group = "autoloader",
		effects = {attack_interval = -0.20},  # v6.0 平衡性调整: -30% → -20%
		unlock_conditions = {required_level = 4}
	},

	"art_10_auto_nav" = {
		id = ART_10_AUTO_NAV,
		name = "自动导航系统",
		name_en = "Auto Navigation",
		icon = "res://assets/ui/icons/mod_icons/mod_mobility.png",
		prototype = "车载GPS/惯导",
		description = "自动行进定位，部署速度提升",
		rarity = "uncommon",
	power_mult = 1.0,
		cost_research = 100,
		cost_install = 50,
		slot_type = "mobility",
		conflict_group = "mobility",
		effects = {deploy_speed = 2},
		unlock_conditions = {required_level = 2}
	},

	"art_11_thermobaric" = {
		id = ART_11_THERMOBARIC,
		name = "温压弹",
		name_en = "Thermobaric Munition",
		icon = "res://assets/ui/icons/mod_icons/mod_ammunition.png",
		prototype = "TOS-1喷火坦克",
		description = "温压弹头，对堡垒伤害大幅提升",
		rarity = "legendary",
	power_mult = 2.0,
		cost_research = 450,
		cost_install = 225,
		slot_type = "ammunition",
		conflict_group = "ammunition",
		effects = {attack_fort = 0.50},
		unlock_conditions = {required_level = 7}
	},

	"art_12_fortification" = {
		id = ART_12_FORTIFICATION,
		name = "火炮掩体",
		name_en = "Artillery Fortification",
		icon = "res://assets/ui/icons/mod_icons/mod_fortification.png",
		prototype = "混凝土阵地",
		description = "防御阵地，防护提升，部署略慢",
		rarity = "uncommon",
	power_mult = 1.0,
		cost_research = 120,
		cost_install = 60,
		slot_type = "fortification",
		conflict_group = "fortification",
		effects = {defense_light = 0.40, deploy_speed = -1},
		unlock_conditions = {required_level = 2}
	},
}

static func get_mod_data(mod_id: String) -> Dictionary:
	return DATA.get(mod_id, {}).duplicate(true)

static func get_all_mod_ids() -> Array:
	return DATA.keys()

static func get_for_unit_type(unit_type: int) -> Array:
	# Artillery is SUPPORT (2)
	if unit_type == 2:
		return DATA.keys()
	return []

static func check_conflict(mod_id_a: String, mod_id_b: String) -> bool:
	var data_a = get_mod_data(mod_id_a)
	var data_b = get_mod_data(mod_id_b)
	return data_a.get("conflict_group", "") == data_b.get("conflict_group", "") and data_a.get("conflict_group", "") != ""

## 按 card_id 精筛（优先于 get_for_unit_type）
static func get_for_card(card_id: String) -> Array:
	if _matches_card(card_id):
		return DATA.keys()
	return []

static func _matches_card(card_id: String) -> bool:
	for prefix in _CARD_PREFIXES:
		if card_id.begins_with(prefix):
			return true
	return false

const _CARD_PREFIXES: Array = ["ww1_m81", "ww1_m76", "ww1_77mm", "ww1_105mm", "ww1_mg08", "ww1_vickers", "ww2_m81", "ww2_m120", "ww2_mg42", "ww2_browning", "cold_m113", "mod_m270", "fut_howitzer", "fut_stormcore"]
