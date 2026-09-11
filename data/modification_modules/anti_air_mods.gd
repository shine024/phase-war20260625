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
		icon = "res://assets/ui/icons/mod_icons/mod_radar.png",
		prototype = "SCR-584", description = "炮瞄雷达自动跟踪。暴击伤害和射速提升。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 180, cost_install = 90,
		slot_type = "radar", conflict_group = "radar",
		# v7.x: per-slot 弹道——对空槽改 FLAK 雷达引导高炮
		condition_slot = 2,
		era_band = [1, 4],
		effects = {accuracy_bonus = 0.30, attack_interval = -0.30, slot_weapon_type = 7},  # v6.0 -30% + v7.x 对空槽 FLAK,
		unlock_conditions = {required_level = 3}
	},
	"aa_02_iff" = {
		id = AA_02_IFF, name = "敌我识别器", name_en = "IFF",
		icon = "res://assets/ui/icons/mod_icons/mod_electronics.png",
		prototype = "IFF Mark X", description = "敌我识别器辅助索敌。对轻装伤害提升。",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 80, cost_install = 40,
		slot_type = "electronics", conflict_group = "electronics",
		era_band = [1, 4],
		effects = {attack_light = 8},
		level_effects = {1: {attack_light = 8}, 2: {attack_light = 14}, 3: {attack_light = 21}},
		unlock_conditions = {required_level = 1}
	},
	"aa_03_missile_rail" = {
		id = AA_03_MISSILE_RAIL, name = "防空导弹挂架", name_en = "Missile Rail",
		icon = "res://assets/ui/icons/mod_icons/mod_missile.png",
		prototype = "毒刺/萨姆-7", description = "挂装防空导弹。对空火力大幅提升。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 280, cost_install = 140,
		slot_type = "missile", conflict_group = "missile",
		# v7.x: per-slot 弹道——对空槽改 MISSILE 导弹
		condition_slot = 2,
		era_band = [2, 4],
		effects = {attack_air = 0.40, slot_weapon_type = 9},  # v7.x: 对空槽导弹弹道,
		unlock_conditions = {required_level = 4}
	},
	"aa_04_quad_mount" = {
		id = AA_04_QUAD_MOUNT, name = "双联/四联装", name_en = "Quad Mount",
		icon = "res://assets/ui/icons/mod_icons/mod_mount.png",
		prototype = "M45四联.50", description = "多管并联。射速提升。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 200, cost_install = 100,
		slot_type = "mount", conflict_group = "mount",
		effects = {attack_interval = -0.30},
		unlock_conditions = {required_level = 3}
	},
	"aa_05_proximity_fuze" = {
		id = AA_05_PROXIMITY_FUZE, name = "近炸引信", name_en = "Proximity Fuze",
		icon = "res://assets/ui/icons/mod_icons/mod_fuze.png",
		prototype = "二战重大发明", description = "近炸引信空爆。暴击伤害与溅射提升。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 300, cost_install = 150,
		slot_type = "fuze", conflict_group = "fuze",
		# v7.x: per-slot 弹道——对空槽改 FLAK 高炮（近炸空爆）
		condition_slot = 2,
		era_band = [1, 4],
		effects = {accuracy_bonus = 0.40, splash_radius = 0.30, slot_weapon_type = 7, vfx_variant = "proximity"},  # v7.x: 对空槽 FLAK + v8.4 近炸空爆专属视觉,
		unlock_conditions = {required_level = 5}
	},
	"aa_06_laser" = {
		id = AA_06_LASER, name = "激光近防系统", name_en = "Laser CIWS",
		icon = "res://assets/ui/icons/mod_icons/mod_laser.png",
		# v8.x: 从 missile_intercept(→damage_reduction 减伤，偏弱) 迁移到真拦截 intercept_system。
		# 与 arm_04_aps(30%×3次) 区分定位：激光靠"无限弹药"持续拦截，
		# intercept_charges=-1 在 try_intercept 中走无限分支（不耗尽），匹配 legendary+Lv8 门槛。
		prototype = "HELIOS", description = "激光近防拦截来袭弹药。30% 概率拦截，弹药无限，无次数限制。",
		rarity = "legendary",
	power_mult = 2.0, cost_research = 500, cost_install = 250,
		slot_type = "laser", conflict_group = "laser",
		era_band = [3, 4],
		effects = {intercept_system = 0.30, intercept_charges = -1, infinite_ammo = true},
		level_effects = {1: {intercept_system = 0.3, intercept_charges = -1, infinite_ammo = true}, 2: {intercept_system = 0.39, intercept_charges = -1, infinite_ammo = true}, 3: {intercept_system = 0.51, intercept_charges = -1, infinite_ammo = true}},
		unlock_conditions = {required_level = 8}
	},
	"aa_07_aesa" = {
		id = AA_07_AESA, name = "相控阵雷达", name_en = "AESA Radar",
		icon = "res://assets/ui/icons/mod_icons/mod_radar.png",
		prototype = "AN/MPQ-65", description = "相控阵多目标锁定。大范围溅射与射程提升。",
		rarity = "legendary",
	power_mult = 2.0, cost_research = 450, cost_install = 225,
		slot_type = "radar", conflict_group = "radar",
		# v7.x: per-slot 弹道——对空槽改 MISSILE 导弹（相控阵引导）
		condition_slot = 2,
		era_band = [3, 4],
		effects = {splash_damage = 0.4, splash_radius = 0.4, attack_range = 60, slot_weapon_type = 9},  # v7.x: 对空槽导弹,
		unlock_conditions = {required_level = 7}
	},
	"aa_08_power_gen" = {
		id = AA_08_POWER_GEN, name = "车载发电机组", name_en = "Power Generator",
		icon = "res://assets/ui/icons/mod_icons/mod_power.png",
		prototype = "自行高炮必备", description = "车载发电持续供能。攻速 +100%。",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 100, cost_install = 50,
		slot_type = "power", conflict_group = "power",
		effects = {sustained_fire = 1.0},
		unlock_conditions = {required_level = 2}
	},
	"aa_09_smoke_launcher" = {
		id = AA_09_SMOKE_LAUNCHER, name = "烟幕弹发射器", name_en = "Smoke Launcher",
		icon = "res://assets/ui/icons/mod_icons/mod_countermeasure.png",
		prototype = "76mm烟幕", description = "烟幕遮蔽。导弹闪避提升 30%。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 160, cost_install = 80,
		slot_type = "countermeasure", conflict_group = "countermeasure",
		effects = {missile_dodge = 0.30},
		level_effects = {1: {missile_dodge = 0.3}, 2: {missile_dodge = 0.39}, 3: {missile_dodge = 0.51}},
		unlock_conditions = {required_level = 3}
	},
	"aa_10_camouflage" = {
		id = AA_10_CAMOUFLAGE, name = "伪装网", name_en = "Camouflage Net",
		icon = "res://assets/ui/icons/mod_icons/mod_stealth.png",
		prototype = "红外伪装网", description = "红外伪装网隐蔽。闪避 +30%。",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 90, cost_install = 45,
		slot_type = "stealth", conflict_group = "stealth",
		era_band = [2, 4],
		effects = {aggro_reduce = -0.30},
		unlock_conditions = {required_level = 2}
	},
	"aa_11_auto_fc" = {
		id = AA_11_AUTO_FC, name = "自动化火控", name_en = "Auto Fire Control",
		icon = "res://assets/ui/icons/mod_icons/mod_fire_control.png",
		prototype = "天空卫士", description = "全自动火控。射速与暴击伤害提升。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 320, cost_install = 160,
		slot_type = "fire_control", conflict_group = "fire_control",
		era_band = [2, 4],
		effects = {attack_interval = -0.40, accuracy_bonus = 0.15},
		unlock_conditions = {required_level = 5}
	},
	"aa_12_fire_on_move" = {
		id = AA_12_FIRE_ON_MOVE, name = "行进间射击", name_en = "Fire on Move",
		icon = "res://assets/ui/icons/mod_icons/mod_mobility.png",
		prototype = "ZSU-23-4", description = "行进间射击。攻速 +10%，暴击率 -20%。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 300, cost_install = 150,
		slot_type = "mobility", conflict_group = "mobility",
		era_band = [2, 4],
		effects = {mobile_fire = true, accuracy_penalty = -0.20},
		unlock_conditions = {required_level = 5}
	},

	# ─── v7.x 新机制改造 ───

	# debuff 型：雷达锁定（对空目标 40% 标记 + 30% 易伤）
	"aa_13_radar_lock" = {
		id = "aa_13_radar_lock",
		name = "雷达锁定",
		name_en = "Radar Lock-On",
		icon = "res://assets/ui/icons/mod_icons/mod_guidance.png",
		prototype = "AN/MPQ-64 哨兵雷达",
		description = "锁定空中目标：40% 概率标记目标，被标记目标受到 +30% 额外伤害，持续 5 秒",
		rarity = "legendary",
		power_mult = 1.8,
		cost_research = 380,
		cost_install = 190,
		slot_type = "guidance",
		conflict_group = "guidance",
		era_band = [3, 4],
		effects = {target_marking = 0.40, mark_vuln = 0.30, mark_duration = 5.0},
		level_effects = {1: {target_marking = 0.4, mark_vuln = 0.3, mark_duration = 5}, 2: {target_marking = 0.52, mark_vuln = 0.39, mark_duration = 6.5}, 3: {target_marking = 0.6, mark_vuln = 0.51, mark_duration = 8.5}},
		unlock_conditions = {required_level = 6}
	},

	# ==================== v9.1 组合技套路配套改造（2 个） ====================
	# 套路2 电磁脉冲链：电磁战斗部（读 graphite charge 增伤）
	"aa_emp_warhead" = {
		id = "aa_emp_warhead",
		name = "电磁战斗部",
		name_en = "EMP Warhead",
		icon = "res://assets/ui/icons/mod_icons/mod_emp_warhead.png",
		prototype = "微波战斗部",
		description = "40% 概率释放电磁脉冲，降低攻速、暴击与闪避并造成真实伤害。目标石墨电子损坏层数越高伤害越高。电磁脉冲链触发器。",
		rarity = "legendary",
		power_mult = 1.8,
		cost_research = 400,
		cost_install = 200,
		slot_type = "ammunition",
		conflict_group = "special_ammo",
		era_band = [3, 4],
		effects = {emp_chance = 0.40, emp_true_damage = 12.0, graphite_amp = true},
		level_effects = {1: {emp_chance = 0.4, emp_true_damage = 12, graphite_amp = true}, 2: {emp_chance = 0.52, emp_true_damage = 15.6, graphite_amp = true}, 3: {emp_chance = 0.6, emp_true_damage = 20.4, graphite_amp = true}},
		applicable_types = [0, 4],
		unlock_conditions = {required_level = 6}
	},
	# 套路6 化学污染场：酸液战斗部（化学腐蚀触发器）
	"aa_acid_warhead" = {
		id = "aa_acid_warhead",
		name = "酸液战斗部",
		name_en = "Acid Warhead",
		icon = "res://assets/ui/icons/mod_icons/mod_acid.png",
		prototype = "腐蚀性酸战斗部",
		description = "45% 概率挂化学毒。目标化学层数 ≥5 时额外护甲穿透 +20%。化学污染场触发器。",
		rarity = "epic",
		power_mult = 1.7,
		cost_research = 360,
		cost_install = 180,
		slot_type = "ammunition",
		conflict_group = "special_ammo",
		effects = {chem_chance = 0.45, chem_dps = 10.0, chem_duration = 5.0, chem_corrosion = true, attack_air = 0.06},
		applicable_types = [0, 4],
		unlock_conditions = {required_level = 5}
	},
	# ─── v26 防空反制批（era0/1 对空池补强）───
	"aa_14_searchlight" = {
		id = "aa_14_searchlight",
		name = "探照灯组",
		name_en = "Searchlight Battery",
		icon = "res://assets/ui/icons/mod_icons/aa_14_searchlight.png",
		prototype = "不列颠空战 150cm 探照灯带",
		description = "夜间照明锁定轰炸机群——对空命中要害率提升",
		rarity = "uncommon",
		power_mult = 1.1,
		cost_research = 90,
		cost_install = 45,
		slot_type = "optics",
		conflict_group = "optics",
		era_band = [0, 1],
		effects = {crit_chance = 0.06, vision = 0.15},
		unlock_conditions = {required_level = 1}
	},

	"aa_15_flak_burst" = {
		id = "aa_15_flak_burst",
		name = "定时引信防空弹",
		name_en = "Flak Timed-Fuze Shells",
		icon = "res://assets/ui/icons/mod_icons/aa_15_flak_burst.png",
		prototype = "Flak 88 / 博福斯定时引信弹",
		description = "空炸弹幕覆盖机群航线——对空伤害与溅射提升",
		rarity = "rare",
		power_mult = 1.3,
		cost_research = 150,
		cost_install = 75,
		slot_type = "ammunition",
		conflict_group = "ammunition",
		era_band = [0, 2],
		effects = {attack_air_pct = 0.15, splash_damage = 0.20},
		unlock_conditions = {required_level = 2}
	},


	# ══════════ v27 改造2.0 批：普及档 + 对空强化（防空火网套装件为既有 aa_02/05/07/11）══════════
	"aa_16_ammo_cache" = {
		id = "aa_16_ammo_cache",
		name = "备弹库",
		name_en = "Ammunition Cache",
		icon = "res://assets/ui/icons/mod_icons/mod_ammunition.png",
		prototype = "阵地备弹库",
		description = "就近备弹。射速 +4%。",
		rarity = "common",
		power_mult = 0.8,
		cost_research = 50,
		cost_install = 25,
		slot_type = "ammunition",
		conflict_group = "ammunition",
		effects = {attack_interval = -0.04},
		level_effects = {1: {attack_interval = -0.04}, 2: {attack_interval = -0.05}, 3: {attack_interval = -0.07}},
		unlock_conditions = {required_level = 1}
	},
	"aa_17_altimeter" = {
		id = "aa_17_altimeter",
		name = "测高仪",
		name_en = "Altimeter",
		icon = "res://assets/ui/icons/mod_icons/mod_radar.png",
		prototype = "机械测高仪",
		description = "目标高度数据。暴击率 +5%，对空伤害 +8%。",
		rarity = "uncommon",
		power_mult = 1.0,
		cost_research = 100,
		cost_install = 50,
		slot_type = "sensor",
		conflict_group = "sensor",
		effects = {crit_chance = 0.05, attack_air = 0.08},
		level_effects = {1: {crit_chance = 0.05, attack_air = 0.08}, 2: {crit_chance = 0.065, attack_air = 0.10}, 3: {crit_chance = 0.085, attack_air = 0.14}},
		unlock_conditions = {required_level = 2}
	},
	"aa_18_twin_mount" = {
		id = "aa_18_twin_mount",
		name = "双联装改装",
		name_en = "Twin Mount Conversion",
		icon = "res://assets/ui/icons/mod_icons/mod_mount.png",
		prototype = "双联装炮架",
		description = "双炮身交错射击。对空伤害 +15%。",
		rarity = "rare",
		power_mult = 1.3,
		cost_research = 160,
		cost_install = 80,
		slot_type = "weapon",
		conflict_group = "damage",
		effects = {attack_air = 0.15},
		level_effects = {1: {attack_air = 0.15}, 2: {attack_air = 0.20}, 3: {attack_air = 0.26}},
		unlock_conditions = {required_level = 3}
	},
	"aa_19_barrage_computer" = {
		id = "aa_19_barrage_computer",
		name = "弹幕计算机",
		name_en = "Barrage Computer",
		icon = "res://assets/ui/icons/mod_icons/mod_fire_control.png",
		prototype = "提前量弹幕解算",
		description = "弹幕射击解算。射速 +10%，对空伤害 +10%。",
		rarity = "epic",
		power_mult = 1.5,
		cost_research = 300,
		cost_install = 150,
		slot_type = "fire_control",
		conflict_group = "fire_rate",
		era_band = [2, 4],
		effects = {attack_interval = -0.10, attack_air = 0.10},
		level_effects = {1: {attack_interval = -0.10, attack_air = 0.10}, 2: {attack_interval = -0.13, attack_air = 0.13}, 3: {attack_interval = -0.17, attack_air = 0.17}},
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

# v7.x: cold_zsu23→cold_sup_zsu23, mod_m6→mod_sup_m6
const _CARD_PREFIXES: Array = ["ww1_37mm", "cold_sup_zsu23", "cold_sam7", "mod_sup_m6", "mod_stinger", "fut_aa_hover"]
