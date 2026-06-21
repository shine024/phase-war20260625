extends RefCounted
class_name ArmorModifications
## 装甲兵改造模块定义（15个）
## 每个改造映射到真实装甲车辆技术

## ─────────────────────────────────────────────
##  改造ID常量
## ─────────────────────────────────────────────

const ARM_01_SLOPED_ARMOR = "arm_01_sloped_armor"
const ARM_02_COMPOSITE_ARMOR = "arm_02_composite_armor"
const ARM_03_REACTIVE_ARMOR = "arm_03_reactive_armor"
const ARM_04_APS = "arm_04_aps"
const ARM_05_SMOOTHBORE = "arm_05_smoothbore"
const ARM_06_APFSDS = "arm_06_apfsds"
const ARM_07_GUN_MISSILE = "arm_07_gun_missile"
const ARM_08_AUTOLOADER = "arm_08_autoloader"
const ARM_09_TURBINE = "arm_09_turbine"
const ARM_10_DIESEL_TURBO = "arm_10_diesel_turbo"
const ARM_11_FIRE_CONTROL = "arm_11_fire_control"
const ARM_12_THERMAL_SIGHT = "arm_12_thermal_sight"
const ARM_13_DEEP_WADING = "arm_13_deep_wading"
const ARM_14_MINE_PLOW = "arm_14_mine_plow"
const ARM_15_DATA_LINK = "arm_15_data_link"

## ─────────────────────────────────────────────
##  改造数据表
## ─────────────────────────────────────────────

