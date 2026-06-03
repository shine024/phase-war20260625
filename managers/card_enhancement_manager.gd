extends Node
## 单张卡片强化系统 v6.0：统一使用 CardResource.enhance_level
##
## 强化 vs 合成的区别：
## - 强化：单张卡片+纳米材料→属性增加（原卡保留ID）
## - 合成：卡牌+卡牌 或者 卡牌+蓝图 → 新卡（生成新ID）
##
## 强化等级：1-10级
## 强化成功率：100%（无失败机制）
## 强化消耗：固定基数 × 等级系数 × 时代系数（v6.0 修正）
## 强化效果：属性加成 Lv1=+5% ... Lv10=+60%
##           战力倍率 Lv1-8=1.0+level*0.05, Lv9=1.50, Lv10=1.60
##
## v6.0 修正：
## - 不再维护独立 card_enhancement_level 字典，统一读写 card.enhance_level
## - 消耗公式改为 固定基数 × 等级系数 × 时代系数，避免低级单位强化成本过低

signal enhancement_started(card_id: String, target_level: int)
signal enhancement_completed(success: bool, card_id: String, new_stats: Dictionary, message: String)
signal enhancement_failed(card_id: String, reason: String)

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const UnifiedRankSystem = preload("res://data/military_titles/unified_rank_system.gd")

# v6.0 强化等级配置
# 消耗 = ENHANCE_BASE_COST × level_cost_multiplier × era_multiplier
# 100% 成功，无 success_rate
var enhancement_config: Dictionary = {
	1:  {"level_cost_multiplier": 0.5, "attribute_bonus": 0.05},
	2:  {"level_cost_multiplier": 1.0, "attribute_bonus": 0.10},
	3:  {"level_cost_multiplier": 1.5, "attribute_bonus": 0.15},
	4:  {"level_cost_multiplier": 2.0, "attribute_bonus": 0.20},
	5:  {"level_cost_multiplier": 2.5, "attribute_bonus": 0.25},
	6:  {"level_cost_multiplier": 3.0, "attribute_bonus": 0.30},
	7:  {"level_cost_multiplier": 3.5, "attribute_bonus": 0.35},
	8:  {"level_cost_multiplier": 4.0, "attribute_bonus": 0.40},
	9:  {"level_cost_multiplier": 5.0, "attribute_bonus": 0.50},
	10: {"level_cost_multiplier": 6.0, "attribute_bonus": 0.60},
}

## 固定基数：所有单位共享的基础消耗值
const ENHANCE_BASE_COST: int = 50

## 时代系数：越高级时代消耗越高
const ERA_MULTIPLIER: Dictionary = {
	0: 0.5,   # WWI
	1: 1.0,   # WWII
	2: 2.0,   # 冷战
	3: 3.0,   # 现代
	4: 4.0,   # 近未来
}

func _ready() -> void:
	if Engine.is_editor_hint():
		return

func get_card_base_power(card_id: String) -> int:
	var card = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return 0
	return card.power

func get_card_era(card_id: String) -> int:
	var card = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return 0
	return card.era

func get_era_multiplier(era: int) -> float:
	return float(ERA_MULTIPLIER.get(clampi(era, 0, 4), 1.0))

func get_enhance_nano_cost(card_id: String, target_level: int) -> int:
	var config = enhancement_config.get(target_level, {})
	var level_mult = float(config.get("level_cost_multiplier", 1.0))
	var era = get_card_era(card_id)
	var era_mult = get_era_multiplier(era)
	return int(ENHANCE_BASE_COST * level_mult * era_mult)

func get_power_multiplier(level: int) -> float:
	if level >= 9:
		return 1.50 if level == 9 else 1.60
	return 1.0 + level * 0.05

## 获取卡牌当前强化等级（统一从 CardResource.enhance_level 读取）
func get_card_enhancement_level(card_id: String) -> int:
	var card = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return 0
	return maxi(card.enhance_level, 0)

func can_enhance(card_id: String, blueprint_manager: Node) -> bool:
	var card = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return false

	var current_level = get_card_enhancement_level(card_id)
	if current_level >= 10:
		return false

	var target_level = current_level + 1
	var nano_cost = get_enhance_nano_cost(card_id, target_level)

	if blueprint_manager == null or blueprint_manager.get_nano_materials() < nano_cost:
		return false

	return true

