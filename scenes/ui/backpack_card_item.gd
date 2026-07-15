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
## v8.0: 底部信息栏高度（顶行卡名+底行详情，36px 适配 80x120 卡面）
const COMPACT_BOTTOM_TEXT_H := 36
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
const DesignTokens = preload("res://resources/design_tokens.gd")
## v8.0: 背包卡牌独立大卡面尺寸（80x120），不再与战场相位仪槽位(50x80)共用。
## 拖拽到相位仪槽位时视觉对齐由 backpack_card_item_drag 处理（预览缩放）。
var SLOT_SIZE: Vector2 = Vector2(80, 120)
## 兼容别名（部分历史代码引用 BACKPACK_CARD_SIZE）
const BACKPACK_CARD_SIZE := Vector2(80, 120)
## 信息栏高度（底部 30% 区域）
const INFO_BAR_HEIGHT := 36
## 列表内卡图：图标区填满 70% 高度
var CARD_LIST_ICON_DISPLAY_MIN: Vector2 = Vector2(72, 72)
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

# v7.x hover 动效状态
var _hover_tween: Tween = null
var _pulse_tween: Tween = null
var _hover_base_style: StyleBoxFlat = null  # hover 进入前的 stylebox，退出时恢复
var _is_hovering := false
var _hover_base_pos_y: float = 0.0  # hover 进入前 position.y，退出/复位时恢复


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
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

	# v7.3 性能优化：process_frame 不在 _ready 无条件连接。
	# 原实现每个卡牌条目都 connect SceneTree.process_frame，背包几十张卡 = 每帧几十次回调（即使不拖拽也空跑），
	# 且对象池回收时不断开，游离 item 持续触发。改为按需连接：start_drag 时连，end_drag/exit_tree 时断。


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



## v7.3: 仅在拖拽开始时连接 process_frame（按需连接，消除空跑开销）
func _connect_drag_frame() -> void:
	var tree = get_tree()
	if tree and is_instance_valid(tree):
		if not tree.process_frame.is_connected(_check_drag_state):
			tree.process_frame.connect(_check_drag_state)

## v7.3: 拖拽结束时断开 process_frame
func _disconnect_drag_frame() -> void:
	var tree = get_tree()
	if tree and is_instance_valid(tree):
		if tree.process_frame.is_connected(_check_drag_state):
			tree.process_frame.disconnect(_check_drag_state)

func _check_drag_state() -> void:
	BackpackCardItemDrag.check_drag_state(self)

func _disconnect_drag_frame_hook() -> void:
	BackpackCardItemDrag.disconnect_drag_frame_hook(self)

func _exit_tree() -> void:
	# v7.3: 退出树时确保断开 process_frame（防对象池游离节点持续触发）
	_disconnect_drag_frame()
	BackpackCardItemDrag.exit_tree_cleanup(self)
	# v7.x：清理 hover/脉冲 Tween，防对象池游离节点持续触发
	_kill_hover_tweens()

## v7.x hover 动效：上浮 + 发光增强；Legendary/Mythic 额外脉冲（仅 hover 时）
func _on_mouse_entered() -> void:
	if card == null:
		return
	_is_hovering = true
	z_index = 10  # 上浮时置顶，避免被相邻卡遮挡
	_hover_base_pos_y = position.y  # 记录基底，退出/复位时恢复
	# 记录当前 stylebox 作为 hover 基底（退出时恢复）
	var cur := get_theme_stylebox("panel")
	if cur is StyleBoxFlat:
		_hover_base_style = (cur as StyleBoxFlat)
	else:
		_hover_base_style = null
	var motion_reduce: bool = DesignTokens.is_motion_reduce()
	if not motion_reduce:
		# 上浮：position.y 上移 2px + scale 微放大（并行 Tween）
		_hover_tween = create_tween()
		_hover_tween.set_parallel(true)
		_hover_tween.tween_property(self, "position:y", position.y - 2.0, 0.10).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(self, "scale", Vector2(1.03, 1.03), 0.10).set_ease(Tween.EASE_OUT)
	# 发光增强：复制基底 stylebox，shadow_size +2 / shadow_alpha +0.15
	_apply_hover_glow_style(true)
	# Legendary/Mythic 脉冲（仅 hover 时，零 idle 开销；motion_reduce 时跳过）
	if not motion_reduce and (card.rarity == "legendary" or card.rarity == "mythic"):
		_start_pulse_glow()

