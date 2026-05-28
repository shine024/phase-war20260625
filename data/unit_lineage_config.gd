extends RefCounted
class_name UnitLineageConfig

## 卡牌进化链配置（统一卡牌成长体系）
## 规则：
## - evolution_1: 同体系进化
## - faction_branches: 势力特化进化
## - inherit_ratio: 进化仅继承属性比例（不继承改造）

const DefaultCards = preload("res://data/default_cards.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")

const DEFAULT_INHERIT_RATIO: float = 0.30
const E1_MIN_STAR: int = 4
const E2_MIN_STAR: int = 7
const REQUIRED_MOD_COUNT: int = 3

const EVOLVE_COSTS: Dictionary = {
	"e1": {"research": 320, "permit_general": 1, "permit_category": 1, "permit_specific": 0},
	"e2": {"research": 680, "permit_general": 1, "permit_category": 1, "permit_specific": 1},
}

const EVOLVE_REASON_ZH: Dictionary = {
	"ok": "可进化",
	"invalid": "条件无效",
	"card_locked": "蓝图未解锁",
	"invalid_target": "进化目标不存在",
	"target_not_in_path": "目标不在该卡进化路线中",
	"star_not_enough": "星级不足（基础进化需4★，势力分支需7★）",
	"mod_not_enough": "改装未满3次",
	"research_not_enough": "研究点不足",
	"resource_manager_unavailable": "资源系统不可用",
	"permit_general_not_enough": "通用改造许可函不足",
	"permit_category_not_enough": "类型改造许可函不足",
	"permit_specific_not_enough": "专属改造许可函不足",
}

const LINEAGES: Dictionary = {
	"ww1_rolls": {
		"evolution_1": "ww2_hellcat",
		"faction_branches": {
			"iron_wall_corp": "ww2_tiger",
			"nova_arms": "ww2_bazooka",
			"void_research": "fut_scout_mech",
		},
	},
	"ww1_ft17": {
		"evolution_1": "ww2_sherman",
		"faction_branches": {
			"iron_wall_corp": "ww2_tiger",
			"nova_arms": "ww2_bazooka",
			"void_research": "fut_hovertank",
		},
	},
	"ww1_77mm": {
		"evolution_1": "ww1_m81",
		"faction_branches": {
			"iron_wall_corp": "ww2_m81 mortar",
			"helix_recon": "ww2_panzerschrek",
			"void_research": "fut_heavy_mech",
		},
	},
	"ww1_cavalry": {
		"evolution_1": "ww2_panzerschrek",
		"faction_branches": {
			"helix_recon": "cold_m113",
			"aether_dynamics": "cold_zsu23",
			"void_research": "fut_prism",
		},
	},
	"ww1_engineer": {
		"evolution_1": "cold_bmp1",
		"faction_branches": {
			"iron_wall_corp": "cold_bmp1",
			"quantum_logistics": "cold_bmp1",
			"frontier_union": "cold_btr60",
		},
	},
	"ww2_hellcat": {
		"evolution_1": "cold_btr60",
		"faction_branches": {
			"iron_wall_corp": "cold_t55",
			"frontier_union": "cold_m113",
			"void_research": "fut_hovertank",
		},
	},
	"ww2_sherman": {
		"evolution_1": "cold_t55",
		"faction_branches": {
			"iron_wall_corp": "mod_m1a2sep",
			"aether_dynamics": "mod_m6",
			"void_research": "fut_heavy_mech",
		},
	},
	"ww2_tiger": {
		"evolution_1": "cold_t55",
		"faction_branches": {
			"iron_wall_corp": "mod_m1a2sep",
			"nova_arms": "cold_m113",
			"void_research": "fut_heavy_mech",
		},
	},
	"ww2_bazooka": {
		"evolution_1": "cold_m113",
		"faction_branches": {
			"nova_arms": "mod_technical",
			"frontier_union": "fut_scout_mech",
			"void_research": "fut_hovertank",
		},
	},
	"ww2_panzerschrek": {
		"evolution_1": "cold_zsu23",
		"faction_branches": {
			"helix_recon": "mod_m6",
			"aether_dynamics": "cold_m113",
			"void_research": "fut_prism",
		},
	},
	"ww2_m81 mortar": {
		"evolution_1": "mod_m270",
		"faction_branches": {
			"iron_wall_corp": "mod_m1a2sep",
			"nova_arms": "mod_m1a1",
			"void_research": "fut_nexus",
		},
	},
	"ww1_m81": {
		"evolution_1": "mod_m1a2sep",
		"faction_branches": {
			"iron_wall_corp": "mod_m270",
			"helix_recon": "fut_scout_drone",
			"void_research": "fut_heavy_mech",
		},
	},
	"cold_btr60": {
		"evolution_1": "mod_technical",
		"faction_branches": {
			"helix_recon": "fut_scout_drone",
			"frontier_union": "fut_scout_mech",
			"void_research": "fut_hovertank",
		},
	},
	"cold_t55": {
		"evolution_1": "mod_m1a1",
		"faction_branches": {
			"iron_wall_corp": "mod_m1a2sep",
			"aether_dynamics": "mod_m6",
			"void_research": "fut_heavy_mech",
		},
	},
	"cold_bmp1": {
		"evolution_1": "mod_m1a1",
		"faction_branches": {
			"iron_wall_corp": "mod_m1a2sep",
			"aether_dynamics": "mod_m6",
			"void_research": "fut_heavy_mech",
		},
	},
	"cold_m113": {
		"evolution_1": "fut_scout_mech",
		"faction_branches": {
			"helix_recon": "fut_scout_drone",
			"frontier_union": "mod_technical",
			"void_research": "fut_nexus",
		},
	},
	"mod_technical": {
		"evolution_1": "fut_scout_mech",
		"faction_branches": {
			"helix_recon": "fut_prism",
			"frontier_union": "fut_hovertank",
			"void_research": "fut_nexus",
		},
	},
	"mod_m1a1": {
		"evolution_1": "fut_heavy_mech",
		"faction_branches": {
			"iron_wall_corp": "mod_m1a2sep",
			"helix_recon": "fut_scout_mech",
			"void_research": "fut_nexus",
		},
	},
	"mod_m6": {
		"evolution_1": "fut_prism",
		"faction_branches": {
			"helix_recon": "fut_scout_mech",
			"aether_dynamics": "fut_hovertank",
			"void_research": "fut_nexus",
		},
	},
	"void_time_ripple": {
		"evolution_1": "void_barrier_shift",
		"faction_branches": {
			"void_research": "void_phase_cloak",
			"frontier_union": "thunder_emp_storm",
		},
	},
}

