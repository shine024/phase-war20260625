class_name InstrumentBarDrag
extends RefCounted
## 底部相位仪栏 - 槽位拖放系统（从 bottom_instrument_bar.gd 拆分）
## 负责：槽位兼容性校验（供背包手动拖拽复用）、坐标转换、卸下
## 2026-08-22 D3：删除原生 DnD 死链路（can_drop_data/drop_data/get_slot_entry_by_local_pos）——
## 全项目无任何 _get_drag_data 实现（原生拖拽源），这些回调永远不会触发；
## 实际拖放走 backpack_card_item_drag 的手动拖拽系统。

const GC = preload("res://resources/game_constants.gd")

## 宿主引用（由 bottom_instrument_bar 在 _ready 设置）
var _host: Node = null  # BottomInstrumentBar

func setup(host: Node) -> void:
	_host = host


## 卡牌与槽位颜色兼容性校验（静态公共，供背包手动拖拽的悬停反馈/落点判定复用）
## 2026-08-22 抽取——背包拖拽需要"松手前"就知道能否放置（绿框/红框）
static func card_matches_slot_color(card: CardResource, color: String) -> bool:
	if card == null or color.is_empty():
		return false
	if color == "rune":
		return false  # 符文槽只收符文拖放，卡牌一律不可放
	if color == "green":
		return card.card_type == GC.CardType.COMBAT_UNIT
	if color == "yellow":
		return card.card_type == GC.CardType.ENERGY
	if color == "red" or color == "blue":
		# v9.x（P2-7范围A）：法则卡槽位链路退役——红/蓝槽不再接受卡牌拖放（2b 随蓝槽法则链整体清理）
		return false
	return false

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
