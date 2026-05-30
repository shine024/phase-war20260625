## 近未来敌人原型数据
## 由 enemy_archetypes.gd 拆分而来
extends RefCounted
class_name EnemyArchetypesFuture

const DATA := {
	# ==================== 近未来敌人（7种） ====================

	# 基础敌人（4种）
	"enemy_future_drone": {
		"swarm_unit": true,
		"era": 4,
		"display_name": "无人机群",
		"hp": 40.0,
		"speed": -150.0,
		"attack_damage": 12.0,
		"attack_range": 180.0,
		"attack_interval": 0.4,
		"weapon_type": 8,
		"tags": ["aircraft", "fast"],
		"drops": [],
	},
	"enemy_future_cyborg": {
		"swarm_unit": true,
		"era": 4,
		"display_name": "机械步兵",
		"hp": 100.0,
		"speed": -100.0,
		"attack_damage": 22.0,
		"attack_range": 160.0,
		"attack_interval": 0.25,
		"weapon_type": 8,
		"tags": ["infantry", "frontline"],
		"drops": [],
	},
	"enemy_future_mech": {
		"era": 4,
		"display_name": "机甲步兵",
		"hp": 180.0,
		"speed": -80.0,
		"attack_damage": 30.0,
		"attack_range": 150.0,
		"attack_interval": 0.67,
		"weapon_type": 8,
		"tags": ["vehicle", "armored"],
		"drops": [],
	},
	"enemy_future_hovertank": {
		"era": 4,
		"display_name": "悬浮坦克",
		"hp": 250.0,
		"speed": -110.0,
		"attack_damage": 40.0,
		"attack_range": 250.0,
		"attack_interval": 0.5,
		"weapon_type": 8,
		"tags": ["vehicle", "armored", "fast"],
		"drops": [],
	},

	# 精英敌人（2种）
	"elite_future_spectre": {
		"era": 4,
		"display_name": "幽灵特工",
		"hp": 120.0,
		"speed": -140.0,
		"attack_damage": 35.0,
		"attack_range": 210.0,
		"attack_interval": 0.4,
		"weapon_type": 8,
		"tags": ["elite", "infantry", "fast", "stealth"],
		"drops": [
			{"card_id": "bp_near_001", "chance": 0.4},
		],
	},
	"elite_future_colossus": {
		"era": 4,
		"display_name": "巨神机甲",
		"hp": 400.0,
		"speed": -60.0,
		"attack_damage": 55.0,
		"attack_range": 250.0,
		"attack_interval": 1.0,
		"weapon_type": 8,
		"tags": ["elite", "tank", "armored"],
		"drops": [
			{"card_id": "bp_near_002", "chance": 0.5},
		],
	},

	# 头目（1种）
	"boss_future_nexus": {
		"era": 4,
		"display_name": "风暴核心",
		"hp": 900.0,
		"speed": -30.0,
		"attack_damage": 90.0,
		"attack_range": 300.0,
		"attack_interval": 0.9,
		"weapon_type": 10,
		"tags": ["boss", "ultimate"],
		"drops": [
			{"card_id": "bp_near_003", "chance": 1.0},
		],
	},
}

