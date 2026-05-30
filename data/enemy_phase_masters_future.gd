extends RefCounted
class_name EnemyPhaseMastersNEARFUTURE

## 敌方相位师资料 - 近未来时代 (enemy_master_025 ~ enemy_master_030)
## 由 enemy_phase_masters.gd 拆分，按时代组织
## 所有装备引用均来自 EnemyPhaseEquipment 的有效ID

const ERA_MASTERS: Array = [
	{
		"id": "enemy_master_025",
		"name": "暗影主宰·深渊",
		"title": "暗影之王",
		"level": 28,
		"faction": "void",
		"difficulty": "legendary",
		"traits": [
			{
				"id": "shadow_realm",
				"name": "暗影领域",
				"description": "暗影中敌人受到伤害+50%；背刺伤害+200%",
				"effects": {"darkness_damage_boost": 0.50, "backstab_damage_boost": 2.0}
			}
		],
		"active_spells": [
			{
				"id": "shadow_clones",
				"name": "暗影军团",
				"description": "召唤8个暗影分身，持续时间15秒",
				"cooldown": 35.0,
				"mana_cost": 220,
				"effect": "shadow_clones",
				"params": {"count": 8, "duration": 15.0}
			},
			{
				"id": "eclipse",
				"name": "日蚀",
				"description": "战场陷入黑暗，敌人命中率降低40%",
				"cooldown": 40.0,
				"mana_cost": 180,
				"effect": "darkness_debuff",
				"params": {"accuracy_reduction": 0.4, "duration": 10.0}
			}
		],
		"passive_spells": [
			{
				"id": "teleport_behind",
				"name": "暗影步",
				"description": "友军可以瞬间移动到敌人身后",
				"effect": "teleport_behind",
				"params": {"cooldown": 8.0}
			},
			{
				"id": "execute_damage",
				"name": "暗杀",
				"description": "攻击低生命值敌人时，伤害提升100%",
				"effect": "execute_damage",
				"params": {"threshold": 0.3, "damage_boost": 1.0}
			}
		],
		"equipment": {
			"phase_instrument": "void_walker_mk4",
			"level": 28,
			"platforms": ["void_stealth_expert", "void_mage_expert"],
			"weapons": ["void_lance_expert", "entropy_caster_expert"],
			"energy_cards": ["void_energy_expert"]
		},
		"stats": {
			"max_hp": 4500,
			"attack_power": 580,
			"defense": 80,
			"energy_regen": 4.5,
			"unit_limit": 7
		}
	},

	# ==================== Tier 6 - 神级相位师 (Lv28-30) ====================
	{
		"id": "enemy_master_026",
		"name": "钢铁之神·赫淮斯托斯",
		"title": "锻造之神",
		"level": 28,
		"faction": "steel",
		"difficulty": "legendary",
		"traits": [
			{
				"id": "divine_forging",
				"name": "神圣锻造",
				"description": "每场战斗可使用一次神圣变身：全队全属性+80%持续15秒",
				"effects": {"divine_transform": {"duration": 15.0, "all_stat_boost": 0.80}}
			},
			{
				"id": "cheat_death",
				"name": "神之庇护",
				"description": "友军受到致命伤害时，有40%概率保留1点生命值（每单位一次）",
				"effects": {"cheat_death_chance": 0.40}
			}
		],
		"active_spells": [
			{
				"id": "divine_transformation",
				"name": "神圣锻造",
				"description": "将所有友军转化为神圣形态，全属性提升80%",
				"cooldown": 90.0,
				"mana_cost": 600,
				"effect": "divine_transformation",
				"params": {"duration": 15.0, "stat_boost": 0.8}
			},
			{
				"id": "terrain_forge",
				"name": "世界锻造",
				"description": "重塑战场地形，创造3个钢铁堡垒",
				"cooldown": 120.0,
				"mana_cost": 800,
				"effect": "terrain_forge",
				"params": {"fortress_count": 3}
			}
		],
		"passive_spells": [
			{
				"id": "cheat_death_chance",
				"name": "神圣庇护",
				"description": "友军受到致命伤害时，有40%概率保留1点生命值",
				"effect": "cheat_death_chance",
				"params": {"chance": 0.4}
			},
			{
				"id": "massive_heal_aura",
				"name": "神之光环",
				"description": "周围友军每秒恢复4%最大生命值",
				"effect": "massive_heal_aura",
				"params": {"heal_percent": 0.04, "radius": 250}
			}
		],
		"equipment": {
			"phase_instrument": "steel_guardian_god",
			"level": 28,
			"platforms": ["steel_fortress_expert", "steel_titan_expert"],
			"weapons": ["steel_gatling_expert", "steel_artillery_expert"],
			"energy_cards": ["steel_energy_god"]
		},
		"stats": {
			"max_hp": 7000,
			"attack_power": 550,
			"defense": 230,
			"energy_regen": 4.0,
			"unit_limit": 12
		}
	},
	{
		"id": "enemy_master_027",
		"name": "炎魔之神·赫卡特",
		"title": "炼狱女王",
		"level": 29,
		"faction": "flame",
		"difficulty": "legendary",
		"traits": [
			{
				"id": "hell_queen",
				"name": "炼狱女王",
				"description": "火焰伤害+60%；全队单位死亡后3秒自动复活(50%HP)",
				"effects": {"fire_damage_boost": 0.60, "auto_resurrect": {"delay": 3.0, "hp": 0.50}}
			},
			{
				"id": "global_burn",
				"name": "世界燃烧",
				"description": "每秒对所有敌人造成150伤害",
				"effects": {"global_dot": 150}
			}
		],
		"active_spells": [
			{
				"id": "hell_terrain",
				"name": "地狱降临",
				"description": "将整个战场变为地狱环境，持续造成毁灭性伤害",
				"cooldown": 100.0,
				"mana_cost": 700,
				"effect": "hell_terrain",
				"params": {"damage": 400, "duration": 15.0}
			},
			{
				"id": "full_resurrect_all",
				"name": "凤凰涅槃",
				"description": "完全复活所有死亡单位，并恢复70%生命值",
				"cooldown": 150.0,
				"mana_cost": 1000,
				"effect": "full_resurrect_all",
				"params": {"hp_percent": 0.7}
			}
		],
		"passive_spells": [
			{
				"id": "auto_resurrect",
				"name": "不朽之火",
				"description": "友军不会真正死亡，而是3秒后复活",
				"effect": "auto_resurrect",
				"params": {"resurrect_delay": 3.0, "resurrect_hp": 0.5}
			},
			{
				"id": "global_dot",
				"name": "世界燃烧",
				"description": "每秒对所有敌人造成150伤害",
				"effect": "global_dot",
				"params": {"damage": 150}
			}
		],
		"equipment": {
			"phase_instrument": "flame_destroyer_god",
			"level": 29,
			"platforms": ["flame_raider_expert", "flame_siege_expert"],
			"weapons": ["flame_thrower_expert", "plasma_cannon_expert"],
			"energy_cards": ["flame_energy_god"]
		},
		"stats": {
			"max_hp": 6500,
			"attack_power": 750,
			"defense": 140,
			"energy_regen": 4.5,
			"unit_limit": 11
		}
	},
	{
		"id": "enemy_master_028",
		"name": "雷神·托尔",
		"title": "雷霆之神",
		"level": 29,
		"faction": "thunder",
		"difficulty": "legendary",
		"traits": [
			{
				"id": "god_of_thunder",
				"name": "雷霆之神",
				"description": "雷电伤害+150%，技能冷却-40%，能量消耗-60%",
				"effects": {"lightning_damage_boost": 1.50, "cooldown_reduction": 0.40, "energy_cost_reduction": 0.60}
			},
			{
				"id": "thunder_dome",
				"name": "雷霆穹顶",
				"description": "每60秒自动展开雷霆穹顶，保护友军5秒",
				"effects": {"auto_thunder_dome": {"interval": 60.0, "duration": 5.0}}
			}
		],
		"active_spells": [
			{
				"id": "god_weapon_attack",
				"name": "雷神之锤",
				"description": "投掷雷神之锤，造成1500伤害并瘫痪所有敌人4秒",
				"cooldown": 80.0,
				"mana_cost": 800,
				"effect": "god_weapon_attack",
				"params": {"damage": 1500, "stun_duration": 4.0}
			},
			{
				"id": "thunder_dome_shield",
				"name": "雷霆穹顶",
				"description": "创造无敌雷霆穹顶，保护所有友军并电击敌人",
				"cooldown": 60.0,
				"mana_cost": 600,
				"effect": "thunder_dome_shield",
				"params": {"duration": 12.0, "shock_damage": 250}
			}
		],
		"passive_spells": [
			{
				"id": "god_mastery",
				"name": "雷霆之神",
				"description": "所有雷电伤害提升150%，冷却时间减少40%",
				"effect": "god_mastery",
				"params": {"damage_boost": 1.5, "cooldown_reduction": 0.4, "element": "lightning"}
			},
			{
				"id": "energy_cost_reduction",
				"name": "无限能量",
				"description": "能量消耗减少60%",
				"effect": "energy_cost_reduction",
				"params": {"reduction": 0.6}
			}
		],
		"equipment": {
			"phase_instrument": "thunder_storm_god",
			"level": 29,
			"platforms": ["thunter_striker_expert", "thunter_sniper_expert"],
			"weapons": ["tesla_coil_expert", "railgun_expert"],
			"energy_cards": ["thunder_energy_god"]
		},
		"stats": {
			"max_hp": 6000,
			"attack_power": 850,
			"defense": 130,
			"energy_regen": 6.0,
			"unit_limit": 10
		}
	},
	{
		"id": "enemy_master_029",
		"name": "虚空女神·尼克斯",
		"title": "夜之女神",
		"level": 30,
		"faction": "void",
		"difficulty": "legendary",
		"traits": [
			{
				"id": "void_goddess_trait",
				"name": "夜之女神",
				"description": "虚空伤害+200%；永久黑暗(敌方命中率-60%)；可转化1个敌方单位",
				"effects": {"void_damage_boost": 2.0, "permanent_darkness": 0.60, "mass_convert_once": true}
			},
			{
				"id": "reality_erasure",
				"name": "现实抹除",
				"description": "每90秒可抹除1个敌方单位",
				"effects": {"instant_delete": {"cooldown": 90.0}}
			}
		],
		"active_spells": [
			{
				"id": "mass_conversion",
				"name": "虚空转化",
				"description": "将生命值最低的敌方单位转化为虚空生物",
				"cooldown": 120.0,
				"mana_cost": 900,
				"effect": "mass_conversion",
				"params": {"duration": 12.0, "target_count": 2}
			},
			{
				"id": "instant_delete",
				"name": "现实抹除",
				"description": "抹除一个敌方单位的存在",
				"cooldown": 90.0,
				"mana_cost": 700,
				"effect": "instant_delete",
				"params": {"cast_time": 2.0}
			}
		],
		"passive_spells": [
			{
				"id": "goddess_mastery",
				"name": "虚空女神",
				"description": "所有虚空技能伤害提升200%",
				"effect": "goddess_mastery",
				"params": {"damage_boost": 2.0}
			},
			{
				"id": "permanent_darkness",
				"name": "永恒之夜",
				"description": "战场永远保持黑暗状态，敌人命中率降低60%",
				"effect": "permanent_darkness",
				"params": {"accuracy_reduction": 0.6}
			}
		],
		"equipment": {
			"phase_instrument": "void_walker_god",
			"level": 30,
			"platforms": ["void_stealth_expert", "void_mage_expert"],
			"weapons": ["void_lance_expert", "entropy_caster_expert"],
			"energy_cards": ["void_energy_god"]
		},
		"stats": {
			"max_hp": 5800,
			"attack_power": 800,
			"defense": 110,
			"energy_regen": 5.5,
			"unit_limit": 9
		}
	},

	# ==================== Tier 7 - 终极相位师 (Lv30) ====================
	{
		"id": "enemy_master_030",
		"name": "全能相位师·奥米伽",
		"title": "完美融合",
		"level": 30,
		"faction": "all",
		"difficulty": "ultimate",
		"traits": [
			{
				"id": "master_of_all",
				"name": "万物主宰",
				"description": "所有伤害类型+80%，所有抗性+40%，每使用技能全属性+8%(无上限)",
				"effects": {"all_damage_boost": 0.80, "all_resistance_boost": 0.40, "scaling_per_cast": 0.08}
			},
			{
				"id": "infinite_potential",
				"name": "无限潜能",
				"description": "能量回复+100%，单位上限+3",
				"effects": {"energy_regen_boost": 1.0, "unit_limit_bonus": 3}
			}
		],
		"active_spells": [
			{
				"id": "perfect_fusion",
				"name": "完美和谐",
				"description": "融合所有势力力量，全属性提升150%",
				"cooldown": 120.0,
				"mana_cost": 1000,
				"effect": "perfect_fusion",
				"params": {"duration": 25.0, "all_boost": 1.5}
			},
			{
				"id": "combo_ultimate",
				"name": "奥米茄打击",
				"description": "释放所有势力的终极技能，造成毁灭性伤害",
				"cooldown": 180.0,
				"mana_cost": 1500,
				"effect": "combo_ultimate",
				"params": {"skill_count": 4}
			}
		],
		"passive_spells": [
			{
				"id": "omni_mastery",
				"name": "万物主宰",
				"description": "所有伤害类型提升80%，所有抗性提升40%",
				"effect": "omni_mastery",
				"params": {"damage_boost": 0.8, "resistance_boost": 0.4}
			},
			{
				"id": "infinite_scaling",
				"name": "无限潜能",
				"description": "每使用一个技能，所有属性提升8%，无上限",
				"effect": "infinite_scaling",
				"params": {"boost_per_cast": 0.08}
			}
		],
		"equipment": {
			"phase_instrument": "omega_instrument",
			"level": 30,
			"platforms": ["steel_titan_expert", "flame_siege_expert"],
			"weapons": ["railgun_expert", "plasma_cannon_expert"],
			"energy_cards": ["hybrid_energy_god"]
		},
		"stats": {
			"max_hp": 10000,
			"attack_power": 1000,
			"defense": 200,
			"energy_regen": 8.0,
			"unit_limit": 15
		}
	}
]
