extends RefCounted
class_name VfxImpactFactory
## 命中特效分层化工厂（v8.1）
## 把原 spawn_impact_with_kind 的单一径向火花升级为三层组合特效：
##   第1层 冲击波环（Polygon2D 扩散淡出）
##   第2层 主火花（CPUParticles2D，按武器配方表差异化）
##   第3层 碎片/烟尘（重型武器专属，第二组粒子）
## 另提供特殊伤害专用特效：暴击光环 / 穿透光线 / 溅射冲击波 / 闪电链电弧
##
## 所有特效走对象池（参考 weapon_projectile_vfx 的 one_shot + SceneTreeTimer 回收模式）。
## 可访问性：DT.is_motion_reduce() 时只保留第2层主火花（减层）。

const DT = preload("res://resources/design_tokens.gd")

# ── 池化上限 ──
const MAX_RINGS: int = 80
const MAX_DEBRIS: int = 60
const MAX_SPARKS: int = 200
# v7.4 性能优化：ring 顶点预分配。原 _configure_ring_polygon 每帧 new PackedVector2Array + 48 append，
# 80 ring 激活时每帧 80×48 分配。改为每 ring 绑定预分配 buffer，每帧只原地改坐标（零堆分配）。
const _RING_SEGS: int = 24       # 圆环段数（外圈+内圈交错 = 48 顶点）
const _RING_VERTS: int = 48      # _RING_SEGS * 2

# ── 对象池 ──
static var _ring_pool: Array = []       # 可复用 Polygon2D（冲击波环）
static var _debris_pool: Array = []     # 可复用 CPUParticles2D（碎片/烟尘）
static var _spark_pool: Array = []      # 可复用 CPUParticles2D（主火花）
static var _active_rings: int = 0
static var _active_debris: int = 0
static var _active_sparks: int = 0

# v7.4: ring 顶点 buffer 缓存——ring(Polygon2D) -> Dictionary{_unit, _scratch}
# _unit: 预计算的单位圆坐标（半径=1，48 点），acquire 时算一次
# _scratch: 工作数组，每帧 = _unit × radius 原地缩放（零分配）
static var _ring_buffers: Dictionary = {}

# v7.4: Line2D 特效池（穿透光线/闪电链/激光余晖共用）。原每次 new Line2D + queue_free
static var _beam_pool: Array = []
static var _active_beams: int = 0
const MAX_BEAMS: int = 60

# ── ADD 混合材质缓存 ──
static var _add_mat: CanvasItemMaterial = null

## ======================================================================
## 主入口：分层化命中特效
## ======================================================================
## opts 可选字段：
##   "is_crit": bool     — 暴击（叠加金色脉动光环）
##   "is_pierce": bool   — 穿透（叠加紫色穿甲光线，需配合 direction）
##   "direction": Vector2 — 穿透光线方向（默认向右）
static func spawn_layered_impact(parent: Node2D, world_pos: Vector2, weapon_type: int, is_player: bool, combat_kind: int = -1, opts: Dictionary = {}) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var motion_reduce: bool = DT.is_motion_reduce()
	# 基色（复用 WeaponProjectileVfx 的配色逻辑）
	var base_color: Color = _impact_color(weapon_type, combat_kind, is_player)
	# 配方
	var recipe: Dictionary = _impact_recipe(weapon_type)
	# 第1层：冲击波环（motion_reduce 时跳过）
	if not motion_reduce:
		_spawn_ring(parent, world_pos, recipe.get("ring_r", 24.0), recipe.get("ring_dur", 0.2), base_color)
	# 第2层：主火花（始终生成）
	_spawn_sparks(parent, world_pos, recipe, base_color, weapon_type)
	# 第3层：碎片/烟尘（重型武器，motion_reduce 时跳过）
	if not motion_reduce and recipe.has("debris"):
		_spawn_debris(parent, world_pos, recipe["debris"], base_color, weapon_type)
	# 特殊伤害叠加
	if opts.get("is_crit", false) and not motion_reduce:
		spawn_crit_aura(parent, world_pos)
	if opts.get("is_pierce", false) and not motion_reduce:
		var dir: Variant = opts.get("direction", Vector2.RIGHT)
		spawn_pierce_beam(parent, world_pos, dir if dir is Vector2 else Vector2.RIGHT)


