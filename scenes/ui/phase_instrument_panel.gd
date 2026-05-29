extends HBoxContainer
## 相位仪面板：按当前相位仪配置动态槽位，响应装备/卸下

const PhaseSlotScenePath = "res://scenes/ui/phase_slot.tscn"
const PhaseSlotScene = preload("res://scenes/ui/phase_slot.tscn")
const DT = preload("res://resources/design_tokens.gd")
const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const RankDisplayUi = preload("res://scripts/rank_display_ui.gd")
const NodeFinder = preload("res://scripts/node_finder.gd")
const BackpackPanelScript = preload("res://scenes/ui/backpack_panel.gd")
const BackpackCombatPreview = preload("res://scenes/ui/backpack_combat_preview.gd")
const DEBUG_PHASE_PANEL_LOG := false

var slots: Array = []
var _phase_level_label: Label = null
var _slots_refresh_pending: bool = false
var _pending_slots_data: Array = []

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

	var total_slots: int = red_n + blue_n + green_n + yellow_n
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
	var expected_size: int = red_count + blue_count + green_count + yellow_count
	if slots.size() != expected_size:
		_rebuild_slots()

	_refresh_phase_level_label()

	var all_slots: Array = _pending_slots_data if not _pending_slots_data.is_empty() else _pim_sc.get_slots()
	for i in range(min(slots.size(), all_slots.size())):
		var slot_card: CardResource = all_slots[i] as CardResource if all_slots[i] else null
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
			print("[PhaseInstrumentPanel] 装备卡牌 %s 到槽位 %d，结果: %s" % [card.display_name, slot_index, "成功" if ok else "失败"])

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
	BackpackPanelScript.open_card_detail(card, null)
	if NodeFinder.get_backpack_panel() != null:
		return
	_show_detail_popup_for_card(card)

## 直接显示卡牌详情弹窗
func _show_detail_popup_for_card(card: CardResource) -> void:
	if BlueprintManager == null:
		return
	
	# 创建临时弹窗
	var popup = Window.new()
	popup.title = card.display_name
	popup.size = Vector2i(360, min(560, int(get_viewport_rect().size.y * 0.72)))
	popup.transient = true
	# exclusive 易导致标题栏关闭与输入焦点异常；用 unexclusive + close_requested 统一释放
	popup.exclusive = false
	popup.close_requested.connect(func():
		_dbg_agent("H_window_close", "close_requested queue_free", {"card_id": card.card_id})
		if is_instance_valid(popup):
			popup.call_deferred("queue_free")
	)
	get_tree().root.add_child(popup)
	_dbg_agent("H_popup_open", "detail Window shown", {"card_id": card.card_id, "exclusive": false})
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	popup.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 5)
	scroll.add_child(vbox)
	
	# 卡牌名称和类型
	var name_label = Label.new()
	name_label.text = "[%s] %s" % [card.rarity, card.display_name]
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)
	
	var type_label = Label.new()
	type_label.text = card.type_line
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1.0))
	vbox.add_child(type_label)
	
	var rank_host := HBoxContainer.new()
	rank_host.alignment = BoxContainer.ALIGNMENT_BEGIN
	var rank_info: Dictionary = RankDisplayUi.resolve_from_card_resource(card)
	RankDisplayUi.apply_to_host(rank_host, rank_info, 22)
	if not rank_info.is_empty():
		var rn: Label = rank_host.get_node_or_null("RankName") as Label
		if rn:
			var power: float = float(rank_info.get("power_score", 0.0))
			if power > 0.0:
				rn.text = "%s（战力 %.0f）" % [str(rank_info.get("rank_name", "")), power]
			rn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45, 1))
		vbox.add_child(rank_host)
	
	# 经验等级
	var prog = BlueprintManager.get_card_xp_progress(card.card_id)
	var lvl = int(prog.get("level", 1))
	var bt = BlueprintManager.get_card_breakthroughs(card.card_id)
	var level_text = "Lv.%d" % lvl
	if bt > 0:
		level_text += " (突破 %d)" % bt
	var level_label = Label.new()
	level_label.text = level_text
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
	vbox.add_child(level_label)
	
	# 能量消耗
	var cost_label = Label.new()
	cost_label.text = "能量消耗: %d⚡" % int(card.energy_cost)
	cost_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(cost_label)
	
	# 摘要（优先使用战前预览的缩放值）
	var summary_label = Label.new()
	var combat_line: String = BackpackCombatPreview.build_line(card)
	summary_label.text = combat_line if not combat_line.is_empty() else card.summary_line
	summary_label.add_theme_font_size_override("font_size", 11)
	summary_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 0.9))
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(summary_label)
	
	# 描述
	var desc_label = Label.new()
	desc_label.text = card.description
	if BlueprintManager and BlueprintManager.has_method("get_star_enhancement_lines"):
		var star_now: int = BlueprintManager.get_blueprint_star(card.card_id)
		var enhance_lines: Array[String] = BlueprintManager.get_star_enhancement_lines(card.card_id, star_now)
		if not enhance_lines.is_empty():
			desc_label.text += "\n\n【星级强化（★%d）】\n- %s" % [star_now, "\n- ".join(enhance_lines)]
		elif star_now >= 1:
			desc_label.text += "\n\n【星级强化（★%d）】\n- （暂无词条说明）" % star_now
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85, 0.85))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)
	
	# 卸下按钮
	var unequip_btn = Button.new()
	unequip_btn.text = "卸下此卡"
	unequip_btn.pressed.connect(func():
		_dbg_agent("H_btn", "unequip pressed", {"card_id": card.card_id})
		_on_slot_unequip_requested(_find_slot_index_by_card(card))
		if is_instance_valid(popup):
			popup.call_deferred("queue_free")
	)
	vbox.add_child(unequip_btn)
	
	# 关闭按钮
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(func():
		_dbg_agent("H_btn", "close pressed", {"card_id": card.card_id})
		if is_instance_valid(popup):
			popup.call_deferred("queue_free")
	)
	vbox.add_child(close_btn)
	
	# 弹出窗口
	popup.popup_centered()

## 根据卡牌查找槽位索引
func _find_slot_index_by_card(card: CardResource) -> int:
	for i in range(slots.size()):
		if slots[i] != null:
			var slot_card = slots[i].get("current_card")
			if slot_card != null and slot_card.card_id == card.card_id:
				return i
	return -1
