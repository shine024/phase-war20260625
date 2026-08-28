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
## v9.3: 底部信息栏高度（顶行卡名+底行详情）。40px 适配 108×154 大卡面——
## 立绘区 102×108（高 = SLOT_SIZE.y − 40 − 6），占比 ~70%，底栏 ~26%：卡图清晰但不挤压底栏。
## name(14) + sep(1) + stat(9) ≈ 24px 内容，40px 容器留 16px 余量，舒展不压缩。
## 注：曾试 32px（立绘区 116 占 75%），卡图过大挤占底栏 + 立绘纵向变形 13%，故回调 40。
const COMPACT_BOTTOM_TEXT_H := 40
const ENABLE_IMAGE_DRAG_PREVIEW := true
var _last_drag_log_ms: int = 0
var _drag_started_ms: int = 0
const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const BackpackCombatPreview = preload("res://scenes/ui/backpack_combat_preview.gd")
const RankDisplayUi = preload("res://scripts/rank_display_ui.gd")
const CardFrameUi = preload("res://scripts/card_frame_ui.gd")
const CardBackgroundUi = preload("res://scripts/card_background_ui.gd")
const DesignTokens = preload("res://resources/design_tokens.gd")
const UnifiedCardTable = preload("res://data/unified_card_table.gd")  # v20.13c: tooltip 预览每卡部署次数
## v9.3: 背包卡牌大卡面尺寸（108×154），立绘区约 102×116，承载更多视觉信息（5星+兵种色块+Lv+战力+EQUIP徽章）。
## 拖拽到相位仪槽位时视觉对齐由 backpack_card_item_drag 处理（预览缩放，引用本变量自动适配）。
var SLOT_SIZE: Vector2 = Vector2(108, 154)
## 兼容别名（部分历史代码引用 BACKPACK_CARD_SIZE）
const BACKPACK_CARD_SIZE := Vector2(108, 154)
## 信息栏高度（底部约 30% 区域）
const INFO_BAR_HEIGHT := 42
## 列表内卡图：图标区填满 70% 高度
var CARD_LIST_ICON_DISPLAY_MIN: Vector2 = Vector2(72, 72)
## 拖拽预览外框同槽位；内图标竖向略小于外框
const DRAG_PREVIEW_ICON_DISPLAY_MIN := Vector2(36, 56)
var _icon_cache: Dictionary = {}
## v9.4: 视口裁切状态——当前卡牌图标是否已加载纹理。
## false 时 icon_rect 显示 placeholder glyph，进入视口后才真正加载（避免 OOM）。
var _icon_loaded: bool = false
## v9.4: 当前关联的 icon_rect（set_card 时记录），供滚动钩子重扫时复用。
var _bound_icon_rect: TextureRect = null

