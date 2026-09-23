extends RefCounted
class_name EnemyPhaseMastersCOLDWAR

## 敌方相位师资料 - 冷战时代 (enemy_master_013 ~ enemy_master_018)
## 由 enemy_phase_masters.gd 拆分，按时代组织
## 所有装备引用均来自 EnemyPhaseEquipment 的有效ID

const ERA_MASTERS: Array = [
	{
		"id": "enemy_master_013",
		"name": "韩铸犁",
		"title": "熔剑为犁",
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
		"name": "方镇流",
		"title": "吞雷的装甲",
		"level": 19,
		"faction": "thunder_steel",
		"difficulty": "hard",
		"equipment": {
			"phase_instrument": "pi_steelthunder_01",
			"level": 19,
			"platforms": ["cold_arm_t72_e", "cold_arm_btr_e", "cold_air_m113_e", "cold_inf_spetsnaz_e", "cold_boss_mig"],
			"weapons": ["steel_railcannon_expert", "tesla_coil_expert"],
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
		"name": "郁向暖",
		"title": "熵减之焰",
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
		"name": "石顶安",
		"title": "顶住塌方的人",
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
		"name": "江焚渡",
		"title": "烧桥的人",
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
		"name": "纪回春",
		"title": "圈外的雷",
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
