extends RefCounted
class_name EnemyPhaseEquipment

const _INSTRUMENTS_JSON_PATH := "res://data/json/enemy_phase_instruments.json"
const _PLATFORMS_JSON_PATH := "res://data/json/enemy_phase_platforms.json"
const _WEAPONS_JSON_PATH := "res://data/json/enemy_phase_weapons.json"
const _ENERGY_JSON_PATH := "res://data/json/enemy_phase_energy_cards.json"

static var PHASE_INSTRUMENTS: Dictionary = _load_json_dict(_INSTRUMENTS_JSON_PATH, LEGACY_PHASE_INSTRUMENTS)
static var WAR_PLATFORMS: Dictionary = _load_json_dict(_PLATFORMS_JSON_PATH, LEGACY_WAR_PLATFORMS)
static var WAR_WEAPONS: Dictionary = _load_json_dict(_WEAPONS_JSON_PATH, LEGACY_WAR_WEAPONS)
static var ENERGY_CARDS: Dictionary = _load_json_dict(_ENERGY_JSON_PATH, LEGACY_ENERGY_CARDS)

static func _load_json_dict(path: String, fallback: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("[EnemyPhaseEquipment] JSON missing: %s" % path)
		return fallback
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema_version", 0)) != 1:
		return fallback
	var data = parsed.get("data", fallback)
	return data if typeof(data) == TYPE_DICTIONARY else fallback

## 敌方相位师装备数据：相位仪、平台、武器、能量卡

const GC = preload("res://resources/game_constants.gd")

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
		"special_effects": ["steel_skin_basic"]
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
		"special_effects": ["steel_skin_advanced", "fortress_aura"]
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
		"special_effects": ["steel_skin_expert", "fortress_mastery", "industrial_aura"]
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
		"special_effects": ["steel_skin_master", "immortal_fortress", "steel_mountain"]
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
		"special_effects": ["burning_aura_basic"]
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
		"special_effects": ["burning_aura_advanced", "heat_wave"]
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
		"special_effects": ["burning_aura_expert", "hellfire", "immolation"]
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
		"special_effects": ["eternal_flame", "world_burning", "phoenix_aura"]
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
		"special_effects": ["static_field_basic"]
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
		"special_effects": ["static_field_advanced", "chain_lightning_passive"]
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
		"special_effects": ["static_field_expert", "lightning_speed", "overcharge"]
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
		"special_effects": ["omnipresent_lightning", "conductive_world", "thunder_god_aura"]
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
		"special_effects": ["entropy_aura_basic"]
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
		"special_effects": ["entropy_aura_advanced", "phase_shift"]
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
		"special_effects": ["entropy_aura_expert", "reality_tear", "void_embrace"]
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
		"special_effects": ["void_lord", "reality_breakdown", "void_mastery_ultimate"]
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
		"special_effects": ["molten_aura", "tempered_skin"]
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
		"special_effects": ["conductive_armor", "energized_shield"]
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
		"special_effects": ["chaos_aura", "entropy_flame_passive"]
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
		"special_effects": ["divine_protection", "godly_aura", "immortal_fortress"]
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
		"special_effects": ["immortal_flame", "world_burning", "hell_on_earth"]
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
		"special_effects": ["god_of_thunder", "infinite_energy", "thunder_dome_passive"]
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
		"special_effects": ["void_goddess", "night_everlasting", "reality_erasure"]
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
		"special_effects": ["perfect_harmony", "master_of_all", "infinite_potential"]
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
		"special_effects": ["conductive_armor", "energized_shield", "storm_forged"]
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
		"special_effects": ["chaos_aura", "entropy_flame_passive", "dimensional_burn"]
	}
}

