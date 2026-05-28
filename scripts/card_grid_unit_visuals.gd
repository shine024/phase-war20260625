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
	c.display_name = String(cfg.get("display_name", archetype_id))
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
	apply_uniform_card_sprite(unit_spr, tex, face_right)
	if card != null:
		apply_battle_card_chrome(host, unit_spr, card)
	sync_rank_strip(host, rank_level, unit_spr)
	return true


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
	var card_art_w: float = float(spr.texture.get_width()) * absf(spr.scale.x)
	strip.rebuild(rank_level, card_art_w)
	var half_h: float = float(spr.texture.get_height()) * absf(spr.scale.y) * 0.5
	strip.position = Vector2(0.0, -half_h - strip.get_total_height() - card_art_w * 0.02)
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
	var card_art_w: float = float(spr.texture.get_width()) * absf(spr.scale.x)
	strip.rebuild(kinds, card_art_w)
	var half_h: float = float(spr.texture.get_height()) * absf(spr.scale.y) * 0.5
	var hp_gap: float = 8.0
	var hp_h: float = 8.0
	var hb := host.get_node_or_null("HpBar")
	if hb != null and (hb as CanvasItem).visible:
		hp_h = 8.0
	strip.position = Vector2(0.0, half_h + hp_gap + hp_h + card_art_w * 0.03)