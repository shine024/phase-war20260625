extends PanelContainer
## 成长面板 - 2x2 网格布局 (严格按 HTML 预览 v3)

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const StarConfig = preload("res://data/blueprint_star_config.gd")
const ModRegistry = preload("res://scripts/systems/modification_registry.gd")
const ModSlotScene: PackedScene = preload("res://scenes/ui/mod_slot_item.tscn")
const EvoPathRegistry = preload("res://scripts/systems/evolution_path_registry.gd")

signal closed

var _anim_duration: float = 0.25
var _is_open: bool = false
var _selected_card: CardResource = null
var _last_unlocked_ids: Array[String] = []

# M1: 缓存 StyleBox
var _tag_stylebox: StyleBoxFlat

# ---- Header 区域 ----
var unit_name_label: Label
var unit_subtitle_label: Label
var era_badge: Label
var stat_tags: HBoxContainer
var stars_row_container: HBoxContainer
var star_count_label: Label
var close_btn: Button
var portrait_icon: Label

# ---- 星级强化区块 ----
var star_level_label: Label
var star_stars_container: HBoxContainer
var star_progress_bar: ProgressBar
var star_xp_text: Label
var star_cost_text: Label

# ---- 卡牌强化区块 ----
var enhance_level_label: Label
var enhance_progress_bar: ProgressBar
var stat_atk_label: Label
var stat_def_label: Label
var stat_hp_label: Label
var stat_misc_label: Label

# ---- MOD 区块 ----
var mod_count_label: Label
var mod_grid: GridContainer

# ---- 进化区块 ----
var evo_status_label: Label
var evo_current_icon: Label
var evo_current_name: Label
var evo_current_lv: Label
var evo_target_icon: Label
var evo_target_name: Label
var evo_target_lv: Label
var evo_requirements_label: RichTextLabel
var evo_requirements_panel: PanelContainer

# ---- Footer ----
var currency_labels: Array[Label]
var apply_btn: Button

# ---- 卡牌列表 ----
var card_list_container: VBoxContainer
var card_list_scroll: ScrollContainer
var card_list_hint: Label
var footer_res_labels: Array[Label]

func _ready() -> void:
	visible = false
	modulate.a = 0.0

	# M1: 预缓存 StyleBox
	_init_cached_styleboxes()

	# Header
	unit_name_label = get_node_or_null("%UnitName")
	unit_subtitle_label = get_node_or_null("%Subtitle")
	era_badge = get_node_or_null("%EraBadge")
	stat_tags = get_node_or_null("%TagsContainer")
	stars_row_container = get_node_or_null("%StarsRow")
	star_count_label = get_node_or_null("%StarCountLabel")
	close_btn = get_node_or_null("%CloseBtn")
	portrait_icon = get_node_or_null("%PortraitIcon")

	# 星级强化区块
	star_level_label = get_node_or_null("%StarLevel")
	star_stars_container = get_node_or_null("%StarStars")
	star_progress_bar = get_node_or_null("%StarProgress")
	star_xp_text = get_node_or_null("%StarXpText")
	star_cost_text = get_node_or_null("%StarCostText")

	# 卡牌强化区块
	enhance_level_label = get_node_or_null("%EnhanceLevel")
	enhance_progress_bar = get_node_or_null("%EnhanceProgress")
	stat_atk_label = get_node_or_null("%AtkValues")
	stat_def_label = get_node_or_null("%DefValues")
	stat_hp_label = get_node_or_null("%HpValues")
	stat_misc_label = get_node_or_null("%MiscValues")

	# MOD
	mod_count_label = get_node_or_null("%ModCountLabel")
	mod_grid = get_node_or_null("%ModGrid")

	# 进化
	evo_status_label = get_node_or_null("%EvoStatusLabel")
	evo_current_icon = get_node_or_null("%EvoCurrentIcon")
	evo_current_name = get_node_or_null("%EvoCurrentName")
	evo_current_lv = get_node_or_null("%EvoCurrentLv")
	evo_target_icon = get_node_or_null("%EvoTargetIcon")
	evo_target_name = get_node_or_null("%EvoTargetName")
	evo_target_lv = get_node_or_null("%EvoTargetLv")
	evo_requirements_label = get_node_or_null("%EvoReqInner")
	evo_requirements_panel = get_node_or_null("%EvoRequirements")

	# P1: Footer
	currency_labels = [
		get_node_or_null("%F_C1"),
		get_node_or_null("%F_C2"),
		get_node_or_null("%F_C3"),
		get_node_or_null("%F_C4"),
	]
	apply_btn = get_node_or_null("%ApplyBtn")
	if apply_btn:
		apply_btn.pressed.connect(_on_apply_pressed)

	# 卡牌列表
	card_list_container = get_node_or_null("%CardListContainer")
	card_list_scroll = get_node_or_null("%CardListScroll")
	card_list_hint = get_node_or_null("%CardListHint")
	footer_res_labels = [
		get_node_or_null("%FooterRes1"),
		get_node_or_null("%FooterRes2"),
		get_node_or_null("%FooterRes3"),
	]

	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)

	print("[GrowthPanel] _ready OK")

	# 视觉样式美化
	_apply_visual_styles()