## 战争平台数据
const LEGACY_WAR_PLATFORMS: Dictionary = {
	# ==================== 钢铁平台 ====================
	"steel_fortress_basic": {
		"id": "steel_fortress_basic",
		"name": "【钢铁·基础】要塞固定炮平台",
		"faction": "steel",
		"level": 5,
		"type": "fortress",
		"stats": {
			"hp": 1500,
			"attack": 80,
			"defense": 100,
			"move_speed": 20,
			"attack_speed": 1.0
		},
		"special": ["stationary", "high_defense"]
	},
	"steel_titan_basic": {
		"id": "steel_titan_basic",
		"name": "【钢铁·基础】马克V型坦克平台",
		"faction": "steel",
		"level": 5,
		"type": "titan",
		"stats": {
			"hp": 1200,
			"attack": 100,
			"defense": 80,
			"move_speed": 35,
			"attack_speed": 0.9
		},
		"special": ["heavy_armor", "slow_but_strong"]
	},
	"steel_fortress_advanced": {
		"id": "steel_fortress_advanced",
		"name": "【钢铁·进阶】要塞固定炮平台",
		"faction": "steel",
		"level": 12,
		"type": "fortress",
		"stats": {
			"hp": 2500,
			"attack": 150,
			"defense": 180,
			"move_speed": 15,
			"attack_speed": 0.8
		},
		"special": ["stationary", "artillery_support"]
	},
	"steel_titan_advanced": {
		"id": "steel_titan_advanced",
		"name": "【钢铁·进阶】马克V型坦克平台",
		"faction": "steel",
		"level": 12,
		"type": "titan",
		"stats": {
			"hp": 2000,
			"attack": 180,
			"defense": 140,
			"move_speed": 30,
			"attack_speed": 0.85
		},
		"special": ["heavy_armor", "regeneration"]
	},
	"steel_fortress_expert": {
		"id": "steel_fortress_expert",
		"name": "【钢铁·专家】要塞固定炮平台",
		"faction": "steel",
		"level": 18,
		"type": "fortress",
		"stats": {
			"hp": 4000,
			"attack": 250,
			"defense": 250,
			"move_speed": 10,
			"attack_speed": 0.7
		},
		"special": ["stationary", "fortress_mode", "repair_aura"]
	},
	"steel_titan_expert": {
		"id": "steel_titan_expert",
		"name": "【钢铁·专家】马克V型坦克平台",
		"faction": "steel",
		"level": 18,
		"type": "titan",
		"stats": {
			"hp": 3500,
			"attack": 300,
			"defense": 200,
			"move_speed": 25,
			"attack_speed": 0.8
		},
		"special": ["heavy_armor", "adaptive_defense"]
	},

	# ==================== 烈焰平台 ====================
	"flame_raider_basic": {
		"id": "flame_raider_basic",
		"name": "【烈焰·基础】BA-64轻型突击车平台",
		"faction": "flame",
		"level": 6,
		"type": "raider",
		"stats": {
			"hp": 900,
			"attack": 120,
			"defense": 40,
			"move_speed": 60,
			"attack_speed": 1.2
		},
		"special": ["fast_attack", "burning_touch"]
	},
	"flame_siege_basic": {
		"id": "flame_siege_basic",
		"name": "【烈焰·基础】203毫米迫击炮平台",
		"faction": "flame",
		"level": 6,
		"type": "siege",
		"stats": {
			"hp": 1100,
			"attack": 150,
			"defense": 60,
			"move_speed": 25,
			"attack_speed": 0.7
		},
		"special": ["explosive_attack", "area_damage"]
	},
	"flame_raider_advanced": {
		"id": "flame_raider_advanced",
		"name": "【烈焰·进阶】BA-64轻型突击车平台",
		"faction": "flame",
		"level": 13,
		"type": "raider",
		"stats": {
			"hp": 1400,
			"attack": 200,
			"defense": 50,
			"move_speed": 70,
			"attack_speed": 1.4
		},
		"special": ["fast_attack", "flame_trail"]
	},
	"flame_siege_advanced": {
		"id": "flame_siege_advanced",
		"name": "【烈焰·进阶】203毫米迫击炮平台",
		"faction": "flame",
		"level": 13,
		"type": "siege",
		"stats": {
			"hp": 1800,
			"attack": 250,
			"defense": 80,
			"move_speed": 20,
			"attack_speed": 0.6
		},
		"special": ["explosive_attack", "incendiary_mortar"]
	},

	# ==================== 雷霆平台 ====================
	"thunter_striker_basic": {
		"id": "thunter_striker_basic",
		"name": "雷霆打击者·基础",
		"faction": "thunder",
		"level": 7,
		"type": "striker",
		"stats": {
			"hp": 800,
			"attack": 140,
			"defense": 35,
			"move_speed": 65,
			"attack_speed": 1.5
		},
		"special": ["lightning_attack", "critical_boost"]
	},
	"thunter_sniper_basic": {
		"id": "thunter_sniper_basic",
		"name": "雷霆狙击手·基础",
		"faction": "thunder",
		"level": 7,
		"type": "sniper",
		"stats": {
			"hp": 600,
			"attack": 200,
			"defense": 20,
			"move_speed": 30,
			"attack_speed": 0.5
		},
		"special": ["long_range", "precision_strike"]
	},

	# ==================== 虚空平台 ====================
	"void_stealth_basic": {
		"id": "void_stealth_basic",
		"name": "虚空潜行者·基础",
		"faction": "void",
		"level": 8,
		"type": "stealth",
		"stats": {
			"hp": 700,
			"attack": 130,
			"defense": 30,
			"move_speed": 80,
			"attack_speed": 1.3
		},
		"special": ["invisibility", "backstab"]
	},
	"void_mage_basic": {
		"id": "void_mage_basic",
		"name": "虚空法师·基础",
		"faction": "void",
		"level": 8,
		"type": "mage",
		"stats": {
			"hp": 650,
			"attack": 180,
			"defense": 25,
			"move_speed": 35,
			"attack_speed": 0.8
		},
		"special": ["void_magic", "entropy_spells"]
	},

	# ==================== 烈焰平台·专家 ====================
	"flame_raider_expert": {
		"id": "flame_raider_expert",
		"name": "【烈焰·专家】BA-64轻型突击车平台",
		"faction": "flame",
		"level": 19,
		"type": "raider",
		"stats": {
			"hp": 2000,
			"attack": 320,
			"defense": 60,
			"move_speed": 80,
			"attack_speed": 1.6
		},
		"special": ["fast_attack", "flame_trail", "burning_fury"]
	},
	"flame_siege_expert": {
		"id": "flame_siege_expert",
		"name": "【烈焰·专家】203毫米迫击炮平台",
		"faction": "flame",
		"level": 19,
		"type": "siege",
		"stats": {
			"hp": 2800,
			"attack": 380,
			"defense": 90,
			"move_speed": 18,
			"attack_speed": 0.5
		},
		"special": ["explosive_attack", "incendiary_mortar", "heat_wave_aura"]
	},

	# ==================== 雷霆平台·进阶与专家 ====================
	"thunter_striker_advanced": {
		"id": "thunter_striker_advanced",
		"name": "雷霆打击者·进阶",
		"faction": "thunder",
		"level": 14,
		"type": "striker",
		"stats": {
			"hp": 1200,
			"attack": 220,
			"defense": 50,
			"move_speed": 75,
			"attack_speed": 1.8
		},
		"special": ["lightning_attack", "critical_boost", "static_discharge"]
	},
	"thunter_sniper_advanced": {
		"id": "thunter_sniper_advanced",
		"name": "雷霆狙击手·进阶",
		"faction": "thunder",
		"level": 14,
		"type": "sniper",
		"stats": {
			"hp": 900,
			"attack": 320,
			"defense": 30,
			"move_speed": 35,
			"attack_speed": 0.4
		},
		"special": ["long_range", "precision_strike", "armor_pierce"]
	},
	"thunter_striker_expert": {
		"id": "thunter_striker_expert",
		"name": "雷霆打击者·专家",
		"faction": "thunder",
		"level": 20,
		"type": "striker",
		"stats": {
			"hp": 1800,
			"attack": 350,
			"defense": 65,
			"move_speed": 85,
			"attack_speed": 2.0
		},
		"special": ["lightning_attack", "critical_boost", "storm_dash", "chain_strike"]
	},
	"thunter_sniper_expert": {
		"id": "thunter_sniper_expert",
		"name": "雷霆狙击手·专家",
		"faction": "thunder",
		"level": 20,
		"type": "sniper",
		"stats": {
			"hp": 1300,
			"attack": 500,
			"defense": 40,
			"move_speed": 40,
			"attack_speed": 0.3
		},
		"special": ["long_range", "precision_strike", "headshot", "railgun_support"]
	},

	# ==================== 虚空平台·进阶与专家 ====================
	"void_stealth_advanced": {
		"id": "void_stealth_advanced",
		"name": "虚空潜行者·进阶",
		"faction": "void",
		"level": 15,
		"type": "stealth",
		"stats": {
			"hp": 1100,
			"attack": 200,
			"defense": 45,
			"move_speed": 95,
			"attack_speed": 1.5
		},
		"special": ["invisibility", "backstab", "phase_shift"]
	},
	"void_mage_advanced": {
		"id": "void_mage_advanced",
		"name": "虚空法师·进阶",
		"faction": "void",
		"level": 15,
		"type": "mage",
		"stats": {
			"hp": 1000,
			"attack": 280,
			"defense": 35,
			"move_speed": 40,
			"attack_speed": 0.7
		},
		"special": ["void_magic", "entropy_spells", "dimensional_rift"]
	},
	"void_stealth_expert": {
		"id": "void_stealth_expert",
		"name": "虚空潜行者·专家",
		"faction": "void",
		"level": 21,
		"type": "stealth",
		"stats": {
			"hp": 1600,
			"attack": 320,
			"defense": 60,
			"move_speed": 110,
			"attack_speed": 1.8
		},
		"special": ["invisibility", "backstab", "shadow_step", "reality_tear"]
	},
	"void_mage_expert": {
		"id": "void_mage_expert",
		"name": "虚空法师·专家",
		"faction": "void",
		"level": 21,
		"type": "mage",
		"stats": {
			"hp": 1500,
			"attack": 420,
			"defense": 50,
			"move_speed": 45,
			"attack_speed": 0.6
		},
		"special": ["void_magic", "entropy_spells", "gravity_control", "black_hole_mini"]
	}
}

