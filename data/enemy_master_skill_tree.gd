extends RefCounted
class_name EnemyMasterSkillTree
## v18 四源重构·批次3 —— 敌方相位师技能树（派生式 typed 节点）
##
## 来源：原 5 个 enemy_phase_masters_*.gd 的 traits / passive_spells 字段按语义归类迁入
## （生成器 tools/gen_enemy_skill_tree.py ← docs/migration_baseline.json，分类规则与
##  tools/compare_old_new_bonuses.py 严格一致——已批准的强度比率 1.04 的数据基础）。
##
## 四源中本文件承载两源：
##   1. 等级属性加成 —— v18.c 起换 flat 统一（CardGrowthConfig 全项目同表）：
##      消费在 enemy_phase_field_driver._apply_master_level_flat（按产兵单位自身时代/兵种
##      × 相位师等级派生固定值，纯加法链尾注入）。本文件不再承载等级通道。
##   2. 相位师技能树 —— num（数值节点，产兵 stats 注入）+ mech（机制节点，engine 按 kind 精确分发）
##      + element（元素聚合，写 UnitStats.element_affinity/element_damage_mult，clamp 2.0）
##
## todo 节点 = 归类后保持现状空转的机制（implemented:false），供后续补齐与信息卡展示。
## 势力技能树（协同）在 data/enemy_faction_skills.gd。

