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
		prototype = "Kontakt-5爆炸反应装甲", description = "破甲弹命中时爆炸反制。伤害大幅减免。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 140, cost_install = 70,
		slot_type = "engineering", conflict_group = "engineering",
		era_band = [2, 4],
		effects = {defense_armor = 25, damage_reduction = 0.10},
		level_effects = {1: {defense_armor = 25, damage_reduction = 0.10}, 2: {defense_armor = 44, damage_reduction = 0.10}, 3: {defense_armor = 62, damage_reduction = 0.10}},
		unlock_conditions = {required_level = 2}
	},
	"eng_02_explosives" = {
		id = ENG_02_EXPLOSIVES, name = "爆破装置", name_en = "Explosive Charges",
		icon = "res://assets/ui/icons/mod_icons/mod_demolition.png",
		prototype = "C4/塑胶炸药", description = "定向爆破装药。对堡垒伤害大幅提升。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 260, cost_install = 130,
		slot_type = "demolition", conflict_group = "demolition",
		# v7.x: per-slot 弹道——对装甲槽改 ROCKET 火箭爆破
		condition_slot = 1,
		era_band = [1, 4],
		effects = {attack_fort = 0.40, slot_weapon_type = 3},  # v7.x: 对装甲槽火箭弹道（爆破）,
		level_effects = {1: {attack_fort = 0.4, slot_weapon_type = 3}, 2: {attack_fort = 0.52, slot_weapon_type = 3}, 3: {attack_fort = 0.6, slot_weapon_type = 3}},
		unlock_conditions = {required_level = 4}
	},
	"eng_03_welding" = {
		id = ENG_03_WELDING, name = "焊接设备", name_en = "Welding Equipment",
		icon = "res://assets/ui/icons/mod_icons/mod_repair.png",
		prototype = "战场抢修", description = "战场焊接抢修。持续回复生命值。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 160, cost_install = 80,
		slot_type = "repair", conflict_group = "repair",
		effects = {hp_regen = 0.005},
		level_effects = {1: {hp_regen = 0.005}, 2: {hp_regen = 0.007}, 3: {hp_regen = 0.009}},
		unlock_conditions = {required_level = 3}
	},
	"eng_04_bridge" = {
		id = ENG_04_BRIDGE, name = "架桥设备", name_en = "Bridge Layer",
		icon = "res://assets/ui/icons/mod_icons/mod_bridge.png",
		prototype = "坦克架桥车", description = "坦克架桥车随行。部署加速 5%。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 300, cost_install = 150,
		slot_type = "bridge", conflict_group = "engineering_gear",
		effects = {ally_river_bonus = 1.00},
		level_effects = {1: {ally_river_bonus = 1}, 2: {ally_river_bonus = 0.6}, 3: {ally_river_bonus = 0.6}},
		unlock_conditions = {required_level = 5}
	},
	"eng_05_shovel" = {
		id = ENG_05_SHOVEL, name = "工程铲", name_en = "Combat Shovel",
		icon = "res://assets/ui/icons/mod_icons/mod_digging.png",
		prototype = "推土铲", description = "推土铲构筑工事。防御提升，轻微减速。",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 70, cost_install = 35,
		slot_type = "digging", conflict_group = "engineering_gear",
		effects = {defense_light = 20, move_speed = -5},
		level_effects = {1: {defense_light = 20, move_speed = -5}, 2: {defense_light = 35, move_speed = -5}, 3: {defense_light = 50, move_speed = -5}},
		unlock_conditions = {required_level = 1}
	},
	"eng_06_crane" = {
		id = ENG_06_CRANE, name = "间隙装甲", name_en = "Spaced Armor",
		icon = "res://assets/ui/icons/mod_icons/mod_recovery.png",
		prototype = "谢尔曼/四号附加装甲板", description = "外挂间隙装甲板，提前引爆来袭弹丸。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 180, cost_install = 90,
		slot_type = "recovery", conflict_group = "engineering_gear",
		era_band = [1, 4],
		effects = {defense_armor = 20, max_hp = 25},
		level_effects = {1: {defense_armor = 20, max_hp = 25}, 2: {defense_armor = 35, max_hp = 40}, 3: {defense_armor = 50, max_hp = 60}},
		unlock_conditions = {required_level = 3}
	},
	"eng_07_generator" = {
		id = ENG_07_GENERATOR, name = "发电机", name_en = "Power Generator",
		icon = "res://assets/ui/icons/mod_icons/mod_power.png",
		prototype = "野战发电站", description = "野战发电。三维防御 +12.5%。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 200, cost_install = 100,
		slot_type = "power", conflict_group = "power",
		effects = {ally_fort_regen = 0.50},
		level_effects = {1: {ally_fort_regen = 0.5}, 2: {ally_fort_regen = 0.6}, 3: {ally_fort_regen = 0.6}},
		unlock_conditions = {required_level = 4}
	},
	"eng_08_medical" = {
		id = ENG_08_MEDICAL, name = "战场急救站", name_en = "Field Medical Station",
		icon = "res://assets/ui/icons/mod_icons/mod_medical.png",
		prototype = "机动医疗单元", description = "机动医疗单元。每秒回复 0.15% 生命值。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 280, cost_install = 140,
		slot_type = "medical", conflict_group = "medical",
		effects = {ally_hp_regen = 0.003},
		unlock_conditions = {required_level = 5}
	},
	"eng_09_supply" = {
		id = ENG_09_SUPPLY, name = "弹药补给车", name_en = "Ammo Supply Truck",
		icon = "res://assets/ui/icons/mod_icons/mod_logistics.png",
		prototype = "运输车", description = "弹药补给分发：自身攻速 +15%，周围友军攻速 +30%。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 180, cost_install = 90,
		slot_type = "logistics", conflict_group = "logistics",
		effects = {ally_ammo = 0.30},
		unlock_conditions = {required_level = 3}
	},
	"eng_10_camouflage" = {
		id = ENG_10_CAMOUFLAGE, name = "伪装网系统", name_en = "Camouflage System",
		icon = "res://assets/ui/icons/mod_icons/mod_stealth.png",
		prototype = "大型伪装系统", description = "大型伪装网隐蔽。闪避 +15%。",
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
		description = "定向爆破对堡垒与装甲目标造成额外真实伤害：每次命中无视防御，扣除目标当前生命值的 5%。",
		rarity = "legendary",
		power_mult = 1.9,
		cost_research = 420,
		cost_install = 210,
		slot_type = "ammunition",
		conflict_group = "demolition",
		era_band = [1, 4],
		effects = {siege_bonus = 0.05},
		level_effects = {1: {siege_bonus = 0.05}, 2: {siege_bonus = 0.065}, 3: {siege_bonus = 0.085}},
		unlock_conditions = {required_level = 6}
	},

	# ─── v7.x 第二批：爆反工程车 + 亡语补给 ───
	"eng_12_reactive_engineering" = {
		id = "eng_12_reactive_engineering",
		name = "爆反工程装甲",
		name_en = "Reactive Engineering Armor",
		icon = "res://assets/ui/icons/mod_icons/mod_armor.png",
		prototype = "扫雷艇反应装甲套件",
		description = "工程车加挂爆反装甲。受击时反弹 25% 伤害，可触发 2 次。",
		rarity = "legendary",
		power_mult = 1.7,
		cost_research = 380,
		cost_install = 190,
		slot_type = "armor",
		conflict_group = "armor",
		era_band = [2, 4],
		effects = {reactive_armor = 0.25, reflect_charges = 2},
		level_effects = {1: {reactive_armor = 0.25, reflect_charges = 2}, 2: {reactive_armor = 0.325, reflect_charges = 3}, 3: {reactive_armor = 0.425, reflect_charges = 3}},
		unlock_conditions = {required_level = 5}
	},

	"eng_13_supply_cache" = {
		id = "eng_13_supply_cache",
		name = "补给遗物",
		name_en = "Supply Cache",
		icon = "res://assets/ui/icons/mod_icons/mod_special.png",
		prototype = "自毁式补给投放器",
		description = "阵亡时遗落补给，治疗周围 180 像素内友军，恢复量为自身 15% 最大生命值。",
		rarity = "epic",
		power_mult = 1.5,
		cost_research = 300,
		cost_install = 150,
		slot_type = "special",
		conflict_group = "special",
		effects = {death_heal = 0.15, death_heal_radius = 180.0},
		level_effects = {1: {death_heal = 0.15, death_heal_radius = 180}, 2: {death_heal = 0.195, death_heal_radius = 234}, 3: {death_heal = 0.255, death_heal_radius = 306}},
		unlock_conditions = {required_level = 5}
	},

	# ==================== v9.1 组合技套路配套改造（2 个） ====================
	# 套路4 光束谐振链：光纤链路（光束武器伤害+20%）
	"eng_optical_fiber" = {
		id = "eng_optical_fiber",
		name = "光纤链路",
		name_en = "Optical Fiber Link",
		icon = "res://assets/ui/icons/mod_icons/mod_optical_fiber.png",
		prototype = "战场光纤通信网",
		description = "光束类武器伤害 +20%。光束谐振链全局增益。",
		rarity = "epic",
		power_mult = 1.6,
		cost_research = 340,
		cost_install = 170,
		slot_type = "electronic",
		conflict_group = "electronic",
		era_band = [3, 4],
		effects = {beam_damage_bonus = 0.20, attack_light = 0.05},
		unlock_conditions = {required_level = 5}
	},
	# 套路6 化学污染场：化学喷洒器（范围挂毒）
	"eng_chem_sprayer" = {
		id = "eng_chem_sprayer",
		name = "化学喷洒器",
		name_en = "Chem Sprayer",
		icon = "res://assets/ui/icons/mod_icons/mod_chem_sprayer.png",
		prototype = "车载化学喷洒系统",
		description = "攻击 50% 概率范围挂化学毒，累积战场污染度。化学污染场触发器。",
		rarity = "epic",
		power_mult = 1.6,
		cost_research = 340,
		cost_install = 170,
		slot_type = "special",
		conflict_group = "special",
		effects = {chem_chance = 0.50, chem_dps = 8.0, chem_duration = 5.0, chem_pollute = 4.0, splash_radius = 0.30},
		unlock_conditions = {required_level = 5}
	},

	# ==================== v10 解题式玩法：转换型改造 ====================
	# 回收无人机：击杀→修复（吸血的设定合理版——敌方是相位构造体，击毁后回收残余纳米材料）
	"eng_14_salvage_drone" = {
		id = "eng_14_salvage_drone",
		name = "回收无人机",
		name_en = "Salvage Drone",
		icon = "res://assets/ui/icons/mod_icons/mod_special.png",
		prototype = "战场回收无人机群",
		description = "击毁敌方单位时回收其残余纳米材料修复自身，回复目标最大生命 8%。",
		rarity = "epic",
		power_mult = 1.6,
		cost_research = 320,
		cost_install = 160,
		slot_type = "special",
		conflict_group = "special",
		era_band = [3, 4],
		effects = {salvage_repair = 0.08},
		level_effects = {1: {salvage_repair = 0.08}, 2: {salvage_repair = 0.104}, 3: {salvage_repair = 0.136}},
		unlock_conditions = {required_level = 5}
	},

	# ══════════ v27 改造2.0 批：普及档 + 维修强化 + 工兵防线套装件 ══════════
	"eng_15_entrenching_kit" = {
		id = "eng_15_entrenching_kit",
		name = "工兵铲套装",
		name_en = "Entrenching Kit",
		icon = "res://assets/ui/icons/mod_icons/mod_digging.png",
		prototype = "制式工兵铲",
		description = "快速构筑掩体。对轻装防御 +5，部署加速。",
		rarity = "common",
		power_mult = 0.8,
		cost_research = 50,
		cost_install = 25,
		slot_type = "environment",
		conflict_group = "environment",
		effects = {defense_light = 5, deploy_speed = 1},
		level_effects = {1: {defense_light = 5, deploy_speed = 1}, 2: {defense_light = 7, deploy_speed = 1}, 3: {defense_light = 9, deploy_speed = 1}},
		unlock_conditions = {required_level = 1}
	},
	"eng_16_field_generator" = {
		id = "eng_16_field_generator",
		name = "野战发电机",
		name_en = "Field Generator",
		icon = "res://assets/ui/icons/mod_icons/mod_power.png",
		prototype = "移动电站",
		description = "供电与检修。生命 +20，回复 0.2%/s。",
		rarity = "uncommon",
		power_mult = 1.0,
		cost_research = 100,
		cost_install = 50,
		slot_type = "power",
		conflict_group = "power",
		effects = {max_hp = 20, hp_regen = 0.002},
		level_effects = {1: {max_hp = 20, hp_regen = 0.002}, 2: {max_hp = 26, hp_regen = 0.003}, 3: {max_hp = 34, hp_regen = 0.004}},
		unlock_conditions = {required_level = 2}
	},
	"eng_17_recovery_crane" = {
		id = "eng_17_recovery_crane",
		name = "抢修起重机",
		name_en = "Recovery Crane",
		icon = "res://assets/ui/icons/mod_icons/mod_repair.png",
		prototype = "抢修车起重机",
		description = "战场抢修作业。周围友军回复 0.4%/s。",
		rarity = "rare",
		power_mult = 1.3,
		cost_research = 160,
		cost_install = 80,
		slot_type = "repair",
		conflict_group = "repair",
		effects = {ally_hp_regen = 0.004},
		level_effects = {1: {ally_hp_regen = 0.004}, 2: {ally_hp_regen = 0.005}, 3: {ally_hp_regen = 0.007}},
		unlock_conditions = {required_level = 3}
	},
	# v27 工兵防线套装第 4 件（eng_02/eng_03/eng_12 + 本条集齐满档）
	"eng_18_defense_blueprints" = {
		id = "eng_18_defense_blueprints",
		name = "防线工程蓝图",
		name_en = "Defense Blueprints",
		icon = "res://assets/ui/icons/mod_icons/mod_engineering.png",
		prototype = "永备防线施工图",
		description = "按图施工防线。受装甲/空军攻击减伤 20%，生命 +8%。",
		rarity = "rare",
		power_mult = 1.3,
		cost_research = 180,
		cost_install = 90,
		slot_type = "special",
		conflict_group = "special",
		effects = {urban_defense = 0.20, max_hp = 0.08},
		level_effects = {1: {urban_defense = 0.20, max_hp = 0.08}, 2: {urban_defense = 0.26, max_hp = 0.10}, 3: {urban_defense = 0.34, max_hp = 0.14}},
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

# v7.x: ww1_engineer→ww1_sup_engineer; cold_avlb/mod_m9ace 是死链（default_cards 无定义，见 engineer_evolution.gd:5 注释）已删除
const _CARD_PREFIXES: Array = ["ww1_sup_engineer", "fut_nano_drone"]
