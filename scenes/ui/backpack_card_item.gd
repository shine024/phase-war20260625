extends PanelContainer
## 背包中的单张卡片：固定大小、简略显示，点击卡片弹出全部信息
## 使用自定义拖拽系统来解决 CanvasLayer 拖拽问题
## 拆分模块：拖拽 → BackpackCardItemDrag, 操作 → BackpackCardItemActions

signal card_clicked(card: CardResource, source_item: Control)
signal drag_completed(card: CardResource, target_slot: Control)

var card: CardResource = null

# 自定义拖拽相关
var _is_dragging := false
var _drag_preview: Control = null
var _click_start_position: Vector2
var _drag_threshold := 5.0  # 移动5像素才开始拖拽
## 背包格内简图：卡图 + 底栏名/费（与相位仪槽一致）；完整卡面仅详情弹窗
var ENABLE_MINIMAL_CARD_RENDER := true
const BACKPACK_USE_MTG_CARD_FACE := false
const BACKPACK_MTG_ART_PCT := 58.0
## 与 bottom_instrument_bar._SLOT_BOTTOM_TEXT_H 一致
const COMPACT_BOTTOM_TEXT_H := 30
const ENABLE_IMAGE_DRAG_PREVIEW := true
var _last_drag_log_ms: int = 0
var _drag_started_ms: int = 0
const GC = preload("res://resources/game_constants.gd")
const StarConfig = preload("res://data/blueprint_star_config.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const BackpackCombatPreview = preload("res://scenes/ui/backpack_combat_preview.gd")
const RankDisplayUi = preload("res://scripts/rank_display_ui.gd")
const CardFrameUi = preload("res://scripts/card_frame_ui.gd")
const CardBackgroundUi = preload("res://scripts/card_background_ui.gd")
## 与相位仪槽位 `PhaseSlot.SLOT_SIZE` 一致，便于拖拽与装备时视觉对齐
var SLOT_SIZE: Vector2 = PhaseSlot.SLOT_SIZE
## 列表内卡图：与 backpack_card_item.tscn 中 Icon 一致，竖向窄格内居中
var CARD_LIST_ICON_DISPLAY_MIN: Vector2 = Vector2(28, 28)
## 拖拽预览外框同槽位；内图标竖向略小于外框
const DRAG_PREVIEW_ICON_DISPLAY_MIN := Vector2(36, 56)
var _icon_cache: Dictionary = {}

# 各卡片类型对应的顶部色条颜色
const TYPE_BAR_COLORS := {
	GC.CardType.COMBAT_UNIT: Color(0.1, 0.5, 0.9, 1.0),
	GC.CardType.ENERGY:      Color(0.15, 0.75, 0.35, 1.0),
	GC.CardType.LAW:         Color(0.85, 0.2, 0.5, 1.0),
}

# 空槽样式（懒加载缓存）
var _style_empty: StyleBoxFlat = null
var _style_normal: StyleBoxFlat = null
var _last_hover_slot: Control = null
var _cached_slot_controls: Array = []
static var _type_bar_style_cache: Dictionary = {}
static var _card_border_style_cache: Dictionary = {}
static var _empty_type_bar_style: StyleBoxFlat = null
static var _empty_card_panel_style: StyleBoxFlat = null


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	clip_contents = false
	set_custom_minimum_size(SLOT_SIZE)
	custom_minimum_size = SLOT_SIZE
	if ENABLE_MINIMAL_CARD_RENDER and BACKPACK_USE_MTG_CARD_FACE and not has_meta("_pv_mtg_layout"):
		set_meta("_pv_mtg_layout", true)
		set_meta("_pv_mtg_art_pct", BACKPACK_MTG_ART_PCT)
	var use_mtg_face: bool = _backpack_uses_mtg_face()
	if not use_mtg_face and not _icon_row_has_compact_layout():
		var list_icon: TextureRect = _find_icon_row_icon()
		_apply_icon_texture_rect_fixed(list_icon, CARD_LIST_ICON_DISPLAY_MIN)
	if ENABLE_MINIMAL_CARD_RENDER:
		var inner_v: Control = get_node_or_null("VBox/ContentMargin/InnerVBox") as Control
		if inner_v:
			# 仅裁切溢出；卡名区需参与最小高度计算，勿在子 Label 上 clip_text 否则竖格内易整段不显示
			inner_v.clip_contents = true
		var icon_row_ready: Control = get_node_or_null("VBox/ContentMargin/InnerVBox/IconRow") as Control
		if icon_row_ready:
			icon_row_ready.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 缓存默认面板样式
	_style_normal = get_theme_stylebox("panel") as StyleBoxFlat
	CardBackgroundUi.ensure_overlay(self)
	CardFrameUi.ensure_overlay(self)


	# 监听全局输入以捕获拖拽结束
	var tree = get_tree()
	if tree and is_instance_valid(tree):
		tree.process_frame.connect(_check_drag_state)


## 卡图等比缩放到固定槽位（不随贴图像素尺寸撑开布局）
func _card_icon_tex_path(c: CardResource) -> String:
	if c == null:
		return ""
	return UiAssetLoader.card_icon_path_for(c)


func _apply_icon_texture_rect_fixed(icon_rect: TextureRect, min_size: Vector2) -> void:
	if icon_rect == null:
		return
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = min_size
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER



func _check_drag_state() -> void:
	BackpackCardItemDrag.check_drag_state(self)

func _disconnect_drag_frame_hook() -> void:
	BackpackCardItemDrag.disconnect_drag_frame_hook(self)

func _exit_tree() -> void:
	BackpackCardItemDrag.exit_tree_cleanup(self)

## 检查全局鼠标移动（用于拖拽过程中）
func _check_global_mouse_movement() -> void:
	BackpackCardItemDrag.check_global_mouse_movement(self)

func _backpack_uses_mtg_face() -> bool:
	if not ENABLE_MINIMAL_CARD_RENDER:
		return false
	# 详情弹窗等可显式设 meta；背包格默认不启用
	if has_meta("_pv_mtg_layout") and bool(get_meta("_pv_mtg_layout")):
		return true
	return BACKPACK_USE_MTG_CARD_FACE


func _icon_row_has_compact_layout() -> bool:
	var icon_row: Control = get_node_or_null("VBox/ContentMargin/InnerVBox/IconRow") as Control
	return icon_row != null and icon_row.get_meta("_compact_slot_built", false)


func _find_icon_row() -> Control:
	return get_node_or_null("VBox/ContentMargin/InnerVBox/IconRow") as Control


func _find_icon_row_icon() -> TextureRect:
	var icon_row: Node = _find_icon_row()
	if icon_row == null:
		return null
	return icon_row.find_child("Icon", true, false) as TextureRect


func _find_slot_name_label() -> Label:
	var icon_row: Control = _find_icon_row()
	if icon_row == null:
		return null
	if icon_row.get_meta("_compact_slot_built", false):
		return icon_row.get_node_or_null("CompactTextVBox/NameLabel") as Label
	return icon_row.get_node_or_null("NameLabel") as Label


func _find_slot_cost_label() -> Label:
	var icon_row: Control = _find_icon_row()
	if icon_row == null:
		return get_node_or_null("VBox/ContentMargin/InnerVBox/StatsRow/CostLabel") as Label
	if icon_row.get_meta("_compact_slot_built", false):
		return icon_row.get_node_or_null("CompactTextVBox/CostLabel") as Label
	return get_node_or_null("VBox/ContentMargin/InnerVBox/StatsRow/CostLabel") as Label


func set_card(c: CardResource) -> void:
	card = c
	var icon_row_sync: Control = _find_icon_row()
	if icon_row_sync:
		var want_mtg: bool = _backpack_uses_mtg_face()
		if icon_row_sync.get_meta("_mtg_preview_built", false) and not want_mtg:
			_restore_icon_row_from_mtg_preview(icon_row_sync)
		if icon_row_sync.get_meta("_compact_slot_built", false) and want_mtg:
			_restore_compact_slot_structure(icon_row_sync)
	var type_bar: Panel = get_node_or_null("VBox/TypeBar")
	var icon_rect: TextureRect = _find_icon_row_icon()
	var name_label: Label = _find_slot_name_label()
	var cost_label: Label = _find_slot_cost_label()
	var weight_label: Label = get_node_or_null("VBox/ContentMargin/InnerVBox/StatsRow/WeightLabel")
	var lv_label: Label = get_node_or_null("VBox/ContentMargin/InnerVBox/LevelRow/LvLabel")
	var xp_bar: Panel = get_node_or_null("VBox/ContentMargin/InnerVBox/LevelRow/XpBar")
	var xp_fill: Panel = get_node_or_null("VBox/ContentMargin/InnerVBox/LevelRow/XpBar/XpFill")

	if c == null:
		_set_empty_style(type_bar, name_label, cost_label, weight_label, lv_label, xp_fill, icon_rect)
		return

	if ENABLE_MINIMAL_CARD_RENDER:
		_set_minimal_card_view(c, type_bar, name_label, cost_label, weight_label, lv_label, xp_bar, xp_fill, icon_rect)
		return

	var stats_row_full: Control = get_node_or_null("VBox/ContentMargin/InnerVBox/StatsRow") as Control
	var level_row_full: Control = get_node_or_null("VBox/ContentMargin/InnerVBox/LevelRow") as Control
	if stats_row_full:
		stats_row_full.visible = true
	if level_row_full:
		level_row_full.visible = true

	# ── 类型色条 ──────────────────────────────────────────────
	if type_bar:
		var type_key: String = str(c.card_type)
		if not _type_bar_style_cache.has(type_key):
			var bar_color: Color = TYPE_BAR_COLORS.get(c.card_type, Color(0.4, 0.4, 0.4, 1.0))
			var bar_style := StyleBoxFlat.new()
			bar_style.bg_color = bar_color
			bar_style.corner_radius_top_left = 5
			bar_style.corner_radius_top_right = 5
			_type_bar_style_cache[type_key] = bar_style
		type_bar.add_theme_stylebox_override("panel", _type_bar_style_cache[type_key])
		type_bar.visible = true

	# ── 卡名 ─────────────────────────────────────────────────
	if name_label:
		name_label.remove_theme_font_size_override("font_size")
		name_label.clip_text = false
		name_label.custom_minimum_size = Vector2(0, 22)
		name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var display_name: String = DefaultCards.safe_name(c)

		# 星级（与蓝图库一致：按累计副本换算）+ （副本）数量
		var star_text := ""
		var copies_text := ""

		if BlueprintManager and BlueprintManager.has_method("get_star_progress"):
			var sp: Dictionary = BlueprintManager.get_star_progress(c.card_id)
			var cs: int = int(sp.get("current_star", 0))
			var mx: int = int(sp.get("max_star", 9))
			if mx <= 0:
				mx = 9
			star_text = " %d/%d" % [mini(cs, mx), mx]
			if BlueprintManager.has_method("get_blueprint_copies"):
				var copies: int = BlueprintManager.get_blueprint_copies(c.card_id)
				if copies > 0:
					copies_text = " （副本）%d" % copies

		name_label.text = display_name + star_text + copies_text
		name_label.visible = true
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# 字体颜色跟随稀有度
		match c.rarity:
			"uncommon": name_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6, 1))
			"rare":     name_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0, 1))
			"legendary":   name_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.9, 1))
			_:          name_label.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0, 1))

	# ── 图标 ──────────────────────────────────────────────────
	if icon_rect:
		_apply_card_icon_rect(icon_rect, c, CARD_LIST_ICON_DISPLAY_MIN)

	# ── 能量费用 ──────────────────────────────────────────────
	if cost_label:
		cost_label.text = "%d" % int(c.energy_cost)
		cost_label.visible = true

	# ── 承载 / 重量 ───────────────────────────────────────────
	if weight_label:
		match c.card_type:
			GC.CardType.COMBAT_UNIT:
				if c.weight_capacity > 0:
					weight_label.text = "%d" % int(c.weight_capacity)
					weight_label.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0, 1))
				elif c.weight > 0:
					weight_label.text = "%d" % int(c.weight)
					weight_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35, 1))
				else:
					weight_label.text = ""
			_:
				weight_label.text = ""
		weight_label.visible = true

	# 等级 + 经验进度
	if lv_label and BlueprintManager and BlueprintManager.has_method("get_card_xp_progress"):
		var prog: Dictionary = BlueprintManager.get_card_xp_progress(c.card_id)
		var lvl: int = int(prog.get("level", 1))
		var cur_xp: int = int(prog.get("cur_xp", 0))
		var next_xp: int = int(prog.get("next_xp", 0))
		var max_level: bool = next_xp <= 0 or lvl >= BlueprintManager.MAX_BLUEPRINT_LEVEL
		lv_label.text = "Lv.%d" % lvl
		lv_label.visible = true
		if xp_bar:
			xp_bar.visible = not max_level
		if xp_fill and not max_level and next_xp > 0:
			var ratio: float = clamp(float(cur_xp) / float(next_xp), 0.0, 1.0)
			xp_fill.anchor_right = ratio
			xp_fill.offset_right = 0.0
	elif lv_label:
		lv_label.text = ""
		lv_label.visible = false
		if xp_bar:
			xp_bar.visible = false

	_apply_card_chrome(c)

	tooltip_text = ""

