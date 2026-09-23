class_name GroundLootLayer
extends Node2D
## v33 地面战利品层：击杀掉落实体（纳米颗粒/能量电池/情报碎片/符文/缴获卡）。
##
## 定位（用户拍板"开箱感"设计）：反馈剧场，零玩法——所有经济入账照旧走原链
## （纳米/缴获/符文在 battle_damage_system 原地结算，图纸主腿前移但战后原口发放），
## 本层只做"这一杀值不值"的可见性。不做点击拾取（v32 反支柱：不做微操）。
##
## 三档呈现（色板走 GC.get_rarity_color 唯一权威源）：
## - 货币（纳米/电池）：小簇+微光，落地 ~2s 收走并飘 +N——节奏感，不驻留
## - rare：+地面色环脉动，驻留
## - epic+：+竖直光柱/冲击环/名字标签/落地音——开箱时刻，驻留到战斗结束
## 驻留件全局上限 MAX_PERSIST（超出最旧先收）——v26"满地残骸圆斑"教训不复发。
##
## 守卫：极速推演（BattleTimeState.ff_active）整体不生成（奖励照发，演出静音；
## FF 场次阵亡点也不记录，胜利打扫战场自然空转）；DT.is_motion_reduce() 跳
## 抛掷/光柱/收拢动画，只留静态本体+即时标签。
##
## 挂载：battlefield._ready 创建（z=-3：焦痕 -4 之上/槽位高亮 -2 之下/单位 0 之下），
## 进 PERSISTENT_CHILD_NAMES 跨场常驻；内容自管——battle_started 清空、
## battle_ended 胜利"打扫战场"（撒电池+收拢，需在 v20.15 的 1.6s 视口冻结窗内
## 完成）/失败静默淡出。
## v36 实机验收：货币贴图换数量分档变体家族（drops/drop_{nano,battery}_{1,2,3}.png，
## 256 画布内容高 190px 标定，tools/_tmp_drop_variants.py 可重跑）；
## basic_nano.png 已原位抠透明底（原图备份 _art_backup/，HUD 资源条同源受益）；
## 货币档加地面柔光呼吸、缴获卡 36→30px。

const BattleTimeState = preload("res://scripts/battle/battle_time_state.gd")
const DT = preload("res://resources/design_tokens.gd")
const GC = preload("res://resources/game_constants.gd")
const VfxImpactFactory = preload("res://scripts/battle/vfx_impact_factory.gd")
const CardGridFloatingLabelScript = preload("res://scripts/card_grid_floating_label.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")

const TEX_NANO_TIERS: Array[Texture2D] = [   # 数量分档变体（v36：tools/_tmp_drop_variants.py 产出，256 画布内容高 ~190px）
	preload("res://assets/resources/drops/drop_nano_1.png"),
	preload("res://assets/resources/drops/drop_nano_2.png"),
	preload("res://assets/resources/drops/drop_nano_3.png"),
]
const TEX_BATTERY_TIERS: Array[Texture2D] = [
	preload("res://assets/resources/drops/drop_battery_1.png"),
	preload("res://assets/resources/drops/drop_battery_2.png"),
	preload("res://assets/resources/drops/drop_battery_3.png"),
]
const CURRENCY_TEX_CONTENT_PX: float = 190.0   # 变体画布内容标定高（scale = 目标px / 此值）
# v37 实机验收（用户"掉落晶体还是太大"）：整体缩约 30%——地面线索靠柔光呼吸承担（_draw 段），
# 本体不再放大撑可读性
const CURRENCY_PX_NANO: Array[float] = [14.0, 18.0, 23.0]     # 单体/双粒/小堆 目标高
const CURRENCY_PX_BATTERY: Array[float] = [16.0, 21.0, 26.0]

## 类型常量（spawn_loot 的 type 入参）
const TYPE_NANO := "nano"
const TYPE_BATTERY := "battery"
const TYPE_FRAG := "frag"
const TYPE_RUNE := "rune"
const TYPE_CARD := "card"

