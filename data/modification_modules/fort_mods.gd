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
		icon = "res://assets/ui/icons/mod_icons/mod_armor.png",
		prototype = "碉堡标准", description = "钢筋混凝土碉堡装甲。防护大幅提升。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 160, cost_install = 80,
		slot_type = "armor", conflict_group = "armor",
		effects = {defense_light = 40, max_hp = 85},
		level_effects = {1: {defense_light = 40, max_hp = 85}, 2: {defense_light = 70, max_hp = 150}, 3: {defense_light = 100, max_hp = 220}},
		unlock_conditions = {required_level = 2}
	},
	"for_02_tunnel" = {
		id = FOR_02_TUNNEL, name = "地下坑道", name_en = "Underground Tunnel",
		icon = "res://assets/ui/icons/mod_icons/mod_network.png",
		prototype = "马奇诺防线", description = "地下坑道工事，全方位防御。对轻装、对空、对装甲伤害减免。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 280, cost_install = 140,
		slot_type = "network", conflict_group = "network",
		effects = {defense_light = 0.20, defense_air = 0.20, defense_armor = 0.15},
		level_effects = {1: {defense_light = 0.2, defense_air = 0.2, defense_armor = 0.15}, 2: {defense_light = 0.26, defense_air = 0.26, defense_armor = 0.195}, 3: {defense_light = 0.34, defense_air = 0.34, defense_armor = 0.255}},
		unlock_conditions = {required_level = 4}
	},
	"for_03_auto_turret" = {
		id = FOR_03_AUTO_TURRET, name = "自动炮塔", name_en = "Auto Turret",
		icon = "res://assets/ui/icons/mod_icons/mod_automation.png",
		prototype = "遥控武器站", description = "遥控武器站自动射击。射速提升。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 300, cost_install = 150,
		slot_type = "automation", conflict_group = "automation",
		# v7.x: per-slot 弹道——对装甲槽改 SNIPER 要塞炮穿甲
		condition_slot = 1,
		era_band = [3, 4],
		effects = {attack_interval = -0.20, slot_weapon_type = 6},  # v7.x: 对装甲槽穿甲弹道（要塞炮）,
		unlock_conditions = {required_level = 5}
	},
	"for_04_filtration" = {
		id = FOR_04_FILTRATION, name = "通风过滤系统", name_en = "Filtration System",
		icon = "res://assets/ui/icons/mod_icons/mod_protection.png",
		prototype = "核生化防护", description = "三防通风过滤系统。减伤提升。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 320, cost_install = 160,
		slot_type = "protection", conflict_group = "protection",
		era_band = [2, 4],
		effects = {nbq_immunity = true},
		unlock_conditions = {required_level = 5}
	},
	"for_05_ammo_dump" = {
		id = FOR_05_AMMO_DUMP, name = "弹药库", name_en = "Ammunition Depot",
		icon = "res://assets/ui/icons/mod_icons/mod_ammunition.png",
		prototype = "地下弹药库", description = "地下弹药储备。攻击力提升。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 180, cost_install = 90,
		slot_type = "ammunition", conflict_group = "ammunition",
		# v7.x: per-slot 弹道——对轻装槽改 MG 机枪压制（弹药充足持续射击）
		condition_slot = 0,
		effects = {attack_light = 11, slot_weapon_type = 2},
		level_effects = {1: {attack_light = 11, slot_weapon_type = 2}, 2: {attack_light = 19, slot_weapon_type = 2}, 3: {attack_light = 28, slot_weapon_type = 2}},
		unlock_conditions = {required_level = 3}
	},
	"for_06_radar" = {
		id = FOR_06_RADAR, name = "雷达天线", name_en = "Radar Array",
		icon = "res://assets/ui/icons/mod_icons/mod_radar.png",
		prototype = "远程预警雷达", description = "远程预警雷达索敌。暴击率提升。",
		rarity = "legendary",
	power_mult = 2.0, cost_research = 400, cost_install = 200,
		slot_type = "radar", conflict_group = "radar",
		era_band = [1, 4],
		effects = {stealth_detect = 0.40},
		unlock_conditions = {required_level = 7}
	},
	"for_07_camouflage" = {
		id = FOR_07_CAMOUFLAGE, name = "伪装系统", name_en = "Camouflage System",
		icon = "res://assets/ui/icons/mod_icons/mod_stealth.png",
		prototype = "伪装网/植被", description = "工事伪装覆盖。闪避 +50%。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 140, cost_install = 70,
		slot_type = "stealth", conflict_group = "stealth",
		effects = {detection_reduce = -0.50},
		unlock_conditions = {required_level = 2}
	},
	"for_08_trench" = {
		id = FOR_08_TRENCH, name = "反坦克壕", name_en = "Anti-Tank Trench",
		icon = "res://assets/ui/icons/mod_icons/mod_obstacle.png",
		prototype = "堑壕系统", description = "反坦克壕阻滞装甲推进。对装甲伤害 +50%。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 200, cost_install = 100,
		slot_type = "obstacle", conflict_group = "obstacle",
		effects = {enemy_armor_slow = -0.50},
		unlock_conditions = {required_level = 3}
	},
	"for_09_minefield" = {
		id = FOR_09_MINEFIELD, name = "雷场", name_en = "Minefield",
		icon = "res://assets/ui/icons/mod_icons/mod_minefield.png",
		prototype = "反坦克/人员地雷", description = "雷场封锁通路。对轻装伤害 +10%。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 280, cost_install = 140,
		slot_type = "minefield", conflict_group = "minefield",
		effects = {approach_damage = 0.10},
		unlock_conditions = {required_level = 5}
	},
	"for_10_command" = {
		id = FOR_10_COMMAND, name = "指挥塔", name_en = "Command Tower",
		icon = "res://assets/ui/icons/mod_icons/mod_command.png",
		prototype = "要塞核心", description = "指挥协同：自身暴击 +7.5%，周围友军暴击 +15%。",
		rarity = "legendary",
	power_mult = 2.0, cost_research = 420, cost_install = 210,
		slot_type = "command", conflict_group = "command",
		effects = {ally_hit_bonus = 0.15},
		unlock_conditions = {required_level = 7}
	},

	# ─── v7.x 第二批：堡垒区域控制 ───
	"for_11_advanced_minefield" = {
		id = "for_11_advanced_minefield",
		name = "强化雷场",
		name_en = "Advanced Minefield",
		icon = "res://assets/ui/icons/mod_icons/mod_special.png",
		prototype = "智能反坦克雷场",
		description = "堡垒外围部署智能雷场。对接近的敌人造成 150 点一次性爆炸伤害。",
		rarity = "legendary",
		power_mult = 1.9,
		cost_research = 400,
		cost_install = 200,
		slot_type = "special",
		conflict_group = "special",
		era_band = [3, 4],
		effects = {minefield = 150.0},
		level_effects = {1: {minefield = 150}, 2: {minefield = 195}, 3: {minefield = 255}},
		unlock_conditions = {required_level = 6}
	},

	"for_12_anti_tank_trench" = {
		id = "for_12_anti_tank_trench",
		name = "反坦克壕",
		name_en = "Anti-Tank Trench",
		icon = "res://assets/ui/icons/mod_icons/mod_special.png",
		prototype = "壕堑系统",
		description = "挖掘反坦克壕。200 像素范围内敌方移速降低 40%。",
		rarity = "epic",
		power_mult = 1.6,
		cost_research = 320,
		cost_install = 160,
		slot_type = "special",
		conflict_group = "special",
		effects = {slow_aura = 0.40, slow_aura_radius = 200.0},
		level_effects = {1: {slow_aura = 0.4, slow_aura_radius = 200}, 2: {slow_aura = 0.52, slow_aura_radius = 260}, 3: {slow_aura = 0.6, slow_aura_radius = 340}},
		unlock_conditions = {required_level = 5}
	},

	"for_13_command_bunker" = {
		id = "for_13_command_bunker",
		name = "指挥地堡",
		name_en = "Command Bunker",
		icon = "res://assets/ui/icons/mod_icons/mod_command.png",
		prototype = "地下指挥中心",
		description = "强化指挥塔。250 像素范围内友军暴击 +15%。",
		rarity = "legendary",
		power_mult = 2.0,
		cost_research = 440,
		cost_install = 220,
		slot_type = "command",
		conflict_group = "command",
		effects = {command_aura = 0.15},
		level_effects = {1: {command_aura = 0.15}, 2: {command_aura = 0.195}, 3: {command_aura = 0.255}},
		unlock_conditions = {required_level = 7}
	},
	# ─── v26 轰炸防御批 ───
	"for_14_bomb_shelter" = {
		id = "for_14_bomb_shelter",
		name = "防空洞加固",
		name_en = "Bomb Shelter Hardening",
		icon = "res://assets/ui/icons/mod_icons/for_14_bomb_shelter.png",
		prototype = "马奇诺/齐格菲地下工事",
		description = "顶层防爆隔层与地下掩体。减伤与耐久提升，轰炸反制。",
		rarity = "uncommon",
		power_mult = 1.15,
		cost_research = 110,
		cost_install = 55,
		slot_type = "shelter",
		conflict_group = "shelter",
		effects = {damage_reduction = 0.10, max_hp_pct = 0.10},
		level_effects = {1: {damage_reduction = 0.1, max_hp_pct = 0.1}, 2: {damage_reduction = 0.13, max_hp_pct = 0.13}, 3: {damage_reduction = 0.17, max_hp_pct = 0.17}},
		unlock_conditions = {required_level = 2}
	},


	# ══════════ v27 改造2.0 批：普及档 + 死亡触发 + 堡垒固守套装件 ══════════
	"for_15_sandbag" = {
		id = "for_15_sandbag",
		name = "沙袋工事",
		name_en = "Sandbag Emplacement",
		icon = "res://assets/ui/icons/mod_icons/mod_fortification.png",
		prototype = "沙袋垒筑",
		description = "快速垒筑沙袋。对轻装防御 +6。",
		rarity = "common",
		power_mult = 0.8,
		cost_research = 50,
		cost_install = 25,
		slot_type = "fortification",
		conflict_group = "fortification",
		effects = {defense_light = 6},
		level_effects = {1: {defense_light = 6}, 2: {defense_light = 8}, 3: {defense_light = 10}},
		unlock_conditions = {required_level = 1}
	},
	"for_16_drainage" = {
		id = "for_16_drainage",
		name = "排水系统",
		name_en = "Drainage System",
		icon = "res://assets/ui/icons/mod_icons/mod_survival.png",
		prototype = "阵地排水沟",
		description = "防涝防潮驻守。回复 0.2%/s。",
		rarity = "uncommon",
		power_mult = 1.0,
		cost_research = 100,
		cost_install = 50,
		slot_type = "survival",
		conflict_group = "survival",
		effects = {hp_regen = 0.002},
		level_effects = {1: {hp_regen = 0.002}, 2: {hp_regen = 0.003}, 3: {hp_regen = 0.004}},
		unlock_conditions = {required_level = 2}
	},
	# v27 堡垒固守套装第 4 件（for_01/for_08/for_13 + 本条集齐满档）
	"for_17_hardened_bunker" = {
		id = "for_17_hardened_bunker",
		name = "永备工事",
		name_en = "Hardened Bunker",
		icon = "res://assets/ui/icons/mod_icons/mod_fortification.png",
		prototype = "钢筋混凝土永备工事",
		description = "永备工事标准。对轻装防御 +12%，生命 +12%。",
		rarity = "rare",
		power_mult = 1.3,
		cost_research = 180,
		cost_install = 90,
		slot_type = "fortification",
		conflict_group = "fortification",
		effects = {defense_light = 0.12, max_hp = 0.12},
		level_effects = {1: {defense_light = 0.12, max_hp = 0.12}, 2: {defense_light = 0.16, max_hp = 0.12}, 3: {defense_light = 0.20, max_hp = 0.12}},
		unlock_conditions = {required_level = 4}
	},
	# v27 触发式：死亡引爆（阵亡 → 范围殉爆）。消费点 module_effect_handler.on_death
	"for_18_demolition_cache" = {
		id = "for_18_demolition_cache",
		name = "殉爆预案",
		name_en = "Demolition Cache",
		icon = "res://assets/ui/icons/mod_icons/mod_demolition.png",
		prototype = "预置爆破预案",
		description = "阵地失守时殉爆。阵亡时对 160px 内敌方造成自身 35% 最大生命的伤害。",
		rarity = "epic",
		power_mult = 1.5,
		cost_research = 300,
		cost_install = 150,
		slot_type = "special",
		conflict_group = "special",
		effects = {death_detonate_damage = 0.35, death_detonate_radius = 160.0},
		level_effects = {1: {death_detonate_damage = 0.35, death_detonate_radius = 160.0}, 2: {death_detonate_damage = 0.45, death_detonate_radius = 180.0}, 3: {death_detonate_damage = 0.55, death_detonate_radius = 200.0}},
		unlock_conditions = {required_level = 5}
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

# v7.x: 堡垒卡 ID 是 {era}_fort_* 中缀形式，"fort_" 前缀匹配 0 张卡，改为列出完整 ID
const _CARD_PREFIXES: Array = ["ww1_fort_pillbox", "ww1_fort_artillery", "ww2_fort_bunker", "ww2_fort_flak", "cold_fort_missile", "cold_fort_radar", "mod_fort_citadel", "mod_fort_phalanx", "fut_fort_ion", "fut_fort_shield"]
