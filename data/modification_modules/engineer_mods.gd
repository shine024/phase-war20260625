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
		id = ENG_01_MINE_SWEEPER, name = "反应装甲", name_en = "Reactive Armor",
		icon = "res://assets/ui/icons/mod_icons/mod_engineering.png",
		prototype = "Kontakt-5爆炸反应装甲", description = "破甲弹命中时爆炸反制，大幅减免伤害",
		rarity = "rare",
	power_mult = 1.3, cost_research = 140, cost_install = 70,
		slot_type = "engineering", conflict_group = "engineering",
		effects = {defense_armor = 0.25, damage_reduction = 0.10},
		unlock_conditions = {required_level = 2}
	},
	"eng_02_explosives" = {
		id = ENG_02_EXPLOSIVES, name = "爆破装置", name_en = "Explosive Charges",
		icon = "res://assets/ui/icons/mod_icons/mod_demolition.png",
		prototype = "C4/塑胶炸药", description = "对堡垒伤害大幅提升",
		rarity = "epic",
	power_mult = 1.6, cost_research = 260, cost_install = 130,
		slot_type = "demolition", conflict_group = "demolition",
		# v7.x: per-slot 弹道——对装甲槽改 ROCKET 火箭爆破
		condition_slot = 1,
		effects = {attack_fort = 0.40, slot_weapon_type = 3},  # v7.x: 对装甲槽火箭弹道（爆破）,
		unlock_conditions = {required_level = 4}
	},
	"eng_03_welding" = {
		id = ENG_03_WELDING, name = "焊接设备", name_en = "Welding Equipment",
		icon = "res://assets/ui/icons/mod_icons/mod_repair.png",
		prototype = "战场抢修", description = "持续回复生命值",
		rarity = "rare",
	power_mult = 1.3, cost_research = 160, cost_install = 80,
		slot_type = "repair", conflict_group = "repair",
		effects = {hp_regen = 0.005},
		unlock_conditions = {required_level = 3}
	},
	"eng_04_bridge" = {
		id = ENG_04_BRIDGE, name = "架桥设备", name_en = "Bridge Layer",
		icon = "res://assets/ui/icons/mod_icons/mod_bridge.png",
		prototype = "坦克架桥车", description = "部署加速5%",
		rarity = "epic",
	power_mult = 1.6, cost_research = 300, cost_install = 150,
		slot_type = "bridge", conflict_group = "bridge",
		effects = {ally_river_bonus = 1.00},
		unlock_conditions = {required_level = 5}
	},
	"eng_05_shovel" = {
		id = ENG_05_SHOVEL, name = "工程铲", name_en = "Combat Shovel",
		icon = "res://assets/ui/icons/mod_icons/mod_digging.png",
		prototype = "推土铲", description = "防御提升，轻微减速",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 70, cost_install = 35,
		slot_type = "digging", conflict_group = "digging",
		effects = {defense_light = 0.20, move_speed = -5},
		unlock_conditions = {required_level = 1}
	},
	"eng_06_crane" = {
		id = ENG_06_CRANE, name = "间隙装甲", name_en = "Spaced Armor",
		icon = "res://assets/ui/icons/mod_icons/mod_recovery.png",
		prototype = "谢尔曼/四号附加装甲板", description = "外挂间隙装甲板，提前引爆来袭弹丸",
		rarity = "rare",
	power_mult = 1.3, cost_research = 180, cost_install = 90,
		slot_type = "recovery", conflict_group = "recovery",
		effects = {defense_armor = 0.20, max_hp = 0.08},
		unlock_conditions = {required_level = 3}
	},
	"eng_07_generator" = {
		id = ENG_07_GENERATOR, name = "发电机", name_en = "Power Generator",
		icon = "res://assets/ui/icons/mod_icons/mod_power.png",
		prototype = "野战发电站", description = "野战发电，三维防御+12.5%",
		rarity = "rare",
	power_mult = 1.3, cost_research = 200, cost_install = 100,
		slot_type = "power", conflict_group = "power",
		effects = {ally_fort_regen = 0.50},
		unlock_conditions = {required_level = 4}
	},
	"eng_08_medical" = {
		id = ENG_08_MEDICAL, name = "战场急救站", name_en = "Field Medical Station",
		icon = "res://assets/ui/icons/mod_icons/mod_medical.png",
		prototype = "机动医疗单元", description = "战场医疗，每秒回复0.15%生命值",
		rarity = "epic",
	power_mult = 1.6, cost_research = 280, cost_install = 140,
		slot_type = "medical", conflict_group = "medical",
		effects = {ally_hp_regen = 0.003},
		unlock_conditions = {required_level = 5}
	},
	"eng_09_supply" = {
		id = ENG_09_SUPPLY, name = "弹药补给车", name_en = "Ammo Supply Truck",
		icon = "res://assets/ui/icons/mod_icons/mod_logistics.png",
		prototype = "运输车", description = "弹药补给，攻速+15%",
		rarity = "rare",
	power_mult = 1.3, cost_research = 180, cost_install = 90,
		slot_type = "logistics", conflict_group = "logistics",
		effects = {ally_ammo = 0.30},
		unlock_conditions = {required_level = 3}
	},
	"eng_10_camouflage" = {
		id = ENG_10_CAMOUFLAGE, name = "伪装网系统", name_en = "Camouflage System",
		icon = "res://assets/ui/icons/mod_icons/mod_stealth.png",
		prototype = "大型伪装系统", description = "伪装隐蔽，闪避+15%",
		rarity = "epic",
	power_mult = 1.6, cost_research = 240, cost_install = 120,
		slot_type = "stealth", conflict_group = "stealth",
		effects = {ally_detection = -0.30},
		unlock_conditions = {required_level = 4}
	},

	# ─── v7.x 新机制改造 ───

	# 兵种专属：爆破装药（对堡垒/装甲目标 5% 百分比掉血）
	"eng_11_breaching_charge" = {
		id = "eng_11_breaching_charge",
		name = "爆破装药",
		name_en = "Breaching Charge",
		icon = "res://assets/ui/icons/mod_icons/mod_ammunition.png",
		prototype = "M112 定向爆破装药",
		description = "对堡垒和装甲目标造成额外真实伤害：每次命中扣除目标当前生命值的 5%（无视防御）",
		rarity = "legendary",
		power_mult = 1.9,
		cost_research = 420,
		cost_install = 210,
		slot_type = "ammunition",
		conflict_group = "ammunition",
		effects = {siege_bonus = 0.05},
		unlock_conditions = {required_level = 6}
	},

	# ─── v7.x 第二批：爆反工程车 + 亡语补给 ───
	"eng_12_reactive_engineering" = {
		id = "eng_12_reactive_engineering",
		name = "爆反工程装甲",
		name_en = "Reactive Engineering Armor",
		icon = "res://assets/ui/icons/mod_icons/mod_armor.png",
		prototype = "扫雷艇反应装甲套件",
		description = "工程车辆改装爆反装甲：受击时反弹25%伤害，可触发2次",
		rarity = "legendary",
		power_mult = 1.7,
		cost_research = 380,
		cost_install = 190,
		slot_type = "armor",
		conflict_group = "armor",
		effects = {reactive_armor = 0.25, reflect_charges = 2},
		unlock_conditions = {required_level = 5}
	},

	"eng_13_supply_cache" = {
		id = "eng_13_supply_cache",
		name = "补给遗物",
		name_en = "Supply Cache",
		icon = "res://assets/ui/icons/mod_icons/mod_special.png",
		prototype = "自毁式补给投放器",
		description = "阵亡时遗落补给：治疗周围180像素内友军，恢复量等于自身15%最大生命值",
		rarity = "epic",
		power_mult = 1.5,
		cost_research = 300,
		cost_install = 150,
		slot_type = "special",
		conflict_group = "special",
		effects = {death_heal = 0.15, death_heal_radius = 180.0},
		unlock_conditions = {required_level = 5}
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

# v7.x: ww1_engineer→ww1_sup_engineer; cold_avlb/mod_m9ace 是死链（default_cards 无定义，见 engineer_evolution.gd:5 注释）已删除
const _CARD_PREFIXES: Array = ["ww1_sup_engineer", "fut_nano_drone"]
