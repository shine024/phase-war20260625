class_name BackpackData
extends RefCounted
## 背包数据层 (Model)
## 管理背包中卡牌数据：仅「额外卡」列表（制造/掉落/读档恢复等），不再把 DefaultCards.create_all() 整池摊进背包，避免开局满屏默认卡 + 刷新过重导致卡顿/卡死。
## 不持有任何 UI 引用，可独立进行单元测试。
##
## 设计文档：背包 MVP 架构重构（MVP 模式拆分）
## 职责：
##   - 维护默认卡池 + 额外卡列表
##   - 提供筛选/排序逻辑
##   - 提供存档所需的序列化数据
##   - 派发数据变更信号，供 Presenter 订阅

signal cards_changed()  ## 背包卡牌集合发生增/删变化
signal filter_changed()  ## 筛选/排序条件变化

const DefaultCardsData = preload("res://data/default_cards.gd")
const PhaseLawsData = preload("res://data/phase_laws.gd")
const GC = preload("res://resources/game_constants.gd")

## 背包最大卡槽数
const MAX_CARD_SLOTS: int = 50

## 筛选类型常量（与 GC.CardType 对齐）
enum FilterType {
	ALL = -1,       ## 全部
	PLATFORM = 0,   ## 战斗卡（对应 GC.CardType.COMBAT_UNIT）
	ENERGY = 1,     ## 能量卡（对应 GC.CardType.ENERGY）
	LAW = 2,        ## 法则卡（对应 GC.CardType.LAW）
}

## 排序方式
enum SortType {
	DEFAULT,  ## 默认顺序
	NAME,     ## 按名称
	COST,     ## 按费用
	RARITY,   ## 按稀有度
}

## 额外卡 ID 列表（非默认卡池中的卡，如合成卡、掉落卡）
## 同 id 允许重复，保证读档后不丢失重复卡
var _extra_card_ids: Array = []
var _all_cards_cache: Array[CardResource] = []
var _cards_cache_dirty: bool = true

## 当前筛选类型
var _current_filter_type: int = FilterType.ALL

## 当前排序方式
var _current_sort_type: int = SortType.DEFAULT

## 当前排序是否反转
var _current_sort_reverse: bool = false

## ============================================================
## 初始化 / 重置
## ============================================================

## 重新构建背包卡列表（仅额外卡 ID，不含开局默认全卡池）
func get_all_cards() -> Array[CardResource]:
	if not _cards_cache_dirty:
		return _all_cards_cache
	_all_cards_cache.clear()
	# v7.0: 优先用 InstanceRegistry 取独立实例（含养成）；回退到 DefaultCards 取模板
	var ir: Node = null
	var tree = Engine.get_main_loop()
	if tree and tree.root:
		ir = tree.root.get_node_or_null("InstanceRegistry")
	for id_val in _extra_card_ids:
		var sid: String = str(id_val) if id_val != null else ""
		if sid.is_empty():
			continue
		var card: CardResource = null
		# 先按 instance_id 取实例
		if ir != null and ir.has_method("get_instance"):
			card = ir.get_instance(sid)
		# v7.x 修复（Bug1）：实例查不到时，重建并注册新实例（而非对带 #序号 的 instance_id 查 get_card_by_id 必失败导致卡消失）。
		# 根因：势力卡裸 card_id / 旧档迁移 / load_state 模板查不到静默跳过 等场景，会使 Registry 缺失该实例。
		# 重建后卡不消失、可继续养成（原养成数据若 Registry 本就没存，从0开始，但至少能正常游戏）。
		# v7.x 重复修复：原逻辑无脑 create_instance 新建实例（如 omega_platform#2），导致 Registry 多出同名实例、
		# 成长/背包面板显示重复。改为：优先复用同名实例，只有该 card_id 一个实例都没有时才新建。
		if card == null and ir != null and ir.has_method("get_card_id_of"):
			var base_id: String = ir.get_card_id_of(sid)  # cold_t72#1 → cold_t72（无序号时返回原值）
			if not base_id.is_empty():
				# 优先复用已有的同名实例
				if ir.has_method("get_instances_by_card_id"):
					var _existing: Array = ir.get_instances_by_card_id(base_id)
					if not _existing.is_empty():
						card = ir.get_instance(String(_existing[0]))
						if card != null:
							push_warning("[BackpackData] get_all_cards: 实例 '%s' 缺失，已复用同名实例 '%s'" % [sid, card.instance_id])
				# 该 card_id 一个实例都没有 → 才新建
				if card == null and ir.has_method("create_instance"):
					card = ir.create_instance(base_id)
					if card != null:
						push_warning("[BackpackData] get_all_cards: 实例 '%s' 不存在且无同名实例，已新建 '%s'（养成从0开始）" % [sid, card.instance_id])
		# 最终兜底：ir 不存在或 create_instance 失败（非战斗卡/法则卡），回退 DefaultCards 模板
		if card == null:
			card = DefaultCardsData.get_card_by_id(sid)
		if card == null and sid.begins_with("law:"):
			sid = sid.substr(4)
		if card == null:
			card = DefaultCardsData.create_law_card_resource(sid)
		if card != null:
			_all_cards_cache.append(card)
		else:
			push_warning("[BackpackData] get_all_cards: unresolved id=%s" % sid)
	_cards_cache_dirty = false
	return _all_cards_cache