const MAX_PERSIST := 24           # 驻留件上限（含收拢中未销毁的）
const QUICK_LIFETIME := 2.0       # 货币落地驻留时长（s）
const NANO_MERGE_RADIUS := 60.0   # 纳米同型并堆半径（蜂群波不刷屏）
const DEATH_POS_CAP := 48         # 阵亡点记录上限（电池"打扫战场"取样用）
const SWEEP_BATTERY_MIN := 5      # 打扫战场电池堆数（min..max 随机）
const SWEEP_BATTERY_MAX := 7

## 层实例引用（battlefield 每会话建一次；static 入口全部经它做活性/FF 双守卫）
static var active: GroundLootLayer = null

var _items: Array = []          # 驻留件（frag/rune/card 的 LootItem）
var _nano_piles: Array = []     # 纳米堆簿记 {node: LootItem}（amount 存 node.amount）
var _death_pos: Array = []      # 本场阵亡点（record_death_pos 累积）
var _sweeping := false
var _sweep_gen := 0             # battle_started 清场代际号：作废在途收拢协程


static func spawn_loot(type: String, pos: Vector2, rarity: String = "common",
		amount: int = 1, label_text: String = "", card: Resource = null) -> void:
	if BattleTimeState.ff_active:
		return
	if active == null or not is_instance_valid(active):
		return
	active._spawn(type, pos, rarity, amount, label_text, card)


## 记录阵亡点（胜利"打扫战场"撒电池的取样池；FF 场次不记=空转）
static func record_death_pos(pos: Vector2) -> void:
	if BattleTimeState.ff_active:
		return
	if active == null or not is_instance_valid(active):
		return
	active._record_death_pos(pos)


func _ready() -> void:
	active = self
	SignalBus.battle_started.connect(_on_battle_started)
	SignalBus.battle_ended.connect(_on_battle_ended)


func _exit_tree() -> void:
	if active == self:
		active = null


func _on_battle_started() -> void:
	_sweep_gen += 1   # 作废在途收拢协程
	for child in get_children():
		child.queue_free()
	_items.clear()
	_nano_piles.clear()
	_death_pos.clear()
	_sweeping = false


func _on_battle_ended(player_won: bool) -> void:
	if _sweeping:
		return
	if player_won and not BattleTimeState.ff_active:
		_victory_sweep()
	else:
		_fade_all()


# ── 生成 ───────────────────────────────────────────────────────────

func _spawn(type: String, pos: Vector2, rarity: String, amount: int,
		label_text: String, card: Resource) -> void:
	if type == TYPE_NANO:
		_spawn_nano(pos, amount)
		return
	var item: LootItem = LootItem.new()
	item.setup(type, pos, rarity, amount, label_text, card)
	add_child(item)
	if type == TYPE_BATTERY:
		return   # 电池只在"打扫战场"时撒，随后随收拢走，不进驻留簿记
	_items.append(item)
	_enforce_persist_cap()


## 数量分档：1-7 单体 / 8-29 双粒簇 / 30+ 小堆（纳米并堆累计同口径升档）
static func currency_tier(amount: int) -> int:
	if amount >= 30:
		return 2
	if amount >= 8:
		return 1
	return 0


static func _currency_scale(px_table: Array[float], tier: int) -> float:
	return px_table[clampi(tier, 0, 2)] / CURRENCY_TEX_CONTENT_PX


func _spawn_nano(pos: Vector2, amount: int) -> void:
	# 并堆：60px 内已有活纳米堆 → 数量累加+刷新飘字（蜂群连杀不刷屏）
	_prune_dead_piles()
	for pile in _nano_piles:
		var node = pile["node"]   # 未类型化同 _prune_dead_piles：freed 实例先判活再触碰
		if node == null or not is_instance_valid(node):
			continue
		if node.global_position.distance_to(pos) <= NANO_MERGE_RADIUS:
			node.amount = int(node.amount) + amount
			node.refresh_currency_visual()   # v36：跨档升贴图（单体→双粒→小堆）
			node.show_gain_float("+%d" % int(node.amount), DT.COLOR_RES_NANO)
			return
	var item: LootItem = LootItem.new()
	item.setup(TYPE_NANO, pos, "common", amount, "", null)
	add_child(item)
	_nano_piles.append({"node": item})
	item.begin_quick_cycle(QUICK_LIFETIME)


