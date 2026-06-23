extends PanelContainer
## 底部常驻栏：统一从相位仪槽数据渲染（绿/红/蓝/黄）

const GC = preload("res://resources/game_constants.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const PhaseInstruments = preload("res://data/phase_instruments.gd")
const DefaultCardsData = preload("res://data/default_cards.gd")
const NodeFinder = preload("res://scripts/node_finder.gd")
const CardInfoPanel = preload("res://scenes/ui/card_info_panel.gd")
const BackpackCombatPreview = preload("res://scenes/ui/backpack_combat_preview.gd")
const RankDisplayUi = preload("res://scripts/rank_display_ui.gd")
const CardFrameUi = preload("res://scripts/card_frame_ui.gd")
const CardBackgroundUi = preload("res://scripts/card_background_ui.gd")
const DEBUG_BOTTOM_BAR_LOG := false
## ── 子系统：槽位拖放 ──
const DragSub = preload("res://scenes/ui/instrument_bar_drag.gd")
var _drag_system: InstrumentBarDrag = null

signal instrument_area_clicked
signal phase_level_label_clicked
## 战前点击任意法则格（无激活法则时）→ 打开法则管理面板
signal law_area_clicked
## 战斗中点击主动法则格 → 直接进入施放模式；参数：法则ID、"active"/"passive"
signal law_slot_clicked(law_id: String, kind: String, origin_global: Vector2)

var _slot_panels: Array = []
var _deployed_card_ids: Array = []
const SLOT_FIXED_SIZE := Vector2(68, 64)
const BAR_FIXED_HEIGHT := SLOT_FIXED_SIZE.y
## 槽底双行文字区高度（名称 + 费用），卡图只占上方区域避免遮挡
const _SLOT_BOTTOM_TEXT_H := 30
## 槽位 tooltip 过长会拖慢每次装备/刷新；限制长度
const _TOOLTIP_DESC_MAX := 140
const _TOOLTIP_ENHANCE_MAX := 24
## 合并同帧内多次 phase_slots_changed，只刷新一次 UI
var _slots_refresh_coalesce: bool = false

@onready var instrument_section: HBoxContainer = $Margin/HBox/InstrumentSection
@onready var instrument_icon: TextureRect = $Margin/HBox/InstrumentSection/InstrumentIcon
@onready var name_section: VBoxContainer = $Margin/HBox/InstrumentSection/NameSection
@onready var phase_level_label: Label = $Margin/HBox/InstrumentSection/NameSection/PhaseLevelLabel
@onready var instrument_stats_label: Label = $Margin/HBox/InstrumentSection/NameSection/InstrumentStatsLabel
@onready var slot_section: HBoxContainer = $Margin/HBox/InstrumentSection/SlotSection
var _phase_level_label_container: Control = null

func _ready() -> void:
	_drag_system = DragSub.new()
	_drag_system.setup(self)
	custom_minimum_size.y = BAR_FIXED_HEIGHT
	size.y = BAR_FIXED_HEIGHT
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_update_name_section_width()
	_connect_signals()
	_make_phase_level_label_clickable()
	_refresh_all()
	# 布局完成后，让格子高度精确填满条的可用空间
	call_deferred("_fit_slots_to_bar")

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_name_section_width()
		_fit_slots_to_bar()

func _connect_signals() -> void:
	if SignalBus:
		if SignalBus.has_signal("phase_slots_changed"):
			SignalBus.phase_slots_changed.connect(_on_slots_changed)
		if SignalBus.has_signal("battle_ended"):
			SignalBus.battle_ended.connect(_on_battle_ended)
		if SignalBus.has_signal("unit_spawned"):
			SignalBus.unit_spawned.connect(_on_unit_spawned)
		if SignalBus.has_signal("unit_died"):
			SignalBus.unit_died.connect(_on_unit_died)

func _on_battle_ended(_won: bool) -> void:
	_deployed_card_ids.clear()
	_refresh_slot_layout()
	_refresh_phase_level()

func _on_unit_spawned(unit: Node, is_player: bool) -> void:
	if not is_player:
		return
	if unit == null or not is_instance_valid(unit):
		return
	var card_id = unit.get_meta("source_card_id", "")
	if not card_id.is_empty() and not card_id in _deployed_card_ids:
		_deployed_card_ids.append(card_id)
		_refresh_slot_indicators()

func _on_unit_died(unit: Node, is_player: bool) -> void:
	if not is_player:
		return
	if unit == null or not is_instance_valid(unit):
		return
	var card_id = unit.get_meta("source_card_id", "")
	if not card_id.is_empty() and card_id in _deployed_card_ids:
		_deployed_card_ids.erase(card_id)
		_refresh_slot_indicators()

func _refresh_slot_indicators() -> void:
	if not is_instance_valid(self):
		return
	for panel in _slot_panels:
		if panel == null or not is_instance_valid(panel):
			continue
		var card_id = panel.get_meta("card_id", "")
		if card_id.is_empty():
			continue
		var indicator = panel.get_node_or_null("DeployIndicator")
		if indicator != null and is_instance_valid(indicator):
			indicator.visible = card_id in _deployed_card_ids

## 刷新全部显示
func _refresh_all() -> void:
	_refresh_slot_layout()
	_refresh_phase_level()


func _format_card_slot_tooltip(color: String, card: CardResource) -> String:
	if card == null:
		return ""
	var display_name: String = "能量卡" if card.card_type == GC.CardType.ENERGY else DefaultCardsData.get_safe_display_name(card.card_id)
	var cost_text: String = "%d⚡" % int(card.energy_cost)
	var detail_lines: Array[String] = []
	detail_lines.append("%s 槽：%s" % [_slot_name(color), display_name])
	detail_lines.append("能量消耗：%s" % cost_text)
	if not String(card.type_line).is_empty():
		detail_lines.append("类型：%s" % String(card.type_line))
	if not String(card.summary_line).is_empty():
		detail_lines.append("摘要：%s" % String(card.summary_line))
	var desc := String(card.description)
	if desc.length() > _TOOLTIP_DESC_MAX:
		desc = desc.substr(0, _TOOLTIP_DESC_MAX) + "…"
	if not desc.is_empty():
		detail_lines.append("说明：%s" % desc)
	var rank_line: String = RankDisplayUi.format_line(RankDisplayUi.resolve_from_card_resource(card))
	if not rank_line.is_empty():
		detail_lines.append(rank_line)
	var combat_line: String = BackpackCombatPreview.build_line(card)
	if not combat_line.is_empty():
		detail_lines.append(combat_line)
	# v5.1: star_level system removed - skip star enhancement display
	return "\n".join(detail_lines)


func _on_slots_changed(_slots_data: Array) -> void:
	_slots_refresh_coalesce = true
	call_deferred("_flush_pending_slots_refresh")


func _flush_pending_slots_refresh() -> void:
	if not _slots_refresh_coalesce:
		return
	_slots_refresh_coalesce = false
	if not is_inside_tree():
		return
	_refresh_slot_layout()
	_refresh_phase_level()
	_refresh_slot_indicators()


func _refresh_slot_layout() -> void:
	if PhaseInstrumentManager == null:
		return
	var layout: Array = PhaseInstrumentManager.get_slot_layout() if PhaseInstrumentManager.has_method("get_slot_layout") else []
	# 槽位数量变化时全量重建
	if layout.size() != _slot_panels.size():
		_rebuild_all_slot_panels(layout)
		return
	# 数量相同：始终增量更新（gui_input 闭包通过 panel meta 读取当前状态，不依赖构建时捕获）
	for i in range(layout.size()):
		var entry: Dictionary = layout[i]
		_update_slot_panel(_slot_panels[i], entry)

func _rebuild_all_slot_panels(layout: Array) -> void:
	for old in _slot_panels:
		if old and is_instance_valid(old):
			old.queue_free()
	_slot_panels.clear()
	for i in range(layout.size()):
		var entry: Dictionary = layout[i]
		var panel := _build_slot_panel(entry)
		slot_section.add_child(panel)
		_slot_panels.append(panel)
	call_deferred("_fit_slots_to_bar")

## 增量更新单个格子的内容和样式（避免每次重建所有格子）
func _update_slot_panel(panel: Control, entry: Dictionary) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var color: String = String(entry.get("color", ""))
	# v6.2: rune 槽的 card 字段实际是 rune_id (String)，不能用 CardResource 类型注解，
	# 否则赋值时崩溃 "Trying to assign a non-object value to a variable of type 'card_resource.gd'"。
	# 用 Variant 承载，并在使用 card 属性前用 is CardResource 守卫。
	var card: Variant = entry.get("card", null)
	# 仅当确为 CardResource 时才视为有效卡（rune 槽的 String 不应走卡牌渲染分支）
	var has_card: bool = card != null and card is CardResource
	var law_id: String = String(entry.get("law_id", ""))
	var law_kind: String = String(entry.get("law_kind", ""))
	panel.set_meta("slot_color", color)
	panel.set_meta("card_id", card.card_id if has_card else "")
	panel.set_meta("card_type", int(card.card_type) if has_card else -1)
	panel.set_meta("law_id", law_id)
	panel.set_meta("law_kind", law_kind)
	# 更新样式
	var sb: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		sb.bg_color = _slot_bg(color)
		sb.border_color = _slot_border(color)
	if _slot_name_label(panel) == null:
		return
	# 处理 DeployIndicator：仅在战斗卡时存在
	var needs_indicator: bool = has_card and card.card_type == GC.CardType.COMBAT_UNIT
	var indicator: Polygon2D = panel.get_node_or_null("DeployIndicator") as Polygon2D
	if needs_indicator and indicator == null:
		indicator = Polygon2D.new()
		indicator.name = "DeployIndicator"
		indicator.polygon = PackedVector2Array([
			Vector2(-6, 0), Vector2(6, 0), Vector2(0, -10)
		])
		indicator.color = Color(0.2, 1.0, 0.3, 0.9)
		indicator.position = Vector2(SLOT_FIXED_SIZE.x * 0.5, -2)
		indicator.visible = String(panel.get_meta("card_id", "")) in _deployed_card_ids
		panel.add_child(indicator)
	elif not needs_indicator and indicator != null:
		indicator.queue_free()
	if has_card:
		_apply_slot_card_labels(panel, card)
		panel.tooltip_text = _format_card_slot_tooltip(color, card)
	elif not law_id.is_empty():
		var PhaseLaws_local = PhaseLaws
		var cfg: Dictionary = PhaseLaws_local.get_by_id(law_id) if PhaseLaws_local else {}
		var law_name: String = String(cfg.get("name", law_id))
		var battle_cost: Dictionary = cfg.get("battle_cost", {})
		var activate_cost: Dictionary = cfg.get("activate_cost", {})
		var battle_energy: int = int(battle_cost.get("energy", 0))
		var activate_nano: int = int(activate_cost.get("nano", 0))
		var cost_line: String = ""
		if battle_energy > 0:
			cost_line = "%d⚡" % battle_energy
		elif activate_nano > 0:
			cost_line = "纳米%d" % activate_nano
		var short_law_name: String = law_name
		if short_law_name.length() > 5:
			short_law_name = short_law_name.substr(0, 5)
		_apply_slot_bottom_text(
			panel,
			("⚔" if law_kind == "active" else "🛡") + short_law_name,
			cost_line
		)
		_sync_slot_icon(panel, card, law_id)
		_sync_slot_rank_badge(panel, card)
		_sync_slot_card_background(panel, card)
		_sync_slot_card_frame(panel, card)
		return
	# v6.2: 符文槽位显示
	var rune_id: String = String(entry.get("rune_id", ""))
	if color == "rune" and not rune_id.is_empty():
		var RuneDefs = preload("res://data/runes.gd")
		var rune_name: String = RuneDefs.get_rune_name(rune_id)
		var rune_def: Dictionary = RuneDefs.get_rune(rune_id)
		var rarity_name: String = RuneDefs.RARITY_NAMES.get(rune_def.get("rarity", ""), "")
		var short_name: String = rune_name
		if short_name.length() > 4:
			short_name = short_name.substr(0, 4)
		_apply_slot_bottom_text(panel, "◈" + short_name, rarity_name)
		panel.tooltip_text = "符文：%s（%s）\n%s" % [rune_name, rarity_name, RuneDefs.get_description(rune_id)]
		# v6.2: 符文专属图标贴图（参照 _sync_slot_icon 的尺寸算法）
		var rune_tr: TextureRect = _slot_icon_rect(panel)
		var rune_tex: Texture2D = UiAssetLoader.rune_icon(rune_id)
		var slot_h: float = panel.size.y if panel.size.y > 4.0 else float(SLOT_FIXED_SIZE.y)
		var art_h: float = maxf(18.0, slot_h - float(_SLOT_BOTTOM_TEXT_H) - 4.0)
		var art_w: float = SLOT_FIXED_SIZE.x - 6.0
		UiAssetLoader.setup_texrect_icon(rune_tr, rune_tex, Vector2(art_w, art_h))
		_sync_slot_card_background(panel, null)
		_sync_slot_card_frame(panel, null)
		return
	_apply_slot_bottom_text(panel, "空", "")
	panel.tooltip_text = "%s 槽（空）" % _slot_name(color)
	_sync_slot_icon(panel, card, law_id)
	_sync_slot_rank_badge(panel, card)
	_sync_slot_card_background(panel, card)
	_sync_slot_card_frame(panel, card)

## 让格子高度精确填满条的可用高度（抵消 PanelContainer content_margin 等开销）
func _fit_slots_to_bar() -> void:
	if not is_instance_valid(slot_section):
		return
	var available: float = slot_section.size.y
	if available < 1.0:
		return
	for p in _slot_panels:
		if p and is_instance_valid(p):
			p.custom_minimum_size.y = available
			p.size.y = available

func _update_name_section_width() -> void:
	if name_section == null or not is_instance_valid(name_section):
		return
	var viewport_width: float = get_viewport_rect().size.x
	if viewport_width <= 1.0:
		return
	name_section.custom_minimum_size.x = floor(viewport_width * 0.25)


func _sync_slot_rank_badge(panel: Control, card: CardResource) -> void:
	if panel == null:
		return
	# 段位角标仅对战斗单位卡显示（法则卡/能量卡无军衔段位）
	if card == null or card.card_type != GC.CardType.COMBAT_UNIT:
		var old: Node = panel.get_node_or_null("RankCornerBadge")
		if old != null:
			old.queue_free()
		return
	RankDisplayUi.attach_corner_badge(panel, RankDisplayUi.resolve_from_card_resource(card), 13)


func _slot_name_label(panel: Control) -> Label:
	return panel.get_node_or_null("SlotVBox/SlotTextVBox/SlotNameLabel") as Label


func _slot_cost_label(panel: Control) -> Label:
	return panel.get_node_or_null("SlotVBox/SlotTextVBox/SlotCostLabel") as Label


func _slot_icon_rect(panel: Control) -> TextureRect:
	return panel.get_node_or_null("SlotVBox/SlotIconClip/SlotIcon") as TextureRect


func _apply_slot_bottom_text(panel: Control, name_text: String, cost_text: String) -> void:
	var name_l: Label = _slot_name_label(panel)
	var cost_l: Label = _slot_cost_label(panel)
	if name_l:
		name_l.text = name_text
	if cost_l:
		cost_l.text = cost_text


func _apply_slot_card_labels(panel: Control, card: CardResource) -> void:
	if card == null:
		return
	var display_name: String = "能量" if card.card_type == GC.CardType.ENERGY else String(card.display_name)
	if display_name.is_empty():
		display_name = DefaultCardsData.get_safe_display_name(card.card_id)
	if display_name.length() > 6:
		display_name = display_name.substr(0, 6)
	_apply_slot_bottom_text(panel, display_name, "%d⚡" % int(card.energy_cost))


func _sync_slot_card_frame(panel: Control, card: CardResource) -> void:
	if panel == null or not (panel is PanelContainer):
		return
	var p: PanelContainer = panel as PanelContainer
	if card != null:
		CardFrameUi.apply_slot_chrome(p, card)
	else:
		CardFrameUi.clear_panel_frame(p)
		CardBackgroundUi.clear_overlay(p)


func _sync_slot_card_background(panel: Control, card: CardResource) -> void:
	_sync_slot_card_frame(panel, card)


func _sync_slot_icon(panel: Control, card: CardResource, law_id: String) -> void:
	var tr: TextureRect = _slot_icon_rect(panel)
	if tr == null:
		return
	var tex: Texture2D = null
	if card != null:
		tex = UiAssetLoader.load_tex(UiAssetLoader.card_icon_path_for(card))
	elif not law_id.is_empty():
		tex = UiAssetLoader.load_tex(UiAssetLoader.law_slot_icon_path(law_id))
	var slot_h: float = panel.size.y if panel.size.y > 4.0 else float(SLOT_FIXED_SIZE.y)
	var art_h: float = maxf(18.0, slot_h - float(_SLOT_BOTTOM_TEXT_H) - 4.0)
	var art_w: float = SLOT_FIXED_SIZE.x - 6.0
	if card != null:
		UiAssetLoader.setup_card_unit_icon(tr, tex, Vector2(art_w, art_h), true)
	else:
		UiAssetLoader.setup_texrect_icon(tr, tex, Vector2(art_w, art_h))


func _build_slot_panel(entry: Dictionary) -> PanelContainer:
	var color: String = String(entry.get("color", "green"))
	var color_index: int = int(entry.get("index", -1))
	var law_id: String = String(entry.get("law_id", ""))
	var law_kind: String = String(entry.get("law_kind", ""))
	# v6.2: rune 槽的 card 字段实际是 rune_id (String)，用 Variant 承载避免类型崩溃
	var card: Variant = entry.get("card", null)
	var has_card: bool = card != null and card is CardResource
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_FIXED_SIZE.x, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.set_meta("slot_color", color)
	panel.set_meta("slot_index", color_index)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.bg_color = _slot_bg(color)
	sb.border_color = _slot_border(color)
	panel.add_theme_stylebox_override("panel", sb)
	var root_v := VBoxContainer.new()
	root_v.name = "SlotVBox"
	root_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_theme_constant_override("separation", 2)
	var icon_clip := Control.new()
	icon_clip.name = "SlotIconClip"
	icon_clip.clip_contents = true
	icon_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot_icon_tr := TextureRect.new()
	slot_icon_tr.name = "SlotIcon"
	slot_icon_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_icon_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot_icon_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot_icon_tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_clip.add_child(slot_icon_tr)
	var text_v := VBoxContainer.new()
	text_v.name = "SlotTextVBox"
	text_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_v.size_flags_vertical = Control.SIZE_SHRINK_END
	text_v.custom_minimum_size.y = _SLOT_BOTTOM_TEXT_H
	text_v.add_theme_constant_override("separation", 0)
	text_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_lbl := Label.new()
	name_lbl.name = "SlotNameLabel"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 1.0))
	var cost_lbl := Label.new()
	cost_lbl.name = "SlotCostLabel"
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	cost_lbl.clip_text = true
	cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_lbl.add_theme_font_size_override("font_size", 9)
	cost_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35, 1.0))
	text_v.add_child(name_lbl)
	text_v.add_child(cost_lbl)
	root_v.add_child(icon_clip)
	root_v.add_child(text_v)
	panel.add_child(root_v)
	# v6.2c: 符文槽位（card 字段是 rune_id String，不是 CardResource，必须单独处理）
	var rune_id: String = String(entry.get("rune_id", ""))
	if color == "rune" and not rune_id.is_empty():
		var rune_name: String = RuneDefinitions.get_rune_name(rune_id)
		var rune_def: Dictionary = RuneDefinitions.get_rune(rune_id)
		var rarity_name: String = RuneDefinitions.RARITY_NAMES.get(rune_def.get("rarity", ""), "")
		var short_name: String = rune_name
		if short_name.length() > 4:
			short_name = short_name.substr(0, 4)
		panel.set_meta("card_id", "")
		panel.set_meta("card_type", -1)
		panel.set_meta("law_id", "")
		panel.set_meta("law_kind", "")
		_apply_slot_bottom_text(panel, "◈" + short_name, rarity_name)
		panel.tooltip_text = "符文：%s（%s）\n%s" % [rune_name, rarity_name, RuneDefinitions.get_description(rune_id)]
		var rune_tr: TextureRect = _slot_icon_rect(panel)
		var rune_tex: Texture2D = UiAssetLoader.rune_icon(rune_id)
		var slot_h: float = panel.size.y if panel.size.y > 4.0 else float(SLOT_FIXED_SIZE.y)
		var art_h: float = maxf(18.0, slot_h - float(_SLOT_BOTTOM_TEXT_H) - 4.0)
		var art_w: float = SLOT_FIXED_SIZE.x - 6.0
		UiAssetLoader.setup_texrect_icon(rune_tr, rune_tex, Vector2(art_w, art_h))
		_sync_slot_rank_badge(panel, null)
		_sync_slot_card_background(panel, null)
		_sync_slot_card_frame(panel, null)
		panel.gui_input.connect(_on_slot_gui_input.bind(panel))
		return panel
	if has_card:
		panel.set_meta("card_id", card.card_id)
		panel.set_meta("card_type", int(card.card_type))
		panel.set_meta("law_id", "")
		panel.set_meta("law_kind", "")
		_apply_slot_card_labels(panel, card)
		panel.tooltip_text = _format_card_slot_tooltip(color, card)
		if card.card_type == GC.CardType.COMBAT_UNIT:
			var indicator := Polygon2D.new()
			indicator.name = "DeployIndicator"
			indicator.polygon = PackedVector2Array([
				Vector2(-6, 0), Vector2(6, 0), Vector2(0, -10)
			])
			indicator.color = Color(0.2, 1.0, 0.3, 0.9)
			indicator.position = Vector2(SLOT_FIXED_SIZE.x * 0.5, -2)
			indicator.visible = false
			panel.add_child(indicator)
	elif not law_id.is_empty():
		panel.set_meta("card_id", "")
		panel.set_meta("card_type", -1)
		panel.set_meta("law_id", law_id)
		panel.set_meta("law_kind", law_kind)
		var cfg: Dictionary = PhaseLaws.get_by_id(law_id) if PhaseLaws else {}
		var law_name: String = String(cfg.get("name", law_id))
		var battle_cost: Dictionary = cfg.get("battle_cost", {})
		var activate_cost: Dictionary = cfg.get("activate_cost", {})
		var battle_energy: int = int(battle_cost.get("energy", 0))
		var activate_nano: int = int(activate_cost.get("nano", 0))
		var cost_line: String = ""
		if battle_energy > 0:
			cost_line = "%d⚡" % battle_energy
		elif activate_nano > 0:
			cost_line = "纳米%d" % activate_nano
		var short_law_name: String = law_name
		if short_law_name.length() > 5:
			short_law_name = short_law_name.substr(0, 5)
		_apply_slot_bottom_text(
			panel,
			("⚔" if law_kind == "active" else "🛡") + short_law_name,
			cost_line
		)
		var detail_lines: Array[String] = []
		detail_lines.append("%s 槽：%s" % [_slot_name(color), law_name])
		detail_lines.append("类型：%s" % ("主动法则" if law_kind == "active" else "被动法则"))
		if battle_energy > 0:
			detail_lines.append("战斗能量消耗：%d⚡" % battle_energy)
		if activate_nano > 0:
			detail_lines.append("激活消耗：纳米%d" % activate_nano)
		var rt: Dictionary = cfg.get("runtime_tags", {})
		if not rt.is_empty():
			var effect: String = String(rt.get("effect", ""))
			var value: float = float(rt.get("value", 0.0))
			var duration: float = float(rt.get("duration", 0.0))
			if not effect.is_empty():
				var effect_line: String = "效果：%s" % effect
				if value != 0.0:
					effect_line += "（值 %.2f）" % value
				if duration > 0.0:
					effect_line += "，持续 %.1f 秒" % duration
				detail_lines.append(effect_line)
		var env_req: Dictionary = cfg.get("env_req", {})
		if not env_req.is_empty():
			var env_parts: Array[String] = []
			if env_req.has("weather"):
				env_parts.append("天气:%s" % _join_env_values("weather", env_req["weather"]))
			if env_req.has("terrain"):
				env_parts.append("地形:%s" % _join_env_values("terrain", env_req["terrain"]))
			if env_req.has("energy_field"):
				env_parts.append("能场:%s" % _join_env_values("energy_field", env_req["energy_field"]))
			if env_req.has("time_of_day"):
				env_parts.append("时段:%s" % _join_env_values("time_of_day", env_req["time_of_day"]))
			if env_parts.size() > 0:
				detail_lines.append("环境要求：" + "；".join(env_parts))
		panel.tooltip_text = "\n".join(detail_lines)
	else:
		panel.set_meta("card_id", "")
		panel.set_meta("card_type", -1)
		panel.set_meta("law_id", "")
		panel.set_meta("law_kind", "")
		_apply_slot_bottom_text(panel, "空", "")
		panel.tooltip_text = "%s 槽（空）" % _slot_name(color)
	_sync_slot_icon(panel, card, law_id)
	_sync_slot_rank_badge(panel, card)
	_sync_slot_card_background(panel, card)
	_sync_slot_card_frame(panel, card)
	# 统一 gui_input 处理：通过 panel meta 读取当前状态
	# 无论面板初始是卡牌/法则/空，都能正确处理所有情况
	panel.gui_input.connect(_on_slot_gui_input.bind(panel))
	return panel