## 去重后的额外卡 ID（供兼容接口；不再混入默认卡池）
func get_all_card_ids() -> Array:
	var all_ids: Array = []
	var seen: Dictionary = {}
	for extra_id in _extra_card_ids:
		var s: String = str(extra_id)
		if s.is_empty() or seen.has(s):
			continue
		seen[s] = true
		all_ids.append(s)
	return all_ids

## ============================================================
## 卡牌增删
## ============================================================

## 添加一张额外卡（合成卡、掉落卡等）
## silent：为 true 时不发 cards_changed（由调用方自己做增量 UI，避免先全量重建再 add_card 导致双倍开销甚至卡死）
func add_extra_card(card_id: String, silent: bool = false) -> void:
	if card_id.is_empty():
		return
	_extra_card_ids.append(card_id)
	_invalidate_cards_cache()
	if not silent:
		cards_changed.emit()

## 根据 card_id 移除一张卡（从额外卡列表中删除一条匹配记录）
## returns: 是否成功移除
func remove_card(card_id: String, silent: bool = false) -> bool:
	if card_id.is_empty():
		return false
	var idx: int = _extra_card_ids.find(card_id)
	if idx >= 0:
		_extra_card_ids.remove_at(idx)
		_invalidate_cards_cache()
		if not silent:
			cards_changed.emit()
		return true
	# 如果不在额外卡中，可能是默认卡被消耗，也通知 UI 刷新
	_invalidate_cards_cache()
	if not silent:
		cards_changed.emit()
	return true

## 严格移除：仅当额外卡列表中存在该 card_id 时才移除并返回 true
func remove_extra_card_strict(card_id: String, silent: bool = false) -> bool:
	if card_id.is_empty():
		return false
	var idx: int = _extra_card_ids.find(card_id)
	if idx < 0:
		return false
	_extra_card_ids.remove_at(idx)
	_invalidate_cards_cache()
	if not silent:
		cards_changed.emit()
	return true

## ============================================================
## 筛选 / 排序
## ============================================================

func set_filter_type(filter_type: int) -> void:
	_current_filter_type = filter_type
	filter_changed.emit()

func set_sort_type(sort_type: int) -> void:
	if _current_sort_type == sort_type:
		_current_sort_reverse = not _current_sort_reverse
	else:
		_current_sort_type = sort_type
		_current_sort_reverse = false
	filter_changed.emit()

func reset_filters() -> void:
	_current_filter_type = FilterType.ALL
	_current_sort_type = SortType.DEFAULT
	_current_sort_reverse = false
	filter_changed.emit()

## 获取经过筛选和排序后的卡牌列表
func get_filtered_sorted_cards() -> Array[CardResource]:
	var cards := get_all_cards()
	var filtered := _apply_filter(cards)
	var sorted := _apply_sort(filtered)
	return sorted