func _on_mouse_exited() -> void:
	if not _is_hovering:
		return
	_is_hovering = false
	z_index = 0
	_kill_hover_tweens()
	var motion_reduce: bool = DesignTokens.is_motion_reduce()
	if not motion_reduce:
		_hover_tween = create_tween()
		_hover_tween.set_parallel(true)
		_hover_tween.tween_property(self, "position:y", _hover_base_pos_y, 0.15).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
	# 恢复 hover 前 stylebox
	if _hover_base_style != null:
		add_theme_stylebox_override("panel", _hover_base_style)
	else:
		remove_theme_stylebox_override("panel")

## 构建 hover 增强发光 stylebox（duplicate 基底，避免污染缓存共享对象）并应用
func _apply_hover_glow_style(increase: bool) -> void:
	if _hover_base_style == null:
		return
	var hover_style := (_hover_base_style.duplicate()) as StyleBoxFlat
	if increase:
		hover_style.shadow_size = clampi(hover_style.shadow_size + 2, 0, 16)
		var sc: Color = hover_style.shadow_color
		hover_style.shadow_color = Color(sc.r, sc.g, sc.b, clampf(sc.a + 0.15, 0.0, 1.0))
	add_theme_stylebox_override("panel", hover_style)

## Legendary/Mythic 脉冲：循环呼吸 shadow_alpha（base↔base+0.2）
func _start_pulse_glow() -> void:
	if _hover_base_style == null:
		return
	var base_a: float = _hover_base_style.shadow_color.a
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_method(_set_pulse_glow_alpha, base_a, clampf(base_a + 0.2, 0.0, 1.0), 0.6)
	_pulse_tween.tween_method(_set_pulse_glow_alpha, clampf(base_a + 0.2, 0.0, 1.0), base_a, 0.6)

func _set_pulse_glow_alpha(a: float) -> void:
	if _hover_base_style == null or not _is_hovering:
		return
	var s := (_hover_base_style.duplicate()) as StyleBoxFlat
	var sc: Color = s.shadow_color
	s.shadow_color = Color(sc.r, sc.g, sc.b, a)
	s.shadow_size = clampi(s.shadow_size + 2, 0, 16)  # 保持 hover 增强档
	add_theme_stylebox_override("panel", s)

