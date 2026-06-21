extends RefCounted
class_name InfantryModifications
## 步兵改造模块定义（22个）
## 每个改造映射到真实军事技术，影响9字段攻击防御体系

## ─────────────────────────────────────────────
##  改造ID常量
## ─────────────────────────────────────────────

const INF_01_SUBMACHINE_GUN = "inf_01_submachine_gun"
const INF_02_ASSAULT_RIFLE = "inf_02_assault_rifle"
const INF_03_SMALL_CALIBER = "inf_03_small_caliber"
const INF_04_BULLPUP = "inf_04_bullpup"
const INF_05_AP_AMMO = "inf_05_ap_ammo"
const INF_06_HP_AMMO = "inf_06_hp_ammo"
const INF_07_OPTICAL_SCOPE = "inf_07_optical_scope"
const INF_08_HOLOGRAPHIC = "inf_08_holographic"
const INF_09_DUAL_MAG = "inf_09_dual_mag"
const INF_10_SAW = "inf_10_saw"
const INF_11_ARMOR_INSERT = "inf_11_armor_insert"
const INF_12_BODY_ARMOR = "inf_12_body_armor"
const INF_13_HELMET_UPGRADE = "inf_13_helmet_upgrade"
const INF_14_KNEE_PADS = "inf_14_knee_pads"
const INF_15_RIOT_SHIELD = "inf_15_riot_shield"
const INF_16_EXOSKELETON = "inf_16_exoskeleton"
const INF_17_TOURNIQUET = "inf_17_tourniquet"
const INF_18_IFAK = "inf_18_ifak"
const INF_19_RADIO = "inf_19_radio"
const INF_20_NIGHT_VISION = "inf_20_night_vision"
const INF_21_THERMAL = "inf_21_thermal"
const INF_22_BREACHING = "inf_22_breaching"

## ─────────────────────────────────────────────
##  改造数据表
## ─────────────────────────────────────────────

