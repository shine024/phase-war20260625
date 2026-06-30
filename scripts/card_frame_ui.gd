extends RefCounted
class_name CardFrameUi
## 稀有度 PNG 卡框叠层（`assets/cards/frames/<rarity>.png`，5:8 透明中心）

const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const CardBackgroundUi = preload("res://scripts/card_background_ui.gd")

static func frame_path_for(rarity: String) -> String:
	return UiAssetLoader.card_frame_path_for(rarity)


static func has_frame(rarity: String) -> bool:
	var p: String = frame_path_for(rarity)
	return ResourceLoader.exists(p) and UiAssetLoader.load_tex(p) != null


static func load_frame(rarity: String) -> Texture2D:
	return UiAssetLoader.card_frame_for_rarity(rarity)


static func ensure_overlay(host: Control) -> TextureRect:
	var tr := host.get_node_or_null("CardFrameOverlay") as TextureRect
	if tr != null:
		return tr
	tr = TextureRect.new()
	tr.name = "CardFrameOverlay"
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tr.grow_vertical = Control.GROW_DIRECTION_BOTH
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.z_index = 30
	host.add_child(tr)
	host.move_child(tr, host.get_child_count() - 1)
	return tr


static func apply_to_host(host: Control, rarity: String) -> void:
	if host == null:
		return
	var tr := ensure_overlay(host)
	var tex := load_frame(rarity)
	tr.texture = tex
	tr.visible = tex != null


static func clear_overlay(host: Control) -> void:
	if host == null:
		return
	var tr := host.get_node_or_null("CardFrameOverlay") as TextureRect
	if tr:
		tr.texture = null
		tr.visible = false


static var _subtle_panel_style: StyleBoxFlat = null


## PNG 卡框存在时：深色底 + 细灰边（稀有度由框图表达）
static func subtle_panel_style() -> StyleBoxFlat:
	if _subtle_panel_style != null:
		return _subtle_panel_style
	_subtle_panel_style = StyleBoxFlat.new()
	_subtle_panel_style.bg_color = Color(0.05, 0.08, 0.14, 0.92)
	_subtle_panel_style.border_width_left = 1
	_subtle_panel_style.border_width_top = 1
	_subtle_panel_style.border_width_right = 1
	_subtle_panel_style.border_width_bottom = 1
	_subtle_panel_style.border_color = Color(0.12, 0.16, 0.24, 0.55)
	_subtle_panel_style.corner_radius_top_left = 5
	_subtle_panel_style.corner_radius_top_right = 5
	_subtle_panel_style.corner_radius_bottom_right = 5
	_subtle_panel_style.corner_radius_bottom_left = 5
	return _subtle_panel_style


static func apply_panel_with_frame(host: PanelContainer, rarity: String) -> void:
	if host == null:
		return
	if has_frame(rarity):
		host.add_theme_stylebox_override("panel", subtle_panel_style())
		apply_to_host(host, rarity)
	else:
		clear_overlay(host)


static func clear_panel_frame(host: PanelContainer) -> void:
	if host == null:
		return
	clear_overlay(host)


## 背包格 / 相位仪槽：势力底 + 稀有度框 + 深色面板底
static func apply_slot_chrome(host: PanelContainer, card: CardResource) -> void:
	if host == null:
		return
	if card == null:
		clear_panel_frame(host)
		CardBackgroundUi.clear_overlay(host)
		return
	CardBackgroundUi.apply_to_host(host, CardBackgroundUi.resolve_faction_id_for_card(card))
	apply_panel_with_frame(host, card.rarity)


# ── v7.x 费用角标（左上角黄底小气泡，显示 N⚡）──
# 与 RankCornerBadge（右上角段位）分占左右上角，互不遮挡。
# 用法：ensure_cost_corner_badge(panel).text = "%d⚡" % cost；空槽位 clear_cost_corner_badge(panel)。

static var _cost_badge_style: StyleBoxFlat = null

static func _cost_badge_stylebox() -> StyleBoxFlat:
	if _cost_badge_style == null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.82, 0.20, 0.95)  # 能量金黄
		sb.border_color = Color(0.20, 0.15, 0.05, 0.9)
		sb.set_border_width_all(1)
		# 圆形：corner_radius 设为半边（正方形角标 → 真圆）
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 0.0
		sb.content_margin_right = 0.0
		sb.content_margin_top = 0.0
		sb.content_margin_bottom = 0.0
		_cost_badge_style = sb
	return _cost_badge_style

## 在 host 左上角创建/复用费用角标（返回 Label，调用方设置 .text）。
## 若已存在则复用，避免反复 free/new 抖动。
## v7.x：圆形角标（20×20 正方形 + corner_radius=10 → 真圆）。
static func ensure_cost_corner_badge(host: Control) -> Label:
	if host == null:
		return null
	var lbl: Label = host.get_node_or_null("CostCornerBadge") as Label
	if lbl == null:
		lbl = Label.new()
		lbl.name = "CostCornerBadge"
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.clip_text = false
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", Color(0.10, 0.07, 0.02, 1.0))
		lbl.add_theme_stylebox_override("normal", _cost_badge_stylebox())
		# 正方形 20×20（左上角，圆形）
		lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		lbl.offset_left = 2.0
		lbl.offset_top = 2.0
		lbl.offset_right = 22.0
		lbl.offset_bottom = 22.0
		lbl.z_index = 35
		host.add_child(lbl)
	return lbl

## 清除费用角标（空槽位时调用）。
static func clear_cost_corner_badge(host: Control) -> void:
	if host == null:
		return
	var old: Node = host.get_node_or_null("CostCornerBadge")
	if old != null:
		old.queue_free()