func _set_empty_style(type_bar, name_label, cost_label, weight_label, lv_label, xp_fill, icon_rect) -> void:
	if _icon_row_has_compact_layout():
		if type_bar:
			type_bar.visible = false
		var empty_name: Label = _find_slot_name_label()
		var empty_cost: Label = _find_slot_cost_label()
		if empty_name:
			empty_name.text = ""
			empty_name.visible = false
		if empty_cost:
			empty_cost.text = ""
			empty_cost.visible = false
		if icon_rect:
			icon_rect.texture = null
			icon_rect.visible = false
		add_theme_stylebox_override("panel", _get_empty_card_panel_style())
		return
	var stats_row_e: Control = get_node_or_null("VBox/ContentMargin/InnerVBox/StatsRow") as Control
	var level_row_e: Control = get_node_or_null("VBox/ContentMargin/InnerVBox/LevelRow") as Control
	if stats_row_e:
		stats_row_e.visible = not ENABLE_MINIMAL_CARD_RENDER
	if level_row_e:
		level_row_e.visible = not ENABLE_MINIMAL_CARD_RENDER
	if type_bar:
		type_bar.add_theme_stylebox_override("panel", _get_empty_type_bar_style())
	if name_label:
		name_label.text = ""
		name_label.add_theme_color_override("font_color", Color(0.3, 0.35, 0.45, 0.6))
		name_label.visible = not ENABLE_MINIMAL_CARD_RENDER
		name_label.remove_theme_font_size_override("font_size")
		name_label.clip_text = false
		name_label.custom_minimum_size = Vector2.ZERO
		name_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if cost_label:
		cost_label.text = ""
	if weight_label:
		weight_label.text = ""
	if lv_label:
		lv_label.text = ""
	if xp_fill:
		xp_fill.anchor_right = 0.0
	if icon_rect:
		icon_rect.texture = null
	# 空槽使用暗淡边框
	add_theme_stylebox_override("panel", _get_empty_card_panel_style())
	CardFrameUi.clear_overlay(self)
	CardBackgroundUi.clear_overlay(self)

