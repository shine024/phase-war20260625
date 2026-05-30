class_name CardEvolutionManager
## 进化系统 — 从 BlueprintManager 拆分的子模块
## 所有函数为 static，通过 bpm_ref（BlueprintManager 实例）访问核心数据

const DefaultCards = preload("res://data/default_cards.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const UnitLineageConfig = preload("res://data/unit_lineage_config.gd")
const BasicResources = preload("res://data/basic_resources.gd")

## 获取进化选项
static func get_evolution_options(card_id: String) -> Dictionary:
	if card_id.is_empty():
		return {}
	var evo_1: String = UnitLineageConfig.get_evolution_1_target(card_id)
	var branches: Dictionary = UnitLineageConfig.get_all_faction_targets(card_id)
	return {
		"base_card_id": card_id,
		"evolution_1": evo_1,
		"faction_branches": branches,
	}

## 获取卡片情报进度
static func get_card_intel_progress(card_id: String) -> float:
	var tree = Engine.get_main_loop()
	if tree and tree.root:
		var im = tree.root.get_node_or_null("IntelManual")
		if im and im.has_method("get_intel_progress"):
			return im.get_intel_progress(card_id)
	return 0.0

## 拒绝结果构建
static func _evolve_check_denied(reason: String) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"reason_zh": UnitLineageConfig.localize_evolve_reason(reason),
	}

## 进化条件检查
static func can_evolve_blueprint(card_id: String, target_card_id: String, bpm_ref: Node) -> Dictionary:
	if card_id.is_empty() or target_card_id.is_empty():
		return _evolve_check_denied("invalid")
	if not bpm_ref.is_blueprint_unlocked(card_id):
		return _evolve_check_denied("card_locked")
	if DefaultCards.get_card_by_id(target_card_id) == null and PhaseLaws.get_by_id(target_card_id).is_empty():
		return _evolve_check_denied("invalid_target")
	var opts: Dictionary = get_evolution_options(card_id)
	var evo_1: String = String(opts.get("evolution_1", ""))
	var branches: Dictionary = opts.get("faction_branches", {})
	var valid_target: bool = (target_card_id == evo_1)
	if not valid_target:
		for k in branches.keys():
			if String(branches[k]) == target_card_id:
				valid_target = true
				break
	if not valid_target:
		return _evolve_check_denied("target_not_in_path")

	## v5.0 Phase 4: 不跨类型检查（combat_kind 一致）
	var from_card: CardResource = DefaultCards.get_card_by_id(card_id)
	var to_card: CardResource = DefaultCards.get_card_by_id(target_card_id)
	if from_card != null and to_card != null:
		if from_card.combat_kind >= 0 and to_card.combat_kind >= 0:
			if from_card.combat_kind != to_card.combat_kind:
				return _evolve_check_denied("cross_class")

	## v5.0 Phase 4: 战力达标检查（培养后战力 >= 目标基础战力）
	var target_base_power: int = UnitLineageConfig.get_target_base_power(target_card_id)
	if target_base_power > 0:
		var current_power: float = EvolutionHelpers.estimate_power_score(card_id, bpm_ref)
		if current_power < float(target_base_power):
			return _evolve_check_denied("power_not_enough")

	## v5.0 情报100%检查
	var target_intel: float = get_card_intel_progress(target_card_id)
	if target_intel < 1.0:
		return _evolve_check_denied("intel_not_full")

	var stage: String = UnitLineageConfig.get_stage(card_id, target_card_id)
	var min_star: int = UnitLineageConfig.get_min_star_for_stage(stage)
	if bpm_ref.get_blueprint_star(card_id) < min_star:
		return _evolve_check_denied("star_not_enough")
	if ModManager.get_modification_count(card_id, bpm_ref.blueprint_mods) < UnitLineageConfig.REQUIRED_MOD_COUNT:
		return _evolve_check_denied("mod_not_enough")
	var costs: Dictionary = UnitLineageConfig.get_costs_for_stage(stage)
	var cost_research: int = int(costs.get("research", 0))
	if bpm_ref.get_research_points() < cost_research:
		return _evolve_check_denied("research_not_enough")
	var brm: Node = bpm_ref._get_basic_resource_manager()
	if brm == null or not brm.has_method("get_total"):
		return _evolve_check_denied("resource_manager_unavailable")
	var need_general: int = int(costs.get("permit_general", 0))
	var need_category: int = int(costs.get("permit_category", 0))
	var need_specific: int = int(costs.get("permit_specific", 0))
	var category_id: String = bpm_ref._get_mod_category_permit_id(card_id)
	var specific_id: String = BasicResources.get_specific_permit_id(target_card_id)
	if int(brm.get_total(BasicResources.ID_PERMIT_GENERAL)) < need_general:
		return _evolve_check_denied("permit_general_not_enough")
	if int(brm.get_total(category_id)) < need_category:
		return _evolve_check_denied("permit_category_not_enough")
	if int(brm.get_total(specific_id)) < need_specific:
		return _evolve_check_denied("permit_specific_not_enough")
	var out: Dictionary = {
		"ok": true,
		"reason": "ok",
		"stage": stage,
		"research_cost": cost_research,
		"permit_general_id": BasicResources.ID_PERMIT_GENERAL,
		"permit_general_count": need_general,
		"permit_category_id": category_id,
		"permit_category_count": need_category,
		"permit_specific_id": specific_id,
		"permit_specific_count": need_specific,
	}
	out["inherit_ratio"] = UnitLineageConfig.get_inherit_ratio(card_id, target_card_id)
	out["reason_zh"] = UnitLineageConfig.localize_evolve_reason(String(out.get("reason", "invalid")))
	return out

