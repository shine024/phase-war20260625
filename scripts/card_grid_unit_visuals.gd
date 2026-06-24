extends RefCounted
class_name CardGridUnitVisuals

const CardGridThumbnailScale = preload("res://scripts/card_grid_thumbnail_scale.gd")
const CardGridRankStrip = preload("res://scripts/card_grid_rank_strip.gd")
const CardGridBuffStrip = preload("res://scripts/card_grid_buff_strip.gd")
const CardGridBattleLayout = preload("res://scripts/card_grid_battle_layout.gd")
const RankRules = preload("res://data/rank_rules.gd")
const CardFrameUi = preload("res://scripts/card_frame_ui.gd")
const CardBackgroundUi = preload("res://scripts/card_background_ui.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const CapturedUnitCards = preload("res://data/captured_unit_cards.gd")
const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const GC = preload("res://resources/game_constants.gd")


## `face_right`：原画朝左；我方 true（负 scale.x 镜像朝右），敌方 false（保持朝左）。
## 敌我格子战共用：从 archetype / 缴获清单 / drops 解析 CardResource（框与底图用）
static func resolve_card_for_archetype(archetype_id: String) -> CardResource:
	var aid: String = archetype_id.strip_edges()
	if aid.is_empty():
		return null
	CapturedUnitCards.register_into_default_cards_cache()
	var manifest_drop: String = EnemyUnitManifest.get_drop_card_id(aid)
	if not manifest_drop.is_empty():
		var from_manifest: CardResource = DefaultCards.get_card_by_id(manifest_drop)
		if from_manifest != null:
			return from_manifest
	var cfg: Dictionary = EnemyArchetypes.get_config(aid)
	for d in cfg.get("drops", []):
		if d is not Dictionary:
			continue
		var cid: String = String((d as Dictionary).get("card_id", ""))
		if cid.is_empty():
			continue
		var from_drop: CardResource = DefaultCards.get_card_by_id(cid)
		if from_drop != null:
			return from_drop
	return null


static func synthetic_card_for_archetype(archetype_id: String, cfg: Dictionary) -> CardResource:
	var c := CardResource.new()
	c.card_id = archetype_id
	c.display_name = String(cfg.get("display_name", DefaultCards.get_safe_display_name(archetype_id)))
	c.rarity = "common"
	c.card_type = GC.CardType.COMBAT_UNIT
	return c


static func resolve_battle_icon_texture(
	card: CardResource,
	archetype_id: String,
	cfg: Dictionary = {}
) -> Texture2D:
	if card != null:
		var from_card: Texture2D = UiAssetLoader.load_tex(UiAssetLoader.card_icon_path_for(card))
		if from_card != null:
			return from_card
	var merged: Dictionary = cfg if not cfg.is_empty() else EnemyArchetypes.get_config(archetype_id)
	var path: String = EnemyArchetypes.resolve_card_icon_texture_path(archetype_id, merged, archetype_id)
	return UiAssetLoader.load_tex(path)


## 立绘 + 势力底 + 稀有度框 + 军衔条（与背包简略卡面一致）
static func apply_battle_unit_presentation(
	host: Node2D,
	unit_spr: Sprite2D,
	card: CardResource,
	tex: Texture2D,
	face_right: bool,
	rank_level: int
) -> bool:
	if host == null or unit_spr == null or tex == null:
		return false
	unit_spr.visible = true
	unit_spr.modulate = Color.WHITE
	# 统一卡图大小：所有单位同一缩放（按纹理宽度归一到固定卡宽），不按类型缩放。
	apply_uniform_card_sprite(unit_spr, tex, face_right)
	# 立绘居中（position 默认原点），不悬浮、不按脚线对齐。
	unit_spr.position = Vector2(unit_spr.position.x, 0.0)
	if card != null:
		apply_battle_card_chrome(host, unit_spr, card)
	sync_rank_strip(host, rank_level, unit_spr)
	sync_name_strip(host, unit_spr, card, face_right)
	return true


## v6.5: 在卡片立绘底部绘制单位名称条（我方青 / 敌方橙），补齐格子战可读性。
static func sync_name_strip(host: Node2D, unit_spr: Sprite2D, card: CardResource, is_player: bool) -> void:
	if host == null or unit_spr == null or unit_spr.texture == null:
		return
	var strip = host.get_node_or_null("CardGridNameStrip")
	if strip == null:
		var NameStripClass = preload("res://scripts/card_grid_name_strip.gd")
		strip = NameStripClass.new()
		strip.name = "CardGridNameStrip"
		host.add_child(strip)
	strip.z_index = 13
	var display_name: String = ""
	if card != null:
		display_name = card.display_name
	# 卡的尺寸取"外壳"（势力底图 CardBattleBg，5:8）而非立绘纹理，保证与底图对齐
	var card_w: float = CardGridBattleLayout.battle_card_width_px()
	var card_h: float = card_w * 8.0 / 5.0
	var bg_spr := host.get_node_or_null("CardBattleBg") as Sprite2D
	if bg_spr != null and bg_spr.texture != null:
		card_w = float(bg_spr.texture.get_width()) * absf(bg_spr.scale.x)
		card_h = float(bg_spr.texture.get_height()) * absf(bg_spr.scale.y)
	strip.rebuild(display_name, is_player, card_w, card_h)
	# 卡底定位：立绘居中（position.y=0），底图跟随立绘，名称条贴卡底 = 立绘中心 + half_h
	var half_h: float = card_h * 0.5
	strip.position = Vector2(unit_spr.position.x, unit_spr.position.y + half_h + 2.0)


static func apply_uniform_card_sprite(spr: Sprite2D, tex: Texture2D, face_right: bool = false) -> float:
	if spr == null:
		return 0.1
	if tex != null:
		spr.texture = tex
	var sc: float = CardGridThumbnailScale.compute_battlefield_uniform_width_scale(
		spr.texture if spr.texture != null else tex
	)
	spr.offset = Vector2.ZERO
	var sx: float = -sc if face_right else sc
	spr.scale = Vector2(sx, sc)
	return abs(sc)


static func _ensure_battle_chrome_sprite(host: Node2D, node_name: String, z: int) -> Sprite2D:
	var spr := host.get_node_or_null(node_name) as Sprite2D
	if spr != null:
		return spr
	spr = Sprite2D.new()
	spr.name = node_name
	spr.z_index = z
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	host.add_child(spr)
	return spr


## 格子战立绘：5:8 势力底 + 单位图 + 稀有度框（与 UI 槽一致）
static func apply_battle_card_chrome(host: Node2D, unit_spr: Sprite2D, card: CardResource) -> void:
	if host == null or unit_spr == null or card == null:
		return
	var card_w: float = CardGridBattleLayout.battle_card_width_px()
	var card_h: float = card_w * 8.0 / 5.0
	var bg_tex: Texture2D = CardBackgroundUi.load_background(
		CardBackgroundUi.resolve_faction_id_for_card(card)
	)
	var frame_tex: Texture2D = CardFrameUi.load_frame(card.rarity)
	var bg_spr := _ensure_battle_chrome_sprite(host, "CardBattleBg", 4)
	var frame_spr := _ensure_battle_chrome_sprite(host, "CardBattleFrame", 14)
	for chrome in [bg_spr, frame_spr]:
		chrome.centered = true
		chrome.position = unit_spr.position
	if bg_tex != null:
		bg_spr.texture = bg_tex
		var bw: float = maxf(float(bg_tex.get_width()), 1.0)
		var bh: float = maxf(float(bg_tex.get_height()), 1.0)
		bg_spr.scale = Vector2(card_w / bw, card_h / bh)
		bg_spr.visible = true
	else:
		bg_spr.visible = false
	if frame_tex != null:
		frame_spr.texture = frame_tex
		var fw: float = maxf(float(frame_tex.get_width()), 1.0)
		var fh: float = maxf(float(frame_tex.get_height()), 1.0)
		frame_spr.scale = Vector2(card_w / fw, card_h / fh)
		frame_spr.visible = true
	else:
		frame_spr.visible = false
	unit_spr.z_index = 10


static func sync_rank_strip(host: Node2D, rank_level: int, spr: Sprite2D) -> void:
	if host == null or spr == null or spr.texture == null:
		return
	var strip: CardGridRankStrip = host.get_node_or_null("CardGridRankStrip") as CardGridRankStrip
	if strip == null:
		strip = CardGridRankStrip.new()
		strip.name = "CardGridRankStrip"
		host.add_child(strip)
	strip.z_index = 12
	# 卡的尺寸取"外壳"（势力底图 CardBattleBg，5:8）而非立绘纹理，保证与底图对齐
	var card_w: float = CardGridBattleLayout.battle_card_width_px()
	var card_h: float = card_w * 8.0 / 5.0
	var bg_spr := host.get_node_or_null("CardBattleBg") as Sprite2D
	if bg_spr != null and bg_spr.texture != null:
		card_w = float(bg_spr.texture.get_width()) * absf(bg_spr.scale.x)
		card_h = float(bg_spr.texture.get_height()) * absf(bg_spr.scale.y)
	strip.rebuild(rank_level, card_w)
	var half_h: float = card_h * 0.5
	# 卡顶定位：卡的顶部（底图顶）= 立绘中心(spr.position.y) - card_h/2；军衔条再往上
	strip.position = Vector2(0.0, spr.position.y - half_h - strip.get_total_height() - card_w * 0.02)
	strip.visible = rank_level > 0


static func rank_level_from_id(rank_id: String) -> int:
	return RankRules.rank_id_to_level(rank_id)


## 卡底加成条：雷达/侦查/堡垒/指挥等受光环单位下方彩色矢量图标
static func sync_buff_strip(host: Node2D, unit: Node, spr: Sprite2D) -> void:
	if host == null or unit == null or spr == null or spr.texture == null:
		return
	var kinds: Array[CardGridBuffStrip.BuffKind] = CardGridBuffStrip.collect_buff_kinds(unit)
	var strip: CardGridBuffStrip = host.get_node_or_null("CardGridBuffStrip") as CardGridBuffStrip
	if kinds.is_empty():
		if strip != null:
			strip.rebuild([])
			strip.visible = false
		return
	if strip == null:
		strip = CardGridBuffStrip.new()
		strip.name = "CardGridBuffStrip"
		host.add_child(strip)
	strip.z_index = 13
	# 卡的尺寸取"外壳"（势力底图 CardBattleBg，5:8）而非立绘纹理，保证与底图对齐
	var card_w: float = CardGridBattleLayout.battle_card_width_px()
	var card_h: float = card_w * 8.0 / 5.0
	var bg_spr := host.get_node_or_null("CardBattleBg") as Sprite2D
	if bg_spr != null and bg_spr.texture != null:
		card_w = float(bg_spr.texture.get_width()) * absf(bg_spr.scale.x)
		card_h = float(bg_spr.texture.get_height()) * absf(bg_spr.scale.y)
	strip.rebuild(kinds, card_w)
	var half_h: float = card_h * 0.5
	var hp_gap: float = 8.0
	# 血条高度读真实折叠态（修复 H1：原硬编码 8.0 与未选中单位 4px 折叠态脱钩，导致 buff 条错位）
	# 敌方血条不可见时 hp_h=0（敌方不显示头顶血条）
	var hp_h: float = 0.0
	var hb := host.get_node_or_null("HpBar")
	if hb != null and (hb as CanvasItem).visible:
		if hb.has_method("get_bar_height"):
			hp_h = float(hb.get_bar_height())
		else:
			hp_h = 8.0  # 回退默认展开高度
	# 卡底下方定位：卡的底部（底图底）= 底图基线(CardBattleBg.position.y) + card_h/2；buff 条再往下
	# 注意：立绘 spr.position.y 已改为"脚对齐"，不等于底图基线；buff 条跟随底图（卡的外壳）。
	var base_y: float = bg_spr.position.y if (bg_spr != null and bg_spr.texture != null) else spr.position.y
	strip.position = Vector2(0.0, base_y + half_h + hp_gap + hp_h + card_w * 0.03)