func _sync_card_background_overlay(c: CardResource) -> void:
	if c == null:
		CardBackgroundUi.clear_overlay(self)
		return
	CardBackgroundUi.apply_to_host(self, CardBackgroundUi.resolve_faction_id_for_card(c))


func _sync_card_frame_overlay(c: CardResource) -> void:
	if c == null:
		CardFrameUi.clear_overlay(self)
		return
	CardFrameUi.apply_to_host(self, c.rarity)


func _get_frame_panel_style() -> StyleBoxFlat:
	return CardFrameUi.subtle_panel_style()


func _set_minimal_card_view(c: CardResource, type_bar, name_label, cost_label, weight_label, lv_label, xp_bar, xp_fill, icon_rect) -> void:
	if _backpack_uses_mtg_face():
		_set_mtg_minimal_card_view(c, type_bar, name_label, cost_label, weight_label, lv_label, xp_bar, xp_fill, icon_rect)
		return
	_set_compact_slot_view(c, type_bar, name_label, cost_label, weight_label, lv_label, xp_bar, xp_fill, icon_rect)


func _apply_card_chrome(c: CardResource) -> void:
	if c == null:
		CardFrameUi.clear_panel_frame(self)
		CardBackgroundUi.clear_overlay(self)
		return
	CardBackgroundUi.apply_to_host(self, CardBackgroundUi.resolve_faction_id_for_card(c))
	if CardFrameUi.has_frame(c.rarity):
		CardFrameUi.apply_panel_with_frame(self, c.rarity)
	else:
		CardFrameUi.clear_overlay(self)
		_apply_card_border_flat(c)
	# 势力专属卡不可用检测
	_apply_faction_exclusive_state(c)

## 势力专属卡：不可用时显示灰色 + 降低透明度
func _apply_faction_exclusive_state(c: CardResource) -> void:
	if not c.is_faction_exclusive:
		return
	var EC = preload("res://data/faction_exclusive_cards.gd")
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	var available := false
	if fsm != null:
		var faction_id: String = EC.get_exclusive_faction(c.card_id)
		var min_lv: int = EC.get_min_faction_level(c.card_id)
		if fsm.get_active_faction() == faction_id and fsm.get_faction_level(faction_id) >= min_lv:
			available = true
	if not available:
		modulate = Color(0.5, 0.5, 0.5, 0.7)
		tooltip_text = "需要激活 %s 势力且等级 >= %d" % [
			EC.get_exclusive_faction(c.card_id),
			EC.get_min_faction_level(c.card_id)]
	else:
		modulate = Color(1, 1, 1, 1)