# 各卡片类型对应的顶部色条颜色
const TYPE_BAR_COLORS := {
	GC.CardType.COMBAT_UNIT: Color(0.1, 0.5, 0.9, 1.0),
	GC.CardType.ENERGY:      Color(0.15, 0.75, 0.35, 1.0),
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
## v7.x: 选择模式状态




func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# P1-5: 可点击卡牌用手型光标（非 Button 控件不在全局 node_added 钩子覆盖范围）
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
	# v9.x 修复：创建装饰中间层（非 Container 的 Control）。
	# BackpackCardItem 是 PanelContainer，会对所有直接子节点强制 fit_child_in_rect（填满整卡）。
	# 装饰节点（RarityTopStrip/EquippedMark/InstanceNo/EvolutionMark）需要按
	# anchor/offset 定位到卡牌局部位置，不能被强制拉伸。把它们挂到 DecorationLayer 下：
	# DecorationLayer 本身被父 PanelContainer 拉伸到整卡（符合预期，它就是全卡覆盖层），
	# 但它是 Control（非 Container），不会强制布局自己的子节点，装饰的 anchor/offset 正常生效。
	_ensure_decoration_layer()

	# v7.3 性能优化：process_frame 不在 _ready 无条件连接。
	# 原实现每个卡牌条目都 connect SceneTree.process_frame，背包几十张卡 = 每帧几十次回调（即使不拖拽也空跑），
	# 且对象池回收时不断开，游离 item 持续触发。改为按需连接：start_drag 时连，end_drag/exit_tree 时断。


## 卡图等比缩放到固定槽位（不随贴图像素尺寸撑开布局）
## v9.4: 列表场景默认走缩略图（card_icon_path_for_list），VRAM 占用降至 1/4~1/16，
## 避免背包一次性渲染上百张全分辨率图标导致 OOM。全分辨率图保留给战场/卡详情。
func _card_icon_tex_path(c: CardResource) -> String:
	if c == null:
		return ""
	return UiAssetLoader.card_icon_path_for_list(c)


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
	# v7.x: 退出树时确保断开 process_frame（防对象池游离节点持续触发）
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
		# v9.4: 重置视口裁切状态，避免池化复用时残留"已加载"标记
		_icon_loaded = false
		_bound_icon_rect = null
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
	# 2026-08-22：原 get_card_xp_progress 恒返 Lv.1（已随蓝图体系移除），
	# 改用 v19 真实口径：实例战斗等级（InstanceRegistry.get_card_level）
	if lv_label:
		var lvl: int = _real_card_level(c)
		if lvl > 0:
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
	# v9.1：空槽清理所有装饰层（防池化复用残留）
	_hide_decoration("RarityTopStrip")

	_hide_decoration("StarsOverlay")
	_hide_decoration("EquippedMark")
	_hide_decoration("InstanceNo")
	_hide_decoration("EvolutionMark")

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
		modulate = DesignTokens.COLOR_HOVER_WHITE


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
	panel_style.set_corner_radius_all(4)
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
	_empty_card_panel_style.set_corner_radius_all(4)
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
	# v9.1 修复：Control 在 VBoxContainer 中若没有内容/最小尺寸会塌缩为 0×0，
	# 导致 Icon（FULL_RECT 锚定）实际渲染区域为 0，卡图不可见（"闪一下就消失"）。
	# 给一个与 SLOT_SIZE 匹配的图标区最小尺寸（高度预留 footer 38px + 顶部色条 3px + 边距）。
	art_clip.custom_minimum_size = Vector2(SLOT_SIZE.x - 6, SLOT_SIZE.y - COMPACT_BOTTOM_TEXT_H - 6)
	art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# v9.3：底层氛围背景（暗蓝底 + 顶部蓝渐变 + 中心高光），无图卡不再空洞；对齐 HTML .art 渐变
	var backdrop := _ArtBackdrop.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_clip.add_child(backdrop)
	# v9.3：无图占位 glyph（兵种字，大号半透明蓝），有图时由 _apply_card_icon_to_clip 隐藏
	var placeholder := Label.new()
	placeholder.name = "Placeholder"
	placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.add_theme_font_size_override("font_size", 34)
	placeholder.add_theme_color_override("font_color", Color(0.30, 0.50, 0.90, 0.22))
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder.visible = false
	art_clip.add_child(placeholder)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# v9.1：用 SCALE（铺满容器，可能轻微变形）而非 COVERED——COVERED 在 Godot 4.5 的
	# EXPAND_IGNORE_SIZE 模式下仍按贴图原尺寸居中渲染（实测卡图不显示）。
	# SCALE 让贴图强制拉伸到 Icon 的 size，配合锚定 = 填满立绘区。
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	# v9.3：立绘顶部留 14px 让出星辰区（星辰在卡顶 y7~17；art_clip 从卡 y3 起，
	# offset_top=14 → 立绘从卡 y17 开始，紧贴星辰下方，不再重叠）。
	icon.anchor_left = 0.0
	icon.anchor_top = 0.0
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.offset_left = 0.0
	icon.offset_top = 14.0
	icon.offset_right = 0.0
	icon.offset_bottom = 0.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_clip.add_child(icon)
	# v9.1 HTML 设计稿 footer 结构：name-line + stat-line（HBox: 左 Lv·改N/M / 右 战力）
	var text_v := VBoxContainer.new()
	text_v.name = "CompactTextVBox"
	text_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_v.size_flags_vertical = Control.SIZE_SHRINK_END
	text_v.custom_minimum_size.y = COMPACT_BOTTOM_TEXT_H
	text_v.add_theme_constant_override("separation", 1)
	text_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# name-line：卡名（HTML .name-line，居中、单行省略）
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size = Vector2(0, 14)
	name_label.remove_theme_font_size_override("font_size")
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.91, 0.93, 0.97, 1.0))
	text_v.add_child(name_label)
	# stat-line：左侧 [Lv·改] + 右侧 战力（HTML .stat-line，mono 9px）
	# v9.3：StatLeft 改为 HBox（Lv amber-soft + Mod cyan-soft），三段分色提升扫读性
	var stat_line := HBoxContainer.new()
	stat_line.name = "StatLine"
	stat_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_line.add_theme_constant_override("separation", 0)
	stat_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stat_left := HBoxContainer.new()
	stat_left.name = "StatLeft"
	stat_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_left.add_theme_constant_override("separation", 4)
	stat_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lv_label := Label.new()
	lv_label.name = "Lv"
	lv_label.clip_text = true
	lv_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lv_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_XSMALL)
	lv_label.add_theme_color_override("font_color", DesignTokens.COLOR_AMBER_SOFT)  # amber-soft
	lv_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stat_left.add_child(lv_label)
	var mod_label := Label.new()
	mod_label.name = "Mod"
	mod_label.clip_text = true
	mod_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mod_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
	mod_label.add_theme_color_override("font_color", Color(0.498, 0.851, 1.0, 1.0))  # cyan-soft
	mod_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stat_left.add_child(mod_label)
	stat_line.add_child(stat_left)
	var stat_right := Label.new()
	stat_right.name = "StatRight"
	stat_right.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_XSMALL)
	stat_right.add_theme_color_override("font_color", Color(0.91, 0.93, 0.97, 1.0))
	stat_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stat_line.add_child(stat_right)
	text_v.add_child(stat_line)
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
	# v9.1：SCALE 拉伸填满容器（COVERED/CENTERED 在 EXPAND_IGNORE_SIZE 下实测卡图不显示）
	var tex: Texture2D = icon.texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	if tex == null:
		icon.visible = false


