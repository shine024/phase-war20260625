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
				"description": "雷电伤害+20%，闪电链弹射+1次",
				"effects": {"lightning_damage_boost": 0.20, "chain_bounce_bonus": 1}
			}
		],
		"active_spells": [
			{
				"id": "lightning_storm",
				"name": "雷暴",
				"description": "全屏闪电打击，随机敌人受到300伤害",
				"cooldown": 20.0,
				"mana_cost": 160,
				"effect": "global_lightning",
				"params": {"damage": 300, "strike_count": 6}
			},
			{
				"id": "electrify",
				"name": "充能",
				"description": "使所有友军获得电击攻击，每次攻击附加100伤害",
				"cooldown": 18.0,
				"mana_cost": 140,
				"effect": "weapon_enchant",
				"params": {"bonus_damage": 100, "duration": 10.0}
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
			"phase_instrument": "thunder_storm_mk2",
			"level": 13,
			"platforms": ["thunter_striker_advanced", "thunter_sniper_advanced"],
			"weapons": ["tesla_coil_advanced", "railgun_advanced"],
			"energy_cards": ["thunder_energy_advanced"]
		},
		"stats": {
			"max_hp": 1800,
			"attack_power": 300,
			"defense": 65,
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
				"description": "虚空伤害+20%，相位仪能量恢复+30%",
				"effects": {"void_damage_boost": 0.20, "energy_regen_boost": 0.30}
			}
		],
		"active_spells": [
			{
				"id": "dimension_rift",
				"name": "维度裂隙",
				"description": "打开传送门，持续召唤虚空生物，持续12秒",
				"cooldown": 35.0,
				"mana_cost": 200,
				"effect": "portal_summon",
				"params": {"duration": 12.0, "spawn_interval": 2.0}
			},
			{
				"id": "black_hole",
				"name": "黑洞",
				"description": "创造黑洞，持续吸引敌人并每秒造成200伤害",
				"cooldown": 28.0,
				"mana_cost": 180,
				"effect": "black_hole",
				"params": {"damage": 200, "duration": 6.0, "radius": 150}
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
			"phase_instrument": "void_walker_mk2",
			"level": 14,
			"platforms": ["void_stealth_advanced", "void_mage_advanced"],
			"weapons": ["void_lance_advanced", "gravity_well_advanced"],
			"energy_cards": ["void_energy_advanced"]
		},
		"stats": {
			"max_hp": 2100,
			"attack_power": 280,
			"defense": 80,
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
				"description": "单位生产速度+30%，存活单位每10秒获得+5%全属性",
				"effects": {"deploy_speed_boost": 0.30, "time_scaling": {"interval": 10.0, "boost": 0.05}}
			}
		],
		"active_spells": [
			{
				"id": "legion_call",
				"name": "军团召唤",
				"description": "召唤10个钢铁战士，包括3个精锐和7个普通",
				"cooldown": 40.0,
				"mana_cost": 220,
				"effect": "mass_summon",
				"params": {"elite_count": 3, "normal_count": 7}
			},
			{
				"id": "fortress_mode",
				"name": "要塞模式",
				"description": "所有友军获得50%防御和1500生命值护盾",
				"cooldown": 35.0,
				"mana_cost": 200,
				"effect": "mass_buff_shield",
				"params": {"defense_boost": 0.5, "shield_amount": 1500}
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
			"phase_instrument": "steel_guardian_mk3",
			"level": 16,
			"platforms": ["steel_fortress_expert", "steel_titan_expert"],
			"weapons": ["steel_gatling_expert", "steel_artillery_expert"],
			"energy_cards": ["steel_energy_expert"]
		},
		"stats": {
			"max_hp": 3000,
			"attack_power": 280,
			"defense": 150,
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
				"description": "火焰伤害+30%，友军移动路径留下燃烧轨迹",
				"effects": {"fire_damage_boost": 0.30, "flame_trail": true}
			}
		],
		"active_spells": [
			{
				"id": "world_inferno",
				"name": "世界炼狱",
				"description": "将战场变为熔岩环境，所有敌人每秒受到80伤害",
				"cooldown": 50.0,
				"mana_cost": 300,
				"effect": "terrain_transform",
				"params": {"damage": 80, "duration": 12.0}
			},
			{
				"id": "supernova",
				"name": "超新星",
				"description": "在中心点释放巨大爆炸，造成700伤害并点燃所有敌人",
				"cooldown": 45.0,
				"mana_cost": 280,
				"effect": "massive_explosion",
				"params": {"damage": 700, "radius": 200, "burn_duration": 6.0}
			}
		],
		"passive_spells": [
			{
				"id": "hellfire",
				"name": "地狱火",
				"description": "友军攻击造成额外40%火焰伤害",
				"effect": "elemental_damage_boost",
				"params": {"boost": 0.4, "element": "fire"}
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
			"phase_instrument": "flame_destroyer_mk3",
			"level": 17,
			"platforms": ["flame_raider_expert", "flame_siege_expert"],
			"weapons": ["flame_thrower_expert", "plasma_cannon_expert"],
			"energy_cards": ["flame_energy_expert"]
		},
		"stats": {
			"max_hp": 2800,
			"attack_power": 380,
			"defense": 90,
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
				"description": "雷电伤害+35%，能量满时自动触发闪电链打击",
				"effects": {"lightning_damage_boost": 0.35, "energy_full_auto_strike": true}
			}
		],
		"active_spells": [
			{
				"id": "thunder_god_fury",
				"name": "雷神之怒",
				"description": "连续释放8次强力闪电，每次造成450伤害",
				"cooldown": 30.0,
				"mana_cost": 250,
				"effect": "rapid_lightning",
				"params": {"strike_count": 8, "damage": 450}
			},
			{
				"id": "electromagnetic_pulse",
				"name": "电磁脉冲",
				"description": "EMP攻击，瘫痪所有敌人4秒",
				"cooldown": 40.0,
				"mana_cost": 200,
				"effect": "emp_stun",
				"params": {"duration": 4.0, "target_type": "all"}
			}
		],
		"passive_spells": [
			{
				"id": "lightning_speed",
				"name": "闪电速度",
				"description": "所有友军移动和攻击速度提升30%",
				"effect": "speed_boost",
				"params": {"move_speed": 0.3, "attack_speed": 0.3}
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
			"phase_instrument": "thunder_storm_mk3",
			"level": 18,
			"platforms": ["thunter_striker_expert", "thunter_sniper_expert"],
			"weapons": ["tesla_coil_expert", "railgun_expert"],
			"energy_cards": ["thunder_energy_expert"]
		},
		"stats": {
			"max_hp": 2600,
			"attack_power": 420,
			"defense": 85,
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
				"description": "虚空伤害+35%，所有技能冷却-20%，能量吸取效果+50%",
				"effects": {"void_damage_boost": 0.35, "cooldown_reduction": 0.20, "energy_drain_boost": 0.50}
			}
		],
		"active_spells": [
			{
				"id": "reality_collapse",
				"name": "现实崩塌",
				"description": "删除区域内生命值低于20%的敌人",
				"cooldown": 60.0,
				"mana_cost": 350,
				"effect": "instant_kill_zone",
				"params": {"radius": 100, "cast_time": 3.0, "hp_threshold": 0.2}
			},
			{
				"id": "void_army",
				"name": "虚空大军",
				"description": "召唤12个虚空生物，包括2个虚空巨兽",
				"cooldown": 45.0,
				"mana_cost": 280,
				"effect": "summon_void_army",
				"params": {"normal_count": 10, "behemoth_count": 2}
			}
		],
		"passive_spells": [
			{
				"id": "cooldown_mastery",
				"name": "冷却精通",
				"description": "所有技能冷却时间减少25%",
				"effect": "cooldown_reduction",
				"params": {"reduction": 0.25}
			},
			{
				"id": "dimension_siphon",
				"name": "维度虹吸",
				"description": "从每个敌人身上每秒吸取40生命值和15能量",
				"effect": "life_energy_drain",
				"params": {"hp_drain": 40, "energy_drain": 15}
			}
		],
		"equipment": {
			"phase_instrument": "void_walker_mk3",
			"level": 19,
			"platforms": ["void_stealth_expert", "void_mage_expert"],
			"weapons": ["void_lance_expert", "entropy_caster_expert"],
			"energy_cards": ["void_energy_expert"]
		},
		"stats": {
			"max_hp": 3200,
			"attack_power": 400,
			"defense": 100,
			"energy_regen": 4.2,
			"unit_limit": 7
		}
	},
]
