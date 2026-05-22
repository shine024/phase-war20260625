extends Control
class_name EvolutionAtlasView

## 进化总览：按时代分列列出全部单位（无连线），点击进入详情

signal card_selected(card_id: String)

const EvolutionGraphBuilder = preload("res://scripts/progression/evolution_graph_builder.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const DefaultCards = preload("res://data/default_cards.gd")

const COL_MIN_WIDTH := 112
## 与旧版画布节点一致：图标 40×40，下方仅显示名称
const CARD_ICON_SIZE := Vector2(40, 40)
const UNIT_ENTRY_MIN_SIZE := Vector2(96, 72)

var _scroll: ScrollContainer
var _columns_row: HBoxContainer
var _hint_label: Label
var _graph: Dictionary = {}
var _unit_entries: Dictionary = {}  # card_id -> Control（可点击条目）


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	refresh()


func _build_ui() -> void:
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(outer)

	_hint_label = Label.new()
	_hint_label.text = "按时代分列 · 点击单位查看进化来源与养成详情"
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72, 1.0))
	outer.add_child(_hint_label)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	outer.add_child(_scroll)

	_columns_row = HBoxContainer.new()
	_columns_row.add_theme_constant_override("separation", 12)
	_columns_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_columns_row)


func refresh() -> void:
	_graph = EvolutionGraphBuilder.build()
	_rebuild_columns()


func focus_card(card_id: String) -> void:
	if card_id.is_empty() or not _unit_entries.has(card_id):
		return
	_highlight_card(card_id)
	call_deferred("_scroll_to_unit_entry", card_id)


func _scroll_to_unit_entry(card_id: String) -> void:
	var entry: Control = _unit_entries.get(card_id)
	if entry == null or not is_instance_valid(entry) or _scroll == null:
		return
	var rect := entry.get_global_rect()
	var scroll_rect := _scroll.get_global_rect()
	if rect.position.x < scroll_rect.position.x:
		_scroll.scroll_horizontal = int(maxf(0.0, _scroll.scroll_horizontal + (rect.position.x - scroll_rect.position.x) - 16.0))
	elif rect.end.x > scroll_rect.end.x:
		_scroll.scroll_horizontal = int(_scroll.scroll_horizontal + (rect.end.x - scroll_rect.end.x) + 16.0)


func _rebuild_columns() -> void:
	if _columns_row == null:
		return
	for child in _columns_row.get_children():
		child.queue_free()
	_unit_entries.clear()

	var by_era: Array = _graph.get("by_era", [])
	var era_labels: PackedStringArray = _graph.get("era_labels", PackedStringArray())

	for era in range(by_era.size()):
		var col_entries: Array = by_era[era] if era < by_era.size() else []
		var col := _make_era_column(era, era_labels, col_entries)
		_columns_row.add_child(col)


func _make_era_column(era: int, era_labels: PackedStringArray, entries: Array) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(COL_MIN_WIDTH, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.55)
	style.border_color = Color(0.18, 0.32, 0.48, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var col_vbox := VBoxContainer.new()
	col_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(col_vbox)

	var title := Label.new()
	title.text = era_labels[era] if era < era_labels.size() else "时代 %d" % era
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.5, 0.72, 0.95, 1.0))
	col_vbox.add_child(title)

	var count_lbl := Label.new()
	count_lbl.text = "%d 种单位" % entries.size()
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_size_override("font_size", 10)
	count_lbl.add_theme_color_override("font_color", Color(0.45, 0.52, 0.62, 1.0))
	col_vbox.add_child(count_lbl)

	var sep := HSeparator.new()
	col_vbox.add_child(sep)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_vbox.add_child(list)

	if entries.is_empty():
		var empty := Label.new()
		empty.text = "—"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5, 0.8))
		list.add_child(empty)
	else:
		for entry in entries:
			if entry is Dictionary:
				list.add_child(_make_unit_entry(entry))

	return panel


