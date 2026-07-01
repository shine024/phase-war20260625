extends RefCounted
class_name CardFrameUi
## 稀有度 PNG 卡框叠层（`assets/cards/frames/<rarity>.png`，5:8 透明中心）

const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const CardBackgroundUi = preload("res://scripts/card_background_ui.gd")
const _CostBadgeScript = preload("res://scripts/cost_badge.gd")

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
# 用法：ensure_cost_corner_badge(panel).energy_value = cost；空槽位 clear_cost_corner_badge(panel)。

## 在 host 左上角创建/复用费用角标（返回 Control，调用方设置 energy_value）。
## 若已存在则复用，避免反复 free/new 抖动。
## v7.x：CostBadge 用 _draw 画文字 + set_as_top_level 脱离父节点坐标系，
## 彻底绕过 PanelContainer 对子节点的布局强制管理。
## anchor_right=true 时费用在 host 右上角（否则左上角）。
## 返回 Control（cost_badge.gd 实例），调用方设 .energy_value。
static func ensure_cost_corner_badge(host: Control, anchor_right: bool = false) -> Control:
	if host == null:
		return null
	var badge: Control = host.get_node_or_null("CostCornerBadge") as Control
	if badge == null:
		badge = _CostBadgeScript.new()
		badge.name = "CostCornerBadge"
		host.add_child(badge)
	if badge.has_method("follow_host"):
		badge.follow_host(host, anchor_right)
	return badge

## 清除费用角标（空槽位时调用）。
static func clear_cost_corner_badge(host: Control) -> void:
	if host == null:
		return
	var old: Node = host.get_node_or_null("CostCornerBadge")
	if old != null:
		old.queue_free()
