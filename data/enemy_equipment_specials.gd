## 特殊装备数据：相位仪 + 能量卡
## 由 enemy_phase_equipment.gd 拆分而来
extends RefCounted
class_name EnemyEquipmentSpecials

## 相位仪数据
const LEGACY_PHASE_INSTRUMENTS: Dictionary = {
	# ==================== 钢铁势力相位仪 ====================
	"steel_guardian_mk1": {
		"id": "steel_guardian_mk1",
		"name": "钢铁卫士·初阶",
		"faction": "steel",
		"level": 5,
		"rarity": "common",
		"base_stats": {
			"max_hp": 500,
			"energy_capacity": 100,
			"energy_regen": 1.0,
			"defense": 20
		},
		"special_effects": ["steel_skin_basic"],
		"atk_bonus": 1.67,
		"hp_bonus": 1.25,
		"def_bonus": 1.0
	},
	"steel_guardian_mk2": {
		"id": "steel_guardian_mk2",
		"name": "钢铁卫士·进阶",
		"faction": "steel",
		"level": 12,
		"rarity": "uncommon",
		"base_stats": {
			"max_hp": 800,
			"energy_capacity": 150,
			"energy_regen": 1.5,
			"defense": 35
		},
		"special_effects": ["steel_skin_advanced", "fortress_aura"],
		"atk_bonus": 4.4,
		"hp_bonus": 3.3,
		"def_bonus": 2.64
	},
	"steel_guardian_mk3": {
		"id": "steel_guardian_mk3",
		"name": "钢铁卫士·专家",
		"faction": "steel",
		"level": 18,
		"rarity": "rare",
		"base_stats": {
			"max_hp": 1200,
			"energy_capacity": 200,
			"energy_regen": 2.0,
			"defense": 50
		},
		"special_effects": ["steel_skin_expert", "fortress_mastery", "industrial_aura"],
		"atk_bonus": 7.5,
		"hp_bonus": 5.62,
		"def_bonus": 4.5
	},
	"steel_guardian_mk4": {
		"id": "steel_guardian_mk4",
		"name": "钢铁卫士·大师",
		"faction": "steel",
		"level": 25,
		"rarity": "mythic",
		"base_stats": {
			"max_hp": 2000,
			"energy_capacity": 300,
			"energy_regen": 2.5,
			"defense": 80
		},
		"special_effects": ["steel_skin_master", "immortal_fortress", "steel_mountain"],
		"atk_bonus": 13.33,
		"hp_bonus": 10.0,
		"def_bonus": 8.0
	},

	# ==================== 烈焰势力相位仪 ====================
	"flame_destroyer_mk1": {
		"id": "flame_destroyer_mk1",
		"name": "烈焰破坏者·初阶",
		"faction": "flame",
		"level": 6,
		"rarity": "common",
		"base_stats": {
			"max_hp": 450,
			"energy_capacity": 110,
			"energy_regen": 1.2,
			"attack_power": 15
		},
		"special_effects": ["burning_aura_basic"],
		"atk_bonus": 2.0,
		"hp_bonus": 1.5,
		"def_bonus": 1.2
	},
	"flame_destroyer_mk2": {
		"id": "flame_destroyer_mk2",
		"name": "烈焰破坏者·进阶",
		"faction": "flame",
		"level": 13,
		"rarity": "uncommon",
		"base_stats": {
			"max_hp": 700,
			"energy_capacity": 160,
			"energy_regen": 1.8,
			"attack_power": 25
		},
		"special_effects": ["burning_aura_advanced", "heat_wave"],
		"atk_bonus": 4.77,
		"hp_bonus": 3.58,
		"def_bonus": 2.86
	},
	"flame_destroyer_mk3": {
		"id": "flame_destroyer_mk3",
		"name": "烈焰破坏者·专家",
		"faction": "flame",
		"level": 19,
		"rarity": "rare",
		"base_stats": {
			"max_hp": 1000,
			"energy_capacity": 220,
			"energy_regen": 2.3,
			"attack_power": 40
		},
		"special_effects": ["burning_aura_expert", "hellfire", "immolation"],
		"atk_bonus": 7.92,
		"hp_bonus": 5.94,
		"def_bonus": 4.75
	},
	"flame_destroyer_mk4": {
		"id": "flame_destroyer_mk4",
		"name": "烈焰破坏者·大师",
		"faction": "flame",
		"level": 26,
		"rarity": "mythic",
		"base_stats": {
			"max_hp": 1800,
			"energy_capacity": 320,
			"energy_regen": 3.0,
			"attack_power": 60
		},
		"special_effects": ["eternal_flame", "world_burning", "phoenix_aura"],
		"atk_bonus": 13.87,
		"hp_bonus": 10.4,
		"def_bonus": 8.32
	},

	# ==================== 雷霆势力相位仪 ====================
	"thunder_storm_mk1": {
		"id": "thunder_storm_mk1",
		"name": "雷霆风暴·初阶",
		"faction": "thunder",
		"level": 7,
		"rarity": "common",
		"base_stats": {
			"max_hp": 420,
			"energy_capacity": 120,
			"energy_regen": 1.3,
			"attack_speed": 0.1
		},
		"special_effects": ["static_field_basic"],
		"atk_bonus": 2.33,
		"hp_bonus": 1.75,
		"def_bonus": 1.4
	},
	"thunder_storm_mk2": {
		"id": "thunder_storm_mk2",
		"name": "雷霆风暴·进阶",
		"faction": "thunder",
		"level": 14,
		"rarity": "uncommon",
		"base_stats": {
			"max_hp": 650,
			"energy_capacity": 170,
			"energy_regen": 1.9,
			"attack_speed": 0.2
		},
		"special_effects": ["static_field_advanced", "chain_lightning_passive"],
		"atk_bonus": 5.13,
		"hp_bonus": 3.85,
		"def_bonus": 3.08
	},
	"thunder_storm_mk3": {
		"id": "thunder_storm_mk3",
		"name": "雷霆风暴·专家",
		"faction": "thunder",
		"level": 20,
		"rarity": "rare",
		"base_stats": {
			"max_hp": 900,
			"energy_capacity": 240,
			"energy_regen": 2.5,
			"attack_speed": 0.3
		},
		"special_effects": ["static_field_expert", "lightning_speed", "overcharge"],
		"atk_bonus": 8.33,
		"hp_bonus": 6.25,
		"def_bonus": 5.0
	},
	"thunder_storm_mk4": {
		"id": "thunder_storm_mk4",
		"name": "雷霆风暴·大师",
		"faction": "thunder",
		"level": 27,
		"rarity": "mythic",
		"base_stats": {
			"max_hp": 1600,
			"energy_capacity": 350,
			"energy_regen": 3.2,
			"attack_speed": 0.5
		},
		"special_effects": ["omnipresent_lightning", "conductive_world", "thunder_god_aura"],
		"atk_bonus": 14.4,
		"hp_bonus": 10.8,
		"def_bonus": 8.64
	},

	# ==================== 虚空势力相位仪 ====================
	"void_walker_mk1": {
		"id": "void_walker_mk1",
		"name": "虚空行者·初阶",
		"faction": "void",
		"level": 8,
		"rarity": "common",
		"base_stats": {
			"max_hp": 480,
			"energy_capacity": 105,
			"energy_regen": 1.1,
			"magic_power": 20
		},
		"special_effects": ["entropy_aura_basic"],
		"atk_bonus": 2.67,
		"hp_bonus": 2.0,
		"def_bonus": 1.6
	},
	"void_walker_mk2": {
		"id": "void_walker_mk2",
		"name": "虚空行者·进阶",
		"faction": "void",
		"level": 15,
		"rarity": "uncommon",
		"base_stats": {
			"max_hp": 750,
			"energy_capacity": 155,
			"energy_regen": 1.7,
			"magic_power": 35
		},
		"special_effects": ["entropy_aura_advanced", "phase_shift"],
		"atk_bonus": 5.5,
		"hp_bonus": 4.12,
		"def_bonus": 3.3
	},
	"void_walker_mk3": {
		"id": "void_walker_mk3",
		"name": "虚空行者·专家",
		"faction": "void",
		"level": 21,
		"rarity": "rare",
		"base_stats": {
			"max_hp": 1100,
			"energy_capacity": 230,
			"energy_regen": 2.2,
			"magic_power": 55
		},
		"special_effects": ["entropy_aura_expert", "reality_tear", "void_embrace"],
		"atk_bonus": 8.75,
		"hp_bonus": 6.56,
		"def_bonus": 5.25
	},
	"void_walker_mk4": {
		"id": "void_walker_mk4",
		"name": "虚空行者·大师",
		"faction": "void",
		"level": 28,
		"rarity": "mythic",
		"base_stats": {
			"max_hp": 1700,
			"energy_capacity": 340,
			"energy_regen": 2.8,
			"magic_power": 80
		},
		"special_effects": ["void_lord", "reality_breakdown", "void_mastery_ultimate"],
		"atk_bonus": 14.93,
		"hp_bonus": 11.2,
		"def_bonus": 8.96
	},

	# ==================== 混合势力相位仪 ====================
	"hybrid_steel_flame_mk1": {
		"id": "hybrid_steel_flame_mk1",
		"name": "熔铸卫士",
		"faction": "steel_flame",
		"level": 16,
		"rarity": "rare",
		"base_stats": {
			"max_hp": 900,
			"energy_capacity": 180,
			"energy_regen": 2.0,
			"defense": 40,
			"attack_power": 30
		},
		"special_effects": ["molten_aura", "tempered_skin"],
		"atk_bonus": 6.67,
		"hp_bonus": 5.0,
		"def_bonus": 4.0
	},
	"hybrid_thunder_steel_mk1": {
		"id": "hybrid_thunder_steel_mk1",
		"name": "电磁卫士",
		"faction": "thunder_steel",
		"level": 17,
		"rarity": "rare",
		"base_stats": {
			"max_hp": 850,
			"energy_capacity": 190,
			"energy_regen": 2.1,
			"defense": 45,
			"attack_speed": 0.25
		},
		"special_effects": ["conductive_armor", "energized_shield"],
		"atk_bonus": 7.08,
		"hp_bonus": 5.31,
		"def_bonus": 4.25
	},
	"hybrid_void_flame_mk1": {
		"id": "hybrid_void_flame_mk1",
		"name": "熵增炎魔",
		"faction": "void_flame",
		"level": 18,
		"rarity": "rare",
		"base_stats": {
			"max_hp": 800,
			"energy_capacity": 200,
			"energy_regen": 2.0,
			"magic_power": 45,
			"attack_power": 35
		},
		"special_effects": ["chaos_aura", "entropy_flame_passive"],
		"atk_bonus": 7.5,
		"hp_bonus": 5.62,
		"def_bonus": 4.5
	},

	# ==================== 神级相位仪 ====================
	"steel_guardian_god": {
		"id": "steel_guardian_god",
		"name": "钢铁之神",
		"faction": "steel",
		"level": 29,
		"rarity": "mythic",
		"base_stats": {
			"max_hp": 3000,
			"energy_capacity": 500,
			"energy_regen": 4.0,
			"defense": 100
		},
		"special_effects": ["divine_protection", "godly_aura", "immortal_fortress"],
		"atk_bonus": 15.47,
		"hp_bonus": 11.6,
		"def_bonus": 9.28
	},
	"flame_destroyer_god": {
		"id": "flame_destroyer_god",
		"name": "炎魔之神",
		"faction": "flame",
		"level": 30,
		"rarity": "mythic",
		"base_stats": {
			"max_hp": 2800,
			"energy_capacity": 550,
			"energy_regen": 4.5,
			"attack_power": 100
		},
		"special_effects": ["immortal_flame", "world_burning", "hell_on_earth"],
		"atk_bonus": 16.0,
		"hp_bonus": 12.0,
		"def_bonus": 9.6
	},
	"thunder_storm_god": {
		"id": "thunder_storm_god",
		"name": "雷神",
		"faction": "thunder",
		"level": 30,
		"rarity": "mythic",
		"base_stats": {
			"max_hp": 2600,
			"energy_capacity": 520,
			"energy_regen": 4.8,
			"attack_power": 120,
			"attack_speed": 0.6
		},
		"special_effects": ["god_of_thunder", "infinite_energy", "thunder_dome_passive"],
		"atk_bonus": 16.0,
		"hp_bonus": 12.0,
		"def_bonus": 9.6
	},
	"void_walker_god": {
		"id": "void_walker_god",
		"name": "虚空女神",
		"faction": "void",
		"level": 30,
		"rarity": "mythic",
		"base_stats": {
			"max_hp": 2500,
			"energy_capacity": 500,
			"energy_regen": 4.2,
			"magic_power": 120
		},
		"special_effects": ["void_goddess", "night_everlasting", "reality_erasure"],
		"atk_bonus": 16.0,
		"hp_bonus": 12.0,
		"def_bonus": 9.6
	},
	"omega_instrument": {
		"id": "omega_instrument",
		"name": "奥米茄相位仪",
		"faction": "all",
		"level": 30,
		"rarity": "mythic",
		"base_stats": {
			"max_hp": 4000,
			"energy_capacity": 800,
			"energy_regen": 6.0,
			"all_stats_boost": 50
		},
		"special_effects": ["perfect_harmony", "master_of_all", "infinite_potential"],
		"atk_bonus": 16.0,
		"hp_bonus": 12.0,
		"def_bonus": 9.6
	},
	"hybrid_steel_thunder_mk1": {
		"id": "hybrid_steel_thunder_mk1",
		"name": "电磁卫士",
		"faction": "steel_thunder",
		"level": 24,
		"rarity": "epic",
		"base_stats": {
			"max_hp": 1100,
			"energy_capacity": 260,
			"energy_regen": 2.8,
			"defense": 55,
			"attack_speed": 0.35
		},
		"special_effects": ["conductive_armor", "energized_shield", "storm_forged"],
		"atk_bonus": 11.2,
		"hp_bonus": 8.4,
		"def_bonus": 6.72
	},
	"hybrid_flame_void_mk1": {
		"id": "hybrid_flame_void_mk1",
		"name": "混沌炎魔仪",
		"faction": "flame_void",
		"level": 25,
		"rarity": "epic",
		"base_stats": {
			"max_hp": 1000,
			"energy_capacity": 270,
			"energy_regen": 2.6,
			"magic_power": 55,
			"attack_power": 50
		},
		"special_effects": ["chaos_aura", "entropy_flame_passive", "dimensional_burn"],
		"atk_bonus": 11.67,
		"hp_bonus": 8.75,
		"def_bonus": 7.0
	}
}