## 战争武器数据
const LEGACY_WAR_WEAPONS: Dictionary = {
	# ==================== 钢铁武器 ====================
	"steel_machinegun_basic": {
		"id": "steel_machinegun_basic",
		"name": "钢铁机枪·基础",
		"faction": "steel",
		"level": 5,
		"type": "machinegun",
		"damage": 25,
		"attack_speed": 0.15,
		"range": 200,
		"special": ["sustained_fire"]
	},
	"steel_cannon_basic": {
		"id": "steel_cannon_basic",
		"name": "钢铁火炮·基础",
		"faction": "steel",
		"level": 5,
		"type": "cannon",
		"damage": 80,
		"attack_speed": 1.5,
		"range": 300,
		"special": ["explosive_shell", "splash_damage"]
	},
	"steel_minigun_advanced": {
		"id": "steel_minigun_advanced",
		"name": "钢铁转轮机枪·进阶",
		"faction": "steel",
		"level": 12,
		"type": "machinegun",
		"damage": 35,
		"attack_speed": 0.08,
		"range": 220,
		"special": ["rapid_fire", "overheat"]
	},
	"steel_railcannon_advanced": {
		"id": "steel_railcannon_advanced",
		"name": "钢铁电磁炮·进阶",
		"faction": "steel",
		"level": 12,
		"type": "railcannon",
		"damage": 150,
		"attack_speed": 2.0,
		"range": 400,
		"special": ["piercing", "high_velocity"]
	},

	# ==================== 烈焰武器 ====================
	"flame_thrower_basic": {
		"id": "flame_thrower_basic",
		"name": "火焰喷射器·基础",
		"faction": "flame",
		"level": 6,
		"type": "flamethrower",
		"damage": 40,
		"attack_speed": 0.1,
		"range": 120,
		"special": ["continuous_damage", "ignite"]
	},
	"incendiary_mortar_basic": {
		"id": "incendiary_mortar_basic",
		"name": "燃烧迫击炮·基础",
		"faction": "flame",
		"level": 6,
		"type": "mortar",
		"damage": 100,
		"attack_speed": 2.5,
		"range": 350,
		"special": ["incendiary", "area_denial"]
	},

	# ==================== 雷霆武器 ====================
	"tesla_coil_basic": {
		"id": "tesla_coil_basic",
		"name": "特斯拉线圈·基础",
		"faction": "thunder",
		"level": 7,
		"type": "tesla",
		"damage": 45,
		"attack_speed": 0.5,
		"range": 180,
		"special": ["chain_lightning", "arc_damage"]
	},
	"railgun_basic": {
		"id": "railgun_basic",
		"name": "电磁炮·基础",
		"faction": "thunder",
		"level": 7,
		"type": "railgun",
		"damage": 120,
		"attack_speed": 1.8,
		"range": 500,
		"special": ["single_target", "armor_pierce"]
	},

	# ==================== 虚空武器 ====================
	"void_lance_basic": {
		"id": "void_lance_basic",
		"name": "虚空长矛·基础",
		"faction": "void",
		"level": 8,
		"type": "lance",
		"damage": 90,
		"attack_speed": 1.2,
		"range": 150,
		"special": ["life_steal", "void_corruption"]
	},
	"gravity_well_basic": {
		"id": "gravity_well_basic",
		"name": "重力井·基础",
		"faction": "void",
		"level": 8,
		"type": "gravity",
		"damage": 60,
		"attack_speed": 2.0,
		"range": 200,
		"special": ["pull_enemies", "area_control"]
	},

	# ==================== 烈焰武器·进阶与专家 ====================
	"flame_thrower_advanced": {
		"id": "flame_thrower_advanced",
		"name": "火焰喷射器·进阶",
		"faction": "flame",
		"level": 13,
		"type": "flamethrower",
		"damage": 65,
		"attack_speed": 0.08,
		"range": 140,
		"special": ["continuous_damage", "ignite", "flame_trail"]
	},
	"incendiary_cannon_advanced": {
		"id": "incendiary_cannon_advanced",
		"name": "燃烧炮·进阶",
		"faction": "flame",
		"level": 13,
		"type": "mortar",
		"damage": 160,
		"attack_speed": 2.0,
		"range": 380,
		"special": ["incendiary", "area_denial", "cluster_bomb"]
	},
	"flame_thrower_expert": {
		"id": "flame_thrower_expert",
		"name": "等离子喷射器·专家",
		"faction": "flame",
		"level": 19,
		"type": "flamethrower",
		"damage": 100,
		"attack_speed": 0.06,
		"range": 160,
		"special": ["continuous_damage", "ignite", "plasma_burn", "melting"]
	},
	"plasma_cannon_expert": {
		"id": "plasma_cannon_expert",
		"name": "等离子炮·专家",
		"faction": "flame",
		"level": 19,
		"type": "cannon",
		"damage": 280,
		"attack_speed": 1.5,
		"range": 400,
		"special": ["explosive_shell", "plasma_explosion", "armor_melt"]
	},

	# ==================== 雷霆武器·进阶与专家 ====================
	"tesla_coil_advanced": {
		"id": "tesla_coil_advanced",
		"name": "特斯拉线圈·进阶",
		"faction": "thunder",
		"level": 14,
		"type": "tesla",
		"damage": 75,
		"attack_speed": 0.4,
		"range": 200,
		"special": ["chain_lightning", "arc_damage", "overcharge"]
	},
	"railgun_advanced": {
		"id": "railgun_advanced",
		"name": "电磁炮·进阶",
		"faction": "thunder",
		"level": 14,
		"type": "railgun",
		"damage": 200,
		"attack_speed": 1.5,
		"range": 550,
		"special": ["single_target", "armor_pierce", "shockwave"]
	},
	"tesla_coil_expert": {
		"id": "tesla_coil_expert",
		"name": "特斯拉线圈·专家",
		"faction": "thunder",
		"level": 20,
		"type": "tesla",
		"damage": 120,
		"attack_speed": 0.3,
		"range": 250,
		"special": ["chain_lightning", "arc_damage", "storm_field", "emp_pulse"]
	},
	"railgun_expert": {
		"id": "railgun_expert",
		"name": "电磁炮·专家",
		"faction": "thunder",
		"level": 20,
		"type": "railgun",
		"damage": 320,
		"attack_speed": 1.2,
		"range": 600,
		"special": ["single_target", "armor_pierce", "railgun_burst", "thunder_strike"]
	},

	# ==================== 虚空武器·进阶与专家 ====================
	"void_lance_advanced": {
		"id": "void_lance_advanced",
		"name": "虚空长矛·进阶",
		"faction": "void",
		"level": 15,
		"type": "lance",
		"damage": 140,
		"attack_speed": 1.0,
		"range": 170,
		"special": ["life_steal", "void_corruption", "phase_strike"]
	},
	"gravity_well_advanced": {
		"id": "gravity_well_advanced",
		"name": "重力井·进阶",
		"faction": "void",
		"level": 15,
		"type": "gravity",
		"damage": 100,
		"attack_speed": 1.5,
		"range": 250,
		"special": ["pull_enemies", "area_control", "gravity_crush"]
	},
	"void_lance_expert": {
		"id": "void_lance_expert",
		"name": "虚空长矛·专家",
		"faction": "void",
		"level": 21,
		"type": "lance",
		"damage": 220,
		"attack_speed": 0.8,
		"range": 190,
		"special": ["life_steal", "void_corruption", "dimensional_slash", "reality_tear"]
	},
	"entropy_caster_expert": {
		"id": "entropy_caster_expert",
		"name": "熵增法杖·专家",
		"faction": "void",
		"level": 21,
		"type": "gravity",
		"damage": 180,
		"attack_speed": 1.2,
		"range": 280,
		"special": ["pull_enemies", "entropy_drain", "black_hole_channel", "void_eruption"]
	},

	# ==================== 钢铁武器·专家 ====================
	"steel_gatling_expert": {
		"id": "steel_gatling_expert",
		"name": "钢铁转轮机枪·专家",
		"faction": "steel",
		"level": 18,
		"type": "machinegun",
		"damage": 50,
		"attack_speed": 0.05,
		"range": 250,
		"special": ["rapid_fire", "overheat", "armor_pierce_light", "sustained_suppression"]
	},
	"steel_artillery_expert": {
		"id": "steel_artillery_expert",
		"name": "钢铁重炮·专家",
		"faction": "steel",
		"level": 18,
		"type": "cannon",
		"damage": 220,
		"attack_speed": 1.8,
		"range": 450,
		"special": ["explosive_shell", "splash_damage", "fortress_breaker", "cluster_shell"]
	}
}

