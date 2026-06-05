extends RefCounted
class_name AntiAirModifications
## 防空兵改造模块定义（12个）

const AA_01_RADAR = "aa_01_radar"
const AA_02_IFF = "aa_02_iff"
const AA_03_MISSILE_RAIL = "aa_03_missile_rail"
const AA_04_QUAD_MOUNT = "aa_04_quad_mount"
const AA_05_PROXIMITY_FUZE = "aa_05_proximity_fuze"
const AA_06_LASER = "aa_06_laser"
const AA_07_AESA = "aa_07_aesa"
const AA_08_POWER_GEN = "aa_08_power_gen"
const AA_09_SMOKE_LAUNCHER = "aa_09_smoke_launcher"
const AA_10_CAMOUFLAGE = "aa_10_camouflage"
const AA_11_AUTO_FC = "aa_11_auto_fc"
const AA_12_FIRE_ON_MOVE = "aa_12_fire_on_move"

const DATA: Dictionary = {
	"aa_01_radar" = {
		id = AA_01_RADAR, name = "炮瞄雷达", name_en = "Fire Control Radar",
		prototype = "SCR-584", description = "自动跟踪，命中和射速提升",
		rarity = "rare",
	power_mult = 1.3, cost_research = 180, cost_install = 90,
		slot_type = "radar", conflict_group = "radar",
		effects = {accuracy_bonus = 0.30, attack_interval = -0.50},
		unlock_conditions = {required_level = 3}
	},
	"aa_02_iff" = {
		id = AA_02_IFF, name = "敌我识别器", name_en = "IFF",
		prototype = "IFF Mark X", description = "防止误击友军",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 80, cost_install = 40,
		slot_type = "electronics", conflict_group = "electronics",
		effects = {no_friendly_fire = true},
		unlock_conditions = {required_level = 1}
	},
	"aa_03_missile_rail" = {
		id = AA_03_MISSILE_RAIL, name = "防空导弹挂架", name_en = "Missile Rail",
		prototype = "毒刺/萨姆-7", description = "对空火力大幅提升",
		rarity = "epic",
	power_mult = 1.6, cost_research = 280, cost_install = 140,
		slot_type = "missile", conflict_group = "missile",
		effects = {attack_air = 0.40},
		unlock_conditions = {required_level = 4}
	},
	"aa_04_quad_mount" = {
		id = AA_04_QUAD_MOUNT, name = "双联/四联装", name_en = "Quad Mount",
		prototype = "M45四联.50", description = "多管并联，射速提升",
		rarity = "rare",
	power_mult = 1.3, cost_research = 200, cost_install = 100,
		slot_type = "mount", conflict_group = "mount",
		effects = {attack_interval = -0.35},
		unlock_conditions = {required_level = 3}
	},
	"aa_05_proximity_fuze" = {
		id = AA_05_PROXIMITY_FUZE, name = "近炸引信", name_en = "Proximity Fuze",
		prototype = "二战重大发明", description = "命中率和溅射提升",
		rarity = "epic",
	power_mult = 1.6, cost_research = 300, cost_install = 150,
		slot_type = "fuze", conflict_group = "fuze",
		effects = {accuracy_bonus = 0.40, splash_radius = 0.30},
		unlock_conditions = {required_level = 5}
	},
	"aa_06_laser" = {
		id = AA_06_LASER, name = "激光近防系统", name_en = "Laser CIWS",
		prototype = "HELIOS", description = "30%拦截导弹，无限弹药",
		rarity = "legendary",
	power_mult = 2.0, cost_research = 500, cost_install = 250,
		slot_type = "laser", conflict_group = "laser",
		effects = {missile_intercept = 0.30, infinite_ammo = true},
		unlock_conditions = {required_level = 8}
	},
	"aa_07_aesa" = {
		id = AA_07_AESA, name = "相控阵雷达", name_en = "AESA Radar",
		prototype = "AN/MPQ-65", description = "多目标锁定，射程提升",
		rarity = "legendary",
	power_mult = 2.0, cost_research = 450, cost_install = 225,
		slot_type = "radar", conflict_group = "radar",
		effects = {multi_target = 3, attack_range = 60},
		unlock_conditions = {required_level = 7}
	},
	"aa_08_power_gen" = {
		id = AA_08_POWER_GEN, name = "车载发电机组", name_en = "Power Generator",
		prototype = "自行高炮必备", description = "持续作战，无限电力",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 100, cost_install = 50,
		slot_type = "power", conflict_group = "power",
		effects = {sustained_fire = 1.0},
		unlock_conditions = {required_level = 2}
	},
	"aa_09_smoke_launcher" = {
		id = AA_09_SMOKE_LAUNCHER, name = "烟幕弹发射器", name_en = "Smoke Launcher",
		prototype = "76mm烟幕", description = "闪避制导武器",
		rarity = "rare",
	power_mult = 1.3, cost_research = 160, cost_install = 80,
		slot_type = "countermeasure", conflict_group = "countermeasure",
		effects = {missile_dodge = 0.30},
		unlock_conditions = {required_level = 3}
	},
	"aa_10_camouflage" = {
		id = AA_10_CAMOUFLAGE, name = "伪装网", name_en = "Camouflage Net",
		prototype = "红外伪装网", description = "降低被攻击优先级",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 90, cost_install = 45,
		slot_type = "stealth", conflict_group = "stealth",
		effects = {aggro_reduce = -0.30},
		unlock_conditions = {required_level = 2}
	},
	"aa_11_auto_fc" = {
		id = AA_11_AUTO_FC, name = "自动化火控", name_en = "Auto Fire Control",
		prototype = "天空卫士", description = "全自动火控，射速和精度提升",
		rarity = "epic",
	power_mult = 1.6, cost_research = 320, cost_install = 160,
		slot_type = "fire_control", conflict_group = "fire_control",
		effects = {attack_interval = -0.50, accuracy_bonus = 0.15},
		unlock_conditions = {required_level = 5}
	},
	"aa_12_fire_on_move" = {
		id = AA_12_FIRE_ON_MOVE, name = "行进间射击", name_en = "Fire on Move",
		prototype = "ZSU-23-4", description = "移动中可射击，精度略降",
		rarity = "epic",
	power_mult = 1.6, cost_research = 300, cost_install = 150,
		slot_type = "mobility", conflict_group = "mobility",
		effects = {mobile_fire = true, accuracy_penalty = -0.20},
		unlock_conditions = {required_level = 5}
	},
}

static func get_mod_data(mod_id: String) -> Dictionary:
	return DATA.get(mod_id, {}).duplicate(true)

static func get_all_mod_ids() -> Array:
	return DATA.keys()

static func get_for_unit_type(unit_type: int) -> Array:
	if unit_type == 2: return DATA.keys()  # SUPPORT
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

const _CARD_PREFIXES: Array = ["ww1_37mm", "cold_zsu23", "cold_sam7", "mod_m6", "mod_stinger", "fut_aa_hover"]
