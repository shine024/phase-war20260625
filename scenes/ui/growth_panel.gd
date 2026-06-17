extends PanelContainer
## 成长面板 - 2x2 网格布局 (严格按 HTML 预览 v3)

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const StarConfig = preload("res://data/blueprint_star_config.gd")
const ModRegistry = preload("res://scripts/systems/modification_registry.gd")
const ModSlotScene: PackedScene = preload("res://scenes/ui/mod_slot_item.tscn")
const EvoPathRegistry = preload("res://scripts/systems/evolution_path_registry.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")

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

# ---- 操作按钮 ----
var enhance_btn: Button
var mod_btn: Button
var evo_btn: Button

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
	if evo_requirements_label:
		evo_requirements_label.bbcode_enabled = true

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

	# 操作按钮
	enhance_btn = get_node_or_null("%EnhanceBtn")
	mod_btn = get_node_or_null("%ModBtn")
	evo_btn = get_node_or_null("%EvoBtn")
	if enhance_btn:
		enhance_btn.pressed.connect(_on_enhance_pressed)
	if mod_btn:
		mod_btn.pressed.connect(_on_mod_pressed)
	if evo_btn:
		evo_btn.pressed.connect(_on_evo_pressed)

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
	# 改造系统入口按钮挂图标（强化/改装/进化）
	_apply_action_btn_icons()

# ========== 视觉样式方法 ==========

func _apply_visual_styles() -> void:
	# tscn 已定义基础 StyleBox，这里只做运行时动态调整

	# --- 关闭按钮 ---（tscn 无法定义 hover 态）
	var cbtn = get_node_or_null("%CloseBtn")
	if cbtn:
		var sb_n = StyleBoxFlat.new()
		sb_n.bg_color = Color(0.55, 0.35, 0.96, 0.12)
		sb_n.border_color = Color(0.55, 0.35, 0.96, 0.45)
		sb_n.set_border_width_all(1)
		sb_n.set_corner_radius_all(4)
		cbtn.add_theme_stylebox_override("normal", sb_n)
		var sb_h = StyleBoxFlat.new()
		sb_h.bg_color = Color(0.9, 0.2, 0.2, 0.22)
		sb_h.border_color = Color(0.95, 0.3, 0.3, 0.75)
		sb_h.set_border_width_all(1)
		sb_h.set_corner_radius_all(4)
		cbtn.add_theme_stylebox_override("hover", sb_h)

	# --- 进度条 ---
	var sp = get_node_or_null("%StarProgress")
	if sp:
		sp.custom_minimum_size = Vector2(0, 6)
	var ep = get_node_or_null("%EnhanceProgress")
	if ep:
		ep.custom_minimum_size = Vector2(0, 6)

# ========== 改造系统入口按钮图标 ==========

## 给强化/改装/进化三个入口按钮挂图标（图标在文字左侧，保留中文文字）
func _apply_action_btn_icons() -> void:
	# 强化：mod_enhancement.png 在 mod_icons 子目录，用完整路径加载
	var enh_tex := UiAssetLoader.load_tex("res://assets/ui/icons/mod_icons/mod_enhancement.png")
	# 改装：根目录 svg
	var mod_tex := UiAssetLoader.ui_icon("icon_modification")
	# 进化：暂用 icon_blueprint.svg 占位（与 intel_manual_items.gd 进化蓝图一致）
	var evo_tex := UiAssetLoader.ui_icon("icon_blueprint")
	_apply_btn_icon(%EnhanceBtn, enh_tex, "强化")
	_apply_btn_icon(%ModBtn, mod_tex, "改造")
	_apply_btn_icon(%EvoBtn, evo_tex, "进化")

## 统一挂图标：去掉原 text 开头的 emoji，保留中文文字
func _apply_btn_icon(btn: Button, tex: Texture2D, text_label: String) -> void:
	if btn == null or tex == null:
		return
	btn.text = text_label
	btn.icon = tex
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_constant_override("icon_max_width", 18)

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
	## 从背包读取卡牌（与 backpack_presenter / card_enhancement_panel 一致）
	var all_ids: Array[String] = []
	var seen: Dictionary = {}
	var _sm = get_node_or_null("/root/SaveManager")
	if _sm:
		var pending: Array = _sm.get_pending_backpack_ids() if _sm.has_method("get_pending_backpack_ids") else []
		var last_known: Array = _sm.get_last_known_backpack_ids() if _sm.has_method("get_last_known_backpack_ids") else []
		for id in pending:
			var sid: String = String(id)
			if not sid.is_empty() and not seen.has(sid):
				all_ids.append(sid)
				seen[sid] = true
		for id in last_known:
			var sid: String = String(id)
			if not sid.is_empty() and not seen.has(sid):
				all_ids.append(sid)
				seen[sid] = true
	# 补充 BlueprintManager 中已解锁但不在背包中的蓝图
	var bp = get_node_or_null("/root/BlueprintManager")
	if bp:
		var bp_ids: Array = bp.get_all_blueprint_ids() if bp.has_method("get_all_blueprint_ids") else bp.get_unlocked_blueprint_ids()
		for id in bp_ids:
			var sid: String = String(id)
			if not sid.is_empty() and not seen.has(sid):
				all_ids.append(sid)
				seen[sid] = true
	_last_unlocked_ids = all_ids
	refresh_card_list(all_ids)
	if not _selected_card and not all_ids.is_empty():
		var first_card = DefaultCards.get_card_by_id(all_ids[0])
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