# ========== 视觉样式方法 ==========

func _apply_visual_styles() -> void:
	# --- 主面板 ---
	var panel = self as PanelContainer
	if panel:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.043, 0.055, 0.102, 1)
		sb.border_color = Color(0.29, 0.561, 0.851, 0.25)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 8.0
		sb.content_margin_top = 8.0
		sb.content_margin_right = 8.0
		sb.content_margin_bottom = 8.0
		panel.add_theme_stylebox_override("panel", sb)

	# --- 卡牌列表列背景 ---
	var clp = get_node_or_null("%CardListPanel")
	if clp:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.043, 0.063, 0.125, 1)
		sb.border_color = Color(0.29, 0.561, 0.851, 0.15)
		sb.border_width_right = 1
		sb.content_margin_left = 0
		sb.content_margin_top = 0
		sb.content_margin_right = 0
		sb.content_margin_bottom = 0
		clp.add_theme_stylebox_override("panel", sb)

	# --- Header背景 ---
	var hdr = get_node_or_null("%DetailHeader")
	if hdr:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.059, 0.086, 0.145, 1)
		sb.border_color = Color(0.29, 0.561, 0.851, 0.8)
		sb.border_width_top = 2
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		hdr.add_theme_stylebox_override("panel", sb)

	# --- 头像框 ---
	var port = get_node_or_null("%Portrait")
	if port:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.102, 0.157, 0.267, 1)
		sb.border_color = Color(0.29, 0.561, 0.851, 0.8)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 0
		sb.content_margin_top = 0
		sb.content_margin_right = 0
		sb.content_margin_bottom = 0
		port.add_theme_stylebox_override("panel", sb)

	# --- 关闭按钮 ---
	var cbtn = get_node_or_null("%CloseBtn")
	if cbtn:
		var sb_n = StyleBoxFlat.new()
		sb_n.bg_color = Color(0.15, 0.15, 0.15, 0.4)
		sb_n.border_color = Color(0.8, 0.8, 0.8, 0.12)
		sb_n.set_border_width_all(1)
		sb_n.set_corner_radius_all(4)
		cbtn.add_theme_stylebox_override("normal", sb_n)
		var sb_h = StyleBoxFlat.new()
		sb_h.bg_color = Color(0.8, 0.2, 0.2, 0.15)
		sb_h.border_color = Color(1.0, 0.3, 0.3, 0.4)
		sb_h.set_border_width_all(1)
		sb_h.set_corner_radius_all(4)
		cbtn.add_theme_stylebox_override("hover", sb_h)

	# --- 4个区块背景 ---
	_setup_section_style("%StarSection")
	_setup_section_style("%EnhanceSection")
	_setup_section_style("%ModSection2")
	_setup_section_style("%EvoSection2")

	# --- 属性格卡片 ---
	_setup_stat_card("%AtkCard", Color(0.9, 0.3, 0.3, 0.6))
	_setup_stat_card("%DefCard", Color(0.3, 0.5, 0.9, 0.6))
	_setup_stat_card("%HpCard", Color(0.3, 0.8, 0.4, 0.6))
	_setup_stat_card("%MiscCard", Color(0.3, 0.8, 0.9, 0.6))

	# --- 应用按钮 ---
	var abtn = get_node_or_null("%ApplyBtn")
	if abtn:
		abtn.add_theme_font_size_override("font_size", 10)
		abtn.add_theme_color_override("font_color", Color(0.91, 0.93, 0.96, 1))
		abtn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		abtn.custom_minimum_size = Vector2(100, 28)

	# --- 进度条极细 ---
	var sp = get_node_or_null("%StarProgress")
	if sp:
		sp.custom_minimum_size = Vector2(0, 3)
	var ep = get_node_or_null("%EnhanceProgress")
	if ep:
		ep.custom_minimum_size = Vector2(0, 3)

	# --- 标签样式 ---
	if _tag_stylebox:
		_tag_stylebox.bg_color = Color(0.29, 0.561, 0.851, 0.1)
		_tag_stylebox.border_color = Color(0.29, 0.561, 0.851, 0.25)
		_tag_stylebox.set_corner_radius_all(2)
		_tag_stylebox.content_margin_left = 6
		_tag_stylebox.content_margin_top = 1
		_tag_stylebox.content_margin_right = 6
		_tag_stylebox.content_margin_bottom = 1

