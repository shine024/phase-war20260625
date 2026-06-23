extends RefCounted
class_name AirModifications
## 空中单位改造模块定义（14个）

const AIR_01_TURBOFAN = "air_01_turbofan"
const AIR_02_VECTOR_THRUST = "air_02_vector_thrust"
const AIR_03_STEALTH_COATING = "air_03_stealth_coating"
const AIR_04_AESA = "air_04_aesa"
const AIR_05_HELMET_SIGHT = "air_05_helmet_sight"
const AIR_06_BVR_MISSILE = "air_06_bvr_missile"
const AIR_07_DOGFIGHT_MISSILE = "air_07_dogfight_missile"
const AIR_08_ECM = "air_08_ecm"
const AIR_09_AIR_REFUEL = "air_09_air_refuel"
const AIR_10_DROP_TANK = "air_10_drop_tank"
const AIR_11_WEAPON_RACK = "air_11_weapon_rack"
const AIR_12_DATA_LINK = "air_12_data_link"
const AIR_13_EJECTION_SEAT = "air_13_ejection_seat"
const AIR_14_SWING_WING = "air_14_swing_wing"

const DATA: Dictionary = {
	"air_01_turbofan" = {
		id = AIR_01_TURBOFAN, name = "涡扇发动机", name_en = "Turbofan Engine",
		icon = "res://assets/ui/icons/mod_icons/mod_engine.png",
		prototype = "F100-PW-220", description = "高涵道比涡扇，速度提升",
		rarity = "epic",
	power_mult = 1.6, cost_research = 280, cost_install = 140,
		slot_type = "engine", conflict_group = "engine",
		effects = {move_speed = 30},
		unlock_conditions = {required_level = 4}
	},
	"air_02_vector_thrust" = {
		id = AIR_02_VECTOR_THRUST, name = "矢量推力", name_en = "Thrust Vectoring",
		icon = "res://assets/ui/icons/mod_icons/mod_thrust.png",
		prototype = "F-22/F-35", description = "推力矢量，机动性大幅提升",
		rarity = "legendary",
	power_mult = 2.0, cost_research = 450, cost_install = 225,
		slot_type = "thrust", conflict_group = "thrust",
		effects = {dodge_chance = 0.15},
		unlock_conditions = {required_level = 7}
	},
	"air_03_stealth_coating" = {
		id = AIR_03_STEALTH_COATING, name = "隐身涂层", name_en = "Stealth Coating",
		icon = "res://assets/ui/icons/mod_icons/mod_stealth.png",
		prototype = "RAM吸波材料", description = "降低被锁定概率",
		rarity = "legendary",
	power_mult = 2.0, cost_research = 500, cost_install = 250,
		slot_type = "stealth", conflict_group = "stealth",
		effects = {lock_reduction = -0.40},
		unlock_conditions = {required_level = 8}
	},
	"air_04_aesa" = {
		id = AIR_04_AESA, name = "有源相控阵雷达", name_en = "AESA Radar",
		icon = "res://assets/ui/icons/mod_icons/mod_radar.png",
		prototype = "AN/APG-77", description = "多目标锁定，大范围溅射+射程提升",
		rarity = "legendary",
	power_mult = 2.0, cost_research = 480, cost_install = 240,
		slot_type = "radar", conflict_group = "radar",
		effects = {splash_damage = 0.5, splash_radius = 0.5, attack_range = 60},
		unlock_conditions = {required_level = 7}
	},
	"air_05_helmet_sight" = {
		id = AIR_05_HELMET_SIGHT, name = "头盔瞄准具", name_en = "Helmet Mounted Sight",
		icon = "res://assets/ui/icons/mod_icons/mod_optics.png",
		prototype = "苏-27/阿帕奇", description = "头显瞄准，射速提升",
		rarity = "epic",
	power_mult = 1.6, cost_research = 300, cost_install = 150,
		slot_type = "optics", conflict_group = "optics",
		effects = {attack_interval = -0.40},
		unlock_conditions = {required_level = 5}
	},
	"air_06_bvr_missile" = {
		id = AIR_06_BVR_MISSILE, name = "超视距导弹", name_en = "BVR Missile",
		icon = "res://assets/ui/icons/mod_icons/mod_missile.png",
		prototype = "AIM-120C", description = "远程导弹，射程和精度提升",
		rarity = "epic",
	power_mult = 1.6, cost_research = 350, cost_install = 175,
		slot_type = "missile", conflict_group = "missile",
		effects = {attack_range = 90, accuracy_bonus = 0.25},
		unlock_conditions = {required_level = 6}
	},
	"air_07_dogfight_missile" = {
		id = AIR_07_DOGFIGHT_MISSILE, name = "格斗弹舱", name_en = "Dogfight Missile",
		icon = "res://assets/ui/icons/mod_icons/mod_missile.png",
		prototype = "AIM-9X", description = "近距格斗导弹，近战命中提升",
		rarity = "epic",
	power_mult = 1.6, cost_research = 320, cost_install = 160,
		slot_type = "missile", conflict_group = "missile",
		effects = {close_accuracy = 0.35},
		unlock_conditions = {required_level = 5}
	},
	"air_08_ecm" = {
		id = AIR_08_ECM, name = "电子对抗系统", name_en = "ECM Suite",
		icon = "res://assets/ui/icons/mod_icons/mod_ecm.png",
		prototype = "AN/ALQ-211", description = "电子干扰，导弹闪避提升",
		rarity = "epic",
	power_mult = 1.6, cost_research = 380, cost_install = 190,
		slot_type = "ecm", conflict_group = "ecm",
		effects = {missile_dodge = 0.30},
		unlock_conditions = {required_level = 6}
	},
	"air_09_air_refuel" = {
		id = AIR_09_AIR_REFUEL, name = "空中加油口", name_en = "Aerial Refueling",
		icon = "res://assets/ui/icons/mod_icons/mod_logistics.png",
		prototype = "伙伴加油", description = "作战时间大幅延长",
		rarity = "rare",
	power_mult = 1.3, cost_research = 220, cost_install = 110,
		slot_type = "logistics", conflict_group = "logistics",
		effects = {sustained_combat = 0.50},
		unlock_conditions = {required_level = 4}
	},
	"air_10_drop_tank" = {
		id = AIR_10_DROP_TANK, name = "副油箱", name_en = "Drop Tank",
		icon = "res://assets/ui/icons/mod_icons/mod_logistics.png",
		prototype = "增加燃料", description = "增加燃料，航程提升",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 100, cost_install = 50,
		slot_type = "logistics", conflict_group = "logistics",
		effects = {combat_range = 0.40},
		unlock_conditions = {required_level = 2}
	},
	"air_11_weapon_rack" = {
		id = AIR_11_WEAPON_RACK, name = "外挂武器架", name_en = "Weapon Rack",
		icon = "res://assets/ui/icons/mod_icons/mod_weapons.png",
		prototype = "复合挂架", description = "载弹量大幅提升",
		rarity = "rare",
	power_mult = 1.3, cost_research = 200, cost_install = 100,
		slot_type = "weapons", conflict_group = "weapons",
		effects = {ammo_capacity = 0.50},
		unlock_conditions = {required_level = 4}
	},
	"air_12_data_link" = {
		id = AIR_12_DATA_LINK, name = "数据链系统", name_en = "Data Link",
		icon = "res://assets/ui/icons/mod_icons/mod_command.png",
		prototype = "Link 16", description = "编队协同，全属性微升",
		rarity = "epic",
	power_mult = 1.6, cost_research = 340, cost_install = 170,
		slot_type = "command", conflict_group = "command",
		effects = {formation_bonus = 0.15},
		unlock_conditions = {required_level = 6}
	},
	"air_13_ejection_seat" = {
		id = AIR_13_EJECTION_SEAT, name = "钛合金浴缸座舱", name_en = "Titanium Bathtub Cockpit",
		icon = "res://assets/ui/icons/mod_icons/mod_survival.png",
		prototype = "A-10钛合金装甲浴缸", description = "钛合金装甲包裹座舱，抗弹能力大幅提升",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 120, cost_install = 60,
		slot_type = "survival", conflict_group = "survival",
		effects = {defense_armor = 0.25, max_hp = 0.10},
		unlock_conditions = {required_level = 2}
	},
	"air_14_swing_wing" = {
		id = AIR_14_SWING_WING, name = "可变后掠翼", name_en = "Swing Wing",
		icon = "res://assets/ui/icons/mod_icons/mod_aerodynamics.png",
		prototype = "F-14雄猫", description = "后掠翼，速度和机动平衡",
		rarity = "epic",
	power_mult = 1.6, cost_research = 360, cost_install = 180,
		slot_type = "aerodynamics", conflict_group = "aerodynamics",
		effects = {move_speed = 20, dodge_chance = 0.10},
		unlock_conditions = {required_level = 5}
	},
}

static func get_mod_data(mod_id: String) -> Dictionary:
	return DATA.get(mod_id, {}).duplicate(true)

static func get_all_mod_ids() -> Array:
	return DATA.keys()

static func get_for_unit_type(unit_type: int) -> Array:
	if unit_type == 3: return DATA.keys()  # AIR
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

const _CARD_PREFIXES: Array = ["cold_mig21", "cold_f4", "mod_ah64", "mod_ah1", "mod_uh60", "fut_swarm", "fut_scout_drone", "fut_attack_drone", "fut_stealth_bomber", "fut_space_fighter"]