func is_default_view_mode() -> bool:
	return _current_filter_type == FilterType.ALL and _current_sort_type == SortType.DEFAULT and not _current_sort_reverse

## 快速按稀有度筛选（返回符合稀有度的卡 ID 列表）
func get_card_ids_by_rarity(rarity: String) -> Array[String]:
	var result: Array[String] = []
	for card in get_all_cards():
		if card.rarity == rarity:
			result.append(card.card_id)
	return result

## ============================================================
## 统计
## ============================================================

## 获取背包统计信息
func get_statistics() -> Dictionary:
	var stats := {
		"total_cards": 0,
		"platform_cards": 0,
		"weapon_cards": 0,
		"energy_cards": 0,
		"law_cards": 0,
		"empty_slots": MAX_CARD_SLOTS,
	}
	for card in get_all_cards():
		stats["total_cards"] += 1
		stats["empty_slots"] -= 1
		match card.card_type:
			GC.CardType.COMBAT_UNIT:
				stats["platform_cards"] += 1
			GC.CardType.PLATFORM, GC.CardType.WEAPON, GC.CardType.COMBINED:
				# 武器概念下线后，将旧武器/平台/合成卡一并计入战斗卡
				stats["platform_cards"] += 1
				stats["weapon_cards"] += 1  # 保留旧字段以兼容外部读取
			GC.CardType.ENERGY:
				stats["energy_cards"] += 1
			GC.CardType.LAW:
				stats["law_cards"] += 1
	return stats

## ============================================================
## 存档接口
## ============================================================

## 获取额外卡 ID 列表（供存档写入）
func get_extra_card_ids() -> Array:
	return _extra_card_ids.duplicate()

## 读档后恢复额外卡列表并重置状态
func restore_extra_cards(ids: Array) -> void:
	_extra_card_ids.clear()
	for id_val in ids:
		var sid: String = str(id_val) if id_val != null else ""
		if not sid.is_empty():
			_extra_card_ids.append(sid)
	_invalidate_cards_cache()
	cards_changed.emit()

## 追加额外卡列表（不清空现有数据）
func append_extra_cards(ids: Array, silent: bool = false) -> void:
	var changed: bool = false
	for id_val in ids:
		var sid: String = str(id_val) if id_val != null else ""
		if sid.is_empty():
			continue
		_extra_card_ids.append(sid)
		changed = true
	if changed:
		_invalidate_cards_cache()
	if changed and not silent:
		cards_changed.emit()

## ============================================================
## 能量卡保底逻辑
## ============================================================

## 曾用于把默认能量卡塞进网格；背包已改为仅显示额外卡，不再自动注入，避免与「无默认池」设计冲突及多余 UI 刷新
func get_guaranteed_energy_cards() -> Array[CardResource]:
	return []

## ============================================================
## 内部实现
## ============================================================

func _apply_filter(cards: Array[CardResource]) -> Array[CardResource]:
	if _current_filter_type == FilterType.ALL:
		return cards
	var filtered: Array[CardResource] = []
	for card in cards:
		if card.card_type == _current_filter_type:
			filtered.append(card)
	return filtered

func _apply_sort(cards: Array[CardResource]) -> Array[CardResource]:
	if _current_sort_type == SortType.DEFAULT:
		return cards
	var sorted := cards.duplicate()
	match _current_sort_type:
		SortType.NAME:
			sorted.sort_custom(func(a: CardResource, b: CardResource): return a.display_name < b.display_name)
		SortType.COST:
			sorted.sort_custom(func(a: CardResource, b: CardResource): return a.energy_cost < b.energy_cost)
		SortType.RARITY:
			sorted.sort_custom(func(a: CardResource, b: CardResource): return _get_rarity_value(a.rarity) < _get_rarity_value(b.rarity))
	if _current_sort_reverse:
		sorted.reverse()
	return sorted

func _invalidate_cards_cache() -> void:
	_cards_cache_dirty = true

static func _get_rarity_value(rarity: String) -> int:
	match rarity:
		"common": return 0
		"uncommon": return 1
		"rare": return 2
		"epic": return 3
		"legendary": return 4
		_: return 0
