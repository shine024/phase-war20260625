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
				"description": "三维攻击+15%",
				"effects": {"atk_light": 0.15, "atk_armor": 0.15, "atk_air": 0.15}
			}
		],
		"active_spells": [],
		"passive_spells": [
			{
				"id": "void_lord",
				"name": "虚空领主",
				"description": "三维攻击+15%",
				"effect": "void_mastery_ultimate",
				"params": {"damage_boost": 0.15}
			},
			{
				"id": "enemy_defense_reduction",
				"name": "现实崩溃",
				"description": "三维攻击+8%",
				"effect": "enemy_defense_reduction",
				"params": {"reduction": 0.08}
			}
		],
		"equipment": {
			"phase_instrument": "pi_void_04",
			"level": 25,
			"platforms": ["mod_boss_command", "mod_arm_abrams_e", "mod_arm_abrams_e", "mod_air_apache_e", "mod_arm_stryker_e", "mod_inf_delta_e"],
			"weapons": ["void_lance_expert", "entropy_caster_expert"],
			"energy_cards": ["void_energy_expert"]
		},
		"stats": {
			"max_hp": 17650,
			"attack_power": 207,
			"defense": 40,
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
		"active_spells": [],
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
			"phase_instrument": "pi_steelthunder_01",
			"level": 24,
			"platforms": ["mod_boss_command", "mod_arm_abrams_e", "mod_arm_abrams_e", "mod_arm_stryker_e", "mod_air_apache_e", "mod_inf_delta_e"],
			"weapons": ["steel_gatling_expert", "tesla_coil_expert"],
			"energy_cards": ["hybrid_energy_advanced"]
		},
		"stats": {
			"max_hp": 17450,
			"attack_power": 203,
			"defense": 56,
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
		"active_spells": [],
		"passive_spells": [
			{
				"id": "dual_element_boost",
				"name": "混沌之火",
				"description": "三维攻击+8%",
				"effect": "dual_element_boost",
				"params": {"boost": 0.08, "dual_chance": 0.15}
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
			"phase_instrument": "pi_flamevoid_01",
			"level": 25,
			"platforms": ["mod_arm_abrams_e", "mod_arty_mlrs_e", "mod_boss_command", "mod_air_apache_e"],
			"weapons": ["plasma_cannon_expert", "entropy_caster_expert"],
			"energy_cards": ["hybrid_energy_advanced"]
		},
		"stats": {
			"max_hp": 17650,
			"attack_power": 207,
			"defense": 37,
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
		"active_spells": [],
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
			"phase_instrument": "pi_steel_04",
			"level": 26,
			"platforms": ["mod_boss_command", "mod_arm_abrams_e", "mod_arm_abrams_e", "mod_arm_stryker_e", "mod_air_apache_e", "mod_arty_mlrs_e"],
			"weapons": ["steel_gatling_expert", "steel_artillery_expert"],
			"energy_cards": ["steel_energy_expert"]
		},
		"stats": {
			"max_hp": 17850,
			"attack_power": 211,
			"defense": 55,
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
		"active_spells": [],
		"passive_spells": [
			{
				"id": "fire_mastery",
				"name": "火焰精通",
				"description": "三维攻击+15%",
				"effect": "elemental_mastery",
				"params": {"element": "fire", "damage_boost": 0.15}
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
			"phase_instrument": "pi_flame_04",
			"level": 27,
			"platforms": ["mod_arm_abrams_e", "mod_arty_mlrs_e", "mod_boss_command", "mod_air_apache_e", "mod_inf_delta_e"],
			"weapons": ["flame_thrower_expert", "plasma_cannon_expert"],
			"energy_cards": ["flame_energy_expert"]
		},
		"stats": {
			"max_hp": 18050,
			"attack_power": 214,
			"defense": 32,
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
				"description": "三维攻击+8%",
				"effects": {"atk_light": 0.08, "atk_armor": 0.08, "atk_air": 0.08}
			}
		],
		"active_spells": [],
		"passive_spells": [
			{
				"id": "storm_speed",
				"name": "风暴骑手",
				"description": "暴击率+8%，闪避+5%",
				"effect": "storm_speed",
				"params": {"crit_chance": 0.08, "dodge_chance": 0.05}
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
			"phase_instrument": "pi_thunder_04",
			"level": 27,
			"platforms": ["mod_boss_command", "mod_boss_command", "mod_air_apache_e", "mod_arm_abrams_e", "mod_arm_stryker_e", "mod_arty_mlrs_e"],
			"weapons": ["tesla_coil_expert", "railgun_expert"],
			"energy_cards": ["thunder_energy_expert"]
		},
		"stats": {
			"max_hp": 18050,
			"attack_power": 214,
			"defense": 30,
			"energy_regen": 4.8,
			"unit_limit": 8
		}
	},
]
