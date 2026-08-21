extends RefCounted
class_name EnemyPhaseMastersCOLDWAR

## 敌方相位师资料 - 冷战时代 (enemy_master_013 ~ enemy_master_018)
## 由 enemy_phase_masters.gd 拆分，按时代组织
## 所有装备引用均来自 EnemyPhaseEquipment 的有效ID

const ERA_MASTERS: Array = [
	{
		"id": "enemy_master_013",
		"name": "钢铁烈焰·卡尔",
		"title": "熔铸大师",
		"level": 18,
		"faction": "steel_flame",
		"difficulty": "hard",
		"equipment": {
			"phase_instrument": "pi_steelflame_01",
			"level": 18,
			"platforms": ["cold_arm_t72_e", "cold_arm_t72_e", "cold_arm_btr_e", "cold_air_m113_e", "cold_inf_ak"],
			"weapons": ["steel_gatling_expert", "flame_thrower_expert"],
			"energy_cards": ["hybrid_energy_basic"]
		},
		"stats": {
			"max_hp": 9450,
			"attack_power": 121,
			"defense": 37,
			"energy_regen": 3.2,
			"unit_limit": 8
		}
	},
	{
		"id": "enemy_master_014",
		"name": "雷霆钢铁·维克多",
		"title": "电磁装甲师",
		"level": 19,
		"faction": "thunder_steel",
		"difficulty": "hard",
		"equipment": {
			"phase_instrument": "pi_steelthunder_01",
			"level": 19,
			"platforms": ["cold_arm_t72_e", "cold_arm_btr_e", "cold_air_m113_e", "cold_inf_spetsnaz_e", "cold_boss_mig"],
			"weapons": ["steel_railcannon_advanced", "tesla_coil_expert"],
			"energy_cards": ["hybrid_energy_basic"]
		},
		"stats": {
			"max_hp": 9550,
			"attack_power": 124,
			"defense": 46,
			"energy_regen": 3.5,
			"unit_limit": 7
		}
	},
	{
		"id": "enemy_master_015",
		"name": "虚空烈焰·塞拉菲娜",
		"title": "熵增炎魔",
		"level": 20,
		"faction": "void_flame",
		"difficulty": "expert",
		"equipment": {
			"phase_instrument": "pi_flamevoid_01",
			"level": 20,
			"platforms": ["cold_boss_mig", "cold_arm_t72_e", "cold_arm_t72_e", "cold_air_m113_e", "cold_inf_spetsnaz_e"],
			"weapons": ["entropy_caster_expert", "plasma_cannon_expert"],
			"energy_cards": ["hybrid_energy_advanced"]
		},
		"stats": {
			"max_hp": 9700,
			"attack_power": 126,
			"defense": 29,
			"energy_regen": 3.8,
			"unit_limit": 7
		}
	},

	# ==================== Tier 4 - 专家级相位师 (Lv22-25) ====================
	{
		"id": "enemy_master_016",
		"name": "不朽钢铁·阿特拉斯",
		"title": "世界承载者",
		"level": 22,
		"faction": "steel",
		"difficulty": "expert",
		"equipment": {
			"phase_instrument": "pi_steel_04",
			"level": 22,
			"platforms": ["cold_boss_mig", "cold_arm_t72_e", "cold_arm_t72_e", "cold_air_m113_e", "cold_inf_spetsnaz_e", "cold_arm_btr_e"],
			"weapons": ["steel_gatling_expert", "steel_artillery_expert"],
			"energy_cards": ["steel_energy_expert"]
		},
		"stats": {
			"max_hp": 9900,
			"attack_power": 131,
			"defense": 36,
			"energy_regen": 3.5,
			"unit_limit": 9
		}
	},
	{
		"id": "enemy_master_017",
		"name": "永恒炎魔·苏尔特",
		"title": "诸神黄昏",
		"level": 23,
		"faction": "flame",
		"difficulty": "expert",
		"equipment": {
			"phase_instrument": "pi_flame_04",
			"level": 23,
			"platforms": ["cold_arm_t72_e", "cold_inf_ak", "cold_boss_mig", "cold_arm_btr_e"],
			"weapons": ["flame_thrower_expert", "plasma_cannon_expert"],
			"energy_cards": ["flame_energy_expert"]
		},
		"stats": {
			"max_hp": 10000,
			"attack_power": 133,
			"defense": 24,
			"energy_regen": 4.0,
			"unit_limit": 8
		}
	},
	{
		"id": "enemy_master_018",
		"name": "万雷之主·雷神",
		"title": "雷霆化身",
		"level": 24,
		"faction": "thunder",
		"difficulty": "expert",
		"equipment": {
			"phase_instrument": "pi_thunder_04",
			"level": 24,
			"platforms": ["cold_boss_mig", "cold_boss_mig", "cold_arm_t72_e", "cold_air_m113_e", "cold_inf_spetsnaz_e", "cold_arm_btr_e"],
			"weapons": ["tesla_coil_expert", "railgun_expert"],
			"energy_cards": ["thunder_energy_expert"]
		},
		"stats": {
			"max_hp": 10150,
			"attack_power": 136,
			"defense": 23,
			"energy_regen": 4.5,
			"unit_limit": 8
		}
	},
]
