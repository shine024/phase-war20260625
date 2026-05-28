extends Node
## 单张卡片强化系统：区别于卡牌合成
##
## 强化 vs 合成的区别：
## - 强化：单张卡片+纳米材料→属性增加（原卡保留ID）
## - 合成：卡牌+卡牌 或 卡牌+蓝图 → 新卡（生成新ID）
##
## 强化等级：1-10级
## 强化消耗：递增的纳米材料
## 强化效果：基础属性加成（HP、DMG）+ 稀有度变化

signal enhancement_started(card_id: String, target_level: int)
signal enhancement_completed(success: bool, card_id: String, new_stats: Dictionary, message: String)
signal enhancement_failed(card_id: String, reason: String)

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")

# 强化等级配置
var enhancement_config: Dictionary = {
	1: {"nano_cost": 100, "success_rate": 0.95, "attribute_bonus": 0.05},   # Lv1: +5% 属性
	2: {"nano_cost": 200, "success_rate": 0.90, "attribute_bonus": 0.10},   # Lv2: +10% 属性
	3: {"nano_cost": 350, "success_rate": 0.85, "attribute_bonus": 0.15},   # Lv3: +15% 属性
	4: {"nano_cost": 550, "success_rate": 0.80, "attribute_bonus": 0.20},   # Lv4: +20% 属性
	5: {"nano_cost": 800, "success_rate": 0.75, "attribute_bonus": 0.25},   # Lv5: +25% 属性
	6: {"nano_cost": 1100, "success_rate": 0.70, "attribute_bonus": 0.30},  # Lv6: +30% 属性
	7: {"nano_cost": 1450, "success_rate": 0.65, "attribute_bonus": 0.35},  # Lv7: +35% 属性
	8: {"nano_cost": 1850, "success_rate": 0.60, "attribute_bonus": 0.40},  # Lv8: +40% 属性
	9: {"nano_cost": 2300, "success_rate": 0.50, "attribute_bonus": 0.50},  # Lv9: +50% 属性
	10: {"nano_cost": 3000, "success_rate": 0.40, "attribute_bonus": 0.60}, # Lv10: +60% 属性
}

# 追踪卡牌强化等级：card_id -> 当前强化等级(1-10)
var card_enhancement_level: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	# 初始化所有卡牌强化等级为1
	_init_card_enhancement_data()

func _init_card_enhancement_data() -> void:
	## 初始化卡牌强化数据
	var all_ids = DefaultCards.get_all_blueprint_ids()
	
	for card_id in all_ids:
		if not card_id.is_empty():
			card_enhancement_level[card_id] = 1

func can_enhance(card_id: String, blueprint_manager: Node) -> bool:
	## 检查是否可以强化某张卡牌
	# 检查卡牌是否存在
	var card = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return false
	
	# 检查是否已达到最高等级
	var current_level = get_card_enhancement_level(card_id)
	if current_level >= 10:
		return false
	
	# 检查纳米材料是否足够
	var target_level = current_level + 1
	var config = enhancement_config.get(target_level, {})
	var nano_cost = config.get("nano_cost", 0)
	
	if blueprint_manager == null or blueprint_manager.get_nano_materials() < nano_cost:
		return false
	
	return true

func enhance(card_id: String, blueprint_manager: Node) -> bool:
	## 执行单张卡片强化
	if not can_enhance(card_id, blueprint_manager):
		emit_signal("enhancement_failed", card_id, "无法强化此卡牌")
		return false
	
	var current_level = get_card_enhancement_level(card_id)
	var target_level = current_level + 1
	
	# 获取配置
	var config = enhancement_config.get(target_level, {})
	var nano_cost = config.get("nano_cost", 0)
	var success_rate = config.get("success_rate", 0.5)
	var attribute_bonus = config.get("attribute_bonus", 0.0)
	
	# 发出开始信号
	emit_signal("enhancement_started", card_id, target_level)
	
	# 消耗纳米材料（add_nano_materials 为 void，前置校验已在 can_enhance 中完成）
	blueprint_manager.add_nano_materials(-nano_cost)
	
	# 检查成功率
	if randf() > success_rate:
		# 强化失败
		emit_signal("enhancement_completed", false, card_id, {}, "强化失败！成功率: %.0f%%" % (success_rate * 100))
		return false
	
	# 强化成功：更新等级
	card_enhancement_level[card_id] = target_level
	
	# 计算新属性
	var new_stats = _calculate_enhanced_stats(card_id, attribute_bonus)
	
	emit_signal("enhancement_completed", true, card_id, new_stats, "强化成功！等级提升至 Lv.%d，属性 +%.0f%%" % [target_level, attribute_bonus * 100])
	
	return true