## v8.0: 把图标纹理应用到 CompactArtClip 内的 Icon（不设最小尺寸，纯靠容器裁切）
## v9.4: 懒加载——set_card 时永远只显示 placeholder glyph，不立即加载纹理。
## 原因：_flush_rebuild_card_grid 一次性 add_child 上百张卡，此时节点未布局，
## get_global_rect() 不可靠，无法做视口裁切；且同步加载上百张纹理会触发内存峰值 OOM。
## 贴图加载推迟到布局完成后，由滚动钩子 _check_viewport_visibility 按视口可见性触发。
## 无滚动容器的场景（卡详情弹窗/拖拽预览）由 _check_viewport_visibility 的 _NOTIFICATION_READY 兜底立即加载。
func _apply_card_icon_to_clip(icon_rect: TextureRect, c: CardResource) -> void:
	if icon_rect == null or c == null:
		return
	_bound_icon_rect = icon_rect
	_icon_loaded = false
	_show_icon_placeholder(icon_rect, c)


## v9.4: 实际加载并应用图标纹理（视口内或无滚动容器时调用）。
func _load_and_apply_icon(icon_rect: TextureRect, c: CardResource) -> void:
	var tex_path := _card_icon_tex_path(c)
	var tex: Texture2D = _get_cached_icon_texture(tex_path)
	var art_clip: Control = icon_rect.get_parent() as Control
	var placeholder: Label = null
	if art_clip != null:
		placeholder = art_clip.get_node_or_null("Placeholder") as Label
	if tex == null:
		# 真无图（路径无效/导入失败）：显示 placeholder，标记已加载避免反复重试
		_icon_loaded = true
		_show_icon_placeholder(icon_rect, c, placeholder)
		return
	icon_rect.texture = tex
	icon_rect.visible = true
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# v9.1：SCALE 强制拉伸填满（COVERED/CENTERED 在 EXPAND_IGNORE_SIZE 下实测卡图不显示）
	icon_rect.stretch_mode = TextureRect.STRETCH_SCALE
	if placeholder:
		placeholder.visible = false
	_icon_loaded = true


## v9.4: 显示占位 glyph（无图 或 视口外未加载）。
func _show_icon_placeholder(icon_rect: TextureRect, c: CardResource, placeholder: Label = null) -> void:
	icon_rect.texture = null
	icon_rect.visible = false
	if placeholder == null:
		var art_clip: Control = icon_rect.get_parent() as Control
		if art_clip != null:
			placeholder = art_clip.get_node_or_null("Placeholder") as Label
	if placeholder:
		placeholder.text = "？"
		placeholder.visible = true


## v9.4: 判断本节点是否在某个 ScrollContainer 的可见视口内。
## 沿父链向上找 ScrollContainer；找不到（卡详情弹窗/拖拽预览等无滚动场景）返回 true（视为可见，照常加载）。
## 找到则比较本节点的全局矩形与 ScrollContainer 全局矩形是否相交（含一定预加载边距）。
const _VIEWPORT_PRELOAD_MARGIN := 200.0
func _is_in_any_viewport() -> bool:
	var p: Node = get_parent()
	var scroll: ScrollContainer = null
	while p != null:
		if p is ScrollContainer:
			scroll = p as ScrollContainer
			break
		p = p.get_parent()
	# 无滚动容器 → 视为可见（非列表场景，如弹窗/预览，照常加载全分辨率或缩略图）
	if scroll == null:
		return true
	var self_rect := get_global_rect()
	var view_rect := scroll.get_global_rect()
	# 扩展视口边距，让即将进入视口的卡牌预加载，减少滚动时闪烁
	view_rect = view_rect.grow_individual(_VIEWPORT_PRELOAD_MARGIN, _VIEWPORT_PRELOAD_MARGIN, _VIEWPORT_PRELOAD_MARGIN, _VIEWPORT_PRELOAD_MARGIN)
	return self_rect.intersects(view_rect)


