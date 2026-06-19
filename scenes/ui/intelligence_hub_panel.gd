extends PanelContainer
class_name IntelligenceHubPanel

## 情报中心：V1 世界观情报 · V3 单位进化总图 + 详情 · v6.2 符文图鉴

signal closed
signal open_progression_requested(card_id: String)

const RuneDefs = preload("res://data/runes.gd")
const RunewordDefs = preload("res://data/runewords.gd")

@onready var _close_btn: Button = $Margin/VBox/TitleRow/CloseButton
@onready var _tab_container: TabContainer = $Margin/VBox/TabContainer
@onready var _lore_grid: GridContainer = $Margin/VBox/TabContainer/LoreTab/LoreScroll/LoreGrid
@onready var _evolution_host: Control = $Margin/VBox/TabContainer/EvolutionTab/EvolutionHost
@onready var _rune_content: VBoxContainer = $Margin/VBox/TabContainer/RuneTab/RuneScroll/RuneContent

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
	_refresh_runes_tab()
	if _tab_container:
		_tab_container.set_tab_title(0, "世界观情报")
		_tab_container.set_tab_title(1, "单位进化图谱")
		_tab_container.set_tab_title(2, "符文图鉴")
		_tab_container.tab_changed.connect(_on_tab_changed)


func refresh() -> void:
	_refresh_lore()
	_refresh_runes_tab()
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
	if tab == 2:
		_refresh_runes_tab()


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


# ═══════════════════════════════════════════════════════════════════
# v6.2: 符文图鉴标签页 — 显示全部符文和符文之语说明
# ═══════════════════════════════════════════════════════════════════

func _refresh_runes_tab() -> void:
	if _rune_content == null:
		return
	for child in _rune_content.get_children():
		child.queue_free()
	# 获取玩家拥有的符文（用于标记"已获得"）
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	var owned_runes: Array = []
	var equipped_runes: Array = []
	if pim and pim.has_method("get_owned_runes"):
		owned_runes = pim.get_owned_runes()
	if pim and pim.has_method("get_rune_slots"):
		equipped_runes = pim.get_rune_slots()
	# ── 第一部分：符文列表 ──
	_add_rune_section_header("◈ 符文列表（%d/%d 已获得）" % [owned_runes.size(), RuneDefs.ALL_RUNES.size()])
	for rune in RuneDefs.ALL_RUNES:
		var rune_id: String = rune.get("id", "")
		var is_owned: bool = owned_runes.has(rune_id)
		var is_equipped: bool = equipped_runes.has(rune_id)
		_add_rune_card(rune, is_owned, is_equipped)
	# ── 第二部分：符文之语列表 ──
	_add_rune_section_header("✦ 符文之语列表（共%d种）" % RunewordDefs.ALL_RUNEWORDS.size())
	for rw in RunewordDefs.ALL_RUNEWORDS:
		_add_runeword_card(rw, owned_runes)


func _add_rune_section_header(title_text: String) -> void:
	var header := Label.new()
	header.text = title_text
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.75, 0.55, 0.95, 1.0))
	_rune_content.add_child(header)


func _add_rune_card(rune_def: Dictionary, is_owned: bool, is_equipped: bool) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 0)
	var style := StyleBoxFlat.new()
	var rarity: String = str(rune_def.get("rarity", "common"))
	var border_color: Color = RuneDefs.RARITY_COLORS.get(rarity, Color(0.5, 0.5, 0.5))
	style.bg_color = Color(0.08, 0.10, 0.15, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = border_color if is_owned else Color(0.2, 0.2, 0.25, 0.5)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# 符文名 + 状态标记
	var rune_id: String = rune_def.get("id", "")
	var rune_name: String = RuneDefs.RUNE_NAMES.get(rune_id, rune_id)
	var rarity_name: String = RuneDefs.RARITY_NAMES.get(rarity, "未知") as String
	var category_name: String = _rune_category_name(rune_def.get("category", ""))
	var status: String = ""
	if is_equipped:
		status = " [已装备]"
	elif is_owned:
		status = " [已获得]"
	else:
		status = " [未获得]"

	# v6.2: 符文专属图标缩略图（未获得的半透明，与文字状态色一致）
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = UiAssetLoader.rune_icon(rune_id)
	icon_rect.modulate = border_color if is_owned else Color(0.4, 0.4, 0.45, 0.5)
	hbox.add_child(icon_rect)

	var name_lbl := Label.new()
	name_lbl.text = "%s  (%s·%s)%s" % [rune_name, category_name, rarity_name, status]
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", border_color if is_owned else Color(0.4, 0.4, 0.45))
	name_lbl.custom_minimum_size = Vector2(300, 0)
	hbox.add_child(name_lbl)

	# 效果说明
	var effect_lbl := Label.new()
	var primary: String = str(rune_def.get("desc_primary", ""))
	var secondary: String = str(rune_def.get("desc_secondary", ""))
	var effect_text: String = primary
	if not secondary.is_empty():
		effect_text += " / " + secondary
	effect_lbl.text = effect_text
	effect_lbl.add_theme_font_size_override("font_size", 11)
	effect_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8) if is_owned else Color(0.35, 0.35, 0.4))
	effect_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(effect_lbl)

	_rune_content.add_child(panel)


func _add_runeword_card(rw_def: Dictionary, owned_runes: Array) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var tier: int = int(rw_def.get("tier", 2))
	var tier_color: Color = RunewordDefs.TIER_COLORS.get(tier, Color(0.6, 0.6, 0.6))
	# 检查玩家是否拥有全部所需符文
	var required: Array = rw_def.get("required_runes", [])
	var has_all: bool = true
	for rid in required:
		if not owned_runes.has(str(rid)):
			has_all = false
			break
	style.bg_color = Color(0.08, 0.06, 0.14, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = tier_color if has_all else Color(0.2, 0.2, 0.25, 0.5)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# 名称行
	var rw_id: String = rw_def.get("id", "")
	var rw_name: String = RunewordDefs.RUNEWORD_NAMES.get(rw_id, rw_id) as String
	var tier_name: String = RunewordDefs.TIER_NAMES.get(tier, "未知") as String
	var status_str: String = " [可激活]" if has_all else " [符文不足]"
	var name_lbl := Label.new()
	name_lbl.text = "★ %s  (%s·%d符文)%s" % [rw_name, tier_name, required.size(), status_str]
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", tier_color if has_all else Color(0.4, 0.4, 0.45))
	vbox.add_child(name_lbl)

	# 所需符文行
	var runes_str: String = ""
	for rid in required:
		if not runes_str.is_empty():
			runes_str += " + "
		runes_str += RuneDefs.RUNE_NAMES.get(str(rid), str(rid))
	var req_lbl := Label.new()
	req_lbl.text = "所需符文：%s" % runes_str
	req_lbl.add_theme_font_size_override("font_size", 10)
	req_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	vbox.add_child(req_lbl)

	# 效果行
	var effect_lbl := Label.new()
	effect_lbl.text = RunewordDefs.get_effects_description(rw_id)
	effect_lbl.add_theme_font_size_override("font_size", 11)
	effect_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85) if has_all else Color(0.35, 0.35, 0.4))
	effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(effect_lbl)

	_rune_content.add_child(panel)


func _rune_category_name(category: String) -> String:
	match category:
		"attack": return "攻击"
		"defense": return "防御"
		"energy": return "能量"
		"mobility": return "机动"
		"special": return "特殊"
	return "未知"


func _on_close() -> void:
	_on_detail_back()
	closed.emit()