func _setup_section_style(panel_name: String) -> void:
	var sec = get_node_or_null(panel_name)
	if not sec:
		return
	var p = sec as PanelContainer
	if p:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.067, 0.094, 0.153, 1)
		sb.border_color = Color(0, 0, 0, 0)
		sb.set_border_width_all(0)
		sb.content_margin_left = 12
		sb.content_margin_top = 8
		sb.content_margin_right = 12
		sb.content_margin_bottom = 8
		p.add_theme_stylebox_override("panel", sb)

func _setup_stat_card(panel_name: String, border_color: Color) -> void:
	var c = get_node_or_null(panel_name)
	if not c:
		return
	var p = c as PanelContainer
	if p:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.137, 0.2, 0.3)
		sb.border_color = border_color
		sb.border_width_left = 2
		sb.border_width_top = 0
		sb.border_width_right = 0
		sb.border_width_bottom = 0
		sb.set_corner_radius_all(2)
		sb.content_margin_left = 6.0
		sb.content_margin_top = 4.0
		sb.content_margin_right = 6.0
		sb.content_margin_bottom = 4.0
		p.add_theme_stylebox_override("panel", sb)

# ========== 打开/关闭 ==========

func show_panel(card: CardResource) -> void:
	if _is_open:
		return
	_is_open = true
	_selected_card = card
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.92, 0.92)
	_load_unlocked_cards()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, _anim_duration).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), _anim_duration).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(func(): _refresh_data())

func _load_unlocked_cards() -> void:
	var bp = get_node_or_null("/root/BlueprintManager")
	if not bp:
		return
	var unlocked_ids: Array[String] = []
	if bp.has_method("get_all_blueprint_ids"):
		for id in bp.get_all_blueprint_ids():
			unlocked_ids.append(String(id))
	else:
		for id in bp.get_unlocked_blueprint_ids():
			unlocked_ids.append(String(id))
	_last_unlocked_ids = unlocked_ids
	refresh_card_list(unlocked_ids)
	if not _selected_card and not unlocked_ids.is_empty():
		var first_card = DefaultCards.get_card_by_id(unlocked_ids[0])
		if first_card:
			_selected_card = first_card

func hide_panel() -> void:
	if not _is_open:
		return
	_is_open = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, _anim_duration).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "scale", Vector2(0.92, 0.92), _anim_duration).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		visible = false
		print("[GrowthPanel] hide_panel complete")
	)
	closed.emit()

# P4: 实际保存逻辑
func _on_apply_pressed() -> void:
	if not _selected_card:
		return
	var bp = get_node_or_null("/root/BlueprintManager")
	if bp:
		if bp.has_method("save_card_weapon_slots"):
			bp.save_card_weapon_slots(_selected_card)
	# 通知其他系统
	var sb = get_node_or_null("/root/SignalBus")
	if sb and sb.has_signal("growth_panel_saved"):
		sb.growth_panel_saved.emit(_selected_card)
	if sb and sb.has_signal("card_data_changed"):
		sb.card_data_changed.emit(_selected_card.card_id)
	print("[GrowthPanel] 应用保存完成: %s" % _selected_card.card_id)

func _on_close_pressed() -> void:
	print("[GrowthPanel] 关闭按钮按下")
	hide_panel()

# ========== 卡牌列表 ==========