func _apply_card_icon_rect(icon_rect: TextureRect, c: CardResource, min_size: Vector2) -> void:
	if icon_rect == null:
		return
	_apply_icon_texture_rect_fixed(icon_rect, min_size)
	if c == null:
		icon_rect.texture = null
		icon_rect.visible = false
		return
	var tex_path := _card_icon_tex_path(c)
	UiAssetLoader.setup_card_unit_icon(icon_rect, _get_cached_icon_texture(tex_path), min_size, true)


func _apply_card_border_flat(c: CardResource) -> void:
	var cache_key: String = "%d_%s" % [int(c.card_type), str(c.rarity)]
	if _card_border_style_cache.has(cache_key):
		add_theme_stylebox_override("panel", _card_border_style_cache[cache_key])
		return
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.10, 0.17, 0.95)
	panel_style.corner_radius_top_left = 5
	panel_style.corner_radius_top_right = 5
	panel_style.corner_radius_bottom_right = 5
	panel_style.corner_radius_bottom_left = 5
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	match c.card_type:
		GC.CardType.COMBAT_UNIT:
			panel_style.border_color = Color(0.15, 0.55, 0.9, 0.55)
		GC.CardType.ENERGY:
			panel_style.border_color = Color(0.2, 0.8, 0.4, 0.55)
		GC.CardType.LAW:
			panel_style.border_color = Color(0.85, 0.2, 0.5, 0.55)
		_:
			panel_style.border_color = Color(0.25, 0.35, 0.5, 0.5)

	# 稀有度增强边框
	match c.rarity:
		"rare":   panel_style.border_width_left = 2; panel_style.border_width_top = 2; panel_style.border_width_right = 2; panel_style.border_width_bottom = 2
		"legendary": panel_style.border_width_left = 2; panel_style.border_width_top = 2; panel_style.border_width_right = 2; panel_style.border_width_bottom = 2; panel_style.shadow_color = Color(1.0, 0.6, 0.9, 0.3); panel_style.shadow_size = 4
	_card_border_style_cache[cache_key] = panel_style
	add_theme_stylebox_override("panel", panel_style)

func _get_empty_type_bar_style() -> StyleBoxFlat:
	if _empty_type_bar_style != null:
		return _empty_type_bar_style
	_empty_type_bar_style = StyleBoxFlat.new()
	_empty_type_bar_style.bg_color = Color(0.15, 0.2, 0.28, 0.5)
	_empty_type_bar_style.corner_radius_top_left = 5
	_empty_type_bar_style.corner_radius_top_right = 5
	return _empty_type_bar_style

func _get_empty_card_panel_style() -> StyleBoxFlat:
	if _empty_card_panel_style != null:
		return _empty_card_panel_style
	_empty_card_panel_style = StyleBoxFlat.new()
	_empty_card_panel_style.bg_color = Color(0.04, 0.07, 0.12, 0.5)
	_empty_card_panel_style.border_width_left = 1
	_empty_card_panel_style.border_width_top = 1
	_empty_card_panel_style.border_width_right = 1
	_empty_card_panel_style.border_width_bottom = 1
	_empty_card_panel_style.border_color = Color(0.2, 0.25, 0.35, 0.3)
	_empty_card_panel_style.corner_radius_top_left = 5
	_empty_card_panel_style.corner_radius_top_right = 5
	_empty_card_panel_style.corner_radius_bottom_right = 5
	_empty_card_panel_style.corner_radius_bottom_left = 5
	return _empty_card_panel_style


func _restore_icon_row_from_mtg_preview(icon_row: Control) -> void:
	if icon_row == null or not icon_row.get_meta("_mtg_preview_built", false):
		return
	var art_clip: Control = icon_row.get_node_or_null("MtgArtClip") as Control
	var icon: TextureRect = null
	if art_clip:
		icon = art_clip.get_node_or_null("Icon") as TextureRect
		if icon:
			art_clip.remove_child(icon)
		var ac := art_clip
		ac.queue_free()
	var hdr: Node = icon_row.get_node_or_null("MtgHeader")
	if hdr:
		hdr.queue_free()
	var stars: Node = icon_row.get_node_or_null("MtgStarsRow")
	if stars:
		stars.queue_free()
	var name_lbl: Label = icon_row.get_node_or_null("NameLabel") as Label
	if icon and icon.get_parent() != icon_row:
		icon_row.add_child(icon)
	if name_lbl and name_lbl.get_parent() != icon_row:
		icon_row.add_child(name_lbl)
	if icon:
		icon_row.move_child(icon, 0)
	if name_lbl and is_instance_valid(name_lbl):
		var idx := mini(1, icon_row.get_child_count() - 1)
		icon_row.move_child(name_lbl, idx)
	if icon_row.has_meta("_mtg_preview_built"):
		icon_row.remove_meta("_mtg_preview_built")
	if icon:
		_apply_icon_texture_rect_fixed(icon, CARD_LIST_ICON_DISPLAY_MIN)


func _restore_compact_slot_structure(icon_row: Control) -> void:
	if icon_row == null or not icon_row.get_meta("_compact_slot_built", false):
		return
	var art_clip: Control = icon_row.get_node_or_null("CompactArtClip") as Control
	var icon: TextureRect = null
	if art_clip:
		icon = art_clip.get_node_or_null("Icon") as TextureRect
		if icon:
			art_clip.remove_child(icon)
		art_clip.queue_free()
	var text_v: Node = icon_row.get_node_or_null("CompactTextVBox")
	var name_lbl: Label = null
	var cost_lbl: Label = null
	if text_v:
		name_lbl = text_v.get_node_or_null("NameLabel") as Label
		cost_lbl = text_v.get_node_or_null("CostLabel") as Label
		if name_lbl:
			text_v.remove_child(name_lbl)
		if cost_lbl:
			text_v.remove_child(cost_lbl)
		text_v.queue_free()
	if icon and icon.get_parent() != icon_row:
		icon_row.add_child(icon)
	if name_lbl and name_lbl.get_parent() != icon_row:
		icon_row.add_child(name_lbl)
	if cost_lbl:
		var stats_row: Control = get_node_or_null("VBox/ContentMargin/InnerVBox/StatsRow") as Control
		if stats_row and cost_lbl.get_parent() != stats_row:
			stats_row.add_child(cost_lbl)
			cost_lbl.visible = false
	if icon:
		icon_row.move_child(icon, 0)
	if name_lbl and is_instance_valid(name_lbl):
		var idx := mini(1, icon_row.get_child_count() - 1)
		icon_row.move_child(name_lbl, idx)
	if icon_row.has_meta("_compact_slot_built"):
		icon_row.remove_meta("_compact_slot_built")
	if icon:
		_apply_icon_texture_rect_fixed(icon, CARD_LIST_ICON_DISPLAY_MIN)


