class_name PhaseInstrumentLoadoutSync
extends RefCounted
## 相位仪装备/卸下/负载同步逻辑（从 phase_instrument_manager 拆分）
## 负责：equip_card, unequip_card, unequip_all, loadouts, 法则同步

const GC = preload("res://resources/game_constants.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const DefaultCards = preload("res://data/default_cards.gd")

## 法则卡跨色路由装配时的最大递归深度（防止无限递归）
const MAX_EQUIP_RECURSION: int = 2
const DEBUG_EQUIP_LOG := false

## ── 宿主引用（由 phase_instrument_manager 在 _ready 设置） ──
var _host: Node = null  # PhaseInstrumentManager

func setup(host: Node) -> void:
	_host = host

## ── 内部引用：通过 host 读取状态 ──
func _instrument_slots() -> Dictionary:
	return _host.instrument_slots if _host else {}
func _plm() -> Node:
	return _host._plm if _host else null
func _ensure_plm() -> Node:
	if _host and _host.has_method("_ensure_plm"):
		_host._ensure_plm()
	return _plm()
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

func _law_id_from_card(card: CardResource) -> String:
	if card == null or card.card_type != GC.CardType.LAW:
		return ""
	var lid: String = card.linked_law_id if not String(card.linked_law_id).is_empty() else card.card_id
	if lid.begins_with("law:"):
		lid = lid.substr(4)
	if PhaseLaws.get_by_id(lid).is_empty():
		return ""
	return lid

func _has_any_law_card_in_slots() -> bool:
	var slots: Dictionary = _instrument_slots()
	for color in ["red", "blue"]:
		for c_raw in slots.get(color, []):
			var c: CardResource = c_raw
			if c != null and c.card_type == GC.CardType.LAW:
				return true
	return false

func _compact_law_ids_from_slots_hypothetical(color: String, color_index: int, new_card: CardResource) -> Dictionary:
	var reds: Array = (_instrument_slots().get("red", []) as Array).duplicate()
	var blues: Array = (_instrument_slots().get("blue", []) as Array).duplicate()
	if color == "red" and color_index >= 0 and color_index < reds.size():
		reds[color_index] = new_card
	elif color == "blue" and color_index >= 0 and color_index < blues.size():
		blues[color_index] = new_card
	return {
		"actives": _compact_law_ids_for_kind(reds, "active"),
		"passives": _compact_law_ids_for_kind(blues, "passive"),
	}

func _compact_law_ids_for_kind(slot_arr: Array, expected_kind: String) -> Array:
	var out: Array = []
	for c_raw in slot_arr:
		var c: CardResource = c_raw
		if c == null:
			continue
		var lid: String = _law_id_from_card(c)
		if lid.is_empty():
			continue
		var law: Dictionary = PhaseLaws.get_by_id(lid)
		if law.is_empty() or String(law.get("kind", "")) != expected_kind:
			continue
		if not out.has(lid):
			out.append(lid)
	return out

func _compact_law_ids_from_current_slots() -> Dictionary:
	return {
		"actives": _compact_law_ids_for_kind(_instrument_slots().get("red", []), "active"),
		"passives": _compact_law_ids_for_kind(_instrument_slots().get("blue", []), "passive"),
	}

func _apply_law_slots_to_plm() -> bool:
	_ensure_plm()
	var plm: Node = _plm()
	if not plm or not plm.has_method("set_equipped_laws"):
		return false
	if not plm.is_inside_tree():
		return false
	var pack: Dictionary = _compact_law_ids_from_current_slots()
	for pid in pack["passives"]:
		if plm.has_method("ensure_law_unlocked"):
			plm.ensure_law_unlocked(String(pid))
	for aid in pack["actives"]:
		if plm.has_method("ensure_law_unlocked"):
			plm.ensure_law_unlocked(String(aid))
	var budget: int = int(plm.battle_nano_budget) if "battle_nano_budget" in plm else 0
	var ok: bool = plm.set_equipped_laws(pack["passives"], pack["actives"], budget)
	if not ok and plm.has_method("force_sync_instrument_law_slots"):
		plm.force_sync_instrument_law_slots(pack["passives"], pack["actives"])
		return true
	return ok

## 开战前调用：以红/蓝槽内法则卡为准，刷新 PhaseLawManager 的装配
func sync_law_cards_to_phase_law_manager() -> bool:
	return _apply_law_slots_to_plm()

## 旧存档：槽位无法则卡但 PhaseLawManager 仍有装配时，生成槽内卡并同步
func migrate_law_slots_from_phase_law_manager_if_empty() -> void:
	if _has_any_law_card_in_slots():
		return
	var actives: Array = []
	var passives: Array = []
	_ensure_plm()
	var plm: Node = _plm()
	if plm and "equipped_active_laws" in plm:
		actives = plm.equipped_active_laws
	if plm and "equipped_passive_laws" in plm:
		passives = plm.equipped_passive_laws
	if actives.is_empty() and passives.is_empty():
		return
	var slots: Dictionary = _instrument_slots()
	var reds: Array = slots.get("red", [])
	var blues: Array = slots.get("blue", [])
	var changed: bool = false
	for i in range(reds.size()):
		if i >= actives.size():
			break
		var lid: String = String(actives[i])
		if lid.is_empty():
			continue
		var tmpl: CardResource = DefaultCards.create_law_card_resource(lid)
		if tmpl != null:
			reds[i] = tmpl.clone()
			changed = true
	for i in range(blues.size()):
		if i >= passives.size():
			break
		var lid2: String = String(passives[i])
		if lid2.is_empty():
			continue
		var tmpl2: CardResource = DefaultCards.create_law_card_resource(lid2)
		if tmpl2 != null:
			blues[i] = tmpl2.clone()
			changed = true
	if changed:
		slots["red"] = reds
		slots["blue"] = blues
		_host.instrument_slots = slots
		_apply_law_slots_to_plm()
		_emit_slots_changed()

## 读档后：若槽内已有法则卡，用槽位覆盖 PhaseLawManager 装配列表
func sync_law_slots_to_plm_if_has_law_cards() -> void:
	if _has_any_law_card_in_slots():
		_apply_law_slots_to_plm()

## ── 装备卡牌到槽位 ──
func equip_card(slot_index: int, card: CardResource, _energy_manager: Node = null, _recursion_depth: int = 0) -> bool:
	var _equip_t0: int = Time.get_ticks_msec()
	var loc: Dictionary = _host._flat_index_to_slot(slot_index) if _host and _host.has_method("_flat_index_to_slot") else {}
	var color: String = String(loc.get("color", ""))
	var color_index: int = int(loc.get("index", -1))
	if color.is_empty() or color_index < 0 or card == null:
		return false
	if not _can_equip_card_to_color(card, color):
		# 法则卡自动路由
		if card.card_type == GC.CardType.LAW and (color == "red" or color == "blue"):
			var alt_color: String = "red" if color == "blue" else "blue"
			if _can_equip_card_to_color(card, alt_color):
				var alt_arr: Array = _instrument_slots().get(alt_color, [])
				for ai in range(alt_arr.size()):
					if alt_arr[ai] == null:
						var alt_flat: int = _host._slot_to_flat_index(alt_color, ai) if _host and _host.has_method("_slot_to_flat_index") else -1
						if alt_flat >= 0 and _recursion_depth < MAX_EQUIP_RECURSION:
							return equip_card(alt_flat, card, _energy_manager, _recursion_depth + 1)
						break
		return false

	if color == "red" or color == "blue":
		_ensure_plm()
		var plm: Node = _plm()
		if not plm or not plm.has_method("set_equipped_laws"):
			return false
		var hyp: Dictionary = _compact_law_ids_from_slots_hypothetical(color, color_index, card)
		for pid in hyp["passives"]:
			if plm.has_method("ensure_law_unlocked"):
				plm.ensure_law_unlocked(String(pid))
		for aid in hyp["actives"]:
			if plm.has_method("ensure_law_unlocked"):
				plm.ensure_law_unlocked(String(aid))
		var budget: int = int(plm.battle_nano_budget) if "battle_nano_budget" in plm else 0
		if not plm.set_equipped_laws(hyp["passives"], hyp["actives"], budget):
			if plm.has_method("force_sync_instrument_law_slots"):
				plm.force_sync_instrument_law_slots(hyp["passives"], hyp["actives"])
			else:
				# [LOG-v5.1] print("[PhaseInstrumentLoadoutSync] 法则槽装配未通过: ", card.display_name)
				pass
				return false

	if DEBUG_EQUIP_LOG:
		pass  # [LOG-v5.1] print("[PhaseInstrumentLoadoutSync] 装备卡牌 %s 到槽位 %s (颜色: %s)" % [card.display_name, slot_index, color])

	var slots: Dictionary = _instrument_slots()
	var arr: Array = slots.get(color, [])
	var old_card: CardResource = arr[color_index]
	arr[color_index] = card
	slots[color] = arr
	_host.instrument_slots = slots

	if old_card != null:
		SignalBus.card_added_to_backpack.emit(old_card)
	_emit_slots_changed()
	SignalBus.card_equipped.emit(slot_index, card.card_id, _card_type_name(card))
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
	if color == "red" or color == "blue":
		_apply_law_slots_to_plm()
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
	_apply_law_slots_to_plm()
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
	if color == "yellow":
		return card.card_type == GC.CardType.ENERGY
	if color == "red" or color == "blue":
		if card.card_type != GC.CardType.LAW:
			return false
		var lid: String = _law_id_from_card(card)
		if lid.is_empty():
			return false
		var law: Dictionary = PhaseLaws.get_by_id(lid)
		if law.is_empty():
			return false
		var kind: String = String(law.get("kind", ""))
		if color == "red":
			return kind == "active"
		return kind == "passive"
	return false