## 能量卡数据
const LEGACY_ENERGY_CARDS: Dictionary = {
	"steel_energy_basic": {
		"id": "steel_energy_basic",
		"name": "钢铁能量·基础",
		"faction": "steel",
		"level": 5,
		"energy_amount": 50,
		"energy_regen_boost": 0.5,
		"special_effect": "steel_skin_boost"
	},
	"flame_energy_basic": {
		"id": "flame_energy_basic",
		"name": "烈焰能量·基础",
		"faction": "flame",
		"level": 6,
		"energy_amount": 60,
		"energy_regen_boost": 0.6,
		"special_effect": "burning_aura"
	},
	"thunder_energy_basic": {
		"id": "thunder_energy_basic",
		"name": "雷霆能量·基础",
		"faction": "thunder",
		"level": 7,
		"energy_amount": 55,
		"energy_regen_boost": 0.7,
		"special_effect": "static_field"
	},
	"void_energy_basic": {
		"id": "void_energy_basic",
		"name": "虚空能量·基础",
		"faction": "void",
		"level": 8,
		"energy_amount": 65,
		"energy_regen_boost": 0.8,
		"special_effect": "entropy_aura"
	},

	# ==================== 进阶能量卡 ====================
	"steel_energy_advanced": {
		"id": "steel_energy_advanced",
		"name": "钢铁能量·进阶",
		"faction": "steel",
		"level": 12,
		"energy_amount": 100,
		"energy_regen_boost": 1.0,
		"special_effect": "fortress_mode"
	},
	"flame_energy_advanced": {
		"id": "flame_energy_advanced",
		"name": "烈焰能量·进阶",
		"faction": "flame",
		"level": 13,
		"energy_amount": 120,
		"energy_regen_boost": 1.2,
		"special_effect": "heat_wave"
	},

	# ==================== 专家能量卡 ====================
	"steel_energy_expert": {
		"id": "steel_energy_expert",
		"name": "钢铁能量·专家",
		"faction": "steel",
		"level": 18,
		"energy_amount": 150,
		"energy_regen_boost": 1.5,
		"special_effect": "industrial_warfare"
	},
	"flame_energy_expert": {
		"id": "flame_energy_expert",
		"name": "烈焰能量·专家",
		"faction": "flame",
		"level": 19,
		"energy_amount": 180,
		"energy_regen_boost": 1.8,
		"special_effect": "eternal_flame"
	},

	# ==================== 混合能量卡 ====================
	"hybrid_energy_basic": {
		"id": "hybrid_energy_basic",
		"name": "混合能量·基础",
		"faction": "hybrid",
		"level": 16,
		"energy_amount": 80,
		"energy_regen_boost": 1.0,
		"special_effect": "hybrid_bonus"
	},
	"hybrid_energy_advanced": {
		"id": "hybrid_energy_advanced",
		"name": "混合能量·进阶",
		"faction": "hybrid",
		"level": 18,
		"energy_amount": 120,
		"energy_regen_boost": 1.4,
		"special_effect": "fusion_power"
	},

	# ==================== 神级能量卡 ====================
	"steel_energy_god": {
		"id": "steel_energy_god",
		"name": "钢铁神力",
		"faction": "steel",
		"level": 29,
		"energy_amount": 300,
		"energy_regen_boost": 3.0,
		"special_effect": "divine_protection_all"
	},
	"flame_energy_god": {
		"id": "flame_energy_god",
		"name": "炎魔神力",
		"faction": "flame",
		"level": 30,
		"energy_amount": 350,
		"energy_regen_boost": 3.5,
		"special_effect": "immortal_flame_all"
	},
	"thunder_energy_god": {
		"id": "thunder_energy_god",
		"name": "雷霆神力",
		"faction": "thunder",
		"level": 30,
		"energy_amount": 320,
		"energy_regen_boost": 4.0,
		"special_effect": "thunder_god_avatar"
	},
	"void_energy_god": {
		"id": "void_energy_god",
		"name": "虚空神力",
		"faction": "void",
		"level": 30,
		"energy_amount": 330,
		"energy_regen_boost": 3.8,
		"special_effect": "void_goddess_transformation"
	},
	"hybrid_energy_god": {
		"id": "hybrid_energy_god",
		"name": "奥米茄能量",
		"faction": "all",
		"level": 30,
		"energy_amount": 500,
		"energy_regen_boost": 5.0,
		"special_effect": "perfect_harmony_all"
	},

	# ==================== 补充能量卡 ====================
	"thunder_energy_advanced": {
		"id": "thunder_energy_advanced",
		"name": "雷霆能量·进阶",
		"faction": "thunder",
		"level": 14,
		"energy_amount": 90,
		"energy_regen_boost": 1.0,
		"special_effect": "chain_boost"
	},
	"void_energy_advanced": {
		"id": "void_energy_advanced",
		"name": "虚空能量·进阶",
		"faction": "void",
		"level": 15,
		"energy_amount": 100,
		"energy_regen_boost": 1.1,
		"special_effect": "entropy_drain_boost"
	},
	"thunder_energy_expert": {
		"id": "thunder_energy_expert",
		"name": "雷霆能量·专家",
		"faction": "thunder",
		"level": 20,
		"energy_amount": 140,
		"energy_regen_boost": 1.6,
		"special_effect": "storm_command"
	},
	"void_energy_expert": {
		"id": "void_energy_expert",
		"name": "虚空能量·专家",
		"faction": "void",
		"level": 21,
		"energy_amount": 160,
		"energy_regen_boost": 1.8,
		"special_effect": "void_mastery_energy"
	}
}

