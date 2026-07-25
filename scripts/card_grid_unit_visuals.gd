extends RefCounted
class_name CardGridUnitVisuals

const CardGridThumbnailScale = preload("res://scripts/card_grid_thumbnail_scale.gd")
const CardGridRankStrip = preload("res://scripts/card_grid_rank_strip.gd")
const CardGridBuffStrip = preload("res://scripts/card_grid_buff_strip.gd")
const CardGridModStrip = preload("res://scripts/card_grid_mod_strip.gd")
const CardGridBattleLayout = preload("res://scripts/card_grid_battle_layout.gd")
const CardGridFloatingLabel = preload("res://scripts/card_grid_floating_label.gd")
const RankRules = preload("res://data/rank_rules.gd")
const CardFrameUi = preload("res://scripts/card_frame_ui.gd")
const CardBackgroundUi = preload("res://scripts/card_background_ui.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const CapturedUnitCards = preload("res://data/captured_unit_cards.gd")
const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const GC = preload("res://resources/game_constants.gd")


## `face_right`：v7.x 起图本身已携带朝向（vis_player=我方翻转图，vis_enemy=敌方原图），
## 不再靠 scale.x 翻转。此参数仅保留给 sync_name_strip 区分敌我颜色（我方青/敌方橙）。
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


## 战场单位取图。`for_player=true`（我方）取 vis_player 翻转图；`for_player=false`（敌方）取 vis_enemy 原图。
## 我方走 card_icon_path_for（UI 路径，默认 vis_player）；敌方跳过该路径直接走 resolve_card_icon_texture_path（vis_enemy）。
static func resolve_battle_icon_texture(
	card: CardResource,
	archetype_id: String,
	cfg: Dictionary = {},
	for_player: bool = true
) -> Texture2D:
	if for_player and card != null:
		var from_card: Texture2D = UiAssetLoader.load_tex(UiAssetLoader.card_icon_path_for(card))
		if from_card != null:
			return from_card
	var merged: Dictionary = cfg if not cfg.is_empty() else EnemyArchetypes.get_config(archetype_id)
	var path: String = EnemyArchetypes.resolve_card_icon_texture_path(archetype_id, merged, archetype_id)
	return UiAssetLoader.load_tex(path)


## 立绘 + 势力底 + 稀有度框 + 军衔条（与背包简略卡面一致）
## unit 可选参数：传入单位节点以启用精英金角标（敌方 elite/boss 显示）
static func apply_battle_unit_presentation(
	host: Node2D,
	unit_spr: Sprite2D,
	card: CardResource,
	tex: Texture2D,
	face_right: bool,
	rank_level: int,
	unit: Node = null
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
	# v7.x 战场视觉反馈：单位头顶增强——稀有度角标 + 等级标签
	if card != null:
		sync_rarity_badge(host, unit_spr, card)
	sync_level_tag(host, unit_spr, card, unit)
	# v7.x 战场视觉反馈：敌方精英金角标（elite/boss 单位，左上角，避开右上的稀有度角标）
	sync_elite_badge(host, unit_spr, unit)
	# v7.x HP 数值标签（卡框下方，我方青/敌方红）
	sync_hp_label(host, unit_spr, unit)
	# v7.x 战场视觉反馈：漂浮 buff/debuff 标签（卡顶上方，破甲/标记/暴击标注/反炮）
	sync_buff_labels(host, unit_spr, unit)
	return true


## 敌方精英金角标：当 unit 是 elite/boss 时，卡框左上角显示金色星形角标
## 与右上角的稀有度三角错开，一眼识别威胁等级
static func sync_elite_badge(host: Node2D, unit_spr: Sprite2D, unit: Node) -> void:
	if host == null or unit_spr == null or unit == null:
		# 无 unit 引用则清掉残留角标（防御性）
		var stale := host.get_node_or_null("EliteBadge") as Polygon2D
		if stale != null:
			stale.visible = false
		return
	# 仅当单位暴露 get_elite_spawn_type() 且值为 elite/boss 才显示
	var spawn_type: String = ""
	if unit.has_method("get_elite_spawn_type"):
		spawn_type = String(unit.get_elite_spawn_type())
	var is_elite := (spawn_type == "elite" or spawn_type == "boss")
	var badge := host.get_node_or_null("EliteBadge") as Polygon2D
	if not is_elite:
		if badge != null:
			badge.visible = false
		return
	if badge == null:
		badge = Polygon2D.new()
		badge.name = "EliteBadge"
		badge.z_index = 16
		host.add_child(badge)
	# boss 用更大尺寸 + 更亮的金；elite 标准
	var s: float = 7.5 if spawn_type == "boss" else 6.0
	# 五角星形（向上）
	badge.polygon = PackedVector2Array([
		Vector2(0.0, -s),
		Vector2(s * 0.224, -s * 0.309),
		Vector2(s, -s * 0.309),
		Vector2(s * 0.363, s * 0.118),
		Vector2(s * 0.588, s),
		Vector2(0.0, s * 0.382),
		Vector2(-s * 0.588, s),
		Vector2(-s * 0.363, s * 0.118),
		Vector2(-s, -s * 0.309),
		Vector2(-s * 0.224, -s * 0.309),
	])
	# 金色（boss 更亮）
	badge.color = Color(1.0, 0.78, 0.20, 1.0) if spawn_type == "boss" else Color(0.98, 0.75, 0.15, 1.0)
	# 定位：卡框左上角（与右上角的 RarityBadge 对称）
	var card_h: float = CardGridBattleLayout.battle_card_width_px() * 8.0 / 5.0
	badge.position = Vector2(-CardGridBattleLayout.battle_card_width_px() * 0.42, unit_spr.position.y - card_h * 0.5 - s)
	badge.visible = true


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
	strip.z_index = 15
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
	# 名称条改为"卡框内部下部"：紧贴卡底边内侧（立绘中心 + half_h - 条高），不再悬于卡外。
	# 条高与 CardGridNameStrip.rebuild() 内部公式一致（max(card_w × 0.30, 14)），用于反向定位。
	var half_h: float = card_h * 0.5
	var bar_h: float = maxf(card_w * 0.30, 14.0)
	strip.position = Vector2(unit_spr.position.x, unit_spr.position.y + half_h - bar_h)


static func apply_uniform_card_sprite(spr: Sprite2D, tex: Texture2D, face_right: bool = false) -> float:
	if spr == null:
		return 0.1
	if tex != null:
		spr.texture = tex
	var sc: float = CardGridThumbnailScale.compute_battlefield_uniform_width_scale(
		spr.texture if spr.texture != null else tex
	)
	spr.offset = Vector2.ZERO
	# v7.x: 图本身已携带朝向（vis_player=翻转/我方，vis_enemy=原图/敌方），不再 scale 翻转。
	# face_right 参数保留仅用于 sync_name_strip 的敌我颜色区分，不影响贴图朝向。
	spr.scale = Vector2(sc, sc)
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


# ============================================================================
#  v7.x 战场视觉反馈：单位头顶增强（稀有度角标 + 等级标签 + 改造图标条）
# ============================================================================

## 稀有度小角标：卡框右上角的 12px 三角形，颜色按稀有度（敌方也显示，肉眼识别精英）
static func sync_rarity_badge(host: Node2D, unit_spr: Sprite2D, card: CardResource) -> void:
	if host == null or card == null:
		return
	var badge := host.get_node_or_null("RarityBadge") as Polygon2D
	# common 不显示（避免视觉噪音）
	var is_common := (card.rarity == "common" or card.rarity.is_empty())
	if is_common:
		if badge != null:
			badge.visible = false
		return
	if badge == null:
		badge = Polygon2D.new()
		badge.name = "RarityBadge"
		badge.z_index = 16
		host.add_child(badge)
	# 三角形（向下的稀有度标记）
	var s: float = 6.0
	badge.polygon = PackedVector2Array([
		Vector2(-s, -s),
		Vector2(s, -s),
		Vector2(0.0, s * 0.6),
	])
	badge.color = GC.get_rarity_color(card.rarity)
	# 定位：卡框右上角（立绘上方）
	var card_h: float = CardGridBattleLayout.battle_card_width_px() * 8.0 / 5.0
	badge.position = Vector2(CardGridBattleLayout.battle_card_width_px() * 0.42, unit_spr.position.y - card_h * 0.5 - s)
	badge.visible = true


## 等级小标签：卡框左上角 "Lv.X"（我方读 enhance_level，敌方无则隐藏）
## 用 Node2D + _draw() 自绘（参考 CardGridRankStrip），避免 Label 在 Node2D 下
## 因 Control 布局系统不触发导致的 size=0 / 文字不渲染问题。
static func sync_level_tag(host: Node2D, unit_spr: Sprite2D, card: CardResource, unit: Node = null) -> void:
	if host == null:
		return
	var level: int = 0
	# v7.x: 优先读 unit.stats.enhance_level（我方 construct_unit 有，敌方无则 level=0 不显示）
	if unit != null and "stats" in unit and unit.stats != null and "enhance_level" in unit.stats:
		level = int(unit.stats.enhance_level)
	elif host.has_meta("enhance_level"):
		level = int(host.get_meta("enhance_level"))
	elif card != null and "enhance_level" in card:
		level = int(card.enhance_level)
	var label := host.get_node_or_null("LevelTag") as CardGridFloatingLabel
	if level <= 0:
		if label != null:
			label.visible = false
		return
	if label == null:
		label = CardGridFloatingLabel.new()
		label.name = "LevelTag"
		host.add_child(label)
	label.set_text("Lv.%d" % level)
	label.set_style(11, Color(1.0, 0.85, 0.35, 1.0), Color(0, 0, 0, 0.85), 3, HORIZONTAL_ALIGNMENT_CENTER)
	# 定位：卡框左上角（Node2D position 即原点，文字以原点为中心居中绘制）
	var card_w: float = CardGridBattleLayout.battle_card_width_px()
	var card_h: float = card_w * 8.0 / 5.0
	label.position = Vector2(-card_w * 0.5 - 18.0, unit_spr.position.y - card_h * 0.5 - 8.0)
	label.visible = true


## v7.x HP 数值标签：卡框下方显示当前/最大 HP（我方青/敌方红）
## 我方读 unit.hp / unit.stats.max_hp；敌方读 unit.hp / unit.max_hp
## 用 Node2D + _draw() 自绘（参考 CardGridRankStrip），避免 Label 在 Node2D 下
## 因 Control 布局系统不触发导致的 size=0 / 文字不渲染问题。
static func sync_hp_label(host: Node2D, unit_spr: Sprite2D, unit: Node) -> void:
	if host == null or unit == null:
		return
	var cur_hp: float = 0.0
	var max_hp_val: float = 0.0
	var is_player: bool = false
	if "hp" in unit:
		cur_hp = float(unit.hp)
	if "is_player" in unit:
		is_player = bool(unit.is_player)
	if is_player and "stats" in unit and unit.stats != null and "max_hp" in unit.stats:
		max_hp_val = float(unit.stats.max_hp)
	elif "max_hp" in unit:
		max_hp_val = float(unit.max_hp)
	if max_hp_val <= 0.0:
		return
	var label := host.get_node_or_null("HpValueLabel") as CardGridFloatingLabel
	if label == null:
		label = CardGridFloatingLabel.new()
		label.name = "HpValueLabel"
		host.add_child(label)
	# 配色：我方青、敌方红
	var font_color: Color = Color(0.65, 0.95, 1.0, 1.0) if is_player else Color(1.0, 0.6, 0.6, 1.0)
	label.set_text("%d/%d" % [int(cur_hp), int(max_hp_val)])
	label.set_style(11, font_color, Color(0, 0, 0, 0.85), 3, HORIZONTAL_ALIGNMENT_CENTER)
	# 定位：卡框底部下方（Node2D position 即原点，文字以原点为中心居中绘制）
	var card_w: float = CardGridBattleLayout.battle_card_width_px()
	var card_h: float = card_w * 8.0 / 5.0
	label.position = Vector2(0.0, unit_spr.position.y + card_h * 0.5 + 8.0)
	label.visible = true


## v7.x: 更新 HP 数值标签的文字（供单位 _refresh_hp_value_label 高频调用，避免每次重建样式）
## 这是 _refresh_hp_value_label 的轻量入口：只更新文字，不重设样式/位置
static func update_hp_label_text(host: Node2D, cur_hp: float, max_hp: float) -> void:
	if host == null:
		return
	var label := host.get_node_or_null("HpValueLabel") as CardGridFloatingLabel
	if label == null:
		return
	label.set_text("%d/%d" % [int(cur_hp), int(max_hp)])


## 改造图标条：装备改造的单位卡底显示图标（与 buff_strip 错位，放在更下方）
static func sync_mod_strip(host: Node2D, unit: Node, spr: Sprite2D) -> void:
	if host == null or unit == null or spr == null or spr.texture == null:
		return
	var kinds: Array[CardGridModStrip.ModKind] = CardGridModStrip.collect_mod_kinds(unit)
	var strip: CardGridModStrip = host.get_node_or_null("CardGridModStrip") as CardGridModStrip
	if kinds.is_empty():
		if strip != null:
			strip.rebuild([])
			strip.visible = false
		return
	if strip == null:
		strip = CardGridModStrip.new()
		strip.name = "CardGridModStrip"
		host.add_child(strip)
	strip.z_index = 13
	var card_w: float = CardGridBattleLayout.battle_card_width_px()
	var card_h: float = card_w * 8.0 / 5.0
	var bg_spr := host.get_node_or_null("CardBattleBg") as Sprite2D
	if bg_spr != null and bg_spr.texture != null:
		card_w = float(bg_spr.texture.get_width()) * absf(bg_spr.scale.x)
		card_h = float(bg_spr.texture.get_height()) * absf(bg_spr.scale.y)
	strip.rebuild(kinds, card_w)
	var half_h: float = card_h * 0.5
	# 定位：buff_strip 下方（buff_strip 高约 card_w*0.22，留 2px 间距）
	var buff_strip_h: float = card_w * 0.22 + 2.0
	var base_y: float = bg_spr.position.y if (bg_spr != null and bg_spr.texture != null) else spr.position.y
	strip.position = Vector2(0.0, base_y + half_h + 8.0 + 8.0 + buff_strip_h)


# ============================================================================
#  v7.x 战场视觉反馈：漂浮 buff/debuff 标签（卡顶上方）
# ============================================================================

## 漂浮 buff/debuff 标签：单位卡顶上方显示当前激活的 debuff 状态
## 数据源（unit meta，由 module_effect_handler 设置）：
##   _armor_break_stacks（破甲叠加层数）、_marked_until（标记过期时间戳）
##   _crit_marked_until（暴击标注过期时间戳）、_counter_marked_by（反炮标记来源）
## 过期的标记（_marked_until / _crit_marked_until）不显示
## 多个 debuff 横向排列在卡顶上方一行
## 用 Node2D + _draw() 自绘（避免 Label 在 Node2D 下不渲染）
static func sync_buff_labels(host: Node2D, unit_spr: Sprite2D, unit: Node) -> void:
	if host == null or unit_spr == null or unit == null:
		return
	# 收集当前激活的 debuff（顺序固定：破甲 → 标记 → 暴击 → 反炮）
	var tags: Array[Dictionary] = []
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	if unit.has_meta("_armor_break_stacks"):
		var stacks: int = int(unit.get_meta("_armor_break_stacks", 0))
		if stacks > 0:
			tags.append({"text": "破甲×%d" % stacks, "color": Color(1.0, 0.55, 0.25, 1.0), "bg": Color(0.30, 0.12, 0.05, 0.75)})
	if unit.has_meta("_marked_until"):
		var expire_at: float = float(unit.get_meta("_marked_until", 0.0))
		if expire_at > now_sec:
			tags.append({"text": "标记", "color": Color(0.95, 0.55, 0.95, 1.0), "bg": Color(0.28, 0.08, 0.22, 0.75)})
	if unit.has_meta("_crit_marked_until"):
		var expire_at2: float = float(unit.get_meta("_crit_marked_until", 0.0))
		if expire_at2 > now_sec:
			tags.append({"text": "暴击眼", "color": Color(1.0, 0.85, 0.30, 1.0), "bg": Color(0.30, 0.22, 0.05, 0.75)})
	if unit.has_meta("_counter_marked_by"):
		tags.append({"text": "反炮", "color": Color(0.80, 0.60, 1.0, 1.0), "bg": Color(0.18, 0.10, 0.30, 0.75)})
	# 容器节点（Node2D，挂在 host 下；子标签是 CardGridFloatingLabel）
	var container := host.get_node_or_null("BuffLabelsRow")
	if container == null:
		container = Node2D.new()
		container.name = "BuffLabelsRow"
		container.z_index = 16
		host.add_child(container)
	# 清理旧标签（每次重建，因为标签数量会变）
	for child in container.get_children():
		child.queue_free()
	if tags.is_empty():
		container.visible = false
		return
	container.visible = true
	# 标签布局参数
	var gap: float = 2.0
	# 第一遍：创建所有标签并测量宽度
	var labels: Array[CardGridFloatingLabel] = []
	var total_w: float = 0.0
	for i in range(tags.size()):
		var tag: Dictionary = tags[i]
		var lbl := CardGridFloatingLabel.new()
		lbl.name = "Tag%d" % i
		container.add_child(lbl)
		lbl.set_text(String(tag.get("text", "")))
		lbl.set_style(9, tag.get("color", Color.WHITE), Color(0, 0, 0, 0.85), 2, HORIZONTAL_ALIGNMENT_CENTER)
		lbl.set_background(tag.get("bg", Color(0, 0, 0, 0.6)), 2.0)
		labels.append(lbl)
		total_w += lbl.get_text_width() + 4.0  # +padding
		if i > 0:
			total_w += gap
	# 第二遍：从左到右定位
	var card_w: float = CardGridBattleLayout.battle_card_width_px()
	var card_h: float = card_w * 8.0 / 5.0
	var x_cursor: float = -total_w * 0.5
	var y_top: float = unit_spr.position.y - card_h * 0.5 - 12.0
	for i in range(labels.size()):
		var lbl: CardGridFloatingLabel = labels[i]
		var w: float = lbl.get_text_width() + 4.0
		lbl.position = Vector2(x_cursor + w * 0.5, y_top)
		x_cursor += w + gap