func _ensure_compact_slot_structure(icon_row: Control, name_label: Label, cost_label: Label) -> void:
	if icon_row == null or name_label == null or cost_label == null:
		return
	if icon_row.get_meta("_compact_slot_built", false):
		return
	if icon_row.get_node_or_null("CompactArtClip") != null:
		icon_row.set_meta("_compact_slot_built", true)
		return
	if icon_row.get_meta("_mtg_preview_built", false):
		_restore_icon_row_from_mtg_preview(icon_row)
	var icon: TextureRect = icon_row.find_child("Icon", true, false) as TextureRect
	if icon == null:
		return
	if icon.get_parent() == icon_row:
		icon_row.remove_child(icon)
	if name_label.get_parent() == icon_row:
		icon_row.remove_child(name_label)
	var stats_row: Control = get_node_or_null("VBox/ContentMargin/InnerVBox/StatsRow") as Control
	if cost_label.get_parent() == stats_row:
		stats_row.remove_child(cost_label)
	var art_clip := Control.new()
	art_clip.name = "CompactArtClip"
	art_clip.clip_contents = true
	art_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_clip.add_child(icon)
	var text_v := VBoxContainer.new()
	text_v.name = "CompactTextVBox"
	text_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_v.size_flags_vertical = Control.SIZE_SHRINK_END
	text_v.custom_minimum_size.y = COMPACT_BOTTOM_TEXT_H
	text_v.add_theme_constant_override("separation", 0)
	text_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size = Vector2(0, 14)
	name_label.remove_theme_font_size_override("font_size")
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 1.0))
	cost_label.name = "CostLabel"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	cost_label.clip_text = true
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_label.custom_minimum_size = Vector2(0, 14)
	cost_label.remove_theme_font_size_override("font_size")
	cost_label.add_theme_font_size_override("font_size", 9)
	cost_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35, 1.0))
	text_v.add_child(name_label)
	text_v.add_child(cost_label)
	icon_row.add_child(art_clip)
	icon_row.add_child(text_v)
	icon_row.set_meta("_compact_slot_built", true)
	var clip_ref := art_clip
	art_clip.resized.connect(func() -> void:
		_layout_compact_art_clip(clip_ref)
	)


func _layout_compact_art_clip(art_clip: Control) -> void:
	if art_clip == null or not is_instance_valid(art_clip):
		return
	var icon := art_clip.get_node_or_null("Icon") as TextureRect
	if icon == null:
		return
	var art_w: float = maxf(art_clip.size.x - 4.0, 20.0)
	var art_h: float = maxf(art_clip.size.y - 2.0, 18.0)
	if art_clip.size.x < 2.0:
		art_w = maxf(float(SLOT_SIZE.x) - 8.0, 20.0)
	if art_clip.size.y < 2.0:
		art_h = maxf(float(SLOT_SIZE.y) - float(COMPACT_BOTTOM_TEXT_H) - 10.0, 18.0)
	UiAssetLoader.setup_texrect_icon(icon, icon.texture, Vector2(art_w, art_h))


func _compact_display_name(c: CardResource) -> String:
	var display_name: String = "能量" if c.card_type == GC.CardType.ENERGY else DefaultCards.safe_name(c)
	if display_name.is_empty():
		display_name = DefaultCards.get_safe_display_name(c.card_id)
	if display_name.length() > 6:
		display_name = display_name.substr(0, 6)
	return display_name


func _set_compact_slot_view(c: CardResource, type_bar, name_label, cost_label, weight_label, lv_label, xp_bar, xp_fill, icon_rect) -> void:
	if type_bar:
		type_bar.visible = false
	var icon_row: Control = _find_icon_row()
	if icon_row:
		icon_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stats_row: Control = get_node_or_null("VBox/ContentMargin/InnerVBox/StatsRow") as Control
	var level_row: Control = get_node_or_null("VBox/ContentMargin/InnerVBox/LevelRow") as Control
	if stats_row:
		stats_row.visible = false
	if level_row:
		level_row.visible = false
	if weight_label:
		weight_label.visible = false
		weight_label.text = ""
	if lv_label:
		lv_label.visible = false
		lv_label.text = ""
	if xp_bar:
		xp_bar.visible = false
	if xp_fill:
		xp_fill.anchor_right = 0.0
	if icon_row == null or name_label == null or cost_label == null:
		return
	_ensure_compact_slot_structure(icon_row, name_label, cost_label)
	var art_clip: Control = icon_row.get_node_or_null("CompactArtClip") as Control
	if icon_rect:
		_apply_card_icon_rect(icon_rect, c, CARD_LIST_ICON_DISPLAY_MIN)
	name_label.visible = true
	name_label.text = _compact_display_name(c)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.max_lines_visible = 1
	cost_label.visible = true
	cost_label.text = "%d⚡" % int(c.energy_cost)
	tooltip_text = ""
	_apply_card_chrome(c)
	if art_clip:
		call_deferred("_layout_compact_art_clip", art_clip)