func _show_instrument_slot_card_detail(card_id: String, source_panel: Control) -> bool:
	if card_id.is_empty():
		return false
	var card: CardResource = DefaultCardsData.get_card_by_id(card_id)
	if card == null and PhaseInstrumentManager and PhaseInstrumentManager.has_method("get_card_by_id"):
		card = PhaseInstrumentManager.get_card_by_id(card_id)
	if card == null:
		return false
	# 先隐藏背包的 CardDetailPopup（防止与全局面板同时显示）
	var backpack_panel = NodeFinder.get_backpack_panel()
	if backpack_panel and backpack_panel.has_method("hide_card_detail"):
		backpack_panel.hide_card_detail()
	# 使用全局 CardInfoPanel（挂在 InfoPanelLayer layer=90，不被 HUD 遮挡）
	var info_panel: Control = NodeFinder.get_card_info_panel() as Control
	if info_panel != null:
		if info_panel.has_method("set_panel_mode"):
			info_panel.set_panel_mode(CardInfoPanel.PanelMode.MODE_BATTLEFIELD)
		if info_panel.has_method("show_card_info"):
			var show_pos := source_panel.global_position + Vector2(source_panel.size.x + 8, -200)
			info_panel.show_card_info(card, show_pos)
		return true
	return false


func _on_slot_gui_input(ev: InputEvent, panel: Control) -> void:
	if not is_instance_valid(panel) or not is_instance_valid(self):
		return
	var m_color: String = String(panel.get_meta("slot_color", ""))
	var m_index: int = int(panel.get_meta("slot_index", -1))
	var m_card_id: String = String(panel.get_meta("card_id", ""))
	var m_law_id: String = String(panel.get_meta("law_id", ""))
	var m_law_kind: String = String(panel.get_meta("law_kind", ""))
	var m_card_type: int = int(panel.get_meta("card_type", -1))
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if Input.is_key_pressed(KEY_SHIFT):
			if _try_unequip_card_slot(m_color, m_index):
				return
		if m_color == "green" and not m_card_id.is_empty():
			var in_battle: bool = BattleManager != null and "battle_active" in BattleManager and BattleManager.battle_active
			var can_deploy: bool = (
				in_battle
				and m_card_type == GC.CardType.COMBAT_UNIT
			)
			if can_deploy and SignalBus:
				BattleInputState.pending_cast_law_id = ""
				BattleInputState.pending_cast_law_origin_global = Vector2.ZERO
				BattleInputState.pending_deploy_platform_card_id = m_card_id
				BattleInputState.pending_deploy_origin_global = panel.get_global_rect().get_center()
				return
			if _show_instrument_slot_card_detail(m_card_id, panel):
				return
		if (m_color == "red" or m_color == "blue") and not m_law_id.is_empty():
			if m_law_kind == "active":
				law_slot_clicked.emit(m_law_id, m_law_kind, panel.get_global_rect().get_center())
			else:
				var in_battle_passive: bool = BattleManager != null and "battle_active" in BattleManager and BattleManager.battle_active
				if not in_battle_passive:
					law_area_clicked.emit()
			return
		instrument_area_clicked.emit()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		if _try_unequip_card_slot(m_color, m_index):
			return

