extends RefCounted
class_name EnhancementModifications
## v6.4 强化词条（原系统D module_definitions 迁移到统一B格式）
## 16个词条，统一 level 1-3 等级，以B的 apply_effects 语义为准。
## 等级系数：Lv1=1.0×, Lv2=1.3×, Lv3=1.7×

const DATA: Dictionary = {
	# ─── 基础池（7个） ───
	"enh_hp_up" = {
		id = "enh_hp_up", name = "铁甲强化", name_en = "HP Up",
		icon = "res://assets/ui/icons/mod_icons/mod_enhancement.png",
		prototype = "纳米护甲", description = "HP提升",
		rarity = "uncommon",
		power_mult = 1.2, cost_research = 100, cost_install = 50,
		slot_type = "enhancement", conflict_group = "enh_hp",
		applicable_types = [0, 1, 2, 3, 4], max_level = 3, source = "enhancement",
		level_effects = {
			1: {max_hp = 0.12}, 2: {max_hp = 0.156}, 3: {max_hp = 0.204},
		},
		unlock_conditions = {required_level = 1}
	},
	"enh_dmg_up" = {
		id = "enh_dmg_up", name = "穿透弹头", name_en = "Damage Up",
		icon = "res://assets/ui/icons/mod_icons/mod_enhancement.png",
		prototype = "穿甲弹", description = "三维攻击提升",
		rarity = "uncommon",
		power_mult = 1.2, cost_research = 100, cost_install = 50,
		slot_type = "enhancement", conflict_group = "enh_dmg",
		applicable_types = [0, 1, 2, 3, 4], max_level = 3, source = "enhancement",
		level_effects = {
			1: {attack_light = 0.15, attack_armor = 0.15, attack_air = 0.15},
			2: {attack_light = 0.195, attack_armor = 0.195, attack_air = 0.195},
			3: {attack_light = 0.255, attack_armor = 0.255, attack_air = 0.255},
		},
		unlock_conditions = {required_level = 1}
	},
	"enh_def_up" = {
		id = "enh_def_up", name = "纳米装甲", name_en = "Damage Reduction",
		icon = "res://assets/ui/icons/mod_icons/mod_enhancement.png",
		prototype = "纳米装甲层", description = "伤害减免",
		rarity = "uncommon",
		power_mult = 1.2, cost_research = 100, cost_install = 50,
		slot_type = "enhancement", conflict_group = "enh_def",
		applicable_types = [0, 1, 2, 3, 4], max_level = 3, source = "enhancement",
		level_effects = {
			1: {damage_reduction = 0.05}, 2: {damage_reduction = 0.07}, 3: {damage_reduction = 0.10},
		},
		unlock_conditions = {required_level = 1}
	},
	"enh_def_flat" = {
		id = "enh_def_flat", name = "复合装甲", name_en = "Defense Flat",
		icon = "res://assets/ui/icons/mod_icons/mod_enhancement.png",
		prototype = "复合装甲板", description = "三维防御提升",
		rarity = "uncommon",
		power_mult = 1.2, cost_research = 100, cost_install = 50,
		slot_type = "enhancement", conflict_group = "enh_def_flat",
		applicable_types = [0, 1, 2, 3, 4], max_level = 3, source = "enhancement",
		level_effects = {
			1: {defense_light = 0.15, defense_armor = 0.15, defense_air = 0.15},
			2: {defense_light = 0.20, defense_armor = 0.20, defense_air = 0.20},
			3: {defense_light = 0.26, defense_armor = 0.26, defense_air = 0.26},
		},
		unlock_conditions = {required_level = 1}
	},
	"enh_speed_up" = {
		id = "enh_speed_up", name = "动力引擎", name_en = "Speed Up",
		icon = "res://assets/ui/icons/mod_icons/mod_enhancement.png",
		prototype = "高效动力组", description = "移动速度提升",
		rarity = "uncommon",
		power_mult = 1.2, cost_research = 100, cost_install = 50,
		slot_type = "enhancement", conflict_group = "enh_speed",
		applicable_types = [0, 1, 2, 3, 4], max_level = 3, source = "enhancement",
		level_effects = {
			1: {move_speed = 12}, 2: {move_speed = 16}, 3: {move_speed = 20},
		},
		unlock_conditions = {required_level = 1}
	},
	"enh_range_up" = {
		id = "enh_range_up", name = "光学瞄准", name_en = "Range Up",
		icon = "res://assets/ui/icons/mod_icons/mod_enhancement.png",
		prototype = "瞄准光学组", description = "射程提升",
		rarity = "uncommon",
		power_mult = 1.2, cost_research = 100, cost_install = 50,
		slot_type = "enhancement", conflict_group = "enh_range",
		applicable_types = [0, 1, 2, 3, 4], max_level = 3, source = "enhancement",
		level_effects = {
			1: {attack_range = 15}, 2: {attack_range = 20}, 3: {attack_range = 25},
		},
		unlock_conditions = {required_level = 1}
	},
	"enh_atkspd_up" = {
		id = "enh_atkspd_up", name = "供弹系统", name_en = "Attack Speed Up",
		icon = "res://assets/ui/icons/mod_icons/mod_enhancement.png",
		prototype = "快拆弹匣", description = "攻速提升（间隔降低）",
		rarity = "uncommon",
		power_mult = 1.2, cost_research = 100, cost_install = 50,
		slot_type = "enhancement", conflict_group = "enh_atkspd",
		applicable_types = [0, 1, 2, 3, 4], max_level = 3, source = "enhancement",
		level_effects = {
			1: {attack_interval = -0.10}, 2: {attack_interval = -0.13}, 3: {attack_interval = -0.17},
		},
		unlock_conditions = {required_level = 1}
	},
	# ─── 进阶池（6个） ───
	"enh_crit" = {
		id = "enh_crit", name = "精密瞄准镜", name_en = "Crit Scope",
		icon = "res://assets/ui/icons/mod_icons/mod_enhancement.png",
		prototype = "高精度瞄准镜", description = "暴击率提升",
		rarity = "rare",
		power_mult = 1.35, cost_research = 200, cost_install = 100,
		slot_type = "enhancement", conflict_group = "enh_crit",
		applicable_types = [0, 1, 2, 3, 4], max_level = 3, source = "enhancement",
		level_effects = {
			1: {crit_chance = 0.08}, 2: {crit_chance = 0.12}, 3: {crit_chance = 0.16},
		},
		unlock_conditions = {required_level = 2}
	},
	"enh_lifesteal" = {
		id = "enh_lifesteal", name = "纳米修复", name_en = "Lifesteal",
		icon = "res://assets/ui/icons/mod_icons/mod_enhancement.png",
		prototype = "纳米修复蜂群", description = "吸血",
		rarity = "rare",
		power_mult = 1.35, cost_research = 200, cost_install = 100,
		slot_type = "enhancement", conflict_group = "enh_lifesteal",
		applicable_types = [0, 1, 2, 3, 4], max_level = 3, source = "enhancement",
		level_effects = {
			1: {lifesteal = 0.05}, 2: {lifesteal = 0.08}, 3: {lifesteal = 0.11},
		},
		unlock_conditions = {required_level = 2}
	},
	"enh_splash" = {
		id = "enh_splash", name = "高爆弹药", name_en = "Splash",
		icon = "res://assets/ui/icons/mod_icons/mod_enhancement.png",
		prototype = "高爆战斗部", description = "溅射伤害",
		rarity = "rare",
		power_mult = 1.35, cost_research = 200, cost_install = 100,
		slot_type = "enhancement", conflict_group = "enh_splash",
		applicable_types = [0, 1, 2, 3, 4], max_level = 3, source = "enhancement",
		level_effects = {
			1: {splash_damage = 0.10}, 2: {splash_damage = 0.15}, 3: {splash_damage = 0.20},
		},
		unlock_conditions = {required_level = 2}
	},
	"enh_penetration" = {
		id = "enh_penetration", name = "穿甲核心", name_en = "Penetration",
		icon = "res://assets/ui/icons/mod_icons/mod_enhancement.png",
		prototype = "钨合金穿甲", description = "穿甲提升",
		rarity = "rare",
		power_mult = 1.35, cost_research = 200, cost_install = 100,
		slot_type = "enhancement", conflict_group = "enh_penetration",
		applicable_types = [0, 1, 2, 3, 4], max_level = 3, source = "enhancement",
		level_effects = {
			1: {armor_penetration = 0.10}, 2: {armor_penetration = 0.15}, 3: {armor_penetration = 0.20},
		},
		unlock_conditions = {required_level = 2}
	},
	"enh_regen" = {
		id = "enh_regen", name = "自修复系统", name_en = "HP Regen",
		icon = "res://assets/ui/icons/mod_icons/mod_enhancement.png",
		prototype = "自修复纳米", description = "每秒回血",
		rarity = "rare",
		power_mult = 1.35, cost_research = 200, cost_install = 100,
		slot_type = "enhancement", conflict_group = "enh_regen",
		applicable_types = [0, 1, 2, 3, 4], max_level = 3, source = "enhancement",
		level_effects = {
			1: {hp_regen = 0.005}, 2: {hp_regen = 0.008}, 3: {hp_regen = 0.012},
		},
		unlock_conditions = {required_level = 2}
	},
	"enh_chain" = {
		id = "enh_chain", name = "链式反应", name_en = "Chain",
		icon = "res://assets/ui/icons/mod_icons/mod_enhancement.png",
		prototype = "链式电弧", description = "连锁概率",
		rarity = "rare",
		power_mult = 1.35, cost_research = 200, cost_install = 100,
		slot_type = "enhancement", conflict_group = "enh_chain",
		applicable_types = [0, 1, 2, 3, 4], max_level = 3, source = "enhancement",
		level_effects = {
			1: {chain_chance = 0.08}, 2: {chain_chance = 0.12}, 3: {chain_chance = 0.16},
		},
		unlock_conditions = {required_level = 2}
	},
	# ─── 终极池（3个） ───
	"enh_shield_kill" = {
		id = "enh_shield_kill", name = "击杀护盾", name_en = "Shield on Kill",
		icon = "res://assets/ui/icons/mod_icons/mod_enhancement.png",
		prototype = "击杀力场", description = "击杀获得护盾",
		rarity = "epic",
		power_mult = 1.5, cost_research = 400, cost_install = 200,
		slot_type = "enhancement", conflict_group = "enh_shield_kill",
		applicable_types = [0, 1, 2, 3, 4], max_level = 3, source = "enhancement",
		level_effects = {
			1: {shield_on_kill = 0.05}, 2: {shield_on_kill = 0.08}, 3: {shield_on_kill = 0.11},
		},
		unlock_conditions = {required_level = 3}
	},
	"enh_dodge" = {
		id = "enh_dodge", name = "相位闪避", name_en = "Dodge",
		icon = "res://assets/ui/icons/mod_icons/mod_enhancement.png",
		prototype = "相位规避", description = "闪避率提升",
		rarity = "epic",
		power_mult = 1.5, cost_research = 400, cost_install = 200,
		slot_type = "enhancement", conflict_group = "enh_dodge",
		applicable_types = [0, 1, 2, 3, 4], max_level = 3, source = "enhancement",
		level_effects = {
			1: {dodge_chance = 0.06}, 2: {dodge_chance = 0.09}, 3: {dodge_chance = 0.13},
		},
		unlock_conditions = {required_level = 3}
	},
	"enh_crit_dmg" = {
		id = "enh_crit_dmg", name = "致命强化", name_en = "Crit Damage",
		icon = "res://assets/ui/icons/mod_icons/mod_enhancement.png",
		prototype = "致命弹药", description = "暴击伤害加成",
		rarity = "epic",
		power_mult = 1.5, cost_research = 400, cost_install = 200,
		slot_type = "enhancement", conflict_group = "enh_crit_dmg",
		applicable_types = [0, 1, 2, 3, 4], max_level = 3, source = "enhancement",
		level_effects = {
			1: {crit_damage_bonus = 0.20}, 2: {crit_damage_bonus = 0.30}, 3: {crit_damage_bonus = 0.42},
		},
		unlock_conditions = {required_level = 3}
	},
}

## 获取词条定义
static func get_mod_data(mod_id: String) -> Dictionary:
	return DATA.get(mod_id, {})

## 获取所有词条ID
static func get_all_mod_ids() -> Array:
	return DATA.keys()

## v6.4: 按兵种返回可用的强化词条（applicable_types 含全部兵种 [0,1,2,3,4]）
static func get_for_unit_type(unit_type: int) -> Array:
	# 强化词条适用于所有兵种，全部返回
	return DATA.keys()

## 检查冲突
static func check_conflict(mod_id_a: String, mod_id_b: String) -> bool:
	var data_a = get_mod_data(mod_id_a)
	var data_b = get_mod_data(mod_id_b)
	var group_a = data_a.get("conflict_group", "")
	var group_b = data_b.get("conflict_group", "")
	return group_a != "" and group_a == group_b

## 按 card_id 精筛（强化词条适用所有卡）
static func get_for_card(card_id: String) -> Array:
	return DATA.keys()
