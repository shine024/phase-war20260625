extends PanelContainer
class_name IntelligenceHubPanel

## 情报中心：V1 世界观情报 · V3 单位进化总图 + 详情

signal closed
signal open_progression_requested(card_id: String)

@onready var _close_btn: Button = $Margin/VBox/TitleRow/CloseButton
@onready var _tab_container: TabContainer = $Margin/VBox/TabContainer
@onready var _lore_grid: GridContainer = $Margin/VBox/TabContainer/LoreTab/LoreScroll/LoreGrid
@onready var _evolution_host: Control = $Margin/VBox/TabContainer/EvolutionTab/EvolutionHost

var _atlas: EvolutionAtlasView
var _detail: UnitProgressionDetailView


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.97)
	style.border_color = Color(0.2, 0.45, 0.72, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", style)

	if _close_btn:
		_close_btn.pressed.connect(_on_close)
	_setup_evolution_tab()
	_refresh_lore()
	if _tab_container:
		_tab_container.set_tab_title(0, "世界观情报")
		_tab_container.set_tab_title(1, "单位进化图谱")
		_tab_container.tab_changed.connect(_on_tab_changed)


func refresh() -> void:
	_refresh_lore()
	if _atlas:
		_atlas.refresh()
	if _detail and _detail.visible and not _detail.get_card_id().is_empty():
		_detail.show_card(_detail.get_card_id())


func _setup_evolution_tab() -> void:
	if _evolution_host == null:
		return
	for child in _evolution_host.get_children():
		child.queue_free()

	_atlas = EvolutionAtlasView.new()
	_atlas.name = "EvolutionAtlas"
	_atlas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_atlas.card_selected.connect(_on_atlas_card_selected)
	_evolution_host.add_child(_atlas)

	_detail = UnitProgressionDetailView.new()
	_detail.name = "UnitDetail"
	_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail.back_pressed.connect(_on_detail_back)
	_detail.open_progression_requested.connect(_on_detail_open_progression)
	_evolution_host.add_child(_detail)
	_detail.hide_detail()


func _on_tab_changed(tab: int) -> void:
	if tab == 1 and _atlas:
		_atlas.refresh()


func _refresh_lore() -> void:
	if _lore_grid == null:
		return
	for child in _lore_grid.get_children():
		child.queue_free()

	var lm: Node = get_node_or_null("/root/LoreManager")
	if lm == null or not lm.has_method("get_unlocked_lore"):
		_add_lore_placeholder("情报系统未初始化")
		return

	var unlocked: Array = lm.get_unlocked_lore()
	if unlocked.is_empty():
		_add_lore_placeholder("暂无已解锁世界观情报\n（战斗掉落情报页后显示于此）")
		return

	for lore_data in unlocked:
		_add_lore_card(lore_data)


func _add_lore_placeholder(message: String) -> void:
	var lbl := Label.new()
	lbl.text = message
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 0.9))
	_lore_grid.add_child(lbl)


func _add_lore_card(lore_data: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 100)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = lore_data.get("name", "情报资料")
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	name_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(name_lbl)

	var desc := Label.new()
	desc.text = lore_data.get("description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(200, 0)
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	vbox.add_child(desc)

	_lore_grid.add_child(panel)


func _on_atlas_card_selected(card_id: String) -> void:
	if _detail == null or _atlas == null:
		return
	_detail.show_card(card_id)
	_atlas.visible = false


func _on_detail_back() -> void:
	var focus_id: String = _detail.get_card_id() if _detail else ""
	if _detail:
		_detail.hide_detail()
	if _atlas:
		_atlas.visible = true
		if not focus_id.is_empty():
			_atlas.focus_card(focus_id)


func _on_detail_open_progression(card_id: String) -> void:
	open_progression_requested.emit(card_id)


func _on_close() -> void:
	_on_detail_back()
	closed.emit()