func refresh_card_list(unlocked_ids: Array[String]) -> void:
	if not card_list_container:
		return
	for child in card_list_container.get_children():
		child.queue_free()

	if unlocked_ids.is_empty():
		if card_list_hint:
			card_list_hint.visible = true
		return

	if card_list_hint:
		card_list_hint.visible = false

	for i in range(unlocked_ids.size()):
		var card_id: String = unlocked_ids[i]
		var card = DefaultCards.get_card_by_id(card_id)
		if not card:
			continue

		# 卡牌列表项：PanelContainer 包裹 VBoxContainer
		var item_panel := PanelContainer.new()
		item_panel.custom_minimum_size = Vector2(0, 34)
		item_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var item_sb := StyleBoxFlat.new()
		item_sb.bg_color = Color(0, 0, 0, 0)
		item_sb.border_color = Color(0, 0, 0, 0)
		item_sb.set_border_width_all(0)
		item_sb.set_corner_radius_all(3)
		item_sb.content_margin_left = 8
		item_sb.content_margin_top = 5
		item_sb.content_margin_right = 8
		item_sb.content_margin_bottom = 5
		item_panel.add_theme_stylebox_override("panel", item_sb)

		var item_vbox := VBoxContainer.new()
		item_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_vbox.add_theme_constant_override("separation", 1)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 22)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_color_override("font_color", Color(0.75, 0.8, 0.87))
		btn.add_theme_color_override("font_hover_color", Color(0.0, 0.9, 0.46))
		btn.text = card.display_name if card.display_name else card.card_id

		# 选中高亮
		if _selected_card and _selected_card.card_id == card_id:
			btn.add_theme_color_override("font_color", Color(0.0, 0.9, 0.46))
			var highlight_sb := StyleBoxFlat.new()
			highlight_sb.bg_color = Color(0.29, 0.561, 0.851, 0.12)
			highlight_sb.border_color = Color(0.29, 0.561, 0.851, 0.4)
			highlight_sb.set_border_width_all(1)
			highlight_sb.set_corner_radius_all(3)
			highlight_sb.content_margin_left = 8
			highlight_sb.content_margin_top = 5
			highlight_sb.content_margin_right = 8
			highlight_sb.content_margin_bottom = 5
			item_panel.add_theme_stylebox_override("panel", highlight_sb)

		# 星星 + 等级 meta 行
		var meta_row := HBoxContainer.new()
		meta_row.add_theme_constant_override("separation", 3)
		var star_count: int = StarConfig.calculate_star(card.enhance_level * 2, card.rarity)
		var star_str = ""
		for s in range(5):
			star_str += "\u2605" if s < star_count else "\u2606"
		var star_label := Label.new()
		star_label.text = star_str
		star_label.add_theme_font_size_override("font_size", 7)
		star_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 0.7))
		meta_row.add_child(star_label)
		var level_label := Label.new()
		level_label.text = "Lv.%d" % card.enhance_level
		level_label.add_theme_font_size_override("font_size", 7)
		level_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.6))
		meta_row.add_child(level_label)

		item_vbox.add_child(btn)
		item_vbox.add_child(meta_row)

		item_panel.add_child(item_vbox)
		btn.pressed.connect(_on_card_selected.bind(card))
		card_list_container.add_child(item_panel)

	# M5: 底部资源实际更新
	_refresh_card_list_footer(unlocked_ids)

func _refresh_card_list_footer(unlocked_ids: Array[String]) -> void:
	if footer_res_labels.size() < 3:
		return
	var res_mgr = get_node_or_null("/root/BasicResourceManager")
	if not res_mgr:
		return
	var res_ids := ["res_nano", "res_alloy", "res_crystal"]
	var res_symbols := ["\u26A1", "\U0001F529", "\U0001F48E"]
	var res_names := ["纳米", "合金", "晶体"]
	for i in range(mini(3, footer_res_labels.size())):
		if footer_res_labels[i]:
			var amt: int = res_mgr.get_total(res_ids[i])
			footer_res_labels[i].text = "%s %s" % [res_symbols[i], _format_number(amt)]

func _on_card_selected(card: CardResource) -> void:
	_selected_card = card
	if not _last_unlocked_ids.is_empty():
		refresh_card_list(_last_unlocked_ids)
	select_card(card)

# ========== 旧方法（兼容） ==========

func select_card_by_id(card_id: String) -> void:
	if card_id.is_empty():
		return
	var card = DefaultCards.get_card_by_id(card_id)
	if card:
		_selected_card = card
		if visible:
			_refresh_data()

func select_card(card: CardResource) -> void:
	_selected_card = card
	if visible:
		_refresh_data()

# ========== 数据刷新 ==========

func _refresh_data() -> void:
	if not _selected_card:
		return
	_refresh_header()
	_refresh_star_section()
	_refresh_enhance_section()
	_refresh_mod_section()
	_refresh_evolution_section()
	_refresh_footer()

