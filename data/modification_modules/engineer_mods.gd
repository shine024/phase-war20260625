extends RefCounted
class_name EngineerModifications
## 工程/支援改造模块定义（10个）

const ENG_01_MINE_SWEEPER = "eng_01_mine_sweeper"
const ENG_02_EXPLOSIVES = "eng_02_explosives"
const ENG_03_WELDING = "eng_03_welding"
const ENG_04_BRIDGE = "eng_04_bridge"
const ENG_05_SHOVEL = "eng_05_shovel"
const ENG_06_CRANE = "eng_06_crane"
const ENG_07_GENERATOR = "eng_07_generator"
const ENG_08_MEDICAL = "eng_08_medical"
const ENG_09_SUPPLY = "eng_09_supply"
const ENG_10_CAMOUFLAGE = "eng_10_camouflage"

const DATA: Dictionary = {
	"eng_01_mine_sweeper" = {
		id = ENG_01_MINE_SWEEPER, name = "扫雷索", name_en = "Mine Sweeper",
		prototype = "坦克扫雷装置", description = "清除地雷，轻微减速",
		rarity = "rare",
	power_mult = 1.3, cost_research = 140, cost_install = 70,
		slot_type = "engineering", conflict_group = "engineering",
		effects = {mine_clear = true, move_speed = -5},
		unlock_conditions = {required_level = 2}
	},
	"eng_02_explosives" = {
		id = ENG_02_EXPLOSIVES, name = "爆破装置", name_en = "Explosive Charges",
		prototype = "C4/塑胶炸药", description = "对堡垒伤害大幅提升",
		rarity = "epic",
	power_mult = 1.6, cost_research = 260, cost_install = 130,
		slot_type = "demolition", conflict_group = "demolition",
		effects = {attack_fort = 0.40},
		unlock_conditions = {required_level = 4}
	},
	"eng_03_welding" = {
		id = ENG_03_WELDING, name = "焊接设备", name_en = "Welding Equipment",
		prototype = "战场抢修", description = "持续回复生命值",
		rarity = "rare",
	power_mult = 1.3, cost_research = 160, cost_install = 80,
		slot_type = "repair", conflict_group = "repair",
		effects = {hp_regen = 0.005},
		unlock_conditions = {required_level = 3}
	},
	"eng_04_bridge" = {
		id = ENG_04_BRIDGE, name = "架桥设备", name_en = "Bridge Layer",
		prototype = "坦克架桥车", description = "友军河流地形速度提升",
		rarity = "epic",
	power_mult = 1.6, cost_research = 300, cost_install = 150,
		slot_type = "bridge", conflict_group = "bridge",
		effects = {ally_river_bonus = 1.00},
		unlock_conditions = {required_level = 5}
	},
	"eng_05_shovel" = {
		id = ENG_05_SHOVEL, name = "工程铲", name_en = "Combat Shovel",
		prototype = "推土铲", description = "防御提升，轻微减速",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 70, cost_install = 35,
		slot_type = "digging", conflict_group = "digging",
		effects = {defense_light = 0.20, move_speed = -5},
		unlock_conditions = {required_level = 1}
	},
	"eng_06_crane" = {
		id = ENG_06_CRANE, name = "起重机", name_en = "Recovery Crane",
		prototype = "装甲回收车", description = "战损单位50%回收",
		rarity = "rare",
	power_mult = 1.3, cost_research = 180, cost_install = 90,
		slot_type = "recovery", conflict_group = "recovery",
		effects = {salvage_rate = 0.50},
		unlock_conditions = {required_level = 3}
	},
	"eng_07_generator" = {
		id = ENG_07_GENERATOR, name = "发电机", name_en = "Power Generator",
		prototype = "野战发电站", description = "周围堡垒HP回复提升",
		rarity = "rare",
	power_mult = 1.3, cost_research = 200, cost_install = 100,
		slot_type = "power", conflict_group = "power",
		effects = {ally_fort_regen = 0.50},
		unlock_conditions = {required_level = 4}
	},
	"eng_08_medical" = {
		id = ENG_08_MEDICAL, name = "战场急救站", name_en = "Field Medical Station",
		prototype = "机动医疗单元", description = "周围友军回复生命值",
		rarity = "epic",
	power_mult = 1.6, cost_research = 280, cost_install = 140,
		slot_type = "medical", conflict_group = "medical",
		effects = {ally_hp_regen = 0.003},
		unlock_conditions = {required_level = 5}
	},
	"eng_09_supply" = {
		id = ENG_09_SUPPLY, name = "弹药补给车", name_en = "Ammo Supply Truck",
		prototype = "运输车", description = "周围友军弹药提升",
		rarity = "rare",
	power_mult = 1.3, cost_research = 180, cost_install = 90,
		slot_type = "logistics", conflict_group = "logistics",
		effects = {ally_ammo = 0.30},
		unlock_conditions = {required_level = 3}
	},
	"eng_10_camouflage" = {
		id = ENG_10_CAMOUFLAGE, name = "伪装网系统", name_en = "Camouflage System",
		prototype = "大型伪装系统", description = "周围单位被发现降低",
		rarity = "epic",
	power_mult = 1.6, cost_research = 240, cost_install = 120,
		slot_type = "stealth", conflict_group = "stealth",
		effects = {ally_detection = -0.30},
		unlock_conditions = {required_level = 4}
	},
}

static func get_mod_data(mod_id: String) -> Dictionary:
	return DATA.get(mod_id, {}).duplicate(true)

static func get_all_mod_ids() -> Array:
	return DATA.keys()

static func get_for_unit_type(unit_type: int) -> Array:
	if unit_type == 2: return DATA.keys()  # SUPPORT (engineer)
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

const _CARD_PREFIXES: Array = ["ww1_engineer", "cold_avlb", "mod_m9ace", "fut_nano_drone"]
