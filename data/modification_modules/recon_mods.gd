extends RefCounted
class_name ReconModifications
## 侦察/特种改造模块定义（12个）

const REC_01_OPTICAL_CAMOUFLAGE = "rec_01_optical_camouflage"
const REC_02_IR_SUPPRESSION = "rec_02_ir_suppression"
const REC_03_SUPPRESSOR = "rec_03_suppressor"
const REC_04_HIGH_POWER_SCOPE = "rec_04_high_power_scope"
const REC_05_UAV = "rec_05_uav"
const REC_06_TACTICAL_RADIO = "rec_06_tactical_radio"
const REC_07_GPS = "rec_07_gps"
const REC_08_NVG = "rec_08_nvg"
const REC_09_BREACHING = "rec_09_breaching"
const REC_10_MEDKIT = "rec_10_medkit"
const REC_11_DECOY = "rec_11_decoy"
const REC_12_ATV = "rec_12_atv"

const DATA: Dictionary = {
	"rec_01_optical_camouflage" = {
		id = REC_01_OPTICAL_CAMOUFLAGE, name = "光学伪装", name_en = "Optical Camouflage",
		icon = "res://assets/ui/icons/mod_icons/mod_stealth.png",
		prototype = "吉利服", description = "隐蔽接敌，暴击+50%",
		rarity = "rare",
	power_mult = 1.3, cost_research = 140, cost_install = 70,
		slot_type = "stealth", conflict_group = "stealth",
		effects = {detection_range = -0.50},
		unlock_conditions = {required_level = 2}
	},
	"rec_02_ir_suppression" = {
		id = REC_02_IR_SUPPRESSION, name = "红外抑制", name_en = "IR Suppression",
		icon = "res://assets/ui/icons/mod_icons/mod_stealth.png",
		prototype = "热信号遮蔽", description = "减伤提升",
		rarity = "epic",
	power_mult = 1.6, cost_research = 280, cost_install = 140,
		slot_type = "stealth", conflict_group = "stealth",
		effects = {thermal_immunity = 0.70},
		unlock_conditions = {required_level = 4}
	},
	"rec_03_suppressor" = {
		id = REC_03_SUPPRESSOR, name = "消音器", name_en = "Suppressor",
		icon = "res://assets/ui/icons/mod_icons/mod_weapon.png",
		prototype = "抑制器", description = "闪避+50%",
		rarity = "rare",
	power_mult = 1.3, cost_research = 160, cost_install = 80,
		slot_type = "weapon", conflict_group = "weapon",
		effects = {fire_exposure = -0.80},
		unlock_conditions = {required_level = 3}
	},
	"rec_04_high_power_scope" = {
		id = REC_04_HIGH_POWER_SCOPE, name = "高倍瞄准镜", name_en = "High-Power Scope",
		icon = "res://assets/ui/icons/mod_icons/mod_optics.png",
		prototype = "施华洛世奇", description = "高倍瞄具，射程和暴击提升",
		rarity = "epic",
	power_mult = 1.6, cost_research = 300, cost_install = 150,
		slot_type = "optics", conflict_group = "optics",
		# v7.x: per-slot 弹道——对轻装槽改 SNIPER 精确射击
		condition_slot = 0,
		effects = {attack_range = 60, crit_chance = 0.10, slot_weapon_type = 6, true_damage = 12},  # v8.6: 狙击补真实伤害（高倍瞄准=无视护甲命中要害）
		unlock_conditions = {required_level = 5}
	},
	"rec_05_uav" = {
		id = REC_05_UAV, name = "无人侦察机", name_en = "Recon UAV",
		icon = "res://assets/ui/icons/mod_icons/mod_drone.png",
		prototype = "RQ-11大乌鸦", description = "无人机侦察，暴击率提升",
		rarity = "epic",
	power_mult = 1.6, cost_research = 320, cost_install = 160,
		slot_type = "drone", conflict_group = "drone",
		effects = {vision_bonus = 0.50, stealth_detect = 0.20},
		unlock_conditions = {required_level = 5}
	},
	"rec_06_tactical_radio" = {
		id = REC_06_TACTICAL_RADIO, name = "战术电台", name_en = "Tactical Radio",
		icon = "res://assets/ui/icons/mod_icons/mod_comms.png",
		prototype = "单兵超短波", description = "战术通讯协调，暴击率+30%",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 80, cost_install = 40,
		slot_type = "comms", conflict_group = "comms",
		effects = {intel_speed = 0.30},
		unlock_conditions = {required_level = 1}
	},
	"rec_07_gps" = {
		id = REC_07_GPS, name = "GPS定位仪", name_en = "GPS Receiver",
		icon = "res://assets/ui/icons/mod_icons/mod_navigation.png",
		prototype = "军用GPS", description = "GPS定位，部署加速20%",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 90, cost_install = 45,
		slot_type = "navigation", conflict_group = "navigation",
		effects = {move_speed = 10},
		unlock_conditions = {required_level = 2}
	},
	"rec_08_nvg" = {
		id = REC_08_NVG, name = "夜视仪", name_en = "Night Vision",
		icon = "res://assets/ui/icons/mod_icons/mod_optics.png",
		prototype = "PVS-14", description = "夜视瞄准，暴击率+15%",
		rarity = "rare",
	power_mult = 1.3, cost_research = 180, cost_install = 90,
		slot_type = "optics", conflict_group = "optics",
		effects = {night_bonus = 0.15},
		unlock_conditions = {required_level = 3}
	},
	"rec_09_breaching" = {
		id = REC_09_BREACHING, name = "破门工具", name_en = "Breaching Tools",
		icon = "res://assets/ui/icons/mod_icons/mod_environment.png",
		prototype = "霰弹枪/破门锤", description = "城市战部署更快",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 100, cost_install = 50,
		slot_type = "environment", conflict_group = "environment",
		# v7.x: per-slot 弹道——对轻装槽改 SHOTGUN 霰弹（破门近战）
		condition_slot = 0,
		effects = {urban_move_bonus = 20, slot_weapon_type = 5},  # v7.x: 对轻装槽霰弹弹道,
		unlock_conditions = {required_level = 2}
	},
	"rec_10_medkit" = {
		id = REC_10_MEDKIT, name = "急救包", name_en = "Medical Kit",
		icon = "res://assets/ui/icons/mod_icons/mod_medical.png",
		prototype = "IFAK", description = "濒死回复15%HP",
		rarity = "rare",
	power_mult = 1.3, cost_research = 120, cost_install = 60,
		slot_type = "medical", conflict_group = "medical",
		effects = {ifak_revive = 0.15},  # v7.x 第二批：修复为濒死复活（原 ifak_heal 误为 hp_regen）
		unlock_conditions = {required_level = 2}
	},
	"rec_11_decoy" = {
		id = REC_11_DECOY, name = "假目标", name_en = "Decoy",
		icon = "res://assets/ui/icons/mod_icons/mod_deception.png",
		prototype = "充气坦克/假人", description = "假目标诱饵，暴击率+20%",
		rarity = "rare",
	power_mult = 1.3, cost_research = 160, cost_install = 80,
		slot_type = "deception", conflict_group = "deception",
		effects = {enemy_confusion = 0.20},
		unlock_conditions = {required_level = 3}
	},
	"rec_12_atv" = {
		id = REC_12_ATV, name = "越野摩托", name_en = "All-Terrain Vehicle",
		icon = "res://assets/ui/icons/mod_icons/mod_mobility.png",
		prototype = "侦察摩托", description = "越野摩托，部署加速60%",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 110, cost_install = 55,
		slot_type = "mobility", conflict_group = "mobility",
		effects = {move_speed = 30},
		unlock_conditions = {required_level = 2}
	},

	# ─── v7.x 新机制改造 ───

	# debuff 型：目标指示器（30% 标记 + 25% 易伤）
	"rec_13_target_designator" = {
		id = "rec_13_target_designator",
		name = "目标指示器",
		name_en = "Target Designator",
		icon = "res://assets/ui/icons/mod_icons/mod_guidance.png",
		prototype = "SOFLAM 激光指示器",
		description = "激光标记目标：30% 概率标记，被标记目标受到 +25% 额外伤害，持续 5 秒",
		rarity = "epic",
		power_mult = 1.6,
		cost_research = 320,
		cost_install = 160,
		slot_type = "guidance",
		conflict_group = "guidance",
		effects = {target_marking = 0.30, mark_vuln = 0.25, mark_duration = 5.0},
		unlock_conditions = {required_level = 5}
	},

	# debuff 型：暴击指示器（30% 暴击标注 + 暴击率+50%，全队远程优先集火）
	"rec_14_crit_designator" = {
		id = "rec_14_crit_designator",
		name = "暴击指示器",
		name_en = "Crit Designator",
		icon = "res://assets/ui/icons/mod_icons/mod_guidance.png",
		prototype = "精确标定仪",
		description = "攻击命中 30% 概率挂暴击标注，被标注目标受到攻击时暴击率 +50%，持续 5 秒（全队远程优先集火）",
		rarity = "epic",
		power_mult = 1.6,
		cost_research = 320,
		cost_install = 160,
		slot_type = "guidance",
		conflict_group = "crit_designator",
		effects = {crit_mark_chance = 0.30, crit_mark_bonus = 0.50, crit_mark_duration = 5.0},
		unlock_conditions = {required_level = 5}
	},
}

static func get_mod_data(mod_id: String) -> Dictionary:
	return DATA.get(mod_id, {}).duplicate(true)

static func get_all_mod_ids() -> Array:
	return DATA.keys()

static func get_for_unit_type(unit_type: int) -> Array:
	if unit_type == 0: return DATA.keys()  # LIGHT (recon)
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

# v7.x: ww1_cavalry→ww1_inf_cavalry, fut_scout_mech→fut_inf_scout_mech, fut_scout_drone→mod_inf_scout_drone
const _CARD_PREFIXES: Array = ["ww1_inf_cavalry", "cold_spetsnaz", "mod_ranger", "fut_spectre", "fut_inf_scout_mech", "mod_inf_scout_drone"]