func _make_unit_entry(entry: Dictionary) -> PanelContainer:
	var card_id: String = String(entry.get("id", ""))
	var label: String = String(entry.get("label", card_id))
	var unlocked: bool = bool(entry.get("unlocked", false))

	var panel := PanelContainer.new()
	panel.custom_minimum_size = UNIT_ENTRY_MIN_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("card_id", card_id)
	panel.set_meta("style_unlocked", unlocked)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.12, 0.2, 0.92) if unlocked else Color(0.06, 0.07, 0.1, 0.75)
	normal.border_color = Color(0.25, 0.5, 0.8, 0.75) if unlocked else Color(0.28, 0.32, 0.4, 0.55)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", normal)
	panel.set_meta("base_style", normal)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	margin.add_child(col)

	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	if card != null:
		var tex: Texture2D = UiAssetLoader.load_tex(UiAssetLoader.card_icon_path_for(card))
		if tex != null:
			var icon_center := CenterContainer.new()
			icon_center.custom_minimum_size = CARD_ICON_SIZE
			icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(icon_center)
			var icon_slot := Control.new()
			icon_slot.custom_minimum_size = CARD_ICON_SIZE
			icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_center.add_child(icon_slot)
			var icon := TextureRect.new()
			icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon.offset_right = CARD_ICON_SIZE.x
			icon.offset_bottom = CARD_ICON_SIZE.y
			icon.texture = tex
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_SCALE
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_slot.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.custom_minimum_size = Vector2(UNIT_ENTRY_MIN_SIZE.x - 12, 0)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.88, 0.92, 0.96) if unlocked else Color(0.52, 0.56, 0.62))
	col.add_child(name_lbl)

	panel.gui_input.connect(_on_entry_gui_input.bind(card_id))
	panel.mouse_entered.connect(_on_entry_hover.bind(panel, true))
	panel.mouse_exited.connect(_on_entry_hover.bind(panel, false))

	_unit_entries[card_id] = panel
	return panel


func _on_entry_hover(panel: PanelContainer, entered: bool) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var hi_id: String = ""
	for cid in _unit_entries.keys():
		if _unit_entries[cid] == panel:
			hi_id = String(cid)
			break
	if not hi_id.is_empty() and _is_entry_highlighted(hi_id):
		return
	var base: StyleBoxFlat = panel.get_meta("base_style") as StyleBoxFlat
	if base == null:
		return
	var st := base.duplicate() as StyleBoxFlat
	if entered:
		st.bg_color = Color(0.1, 0.18, 0.28, 0.98)
		st.border_color = Color(0.35, 0.75, 1.0, 0.9)
		panel.add_theme_stylebox_override("panel", st)
	else:
		panel.add_theme_stylebox_override("panel", base)


func _on_entry_gui_input(event: InputEvent, card_id: String) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_on_unit_pressed(card_id)


func _is_entry_highlighted(card_id: String) -> bool:
	var panel: Control = _unit_entries.get(card_id)
	if panel == null:
		return false
	var st := panel.get_theme_stylebox("panel") as StyleBoxFlat
	return st != null and st.border_color == Color(0.0, 0.92, 1.0, 1.0)


func _highlight_card(card_id: String) -> void:
	for cid in _unit_entries.keys():
		var panel: PanelContainer = _unit_entries[cid]
		if panel == null or not is_instance_valid(panel):
			continue
		var base: StyleBoxFlat = panel.get_meta("base_style") as StyleBoxFlat
		if base == null:
			continue
		var dup := base.duplicate() as StyleBoxFlat
		if String(cid) == card_id:
			dup.bg_color = Color(0.05, 0.22, 0.32, 0.98)
			dup.border_color = Color(0.0, 0.92, 1.0, 1.0)
			dup.set_border_width_all(2)
		panel.add_theme_stylebox_override("panel", dup)


func _on_unit_pressed(card_id: String) -> void:
	if card_id.is_empty():
		return
	_highlight_card(card_id)
	card_selected.emit(card_id)
