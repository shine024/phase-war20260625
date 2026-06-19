extends HBoxContainer
## 相位仪面板：按当前相位仪配置动态槽位，响应装备/卸下

const PhaseSlotScenePath = "res://scenes/ui/phase_slot.tscn"
const PhaseSlotScene = preload("res://scenes/ui/phase_slot.tscn")
const DT = preload("res://resources/design_tokens.gd")
const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const RankDisplayUi = preload("res://scripts/rank_display_ui.gd")
const NodeFinder = preload("res://scripts/node_finder.gd")
const BackpackCombatPreview = preload("res://scenes/ui/backpack_combat_preview.gd")
const CardInfoPanel = preload("res://scenes/ui/card_info_panel.gd")
const DEBUG_PHASE_PANEL_LOG := false

var slots: Array = []
var _phase_level_label: Label = null
var _slots_refresh_pending: bool = false
var _pending_slots_data: Array = []
var rune_slot_count_cache: int = 0  # v6.2: 符文槽位数（用于显示提示）

func _dbg_agent(hypothesis_id: String, message: String, data: Dictionary) -> void:
	var DebugLog = get_node_or_null("/root/DebugLog")
	if DebugLog:
		DebugLog.agent_log("phase_instrument_panel.gd", message, data, hypothesis_id, "95dad8")

func _ready() -> void:
	add_to_group("phase_instrument_panel")
	_sync_height_to_slot()
	_apply_design_tokens()
	_ensure_phase_level_label()
	_rebuild_slots()
	if SignalBus:
		SignalBus.phase_slots_changed.connect(_on_slots_changed)
		if SignalBus.has_signal("battle_ended"):
			SignalBus.battle_ended.connect(_on_battle_ended)
	# 同步当前状态
	if PhaseInstrumentManager:
		_on_slots_changed(PhaseInstrumentManager.get_slots())
		_refresh_phase_level_label()

func _sync_height_to_slot() -> void:
	# 让相位仪条高度始终跟随相位仪格子高度，避免面板写死导致错位
	custom_minimum_size.y = float(PhaseSlot.SLOT_SIZE.y)

func _rebuild_slots() -> void:
	for s in slots:
		if s and is_instance_valid(s):
			s.queue_free()
	slots.clear()

	var red_n: int = 0
	var blue_n: int = 0
	var green_n: int = 0
	var yellow_n: int = 0
	var _pim_rb = PhaseInstrumentManager
	if _pim_rb:
		var ins: Dictionary = _pim_rb.get_current_instrument()
		if not ins.is_empty():
			var sc: Dictionary = ins.get("slot_counts", {})
			red_n = int(sc.get("red", 0))
			blue_n = int(sc.get("blue", 0))
			green_n = int(sc.get("green", 0))
			yellow_n = int(sc.get("yellow", 0))
			# v6.2: rune 槽位由独立的 rune_panel 管理，不在此面板创建 PhaseSlot
			# 但在 phase_level 标签中显示总槽位数
			rune_slot_count_cache = int(sc.get("rune", 0))

	var total_slots: int = green_n + yellow_n  # v6.2: 仅卡牌槽位（战斗卡+能量卡）
	for i in range(total_slots):
		var slot = PhaseSlotScene.instantiate()
		slot.call_deferred("set", "slot_index", i)
		var sig_drop = slot.get("slot_drop_requested")
		if sig_drop:
			sig_drop.connect(_on_slot_drop)
		var sig_click = slot.get("slot_clicked")
		if sig_click:
			sig_click.connect(_on_slot_clicked)
		add_child(slot)
		slots.append(slot)

func _apply_design_tokens(high_contrast: bool = DT.HIGH_CONTRAST_ENABLED) -> void:
	add_theme_constant_override("separation", DT.PADDING_MEDIUM)