## v9.4: 供 backpack_panel 滚动钩子调用——重扫视口可见性，按需加载/卸载图标。
## 在视口内且未加载 → 加载；在视口外且已加载 → 卸载（仅当当前仍持有同一张卡）。
## 无参重载：自己向上找 ScrollContainer 取视口矩形（用于 set_card 后 deferred 首次加载）。
func _check_viewport_visibility(viewport_rect: Rect2 = Rect2()) -> void:
	if card == null:
		return
	var icon_rect: TextureRect = _bound_icon_rect
	if icon_rect == null or not is_instance_valid(icon_rect):
		icon_rect = _find_icon_row_icon()
		if icon_rect == null:
			return
		_bound_icon_rect = icon_rect
	# 无参调用：自己找 ScrollContainer；找不到（卡详情弹窗等）视为可见，直接加载
	var check_rect: Rect2 = viewport_rect
	if check_rect.size == Vector2.ZERO:
		var scroll: ScrollContainer = null
		var p: Node = get_parent()
		while p != null:
			if p is ScrollContainer:
				scroll = p as ScrollContainer
				break
			p = p.get_parent()
		if scroll == null:
			# 非滚动场景（弹窗/预览）：照常加载
			if not _icon_loaded:
				_load_and_apply_icon(icon_rect, card)
			return
		check_rect = scroll.get_global_rect()
	# 用视口矩形判断，扩展预加载边距
	var self_rect := get_global_rect()
	var grown := check_rect.grow_individual(_VIEWPORT_PRELOAD_MARGIN, _VIEWPORT_PRELOAD_MARGIN, _VIEWPORT_PRELOAD_MARGIN, _VIEWPORT_PRELOAD_MARGIN)
	var in_view: bool = self_rect.intersects(grown)
	if in_view and not _icon_loaded:
		_load_and_apply_icon(icon_rect, card)
	elif not in_view and _icon_loaded:
		# 离开视口：卸载纹理释放 VRAM，保留 placeholder glyph
		_icon_loaded = false
		_show_icon_placeholder(icon_rect, card)


func _compact_display_name(c: CardResource) -> String:
	var display_name: String = "能量" if c.card_type == GC.CardType.ENERGY else DefaultCards.safe_name(c)
	if display_name.is_empty():
		display_name = DefaultCards.get_safe_display_name(c.card_id)
	# v9.3：不再硬编码 6 字截断——name_label 已设 clip_text + overrun ellipsis + 单行，
	# 会在底栏实际宽度（108 卡约 8~9 字）内自适应显示，超长才省略，尽量完整显示卡名。
	# 序号不并入卡名（与右下角 instance-no chip 重复），统一由右下角 chip 显示。
	return display_name


## v9.0: 96×138 大卡面紧凑视图——图标区 + 双行信息栏 + 装饰层
## 装饰层（注入到 PanelContainer 本体，绝对定位）：
##   - RarityTopStrip：顶部 3-4px 稀有度色条
##   - EquippedMark：左上 EQUIP 绿色徽章（仅已装备到相位仪）
##   - EvolutionMark：右下角 EV 紫色标记（进化产物）
func _set_compact_slot_view(c: CardResource, name_label, lv_label, icon_rect) -> void:
	var icon_row: Control = _find_icon_row()
	if icon_row:
		icon_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# v9.1：LvLabel 不再承担混合信息显示，HTML 设计改用 CompactTextVBox/StatLine
	if lv_label:
		lv_label.visible = false
	if icon_row == null or name_label == null:
		return
	_ensure_compact_slot_structure(icon_row, name_label)
	var art_clip: Control = icon_row.get_node_or_null("CompactArtClip") as Control
	if icon_rect:
		_apply_card_icon_to_clip(icon_rect, c)
	name_label.visible = true
	name_label.text = _compact_display_name(c)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.max_lines_visible = 1
	_fill_stat_line(icon_row, c)
	var _cost_badge_c = CardFrameUi.ensure_cost_corner_badge(self, false)
	if _cost_badge_c != null:
		_cost_badge_c.energy_value = int(c.energy_cost)
	# v20.13c: 背包格悬停提示——每卡部署次数（卡面空间有限，决策关键信息放 tooltip；
	# 置于 _apply_card_chrome 之前，势力未激活的锁定提示仍可覆盖本行）
	var du_tip: Array[String] = [_compact_display_name(c)]
	var du_entry: Dictionary = UnifiedCardTable.get_entry(c.card_id)
	if not du_entry.is_empty():
		var du_uses: int = UnifiedCardTable.get_deploy_uses(du_entry, c)
		if du_uses < 99:
			du_tip.append("部署×%d/场" % du_uses)
	# v20.15: 固定机制文案（高价值单位机制提示）
	for mech_line in CardMechanismDesc.get_mechanism_lines(c.tags):
		du_tip.append(mech_line)
	tooltip_text = "\n".join(du_tip)
	_apply_card_chrome(c)
	if art_clip:
		call_deferred("_layout_compact_art_clip", art_clip)
	_apply_v9_decorations(c)
	_ensure_instance_no(c)
	# v9.4: 布局完成后 deferred 触发首次视口可见性扫描——此时 get_global_rect() 已可靠，
	# 滚动钩子（backpack_panel）会在下一帧批量扫描；单卡（弹窗/预览）在此 self-trigger 加载。
	call_deferred("_check_viewport_visibility")