const DATA: Dictionary = {
	# ─── 武器改造（影响攻击属性）───────────
	"inf_01_submachine_gun" = {
		id = INF_01_SUBMACHINE_GUN,
		name = "冲锋枪改装",
		name_en = "Submachine Gun Conversion",
		prototype = "MP18/汤普森",
		description = "缩短枪管+大容量弹鼓，提升近战压制能力",
		icon = "res://assets/ui/icons/mod_icons/mod_weapon.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 100,
		cost_install = 50,
		slot_type = "weapon",
		conflict_group = "fire_rate",
		effects = {
			attack_interval = -0.15,  # -15%
			weapon_type = 5,  # v6.5 SHOTGUN spread
		},
		unlock_conditions = {
			required_level = 1,
		}
	},

	"inf_02_assault_rifle" = {
		id = INF_02_ASSAULT_RIFLE,
		name = "突击步枪化",
		name_en = "Assault Rifle Conversion",
		prototype = "STG44",
		description = "中间威力弹革命，火力与机动性平衡",
		icon = "res://assets/ui/icons/mod_icons/mod_weapon.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 120,
		cost_install = 60,
		slot_type = "weapon",
		conflict_group = "damage",
		effects = {
			attack_light = 0.15,  # +15%
			weapon_type = 0,  # v6.5 DIRECT
		},
		unlock_conditions = {
			required_level = 2,
		}
	},

	"inf_03_small_caliber" = {
		id = INF_03_SMALL_CALIBER,
		name = "小口径化",
		name_en = "Small Caliber Conversion",
		prototype = "M16/5.56mm",
		description = "携弹量翻倍，持续作战能力提升",
		icon = "res://assets/ui/icons/mod_icons/mod_weapon.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 150,
		cost_install = 75,
		slot_type = "weapon",
		conflict_group = "damage",
		effects = {
			attack_light = 0.12,
			attack_interval = -0.05,
		},
		unlock_conditions = {
			required_level = 3,
		}
	},

	"inf_04_bullpup" = {
		id = INF_04_BULLPUP,
		name = "无托结构",
		name_en = "Bullpup Configuration",
		prototype = "AUG/法玛斯",
		description = "枪机后置，全长缩短，机动性提升",
		icon = "res://assets/ui/icons/mod_icons/mod_weapon.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 130,
		cost_install = 65,
		slot_type = "weapon",
		conflict_group = "ergonomics",
		effects = {
			attack_range = 20,  # +20px
			deploy_speed = 1,   # +1
		},
		unlock_conditions = {
			required_level = 3,
		}
	},

	"inf_05_ap_ammo" = {
		id = INF_05_AP_AMMO,
		name = "穿甲弹",
		name_en = "Armor-Piercing Ammunition",
		prototype = "M993钨芯弹",
		description = "钨芯穿透弹头，专为应对现代复合装甲设计",
		icon = "res://assets/ui/icons/mod_icons/mod_ammunition.png",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 200,
		cost_install = 100,
		slot_type = "ammunition",
		conflict_group = "ammunition",
		effects = {
			attack_armor = 0.25,   # +25%
			attack_light = -0.10,   # -10% 副作用
		},
		unlock_conditions = {
			required_level = 3,
		}
	},

	"inf_06_hp_ammo" = {
		id = INF_06_HP_AMMO,
		name = "空尖弹",
		name_en = "Hollow-Point Ammunition",
		prototype = ".45 ACP HP",
		description = "扩张弹头，对软组织目标停止作用极强",
		icon = "res://assets/ui/icons/mod_icons/mod_ammunition.png",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 200,
		cost_install = 100,
		slot_type = "ammunition",
		conflict_group = "ammunition",
		effects = {
			attack_light = 0.25,   # +25%
			attack_armor = -0.10,  # -10% 副作用
		},
		unlock_conditions = {
			required_level = 3,
		}
	},

	"inf_07_optical_scope" = {
		id = INF_07_OPTICAL_SCOPE,
		name = "光学瞄准镜",
		name_en = "Optical Scope",
		prototype = "ACOG 4倍镜",
		description = "提高中距离命中率和有效射程",
		icon = "res://assets/ui/icons/mod_icons/mod_optics.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 140,
		cost_install = 70,
		slot_type = "optics",
		conflict_group = "optics",
		effects = {
			attack_range = 30,     # +30px
			crit_chance = 0.05,   # +5%
		},
		unlock_conditions = {
			required_level = 2,
		}
	},

	"inf_08_holographic" = {
		id = INF_08_HOLOGRAPHIC,
		name = "全息瞄准镜",
		name_en = "Holographic Sight",
		prototype = "EOTech",
		description = "近战快速瞄准，反应速度提升",
		icon = "res://assets/ui/icons/mod_icons/mod_optics.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 130,
		cost_install = 65,
		slot_type = "optics",
		conflict_group = "optics",
		effects = {
			attack_interval = -0.08,  # -8%
			dodge_chance = 0.03,      # +3%
		},
		unlock_conditions = {
			required_level = 2,
		}
	},

	"inf_09_dual_mag" = {
		id = INF_09_DUAL_MAG,
		name = "双弹匣并联",
		name_en = "Dual Magazines",
		prototype = "丛林弹匣扣",
		description = "换弹时间减半，持续火力压制",
		icon = "res://assets/ui/icons/mod_icons/mod_ergonomics.png",
		rarity = "uncommon",
	power_mult = 1.0,
		cost_research = 80,
		cost_install = 40,
		slot_type = "ergonomics",
		conflict_group = "ergonomics",
		effects = {
			attack_interval = -0.10,  # -10%
		},
		unlock_conditions = {
			required_level = 1,
		}
	},

	"inf_10_saw" = {
		id = INF_10_SAW,
		name = "班用机枪化",
		name_en = "Squad Automatic Weapon",
		prototype = "M249 SAW",
		description = "弹链供弹，持续压制火力",
		icon = "res://assets/ui/icons/mod_icons/mod_weapon.png",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 250,
		cost_install = 125,
		slot_type = "weapon",
		conflict_group = "fire_rate",
		effects = {
			attack_light = 0.20,      # +20%
			move_speed = -10,         # -10px/s 副作用
		},
		unlock_conditions = {
			required_level = 4,
		}
	},

	# ─── 防护改造（影响防御属性 + HP）────────
	"inf_11_armor_insert" = {
		id = INF_11_ARMOR_INSERT,
		name = "防弹插板",
		name_en = "Armor Insert",
		prototype = "ESAPI碳化硼板",
		description = "抵御步枪弹直射，防护力显著提升",
		icon = "res://assets/ui/icons/mod_icons/mod_armor.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 160,
		cost_install = 80,
		slot_type = "armor",
		conflict_group = "armor",
		effects = {
			max_hp = 0.20,          # +20%
			defense_light = 0.15,    # +15%
		},
		unlock_conditions = {
			required_level = 2,
		}
	},

	"inf_12_body_armor" = {
		id = INF_12_BODY_ARMOR,
		name = "防弹背心",
		name_en = "Body Armor",
		prototype = "IOTV模块化",
		description = "前后插板+侧甲，全方位防护",
		icon = "res://assets/ui/icons/mod_icons/mod_armor.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 180,
		cost_install = 90,
		slot_type = "armor",
		conflict_group = "armor",
		effects = {
			defense_armor = 0.15,   # +15%
			defense_light = 0.10,   # +10%
		},
		unlock_conditions = {
			required_level = 3,
		}
	},

	"inf_13_helmet_upgrade" = {
		id = INF_13_HELMET_UPGRADE,
		name = "头盔升级",
		name_en = "Helmet Upgrade",
		prototype = "MICH 2000→FAST",
		description = "复合材料+附件接口，防护与兼容性提升",
		icon = "res://assets/ui/icons/mod_icons/mod_helmet.png",
		rarity = "uncommon",
	power_mult = 1.0,
		cost_research = 100,
		cost_install = 50,
		slot_type = "helmet",
		conflict_group = "helmet",
		effects = {
			crit_resist = 0.10,     # +10% 暴击抗性
			dodge_chance = 0.03,    # +3%
		},
		unlock_conditions = {
			required_level = 1,
		}
	},

	"inf_14_knee_pads" = {
		id = INF_14_KNEE_PADS,
		name = "护膝护肘",
		name_en = "Knee and Elbow Pads",
		prototype = "战斗服内置护具",
		description = "减少地形减速，机动性微升",
		icon = "res://assets/ui/icons/mod_icons/mod_mobility.png",
		rarity = "common",
	power_mult = 0.8,
		cost_research = 50,
		cost_install = 25,
		slot_type = "mobility",
		conflict_group = "mobility",
		effects = {
			# 特殊：减少减速惩罚，实际体现为移动速度+5
			move_speed = 5,         # +5px/s
		},
		unlock_conditions = {
			required_level = 1,
		}
	},

	"inf_15_riot_shield" = {
		id = INF_15_RIOT_SHIELD,
		name = "防弹盾牌",
		name_en = "Riot Shield",
		prototype = "防弹盾（凯夫拉）",
		description = "移动掩体，防护力大幅提升",
		icon = "res://assets/ui/icons/mod_icons/mod_shield.png",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 220,
		cost_install = 110,
		slot_type = "shield",
		conflict_group = "shield",
		effects = {
			defense_light = 0.40,    # +40%
			move_speed = -20,        # -20px/s 副作用
		},
		unlock_conditions = {
			required_level = 4,
		}
	},

	# ─── 战术/特殊改造 ───────────────────
	"inf_16_exoskeleton" = {
		id = INF_16_EXOSKELETON,
		name = "外骨骼原型",
		name_en = "Exoskeleton Prototype",
		prototype = "HULC/XOS 2",
		description = "负重翻倍，机动性和部署速度提升",
		icon = "res://assets/ui/icons/mod_icons/mod_exoskeleton.png",
		rarity = "legendary",
	power_mult = 2.0,
		cost_research = 400,
		cost_install = 200,
		slot_type = "exoskeleton",
		conflict_group = "exoskeleton",
		effects = {
			move_speed = 15,        # +15px/s
			deploy_speed = 1,       # +1
		},
		unlock_conditions = {
			required_level = 6,
		}
	},

	"inf_17_tourniquet" = {
		id = INF_17_TOURNIQUET,
		name = "止血带",
		name_en = "Tourniquet",
		prototype = "CAT止血带",
		description = "四肢大出血控制，战斗内缓慢回复",
		icon = "res://assets/ui/icons/mod_icons/mod_medical.png",
		rarity = "uncommon",
	power_mult = 1.0,
		cost_research = 60,
		cost_install = 30,
		slot_type = "medical",
		conflict_group = "medical",
		effects = {
			hp_regen = 0.003,      # +0.3%/s
		},
		unlock_conditions = {
			required_level = 1,
		}
	},

	"inf_18_ifak" = {
		id = INF_18_IFAK,
		name = "战场急救包",
		name_en = "Individual First Aid Kit",
		prototype = "IFAK单兵急救",
		description = "止血+气道管理，濒死时回复15%HP（每战1次）",
		icon = "res://assets/ui/icons/mod_icons/mod_medical.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 120,
		cost_install = 60,
		slot_type = "medical",
		conflict_group = "medical",
		effects = {
			# 特殊效果：生命低于30%时回复15%HP
			ifak_heal = 0.15,
		},
		unlock_conditions = {
			required_level = 2,
		}
	},

	"inf_19_radio" = {
		id = INF_19_RADIO,
		name = "单兵电台",
		name_en = "Personal Radio",
		prototype = "PRC-152",
		description = "战术通讯，可呼叫支援并提升周围友军命中",
		icon = "res://assets/ui/icons/mod_icons/mod_comms.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 140,
		cost_install = 70,
		slot_type = "comms",
		conflict_group = "comms",
		effects = {
			attack_interval = -0.05,  # -5% 呼叫支援
			ally_bonus = 0.03,        # 周围友军+3%命中
		},
		unlock_conditions = {
			required_level = 3,
		}
	},

	"inf_20_night_vision" = {
		id = INF_20_NIGHT_VISION,
		name = "夜视仪",
		name_en = "Night Vision Goggles",
		prototype = "PVS-14",
		description = "微光夜视，夜间/黑暗地形战斗力提升",
		icon = "res://assets/ui/icons/mod_icons/mod_optics.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 160,
		cost_install = 80,
		slot_type = "optics",
		conflict_group = "optics",
		effects = {
			# 特殊：夜间/黑暗地形 attack_light +15%
			night_bonus = 0.15,
		},
		unlock_conditions = {
			required_level = 3,
		}
	},

	"inf_21_thermal" = {
		id = INF_21_THERMAL,
		name = "热成像",
		name_en = "Thermal Imaging",
		prototype = "AN/PAS-13",
		description = "穿透烟雾/植被，无视环境遮蔽",
		icon = "res://assets/ui/icons/mod_icons/mod_optics.png",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 240,
		cost_install = 120,
		slot_type = "optics",
		conflict_group = "optics",
		effects = {
			smoke_ignore = true,     # 无视烟雾
			crit_chance = 0.08,       # +8%
		},
		unlock_conditions = {
			required_level = 5,
		}
	},

	"inf_22_breaching" = {
		id = INF_22_BREACHING,
		name = "破门工具",
		name_en = "Breaching Tools",
		prototype = "霰弹枪/破门锤",
		description = "城市战突入专用，地形适应性提升",
		icon = "res://assets/ui/icons/mod_icons/mod_environment.png",
		rarity = "uncommon",
	power_mult = 1.0,
		cost_research = 70,
		cost_install = 35,
		slot_type = "environment",
		conflict_group = "environment",
		effects = {
			# 特殊：城市地形 move_speed +10px/s, attack_interval -5%
			urban_move_bonus = 10,
			urban_attack_bonus = -0.05,
		},
		unlock_conditions = {
			required_level = 2,
		}
	},
}

