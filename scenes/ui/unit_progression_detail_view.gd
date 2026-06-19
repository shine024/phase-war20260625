extends PanelContainer
class_name UnitProgressionDetailView

## 单位进化/养成详情（情报中心 V3 子页）

signal back_pressed
signal open_progression_requested(card_id: String)

const DefaultCards = preload("res://data/default_cards.gd")
const UnitLineageConfig = preload("res://data/unit_lineage_config.gd")
const StarConfig = preload("res://data/blueprint_star_config.gd")
const CardProgressionSettings = preload("res://data/card_progression_settings.gd")
const CompanyDefinitions = preload("res://data/company_definitions.gd")
const EvolutionGraphBuilder = preload("res://scripts/progression/evolution_graph_builder.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")

var _card_id: String = ""
var _scroll: ScrollContainer
var _content: VBoxContainer
var _back_btn: Button
var _progression_btn: Button


func _ready() -> void:
	_build_ui()
	visible = false


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)

	_back_btn = Button.new()
	_back_btn.text = "← 返回总图"
	_back_btn.pressed.connect(func() -> void: back_pressed.emit())
	top.add_child(_back_btn)

	_progression_btn = Button.new()
	_progression_btn.text = "前往成长面板"
	_progression_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progression_btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progression_btn.pressed.connect(_on_progression_pressed)
	top.add_child(_progression_btn)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	_scroll.add_child(_content)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.14, 0.96)
	style.border_color = Color(0.22, 0.42, 0.65, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)


func show_card(card_id: String) -> void:
	_card_id = card_id
	visible = true
	_rebuild_content()


func hide_detail() -> void:
	_card_id = ""
	visible = false


func get_card_id() -> String:
	return _card_id


func _on_progression_pressed() -> void:
	if not _card_id.is_empty():
		open_progression_requested.emit(_card_id)


func _rebuild_content() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()

	if _card_id.is_empty():
		_add_line("未选择单位", Color(0.6, 0.65, 0.75))
		return

	var card: CardResource = DefaultCards.get_card_by_id(_card_id)
	var title: String = card.display_name if card != null else _card_id
	_add_line(title, Color(0.0, 0.92, 1.0), 18)

	if card != null:
		var icon_path: String = UiAssetLoader.card_icon_path_for(card)
		var tex: Texture2D = UiAssetLoader.load_tex(icon_path)
		if tex != null:
			var tex_rect := TextureRect.new()
			tex_rect.texture = tex
			tex_rect.custom_minimum_size = Vector2(64, 64)
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_content.add_child(tex_rect)
		if not String(card.type_line).is_empty():
			_add_line(String(card.type_line), Color(0.65, 0.72, 0.82), 12)
		if not String(card.summary_line).is_empty():
			_add_line(String(card.summary_line), Color(0.75, 0.8, 0.88), 12)

	_add_separator()
	_add_predecessor_block()
	_add_separator()
	_add_progress_block()
	_add_separator()
	_add_forward_evolution_block()


func _add_progress_block() -> void:
	_add_line("当前养成", Color(0.55, 0.82, 1.0), 14)
	if BlueprintManager == null:
		_add_line("蓝图系统未就绪", Color(0.7, 0.5, 0.5))
		return
	var star: int = BlueprintManager.get_blueprint_star(_card_id) if BlueprintManager.has_method("get_blueprint_star") else 1
	var mod_count: int = BlueprintManager.get_modification_count(_card_id) if BlueprintManager.has_method("get_modification_count") else 0
	var unlocked: bool = EvolutionGraphBuilder.is_blueprint_unlocked(_card_id)
	_add_line("蓝图：%s" % ("已解锁" if unlocked else "未解锁"), Color(0.8, 0.85, 0.9))
	_add_line("星级：%d / %d" % [star, CardProgressionSettings.STAR_MAX], Color(0.9, 0.88, 0.55))
	_add_line("改装：%d / %d" % [mod_count, CardProgressionSettings.MOD_MAX], Color(0.85, 0.75, 1.0))
	if BlueprintManager.has_method("get_rank_info"):
		var rank_info: Dictionary = BlueprintManager.get_rank_info(_card_id)
		_add_line(
			"军衔：%s（战力 %d）" % [
					String(rank_info.get("rank_name", "未定级")),
					int(float(rank_info.get("power_score", 0.0))),
				],
			Color(0.95, 0.85, 0.45)
		)
	var rarity: String = "common"
	if DefaultCards.get_card_by_id(_card_id) != null:
		rarity = String(DefaultCards.get_card_by_id(_card_id).rarity).to_lower()
	var next_rp: int = StarConfig.get_research_cost_for_next_star(star, rarity) if star < CardProgressionSettings.STAR_MAX else 0
	if next_rp > 0:
		_add_line("下一星研究点：%d" % next_rp, Color(0.7, 0.65, 0.95))