## v9.1: 填充 stat-line（HTML .stat-line 结构：左 Lv·改N/M · 右 战力）
func _fill_stat_line(icon_row: Control, c: CardResource) -> void:
	if icon_row == null:
		return
	# v9.3：StatLeft 现为 HBox（Lv amber-soft + Mod cyan-soft 两个 Label）
	var lv_label: Label = icon_row.get_node_or_null("CompactTextVBox/StatLine/StatLeft/Lv") as Label
	var mod_label: Label = icon_row.get_node_or_null("CompactTextVBox/StatLine/StatLeft/Mod") as Label
	var stat_right: Label = icon_row.get_node_or_null("CompactTextVBox/StatLine/StatRight") as Label
	if lv_label == null or stat_right == null:
		return
	# Lv.x（amber-soft）——v19：战斗等级 card_level（1-30，经验驱动），不再用强化等级
	lv_label.text = "Lv.%d" % _card_level_of(c)
	# 改N/M（cyan-soft，仅战斗卡且有槽位）
	if mod_label != null:
		if c.card_type == GC.CardType.COMBAT_UNIT:
			var mod_count: int = _get_mod_count_for_card(c)
			var slot_total: int = c.module_slots.size() if c.module_slots != null else 0
			mod_label.text = "改%d/%d" % [mod_count, slot_total] if slot_total > 0 else ""
		else:
			mod_label.text = ""
	# 右：战力分（HTML .pwr，text-white + 600 weight）
	var power: int = int(_get_card_power_score(c))
	stat_right.text = str(power) if power > 0 else ""


## v9.x 修复：装饰中间层。BackpackCardItem(PanelContainer) 会强制布局直接子节点，
## 装饰节点挂到这里（Control 非 Container，不强制布局子节点），anchor/offset 正常生效。
func _ensure_decoration_layer() -> Control:
	var layer: Control = get_node_or_null("DecorationLayer") as Control
	if layer == null:
		layer = Control.new()
		layer.name = "DecorationLayer"
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# z_index 设为 5，让装饰层在 VBox(图标层 z=0) 之上、CardFrameOverlay(z=30) 之下
		layer.z_index = 5
		add_child(layer)
	return layer


## v9.0: 注入战斗卡装饰层——顶部稀有度色条 + 兵种色块 + 5 星点 + EQUIP 徽章
## 全部绝对定位在 PanelContainer 本体上（z_index 高于 art_clip），按需创建/复用
func _apply_v9_decorations(c: CardResource) -> void:
	if c == null:
		return
	# 1. 顶部稀有度色条（3-4px，传奇/神话加粗到 4px）
	_ensure_rarity_top_strip(c.rarity)

	# 3. 星点装饰已移除（等级信息由 stat-line 的 Lv.N 承担）；
	# 无条件隐藏防池化/热重载残留
	_hide_decoration("StarsOverlay")
	# 4. EQUIP 徽章（已装备到相位仪）
	_ensure_equipped_mark(c)
	# 5. 进化标记（inherit_bonus > 0 表示此卡为进化产物）
	_ensure_evolution_mark(c)