func _ensure_mtg_preview_structure(icon_row: Control, name_label: Label) -> void:
	if icon_row == null:
		return
	if icon_row.get_meta("_mtg_preview_built", false):
		var hdr_chk: Node = icon_row.get_node_or_null("MtgHeader")
		if hdr_chk and hdr_chk.get_node_or_null("MtgRankRow"):
			return
		_restore_icon_row_from_mtg_preview(icon_row)
	if icon_row.get_meta("_mtg_preview_built", false):
		return
	if icon_row.get_node_or_null("MtgArtClip") != null:
		icon_row.set_meta("_mtg_preview_built", true)
		return
	var icon: TextureRect = icon_row.find_child("Icon", true, false) as TextureRect
	if icon == null or name_label == null:
		return
	if icon.get_parent() != icon_row or name_label.get_parent() != icon_row:
		return
	icon_row.remove_child(icon)
	icon_row.remove_child(name_label)
	var header := HBoxContainer.new()
	header.name = "MtgHeader"
	header.add_theme_constant_override("separation", 6)
	header.custom_minimum_size = Vector2(0, 18)
	var name_hdr := Label.new()
	name_hdr.name = "MtgNameLabel"
	name_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hdr.clip_text = true
	name_hdr.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_hdr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_hdr.add_theme_font_size_override("font_size", 9)
	var rank_hdr := HBoxContainer.new()
	rank_hdr.name = "MtgRankRow"
	rank_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_hdr.alignment = BoxContainer.ALIGNMENT_CENTER
	rank_hdr.add_theme_constant_override("separation", 3)
	var cost_lbl := Label.new()
	cost_lbl.name = "MtgCostLabel"
	cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 9)
	cost_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35, 1.0))
	header.add_child(name_hdr)
	header.add_child(rank_hdr)
	header.add_child(cost_lbl)
	var art_clip := Control.new()
	art_clip.name = "MtgArtClip"
	art_clip.clip_contents = true
	# 横向占满 IconRow 可用宽度
	art_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_clip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art_clip.custom_minimum_size = Vector2(0, 36)
	art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon.custom_minimum_size = Vector2(2, 2)
	art_clip.add_child(icon)
	var stars_row := HBoxContainer.new()
	stars_row.name = "MtgStarsRow"
	stars_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	stars_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stars_row.add_theme_constant_override("separation", 3)
	stars_row.custom_minimum_size = Vector2(0, 14)
	stars_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.add_child(header)
	icon_row.add_child(art_clip)
	icon_row.add_child(stars_row)
	icon_row.add_child(name_label)
	icon_row.set_meta("_mtg_preview_built", true)
	var clip_ref := art_clip
	art_clip.resized.connect(func() -> void:
		_layout_mtg_art_clip(clip_ref)
	)


func _layout_mtg_art_clip(art_clip: Control) -> void:
	if art_clip == null or not is_instance_valid(art_clip):
		return
	var icon := art_clip.get_node_or_null("Icon") as TextureRect
	if icon == null:
		return
	var cw: float = art_clip.size.x
	var ch: float = art_clip.size.y
	if cw < 2.0:
		cw = maxf(art_clip.custom_minimum_size.x, 2.0)
	if ch < 2.0:
		ch = maxf(art_clip.custom_minimum_size.y, 8.0)
	var tex: Texture2D = icon.texture
	icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex == null:
		icon.position = Vector2.ZERO
		icon.size = Vector2(cw, ch)
		return
	var tw: float = maxf(float(tex.get_width()), 1.0)
	var th: float = maxf(float(tex.get_height()), 1.0)
	var scale: float = maxf(cw / tw, ch / th)
	var sw: float = tw * scale
	var sh: float = th * scale
	icon.size = Vector2(sw, sh)
	icon.position = Vector2((cw - sw) * 0.5, (ch - sh) * 0.5)


func _mtg_star_display_count(c: CardResource) -> int:
	var st: int = int(c.enhance_level)
	# 注：蓝图星级逻辑已废弃，enhance_level 直接作为显示值
	return clampi(st, 0, 10)  # MAX_ENHANCE_LEVEL = 10


func _mtg_intel_body_text(c: CardResource) -> String:
	var parts: Array[String] = []
	if not c.type_line.is_empty():
		parts.append(c.type_line)
	if not c.summary_line.is_empty():
		parts.append(c.summary_line)
	var combat_tip: String = BackpackCombatPreview.build_line(c)
	var use_combat: bool = (
		not combat_tip.is_empty()
		and c.card_type == GC.CardType.COMBAT_UNIT
	)
	if use_combat:
		parts.append(combat_tip)
	return "\n".join(parts)


func _ensure_mtg_rank_row(header: HBoxContainer) -> HBoxContainer:
	var row := header.get_node_or_null("MtgRankRow") as HBoxContainer
	if row != null:
		return row
	var legacy := header.get_node_or_null("MtgRankLabel") as Label
	var insert_idx: int = 1
	if legacy != null:
		insert_idx = legacy.get_index()
		header.remove_child(legacy)
		legacy.queue_free()
	row = HBoxContainer.new()
	row.name = "MtgRankRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	header.add_child(row)
	header.move_child(row, insert_idx)
	return row


func _mtg_rank_info(c: CardResource) -> Dictionary:
	var info: Dictionary = RankDisplayUi.resolve_from_card_resource(c)
	if info.is_empty() and String(c.card_id).begins_with("preview_"):
		return {"rank_id": "private", "rank_name": "未定级", "power_score": 0.0}
	return info


func _apply_mtg_header_rarity_colors(c: CardResource, name_hdr: Label, rank_hdr: Label) -> void:
	var col: Color = Color(0.92, 0.95, 1.0, 0.95)
	match c.rarity:
		"uncommon":
			col = Color(0.4, 1.0, 0.6, 1)
		"rare":
			col = Color(0.4, 0.7, 1.0, 1)
		"legendary":
			col = Color(1.0, 0.6, 0.9, 1)
	if name_hdr:
		name_hdr.add_theme_color_override("font_color", col)
	if rank_hdr:
		rank_hdr.add_theme_color_override("font_color", Color(col.r * 0.92, col.g * 0.92, col.b * 0.92, col.a))