## 能量卡数据
const LEGACY_ENERGY_CARDS: Dictionary = {
	# ==================== 基础能量卡 ====================
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

## 战争平台 type 字符串 -> GameConstants.PlatformType（用于蓝图库 CardResource）
const _WAR_PLATFORM_TYPE_MAP: Dictionary = {
	"fortress": GC.PlatformType.FORTRESS,
	"titan": GC.PlatformType.TITAN,
	"raider": GC.PlatformType.RAIDER,
	"siege": GC.PlatformType.SIEGE,
	"striker": GC.PlatformType.RAIDER,
	"sniper": GC.PlatformType.SCOUT,
	"stealth": GC.PlatformType.STEALTH,
	"mage": GC.PlatformType.OMEGA_PLATFORM,
}

## 战争武器 type 字符串 -> GameConstants.WeaponType
const _WAR_WEAPON_TYPE_MAP: Dictionary = {
	"machinegun": GC.WeaponType.MG,
	"cannon": GC.WeaponType.ROCKET,
	"railcannon": GC.WeaponType.RAIL_CANNON,
	"flamethrower": GC.WeaponType.FLAK,
	"mortar": GC.WeaponType.ROCKET,
	"tesla": GC.WeaponType.LASER,
	"railgun": GC.WeaponType.RAIL_CANNON,
	"lance": GC.WeaponType.LASER,
	"gravity": GC.WeaponType.MISSILE,
}

## 将敌方相位师装备 ID 转为蓝图库/解析 UI 用的 CardResource（仅展示）
static func get_equipment_blueprint(equipment_id: String) -> CardResource:
	if equipment_id.is_empty():
		return null
	var pdata: Dictionary = get_war_platform(equipment_id)
	if not pdata.is_empty():
		return _card_resource_from_war_platform(pdata, equipment_id)
	var wdata: Dictionary = get_war_weapon(equipment_id)
	if not wdata.is_empty():
		return _card_resource_from_war_weapon(wdata, equipment_id)
	var edata: Dictionary = get_energy_card(equipment_id)
	if not edata.is_empty():
		return _card_resource_from_energy_card(edata, equipment_id)
	var idata: Dictionary = get_phase_instrument(equipment_id)
	if not idata.is_empty():
		return _card_resource_from_phase_instrument(idata, equipment_id)
	return null

static func _card_resource_from_war_platform(d: Dictionary, equipment_id: String) -> CardResource:
	var c := CardResource.new()
	c.card_id = equipment_id
	c.display_name = String(d.get("name", equipment_id))
	c.rarity = String(d.get("rarity", "common"))
	var ptype: String = String(d.get("type", "titan"))
	c.card_type = GC.CardType.PLATFORM
	c.platform_type = int(_WAR_PLATFORM_TYPE_MAP.get(ptype, GC.PlatformType.TITAN))
	c.energy_cost = 5.0 + float(d.get("level", 5)) * 0.3
	c.type_line = "平台 — %s／敌方相位师" % String(d.get("faction", ""))
	var stats: Dictionary = d.get("stats", {}) as Dictionary
	c.summary_line = "耐久 %d｜攻击 %d｜移速 %d" % [
		int(stats.get("hp", 0)), int(stats.get("attack", 0)), int(stats.get("move_speed", 0))]
	c.description = "由敌方相位师装备数据生成的平台蓝图（展示用）。"
	c.flavor_text = ""
	c.max_weapons = 2
	c.weight_capacity = 0
	return c

static func _card_resource_from_war_weapon(d: Dictionary, equipment_id: String) -> CardResource:
	var c := CardResource.new()
	c.card_id = equipment_id
	c.display_name = String(d.get("name", equipment_id))
	c.rarity = String(d.get("rarity", "common"))
	var wtype: String = String(d.get("type", "machinegun"))
	c.card_type = GC.CardType.WEAPON
	c.weapon_type = int(_WAR_WEAPON_TYPE_MAP.get(wtype, GC.WeaponType.MG))
	c.energy_cost = 4.0 + float(d.get("level", 5)) * 0.25
	c.type_line = "武器 — %s／敌方相位师" % String(d.get("faction", ""))
	c.summary_line = "伤害 %d｜攻速 %.2f｜射程 %d" % [
		int(d.get("damage", 0)), float(d.get("attack_speed", 0.0)), int(d.get("range", 0))]
	c.description = "由敌方相位师装备数据生成的武器蓝图（展示用）。"
	c.weight = 1
	return c

static func _card_resource_from_energy_card(d: Dictionary, equipment_id: String) -> CardResource:
	var c := CardResource.new()
	c.card_id = equipment_id
	c.display_name = String(d.get("name", equipment_id))
	c.rarity = String(d.get("rarity", "common"))
	c.card_type = GC.CardType.ENERGY
	c.energy_cost = 0.0
	c.energy_grant = float(d.get("energy_amount", 15))
	c.type_line = "能量 — %s／敌方相位师" % String(d.get("faction", ""))
	c.summary_line = "能量 +%.0f｜回充 +%.1f" % [
		float(d.get("energy_amount", 0.0)), float(d.get("energy_regen_boost", 0.0))]
	c.description = "由敌方相位师装备数据生成的能量卡蓝图（展示用）。"
	return c

static func _card_resource_from_phase_instrument(d: Dictionary, equipment_id: String) -> CardResource:
	var c := CardResource.new()
	c.card_id = equipment_id
	c.display_name = String(d.get("name", equipment_id))
	c.rarity = String(d.get("rarity", "common"))
	c.card_type = GC.CardType.PLATFORM
	c.platform_type = GC.PlatformType.OMEGA_PLATFORM
	c.energy_cost = 6.0 + float(d.get("level", 5)) * 0.35
	c.type_line = "相位仪 — %s" % String(d.get("faction", ""))
	var bs: Dictionary = d.get("base_stats", {}) as Dictionary
	c.summary_line = "Lv.%d｜耐久 %d｜能量 %d" % [
		int(d.get("level", 0)), int(bs.get("max_hp", 0)), int(bs.get("energy_capacity", 0))]
	c.description = "由敌方相位师装备数据生成的相位仪蓝图（展示用）。"
	c.max_weapons = 0
	return c

## 获取相位仪数据
static func get_phase_instrument(instrument_id: String) -> Dictionary:
	if PHASE_INSTRUMENTS.has(instrument_id):
		return PHASE_INSTRUMENTS[instrument_id]
	return {}

## 获取平台数据
static func get_war_platform(platform_id: String) -> Dictionary:
	if WAR_PLATFORMS.has(platform_id):
		return WAR_PLATFORMS[platform_id]
	return {}


## 敌方平台卡绑定的默认武器 id（`enemy_phase_platforms.json` 字段 `default_weapon`）
static func get_default_weapon_id_for_platform(platform_id: String) -> String:
	var d: Dictionary = get_war_platform(platform_id)
	if d.is_empty():
		return ""
	return String(d.get("default_weapon", "")).strip_edges()


## 获取武器数据
static func get_war_weapon(weapon_id: String) -> Dictionary:
	if WAR_WEAPONS.has(weapon_id):
		return WAR_WEAPONS[weapon_id]
	return {}

## 获取能量卡数据
static func get_energy_card(card_id: String) -> Dictionary:
	if ENERGY_CARDS.has(card_id):
		return ENERGY_CARDS[card_id]
	return {}

## 根据等级获取可用装备
static func get_equipment_by_level(level: int) -> Dictionary:
	var result = {
		"phase_instruments": [],
		"platforms": [],
		"weapons": [],
		"energy_cards": []
	}

	for instrument_id in PHASE_INSTRUMENTS:
		var instrument = PHASE_INSTRUMENTS[instrument_id]
		if instrument.level <= level + 5:  # 允许使用稍高等级的装备
			result.phase_instruments.append(instrument_id)

	for platform_id in WAR_PLATFORMS:
		var platform = WAR_PLATFORMS[platform_id]
		if platform.level <= level + 3:
			result.platforms.append(platform_id)

	for weapon_id in WAR_WEAPONS:
		var weapon = WAR_WEAPONS[weapon_id]
		if weapon.level <= level + 3:
			result.weapons.append(weapon_id)

	for card_id in ENERGY_CARDS:
		var card = ENERGY_CARDS[card_id]
		if card.level <= level + 2:
			result.energy_cards.append(card_id)

	return result

## 根据势力获取装备
static func get_equipment_by_faction(faction: String) -> Dictionary:
	var result = {
		"phase_instruments": [],
		"platforms": [],
		"weapons": [],
		"energy_cards": []
	}

	var faction_prefix = faction.split("_")[0]

	for instrument_id in PHASE_INSTRUMENTS:
		if instrument_id.contains(faction_prefix):
			result.phase_instruments.append(instrument_id)

	for platform_id in WAR_PLATFORMS:
		if platform_id.contains(faction_prefix):
			result.platforms.append(platform_id)

	for weapon_id in WAR_WEAPONS:
		if weapon_id.contains(faction_prefix):
			result.weapons.append(weapon_id)

	for card_id in ENERGY_CARDS:
		if card_id.contains(faction_prefix):
			result.energy_cards.append(card_id)

	return result
