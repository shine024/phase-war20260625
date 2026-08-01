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
		description = "多层复合装甲，对装甲防御+30%，减伤+50%",
		icon = "res://assets/ui/icons/mod_icons/mod_armor_special.png",
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
		description = "爆炸反应装甲：受击时反弹30%伤害给攻击者，可触发3次",
		icon = "res://assets/ui/icons/mod_icons/mod_shield_reactive.png",
		rarity = "epic",
		power_mult = 1.6,
		cost_research = 300,
		cost_install = 150,
		slot_type = "armor",
		conflict_group = "armor",
		effects = {
			# v7.x 第二批：修复为真正的爆反（原 heat_immunity_once 只是减伤）
			reactive_armor = 0.30,       # 反弹30%伤害
			reflect_charges = 3,         # 3次后失效
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
		description = "拦截来袭导弹：30%概率完全免伤，可触发3次",
		icon = "res://assets/ui/icons/mod_icons/mod_active.png",
		rarity = "legendary",
		power_mult = 2.0,
		cost_research = 450,
		cost_install = 225,
		slot_type = "active",
		conflict_group = "active",
		effects = {
			# v7.x 第二批：修复为真正的拦截（原 missile_intercept 只是减伤）
			intercept_system = 0.30,    # 30%概率拦截
			intercept_charges = 3,      # 3次后失效
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
	# v7.x: per-slot 弹道——对装甲槽改 DIRECT 直射（滑膛炮直瞄）
	condition_slot = 1,
	effects = {
		attack_armor = 0.25,   # +25%
		attack_range = 30,     # +30px
			weapon_type = 0,  # v6.5 DIRECT（单位级默认）
			slot_weapon_type = 0,  # v7.x: 对装甲槽直射化
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
		icon = "res://assets/ui/icons/mod_icons/mod_ammo_apfsds.png",
		rarity = "epic",
	power_mult = 1.6,
		cost_research = 320,
		cost_install = 160,
	slot_type = "ammunition",
	conflict_group = "ammunition",
	# v7.x: per-slot 弹道——对装甲槽 SNIPER 穿甲（尾翼稳定脱壳）
	condition_slot = 1,
	effects = {
		attack_armor = 0.30,   # +30% (v6.0 平衡性调整: +35% → +30%)
			weapon_type = 6,  # v6.5 SNIPER pierce（单位级默认）
			slot_weapon_type = 6,  # v7.x: 对装甲槽穿甲弹道
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
	# v7.x: per-slot 弹道——对空槽 MISSILE 导弹（grant_slot 已激活槽位，此处补 slot_weapon_type 双保险）
	condition_slot = 2,
	effects = {
		attack_armor = 0.20,   # +20% 对装甲
		slot_weapon_type = 9,  # v7.x: 对空槽导弹弹道（MISSILE）
		vfx_variant = "gun_missile",  # v8.4: 炮射导弹专属视觉（蓝白尾焰，区分标准导弹）
	},
	# v6.13: grant_slot 直接激活对空武器槽（修复原 attack_air=0.20 对 base=0 失效的 bug）
	# 以载体 attack_armor 为基准 ×0.8 派生对空基础伤害，导弹式低射速高单发
	# 平衡：装T-72→对空144；装M1A2→对空240（接近 mod_stinger 220，弱于 mod_m6 840）
	grant_slot = {
		slot = 2,                      # 对空槽位（0=轻装, 1=装甲, 2=对空）
		base_damage = "attack_armor",  # 基准字段：载体单位的对装甲伤害
		damage_ratio = 0.8,            # 基准 × 此系数 = 对空基础伤害
		speed = 0.33,                  # 攻速（次/秒，导弹式低射速高单发）
		windup = 0.6,                  # 前摇（秒，导弹发射准备）
		active = 0.15,                 # 动作（秒）
		weapon_type = 9,               # MISSILE（旧型号9，弹道VFX用）
		range_value = 3,               # 射程（格，与主炮一致）
		display_name = "炮射导弹",
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
		description = "燃气轮机，部署加速40%",
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
		description = "增压柴油机，部署加速20%，生命+10%",
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
		# v8.x: 原 smoke_ignore→暴击 + attack_range+30px（射程加成过小几乎无感）。
		# 项目无独立烟雾战术系统，smoke_ignore bool 被重定向为固定 +15% 暴击；
		# 现 effects 直接写 crit_chance=0.15（语义对齐"热成像=看得清=命中要害"），射程加成删除。
		# v8.6: 稀有度 rare→epic（+15%暴击比所有 epic 同类 +8~10% 都强，倒挂修正）。
		description = "热成像瞄准，暴击率+15%",
		icon = "res://assets/ui/icons/mod_icons/mod_optics.png",
		rarity = "epic",
	power_mult = 1.6,
	cost_research = 240,
	cost_install = 120,
	slot_type = "optics",
	conflict_group = "optics",
	effects = {
		crit_chance = 0.15,    # +15% 暴击率（热成像精准锁定）
	},
	unlock_conditions = {
		required_level = 5,
	}
	},

	# ─── 特殊环境改造 ───────────────────────
	"arm_13_deep_wading" = {
		id = ARM_13_DEEP_WADING,
		name = "火控计算机",
		name_en = "Fire Control Computer",
		prototype = "M1艾布拉姆斯火控系统",
		description = "弹道计算机实时解算，开火节奏加快",
		icon = "res://assets/ui/icons/mod_icons/mod_environment.png",
		rarity = "uncommon",
	power_mult = 1.0,
		cost_research = 100,
		cost_install = 50,
		slot_type = "environment",
		conflict_group = "environment",
		effects = {
			attack_interval = -0.15,  # 火控解算快→开火间隔缩短
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
		# v8.x: 项目无敌方地雷机制，原 mine_immunity 空转。
		# 重定向为三维防御加成（registry mine_immunity 分支控制系数），
		# 描述对齐实际效果，不提"免疫地雷"。
		description = "附加装甲提升三维防御+30%，轻微减速",
		icon = "res://assets/ui/icons/mod_icons/mod_engineering.png",
		rarity = "rare",
	power_mult = 1.3,
		cost_research = 160,
		cost_install = 80,
		slot_type = "engineering",
		conflict_group = "engineering",
		effects = {
			mine_immunity = true,   # 重定向为三维防御+30%（registry mine_immunity 分支）
			move_speed = -5,        # -5px/s 副作用（重定向为部署延迟+0.1）
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
		description = "数据链协同：自身暴击+5%，周围友军暴击+10%",
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

	# ─── v7.x 新机制改造 ───

	# 怒气型：战斗狂热（受击 8 次后激活 5 秒 +35% 攻击）
	"arm_16_battle_frenzy" = {
		id = "arm_16_battle_frenzy",
		name = "战斗狂热",
		name_en = "Battle Frenzy",
		icon = "res://assets/ui/icons/mod_icons/mod_special.png",
		prototype = "损伤响应式反应装甲",
		description = "承受攻击积累怒气，受击 8 次后激活战斗狂热：5 秒内攻击力 +35%",
		rarity = "legendary",
		power_mult = 1.8,
		cost_research = 400,
		cost_install = 200,
		slot_type = "special",
		conflict_group = "special",
		effects = {rage_system = 8, rage_bonus = 0.35},
		unlock_conditions = {required_level = 6}
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
	# cold_m1(装甲) 与 cold_m14(步兵) 前缀冲突：begins_with("cold_m1") 会误匹配 cold_m14，
	# 此处显式排除步兵卡 cold_m14。
	if card_id == "cold_m14":
		return false
	for prefix in _CARD_PREFIXES:
		if card_id.begins_with(prefix):
			return true
	return false

# v7.x: 卡牌 ID 规范化后（加 _arm_/_inf_ 等兵种中缀），前缀表已同步更新。
# mod_arm_m1a 覆盖 mod_arm_m1a1/mod_arm_m1a2sep；mod_m1a2 是独立卡单独列出。
const _CARD_PREFIXES: Array = ["ww1_arm_rolls", "ww1_lanchest", "ww1_arm_ft17", "ww1_saint", "ww1_a7v", "ww1_mark4", "ww2_pz", "ww2_panther", "ww2_arm_tiger", "ww2_kingtiger", "ww2_t34", "ww2_is2", "ww2_arm_sherman", "ww2_inf_hellcat", "cold_inf_btr60", "cold_inf_bmp1", "cold_bradley", "cold_arm_t55", "cold_t62", "cold_t72", "cold_m60t", "cold_m1", "cold_leo1", "cold_chieftain", "mod_stryker", "mod_arm_m1a", "mod_m1a2", "mod_t90", "mod_leo2a6", "mod_challenger2", "fut_assault_mech", "fut_arm_heavy_mech", "fut_arm_hovertank", "fut_arm_prism", "fut_colossus", "fut_arm_nexus", "fut_arm_omega"]
