## 特殊装备数据：能量卡（相位仪已统一到 PhaseInstruments 池）
## 由 enemy_phase_equipment.gd 拆分而来
extends RefCounted
class_name EnemyEquipmentSpecials

## 能量卡数据
## v9.x: 删除 19 个 special_effect 死字段（全项目零战斗消费，仅 UI 卡面回退读 name/energy_amount/energy_regen_boost）。
const LEGACY_ENERGY_CARDS: Dictionary = {
	"steel_energy_basic": {
		"id": "steel_energy_basic",
		"name": "钢铁能量·基础",
		"faction": "steel",
		"level": 5,
		"energy_amount": 50,
		"energy_regen_boost": 0.5
	},
	"flame_energy_basic": {
		"id": "flame_energy_basic",
		"name": "烈焰能量·基础",
		"faction": "flame",
		"level": 6,
		"energy_amount": 60,
		"energy_regen_boost": 0.6
	},
	"thunder_energy_basic": {
		"id": "thunder_energy_basic",
		"name": "雷霆能量·基础",
		"faction": "thunder",
		"level": 7,
		"energy_amount": 55,
		"energy_regen_boost": 0.7
	},
	"void_energy_basic": {
		"id": "void_energy_basic",
		"name": "虚空能量·基础",
		"faction": "void",
		"level": 8,
		"energy_amount": 65,
		"energy_regen_boost": 0.8
	},

	# ==================== 进阶能量卡 ====================
	"steel_energy_advanced": {
		"id": "steel_energy_advanced",
		"name": "钢铁能量·进阶",
		"faction": "steel",
		"level": 12,
		"energy_amount": 100,
		"energy_regen_boost": 1.0
	},
	"flame_energy_advanced": {
		"id": "flame_energy_advanced",
		"name": "烈焰能量·进阶",
		"faction": "flame",
		"level": 13,
		"energy_amount": 120,
		"energy_regen_boost": 1.2
	},

	# ==================== 专家能量卡 ====================
	"steel_energy_expert": {
		"id": "steel_energy_expert",
		"name": "钢铁能量·专家",
		"faction": "steel",
		"level": 18,
		"energy_amount": 150,
		"energy_regen_boost": 1.5
	},
	"flame_energy_expert": {
		"id": "flame_energy_expert",
		"name": "烈焰能量·专家",
		"faction": "flame",
		"level": 19,
		"energy_amount": 180,
		"energy_regen_boost": 1.8
	},

	# ==================== 混合能量卡 ====================
	"hybrid_energy_basic": {
		"id": "hybrid_energy_basic",
		"name": "混合能量·基础",
		"faction": "hybrid",
		"level": 16,
		"energy_amount": 80,
		"energy_regen_boost": 1.0
	},
	"hybrid_energy_advanced": {
		"id": "hybrid_energy_advanced",
		"name": "混合能量·进阶",
		"faction": "hybrid",
		"level": 18,
		"energy_amount": 120,
		"energy_regen_boost": 1.4
	},

	# ==================== 神级能量卡 ====================
	"steel_energy_god": {
		"id": "steel_energy_god",
		"name": "钢铁神力",
		"faction": "steel",
		"level": 29,
		"energy_amount": 300,
		"energy_regen_boost": 3.0
	},
	"flame_energy_god": {
		"id": "flame_energy_god",
		"name": "炎魔神力",
		"faction": "flame",
		"level": 30,
		"energy_amount": 350,
		"energy_regen_boost": 3.5
	},
	"thunder_energy_god": {
		"id": "thunder_energy_god",
		"name": "雷霆神力",
		"faction": "thunder",
		"level": 30,
		"energy_amount": 320,
		"energy_regen_boost": 4.0
	},
	"void_energy_god": {
		"id": "void_energy_god",
		"name": "虚空神力",
		"faction": "void",
		"level": 30,
		"energy_amount": 330,
		"energy_regen_boost": 3.8
	},
	"hybrid_energy_god": {
		"id": "hybrid_energy_god",
		"name": "奥米茄能量",
		"faction": "all",
		"level": 30,
		"energy_amount": 500,
		"energy_regen_boost": 5.0
	},

	# ==================== 补充能量卡 ====================
	"thunder_energy_advanced": {
		"id": "thunder_energy_advanced",
		"name": "雷霆能量·进阶",
		"faction": "thunder",
		"level": 14,
		"energy_amount": 90,
		"energy_regen_boost": 1.0
	},
	"void_energy_advanced": {
		"id": "void_energy_advanced",
		"name": "虚空能量·进阶",
		"faction": "void",
		"level": 15,
		"energy_amount": 100,
		"energy_regen_boost": 1.1
	},
	"thunder_energy_expert": {
		"id": "thunder_energy_expert",
		"name": "雷霆能量·专家",
		"faction": "thunder",
		"level": 20,
		"energy_amount": 140,
		"energy_regen_boost": 1.6
	},
	"void_energy_expert": {
		"id": "void_energy_expert",
		"name": "虚空能量·专家",
		"faction": "void",
		"level": 21,
		"energy_amount": 160,
		"energy_regen_boost": 1.8
	}
}