## ======================================================================
## 特殊伤害专用特效
## ======================================================================

## 暴击金色脉动光环（v8.2：加长到可清晰感知）
static func spawn_crit_aura(parent: Node2D, world_pos: Vector2) -> void:
	# 第一层：快速扩张大光环
	var ring1 := _acquire_ring()
	if ring1 == null:
		return
	ring1.position = world_pos
	_configure_ring_polygon(ring1, 8.0, Color(1.0, 0.88, 0.35, 1.0))  # 亮金
	parent.add_child(ring1)
	var target_r: float = 46.0
	var tween1 := ring1.create_tween()
	tween1.tween_method(func(r: float): _configure_ring_polygon(ring1, r, Color(1.0, 0.88, 0.35, 1.0 * (1.0 - r / target_r))), 8.0, target_r, 0.45)
	tween1.tween_callback(func(): _release_ring(ring1))
	# 第二层：延迟0.08s的二次脉冲（让暴击有"连击"的层次感）
	var ring2 := _acquire_ring()
	if ring2 == null:
		return
	ring2.position = world_pos
	_configure_ring_polygon(ring2, 6.0, Color(1.0, 0.7, 0.2, 0.7))
	parent.add_child(ring2)
	var tween2 := ring2.create_tween()
	tween2.tween_interval(0.08)
	tween2.tween_method(func(r: float): _configure_ring_polygon(ring2, r, Color(1.0, 0.7, 0.2, 0.7 * (1.0 - r / 34.0))), 6.0, 34.0, 0.40)
	tween2.tween_callback(func(): _release_ring(ring2))


## v7.4: 暴击辐射火花（复用 spark 池，替代 damage_number_display 每次 new CPUParticles2D+Gradient）。
## 参数对齐原 damage_number_display._spawn_crit_sparks 的配置。
static func spawn_crit_sparks(parent: Node2D, world_pos: Vector2, is_full_crit: bool) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if _active_sparks >= MAX_SPARKS:
		return
	_active_sparks += 1
	var p := _acquire_spark_particle()
	if p == null:
		_active_sparks -= 1
		return
	var intensity: float = 0.8 if is_full_crit else 0.5
	p.position = world_pos
	p.lifetime = 0.40
	p.amount = int(intensity * 14)
	p.emission_sphere_radius = 1.5
	p.direction = Vector2(0, 0)
	p.spread = 360.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	# 金色渐变（暴击配色）；固定 Gradient 可考虑缓存，但暴击频率远低于普通命中，暂不复用 _spark_ramp_cache
	var ramp := _get_crit_ramp()
	p.color_ramp = ramp
	parent.add_child(p)
	var tree := p.get_tree()
	if tree != null:
		var timer := tree.create_timer(p.lifetime + 0.1)
		timer.timeout.connect(func(): _release_spark_particle(p))


## v7.4: 炮口火焰（复用 spark 池，替代 bullet.gd 每次 new CPUParticles2D+Gradient）。
## 参数对齐原 bullet._spawn_muzzle_effect 的配置。
static func spawn_muzzle_flash(parent: Node2D, local_pos: Vector2, facing_right: bool) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if _active_sparks >= MAX_SPARKS:
		return
	_active_sparks += 1
	var p := _acquire_spark_particle()
	if p == null:
		_active_sparks -= 1
		return
	p.position = local_pos
	p.lifetime = 0.40
	p.amount = 12
	p.emission_sphere_radius = 3.0
	p.direction = Vector2(1, 0) if facing_right else Vector2(-1, 0)
	p.spread = 120.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 80.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.8
	p.color_ramp = _get_muzzle_ramp()
	parent.add_child(p)
	var tree := p.get_tree()
	if tree != null:
		var timer := tree.create_timer(p.lifetime + 0.1)
		timer.timeout.connect(func(): _release_spark_particle(p))


