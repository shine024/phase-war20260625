## 武器装备数据：战争武器
## 由 enemy_phase_equipment.gd 拆分而来
extends RefCounted
class_name EnemyEquipmentWeapons

## 战争武器数据
const LEGACY_WAR_WEAPONS: Dictionary = {
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

