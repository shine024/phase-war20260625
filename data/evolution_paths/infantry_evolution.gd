extends RefCounted
class_name InfantryEvolution
## 步兵进化路径定义
## 主线：MP18突击班 → 巨神机甲
## 隐藏分支：特种作战、反坦克猎手、狙击手

## ─────────────────────────────────────────────
##  进化节点定义
## ─────────────────────────────────────────────

## 主线进化节点
const MAIN_LINE: Dictionary = {
	E0 = {
		stage = 0,
		card_id = "ww1_mp18",
		name = "MP18突击班",
		era = "WW1",
		power = 15,
		max_hp = 100,
		attack_light = 35,
		attack_armor = 0,
		attack_air = 0,
		defense_light = 8,
		defense_armor = 5,
		defense_air = 3,
		inherit_multiplier = 0.0,  # 起始节点无继承
	},
	E1 = {
		stage = 1,
		card_id = "ww2_thompson",
		name = "汤普森班",
		era = "WW2",
		power = 60,
		max_hp = 140,
		attack_light = 55,
		attack_armor = 0,
		attack_air = 0,
		defense_light = 15,
		defense_armor = 10,
		defense_air = 6,
		inherit_multiplier = 0.30,
		requirements = {
			level = 5,
			mods_count = 2,
			intel_basic = 50,
			power_ratio = 0.8,  # 当前战力 ≥ 目标×0.8
		}
	},
	E2 = {
		stage = 2,
		card_id = "cold_ak47",
		name = "AK-47步兵班",
		era = "Cold",
		power = 160,
		max_hp = 200,
		attack_light = 90,
		attack_armor = 0,
		attack_air = 0,
		defense_light = 30,
		defense_armor = 20,
		defense_air = 12,
		inherit_multiplier = 0.30,
		requirements = {
			level = 8,
			mods_count = 5,
			eom_count = 1,
			intel_basic = 75,
			power_ratio = 0.9,
		}
	},
	E3 = {
		stage = 3,
		card_id = "mod_marine",
		name = "海军陆战队",
		era = "Modern",
		power = 320,
		max_hp = 300,
		attack_light = 140,
		attack_armor = 0,
		attack_air = 0,
		defense_light = 50,
		defense_armor = 35,
		defense_air = 20,
		inherit_multiplier = 0.30,
		requirements = {
			level = 10,
			mods_count = 8,
			eom_count = 2,
			intel_basic = 90,
			power_ratio = 1.0,
		}
	},
	E4 = {
		stage = 4,
		card_id = "fut_cyborg",
		name = "机械步兵",
		era = "Future",
		power = 500,
		max_hp = 400,
		attack_light = 200,
		attack_armor = 50,
		attack_air = 0,
		defense_light = 80,
		defense_armor = 60,
		defense_air = 40,
		inherit_multiplier = 0.30,
		requirements = {
			level = 10,
			mods_count = 9,
			eom_count = 3,
			intel_basic = 100,
			power_ratio = 1.1,
		}
	},
	E5 = {
		stage = 5,
		card_id = "fut_colossus",
		name = "巨神机甲",
		era = "Ultimate",
		power = 1590,
		max_hp = 2000,
		attack_light = 100,
		attack_armor = 550,
		attack_air = 0,
		defense_light = 150,
		defense_armor = 250,
		defense_air = 100,
		inherit_multiplier = 0.30,
		requirements = {
			level = 10,
			mods_count = 9,
			eom_count = 3,
			intel_basic = 100,
			power_ratio = 1.2,
			hidden_branch = true,  # 需要解锁隐藏分支
		}
	},
}

## 隐藏分支1：特种作战路线
const SPECIAL_BRANCH: Dictionary = {
	E3_ALT = {
		stage = 3,
		card_id = "mod_ranger",
		name = "游骑兵",
		era = "Modern",
		power = 340,
		max_hp = 320,
		attack_light = 160,
		attack_armor = 20,
		attack_air = 0,
		defense_light = 55,
		defense_armor = 38,
		defense_air = 22,
		inherit_multiplier = 0.40,
		special = {dodge_chance = 0.10},
		requirements = {
			level = 8,
			mods_count = 5,
			intel_stealth = 75,
			intel_basic = 50,
			power_ratio = 1.0,
		}
	},
	E4_ALT = {
		stage = 4,
		card_id = "fe_nova_ghost_sniper",
		name = "幽灵狙击组",
		era = "Future",
		power = 580,
		max_hp = 280,
		attack_light = 180,
		attack_armor = 30,
		attack_air = 0,
		defense_light = 70,
		defense_armor = 50,
		defense_air = 30,
		inherit_multiplier = 0.40,
		special = {crit_chance = 0.15, attack_range = 50},
		requirements = {
			level = 10,
			mods_count = 8,
			intel_stealth = 90,
			intel_basic = 75,
			power_ratio = 1.1,
		}
	},
	E5_ALT = {
		stage = 5,
		card_id = "fut_spectre",
		name = "幽灵特工",
		era = "Ultimate",
		power = 620,
		max_hp = 350,
		attack_light = 220,
		attack_armor = 80,
		attack_air = 0,
		defense_light = 60,
		defense_armor = 50,
		defense_air = 40,
		inherit_multiplier = 0.45,
		special = {stealth_first_crit = true},
		requirements = {
			level = 10,
			mods_count = 9,
			intel_stealth = 100,
			intel_basic = 100,
			power_ratio = 1.2,
		}
	},
}

