extends RefCounted
class_name EnemyPhaseMastersMODERN

## 敌方相位师资料 - 现代时代 (enemy_master_019 ~ enemy_master_024)
## 由 enemy_phase_masters.gd 拆分，按时代组织
## 所有装备引用均来自 EnemyPhaseEquipment 的有效ID

const ERA_MASTERS: Array = [
	{
		"id": "enemy_master_019",
		"name": "虚空主宰·尼德霍格",
		"title": "世界吞噬者",
		"level": 25,
		"faction": "void",
		"difficulty": "expert",
		"traits": [
			{
				"id": "world_devourer",
				"name": "世界吞噬者",
				"description": "虚空伤害+45%；敌方护盾和护甲效果降低30%",
				"effects": {"void_damage_boost": 0.45, "enemy_defense_reduction": 0.30}
			}
		],
		"active_spells": [
			{
				"id": "devour_all",
				"name": "世界吞噬",
				"description": "吞噬战场上低生命值的敌人，恢复40%最大生命值",
				"cooldown": 80.0,
				"mana_cost": 500,
				"effect": "devour_all",
				"params": {"heal_percent": 0.4, "hp_threshold": 0.25}
			},
			{
				"id": "void_apocalypse",
				"name": "虚空末日",
				"description": "开启虚空末日，所有敌人持续受到伤害并被传送",
				"cooldown": 60.0,
				"mana_cost": 450,
				"effect": "void_apocalypse",
				"params": {"damage": 180, "duration": 12.0}
			}
		],
		"passive_spells": [
			{
				"id": "void_lord",
				"name": "虚空领主",
				"description": "所有虚空技能伤害提升80%，冷却减少25%",
				"effect": "void_mastery_ultimate",
				"params": {"damage_boost": 0.8, "cooldown_reduction": 0.25}
			},
			{
				"id": "enemy_defense_reduction",
				"name": "现实崩溃",
				"description": "敌人的护盾和护甲效果降低40%",
				"effect": "enemy_defense_reduction",
				"params": {"reduction": 0.4}
			}
		],
		"equipment": {
			"phase_instrument": "void_walker_mk4",
			"level": 25,
			"platforms": ["void_stealth_expert", "void_mage_expert"],
			"weapons": ["void_lance_expert", "entropy_caster_expert"],
			"energy_cards": ["void_energy_expert"]
		},
		"stats": {
			"max_hp": 4500,
			"attack_power": 500,
			"defense": 120,
			"energy_regen": 4.5,
			"unit_limit": 8
		}
	},

	# ==================== Tier 4 - 混合专家 (Lv24-25) ====================
	{
		"id": "enemy_master_020",
		"name": "钢铁雷霆·泰尔",
		"title": "电磁战神",
		"level": 24,
		"faction": "steel_thunder",
		"difficulty": "expert",
		"traits": [
			{
				"id": "em_war_god",
				"name": "电磁战神",
				"description": "钢铁+雷霆协同：部署时单位获得闪电护盾，反弹200伤害",
				"effects": {"synergy_boost": 0.30, "synergy_types": ["steel", "thunder"], "deploy_shield": 200}
			}
		],
		"active_spells": [
			{
				"id": "electromagnetic_fortress",
				"name": "电磁堡垒",
				"description": "创造电磁堡垒，对周围敌人造成持续伤害",
				"cooldown": 45.0,
				"mana_cost": 300,
				"effect": "em_fortress",
				"params": {"damage": 200, "duration": 15.0}
			},
			{
				"id": "lightning_assault",
				"name": "雷霆突击",
				"description": "所有友军获得闪电护盾和攻击加速",
				"cooldown": 30.0,
				"mana_cost": 250,
				"effect": "lightning_buff",
				"params": {"attack_speed": 0.4, "shield_damage": 120}
			}
		],
		"passive_spells": [
			{
				"id": "synergy_boost",
				"name": "导电钢铁",
				"description": "钢铁单位和雷电单位互相增强25%属性",
				"effect": "synergy_boost",
				"params": {"boost": 0.25, "types": ["steel", "thunder"]}
			},
			{
				"id": "armor_chain_lightning",
				"name": "雷霆护甲",
				"description": "友军受到攻击时，触发连锁闪电",
				"effect": "armor_chain_lightning",
				"params": {"chain_count": 3, "damage": 100}
			}
		],
		"equipment": {
			"phase_instrument": "hybrid_steel_thunder_mk1",
			"level": 24,
			"platforms": ["steel_fortress_expert", "thunter_striker_expert"],
			"weapons": ["steel_gatling_expert", "tesla_coil_expert"],
			"energy_cards": ["hybrid_energy_advanced"]
		},
		"stats": {
			"max_hp": 4200,
			"attack_power": 480,
			"defense": 160,
			"energy_regen": 4.0,
			"unit_limit": 8
		}
	},
	{
		"id": "enemy_master_021",
		"name": "烈焰虚空·克尔加",
		"title": "混沌炎魔",
		"level": 25,
		"faction": "flame_void",
		"difficulty": "legendary",
		"traits": [
			{
				"id": "chaos_inferno_trait",
				"name": "混沌炎魔",
				"description": "烈焰+虚空协同：被燃烧的敌人随机传送，有20%概率双重伤害",
				"effects": {"synergy_boost": 0.30, "synergy_types": ["flame", "void"], "dual_damage_chance": 0.20}
			}
		],
		"active_spells": [
			{
				"id": "chaos_zone",
				"name": "混沌虚空炼狱",
				"description": "创造混乱的虚空炼狱，随机传送和伤害敌人",
				"cooldown": 50.0,
				"mana_cost": 350,
				"effect": "chaos_zone",
				"params": {"damage": 250, "duration": 12.0}
			},
			{
				"id": "entropy_drain",
				"name": "熵增烈焰",
				"description": "所有敌人持续失去生命值和能量",
				"cooldown": 40.0,
				"mana_cost": 280,
				"effect": "entropy_drain",
				"params": {"hp_drain": 80, "energy_drain": 40, "duration": 8.0}
			}
		],
		"passive_spells": [
			{
				"id": "dual_element_boost",
				"name": "混沌之火",
				"description": "火焰和虚空伤害提升40%，有15%概率触发双重伤害",
				"effect": "dual_element_boost",
				"params": {"boost": 0.4, "dual_chance": 0.15}
			},
			{
				"id": "immunity",
				"name": "混沌免疫",
				"description": "友军对燃烧和虚空能量流失效果免疫",
				"effect": "immunity",
				"params": {"effects": ["burn", "void_drain"]}
			}
		],
		"equipment": {
			"phase_instrument": "hybrid_flame_void_mk1",
			"level": 25,
			"platforms": ["flame_siege_expert", "void_mage_expert"],
			"weapons": ["plasma_cannon_expert", "entropy_caster_expert"],
			"energy_cards": ["hybrid_energy_advanced"]
		},
		"stats": {
			"max_hp": 4000,
			"attack_power": 520,
			"defense": 100,
			"energy_regen": 4.5,
			"unit_limit": 7
		}
	},

	# ==================== Tier 5 - 传说级相位师 (Lv26-29) ====================
	{
		"id": "enemy_master_022",
		"name": "战争机器·铁骑",
		"title": "钢铁风暴",
		"level": 26,
		"faction": "steel",
		"difficulty": "legendary",
		"traits": [
			{
				"id": "automated_warfare",
				"name": "自动化战争",
				"description": "每10秒自动生产一个战斗单位；单位每存活10秒获得一层升级(+8%属性)",
				"effects": {"auto_spawn_interval": 10.0, "time_scaling": {"interval": 10.0, "boost": 0.08}}
			}
		],
		"active_spells": [
			{
				"id": "deploy_mechs",
				"name": "机械军团",
				"description": "部署6个战斗机器人",
				"cooldown": 30.0,
				"mana_cost": 180,
				"effect": "deploy_mechs",
				"params": {"count": 6, "mech_type": "battle_robot"}
			},
			{
				"id": "mass_repair",
				"name": "修复蜂群",
				"description": "纳米机器人修复所有友军，恢复25%生命值",
				"cooldown": 25.0,
				"mana_cost": 150,
				"effect": "mass_repair",
				"params": {"heal_percent": 0.25}
			}
		],
		"passive_spells": [
			{
				"id": "automation",
				"name": "自动化",
				"description": "每12秒自动生产一个战斗单位",
				"effect": "auto_production_fast",
				"params": {"interval": 12.0}
			},
			{
				"id": "modular_upgrade",
				"name": "模块化升级",
				"description": "友军单位每存活10秒，获得一层升级（+8%属性）",
				"effect": "time_based_upgrade",
				"params": {"interval": 10.0, "boost_per_level": 0.08}
			}
		],
		"equipment": {
			"phase_instrument": "steel_guardian_mk4",
			"level": 26,
			"platforms": ["steel_fortress_expert", "steel_titan_expert"],
			"weapons": ["steel_gatling_expert", "steel_artillery_expert"],
			"energy_cards": ["steel_energy_expert"]
		},
		"stats": {
			"max_hp": 5500,
			"attack_power": 480,
			"defense": 200,
			"energy_regen": 3.5,
			"unit_limit": 10
		}
	},
	{
		"id": "enemy_master_023",
		"name": "火术宗师·凤凰",
		"title": "不死鸟",
		"level": 27,
		"faction": "flame",
		"difficulty": "legendary",
		"traits": [
			{
				"id": "phoenix_trait",
				"name": "不死鸟",
				"description": "火焰技能冷却-30%；全队每场战斗可触发一次完全复活",
				"effects": {"fire_cooldown_reduction": 0.30, "full_resurrect_once": true}
			}
		],
		"active_spells": [
			{
				"id": "pyroblast",
				"name": "炎爆术",
				"description": "发射巨大火球，造成600伤害并点燃区域",
				"cooldown": 18.0,
				"mana_cost": 160,
				"effect": "pyroblast",
				"params": {"damage": 600, "radius": 100, "burn_duration": 6.0}
			},
			{
				"id": "flame_wave",
				"name": "烈焰波",
				"description": "释放环形烈焰波，推开敌人并造成400伤害",
				"cooldown": 16.0,
				"mana_cost": 140,
				"effect": "flame_wave",
				"params": {"damage": 400, "knockback": 150}
			}
		],
		"passive_spells": [
			{
				"id": "fire_mastery",
				"name": "火焰精通",
				"description": "火焰伤害提升35%，火焰法术冷却减少20%",
				"effect": "elemental_mastery",
				"params": {"element": "fire", "damage_boost": 0.35, "cooldown_reduction": 0.2}
			},
			{
				"id": "ignite",
				"name": "点燃",
				"description": "攻击有20%概率点燃敌人，每秒造成45伤害",
				"effect": "ignite_chance",
				"params": {"chance": 0.2, "burn_damage": 45}
			}
		],
		"equipment": {
			"phase_instrument": "flame_destroyer_mk4",
			"level": 27,
			"platforms": ["flame_raider_expert", "flame_siege_expert"],
			"weapons": ["flame_thrower_expert", "plasma_cannon_expert"],
			"energy_cards": ["flame_energy_expert"]
		},
		"stats": {
			"max_hp": 4800,
			"attack_power": 580,
			"defense": 100,
			"energy_regen": 4.2,
			"unit_limit": 9
		}
	},
	{
		"id": "enemy_master_024",
		"name": "风暴使者·赛勒斯",
		"title": "疾风迅雷",
		"level": 27,
		"faction": "thunder",
		"difficulty": "legendary",
		"traits": [
			{
				"id": "storm_rush",
				"name": "超级突袭",
				"description": "移动速度+50%；对首领级目标造成+100%伤害",
				"effects": {"move_speed_boost": 0.50, "boss_damage_boost": 1.0}
			}
		],
		"active_spells": [
			{
				"id": "tornado_summon",
				"name": "龙卷风链",
				"description": "召唤3个龙卷风，在战场上移动并造成伤害",
				"cooldown": 28.0,
				"mana_cost": 200,
				"effect": "tornado_summon",
				"params": {"count": 3, "damage": 160, "duration": 10.0}
			},
			{
				"id": "wind_blast",
				"name": "风之冲击",
				"description": "强力风击，将所有敌人推向一侧并造成280伤害",
				"cooldown": 22.0,
				"mana_cost": 170,
				"effect": "wind_push",
				"params": {"damage": 280, "push_distance": 200}
			}
		],
		"passive_spells": [
			{
				"id": "storm_speed",
				"name": "风暴骑手",
				"description": "友军移动速度提升50%，攻击速度提升25%",
				"effect": "storm_speed",
				"params": {"move_speed": 0.5, "attack_speed": 0.25}
			},
			{
				"id": "periodic_electric_shock",
				"name": "电场",
				"description": "周围敌人每3秒受到一次电击",
				"effect": "periodic_electric_shock",
				"params": {"interval": 3.0, "damage": 100}
			}
		],
		"equipment": {
			"phase_instrument": "thunder_storm_mk4",
			"level": 27,
			"platforms": ["thunter_striker_expert", "thunter_sniper_expert"],
			"weapons": ["tesla_coil_expert", "railgun_expert"],
			"energy_cards": ["thunder_energy_expert"]
		},
		"stats": {
			"max_hp": 4000,
			"attack_power": 550,
			"defense": 80,
			"energy_regen": 4.8,
			"unit_limit": 8
		}
	},
]