func _set_mtg_minimal_card_view(c: CardResource, type_bar, name_label, cost_label, weight_label, lv_label, xp_bar, xp_fill, icon_rect) -> void:
	# 线框式竖卡：顶栏为「全名 | 军衔 | 费用」，不占单独色条
	if type_bar:
		type_bar.visible = false
	var icon_row: Control = get_node_or_null("VBox/ContentMargin/InnerVBox/IconRow") as Control
	if icon_row:
		icon_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stats_row: Control = get_node_or_null("VBox/ContentMargin/InnerVBox/StatsRow") as Control
	var level_row: Control = get_node_or_null("VBox/ContentMargin/InnerVBox/LevelRow") as Control
	if stats_row:
		stats_row.visible = false
	if level_row:
		level_row.visible = false
	if cost_label:
		cost_label.visible = false
		cost_label.text = ""
	if weight_label:
		weight_label.visible = false
		weight_label.text = ""
	if lv_label:
		lv_label.visible = false
		lv_label.text = ""
	if xp_bar:
		xp_bar.visible = false
	if xp_fill:
		xp_fill.anchor_right = 0.0
	if icon_row == null or name_label == null:
		return
	_ensure_mtg_preview_structure(icon_row, name_label)
	var pct: int = 55
	if has_meta("_pv_mtg_art_pct"):
		pct = clampi(int(get_meta("_pv_mtg_art_pct")), 20, 80)
	var art_max: int = maxi(200, int(ceil(SLOT_SIZE.y * 0.78)))
	var art_h: int = clampi(int(float(SLOT_SIZE.y) * float(pct) / 100.0), 22, art_max)
	var art_clip: Control = icon_row.get_node_or_null("MtgArtClip") as Control if icon_row else null
	if art_clip:
		art_clip.custom_minimum_size = Vector2(0, art_h)
	var hdr_h: int = clampi(int(ceil(SLOT_SIZE.y * 0.042)), 16, 32)
	var name_hdr: Label = icon_row.get_node_or_null("MtgHeader/MtgNameLabel") as Label if icon_row else null
	var rank_row: HBoxContainer = icon_row.get_node_or_null("MtgHeader/MtgRankRow") as HBoxContainer if icon_row else null
	var hdr_root_for_rank: HBoxContainer = icon_row.get_node_or_null("MtgHeader") as HBoxContainer if icon_row else null
	if hdr_root_for_rank:
		rank_row = _ensure_mtg_rank_row(hdr_root_for_rank)
	var rank_hdr: Label = rank_row.get_node_or_null("RankName") as Label if rank_row else null
	var cost_hdr: Label = icon_row.get_node_or_null("MtgHeader/MtgCostLabel") as Label if icon_row else null
	var hdr_root: Control = icon_row.get_node_or_null("MtgHeader") as Control if icon_row else null
	if hdr_root:
		hdr_root.custom_minimum_size.y = hdr_h
	if name_hdr:
		name_hdr.text = DefaultCards.safe_name(c)
		name_hdr.add_theme_font_size_override("font_size", clampi(int(ceil(SLOT_SIZE.y * 0.028)), 9, 18))
	if rank_row:
		var ri: Dictionary = _mtg_rank_info(c)
		var icon_px: int = clampi(int(ceil(SLOT_SIZE.y * 0.032)), 10, 20)
		RankDisplayUi.apply_to_host(rank_row, ri, icon_px)
		rank_hdr = rank_row.get_node_or_null("RankName") as Label
		if rank_hdr:
			rank_hdr.add_theme_font_size_override("font_size", clampi(int(ceil(SLOT_SIZE.y * 0.026)), 8, 17))
	if cost_hdr:
		cost_hdr.text = "%d⚡" % int(c.energy_cost)
		cost_hdr.add_theme_font_size_override("font_size", clampi(int(ceil(SLOT_SIZE.y * 0.028)), 9, 18))
	_apply_mtg_header_rarity_colors(c, name_hdr, rank_hdr)
	if icon_rect:
		_apply_card_icon_rect(icon_rect, c, CARD_LIST_ICON_DISPLAY_MIN)
	if name_label:
		name_label.text = _mtg_intel_body_text(c)
		name_label.clip_text = false
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if has_meta("_pv_name_ml"):
			name_label.max_lines_visible = clampi(int(get_meta("_pv_name_ml")), 1, 16)
		else:
			name_label.max_lines_visible = 8
		name_label.add_theme_font_size_override("font_size", clampi(int(ceil(SLOT_SIZE.y * 0.022)), 7, 20))
		if has_meta("_pv_name_mh"):
			name_label.custom_minimum_size = Vector2(0, clampi(int(get_meta("_pv_name_mh")), 20, 420))
		else:
			name_label.custom_minimum_size = Vector2(0, clampi(int(SLOT_SIZE.y * 0.12), 24, 200))
		name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		match c.rarity:
			"uncommon":
				name_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.65, 1))
			"rare":
				name_label.add_theme_color_override("font_color", Color(0.55, 0.75, 0.95, 1))
			"legendary":
				name_label.add_theme_color_override("font_color", Color(0.95, 0.7, 0.88, 1))
			_:
				name_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.88, 0.95))
		name_label.visible = true
	var stars_row: HBoxContainer = icon_row.get_node_or_null("MtgStarsRow") as HBoxContainer if icon_row else null
	if stars_row:
		for ch in stars_row.get_children():
			ch.queue_free()
		var sn: int = _mtg_star_display_count(c)
		var unit_tex: Texture2D = UiAssetLoader.star_unit_gold_svg()
		var spx: int = clampi(int(round(float(SLOT_SIZE.x) / 25.0)), 9, 20)
		stars_row.custom_minimum_size.y = spx + 4
		if sn > 0 and unit_tex:
			for __s in range(sn):
				var tr := TextureRect.new()
				tr.texture = unit_tex
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				tr.custom_minimum_size = Vector2(spx, spx)
				stars_row.add_child(tr)
		elif sn > 0:
			var star_lbl := Label.new()
			var seg := ""
			for __j in range(sn):
				seg += "★"
			star_lbl.text = seg
			star_lbl.add_theme_font_size_override("font_size", clampi(spx + 4, 12, 28))
			star_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.22, 1.0))
			star_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			stars_row.add_child(star_lbl)
		stars_row.visible = sn > 0
	var tip_parts: Array[String] = []
	tip_parts.append("[%s] %s" % [c.rarity, DefaultCards.safe_name(c)])
	if not c.type_line.is_empty():
		tip_parts.append(c.type_line)
	var combat_tip: String = BackpackCombatPreview.build_line(c)
	var use_combat_only: bool = (
		not combat_tip.is_empty()
		and c.card_type == GC.CardType.COMBAT_UNIT
	)
	if use_combat_only:
		tip_parts.append(combat_tip)
	elif not c.summary_line.is_empty():
		tip_parts.append(c.summary_line)
	tooltip_text = "\n".join(tip_parts)
	_apply_card_chrome(c)
	if art_clip:
		call_deferred("_layout_mtg_art_clip", art_clip)