func _slot_name(color: String) -> String:
	match color:
		"green": return "单位"
		"red": return "主动法则"
		"blue": return "被动法则"
		"yellow": return "能量"
		"rune": return "符文"
	return color

func _env_value_label(env_key: String, raw: String) -> String:
	var maps: Dictionary = {
		"weather": {
			"clear": "晴朗",
			"rain": "降雨",
			"storm": "风暴",
			"fog": "迷雾",
		},
		"terrain": {
			"plain": "平原",
			"city": "城市",
			"mountain": "山地",
			"forest": "森林",
		},
		"energy_field": {
			"normal": "常规场",
			"high_field": "高能场",
			"nano_fog": "纳米雾",
			"void_rift": "虚空裂隙",
		},
		"time_of_day": {
			"day": "白天",
			"dusk": "黄昏",
			"night": "夜晚",
		},
	}
	var group: Dictionary = maps.get(env_key, {})
	if group.has(raw):
		return String(group[raw])
	return raw

func _join_env_values(env_key: String, values: Array) -> String:
	var out: Array[String] = []
	for v in values:
		out.append(_env_value_label(env_key, String(v)))
	return ", ".join(out)

func _slot_bg(color: String) -> Color:
	match color:
		"green": return Color(0.04, 0.16, 0.08, 0.92)
		"red": return Color(0.20, 0.05, 0.05, 0.92)
		"blue": return Color(0.05, 0.10, 0.22, 0.92)
		"yellow": return Color(0.18, 0.15, 0.04, 0.92)
		"rune": return Color(0.14, 0.06, 0.22, 0.92)
	return Color(0.07, 0.08, 0.12, 0.92)

