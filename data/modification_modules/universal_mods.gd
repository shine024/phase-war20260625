extends RefCounted
class_name UniversalModifications
## 通用改造模块定义（10个）
## 可用于多个兵种

const GEN_01_COMMS = "gen_01_comms"
const GEN_02_DIGITAL = "gen_02_digital"
const GEN_03_CAMOUFLAGE = "gen_03_camouflage"
const GEN_04_VEST = "gen_04_vest"
const GEN_05_SHIELD = "gen_05_shield"
const GEN_06_LASER_DESIGNATOR = "gen_06_laser_designator"
const GEN_07_MINE_RESISTANT = "gen_07_mine_resistant"
const GEN_08_NBC_PROTECTION = "gen_08_nbc_protection"
const GEN_09_IR_JAMMER = "gen_09_ir_jammer"
const GEN_10_AMMO_RACK = "gen_10_ammo_rack"

const DATA: Dictionary = {
	"gen_01_comms" = {
		id = GEN_01_COMMS, name = "战场通讯", name_en = "Field Comms",
		prototype = "SCR-536对讲机", description = "基础通讯，射速和视野微升",
		rarity = "uncommon", cost_research = 60, cost_install = 30,
		slot_type = "comms", conflict_group = "comms",
		effects = {attack_interval = -0.05, vision = 0.20},
		applicable_types = [0, 6],  # LIGHT, RECON
		unlock_conditions = {required_level = 1}
	},
	"gen_02_digital" = {
		id = GEN_02_DIGITAL, name = "数字化单兵", name_en = "Digital Soldier System",
		prototype = "陆地勇士系统", description = "指挥效率提升",
		rarity = "rare", cost_research = 140, cost_install = 70,
		slot_type = "system", conflict_group = "system",
		effects = {command_efficiency = 0.15},
		applicable_types = [0, 6],  # LIGHT, RECON
		unlock_conditions = {required_level = 3}
	},
	"gen_03_camouflage" = {
		id = GEN_03_CAMOUFLAGE, name = "伪装迷彩", name_en = "Camouflage Pattern",
		prototype = "多地形迷彩", description = "降低被发现概率",
		rarity = "uncommon", cost_research = 70, cost_install = 35,
		slot_type = "stealth", conflict_group = "stealth",
		effects = {detection_reduce = -0.20},
		applicable_types = [0, 1, 2, 3, 4, 5, 6],  # ALL
		unlock_conditions = {required_level = 1}
	},
	"gen_04_vest" = {
		id = GEN_04_VEST, name = "战术背心", name_en = "Tactical Vest",
		prototype = "IOTV模块化", description = "基础防护提升",
		rarity = "uncommon", cost_research = 80, cost_install = 40,
		slot_type = "armor", conflict_group = "armor",
		effects = {max_hp = 0.10, defense_light = 0.05},
		applicable_types = [0, 2, 6],  # LIGHT, SUPPORT, RECON
		unlock_conditions = {required_level = 1}
	},
	"gen_05_shield" = {
		id = GEN_05_SHIELD, name = "防弹盾牌", name_en = "Riot Shield",
		prototype = "防弹盾", description = "防护大幅提升，速度略降",
		rarity = "rare", cost_research = 160, cost_install = 80,
		slot_type = "shield", conflict_group = "shield",
		effects = {defense_light = 0.40, move_speed = -10},
		applicable_types = [0, 2],  # LIGHT, SUPPORT
		unlock_conditions = {required_level = 2}
	},
	"gen_06_laser_designator" = {
		id = GEN_06_LASER_DESIGNATOR, name = "激光指示器", name_en = "Laser Designator",
		prototype = "激光目标指示器", description = "周围炮兵命中提升",
		rarity = "rare", cost_research = 180, cost_install = 90,
		slot_type = "designator", conflict_group = "designator",
		effects = {ally_arty_bonus = 0.20},
		applicable_types = [0, 6],  # LIGHT, RECON
		unlock_conditions = {required_level = 3}
	},
	"gen_07_mine_resistant" = {
		id = GEN_07_MINE_RESISTANT, name = "防雷座椅", name_en = "Mine-Resistant Seat",
		prototype = "悬挂防雷座椅", description = "地雷伤害大幅降低",
		rarity = "epic", cost_research = 260, cost_install = 130,
		slot_type = "survival", conflict_group = "survival",
		effects = {mine_damage_reduction = -0.80},
		applicable_types = [1],  # ARMOR
		unlock_conditions = {required_level = 4}
	},
	"gen_08_nbc_protection" = {
		id = GEN_08_NBC_PROTECTION, name = "三防系统", name_en = "NBC Protection",
		prototype = "核生化防护", description = "免疫生化攻击",
		rarity = "epic", cost_research = 300, cost_install = 150,
		slot_type = "protection", conflict_group = "protection",
		effects = {nbq_immunity = true},
		applicable_types = [1, 2, 4],  # ARMOR, SUPPORT, FORT
		unlock_conditions = {required_level = 5}
	},
	"gen_09_ir_jammer" = {
		id = GEN_09_IR_JAMMER, name = "红外干扰机", name_en = "IR Jammer",
		prototype = "窗帘光电干扰", description = "导弹闪避提升",
		rarity = "epic", cost_research = 320, cost_install = 160,
		slot_type = "countermeasure", conflict_group = "countermeasure",
		effects = {missile_dodge = 0.25},
		applicable_types = [1, 3],  # ARMOR, AIR
		unlock_conditions = {required_level = 5}
	},
	"gen_10_ammo_rack" = {
		id = GEN_10_AMMO_RACK, name = "备用弹药架", name_en = "Ammo Rack",
		prototype = "外挂弹药箱", description = "持续作战能力提升",
		rarity = "uncommon", cost_research = 90, cost_install = 45,
		slot_type = "ammunition", conflict_group = "ammunition",
		effects = {sustained_fire = 0.30},
		applicable_types = [0, 1, 2, 3, 4, 5, 6],  # ALL
		unlock_conditions = {required_level = 1}
	},
}

static func get_mod_data(mod_id: String) -> Dictionary:
	return DATA.get(mod_id, {}).duplicate(true)

static func get_all_mod_ids() -> Array:
	return DATA.keys()

static func get_for_card(_card_id: String) -> Array:
	return DATA.keys()

static func get_for_unit_type(unit_type: int) -> Array:
	var result = []
	for mod_id in DATA.keys():
		var mod_data = get_mod_data(mod_id)
		var applicable = mod_data.get("applicable_types", [])
		if unit_type in applicable:
			result.append(mod_id)
	return result

static func check_conflict(mod_id_a: String, mod_id_b: String) -> bool:
	var data_a = get_mod_data(mod_id_a)
	var data_b = get_mod_data(mod_id_b)
	return data_a.get("conflict_group", "") == data_b.get("conflict_group", "") and data_a.get("conflict_group", "") != ""