## v9.0: 顶部稀有度色条
## v9.x 修复：原用 PanelContainer（Container 子类），父 BackpackCardItem(PanelContainer)
## 会强制布局 Container 子节点，把色条拉伸到整个卡牌大小，bg_color 盖住卡图。
## 改用 Control + ColorRect（非 Container），anchor/offset 正常生效，不会被父级强制布局。
func _ensure_rarity_top_strip(rarity: String) -> void:
	var layer: Control = _ensure_decoration_layer()
	var strip: Control = layer.get_node_or_null("RarityTopStrip") as Control
	var bg: ColorRect = null
	if strip == null:
		strip = Control.new()
		strip.name = "RarityTopStrip"
		strip.anchor_left = 0.0
		strip.anchor_right = 1.0
		strip.anchor_top = 0.0
		strip.anchor_bottom = 0.0
		strip.offset_left = 0.0
		strip.offset_right = 0.0
		strip.offset_top = 0.0
		# offset_bottom 在下面按稀有度设
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(strip)
		bg = ColorRect.new()
		bg.name = "Bg"
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(bg)
		# v9.3：色条扫光（横向 透明→白→透明），对齐设计稿 .top-strip::after 光泽
		var sheen := TextureRect.new()
		sheen.name = "Sheen"
		sheen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sheen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sheen.stretch_mode = TextureRect.STRETCH_SCALE
		var sheen_grad := Gradient.new()
		sheen_grad.add_point(0.0, DesignTokens.COLOR_TRANSPARENT)
		sheen_grad.add_point(0.5, Color(1, 1, 1, 0.22))
		sheen_grad.add_point(1.0, DesignTokens.COLOR_TRANSPARENT)
		var sheen_tex := GradientTexture1D.new()
		sheen_tex.gradient = sheen_grad
		sheen.texture = sheen_tex
		strip.add_child(sheen)
	else:
		bg = strip.get_node_or_null("Bg") as ColorRect
	# 稀有度色 + 厚度（传奇/神话加粗）
	var rar_color: Color = _v9_rarity_color(rarity)
	var thickness: int = 4 if (rarity == "legendary" or rarity == "mythic") else 3
	strip.offset_bottom = float(thickness)
	if bg:
		bg.color = rar_color
	strip.visible = true


## v9.0: 稀有度 → 色值
## C1: 透传全项目唯一权威源 GC.get_rarity_color（禁止本地副本，fallback 枪铁灰非中灰）
func _v9_rarity_color(rarity: String) -> Color:
	return GC.get_rarity_color(rarity)





## v9.0: 星点装饰（StarsOverlay）已随卡面信息精简移除——
## 等级信息由 stat-line 的 "Lv.N" 文字承担，不再叠加 5 星图形。


## v9.0: 左上 EQUIP 绿色徽章（已装备到相位仪）
## v9.x 修复：PanelContainer → Control + ColorRect（避免父 PanelContainer 强制布局）
func _ensure_equipped_mark(c: CardResource) -> void:
	var is_equipped := _is_card_equipped_to_phase_instrument(c)
	var layer: Control = _ensure_decoration_layer()
	var badge: Control = layer.get_node_or_null("EquippedMark") as Control
	if not is_equipped:
		if badge:
			badge.visible = false
		return
	# v9.3：bg 改为 PanelContainer（绿边框 + 暗绿底 + 圆角），对齐设计稿 .equipped-mark 边框
	var bg: PanelContainer = null
	var text_lbl: Label = null
	if badge == null:
		badge = Control.new()
		badge.name = "EquippedMark"
		badge.anchor_left = 0.0
		badge.anchor_right = 0.0
		badge.anchor_top = 0.0
		badge.anchor_bottom = 0.0
		badge.offset_left = 4.0
		badge.offset_right = 42.0
		badge.offset_top = 26.0
		badge.offset_bottom = 38.0
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(badge)
		bg = PanelContainer.new()
		bg.name = "Bg"
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.13, 0.40, 0.23, 0.45)  # 暗绿底
		bg_style.border_color = Color(0.30, 0.92, 0.60, 0.55)  # 绿边框
		bg_style.set_border_width_all(1)
		bg_style.set_corner_radius_all(2)
		bg.add_theme_stylebox_override("panel", bg_style)
		badge.add_child(bg)
		text_lbl = Label.new()
		text_lbl.name = "Text"
		text_lbl.text = "EQUIP"
		text_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text_lbl.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_XSMALL)
		text_lbl.add_theme_color_override("font_color", Color(0.30, 0.92, 0.60, 1.0))
		text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(text_lbl)
	else:
		bg = badge.get_node_or_null("Bg") as PanelContainer
		text_lbl = badge.get_node_or_null("Text") as Label
	badge.visible = true


