extends RefCounted
class_name EnemyPhaseMastersWW2

## 敌方相位师资料 - 二战时代 (enemy_master_007 ~ enemy_master_012)
## 由 enemy_phase_masters.gd 拆分，按时代组织
## 所有装备引用均来自 EnemyPhaseEquipment 的有效ID

const ERA_MASTERS: Array = [
	{
		"id": "enemy_master_007",
		"name": "雷神之子·索尔",
		"title": "万钧雷霆",
		"level": 13,
		"faction": "thunder",
		"difficulty": "hard",
		"traits": [
			{
				"id": "storm_child",
				"name": "风暴之子",
				"description": "三维攻击+8%",
				"effects": {"atk_light": 0.08, "atk_armor": 0.08, "atk_air": 0.08}
			}
		],
		"active_spells": [
			{
				"id": "thunderstorm_chain",
				"name": "雷暴连锁",
				"description": "每20秒释放连锁闪电，跳跃打击玩家单位",
				"effect": "thunderstorm_chain",
				"cooldown": 20.0,
				"params": {"damage_mult": 1.0}
			}
		],
		"passive_spells": [
			{
				"id": "conductive",
				"name": "传导",
				"description": "友军攻击时，电流会在敌人间跳跃",
				"effect": "chain_attack",
				"params": {"jump_count": 2, "jump_damage": 80}
			},
			{
				"id": "storm_caller",
				"name": "风暴召唤者",
				"description": "能量满时自动释放闪电链，不消耗能量",
				"effect": "full_energy_trigger",
				"params": {"trigger_spell": "chain_lightning"}
			}
		],
		"equipment": {
			"phase_instrument": "pi_thunder_03",
			"level": 13,
			"platforms": ["ww1_boss_av7", "ww1_boss_av7", "ww1_arm_rolls_e", "ww1_sup_mg_nest"],
			"weapons": ["tesla_coil_advanced", "railgun_advanced"],
			"energy_cards": ["thunder_energy_advanced"]
		},
		"stats": {
			"max_hp": 5200,
			"attack_power": 73,
			"defense": 32,
			"energy_regen": 3.5,
			"unit_limit": 6
		}
	},
	{
		"id": "enemy_master_008",
		"name": "虚空领主·萨洛斯",
		"title": "维度撕裂者",
		"level": 14,
		"faction": "void",
		"difficulty": "hard",
		"traits": [
			{
				"id": "dimension_perception",
				"name": "维度感知",
				"description": "三维攻击+8%",
				"effects": {"atk_light": 0.08, "atk_armor": 0.08, "atk_air": 0.08}
			}
		],
		"active_spells": [
			{
				"id": "void_implosion",
				"name": "虚空内爆",
				"description": "每22秒引发虚空坍缩，对全体玩家单位造成范围伤害",
				"effect": "void_explosion",
				"cooldown": 22.0,
				"params": {"damage_mult": 1.0}
			}
		],
		"passive_spells": [
			{
				"id": "reality_tear",
				"name": "现实撕裂",
				"description": "攻击有20%概率无视敌人护甲",
				"effect": "armor_ignore_chance",
				"params": {"chance": 0.2}
			},
			{
				"id": "void_embrace",
				"name": "虚空拥抱",
				"description": "周围敌人每秒失去5%能量",
				"effect": "energy_drain",
				"params": {"drain_percent": 0.05, "radius": 200}
			}
		],
		"equipment": {
			"phase_instrument": "pi_void_03",
			"level": 14,
			"platforms": ["ww2_boss_kingtiger", "ww2_arm_panther_e", "ww2_arm_panther_e", "ww2_inf_panzerschreck_e", "ww2_inf_para_e"],
			"weapons": ["void_lance_advanced", "gravity_well_advanced"],
			"energy_cards": ["void_energy_advanced"]
		},
		"stats": {
			"max_hp": 5250,
			"attack_power": 74,
			"defense": 34,
			"energy_regen": 3.8,
			"unit_limit": 6
		}
	},

	# ==================== Tier 3 - 高级相位师 (Lv16-19) ====================
	{
		"id": "enemy_master_009",
		"name": "钢铁军团长·费米",
		"title": "钢铁军团统帅",
		"level": 16,
		"faction": "steel",
		"difficulty": "hard",
		"traits": [
			{
				"id": "industrial_commander",
				"name": "工业统帅",
				"description": "HP+15%，三维防御+10%",
				"effects": {"hp": 0.15, "def_light": 0.10, "def_armor": 0.10, "def_air": 0.10}
			}
		],
		"active_spells": [
			{
				"id": "legion_deploy",
				"name": "军团动员",
				"description": "每19秒召唤钢铁军团单位增援",
				"effect": "deploy_legion",
				"cooldown": 19.0
			}
		],
		"passive_spells": [
			{
				"id": "iron_will",
				"name": "钢铁意志",
				"description": "友军生命值低于30%时，防御翻倍",
				"effect": "low_hp_defense_boost",
				"params": {"threshold": 0.3, "defense_multiplier": 2.0}
			},
			{
				"id": "auto_production",
				"name": "自动化生产",
				"description": "每12秒自动生产一个额外单位",
				"effect": "auto_production",
				"params": {"interval": 12.0}
			}
		],
		"equipment": {
			"phase_instrument": "pi_steel_04",
			"level": 16,
			"platforms": ["ww2_boss_kingtiger", "ww2_boss_kingtiger", "ww2_arm_panther_e", "ww2_inf_panzerschreck_e", "ww2_inf_para_e"],
			"weapons": ["steel_gatling_expert", "steel_artillery_expert"],
			"energy_cards": ["steel_energy_expert"]
		},
		"stats": {
			"max_hp": 5400,
			"attack_power": 78,
			"defense": 46,
			"energy_regen": 3.0,
			"unit_limit": 8
		}
	},
	{
		"id": "enemy_master_010",
		"name": "炎帝·普罗米修斯",
		"title": "永恒烈焰",
		"level": 17,
		"faction": "flame",
		"difficulty": "hard",
		"traits": [
			{
				"id": "eternal_inferno",
				"name": "永恒烈焰",
				"description": "三维攻击+15%",
				"effects": {"atk_light": 0.15, "atk_armor": 0.15, "atk_air": 0.15}
			}
		],
		"active_spells": [
			{
				"id": "prometheus_flame",
				"name": "普罗米修斯之焰",
				"description": "每18秒降下天火，对全体玩家单位造成烈焰伤害",
				"effect": "meteor_flame",
				"cooldown": 18.0,
				"params": {"damage_mult": 1.1}
			}
		],
		"passive_spells": [
			{
				"id": "hellfire",
				"name": "地狱火",
				"description": "友军攻击力提升8%",
				"effect": "elemental_damage_boost",
				"params": {"boost": 0.08, "element": "fire"}
			},
			{
				"id": "immolation",
				"name": "自焚",
				"description": "友军每秒对周围造成40伤害，自身失去15生命值",
				"effect": "self_damage_aura",
				"params": {"aura_damage": 40, "self_damage": 15}
			}
		],
		"equipment": {
			"phase_instrument": "pi_flame_04",
			"level": 17,
			"platforms": ["ww2_arm_panther_e", "ww2_inf_panzerschreck_e", "ww2_boss_kingtiger", "ww2_inf_para_e"],
			"weapons": ["flame_thrower_expert", "plasma_cannon_expert"],
			"energy_cards": ["flame_energy_expert"]
		},
		"stats": {
			"max_hp": 5450,
			"attack_power": 79,
			"defense": 30,
			"energy_regen": 3.5,
			"unit_limit": 8
		}
	},
	{
		"id": "enemy_master_011",
		"name": "雷皇·宙斯",
		"title": "雷霆主宰",
		"level": 18,
		"faction": "thunder",
		"difficulty": "hard",
		"traits": [
			{
				"id": "thunder_domination",
				"name": "雷霆主宰",
				"description": "三维攻击+15%",
				"effects": {"atk_light": 0.15, "atk_armor": 0.15, "atk_air": 0.15}
			}
		],
		"active_spells": [
			{
				"id": "zeus_lightning",
				"name": "宙斯雷霆",
				"description": "每16秒降下雷霆连锁，跳跃打击多个玩家单位",
				"effect": "lightning_chain",
				"cooldown": 16.0,
				"params": {"damage_mult": 1.2}
			},
			{
				"id": "olympus_ward",
				"name": "奥林匹斯之护",
				"description": "每24秒为自身施加18%最大生命值护盾",
				"effect": "dome_barrier",
				"cooldown": 24.0,
				"params": {"shield_pct": 0.18}
			}
		],
		"passive_spells": [
			{
				"id": "lightning_speed",
				"name": "闪电速度",
				"description": "暴击率+8%，闪避+5%",
				"effect": "speed_boost",
				"params": {"crit_chance": 0.08, "dodge_chance": 0.05}
			},
			{
				"id": "static_overload",
				"name": "静电过载",
				"description": "友军死亡时释放连锁闪电",
				"effect": "death_chain_lightning",
				"params": {"damage": 180, "bounces": 3}
			}
		],
		"equipment": {
			"phase_instrument": "pi_thunder_04",
			"level": 18,
			"platforms": ["ww2_boss_kingtiger", "ww2_arm_panther_e", "ww2_arm_panther_e", "ww2_sup_mg42", "ww2_inf_panzerschreck_e"],
			"weapons": ["tesla_coil_expert", "railgun_expert"],
			"energy_cards": ["thunder_energy_expert"]
		},
		"stats": {
			"max_hp": 5550,
			"attack_power": 81,
			"defense": 30,
			"energy_regen": 4.0,
			"unit_limit": 7
		}
	},
	{
		"id": "enemy_master_012",
		"name": "虚空虚主·阿扎托斯",
		"title": "虚空君王",
		"level": 19,
		"faction": "void",
		"difficulty": "expert",
		"traits": [
			{
				"id": "void_mastery",
				"name": "虚空精通",
				"description": "三维攻击+15%",
				"effects": {"atk_light": 0.15, "atk_armor": 0.15, "atk_air": 0.15}
			}
		],
		"active_spells": [
			{
				"id": "abyss_apocalypse",
				"name": "深渊降临",
				"description": "每18秒引发虚空灾变，对全体玩家单位造成范围伤害",
				"effect": "abyss_apocalypse",
				"cooldown": 18.0,
				"params": {"damage_mult": 1.2}
			},
			{
				"id": "devouring_void",
				"name": "虚空吞噬",
				"description": "每14秒对生命最高的玩家单位发动吞噬打击",
				"effect": "devour_single",
				"cooldown": 14.0,
				"params": {"damage_mult": 1.3}
			}
		],
		"passive_spells": [
			{
				"id": "dimension_siphon",
				"name": "维度虹吸",
				"description": "从每个敌人身上每秒吸取40生命值和15能量",
				"effect": "life_energy_drain",
				"params": {"hp_drain": 40, "energy_drain": 15}
			}
		],
		"equipment": {
			"phase_instrument": "pi_void_04",
			"level": 19,
			"platforms": ["ww2_boss_kingtiger", "ww2_boss_kingtiger", "ww2_arm_panther_e", "ww2_sup_mg42", "ww2_inf_para_e"],
			"weapons": ["void_lance_expert", "entropy_caster_expert"],
			"energy_cards": ["void_energy_expert"]
		},
		"stats": {
			"max_hp": 5600,
			"attack_power": 82,
			"defense": 29,
			"energy_regen": 4.2,
			"unit_limit": 7
		}
	},
]
