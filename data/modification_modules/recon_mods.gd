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
		icon = "res://assets/ui/icons/mod_icons/rec_01_optical_camouflage.png",
		prototype = "吉利服", description = "光学迷彩隐蔽接敌。暴击 +50%。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 140, cost_install = 70,
		slot_type = "stealth", conflict_group = "stealth",
		effects = {detection_range = -0.50},
		unlock_conditions = {required_level = 2}
	},
	"rec_02_ir_suppression" = {
		id = REC_02_IR_SUPPRESSION, name = "红外抑制", name_en = "IR Suppression",
		icon = "res://assets/ui/icons/mod_icons/rec_02_ir_suppression.png",
		prototype = "热信号遮蔽", description = "热信号遮蔽处理。减伤提升。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 280, cost_install = 140,
		slot_type = "stealth", conflict_group = "stealth",
		era_band = [3, 4],
		effects = {thermal_immunity = 0.70},
		level_effects = {1: {thermal_immunity = 0.7}, 2: {thermal_immunity = 0.6}, 3: {thermal_immunity = 0.6}},
		unlock_conditions = {required_level = 4}
	},
	"rec_03_suppressor" = {
		id = REC_03_SUPPRESSOR, name = "消音器", name_en = "Suppressor",
		icon = "res://assets/ui/icons/mod_icons/rec_03_suppressor.png",
		prototype = "抑制器", description = "枪口抑制器压制声光。闪避 +50%。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 160, cost_install = 80,
		slot_type = "weapon", conflict_group = "weapon",
		effects = {fire_exposure = -0.80},
		unlock_conditions = {required_level = 3}
	},
	"rec_04_high_power_scope" = {
		id = REC_04_HIGH_POWER_SCOPE, name = "高倍瞄准镜", name_en = "High-Power Scope",
		icon = "res://assets/ui/icons/mod_icons/rec_04_high_power_scope.png",
		prototype = "施华洛世奇", description = "高倍观测瞄准。射程与暴击提升。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 300, cost_install = 150,
		slot_type = "optics", conflict_group = "optics",
		# v7.x: per-slot 弹道——对轻装槽改 SNIPER 精确射击
		condition_slot = 0,
		era_band = [0, 3],
		effects = {attack_range = 60, crit_chance = 0.10, slot_weapon_type = 6, true_damage = 12},  # v8.6: 狙击补真实伤害（高倍瞄准=无视护甲命中要害）
		unlock_conditions = {required_level = 5}
	},
	"rec_05_uav" = {
		id = REC_05_UAV, name = "无人侦察机", name_en = "Recon UAV",
		icon = "res://assets/ui/icons/mod_icons/rec_05_uav.png",
		prototype = "RQ-11大乌鸦", description = "无人侦察机校射。暴击率提升。",
		rarity = "epic",
	power_mult = 1.6, cost_research = 320, cost_install = 160,
		slot_type = "drone", conflict_group = "uav",
		era_band = [3, 4],
		effects = {vision_bonus = 0.50, stealth_detect = 0.20},
		unlock_conditions = {required_level = 5}
	},
	"rec_06_tactical_radio" = {
		id = REC_06_TACTICAL_RADIO, name = "战术电台", name_en = "Tactical Radio",
		icon = "res://assets/ui/icons/mod_icons/rec_06_tactical_radio.png",
		prototype = "单兵超短波", description = "战术电台通讯协调。暴击率 +30%。",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 80, cost_install = 40,
		slot_type = "comms", conflict_group = "comms",
		era_band = [1, 4],
		effects = {intel_speed = 0.30},
		level_effects = {1: {intel_speed = 0.3}, 2: {intel_speed = 0.39}, 3: {intel_speed = 0.51}},
		unlock_conditions = {required_level = 1}
	},
	"rec_07_gps" = {
		id = REC_07_GPS, name = "GPS定位仪", name_en = "GPS Receiver",
		icon = "res://assets/ui/icons/mod_icons/rec_07_gps.png",
		prototype = "军用GPS", description = "GPS 定位引导。部署加速 20%。",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 90, cost_install = 45,
		slot_type = "navigation", conflict_group = "navigation",
		era_band = [3, 4],
		effects = {move_speed = 10},
		unlock_conditions = {required_level = 2}
	},
	"rec_08_nvg" = {
		id = REC_08_NVG, name = "夜视仪", name_en = "Night Vision",
		icon = "res://assets/ui/icons/mod_icons/rec_08_nvg.png",
		prototype = "PVS-14", description = "微光夜视瞄准。暴击率 +15%。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 180, cost_install = 90,
		slot_type = "optics", conflict_group = "optics",
		era_band = [2, 4],
		effects = {night_bonus = 0.15},
		level_effects = {1: {night_bonus = 0.15}, 2: {night_bonus = 0.195}, 3: {night_bonus = 0.255}},
		unlock_conditions = {required_level = 3}
	},
	"rec_09_breaching" = {
		id = REC_09_BREACHING, name = "破门工具", name_en = "Breaching Tools",
		icon = "res://assets/ui/icons/mod_icons/rec_09_breaching.png",
		prototype = "霰弹枪/破门锤", description = "破门器材随行。城市战部署更快。",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 100, cost_install = 50,
		slot_type = "environment", conflict_group = "environment",
		# v7.x: per-slot 弹道——对轻装槽改 SHOTGUN 霰弹（破门近战）
		condition_slot = 0,
		effects = {urban_move_bonus = 20, slot_weapon_type = 5},  # v7.x: 对轻装槽霰弹弹道,
		level_effects = {1: {urban_move_bonus = 20, slot_weapon_type = 5}, 2: {urban_move_bonus = 26, slot_weapon_type = 5}, 3: {urban_move_bonus = 34, slot_weapon_type = 5}},
		unlock_conditions = {required_level = 2}
	},
	"rec_10_medkit" = {
		id = REC_10_MEDKIT, name = "急救包", name_en = "Medical Kit",
		icon = "res://assets/ui/icons/mod_icons/rec_10_medkit.png",
		prototype = "IFAK", description = "急救包随行。濒死时回复 15% 生命值。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 120, cost_install = 60,
		slot_type = "medical", conflict_group = "medical",
		effects = {ifak_revive = 0.15},  # v7.x 第二批：修复为濒死复活（原 ifak_heal 误为 hp_regen）
		level_effects = {1: {ifak_revive = 0.15}, 2: {ifak_revive = 0.195}, 3: {ifak_revive = 0.255}},
		unlock_conditions = {required_level = 2}
	},
	"rec_11_decoy" = {
		id = REC_11_DECOY, name = "假目标", name_en = "Decoy",
		icon = "res://assets/ui/icons/mod_icons/rec_11_decoy.png",
		prototype = "充气坦克/假人", description = "充气假目标误导敌方。暴击率 +20%。",
		rarity = "rare",
	power_mult = 1.3, cost_research = 160, cost_install = 80,
		slot_type = "deception", conflict_group = "stealth",
		effects = {enemy_confusion = 0.20},
		level_effects = {1: {enemy_confusion = 0.2}, 2: {enemy_confusion = 0.26}, 3: {enemy_confusion = 0.34}},
		unlock_conditions = {required_level = 3}
	},
	"rec_12_atv" = {
		id = REC_12_ATV, name = "越野摩托", name_en = "All-Terrain Vehicle",
		icon = "res://assets/ui/icons/mod_icons/rec_12_atv.png",
		prototype = "侦察摩托", description = "越野摩托机动。部署加速 60%。",
		rarity = "uncommon",
	power_mult = 1.0, cost_research = 110, cost_install = 55,
		slot_type = "mobility", conflict_group = "mobility",
		effects = {move_speed = 30},
		level_effects = {1: {move_speed = 30}, 2: {move_speed = 39}, 3: {move_speed = 51}},
		unlock_conditions = {required_level = 2}
	},

	# ─── v7.x 新机制改造 ───

	# debuff 型：目标指示器（30% 标记 + 25% 易伤）
	"rec_13_target_designator" = {
		id = "rec_13_target_designator",
		name = "目标指示器",
		name_en = "Target Designator",
		icon = "res://assets/ui/icons/mod_icons/rec_13_target_designator.png",
		prototype = "SOFLAM 激光指示器",
		description = "激光标记目标：30% 概率标记，被标记目标受到 +25% 额外伤害，持续 5 秒",
		rarity = "epic",
		power_mult = 1.6,
		cost_research = 320,
		cost_install = 160,
		slot_type = "guidance",
		conflict_group = "guidance",
		era_band = [3, 4],
		effects = {target_marking = 0.30, mark_vuln = 0.25, mark_duration = 5.0},
		level_effects = {1: {target_marking = 0.3, mark_vuln = 0.25, mark_duration = 5}, 2: {target_marking = 0.39, mark_vuln = 0.325, mark_duration = 6.5}, 3: {target_marking = 0.51, mark_vuln = 0.425, mark_duration = 8.5}},
		unlock_conditions = {required_level = 5}
	},

	# debuff 型：暴击指示器（30% 暴击标注 + 暴击率+50%，全队远程优先集火）
	"rec_14_crit_designator" = {
		id = "rec_14_crit_designator",
		name = "暴击指示器",
		name_en = "Crit Designator",
		icon = "res://assets/ui/icons/mod_icons/rec_14_crit_designator.png",
		prototype = "精确标定仪",
		description = "攻击命中 30% 概率挂暴击标注。被标注目标受攻击时暴击率 +50%，持续 5 秒，全队远程优先集火。",
		rarity = "epic",
		power_mult = 1.6,
		cost_research = 320,
		cost_install = 160,
		slot_type = "guidance",
		conflict_group = "designator",
		era_band = [3, 4],
		effects = {crit_mark_chance = 0.30, crit_mark_bonus = 0.50, crit_mark_duration = 5.0},
		level_effects = {1: {crit_mark_chance = 0.3, crit_mark_bonus = 0.5, crit_mark_duration = 5}, 2: {crit_mark_chance = 0.39, crit_mark_bonus = 0.6, crit_mark_duration = 6.5}, 3: {crit_mark_chance = 0.51, crit_mark_bonus = 0.6, crit_mark_duration = 8.5}},
		unlock_conditions = {required_level = 5}
	},

	# ==================== v9.1 组合技套路配套改造（1 个） ====================
	# 套路5 侦察链式：相控阵雷达（周期性挂 _radar_locked 标记）
	"rec_phased_radar" = {
		id = "rec_phased_radar",
		name = "相控阵雷达",
		name_en = "Phased Array Radar",
		icon = "res://assets/ui/icons/mod_icons/rec_phased_radar.png",
		prototype = "AN/APG-81 相控阵",
		description = "周期扫描锁定敌方高威胁单位，雷达锁定易伤 +15%。与无人机标记叠加触发集火链式。侦察链式触发器。代价：雷达组占重，生命 -10%。",
		rarity = "legendary",
		keystone = true,
		power_mult = 1.7,
		cost_research = 380,
		cost_install = 190,
		slot_type = "sensor",
		conflict_group = "sensor",
		era_band = [3, 4],
		effects = {radar_lock_interval = 12.0, radar_lock_radius = 400.0, radar_lock_vuln = 0.15, radar_lock_duration = 8.0, crit_chance = 0.05, max_hp = -0.1 },
		level_effects = {1: {radar_lock_interval = 12, radar_lock_radius = 400, radar_lock_vuln = 0.15, radar_lock_duration = 8, crit_chance = 0.05, max_hp = -0.1 }, 2: {radar_lock_interval = 15.6, radar_lock_radius = 520, radar_lock_vuln = 0.195, radar_lock_duration = 10.4, crit_chance = 0.065, max_hp = -0.1 }, 3: {radar_lock_interval = 20.4, radar_lock_radius = 680, radar_lock_vuln = 0.255, radar_lock_duration = 13.6, crit_chance = 0.085, max_hp = -0.1 }},
		unlock_conditions = {required_level = 6}
	},

	# ══════════ v27 改造2.0 批：普及档 + 标记系统强化 ══════════
	"rec_15_field_binoculars" = {
		id = "rec_15_field_binoculars",
		name = "野战双筒镜",
		name_en = "Field Binoculars",
		icon = "res://assets/ui/icons/mod_icons/rec_15_field_binoculars.png",
		prototype = "制式观测双筒镜",
		description = "观瞄升级：射程 +15，暴击率 +2%（升级后射程与暴击进一步提升）。",
		rarity = "common",
		power_mult = 0.8,
		cost_research = 50,
		cost_install = 25,
		slot_type = "optics",
		conflict_group = "optics",
		effects = {attack_range = 15, crit_chance = 0.02},
		level_effects = {1: {attack_range = 15, crit_chance = 0.02}, 2: {attack_range = 20, crit_chance = 0.03}, 3: {attack_range = 26, crit_chance = 0.04}},
		unlock_conditions = {required_level = 1}
	},
	"rec_16_silent_boots" = {
		id = "rec_16_silent_boots",
		name = "静音靴",
		name_en = "Silent Boots",
		icon = "res://assets/ui/icons/mod_icons/rec_16_silent_boots.png",
		prototype = "消音胶底靴",
		description = "消音机动。闪避 +6%。",
		rarity = "uncommon",
		power_mult = 1.0,
		cost_research = 90,
		cost_install = 45,
		slot_type = "stealth",
		conflict_group = "stealth",
		effects = {dodge_chance = 0.06},
		level_effects = {1: {dodge_chance = 0.06}, 2: {dodge_chance = 0.08}, 3: {dodge_chance = 0.10}},
		unlock_conditions = {required_level = 1}
	},
	"rec_17_multiband_sensor" = {
		id = "rec_17_multiband_sensor",
		name = "多光谱传感",
		name_en = "Multiband Sensor",
		icon = "res://assets/ui/icons/mod_icons/rec_17_multiband_sensor.png",
		prototype = "多频段传感融合",
		description = "多光谱穿透遮蔽。暴击率 +6%，无视烟雾。",
		rarity = "rare",
		power_mult = 1.3,
		cost_research = 160,
		cost_install = 80,
		slot_type = "sensor",
		conflict_group = "sensor",
		effects = {crit_chance = 0.06, smoke_ignore = true},
		level_effects = {1: {crit_chance = 0.06, smoke_ignore = true}, 2: {crit_chance = 0.08, smoke_ignore = true}, 3: {crit_chance = 0.10, smoke_ignore = true}},
		unlock_conditions = {required_level = 3}
	},
	"rec_18_target_database" = {
		id = "rec_18_target_database",
		name = "目标数据库",
		name_en = "Target Database",
		icon = "res://assets/ui/icons/mod_icons/rec_18_target_database.png",
		prototype = "威胁特征库",
		description = "特征比对快速标记。命中 30% 概率标记目标，被标记者受伤 +15%。",
		rarity = "epic",
		power_mult = 1.5,
		cost_research = 300,
		cost_install = 150,
		slot_type = "system",
		conflict_group = "system",
		effects = {target_marking = 0.30, mark_vuln = 0.15},
		level_effects = {1: {target_marking = 0.30, mark_vuln = 0.15}, 2: {target_marking = 0.39, mark_vuln = 0.20}, 3: {target_marking = 0.51, mark_vuln = 0.26}},
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