func _slot_border(color: String) -> Color:
	match color:
		"green": return Color(0.32, 0.85, 0.45, 0.85)
		"red": return Color(0.90, 0.35, 0.35, 0.85)
		"blue": return Color(0.45, 0.70, 1.00, 0.85)
		"yellow": return Color(0.95, 0.80, 0.35, 0.90)
		"rune": return Color(0.75, 0.45, 0.95, 0.90)
	return Color(0.35, 0.45, 0.60, 0.8)

func _try_unequip_card_slot(color: String, color_index: int) -> bool:
	if _drag_system:
		return _drag_system.try_unequip_card_slot(color, color_index)
	return false

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if _drag_system:
		return _drag_system.can_drop_data(at_position, data)
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _drag_system:
		_drag_system.drop_data(at_position, data)

func _get_slot_entry_by_local_pos(at_position: Vector2) -> Dictionary:
	if _drag_system:
		return _drag_system.get_slot_entry_by_local_pos(at_position)
	return {}

func _slot_to_flat_index(color: String, color_index: int) -> int:
	if _drag_system:
		return _drag_system.slot_to_flat_index(color, color_index)
	return -1

## 刷新相位仪等级标签
func _refresh_phase_level() -> void:
	if phase_level_label == null or not is_instance_valid(phase_level_label):
		return
	if PhaseInstrumentManager == null or not PhaseInstrumentManager.has_method("get_phase_field_xp_progress"):
		return
	var prog: Dictionary = PhaseInstrumentManager.get_phase_field_xp_progress()
	var lv: int = int(prog.get("level", 1))
	var cur_xp: int = int(prog.get("cur_xp", 0))
	var next_xp: int = int(prog.get("next_xp", 0))
	var instrument_name: String = ""
	var instrument_star: int = -1
	var cfg: Dictionary = {}
	if PhaseInstrumentManager.has_method("get_current_instrument"):
		cfg = PhaseInstrumentManager.get_current_instrument()
		instrument_name = String(cfg.get("name", ""))
		instrument_star = int(cfg.get("star", -1))
	var head: String = "相位场"
	if not instrument_name.is_empty() and instrument_star > 0:
		head = "%s ★%d" % [instrument_name, instrument_star]
	if next_xp <= 0:
		phase_level_label.text = "%s Lv.%d MAX" % [head, lv]
	else:
		phase_level_label.text = "%s Lv.%d %d/%d" % [head, lv, cur_xp, next_xp]
	_refresh_instrument_stats()
	# 在名称区域设置完整属性 tooltip
	_update_instrument_tooltip(cfg)

