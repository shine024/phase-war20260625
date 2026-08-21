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
		"equipment": {
			"phase_instrument": "pi_void_04",
			"level": 28,
			"platforms": ["fut_boss_nexus", "fut_arm_colossus_e", "fut_arm_colossus_e", "fut_arm_mech_e", "fut_inf_spectre_e", "fut_air_drone"],
			"weapons": ["void_lance_expert", "entropy_caster_expert"],
			"energy_cards": ["void_energy_expert"]
		},
		"stats": {
			"max_hp": 25200,
			"attack_power": 295,
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
		"equipment": {
			"phase_instrument": "pi_steel_05",
			"level": 28,
			"platforms": ["fut_boss_nexus", "fut_arm_colossus_e", "fut_arm_colossus_e", "fut_arm_hovertank_e", "fut_arm_mech_e", "fut_inf_cyborg"],
			"weapons": ["steel_gatling_expert", "steel_artillery_expert"],
			"energy_cards": ["steel_energy_god"]
		},
		"stats": {
			"max_hp": 26200,
			"attack_power": 308,
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
		"equipment": {
			"phase_instrument": "pi_flame_05",
			"level": 29,
			"platforms": ["fut_arm_colossus_e", "fut_arm_hovertank_e", "fut_boss_nexus", "fut_inf_spectre_e", "fut_arm_mech_e"],
			"weapons": ["flame_thrower_expert", "plasma_cannon_expert"],
			"energy_cards": ["flame_energy_god"]
		},
		"stats": {
			"max_hp": 27400,
			"attack_power": 322,
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
		"equipment": {
			"phase_instrument": "pi_thunder_05",
			"level": 29,
			"platforms": ["fut_boss_nexus", "fut_boss_nexus", "fut_arm_colossus_e", "fut_arm_hovertank_e", "fut_inf_spectre_e", "fut_air_drone"],
			"weapons": ["tesla_coil_expert", "railgun_expert"],
			"energy_cards": ["thunder_energy_god"]
		},
		"stats": {
			"max_hp": 28400,
			"attack_power": 335,
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
		"equipment": {
			"phase_instrument": "pi_void_05",
			"level": 30,
			"platforms": ["fut_inf_cyborg", "fut_arm_hovertank_e", "fut_boss_nexus", "fut_inf_spectre_e", "fut_arm_colossus_e", "fut_air_drone"],
			"weapons": ["void_lance_expert", "entropy_caster_expert"],
			"energy_cards": ["void_energy_god"]
		},
		"stats": {
			"max_hp": 29600,
			"attack_power": 348,
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
		"equipment": {
			"phase_instrument": "pi_omega_01",
			"level": 30,
			"platforms": ["fut_boss_nexus", "fut_boss_nexus", "fut_arm_colossus_e", "fut_arm_colossus_e", "fut_arm_hovertank_e", "fut_arm_mech_e"],
			"weapons": ["railgun_expert", "plasma_cannon_expert"],
			"energy_cards": ["hybrid_energy_god"]
		},
		"stats": {
			"max_hp": 30800,
			"attack_power": 360,
			"defense": 47,
			"energy_regen": 8.0,
			"unit_limit": 15
		}
	}
]
