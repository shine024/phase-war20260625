class_name ModManager
extends RefCounted
## 改装系统 — 从 BlueprintManager 拆分的子模块
## 所有函数为 static，通过 bpm_ref（BlueprintManager 实例）或 mods_dict 访问核心数据

const ModEffects = preload("res://data/mod_effects.gd")
const StarConfig = preload("res://data/blueprint_star_config.gd")
const BasicResources = preload("res://data/basic_resources.gd")

## 获取卡牌基础战力（不含改造加成），用于改造消耗公式
static func get_base_power_for_mod_cost(card_id: String, bpm_ref: Node) -> float:
	var star: int = bpm_ref.get_blueprint_star(card_id)
	var rarity_mul: float = EvolutionHelpers.get_rarity_multiplier(card_id)
	var inherit_bonus: float = float(bpm_ref.blueprint_inherit_bonus.get(card_id, 0.0))
	return (80.0 + float(star) * 28.0) * rarity_mul * (1.0 + inherit_bonus)

## 获取第 mod_index 个改造槽位的消耗需求（研究点 + 许可证）
static func get_modification_requirements(card_id: String, mod_index: int, bpm_ref: Node) -> Dictionary:
	var base_power: float = get_base_power_for_mod_cost(card_id, bpm_ref)
	var cost_mul: float = ModEffects.get_mod_slot_cost(mod_index)
	var research_cost: int = max(1, int(base_power * cost_mul))
	var rule: Dictionary = StarConfig.get_mod_permit_rule(mod_index)
	var req_general: int = int(rule.get("general", 0))
	var req_category: int = int(rule.get("category", 0))
	var req_specific: int = int(rule.get("specific", 0))
	var category_permit_id: String = bpm_ref._get_mod_category_permit_id(card_id)
	var specific_permit_id: String = BasicResources.get_specific_permit_id(card_id)
	return {
		"research_points": research_cost,
		"permit_general_id": BasicResources.ID_PERMIT_GENERAL,
		"permit_general_count": req_general,
		"permit_category_id": category_permit_id,
		"permit_category_count": req_category,
		"permit_specific_id": specific_permit_id,
		"permit_specific_count": req_specific,
	}

## 获取当前已装改造数量
static func get_modification_count(card_id: String, mods_dict: Dictionary) -> int:
	var mods: Array = mods_dict.get(card_id, [])
	return mods.size()

## 获取最大改造次数
static func get_max_mod_slots() -> int:
	return ModEffects.MAX_MOD_SLOTS

## 获取可选 MOD 列表
static func get_mod_options(card_id: String) -> Array[Dictionary]:
	if card_id.is_empty():
		return []
	return ModEffects.get_all_mod_definitions()

## 检查是否可以执行第 mod_index 次改造
static func can_apply_modification(card_id: String, mod_index: int, bpm_ref: Node) -> bool:
	if card_id.is_empty() or mod_index < 0:
		return false
	if mod_index >= ModEffects.MAX_MOD_SLOTS:
		return false
	if mod_index != get_modification_count(card_id, bpm_ref.blueprint_mods):
		return false
	var need_star: int = StarConfig.get_mod_unlock_star(mod_index)
	if bpm_ref.get_blueprint_star(card_id) < need_star:
		return false
	var req: Dictionary = get_modification_requirements(card_id, mod_index, bpm_ref)
	var brm: Node = bpm_ref._get_basic_resource_manager()
	if bpm_ref.get_research_points() < int(req.get("research_points", 0)):
		return false
	if brm == null or not brm.has_method("get_total"):
		return false
	if int(req.get("permit_general_count", 0)) > int(brm.get_total(String(req.get("permit_general_id", "")))):
		return false
	if int(req.get("permit_category_count", 0)) > int(brm.get_total(String(req.get("permit_category_id", "")))):
		return false
	if int(req.get("permit_specific_count", 0)) > int(brm.get_total(String(req.get("permit_specific_id", "")))):
		return false
	return true

## 执行改造：安装 MOD
## 替换规则：
##   - 同 conflict_group 冲突：替换已有旧件（总数不变）
##   - 无冲突且未满 9 个：追加（总数 +1）
##   - 无冲突但已满 9 个：拒绝
static func apply_modification(card_id: String, option_id: String, bpm_ref: Node) -> bool:
	var mod_index: int = get_modification_count(card_id, bpm_ref.blueprint_mods)
	## 冲突替换时 mod_index 可能 == count，先不严格校验 count == index
	if card_id.is_empty() or mod_index < 0 or mod_index >= ModEffects.MAX_MOD_SLOTS:
		return false
	var options: Array[Dictionary] = get_mod_options(card_id)
	var found: bool = false
	for op in options:
		if String(op.get("id", "")) == option_id:
			found = true
			break
	if not found:
		return false
	## 资源检查
	var req: Dictionary = get_modification_requirements(card_id, mod_index, bpm_ref)
	if bpm_ref.get_research_points() < int(req.get("research_points", 0)):
		return false
	var brm: Node = bpm_ref._get_basic_resource_manager()
	if brm == null or not brm.has_method("get_total"):
		return false
	if int(req.get("permit_general_count", 0)) > int(brm.get_total(String(req.get("permit_general_id", "")))):
		return false
	if int(req.get("permit_category_count", 0)) > int(brm.get_total(String(req.get("permit_category_id", "")))):
		return false
	if int(req.get("permit_specific_count", 0)) > int(brm.get_total(String(req.get("permit_specific_id", "")))):
		return false
	## 冲突检测 + 替换/追加
	var conflict_group: String = ModEffects.get_conflict_group(option_id)
	var mods: Array = bpm_ref.blueprint_mods.get(card_id, [])
	var replaced: bool = false
	if not conflict_group.is_empty():
		for i in range(mods.size()):
			if ModEffects.get_conflict_group(String(mods[i])) == conflict_group:
				mods[i] = option_id
				replaced = true
				if bpm_ref.DEBUG_BLUEPRINT_LOG:
					print("[ModManager] 改造替换：slot %d %s → %s" % [i, mods[i], option_id])
				break
	if not replaced:
		if mods.size() >= ModEffects.MAX_MOD_SLOTS:
			return false
		mods.append(option_id)
	## 扣除消耗
	bpm_ref.add_research_points(-int(req.get("research_points", 0)))
	if brm != null and brm.has_method("add_resource"):
		var n_general: int = int(req.get("permit_general_count", 0))
		var n_category: int = int(req.get("permit_category_count", 0))
		var n_specific: int = int(req.get("permit_specific_count", 0))
		if n_general > 0:
			brm.add_resource(String(req.get("permit_general_id", "")), -n_general)
		if n_category > 0:
			brm.add_resource(String(req.get("permit_category_id", "")), -n_category)
		if n_specific > 0:
			brm.add_resource(String(req.get("permit_specific_id", "")), -n_specific)
	bpm_ref.blueprint_mods[card_id] = mods
	bpm_ref.emit_signal("fragments_changed")
	return true