func _update_instrument_tooltip(cfg: Dictionary) -> void:
	var target: Control = _phase_level_label_container if (_phase_level_label_container and is_instance_valid(_phase_level_label_container)) else name_section
	if target == null:
		return
	if cfg.is_empty():
		target.tooltip_text = ""
		return
	var lines: Array[String] = []
	# 能量属性
	var output_rate: float = float(cfg.get("energy_output_rate", 1.0))
	var recovery_rate: float = float(cfg.get("energy_recovery_rate", 0.3))
	var output_ps: float = output_rate * 5.0
	var recovery_ps: float = recovery_rate * 3.0
	lines.append("能量输出: %.1f/秒" % output_ps)
	lines.append("能量恢复: %.1f/秒" % recovery_ps)
	# 部署范围
	var spawn_ratio: float = float(cfg.get("spawn_range_ratio", 0.3))
	lines.append("部署范围: %.0f%%" % (spawn_ratio * 100.0))
	# 槽位配置
	var sc: Dictionary = cfg.get("slot_counts", {})
	var green_n: int = int(sc.get("green", 0))
	var red_n: int = int(sc.get("red", 0))
	var blue_n: int = int(sc.get("blue", 0))
	var yellow_n: int = int(sc.get("yellow", 0))
	var rune_n: int = int(sc.get("rune", 0))
	var slot_parts: Array[String] = []
	if green_n > 0: slot_parts.append("单位%d" % green_n)
	if red_n > 0: slot_parts.append("主动%d" % red_n)
	if blue_n > 0: slot_parts.append("被动%d" % blue_n)
	if yellow_n > 0: slot_parts.append("能量%d" % yellow_n)
	if rune_n > 0: slot_parts.append("符文%d" % rune_n)
	if not slot_parts.is_empty():
		lines.append("槽位: %s" % " ".join(slot_parts))
	# 属性加成（新 properties[] + 旧字段回退）
	var bonus_lines: Array[String] = _collect_cfg_property_lines(cfg)
	if not bonus_lines.is_empty():
		lines.append("属性加成:")
		for bl in bonus_lines:
			lines.append("  %s" % bl)
	# 特殊特性
	var traits: Array = cfg.get("special_traits", [])
	if not traits.is_empty():
		lines.append("特殊特性:")
		for t in traits:
			lines.append("  ✦ %s" % String(t))
	# v6.7: 主动特殊能力（active_ability）— 7星相位仪招牌技能，原装配后 tooltip 漏显示
	var ability: Dictionary = cfg.get("active_ability", {})
	if not ability.is_empty():
		var ability_name: String = String(ability.get("name", ""))
		var ability_desc: String = String(ability.get("description", ""))
		var ability_text: String = ability_desc if not ability_desc.is_empty() else ability_name
		if not ability_name.is_empty() and not ability_desc.is_empty():
			ability_text = "%s：%s" % [ability_name, ability_desc]
		lines.append("主动能力:")
		lines.append("  ⚡ %s" % ability_text)
	# v6.2: 追加符文之语 + 相位场属性点加成
	_append_bonus_tooltip_lines(lines)
	target.tooltip_text = "\n".join(lines)