## v7.4: 固定 Gradient 缓存（暴击/炮口专用，避免每次 new Gradient）
static var _crit_ramp: Gradient = null
static var _muzzle_ramp: Gradient = null

static func _get_crit_ramp() -> Gradient:
	if _crit_ramp == null:
		_crit_ramp = Gradient.new()
		_crit_ramp.add_point(0, Color(1.0, 0.95, 0.5, 1.0))
		_crit_ramp.add_point(1.0, Color(1.0, 0.95, 0.5, 0.0))
	return _crit_ramp

static func _get_muzzle_ramp() -> Gradient:
	if _muzzle_ramp == null:
		_muzzle_ramp = Gradient.new()
		_muzzle_ramp.add_point(0, Color(1.0, 0.9, 0.4, 1.0))
		_muzzle_ramp.add_point(0.6, Color(1.0, 0.5, 0.1, 0.5))
		_muzzle_ramp.add_point(1.0, Color(1.0, 0.3, 0.0, 0.0))
	return _muzzle_ramp


## 穿透紫色穿甲光线（v8.2：加长淡出到可看清）。v7.4: 改用 beam 池
static func spawn_pierce_beam(parent: Node2D, world_pos: Vector2, direction: Vector2) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var beam := _acquire_beam()
	if beam == null:
		return
	beam.width = 5.0
	beam.default_color = Color(0.85, 0.55, 1.0, 1.0)  # 亮紫
	beam.joint_mode = Line2D.LINE_JOINT_ROUND
	beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	var d := direction.normalized()
	var start := world_pos - d * 16.0
	var end := world_pos + d * 60.0  # 加长
	beam.add_point(start)
	beam.add_point(end)
	beam.position = Vector2.ZERO
	parent.add_child(beam)
	var tween := beam.create_tween()
	# 先变细再淡出（模拟穿甲弹穿透后能量消散）
	tween.tween_property(beam, "width", 2.0, 0.15)
	tween.parallel().tween_property(beam, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func(): _release_beam(beam))


## 溅射冲击波环（v8.2：加长到可看清）
static func spawn_shockwave(parent: Node2D, world_pos: Vector2, radius: float, color: Color = Color(1.0, 0.6, 0.2, 0.8)) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var ring := _acquire_ring()
	if ring == null:
		return
	ring.position = world_pos
	_configure_ring_polygon(ring, 8.0, color)
	parent.add_child(ring)
	var tween := ring.create_tween()
	var col_closing: Color = Color(color.r, color.g, color.b, 0.0)
	tween.tween_method(func(r: float): _configure_ring_polygon(ring, r, color.lerp(col_closing, 1.0 - (radius - r) / maxf(radius - 8.0, 1.0) if r < radius else 1.0)), 8.0, radius, 0.40)
	tween.tween_callback(func(): _release_ring(ring))


## 闪电链电弧（锯齿线段，主目标→次目标）。v7.4: 改用 beam 池
static func spawn_lightning_arc(parent: Node2D, from_pos: Vector2, to_pos: Vector2, color: Color = Color(0.5, 0.7, 1.0, 1.0)) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var arc := _acquire_beam()
	if arc == null:
		return
	arc.width = 2.5
	arc.default_color = color
	arc.joint_mode = Line2D.LINE_JOINT_ROUND
	# 锯齿：在 from→to 之间插 4-5 个带 jitter 的点
	var segs := 5
	arc.add_point(from_pos)
	for i in range(1, segs):
		var t := float(i) / float(segs)
		var pt := from_pos.lerp(to_pos, t)
		# 垂直于方向偏移
		var perp := (to_pos - from_pos).normalized().rotated(PI / 2.0)
		var jitter := randf_range(-14.0, 14.0)
		pt += perp * jitter
		arc.add_point(pt)
	arc.add_point(to_pos)
	arc.position = Vector2.ZERO
	parent.add_child(arc)
	var tween := arc.create_tween()
	tween.tween_property(arc, "modulate:a", 0.0, 0.30)  # v8.2: 0.12→0.30，电弧原太短一闪即逝
	tween.tween_callback(func(): _release_beam(arc))


