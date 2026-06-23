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
const BattleUnitSizeRules = preload("res://scripts/battle_unit_size_rules.gd")


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
## combat_kind：单位战斗定位（CombatKind），用于按类型缩放卡图 + 空中单位悬浮。
##              -1 表示未知，按 1.0 倍率（不缩放、不悬浮）。
static func apply_battle_unit_presentation(
	host: Node2D,
	unit_spr: Sprite2D,
	card: CardResource,
	tex: Texture2D,
	face_right: bool,
	rank_level: int,
	combat_kind: int = -1
) -> bool:
	if host == null or unit_spr == null or tex == null:
		return false
	unit_spr.visible = true
	unit_spr.modulate = Color.WHITE
	var size_mul: float = BattleUnitSizeRules.get_size_multiplier(combat_kind)
	# 空中单位悬浮偏移（让空中单位高于地面单位一行，纯视觉，不改逻辑坐标）
	var hover_y: float = 0.0
	if BattleUnitSizeRules.is_hovering_kind(combat_kind):
		hover_y = BattleUnitSizeRules.get_air_hover_offset_px()
	# 先定 scale（apply_uniform_card_sprite 内部完成），再据"卡"的视觉高度算底部基线对齐
	apply_uniform_card_sprite(unit_spr, tex, face_right, size_mul)
	# 底部基线对齐：以卡的"外壳"（势力底图/稀有度框，5:8 比例）高度为基准。
	# 底图才是卡的真正形状（立绘只是框内图案），所有卡的底图底部对齐到同一基线（单位原点 = 车道 Y）。
	# 大卡 card_h 大、中心更高，小卡 card_h 小、中心更低，但底图底部齐平。
	# 立绘（正方形）跟随同一中心，在底图内居中（这是正常卡牌设计：立绘居中、底图包边）。
	var card_w: float = CardGridBattleLayout.battle_card_width_px() * maxf(size_mul, 0.0001)
	var card_h: float = card_w * 8.0 / 5.0
	var baseline_y: float = -card_h * 0.5
	# chrome 会读取 unit_spr.position 对齐底图/框，故先设好 position 再调 chrome
	unit_spr.position = Vector2(unit_spr.position.x, baseline_y + hover_y)
	if card != null:
		apply_battle_card_chrome(host, unit_spr, card, size_mul)
	# rank_strip（卡顶）与 name_strip（卡底）相对立绘中心定位，立绘 position.y 已含底部基线+悬浮
	sync_rank_strip(host, rank_level, unit_spr)
	sync_name_strip(host, unit_spr, card, face_right)
	return true


## v6.5: 在卡片立绘底部绘制单位名称条（我方青 / 敌方橙），补齐格子战可读性。
## 卡宽/卡高由 unit_spr 的纹理尺寸 × 缩放计算（已含按类型 size_mul 放大）；定位与 sync_rank_strip 对称（卡顶/卡底）。
## 立绘 position.y 已含底部基线偏移 + 空中悬浮，名称条贴卡底 = 立绘中心 + half_h。
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
	# 卡底定位：卡的底部（底图底）= 立绘中心(unit_spr.position.y) + card_h/2；名称条贴其下
	var half_h: float = card_h * 0.5
	strip.position = Vector2(unit_spr.position.x, unit_spr.position.y + half_h + 2.0)


static func apply_uniform_card_sprite(spr: Sprite2D, tex: Texture2D, face_right: bool = false, size_mul: float = 1.0) -> float:
	if spr == null:
		return 0.1
	if tex != null:
		spr.texture = tex
	var sc: float = CardGridThumbnailScale.compute_battlefield_uniform_width_scale(
		spr.texture if spr.texture != null else tex
	)
	sc *= maxf(size_mul, 0.0001)
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
## size_mul：按类型缩放卡图时，底图/稀有度框同步放大，避免大立绘配小底框错位。
static func apply_battle_card_chrome(host: Node2D, unit_spr: Sprite2D, card: CardResource, size_mul: float = 1.0) -> void:
	if host == null or unit_spr == null or card == null:
		return
	var card_w: float = CardGridBattleLayout.battle_card_width_px() * maxf(size_mul, 0.0001)
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
	var hp_h: float = 8.0
	var hb := host.get_node_or_null("HpBar")
	if hb != null and (hb as CanvasItem).visible:
		hp_h = 8.0
	# 卡底下方定位：卡的底部（底图底）= 立绘中心(spr.position.y) + card_h/2；buff 条再往下
	strip.position = Vector2(0.0, spr.position.y + half_h + hp_gap + hp_h + card_w * 0.03)