## v6.2: 把符文之语加成和相位场加成格式化追加到 tooltip lines
## 复用 PhaseInstrumentManager.get_all_bonus_summary() 统一数据源
func _append_bonus_tooltip_lines(lines: Array) -> void:
	if PhaseInstrumentManager == null or not PhaseInstrumentManager.has_method("get_all_bonus_summary"):
		return
	var summary: Dictionary = PhaseInstrumentManager.get_all_bonus_summary()
	# v6.2b: 单符文加成
	var rune_stats: Dictionary = summary.get("rune_stats", {})
	var rune_specials: Array = summary.get("rune_specials", [])
	if not rune_stats.is_empty() or not rune_specials.is_empty():
		lines.append("符文加成:")
		if not rune_stats.is_empty():
			var stat_parts: Array[String] = []
			for key in rune_stats.keys():
				var s: String = RuneDefinitions.format_stat_bonus(String(key), float(rune_stats[key]))
				if not s.is_empty():
					stat_parts.append(s)
			if not stat_parts.is_empty():
				lines.append("  " + " | ".join(stat_parts))
		if not rune_specials.is_empty():
			var sp_parts: Array[String] = []
			for sp in rune_specials:
				if not (sp is Dictionary):
					continue
				var sp_name: String = RuneDefinitions.special_display_name(String((sp as Dictionary).get("special", "")))
				var chance := int(round(float((sp as Dictionary).get("chance", 1.0)) * 100.0))
				sp_parts.append("%s(%d%%概率)" % [sp_name, chance])
			if not sp_parts.is_empty():
				lines.append("  " + " | ".join(sp_parts))
	# v6.2b: 符文之语加成（每个带名称）
	var runeword_bonuses: Array = summary.get("runeword_bonuses", [])
	if not runeword_bonuses.is_empty():
		lines.append("符文之语加成:")
		for rw in runeword_bonuses:
			if not (rw is Dictionary):
				continue
			var rw_name: String = String((rw as Dictionary).get("name", ""))
			var rw_stats: Dictionary = (rw as Dictionary).get("stats", {})
			var rw_parts: Array[String] = []
			for key in rw_stats.keys():
				var s: String = RuneDefinitions.format_stat_bonus(String(key), float(rw_stats[key]))
				if not s.is_empty():
					rw_parts.append(s)
			for sp in (rw as Dictionary).get("specials", []):
				if not (sp is Dictionary):
					continue
				var sp_name: String = RuneDefinitions.special_display_name(String((sp as Dictionary).get("special", "")))
				var chance := int(round(float((sp as Dictionary).get("chance", 1.0)) * 100.0))
				rw_parts.append("%s(%d%%概率)" % [sp_name, chance])
			if not rw_parts.is_empty():
				lines.append("  [%s] %s" % [rw_name, " | ".join(rw_parts)])
	# 相位场属性点加成
	var pf_bonus: Dictionary = summary.get("phase_field", {})
	var pf_labels: Dictionary = summary.get("phase_field_labels", {})
	if not pf_bonus.is_empty():
		var pf_parts: Array[String] = []
		for key in pf_bonus.keys():
			var val: float = float(pf_bonus[key])
			var pct := int(round(val * 100.0))
			if pct == 0:
				continue
			var label: String = String(pf_labels.get(key, key))
			pf_parts.append("%s +%d%%" % [label, pct])
		if not pf_parts.is_empty():
			lines.append("相位场加成:")
			lines.append("  " + " | ".join(pf_parts))

