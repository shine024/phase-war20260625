extends RefCounted
class_name EnemyPhaseMastersWW1

## 敌方相位师资料 - 一战时代 (enemy_master_001 ~ enemy_master_006)
## 由 enemy_phase_masters.gd 拆分，按时代组织
## 所有装备引用均来自 EnemyPhaseEquipment 的有效ID

const ERA_MASTERS: Array = [
	{
		"id": "enemy_master_001",
		"name": "沈铸城",
		"title": "十七天的防线",
		"level": 5,
		"faction": "steel",
		"difficulty": "easy",
		"equipment": {
			"phase_instrument": "pi_steel_02",
			"level": 5,
			"platforms": ["steel_fortress_basic", "steel_titan_basic"],
			"weapons": ["steel_machinegun_basic", "steel_cannon_basic"],
			"energy_cards": ["steel_energy_basic"]
		},
		"stats": {
			"max_hp": 2900,
			"attack_power": 36,
			"defense": 32,
			"energy_regen": 2.0,
			"unit_limit": 5
		}
	},
	{
		"id": "enemy_master_002",
		"name": "祝晚棠",
		"title": "过载之火",
		"level": 6,
		"faction": "flame",
		"difficulty": "easy",
		"equipment": {
			"phase_instrument": "pi_flame_02",
			"level": 6,
			"platforms": ["flame_raider_basic", "flame_siege_basic"],
			"weapons": ["flame_thrower_basic", "incendiary_mortar_basic"],
			"energy_cards": ["flame_energy_basic"]
		},
		"stats": {
			"max_hp": 2950,
			"attack_power": 37,
			"defense": 25,
			"energy_regen": 2.5,
			"unit_limit": 6
		}
	},
	{
		"id": "enemy_master_003",
		"name": "陆惊鸿",
		"title": "七重闪电",
		"level": 7,
		"faction": "thunder",
		"difficulty": "medium",
		"equipment": {
			"phase_instrument": "pi_thunder_02",
			"level": 7,
			"platforms": ["thunter_striker_basic", "thunter_sniper_basic"],
			"weapons": ["tesla_coil_basic", "railgun_basic"],
			"energy_cards": ["thunder_energy_basic"]
		},
		"stats": {
			"max_hp": 2950,
			"attack_power": 38,
			"defense": 25,
			"energy_regen": 3.0,
			"unit_limit": 5
		}
	},
	{
		"id": "enemy_master_004",
		"name": "裴溯",
		"title": "四十一秒的裂隙",
		"level": 8,
		"faction": "void",
		"difficulty": "medium",
		"equipment": {
			"phase_instrument": "pi_void_02",
			"level": 8,
			"platforms": ["void_stealth_basic", "void_mage_basic"],
			"weapons": ["void_lance_basic", "gravity_well_basic"],
			"energy_cards": ["void_energy_basic"]
		},
		"stats": {
			"max_hp": 3000,
			"attack_power": 39,
			"defense": 29,
			"energy_regen": 2.8,
			"unit_limit": 5
		}
	},

	# ==================== Tier 2 - 中级相位师 (Lv10-14) ====================
	{
		"id": "enemy_master_005",
		"name": "霍北望",
		"title": "不可破之盾",
		"level": 10,
		"faction": "steel",
		"difficulty": "medium",
		"equipment": {
			"phase_instrument": "pi_steel_03",
			"level": 10,
			"platforms": ["ww1_boss_av7", "ww1_boss_av7", "ww1_arm_rolls_e", "ww1_inf_storm_e"],
			"weapons": ["steel_minigun_advanced", "steel_railcannon_advanced"],
			"energy_cards": ["steel_energy_advanced"]
		},
		"stats": {
			"max_hp": 3100,
			"attack_power": 41,
			"defense": 35,
			"energy_regen": 2.5,
			"unit_limit": 7
		}
	},
	{
		"id": "enemy_master_006",
		"name": "姜拾烬",
		"title": "毁灭之焰",
		"level": 12,
		"faction": "flame",
		"difficulty": "medium",
		"equipment": {
			"phase_instrument": "pi_flame_03",
			"level": 12,
			"platforms": ["ww1_boss_av7", "ww1_arm_rolls_e", "ww1_arm_rolls_e", "ww1_inf_storm_e"],
			"weapons": ["flame_thrower_advanced", "incendiary_cannon_advanced"],
			"energy_cards": ["flame_energy_advanced"]
		},
		"stats": {
			"max_hp": 3400,
			"attack_power": 48,
			"defense": 23,
			"energy_regen": 3.0,
			"unit_limit": 7
		}
	},
]
