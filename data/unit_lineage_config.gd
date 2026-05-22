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
	"platform_ww1_light": {
		"evolution_1": "platform_ww2_light",
		"faction_branches": {
			"iron_wall_corp": "platform_ww2_heavy",
			"nova_arms": "platform_ww2_raider",
			"void_research": "platform_future_light",
		},
	},
	"platform_ww1_medium": {
		"evolution_1": "platform_ww2_medium",
		"faction_branches": {
			"iron_wall_corp": "platform_ww2_heavy",
			"nova_arms": "platform_ww2_raider",
			"void_research": "platform_future_medium",
		},
	},
	"platform_ww1_fort": {
		"evolution_1": "platform_ww2_fortress",
		"faction_branches": {
			"iron_wall_corp": "platform_ww2_siege",
			"helix_recon": "platform_ww2_radar",
			"void_research": "platform_future_heavy",
		},
	},
	"platform_ww1_radar": {
		"evolution_1": "platform_ww2_radar",
		"faction_branches": {
			"helix_recon": "platform_cold_scout",
			"aether_dynamics": "platform_cold_radar",
			"void_research": "platform_future_radar",
		},
	},
	"platform_ww1_medic": {
		"evolution_1": "platform_cold_carrier",
		"faction_branches": {
			"iron_wall_corp": "platform_cold_ifv",
			"quantum_logistics": "platform_cold_carrier",
			"frontier_union": "platform_cold_light",
		},
	},
	"platform_ww2_light": {
		"evolution_1": "platform_cold_light",
		"faction_branches": {
			"iron_wall_corp": "platform_cold_medium",
			"frontier_union": "platform_cold_scout",
			"void_research": "platform_future_medium",
		},
	},
	"platform_ww2_medium": {
		"evolution_1": "platform_cold_medium",
		"faction_branches": {
			"iron_wall_corp": "platform_modern_guard_heavy",
			"aether_dynamics": "platform_modern_radar",
			"void_research": "platform_future_heavy",
		},
	},
	"platform_ww2_heavy": {
		"evolution_1": "platform_cold_medium",
		"faction_branches": {
			"iron_wall_corp": "platform_modern_guard_heavy",
			"nova_arms": "platform_cold_scout",
			"void_research": "platform_future_heavy",
		},
	},
	"platform_ww2_raider": {
		"evolution_1": "platform_cold_scout",
		"faction_branches": {
			"nova_arms": "platform_modern_light",
			"frontier_union": "platform_future_light",
			"void_research": "platform_future_medium",
		},
	},
	"platform_ww2_radar": {
		"evolution_1": "platform_cold_radar",
		"faction_branches": {
			"helix_recon": "platform_modern_radar",
			"aether_dynamics": "platform_cold_scout",
			"void_research": "platform_future_radar",
		},
	},
	"platform_ww2_siege": {
		"evolution_1": "platform_modern_spg",
		"faction_branches": {
			"iron_wall_corp": "platform_modern_guard_heavy",
			"nova_arms": "platform_modern_medium",
			"void_research": "omega_platform",
		},
	},
	"platform_ww2_fortress": {
		"evolution_1": "platform_modern_guard_heavy",
		"faction_branches": {
			"iron_wall_corp": "platform_modern_spg",
			"helix_recon": "platform_modern_stealth",
			"void_research": "platform_future_heavy",
		},
	},
	"platform_cold_light": {
		"evolution_1": "platform_modern_light",
		"faction_branches": {
			"helix_recon": "platform_modern_stealth",
			"frontier_union": "platform_future_light",
			"void_research": "platform_future_medium",
		},
	},
	"platform_cold_medium": {
		"evolution_1": "platform_modern_medium",
		"faction_branches": {
			"iron_wall_corp": "platform_modern_guard_heavy",
			"aether_dynamics": "platform_modern_radar",
			"void_research": "platform_future_heavy",
		},
	},
	"platform_cold_ifv": {
		"evolution_1": "platform_modern_medium",
		"faction_branches": {
			"iron_wall_corp": "platform_modern_guard_heavy",
			"aether_dynamics": "platform_modern_radar",
			"void_research": "platform_future_heavy",
		},
	},
	"platform_cold_scout": {
		"evolution_1": "platform_future_light",
		"faction_branches": {
			"helix_recon": "platform_modern_stealth",
			"frontier_union": "platform_modern_light",
			"void_research": "omega_platform",
		},
	},
	"platform_modern_light": {
		"evolution_1": "platform_future_light",
		"faction_branches": {
			"helix_recon": "platform_future_radar",
			"frontier_union": "platform_future_medium",
			"void_research": "omega_platform",
		},
	},
	"platform_modern_medium": {
		"evolution_1": "platform_future_heavy",
		"faction_branches": {
			"iron_wall_corp": "platform_modern_guard_heavy",
			"helix_recon": "platform_future_light",
			"void_research": "omega_platform",
		},
	},
	"platform_modern_radar": {
		"evolution_1": "platform_future_radar",
		"faction_branches": {
			"helix_recon": "platform_future_light",
			"aether_dynamics": "platform_future_medium",
			"void_research": "omega_platform",
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