## v9.1: 右下角 instance-no 角标（HTML .instance-no，显示 #N 序号）
## 仅当 c.instance_id 非空时显示（裸模板无实例序号）
func _ensure_instance_no(c: CardResource) -> void:
	var seq: String = ""
	if c != null and not c.instance_id.is_empty():
		# instance_id 格式 card_id#N，取 #N 部分
		var hash_pos: int = c.instance_id.rfind("#")
		if hash_pos >= 0:
			seq = c.instance_id.substr(hash_pos)  # 含 #
	# v9.3：角标改为 PanelContainer（圆角暗底 chip）内含 Label，对齐设计稿 .instance-no
	var layer: Control = _ensure_decoration_layer()
	var chip: PanelContainer = layer.get_node_or_null("InstanceNo") as PanelContainer
	if seq.is_empty():
		if chip:
			chip.visible = false
		return
	var lbl: Label = null
	if chip == null:
		chip = PanelContainer.new()
		chip.name = "InstanceNo"
		chip.anchor_left = 1.0
		chip.anchor_right = 1.0
		chip.anchor_top = 1.0
		chip.anchor_bottom = 1.0
		chip.offset_left = -36.0
		chip.offset_right = -10.0
		# v9.3：chip 上移到立绘区底右角（footer 之上），避开 name-line/stat-line 文字行。
		# 原 offset_top=-38/offset_bottom=-24 落在 footer 内、与卡名同行，短名卡上 #N 贴到卡名框。
		# offset_right=-10：稀有度框/发光较宽，#N 距右边 10px 避免被卡框盖住（原 -4 太靠右）。
		chip.offset_top = -60.0
		chip.offset_bottom = -46.0
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var chip_style := StyleBoxFlat.new()
		# v9.3：bg 透明——角标所在卡面已有稀有度底色，再叠暗底成两层背景，故去掉。
		chip_style.bg_color = DesignTokens.COLOR_TRANSPARENT
		chip_style.content_margin_left = 3.0
		chip_style.content_margin_right = 3.0
		chip_style.content_margin_top = 1.0
		chip_style.content_margin_bottom = 1.0
		chip.add_theme_stylebox_override("panel", chip_style)
		layer.add_child(chip)
		lbl = Label.new()
		lbl.name = "Text"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(lbl)
	else:
		lbl = chip.get_node_or_null("Text") as Label
	chip.visible = true
	if lbl:
		lbl.text = seq
		lbl.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_XSMALL)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.70, 0.80, 0.95))


## v9.0: 检测卡是否已装备到相位仪（查 PhaseInstrumentManager.get_slot_card_ids）
func _is_card_equipped_to_phase_instrument(c: CardResource) -> bool:
	if c == null:
		return false
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim == null or not pim.has_method("get_slot_card_ids"):
		return false
	var equipped_ids: Array = pim.get_slot_card_ids()
	if equipped_ids.is_empty():
		return false
	# v9.0：精确匹配 instance_id（非空时）或裸 card_id（与 get_slot_card_ids 内部口径一致）
	var id_to_match: String = c.instance_id if not c.instance_id.is_empty() else c.card_id
	return equipped_ids.has(id_to_match)


## v21.x: 右下角进化标记（紫色"EV"徽章，表示此卡由进化产生）
## 通过 InstanceRegistry.get_inherit_bonus 判断是否为进化卡
## 位置与 InstanceNo 相邻，位于立绘区右下角
func _ensure_evolution_mark(c: CardResource) -> void:
	if c == null:
		_hide_decoration("EvolutionMark")
		return
	# 检查是否为进化卡（inherit_bonus > 0 表示有进化继承加成）
	var is_evolved: bool = false
	if not c.instance_id.is_empty():
		var ir: Node = get_node_or_null("/root/InstanceRegistry")
		if ir != null and ir.has_method("get_inherit_bonus"):
			is_evolved = ir.get_inherit_bonus(c.instance_id) > 0.0
	if not is_evolved:
		_hide_decoration("EvolutionMark")
		return
	# 创建/显示进化标记
	var layer: Control = _ensure_decoration_layer()
	var badge: Control = layer.get_node_or_null("EvolutionMark") as Control
	if badge == null:
		badge = Control.new()
		badge.name = "EvolutionMark"
		badge.anchor_left = 1.0
		badge.anchor_right = 1.0
		badge.anchor_top = 1.0
		badge.anchor_bottom = 1.0
		# 右下角定位：距右边10px，距底部46px（在InstanceNo上方）
		badge.offset_left = -34.0
		badge.offset_right = -10.0
		badge.offset_top = -60.0
		badge.offset_bottom = -46.0
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(badge)
		# 背景
		var bg: PanelContainer = PanelContainer.new()
		bg.name = "Bg"
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.55, 0.30, 0.85, 0.55)  # 暗紫底
		bg_style.border_color = Color(0.75, 0.55, 1.0, 0.85)  # 紫色边框
		bg_style.set_border_width_all(1)
		bg_style.set_corner_radius_all(3)
		bg.add_theme_stylebox_override("panel", bg_style)
		badge.add_child(bg)
		# 文字
		var text_lbl: Label = Label.new()
		text_lbl.name = "Text"
		text_lbl.text = "EV"
		text_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text_lbl.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_XSMALL)
		text_lbl.add_theme_color_override("font_color", Color(0.85, 0.70, 1.0, 1.0))  # 浅紫文字
		text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(text_lbl)
	badge.visible = true


