extends Node
## 单张卡片强化系统 v5.0：区别于卡牌合成
##
## 强化 vs 合成的区别：
## - 强化：单张卡片+纳米材料→属性增加（原卡保留ID）
## - 合成：卡牌+卡牌 或 卡牌+蓝图 → 新卡（生成新ID）
##
## 强化等级：1-10级
## 强化成功率：100%（无失败机制）
## 强化消耗：基础战力 x 等级系数（动态计算）
## 强化效果：属性加成 Lv1=+5% ... Lv10=+60%，战力倍率 Lv1-8=1.0+level*0.05, Lv9=1.50, Lv10=1.60

signal enhancement_started(card_id: String, target_level: int)
signal enhancement_completed(success: bool, card_id: String, new_stats: Dictionary, message: String)
signal enhancement_failed(card_id: String, reason: String)

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")

# v5.0 强化等级配置
# 消耗 = 基础战力 x level_cost_multiplier（不再使用固定纳米消耗表）
# 100% 成功，无 success_rate
var enhancement_config: Dictionary = {
	1:  {"level_cost_multiplier": 0.5, "attribute_bonus": 0.05},   # Lv1:  消耗=基础战力*0.5,  +5% 属性
	2:  {"level_cost_multiplier": 1.0, "attribute_bonus": 0.10},   # Lv2:  消耗=基础战力*1.0,  +10% 属性
	3:  {"level_cost_multiplier": 1.5, "attribute_bonus": 0.15},   # Lv3:  消耗=基础战力*1.5,  +15% 属性
	4:  {"level_cost_multiplier": 2.0, "attribute_bonus": 0.20},   # Lv4:  消耗=基础战力*2.0,  +20% 属性
	5:  {"level_cost_multiplier": 2.5, "attribute_bonus": 0.25},   # Lv5:  消耗=基础战力*2.5,  +25% 属性
	6:  {"level_cost_multiplier": 3.0, "attribute_bonus": 0.30},   # Lv6:  消耗=基础战力*3.0,  +30% 属性
	7:  {"level_cost_multiplier": 3.5, "attribute_bonus": 0.35},   # Lv7:  消耗=基础战力*3.5,  +35% 属性
	8:  {"level_cost_multiplier": 4.0, "attribute_bonus": 0.40},   # Lv8:  消耗=基础战力*4.0,  +40% 属性
	9:  {"level_cost_multiplier": 5.0, "attribute_bonus": 0.50},   # Lv9:  消耗=基础战力*5.0,  +50% 属性
	10: {"level_cost_multiplier": 6.0, "attribute_bonus": 0.60},   # Lv10: 消耗=基础战力*6.0,  +60% 属性
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

func get_card_base_power(card_id: String) -> int:
	## 获取卡牌基础战力（用于动态计算强化消耗）
	var card = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return 0
	# 基础战力 = HP + DMG（或其他卡牌类型的等效值）
	return card.base_hp + card.base_damage

func get_enhance_nano_cost(card_id: String, target_level: int) -> int:
	## 计算强化到目标等级的纳米消耗 = 基础战力 x 等级系数
	var base_power = get_card_base_power(card_id)
	var config = enhancement_config.get(target_level, {})
	var multiplier = config.get("level_cost_multiplier", 1.0)
	return int(base_power * multiplier)

func get_power_multiplier(level: int) -> float:
	## 获取指定强化等级的战力倍率
	## Lv1-8: 1.0 + level * 0.05  →  Lv1=1.05, Lv8=1.40
	## Lv9=1.50, Lv10=1.60
	if level >= 9:
		return 1.50 if level == 9 else 1.60
	return 1.0 + level * 0.05

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
	
	# v5.0: 动态计算纳米消耗
	var target_level = current_level + 1
	var nano_cost = get_enhance_nano_cost(card_id, target_level)
	
	if blueprint_manager == null or blueprint_manager.get_nano_materials() < nano_cost:
		return false
	
	return true

func enhance(card_id: String, blueprint_manager: Node) -> bool:
	## 执行单张卡片强化（v5.0: 100% 成功）
	if not can_enhance(card_id, blueprint_manager):
		emit_signal("enhancement_failed", card_id, "无法强化此卡牌")
		return false
	
	var current_level = get_card_enhancement_level(card_id)
	var target_level = current_level + 1
	
	# 获取配置
	var config = enhancement_config.get(target_level, {})
	var nano_cost = get_enhance_nano_cost(card_id, target_level)
	var attribute_bonus = config.get("attribute_bonus", 0.0)
	
	# 发出开始信号
	emit_signal("enhancement_started", card_id, target_level)
	
	# 消耗纳米材料
	blueprint_manager.add_nano_materials(-nano_cost)
	
	# v5.0: 100% 成功，无随机判定
	# 强化成功：更新等级
	card_enhancement_level[card_id] = target_level
	
	# 计算新属性
	var new_stats = _calculate_enhanced_stats(card_id, attribute_bonus)
	
	var power_mult = get_power_multiplier(target_level)
	emit_signal("enhancement_completed", true, card_id, new_stats,
		"强化成功！等级提升至 Lv.%d，属性 +%.0f%%，战力倍率 %.2f" % [target_level, attribute_bonus * 100, power_mult])
	
	return true

func _calculate_enhanced_stats(card_id: String, bonus: float) -> Dictionary:
	## 计算强化后的卡牌属性
	var card = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return {}
	
	var level = get_card_enhancement_level(card_id)
	var power_mult = get_power_multiplier(level)
	
	# 基础属性加成
	var stats = {
		"card_id": card_id,
		"original_energy_cost": card.energy_cost,
		"enhanced_energy_cost": card.energy_cost * (1.0 + bonus * 0.5),  # 能量消耗也略微增加
		"attribute_bonus": bonus,  # 基础属性加成百分比
		"level": level,
		"power_multiplier": power_mult,  # v5.0: 战力倍率
	}
	
	# 不同类型卡牌的强化效果
	match card.card_type:
		GC.CardType.COMBAT_UNIT:
			stats["hp_bonus"] = bonus  # 血量提升 5%-60%
			stats["weight_bonus"] = bonus * 0.2  # 承载能力略微增加
			
		GC.CardType.ENERGY:
			stats["energy_grant_bonus"] = bonus  # 能量输出提升 5%-60%
			
		GC.CardType.LAW:
			stats["effect_bonus"] = bonus  # 法则效果提升 5%-60%
		
		_:
			stats["damage_bonus"] = bonus  # 默认：伤害提升 5%-60%
	
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
		"current_power_multiplier": get_power_multiplier(current_level),
	}
	
	if current_level < 10:
		var target_level = current_level + 1
		var config = enhancement_config.get(target_level, {})
		
		info["next_level"] = target_level
		info["nano_cost"] = get_enhance_nano_cost(card_id, target_level)
		info["attribute_bonus"] = config.get("attribute_bonus", 0.0)
		info["next_power_multiplier"] = get_power_multiplier(target_level)
	
	return info

func get_all_enhancement_costs(card_id: String) -> Dictionary:
	## 获取所有等级的强化成本（v5.0: 需要card_id动态计算）
	var costs = {}
	for level in enhancement_config.keys():
		costs[level] = get_enhance_nano_cost(card_id, level)
	return costs

func get_total_enhancement_cost_to_max(card_id: String) -> int:
	## 获取从当前等级升到满级的总成本（v5.0: 动态计算）
	var current_level = get_card_enhancement_level(card_id)
	var total_cost = 0
	
	for level in range(current_level + 1, 11):
		total_cost += get_enhance_nano_cost(card_id, level)
	
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