## ======================================================================
## 内部：三层特效生成
## ======================================================================

## v8.1: 激光命中光束余晖（v8.2：加长淡出到可看清）。v7.4: 改用 beam 池
static func spawn_laser_beam(parent: Node2D, from_pos: Vector2, to_pos: Vector2, color: Color = Color(0.3, 0.8, 1.0, 0.95)) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var beam := _acquire_beam()
	if beam == null:
		return
	beam.width = 7.0
	beam.default_color = color
	beam.joint_mode = Line2D.LINE_JOINT_ROUND
	beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	beam.add_point(from_pos)
	beam.add_point(to_pos)
	beam.position = Vector2.ZERO
	parent.add_child(beam)
	var tween := beam.create_tween()
	tween.tween_property(beam, "width", 2.0, 0.25)  # v8.2: 0.12→0.25 变细
	tween.parallel().tween_property(beam, "modulate:a", 0.0, 0.30)  # v8.2: 0.14→0.30 淡出
	tween.tween_callback(func(): _release_beam(beam))


## 冲击波环
static func _spawn_ring(parent: Node2D, pos: Vector2, target_r: float, duration: float, color: Color) -> void:
	var ring := _acquire_ring()
	if ring == null:
		return
	ring.position = pos
	_configure_ring_polygon(ring, 5.0, Color(color.r, color.g, color.b, 0.8))
	parent.add_child(ring)
	var tween := ring.create_tween()
	# 扩散同时 alpha 从 0.8 → 0
	var col_end := Color(color.r, color.g, color.b, 0.0)
	tween.tween_method(func(r: float): _configure_ring_polygon(ring, r, color.lerp(col_end, (r - 5.0) / maxf(target_r - 5.0, 1.0))), 5.0, target_r, duration)
	tween.tween_callback(func(): _release_ring(ring))


## 主火花（工厂自管池化粒子，按配方差异化）
static func _spawn_sparks(parent: Node2D, pos: Vector2, recipe: Dictionary, base_color: Color, weapon_type: int) -> void:
	if _active_sparks >= MAX_SPARKS:
		return
	_active_sparks += 1
	var p := _acquire_spark_particle()
	if p == null:
		_active_sparks -= 1
		return
	p.position = pos
	p.color = base_color
	# 按配方差异化参数
	p.amount = int(recipe.get("spark_amount", 18))
	p.initial_velocity_min = float(recipe.get("spark_vmin", 40.0))
	p.initial_velocity_max = float(recipe.get("spark_vmax", 120.0))
	p.scale_amount_min = float(recipe.get("spark_smin", 1.5))
	p.scale_amount_max = float(recipe.get("spark_smax", 3.0))
	p.lifetime = float(recipe.get("spark_life", 0.28))
	p.spread = float(recipe.get("spark_spread", 360.0))
	# 激光/能量类用线性方向（集中喷射感）
	if recipe.get("spark_dir", false):
		p.spread = float(recipe.get("spark_spread", 45.0))
	p.color_ramp = _get_spark_ramp(base_color)
	parent.add_child(p)
	var tree := p.get_tree()
	if tree != null:
		# +0.1s 余量：timer == lifetime 时最后一批发射的粒子刚到寿命终点即被 remove_child，
		# 帧率波动下会提前截断尾段
		var timer := tree.create_timer(p.lifetime + 0.1)
		timer.timeout.connect(func(): _release_spark_particle(p))


## 火花色带缓存（Gradient，按颜色键缓存）
static var _spark_ramp_cache: Dictionary = {}
static func _get_spark_ramp(base_color: Color) -> Gradient:
	var key := "%02x%02x%02x" % [int(base_color.r*255), int(base_color.g*255), int(base_color.b*255)]
	if _spark_ramp_cache.has(key):
		return _spark_ramp_cache[key]
	var g := Gradient.new()
	g.add_point(0, Color(1.0, 1.0, 1.0, 1.0))
	g.add_point(0.3, base_color)
	g.add_point(1.0, Color(base_color.r, base_color.g, base_color.b, 0.0))
	_spark_ramp_cache[key] = g
	return g