## ─────────────────────────────────────────────
##  查询接口
## ─────────────────────────────────────────────

## 获取改造数据
static func get_mod_data(mod_id: String) -> Dictionary:
	if DATA.has(mod_id):
		return DATA[mod_id].duplicate(true)
	return {}

## 获取所有改造ID列表
static func get_all_mod_ids() -> Array:
	return DATA.keys()

## 获取步兵可用改造（按兵种过滤）
static func get_for_unit_type(unit_type: int) -> Array:
	if unit_type == 0:  # LIGHT
		return DATA.keys()
	return []
## 检查冲突
static func check_conflict(mod_id_a: String, mod_id_b: String) -> bool:
	var data_a = get_mod_data(mod_id_a)
	var data_b = get_mod_data(mod_id_b)
	var group_a = data_a.get("conflict_group", "")
	var group_b = data_b.get("conflict_group", "")
	return group_a != "" and group_a == group_b

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

const _CARD_PREFIXES: Array = ["ww1_mp18", "ww1_mauser", "ww1_enfield", "ww1_storm", "ww1_flame", "ww2_thompson", "ww2_garand", "ww2_mp40", "ww2_ppsh", "ww2_panzerschrek", "ww2_bazooka", "cold_ak47", "cold_m14", "cold_m60", "cold_rpk", "cold_rpg", "mod_marine", "mod_technical", "mod_hummer_m2", "mod_hummer_tow", "fut_cyborg", "fut_heavy_trooper", "fut_scout_mech"]
