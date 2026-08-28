extends RefCounted
class_name CardFrameUi
## 稀有度 PNG 卡框叠层（`assets/cards/frames/<rarity>.png`，5:8 透明中心）

const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const CardBackgroundUi = preload("res://scripts/card_background_ui.gd")
const _CostBadgeScript = preload("res://scripts/cost_badge.gd")
const GC = preload("res://resources/game_constants.gd")

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


## v7.x 稀有度底色分层（铺满 + 低饱和）：作为稀有度的第三层编码。
## 底色铺满整个面板，alpha=0.95 留 5% 透出下层势力底图（CardBackgroundOverlay, z_index=-1）。
## 低饱和避免与势力底图/稀有度框 PNG 叠加后显脏。
## 此函数只管底色 + 细边框；glow/shadow 由调用方（_apply_card_border_flat 等）另行叠加。
static var _rarity_panel_style_cache: Dictionary = {}

static func _rarity_bg_color(rarity: String) -> Color:
	# 低饱和暗色底，按稀有度色相微偏（与 GC.get_rarity_color 同色相但大幅降饱和/降明度）
	match rarity:
		"common":    return Color(0.08, 0.10, 0.14, 0.95)
		"uncommon":  return Color(0.07, 0.12, 0.09, 0.95)
		"rare":      return Color(0.07, 0.10, 0.16, 0.95)
		"epic":      return Color(0.10, 0.08, 0.16, 0.95)
		"legendary": return Color(0.14, 0.10, 0.06, 0.95)
		"mythic":    return Color(0.15, 0.07, 0.11, 0.95)
		_:           return Color(0.08, 0.10, 0.14, 0.95)

## 返回按稀有度分层的底色 StyleBoxFlat（带缓存）。仅底色 + 1px 细灰边 + 圆角；
## 不含 glow/shadow，便于调用方在 hover 时叠加额外发光。
static func rarity_panel_style(rarity: String) -> StyleBoxFlat:
	if _rarity_panel_style_cache.has(rarity):
		return _rarity_panel_style_cache[rarity]
	var s := StyleBoxFlat.new()
	s.bg_color = _rarity_bg_color(rarity)
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.12, 0.16, 0.24, 0.55)
	s.set_corner_radius_all(6)
	_rarity_panel_style_cache[rarity] = s
	return s

## v7.x：50×80 小瓷砖专用稀有度样式（改造/符文标签用）。
## 与 rarity_panel_style（80×120 战斗卡）分开缓存，避免圆角/边框互扰。
## 含底色（复用同源 _rarity_bg_color）+ 稀有度色边框 + 稀有度发光（shadow）。
## glow_mode: 0=常态, 1=激活态（符文已装备时，shadow 翻倍 + 边框增亮）。
static var _tile_rarity_style_cache: Dictionary = {}

static func tile_rarity_style(rarity: String, glow_mode: int = 0) -> StyleBoxFlat:
	var cache_key: String = "%s_%d" % [rarity, glow_mode]
	if _tile_rarity_style_cache.has(cache_key):
		return _tile_rarity_style_cache[cache_key]
	var s := StyleBoxFlat.new()
	s.bg_color = _rarity_bg_color(rarity)
	s.set_corner_radius_all(4)
	var rarity_col: Color = GC.get_rarity_color(rarity)
	# 边框宽度随稀有度递增（common 1px 无光 → mythic 2px 强光）
	var bw: int = 1
	var shadow_alpha: float = 0.0
	var shadow_size: int = 0
	match rarity:
		"common":
			bw = 1; shadow_alpha = 0.0; shadow_size = 0
		"uncommon":
			bw = 1; shadow_alpha = 0.25; shadow_size = 2
		"rare":
			bw = 1; shadow_alpha = 0.30; shadow_size = 2
		"epic":
			bw = 2; shadow_alpha = 0.40; shadow_size = 3
		"legendary":
			bw = 2; shadow_alpha = 0.50; shadow_size = 4
		"mythic":
			bw = 2; shadow_alpha = 0.60; shadow_size = 5
	s.border_color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.85)
	s.set_border_width_all(bw)
	if glow_mode == 1:
		# 激活态：发光增强（符文已装备时视觉强化）
		shadow_alpha = clampf(shadow_alpha + 0.25, 0.4, 0.9)
		shadow_size += 2
		s.border_color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 1.0)
	if shadow_size > 0:
		s.shadow_color = Color(rarity_col.r, rarity_col.g, rarity_col.b, shadow_alpha)
		s.shadow_size = shadow_size
	_tile_rarity_style_cache[cache_key] = s
	return s


static func apply_panel_with_frame(host: PanelContainer, rarity: String) -> void:
	if host == null:
		return
	if has_frame(rarity):
		# v7.x：底色改用按稀有度分层的 rarity_panel_style（原 subtle_panel_style 统一暗色，稀有度仅靠框线）
		host.add_theme_stylebox_override("panel", rarity_panel_style(rarity))
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
	# v21.x 修复：池化复用竞态——_flush_rebuild_card_grid 在同一次 deferred 调用内
	# "set_card(null) 清角标（queue_free）→ 复用同一 item set_card(card)"，
	# get_node_or_null 会捞到垂死角标并复用，帧末随 queue_free 一起被释放，
	# 表现为背包网格重建后卡面的费用角标（N⚡）整批消失。
	# 处理：垂死节点立即从树上摘除（当帧不再绘制/查询不到），重建新角标接管原名。
	if badge != null and badge.is_queued_for_deletion():
		host.remove_child(badge)
		badge = null
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