## 进化执行
static func evolve_blueprint(card_id: String, target_card_id: String, bpm_ref: Node) -> bool:
	var can_info: Dictionary = can_evolve_blueprint(card_id, target_card_id, bpm_ref)
	if not bool(can_info.get("ok", false)):
		return false
	var research_cost: int = int(can_info.get("research_cost", 0))
	bpm_ref.add_research_points(-research_cost)
	var brm: Node = bpm_ref._get_basic_resource_manager()
	if brm != null and brm.has_method("add_resource"):
		var n_general: int = int(can_info.get("permit_general_count", 0))
		var n_category: int = int(can_info.get("permit_category_count", 0))
		var n_specific: int = int(can_info.get("permit_specific_count", 0))
		if n_general > 0:
			brm.add_resource(String(can_info.get("permit_general_id", "")), -n_general)
		if n_category > 0:
			brm.add_resource(String(can_info.get("permit_category_id", "")), -n_category)
		if n_specific > 0:
			brm.add_resource(String(can_info.get("permit_specific_id", "")), -n_specific)
	var old_star: int = bpm_ref.get_blueprint_star(card_id)
	var inherit_ratio: float = float(can_info.get("inherit_ratio", 0.30))
	var old_bonus: float = float(bpm_ref.blueprint_inherit_bonus.get(card_id, 0.0))
	var merged_bonus: float = clampf(old_bonus + inherit_ratio, 0.0, 0.9)
	if not bpm_ref.is_blueprint_unlocked(target_card_id):
		bpm_ref.unlock_blueprint(target_card_id)
	bpm_ref.blueprint_copies[target_card_id] = max(1, int(bpm_ref.blueprint_copies.get(target_card_id, 0)))
	bpm_ref.blueprint_stars[target_card_id] = max(int(bpm_ref.blueprint_stars.get(target_card_id, 1)), old_star)
	bpm_ref.blueprint_inherit_bonus[target_card_id] = merged_bonus
	var old_hp: float = EvolutionHelpers.compute_platform_preview_hp(card_id, 0, bpm_ref)
	if old_hp > 0.0:
		var floor_hp: float = old_hp * 1.10
		var prev_floor: float = float(bpm_ref.blueprint_evolution_hp_floor.get(target_card_id, 0.0))
		bpm_ref.blueprint_evolution_hp_floor[target_card_id] = maxf(prev_floor, floor_hp)

	## v5.0 Phase 4 进化执行规则:
	## - 改造完全继承（mods 从源复制到目标，源清空）
	## - 强化重置（enhance_level=0 在 CardResource 层面）
	## - 品质保留（星级已通过 max 继承）
	## - 情报保留（blueprint_intel 字段，Phase 5 数据层预留）
	var source_mods: Array = bpm_ref.blueprint_mods.get(card_id, [])
	bpm_ref.blueprint_mods[target_card_id] = source_mods.duplicate()
	bpm_ref.blueprint_mods[card_id] = []

	## Phase 5 预留: 情报继承 — 进化后保留目标情报进度
	## var source_intel: float = float(bpm_ref.blueprint_intel.get(card_id, 0.0))
	## bpm_ref.blueprint_intel[target_card_id] = maxf(float(bpm_ref.blueprint_intel.get(target_card_id, 0.0)), source_intel)

	bpm_ref.emit_signal("fragments_changed")
	bpm_ref.emit_signal("blueprint_star_upgraded", target_card_id, int(bpm_ref.blueprint_stars[target_card_id]))
	return true