## 碎片/烟尘
static func _spawn_debris(parent: Node2D, pos: Vector2, debris_cfg: Dictionary, base_color: Color, weapon_type: int) -> void:
	if _active_debris >= MAX_DEBRIS:
		return
	_active_debris += 1
	var p := _acquire_debris_particle()
	if p == null:
		_active_debris -= 1
		return
	p.position = pos
	p.amount = int(debris_cfg.get("amount", 10))
	p.lifetime = float(debris_cfg.get("life", 0.5))
	p.initial_velocity_min = float(debris_cfg.get("vmin", 30.0))
	p.initial_velocity_max = float(debris_cfg.get("vmax", 90.0))
	p.scale_amount_min = float(debris_cfg.get("smin", 2.0))
	p.scale_amount_max = float(debris_cfg.get("smax", 4.0))
	# 烟尘向上、碎片有重力
	if bool(debris_cfg.get("is_smoke", false)):
		p.direction = Vector2(0, -1)  # 向上
		p.spread = 40.0
		p.gravity = Vector2(0, -8.0)  # 轻微上飘
		p.color = debris_cfg.get("smoke_color", Color(0.4, 0.35, 0.3, 0.6))
	else:
		p.direction = Vector2(0, 0)
		p.spread = 360.0
		p.gravity = Vector2(0, 200.0)  # 重力下落
		p.color = debris_cfg.get("debris_color", Color(0.6, 0.5, 0.4, 1.0))
	p.emitting = true
	parent.add_child(p)
	var tree := p.get_tree()
	if tree != null:
		# +0.1s 余量（同 _spawn_sparks，防尾段截断）
		var timer := tree.create_timer(p.lifetime + 0.1)
		timer.timeout.connect(func(): _release_debris_particle(p))


## ======================================================================
## 内部：配色 & 配方表
## ======================================================================

## 命中主色（提取自 WeaponProjectileVfx.IMPACT_COLOR_BY_WT + IMPACT_TINT_BY_KIND）
static func _impact_color(weapon_type: int, combat_kind: int, is_player: bool) -> Color:
	const COLOR_BY_WT: Dictionary = {
		0: Color(0.95, 0.92, 0.5, 1.0),   # DIRECT/SMG 黄白
		4: Color(0.95, 0.92, 0.5, 1.0),   # PISTOL
		5: Color(1.0, 0.7, 0.3, 1.0),     # SHOTGUN 橙
		6: Color(1.0, 0.95, 0.6, 1.0),    # SNIPER 亮黄
		3: Color(1.0, 0.55, 0.2, 1.0),    # ROCKET 橙红
		7: Color(1.0, 0.55, 0.2, 1.0),    # FLAK
		9: Color(1.0, 0.45, 0.15, 1.0),   # MISSILE 深橙
		1: Color(1.0, 0.5, 0.15, 1.0),    # INDIRECT 曲射爆炸
		2: Color(1.0, 0.4, 0.1, 1.0),     # AERIAL 空射导弹
		8: Color(0.3, 0.8, 1.0, 1.0),     # LASER 蓝
		10: Color(0.4, 0.6, 1.0, 1.0),    # OMEGA 能量蓝
		11: Color(0.5, 0.9, 1.0, 1.0),    # RAIL 电磁青
	}
	const TINT_BY_KIND: Dictionary = {
		0: Color(1.0, 0.95, 0.6),   # LIGHT 黄白火花
		2: Color(1.0, 0.95, 0.6),   # SUPPORT
		1: Color(1.0, 0.55, 0.25),  # ARMOR 橙红金属碎屑
		4: Color(1.0, 0.55, 0.25),  # FORT
		3: Color(1.0, 1.0, 1.0),    # AIR 保留原色
	}
	var base: Color = COLOR_BY_WT.get(weapon_type, Color(0.95, 0.92, 0.5))
	if combat_kind >= 0 and TINT_BY_KIND.has(combat_kind):
		base = TINT_BY_KIND[combat_kind]
	elif not is_player:
		base = Color(1.0, 0.45, 0.55)  # 敌方粉红
	return base