# ---------- Header ----------

func _refresh_header() -> void:
	var c := _selected_card
	if not c:
		return

	# 头像图标和边框
	if portrait_icon:
		portrait_icon.text = _get_unit_icon(c)
		var portrait_panel = get_node_or_null("%Portrait")
		if portrait_panel:
			var icon_sb := StyleBoxFlat.new()
			icon_sb.bg_color = Color(0.102, 0.157, 0.267, 1)
			icon_sb.border_color = _get_kind_color(c.combat_kind)
			icon_sb.set_border_width_all(2)
			icon_sb.set_corner_radius_all(8)
			portrait_panel.add_theme_stylebox_override("panel", icon_sb)

	if unit_name_label:
		unit_name_label.text = c.card_id.to_upper()
	if unit_subtitle_label:
		unit_subtitle_label.text = c.display_name
	if era_badge:
		var era_name = GameConstants.get_era_name(c.era)
		era_badge.text = era_name if era_name else ""

	# 标签
	if stat_tags:
		for child in stat_tags.get_children():
			child.queue_free()
		if c.card_type == GC.CardType.COMBAT_UNIT:
			var kind_tag := Label.new()
			kind_tag.text = CardResource.get_combat_kind_name(c.combat_kind)
			kind_tag.add_theme_font_size_override("font_size", 11)
			kind_tag.add_theme_stylebox_override("normal", _tag_stylebox)
			stat_tags.add_child(kind_tag)

			if c.weapon_type == GC.WeaponType.DIRECT:
				_add_tag("直射")
			elif c.weapon_type == GC.WeaponType.INDIRECT:
				_add_tag("曲射")
			elif c.weapon_type == GC.WeaponType.AERIAL:
				_add_tag("空射")
			else:
				_add_tag("辅助")

			if c.range_value > 0:
				_add_tag("射程 %d" % c.range_value)
			_add_tag("能量 %.0f" % c.energy_cost)

	# 星星
	if stars_row_container:
		for child in stars_row_container.get_children():
			child.queue_free()
		var star: int = _calculate_star()
		for idx in range(5):
			var s := Label.new()
			s.add_theme_font_size_override("font_size", 18)
			s.custom_minimum_size = Vector2(22, 22)
			s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if idx < star:
				s.text = "\u2605"
				s.modulate = Color(1.0, 0.84, 0.0)
				s.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
			else:
				s.text = "\u2606"
				s.modulate = Color(0.333, 0.4, 0.467)
			stars_row_container.add_child(s)

	if star_count_label:
		star_count_label.text = "%d/5" % _calculate_star()

# ---------- 星级强化 ----------

func _refresh_star_section() -> void:
	if not _selected_card:
		return
	var star: int = _calculate_star()

	if star_level_label:
		star_level_label.text = "LV.%d" % star

	if star_stars_container:
		for child in star_stars_container.get_children():
			child.queue_free()
		for idx in range(5):
			var s := Label.new()
			s.add_theme_font_size_override("font_size", 12)
			if idx < star:
				s.text = "\u2605"
				s.modulate = Color(1.0, 0.84, 0.0)
			else:
				s.text = "\u2606"
				s.modulate = Color(0.333, 0.4, 0.467)
			star_stars_container.add_child(s)

	if star_progress_bar:
		star_progress_bar.value = (float(mini(star, 5)) / 5.0) * 100.0

	var next_cost := StarConfig.get_research_cost_for_next_star(star, _selected_card.rarity)

	# 真实 XP 数据
	if star_xp_text:
		var bp = get_node_or_null("/root/BlueprintManager")
		if bp and bp.has_method("get_star_progress"):
			var progress: Dictionary = bp.get_star_progress(_selected_card.card_id)
			var cur_rp: int = int(progress.get("current_research", 0))
			var need_rp: int = int(progress.get("next_star_research", next_cost))
			if need_rp <= 0:
				star_xp_text.text = "已满星"
			else:
				star_xp_text.text = "%s / %s 研究点" % [_format_number(cur_rp), _format_number(need_rp)]
		else:
			if next_cost <= 0:
				star_xp_text.text = "已满星"
			else:
				star_xp_text.text = "下一星需 %s 研究点" % _format_number(next_cost)

	if star_cost_text:
		if next_cost <= 0:
			star_cost_text.text = "已达最高星级"
		else:
			var alloy_cost: int = maxi(1, int(next_cost * 0.2))
			var crystal_cost: int = maxi(1, int(next_cost * 0.15))
			star_cost_text.text = "下一星: 合金×%s · 晶体×%s" % [_format_number(alloy_cost), _format_number(crystal_cost)]