func _calculate_enhanced_stats(card_id: String, bonus: float) -> Dictionary:
	## 计算强化后的卡牌属性
	var card = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return {}
	
	# 基础属性加成（可根据卡牌类型定制）
	var stats = {
		"card_id": card_id,
		"original_energy_cost": card.energy_cost,
		"enhanced_energy_cost": card.energy_cost * (1.0 + bonus * 0.5),  # 能量消耗也略微增加
		"attribute_bonus": bonus,  # 基础属性加成百分比
		"level": get_card_enhancement_level(card_id),
	}
	
	# 不同类型卡牌的强化效果
	match card.card_type:
		GC.CardType.COMBAT_UNIT:
			stats["hp_bonus"] = bonus  # 血量提升 5%-60%
			stats["weight_bonus"] = bonus * 0.2  # 承载能力略微增加
		
		GC.CardType.COMBAT_UNIT:
			stats["damage_bonus"] = bonus  # 伤害提升 5%-60%
			stats["weight_bonus"] = -bonus * 0.1  # 优化设计，重量略微降低
		
		GC.CardType.ENERGY:
			stats["energy_grant_bonus"] = bonus  # 能量输出提升 5%-60%
		
		GC.CardType.LAW:
			stats["effect_bonus"] = bonus  # 法则效果提升 5%-60%
	
	return stats

func get_card_enhancement_level(card_id: String) -> int:
	## 获取卡牌当前强化等级
	return card_enhancement_level.get(card_id, 1)

func get_enhancement_info(card_id: String) -> Dictionary:
	## 获取卡牌强化信息
	var current_level = get_card_enhancement_level(card_id)
	
	var info = {
		"card_id": card_id,
		"current_level": current_level,
		"max_level": 10,
		"can_enhance": current_level < 10,
	}
	
	if current_level < 10:
		var target_level = current_level + 1
		var config = enhancement_config.get(target_level, {})
		
		info["next_level"] = target_level
		info["nano_cost"] = config.get("nano_cost", 0)
		info["success_rate"] = config.get("success_rate", 0.5)
		info["attribute_bonus"] = config.get("attribute_bonus", 0.0)
	
	return info

func get_all_enhancement_costs() -> Dictionary:
	## 获取所有等级的强化成本
	var costs = {}
	for level in enhancement_config.keys():
		costs[level] = enhancement_config[level].get("nano_cost", 0)
	return costs

func get_total_enhancement_cost_to_max(card_id: String) -> int:
	## 获取从当前等级升到满级的总成本
	var current_level = get_card_enhancement_level(card_id)
	var total_cost = 0
	
	for level in range(current_level + 1, 11):
		var config = enhancement_config.get(level, {})
		total_cost += config.get("nano_cost", 0)
	
	return total_cost

# ============ 存档功能 ============

func save_state() -> Dictionary:
	## 保存强化系统状态
	return {
		"card_enhancement_level": card_enhancement_level.duplicate(true),
	}

func load_state(data: Dictionary) -> void:
	## 加载强化系统状态
	if data.has("card_enhancement_level") and data["card_enhancement_level"] is Dictionary:
		card_enhancement_level = (data["card_enhancement_level"] as Dictionary).duplicate(true)
		# 确保新卡牌初始化为1级
		_init_card_enhancement_data()

func reset_to_defaults() -> void:
	## 重置到默认状态
	card_enhancement_level.clear()
	_init_card_enhancement_data()