## 武器配方表（按 weapon_type 数值索引）
## 注：weapon_type=1 在 bullet 路径=INDIRECT(曲射)，在 batch 路径=RIFLE(直射)，
## 取折中"中火"配置（既不太像火炮也不太像步枪），不加剧既有歧义。
## v8.2: 整体加长寿命到"可清晰感知"区间（火花≥0.45s/环≥0.35s），保留武器间梯度。
static func _impact_recipe(weapon_type: int) -> Dictionary:
	match weapon_type:
		0, 4:  # DIRECT/SMG/PISTOL — 小环 + 密集小火花
			return {
				"ring_r": 24.0, "ring_dur": 0.32,
				"spark_amount": 18, "spark_vmin": 70.0, "spark_vmax": 170.0,
				"spark_smin": 1.5, "spark_smax": 2.8, "spark_life": 0.45, "spark_spread": 360.0,
			}
		6:  # SNIPER — 中环 + 高速集中喷射
			return {
				"ring_r": 32.0, "ring_dur": 0.36,
				"spark_amount": 22, "spark_vmin": 130.0, "spark_vmax": 240.0,
				"spark_smin": 1.8, "spark_smax": 3.2, "spark_life": 0.42, "spark_spread": 55.0,
				"spark_dir": true,
			}
		5:  # SHOTGUN — 宽散布
			return {
				"ring_r": 29.0, "ring_dur": 0.34,
				"spark_amount": 28, "spark_vmin": 60.0, "spark_vmax": 150.0,
				"spark_smin": 1.5, "spark_smax": 2.8, "spark_life": 0.42, "spark_spread": 360.0,
			}
		1:  # INDIRECT(曲射) / RIFLE(batch直射) — 中火折中
			return {
				"ring_r": 36.0, "ring_dur": 0.40,
				"spark_amount": 24, "spark_vmin": 70.0, "spark_vmax": 160.0,
				"spark_smin": 2.0, "spark_smax": 3.8, "spark_life": 0.50, "spark_spread": 360.0,
			}
		3:  # ROCKET — 大环 + 烟尘
			return {
				"ring_r": 56.0, "ring_dur": 0.52,
				"spark_amount": 32, "spark_vmin": 80.0, "spark_vmax": 200.0,
				"spark_smin": 3.0, "spark_smax": 6.0, "spark_life": 0.58, "spark_spread": 360.0,
				"debris": {"amount": 14, "life": 0.9, "vmin": 40.0, "vmax": 100.0, "smin": 3.0, "smax": 5.0, "is_smoke": true, "smoke_color": Color(0.4, 0.35, 0.3, 0.5)},
			}
		9, 2:  # MISSILE / AERIAL — 大环 + 碎片 + 烟柱
			return {
				"ring_r": 60.0, "ring_dur": 0.56,
				"spark_amount": 36, "spark_vmin": 90.0, "spark_vmax": 220.0,
				"spark_smin": 3.0, "spark_smax": 7.0, "spark_life": 0.62, "spark_spread": 360.0,
				"debris": {"amount": 16, "life": 1.0, "vmin": 50.0, "vmax": 120.0, "smin": 2.0, "smax": 4.0, "is_smoke": false, "debris_color": Color(0.5, 0.45, 0.4, 1.0)},
			}
		7:  # FLAK — 中大环 + 烟尘
			return {
				"ring_r": 46.0, "ring_dur": 0.44,
				"spark_amount": 28, "spark_vmin": 70.0, "spark_vmax": 170.0,
				"spark_smin": 2.5, "spark_smax": 5.0, "spark_life": 0.52, "spark_spread": 360.0,
				"debris": {"amount": 12, "life": 0.8, "vmin": 35.0, "vmax": 80.0, "smin": 3.0, "smax": 4.0, "is_smoke": true, "smoke_color": Color(0.45, 0.4, 0.35, 0.45)},
			}
		8:  # LASER — 细环 + 高速线状火花（能量武器灼烧感，仍比动能武器短，但已能看清）
			return {
				"ring_r": 22.0, "ring_dur": 0.24,
				"spark_amount": 22, "spark_vmin": 120.0, "spark_vmax": 260.0,
				"spark_smin": 1.2, "spark_smax": 2.2, "spark_life": 0.32, "spark_spread": 40.0,
				"spark_dir": true,
			}
		10, 11:  # OMEGA / RAIL — 快环 + 青色火花
			return {
				"ring_r": 34.0, "ring_dur": 0.36,
				"spark_amount": 24, "spark_vmin": 70.0, "spark_vmax": 170.0,
				"spark_smin": 2.0, "spark_smax": 4.5, "spark_life": 0.48, "spark_spread": 360.0,
			}
		_:
			return {
				"ring_r": 28.0, "ring_dur": 0.34,
				"spark_amount": 20, "spark_vmin": 60.0, "spark_vmax": 150.0,
				"spark_smin": 1.8, "spark_smax": 3.2, "spark_life": 0.46, "spark_spread": 360.0,
			}


