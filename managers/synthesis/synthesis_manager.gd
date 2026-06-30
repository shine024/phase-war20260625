extends Node
class_name SynthesisManager

const SynthesisRecipes = preload("res://data/synthesis_recipes.gd")
const FactionCardBonuses = preload("res://data/faction_card_bonuses.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const ExclusiveCards = preload("res://data/faction_exclusive_cards.gd")

signal synthesis_completed(hybrid_card_id: String)
signal synthesis_failed(reason: String)

## 已合成的混血卡ID列表
var hybrid_cards: Array = []
## 混血卡重建配方: hybrid_id -> {base_card_id, faction_a, faction_b, level_a, level_b}
## 用于存档后重建混血 CardResource（避免序列化整个 Resource）
var hybrid_recipes: Dictionary = {}

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
## 返回 {"ok":bool, "hybrid_id":str, "reason":str(失败时), "hybrid_card":CardResource(成功时)}
## 资源消耗：research_points + nanomaterial + synthesis_permit（自动检查并扣除）
func synthesize(card_id_a: String, card_id_b: String) -> Dictionary:
	var check: Dictionary = can_synthesize(card_id_a, card_id_b)
	if not check.get("ok", false):
		synthesis_failed.emit(check.get("reason", "unknown"))
		return check
	# 检查并消耗资源
	var cost: Dictionary = SynthesisRecipes.get_synthesis_cost(check["base_card_id"], check["faction_a"], check["faction_b"])
	var brm: Node = get_node_or_null("/root/BasicResourceManager")
	if brm == null:
		synthesis_failed.emit("economy_unavailable")
		return {"ok": false, "reason": "economy_unavailable"}
	if not _check_and_spend_cost(brm, cost):
		synthesis_failed.emit("insufficient_resources")
		return {"ok": false, "reason": "insufficient_resources", "cost": cost}
	# 获取势力等级
	var level_a: int = _get_faction_level(check["faction_a"])
	var level_b: int = _get_faction_level(check["faction_b"])
	# 构建混血卡
	var hybrid: CardResource = _build_hybrid_card(check["base_card_id"], check["faction_a"], check["faction_b"], level_a, level_b, check["hybrid_id"])
	if hybrid == null:
		# 回滚资源消耗
		_refund_cost(brm, cost)
		synthesis_failed.emit("base_card_not_found")
		return {"ok": false, "reason": "base_card_not_found"}
	hybrid_cards.append(check["hybrid_id"])
	# 存储重建配方（存档后可重建）
	hybrid_recipes[check["hybrid_id"]] = {
		"base_card_id": check["base_card_id"],
		"faction_a": check["faction_a"],
		"faction_b": check["faction_b"],
		"level_a": level_a,
		"level_b": level_b,
	}
	# 注册到 DefaultCards 动态缓存，使 get_card_by_id 能找到它
	DefaultCards.register_dynamic_card(hybrid)
	# v7.0: 合成卡实例化（独立养成身份），用 instance_id 入队背包
	var hybrid_instance: CardResource = hybrid
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("create_instance_from_template"):
		hybrid_instance = ir.create_instance_from_template(hybrid)
	var enqueue_id: String = hybrid_instance.instance_id if not hybrid_instance.instance_id.is_empty() else check["hybrid_id"]
	# 加入玩家背包
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("enqueue_backpack_card_id"):
		sm.enqueue_backpack_card_id(enqueue_id)
	synthesis_completed.emit(check["hybrid_id"])
	return {"ok": true, "hybrid_card": hybrid_instance, "hybrid_id": check["hybrid_id"]}

## 检查并扣除合成资源（返回 false 表示资源不足）
func _check_and_spend_cost(brm: Node, cost: Dictionary) -> bool:
	# research_points
	var rp_needed: int = int(cost.get("research_points", 0))
	if rp_needed > 0:
		var rp_have: int = brm.get_total("research_points") if brm.has_method("get_total") else 0
		if rp_have < rp_needed:
			return false
	# nanomaterial
	var nm_needed: int = int(cost.get("nanomaterial", 0))
	if nm_needed > 0:
		var nm_have: int = brm.get_total("nano_materials") if brm.has_method("get_total") else 0
		if nm_have < nm_needed:
			return false
	# synthesis_permit（消耗品）
	var permit_needed: int = int(cost.get("synthesis_permit", 0))
	if permit_needed > 0:
		var permit_have: int = brm.get_total("synthesis_permit") if brm.has_method("get_total") else 0
		if permit_have < permit_needed:
			return false
	# 全部满足 → 扣除
	if rp_needed > 0 and brm.has_method("consume"):
		brm.consume("research_points", rp_needed)
	if nm_needed > 0 and brm.has_method("consume"):
		brm.consume("nano_materials", nm_needed)
	if permit_needed > 0 and brm.has_method("consume"):
		brm.consume("synthesis_permit", permit_needed)
	return true

## 回滚资源消耗（合成构建失败时）
func _refund_cost(brm: Node, cost: Dictionary) -> void:
	if brm.has_method("add_resource"):
		if int(cost.get("research_points", 0)) > 0:
			brm.add_resource("research_points", int(cost["research_points"]))
		if int(cost.get("nanomaterial", 0)) > 0:
			brm.add_resource("nano_materials", int(cost["nanomaterial"]))
		if int(cost.get("synthesis_permit", 0)) > 0:
			brm.add_resource("synthesis_permit", int(cost["synthesis_permit"]))

## 构建混血卡（内部复用：首次合成 + 存档重建共用）
func _build_hybrid_card(base_card_id: String, faction_a: String, faction_b: String, level_a: int, level_b: int, hybrid_id: String) -> CardResource:
	# 计算混血加成
	var hybrid_bonus: Dictionary = SynthesisRecipes.calculate_hybrid_bonus(
		base_card_id, faction_a, faction_b, level_a, level_b
	)
	# 创建混血 CardResource
	var base_card: CardResource = DefaultCards.get_card_by_id(base_card_id)
	if base_card == null:
		# 尝试专属卡
		for cfg in ExclusiveCards.EXCLUSIVE_CARDS:
			if cfg.get("id", "") == base_card_id:
				base_card = ExclusiveCards.create_card(cfg)
				break
	if base_card == null:
		return null
	var hybrid: CardResource = base_card.clone()
	hybrid.card_id = hybrid_id
	var name_a: String = FactionCardBonuses.FACTION_NAMES.get(faction_a, "")
	var name_b: String = FactionCardBonuses.FACTION_NAMES.get(faction_b, "")
	hybrid.display_name = "混血·%s x %s · %s" % [name_a, name_b, base_card.display_name]
	# 应用混血加成到属性
	_apply_hybrid_bonus_to_card(hybrid, hybrid_bonus)
	hybrid.power = base_card.power
	hybrid.is_faction_variant = true
	hybrid.is_faction_hybrid = true
	hybrid.faction_id = faction_a
	hybrid.hybrid_second_faction = faction_b
	hybrid.base_card_id = base_card_id
	hybrid.faction_level = max(level_a, level_b)
	hybrid.type_line = "%s — %s · 混血变体" % [hybrid.type_line, ""]
	hybrid.summary_line = "战力 %d｜混血·%s x %s" % [hybrid.power, name_a, name_b]
	return hybrid

## 根据 hybrid_id 重建混血卡（存档加载后调用）
func get_hybrid_card(hybrid_id: String) -> CardResource:
	if not hybrid_recipes.has(hybrid_id):
		# 尝试从已注册的动态卡取
		return DefaultCards.get_card_by_id(hybrid_id)
	var recipe: Dictionary = hybrid_recipes[hybrid_id]
	var card := _build_hybrid_card(
		recipe["base_card_id"], recipe["faction_a"], recipe["faction_b"],
		int(recipe["level_a"]), int(recipe["level_b"]), hybrid_id
	)
	if card:
		DefaultCards.register_dynamic_card(card)
	return card

## 启动时重建所有已存档的混血卡（恢复 DefaultCards 动态缓存）
func rebuild_all_hybrids() -> void:
	for hybrid_id in hybrid_cards:
		if hybrid_recipes.has(hybrid_id):
			get_hybrid_card(hybrid_id)

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
	return {
		"hybrid_cards": hybrid_cards.duplicate(),
		"hybrid_recipes": hybrid_recipes.duplicate(true),
	}

## 加载状态
func load_state(data: Dictionary) -> void:
	if data.has("hybrid_cards") and data["hybrid_cards"] is Array:
		hybrid_cards = data["hybrid_cards"].duplicate()
	else:
		hybrid_cards = []
	if data.has("hybrid_recipes") and data["hybrid_recipes"] is Dictionary:
		hybrid_recipes = data["hybrid_recipes"].duplicate(true)
	else:
		hybrid_recipes = {}
	# 重建所有混血卡到 DefaultCards 动态缓存（使 get_card_by_id 可用）
	call_deferred("rebuild_all_hybrids")