## 打开强化面板（ EnhancementOverlay → CardEnhancementPanel ）
func _on_enhance_pressed() -> void:
	if not _selected_card:
		return
	_open_target_panel("enhancement")

## 打开改造面板（ ModificationOverlay → ModificationPanel ）
func _on_mod_pressed() -> void:
	if not _selected_card:
		return
	_open_target_panel("modification")

## 打开进化面板（ EvolutionOverlay → EvolutionPanel ）
func _on_evo_pressed() -> void:
	if not _selected_card:
		return
	_open_target_panel("evolution")

## 关闭自身后打开目标面板（等关闭动画完成再切）
func _open_target_panel(panel_key: String) -> void:
	if _is_open:
		_is_open = false
		modulate.a = 0.0
		visible = false
		closed.emit()
	var main = get_node_or_null("/root/Main")
	if main and main.has_method("_toggle_overlay"):
		var overlay = main._overlay_for_panel_key(panel_key) if main.has_method("_overlay_for_panel_key") else null
		if overlay:
			main._toggle_overlay(overlay, panel_key)

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
		btn.custom_minimum_size = Vector2(0, 26)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color(0.75, 0.8, 0.87))
		btn.add_theme_color_override("font_hover_color", Color(0.0, 0.9, 0.46))
		btn.text = card.display_name if card.display_name else card.card_id

		# 选中高亮
		if _selected_card and _selected_card.card_id == card_id:
			btn.add_theme_color_override("font_color", Color(0, 0.94, 1, 1))
			var highlight_sb := StyleBoxFlat.new()
			highlight_sb.bg_color = Color(0, 0.94, 1, 0.14)
			highlight_sb.border_color = Color(0, 0.94, 1, 0.45)
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
		star_label.add_theme_font_size_override("font_size", 9)
		star_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 0.7))
		meta_row.add_child(star_label)
		var level_label := Label.new()
		level_label.text = "Lv.%d" % card.enhance_level
		level_label.add_theme_font_size_override("font_size", 9)
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
	var res_symbols := ["纳米", "合金", "晶体"]
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
			_add_tag(CardResource.get_combat_kind_name(c.combat_kind))

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
			s.add_theme_font_size_override("font_size", 20)
			s.custom_minimum_size = Vector2(24, 24)
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
			s.add_theme_font_size_override("font_size", 14)
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
	# [临时诊断] 确认 mods 数据是否到达成长面板
	print("[GrowthPanel:Diag] card=%s mods.size=%d filled=%d" % [_selected_card.card_id, mod_list.size(), filled])
	for i in range(mini(mod_list.size(), 3)):
		print("[GrowthPanel:Diag]   mods[%d]=%s" % [i, mod_list[i]])
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
			# BlueprintManager 写入的 entry 是 {id, installed_at}，不含 name/level/tier 等显示字段；
			# 统一用 id 反查改造注册表补全，避免 mod_slot_item 取不到 name 显示空白。
			# 用 duplicate 避免把显示字段写回 card.mods 污染存档数据。
			var mod_id_str: String = ""
			if entry is Dictionary:
				mod_id_str = String(entry.get("id", ""))
				mod_data = entry.duplicate(true)
			elif entry is String:
				mod_id_str = String(entry)
			if not mod_id_str.is_empty():
				var md: Dictionary = ModRegistry.get_data(mod_id_str)
				mod_data["id"] = mod_id_str
				# 改造数据名字字段是 "name"（非 display_name）
				mod_data["name"] = md.get("name", mod_id_str)
				if not mod_data.has("level"):
					mod_data["level"] = 1
				if not mod_data.has("tier"):
					mod_data["tier"] = md.get("tier", "A")
				if not mod_data.has("icon"):
					mod_data["icon"] = md.get("icon", "")
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
			evo_target_icon.text = "?"
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

		evo_requirements_label.bbcode_text = "  \u00B7  ".join(bbcode_parts)

# ---------- Footer ----------

func _refresh_footer() -> void:
	if currency_labels.size() >= 4:
		var res_mgr = get_node_or_null("/root/BasicResourceManager")
		if res_mgr:
			var ids := ["res_alloy", "res_crystal", "res_nano", "res_permit"]
			var symbols := ["合金", "晶体", "纳米", "许可"]
			var names := ["合金", "晶体", "纳米", "许可"]
			for i in range(min(4, ids.size())):
				if currency_labels[i]:
					var amt: int = res_mgr.get_total(ids[i])
					currency_labels[i].text = "%s %s" % [names[i], _format_number(amt)]

# ========== 辅助 ==========

func _add_tag(text: String) -> void:
	var tag_panel := PanelContainer.new()
	tag_panel.add_theme_stylebox_override("panel", _tag_stylebox)

	var tag_label := Label.new()
	tag_label.text = text
	tag_label.add_theme_font_size_override("font_size", 12)
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
		"装甲": return "◈"
		"炮兵": return "◎"
		"防空": return "↑"
		"空军": return "\u2708"
		"侦察": return "◉"
		"工程": return "⚙"
		"堡垒": return "■"
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
	_tag_stylebox.bg_color = Color(0, 0.94, 1, 0.08)
	_tag_stylebox.border_color = Color(0, 0.94, 1, 0.3)
	_tag_stylebox.set_corner_radius_all(2)
	_tag_stylebox.content_margin_left = 6
	_tag_stylebox.content_margin_top = 1
	_tag_stylebox.content_margin_right = 6
	_tag_stylebox.content_margin_bottom = 1
