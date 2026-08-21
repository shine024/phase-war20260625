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
		"equipment": {
			"phase_instrument": "pi_thunder_03",
			"level": 13,
			"platforms": ["ww1_boss_av7", "ww1_boss_av7", "ww1_arm_rolls_e", "ww1_sup_mg_nest"],
			"weapons": ["tesla_coil_advanced", "railgun_advanced"],
			"energy_cards": ["thunder_energy_advanced"]
		},
		"stats": {
			"max_hp": 5000,
			"attack_power": 68,
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