# ---------- 卡牌强化 ----------

func _refresh_enhance_section() -> void:
	var c := _selected_card
	if not c:
		return

	if enhance_level_label:
		enhance_level_label.text = "Lv.%d/10" % c.enhance_level

	if enhance_progress_bar:
		enhance_progress_bar.value = (float(c.enhance_level) / 10.0) * 100.0

	var base_stats := _get_base_stats()
	var enhanced_stats := _get_enhanced_stats()

	if stat_atk_label:
		stat_atk_label.text = "轻%.0f / 甲%.0f / 空%.0f%s" % [
			float(enhanced_stats.get("atk_light", 0)),
			float(enhanced_stats.get("atk_armor", 0)),
			float(enhanced_stats.get("atk_air", 0)),
			_get_stat_delta(float(base_stats.get("atk_light", 0)), float(enhanced_stats.get("atk_light", 0)))]
	if stat_def_label:
		stat_def_label.text = "轻%.0f / 甲%.0f / 空%.0f%s" % [
			float(enhanced_stats.get("def_light", 0)),
			float(enhanced_stats.get("def_armor", 0)),
			float(enhanced_stats.get("def_air", 0)),
			_get_stat_delta(float(base_stats.get("def_light", 0)), float(enhanced_stats.get("def_light", 0)))]
	if stat_hp_label:
		stat_hp_label.text = "%.0f%s" % [
			float(enhanced_stats.get("hp", 0)),
			_get_stat_delta(float(base_stats.get("hp", 0)), float(enhanced_stats.get("hp", 0)))]
	if stat_misc_label:
		# V2: 加入移速显示
		stat_misc_label.text = "射程 %d | 攻速 %.1f | 移速 %.1f" % [
			int(enhanced_stats.get("range", c.range_value)),
			float(enhanced_stats.get("atk_speed", c.attack_speed)),
			float(enhanced_stats.get("speed", c.base_speed))]

# ---------- MOD ----------

func _refresh_mod_section() -> void:
	if not mod_grid or not _selected_card:
		return
	for child in mod_grid.get_children():
		child.queue_free()

	var mod_list: Array = _selected_card.mods
	var filled: int = mini(mod_list.size(), 9)
	if mod_count_label:
		mod_count_label.text = "%d/9" % filled

	for idx in range(9):
		if idx < filled:
			var slot: Control = ModSlotScene.instantiate()
			slot.custom_minimum_size = Vector2(80, 56)
			slot.modulate.a = 1.0
			mod_grid.add_child(slot)
			if slot.has_method("set_slot_index"):
				slot.set_slot_index(idx + 1)
			var mod_data: Dictionary = {}
			var entry = mod_list[idx]
			if entry is Dictionary:
				mod_data = entry
			elif entry is String:
				var entry_str: String = String(entry)
				var md: Dictionary = ModRegistry.get_data(entry_str)
				mod_data = {"id": entry_str, "name": md.get("display_name", entry_str), "level": 1, "tier": "A"}
			if slot.has_method("set_mod"):
				slot.set_mod(mod_data)
		else:
			# 空槽位 - 虚线边框
			var placeholder := PanelContainer.new()
			placeholder.custom_minimum_size = Vector2(80, 56)
			placeholder.name = "PlaceholderSlot"
			var placeholder_sb := StyleBoxFlat.new()
			placeholder_sb.bg_color = Color(0.1, 0.137, 0.2, 0.15)
			placeholder_sb.border_color = Color(1, 1, 1, 0.05)
			placeholder_sb.set_border_width_all(1)
			placeholder_sb.set_corner_radius_all(3)
			# 虚线效果
			placeholder_sb.draw_center = false
			placeholder.add_theme_stylebox_override("panel", placeholder_sb)
			var plus_label := Label.new()
			plus_label.text = "+"
			plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			plus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			plus_label.add_theme_font_size_override("font_size", 16)
			plus_label.add_theme_color_override("font_color", Color(0.4, 0.5, 0.55, 0.4))
			placeholder.add_child(plus_label)
			mod_grid.add_child(placeholder)

# ---------- 进化 ----------