## ======================================================================
## 内部：对象池
## ======================================================================

static func _get_add_mat() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat


## 冲击波环（Polygon2D）池
static func _acquire_ring() -> Polygon2D:
	var i := _ring_pool.size() - 1
	while i >= 0:
		var candidate = _ring_pool[i]
		_ring_pool.remove_at(i)
		if candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			_active_rings += 1
			candidate.visible = true
			candidate.modulate.a = 1.0
			_ensure_ring_buffer(candidate)  # v7.4: 防御性确保 buffer 存在
			return candidate
		else:
			# 失效节点，清理其 buffer 缓存
			_ring_buffers.erase(candidate)
		i -= 1
	if _active_rings >= MAX_RINGS:
		return null
	_active_rings += 1
	var ring := Polygon2D.new()
	ring.material = _get_add_mat()
	_ensure_ring_buffer(ring)  # v7.4: 新建 ring 时预分配顶点 buffer
	return ring


## v7.4: 为 ring 创建/确保预分配顶点 buffer（单位圆坐标 + 工作数组）。
## 单位圆坐标按原 _configure_ring_polygon 的内外圈交错布局预计算，每帧只需 × radius 缩放。
static func _ensure_ring_buffer(ring: Polygon2D) -> void:
	if _ring_buffers.has(ring):
		return
	var unit_pts := PackedVector2Array()
	unit_pts.resize(_RING_VERTS)
	for i in range(_RING_SEGS):
		var a := (float(i) / float(_RING_SEGS)) * TAU
		var outer := Vector2(cos(a), sin(a))
		var inner := Vector2(cos(a + PI / _RING_SEGS), sin(a + PI / _RING_SEGS))
		unit_pts[i * 2] = outer       # 外圈点（radius 缩放）
		unit_pts[i * 2 + 1] = inner   # 内圈点（radius-3 缩放，configure 时动态算）
	var scratch := PackedVector2Array()
	scratch.resize(_RING_VERTS)
	_ring_buffers[ring] = {"unit": unit_pts, "scratch": scratch}


static func _release_ring(ring: Polygon2D) -> void:
	if ring == null or not is_instance_valid(ring):
		_active_rings -= 1
		_ring_buffers.erase(ring)  # v7.4: 清理失效 buffer 缓存
		return
	if ring.is_inside_tree() and ring.get_parent():
		ring.get_parent().remove_child(ring)
	ring.visible = false
	_active_rings -= 1
	if _ring_pool.size() < MAX_RINGS:
		_ring_pool.append(ring)  # buffer 保留，下次 acquire 复用
	else:
		_ring_buffers.erase(ring)  # v7.4: 即将 free，清理 buffer 缓存
		ring.queue_free()


