extends Node
class_name SynthesisManager

const SynthesisRecipes = preload("res://data/synthesis_recipes.gd")
const FactionCardBonuses = preload("res://data/faction_card_bonuses.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const ExclusiveCards = preload("res://data/faction_exclusive_cards.gd")
const FactionSkillManager = preload("res://managers/faction/faction_skill_manager.gd")

signal synthesis_completed(hybrid_card_id: String)
signal synthesis_failed(reason: String)

## 已合成的混血卡ID列表
var hybrid_cards: Array = []

## 检查合成可行性
func can_synthesize(card_id_a: String, card_id_b: String) -> Dictionary:
	var base_a: String = _get_base_card_id(card_id_a)
	var base_b: String = _get_base_card_id(card_id_b)
	if base_a.is_empty() or base_b.is_empty():
		return {"ok": false, "reason": "invalid_card"}
	if base_a != base_b:
		return {"ok": false, "reason": "different_base"}
	var fac_a: String = _get_faction_id(card_id_a)
	var fac_b: String = _get_faction_id(card_id_b)
	if fac_a == fac_b:
		return {"ok": false, "reason": "same_faction"}
	if fac_a.is_empty() or fac_b.is_empty():
		return {"ok": false, "reason": "not_variant"}
	# 检查是否已有混血版本
	var hybrid_id: String = SynthesisRecipes.generate_hybrid_id(base_a, fac_a, fac_b)
	if hybrid_id in hybrid_cards:
		return {"ok": false, "reason": "already_exists"}
	return {"ok": true, "hybrid_id": hybrid_id, "base_card_id": base_a, "faction_a": fac_a, "faction_b": fac_b}

## 获取基础卡ID
func _get_base_card_id(card_id: String) -> String:
	if card_id.begins_with("fe_"):
		return card_id
	# 检查是否为势力变体（格式: faction_basecard）
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm != null and fsm.has_method("get_faction_variant_base_id"):
		var base: String = fsm.get_faction_variant_base_id(card_id)
		if not base.is_empty():
			return base
	return card_id

## 获取卡牌所属势力
func _get_faction_id(card_id: String) -> String:
	if card_id.begins_with("fe_"):
		return ExclusiveCards.get_exclusive_faction(card_id)
	# 尝试从 BlueprintManager 获取
	var bpm: Node = get_node_or_null("/root/BlueprintManager")
	if bpm != null and bpm.has_method("get_blueprint_faction_branch"):
		var faction: String = bpm.get_blueprint_faction_branch(card_id)
		if not faction.is_empty():
			return faction
	return ""

## 获取势力等级
func _get_faction_level(faction_id: String) -> int:
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm != null and fsm.has_method("get_faction_level"):
		return fsm.get_faction_level(faction_id)
	return 0

## 执行合成
func synthesize(card_id_a: String, card_id_b: String) -> Dictionary:
	var check: Dictionary = can_synthesize(card_id_a, card_id_b)
	if not check.get("ok", false):
		synthesis_failed.emit(check.get("reason", "unknown"))
		return check
	# 消耗资源（检查 + 扣除）-- 由调用方处理资源扣除
	# 获取势力等级
	var level_a: int = _get_faction_level(check["faction_a"])
	var level_b: int = _get_faction_level(check["faction_b"])
	# 计算混血加成
	var hybrid_bonus: Dictionary = SynthesisRecipes.calculate_hybrid_bonus(
		check["base_card_id"], check["faction_a"], check["faction_b"], level_a, level_b
	)
	# 创建混血 CardResource
	var base_card: CardResource = DefaultCards.get_card_by_id(check["base_card_id"])
	if base_card == null:
		# 尝试专属卡
		for cfg in ExclusiveCards.EXCLUSIVE_CARDS:
			if cfg.get("id", "") == check["base_card_id"]:
				base_card = ExclusiveCards.create_card(cfg)
				break
	if base_card == null:
		synthesis_failed.emit("base_card_not_found")
		return {"ok": false, "reason": "base_card_not_found"}
	var hybrid: CardResource = base_card.clone()
	hybrid.card_id = check["hybrid_id"]
	var name_a: String = FactionCardBonuses.FACTION_NAMES.get(check["faction_a"], "")
	var name_b: String = FactionCardBonuses.FACTION_NAMES.get(check["faction_b"], "")
	hybrid.display_name = "混血·%s x %s · %s" % [name_a, name_b, base_card.display_name]
	# 应用混血加成到属性
	_apply_hybrid_bonus_to_card(hybrid, hybrid_bonus)
	hybrid.power = base_card.power
	hybrid.is_faction_variant = true
	hybrid.is_faction_hybrid = true
	hybrid.faction_id = check["faction_a"]
	hybrid.hybrid_second_faction = check["faction_b"]
	hybrid.base_card_id = check["base_card_id"]
	hybrid.faction_level = max(level_a, level_b)
	hybrid.type_line = "%s — %s · 混血变体" % [hybrid.type_line, ""]
	hybrid.summary_line = "战力 %d｜混血·%s x %s" % [hybrid.power, name_a, name_b]
	hybrid_cards.append(check["hybrid_id"])
	synthesis_completed.emit(check["hybrid_id"])
	return {"ok": true, "hybrid_card": hybrid, "hybrid_id": check["hybrid_id"]}

## 将混血加成应用到卡牌属性
func _apply_hybrid_bonus_to_card(card: CardResource, bonus: Dictionary) -> void:
	if bonus.has("hp_bonus") and float(bonus["hp_bonus"]) != 0.0:
		card.base_hp *= (1.0 + float(bonus["hp_bonus"]))
	if bonus.has("atk_light_bonus") and float(bonus["atk_light_bonus"]) != 0.0:
		card.attack_light *= (1.0 + float(bonus["atk_light_bonus"]))
	if bonus.has("atk_armor_bonus") and float(bonus["atk_armor_bonus"]) != 0.0:
		card.attack_armor *= (1.0 + float(bonus["atk_armor_bonus"]))
	if bonus.has("atk_air_bonus") and float(bonus["atk_air_bonus"]) != 0.0:
		card.attack_air *= (1.0 + float(bonus["atk_air_bonus"]))
	if bonus.has("def_light_bonus") and float(bonus["def_light_bonus"]) != 0.0:
		card.defense_light *= (1.0 + float(bonus["def_light_bonus"]))
	if bonus.has("def_armor_bonus") and float(bonus["def_armor_bonus"]) != 0.0:
		card.defense_armor *= (1.0 + float(bonus["def_armor_bonus"]))
	if bonus.has("def_air_bonus") and float(bonus["def_air_bonus"]) != 0.0:
		card.defense_air *= (1.0 + float(bonus["def_air_bonus"]))
	if bonus.has("energy_cost_reduce") and float(bonus["energy_cost_reduce"]) != 0.0:
		card.energy_cost *= (1.0 - float(bonus["energy_cost_reduce"]))
	if bonus.has("deploy_speed_bonus") and int(bonus["deploy_speed_bonus"]) != 0:
		card.deploy_speed += int(bonus["deploy_speed_bonus"])
	if bonus.has("attack_speed_bonus") and float(bonus["attack_speed_bonus"]) != 0.0:
		card.attack_light_speed *= (1.0 + float(bonus["attack_speed_bonus"]))
		card.attack_armor_speed *= (1.0 + float(bonus["attack_speed_bonus"]))
		card.attack_air_speed *= (1.0 + float(bonus["attack_speed_bonus"]))

## 获取所有混血卡ID
func get_all_hybrid_ids() -> Array:
	return hybrid_cards.duplicate()

## 检查是否为混血卡
func is_hybrid(card_id: String) -> bool:
	return card_id in hybrid_cards

## 保存状态
func save_state() -> Dictionary:
	return {"hybrid_cards": hybrid_cards.duplicate()}

## 加载状态
func load_state(data: Dictionary) -> void:
	if data.has("hybrid_cards") and data["hybrid_cards"] is Array:
		hybrid_cards = data["hybrid_cards"].duplicate()
	else:
		hybrid_cards = []