## master_id → 技能树节点表（num/mech/todo/element）
const MASTER_NODES: Dictionary = {
	"enemy_master_001": {
		"num": [
			{
				"id": "recruit_commander",
				"name": "新兵教官",
				"effects": {
					"def_light": 0.1,
					"def_armor": 0.1,
					"def_air": 0.1
				}
			},
			{
				"id": "steel_skin",
				"name": "钢铁之肤",
				"effects": {
					"def_light": 0.12,
					"def_armor": 0.12,
					"def_air": 0.12
				}
			}
		],
		"mech": [
			{
				"id": "fortress_mind",
				"name": "堡垒思维",
				"kind": "death_shield",
				"effect": "death_shield",
				"params": {
					"shield_percent": 0.05
				}
			}
		],
		"todo": []
	},
	"enemy_master_002": {
		"num": [
			{
				"id": "first_flame",
				"name": "初燃之心",
				"effects": {
					"atk_light": 0.08,
					"atk_armor": 0.08,
					"atk_air": 0.08
				}
			},
			{
				"id": "fire_adaptation",
				"name": "火焰适应",
				"effects": {
					"atk_light": 0.2,
					"atk_armor": 0.2,
					"atk_air": 0.2
				}
			}
		],
		"mech": [
			{
				"id": "burning_aura",
				"name": "燃烧光环",
				"kind": "aura_damage",
				"effect": "damage_aura",
				"params": {
					"damage": 30,
					"radius": 100
				}
			}
		],
		"todo": []
	},
	"enemy_master_003": {
		"num": [
			{
				"id": "first_thunder",
				"name": "初雷之印",
				"effects": {
					"crit_chance": 0.08,
					"dodge_chance": 0.05
				}
			}
		],
		"mech": [
			{
				"id": "overcharge",
				"name": "过载",
				"kind": "high_energy",
				"effect": "high_energy_bonus",
				"params": {
					"threshold": 0.8,
					"attack_speed_boost": 0.4
				}
			}
		],
		"todo": [
			{
				"id": "static_field",
				"name": "静电场",
				"kind": "todo",
				"effect": "splash_damage"
			}
		]
	},
	"enemy_master_004": {
		"num": [
			{
				"id": "void_sense",
				"name": "虚空初感",
				"effects": {
					"atk_light": 0.08,
					"atk_armor": 0.08,
					"atk_air": 0.08
				}
			}
		],
		"mech": [
			{
				"id": "entropy_aura",
				"name": "熵增光环",
				"kind": "aura_damage",
				"effect": "max_hp_drain",
				"params": {
					"drain_percent": 0.01,
					"radius": 150
				}
			}
		],
		"todo": [
			{
				"id": "phase_shift",
				"name": "相位移",
				"kind": "todo",
				"effect": "death_avoid_teleport"
			}
		]
	},
	"enemy_master_005": {
		"num": [
			{
				"id": "iron_wall_command",
				"name": "铁壁指挥",
				"effects": {
					"hp": 0.15,
					"def_light": 0.1,
					"def_armor": 0.1,
					"def_air": 0.1
				}
			},
			{
				"id": "formation_master",
				"name": "阵型大师",
				"effects": {
					"atk_light": 0.2,
					"atk_armor": 0.2,
					"atk_air": 0.2
				}
			}
		],
		"mech": [],
		"todo": [
			{
				"id": "siege_breaker",
				"name": "攻城破坏者",
				"kind": "todo",
				"effect": "damage_vs_building"
			}
		]
	},
	"enemy_master_006": {
		"num": [
			{
				"id": "flame_authority",
				"name": "炎之权柄",
				"effects": {
					"atk_light": 0.15,
					"atk_armor": 0.15,
					"atk_air": 0.15
				}
			}
		],
		"mech": [
			{
				"id": "eternal_flame",
				"name": "永恒之火",
				"kind": "death_explosion",
				"effect": "death_explosion",
				"params": {
					"damage": 200,
					"radius": 100
				}
			}
		],
		"todo": [
			{
				"id": "heat_wave",
				"name": "热浪",
				"kind": "todo",
				"effect": "scaling_damage"
			}
		]
	},
	"enemy_master_007": {
		"num": [
			{
				"id": "storm_child",
				"name": "风暴之子",
				"effects": {
					"atk_light": 0.08,
					"atk_armor": 0.08,
					"atk_air": 0.08
				}
			}
		],
		"mech": [],
		"todo": [
			{
				"id": "conductive",
				"name": "传导",
				"kind": "todo",
				"effect": "chain_attack"
			},
			{
				"id": "storm_caller",
				"name": "风暴召唤者",
				"kind": "todo",
				"effect": "full_energy_trigger"
			}
		]
	},
	"enemy_master_008": {
		"num": [
			{
				"id": "dimension_perception",
				"name": "维度感知",
				"effects": {
					"atk_light": 0.08,
					"atk_armor": 0.08,
					"atk_air": 0.08
				}
			}
		],
		"mech": [],
		"todo": [
			{
				"id": "reality_tear",
				"name": "现实撕裂",
				"kind": "todo",
				"effect": "armor_ignore_chance"
			},
			{
				"id": "void_embrace",
				"name": "虚空拥抱",
				"kind": "todo",
				"effect": "energy_drain"
			}
		]
	},
	"enemy_master_009": {
		"num": [
			{
				"id": "industrial_commander",
				"name": "工业统帅",
				"effects": {
					"hp": 0.15,
					"def_light": 0.1,
					"def_armor": 0.1,
					"def_air": 0.1
				}
			}
		],
		"mech": [],
		"todo": [
			{
				"id": "iron_will",
				"name": "钢铁意志",
				"kind": "todo",
				"effect": "low_hp_defense_boost"
			},
			{
				"id": "auto_production",
				"name": "自动化生产",
				"kind": "todo",
				"effect": "auto_production"
			}
		]
	},
	"enemy_master_010": {
		"num": [
			{
				"id": "eternal_inferno",
				"name": "永恒烈焰",
				"effects": {
					"atk_light": 0.15,
					"atk_armor": 0.15,
					"atk_air": 0.15
				}
			}
		],
		"mech": [
			{
				"id": "immolation",
				"name": "自焚",
				"kind": "aura_damage",
				"effect": "self_damage_aura",
				"params": {
					"aura_damage": 40,
					"self_damage": 15
				}
			}
		],
		"todo": [],
		"element": {
			"affinity": 1,
			"mult": 1.08
		}
	},
	"enemy_master_011": {
		"num": [
			{
				"id": "thunder_domination",
				"name": "雷霆主宰",
				"effects": {
					"atk_light": 0.15,
					"atk_armor": 0.15,
					"atk_air": 0.15
				}
			}
		],
		"mech": [],
		"todo": [
			{
				"id": "lightning_speed",
				"name": "闪电速度",
				"kind": "todo",
				"effect": "speed_boost"
			},
			{
				"id": "static_overload",
				"name": "静电过载",
				"kind": "todo",
				"effect": "death_chain_lightning"
			}
		]
	},
	"enemy_master_012": {
		"num": [
			{
				"id": "void_mastery",
				"name": "虚空精通",
				"effects": {
					"atk_light": 0.15,
					"atk_armor": 0.15,
					"atk_air": 0.15
				}
			}
		],
		"mech": [
			{
				"id": "dimension_siphon",
				"name": "维度虹吸",
				"kind": "aura_damage",
				"effect": "life_energy_drain",
				"params": {
					"hp_drain": 40,
					"energy_drain": 15
				}
			}
		],
		"todo": []
	},
	"enemy_master_013": {
		"num": [],
		"mech": [],
		"todo": [
			{
				"id": "heat_treatment",
				"name": "热处理",
				"kind": "todo",
				"effect": "proc_explosion"
			}
		],
		"element": {
			"affinity": 1,
			"mult": 1.1
		}
	},
	"enemy_master_014": {
		"num": [],
		"mech": [
			{
				"id": "conductive_armor",
				"name": "导电护甲",
				"kind": "thorn",
				"effect": "lightning_thorn",
				"params": {
					"thorn_damage": 60
				}
			},
			{
				"id": "overclock",
				"name": "超频",
				"kind": "high_energy",
				"effect": "high_energy_attack_speed",
				"params": {
					"threshold": 0.7,
					"speed_boost": 0.4
				}
			}
		],
		"todo": [
			{
				"id": "electromagnetic_armor",
				"name": "电磁装甲师",
				"kind": "todo",
				"effect": "trait:armor_reflect"
			}
		]
	},
	"enemy_master_015": {
		"num": [],
		"mech": [],
		"todo": [
			{
				"id": "chaos_flame_trait",
				"name": "熵增炎魔",
				"kind": "todo",
				"effect": "trait:burn_energy_drain_mult"
			},
			{
				"id": "entropy_flame",
				"name": "熵增之火",
				"kind": "todo",
				"effect": "fire_lifesteal_chance"
			},
			{
				"id": "void_burn",
				"name": "虚空燃烧",
				"kind": "todo",
				"effect": "burn_slow"
			}
		]
	},
	"enemy_master_016": {
		"num": [],
		"mech": [],
		"todo": [
			{
				"id": "immortal_will",
				"name": "不朽意志",
				"kind": "todo",
				"effect": "trait:damage_cap,unit_count_defense"
			},
			{
				"id": "unbreakable",
				"name": "不可破坏",
				"kind": "todo",
				"effect": "damage_cap"
			},
			{
				"id": "steel_mountain",
				"name": "钢铁之山",
				"kind": "todo",
				"effect": "unit_count_defense"
			}
		]
	},
	"enemy_master_017": {
		"num": [
			{
				"id": "ragnarok",
				"name": "诸神黄昏",
				"effects": {
					"atk_light": 0.15,
					"atk_armor": 0.15,
					"atk_air": 0.15
				}
			}
		],
		"mech": [
			{
				"id": "time_based_hp_drain",
				"name": "热寂",
				"kind": "aura_damage",
				"effect": "time_based_hp_drain",
				"params": {
					"interval": 30.0,
					"drain_percent": 0.08
				}
			}
		],
		"todo": [
			{
				"id": "phoenix_rebirth_auto",
				"name": "凤凰重生",
				"kind": "todo",
				"effect": "phoenix_rebirth_auto"
			}
		]
	},
	"enemy_master_018": {
		"num": [
			{
				"id": "thunder_avatar",
				"name": "万钧雷霆",
				"effects": {
					"atk_light": 0.15,
					"atk_armor": 0.15,
					"atk_air": 0.15
				}
			},
			{
				"id": "global_damage_boost",
				"name": "导电世界",
				"effects": {
					"atk_light": 0.2,
					"atk_armor": 0.2,
					"atk_air": 0.2
				}
			}
		],
		"mech": [],
		"todo": [
			{
				"id": "auto_lightning",
				"name": "无处不在的闪电",
				"kind": "todo",
				"effect": "auto_lightning"
			}
		]
	},
	"enemy_master_019": {
		"num": [
			{
				"id": "world_devourer",
				"name": "世界吞噬者",
				"effects": {
					"atk_light": 0.15,
					"atk_armor": 0.15,
					"atk_air": 0.15
				}
			}
		],
		"mech": [],
		"todo": [
			{
				"id": "void_lord",
				"name": "虚空领主",
				"kind": "todo",
				"effect": "void_mastery_ultimate"
			},
			{
				"id": "enemy_defense_reduction",
				"name": "现实崩溃",
				"kind": "todo",
				"effect": "enemy_defense_reduction"
			}
		]
	},
	"enemy_master_020": {
		"num": [],
		"mech": [],
		"todo": [
			{
				"id": "em_war_god",
				"name": "电磁战神",
				"kind": "todo",
				"effect": "trait:deploy_shield"
			},
			{
				"id": "armor_chain_lightning",
				"name": "雷霆护甲",
				"kind": "todo",
				"effect": "armor_chain_lightning"
			}
		]
	},
	"enemy_master_021": {
		"num": [],
		"mech": [],
		"todo": [
			{
				"id": "chaos_inferno_trait",
				"name": "混沌炎魔",
				"kind": "todo",
				"effect": "trait:dual_damage_chance"
			},
			{
				"id": "immunity",
				"name": "混沌免疫",
				"kind": "todo",
				"effect": "immunity"
			}
		],
		"element": {
			"affinity": 1,
			"mult": 1.08
		}
	},
	"enemy_master_022": {
		"num": [],
		"mech": [],
		"todo": [
			{
				"id": "automated_warfare",
				"name": "自动化战争",
				"kind": "todo",
				"effect": "trait:auto_spawn_interval,time_scaling"
			},
			{
				"id": "automation",
				"name": "自动化",
				"kind": "todo",
				"effect": "auto_production_fast"
			},
			{
				"id": "modular_upgrade",
				"name": "模块化升级",
				"kind": "todo",
				"effect": "time_based_upgrade"
			}
		]
	},
	"enemy_master_023": {
		"num": [],
		"mech": [],
		"todo": [
			{
				"id": "phoenix_trait",
				"name": "不死鸟",
				"kind": "todo",
				"effect": "trait:fire_cooldown_reduction,full_resurrect_once"
			},
			{
				"id": "fire_mastery",
				"name": "火焰精通",
				"kind": "todo",
				"effect": "elemental_mastery"
			},
			{
				"id": "ignite",
				"name": "点燃",
				"kind": "todo",
				"effect": "ignite_chance"
			}
		]
	},
	"enemy_master_024": {
		"num": [
			{
				"id": "storm_rush",
				"name": "超级突袭",
				"effects": {
					"atk_light": 0.08,
					"atk_armor": 0.08,
					"atk_air": 0.08
				}
			}
		],
		"mech": [],
		"todo": [
			{
				"id": "storm_speed",
				"name": "风暴骑手",
				"kind": "todo",
				"effect": "storm_speed"
			},
			{
				"id": "periodic_electric_shock",
				"name": "电场",
				"kind": "todo",
				"effect": "periodic_electric_shock"
			}
		]
	},
	"enemy_master_025": {
		"num": [
			{
				"id": "shadow_realm",
				"name": "暗影领域",
				"effects": {
					"atk_light": 0.15,
					"atk_armor": 0.15,
					"atk_air": 0.15
				}
			}
		],
		"mech": [],
		"todo": [
			{
				"id": "teleport_behind",
				"name": "暗影步",
				"kind": "todo",
				"effect": "teleport_behind"
			},
			{
				"id": "execute_damage",
				"name": "暗杀",
				"kind": "todo",
				"effect": "execute_damage"
			}
		]
	},
	"enemy_master_026": {
		"num": [],
		"mech": [
			{
				"id": "massive_heal_aura",
				"name": "神之光环",
				"kind": "aura_heal",
				"effect": "massive_heal_aura",
				"params": {
					"heal_percent": 0.04,
					"radius": 250
				}
			}
		],
		"todo": [
			{
				"id": "divine_forging",
				"name": "神圣锻造",
				"kind": "todo",
				"effect": "trait:divine_transform"
			},
			{
				"id": "cheat_death",
				"name": "神之庇护",
				"kind": "todo",
				"effect": "trait:cheat_death_chance"
			}
		]
	},
	"enemy_master_027": {
		"num": [
			{
				"id": "hell_queen",
				"name": "炼狱女王",
				"effects": {
					"atk_light": 0.15,
					"atk_armor": 0.15,
					"atk_air": 0.15
				}
			}
		],
		"mech": [],
		"todo": [
			{
				"id": "global_burn",
				"name": "世界燃烧",
				"kind": "todo",
				"effect": "trait:global_dot"
			},
			{
				"id": "auto_resurrect",
				"name": "不朽之火",
				"kind": "todo",
				"effect": "auto_resurrect"
			},
			{
				"id": "global_dot",
				"name": "世界燃烧",
				"kind": "todo",
				"effect": "global_dot"
			}
		]
	},
	"enemy_master_028": {
		"num": [
			{
				"id": "god_of_thunder",
				"name": "雷霆之神",
				"effects": {
					"atk_light": 0.15,
					"atk_armor": 0.15,
					"atk_air": 0.15
				}
			}
		],
		"mech": [
			{
				"id": "lightning_aura_028",
				"name": "雷暴光环",
				"kind": "aura_damage",
				"effect": "lightning_aura",
				"params": {
					"damage_mult": 1.0
				}
			}
		],
		"todo": [
			{
				"id": "thunder_dome",
				"name": "雷霆穹顶",
				"kind": "todo",
				"effect": "trait:auto_thunder_dome"
			}
		],
		"element": {
			"affinity": 2,
			"mult": 1.12
		}
	},
	"enemy_master_029": {
		"num": [],
		"mech": [],
		"todo": [
			{
				"id": "void_goddess_trait",
				"name": "夜之女神",
				"kind": "todo",
				"effect": "trait:permanent_darkness,mass_convert_once"
			},
			{
				"id": "reality_erasure",
				"name": "现实抹除",
				"kind": "todo",
				"effect": "trait:instant_delete"
			},
			{
				"id": "permanent_darkness",
				"name": "永恒之夜",
				"kind": "todo",
				"effect": "permanent_darkness"
			}
		],
		"element": {
			"affinity": 3,
			"mult": 2.0
		}
	},
	"enemy_master_030": {
		"num": [
			{
				"id": "master_of_all",
				"name": "万物主宰",
				"effects": {
					"atk_light": 0.15,
					"atk_armor": 0.15,
					"atk_air": 0.15
				}
			},
			{
				"id": "infinite_potential",
				"name": "无限潜能",
				"effects": {
					"hp": 0.15,
					"def_light": 0.1,
					"def_armor": 0.1,
					"def_air": 0.1
				}
			}
		],
		"mech": [],
		"todo": [
			{
				"id": "infinite_scaling",
				"name": "无限潜能",
				"kind": "todo",
				"effect": "infinite_scaling"
			}
		],
		"element": {
			"affinity": 3,
			"mult": 1.15
		}
	},
}