## v9.0: 隐藏某个装饰层（按名字）。v9.x 装饰挂在 DecorationLayer 下。
func _hide_decoration(deco_name: String) -> void:
	var layer: Control = get_node_or_null("DecorationLayer") as Control
	var n: Node = null
	if layer:
		n = layer.get_node_or_null(deco_name)
	else:
		n = get_node_or_null(deco_name)  # 兼容旧路径
	if n is CanvasItem:
		(n as CanvasItem).visible = false


## v8.0: 构建底行信息——兵种|等级|改造|战力
func _build_bottom_info_line(c: CardResource) -> String:
	var parts: Array[String] = []
	# 兵种标识（仅战斗卡）
	if c.card_type == GC.CardType.COMBAT_UNIT:
		parts.append(CardResource.get_combat_kind_short(c.combat_kind))
	# 战斗卡等级（v20.12 等级统一：唯一等级轴 card_level；"强x/10"已随强化①退役）
	parts.append("Lv.%d" % maxi(_real_card_level(c), 1))
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
## v19: 战斗等级（card_level 1-30）查询——InstanceRegistry 按实例身份；未成长按 Lv1
func _card_level_of(c: CardResource) -> int:
	if c == null:
		return 1
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_card_level"):
		var identity: String = String(c.instance_id) if not String(c.instance_id).is_empty() else String(c.card_id)
		return clampi(maxi(int(ir.get_card_level(identity)), 1), 1, 30)
	return 1

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
	name_hdr.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
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
	cost_lbl.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
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
	# v20.12 等级统一：星级视觉从战斗卡等级换算（30级÷3 → 0-10 星，量纲保持 0-10）
	var st: int = int(round(float(maxi(_real_card_level(c), 0)) / 3.0))
	return clampi(st, 0, 10)


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
		# MTG 模式下等级显示在 InnerVBox 下方（v19 实例真实等级口径）
		var lvl_m: int = _real_card_level(c)
		if lvl_m > 0:
			lv_label.text = "Lv.%d" % lvl_m
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
		name_hdr.add_theme_font_size_override("font_size", clampi(int(ceil(SLOT_SIZE.y * 0.028)), 10, 18))
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
	# v19: 悬停提示补等级（card_level）——装配/比较决策的核心维度
	if c.card_type == GC.CardType.COMBAT_UNIT:
		tip_parts.append("等级 Lv.%d" % _card_level_of(c))
		# v20.13c: 每卡部署次数（实例卡含等级修正，与战场底栏 ×N 角标同源口径）
		var du_entry: Dictionary = UnifiedCardTable.get_entry(c.card_id)
		if not du_entry.is_empty():
			var du_uses: int = UnifiedCardTable.get_deploy_uses(du_entry, c)
			if du_uses < 99:
				tip_parts.append("部署×%d/场" % du_uses)
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



## v19 口径卡牌战斗等级：实例在 InstanceRegistry 的等级；查不到（模板/旧卡）回退 enhance_level，再回退 0
func _real_card_level(c: CardResource) -> int:
	if c == null:
		return 0
	var key: String = c.instance_id if not c.instance_id.is_empty() else c.card_id
	var ir := get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_card_level"):
		var lv: int = int(ir.get_card_level(key))
		if lv > 0:
			return lv
	return int(c.enhance_level)

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
	if not ResourceLoader.exists(tex_path):
		_icon_cache[tex_path] = null
		return null
	# 导入有效性校验：文件在但导入失败（valid=false）时，ResourceLoader.exists 仍 true，
	# 但 load() 会返回引擎橙色 missing-texture 占位。拦截避免渲染占位方块。
	if UiAssetLoader.is_import_marked_invalid(tex_path):
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


## v9.3: 立绘区底层氛围背景（暗蓝底 + 顶部蓝色淡渐变 + 中心高光）
## 对齐 HTML .art 的 radial/linear 渐变，让无图卡也有环境光氛围、有图卡背景更立体。
class _ArtBackdrop extends Control:
	func _init() -> void:
		clip_contents = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if r.size.x < 2.0 or r.size.y < 2.0:
			return
		# 暗蓝底
		draw_rect(r, Color(0.045, 0.075, 0.135, 0.96), true)
		# 顶部蓝色淡渐变（占上 70%，越往下越淡）
		var grad_h: float = r.size.y * 0.7
		var steps: int = 8
		for i in range(steps):
			var t: float = float(i) / float(steps)
			var y0: float = t * grad_h
			var y1: float = (float(i + 1) / float(steps)) * grad_h
			var a: float = 0.11 * (1.0 - t)
			draw_rect(Rect2(0.0, y0, r.size.x, y1 - y0 + 1.0), Color(0.30, 0.50, 0.90, a), true)
		# 中心偏上高光（radial 近似）
		draw_circle(Vector2(r.size.x * 0.5, r.size.y * 0.3), r.size.x * 0.42, Color(1.0, 1.0, 1.0, 0.035))
