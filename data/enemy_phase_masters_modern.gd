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
		"equipment": {
			"phase_instrument": "pi_void_04",
			"level": 25,
			"platforms": ["mod_boss_command", "mod_arm_abrams_e", "mod_arm_abrams_e", "mod_air_apache_e", "mod_arm_stryker_e", "mod_inf_delta_e"],
			"weapons": ["void_lance_expert", "entropy_caster_expert"],
			"energy_cards": ["void_energy_expert"]
		},
		"stats": {
			"max_hp": 16800,
			"attack_power": 198,
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
		"equipment": {
			"phase_instrument": "pi_steelthunder_01",
			"level": 24,
			"platforms": ["mod_boss_command", "mod_arm_abrams_e", "mod_arm_abrams_e", "mod_arm_stryker_e", "mod_air_apache_e", "mod_inf_delta_e"],
			"weapons": ["steel_gatling_expert", "tesla_coil_expert"],
			"energy_cards": ["hybrid_energy_advanced"]
		},
		"stats": {
			"max_hp": 17500,
			"attack_power": 206,
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
		"equipment": {
			"phase_instrument": "pi_flamevoid_01",
			"level": 25,
			"platforms": ["mod_arm_abrams_e", "mod_arty_mlrs_e", "mod_boss_command", "mod_air_apache_e"],
			"weapons": ["plasma_cannon_expert", "entropy_caster_expert"],
			"energy_cards": ["hybrid_energy_advanced"]
		},
		"stats": {
			"max_hp": 18400,
			"attack_power": 214,
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
		"equipment": {
			"phase_instrument": "pi_steel_04",
			"level": 26,
			"platforms": ["mod_boss_command", "mod_arm_abrams_e", "mod_arm_abrams_e", "mod_arm_stryker_e", "mod_air_apache_e", "mod_arty_mlrs_e"],
			"weapons": ["steel_gatling_expert", "steel_artillery_expert"],
			"energy_cards": ["steel_energy_expert"]
		},
		"stats": {
			"max_hp": 19200,
			"attack_power": 224,
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
		"equipment": {
			"phase_instrument": "pi_flame_04",
			"level": 27,
			"platforms": ["mod_arm_abrams_e", "mod_arty_mlrs_e", "mod_boss_command", "mod_air_apache_e", "mod_inf_delta_e"],
			"weapons": ["flame_thrower_expert", "plasma_cannon_expert"],
			"energy_cards": ["flame_energy_expert"]
		},
		"stats": {
			"max_hp": 20000,
			"attack_power": 232,
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
		"equipment": {
			"phase_instrument": "pi_thunder_04",
			"level": 27,
			"platforms": ["mod_boss_command", "mod_boss_command", "mod_air_apache_e", "mod_arm_abrams_e", "mod_arm_stryker_e", "mod_arty_mlrs_e"],
			"weapons": ["tesla_coil_expert", "railgun_expert"],
			"energy_cards": ["thunder_energy_expert"]
		},
		"stats": {
			"max_hp": 20800,
			"attack_power": 240,
			"defense": 30,
			"energy_regen": 4.8,
			"unit_limit": 8
		}
	},
]
