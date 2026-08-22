class_name PhaseInstrumentLoadoutSync
extends RefCounted
## 相位仪装备/卸下/负载同步逻辑（从 phase_instrument_manager 拆分）
## 负责：equip_card, unequip_card, unequip_all, loadouts
## v9.x（P2-7范围B）：法则同步函数群已随法则系统退役移除

const GC = preload("res://resources/game_constants.gd")
const DEBUG_EQUIP_LOG := false

## ── 宿主引用（由 phase_instrument_manager 在 _ready 设置） ──
var _host: Node = null  # PhaseInstrumentManager

func setup(host: Node) -> void:
	_host = host

## ── 内部引用：通过 host 读取状态 ──
func _instrument_slots() -> Dictionary:
	return _host.instrument_slots if _host else {}
func _mark_loadouts_dirty() -> void:
	if _host and _host.has_method("_mark_loadouts_dirty"):
		_host._mark_loadouts_dirty()
func _emit_slots_changed() -> void:
	if _host and _host.has_method("_emit_slots_changed"):
		_host._emit_slots_changed()
func _card_type_name(card: CardResource) -> String:
	if _host and _host.has_method("_card_type_name"):
		return _host._card_type_name(card)
	return ""

# v9.x（P2-7范围B）：_law_id_from_card / _has_any_law_card_in_slots /
# _compact_law_ids_* / _apply_law_slots_to_plm / sync_* 法则函数群
# 已随法则系统退役移除
## ── 装备卡牌到槽位 ──
func equip_card(slot_index: int, card: CardResource, _energy_manager: Node = null, _recursion_depth: int = 0) -> bool:
	var _equip_t0: int = Time.get_ticks_msec()
	var loc: Dictionary = _host._flat_index_to_slot(slot_index) if _host and _host.has_method("_flat_index_to_slot") else {}
	var color: String = String(loc.get("color", ""))
	var color_index: int = int(loc.get("index", -1))
	if color.is_empty() or color_index < 0 or card == null:
		return false
	if not _can_equip_card_to_color(card, color):
		# v9.x（P2-7范围B）：法则卡自动路由与红/蓝槽 PLM 同步已随法则系统退役移除
		return false

	if DEBUG_EQUIP_LOG:
		pass  # [LOG-v5.1] print("[PhaseInstrumentLoadoutSync] 装备卡牌 %s 到槽位 %s (颜色: %s)" % [card.display_name, slot_index, color])

	var slots: Dictionary = _instrument_slots()
	var arr: Array = slots.get(color, [])
	var old_card: CardResource = arr[color_index]
	arr[color_index] = card
	slots[color] = arr
	_host.instrument_slots = slots

	# v7.0: card_equipped 第2参数改传 instance_id；无 instance_id 回退 card_id
	var equip_id: String = card.instance_id if not card.instance_id.is_empty() else card.card_id
	if old_card != null:
		# 换装原子信号（与主文件 equip_card 同步，消除双信号中间态导致的背包重复 bug）
		SignalBus.card_swapped.emit(slot_index, old_card, equip_id)
	else:
		SignalBus.card_equipped.emit(slot_index, equip_id, _card_type_name(card))
	_emit_slots_changed()
	return true

## ── 卸下槽位卡牌 ──
func unequip_card(slot_index: int) -> void:
	var loc: Dictionary = _host._flat_index_to_slot(slot_index) if _host and _host.has_method("_flat_index_to_slot") else {}
	var color: String = String(loc.get("color", ""))
	var color_index: int = int(loc.get("index", -1))
	if color.is_empty() or color_index < 0:
		return
	var slots: Dictionary = _instrument_slots()
	var arr: Array = slots.get(color, [])
	var card: CardResource = arr[color_index]
	arr[color_index] = null
	slots[color] = arr
	_host.instrument_slots = slots
	# v9.x（P2-7范围B）：红/蓝槽法则同步已随法则系统退役移除
	_emit_slots_changed()
	SignalBus.card_unequipped.emit(slot_index)
	if card != null:
		SignalBus.card_added_to_backpack.emit(card)

## 战斗结束后：清空所有槽位并将卡片逐一放回背包
func unequip_all_and_return_to_backpack() -> void:
	var CARD_SLOTS: Array[String] = ["red", "blue", "green", "yellow"]
	var cards_to_return: Array[CardResource] = []
	var slots: Dictionary = _instrument_slots()
	for color in CARD_SLOTS:
		var arr: Array = slots.get(color, [])
		for i in range(arr.size()):
			var c: CardResource = arr[i]
			if c != null:
				cards_to_return.append(c)
				arr[i] = null
			slots[color] = arr
	_host.instrument_slots = slots
	# v9.x（P2-7范围B）：法则槽同步已随法则系统退役移除
	_emit_slots_changed()
	if SignalBus and not cards_to_return.is_empty():
		for c2 in cards_to_return:
			SignalBus.card_added_to_backpack.emit(c2)
			# [LOG-v5.1] print("[PhaseInstrumentLoadoutSync] 卡片 %s 已返还背包" % c2.card_id)

## ── 负载系统 ──
func get_loadouts() -> Array:
	if not _host or not _host.has_method("get_phase_field_level"):
		return []
	var loadouts: Array = []
	var green_slots: Array = _instrument_slots().get("green", [])
	for c_raw in green_slots:
		var c: CardResource = c_raw
		if c == null:
			continue
		if c.card_type != GC.CardType.COMBAT_UNIT:
			continue
		loadouts.append({"platform": c, "weapons": []})
	return loadouts

## 按平台卡 id 查找完整 loadout
func get_loadout_by_platform_card_id(platform_card_id: String) -> Dictionary:
	if platform_card_id.is_empty():
		return {}
	for ld in get_loadouts():
		if not (ld is Dictionary):
			continue
		var plat: CardResource = ld.get("platform", null)
		if plat != null and plat.card_id == platform_card_id:
			return ld
	return {}

func _can_equip_card_to_color(card: CardResource, color: String) -> bool:
	if color == "green":
		return card.card_type == GC.CardType.COMBAT_UNIT
	# v7.x: yellow 能量槽已移除（能量卡系统移除），不再接受任何卡
	if color == "yellow":
		return false
	# v9.x（P2-7范围B）：红/蓝法则槽不再接受任何卡（法则系统退役；槽位自 v6.2 起数量恒 0）
	return false