## 隐藏分支2：反坦克猎手路线
const AT_BRANCH: Dictionary = {
	E2_AT = {
		stage = 2,
		card_id = "ww2_panzerschrek",
		name = "铁拳反坦克组",
		era = "WW2",
		power = 65,
		max_hp = 120,
		attack_light = 15,
		attack_armor = 90,
		attack_air = 0,
		defense_light = 12,
		defense_armor = 10,
		defense_air = 5,
		inherit_multiplier = 0.40,
		special = {attack_armor = 90},
		requirements = {
			level = 8,
			mods_count = 5,
			intel_armor = 80,
			intel_tech = 75,
			power_ratio = 1.0,
		}
	},
	E3_AT = {
		stage = 3,
		card_id = "cold_rpg",
		name = "RPG-7火箭筒组",
		era = "Cold",
		power = 170,
		max_hp = 180,
		attack_light = 18,
		attack_armor = 120,
		attack_air = 0,
		defense_light = 15,
		defense_armor = 5,
		defense_air = 5,
		inherit_multiplier = 0.45,
		special = {attack_armor = 120, armor_penetration = 0.20},
		requirements = {
			level = 10,
			mods_count = 8,
			intel_armor = 90,
			intel_tech = 85,
			power_ratio = 1.1,
		}
	},
	E4_AT = {
		stage = 4,
		card_id = "mod_javelin",
		name = "标枪导弹兵",
		era = "Modern",
		power = 330,
		max_hp = 220,
		attack_light = 25,
		attack_armor = 250,
		attack_air = 20,
		defense_light = 30,
		defense_armor = 25,
		defense_air = 15,
		inherit_multiplier = 0.50,
		special = {attack_armor = 250, attack_light = 25},
		requirements = {
			level = 10,
			mods_count = 9,
			intel_armor = 100,
			intel_tech = 95,
			power_ratio = 1.2,
		}
	},
	E5_AT = {
		stage = 5,
		card_id = "fut_cyborg_at",
		name = "机械步兵·破甲型",
		era = "Future",
		power = 520,
		max_hp = 420,
		attack_light = 50,
		attack_armor = 350,
		attack_air = 0,
		defense_light = 80,
		defense_armor = 70,
		defense_air = 50,
		inherit_multiplier = 0.55,
		special = {attack_armor = 350},
		requirements = {
			level = 10,
			mods_count = 9,
			intel_armor = 100,
			intel_tech = 100,
			power_ratio = 1.3,
		}
	},
}

## 隐藏分支3：狙击手路线
const SNIPER_BRANCH: Dictionary = {
	E2_SNIPER = {
		stage = 2,
		card_id = "cold_sniper",
		name = "SVD狙击组",
		era = "Cold",
		power = 175,
		max_hp = 160,
		attack_light = 85,
		attack_armor = 15,
		attack_air = 0,
		defense_light = 25,
		defense_armor = 20,
		defense_air = 15,
		inherit_multiplier = 0.35,
		special = {attack_range = 100, crit_chance = 0.10},
		requirements = {
			level = 8,
			mods_count = 5,
			combat_rating = "A+",
			intel_recon = 80,
			power_ratio = 1.0,
		}
	},
	E3_SNIPER = {
		stage = 3,
		card_id = "mod_m24",
		name = "M24狙击组",
		era = "Modern",
		power = 350,
		max_hp = 240,
		attack_light = 130,
		attack_armor = 30,
		attack_air = 0,
		defense_light = 45,
		defense_armor = 30,
		defense_air = 25,
		inherit_multiplier = 0.40,
		special = {attack_range = 150, crit_damage = 0.3},
		requirements = {
			level = 10,
			mods_count = 8,
			combat_rating = "S",
			intel_recon = 90,
			power_ratio = 1.1,
		}
	},
	E4_SNIPER = {
		stage = 4,
		card_id = "fut_nexus_archer",
		name = "虚空射手",
		era = "Future",
		power = 580,
		max_hp = 300,
		attack_light = 200,
		attack_armor = 100,
		attack_air = 0,
		defense_light = 70,
		defense_armor = 60,
		defense_air = 50,
		inherit_multiplier = 0.50,
		special = {always_hit = true},
		requirements = {
			level = 10,
			mods_count = 9,
			combat_rating = "S+",
			intel_recon = 100,
			power_ratio = 1.2,
		}
	},
}

## ─────────────────────────────────────────────
##  查询接口
## ─────────────────────────────────────────────

## 获取主线进化节点
static func get_main_line() -> Dictionary:
	return MAIN_LINE.duplicate(true)

## 获取隐藏分支节点
static func get_hidden_branches() -> Dictionary:
	return {
		special = SPECIAL_BRANCH.duplicate(true),
		at = AT_BRANCH.duplicate(true),
		sniper = SNIPER_BRANCH.duplicate(true),
	}

## 检查进化条件
static func check_requirements(card: Dictionary, target_stage: String) -> Dictionary:
	var result = {passed = true, missing = []}
	# TODO: 实现条件检查逻辑
	return result

## 获取进化后的属性计算
static func calculate_evolved_stats(old_card: Dictionary, target_node: Dictionary) -> Dictionary:
	var inherit_mult = target_node.get("inherit_multiplier", 0.30)
	var base_stats = {
		max_hp = target_node.max_hp,
		attack_light = target_node.attack_light,
		attack_armor = target_node.attack_armor,
		attack_air = target_node.attack_air,
		defense_light = target_node.defense_light,
		defense_armor = target_node.defense_armor,
		defense_air = target_node.defense_air,
	}
	# 继承旧卡牌的改造加成（30%-55%）
	# TODO: 实现继承计算
	return base_stats
