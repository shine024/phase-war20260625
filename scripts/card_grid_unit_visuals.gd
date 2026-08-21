extends RefCounted
class_name CardGridUnitVisuals

const CardGridThumbnailScale = preload("res://scripts/card_grid_thumbnail_scale.gd")
const CardGridRankStrip = preload("res://scripts/card_grid_rank_strip.gd")
const CardGridBuffStrip = preload("res://scripts/card_grid_buff_strip.gd")
const CardGridModStrip = preload("res://scripts/card_grid_mod_strip.gd")
const CardGridBattleLayout = preload("res://scripts/card_grid_battle_layout.gd")
const CardGridFloatingLabel = preload("res://scripts/card_grid_floating_label.gd")
const RankRules = preload("res://data/rank_rules.gd")
const DT = preload("res://resources/design_tokens.gd")  # v13: 待机微动效 motion_reduce 守卫
const BossIdleAnim = preload("res://scripts/battle/boss_idle_anim.gd")  # v14/P2: boss 帧动画
const CardFrameUi = preload("res://scripts/card_frame_ui.gd")
const CardBackgroundUi = preload("res://scripts/card_background_ui.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const CapturedUnitCards = preload("res://data/captured_unit_cards.gd")
const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const CardFootAnchors = preload("res://data/card_foot_anchors.gd")
const GC = preload("res://resources/game_constants.gd")

## v8.x 性能优化：sync_buff_labels 的签名缓存（按 host instance_id），状态不变则跳过重建。
## 单位被 queue_free 时其 id 会被回收复用，但 host 销毁后不会再调 sync_buff_labels，
## 故残留 key 无害（仅占微量内存）；必要时可定期清理，但权衡下不值得。
static var _buff_label_sig_cache: Dictionary = {}


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
	# 统一卡图大小：所有单位按纹理宽度归一到固定卡宽（基础尺寸一致），再按缩放表
	# 乘以各自的视觉倍数（步兵小/坦克大/boss 更大）。缩放查询统一走 CardFootAnchors（单一真理源）。
	apply_uniform_card_sprite(unit_spr, tex, face_right)
	if card != null:
		var vs: float = CardFootAnchors.get_visual_scale(card)
		if vs > 0.0 and vs != 1.0:
			unit_spr.scale *= vs
	# 立绘居中（position 默认原点），不悬浮、不按脚线对齐。
	unit_spr.position = Vector2(unit_spr.position.x, 0.0)
	if card != null:
		apply_battle_card_chrome(host, unit_spr, card)
	sync_rank_strip(host, rank_level, unit_spr)
	sync_name_strip(host, unit_spr, card, face_right, unit)
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
	_apply_idle_motion(unit_spr, card)
	# v14/P2: boss/相位师专属待机——有帧资产走帧动画,无则 boss 级程序化待机(威压摇摆)
	var anim_id: String = card.card_id if card != null else ""
	if anim_id.is_empty() and unit != null and "_visual_archetype_id" in unit:
		anim_id = String(unit.get("_visual_archetype_id"))
	var is_boss_tier: bool = anim_id.begins_with("enemy_master") or anim_id.begins_with("boss_")
	if unit != null and unit.has_method("get_elite_spawn_type"):
		var st: String = String(unit.call("get_elite_spawn_type"))
		is_boss_tier = is_boss_tier or st == "elite" or st == "boss"
	elif unit != null and unit.has_meta("elite_spawn_type"):
		# v19: 产兵（ConstructUnit）无该方法，回退 meta——词缀怪也走 boss 级待机
		var st_meta: String = String(unit.get_meta("elite_spawn_type", ""))
		is_boss_tier = is_boss_tier or st_meta == "elite" or st_meta == "boss"
	if is_boss_tier and not anim_id.is_empty():
		BossIdleAnim.attach(unit_spr, anim_id)
		_boss_sway_idle(unit_spr)
	return true


## v14/P2: boss 级程序化待机——威压摇摆(rotation 缓摆,±0.6°)。
## 与待机浮动(y)/开火冲撞(x)/开火脉冲(scale)/受击闪白(modulate)全部不同属性,零冲突。
## rotation 在 host 上有受击后仰(_play_card_hit_recoil),这里只动 unit_spr 自身 rotation。
## Godot 4.5 实测:get_meta(key, default) 在 key 不存在时即使给了默认值,
## 引擎仍会向日志打 ERROR(功能正常但刷屏)——杀 meta 旧 tween 必须先 has_meta 守卫。
static func _kill_meta_tween(o: Object, key: String) -> void:
	if o == null or not o.has_meta(key):
		return
	var old: Variant = o.get_meta(key)
	if old is Tween:
		(old as Tween).kill()


static func _boss_sway_idle(unit_spr: Sprite2D) -> void:
	if unit_spr == null or DT.is_motion_reduce():
		return
	_kill_meta_tween(unit_spr, "_boss_sway_tw")
	var tw := unit_spr.create_tween().set_loops()
	tw.tween_property(unit_spr, "rotation", 0.011, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(unit_spr, "rotation", -0.011, 5.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(unit_spr, "rotation", 0.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	unit_spr.set_meta("_boss_sway_tw", tw)


## v13/v14: 待机微动效——Phase2 审计实锤"单位完全静止站桩,画面死"。
## v14 按兵种差异化:空中(AIR)大幅浮动±3px / 装甲缓浮(2.2s 周期,厚重) /
## 步兵轻快浮动±1.2px / 堡垒(FORT)完全不动(稳重感)。
## 全部走 position:y——scale 留给开火脉冲,避免两个 tween 同属性打架。
## 相位随机错开避免全屏同频;尊重 motion_reduce(无障碍)。
static func _apply_idle_motion(unit_spr: Sprite2D, card: CardResource) -> void:
	if unit_spr == null or DT.is_motion_reduce():
		return
	_kill_meta_tween(unit_spr, "_idle_tw")
	var kind: int = card.combat_kind if card != null else -1
	if kind == GC.CombatKind.FORT:
		return  # v14: 堡垒不动——要塞/工事的厚重稳重感
	var amp: float = 3.0 if kind == GC.CombatKind.AIR else 1.2
	var half: float = 1.0 if kind == GC.CombatKind.AIR else (1.8 if kind == GC.CombatKind.ARMOR else 1.3)
	half += randf() * 0.4  # 相位错开
	var base_y: float = unit_spr.position.y
	var tw := unit_spr.create_tween().set_loops()
	tw.tween_property(unit_spr, "position:y", base_y - amp, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(unit_spr, "position:y", base_y, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	unit_spr.set_meta("_idle_tw", tw)


## v14: 开火冲撞——前倾冲撞(0.05s)→后坐回弹(0.08s)→归位(0.10s)。
## 预备-发力-跟随三段,让单位本体参与开火演出(此前只有枪口火在动,本体纹丝不动)。
## 与待机浮动不同轴(x vs y)不打架;与开火缩放脉冲(scale)不同属性不打架。
## fire_right: 攻击朝向;heavy: 重武器(曲射/火箭/导弹/能量)冲撞幅度加倍。
static func fire_lunge_sprite(spr: Sprite2D, face_right: bool, heavy: bool) -> void:
	if spr == null or DT.is_motion_reduce():
		return
	_kill_meta_tween(spr, "_lunge_tw")
	var base_x: float = spr.position.x
	if spr.has_meta("_lunge_base_x"):
		base_x = float(spr.get_meta("_lunge_base_x"))
		spr.position.x = base_x  # 杀旧冲撞后先归位再重放
	var dir: float = 1.0 if face_right else -1.0
	var amp: float = 8.0 if heavy else 4.0
	spr.set_meta("_lunge_base_x", base_x)
	var tw := spr.create_tween()
	tw.tween_property(spr, "position:x", base_x + amp * dir, 0.05).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "position:x", base_x - amp * 0.4 * dir, 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "position:x", base_x, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	spr.set_meta("_lunge_tw", tw)


## v14: 开火冲撞(按单位节点找 Sprite 子节点)——给蜂群等无实例方法的单位用。
## Sprite 子节点名兼容 "Sprite"(玩家) / "Sprite2D"(敌方);找不到静默返回。
static func fire_lunge_unit(unit: Node, face_right: bool, heavy: bool) -> void:
	if unit == null or not is_instance_valid(unit) or DT.is_motion_reduce():
		return
	var spr: Sprite2D = unit.get_node_or_null("Sprite") as Sprite2D
	if spr == null:
		spr = unit.get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	fire_lunge_sprite(spr, face_right, heavy)


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
	# v19: 相位师产兵（ConstructUnit）无该方法，回退读 meta elite_spawn_type
	# （enemy_phase_field_driver 词缀产兵时写入），让词缀怪也有金角标
	var spawn_type: String = ""
	if unit.has_method("get_elite_spawn_type"):
		spawn_type = String(unit.get_elite_spawn_type())
	elif unit.has_meta("elite_spawn_type"):
		spawn_type = String(unit.get_meta("elite_spawn_type", ""))
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
	# 定位：实体左上角（与右上角的 RarityBadge 对称），锚定实体顶部
	var card_w_eb: float = CardGridBattleLayout.BASE_CARD_WIDTH_PX
	badge.position = Vector2(-card_w_eb * 0.42, entity_top_y(unit_spr) - s)
	badge.visible = true


## v6.5: 在卡片立绘底部绘制单位名称条（我方青 / 敌方橙），补齐格子战可读性。
static func sync_name_strip(host: Node2D, unit_spr: Sprite2D, card: CardResource, is_player: bool, unit: Node = null) -> void:
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
	# v9.x: 势力前缀平台产兵（一战 4 相位师）名称加势力前缀，显示「势力前缀·真实兵种名」。
	# faction_prefix meta 由 enemy_phase_field_driver 在产兵时按 LEGACY_PLATFORM_TO_ARCHETYPE 记录。
	if unit != null and not display_name.is_empty():
		var prefix: String = String(unit.get_meta("faction_prefix", ""))
		if not prefix.is_empty():
			display_name = "%s·%s" % [prefix, display_name]
	# 卡的尺寸取标准卡宽（CardBattleBg 已在 apply_battle_card_chrome 强制隐藏且不加载纹理，
	# 故 bg_spr.texture 恒为 null，原 bg_spr 读取分支永不命中，已清理）
	var card_w: float = CardGridBattleLayout.BASE_CARD_WIDTH_PX
	var card_h: float = card_w * 8.0 / 5.0
	strip.rebuild(display_name, is_player, card_w, card_h)
	# 名字条锚定到实体脚部（地面线 y=0）下方固定距离，不再随卡框尺寸浮动。
	# 实体脚部 = unit_spr 经 offset 底部对齐后落在节点原点(y=0)；名字条在脚下固定 6px。
	# 这样不同缩放/不同图，名字条离实体脚部距离恒定。
	var bar_h: float = maxf(card_w * 0.30, 14.0)
	strip.position = Vector2(unit_spr.position.x, 0.0 + 6.0)


static func apply_uniform_card_sprite(spr: Sprite2D, tex: Texture2D, face_right: bool = false) -> float:
	if spr == null:
		return 0.1
	if tex != null:
		spr.texture = tex
	var sc: float = CardGridThumbnailScale.compute_battlefield_uniform_width_scale(
		spr.texture if spr.texture != null else tex
	)
	# 脚部对齐地面线：用扫描得到的 foot_frac（脚距纹理底的比例）算 offset。
	# centered 立绘：纹理底部相对中心 = +tex_h/2，脚在纹理底上方 foot_frac*tex_h 处。
	# offset.y 让脚落在节点原点(地面线 y=0)：offset.y = -(0.5 - foot_frac) * tex_h
	# offset 在纹理空间，随 scale 缩放后脚部恒在原点（与 scale 无关）。
	spr.offset = Vector2(0.0, _foot_offset_y(spr.texture))
	# v7.x: 图本身已携带朝向（vis_player=翻转/我方，vis_enemy=原图/敌方），不再 scale 翻转。
	# face_right 参数保留仅用于 sync_name_strip 的敌我颜色区分，不影响贴图朝向。
	spr.scale = Vector2(sc, sc)
	return abs(sc)


## 算立绘 offset.y 让脚部对齐地面（节点原点 y=0）。
static func _foot_offset_y(tex: Texture2D) -> float:
	if tex == null:
		return 0.0
	var tex_h: float = maxf(float(tex.get_height()), 1.0)
	var file_name: String = ""
	if tex.resource_path != null and not tex.resource_path.is_empty():
		file_name = String(tex.resource_path).get_file().get_basename()
	var foot_frac: float = CardFootAnchors.get_foot_frac(file_name)
	return -(0.5 - foot_frac) * tex_h


## 返回实体顶部相对节点原点(地面线 y=0)的 Y 坐标（负值，在脚上方）。
## 供头顶 UI（军衔条/角标/等级）锚定，保证 UI 离实体顶部固定距离（不随缩放/卡框浮动）。
static func entity_top_y(unit_spr: Sprite2D) -> float:
	return CardFootAnchors.entity_top_y_for_sprite(unit_spr)


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


## 格子战立绘：势力底图/稀有度卡框已停用（去框去背景），仅保留立绘本身。
## 仍确保两个 chrome 节点存在并隐藏，兼容老单位/其他读取这些节点的代码。
## 血条/军衔条/名称条/角标等功能性 UI 在其它兄弟函数中处理，不受影响。
static func apply_battle_card_chrome(host: Node2D, unit_spr: Sprite2D, card: CardResource) -> void:
	if host == null or unit_spr == null or card == null:
		return
	var bg_spr := _ensure_battle_chrome_sprite(host, "CardBattleBg", 4)
	var frame_spr := _ensure_battle_chrome_sprite(host, "CardBattleFrame", 14)
	for chrome in [bg_spr, frame_spr]:
		chrome.centered = true
		chrome.position = unit_spr.position
		chrome.visible = false  # 去卡框/卡背景：彻底隐藏，不加载纹理
	unit_spr.z_index = 10


static func sync_rank_strip(host: Node2D, rank_level: int, spr: Sprite2D) -> void:
	# 战场单位顶部军衔条已移除（v7.x 布局优化），仅保留兼容性空实现
	if host == null:
		return
	# 移除rank strip节点以避免显示
	var strip: CardGridRankStrip = host.get_node_or_null("CardGridRankStrip") as CardGridRankStrip
	if strip != null and is_instance_valid(strip):
		strip.visible = false
		# 可选：从场景中移除节点
		# host.remove_child(strip)


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
	# 卡宽取标准值（CardBattleBg 已隐藏不加载纹理，bg_spr 读取分支永不命中，已清理）
	var card_w: float = CardGridBattleLayout.BASE_CARD_WIDTH_PX
	var card_h: float = card_w * 8.0 / 5.0
	strip.rebuild(kinds, card_w)
	# buff 条移到血条上方横排：血条在 entity_top_y-14，buff 条在血条上方（留 4px 间距）。
	# buff_strip 内部以原点为中心绘制，故 position.y 对齐到目标行中心。
	var top_y_bs: float = entity_top_y(spr)
	var hp_bar_y_bs: float = top_y_bs - 14.0
	strip.position = Vector2(0.0, hp_bar_y_bs - 4.0 - card_w * 0.11)


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
	# 定位：实体右上角，锚定实体顶部（不随卡框/缩放浮动）
	var card_w_rb: float = CardGridBattleLayout.BASE_CARD_WIDTH_PX
	badge.position = Vector2(card_w_rb * 0.42, entity_top_y(unit_spr) - s)
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
	# 定位：实体左上角，锚定实体顶部
	var card_w_lt: float = CardGridBattleLayout.BASE_CARD_WIDTH_PX
	label.position = Vector2(-card_w_lt * 0.5 - 18.0, entity_top_y(unit_spr) - 8.0)
	label.visible = true


## v7.x: HP数值标签已弃用，HP现在显示在血条内部（保留兼容性函数）
static func sync_hp_label(host: Node2D, unit_spr: Sprite2D, unit: Node) -> void:
	# 已移除：HP now displayed inside blood bar via unit_hp_bar
	# 清理可能存在的旧标签
	var label := host.get_node_or_null("HpValueLabel") as CardGridFloatingLabel
	if label != null and is_instance_valid(label):
		label.visible = false


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
	# v8.x: mod_strip 在 buff_strip 上方，分层 z_index(14>13) 防止小卡图下两行重叠
	strip.z_index = 14
	# 卡宽取标准值（CardBattleBg 已隐藏不加载纹理，bg_spr 读取分支永不命中，已清理）
	var card_w: float = CardGridBattleLayout.BASE_CARD_WIDTH_PX
	var card_h: float = card_w * 8.0 / 5.0
	strip.rebuild(kinds, card_w)
	# mod 条移到 buff 条上方横排（头顶最上层）：buff 条在 hp_bar_y-4-0.22w，mod 再往上。
	var top_y_ms: float = entity_top_y(spr)
	var hp_bar_y_ms: float = top_y_ms - 14.0
	strip.position = Vector2(0.0, hp_bar_y_ms - 4.0 - card_w * 0.22 - 2.0 - card_w * 0.09)


# ============================================================================
#  v7.x 战场视觉反馈：漂浮 buff/debuff 标签（卡顶上方）
# ============================================================================

## 漂浮 buff/debuff 标签：单位卡顶上方（rank_strip 之上）显示当前激活的 debuff 状态
## 数据源（unit meta，由 module_effect_handler 设置）：
##   _armor_break_stacks（破甲叠加层数）、_marked_until（标记过期时间戳）
##   _crit_marked_until（暴击标注过期时间戳）、_counter_marked_by（反炮标记来源）
## 过期的标记（_marked_until / _crit_marked_until）不显示
## 多个 debuff 横向排列在 rank_strip 上方一行
##
## 位置选择说明：卡顶元素垂直分层（从下到上）：
##   level_tag/rarity_badge/elite_badge (-card_h/2-6~-8，左右两侧)
##   rank_strip (-card_h/2-12~rank_h，居中)
##   buff_labels (-card_h/2-28，居中，rank_strip 之上 16px)
## 卡底留给 hp_value（+20）+ buff_strip/mod_strip（+24 起）
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
	# signature 去重：状态不变则跳过重建（避免每 0.3s × 全场单位 queue_free + new）
	var sig_parts: PackedStringArray = []
	for t in tags:
		sig_parts.append(String(t.get("text", "")))
	var sig: String = "|".join(sig_parts)
	var host_id: int = host.get_instance_id()
	if _buff_label_sig_cache.has(host_id) and String(_buff_label_sig_cache[host_id]) == sig:
		return  # 状态未变，跳过
	_buff_label_sig_cache[host_id] = sig
	# 容器节点（Node2D，挂在 host 下；子标签是 CardGridFloatingLabel）
	var container := host.get_node_or_null("BuffLabelsRow")
	if container == null:
		container = Node2D.new()
		container.name = "BuffLabelsRow"
		container.z_index = 16
		host.add_child(container)
	if tags.is_empty():
		container.visible = false
		# 清理可能残留的旧标签
		for child in container.get_children():
			child.queue_free()
		return
	container.visible = true
	# 节点池复用：尽量复用已有子标签，多余的 queue_free，不足的 new（避免全量重建）
	var existing: Array[Node] = container.get_children()
	var gap: float = 2.0
	var labels: Array[CardGridFloatingLabel] = []
	var total_w: float = 0.0
	for i in range(tags.size()):
		var tag: Dictionary = tags[i]
		var lbl: CardGridFloatingLabel
		if i < existing.size() and is_instance_valid(existing[i]):
			lbl = existing[i] as CardGridFloatingLabel
		else:
			lbl = CardGridFloatingLabel.new()
			lbl.name = "Tag%d" % i
			container.add_child(lbl)
		lbl.set_text(String(tag.get("text", "")))
		lbl.set_style(9, tag.get("color", Color.WHITE), Color(0, 0, 0, 0.85), 2, HORIZONTAL_ALIGNMENT_CENTER)
		lbl.set_background(tag.get("bg", Color(0, 0, 0, 0.6)), 2.0)
		labels.append(lbl)
		total_w += lbl.get_text_width() + 4.0  # +padding
		if i > 0:
			total_w += gap
	# 销毁多余的旧标签（标签数量减少时）
	for i in range(tags.size(), existing.size()):
		if is_instance_valid(existing[i]):
			existing[i].queue_free()
	# 从左到右定位（buff 标签在实体顶部上方 28px，与稀有度/精英角标同基准 entity_top_y 对齐）
	var x_cursor: float = -total_w * 0.5
	var y_top: float = entity_top_y(unit_spr) - 28.0
	for i in range(labels.size()):
		var lbl: CardGridFloatingLabel = labels[i]
		var w: float = lbl.get_text_width() + 4.0
		lbl.position = Vector2(x_cursor + w * 0.5, y_top)
		x_cursor += w + gap