func _kill_hover_tweens() -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = null
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null

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
	# v7.x：池化复用复位 hover 变换残留（position/scale/z_index）
	if _is_hovering or _hover_tween != null or _pulse_tween != null:
		_kill_hover_tweens()
		_is_hovering = false
		z_index = 0
		scale = Vector2(1.0, 1.0)
		position.y = _hover_base_pos_y  # 恢复 hover 进入前的 y
	var icon_row_sync: Control = _find_icon_row()
	if icon_row_sync:
		var want_mtg: bool = _backpack_uses_mtg_face()
		if icon_row_sync.get_meta("_mtg_preview_built", false) and not want_mtg:
			_restore_icon_row_from_mtg_preview(icon_row_sync)
		if icon_row_sync.get_meta("_compact_slot_built", false) and want_mtg:
			_restore_compact_slot_structure(icon_row_sync)
	var icon_rect: TextureRect = _find_icon_row_icon()
	var name_label: Label = _find_slot_name_label()
	var lv_label: Label = get_node_or_null("VBox/ContentMargin/InnerVBox/LvLabel") as Label

	if c == null:
		_set_empty_style(name_label, lv_label, icon_rect)
		return

	if ENABLE_MINIMAL_CARD_RENDER:
		_set_minimal_card_view(c, name_label, lv_label, icon_rect)
		return

	# ── 卡名 ─────────────────────────────────────────────────
	if name_label:
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.max_lines_visible = 1
		name_label.text = _compact_display_name(c)
		name_label.visible = true
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# 字体颜色跟随稀有度（统一到 GC.get_rarity_color）
		name_label.add_theme_color_override("font_color", GC.get_rarity_color(c.rarity))

	# ── 图标 ──────────────────────────────────────────────────
	if icon_rect:
		_apply_card_icon_rect(icon_rect, c, CARD_LIST_ICON_DISPLAY_MIN)

	# ── 能量费用（左上角角标气泡）──────────────────────────────
	var _cost_badge_n = CardFrameUi.ensure_cost_corner_badge(self, true)
	if _cost_badge_n != null:
		_cost_badge_n.energy_value = int(c.energy_cost)

	# ── 等级（名称下方紧凑小字）────────────────────────────────
	if lv_label:
		if BlueprintManager and BlueprintManager.has_method("get_card_xp_progress"):
			var prog: Dictionary = BlueprintManager.get_card_xp_progress(c.card_id)
			var lvl: int = int(prog.get("level", 1))
			lv_label.text = "Lv.%d" % lvl
			lv_label.visible = true
		else:
			lv_label.text = ""
			lv_label.visible = false

	_apply_card_chrome(c)

	tooltip_text = ""

func _set_empty_style(name_label, lv_label, icon_rect) -> void:
	# v7.x：空格子清除费用角标，避免旧角标残留
	CardFrameUi.clear_cost_corner_badge(self)
	if name_label:
		name_label.text = ""
		name_label.visible = false
	if lv_label:
		lv_label.text = ""
		lv_label.visible = false
	if icon_rect:
		icon_rect.texture = null
		icon_rect.visible = false
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


func _set_minimal_card_view(c: CardResource, name_label, lv_label, icon_rect) -> void:
	if _backpack_uses_mtg_face():
		_set_mtg_minimal_card_view(c, name_label, lv_label, icon_rect)
		return
	_set_compact_slot_view(c, name_label, lv_label, icon_rect)


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
		var min_rep: int = EC.get_min_reputation(c.card_id)
		if fsm.get_active_faction() == faction_id and fsm.get_faction_reputation(faction_id) >= min_rep:
			available = true
	if not available:
		modulate = Color(0.5, 0.5, 0.5, 0.7)
		tooltip_text = "需要激活 %s 势力且声望 >= %d" % [
			EC.get_exclusive_faction(c.card_id),
			EC.get_min_reputation(c.card_id)]
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