func _add_predecessor_block() -> void:
	_add_line("进化来源", Color(0.55, 0.82, 1.0), 14)
	var preds: Array[Dictionary] = EvolutionGraphBuilder.get_predecessors(_card_id)
	if preds.is_empty():
		_add_line("初始单位：本时代列起点，无上一级进化来源", Color(0.65, 0.72, 0.82))
		return
	for p in preds:
		var from_id: String = String(p.get("from_id", ""))
		var from_name: String = String(p.get("from_label", from_id))
		var stage_label: String = String(p.get("stage_label", ""))
		var era_idx: int = EvolutionGraphBuilder.infer_era_index(from_id)
		var era_name: String = EvolutionGraphBuilder.ERA_LABELS[era_idx] if era_idx < EvolutionGraphBuilder.ERA_LABELS.size() else ""
		_add_line("← %s" % from_name, Color(0.85, 0.92, 0.7), 13)
		_add_line("  %s · 前置时代：%s" % [stage_label, era_name], Color(0.6, 0.68, 0.78), 11)


func _add_forward_evolution_block() -> void:
	_add_line("可进化至", Color(0.55, 0.82, 1.0), 14)
	if not UnitLineageConfig.has_lineage(_card_id):
		_add_line("该单位无后续进化出口（终局或法则单位）", Color(0.6, 0.65, 0.75))
		return
	if BlueprintManager == null or not BlueprintManager.has_method("get_evolution_options"):
		_add_line("进化系统未启用", Color(0.7, 0.5, 0.5))
		return

	var opts: Dictionary = BlueprintManager.get_evolution_options(_card_id)
	var e1: String = String(opts.get("evolution_1", ""))
	if not e1.is_empty():
		_add_evolution_target("E1 · 同体系", e1, "base")
	var branches: Dictionary = opts.get("faction_branches", {})
	if e1.is_empty() and branches.is_empty():
		_add_line("暂无可进化路线", Color(0.6, 0.65, 0.75))
		return
	for faction_id in branches.keys():
		var tid: String = String(branches[faction_id])
		if tid.is_empty():
			continue
		var fname: String = EvolutionGraphBuilder.faction_display_name(String(faction_id))
		_add_evolution_target("E2 · %s" % fname, tid, String(faction_id))

	_add_line("传承比例：%.0f%% · 进化后改装重置" % (UnitLineageConfig.DEFAULT_INHERIT_RATIO * 100.0), Color(0.65, 0.7, 0.78), 11)


func _add_evolution_target(stage_label: String, target_id: String, faction_id: String) -> void:
	var target_card: CardResource = DefaultCards.get_card_by_id(target_id)
	var target_name: String = target_card.display_name if target_card != null else target_id
	var can_info: Dictionary = BlueprintManager.can_evolve_blueprint(_card_id, target_id)
	var ok: bool = bool(can_info.get("ok", false))
	var reason: String = String(can_info.get("reason_zh", UnitLineageConfig.localize_evolve_reason(String(can_info.get("reason", "")))))
	var enhance_req: int = int(can_info.get("enhance_requirement", 0))
	var mod_req: int = int(can_info.get("mod_requirement", 0))
	var status_col := Color(0.55, 0.95, 0.65) if ok else Color(0.95, 0.55, 0.45)
	var status_text: String = "可进化" if ok else "未满足：%s" % reason
	_add_line("%s → %s" % [stage_label, target_name], Color(0.85, 0.9, 0.95), 13)
	_add_line("  需 强化Lv%d · %d个MOD · %s" % [enhance_req, mod_req, status_text], status_col, 11)


func _add_separator() -> void:
	var sep := HSeparator.new()
	_content.add_child(sep)


func _add_line(text: String, col: Color, font_size: int = 13) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", font_size)
	_content.add_child(lbl)