func enhance(card_id: String, blueprint_manager: Node) -> bool:
	if not can_enhance(card_id, blueprint_manager):
		emit_signal("enhancement_failed", card_id, "无法强化此卡牌")
		return false

	var card = DefaultCards.get_card_by_id(card_id)
	if card == null:
		emit_signal("enhancement_failed", card_id, "卡牌不存在")
		return false

	var current_level = get_card_enhancement_level(card_id)
	var target_level = current_level + 1

	var config = enhancement_config.get(target_level, {})
	var nano_cost = get_enhance_nano_cost(card_id, target_level)
	var attribute_bonus = float(config.get("attribute_bonus", 0.0))

	emit_signal("enhancement_started", card_id, target_level)

	blueprint_manager.add_nano_materials(-nano_cost)

	# v6.0: 直接写入 CardResource.enhance_level，与战斗系统统一
	card.enhance_level = target_level

	var new_stats = _calculate_enhanced_stats(card_id, attribute_bonus)
	var power_mult = get_power_multiplier(target_level)
	emit_signal("enhancement_completed", true, card_id, new_stats,
		"强化成功！等级提升至 Lv.%d，属性 +%.0f%%，战力倍率 %.2f" % [target_level, attribute_bonus * 100, power_mult])

	return true

func _calculate_enhanced_stats(card_id: String, bonus: float) -> Dictionary:
	var card = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return {}

	var level = get_card_enhancement_level(card_id)
	var power_mult = get_power_multiplier(level)

	var stats = {
		"card_id": card_id,
		"original_energy_cost": card.energy_cost,
		"enhanced_energy_cost": card.energy_cost * (1.0 + bonus * 0.5),
		"attribute_bonus": bonus,
		"level": level,
		"power_multiplier": power_mult,
	}

	match card.card_type:
		GC.CardType.COMBAT_UNIT:
			stats["hp_bonus"] = bonus
			stats["weight_bonus"] = bonus * 0.2
		GC.CardType.ENERGY:
			stats["energy_grant_bonus"] = bonus
		GC.CardType.LAW:
			stats["effect_bonus"] = bonus
		_:
			stats["damage_bonus"] = bonus

	return stats

func get_enhancement_info(card_id: String) -> Dictionary:
	var current_level = get_card_enhancement_level(card_id)

	var info = {
		"card_id": card_id,
		"current_level": current_level,
		"max_level": 10,
		"can_enhance": current_level < 10,
		"current_power_multiplier": get_power_multiplier(current_level),
	}

	if current_level < 10:
		var target_level = current_level + 1
		var config = enhancement_config.get(target_level, {})

		info["next_level"] = target_level
		info["nano_cost"] = get_enhance_nano_cost(card_id, target_level)
		info["attribute_bonus"] = float(config.get("attribute_bonus", 0.0))
		info["next_power_multiplier"] = get_power_multiplier(target_level)

	return info

func get_all_enhancement_costs(card_id: String) -> Dictionary:
	var costs = {}
	for level in enhancement_config.keys():
		costs[level] = get_enhance_nano_cost(card_id, level)
	return costs

func get_total_enhancement_cost_to_max(card_id: String) -> int:
	var current_level = get_card_enhancement_level(card_id)
	var total_cost = 0

	for level in range(current_level + 1, 11):
		total_cost += get_enhance_nano_cost(card_id, level)

	return total_cost

# ============ 存档功能 ============
# v6.0: enhance_level 已由 CardResource 管理，存档通过 BlueprintManager 的 blueprint_data 保存。
# 此处保留 save_state/load_state 做向后兼容（旧存档迁移用）。

func save_state() -> Dictionary:
	# v6.0: 不再保存独立字典，返回空标记
	return {"_v6_migrated": true}

func load_state(data: Dictionary) -> void:
	# v6.0: enhance_level 已在 CardResource 上，无需额外加载
	# 旧存档兼容：如果有 card_enhancement_level 数据，迁移到 CardResource
	if data.has("card_enhancement_level") and data["card_enhancement_level"] is Dictionary:
		var old_levels: Dictionary = data["card_enhancement_level"]
		for card_id in old_levels.keys():
			var card = DefaultCards.get_card_by_id(card_id)
			if card != null:
				card.enhance_level = int(old_levels[card_id])

func reset_to_defaults() -> void:
	# 重置所有卡牌 enhance_level 为 0
	var all_ids = DefaultCards.get_all_blueprint_ids()
	for card_id in all_ids:
		if not card_id.is_empty():
			var card = DefaultCards.get_card_by_id(card_id)
			if card != null:
				card.enhance_level = 0
