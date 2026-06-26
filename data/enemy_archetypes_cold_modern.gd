## 冷战 + 现代敌人原型数据
## 由 enemy_archetypes.gd 拆分而来
extends RefCounted
class_name EnemyArchetypesColdModern

const DATA := {
	# ==================== 冷战敌人（7种） ====================

	# 基础敌人（4种）
	"enemy_cold_ak": {
		"swarm_unit": true,
		"era": 2,
		"display_name": "苏军步兵",
		"hp": 60.0,
		"speed": -90.0,
		"attack_damage": 14.0,
		"attack_range": 140.0,
		"attack_interval": 0.33,
		"weapon_type": 1,
		"tags": ["infantry", "frontline"],
		"drops": [],
	},
	"enemy_cold_m60": {
		"swarm_unit": true,
		"era": 2,
		"display_name": "美军步兵",
		"hp": 65.0,
		"speed": -90.0,
		"attack_damage": 15.0,
		"attack_range": 150.0,
		"attack_interval": 0.25,
		"weapon_type": 2,
		"tags": ["infantry", "frontline"],
		"drops": [],
	},
	"enemy_cold_btr": {
		"era": 2,
		"display_name": "BTR装甲车",
		"hp": 120.0,
		"speed": -80.0,
		"attack_damage": 18.0,
		"attack_range": 130.0,
		"attack_interval": 0.3,
		"weapon_type": 2,
		"tags": ["vehicle", "armored"],
		"drops": [],
	},
	"enemy_cold_m113": {
		"era": 2,
		"display_name": "M113装甲车",
		"hp": 110.0,
		"speed": -70.0,
		"attack_damage": 12.0,
		"attack_range": 120.0,
		"attack_interval": 0.35,
		"weapon_type": 2,
		"tags": ["vehicle", "support"],
		"drops": [],
	},

	# 精英敌人（2种）
	"elite_cold_spetsnaz": {
		"era": 2,
		"display_name": "特种部队",
		"hp": 90.0,
		"speed": -120.0,
		"attack_damage": 20.0,
		"attack_range": 220.0,
		"attack_interval": 1.25,
		"weapon_type": 6,
		"tags": ["elite", "infantry", "fast"],
		"drops": [
			{"card_id": "bp_cold_001", "chance": 0.3},
		],
	},
	"elite_cold_t72": {
		"era": 2,
		"display_name": "T-72坦克",
		"hp": 375.0,
		"speed": -60.0,
		"attack_damage": 40.0,
		"attack_range": 160.0,
		"attack_interval": 0.8,
		"weapon_type": 3,
		"tags": ["elite", "tank", "armored"],
		"drops": [
			{"card_id": "regen_frame", "chance": 0.3},
		],
	},

	# 头目（1种）
	"boss_cold_mig": {
		"era": 2,
		"display_name": "米格-29",
		"hp": 750.0,
		"speed": -150.0,
		"attack_damage": 55.0,
		"attack_range": 210.0,
		"attack_interval": 0.8,
		"weapon_type": 9,
		"tags": ["boss", "aircraft", "fast"],
		"drops": [
			{"card_id": "bp_cold_002", "chance": 0.4},
		],
	},

	
	# ==================== 现代敌人（8种） ====================

	# 基础敌人（4种）
	"enemy_modern_marine": {
		"swarm_unit": true,
		"era": 3,
		"display_name": "海军陆战队",
		"hp": 70.0,
		"speed": -100.0,
		"attack_damage": 16.0,
		"attack_range": 150.0,
		"attack_interval": 0.29,
		"weapon_type": 1,
		"tags": ["infantry", "frontline"],
		"drops": [],
	},
	"enemy_modern_technical": {
		"era": 3,
		"display_name": "皮卡武装",
		"hp": 90.0,
		"speed": -120.0,
		"attack_damage": 18.0,
		"attack_range": 130.0,
		"attack_interval": 0.3,
		"weapon_type": 2,
		"tags": ["vehicle", "fast"],
		"drops": [],
	},
	"enemy_modern_stryker": {
		"era": 3,
		"display_name": "斯特赖克装甲车",
		"hp": 150.0,
		"speed": -80.0,
		"attack_damage": 22.0,
		"attack_range": 150.0,
		"attack_interval": 0.35,
		"weapon_type": 2,
		"tags": ["vehicle", "armored"],
		"drops": [],
	},
	"enemy_modern_mlrs": {
		"era": 3,
		"display_name": "火箭炮车",
		"hp": 100.0,
		"speed": -50.0,
		"attack_damage": 35.0,
		"attack_range": 250.0,
		"attack_interval": 2.0,
		"weapon_type": 3,
		"tags": ["artillery", "backline"],
		"drops": [],
	},

	# 精英敌人（3种）
	"elite_modern_delta": {
		"era": 3,
		"display_name": "三角洲部队",
		"hp": 100.0,
		"speed": -130.0,
		"attack_damage": 24.0,
		"attack_range": 150.0,
		"attack_interval": 0.29,
		"weapon_type": 1,
		"tags": ["elite", "infantry", "fast"],
		"drops": [
			{"card_id": "bp_modern_001", "chance": 0.3},
		],
	},
	"elite_modern_abrams": {
		"era": 3,
		"display_name": "M1A2坦克",
		"hp": 450.0,
		"speed": -60.0,
		"attack_damage": 45.0,
		"attack_range": 200.0,
		"attack_interval": 0.8,
		"weapon_type": 3,
		"tags": ["elite", "tank", "armored"],
		"drops": [
			{"card_id": "abrams_mk2", "chance": 0.4},
		],
	},
	"elite_modern_apache": {
		"era": 3,
		"display_name": "阿帕奇直升机",
		"hp": 220.0,
		"speed": -120.0,
		"attack_damage": 38.0,
		"attack_range": 250.0,
		"attack_interval": 0.6,
		"weapon_type": 9,
		"tags": ["elite", "aircraft", "fast"],
		"drops": [
			{"card_id": "bp_modern_002", "chance": 0.35},
		],
	},

	# 头目（1种）
	"boss_modern_command": {
		"era": 3,
		"display_name": "指挥中枢",
		"hp": 1200.0,
		"speed": 0.0,
		"attack_damage": 70.0,
		"attack_range": 220.0,
		"attack_interval": 1.2,
		"weapon_type": 2,
		"tags": ["boss", "support"],
		"drops": [
			{"card_id": "bp_modern_003", "chance": 0.6},
		],
	},
}