## v8.0: 稀有度增强边框 + 发光效果
## common: 1px 灰边无光 | uncommon: 1px 绿边 + 2px柔光
## rare: 2px 蓝边 + 3px光 | epic: 2px 紫边 + 4px光
## legendary: 2px 金边 + 6px光 | mythic: 2px 粉边 + 8px光
func _apply_card_border_flat(c: CardResource) -> void:
	var cache_key: String = "%d_%s" % [int(c.card_type), str(c.rarity)]
	if _card_border_style_cache.has(cache_key):
		add_theme_stylebox_override("panel", _card_border_style_cache[cache_key])
		return
	var panel_style := StyleBoxFlat.new()
	# v7.x：底色改用稀有度分层（与 PNG 框路径 apply_panel_with_frame 统一来源）
	panel_style.bg_color = CardFrameUi._rarity_bg_color(c.rarity)
	panel_style.set_corner_radius_all(6)
	# 稀有度统一配色（GC.get_rarity_color 作为单一数据源）
	var rarity_col: Color = GC.get_rarity_color(c.rarity)
	# 默认边框（common 基准）
	var bw: int = 1
	var shadow_alpha: float = 0.0
	var shadow_size: int = 0
	match c.rarity:
		"common":
			bw = 1; shadow_alpha = 0.0; shadow_size = 0
		"uncommon":
			bw = 1; shadow_alpha = 0.30; shadow_size = 2
		"rare":
			bw = 2; shadow_alpha = 0.35; shadow_size = 3
		"epic":
			bw = 2; shadow_alpha = 0.45; shadow_size = 4
		"legendary":
			bw = 2; shadow_alpha = 0.55; shadow_size = 6
		"mythic":
			bw = 2; shadow_alpha = 0.65; shadow_size = 8
	panel_style.border_color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.90)
	panel_style.set_border_width_all(bw)
	if shadow_size > 0:
		panel_style.shadow_color = Color(rarity_col.r, rarity_col.g, rarity_col.b, shadow_alpha)
		panel_style.shadow_size = shadow_size
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
	_empty_card_panel_style.set_corner_radius_all(6)
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
	if text_v:
		name_lbl = text_v.get_node_or_null("NameLabel") as Label
		if name_lbl:
			text_v.remove_child(name_lbl)
		text_v.queue_free()
	if icon and icon.get_parent() != icon_row:
		icon_row.add_child(icon)
	if name_lbl and name_lbl.get_parent() != icon_row:
		icon_row.add_child(name_lbl)
	if icon:
		icon_row.move_child(icon, 0)
	if name_lbl and is_instance_valid(name_lbl):
		var idx := mini(1, icon_row.get_child_count() - 1)
		icon_row.move_child(name_lbl, idx)
	if icon_row.has_meta("_compact_slot_built"):
		icon_row.remove_meta("_compact_slot_built")
	if icon:
		_apply_icon_texture_rect_fixed(icon, CARD_LIST_ICON_DISPLAY_MIN)


## 清理 icon_row 中的所有动态创建的子节点，避免新旧UI结构叠加
func _cleanup_icon_row_children(icon_row: Control) -> void:
	if icon_row == null:
		return
	# 查找并移除动态创建的节点（CompactArtClip, CompactTextVBox, MtgArtClip 等）
	var dynamic_nodes = ["CompactArtClip", "CompactTextVBox", "MtgArtClip", "MtgHeader", "MtgStarsRow"]
	for node_name in dynamic_nodes:
		var node = icon_row.get_node_or_null(node_name)
		if node and is_instance_valid(node):
			icon_row.remove_child(node)
			node.queue_free()


func _ensure_compact_slot_structure(icon_row: Control, name_label: Label) -> void:
	if icon_row == null or name_label == null:
		return
	if icon_row.get_meta("_compact_slot_built", false):
		return
	if icon_row.get_node_or_null("CompactArtClip") != null:
		icon_row.set_meta("_compact_slot_built", true)
		return

	# 修复两层面板问题：在创建新结构之前，完全清理icon_row中的所有子节点
	# 避免新旧UI结构叠加
	_cleanup_icon_row_children(icon_row)

	if icon_row.get_meta("_mtg_preview_built", false):
		_restore_icon_row_from_mtg_preview(icon_row)

	var icon: TextureRect = icon_row.find_child("Icon", true, false) as TextureRect
	if icon == null:
		return
	if icon.get_parent() == icon_row:
		icon_row.remove_child(icon)
	if name_label.get_parent() == icon_row:
		icon_row.remove_child(name_label)
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
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 1.0))
	text_v.add_child(name_label)
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
	# v8.0 修复：图标在 CompactArtClip 内用 FULL_RECT 填满，不强制 custom_minimum_size。
	# 仅更新纹理和拉伸模式，尺寸由容器布局决定（STRETCH_KEEP_ASPECT_CENTERED 保持比例）。
	var tex: Texture2D = icon.texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if tex == null:
		icon.visible = false


