## 一战 + 二战敌人原型数据
## 由 enemy_archetypes.gd 拆分而来
extends RefCounted
class_name EnemyArchetypesWW

const DATA := {
	# ==================== 一战敌人（7种） ====================

	# 基础敌人（4种）
	"ww1_inf_mp18": {
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
	"ww1_inf_rifle": {
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
	"ww1_sup_mg_nest": {
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
	"ww1_arty_mortar": {
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
	"ww1_inf_storm_e": {
		"era": 0,
		"display_name": "暴风突击队",
		"hp": 70.0,
		"speed": -100.0,
		"attack_damage": 12.0,
		"attack_range": 80.0,
		"attack_interval": 0.25,
		"weapon_type": 0,
		"tags": ["elite", "infantry", "fast"],
		"drops": [],
	},
	"ww1_arm_rolls_e": {
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
			{"card_id": "ww1_saint", "chance": 0.2},
		],
	},

	# 头目（1种）
	"ww1_boss_av7": {
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
			{"card_id": "ww1_a7v", "chance": 1.0},
		],
	},

	
	# ==================== 二战敌人（7种） ====================

	# 基础敌人（4种）
	"ww2_inf_thompson": {
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
	"ww2_inf_garand": {
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
	"ww2_sup_mg42": {
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
	"ww2_inf_panzerschreck_e": {
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
	"ww2_inf_para_e": {
		"era": 1,
		"display_name": "伞兵精英",
		"hp": 80.0,
		"speed": -110.0,
		"attack_damage": 16.0,
		"attack_range": 90.0,
		"attack_interval": 0.22,
		"weapon_type": 0,
		"tags": ["elite", "infantry", "fast"],
		"drops": [],
	},
	"ww2_arm_panther_e": {
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
			{"card_id": "ww2_panther", "chance": 0.25},
		],
	},

	# 头目（1种）
	"ww2_boss_kingtiger": {
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
			{"card_id": "ww2_kingtiger", "chance": 1.0},
		],
	},
}