const DATA: Dictionary = {
	# ─── 装甲改造 ───────────────────────────
	"arm_01_sloped_armor" = {
		id = ARM_01_SLOPED_ARMOR,
		name = "倾斜装甲",
		name_en = "Sloped Armor",
		prototype = "T-34革命设计",
		description = "倾斜装甲增加等效厚度，提升防护",
		icon = "res://assets/ui/icons/mod_icons/mod_armor.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 180,
		cost_install = 90,
		slot_type = "armor",
		conflict_group = "armor",
		effects = {
			defense_armor = 0.20,   # +20%
		},
		unlock_conditions = {
			required_level = 2,
		}
	},

	"arm_02_composite_armor" = {
		id = ARM_02_COMPOSITE_ARMOR,
		name = "复合装甲",
		name_en = "Composite Armor",
		prototype = "乔巴姆",
		description = "多层复合材料，显著提升对HEAT弹防护",
		icon = "res://assets/ui/icons/mod_icons/mod_armor.png",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 280,
		cost_install = 140,
		slot_type = "armor",
		conflict_group = "armor",
		effects = {
			defense_armor = 0.30,   # +30%
			heat_resist = 0.50,     # HEAT抗性+50%
		},
		unlock_conditions = {
			required_level = 4,
		}
	},

	"arm_03_reactive_armor" = {
		id = ARM_03_REACTIVE_ARMOR,
		name = "爆反装甲",
		name_en = "Reactive Armor",
		prototype = "接触-1",
		description = "爆炸反应装甲，首击免疫HEAT，消耗后失效",
		icon = "res://assets/ui/icons/mod_icons/mod_armor.png",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 300,
		cost_install = 150,
		slot_type = "armor",
		conflict_group = "armor",
		effects = {
			heat_immunity_once = true,  # 首击HEAT免疫
			defense_armor = 0.10,       # +10% 基础防护
		},
		unlock_conditions = {
			required_level = 5,
		}
	},

	"arm_04_aps" = {
		id = ARM_04_APS,
		name = "主动防护",
		name_en = "Active Protection System",
		prototype = "铁拳/竞技场",
		description = "拦截来袭反坦克导弹，30%拦截率",
		icon = "res://assets/ui/icons/mod_icons/mod_active.png",
		rarity = "legendary",
	power_mult = 2.0,
		cost_research = 450,
		cost_install = 225,
		slot_type = "active",
		conflict_group = "active",
		effects = {
			missile_intercept = 0.30,  # 30%拦截
		},
		unlock_conditions = {
			required_level = 7,
		}
	},

	# ─── 火炮改造 ───────────────────────────
	"arm_05_smoothbore" = {
		id = ARM_05_SMOOTHBORE,
		name = "滑膛炮",
		name_en = "Smoothbore Gun",
		prototype = "莱茵金属L44",
		description = "滑膛炮设计，穿甲威力提升",
		icon = "res://assets/ui/icons/mod_icons/mod_gun.png",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 260,
		cost_install = 130,
		slot_type = "gun",
		conflict_group = "gun",
		effects = {
			attack_armor = 0.25,   # +25%
			attack_range = 30,     # +30px
				weapon_type = 0,  # v6.5 DIRECT
		},
		unlock_conditions = {
			required_level = 4,
		}
	},

	"arm_06_apfsds" = {
		id = ARM_06_APFSDS,
		name = "尾翼稳定脱壳穿甲弹",
		name_en = "APFSDS",
		prototype = "北约标准",
		description = "高动能穿甲弹，对装甲伤害最大化",
		icon = "res://assets/ui/icons/mod_icons/mod_ammunition.png",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 320,
		cost_install = 160,
		slot_type = "ammunition",
		conflict_group = "ammunition",
		effects = {
			attack_armor = 0.30,   # +30% (v6.0 平衡性调整: +35% → +30%)
				weapon_type = 6,  # v6.5 SNIPER pierce
			attack_light = -0.15,   # -15% 副作用
		},
		unlock_conditions = {
			required_level = 5,
		}
	},

	"arm_07_gun_missile" = {
		id = ARM_07_GUN_MISSILE,
		name = "炮射导弹",
		name_en = "Gun-Launched Missile",
		prototype = "红宝石/反射",
		description = "可攻击空中目标，增加对空能力",
		icon = "res://assets/ui/icons/mod_icons/mod_gun.png",
		rarity = "legendary",
	power_mult = 2.0,
		cost_research = 400,
		cost_install = 200,
		slot_type = "gun",
		conflict_group = "gun",
		effects = {
			attack_air = 0.20,     # +20% 对空（从0提升）
			attack_armor = 0.20,   # +20%
		},
		unlock_conditions = {
			required_level = 6,
		}
	},

	# ─── 机动性改造 ─────────────────────────
	"arm_08_autoloader" = {
		id = ARM_08_AUTOLOADER,
		name = "自动装弹机",
		name_en = "Autoloader",
		prototype = "T-64首创",
		description = "自动装填，射速大幅提升",
		icon = "res://assets/ui/icons/mod_icons/mod_autoloader.png",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 280,
		cost_install = 140,
		slot_type = "autoloader",
		conflict_group = "autoloader",
		effects = {
			attack_interval = -0.20,  # -20%
		},
		unlock_conditions = {
			required_level = 4,
		}
	},

	"arm_09_turbine" = {
		id = ARM_09_TURBINE,
		name = "燃气轮机",
		name_en = "Gas Turbine",
		prototype = "M1艾布拉姆斯",
		description = "燃气轮机，机动性显著提升",
		icon = "res://assets/ui/icons/mod_icons/mod_engine.png",
		rarity = "legendary",
	power_mult = 2.0,
		cost_research = 380,
		cost_install = 190,
		slot_type = "engine",
		conflict_group = "engine",
		effects = {
			move_speed = 20,       # +20px/s
		},
		unlock_conditions = {
			required_level = 6,
		}
	},

	"arm_10_diesel_turbo" = {
		id = ARM_10_DIESEL_TURBO,
		name = "柴油增压引擎",
		name_en = "Turbocharged Diesel",
		prototype = "MTU发动机",
		description = "增压柴油机，机动和耐久平衡",
		icon = "res://assets/ui/icons/mod_icons/mod_engine.png",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 240,
		cost_install = 120,
		slot_type = "engine",
		conflict_group = "engine",
		effects = {
			move_speed = 10,       # +10px/s
			max_hp = 0.10,         # +10%
		},
		unlock_conditions = {
			required_level = 4,
		}
	},

	# ─── 火控与电子设备 ─────────────────────
	"arm_11_fire_control" = {
		id = ARM_11_FIRE_CONTROL,
		name = "猎歼火控",
		name_en = "Hunter-Killer FCS",
		prototype = "豹2",
		description = "猎歼火控系统，精准度大幅提升",
		icon = "res://assets/ui/icons/mod_icons/mod_fire_control.png",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 300,
		cost_install = 150,
		slot_type = "fire_control",
		conflict_group = "fire_control",
		effects = {
			crit_chance = 0.10,    # +10%
		},
		unlock_conditions = {
			required_level = 5,
		}
	},

	"arm_12_thermal_sight" = {
		id = ARM_12_THERMAL_SIGHT,
		name = "热成像瞄准镜",
		name_en = "Thermal Sight",
		prototype = "M60A3 TTS",
		description = "热成像瞄准，无视烟雾，射程提升",
		icon = "res://assets/ui/icons/mod_icons/mod_optics.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 200,
		cost_install = 100,
		slot_type = "optics",
		conflict_group = "optics",
		effects = {
			smoke_ignore = true,   # 无视烟雾
			attack_range = 30,     # +30px
		},
		unlock_conditions = {
			required_level = 3,
		}
	},

	# ─── 特殊环境改造 ───────────────────────
	"arm_13_deep_wading" = {
		id = ARM_13_DEEP_WADING,
		name = "深涉渡套件",
		name_en = "Deep Wading Kit",
		prototype = "DD坦克",
		description = "河流地形移动不减速",
		icon = "res://assets/ui/icons/mod_icons/mod_environment.png",
		rarity = "uncommon",
	power_mult = 1.0,
		cost_research = 100,
		cost_install = 50,
		slot_type = "environment",
		conflict_group = "environment",
		effects = {
			river_no_penalty = true,  # 河流无减速
		},
		unlock_conditions = {
			required_level = 2,
		}
	},

	"arm_14_mine_plow" = {
		id = ARM_14_MINE_PLOW,
		name = "扫雷滚/犁",
		name_en = "Mine Plow/Roller",
		prototype = "以色列地毯",
		description = "免疫地雷，轻微减速",
		icon = "res://assets/ui/icons/mod_icons/mod_engineering.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 160,
		cost_install = 80,
		slot_type = "engineering",
		conflict_group = "engineering",
		effects = {
			mine_immunity = true,   # 免疫地雷
			move_speed = -5,        # -5px/s 副作用
		},
		unlock_conditions = {
			required_level = 3,
		}
	},

	"arm_15_data_link" = {
		id = ARM_15_DATA_LINK,
		name = "战术数据链",
		name_en = "Tactical Data Link",
		prototype = "Link 16",
		description = "数据链系统，周围友军命中提升",
		icon = "res://assets/ui/icons/mod_icons/mod_command.png",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 260,
		cost_install = 130,
		slot_type = "command",
		conflict_group = "command",
		effects = {
			ally_hit_bonus = 0.10,  # 周围友军+10%命中
		},
		unlock_conditions = {
			required_level = 5,
		}
	},
}

## ─────────────────────────────────────────────
##  查询接口
## ─────────────────────────────────────────────

static func get_mod_data(mod_id: String) -> Dictionary:
	if DATA.has(mod_id):
		return DATA[mod_id].duplicate(true)
	return {}

static func get_all_mod_ids() -> Array:
	return DATA.keys()

static func get_for_unit_type(unit_type: int) -> Array:
	if unit_type == 1:  # ARMOR
		return DATA.keys()
	return []

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

const _CARD_PREFIXES: Array = ["ww1_rolls", "ww1_lanchest", "ww1_ft17", "ww1_saint", "ww1_a7v", "ww1_mark4", "ww2_pz", "ww2_tiger", "ww2_kingtiger", "ww2_t34", "ww2_is2", "ww2_sherman", "ww2_hellcat", "cold_btr60", "cold_bmp1", "cold_bradley", "cold_t55", "cold_t62", "cold_t72", "cold_m60t", "cold_m1", "cold_leo1", "cold_chieftain", "mod_stryker", "mod_m1a", "mod_t90", "mod_leo2", "mod_challenger", "fut_assault_mech", "fut_heavy_mech", "fut_hovertank", "fut_prism", "fut_colossus", "fut_nexus", "omega_platform"]