func mtg_preview_refresh_art_layout() -> void:
	if not (has_meta("_pv_mtg_layout") and bool(get_meta("_pv_mtg_layout"))):
		return
	var icon_row: Control = get_node_or_null("VBox/ContentMargin/InnerVBox/IconRow") as Control
	if icon_row == null:
		return
	var art_clip: Control = icon_row.get_node_or_null("MtgArtClip") as Control
	if art_clip:
		_layout_mtg_art_clip(art_clip)


func _on_gui_input(ev: InputEvent) -> void:
	BackpackCardItemDrag.on_gui_input(self, ev)

## 开始拖拽
func _start_drag() -> void:
	BackpackCardItemDrag.start_drag(self)

func _get_cached_icon_texture(tex_path: String) -> Texture2D:
	if tex_path.is_empty():
		return null
	if _icon_cache.has(tex_path):
		return _icon_cache[tex_path] as Texture2D
	# 源文件缺失时 .import 仍可能存在，exists/load 会报错；先检查实际文件
	if not FileAccess.file_exists(tex_path):
		_icon_cache[tex_path] = null
		return null
	if not ResourceLoader.exists(tex_path, "Texture2D"):
		_icon_cache[tex_path] = null
		return null
	var loaded: Resource = ResourceLoader.load(tex_path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	if loaded == null or not (loaded is Texture2D):
		_icon_cache[tex_path] = null
		return null
	var icon_tex: Texture2D = loaded as Texture2D
	_icon_cache[tex_path] = icon_tex
	return icon_tex

func _get_drag_preview_parent() -> Node:
	return BackpackCardItemDrag.get_drag_preview_parent(self)

## 更新拖拽预览位置
func _update_drag_preview() -> void:
	BackpackCardItemDrag.update_drag_preview(self)

## 检查鼠标下的槽位（轻量版：不每帧查找节点）
func _check_slot_under_mouse() -> void:
	BackpackCardItemDrag.check_slot_under_mouse(self)

## 结束拖拽
func _end_drag() -> void:
	BackpackCardItemDrag.end_drag(self)

func _apply_slot_hover_feedback(slot: Control) -> void:
	BackpackCardItemDrag.apply_slot_hover_feedback(self, slot)

func _clear_slot_hover_feedback() -> void:
	BackpackCardItemDrag.clear_slot_hover_feedback(self)

func _clear_single_slot_hover_feedback(slot: Control) -> void:
	BackpackCardItemDrag.clear_single_slot_hover_feedback(slot)

## 查找相位仪面板的槽位容器
func _find_phase_instrument_panel() -> Node:
	# HUD 重构后底部栏位于 HudLayer/BattleBottomBar/BottomInstrumentBar。
	var bottom_bar = get_node_or_null("/root/Main/HudLayer/BattleBottomBar/BottomInstrumentBar")
	if bottom_bar == null:
		# 兼容旧结构
		bottom_bar = get_node_or_null("/root/Main/HudLayer/BottomInstrumentBar")
	if bottom_bar == null:
		# 兜底：按名称搜索，避免路径变更后拖拽失效
		var main_root: Node = get_node_or_null("/root/Main")
		if main_root != null:
			bottom_bar = main_root.find_child("BottomInstrumentBar", true, false)
	if not bottom_bar:
		return null
	var section = bottom_bar.get("instrument_section")
	if section and is_instance_valid(section):
		return section
	section = bottom_bar.get_node_or_null("Margin/HBox/InstrumentSection")
	if section:
		return section
	return null

## 查找鼠标下的槽位
func _find_slot_under_mouse() -> Control:
	return BackpackCardItemDrag.find_slot_under_mouse(self)

## 获取相位仪可放置槽位节点（兼容旧版和新版底栏结构）
func _get_phase_slot_controls(instrument_section: Node) -> Array:
	return BackpackCardItemDrag.get_phase_slot_controls(instrument_section)

func _cache_slot_controls_for_drag() -> void:
	BackpackCardItemDrag.cache_slot_controls_for_drag(self)

func _clear_drag_slot_cache() -> void:
	BackpackCardItemDrag.clear_drag_slot_cache(self)

## 尝试装备到槽位
func _try_equip_to_slot(slot: Control) -> void:
	BackpackCardItemDrag.try_equip_to_slot(self, slot)

## 计算扁平索引（参考 bottom_instrument_bar.gd 的 _slot_to_flat_index）
func _calculate_flat_index(slot_color: String, slot_index: int) -> int:
	return BackpackCardItemDrag.calculate_flat_index(self, slot_color, slot_index)

## 隐藏 BackpackOverlay
func _hide_backpack_overlay() -> void:
	BackpackCardItemDrag.hide_backpack_overlay(self)

## 显示 BackpackOverlay
func _show_backpack_overlay() -> void:
	BackpackCardItemDrag.show_backpack_overlay(self)

	# print("[CustomDrag] 无法找到 BackpackOverlay")

## 拖拽结束时调用（保留以兼容，但现在使用自定义拖拽）
func _notification(what: int) -> void:
	# 不再使用内置拖拽系统
	pass
