class_name RarityHelpers
extends RefCounted
## 稀有度查询辅助工具（从 blueprint_manager.gd 拆分）
## 负责：获取卡牌基础/有效稀有度、稀有度乘数、稀有度颜色查询
## 注意：实际计算委托给 EvolutionHelpers，此处仅提供统一入口 + 缓存逻辑

const GC = preload("res://resources/game_constants.gd")

## ── 静态方法（供 BlueprintManager 或其他系统调用） ──

## 获取卡牌基础稀有度（委托 EvolutionHelpers）
static func get_card_base_rarity(card_id: String) -> String:
	if not ClassDB.class_exists("EvolutionHelpers"):
		return _fallback_rarity(card_id)
	return EvolutionHelpers.get_card_base_rarity(card_id)

## 获取卡牌当前稀有度（含升级影响）
static func get_card_rarity(card_id: String) -> String:
	if not ClassDB.class_exists("EvolutionHelpers"):
		return _fallback_rarity(card_id)
	return EvolutionHelpers.get_card_rarity(card_id)

## 稀有度对应的数值乘数
static func get_rarity_multiplier(card_id: String) -> float:
	if not ClassDB.class_exists("EvolutionHelpers"):
		return 1.0
	return EvolutionHelpers.get_rarity_multiplier(card_id)

## 有效战力乘数（含星级 + 稀有度 + 军衔加成）
## 注意：此方法需要 BlueprintManager 实例
static func get_effective_power_multiplier(card_id: String, _bp_manager: Node) -> float:
	if not ClassDB.class_exists("EvolutionHelpers"):
		return 1.0
	return EvolutionHelpers.get_effective_power_multiplier(card_id, _bp_manager)

## 获取稀有度对应颜色（供 UI 使用）
static func get_rarity_color(rarity: String) -> Color:
	if GC and GC.has_method("get_rarity_color"):
		return GC.get_rarity_color(rarity)
	match rarity.to_lower():
		"common": return Color(0.6, 0.6, 0.6, 1.0)
		"rare": return Color(0.3, 0.5, 1.0, 1.0)
		"epic": return Color(0.7, 0.3, 1.0, 1.0)
		"legendary": return Color(1.0, 0.7, 0.2, 1.0)
		"mythic": return Color(1.0, 0.3, 0.3, 1.0)
		_: return Color(0.6, 0.6, 0.6, 1.0)

## 稀有度显示名（中文）
static func get_rarity_display_name(rarity: String) -> String:
	match rarity.to_lower():
		"common": return "普通"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary": return "传说"
		"mythic": return "神话"
		_: return rarity

## 稀有度排序权重（数值越大越稀有）
static func get_rarity_sort_weight(rarity: String) -> int:
	match rarity.to_lower():
		"common": return 0
		"rare": return 1
		"epic": return 2
		"legendary": return 3
		"mythic": return 4
		_: return -1

## ── 内部辅助 ──

## 无法访问 EvolutionHelpers 时的兜底稀有度
static func _fallback_rarity(card_id: String) -> String:
	if card_id.begins_with("law:"):
		return "common"
	var DefaultCards = load("res://data/default_cards.gd")
	if DefaultCards == null:
		return "common"
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return "common"
	var r: String = String(card.rarity)
	if r.is_empty():
		return "common"
	return r