func _refresh_instrument_stats() -> void:
	if instrument_stats_label == null or not is_instance_valid(instrument_stats_label):
		return
	if PhaseInstrumentManager == null or not PhaseInstrumentManager.has_method("get_current_instrument"):
		instrument_stats_label.text = "--"
		if instrument_icon:
			instrument_icon.texture = null
		return
	var cfg: Dictionary = PhaseInstrumentManager.get_current_instrument()
	if cfg.is_empty():
		instrument_stats_label.text = "--"
		if instrument_icon:
			instrument_icon.texture = null
		return
	# v6.2c: 相位仪位置只显示名字 + 星级（统计信息移到 tooltip）
	var inst_name: String = String(cfg.get("name", "未知相位仪"))
	var star: int = int(cfg.get("star", 0))
	if star > 0:
		instrument_stats_label.text = "%s ★%d" % [inst_name, star]
	else:
		instrument_stats_label.text = inst_name
	# 加载相位仪图标
	if instrument_icon:
		var icon_tex: Texture2D = UiAssetLoader.instrument_icon(String(cfg.get("id", "")))
		instrument_icon.texture = icon_tex
		instrument_icon.visible = (icon_tex != null)

## v6.2: 构建符文加成精简摘要（用于底部统计行，单行，避免撑高底部栏）
## 格式：" | 符文:攻+15% 生+20% ×2语"（×2语 = 已激活 2 个符文之语）
## 符文之语的名称与详细加成由 tooltip 展示，统计行只给精简计数。
## 无任何符文加成返回空字符串。
func _build_rune_bonus_summary() -> String:
	if PhaseInstrumentManager == null or not PhaseInstrumentManager.has_method("get_rune_bonus"):
		return ""
	var bonus: Dictionary = PhaseInstrumentManager.get_rune_bonus()
	var stats: Dictionary = bonus.get("rune_stats", {})
	var parts: Array[String] = []
	for key in stats.keys():
		var val: float = float(stats[key])
		var pct := int(round(val * 100.0))
		if pct == 0:
			continue
		parts.append(RuneDefinitions.format_stat_bonus(String(key), val))
	# 符文之语只显示激活数量（详情见 tooltip）
	var runeword_count: int = bonus.get("runeword_bonuses", []).size()
	var result: String = ""
	if not parts.is_empty():
		result += " | 符文:" + " ".join(parts)
	if runeword_count > 0:
		result += " ×%d语" % runeword_count
	return result