## v8.0: 把图标纹理应用到 CompactArtClip 内的 Icon（不设最小尺寸，纯靠容器裁切）
func _apply_card_icon_to_clip(icon_rect: TextureRect, c: CardResource) -> void:
	if icon_rect == null or c == null:
		return
	var tex_path := _card_icon_tex_path(c)
	var tex: Texture2D = _get_cached_icon_texture(tex_path)
	if tex == null:
		icon_rect.texture = null
		icon_rect.visible = false
		return
	icon_rect.texture = tex
	icon_rect.visible = true
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _compact_display_name(c: CardResource) -> String:
	var display_name: String = "能量" if c.card_type == GC.CardType.ENERGY else DefaultCards.safe_name(c)
	if display_name.is_empty():
		display_name = DefaultCards.get_safe_display_name(c.card_id)
	if display_name.length() > 6:
		# v6.2 修复 L3：超长名截断加省略号（原 substr 直接截断，中文可能残缺）
		display_name = display_name.substr(0, 6) + "…"
	# v7.x：同名卡追加序号后缀（#1/#2…），在截断之后追加，避免序号被截断
	return display_name + DefaultCards.seq_suffix(c)


## v8.0: 80x120 大卡面紧凑视图——图标区(70%) + 双行信息栏(30%)
## 顶行：★★★★★ 卡名  Cost角标 | 底行：兵种 Lv.x/10 🔧x/y 战力
func _set_compact_slot_view(c: CardResource, name_label, lv_label, icon_rect) -> void:
	var icon_row: Control = _find_icon_row()
	if icon_row:
		icon_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if lv_label:
		# 底行信息：兵种|等级|改造|战力 —— 横向紧凑排列
		lv_label.text = _build_bottom_info_line(c)
		lv_label.visible = true
		lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv_label.add_theme_font_size_override("font_size", 11)
		lv_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.95))
	if icon_row == null or name_label == null:
		return
	_ensure_compact_slot_structure(icon_row, name_label)
	var art_clip: Control = icon_row.get_node_or_null("CompactArtClip") as Control
	if icon_rect:
		# v8.0 修复：图标不设强制最小尺寸，纯靠 CompactArtClip 容器裁切 + FULL_RECT 自适应。
		# 原传 CARD_LIST_ICON_DISPLAY_MIN(72x72) 会强制撑爆容器导致卡图溢出卡外。
		_apply_card_icon_to_clip(icon_rect, c)
	name_label.visible = true
	# 顶行：星级前缀 + 卡名
	var star_str: String = _build_star_prefix(c)
	name_label.text = star_str + _compact_display_name(c)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.max_lines_visible = 1
	# 费用用左上角角标气泡（CostCornerBadge）
	var _cost_badge_c = CardFrameUi.ensure_cost_corner_badge(self, true)
	if _cost_badge_c != null:
		_cost_badge_c.energy_value = int(c.energy_cost)
	tooltip_text = ""
	_apply_card_chrome(c)
	if art_clip:
		call_deferred("_layout_compact_art_clip", art_clip)


## v8.0: 构建星级前缀字符串（金色★，最多显示5星避免撑爆）
func _build_star_prefix(c: CardResource) -> String:
	var stars: int = 0
	if BlueprintManager and BlueprintManager.has_method("get_card_xp_progress"):
		var prog: Dictionary = BlueprintManager.get_card_xp_progress(c.card_id)
		stars = int(prog.get("level", 0))
	else:
		stars = int(c.enhance_level)
	stars = clampi(stars, 0, 5)
	if stars <= 0:
		return ""
	# v6.8 收敛后稀有度压缩，星级仍是养成进度主指标
	return "★".repeat(stars) + " "