static func localize_evolve_reason(reason: String) -> String:
	var key: String = String(reason).strip_edges()
	if EVOLVE_REASON_ZH.has(key):
		return String(EVOLVE_REASON_ZH[key])
	return key if not key.is_empty() else String(EVOLVE_REASON_ZH.get("invalid", "条件无效"))

static func is_valid_evolution_target(target_id: String) -> bool:
	if target_id.is_empty():
		return false
	if DefaultCards.get_card_by_id(target_id) != null:
		return true
	return not PhaseLaws.get_by_id(target_id).is_empty()

static func validate_lineage_targets() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	for source_id in LINEAGES.keys():
		var cfg: Dictionary = LINEAGES[source_id]
		var e1: String = String(cfg.get("evolution_1", ""))
		if not e1.is_empty() and not is_valid_evolution_target(e1):
			errors.append("%s → 无效目标: %s (evolution_1)" % [source_id, e1])
		var branches: Dictionary = cfg.get("faction_branches", {})
		for faction_id in branches.keys():
			var target: String = String(branches[faction_id])
			if not is_valid_evolution_target(target):
				errors.append("%s → 无效目标: %s (faction %s)" % [source_id, target, faction_id])
	return errors

static func has_lineage(card_id: String) -> bool:
	return LINEAGES.has(card_id)

static func get_inherit_ratio(_from_card_id: String, _to_card_id: String) -> float:
	return DEFAULT_INHERIT_RATIO

static func get_evolution_1_target(card_id: String) -> String:
	var cfg: Dictionary = LINEAGES.get(card_id, {})
	return String(cfg.get("evolution_1", ""))

static func get_faction_target(card_id: String, faction_id: String) -> String:
	var cfg: Dictionary = LINEAGES.get(card_id, {})
	var branches: Dictionary = cfg.get("faction_branches", {})
	return String(branches.get(faction_id, ""))

static func get_all_faction_targets(card_id: String) -> Dictionary:
	var cfg: Dictionary = LINEAGES.get(card_id, {})
	return (cfg.get("faction_branches", {}) as Dictionary).duplicate(true)

static func get_progression_step(card_id: String) -> int:
	if not has_lineage(card_id):
		return 0
	var evo1: String = get_evolution_1_target(card_id)
	if evo1.is_empty():
		return 0
	if has_lineage(evo1):
		return 1
	return 1

static func get_stage(from_card_id: String, to_card_id: String) -> String:
	if to_card_id == get_evolution_1_target(from_card_id):
		return "e1"
	return "e2"

static func get_min_star_for_stage(stage: String) -> int:
	return E2_MIN_STAR if stage == "e2" else E1_MIN_STAR

static func get_costs_for_stage(stage: String) -> Dictionary:
	return (EVOLVE_COSTS.get(stage, EVOLVE_COSTS["e1"]) as Dictionary).duplicate(true)