## 取组合视图（driver 消费）：数值/机制/元素节点。
## v18.c：等级属性通道移除（换 flat 统一，走 CardGrowthConfig，driver._apply_master_level_flat）。
## level 参数保留供元素稀有度等未来用途，当前不参与派生。
static func get_composition(master_id: String, level: int) -> Dictionary:
	var entry: Dictionary = MASTER_NODES.get(master_id, {})
	return {
		"num": (entry.get("num", []) as Array).duplicate(true),
		"mech": (entry.get("mech", []) as Array).duplicate(true),
		"todo": (entry.get("todo", []) as Array).duplicate(true),
		"element": (entry.get("element", {}) as Dictionary).duplicate(true),
	}


## 供 engine 消费的机制节点（只投递已实现 kind；todo 不投递 = 保持现状空转）
static func get_delivered_mech_nodes(master_id: String) -> Array:
	var entry: Dictionary = MASTER_NODES.get(master_id, {})
	return (entry.get("mech", []) as Array).duplicate(true)


## 效果 key 收集（patterns 套路派生兜底用；替代原 master_config.traits/passive 读法）
static func get_effect_keys(master_id: String) -> Array:
	var entry: Dictionary = MASTER_NODES.get(master_id, {})
	var keys: Array = []
	for n in entry.get("num", []):
		for k in n.get("effects", {}):
			if not keys.has(k):
				keys.append(k)
	for n in entry.get("mech", []):
		var e: String = String(n.get("effect", ""))
		if not e.is_empty() and not keys.has(e):
			keys.append(e)
	return keys