## v8.0: 构建底行信息——兵种|等级|改造|战力
func _build_bottom_info_line(c: CardResource) -> String:
	var parts: Array[String] = []
	# 兵种标识（仅战斗卡）
	if c.card_type == GC.CardType.COMBAT_UNIT:
		parts.append(CardResource.get_combat_kind_short(c.combat_kind))
	# 强化等级 Lv.x/10
	var enhance_lvl: int = int(c.enhance_level)
	parts.append("Lv%d/10" % enhance_lvl)
	# 改造槽位 🔧N/M
	if c.card_type == GC.CardType.COMBAT_UNIT:
		var mod_count: int = _get_mod_count_for_card(c)
		var slot_total: int = c.module_slots.size() if c.module_slots != null else 0
		if slot_total > 0:
			parts.append("改%d/%d" % [mod_count, slot_total])
	# 战力分（千位取整）
	var power: int = int(_get_card_power_score(c))
	if power > 0:
		parts.append("力%d" % power)
	return "  ".join(parts)


## v8.0: 安全获取改造数量（兼容实例/模板）
func _get_mod_count_for_card(c: CardResource) -> int:
	if c == null:
		return 0
	if c.mods != null:
		return c.mods.size()
	if BlueprintManager and BlueprintManager.has_method("get_modification_count"):
		return BlueprintManager.get_modification_count(c.card_id)
	return 0


## v8.0: 安全获取战力分（复用 evolution_helpers）
func _get_card_power_score(c: CardResource) -> float:
	if c == null:
		return 0.0
	# 优先用实例感知的 estimate_power（含养成/改造/进化加成）
	var id_for_power: String = c.instance_id if not c.instance_id.is_empty() else c.card_id
	if BlueprintManager and BlueprintManager.has_method("_estimate_power_score_meta_only"):
		return BlueprintManager._estimate_power_score_meta_only(id_for_power)
	return 0.0


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
	name_hdr.add_theme_font_size_override("font_size", 10)
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
	cost_lbl.add_theme_font_size_override("font_size", 10)
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


func _set_mtg_minimal_card_view(c: CardResource, name_label, lv_label, icon_rect) -> void:
	# 线框式竖卡：顶栏为「全名 | 军衔 | 费用」，不占单独色条
	var icon_row: Control = get_node_or_null("VBox/ContentMargin/InnerVBox/IconRow") as Control
	if icon_row:
		icon_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 费用用左上角角标气泡（CostCornerBadge）
	var _cost_badge_mm = CardFrameUi.ensure_cost_corner_badge(self, true)
	if _cost_badge_mm != null:
		_cost_badge_mm.energy_value = int(c.energy_cost)
	if lv_label:
		# MTG 模式下等级显示在 InnerVBox 下方
		if BlueprintManager and BlueprintManager.has_method("get_card_xp_progress"):
			var prog: Dictionary = BlueprintManager.get_card_xp_progress(c.card_id)
			var lvl: int = int(prog.get("level", 1))
			lv_label.text = "Lv.%d" % lvl
			lv_label.visible = true
		else:
			lv_label.text = ""
			lv_label.visible = false
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
			rank_hdr.add_theme_font_size_override("font_size", clampi(int(ceil(SLOT_SIZE.y * 0.026)), 11, 17))
	if cost_hdr:
		# v7.x：费用从 MtgHeader/MtgCostLabel 移到左上角角标气泡（CostCornerBadge）
		cost_hdr.text = ""
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
		name_label.add_theme_font_size_override("font_size", clampi(int(ceil(SLOT_SIZE.y * 0.022)), 11, 20))
		if has_meta("_pv_name_mh"):
			name_label.custom_minimum_size = Vector2(0, clampi(int(get_meta("_pv_name_mh")), 20, 420))
		else:
			name_label.custom_minimum_size = Vector2(0, clampi(int(SLOT_SIZE.y * 0.12), 24, 200))
		name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		# 统一稀有度配色到 GC.get_rarity_color
		name_label.add_theme_color_override("font_color", GC.get_rarity_color(c.rarity))
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