func _ensure_phase_level_label() -> void:
	if _phase_level_label != null:
		return
	var parent_box: Node = get_parent()
	if parent_box == null or not (parent_box is VBoxContainer):
		_dbg_agent("H_parent", "_ensure_phase_level_label skip no vbox parent", {"parent": str(parent_box)})
		return
	_phase_level_label = Label.new()
	_phase_level_label.name = "PhaseLevelLabel"
	_phase_level_label.text = "相位场 Lv.1  进度 0/0"
	_phase_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_level_label.add_theme_font_size_override("font_size", 12)
	_phase_level_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0, 0.95))
	# 父节点若在场景树构建中，同步 add_child 会失败；顺延到空闲帧
	var idx: int = get_index()
	_dbg_agent("H_busy_parent", "defer add_child phase label", {"parent": str(parent_box.name), "insert_index": idx})
	parent_box.call_deferred("add_child", _phase_level_label)
	parent_box.call_deferred("move_child", _phase_level_label, idx)

func _refresh_phase_level_label() -> void:
	var _pim_pl = PhaseInstrumentManager
	if _phase_level_label == null or not is_instance_valid(_phase_level_label) or _pim_pl == null:
		return
	if not _pim_pl.has_method("get_phase_field_xp_progress"):
		return
	var prog: Dictionary = _pim_pl.get_phase_field_xp_progress()
	var lv: int = int(prog.get("level", 1))
	var cur_xp: int = int(prog.get("cur_xp", 0))
	var next_xp: int = int(prog.get("next_xp", 0))
	if next_xp <= 0:
		_phase_level_label.text = "相位场 Lv.%d  MAX" % lv
	else:
		_phase_level_label.text = "相位场 Lv.%d  进度 %d/%d" % [lv, cur_xp, next_xp]

func _on_battle_ended(_player_won: bool) -> void:
	_refresh_phase_level_label()

func _on_slots_changed(_slots_data: Array) -> void:
	_pending_slots_data = _slots_data
	if _slots_refresh_pending:
		return
	_slots_refresh_pending = true
	call_deferred("_flush_slots_changed")

func _flush_slots_changed() -> void:
	if not _slots_refresh_pending:
		return
	_slots_refresh_pending = false
	var _pim_sc = PhaseInstrumentManager
	if not _pim_sc:
		return
	var ins: Dictionary = _pim_sc.get_current_instrument()
	var red_count: int = 0
	var blue_count: int = 0
	var green_count: int = 0
	var yellow_count: int = 0
	if not ins.is_empty():
		var slot_counts: Dictionary = ins.get("slot_counts", {})
		red_count = int(slot_counts.get("red", 0))
		blue_count = int(slot_counts.get("blue", 0))
		green_count = int(slot_counts.get("green", 0))
		yellow_count = int(slot_counts.get("yellow", 0))
	# v6.2 修复 H3：expected_size 只计 green+yellow（与本面板 _rebuild_slots 的 green_n+yellow_n 一致），
	# 原含 red+blue 会导致每次刷新都重建（因 slots.size()==green+yellow < expected_size）
	var expected_size: int = green_count + yellow_count
	if slots.size() != expected_size:
		_rebuild_slots()

	_refresh_phase_level_label()

	var all_slots: Array = _pending_slots_data if not _pending_slots_data.is_empty() else _pim_sc.get_slots()
	# v6.2 修复 B11：all_slots 顺序为 red,blue,green,yellow,rune，本面板只渲染 green+yellow，
	# 需用偏移跳过 red+blue，否则卡牌会映射到错误槽位
	var offset: int = red_count + blue_count
	for i in range(min(slots.size(), max(0, all_slots.size() - offset))):
		var src_idx: int = i + offset
		if src_idx >= all_slots.size():
			break
		var slot_card: CardResource = all_slots[src_idx] as CardResource if all_slots[src_idx] else null
		var slot_node: Node = slots[i]
		if slot_node != null and slot_node.has_method("set_card"):
			slot_node.set_card(slot_card)
		elif slot_node != null:
			slot_node.set("current_card", slot_card)

	var loadouts: Array = []
	if _pim_sc.has_method("get_loadouts"):
		loadouts = _pim_sc.get_loadouts()

	var slot_weight: Dictionary = {}
	for ld in loadouts:
		if not (ld is Dictionary):
			continue
		var platform_card: CardResource = ld.get("platform", null)
		var used_weight: int = int(ld.get("used_weight", 0))
		var capacity: int = int(ld.get("capacity", 0))
		if platform_card == null:
			continue
		var green_start: int = red_count + blue_count
		for j in range(green_count):
			var flat_i: int = green_start + j
			var c: CardResource = all_slots[flat_i] if flat_i < all_slots.size() else null
			if c != null and c == platform_card:
				slot_weight[flat_i] = {"used": used_weight, "capacity": capacity}
				break

	var green_start2: int = red_count + blue_count
	for j2 in range(green_count):
		var si: int = green_start2 + j2
		if si >= slots.size():
			break
		var info2: Dictionary = slot_weight.get(si, {})
		slots[si].set("used_weight", int(info2.get("used", 0)))
		slots[si].set("weight_capacity", int(info2.get("capacity", 0)))
		if slots[si].has_method("refresh_display"):
			slots[si].refresh_display()

	for k in range(all_slots.size()):
		if k >= green_start2 and k < green_start2 + green_count:
			continue
		if k < slots.size():
			slots[k].set("used_weight", 0)
			slots[k].set("weight_capacity", 0)
	_pending_slots_data = []