## v7.4: 配置 Polygon2D 为给定半径的圆环（空心，24段）。
## 原实现每次 new PackedVector2Array + 48 append（每帧每 ring 一次 = 热点 GC 源）。
## 现从预分配 buffer 取数组，原地 × radius 缩放（零堆分配），最后整体赋值给 polygon。
static func _configure_ring_polygon(ring: Polygon2D, radius: float, color: Color) -> void:
	var buf: Dictionary = _ring_buffers.get(ring, {})
	if buf.is_empty():
		_ensure_ring_buffer(ring)
		buf = _ring_buffers[ring]
	var unit_pts: PackedVector2Array = buf["unit"]
	var scratch: PackedVector2Array = buf["scratch"]
	var inner := maxf(radius - 3.0, 1.0)
	for i in range(_RING_VERTS):
		if i % 2 == 0:
			scratch[i] = unit_pts[i] * radius    # 外圈
		else:
			scratch[i] = unit_pts[i] * inner     # 内圈
	ring.polygon = scratch  # 引擎侧拷贝无法避免，但 GDScript 侧零分配
	ring.color = color


## v7.4: Line2D 特效池（穿透光线/闪电链/激光余晖共用）
static func _acquire_beam() -> Line2D:
	var i := _beam_pool.size() - 1
	while i >= 0:
		var candidate = _beam_pool[i]
		_beam_pool.remove_at(i)
		if candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			_active_beams += 1
			candidate.visible = true
			candidate.modulate.a = 1.0
			candidate.clear_points()  # 清空旧点（复用时重设）
			return candidate
		i -= 1
	if _active_beams >= MAX_BEAMS:
		return null
	_active_beams += 1
	var beam := Line2D.new()
	beam.material = _get_add_mat()
	return beam


static func _release_beam(beam: Line2D) -> void:
	if beam == null or not is_instance_valid(beam):
		_active_beams -= 1
		return
	if beam.is_inside_tree() and beam.get_parent():
		beam.get_parent().remove_child(beam)
	beam.visible = false
	beam.clear_points()
	_active_beams -= 1
	if _beam_pool.size() < MAX_BEAMS:
		_beam_pool.append(beam)
	else:
		beam.queue_free()


## 碎片/烟尘（CPUParticles2D）池
static func _acquire_debris_particle() -> CPUParticles2D:
	var i := _debris_pool.size() - 1
	while i >= 0:
		var candidate = _debris_pool[i]
		_debris_pool.remove_at(i)
		if candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			candidate.visible = true
			candidate.emitting = true
			candidate.restart()
			return candidate
		i -= 1
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 4.0
	p.material = _get_add_mat()
	return p


static func _release_debris_particle(p: CPUParticles2D) -> void:
	if p == null or not is_instance_valid(p):
		_active_debris -= 1
		return
	if p.is_inside_tree() and p.get_parent():
		p.get_parent().remove_child(p)
	p.emitting = false
	p.visible = false
	p.position = Vector2.ZERO
	_active_debris -= 1
	if _debris_pool.size() < MAX_DEBRIS:
		_debris_pool.append(p)
	else:
		p.queue_free()


## 主火花（CPUParticles2D）池
static func _acquire_spark_particle() -> CPUParticles2D:
	var i := _spark_pool.size() - 1
	while i >= 0:
		var candidate = _spark_pool[i]
		_spark_pool.remove_at(i)
		if candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			candidate.visible = true
			candidate.emitting = true
			candidate.restart()
			return candidate
		i -= 1
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.28
	p.amount = 18
	p.gravity = Vector2(0, 0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 2.0
	p.direction = Vector2(0, 0)
	p.spread = 360.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 120.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(1.0, 0.95, 0.6, 1.0)
	p.material = _get_add_mat()
	p.emitting = true
	return p


static func _release_spark_particle(p: CPUParticles2D) -> void:
	if p == null or not is_instance_valid(p):
		_active_sparks -= 1
		return
	if p.is_inside_tree() and p.get_parent():
		p.get_parent().remove_child(p)
	p.emitting = false
	p.visible = false
	p.position = Vector2.ZERO
	_active_sparks -= 1
	if _spark_pool.size() < MAX_SPARKS:
		_spark_pool.append(p)
	else:
		p.queue_free()