## v7.1: 计算并返回能量预览信息字符串
## 显示：能量上限(含能量卡贡献) | 初始能量 | 净回复/秒 | 相位仪回复值
## 注意：战前独立遍历槽位计算，与 EnergyManager._apply_equipped_energy_cards 保持公式一致
func _build_energy_preview_line() -> String:
	if PhaseInstrumentManager == null or not PhaseInstrumentManager.has_method("get_slots"):
		return ""
	var total_star: int = 0
	var base_start: float = 0.0
	var slot_count: int = 0
	for c_raw in PhaseInstrumentManager.get_slots():
		if c_raw is CardResource:
			slot_count += 1
			var card: CardResource = c_raw
			if card.card_type != GC.CardType.ENERGY:
				continue
			total_star += EnergyManager.parse_energy_card_star(card.card_id)
			if card.card_id.begins_with("energy_start_"):
				base_start += maxf(0.0, card.energy_grant)
	# 能量上限 = 基础100 + 能量卡等级×100
	var energy_max: float = GC.ENERGY_MAX
	if total_star > 0:
		energy_max = GC.ENERGY_MAX + float(total_star) * 100.0
	# 初始能量（无能量卡时回落到默认起步值）
	var energy_start: float = base_start if base_start > 0.0 else GC.ENERGY_START
	# 相位仪回复值
	var pi_regen: float = 0.0
	if PhaseInstrumentManager.has_method("get_energy_recovery_rate"):
		pi_regen = PhaseInstrumentManager.get_energy_recovery_rate()
	# 4槽全装回复×5（与 EnergyManager 后端一致）
	var pi_regen_display: float = pi_regen
	if slot_count >= 4:
		pi_regen_display *= 5.0
	# 净回复 = 基础1.0 + 相位仪回复 − 消耗0.5
	var net_regen: float = GC.ENERGY_REGEN_PER_SEC + pi_regen_display - GC.PHASE_BASE_DRAIN_PER_SEC
	return " | ⚡上限%d 初始%d 回复%.1f/s(相位%.1f)" % [int(energy_max), int(energy_start), net_regen, pi_regen_display]

func _collect_cfg_property_lines(cfg: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var props: Array = cfg.get("properties", [])
	if props is Array and not props.is_empty():
		for p in props:
			if not (p is Dictionary):
				continue
			var display: String = String((p as Dictionary).get("display", ""))
			if display.is_empty():
				var pid: String = String((p as Dictionary).get("id", ""))
				display = PhaseInstruments.build_property_display(pid, float((p as Dictionary).get("value", 0.0)))
			if not display.is_empty():
				out.append(display)
		return out
	var dmg: float = float(cfg.get("card_damage_bonus", 0.0))
	var def: float = float(cfg.get("defense_bonus", 0.0))
	var xp_b: float = float(cfg.get("xp_bonus", 0.0))
	var drop_b: float = float(cfg.get("drop_bonus", 0.0))
	var ecr: int = int(cfg.get("energy_cost_reduction", 0))
	if dmg > 0.0: out.append("卡伤 +%.0f%%" % (dmg * 100.0))
	if def > 0.0: out.append("防御 +%.0f%%" % (def * 100.0))
	if xp_b > 0.0: out.append("相位场经验 +%.0f%%" % (xp_b * 100.0))
	if drop_b > 0.0: out.append("掉落 +%.0f%%" % (drop_b * 100.0))
	if ecr > 0: out.append("能耗 -%d" % ecr)
	return out

## 信号回调
func _on_instrument_slot_clicked(_slot_index: int) -> void:
	instrument_area_clicked.emit()

## 外部调用：强制刷新全部
func refresh() -> void:
	_refresh_all()

## 使相位仪等级标签可点击
func _make_phase_level_label_clickable() -> void:
	if phase_level_label == null or not is_instance_valid(phase_level_label):
		return

	# 创建一个容器包裹标签，使其可点击
	var parent = phase_level_label.get_parent()
	if parent == null:
		return

	_phase_level_label_container = HBoxContainer.new()
	_phase_level_label_container.name = "PhaseLevelLabelContainer"
	_phase_level_label_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_phase_level_label_container.add_theme_constant_override("separation", 4)
	_phase_level_label_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_phase_level_label_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_phase_level_label_container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_phase_level_label_container.z_index = 10
	# 保证有可点区域（避免布局首帧前 combined_minimum_size 为 0 导致点击无效）
	_phase_level_label_container.custom_minimum_size = Vector2(120, int(SLOT_FIXED_SIZE.y))
	_phase_level_label_container.mouse_filter = Control.MOUSE_FILTER_STOP

	var pip_icon := TextureRect.new()
	UiAssetLoader.setup_texrect_icon(pip_icon, UiAssetLoader.ui_icon("icon_phase_instrument"), Vector2(18, 18))

	# 将标签的父容器设置为新的容器
	var label_index = phase_level_label.get_index()
	parent.remove_child(phase_level_label)
	_phase_level_label_container.add_child(pip_icon)
	_phase_level_label_container.add_child(phase_level_label)
	parent.add_child(_phase_level_label_container)
	parent.move_child(_phase_level_label_container, label_index)

	phase_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 连接点击事件
	_phase_level_label_container.gui_input.connect(_on_phase_level_label_input)

## 处理相位仪标签点击
func _on_phase_level_label_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		phase_level_label_clicked.emit()