func _on_slot_drop(slot_index: int, card: CardResource) -> void:
	if PhaseInstrumentManager:
		var ok: bool = PhaseInstrumentManager.equip_card(slot_index, card, null)
		if DEBUG_PHASE_PANEL_LOG:
			pass
			# [LOG-v5.1] print("[PhaseInstrumentPanel] 装备卡牌 %s 到槽位 %d，结果: %s" % [card.display_name, slot_index, "成功" if ok else "失败"])

## 处理相位仪槽位点击：左键查看详情，右键卸下
func _on_slot_clicked(slot_index: int, mouse_button_index: int) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		return
	var slot = slots[slot_index]
	if slot == null:
		return
	var card = slot.get("current_card")
	if card == null:
		return
	# 右键点击卸下卡牌
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		_on_slot_unequip_requested(slot_index)
	else:
		# 左键点击查看详情（使用背包的详情弹窗）
		_show_slot_card_detail(card)

## 卸下相位仪槽位中的卡牌
func _on_slot_unequip_requested(slot_index: int) -> void:
	if PhaseInstrumentManager and slot_index >= 0:
		PhaseInstrumentManager.unequip_card(slot_index)

## 显示相位仪槽位中卡牌的详情
func _show_slot_card_detail(card: CardResource) -> void:
	if card == null:
		return
	# 先隐藏背包的 CardDetailPopup（防止与全局面板同时显示）
	var backpack_panel = NodeFinder.get_backpack_panel()
	if backpack_panel and backpack_panel.has_method("hide_card_detail"):
		backpack_panel.hide_card_detail()
	# 使用全局 CardInfoPanel（挂在 InfoPanelLayer layer=90，不被 HUD 遮挡）
	var info_panel: Control = NodeFinder.get_card_info_panel() as Control
	if info_panel == null:
		return
	if info_panel.has_method("set_panel_mode"):
		info_panel.set_panel_mode(CardInfoPanel.PanelMode.MODE_PHASE_INSTRUMENT)
	# 连接 action_requested 信号（仅连接一次）
	if info_panel.has_signal("action_requested") and not info_panel.action_requested.is_connected(_on_phase_panel_action):
		info_panel.action_requested.connect(_on_phase_panel_action)
	if info_panel.has_method("show_card_info"):
		var mouse_pos: Vector2 = get_global_mouse_position()
		var show_pos: Vector2 = mouse_pos if mouse_pos != Vector2.ZERO else Vector2(480, 100)
		info_panel.show_card_info(card, show_pos)

func _on_phase_panel_action(action: String, card: CardResource) -> void:
	match action:
		"unequip":
			var slot_idx: int = _find_slot_index_by_card(card)
			if slot_idx >= 0:
				PhaseInstrumentManager.unequip_card(slot_idx)


## 根据卡牌查找槽位索引
func _find_slot_index_by_card(card: CardResource) -> int:
	for i in range(slots.size()):
		if slots[i] != null:
			var slot_card = slots[i].get("current_card")
			if slot_card != null and slot_card.card_id == card.card_id:
				return i
	return -1
