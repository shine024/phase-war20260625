class_name InstrumentBarDrag
extends RefCounted
## 底部相位仪栏 - 槽位拖放系统（从 bottom_instrument_bar.gd 拆分）
## 负责：拖放验证、执行、坐标转换、卸下

const GC = preload("res://resources/game_constants.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")

## 宿主引用（由 bottom_instrument_bar 在 _ready 设置）
var _host: Node = null  # BottomInstrumentBar

func setup(host: Node) -> void:
	_host = host

## ── 虚方法回调（由宿主连接到 PanelContainer 的 _can_drop_data / _drop_data） ──

## 验证拖放数据是否可以接受
func can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var target: Dictionary = get_slot_entry_by_local_pos(at_position)
	if target.is_empty():
		return false
	var color: String = String(target.get("color", ""))
	# v6.2: rune 槽位接受符文拖放（data 中含 rune_id 字符串）
	if color == "rune":
		var rune_id: String = String(data.get("rune_id", ""))
		if rune_id.is_empty():
			return false
		if PhaseInstrumentManager and PhaseInstrumentManager.has_method("has_rune"):
			return PhaseInstrumentManager.has_rune(rune_id)
		return false
	# 卡牌槽位校验
	if not (data.get("card") is CardResource):
		return false
	var card: CardResource = data.get("card")
	if color == "green":
		return card.card_type == GC.CardType.COMBAT_UNIT
	if color == "yellow":
		return card.card_type == GC.CardType.ENERGY
	if color == "red" or color == "blue":
		if card.card_type != GC.CardType.LAW:
			return false
		var lid: String = card.linked_law_id if not String(card.linked_law_id).is_empty() else card.card_id
		if lid.begins_with("law:"):
			lid = lid.substr(4)
		var law: Dictionary = PhaseLaws.get_by_id(lid)
		if law.is_empty():
			return false
		var kind: String = String(law.get("kind", ""))
		return (color == "red" and kind == "active") or (color == "blue" and kind == "passive")
	return false

## 执行拖放
func drop_data(at_position: Vector2, data: Variant) -> void:
	if not can_drop_data(at_position, data):
		return
	var target: Dictionary = get_slot_entry_by_local_pos(at_position)
	if target.is_empty():
		return
	var color: String = String(target.get("color", ""))
	var color_index: int = int(target.get("index", -1))
	# v6.2: rune 槽位走 equip_rune
	if color == "rune":
		var rune_id: String = String(data.get("rune_id", ""))
		if not rune_id.is_empty() and PhaseInstrumentManager and PhaseInstrumentManager.has_method("equip_rune"):
			PhaseInstrumentManager.equip_rune(color_index, rune_id)
		return
	# 卡牌槽位走 equip_card
	var card: CardResource = data.get("card")
	var flat_index: int = slot_to_flat_index(color, color_index)
	if flat_index < 0:
		return
	if PhaseInstrumentManager and EnergyManager and PhaseInstrumentManager.has_method("equip_card"):
		PhaseInstrumentManager.equip_card(flat_index, card, EnergyManager)

## 通过局部坐标定位槽位
func get_slot_entry_by_local_pos(at_position: Vector2) -> Dictionary:
	if not _host or not is_instance_valid(_host):
		return {}
	var global_pos: Vector2 = _host.get_global_transform() * at_position
	var slot_panels: Array = _host._slot_panels if "_slot_panels" in _host else []
	for p in slot_panels:
		if p == null or not is_instance_valid(p):
			continue
		var rect: Rect2 = (p as Control).get_global_rect()
		if rect.has_point(global_pos):
			return {
				"color": String(p.get_meta("slot_color", "")),
				"index": int(p.get_meta("slot_index", -1))
			}
	return {}

## 颜色+颜色内索引 → 扁平索引
func slot_to_flat_index(color: String, color_index: int) -> int:
	if color_index < 0:
		return -1
	if not PhaseInstrumentManager or not PhaseInstrumentManager.has_method("get_current_instrument"):
		return -1
	var cfg: Dictionary = PhaseInstrumentManager.get_current_instrument()
	var slot_counts: Dictionary = cfg.get("slot_counts", {})
	var red_count = int(slot_counts.get("red", 0))
	var blue_count = int(slot_counts.get("blue", 0))
	var green_count = int(slot_counts.get("green", 0))
	var yellow_count = int(slot_counts.get("yellow", 0))
	# 槽位顺序：红→蓝→绿→黄→符文
	match color:
		"red":
			return color_index
		"blue":
			return red_count + color_index
		"green":
			return red_count + blue_count + color_index
		"yellow":
			return red_count + blue_count + green_count + color_index
		"rune":
			return red_count + blue_count + green_count + yellow_count + color_index
		_:
			return -1

## 尝试卸下槽位卡牌（右键 / Shift+左键）
func try_unequip_card_slot(color: String, color_index: int) -> bool:
	if color_index < 0:
		return false
	var in_battle: bool = BattleManager != null and "battle_active" in BattleManager and BattleManager.battle_active
	if in_battle:
		return false
	if PhaseInstrumentManager == null:
		return false
	# v6.2: rune 槽位走 unequip_rune
	if color == "rune":
		if PhaseInstrumentManager.has_method("unequip_rune"):
			PhaseInstrumentManager.unequip_rune(color_index)
			return true
		return false
	var flat_index: int = slot_to_flat_index(color, color_index)
	if flat_index < 0:
		return false
	if PhaseInstrumentManager.has_method("unequip_card"):
		PhaseInstrumentManager.unequip_card(flat_index)
		return true
	return false
