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
				"description": "三维攻击+15%",
				"effects": {"atk_light": 0.15, "atk_armor": 0.15, "atk_air": 0.15}
			}
		],
		"active_spells": [],
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
			"phase_instrument": "pi_void_04",
			"level": 28,
			"platforms": ["fut_boss_nexus", "fut_arm_colossus_e", "fut_arm_colossus_e", "fut_arm_mech_e", "fut_inf_spectre_e", "fut_air_drone"],
			"weapons": ["void_lance_expert", "entropy_caster_expert"],
			"energy_cards": ["void_energy_expert"]
		},
		"stats": {
			"max_hp": 22950,
			"attack_power": 315,
			"defense": 41,
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
		"active_spells": [],
		"passive_spells": [
			{
				"id": "massive_heal_aura",
				"name": "神之光环",
				"description": "周围友军每秒恢复4%最大生命值",
				"effect": "massive_heal_aura",
				"params": {"heal_percent": 0.04, "radius": 250}
			}
		],
		"equipment": {
			"phase_instrument": "pi_steel_05",
			"level": 28,
			"platforms": ["fut_boss_nexus", "fut_arm_colossus_e", "fut_arm_colossus_e", "fut_arm_hovertank_e", "fut_arm_mech_e", "fut_inf_cyborg"],
			"weapons": ["steel_gatling_expert", "steel_artillery_expert"],
			"energy_cards": ["steel_energy_god"]
		},
		"stats": {
			"max_hp": 22950,
			"attack_power": 315,
			"defense": 76,
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
				"description": "三维攻击+15%；全队单位死亡后3秒自动复活(50%HP)",
				"effects": {"atk_light": 0.15, "atk_armor": 0.15, "atk_air": 0.15, "auto_resurrect": {"delay": 3.0, "hp": 0.50}}
			},
			{
				"id": "global_burn",
				"name": "世界燃烧",
				"description": "每秒对所有敌人造成150伤害",
				"effects": {"global_dot": 150}
			}
		],
		"active_spells": [],
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
			"phase_instrument": "pi_flame_05",
			"level": 29,
			"platforms": ["fut_arm_colossus_e", "fut_arm_hovertank_e", "fut_boss_nexus", "fut_inf_spectre_e", "fut_arm_mech_e"],
			"weapons": ["flame_thrower_expert", "plasma_cannon_expert"],
			"energy_cards": ["flame_energy_god"]
		},
		"stats": {
			"max_hp": 23200,
			"attack_power": 320,
			"defense": 50,
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
				"description": "三维攻击+15%",
				"effects": {"atk_light": 0.15, "atk_armor": 0.15, "atk_air": 0.15}
			},
			{
				"id": "thunder_dome",
				"name": "雷霆穹顶",
				"description": "每60秒自动展开雷霆穹顶，保护友军5秒",
				"effects": {"auto_thunder_dome": {"interval": 60.0, "duration": 5.0}}
			}
		],
		"active_spells": [],
		"passive_spells": [],
		"equipment": {
			"phase_instrument": "pi_thunder_05",
			"level": 29,
			"platforms": ["fut_boss_nexus", "fut_boss_nexus", "fut_arm_colossus_e", "fut_arm_hovertank_e", "fut_inf_spectre_e", "fut_air_drone"],
			"weapons": ["tesla_coil_expert", "railgun_expert"],
			"energy_cards": ["thunder_energy_god"]
		},
		"stats": {
			"max_hp": 23200,
			"attack_power": 320,
			"defense": 50,
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
		"active_spells": [],
		"passive_spells": [
			{
				"id": "goddess_mastery",
				"name": "虚空女神",
				"description": "三维攻击+15%",
				"effect": "goddess_mastery",
				"params": {"damage_boost": 0.15}
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
			"phase_instrument": "pi_void_05",
			"level": 30,
			"platforms": ["fut_inf_cyborg", "fut_arm_hovertank_e", "fut_boss_nexus", "fut_inf_spectre_e", "fut_arm_colossus_e", "fut_air_drone"],
			"weapons": ["void_lance_expert", "entropy_caster_expert"],
			"energy_cards": ["void_energy_god"]
		},
		"stats": {
			"max_hp": 23450,
			"attack_power": 325,
			"defense": 44,
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
				"description": "三维攻击+15%",
				"effects": {"atk_light": 0.15, "atk_armor": 0.15, "atk_air": 0.15}
			},
			{
				"id": "infinite_potential",
				"name": "无限潜能",
				"description": "HP+15%，三维防御+10%",
				"effects": {"hp": 0.15, "def_light": 0.10, "def_armor": 0.10, "def_air": 0.10}
			}
		],
		"active_spells": [],
		"passive_spells": [
			{
				"id": "omni_mastery",
				"name": "万物主宰",
				"description": "三维攻击+15%",
				"effect": "omni_mastery",
				"params": {"damage_boost": 0.15}
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
			"phase_instrument": "pi_omega_01",
			"level": 30,
			"platforms": ["fut_boss_nexus", "fut_boss_nexus", "fut_arm_colossus_e", "fut_arm_colossus_e", "fut_arm_hovertank_e", "fut_arm_mech_e"],
			"weapons": ["railgun_expert", "plasma_cannon_expert"],
			"energy_cards": ["hybrid_energy_god"]
		},
		"stats": {
			"max_hp": 23450,
			"attack_power": 325,
			"defense": 47,
			"energy_regen": 8.0,
			"unit_limit": 15
		}
	}
]
