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
		effects = {attack_range = 60, attack_light = 6, true_damage = 10},
		level_effects = {1: {attack_light = 6, attack_range = 60, true_damage = 10}, 2: {attack_light = 10, attack_range = 60, true_damage = 10}, 3: {attack_light = 14, attack_range = 60, true_damage = 10}},
		unlock_conditions = {required_level = 2}
	},

	"art_02_extended_range" = {
		id = ART_02_EXTENDED_RANGE,
		name = "增程弹",
		name_en = "Extended Range Munition",
		icon = "res://assets/ui/icons/mod_icons/mod_ammo_extended.png",
		prototype = "M549火箭增程弹",
		description = "火箭增程，射程大幅提升，威力略降",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 180,
		cost_install = 90,
		slot_type = "ammunition",
		conflict_group = "ammunition",
		effects = {attack_range = 90, attack_light = -0.10, true_damage = 15},  # v8.6: 补真实伤害（增程弹=远距离精准打击）
		unlock_conditions = {required_level = 3}
	},

	"art_03_guided_shell" = {
		id = ART_03_GUIDED_SHELL,
		name = "精确制导炮弹",
		name_en = "Guided Shell",
		icon = "res://assets/ui/icons/mod_icons/mod_guidance.png",
		prototype = "M982神剑",
		description = "GPS制导，暴击率和暴击伤害大幅提升",
		rarity = "legendary",
	power_mult = 2.0,
		cost_research = 400,
		cost_install = 200,
		slot_type = "guidance",
		conflict_group = "guidance",
		# v7.x: per-slot 弹道——对装甲槽改 MISSILE 制导
		condition_slot = 1,
		effects = {accuracy_bonus = 0.50, crit_chance = 0.15, weapon_type = 9, slot_weapon_type = 9, vfx_variant = "guided"},  # v6.5 MISSILE + v7.x 对装甲槽制导 + v8.4 制导专属视觉,
		unlock_conditions = {required_level = 6}
	},

	"art_04_cluster_munition" = {
		id = ART_04_CLUSTER_MUNITION,
		name = "子母弹",
		name_en = "Cluster Munition",
		icon = "res://assets/ui/icons/mod_icons/mod_ammo_cluster.png",
		prototype = "M26火箭弹",
		description = "范围伤害增加，单目标伤害略降",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 280,
		cost_install = 140,
		slot_type = "ammunition",
		conflict_group = "ammunition",
		# v7.x: per-slot 弹道——对装甲槽改 MISSILE 撒布
		condition_slot = 1,
		effects = {splash_radius = 0.50, single_target_penalty = -0.20, weapon_type = 9, slot_weapon_type = 9, vfx_variant = "cluster"},  # v6.5 MISSILE + v7.x 对装甲槽撒布 + v8.4 子弹药撒布专属视觉,
		unlock_conditions = {required_level = 5}
	},

	"art_05_counter_battery_radar" = {
		id = ART_05_COUNTER_BATTERY_RADAR,
		name = "反炮兵雷达",
		name_en = "Counter-Battery Radar",
		icon = "res://assets/ui/icons/mod_icons/mod_radar.png",
		prototype = "AN/TPQ-53",
		description = "精确反击，暴击伤害提升",
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
		description = "无人机校射，暴击伤害+炮兵攻速提升",
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
		icon = "res://assets/ui/icons/mod_icons/mod_ammo_thermobaric.png",
		prototype = "TOS-1喷火坦克",
		description = "温压弹头，对堡垒伤害大幅提升",
		rarity = "legendary",
	power_mult = 2.0,
		cost_research = 450,
		cost_install = 225,
		slot_type = "ammunition",
		conflict_group = "ammunition",
		# v7.x: per-slot 弹道——对装甲槽改 ROCKET 火箭（温压弹头重型爆破）
		condition_slot = 1,
		effects = {attack_fort = 0.50, slot_weapon_type = 3, vfx_variant = "thermobaric"},  # v7.x: 对装甲槽火箭弹道（ROCKET）+ v8.4 温压二次爆炸视觉
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
		effects = {defense_light = 40, deploy_speed = -1},
		level_effects = {1: {defense_light = 40, deploy_speed = -1}, 2: {defense_light = 70, deploy_speed = -1}, 3: {defense_light = 100, deploy_speed = -1}},
		unlock_conditions = {required_level = 2}
	},

	# ─── v7.x 新机制改造 ───

	# debuff 型：尾翼稳定脱壳穿甲（每次命中 -8% 防御，最多 5 层）
	"art_13_apfsds_sabot" = {
		id = "art_13_apfsds_sabot",
		name = "尾翼稳定脱壳穿甲",
		name_en = "APFSDS Sabot",
		icon = "res://assets/ui/icons/mod_icons/mod_ammo_apfsds.png",
		prototype = "M829A4 穿甲弹",
		description = "每次命中撕裂目标装甲：降低 8% 防御，最多叠加 5 层（累计 -40% 防御）",
		rarity = "legendary",
		power_mult = 1.9,
		cost_research = 420,
		cost_install = 210,
		slot_type = "ammunition",
		conflict_group = "ammunition",
		effects = {armor_break = 0.08, armor_break_stacks = 5},
		unlock_conditions = {required_level = 6}
	},

	# 兵种专属：反击炮击（被攻击时标记攻击者，炮兵优先反击）
	"art_14_counter_battery" = {
		id = "art_14_counter_battery",
		name = "反击炮击",
		name_en = "Counter-Battery Fire",
		icon = "res://assets/ui/icons/mod_icons/mod_special.png",
		prototype = "AN/TPQ-36 反炮兵雷达",
		description = "被攻击时自动标记攻击者（5秒），炮兵优先反击被标记目标，并额外获得 2 次优先反击机会",
		rarity = "legendary",
		power_mult = 2.0,
		cost_research = 450,
		cost_install = 225,
		slot_type = "special",
		conflict_group = "special",
		effects = {counter_battery = 1},
		unlock_conditions = {required_level = 7}
	},

	# ─── v8.6 现实/科幻伤害类型 ───
	"art_15_emp_round" = {
		id = "art_15_emp_round",
		name = "电磁脉冲弹",
		name_en = "EMP Round",
		icon = "res://assets/ui/icons/mod_icons/mod_special.png",
		prototype = "电磁脉冲炮弹",
		description = "攻击40%概率触发电磁脉冲：目标攻速-30%、暴击-20%、闪避-15%（4秒），并造成12点真实伤害（蓝色电弧）",
		rarity = "epic",
		power_mult = 1.6,
		cost_research = 320,
		cost_install = 160,
		slot_type = "special",
		conflict_group = "special_ammo",
		effects = {emp_chance = 0.40, emp_true_damage = 12.0},
		applicable_types = [2],
		unlock_conditions = {required_level = 5}
	},

	"art_16_nano_virus" = {
		id = "art_16_nano_virus",
		name = "纳米病毒弹",
		name_en = "Nano-Virus Shell",
		icon = "res://assets/ui/icons/mod_icons/mod_special.png",
		prototype = "纳米机械病毒弹头",
		description = "攻击25%概率注入纳米病毒：目标每秒损失2%最大生命值，持续8秒（紫色粒子，打肉盾专用）",
		rarity = "legendary",
		power_mult = 1.8,
		cost_research = 400,
		cost_install = 200,
		slot_type = "special",
		conflict_group = "special_ammo",
		effects = {nano_chance = 0.25, nano_pct = 0.02, nano_duration = 8.0},
		applicable_types = [2],
		unlock_conditions = {required_level = 6}
	},

	# ==================== v9.1 组合技套路配套改造（5 个） ====================
	# 套路1 助燃燃烧链：助燃剂弹（命中挂 _incendiary_stacks）
	"art_incendiary_mix" = {
		id = "art_incendiary_mix",
		name = "助燃剂弹",
		name_en = "Incendiary Mix",
		icon = "res://assets/ui/icons/mod_icons/mod_ammo_incendiary.png",
		prototype = "镁粉混合弹药",
		description = "命中40%概率挂助燃剂标记（层数累积），与白磷弹/温压弹组成助燃燃烧链",
		rarity = "epic",
		power_mult = 1.6,
		cost_research = 320,
		cost_install = 160,
		slot_type = "ammunition",
		conflict_group = "special_ammo",
		effects = {incendiary_chance = 0.40, incendiary_stacks = 1, attack_light = 0.08},
		applicable_types = [2],
		unlock_conditions = {required_level = 5}
	},
	# 套路1 助燃燃烧链：白磷弹（读 stacks 提升燃烧概率+层数上限）
	"art_white_phosphorus" = {
		id = "art_white_phosphorus",
		name = "白磷弹",
		name_en = "White Phosphorus",
		icon = "res://assets/ui/icons/mod_icons/mod_ammo_phosphorus.png",
		prototype = "M825白磷发烟弹",
		description = "35%概率挂燃烧，助燃剂层数越高燃烧概率越大；套路激活时燃烧层数上限 5→10",
		rarity = "epic",
		power_mult = 1.7,
		cost_research = 360,
		cost_install = 180,
		slot_type = "ammunition",
		conflict_group = "special_ammo",
		effects = {burn_chance = 0.35, burn_dps = 8.0, incendiary_synergy = true, attack_light = 0.06},
		applicable_types = [2],
		unlock_conditions = {required_level = 5}
	},
	# 套路2 电磁脉冲链：石墨纤维弹（命中累积电子损坏）
	"art_graphite_fiber" = {
		id = "art_graphite_fiber",
		name = "石墨纤维弹",
		name_en = "Graphite Fiber Shell",
		icon = "res://assets/ui/icons/mod_icons/mod_ammo_graphite.png",
		prototype = "石墨纤维战斗部",
		description = "命中50%概率累积石墨电子损坏层数，与电磁战斗部/反辐射导弹组成电磁脉冲链",
		rarity = "epic",
		power_mult = 1.6,
		cost_research = 340,
		cost_install = 170,
		slot_type = "ammunition",
		conflict_group = "special_ammo",
		effects = {graphite_chance = 0.50, graphite_stacks = 1},
		applicable_types = [2],
		unlock_conditions = {required_level = 5}
	},
	# 套路3 纳米浓度场：纳米放大器（读浓度增伤）
	"art_nano_amp" = {
		id = "art_nano_amp",
		name = "纳米放大器",
		name_en = "Nano Amplifier",
		icon = "res://assets/ui/icons/mod_icons/mod_nano_amp.png",
		prototype = "纳米谐振弹头",
		description = "纳米病毒概率+伤害+，与纳米播种机/纳米催化剂组成纳米浓度场套路",
		rarity = "legendary",
		power_mult = 1.9,
		cost_research = 420,
		cost_install = 210,
		slot_type = "special",
		conflict_group = "special_ammo",
		effects = {nano_chance = 0.30, nano_pct = 0.03, nano_duration = 8.0, nano_concentration_amp = true},
		applicable_types = [2],
		unlock_conditions = {required_level = 6}
	},
	# 套路6 化学污染场：化学集束弹（高概率挂毒+累积浓度）
	"art_chem_cluster" = {
		id = "art_chem_cluster",
		name = "化学集束弹",
		name_en = "Chem Cluster",
		icon = "res://assets/ui/icons/mod_icons/mod_ammo_chem.png",
		prototype = "M687化学子母弹",
		description = "50%概率挂化学毒，每次命中累积战场化学污染度；与酸液战斗部/化学喷洒器组成化学污染场套路",
		rarity = "epic",
		power_mult = 1.7,
		cost_research = 360,
		cost_install = 180,
		slot_type = "ammunition",
		conflict_group = "special_ammo",
		effects = {chem_chance = 0.50, chem_dps = 12.0, chem_duration = 5.0, chem_pollute = 3.0, attack_light = 0.05},
		applicable_types = [2],
		unlock_conditions = {required_level = 5}
	},
	# 套路3 纳米浓度场：纳米播种机（攻击累加浓度）
	"sup_nano_seeder" = {
		id = "sup_nano_seeder",
		name = "纳米播种机",
		name_en = "Nano Seeder",
		icon = "res://assets/ui/icons/mod_icons/mod_nano_seeder.png",
		prototype = "纳米粒子播撒装置",
		description = "每次攻击累积战场纳米浓度，浓度越高纳米病毒伤害越高；纳米浓度场触发器",
		rarity = "epic",
		power_mult = 1.6,
		cost_research = 340,
		cost_install = 170,
		slot_type = "special",
		conflict_group = "special_ammo",
		effects = {nano_seeder_amount = 1.5, nano_chance = 0.15, nano_pct = 0.015, nano_duration = 6.0},
		applicable_types = [2],
		unlock_conditions = {required_level = 5}
	},
	# 套路5 侦察链式：目标指示无人机（增强无人机标记范围+易伤）
	"sup_targeting_drone" = {
		id = "sup_targeting_drone",
		name = "目标指示无人机",
		name_en = "Targeting Drone",
		icon = "res://assets/ui/icons/mod_icons/mod_targeting_drone.png",
		prototype = "标定攻击无人机",
		description = "增强无人机标记范围+易伤值，与相控阵雷达叠加触发集火链式弱点暴露；侦察链式触发器",
		rarity = "legendary",
		power_mult = 1.7,
		cost_research = 380,
		cost_install = 190,
		slot_type = "sensor",
		conflict_group = "sensor",
		effects = {drone_mark_vuln_bonus = 0.10, crit_chance = 0.04},
		applicable_types = [2],
		unlock_conditions = {required_level = 6}
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

# v7.x: ww1_m81→ww1_arty_m81, ww1_77mm→ww1_arty_77mm, ww2_m81→ww2_arty_m81,
# cold_m113→cold_sup_m113, mod_m270→mod_arty_m270
const _CARD_PREFIXES: Array = ["ww1_arty_m81", "ww1_m76", "ww1_arty_77mm", "ww1_105mm", "ww1_mg08", "ww1_vickers", "ww2_arty_m81", "ww2_m120", "ww2_mg42", "ww2_browning", "cold_sup_m113", "mod_arty_m270", "fut_howitzer", "fut_stormcore"]