func _refresh_evolution_section() -> void:
	var c := _selected_card
	if not c:
		return
	var evo_paths: Array = c.evolution_paths

	if evo_current_icon:
		evo_current_icon.text = "\u2694"
	if evo_current_name:
		evo_current_name.text = c.display_name
	if evo_current_lv:
		evo_current_lv.text = "当前 · Lv.%d" % c.enhance_level

	if evo_target_icon:
		if evo_paths.is_empty():
			evo_target_icon.text = "\U0001F512"
			if evo_status_label:
				evo_status_label.text = "未解锁"
			if evo_target_name:
				evo_target_name.text = "暂无进化路线"
			if evo_target_lv:
				evo_target_lv.text = ""
		else:
			evo_target_icon.text = "\u2694"
			var target_id: String = String(evo_paths[0])
			var target = DefaultCards.get_card_by_id(target_id)
			if target:
				if evo_target_name:
					evo_target_name.text = target.display_name
				if evo_target_lv:
					evo_target_lv.text = CardResource.get_combat_kind_name(target.combat_kind)
				# 高亮目标（非锁定）
				if evo_target_icon:
					evo_target_icon.modulate = Color.WHITE
			else:
				if evo_target_name:
					evo_target_name.text = target_id
				if evo_target_lv:
					evo_target_lv.text = ""

	# 进化条件
	if evo_requirements_label:
		if evo_paths.is_empty():
			evo_requirements_label.text = "无可用进化路线"
			if evo_requirements_panel:
				evo_requirements_panel.visible = false
			return

		if evo_requirements_panel:
			evo_requirements_panel.visible = true

		# 构建分色条件文本
		var parts: Array = []
		var current_power := c.get_current_power()
		var evo_star := _calculate_star()

		# 条件1：星级
		if evo_star >= 4:
			parts.append({"text": "\u2713 星级 \u2265 4", "is_ok": true})
		else:
			parts.append({"text": "\u2717 星级 \u2265 4 (%d)" % evo_star, "is_ok": false})

		# 条件2：战力
		var target_power_val: int = maxi(int(c.base_hp * 1.5), 800)
		if current_power >= target_power_val:
			parts.append({"text": "\u2713 战力 \u2265 %d" % target_power_val, "is_ok": true})
		else:
			parts.append({"text": "\u2717 战力 \u2265 %d (%d)" % [target_power_val, current_power], "is_ok": false})

		# 进化资源条件
		var evo_data: Dictionary = EvoPathRegistry.get_evolution_path(c.card_id)
		if not evo_data.is_empty():
			var main_line = evo_data.get("main_line", {})
			for stage_key in main_line.keys():
				var stage = main_line[stage_key]
				if stage.get("card_id", "") != c.card_id:
					var requirements: Dictionary = stage.get("requirements", {})
					var res_req = requirements.get("resources", {})
					if not res_req.is_empty():
						var alloy_need: int = int(res_req.get("res_alloy", 500))
						var res_mgr = get_node_or_null("/root/BasicResourceManager")
						var has_alloy: int = res_mgr.get_total("res_alloy") if res_mgr else 0
						if has_alloy >= alloy_need:
							parts.append({"text": "\u2713 合金 \u2265 %s" % _format_number(alloy_need), "is_ok": true})
						else:
							parts.append({"text": "\u2717 合金 \u2265 %s (%s)" % [_format_number(alloy_need), _format_number(has_alloy)], "is_ok": false})
					var intel_req = requirements.get("intel_level", 0)
					if intel_req > 0:
						parts.append({"text": "\u2713 素材情报 \u2265 %d" % intel_req, "is_ok": true})
					break
		else:
			parts.append({"text": "\u2717 合金 500", "is_ok": false})

		# 构建带 BBCode 分色的文本
		var bbcode_parts: Array = []
		for part in parts:
			if part.get("is_ok", false):
				bbcode_parts.append("[color=#00E676]%s[/color]" % part.get("text", ""))
			else:
				bbcode_parts.append("[color=#FF9800]%s[/color]" % part.get("text", ""))

		evo_requirements_label.text = "  \u00B7  ".join(bbcode_parts)
		evo_requirements_label.parse_bbcode = true

# ---------- Footer ----------

func _refresh_footer() -> void:
	if currency_labels.size() >= 4:
		var res_mgr = get_node_or_null("/root/BasicResourceManager")
		if res_mgr:
			var ids := ["res_alloy", "res_crystal", "res_nano", "res_permit"]
			var symbols := ["\U0001F529", "\U0001F48E", "\u26A1", "\U0001F4CB"]
			var names := ["合金", "晶体", "纳米", "许可"]
			for i in range(min(4, ids.size())):
				if currency_labels[i]:
					var amt: int = res_mgr.get_total(ids[i])
					currency_labels[i].text = "%s %s %s" % [symbols[i], names[i], _format_number(amt)]