func _prune_dead_piles() -> void:
	for i in range(_nano_piles.size() - 1, -1, -1):
		# 局部必须未类型化：已 free 的实例赋给 LootItem 类型化局部会先报运行时错并
		# 中止本函数——死条目永远删不掉，后续 _spawn_nano 连锁中止、掉落演出被吞
		var node = _nano_piles[i]["node"]
		if node == null or not is_instance_valid(node):
			_nano_piles.remove_at(i)


func _enforce_persist_cap() -> void:
	while _items.size() > MAX_PERSIST:
		var oldest = _items.pop_front()
		if oldest != null and is_instance_valid(oldest):
			oldest.collect_silent()


func _record_death_pos(pos: Vector2) -> void:
	_death_pos.append(pos)
	if _death_pos.size() > DEATH_POS_CAP:
		_death_pos.pop_front()


# ── 战斗收尾 ────────────────────────────────────────────────────────

## 胜利"打扫战场"：阵亡点撒电池堆（能量块战后掉落的可见性，纯演出不改经济），
## 随后全体战利品 stagger 上浮收拢。必须在 battle_ended 后 1.6s 视口冻结窗内完成
## （v20.15 冻结延迟），总时长预算 ≤1.3s。
func _victory_sweep() -> void:
	_sweeping = true
	var gen := _sweep_gen
	var reduce := DT.is_motion_reduce()
	if not _death_pos.is_empty():
		var count: int = mini(randi_range(SWEEP_BATTERY_MIN, SWEEP_BATTERY_MAX), _death_pos.size())
		for i in count:
			# 等距取样（步长 7 错开）避免电池扎堆在同一阵亡点
			var p: Vector2 = _death_pos[(i * 7 + 3) % _death_pos.size()]
			var item: LootItem = LootItem.new()
			item.setup(TYPE_BATTERY, p, "common", 1, "", null)
			add_child(item)
		if not reduce:
			await get_tree().create_timer(0.35).timeout
			if gen != _sweep_gen or not is_inside_tree():
				return
	_collect_all_staggered(reduce)


## v6.22: 回收计数上报（培养性委托 salvage_items；QuestManager 不在场静默跳过）
func _notify_salvage(count: int) -> void:
	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm != null and qm.has_method("notify_items_salvaged"):
		qm.notify_items_salvaged(count)


func _collect_all_staggered(reduce: bool) -> void:
	var all_items: Array = []
	for child in get_children():
		if child is LootItem:
			all_items.append(child)
	# 收拢节拍：总量越多步距越密，总时长钳在 ~0.9s + 单件 0.4s
	var step: float = clampf(0.9 / maxf(1.0, float(all_items.size())), 0.02, 0.06)
	if not all_items.is_empty():
		_notify_salvage(all_items.size())
	for i in all_items.size():
		var item: LootItem = all_items[i]
		if item != null and is_instance_valid(item):
			item.collect_rise(0.1 + float(i) * step, reduce)
	_items.clear()
	_nano_piles.clear()
	_death_pos.clear()
	_sweeping = false


func _fade_all() -> void:
	for child in get_children():
		if child is LootItem:
			child.collect_silent()
	_items.clear()
	_nano_piles.clear()
	_death_pos.clear()
	_sweeping = false


# ═══════════════════════════════════════════════════════════════════
#  单件地面战利品：本体 + 稀有度附件 + 自身生命周期
# ═══════════════════════════════════════════════════════════════════

