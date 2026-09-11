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
		description = "缩短枪管，换大容量弹鼓。近战压制火力提升。",
		icon = "res://assets/ui/icons/mod_icons/mod_weapon.png",
		rarity = "rare",
	power_mult = 1.3,
	cost_research = 100,
	cost_install = 50,
	slot_type = "weapon",
	conflict_group = "fire_rate",
	# v7.x: per-slot 弹道——对轻装槽改 SHOTGUN 散射弹道
	condition_slot = 0,
	era_band = [0, 1],
	effects = {
		attack_interval = -0.15,  # -15%
		weapon_type = 5,  # v6.5 SHOTGUN spread（单位级默认）
		slot_weapon_type = 5,  # v7.x: 对轻装槽散射化
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
		description = "中间威力弹药革命。火力与机动自此平衡。",
		icon = "res://assets/ui/icons/mod_icons/mod_weapon.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 120,
		cost_install = 60,
	slot_type = "weapon",
	conflict_group = "damage",
	# v7.x: per-slot 弹道——对轻装槽改 DIRECT 直射
	condition_slot = 0,
	# v22 替换通道试点：换装=确定攻击力。attack_light_set 以二战基准声明（≈卡池
	# 二战对轻中位 71 的 1.3 倍），装到低于该值的卡上直接替换为新值（"老卡换新枪"
	# 语义）；高于该值的卡不生效（更优才生效守卫）。时代带 [1,2]：突击步枪是
	# 二战~冷战科技，现代/未来步枪本就以突击步枪为基础，无可换装对象。
	era_band = [1, 2],
	effects = {
		attack_light_set = 90,  # 替换为 90（二战基准；era2 宿主自动缩放为 135）
		weapon_type = 0,  # v6.5 DIRECT（单位级默认）
		slot_weapon_type = 0,  # v7.x: 对轻装槽直射化
	},
	level_effects = {1: {attack_light_set = 90, weapon_type = 0, slot_weapon_type = 0}, 2: {attack_light_set = 105, weapon_type = 0, slot_weapon_type = 0}, 3: {attack_light_set = 120, weapon_type = 0, slot_weapon_type = 0}},
	unlock_conditions = {
		required_level = 2,
	}
},

	"inf_03_small_caliber" = {
		id = INF_03_SMALL_CALIBER,
		name = "小口径化",
		name_en = "Small Caliber Conversion",
		prototype = "M16/5.56mm",
		description = "小口径弹药，携弹量翻倍。持续作战能力提升。",
		icon = "res://assets/ui/icons/mod_icons/mod_weapon.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 150,
		cost_install = 75,
		slot_type = "weapon",
		conflict_group = "damage",
		era_band = [2, 4],
		effects = {
			attack_light = 7,
			attack_interval = -0.05,
		},
		level_effects = {1: {attack_light = 7, attack_interval = -0.05}, 2: {attack_light = 12, attack_interval = -0.05}, 3: {attack_light = 16, attack_interval = -0.05}},
		unlock_conditions = {
			required_level = 3,
		}
	},

	"inf_04_bullpup" = {
		id = INF_04_BULLPUP,
		name = "无托结构",
		name_en = "Bullpup Configuration",
		prototype = "AUG/法玛斯",
		description = "枪机后置，全枪缩短。机动性提升。",
		icon = "res://assets/ui/icons/mod_icons/mod_weapon.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 130,
		cost_install = 65,
		slot_type = "weapon",
		conflict_group = "ergonomics",
		era_band = [3, 4],
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
		description = "钨芯穿甲弹头。步兵由此获得反装甲火力。",
		icon = "res://assets/ui/icons/mod_icons/mod_ammunition.png",
		rarity = "epic",
	power_mult = 1.6,
	cost_research = 200,
	cost_install = 100,
	slot_type = "ammunition",
	conflict_group = "ammunition",
	# v7.x: per-slot 弹道——对装甲槽 SNIPER 穿甲（grant_slot 已激活槽位，此处补 slot_weapon_type 双保险）
	condition_slot = 1,
	effects = {
		attack_light = -0.10,   # -10% 副作用（穿甲弹对软目标效果差）
		slot_weapon_type = 6,  # v7.x: 对装甲槽穿甲弹道（SNIPER）
	},
	# v6.13: grant_slot 激活对装甲武器槽（修复原 attack_armor=0.25 对步枪兵 base=0 失效的 bug）
	# 步枪兵装穿甲弹 → 获得对装甲能力（反坦克步枪语义）
	# 以 attack_light 为基准派生对装甲伤害，反器材步枪式射速
	# v9.x 修复：原 ratio 0.5×speed 0.67 的派生对装甲 DPS（≈0.34×基准）低于白板对装甲槽
	# （mp18: 14.5×0.67≈9.7 < 白板 15×1.0=15），加上对轻装 -10% 副作用 → 典型卡净负、装了变弱。
	# ratio 0.8 + speed 1.0 后派生 DPS ≈ 0.8×基准，明确高于白板槽位，与 epic 弹药定位相符
	# （mod_marine 基准140 → 对装甲112，接近专用反坦克组 panzerschrek 90/javelin 250 的下半区）。
	grant_slot = {
		slot = 1,                      # 对装甲槽位（0=轻装, 1=装甲, 2=对空）
		base_damage = "attack_light",  # 基准字段：载体单位的对轻装伤害（步枪主火力）
		damage_ratio = 0.8,            # 基准 × 此系数 = 对装甲基础伤害
		speed = 1.0,                   # 攻速（次/秒，反器材步枪式）
		windup = 0.3,                  # 前摇（秒）
		active = 0.15,                 # 动作（秒）
		weapon_type = 6,               # SNIPER（旧型号6，穿甲弹道）
		range_value = 3,               # 射程（格，与步枪一致）
		display_name = "穿甲弹",
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
		description = "弹头扩张变形。对软组织目标停止作用强。",
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
		description = "光学瞄准镜。中距离命中率与有效射程提升。",
		icon = "res://assets/ui/icons/mod_icons/mod_optics.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 140,
		cost_install = 70,
	slot_type = "optics",
	conflict_group = "optics",
	# v22 时代带：机械/光电瞄准镜是一战~现代科技；近未来激光武器自带集成火控，
	# 外挂光学镜无意义（全息/热成像归 inf_08/inf_21 谱系）。true_damage 为攻击族
	# flat，按宿主时代自动缩放（ref_era=0 基准声明）。
	era_band = [0, 3],
	effects = {
		attack_range = 30,     # +30px
		crit_chance = 0.05,   # +5%
		true_damage = 8,      # v8.6: 补真实伤害（瞄准镜=精准命中要害）
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
		description = "全息视窗快速瞄准。近战反应提升。",
		icon = "res://assets/ui/icons/mod_icons/mod_optics.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 130,
		cost_install = 65,
	slot_type = "optics",
	conflict_group = "optics",
	# v22 时代带：全息瞄具是现代科技（与光学镜 inf_07 [0,3] 分谱系）
	era_band = [3, 4],
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
		description = "弹匣并联。换弹时间减半，火力压制不中断。",
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
		description = "弹链供弹。压制火力持续输出。",
		icon = "res://assets/ui/icons/mod_icons/mod_weapon.png",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 250,
		cost_install = 125,
	slot_type = "weapon",
	conflict_group = "fire_rate",
	# v7.x: per-slot 弹道——对轻装槽改 MG(2) 机枪压制弹道
	condition_slot = 0,
	era_band = [2, 4],
	effects = {
		attack_light = 0.20,      # +20%
		move_speed = -10,         # -10px/s 副作用
		slot_weapon_type = 2,     # v7.x: 对轻装槽机枪化（MG）
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
		description = "硬质插板抵御步枪弹直射。防护力显著提升。",
		icon = "res://assets/ui/icons/mod_icons/mod_armor.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 160,
		cost_install = 80,
		slot_type = "armor",
		conflict_group = "armor",
		era_band = [2, 4],
		effects = {
			max_hp = 60,
			defense_light = 15,
		},
		level_effects = {1: {max_hp = 60, defense_light = 15}, 2: {max_hp = 100, defense_light = 26}, 3: {max_hp = 145, defense_light = 38}},
		unlock_conditions = {
			required_level = 2,
		}
	},

	"inf_12_body_armor" = {
		id = INF_12_BODY_ARMOR,
		name = "防弹背心",
		name_en = "Body Armor",
		prototype = "IOTV模块化",
		description = "前后插板，加挂侧甲。全方位防护。",
		icon = "res://assets/ui/icons/mod_icons/mod_armor.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 180,
		cost_install = 90,
		slot_type = "armor",
		conflict_group = "armor",
		era_band = [2, 4],
		effects = {
			defense_armor = 15,
			defense_light = 10,
		},
		level_effects = {1: {defense_armor = 15, defense_light = 10}, 2: {defense_armor = 26, defense_light = 18}, 3: {defense_armor = 38, defense_light = 25}},
		unlock_conditions = {
			required_level = 3,
		}
	},

	"inf_13_helmet_upgrade" = {
		id = INF_13_HELMET_UPGRADE,
		name = "头盔升级",
		name_en = "Helmet Upgrade",
		prototype = "MICH 2000→FAST",
		description = "复合材料盔体，附件接口标准化。防护与兼容性提升。",
		icon = "res://assets/ui/icons/mod_icons/mod_helmet.png",
		rarity = "uncommon",
	power_mult = 1.0,
		cost_research = 100,
		cost_install = 50,
		slot_type = "helmet",
		conflict_group = "helmet",
		era_band = [3, 4],
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
		description = "护具内衬减负。部署加速 10%。",
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
		description = "随行移动掩体。防护力大幅提升。",
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
		level_effects = {1: {defense_light = 0.4, move_speed = -20}, 2: {defense_light = 0.52, move_speed = -20}, 3: {defense_light = 0.6, move_speed = -20}},
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
		description = "液压外骨骼。负重翻倍，机动与部署速度提升。",
		icon = "res://assets/ui/icons/mod_icons/mod_exoskeleton.png",
		rarity = "legendary",
	power_mult = 2.0,
		cost_research = 400,
		cost_install = 200,
		slot_type = "exoskeleton",
		conflict_group = "exoskeleton",
		era_band = [3, 4],
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
		description = "四肢止血带。控制大出血，战斗内缓慢回复。",
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
		description = "止血与气道管理。濒死时回复 15% 生命值（每战 1 次）。",
		icon = "res://assets/ui/icons/mod_icons/mod_medical.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 120,
		cost_install = 60,
		slot_type = "medical",
		conflict_group = "medical",
		effects = {
			# v7.x 第二批：修复语义错配——原 ifak_heal 误映射为 hp_regen，改为真正的濒死复活
			ifak_revive = 0.15,
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
		description = "单兵战术电台。自身攻速 +5%，周围友军攻击力 +3%。",
		icon = "res://assets/ui/icons/mod_icons/mod_comms.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 140,
		cost_install = 70,
		slot_type = "comms",
		conflict_group = "comms",
		era_band = [1, 4],
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
		description = "微光夜视瞄准。暴击率 +15%。",
		icon = "res://assets/ui/icons/mod_icons/mod_optics.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 160,
		cost_install = 80,
		slot_type = "optics",
		conflict_group = "optics",
		era_band = [2, 4],
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
		description = "热成像瞄准。暴击率 +23%。",
		icon = "res://assets/ui/icons/mod_icons/mod_optics.png",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 240,
		cost_install = 120,
		slot_type = "optics",
		conflict_group = "optics",
		era_band = [3, 4],
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
		description = "破门装备。部署加速 20%，对轻装伤害 -5%。",
		icon = "res://assets/ui/icons/mod_icons/mod_engineering.png",
		rarity = "uncommon",
	power_mult = 1.0,
		cost_research = 70,
		cost_install = 35,
		slot_type = "environment",
		conflict_group = "environment",
		effects = {
			# v7.5: urban_move_bonus 重定向为部署延迟减少（原 move_speed 死字段）
			urban_move_bonus = 10,
			urban_attack_bonus = -0.05,
		},
		unlock_conditions = {
			required_level = 2,
		}
	},

	# ─── v7.x 新机制改造 ───

	# 连击型：战斗兴奋剂（攻击 5 次后爆发 +25% 伤害）
	"inf_23_combat_stimulant" = {
		id = "inf_23_combat_stimulant",
		name = "战斗兴奋剂",
		name_en = "Combat Stimulant",
		icon = "res://assets/ui/icons/mod_icons/mod_special.png",
		prototype = "肾上腺素自动注射器",
		description = "连续攻击积累战斗节奏，每 5 次命中触发爆发，额外造成 25% 伤害",
		rarity = "epic",
		power_mult = 1.5,
		cost_research = 280,
		cost_install = 140,
		slot_type = "special",
		conflict_group = "special",
		effects = {combo_system = 5, combo_bonus = 0.25},
		unlock_conditions = {required_level = 4}
	},

	# 兵种专属：巷战教范（受装甲/空军攻击减伤 50%）
	"inf_24_urban_warfare" = {
		id = "inf_24_urban_warfare",
		name = "巷战教范",
		name_en = "Urban Warfare Doctrine",
		icon = "res://assets/ui/icons/mod_icons/mod_special.png",
		prototype = "城市作战手册+反应装甲套件",
		description = "城市巷战训练。受到装甲与空军单位攻击时伤害减免 50%。",
		rarity = "epic",
		power_mult = 1.6,
		cost_research = 300,
		cost_install = 150,
		slot_type = "special",
		conflict_group = "special",
		effects = {urban_defense = 0.50},
		unlock_conditions = {required_level = 5}
	},

	# ─── v7.x 第二批：亡语治疗 ───
	"inf_25_medic_sacrifice" = {
		id = "inf_25_medic_sacrifice",
		name = "医疗兵牺牲",
		name_en = "Medic's Sacrifice",
		icon = "res://assets/ui/icons/mod_icons/mod_medical.png",
		prototype = "战场医疗兵遗言",
		description = "阵亡时治疗周围 200 像素内友军，恢复量为自身 20% 最大生命值。",
		rarity = "legendary",
		power_mult = 1.8,
		cost_research = 400,
		cost_install = 200,
		slot_type = "medical",
		conflict_group = "medical",
		effects = {death_heal = 0.20, death_heal_radius = 200.0},
		level_effects = {1: {death_heal = 0.2, death_heal_radius = 200}, 2: {death_heal = 0.26, death_heal_radius = 260}, 3: {death_heal = 0.34, death_heal_radius = 340}},
		unlock_conditions = {required_level = 6}
	},

	# ─── v8.6 现实/科幻伤害类型 ───
	"inf_26_chemical_warhead" = {
		id = "inf_26_chemical_warhead",
		name = "化学弹头",
		name_en = "Chemical Warhead",
		icon = "res://assets/ui/icons/mod_icons/mod_weapon.png",
		prototype = "芥子气/神经毒剂弹头",
		description = "攻击 35% 概率施加化学毒剂：每秒造成 8 点伤害，持续 6 秒（绿色毒雾）。",
		rarity = "epic",
		power_mult = 1.5,
		cost_research = 280,
		cost_install = 140,
		slot_type = "weapon",
		conflict_group = "special_ammo",
		effects = {chem_chance = 0.35, chem_dps = 8.0, chem_duration = 6.0},
		level_effects = {1: {chem_chance = 0.35, chem_dps = 8, chem_duration = 6}, 2: {chem_chance = 0.455, chem_dps = 10.4, chem_duration = 7.8}, 3: {chem_chance = 0.595, chem_dps = 13.6, chem_duration = 10.2}},
		applicable_types = [0, 1],
		unlock_conditions = {required_level = 4}
	},

	"inf_27_napalm" = {
		id = "inf_27_napalm",
		name = "凝固汽油弹",
		name_en = "Napalm Rounds",
		icon = "res://assets/ui/icons/mod_icons/mod_weapon.png",
		prototype = "M202 FLASH 燃烧火箭",
		description = "攻击 30% 概率引燃目标：每层每秒 6 点伤害，可叠至 5 层，持续 5 秒（橙色火苗）。",
		rarity = "epic",
		power_mult = 1.5,
		cost_research = 300,
		cost_install = 150,
		slot_type = "weapon",
		conflict_group = "special_ammo",
		era_band = [1, 4],
		effects = {burn_chance = 0.30, burn_dps = 6.0, burn_duration = 5.0},
		level_effects = {1: {burn_chance = 0.3, burn_dps = 6, burn_duration = 5}, 2: {burn_chance = 0.39, burn_dps = 7.8, burn_duration = 6.5}, 3: {burn_chance = 0.51, burn_dps = 10.2, burn_duration = 8.5}},
		applicable_types = [0],
		unlock_conditions = {required_level = 4}
	},

	# ══════════ v27 改造2.0 批：普及档补池 + 医疗链套装件 + 击杀触发 ══════════
	"inf_28_combat_boots" = {
		id = "inf_28_combat_boots",
		name = "战斗靴",
		name_en = "Combat Boots",
		icon = "res://assets/ui/icons/mod_icons/mod_mobility.png",
		prototype = "减负鞋垫/作战靴",
		description = "合脚战靴与减负鞋垫。移动速度 +8。",
		rarity = "common",
		power_mult = 0.8,
		cost_research = 50,
		cost_install = 25,
		slot_type = "mobility",
		conflict_group = "mobility",
		effects = {move_speed = 8},
		level_effects = {1: {move_speed = 8}, 2: {move_speed = 10}, 3: {move_speed = 14}},
		unlock_conditions = {required_level = 1}
	},
	"inf_29_iron_sights" = {
		id = "inf_29_iron_sights",
		name = "机械瞄具",
		name_en = "Iron Sights",
		icon = "res://assets/ui/icons/mod_icons/mod_optics.png",
		prototype = "照门准星校射",
		description = "出厂瞄具精校。暴击率 +3%。",
		rarity = "common",
		power_mult = 0.8,
		cost_research = 50,
		cost_install = 25,
		slot_type = "optics",
		conflict_group = "optics",
		effects = {crit_chance = 0.03},
		level_effects = {1: {crit_chance = 0.03}, 2: {crit_chance = 0.04}, 3: {crit_chance = 0.05}},
		unlock_conditions = {required_level = 1}
	},
	"inf_30_load_vest" = {
		id = "inf_30_load_vest",
		name = "负重背心",
		name_en = "Load-Bearing Vest",
		icon = "res://assets/ui/icons/mod_icons/mod_ergonomics.png",
		prototype = "模块化负重背心",
		description = "载荷分布到躯干。生命 +25，部署加速。",
		rarity = "uncommon",
		power_mult = 1.0,
		cost_research = 90,
		cost_install = 45,
		slot_type = "ergonomics",
		conflict_group = "ergonomics",
		effects = {max_hp = 25, deploy_speed = 1},
		level_effects = {1: {max_hp = 25, deploy_speed = 1}, 2: {max_hp = 33, deploy_speed = 1}, 3: {max_hp = 43, deploy_speed = 1}},
		unlock_conditions = {required_level = 1}
	},
	"inf_31_flash_suppressor" = {
		id = "inf_31_flash_suppressor",
		name = "消焰器",
		name_en = "Flash Suppressor",
		icon = "res://assets/ui/icons/mod_icons/mod_weapon.png",
		prototype = "枪口消焰装置",
		description = "抑制枪口焰。射速 +6%，暴击率 +2%。",
		rarity = "uncommon",
		power_mult = 1.0,
		cost_research = 90,
		cost_install = 45,
		slot_type = "weapon",
		conflict_group = "fire_rate",
		effects = {attack_interval = -0.06, crit_chance = 0.02},
		level_effects = {1: {attack_interval = -0.06, crit_chance = 0.02}, 2: {attack_interval = -0.08, crit_chance = 0.02}, 3: {attack_interval = -0.10, crit_chance = 0.02}},
		unlock_conditions = {required_level = 2}
	},
	"inf_32_heavy_barrel" = {
		id = "inf_32_heavy_barrel",
		name = "重型枪管",
		name_en = "Heavy Barrel",
		icon = "res://assets/ui/icons/mod_icons/mod_weapon.png",
		prototype = "match 级重枪管",
		description = "重枪管抑制抖动。对轻装伤害 +12%，射程 +15px。",
		rarity = "rare",
		power_mult = 1.3,
		cost_research = 150,
		cost_install = 75,
		slot_type = "weapon",
		conflict_group = "damage",
		effects = {attack_light = 0.12, attack_range = 15},
		level_effects = {1: {attack_light = 0.12, attack_range = 15}, 2: {attack_light = 0.16, attack_range = 15}, 3: {attack_light = 0.20, attack_range = 15}},
		unlock_conditions = {required_level = 3}
	},
	"inf_33_ammo_belt" = {
		id = "inf_33_ammo_belt",
		name = "弹链供弹",
		name_en = "Ammo Belt Feed",
		icon = "res://assets/ui/icons/mod_icons/mod_ammunition.png",
		prototype = "散装弹链/帆布弹带",
		description = "弹链持续供弹。射速 +8%，移动 -5px/s。",
		rarity = "rare",
		power_mult = 1.3,
		cost_research = 150,
		cost_install = 75,
		slot_type = "ammunition",
		conflict_group = "ammunition",
		effects = {attack_interval = -0.08, move_speed = -5},
		level_effects = {1: {attack_interval = -0.08, move_speed = -5}, 2: {attack_interval = -0.10, move_speed = -5}, 3: {attack_interval = -0.12, move_speed = -5}},
		unlock_conditions = {required_level = 3}
	},
	# v27 触发式：击杀战地敷料（击杀 → 范围治疗友军）。消费点 module_effect_handler.on_unit_killed
	"inf_34_kill_field_dressing" = {
		id = "inf_34_kill_field_dressing",
		name = "击杀战地敷料",
		name_en = "Kill Field Dressing",
		icon = "res://assets/ui/icons/mod_icons/mod_medical.png",
		prototype = "战利品急救物资回收",
		description = "击杀敌方后立即为周围 170px 内友军敷伤：每名回复自身 6% 最大生命值。",
		rarity = "epic",
		power_mult = 1.5,
		cost_research = 280,
		cost_install = 140,
		slot_type = "medical",
		conflict_group = "medical",
		effects = {kill_pulse_heal = 0.06, kill_pulse_radius = 170.0},
		level_effects = {1: {kill_pulse_heal = 0.06, kill_pulse_radius = 170.0}, 2: {kill_pulse_heal = 0.08, kill_pulse_radius = 190.0}, 3: {kill_pulse_heal = 0.10, kill_pulse_radius = 210.0}},
		unlock_conditions = {required_level = 4}
	},
	# v27 野战医疗链套装第 4 件（inf_17/18/19 + 本条集齐满档）
	"inf_35_field_hospital" = {
		id = "inf_35_field_hospital",
		name = "野战医院",
		name_en = "Field Hospital",
		icon = "res://assets/ui/icons/mod_icons/mod_medical.png",
		prototype = "折叠式野战医院",
		description = "随军野战医院。周围友军持续回复 0.6%/s，自身生命 +10%。",
		rarity = "legendary",
		power_mult = 1.8,
		cost_research = 420,
		cost_install = 210,
		slot_type = "medical",
		conflict_group = "medical",
		effects = {ally_hp_regen = 0.006, max_hp = 0.10},
		level_effects = {1: {ally_hp_regen = 0.006, max_hp = 0.10}, 2: {ally_hp_regen = 0.008, max_hp = 0.13}, 3: {ally_hp_regen = 0.010, max_hp = 0.17}},
		unlock_conditions = {required_level = 6}
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
	# cold_m60(步兵机枪) 与 cold_m60t(装甲坦克) 前缀冲突：begins_with("cold_m60") 会误匹配 cold_m60t，
	# 此处显式排除装甲卡 cold_m60t。
	if card_id == "cold_m60t":
		return false
	for prefix in _CARD_PREFIXES:
		if card_id.begins_with(prefix):
			return true
	return false

# v7.x: ww2_panzerschrek→ww2_inf_panzerschrek, ww2_bazooka→ww2_inf_bazooka,
# mod_technical→mod_inf_technical, fut_scout_mech→fut_inf_scout_mech
# 补 mod_javelin（标枪导弹兵，原表遗漏）
const _CARD_PREFIXES: Array = ["ww1_mp18", "ww1_mauser", "ww1_enfield", "ww1_storm", "ww1_flame", "ww2_thompson", "ww2_garand", "ww2_mp40", "ww2_ppsh", "ww2_inf_panzerschrek", "ww2_inf_bazooka", "cold_ak47", "cold_m14", "cold_m60", "cold_rpk", "cold_rpg", "mod_marine", "mod_javelin", "mod_inf_technical", "mod_hummer_m2", "mod_hummer_tow", "fut_cyborg", "fut_heavy_trooper", "fut_inf_scout_mech"]
