extends RefCounted
class_name PhaseLaws
## 相位法则定义：战争魔法的研究 / 激活 / 施放数据
##
## 字段约定（每条 law 为一个 Dictionary）：
## - id: 唯一ID
## - family: "STEEL"|"FLAME"|"THUNDER"|"VOID"
## - kind: "passive"|"active"
## - research_req: { defense_knowledge, energy_knowledge, mobility_knowledge, mystic_knowledge } — 解锁唯一门槛（v3）
## - env_req: { weather[], terrain[], energy_field[], time_of_day[] }  战前可激活条件
## - activate_cost: { nano }                                            战前激活消耗（多为被动）
## - battle_cost: { energy, nano }                                     战中施放消耗（主动）
## - cast_conditions: { min_friendly_units, min_affinity_units{family,count}, max_cast_per_battle }
## - env_changes: { add_tags[], remove_tags[] }                        施放后对环境的修改
## - runtime_tags: { effect, radius, duration, value, scales_with, target_side, target_type }

const LAWS: Dictionary = {
	"steel_phase_armor": {
		"id": "steel_phase_armor",
		"name": "钢铁·相位装甲",
		"family": "STEEL",
		"kind": "passive",
		"research_req": {
			"defense_knowledge": 20,
		},
		"env_req": {
			"terrain": ["city", "mountain"],
		},
		"activate_cost": {
			"nano": 20,
		},
		"runtime_tags": {
			"effect": "armor_buff",
			"value": 0.15,
			"scales_with": "defense_knowledge",
			"target_side": "ALLY",
			"target_type": "VEHICLE",
		},
	},

	"flame_heat_overload": {
		"id": "flame_heat_overload",
		"name": "烈焰·热能过载",
		"family": "FLAME",
		"kind": "passive",
		"research_req": {
			"energy_knowledge": 25,
		},
		"env_req": {
			"energy_field": ["high_field", "nano_fog"],
		},
		"activate_cost": {
			"nano": 25,
		},
		"runtime_tags": {
			"effect": "burn_on_hit",
			"value": 4.0,
			"duration": 3.0,
			"scales_with": "energy_knowledge",
			"target_side": "ENEMY",
			"target_type": "ALL",
		},
	},

	"thunder_emp_storm": {
		"id": "thunder_emp_storm",
		"name": "雷霆·电磁风暴",
		"family": "THUNDER",
		"kind": "active",
		"research_req": {
			"mobility_knowledge": 30,
			"energy_knowledge": 10,
		},
		"env_req": {
			"weather": ["storm", "rain"],
			"energy_field": ["normal", "high_field"],
		},
		"activate_cost": {
			"nano": 30,
		},
		"battle_cost": {
			"energy": 50,
			"nano": 0,
		},
		"cast_conditions": {
			"min_friendly_units": 2,
			"max_cast_per_battle": 2,
		},
		"env_changes": {
			"add_tags": ["electromagnetic_storm"],
			"remove_tags": ["storm"],
		},
		"runtime_tags": {
			"effect": "aoe_emp",
			"radius": 380.0,
			"duration": 6.0,
			"value": 20.0,
			"scales_with": "mobility_knowledge",
			"target_side": "ENEMY",
			"target_type": "VEHICLE",
		},
	},

	"void_time_ripple": {
		"id": "void_time_ripple",
		"name": "虚空·时空涟漪",
		"family": "VOID",
		"kind": "active",
		"research_req": {
			"mystic_knowledge": 35,
			"energy_knowledge": 20,
		},
		"env_req": {
			"energy_field": ["void_rift", "nano_fog"],
			"time_of_day": ["dusk", "night"],
		},
		"activate_cost": {
			"nano": 40,
		},
		"battle_cost": {
			"energy": 30,
			"nano": 50,
		},
		"cast_conditions": {
			"max_cast_per_battle": 1,
		},
		"env_changes": {
			"add_tags": ["time_slow_field"],
		},
		"runtime_tags": {
			"effect": "global_time_slow",
			"duration": 8.0,
			"value": 0.5,
			"scales_with": "mystic_knowledge",
			"target_side": "BOTH",
			"target_type": "ALL",
		},
	},

	"steel_bastion_wall": {
		"id": "steel_bastion_wall",
		"name": "钢铁·堡垒之墙",
		"family": "STEEL",
		"kind": "active",
		"research_req": {
			"defense_knowledge": 40,
		},
		"env_req": {
			"terrain": ["plain", "city", "mountain"],
		},
		"activate_cost": {
			"nano": 35,
		},
		"battle_cost": {
			"energy": 40,
		},
		"cast_conditions": {
			"max_cast_per_battle": 3,
		},
		"runtime_tags": {
			"effect": "spawn_shield_wall",
			"radius": 220.0,
			"duration": 10.0,
			"value": 0.3,
			"scales_with": "defense_knowledge",
			"target_side": "ALLY",
			"target_type": "ALL",
		},
	},

	# --- 额外主动战争魔法（测试用） ---
	# 注意：以下法则的 env_req 列出全部可能值，意在设计上降低激活门槛方便测试。
	# 正式版应收紧环境要求，使环境匹配成为有意义的策略维度。
	"flame_front_bombard": {
		"id": "flame_front_bombard",
		"name": "烈焰·前线火力压制",
		"family": "FLAME",
		"kind": "active",
		"research_req": {
			"energy_knowledge": 15,
		},
		# 含 low_field，与 BattleEnvironments / 各关循环一致，任意关可激活
		"env_req": {
			"energy_field": ["normal", "high_field", "nano_fog", "void_rift", "low_field"],
		},
		"activate_cost": {
			"nano": 10,
		},
		"battle_cost": {
			"energy": 25,
			"nano": 0,
		},
		"cast_conditions": {
			"max_cast_per_battle": 3,
		},
		"runtime_tags": {
			"effect": "line_bombard",
			"radius": 260.0,
			"duration": 0.0,
			"value": 18.0,
			"scales_with": "energy_knowledge",
			"target_side": "ENEMY",
			"target_type": "VEHICLE",
		},
	},

	"thunder_chain_discharge": {
		"id": "thunder_chain_discharge",
		"name": "雷霆·链式放电",
		"family": "THUNDER",
		"kind": "active",
		"research_req": {
			"mobility_knowledge": 20,
		},
		"env_req": {
			"weather": ["clear", "rain", "storm", "fog", "snow", "sandstorm"],
		},
		"activate_cost": {
			"nano": 20,
		},
		"battle_cost": {
			"energy": 35,
			"nano": 10,
		},
		"cast_conditions": {
			"min_friendly_units": 1,
			"max_cast_per_battle": 2,
		},
		"runtime_tags": {
			"effect": "chain_lightning",
			"radius": 320.0,
			"duration": 0.0,
			"value": 22.0,
			"scales_with": "mobility_knowledge",
			"target_side": "ENEMY",
			"target_type": "ALL",
		},
	},

	"void_barrier_shift": {
		"id": "void_barrier_shift",
		"name": "虚空·护盾转移",
		"family": "VOID",
		"kind": "active",
		"research_req": {
			"mystic_knowledge": 15,
			"defense_knowledge": 10,
		},
		"env_req": {
			"energy_field": ["void_rift", "normal", "nano_fog"],
		},
		"activate_cost": {
			"nano": 25,
		},
		"battle_cost": {
			"energy": 20,
			"nano": 15,
		},
		"cast_conditions": {
			"max_cast_per_battle": 3,
		},
		"runtime_tags": {
			"effect": "hp_shield_shift",
			"radius": 260.0,
			"duration": 6.0,
			"value": 0.2,
			"scales_with": "mystic_knowledge",
			"target_side": "ALLY",
			"target_type": "ALL",
		},
	},

	"steel_quick_repair": {
		"id": "steel_quick_repair",
		"name": "钢铁·快速维修",
		"family": "STEEL",
		"kind": "passive",
		"research_req": {
			"defense_knowledge": 15,
		},
		"env_req": {
			"terrain": ["city", "plain"],
		},
		"activate_cost": {
			"nano": 12,
		},
		"runtime_tags": {
			"effect": "regen_out_of_combat",
			"value": 2.0,
			"scales_with": "defense_knowledge",
			"target_side": "ALLY",
			"target_type": "VEHICLE",
		},
	},

	"flame_mark": {
		"id": "flame_mark",
		"name": "烈焰·灼烧印记",
		"family": "FLAME",
		"kind": "active",
		"research_req": {
			"energy_knowledge": 22,
		},
		"env_req": {
			"energy_field": ["normal", "high_field"],
		},
		"activate_cost": {
			"nano": 18,
		},
		"battle_cost": {
			"energy": 28,
			"nano": 0,
		},
		"cast_conditions": {
			"max_cast_per_battle": 2,
		},
		"runtime_tags": {
			"effect": "burn_mark",
			"radius": 120.0,
			"duration": 5.0,
			"value": 6.0,
			"scales_with": "energy_knowledge",
			"target_side": "ENEMY",
			"target_type": "ALL",
		},
	},
	"steel_aegis_link": {
		"id": "steel_aegis_link",
		"name": "钢铁·护阵联结",
		"family": "STEEL",
		"kind": "passive",
		"research_req": {"defense_knowledge": 24},
		"env_req": {"terrain": ["plain", "city", "mountain"]},
		"activate_cost": {"nano": 18},
		"runtime_tags": {"effect": "aegis_link", "value": 0.12, "scales_with": "defense_knowledge", "target_side": "ALLY", "target_type": "VEHICLE"},
	},
	"steel_anchor_field": {
		"id": "steel_anchor_field",
		"name": "钢铁·锚定力场",
		"family": "STEEL",
		"kind": "active",
		"research_req": {"defense_knowledge": 26},
		"env_req": {"terrain": ["city", "forest"]},
		"activate_cost": {"nano": 20},
		"battle_cost": {"energy": 26, "nano": 8},
		"cast_conditions": {"max_cast_per_battle": 2},
		"runtime_tags": {"effect": "anchor_field", "radius": 260.0, "duration": 6.0, "value": 0.25, "scales_with": "defense_knowledge", "target_side": "ENEMY", "target_type": "ALL"},
	},
	"steel_fortify_protocol": {
		"id": "steel_fortify_protocol",
		"name": "钢铁·固壁协议",
		"family": "STEEL",
		"kind": "passive",
		"research_req": {"defense_knowledge": 28},
		"env_req": {"terrain": ["plain", "city", "mountain", "forest", "desert"]},
		"activate_cost": {"nano": 20},
		"runtime_tags": {"effect": "fortify_protocol", "value": 0.18, "scales_with": "defense_knowledge", "target_side": "ALLY", "target_type": "ALL"},
	},
	"flame_scorch_wave": {
		"id": "flame_scorch_wave",
		"name": "烈焰·灼浪推进",
		"family": "FLAME",
		"kind": "active",
		"research_req": {"energy_knowledge": 24},
		"env_req": {"energy_field": ["high_field", "nano_fog"]},
		"activate_cost": {"nano": 16},
		"battle_cost": {"energy": 30, "nano": 0},
		"cast_conditions": {"max_cast_per_battle": 3},
		"runtime_tags": {"effect": "scorch_wave", "radius": 280.0, "duration": 0.0, "value": 20.0, "scales_with": "energy_knowledge", "target_side": "ENEMY", "target_type": "ALL"},
	},
	"flame_ember_screen": {
		"id": "flame_ember_screen",
		"name": "烈焰·灰烬幕障",
		"family": "FLAME",
		"kind": "active",
		"research_req": {"energy_knowledge": 26},
		"env_req": {"weather": ["fog", "storm"]},
		"activate_cost": {"nano": 18},
		"battle_cost": {"energy": 24, "nano": 12},
		"cast_conditions": {"max_cast_per_battle": 2},
		"runtime_tags": {"effect": "ember_screen", "radius": 300.0, "duration": 7.0, "value": 0.2, "scales_with": "energy_knowledge", "target_side": "ALLY", "target_type": "ALL"},
	},
	"flame_core_rupture": {
		"id": "flame_core_rupture",
		"name": "烈焰·核心破裂",
		"family": "FLAME",
		"kind": "active",
		"research_req": {"energy_knowledge": 30},
		"env_req": {"energy_field": ["high_field", "void_rift"]},
		"activate_cost": {"nano": 24},
		"battle_cost": {"energy": 38, "nano": 8},
		"cast_conditions": {"max_cast_per_battle": 2},
		"runtime_tags": {"effect": "core_rupture", "radius": 220.0, "duration": 0.0, "value": 36.0, "scales_with": "energy_knowledge", "target_side": "ENEMY", "target_type": "VEHICLE"},
	},
	"flame_afterburn": {
		"id": "flame_afterburn",
		"name": "烈焰·余烬加燃",
		"family": "FLAME",
		"kind": "passive",
		"research_req": {"energy_knowledge": 20},
		# env_req 含全部 energy_field 值 — 降低激活门槛（同 flame_front_bombard）
		"env_req": {"energy_field": ["normal", "high_field", "nano_fog", "void_rift", "low_field"]},
		"activate_cost": {"nano": 14},
		"runtime_tags": {"effect": "afterburn", "value": 0.14, "scales_with": "energy_knowledge", "target_side": "ALLY", "target_type": "ALL"},
	},
	"thunder_ion_net": {
		"id": "thunder_ion_net",
		"name": "雷霆·离子网",
		"family": "THUNDER",
		"kind": "active",
		"research_req": {"mobility_knowledge": 22},
		"env_req": {"weather": ["rain", "storm"]},
		"activate_cost": {"nano": 18},
		"battle_cost": {"energy": 26, "nano": 10},
		"cast_conditions": {"max_cast_per_battle": 2},
		"runtime_tags": {"effect": "ion_net", "radius": 300.0, "duration": 5.0, "value": 0.3, "scales_with": "mobility_knowledge", "target_side": "ENEMY", "target_type": "ALL"},
	},
	"thunder_arc_beacon": {
		"id": "thunder_arc_beacon",
		"name": "雷霆·弧光信标",
		"family": "THUNDER",
		"kind": "passive",
		"research_req": {"mobility_knowledge": 18},
		"env_req": {"weather": ["clear", "rain", "storm"]},
		"activate_cost": {"nano": 12},
		"runtime_tags": {"effect": "arc_beacon", "value": 0.12, "scales_with": "mobility_knowledge", "target_side": "ALLY", "target_type": "ALL"},
	},
	"thunder_surge_drive": {
		"id": "thunder_surge_drive",
		"name": "雷霆·激涌驱动",
		"family": "THUNDER",
		"kind": "active",
		"research_req": {"mobility_knowledge": 28, "energy_knowledge": 12},
		"env_req": {"weather": ["storm", "fog"]},
		"activate_cost": {"nano": 22},
		"battle_cost": {"energy": 34, "nano": 6},
		"cast_conditions": {"max_cast_per_battle": 3},
		"runtime_tags": {"effect": "surge_drive", "radius": 0.0, "duration": 8.0, "value": 0.22, "scales_with": "mobility_knowledge", "target_side": "ALLY", "target_type": "VEHICLE"},
	},
	"thunder_static_domain": {
		"id": "thunder_static_domain",
		"name": "雷霆·静电域",
		"family": "THUNDER",
		"kind": "active",
		"research_req": {"mobility_knowledge": 30},
		"env_req": {"weather": ["storm", "rain"]},
		"activate_cost": {"nano": 24},
		"battle_cost": {"energy": 36, "nano": 10},
		"cast_conditions": {"max_cast_per_battle": 1},
		"runtime_tags": {"effect": "static_domain", "radius": 340.0, "duration": 6.0, "value": 24.0, "scales_with": "mobility_knowledge", "target_side": "ENEMY", "target_type": "ALL"},
	},
	"void_phase_cloak": {
		"id": "void_phase_cloak",
		"name": "虚空·相位披幕",
		"family": "VOID",
		"kind": "active",
		"research_req": {"mystic_knowledge": 24},
		"env_req": {"energy_field": ["void_rift", "nano_fog"]},
		"activate_cost": {"nano": 22},
		"battle_cost": {"energy": 24, "nano": 16},
		"cast_conditions": {"max_cast_per_battle": 2},
		"runtime_tags": {"effect": "phase_cloak", "radius": 260.0, "duration": 6.0, "value": 0.35, "scales_with": "mystic_knowledge", "target_side": "ALLY", "target_type": "ALL"},
	},
	"void_entropy_lens": {
		"id": "void_entropy_lens",
		"name": "虚空·熵镜",
		"family": "VOID",
		"kind": "passive",
		"research_req": {"mystic_knowledge": 22},
		"env_req": {"energy_field": ["void_rift", "normal"]},
		"activate_cost": {"nano": 18},
		"runtime_tags": {"effect": "entropy_lens", "value": 0.16, "scales_with": "mystic_knowledge", "target_side": "ALLY", "target_type": "ALL"},
	},
	"void_gravity_well": {
		"id": "void_gravity_well",
		"name": "虚空·引力井",
		"family": "VOID",
		"kind": "active",
		"research_req": {"mystic_knowledge": 32, "energy_knowledge": 14},
		"env_req": {"energy_field": ["void_rift", "nano_fog"], "time_of_day": ["dusk", "night"]},
		"activate_cost": {"nano": 28},
		"battle_cost": {"energy": 40, "nano": 14},
		"cast_conditions": {"max_cast_per_battle": 1},
		"runtime_tags": {"effect": "gravity_well", "radius": 360.0, "duration": 5.0, "value": 0.4, "scales_with": "mystic_knowledge", "target_side": "ENEMY", "target_type": "ALL"},
	},
	"steel_resonant_plate": {
		"id": "steel_resonant_plate",
		"name": "钢铁·共振装甲",
		"family": "STEEL",
		"kind": "passive",
		"research_req": {"defense_knowledge": 32, "energy_knowledge": 8},
		"env_req": {"terrain": ["city", "mountain"], "energy_field": ["normal", "high_field"]},
		"activate_cost": {"nano": 24},
		"runtime_tags": {"effect": "resonant_plate", "value": 0.2, "scales_with": "defense_knowledge", "target_side": "ALLY", "target_type": "VEHICLE"},
	},
}

static func get_all_ids() -> Array:
	return LAWS.keys()

static func get_all() -> Array:
	var out: Array = []
	for id in LAWS.keys():
		out.append(LAWS[id].duplicate(true))
	return out

static func get_by_id(law_id: String) -> Dictionary:
	if LAWS.has(law_id):
		return LAWS[law_id].duplicate(true)
	return {}

static func get_family(law_id: String) -> String:
	var d := get_by_id(law_id)
	return String(d.get("family", ""))