class LootItem extends Node2D:
	var ltype := "nano"
	var rarity := "common"
	var amount := 1
	var label_text := ""
	var collected := false

	var _body: CanvasItem = null
	var _toss_tween: Tween = null
	var _fade_tween: Tween = null
	var _ring_color: Color = Color(0, 0, 0, 0)
	var _glow_color: Color = Color(0, 0, 0, 0)   # v36：货币档地面柔光（防被单位遮挡后找不到）
	var _cur_tier: int = 0                        # v36：货币数量档（跨档换贴图用）
	var ring_t := 0.0   # 脉动相位（0→1 循环，_draw 消费：rare 环 / 货币柔光共用）

	## 浮字相对层 z(-3) 的抬升值：净 15 = 单位(0) 之上、头顶 UI(20) 之下
	const FLOAT_LABEL_Z := 18

	func setup(p_type: String, p_pos: Vector2, p_rarity: String,
			p_amount: int, p_label: String, p_card: Resource) -> void:
		ltype = p_type
		rarity = p_rarity
		amount = maxi(1, p_amount)
		label_text = p_label
		position = p_pos
		_build_body(p_card)
		_build_rarity_fx()
		_play_toss()

	# ── 本体 ────────────────────────────────────────────────────────

	func _build_body(card: Resource) -> void:
		match ltype:
			GroundLootLayer.TYPE_NANO:
				# v36 数量分档变体：单体晶石 / 双粒簇 / 五晶小堆（tools/_tmp_drop_variants.py 产出）
				_cur_tier = GroundLootLayer.currency_tier(amount)
				_body = _make_sprite(GroundLootLayer.TEX_NANO_TIERS[_cur_tier],
					GroundLootLayer._currency_scale(GroundLootLayer.CURRENCY_PX_NANO, _cur_tier), Vector2.ZERO)
			GroundLootLayer.TYPE_BATTERY:
				_cur_tier = GroundLootLayer.currency_tier(amount)
				_body = _make_sprite(GroundLootLayer.TEX_BATTERY_TIERS[_cur_tier],
					GroundLootLayer._currency_scale(GroundLootLayer.CURRENCY_PX_BATTERY, _cur_tier), Vector2.ZERO)
			GroundLootLayer.TYPE_CARD:
				var tex: Texture2D = null
				if card != null:
					var path: String = UiAssetLoader.card_icon_path_for(card)
					tex = UiAssetLoader.battle_tex_for_path(path, card)
				if tex != null:
					_body = _make_card_sprite(tex)
				else:
					_body = _make_diamond(GC.get_rarity_color(rarity), 12.0)
			_:
				# 情报碎片/符文：稀有度色多边形本体 + 加法混合亮芯
				_body = _make_diamond(GC.get_rarity_color(rarity),
					11.0 if ltype == GroundLootLayer.TYPE_RUNE else 13.0)

	## v36：纳米并堆跨档时换档贴图（重建本体；货币件无稀有度附件，无需重建）
	func refresh_currency_visual() -> void:
		if ltype != GroundLootLayer.TYPE_NANO and ltype != GroundLootLayer.TYPE_BATTERY:
			return
		var tier := GroundLootLayer.currency_tier(amount)
		if tier == _cur_tier:
			return
		_cur_tier = tier
		_body = null
		for c in get_children():
			c.queue_free()
		_build_body(null)
		_start_idle_pulse()

	func _make_sprite(tex: Texture2D, scl: float, offset: Vector2) -> Sprite2D:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2.ONE * scl
		spr.position = offset
		spr.rotation = randf_range(-0.2, 0.2)
		add_child(spr)
		return spr

	func _make_card_sprite(tex: Texture2D) -> Node2D:
		# v37 实机验收（用户把裸缩卡图误读成"缩小的骑兵"）：缴获卡地面件加迷你卡框——
		# 稀有度色描边 + 深底 + 画芯 + 底部名条，一眼读成"一张卡"而不是单位缩略图。
		# 外框 28×36（对齐旧 30px 站位口径）；_body 挂 holder，待机呼吸 modulate 整组生效。
		var holder := Node2D.new()
		var rarity_col: Color = GC.get_rarity_color(rarity)
		var frame := Polygon2D.new()
		frame.polygon = _rect_pts(-14.0, -18.0, 28.0, 36.0)
		frame.color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.95)
		holder.add_child(frame)
		var face := Polygon2D.new()
		face.polygon = _rect_pts(-11.5, -15.5, 23.0, 31.0)
		face.color = Color(0.05, 0.07, 0.11, 0.96)
		holder.add_child(face)
		var art := Sprite2D.new()
		art.texture = tex
		art.scale = Vector2.ONE * (20.0 / maxf(1.0, float(tex.get_width())))
		art.position = Vector2(0, -3.5)
		holder.add_child(art)
		var strip := Polygon2D.new()
		strip.polygon = _rect_pts(-8.0, 9.0, 16.0, 3.0)
		strip.color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.55)
		holder.add_child(strip)
		add_child(holder)
		return holder

	## 轴对齐矩形多边形顶点（迷你卡框图层共用）
	func _rect_pts(x: float, y: float, w: float, h: float) -> PackedVector2Array:
		return PackedVector2Array([
			Vector2(x, y), Vector2(x + w, y),
			Vector2(x + w, y + h), Vector2(x, y + h),
		])

	## 菱形/六边形本体：稀有度色实心 + 白亮芯（加法混合）
	func _make_diamond(color: Color, radius: float) -> Polygon2D:
		var pts := PackedVector2Array([
			Vector2(0, -radius), Vector2(radius * 0.7, 0),
			Vector2(0, radius), Vector2(-radius * 0.7, 0),
		])
		if ltype == GroundLootLayer.TYPE_RUNE:
			pts = PackedVector2Array()
			for i in 6:
				var ang := TAU * float(i) / 6.0 + PI / 6.0
				pts.append(Vector2(cos(ang), sin(ang)) * radius)
		var poly := Polygon2D.new()
		poly.polygon = pts
		poly.color = Color(color.r, color.g, color.b, 0.92)
		add_child(poly)
		var core := Polygon2D.new()
		var core_pts := PackedVector2Array()
		for p in pts:
			core_pts.append(p * 0.45)
		core.polygon = core_pts
		core.color = Color(1.0, 1.0, 1.0, 0.45)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		core.material = mat
		add_child(core)
		return poly

	# ── 稀有度附件（三档情感预算）───────────────────────────────────

	func _build_rarity_fx() -> void:
		if ltype == GroundLootLayer.TYPE_NANO or ltype == GroundLootLayer.TYPE_BATTERY:
			# v36：货币档加地面柔光呼吸（原"本体即全部"——贴图缩小后需要拾取线索）
			_glow_color = DT.COLOR_RES_NANO if ltype == GroundLootLayer.TYPE_NANO else DT.COLOR_RES_ENERGY
			if not DT.is_motion_reduce():
				var tw := create_tween().set_loops()
				tw.tween_method(_advance_ring, 0.0, 1.0, 1.4)
			return
		var tier := _rarity_tier()
		if tier >= 1:
			_ring_color = GC.get_rarity_color(rarity)
			var tw := create_tween().set_loops()
			tw.tween_method(_advance_ring, 0.0, 1.0, 1.3)
		if tier >= 2:
			_add_pillar()
			_add_name_label()
			# v38：掉落音效挪到 _on_landed（落地瞬间发声，原在悬空构建期）

	func _rarity_tier() -> int:
		match rarity:
			"epic", "legendary", "mythic":
				return 2
			"rare":
				return 1
			_:
				return 0

	## 竖直光柱：顶点色渐隐多边形 + 加法混合（高级感来自光，不来自贴图）。
	## v33.1 首拍评审：光柱纤细/档位差不显著 → 加宽加高拉开梯度（112/142/168）。
	func _add_pillar() -> void:
		var color := GC.get_rarity_color(rarity)
		var height := 112.0
		match rarity:
			"legendary":
				height = 142.0
			"mythic":
				height = 168.0
		var half_w := 11.0
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-half_w, -6.0), Vector2(half_w, -6.0),
			Vector2(half_w * 0.62, -height), Vector2(-half_w * 0.62, -height),
		])
		var c_base := Color(color.r, color.g, color.b, 0.42)
		var c_top := Color(color.r, color.g, color.b, 0.0)
		poly.vertex_colors = PackedColorArray([c_base, c_base, c_top, c_top])
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		poly.material = mat
		add_child(poly)

	func _add_name_label() -> void:
		if label_text.is_empty():
			return
		var label: Node2D = CardGridFloatingLabelScript.new()
		label.position = Vector2(0, -42)
		label.z_index = FLOAT_LABEL_Z
		add_child(label)
		label.set_style(13, GC.get_rarity_color(rarity), Color(0, 0, 0, 0.85), 3)
		label.set_background(Color(0.04, 0.05, 0.08, 0.66), 4.0)
		label.set_text(label_text)

	func _play_drop_sfx() -> void:
		# AudioManager.play_sfx 自带极速推演压制（非白名单静默），此处无需重复守卫
		# 注意：本函数在 setup() 内执行——LootItem 尚未 add_child（树外），绝对路径
		# get_node 会触发引擎层报错，须经主循环 root 查 autoload
		var loop := Engine.get_main_loop()
		if loop == null or not (loop is SceneTree):
			return
		var am := (loop as SceneTree).root.get_node_or_null("AudioManager")
		if am == null or not am.has_method("play_sfx"):
			return
		if ltype == GroundLootLayer.TYPE_CARD:
			am.play_sfx("card_pickup", 0.8)
		else:
			am.play_sfx("blueprint_unlock", 0.7)

	# ── 落地/待机/收走 ─────────────────────────────────────────────

	func _play_toss() -> void:
		# v38.2（用户澄清掉落语义）：不是"从天上掉下来"，是**击毁后炸出来散放在地上**——
		# 每件以随机方向/随机距离从落点甩出（小跳 ≤12px），落定带随机倾角；
		# 同次多点掉落方向/距离/倾角各异 → 地面"散放"读感。整齐排布/垂直下落都是反例。
		var eject_dir: float = randf() * TAU
		var eject_dist: float = randf_range(18.0, 64.0)
		var land := position + Vector2.from_angle(eject_dir) * eject_dist
		# 倾角只转本体（光柱/名条/地面柔光保持竖直——散放的是"东西"，不是光）
		if _body != null and is_instance_valid(_body):
			_body.rotation = randf_range(-0.24, 0.24)  # ±14°
		if DT.is_motion_reduce():
			position = land
			_on_landed()
			return
		var start := position
		_toss_tween = create_tween()
		_toss_tween.tween_method(
			func(t: float):
				position = start.lerp(land, t) + Vector2.UP * (12.0 * sin(PI * t)),
			0.0, 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_toss_tween.tween_callback(_on_landed)

	func _on_landed() -> void:
		var tier := _rarity_tier()
		var parent := get_parent() as Node2D
		if not DT.is_motion_reduce() and parent != null:
			var color := GC.get_rarity_color(rarity)
			if tier >= 2:
				var radius := 56.0 if rarity == "legendary" or rarity == "mythic" else 44.0
				VfxImpactFactory.spawn_shockwave(parent, global_position, radius, color)
			else:
				# v38：低档也落地有痕——小尘环（弱/快/低透明），"有东西掉下来"的地面反馈
				var dust: Color = _glow_color if _glow_color.a > 0.01 else Color(color.r, color.g, color.b, 0.5)
				VfxImpactFactory.spawn_shockwave(parent, global_position, 24.0,
					Color(dust.r, dust.g, dust.b, 0.5))
		# v38：高级件音效挪到落地瞬间（原在 setup 期=悬空发声，音画错位）
		if tier >= 2:
			_play_drop_sfx()
		_start_idle_pulse()

	## 待机微光：本体 modulate 呼吸（廉价循环 tween，≤MAX_PERSIST 件可承受）
	func _start_idle_pulse() -> void:
		if _body == null or DT.is_motion_reduce():
			return
		var tw := create_tween().set_loops()
		tw.tween_property(_body, "modulate:a", 0.82, 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_body, "modulate:a", 1.0, 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	func _advance_ring(v: float) -> void:
		ring_t = v
		queue_redraw()

	func _draw() -> void:
		# v36：货币档地面柔光（实心圆呼吸，给"这里有东西可捡"的地面线索）
		if _glow_color.a > 0.01:
			var glow_r := lerpf(11.0, 15.0, ring_t)
			var glow_a := lerpf(0.05, 0.15, sin(ring_t * PI))
			draw_circle(Vector2(0, 3), glow_r,
				Color(_glow_color.r, _glow_color.g, _glow_color.b, glow_a))
			return
		if _ring_color.a <= 0.01:
			return
		var r := lerpf(13.0, 21.0, ring_t)
		var a := (1.0 - ring_t) * 0.55
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24,
			Color(_ring_color.r, _ring_color.g, _ring_color.b, a), 2.0)

	# ── 生命周期出口 ────────────────────────────────────────────────

	## 货币件（纳米）：落地驻留 delay 秒后自动收走并飘 +N
	func begin_quick_cycle(delay: float) -> void:
		get_tree().create_timer(delay).timeout.connect(_quick_collect)

	func _quick_collect() -> void:
		if collected or not is_inside_tree():
			return
		collected = true
		var layer := get_parent()
		if layer != null and layer.has_method("_notify_salvage"):
			layer._notify_salvage(1)
		var color := DT.COLOR_RES_NANO if ltype == GroundLootLayer.TYPE_NANO else DT.COLOR_RES_ENERGY
		show_gain_float("+%d" % int(amount), color)
		_vanish(0.22)

	## 并堆/收账时刷新数量飘字
	func show_gain_float(text: String, color: Color) -> void:
		var label: Node2D = CardGridFloatingLabelScript.new()
		label.position = Vector2(0, -20)
		label.z_index = FLOAT_LABEL_Z
		add_child(label)
		label.set_style(13, color, Color(0, 0, 0, 0.85), 3)
		label.set_text(text)
		if DT.is_motion_reduce():
			get_tree().create_timer(0.6).timeout.connect(label.queue_free)
			return
		var tw := label.create_tween()
		tw.tween_property(label, "position:y", -42.0, 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
		tw.tween_callback(label.queue_free)

	## 胜利收拢：延迟后上浮消散（stagger 由层控制）
	func collect_rise(delay: float, reduce: bool) -> void:
		if collected:
			return
		collected = true
		_kill_toss_tween()
		if reduce:
			_vanish(0.12)
			return
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(self, "position:y", position.y - 26.0, 0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.4)
		tw.parallel().tween_property(self, "scale", Vector2.ONE * 1.25, 0.4)
		tw.tween_callback(queue_free)

	## 静默收走（上限淘汰/败北清场）
	func collect_silent() -> void:
		if collected:
			return
		collected = true
		_kill_toss_tween()
		_vanish(0.3)

	## 抛掷未完即被收走时先杀 toss tween（否则两个 tween 同帧写 position 打架）
	func _kill_toss_tween() -> void:
		if _toss_tween != null and _toss_tween.is_valid():
			_toss_tween.kill()

	func _vanish(dur: float) -> void:
		_kill_toss_tween()
		if _fade_tween != null and _fade_tween.is_valid():
			return
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "scale", Vector2.ONE * 0.05, dur)
		_fade_tween.parallel().tween_property(self, "modulate:a", 0.0, dur)
		_fade_tween.tween_callback(queue_free)