# ========== 辅助 ==========

func _add_tag(text: String) -> void:
	var tag_panel := PanelContainer.new()
	var tag_sb := StyleBoxFlat.new()
	tag_sb.bg_color = Color(0.29, 0.561, 0.851, 0.1)
	tag_sb.border_color = Color(0.29, 0.561, 0.851, 0.25)
	tag_sb.set_corner_radius_all(2)
	tag_sb.content_margin_left = 6
	tag_sb.content_margin_top = 1
	tag_sb.content_right = 6
	tag_sb.content_top = 1
	tag_sb.content_right = 6
	tag_sb.content_bottom = 1
	tag_panel.add_theme_stylebox_override("panel", tag_sb)

	var tag_label := Label.new()
	tag_label.text = text
	tag_label.add_theme_font_size_override("font_size", 11)
	tag_panel.add_child(tag_label)
	stat_tags.add_child(tag_panel)

func _calculate_star() -> int:
	return StarConfig.calculate_star(_selected_card.enhance_level * 2, _selected_card.rarity)

func _get_base_stats() -> Dictionary:
	var c := _selected_card
	return {
		"atk_light": float(c.attack_light),
		"atk_armor": float(c.attack_armor),
		"atk_air": float(c.attack_air),
		"def_light": float(c.defense_light),
		"def_armor": float(c.defense_armor),
		"def_air": float(c.defense_air),
		"hp": float(c.base_hp),
		"range": float(c.range_value),
		"atk_speed": float(c.attack_speed),
		"speed": float(c.base_speed),
	}

func _get_enhanced_stats() -> Dictionary:
	var c := _selected_card
	var mult := 1.0 + (float(c.enhance_level) * 0.08)
	return {
		"atk_light": c.attack_light * mult,
		"atk_armor": c.attack_armor * mult,
		"atk_air": c.attack_air * mult,
		"def_light": c.defense_light * mult,
		"def_armor": c.defense_armor * mult,
		"def_air": c.defense_air * mult,
		"hp": c.base_hp * mult,
		"range": float(c.range_value),
		"atk_speed": float(c.attack_speed),
		"speed": float(c.base_speed),
	}

func _get_stat_delta(base_val: float, enhanced_val: float) -> String:
	var delta := int(enhanced_val - base_val)
	if delta > 0:
		return " \u25B2+%d" % delta
	return ""

func _get_unit_icon(card: CardResource) -> String:
	var kind_names = CardResource.get_combat_kind_name(card.combat_kind)
	match kind_names:
		"步兵": return "\u2694"
		"装甲": return "\U0001F6E1"
		"炮兵": return "\U0001F3AF"
		"防空": return "\U0001F52B"
		"空军": return "\u2708"
		"侦察": return "\U0001F52D"
		"工程": return "\U0001F527"
		"堡垒": return "\U0001F3F0"
		_: return "\u2694"

func _get_kind_color(combat_kind: int) -> Color:
	var kind_names = CardResource.get_combat_kind_name(combat_kind)
	match kind_names:
		"步兵": return Color(0.9, 0.3, 0.3)
		"装甲": return Color(0.3, 0.5, 0.9)
		"炮兵": return Color(0.9, 0.6, 0.2)
		"防空": return Color(0.7, 0.7, 0.3)
		"空军": return Color(0.3, 0.8, 0.9)
		"侦察": return Color(0.5, 0.9, 0.3)
		"工程": return Color(0.6, 0.4, 0.8)
		"堡垒": return Color(0.5, 0.5, 0.5)
		_: return Color(0.5, 0.5, 0.5)

func _format_number(n: int) -> String:
	var s: String = str(n)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result

func _init_cached_styleboxes() -> void:
	_tag_stylebox = StyleBoxFlat.new()
	_tag_stylebox.bg_color = Color(0.29, 0.561, 0.851, 0.1)
	_tag_stylebox.border_color = Color(0.29, 0.561, 0.851, 0.25)
	_tag_stylebox.set_corner_radius_all(2)
	_tag_stylebox.content_margin_left = 6
	_tag_stylebox.content_margin_top = 1
	_tag_stylebox.content_margin_right = 6
	_tag_stylebox.content_margin_bottom = 1
