## 一战 + 二战敌人原型数据
## 由 enemy_archetypes.gd 拆分而来
extends RefCounted
class_name EnemyArchetypesWW

const DATA := {
	# ==================== 一战敌人（7种） ====================

	# 基础敌人（4种）
	"enemy_ww1_infantry_basic": {
		"swarm_unit": true,
		"era": 0,
		"display_name": "步兵班·MP18",
		"hp": 40.0,
		"speed": -80.0,
		"attack_damage": 8.0,
		"attack_range": 80.0,
		"attack_interval": 0.25,
		"weapon_type": 0,
		"tags": ["infantry", "frontline"],
		"drops": [],
	},
	"enemy_ww1_infantry_rifle": {
		"swarm_unit": true,
		"era": 0,
		"display_name": "步兵班·步枪",
		"hp": 45.0,
		"speed": -70.0,
		"attack_damage": 12.0,
		"attack_range": 150.0,
		"attack_interval": 0.67,
		"weapon_type": 1,
		"tags": ["infantry", "backline"],
		"drops": [],
	},
	"enemy_ww1_mg_nest": {
		"era": 0,
		"display_name": "机枪巢",
		"hp": 80.0,
		"speed": 0.0,
		"attack_damage": 10.0,
		"attack_range": 120.0,
		"attack_interval": 0.33,
		"weapon_type": 2,
		"tags": ["turret", "sustained"],
		"drops": [],
	},
	"enemy_ww1_mortar": {
		"era": 0,
		"display_name": "迫击炮组",
		"hp": 60.0,
		"speed": -40.0,
		"attack_damage": 20.0,
		"attack_range": 180.0,
		"attack_interval": 2.0,
		"weapon_type": 3,
		"tags": ["artillery", "backline"],
		"drops": [],
	},

	# 精英敌人（2种）
	"elite_ww1_storm": {
		"era": 0,
		"display_name": "暴风突击队",
		"hp": 70.0,
		"speed": -100.0,
		"attack_damage": 12.0,
		"attack_range": 80.0,
		"attack_interval": 0.25,
		"weapon_type": 0,
		"tags": ["elite", "infantry", "fast"],
		"drops": [
			{"card_id": "bp_ww1_001", "chance": 0.2},
		],
	},
	"elite_ww1_armored": {
		"era": 0,
		"display_name": "装甲车",
		"hp": 120.0,
		"speed": -60.0,
		"attack_damage": 15.0,
		"attack_range": 120.0,
		"attack_interval": 0.33,
		"weapon_type": 2,
		"tags": ["elite", "vehicle", "armored"],
		"drops": [
			{"card_id": "bulwark", "chance": 0.2},
		],
	},

	# 头目（1种）
	"boss_ww1_av7": {
		"era": 0,
		"display_name": "圣沙蒙坦克",
		"hp": 600.0,
		"speed": -30.0,
		"attack_damage": 25.0,
		"attack_range": 150.0,
		"attack_interval": 1.5,
		"weapon_type": 3,
		"tags": ["boss", "tank", "armored"],
		"drops": [
			{"card_id": "titan_mk2", "chance": 1.0},
		],
	},

	
	# ==================== 二战敌人（7种） ====================

	# 基础敌人（4种）
	"enemy_ww2_infantry": {
		"swarm_unit": true,
		"era": 1,
		"display_name": "步兵班·汤普森",
		"hp": 50.0,
		"speed": -90.0,
		"attack_damage": 10.0,
		"attack_range": 85.0,
		"attack_interval": 0.22,
		"weapon_type": 0,
		"tags": ["infantry", "frontline"],
		"drops": [],
	},
	"enemy_ww2_rifleman": {
		"swarm_unit": true,
		"era": 1,
		"display_name": "步枪班·加兰德",
		"hp": 55.0,
		"speed": -70.0,
		"attack_damage": 15.0,
		"attack_range": 160.0,
		"attack_interval": 0.5,
		"weapon_type": 1,
		"tags": ["infantry", "backline"],
		"drops": [],
	},
	"enemy_ww2_mg42": {
		"era": 1,
		"display_name": "MG42机枪组",
		"hp": 90.0,
		"speed": -50.0,
		"attack_damage": 14.0,
		"attack_range": 130.0,
		"attack_interval": 0.2,
		"weapon_type": 2,
		"tags": ["turret", "sustained"],
		"drops": [],
	},
	"enemy_ww2_panzerschreck": {
		"era": 1,
		"display_name": "反坦克组",
		"hp": 70.0,
		"speed": -60.0,
		"attack_damage": 30.0,
		"attack_range": 140.0,
		"attack_interval": 2.5,
		"weapon_type": 3,
		"tags": ["infantry", "antitank"],
		"drops": [],
	},

	# 精英敌人（2种）
	"elite_ww2_paratrooper": {
		"era": 1,
		"display_name": "伞兵精英",
		"hp": 80.0,
		"speed": -110.0,
		"attack_damage": 16.0,
		"attack_range": 90.0,
		"attack_interval": 0.22,
		"weapon_type": 0,
		"tags": ["elite", "infantry", "fast"],
		"drops": [
			{"card_id": "bp_ww2_001", "chance": 0.25},
		],
	},
	"elite_ww2_panther": {
		"era": 1,
		"display_name": "黑豹坦克",
		"hp": 200.0,
		"speed": -50.0,
		"attack_damage": 35.0,
		"attack_range": 150.0,
		"attack_interval": 1.0,
		"weapon_type": 3,
		"tags": ["elite", "tank", "armored"],
		"drops": [
			{"card_id": "storm_rider", "chance": 0.25},
		],
	},

	# 头目（1种）
	"boss_ww2_kingtiger": {
		"era": 1,
		"display_name": "虎王坦克",
		"hp": 800.0,
		"speed": -30.0,
		"attack_damage": 40.0,
		"attack_range": 160.0,
		"attack_interval": 1.2,
		"weapon_type": 3,
		"tags": ["boss", "tank", "armored"],
		"drops": [
			{"card_id": "heavy_carrier", "chance": 1.0},
		],
	},
}
