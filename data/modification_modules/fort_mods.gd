extends RefCounted
class_name FortModifications
## 堡垒/要塞改造模块定义（10个）

const FOR_01_CONCRETE = "for_01_concrete"
const FOR_02_TUNNEL = "for_02_tunnel"
const FOR_03_AUTO_TURRET = "for_03_auto_turret"
const FOR_04_FILTRATION = "for_04_filtration"
const FOR_05_AMMO_DUMP = "for_05_ammo_dump"
const FOR_06_RADAR = "for_06_radar"
const FOR_07_CAMOUFLAGE = "for_07_camouflage"
const FOR_08_TRENCH = "for_08_trench"
const FOR_09_MINEFIELD = "for_09_minefield"
const FOR_10_COMMAND = "for_10_command"

const DATA: Dictionary = {
	"for_01_concrete" = {
		id = FOR_01_CONCRETE, name = "钢筋混凝土装甲", name_en = "Reinforced Concrete",
		prototype = "碉堡标准", description = "标准碉堡装甲，防护大幅提升",
		rarity = "rare",
	power_mult = 1.3, cost_research = 160, cost_install = 80,
		slot_type = "armor", conflict_group = "armor",
		effects = {defense_light = 0.40, max_hp = 0.30},
		unlock_conditions = {required_level = 2}
	},
	"for_02_tunnel" = {
		id = FOR_02_TUNNEL, name = "地下坑道", name_en = "Underground Tunnel",
		prototype = "马奇诺防线", description = "单位间支援提升，被摧毁50%回收",
		rarity = "epic",
	power_mult = 1.6, cost_research = 280, cost_install = 140,
		slot_type = "network", conflict_group = "network",
		effects = {network_bonus = 0.30, destroy_recovery = 0.50},
		unlock_conditions = {required_level = 4}
	},
	"for_03_auto_turret" = {
		id = FOR_03_AUTO_TURRET, name = "自动炮塔", name_en = "Auto Turret",
		prototype = "遥控武器站", description = "自动化射击，射速提升",
		rarity = "epic",
	power_mult = 1.6, cost_research = 300, cost_install = 150,
		slot_type = "automation", conflict_group = "automation",
		effects = {attack_interval = -0.20},
		unlock_conditions = {required_level = 5}
	},
	"for_04_filtration" = {
		id = FOR_04_FILTRATION, name = "通风过滤系统", name_en = "Filtration System",
		prototype = "核生化防护", description = "免疫生化攻击",
		rarity = "epic",
	power_mult = 1.6, cost_research = 320, cost_install = 160,
		slot_type = "protection", conflict_group = "protection",
		effects = {nbq_immunity = true},
		unlock_conditions = {required_level = 5}
	},
	"for_05_ammo_dump" = {
		id = FOR_05_AMMO_DUMP, name = "弹药库", name_en = "Ammunition Depot",
		prototype = "地下弹药库", description = "攻击力提升",
		rarity = "rare",
	power_mult = 1.3, cost_research = 180, cost_install = 90,
		slot_type = "ammunition", conflict_group = "ammunition",
		effects = {attack_light = 0.20},
		unlock_conditions = {required_level = 3}
	},
	"for_06_radar" = {
		id = FOR_06_RADAR, name = "雷达天线", name_en = "Radar Array",
		prototype = "远程预警雷达", description = "发现隐形单位",
		rarity = "legendary",
	power_mult = 2.0, cost_research = 400, cost_install = 200,
		slot_type = "radar", conflict_group = "radar",
		effects = {stealth_detect = 0.40},
		unlock_conditions = {required_level = 7}
	},
	"for_07_camouflage" = {
		id = FOR_07_CAMOUFLAGE, name = "伪装系统", name_en = "Camouflage System",
		prototype = "伪装网/植被", description = "降低被发现概率",
		rarity = "rare",
	power_mult = 1.3, cost_research = 140, cost_install = 70,
		slot_type = "stealth", conflict_group = "stealth",
		effects = {detection_reduce = -0.50},
		unlock_conditions = {required_level = 2}
	},
	"for_08_trench" = {
		id = FOR_08_TRENCH, name = "反坦克壕", name_en = "Anti-Tank Trench",
		prototype = "堑壕系统", description = "敌方装甲兵减速",
		rarity = "rare",
	power_mult = 1.3, cost_research = 200, cost_install = 100,
		slot_type = "obstacle", conflict_group = "obstacle",
		effects = {enemy_armor_slow = -0.50},
		unlock_conditions = {required_level = 3}
	},
	"for_09_minefield" = {
		id = FOR_09_MINEFIELD, name = "雷场", name_en = "Minefield",
		prototype = "反坦克/人员地雷", description = "接近敌人损失生命值",
		rarity = "epic",
	power_mult = 1.6, cost_research = 280, cost_install = 140,
		slot_type = "minefield", conflict_group = "minefield",
		effects = {approach_damage = 0.10},
		unlock_conditions = {required_level = 5}
	},
	"for_10_command" = {
		id = FOR_10_COMMAND, name = "指挥塔", name_en = "Command Tower",
		prototype = "要塞核心", description = "周围友军命中提升",
		rarity = "legendary",
	power_mult = 2.0, cost_research = 420, cost_install = 210,
		slot_type = "command", conflict_group = "command",
		effects = {ally_hit_bonus = 0.15},
		unlock_conditions = {required_level = 7}
	},
}

static func get_mod_data(mod_id: String) -> Dictionary:
	return DATA.get(mod_id, {}).duplicate(true)

static func get_all_mod_ids() -> Array:
	return DATA.keys()

static func get_for_unit_type(unit_type: int) -> Array:
	if unit_type == 4: return DATA.keys()  # FORT
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

const _CARD_PREFIXES: Array = ["fort_"]
