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
const DirectWeaponFlavor = preload("res://data/direct_weapon_flavor.gd")
## v9.2: 粒子贴图——CPUParticles2D 赋 texture 告别方形小方块。
## 按武器类型分流：动能武器（金属火花/灰烟）vs 能量武器（蓝色电弧/蓝烟）。
## 池复用继续（性能优先），texture 在 spawn 时按 weapon_type 重新赋值。
## 生成工作流：docs/VFX特效纹理生成工作流.md。
const PARTICLE_TEX_SPARK_METAL := preload("res://assets/effects/particle_textures/spark_metal.png")     # 动能火花（黄橙短条，DIRECT/PISTOL/SMG/MG/RIFLE/SHOTGUN/SNIPER）
const PARTICLE_TEX_SPARK_ENERGY := preload("res://assets/effects/particle_textures/spark_energy.png")   # 能量火花（蓝白电弧，OMEGA/RAIL/LASER）
const PARTICLE_TEX_SPARK_HEAVY  := preload("res://assets/effects/particle_textures/spark_heavy.png")    # 重型碎片（不规则金属块，ROCKET/FLAK/MISSILE）
const PARTICLE_TEX_SMOKE_GENERIC := preload("res://assets/effects/particle_textures/smoke_generic.png") # 常规烟尘（灰棕团，ROCKET/FLAK/MISSILE）
const PARTICLE_TEX_SMOKE_ENERGY  := preload("res://assets/effects/particle_textures/smoke_energy.png")   # 能量烟（蓝灰团，OMEGA/RAIL/LASER）
const PARTICLE_TEX_MUZZLE_HEAVY  := preload("res://assets/effects/particle_textures/muzzle_heavy.png")  # 重型枪口火（橙红喷射，ROCKET/FLAK/MISSILE/OMEGA/RAIL）
const PARTICLE_TEX_MUZZLE_LIGHT  := preload("res://assets/effects/particle_textures/muzzle_light.png")  # 轻型枪口火（橙点，DIRECT/PISTOL/RIFLE）
const PARTICLE_TEX_EMBER         := preload("res://assets/effects/particle_textures/spark_ember.png")    # 火星点缀（橙色小点）
## v9.2: 放射状命中贴图——区别于拖尾的顺向条纹，命中用放射爆点（"飞行"vs"撞击"形状可分）
const PARTICLE_TEX_IMPACT_METAL  := preload("res://assets/effects/particle_textures/impact_metal.png")   # 动能命中放射火花
const PARTICLE_TEX_IMPACT_ENERGY := preload("res://assets/effects/particle_textures/impact_energy.png") # 能量命中放射爆裂

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

# v8.4: 命中贴图 Sprite 池（重型爆炸武器的 *_impact.png 渲染）。原 v8.0 移除贴图改纯粒子，
# 现重接贴图让爆炸有"形状感"——仅 weapon_projectile_vfx 在有 impact_texture 时调用。
static var _impact_sprite_pool: Array = []
static var _active_impact_sprites: int = 0
const MAX_IMPACT_SPRITES: int = 160  # v9.2: 80→160（双层贴图：光晕+主体，每次爆炸/开火用 2 个）

# v9.x: 组合技指示器池（weakpoint_expose / radar_lock / laser_resonance）。
# 原每次 new Node2D/Polygon2D + queue_free，违背文件"所有特效走对象池"原则。
# resonance 每次命中触发（高频）、radar 周期性 tick、持续 5-6s，密集战斗累积节点。
# 池按 kind 分组（weakpoint=Node2D+2Line2D子 / radar_lock=Polygon2D / resonance=Polygon2D）。
# 每个指示器有 2 个 tween（脉动 loops + 延迟淡出），release 时通过 _vfx_tweens meta 全部 kill。
static var _indicator_pool: Dictionary = {}  # kind -> Array[Node]
static var _active_indicators: int = 0
const MAX_INDICATORS: int = 40  # weakpoint 3s / radar 6s / resonance 5s，并发量可控
const _INDICATOR_KINDS: Array = ["weakpoint", "radar_lock", "resonance"]

# ── ADD 混合材质缓存 ──
static var _add_mat: CanvasItemMaterial = null

# ── v9.2: 烟柱 Gradient 按颜色缓存（spawn_smoke_column 频繁调用）──
static var _smoke_grad_cache: Dictionary = {}

## ======================================================================
## 主入口：分层化命中特效
## ======================================================================
## opts 可选字段：
##   "is_crit": bool     — 暴击（叠加金色脉动光环）
##   "is_pierce": bool   — 穿透（叠加紫色穿甲光线，需配合 direction）
##   "direction": Vector2 — 穿透光线方向（默认向右）
## [param p_weapon_name] 武器名（v8.x：直射系亚类分流用，区分机枪/步枪/坦克炮等）
static func spawn_layered_impact(parent: Node2D, world_pos: Vector2, weapon_type: int, is_player: bool, combat_kind: int = -1, opts: Dictionary = {}, p_weapon_name: String = "") -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var motion_reduce: bool = DT.is_motion_reduce()
	# 基色（复用 WeaponProjectileVfx 的配色逻辑）
	var base_color: Color = _impact_color(weapon_type, combat_kind, is_player)
	# 配方（v8.x：传 weapon_name 做直射系亚类细分）
	var recipe: Dictionary = _impact_recipe(weapon_type, p_weapon_name)
	# v9.4: power_tier 威力分级缩放——HEAVY 档放大粒子层（环半径/火花数/尺寸 ×1.4），
	# LIGHT/MEDIUM ×1.0 不变。配方表本身不动（保持 weapon_type+flavor 分级），tier 只做倍率叠加。
	recipe = _apply_tier_scale(recipe, opts)
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
		# v9.4: piercing_shot 技能穿透走 enhanced 加宽加长版（opts 透传标记）
		var enhanced: bool = bool(opts.get("pierce_enhanced", false))
		spawn_pierce_beam(parent, world_pos, dir if dir is Vector2 else Vector2.RIGHT, Color(0.85, 0.55, 1.0, 1.0), enhanced)


## v9.4: 按 power_tier 缩放命中配方参数（让重型武器命中粒子更猛烈）。
## HEAVY(2) 档：ring_r/spark_amount/spark 尺寸 ×1.4；LIGHT(0)/MEDIUM(1) ×1.0 不变。
## 用字面量 tier 值（0/1/2/3）避免对 WeaponProjectileVfx 的循环依赖。
## 返回缩放后的 recipe 副本（原配方表不被污染）。
static func _apply_tier_scale(recipe: Dictionary, opts: Dictionary) -> Dictionary:
	var tier: int = int(opts.get("power_tier", -1))
	if tier != 2:  # 仅 HEAVY(2) 缩放；其他档（含缺省 -1/0/1）不缩放，向后兼容
		return recipe
	const SCALE := 1.4
	var r: Dictionary = recipe.duplicate(true)
	r["ring_r"] = float(r.get("ring_r", 24.0)) * SCALE
	r["spark_amount"] = int(round(float(r.get("spark_amount", 16)) * SCALE))
	r["spark_smin"] = float(r.get("spark_smin", 2.0)) * SCALE
	r["spark_smax"] = float(r.get("spark_smax", 3.0)) * SCALE
	# 碎片层（如有）也放大粒子数
	if r.has("debris"):
		var d: Dictionary = r["debris"]
		d["amount"] = int(round(float(d.get("amount", 16)) * SCALE))
	return r


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
	# v9.2: 暴击火花用金属火花贴图（池复用需显式赋值，否则继承上次的 texture）
	p.texture = PARTICLE_TEX_SPARK_METAL
	var intensity: float = 0.8 if is_full_crit else 0.5
	p.position = world_pos
	p.lifetime = 0.40
	p.amount = int(intensity * 14)
	p.emission_sphere_radius = 1.5
	p.direction = Vector2(0, 0)
	p.spread = 360.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0
	# v9.2: 暴击火花贴图化缩小（原 0.6-1.2 → 0.3-0.5）
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.5
	# 金色渐变（暴击配色）；固定 Gradient 可考虑缓存，但暴击频率远低于普通命中，暂不复用 _spark_ramp_cache
	var ramp := _get_crit_ramp()
	p.color_ramp = ramp
	parent.add_child(p)
	var tree := p.get_tree()
	if tree != null:
		var timer := tree.create_timer(p.lifetime + 0.1)
		_connect_deferred_release(timer, p, _release_spark_particle)


## v8.x: 单位受击血溅（复用 debris 池）。替代 v7.4 受击"整体变色虚化"——单位保持卡图清晰，
## 打击感外化到命中点：暗红血溅（沿弹道反向飞溅+重力下落）+ 叠加少量金色火花（BLEND_ADD 一闪）。
## direction：弹道反方向（attacker→unit 反向），强度越大粒子越多越远。
static var _spark_blood_ramp: Gradient = null
static func spawn_hit_blood(parent: Node2D, world_pos: Vector2, direction: Vector2, strength: float, is_player: bool) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if DT.is_motion_reduce():
		return
	# 第1层：暗红血溅（debris 池，重力下落）
	if _active_debris < MAX_DEBRIS:
		_active_debris += 1
		var p := _acquire_debris_particle()
		if p == null:
			_active_debris -= 1
		else:
			# v9.2: 血溅用常规烟尘贴图（池复用需显式赋值，否则继承上次的 texture）
			p.texture = PARTICLE_TEX_SMOKE_GENERIC
			# 我方/敌方血色微差（我方亮红、敌方暗红），均不饱和以免糊图
			var d: Vector2 = direction.normalized() if direction.length() > 0.01 else Vector2.ZERO
			p.position = world_pos
			p.lifetime = 0.42
			# 强度 → 数量（直射 strength=3→8 粒子；爆炸 6→14；暴击 10→20）
			var n: int = int(clamp(strength * 2.5, 6.0, 20.0))
			p.amount = n
			p.emission_sphere_radius = 3.0
			p.direction = d
			p.spread = 70.0
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 150.0
			p.gravity = Vector2(0, 220.0)
			# v9.2: 血溅贴图化缩小（原 1.6-3.0 → 0.6-1.2）
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.2
			p.color_ramp = _get_blood_ramp(is_player)
			# 注：debris 池默认带 ADD material（_acquire_debris_particle 新建时设）。
			# 不在此覆盖 material=null——会污染池（复用时其他 debris 特效失去 ADD）。
			# 血溅走 ADD 偏亮（暗红→粉红血雾高光），与火花层视觉协调，且零池污染风险。
			parent.add_child(p)
			var tree := p.get_tree()
			if tree != null:
				var timer := tree.create_timer(p.lifetime + 0.1)
				_connect_deferred_release(timer, p, _release_debris_particle)
	# 第2层：金色火花（spark 池，ADD 一闪即逝）—— 承担"打击感高光"
	if _active_sparks < MAX_SPARKS:
		_active_sparks += 1
		var sp := _acquire_spark_particle()
		if sp == null:
			_active_sparks -= 1
		else:
			# v9.2/v9.4: 血溅金色火花——v9.4 改用圆点亮斑（MUZZLE_LIGHT 橙点），弃用长条 SPARK_METAL
			# （长条贴图 + 高速会拉成长条火星，FORT 持续承伤时脚下堆积成杂乱长条带）。
			# 同时降低速度（200→110）避免圆点也被拉长，保持"一闪即逝高光"语义。
			sp.texture = PARTICLE_TEX_MUZZLE_LIGHT
			var d: Vector2 = direction.normalized() if direction.length() > 0.01 else Vector2.ZERO
			sp.position = world_pos
			sp.lifetime = 0.16
			sp.amount = int(clamp(strength * 1.2, 4.0, 12.0))
			sp.emission_sphere_radius = 2.0
			sp.direction = d
			sp.spread = 90.0
			sp.initial_velocity_min = 50.0
			sp.initial_velocity_max = 110.0
			sp.gravity = Vector2(0, 0)
			# v9.2: 血溅金色火花贴图化缩小
			sp.scale_amount_min = 0.4
			sp.scale_amount_max = 0.7
			sp.color_ramp = _get_blood_spark_ramp()
			parent.add_child(sp)
			var tree2 := sp.get_tree()
			if tree2 != null:
				var timer2 := tree2.create_timer(sp.lifetime + 0.1)
				_connect_deferred_release(timer2, sp, _release_spark_particle)


## 单位死亡反馈：阵营色冲击波 + 碎片/血雾爆散（复用 debris 池，0.45s 重力下落）。
## 在单位 _play_death_fadeout 开头调用一次，让"死亡"与"受击"产生明确的视觉差。
## 走对象池 + motion_reduce 短路，零额外 GC。
static func spawn_death_burst(parent: Node2D, world_pos: Vector2, is_player: bool) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if DT.is_motion_reduce():
		return
	# 阵营色：我方青蓝、敌方暗红（与 hit_blood 配色一致，避免饱和糊图）
	var faction_c: Color = Color(0.35, 0.7, 1.0, 0.85) if is_player else Color(0.9, 0.35, 0.2, 0.85)
	# 第1层：阵营色小冲击波（半径 8→32，0.38s 扩散淡出）
	spawn_shockwave(parent, world_pos, 32.0, faction_c)
	# 第2层：碎片/血雾爆散（debris 池，向上+四周迸射后重力下落）
	if _active_debris < MAX_DEBRIS:
		_active_debris += 1
		var p := _acquire_debris_particle()
		if p == null:
			_active_debris -= 1
		else:
			# v9.2: 死亡爆散用常规烟尘贴图（池复用需显式赋值）
			p.texture = PARTICLE_TEX_SMOKE_GENERIC
			p.position = world_pos
			p.lifetime = 0.45
			p.amount = 10  # 克制：10 粒碎片，足够形成"散开"感而不撞池上限
			p.emission_sphere_radius = 4.0
			p.direction = Vector2(0, -1)  # 略微向上的爆散方向
			p.spread = 110.0
			p.initial_velocity_min = 80.0
			p.initial_velocity_max = 180.0
			p.gravity = Vector2(0, 240.0)
			# v9.2: 死亡爆散贴图化缩小
			p.scale_amount_min = 0.7
			p.scale_amount_max = 1.3
			p.color_ramp = _get_blood_ramp(is_player)
			parent.add_child(p)
			var tree := p.get_tree()
			if tree != null:
				var timer := tree.create_timer(p.lifetime + 0.1)
				_connect_deferred_release(timer, p, _release_debris_particle)


## v8.x: 血溅 Gradient 缓存（敌我各一份，alpha 1.0→0.0 渐隐）
static var _blood_ramp_player: Gradient = null
static var _blood_ramp_enemy: Gradient = null
static func _get_blood_ramp(is_player: bool) -> Gradient:
	var target := _blood_ramp_player if is_player else _blood_ramp_enemy
	if target != null:
		return target
	var base_c: Color = Color(0.82, 0.18, 0.12) if is_player else Color(0.62, 0.10, 0.07)
	var g := Gradient.new()
	g.add_point(0, Color(base_c.r, base_c.g, base_c.b, 1.0))
	g.add_point(1.0, Color(base_c.r, base_c.g, base_c.b, 0.0))
	if is_player:
		_blood_ramp_player = g
	else:
		_blood_ramp_enemy = g
	return g


static func _get_blood_spark_ramp() -> Gradient:
	if _spark_blood_ramp == null:
		_spark_blood_ramp = Gradient.new()
		_spark_blood_ramp.add_point(0, Color(1.0, 0.85, 0.4, 1.0))
		_spark_blood_ramp.add_point(1.0, Color(1.0, 0.55, 0.15, 0.0))
	return _spark_blood_ramp


## v7.4: 炮口火焰（复用 spark 池，替代 bullet.gd 每次 new CPUParticles2D+Gradient）。
## 参数对齐原 bullet._spawn_muzzle_effect 的配置。
static func spawn_muzzle_flash(parent: Node2D, local_pos: Vector2, facing_right: bool, weapon_type: int = 0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if _active_sparks >= MAX_SPARKS:
		return
	_active_sparks += 1
	var p := _acquire_spark_particle()
	if p == null:
		_active_sparks -= 1
		return
	# v9.2: 枪口火按武器类型分流贴图
	if weapon_type in [3, 7, 9, 10, 11]:  # 重型/能量武器
		p.texture = PARTICLE_TEX_MUZZLE_HEAVY
	else:  # 轻型动能武器
		p.texture = PARTICLE_TEX_MUZZLE_LIGHT
	p.position = local_pos
	p.lifetime = 0.40
	# v8.3 视觉增强：炮口火焰 amount 12→20, spread 120→150, velocity 翻倍, scale 加大
	# v9.4: 轻武器枪口火粒子减半（20→10）——轻武器密集齐射是粒子滥用主源；
	# 重型/能量武器保持 20（开火稀疏，大枪口火有冲击感）。
	p.amount = 10 if weapon_type in [0, 1, 2, 4, 5, 6] else 20
	p.emission_sphere_radius = 4.0
	p.direction = Vector2(1, 0) if facing_right else Vector2(-1, 0)
	p.spread = 150.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 140.0
	# v9.2: 枪口火贴图化后 scale 需缩小（32/64px 贴图 × scale）。
	# 原 1.5-2.5 → 0.5-0.9，显示 16-57px（紧凑枪口火，不盖住单位）
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.9
	p.color_ramp = _get_muzzle_ramp()
	parent.add_child(p)
	var tree := p.get_tree()
	if tree != null:
		var timer := tree.create_timer(p.lifetime + 0.1)
		_connect_deferred_release(timer, p, _release_spark_particle)


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
## color: 光线颜色（默认亮紫，给 piercing_shot 相位仪/敌方大招传专属配色）
## enhanced: v9.4 增强——加宽加长加余晖，给 piercing_shot 技能穿透(玩家)/single_target(敌方) 用，
##   让"技能级穿透"区别于"普通穿甲"（宽 5→8，长 60→100，淡出 0.35→0.45）。
## length_scale: 长度倍率（默认1.0=60px；敌方 single_target 传更大值让下劈激光更长）
static func spawn_pierce_beam(parent: Node2D, world_pos: Vector2, direction: Vector2, color: Color = Color(0.85, 0.55, 1.0, 1.0), enhanced: bool = false, length_scale: float = 1.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var beam := _acquire_beam()
	if beam == null:
		return
	var base_width: float = 8.0 if enhanced else 5.0
	beam.width = base_width
	beam.default_color = color
	beam.joint_mode = Line2D.LINE_JOINT_ROUND
	beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	var d := direction.normalized()
	var tail_off: float = 16.0
	var head_off: float = 60.0 * length_scale * (1.6 if enhanced else 1.0)  # 增强版加长
	var start := world_pos - d * tail_off
	var end := world_pos + d * head_off  # 加长
	beam.add_point(start)
	beam.add_point(end)
	beam.position = Vector2.ZERO
	parent.add_child(beam)
	var tween := beam.create_tween()
	# 先变细再淡出（模拟穿甲弹穿透后能量消散）；增强版余晖更长
	var fade_t: float = 0.45 if enhanced else 0.35
	tween.tween_property(beam, "width", 2.0, 0.15)
	tween.parallel().tween_property(beam, "modulate:a", 0.0, fade_t)
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


## v8.4: 命中贴图爆炸（重型爆炸武器专属）。
## 在 world_pos 处用 Sprite2D 渲染 *_impact.png 贴图，快速放大→缓慢淡出，让爆炸有"形状感"。
## 与 spawn_layered_impact 配合使用：贴图层 + 粒子层叠加（先贴图后粒子）。
## v9.2: ADD 发光混合（爆炸火光感）+ 两层叠加（外层光晕 + 内层主体），真实感对标核武 fireball。
## life: 总生命周期秒（默认 0.45）；scale_peak: 峰值缩放（默认 1.0，调用方按贴图基准像素调整）
static func spawn_impact_sprite(parent: Node2D, world_pos: Vector2, texture: Texture2D, scale_peak: float = 1.0, life: float = 0.45) -> void:
	if parent == null or not is_instance_valid(parent) or texture == null:
		return
	if DT.is_motion_reduce():
		return  # 减动效：跳过贴图层，粒子层已足够
	# v9.2: 第1层——外层光晕（ADD 混合，大尺度低 alpha，模拟爆炸整体火光弥散）
	var glow := _acquire_impact_sprite()
	if glow != null:
		glow.texture = texture
		glow.position = world_pos
		glow.scale = Vector2(scale_peak * 1.4, scale_peak * 1.4)
		glow.modulate = Color(1.0, 0.85, 0.6, 0.5)  # 暖白光晕
		glow.visible = true
		glow.material = _get_add_mat()  # ADD 混合让光晕发亮
		parent.add_child(glow)
		glow.add_to_group("battle_vfx")  # v9.4: 战斗结束兜底清理（tween 中断时不残留）
		var tw_glow := glow.create_tween()
		tw_glow.tween_property(glow, "scale", Vector2(scale_peak * 1.8, scale_peak * 1.8), life * 0.5).set_ease(Tween.EASE_OUT)
		tw_glow.parallel().tween_property(glow, "modulate:a", 0.0, life * 0.8).set_ease(Tween.EASE_IN)
		tw_glow.tween_callback(func(): _release_impact_sprite(glow))
	# v9.2: 第2层——主体火球（ADD 混合，快速膨胀→淡出，模拟火球爆炸消散）
	var sprite := _acquire_impact_sprite()
	if sprite == null:
		return  # 池满，静默丢弃（节流）
	sprite.texture = texture
	sprite.position = world_pos
	sprite.scale = Vector2(scale_peak * 0.5, scale_peak * 0.5)  # 起始小
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	sprite.visible = true
	sprite.material = _get_add_mat()  # v9.2: ADD 混合让爆炸有火光明亮感
	parent.add_child(sprite)
	sprite.add_to_group("battle_vfx")  # v9.4: 战斗结束兜底清理（tween 中断时不残留）
	# 快速膨胀到峰值 → 缓慢淡出（模拟爆炸火球膨胀消散）
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "scale", Vector2(scale_peak, scale_peak), life * 0.3).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _release_impact_sprite(sprite))


## v9.3c: 大招专属贴图爆炸（敌我双方大招命中演出，对齐核子轰炸表现力）。
## 与 spawn_impact_sprite 的区别：
##   ① 配色染色（tint 参数 lerp 贴图原色，让每类大招有专属色调）
##   ② 前置预警环（命中前 0.15s 收缩环，给玩家反应时间）
##   ③ 更长寿命（大招级 0.8s，普通命中 0.45s）+ 更大尺度
##   ④ 三层叠加（外光晕 + 主体 + 底环），层次更丰富
## 用于敌方 boss active_spells + 我方相位仪 active_ability 的命中瞬间。
## tint: 染色色（如紫色给虚空、橙红给火焰、蓝白给闪电）；Color.WHITE = 不染色保留贴图原色。
## target_width: 主体贴图峰值显示宽度（像素，如护盾 260 / 大招 360）。按贴图分辨率反算 scale，
##   避免 1024px 贴图被当绝对乘数导致溢屏（与 spawn_rising_sprite:737/spawn_ground_burn:687 同范式）。
static func spawn_spell_burst(parent: Node2D, world_pos: Vector2, texture: Texture2D, tint: Color = Color.WHITE, target_width: float = 320.0, life: float = 0.8) -> void:
	if parent == null or not is_instance_valid(parent) or texture == null:
		return
	if DT.is_motion_reduce():
		return
	# 按贴图分辨率反算 scale（target_width 是显示像素，不是贴图像素乘数）
	var tex_w: float = float(texture.get_width())
	var peak_scale: float = target_width / tex_w if tex_w > 0.0 else 1.0
	# 染色色（lerp 贴图原色→tint，0.5 混合保留贴图细节又带专属色调）
	var body_tint: Color = tint if tint == Color.WHITE else Color(tint.r, tint.g, tint.b, 1.0)
	var glow_tint: Color = Color(tint.r, tint.g, tint.b, 0.5) if tint != Color.WHITE else Color(1.0, 0.85, 0.6, 0.5)
	# 前置预警环（0→0.15s 收缩，提示命中位置）——半径跟随 target_width 同比例缩放，大爆炸预警也大
	var warn_r: float = target_width * 0.3  # 预警环半径=目标宽度的30%（护盾78/大招108）
	var warn_ring := _acquire_ring()
	if warn_ring != null:
		warn_ring.position = world_pos
		_configure_ring_polygon(warn_ring, warn_r, Color(body_tint.r, body_tint.g, body_tint.b, 0.7))
		parent.add_child(warn_ring)
		var captured_warn: Polygon2D = warn_ring
		var captured_wtint: Color = body_tint
		var captured_warn_r: float = warn_r
		var tw_warn := warn_ring.create_tween()
		tw_warn.tween_method(func(r: float): _configure_ring_polygon(captured_warn, r, Color(captured_wtint.r, captured_wtint.g, captured_wtint.b, 0.7 * (r / captured_warn_r if captured_warn_r > 0.0 else 0.0))), warn_r, warn_r * 0.33, 0.15)
		tw_warn.tween_callback(func(): _release_ring(captured_warn))
	# 延迟 0.15s 后贴图爆炸（与预警环同步）
	var weak_parent: WeakRef = weakref(parent)
	var captured_pos: Vector2 = world_pos
	var captured_tex: Texture2D = texture
	var captured_body: Color = body_tint
	var captured_glow: Color = glow_tint
	var captured_scale: float = peak_scale
	# 底环半径也跟随 target_width（护盾260→底环130，大招360→底环180）
	var captured_ring_r: float = target_width * 0.5
	var tw_delay := parent.create_tween()
	tw_delay.tween_interval(0.15)
	tw_delay.tween_callback(func():
		var p: Node2D = weak_parent.get_ref() as Node2D
		if p == null or not is_instance_valid(p):
			return
		# 第1层：外光晕（ADD，大尺度低 alpha）
		var glow := _acquire_impact_sprite()
		if glow != null:
			glow.texture = captured_tex
			glow.position = captured_pos
			glow.scale = Vector2(captured_scale * 1.5, captured_scale * 1.5)
			glow.modulate = captured_glow
			glow.visible = true
			glow.material = _get_add_mat()
			p.add_child(glow)
			glow.add_to_group("battle_vfx")
			var tw_g := glow.create_tween()
			tw_g.tween_property(glow, "scale", Vector2(captured_scale * 2.0, captured_scale * 2.0), life * 0.5).set_ease(Tween.EASE_OUT)
			tw_g.parallel().tween_property(glow, "modulate:a", 0.0, life * 0.8).set_ease(Tween.EASE_IN)
			tw_g.tween_callback(func(): _release_impact_sprite(glow))
		# 第2层：主体（ADD，膨胀→淡出，染色）
		var sprite := _acquire_impact_sprite()
		if sprite == null:
			return
		sprite.texture = captured_tex
		sprite.position = captured_pos
		sprite.scale = Vector2(captured_scale * 0.5, captured_scale * 0.5)
		sprite.modulate = captured_body
		sprite.visible = true
		sprite.material = _get_add_mat()
		p.add_child(sprite)
		sprite.add_to_group("battle_vfx")
		var tw_s := sprite.create_tween()
		tw_s.tween_property(sprite, "scale", Vector2(captured_scale, captured_scale), life * 0.3).set_ease(Tween.EASE_OUT)
		tw_s.parallel().tween_property(sprite, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
		tw_s.tween_callback(func(): _release_impact_sprite(sprite))
		# 第3层：底环（命中扩散，配色，半径跟随 target_width）
		spawn_shockwave(p, captured_pos, captured_ring_r, Color(captured_body.r, captured_body.g, captured_body.b, 0.8))
	)


## ======================================================================
# v8.5+: 战术核武专用公共 VFX（蘑菇云 / 地面焦痕）
# 蘑菇云移植自 phase_instrument_abilities._spawn_smoke_column（公共化复用），
# 让战术核武机制与相位仪核子轰炸共用同一蘑菇云实现。
## ======================================================================

## 上升烟柱粒子（核爆蘑菇云效果）。移植自 phase_instrument_abilities._spawn_smoke_column。
## CPUParticles2D 向上发射 + ADD 混合 + 底浓顶淡渐变，2.5s 后停发并回收。
## tint 由调用方传入（玩家绿 / 敌方暗红橙 / 中性灰）。
static func spawn_smoke_column(parent: Node2D, pos: Vector2, tint: Color = Color(0.5, 0.5, 0.5, 0.5)) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var p := CPUParticles2D.new()
	p.process_mode = Node.PROCESS_MODE_PAUSABLE  # v9.4: 暂停时冻结（蘑菇云烟柱持续2.4s，不设会暂停时继续飘）
	p.position = pos
	p.amount = 36
	p.lifetime = 2.4
	p.one_shot = false
	p.emitting = true
	p.explosiveness = 0.25
	p.direction = Vector2(0, -1)  # 向上
	p.spread = 30.0  # 蘑菇头扩散
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2(0, -20.0)  # 持续上飘
	p.scale_amount_min = 5.0
	p.scale_amount_max = 11.0
	p.color = tint
	# 烟柱渐变：底部浓→顶部淡（v9.2: 按 tint 颜色缓存 Gradient，避免每次烟柱 new）
	p.color_ramp = _get_smoke_grad(tint)
	# v9.2: 复用共享 ADD 材质（_get_add_mat 已缓存），不再每次 new CanvasItemMaterial
	p.material = _get_add_mat()
	parent.add_child(p)
	p.add_to_group("battle_vfx")  # 战斗结束统一清理（自毁链 2.5s+2.4s，中途结束战斗可能未销毁）
	# 2.5s 后停止发射并回收（WeakRef 防 "Lambda capture was freed"）
	var tree := parent.get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(2.5)
	var weak_p: WeakRef = weakref(p)
	timer.timeout.connect(func():
		var captured_p: Variant = weak_p.get_ref()
		if captured_p == null or not is_instance_valid(captured_p):
			return
		captured_p.emitting = false
		var t2 := tree.create_timer(captured_p.lifetime + 0.1)
		t2.timeout.connect(func():
			var captured_p2: Variant = weak_p.get_ref()
			if captured_p2 != null and is_instance_valid(captured_p2):
				captured_p2.queue_free())
	)


## 地面焦痕（核爆遗留痕迹）。加到 parent，永久持续到战斗结束随场景清理。
## radius: 焦痕半径；fade_in: 初始淡入到目标 alpha 的时间（默认 0.3s，模拟焦痕"烧出来"）。
## texture: 可选焦痕贴图（有则用贴图更逼真，无则回退纯色多边形）。贴图按 radius 缩放到目标尺寸。
static func spawn_ground_burn(parent: Node2D, pos: Vector2, radius: float, fade_in: float = 0.3, texture: Texture2D = null) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if DT.is_motion_reduce():
		return  # 减动效：跳过永久焦痕（视觉冗余）
	# 焦痕放单位层之下（z_index 负值，地面层），避免盖住单位
	if texture != null:
		# 贴图版焦痕：按 radius 缩放贴图（贴图基准半径=纹理宽度/2，缩放=radius/基准）
		var burn_sprite := Sprite2D.new()
		burn_sprite.position = pos
		burn_sprite.texture = texture
		var base_r: float = float(texture.get_width()) * 0.5
		var s: float = radius / base_r if base_r > 0.0 else 1.0
		burn_sprite.scale = Vector2(s, s)
		burn_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
		burn_sprite.z_index = -5
		parent.add_child(burn_sprite)
		burn_sprite.add_to_group("battle_vfx")  # 焦痕是永久节点无回收，靠战斗结束统一清理
		if fade_in > 0.0:
			var tween := burn_sprite.create_tween()
			tween.tween_property(burn_sprite, "modulate:a", 0.85, fade_in)
		else:
			burn_sprite.modulate.a = 0.85
	else:
		# 纯色多边形版（无贴图回退）
		var burn := Polygon2D.new()
		burn.position = pos
		# 32 段实心圆（焦痕不需要空心环）
		var segments := 32
		var pts := PackedVector2Array()
		for i in range(segments):
			var ang := (TAU * i) / segments
			pts.append(Vector2(cos(ang), sin(ang)) * radius)
		burn.polygon = pts
		burn.color = Color(0.08, 0.04, 0.02, 0.0)  # 起始透明，淡入到目标 alpha
		# 焦痕放单位层之下（z_index 负值，地面层），避免盖住单位
		burn.z_index = -5
		parent.add_child(burn)
		burn.add_to_group("battle_vfx")  # 焦痕是永久节点无回收，靠战斗结束统一清理
		if fade_in > 0.0:
			var tween := burn.create_tween()
			tween.tween_property(burn, "color:a", 0.55, fade_in)
		else:
			burn.color.a = 0.55


## 上升贴图精灵（蘑菇云贴图版）：放大+上飘+淡出，区别于 spawn_impact_sprite 的纯放大。
## target_width: 蘑菇云峰值宽度（像素，默认 320）——按贴图原始像素反算 scale，避免贴图分辨率不同时尺寸失控。
## rise: 上飘距离（像素）；life: 总生命周期。
## 普通混合（非 ADD）——蘑菇云是烟尘实体不是发光体，ADD 会让它过曝失去形状。
static func spawn_rising_sprite(parent: Node2D, pos: Vector2, texture: Texture2D, target_width: float = 320.0, rise: float = 120.0, life: float = 1.4) -> void:
	if parent == null or not is_instance_valid(parent) or texture == null:
		return
	if DT.is_motion_reduce():
		return
	var sprite := _acquire_impact_sprite()
	if sprite == null:
		return
	sprite.texture = texture
	sprite.position = pos
	# 按目标像素宽度反算 scale（贴图分辨率不同时尺寸一致）
	var tex_w: float = float(texture.get_width())
	var peak_scale: float = target_width / tex_w if tex_w > 0.0 else 1.0
	var start_scale: float = peak_scale * 0.4  # 起始 40% 大小，放大到峰值
	sprite.scale = Vector2(start_scale, start_scale)
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.95)
	sprite.visible = true
	# 普通混合（不 ADD）——保留蘑菇云形状的明暗细节
	parent.add_child(sprite)
	sprite.add_to_group("battle_vfx")  # v9.4: 战斗结束兜底清理（life 1.4s 可能跨战斗结束残留）
	# 放大到峰值 + 上飘 + 淡出（模拟蘑菇云升腾消散）
	var tween := sprite.create_tween()
	tween.parallel().tween_property(sprite, "scale", Vector2(peak_scale, peak_scale), life * 0.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "position:y", pos.y - rise, life).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_release_impact_sprite(sprite))


## 蘑菇云帧动画版（核爆专用）：用 AI 生成的精灵表切割出的多帧，AnimatedSprite2D 逐帧播放。
## 比 spawn_rising_sprite（单 sprite + tween 缩放）更流畅震撼——每帧都是 AI 画的不同成长阶段。
## frame_textures: 帧贴图数组（ Texture2D[]，按时间顺序）；空或 null 回退 false 让调用方用单 sprite。
## target_width: 峰值宽度（像素）；rise: 上飘距离；fps: 帧率（8fps × 9帧 ≈ 1.1s）。
## 成功创建 AnimatedSprite2D 返回 true；帧贴图不足返回 false（调用方回退 spawn_rising_sprite）。
static func spawn_animated_nuclear(parent: Node2D, pos: Vector2, frame_textures: Array, target_width: float = 320.0, rise: float = 120.0, fps: float = 8.0) -> bool:
	if parent == null or not is_instance_valid(parent):
		return false
	if frame_textures == null or frame_textures.size() < 2:
		return false  # 帧数不足，调用方回退单 sprite
	if DT.is_motion_reduce():
		return false  # 减动效：回退单 sprite（帧动画细节多，减动效不需要）
	# 按第一帧贴图分辨率反算 scale（所有帧应同分辨率）
	var first_tex: Texture2D = frame_textures[0]
	var tex_w: float = float(first_tex.get_width())
	var peak_scale: float = target_width / tex_w if tex_w > 0.0 else 1.0
	# 代码建 SpriteFrames（VFX 是临时节点，代码建比 .tres 灵活，不占资源树）
	var frames := SpriteFrames.new()
	frames.add_animation("grow")
	frames.set_animation_loop("grow", false)  # 播完自动停（非循环）
	frames.set_animation_speed("grow", fps)
	for i in frame_textures.size():
		var tex: Texture2D = frame_textures[i]
		if tex != null:
			frames.add_frame("grow", tex)
	# 创建 AnimatedSprite2D
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = frames
	anim.position = pos
	anim.scale = Vector2(peak_scale, peak_scale)
	anim.modulate = Color(1.0, 1.0, 1.0, 0.95)
	anim.z_index = 30  # 蘑菇云盖在单位上方
	anim.play("grow")
	parent.add_child(anim)
	anim.add_to_group("battle_vfx")  # ~1s 自毁，可能跨清场，战斗结束统一兜底清理
	# 总时长 = 帧数 / fps
	var life: float = float(frame_textures.size()) / fps
	# 上飘 + 淡出（与 spawn_rising_sprite 同范式，但配合帧动画播放）
	var tween := anim.create_tween()
	tween.parallel().tween_property(anim, "position:y", pos.y - rise, life).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(anim, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	# 播完销毁（帧动画不进对象池——核爆 CD 45s 频率低，new 节点无性能压力）
	tween.tween_callback(func():
		if is_instance_valid(anim):
			anim.queue_free())
	return true


## 能量光柱（核子轰炸专用，替代蘑菇云）。从天而降的垂直能量束打击命中点。
## 与 spawn_rising_sprite（蘑菇云向上）方向相反——能量武器=从天而降，核武器=地面升腾。
## 实现一条从高空降落到命中点的 Line2D 光束 + ADD 混合发光 + 快速收缩消散。
static func spawn_energy_pillar(parent: Node2D, pos: Vector2, color: Color = Color(0.5, 0.6, 1.0, 0.7), height: float = 400.0, life: float = 0.6) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if DT.is_motion_reduce():
		return
	var beam := _acquire_beam()
	if beam == null:
		return
	beam.width = 18.0
	beam.default_color = color
	beam.joint_mode = Line2D.LINE_JOINT_ROUND
	beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	# 从命中点正上方 height 高度降落到命中点（垂直能量束）
	beam.add_point(Vector2(pos.x, pos.y - height))
	beam.add_point(pos)
	beam.position = Vector2.ZERO
	# ADD 混合发光（与蘑菇云 spawn_smoke_column 同 blend 模式，能量武器感）
	beam.material = _get_add_mat()
	parent.add_child(beam)
	# 光束快速变细 + 淡出（能量打击瞬间消散，非持续燃烧）
	var tween := beam.create_tween()
	tween.tween_property(beam, "width", 3.0, life * 0.5)
	tween.parallel().tween_property(beam, "modulate:a", 0.0, life)
	tween.tween_callback(func():
		beam.material = null  # 清理材质引用（_add_mat 是共享缓存，不 free）
		_release_beam(beam))


## v9.3: 召唤传送门（敌方召唤类大招专用）。
## 程序化螺旋光环：三层同心环，从大收缩到小 + 旋转 + 淡出，模拟"传送门开门/关闭"。
## 复用 ring 池（与冲击波环同池），零新节点类型。duration: 总持续秒（默认 0.9）。
static func spawn_summon_portal(parent: Node2D, pos: Vector2, color: Color = Color(0.7, 0.3, 1.0, 0.9), duration: float = 0.9) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if DT.is_motion_reduce():
		return
	# 三层同心环（外/中/内），各自不同起始半径和延迟，形成层次感
	for layer in range(3):
		var ring := _acquire_ring()
		if ring == null:
			continue
		var start_r: float = 110.0 - float(layer) * 28.0  # 外110/中82/内54
		ring.position = pos
		_configure_ring_polygon(ring, start_r, color)
		parent.add_child(ring)
		var layer_delay: float = float(layer) * 0.08
		var captured_ring: Polygon2D = ring
		var captured_color: Color = color
		var captured_start: float = start_r
		var tw := ring.create_tween()
		tw.tween_interval(layer_delay)
		# 收缩到中心 + 旋转 + 淡出（半径缩小时 alpha 按比例衰减）
		tw.tween_method(func(r: float): _configure_ring_polygon(captured_ring, r, Color(captured_color.r, captured_color.g, captured_color.b, captured_color.a * (r / captured_start if captured_start > 0.0 else 0.0))), start_r, 16.0, duration - layer_delay)
		tw.parallel().tween_property(ring, "rotation", TAU * 0.8, duration - layer_delay)
		tw.tween_callback(func(): _release_ring(captured_ring))


## v9.5: 通用大招弹道飞行体（让大招有"飞过来"的过程，更写实）。
## 基于 _spawn_nuclear_missile（战术核武导弹）范式，扩展为支持多种轨迹类型。
## trajectory: "vertical"=垂直从天而降（陨石/轨道弹/神罚） | "arc"=贝塞尔弧线（核导弹/曲射） | "dive"=低空俯冲（空投燃烧弹）
## texture: 飞行体贴图（缺失回退 laser_beam 线段，保证弹道可见）
## target_width: 飞行体显示宽度（像素，按贴图分辨率反算 scale，与 spawn_spell_burst 同范式）
## tint: 飞行体染色（不同大招专属配色）；Color.WHITE=保留贴图原色
## trail_color: 拖尾颜色（飞行时尾部跟随的发光线段，None=无拖尾）
## on_arrival: 可选回调（飞行到达时触发，供调用方接爆炸特效/伤害结算）
## 返回飞行总时长（秒），调用方据此延迟后续结算（避免"敌人先死、弹还在飞"）。
static func spawn_ultimate_projectile(parent: Node2D, from: Vector2, target: Vector2, texture: Texture2D, trajectory: String = "vertical", target_width: float = 48.0, tint: Color = Color.WHITE, trail_color: Color = Color(1.0, 0.8, 0.3, 0.9), flight_time: float = 0.5, on_arrival: Callable = Callable()) -> float:
	if parent == null or not is_instance_valid(parent):
		return 0.0
	if DT.is_motion_reduce():
		# 减动效：跳过飞行，直接触发到达回调（保持伤害时序，只省视觉）
		if on_arrival.is_valid():
			on_arrival.call(target)
		return 0.0
	# 无贴图回退：用激光线段表示弹道（保证"有东西飞过来"的视觉）
	if texture == null:
		var beam_color: Color = tint if tint != Color.WHITE else Color(1.0, 0.9, 0.4, 1.0)
		VfxImpactFactory.spawn_laser_beam(parent, from, target, beam_color)
		if on_arrival.is_valid():
			var tw_fb := parent.create_tween()
			tw_fb.tween_interval(flight_time)
			tw_fb.tween_callback(func(): on_arrival.call(target))
		return flight_time
	# 创建飞行体 Sprite2D
	var missile := Sprite2D.new()
	missile.texture = texture
	var tex_w: float = float(texture.get_width())
	var mscale: float = target_width / tex_w if tex_w > 0.0 else 0.05
	missile.scale = Vector2(mscale, mscale)
	missile.modulate = tint
	missile.global_position = from
	missile.z_index = 50  # 盖在单位上方，飞行时清晰可见
	parent.add_child(missile)
	missile.add_to_group("battle_vfx")  # 战斗结束兜底清理
	# 按轨迹类型计算贝塞尔控制点
	var apex: Vector2
	match trajectory:
		"vertical":
			# 垂直下落：起点在目标正上方高空，apex 在起点→目标连线的上 1/3（轻微弧度，主要垂直）
			apex = Vector2(target.x, from.y)  # 先水平对齐再垂直下落
		"dive":
			# 低空俯冲：浅弧度（空投燃烧弹，从侧方低空飞入）
			apex = Vector2((from.x + target.x) / 2.0, min(from.y, target.y) - 60.0)
		_:  # "arc" 默认
			# 标准贝塞尔弧：中点上方抬升（像炮弹/导弹抛物线）
			apex = Vector2((from.x + target.x) / 2.0, min(from.y, target.y) - 160.0)
	# 拖尾线段（飞行时跟随，ADD 发光，强化"飞行感"）
	var has_trail: bool = trail_color.a > 0.0
	var trail_beam: Line2D = null
	if has_trail:
		trail_beam = _acquire_beam()
		if trail_beam != null:
			trail_beam.width = 6.0
			trail_beam.default_color = trail_color
			trail_beam.joint_mode = Line2D.LINE_JOINT_ROUND
			trail_beam.end_cap_mode = Line2D.LINE_CAP_ROUND
			trail_beam.material = _get_add_mat()
			parent.add_child(trail_beam)
	# 贝塞尔飞行 + 朝向旋转 + 拖尾更新
	var prev_pt: Vector2 = from
	var captured_missile: Sprite2D = missile
	var captured_trail: Line2D = trail_beam
	var captured_from: Vector2 = from
	var captured_apex: Vector2 = apex
	var captured_target: Vector2 = target
	var captured_arrival: Callable = on_arrival
	var tw := parent.create_tween()
	tw.tween_method(func(progress: float):
		if not is_instance_valid(captured_missile):
			return
		var t: float = progress
		var q0 := captured_from.lerp(captured_apex, t)
		var q1 := captured_apex.lerp(captured_target, t)
		var pt := q0.lerp(q1, t)
		captured_missile.global_position = pt
		# 朝向飞行方向
		var dir := pt - prev_pt
		if dir.length() > 0.5:
			captured_missile.rotation = dir.angle()
		prev_pt = pt
		# 更新拖尾（从飞行体后方延伸）
		if captured_trail != null and is_instance_valid(captured_trail):
			captured_trail.clear_points()
			captured_trail.add_point(pt - dir.normalized() * 24.0)
			captured_trail.add_point(pt)
	, 0.0, 1.0, flight_time)
	# 到达：移除飞行体 + 回收拖尾 + 触发回调
	tw.tween_callback(func():
		if is_instance_valid(captured_missile):
			captured_missile.queue_free()
		if captured_trail != null and is_instance_valid(captured_trail):
			captured_trail.material = null
			_release_beam(captured_trail)
		if captured_arrival.is_valid():
			captured_arrival.call(captured_target))
	return flight_time


## 完整局部核爆效果（火球+冲击波+蘑菇云帧动画+焦痕）。
## 供战术核武（单点）和核子轰炸（多点循环）共用同一套核爆视觉。
## textures: 预加载的核爆贴图包 {"fireball":Tex, "shockwave":Tex, "burn":Tex, "mushroom_frames":Tex[]}
##   缺失的贴图自动跳过对应层（部分核爆仍可见）；mushroom_frames 空则蘑菇云回退单 sprite
## colors: 配色 {"shock":C, "aftershock":C, "smoke":C}
## 全屏闪白/震屏/标题等全局效果不在此方法——由调用方按需触发（多点时只触发一次）。
## 完整局部核爆效果（火球+冲击波+蘑菇云帧动画+焦痕）。
## 供战术核武（单点）和核子轰炸（多点循环）共用同一套核爆视觉。
## textures: 预加载的核爆贴图包 {"fireball":Tex, "shockwave":Tex, "burn":Tex, "mushroom_frames":Tex[]}
##   缺失的贴图自动跳过对应层（部分核爆仍可见）；mushroom_frames 空则蘑菇云回退单 sprite
## colors: 配色 {"shock":C, "aftershock":C, "smoke":C}
## size_scale: 整体尺寸缩放（1.0=战术核武完整尺寸；核子轰炸多点用 0.6 缩小，避免半径覆盖到己方）
## 全屏闪白/震屏/标题等全局效果不在此方法——由调用方按需触发（多点时只触发一次）。
static func spawn_nuclear_explosion(parent: Node2D, pos: Vector2, textures: Dictionary, colors: Dictionary, size_scale: float = 1.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var shock_color: Color = colors.get("shock", Color(1.0, 0.85, 0.5, 0.9))
	var aftershock_color: Color = colors.get("aftershock", Color(0.9, 0.5, 0.2, 0.5))
	var smoke_tint: Color = colors.get("smoke", Color(0.35, 0.32, 0.30, 0.6))
	# 尺寸缩放（核子轰炸多点用 0.6，避免半径 320 的余波环覆盖到靠近的我方单位）
	var fireball_scale: float = 0.35 * size_scale
	var shockwave_tex_scale: float = 0.30 * size_scale
	var main_radius: float = 200.0 * size_scale
	var after_radius: float = 320.0 * size_scale
	var mushroom_w: float = 320.0 * size_scale
	var mushroom_rise: float = 120.0 * size_scale
	var burn_radius: float = 90.0 * size_scale
	# ①火球贴图
	var fireball_tex: Texture2D = textures.get("fireball", null)
	if fireball_tex != null:
		spawn_impact_sprite(parent, pos, fireball_tex, fireball_scale, 0.4)
	# ②主冲击波：贴图 + 程序化环叠加
	var shockwave_tex: Texture2D = textures.get("shockwave", null)
	if shockwave_tex != null:
		spawn_impact_sprite(parent, pos, shockwave_tex, shockwave_tex_scale, 0.45)
	spawn_shockwave(parent, pos, main_radius, shock_color)
	# ③余波环（延迟 0.08s）
	var after_tw := parent.create_tween()
	after_tw.tween_interval(0.08)
	after_tw.tween_callback(func():
		if is_instance_valid(parent):
			spawn_shockwave(parent, pos, after_radius, aftershock_color))
	# ④蘑菇云：优先帧动画，失败回退单 sprite
	var mushroom_frames: Array = textures.get("mushroom_frames", [])
	var mushroom_played: bool = false
	if not mushroom_frames.is_empty():
		mushroom_played = spawn_animated_nuclear(parent, pos, mushroom_frames, mushroom_w, mushroom_rise, 8.0)
	if not mushroom_played:
		var mushroom_tex: Texture2D = textures.get("mushroom", null)
		if mushroom_tex != null:
			spawn_rising_sprite(parent, pos, mushroom_tex, mushroom_w, mushroom_rise, 1.4)
	spawn_smoke_column(parent, pos, smoke_tint)
	# ⑤地面焦痕（贴图版，缺失回退纯色多边形）
	var burn_tex: Texture2D = textures.get("burn", null)
	spawn_ground_burn(parent, pos, burn_radius, 0.3, burn_tex)


## ======================================================================
## v8.4: 武器类改造专属视觉（变体叠加层）
## 在基础三层特效之上，为 5 种武器类改造叠加独有的视觉特征：
##   cluster     — 子母弹：主爆炸 + 6 个随机散布的小溅射点（子弹药撒布）
##   thermobaric — 温压弹：超大冲击波 + 0.15s 后二次爆炸（温压二次燃烧）
##   proximity   — 近炸引信：高空环 + 向下火花锥（空爆闪光）
##   guided      — 制导炮弹：精准命中指示环（快速收缩同心环）
##   gun_missile — 炮射导弹：蓝白拖尾火花锥（区分标准导弹的橙红）
## 所有变体复用现有 ring/spark 池，motion_reduce 时只保留最简特征。
## ======================================================================
static func spawn_variant_overlay(parent: Node2D, world_pos: Vector2, weapon_type: int, variant: String, is_player: bool) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	match variant:
		"cluster":
			_spawn_cluster_burst(parent, world_pos, is_player)
		"thermobaric":
			_spawn_thermobaric_blast(parent, world_pos, is_player)
		"proximity":
			_spawn_proximity_airburst(parent, world_pos, is_player)
		"guided":
			_spawn_guided_indicator(parent, world_pos, is_player)
		"gun_missile":
			_spawn_gun_missile_trail(parent, world_pos, is_player)


## 子母弹：主爆炸周围撒布 6 个小溅射点（子弹药分离）
static func _spawn_cluster_burst(parent: Node2D, pos: Vector2, is_player: bool) -> void:
	if DT.is_motion_reduce():
		return  # 减动效：跳过子弹药撒布
	# 6 个围绕主爆点的小溅射，半径 30-55px 随机散布
	for i in range(6):
		var angle: float = (TAU * i) / 6.0 + randf_range(-0.3, 0.3)
		var dist: float = randf_range(30.0, 55.0)
		var sub_pos: Vector2 = pos + Vector2(cos(angle), sin(angle)) * dist
		# 每个子弹药一个小环 + 少量火花（复用基础特效，武器类型用 ROCKET=3 的配方）
		spawn_layered_impact(parent, sub_pos, 3, is_player, -1)


## 温压弹：超大冲击波（半径×1.5）+ 延迟二次爆炸
static func _spawn_thermobaric_blast(parent: Node2D, pos: Vector2, is_player: bool) -> void:
	# 超大冲击波（橙红，半径 130）
	var blast_color: Color = Color(1.0, 0.4, 0.1, 0.9)
	spawn_shockwave(parent, pos, 130.0, blast_color)
	if DT.is_motion_reduce():
		return  # 减动效：跳过二次爆炸
	# 延迟 0.15s 后二次爆炸（温压弹的持续燃烧特性）
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var weak_parent: WeakRef = weakref(parent)
	tree.create_timer(0.15).timeout.connect(func():
		if not is_instance_valid(weak_parent.get_ref()):
			return
		var captured_parent: Node2D = weak_parent.get_ref() as Node2D
		if captured_parent == null:
			return
		spawn_layered_impact(captured_parent, pos, 3, is_player, -1)
	)


## 近炸引信：高空环 + 向下火花锥（空爆闪光，区别于地面爆炸）
static func _spawn_proximity_airburst(parent: Node2D, pos: Vector2, is_player: bool) -> void:
	# 空爆闪光环（白色，比地面爆炸更亮更快）
	var airburst_color: Color = Color(1.0, 0.85, 0.5, 0.85)
	spawn_shockwave(parent, pos, 70.0, airburst_color)
	if DT.is_motion_reduce():
		return
	# 向下火花锥（模拟破片向下散布击中下方目标）
	if _active_sparks >= MAX_SPARKS:
		return
	_active_sparks += 1
	var p := _acquire_spark_particle()
	if p == null:
		_active_sparks -= 1
		return
	# v9.2: 空爆火花用金属贴图（池复用需显式赋值）
	p.texture = PARTICLE_TEX_SPARK_METAL
	p.position = pos + Vector2(0, -10)  # v8.4: 用 position（与工厂惯例一致，pos 已是 world 坐标）
	p.amount = 16
	p.lifetime = 0.40
	p.direction = Vector2.DOWN
	p.spread = 60.0  # 向下锥形
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 200.0
	p.gravity = Vector2(0, 150)
	p.color = Color(1.0, 0.8, 0.4, 1.0)
	p.color_ramp = _get_spark_ramp(p.color)  # v8.4: 与 _spawn_sparks 一致，设色带避免池复用残留
	# v9.2: 空爆火花贴图化缩小
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	parent.add_child(p)
	var tree := p.get_tree()
	if tree != null:
		# v7.5 同款：用 _connect_deferred_release 避免 "Lambda capture was freed" 运行时错误
		var timer := tree.create_timer(p.lifetime + 0.1)
		_connect_deferred_release(timer, p, _release_spark_particle)


## 制导炮弹：精准命中指示环（两层快速收缩同心环）
static func _spawn_guided_indicator(parent: Node2D, pos: Vector2, is_player: bool) -> void:
	if DT.is_motion_reduce():
		return
	# 外环（青色，快速收缩 → 精准点）
	var outer := _acquire_ring()
	if outer != null:
		outer.position = pos
		_configure_ring_polygon(outer, 50.0, Color(0.4, 0.9, 1.0, 0.7))
		parent.add_child(outer)
		var tw1 := outer.create_tween()
		tw1.tween_method(func(r: float): _configure_ring_polygon(outer, r, Color(0.4, 0.9, 1.0, 0.7 * (r / 50.0))), 50.0, 8.0, 0.25)
		tw1.tween_callback(func(): _release_ring(outer))
	# 内环（延迟 0.08s，更小更快 → 强化"锁定"感）
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		var weak_parent: WeakRef = weakref(parent)
		var captured_pos: Vector2 = pos  # 值类型，lambda 直接捕获安全
		tree.create_timer(0.08).timeout.connect(func():
			var wp: Node2D = weak_parent.get_ref() as Node2D
			if wp == null or not is_instance_valid(wp):
				return
			var inner := _acquire_ring()
			if inner == null:
				return
			inner.position = captured_pos
			_configure_ring_polygon(inner, 30.0, Color(0.6, 1.0, 1.0, 0.8))
			wp.add_child(inner)
			var tw2 := inner.create_tween()
			tw2.tween_method(func(r: float): _configure_ring_polygon(inner, r, Color(0.6, 1.0, 1.0, 0.8 * (r / 30.0))), 30.0, 5.0, 0.18)
			tw2.tween_callback(func(): _release_ring(inner))
		)


## 炮射导弹：蓝白拖尾火花（区分标准导弹的橙红色调）
static func _spawn_gun_missile_trail(parent: Node2D, pos: Vector2, is_player: bool) -> void:
	if DT.is_motion_reduce() or _active_sparks >= MAX_SPARKS:
		return
	_active_sparks += 1
	var p := _acquire_spark_particle()
	if p == null:
		_active_sparks -= 1
		return
	# v9.2: 导弹尾迹用金属贴图（池复用需显式赋值）
	p.texture = PARTICLE_TEX_SPARK_METAL
	p.position = pos  # v8.4: 用 position（与工厂惯例一致）
	p.amount = 20
	p.lifetime = 0.45
	p.direction = Vector2(0, 0)
	p.spread = 360.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 100.0
	p.gravity = Vector2(0, 0)
	# 蓝白色调（炮射导弹特征，区别于标准导弹的橙红）
	p.color = Color(0.6, 0.8, 1.0, 1.0)
	p.color_ramp = _get_spark_ramp(p.color)  # v8.4: 与 _spawn_sparks 一致，设色带避免池复用残留
	# v9.2: 导弹尾迹贴图化缩小
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	parent.add_child(p)
	var tree := p.get_tree()
	if tree != null:
		# v7.5 同款：用 _connect_deferred_release 避免 "Lambda capture was freed" 运行时错误
		var timer := tree.create_timer(p.lifetime + 0.1)
		_connect_deferred_release(timer, p, _release_spark_particle)


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
	# v9.2: 命中粒子用放射状贴图（区别于拖尾的顺向条纹）——让"飞行"和"撞击"形状可分
	#   动能武器 → 放射状金属火花爆点；能量武器 → 放射状能量爆裂
	#   重型爆炸（3/7/9）保持碎片贴图（爆炸碎块语义）
	if weapon_type in [8, 10, 11]:  # LASER / OMEGA / RAIL — 放射能量爆裂
		p.texture = PARTICLE_TEX_IMPACT_ENERGY
	elif weapon_type in [3, 7, 9]:  # ROCKET / FLAK / MISSILE — 爆炸碎片
		p.texture = PARTICLE_TEX_SPARK_HEAVY
	else:                           # 动能直射类 — 放射状撞击火花
		# v9.4: 改用圆点贴图（MUZZLE_LIGHT），弃用 IMPACT_METAL 星芒长条
		# （星芒贴图高速运动拉成长条，密集命中时围成杂乱长条光环；圆点保留放射感但不拉长）
		p.texture = PARTICLE_TEX_MUZZLE_LIGHT
	# 按配方差异化参数
	p.amount = int(recipe.get("spark_amount", 18))
	p.initial_velocity_min = float(recipe.get("spark_vmin", 40.0))
	p.initial_velocity_max = float(recipe.get("spark_vmax", 120.0))
	# v9.4: 轻武器（SMG/RIFLE/MG/PISTOL，wt 0/1/2/4）命中火花克制——
	# 这些武器 attack_speed 高、命中密集（冲锋枪每秒数十次命中），16-22 颗高速火花
	# 累积成满屏"长条火星"（impact_metal 贴图高速运动拉长）。
	# 减半粒子数 + 缩短寿命，保留"命中"反馈但不糊屏。重型/能量武器不动（命中稀疏）。
	if weapon_type in [0, 1, 2, 4]:
		p.amount = maxi(6, p.amount / 2)
		p.lifetime = minf(p.lifetime, 0.25)
	# v9.2: 贴图化后 scale_amount 需除以贴图尺寸系数（原无贴图时 scale=像素直径，
	# 现 32px 贴图 × scale = 显示尺寸，会爆炸）。统一 ×0.4 让命中火花回到合理范围。
	# 配方值 1.5-7.0 × 0.4 = 0.6-2.8 → 32px 贴图显示 19-90px（合理，单位约 60-80px）
	const SPARK_SCALE_FIX: float = 0.4
	p.scale_amount_min = float(recipe.get("spark_smin", 1.5)) * SPARK_SCALE_FIX
	p.scale_amount_max = float(recipe.get("spark_smax", 3.0)) * SPARK_SCALE_FIX
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
		_connect_deferred_release(timer, p, _release_spark_particle)


## ======================================================================
## v7.5: 定时器回收包装器（解决 "Lambda capture was freed" 运行时错误）
## ======================================================================
## 问题：spawn_*_sparks/debris 把粒子加到临时父节点（如 Bullet），父节点被
## queue_free / 归还对象池时粒子随之 free，但 SceneTreeTimer 仍持有 lambda 捕获
## 的强引用 p，触发时引擎报 "Lambda capture at index 0 was freed. Passed null"。
## 解法：lambda 捕获 WeakRef 而非强引用；WeakRef 不阻止对象释放，get_ref() 在
## 对象已释放时返回 null，release 函数已有 null 守卫，安全返回。
static func _connect_deferred_release(timer: SceneTreeTimer, node: Node, release_fn: Callable) -> void:
	var weak: WeakRef = weakref(node)
	timer.timeout.connect(func() -> void:
		var n: Variant = weak.get_ref()
		if n != null and is_instance_valid(n):
			release_fn.call(n)
	)


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
	# v9.2: 烟尘/碎片按武器类型分流贴图（池复用需显式赋值，否则继承上次的 texture）
	if weapon_type in [8, 10, 11]:
		p.texture = PARTICLE_TEX_SMOKE_ENERGY
	else:
		p.texture = PARTICLE_TEX_SMOKE_GENERIC
	p.amount = int(debris_cfg.get("amount", 10))
	p.lifetime = float(debris_cfg.get("life", 0.5))
	p.initial_velocity_min = float(debris_cfg.get("vmin", 30.0))
	p.initial_velocity_max = float(debris_cfg.get("vmax", 90.0))
	# v9.2: 烟尘贴图化后 scale 同样需缩小（64px 贴图 × scale）。统一 ×0.5
	# 配方值 2.0-5.5 × 0.5 = 1.0-2.75 → 64px 贴图显示 64-176px（烟尘本就该大些）
	const DEBRIS_SCALE_FIX: float = 0.5
	p.scale_amount_min = float(debris_cfg.get("smin", 2.0)) * DEBRIS_SCALE_FIX
	p.scale_amount_max = float(debris_cfg.get("smax", 4.0)) * DEBRIS_SCALE_FIX
	# 烟尘向上、碎片有重力
	if bool(debris_cfg.get("is_smoke", false)):
		if bool(debris_cfg.get("low_dust", false)):
			# v8.x: 曲射落地扬尘——横向低矮扩散（贴地），区别于爆炸烟柱的垂直上升
			p.direction = Vector2(1, 0)  # 横向（左甩+右甩由 spread=180 实现）
			p.spread = 180.0
			p.gravity = Vector2(0, 40.0)  # 轻微下沉，模拟尘土回落
			p.color = debris_cfg.get("smoke_color", Color(0.5, 0.45, 0.38, 0.45))
		else:
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
		_connect_deferred_release(timer, p, _release_debris_particle)


## ======================================================================
## 内部：配色 & 配方表
## ======================================================================

## 命中主色（v8.4: 配色表真身，WeaponProjectileVfx.IMPACT_COLOR_BY_WT 已废弃迁移至此）
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
	# 武器本色保留为主（70%），combat_kind 只做轻微染色（30%），不再完全覆盖丢失武器特征色。
	# 原 base = TINT_BY_KIND[...] 直接覆盖导致所有武器打同目标都同色（看不出差异）。
	if combat_kind >= 0 and TINT_BY_KIND.has(combat_kind):
		base = base.lerp(TINT_BY_KIND[combat_kind], 0.3)
	if not is_player:
		base = base.lerp(Color(1.0, 0.45, 0.55), 0.25)  # 敌方轻微偏粉（25%），保留武器色
	return base


## 武器配方表（按 weapon_type 数值索引）
## 注：weapon_type=1 在 bullet 路径=INDIRECT(曲射)，在 batch 路径=RIFLE(直射)，
## 取折中"中火"配置（既不太像火炮也不太像步枪），不加剧既有歧义。
## v8.2: 整体加长寿命到"可清晰感知"区间（火花≥0.45s/环≥0.35s），保留武器间梯度。
## v8.3 视觉增强：环 ×1.5、duration +0.08、spark_amount +50%、spark_vmax +60%、debris +30%
## 让命中爆炸有"砰"的分量感（原环到 24px 就没了，火花 0.15s 消散）
## v9.2: 命中配方缓存——配方是只读静态数据（按 weapon_type+flavor 固定），
## 每次 new Dictionary 字面量在密集命中下是显著的堆分配源。
## 按 (weapon_type*100+flavor) 整数键缓存，命中后返回同一引用（调用方只 .get() 读不改）。
static var _recipe_cache: Dictionary = {}

static func _impact_recipe(weapon_type: int, weapon_name: String = "") -> Dictionary:
	# v8.x: 直射系亚类分类（仅 0/1/2/4 生效，其他返回 NONE 走原配方）
	var flavor: int = DirectWeaponFlavor.classify(weapon_name, weapon_type)
	# v9.2: 缓存命中——同一 (weapon_type, flavor) 的配方是只读的，首次构建后直接返回引用。
	var cache_key: int = weapon_type * 100 + flavor
	if _recipe_cache.has(cache_key):
		return _recipe_cache[cache_key]
	var d: Dictionary = _impact_recipe_build(weapon_type, flavor)
	_recipe_cache[cache_key] = d
	return d

## v9.2: 原 _impact_recipe 的 match 主体（拆出以便 _impact_recipe 做缓存包装）。
static func _impact_recipe_build(weapon_type: int, flavor: int) -> Dictionary:
	match weapon_type:
		0, 4:  # DIRECT/SMG/PISTOL — 小环 + 少量高亮火花（v8.4 重平衡：减粒子数提单粒子亮度）
			# v8.x 亚类细分：机枪/坦克炮/步枪/手枪 各自不同的命中反馈强度
			match flavor:
				DirectWeaponFlavor.Flavor.MG:
					# 机枪：弹着点更密（火花略多 + 环略大），连发时形成密集弹痕
					return {
						"ring_r": 34.0, "ring_dur": 0.34,
						"spark_amount": 22, "spark_vmin": 110.0, "spark_vmax": 280.0,
						"spark_smin": 2.2, "spark_smax": 3.6, "spark_life": 0.42, "spark_spread": 360.0,
					}
				DirectWeaponFlavor.Flavor.TANK_GUN:
					# 坦克炮：重炮命中（大环 + 粗火花），与轻武器弹着点明显区分
					return {
						"ring_r": 52.0, "ring_dur": 0.42,
						"spark_amount": 26, "spark_vmin": 120.0, "spark_vmax": 300.0,
						"spark_smin": 3.0, "spark_smax": 5.0, "spark_life": 0.50, "spark_spread": 360.0,
					}
				DirectWeaponFlavor.Flavor.RIFLE:
					# 步枪：高速集中喷射（窄角，穿甲感），区别于冲锋枪的圆散
					return {
						"ring_r": 30.0, "ring_dur": 0.32,
						"spark_amount": 18, "spark_vmin": 130.0, "spark_vmax": 320.0,
						"spark_smin": 2.0, "spark_smax": 3.2, "spark_life": 0.44, "spark_spread": 70.0,
						"spark_dir": true,
					}
				DirectWeaponFlavor.Flavor.SMALL_ARMS:
					# 手枪/卡宾：最弱命中（小环 + 少火花），体现轻武器
					return {
						"ring_r": 22.0, "ring_dur": 0.28,
						"spark_amount": 12, "spark_vmin": 80.0, "spark_vmax": 200.0,
						"spark_smin": 2.0, "spark_smax": 3.2, "spark_life": 0.38, "spark_spread": 360.0,
					}
				_:
					# GENERIC/UNKNOWN：原基准（冲锋枪/通用直射）
					# v8.4: 原配方 28 小火花在高速连发下糊成一片，改为 16 个更亮火花
					return {
						"ring_r": 28.0, "ring_dur": 0.32,
						"spark_amount": 16, "spark_vmin": 100.0, "spark_vmax": 260.0,
						"spark_smin": 2.5, "spark_smax": 4.0, "spark_life": 0.45, "spark_spread": 360.0,
					}
		6:  # SNIPER — 中环 + 高速集中喷射
			return {
				"ring_r": 48.0, "ring_dur": 0.44,
				"spark_amount": 25, "spark_vmin": 150.0, "spark_vmax": 350.0,
				"spark_smin": 1.8, "spark_smax": 3.2, "spark_life": 0.50, "spark_spread": 55.0,
				"spark_dir": true,
			}
		5:  # SHOTGUN — 宽散布
			return {
				"ring_r": 44.0, "ring_dur": 0.42,
				"spark_amount": 40, "spark_vmin": 80.0, "spark_vmax": 250.0,
				"spark_smin": 1.5, "spark_smax": 2.8, "spark_life": 0.52, "spark_spread": 360.0,
			}
		1:  # INDIRECT(曲射) / RIFLE(batch直射) — 中火折中
			# v8.x 亚类细分：曲射(迫击炮/野战炮等无步枪关键词)加地面扬尘，体现"炮弹落地"；
			# RIFLE 直射(batch 路径) 走窄角集中火花，与直射步枪一致。
			if flavor == DirectWeaponFlavor.Flavor.RIFLE:
				return {
					"ring_r": 36.0, "ring_dur": 0.40,
					"spark_amount": 22, "spark_vmin": 120.0, "spark_vmax": 300.0,
					"spark_smin": 2.0, "spark_smax": 3.4, "spark_life": 0.50, "spark_spread": 70.0,
					"spark_dir": true,
				}
			# 曲射：加低矮横向扬尘（is_smoke + 低重力），模拟炮弹落地激起的尘土
			return {
				"ring_r": 48.0, "ring_dur": 0.48,
				"spark_amount": 32, "spark_vmin": 90.0, "spark_vmax": 260.0,
				"spark_smin": 2.0, "spark_smax": 3.8, "spark_life": 0.60, "spark_spread": 360.0,
				"debris": {"amount": 14, "life": 0.9, "vmin": 40.0, "vmax": 90.0, "smin": 3.5, "smax": 5.5, "is_smoke": true, "smoke_color": Color(0.5, 0.45, 0.38, 0.45), "low_dust": true},
			}
		3:  # ROCKET — 大环 + 烟尘
			return {
				"ring_r": 80.0, "ring_dur": 0.60,
				"spark_amount": 48, "spark_vmin": 100.0, "spark_vmax": 320.0,
				"spark_smin": 3.0, "spark_smax": 6.0, "spark_life": 0.70, "spark_spread": 360.0,
				"debris": {"amount": 18, "life": 1.0, "vmin": 50.0, "vmax": 120.0, "smin": 3.0, "smax": 5.0, "is_smoke": true, "smoke_color": Color(0.4, 0.35, 0.3, 0.5)},
			}
		9, 2:  # MISSILE / AERIAL — 大环 + 碎片 + 烟柱
			return {
				"ring_r": 90.0, "ring_dur": 0.65,
				"spark_amount": 55, "spark_vmin": 110.0, "spark_vmax": 350.0,
				"spark_smin": 3.0, "spark_smax": 7.0, "spark_life": 0.75, "spark_spread": 360.0,
				"debris": {"amount": 20, "life": 1.1, "vmin": 60.0, "vmax": 140.0, "smin": 2.0, "smax": 4.0, "is_smoke": false, "debris_color": Color(0.5, 0.45, 0.4, 1.0)},
			}
		7:  # FLAK — 中大环 + 烟尘
			return {
				"ring_r": 64.0, "ring_dur": 0.52,
				"spark_amount": 38, "spark_vmin": 90.0, "spark_vmax": 270.0,
				"spark_smin": 2.5, "spark_smax": 5.0, "spark_life": 0.62, "spark_spread": 360.0,
				"debris": {"amount": 16, "life": 0.9, "vmin": 45.0, "vmax": 95.0, "smin": 3.0, "smax": 4.0, "is_smoke": true, "smoke_color": Color(0.45, 0.4, 0.35, 0.45)},
			}
		8:  # LASER — 细环 + 高速线状火花（能量武器灼烧感，仍比动能武器短，但已能看清）
			return {
				"ring_r": 30.0, "ring_dur": 0.30,
				"spark_amount": 25, "spark_vmin": 140.0, "spark_vmax": 350.0,
				"spark_smin": 1.2, "spark_smax": 2.2, "spark_life": 0.40, "spark_spread": 40.0,
				"spark_dir": true,
			}
		10:  # OMEGA(离子/等离子炮) — 蓝色 + 蓝紫灼烧烟尘（能量武器融化装甲感）
			return {
				"ring_r": 50.0, "ring_dur": 0.45,
				"spark_amount": 35, "spark_vmin": 90.0, "spark_vmax": 280.0,
				"spark_smin": 2.0, "spark_smax": 4.5, "spark_life": 0.58, "spark_spread": 360.0,
				"debris": {"amount": 12, "life": 0.7, "vmin": 30.0, "vmax": 70.0, "smin": 2.5, "smax": 4.0, "is_smoke": true, "smoke_color": Color(0.35, 0.4, 0.8, 0.4)},
			}
		11:  # RAIL(电磁轨道炮) — 青色 + 高速定向喷射（电磁穿透感，窄角集中）
			return {
				"ring_r": 44.0, "ring_dur": 0.40,
				"spark_amount": 30, "spark_vmin": 160.0, "spark_vmax": 380.0,
				"spark_smin": 1.5, "spark_smax": 3.0, "spark_life": 0.50, "spark_spread": 45.0,
				"spark_dir": true,
			}
		_:
			return {
				"ring_r": 42.0, "ring_dur": 0.42,
				"spark_amount": 28, "spark_vmin": 80.0, "spark_vmax": 240.0,
				"spark_smin": 1.8, "spark_smax": 3.2, "spark_life": 0.56, "spark_spread": 360.0,
			}


## ======================================================================
## 内部：对象池
## ======================================================================

static func _get_add_mat() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat

## v9.2: 烟柱 Gradient 按颜色键缓存——tint 颜色种类有限（几种烟色），
## 按 RGB 量化键复用同一 Gradient 引用，避免每次烟柱 new Gradient + 3 个 add_point。
static func _get_smoke_grad(tint: Color) -> Gradient:
	var key: String = "%02x%02x%02x" % [int(tint.r * 255), int(tint.g * 255), int(tint.b * 255)]
	if _smoke_grad_cache.has(key):
		return _smoke_grad_cache[key]
	var grad := Gradient.new()
	grad.add_point(0, Color(tint.r, tint.g, tint.b, 0.85))
	grad.add_point(0.5, Color(tint.r, tint.g, tint.b, 0.45))
	grad.add_point(1.0, Color(tint.r, tint.g, tint.b, 0.0))
	_smoke_grad_cache[key] = grad
	return grad


## 冲击波环（Polygon2D）池
static func _acquire_ring() -> Polygon2D:
	var i := _ring_pool.size() - 1
	while i >= 0:
		var candidate = _ring_pool[i]
		_ring_pool.remove_at(i)
		if candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			# v7.5: 防御性剥离残留 parent（同 _acquire_spark_particle）
			if candidate.get_parent() != null:
				candidate.get_parent().remove_child(candidate)
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
	# v7.5: 用 get_parent()!=null 判定而非 is_inside_tree()。父节点可能在战斗拆卸时
	# 被移出场景树但尚未 free，此时 is_inside_tree()=false 会跳过 remove_child，
	# 导致 ring 带父归还池中，下次 acquire 的 add_child 触发 "already has a parent"。
	if ring.get_parent() != null:
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
			# v7.5: 防御性剥离残留 parent（同 _acquire_spark_particle）
			if candidate.get_parent() != null:
				candidate.get_parent().remove_child(candidate)
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
	# v7.5: 用 get_parent()!=null 判定（同 _release_ring 注释说明）
	if beam.get_parent() != null:
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
			# v7.5: 防御性剥离残留 parent（同 _acquire_spark_particle）
			if candidate.get_parent() != null:
				candidate.get_parent().remove_child(candidate)
			candidate.visible = true
			candidate.emitting = true
			candidate.restart()
			return candidate
		i -= 1
	var p := CPUParticles2D.new()
	p.process_mode = Node.PROCESS_MODE_PAUSABLE  # v9.4: 暂停时冻结
	p.one_shot = true
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 4.0
	p.material = _get_add_mat()
	# v9.2: 默认贴图（常规烟尘）——调用方 acquire 后会按 weapon_type 覆盖
	p.texture = PARTICLE_TEX_SMOKE_GENERIC
	return p


static func _release_debris_particle(p: CPUParticles2D) -> void:
	if p == null or not is_instance_valid(p):
		_active_debris -= 1
		return
	# v7.5: 用 get_parent()!=null 判定（同 _release_ring 注释说明）
	if p.get_parent() != null:
		p.get_parent().remove_child(p)
	p.emitting = false
	p.visible = false
	p.position = Vector2.ZERO
	# v9.2: 不清 texture——粒子池复用时保留贴图，调用方 acquire 后按 weapon_type 覆盖。
	# 若清 null，下次 acquire 若调用方漏赋 texture 会回退方形方块。
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
			# v7.5: 防御——若池中残留 parent（release 漏判 / 战斗拆卸时序），
			# 此处剥离避免 add_child "already has a parent"。
			if candidate.get_parent() != null:
				candidate.get_parent().remove_child(candidate)
			candidate.visible = true
			candidate.emitting = true
			candidate.restart()
			return candidate
		i -= 1
	var p := CPUParticles2D.new()
	p.process_mode = Node.PROCESS_MODE_PAUSABLE  # v9.4: 暂停时冻结（默认 INHERIT 会跟随 ALWAYS 父节点继续动）
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
	# v9.2: 贴图化后的默认 scale（调用方会覆盖，此为防御性兜底）
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.color = Color(1.0, 0.95, 0.6, 1.0)
	p.material = _get_add_mat()
	# v9.2: 默认贴图（动能火花）——调用方 acquire 后会按 weapon_type 覆盖；
	# 此处赋默认值是防御性：若未来新增调用方漏赋 texture，至少不是方块
	p.texture = PARTICLE_TEX_SPARK_METAL
	p.emitting = true
	return p


static func _release_spark_particle(p: CPUParticles2D) -> void:
	if p == null or not is_instance_valid(p):
		_active_sparks -= 1
		return
	# v7.5: 用 get_parent()!=null 判定（同 _release_ring 注释说明）
	if p.get_parent() != null:
		p.get_parent().remove_child(p)
	p.emitting = false
	p.visible = false
	p.position = Vector2.ZERO
	# v9.2: 不清 texture（同 _release_debris_particle，池复用需保留贴图）
	_active_sparks -= 1
	if _spark_pool.size() < MAX_SPARKS:
		_spark_pool.append(p)
	else:
		p.queue_free()


## v8.4: 命中贴图 Sprite2D 池（重型爆炸武器 *_impact.png 渲染）
static func _acquire_impact_sprite() -> Sprite2D:
	var i := _impact_sprite_pool.size() - 1
	while i >= 0:
		var candidate = _impact_sprite_pool[i]
		_impact_sprite_pool.remove_at(i)
		if candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			# v7.5 同款防御：剥离残留 parent
			if candidate.get_parent() != null:
				candidate.get_parent().remove_child(candidate)
			_active_impact_sprites += 1
			return candidate
		i -= 1
	if _active_impact_sprites >= MAX_IMPACT_SPRITES:
		return null  # 硬上限节流
	_active_impact_sprites += 1
	var s := Sprite2D.new()
	s.centered = true
	s.offset = Vector2.ZERO
	s.scale = Vector2.ONE  # Sprite2D 无 expand_mode（属 TextureRect/Control）；按 scale 渲染是默认行为
	s.visible = false
	return s


static func _release_impact_sprite(s: Sprite2D) -> void:
	if s == null or not is_instance_valid(s):
		_active_impact_sprites -= 1
		return
	if s.get_parent() != null:
		s.get_parent().remove_child(s)
	s.visible = false
	s.position = Vector2.ZERO
	s.texture = null  # 释放贴图引用，避免池中持有资源
	if s.is_in_group("battle_vfx"):
		s.remove_from_group("battle_vfx")  # v9.4: 归还池时移除组（避免池中节点被 end_battle 误清）
	_active_impact_sprites -= 1
	if _impact_sprite_pool.size() < MAX_IMPACT_SPRITES:
		_impact_sprite_pool.append(s)
	else:
		s.queue_free()




## ======================================================================
## v9.1 组合技套路视觉层
## 浓度场区域 / 激活横幅 / 光束分裂反射 / 弱点暴露 / 雷达锁定 / 扩散波纹
## ======================================================================

## 战场纳米浓度可视化（青色半透明区域）。
## amount: 当前浓度（0~50）；parent 是 battlefield Node2D；world_pos 是战场中心。
## 浓度越高：范围越大、alpha 越高。每 0.5s 由 battlefield 重建（非每帧 spawn）。
static func spawn_nano_field(parent: Node2D, world_pos: Vector2, amount: float) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if amount <= 0.5:
		_cleanup_field_vfx(parent, "combo_nano_field")
		return
	var t: float = clampf(amount / 50.0, 0.0, 1.0)
	var radius: float = lerp(100.0, 280.0, t)
	var alpha: float = lerp(0.0, 0.15, t)
	_cleanup_field_vfx(parent, "combo_nano_field")
	var pts := PackedVector2Array()
	var segments := 32
	for i in range(segments):
		var ang := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.position = world_pos
	poly.color = Color(0.2, 0.9, 1.0, alpha)
	poly.z_index = -5  # 盖在地面背景之上、单位之下
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	poly.material = mat
	poly.name = "combo_nano_field"
	parent.add_child(poly)
	poly.add_to_group("battle_vfx")  # 浓度场 name 管理替换，战斗结束若浓度还在则残留


## 战场化学污染可视化（绿色半透明区域）。
## amount: 当前浓度（0~60）；同 spawn_nano_field 参数约定。
static func spawn_chem_field(parent: Node2D, world_pos: Vector2, amount: float) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if amount <= 0.5:
		_cleanup_field_vfx(parent, "combo_chem_field")
		return
	var t: float = clampf(amount / 60.0, 0.0, 1.0)
	var radius: float = lerp(80.0, 320.0, t)
	var alpha: float = lerp(0.0, 0.18, t)
	_cleanup_field_vfx(parent, "combo_chem_field")
	var pts := PackedVector2Array()
	var segments := 32
	for i in range(segments):
		var ang := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.position = world_pos
	poly.color = Color(0.3, 1.0, 0.2, alpha)
	poly.z_index = -5
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	poly.material = mat
	poly.name = "combo_chem_field"
	parent.add_child(poly)
	poly.add_to_group("battle_vfx")  # 浓度场 name 管理替换，战斗结束若浓度还在则残留


## 清理已存在的浓度场 VFX（防止重复创建）。
static func _cleanup_field_vfx(parent: Node2D, node_name: String) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var old := parent.get_node_or_null(node_name)
	if old != null and is_instance_valid(old):
		old.queue_free()


## 化学爆炸扩散波纹（套路1 chem_burst 触发时）。
## 从源单位向外 radiate 绿色冲击波环。
static func spawn_chem_burst_wave(parent: Node2D, pos: Vector2) -> void:
	spawn_shockwave(parent, pos, 80.0, Color(0.3, 1.0, 0.2, 0.9))


## 纳米传染波纹（套路3 nano_spread 触发时）。
## 青色冲击波环。
static func spawn_nano_spread_wave(parent: Node2D, pos: Vector2) -> void:
	spawn_shockwave(parent, pos, 60.0, Color(0.2, 0.9, 1.0, 0.85))


## 屏幕顶部组合技激活横幅。
## text: 横幅文字；duration: 显示时长（秒）；is_team: 是否全队激活（影响样式+震动）。
static func show_combo_activate_banner(text: String, duration: float = 2.0, is_team: bool = false) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var hud := tree.root.get_node_or_null("Main/HudLayer")
	if hud == null:
		return
	# 防重复：同名横幅未消失则跳过
	if hud.has_node("ComboActivateBanner"):
		return
	var banner := Label.new()
	banner.name = "ComboActivateBanner"
	banner.text = text
	var banner_w: float = 400.0
	banner.size = Vector2(banner_w, 36)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 18 if is_team else 14)
	banner.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6, 1))
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	banner.add_theme_constant_override("outline_size", 3)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(banner)
	# v9.x：动态居中 x（原硬编码 440 = (1280-400)/2，stretch/缩放时不居中）。
	# 必须在 add_child 后取 viewport（之前 banner 未入树，get_viewport() 返回 null）。
	# y 起点 -40 保持（与下方 tween 的 position:y 动画解耦，不受影响）。
	var vp_w: float = 1280.0
	var vp := banner.get_viewport()
	if vp != null:
		vp_w = vp.get_visible_rect().size.x
	banner.position = Vector2((vp_w - banner_w) * 0.5, -40)
	# 入场（从上方滑入 + 淡入）
	var tw := banner.create_tween()
	tw.set_parallel(true)
	tw.tween_property(banner, "position:y", 60.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "modulate:a", 1.0, 0.3)
	# 停留后淡出 + 滑出
	var hold := maxf(duration - 0.6, 0.2)
	tw.chain().tween_interval(hold)
	tw.tween_property(banner, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(banner, "position:y", -20.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): if is_instance_valid(banner): banner.queue_free())
	# 全队激活：轻微震动
	if is_team:
		var cam := tree.root.get_node_or_null("Main/BattleContainer/SubViewportContainer/SubViewport/Battlefield/BattleCamera")
		if cam != null and cam.has_method("shake"):
			cam.call("shake", 3.0, 0.15)


## 光束多重攻击次级射线（套路4 beam_split）。
## 从 target_pos 射向各 secondary_pos，color 同主激光。复用 spawn_laser_beam。
static func spawn_beam_split_arcs(parent: Node2D, target_pos: Vector2,
		secondary_positions: Array, color: Color = Color(0.9, 0.8, 1.0, 0.95)) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	for sp in secondary_positions:
		if sp == null:
			continue
		spawn_laser_beam(parent, target_pos, sp, color)


## 光束反射射线（套路4 beam_reflect）。
## 从 target_pos 反射到 reflect_pos，颜色偏暗。
static func spawn_beam_reflect_arc(parent: Node2D, target_pos: Vector2,
		reflect_pos: Vector2) -> void:
	spawn_laser_beam(parent, target_pos, reflect_pos, Color(0.7, 0.6, 0.9, 0.7))


## 弱点暴露指示器（套路5 weakpoint_expose）。
## 目标头顶红色 X 十字，脉动放大，duration 秒后淡出移除。
## parent 应为目标单位的父节点（让指示器跟随世界坐标）。
## v9.x：改走 _indicator_pool（Node2D 父 + 2 Line2D 子结构池化，子节点保留只重置父）。
static func spawn_weakpoint_indicator(parent: Node2D, pos: Vector2, duration: float = 3.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var marker := _acquire_indicator("weakpoint")
	if marker == null:
		return
	marker.position = pos
	marker.scale = Vector2.ONE
	marker.modulate = Color(1, 1, 1, 1)
	marker.z_index = 30
	parent.add_child(marker)
	# 脉动呼吸
	var pulse := marker.create_tween()
	pulse.set_loops()
	pulse.tween_property(marker, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(marker, "scale", Vector2(0.85, 0.85), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# duration 后淡出移除
	var fade := marker.create_tween()
	fade.tween_interval(duration)
	fade.tween_property(marker, "modulate:a", 0.0, 0.3)
	fade.tween_callback(func(): if is_instance_valid(marker): _release_indicator(marker))
	# 记录 tween 供 release 时 kill（脉动是 loops 无限，淡出完成后 callback 触发 release）
	marker.set_meta("_vfx_tweens", [pulse, fade])


## 雷达锁定圈（套路5 radar_lock）。
## 目标脚下蓝色旋转扫描圈，duration 秒后淡出。
## parent 应为目标单位的父节点。
## v9.x：改走 _indicator_pool。防重复仍用 name 标记（acquire 时设，release 时清）。
static func spawn_radar_lock_ring(parent: Node2D, pos: Vector2, duration: float = 6.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	# 防重复：同一位置已有雷达圈则跳过（用 name 标记）
	var ring_name := "combo_radar_lock_%d_%d" % [int(pos.x), int(pos.y)]
	if parent.has_node(ring_name):
		return
	var poly: Polygon2D = _acquire_indicator("radar_lock")
	if poly == null:
		return
	poly.name = ring_name  # 防重复标记（release 时清除，避免池中残留 name 干扰 has_node）
	poly.position = Vector2(pos.x, pos.y + 18)  # 脚下
	poly.scale = Vector2.ONE
	poly.rotation = 0.0
	poly.modulate = Color(1, 1, 1, 1)
	poly.color = Color(0.35, 0.88, 1.0, 0.35)
	poly.z_index = 15
	parent.add_child(poly)
	# 缓慢旋转
	var rot_tw := poly.create_tween()
	rot_tw.set_loops()
	rot_tw.tween_property(poly, "rotation", TAU, 4.0).set_trans(Tween.TRANS_LINEAR)
	# duration 后淡出
	var fade_tw := poly.create_tween()
	fade_tw.tween_interval(duration)
	fade_tw.tween_property(poly, "modulate:a", 0.0, 0.5)
	fade_tw.tween_callback(func(): if is_instance_valid(poly): _release_indicator(poly))
	poly.set_meta("_vfx_tweens", [rot_tw, fade_tw])


## 激光谐振标记环（套路4 laser_resonance）。
## 目标头顶白色光环，层数越多越亮。持续 5s（与谐振 meta 同步刷新）。
## v9.x：改走 _indicator_pool。
static func spawn_resonance_ring(parent: Node2D, pos: Vector2, stacks: int, duration: float = 5.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if stacks <= 0:
		return
	var ring: Polygon2D = _acquire_indicator("resonance")
	if ring == null:
		return
	ring.position = Vector2(pos.x, pos.y - 30)  # 头顶
	ring.scale = Vector2.ONE
	ring.modulate = Color(1, 1, 1, 1)
	var alpha: float = clampf(0.25 + stacks * 0.08, 0.25, 0.8)
	ring.color = Color(0.9, 0.8, 1.0, alpha)
	ring.z_index = 28
	parent.add_child(ring)
	# 脉动
	var pulse := ring.create_tween()
	pulse.set_loops()
	pulse.tween_property(ring, "scale", Vector2(1.15, 1.15), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(ring, "scale", Vector2(0.9, 0.9), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# duration 后淡出
	var fade := ring.create_tween()
	fade.tween_interval(duration)
	fade.tween_property(ring, "modulate:a", 0.0, 0.3)
	fade.tween_callback(func(): if is_instance_valid(ring): _release_indicator(ring))
	ring.set_meta("_vfx_tweens", [pulse, fade])


# =========================================================================
## v9.x: 组合技指示器对象池（acquire/release + 三种 kind 的节点构造）
# =========================================================================

## 从指示器池取一个节点（按 kind）。池空或达上限则新建；满则返回 null 节流。
## kind: "weakpoint"(Node2D+2Line2D子) / "radar_lock"(Polygon2D) / "resonance"(Polygon2D)
## 返回的节点已剥离残留 parent、kill 残留 tween、重置 transform/modulate。
static func _acquire_indicator(kind: String) -> Node2D:
	var pool: Array = _indicator_pool.get(kind, [])
	# 从池尾向前取，首个有效节点返回
	var i := pool.size() - 1
	while i >= 0:
		var candidate: Node = pool[i]
		pool.remove_at(i)
		if candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			# 剥离残留 parent（防 add_child "already has a parent"）
			if candidate.get_parent() != null:
				candidate.get_parent().remove_child(candidate)
			# kill 残留 tween（脉动 loops + 淡出，复用时重建）
			_kill_indicator_tweens(candidate)
			# 重置通用状态
			candidate.visible = true
			candidate.modulate = Color(1, 1, 1, 1)
			candidate.scale = Vector2.ONE
			candidate.rotation = 0.0
			# radar_lock 带 name 防重复标记，acquire 时清除（由 spawn 重设）
			if not candidate.name.is_empty() and candidate.name.begins_with("combo_radar_lock_"):
				candidate.name = ""
			_indicator_pool[kind] = pool
			_active_indicators += 1
			return candidate
		i -= 1
	_indicator_pool[kind] = pool
	# 池空：检查全局上限
	if _active_indicators >= MAX_INDICATORS:
		return null  # 节流
	_active_indicators += 1
	# 按 kind 新建对应结构
	return _create_indicator(kind)


## 新建一个指示器节点（首次或池扩容时）。
## 所有新建节点都 set_meta("_vfx_kind", kind)，_release_indicator 据此归还对应池。
static func _create_indicator(kind: String) -> Node2D:
	match kind:
		"weakpoint":
			# Node2D 父 + 2 Line2D 子（X 十字），子节点配置固定，池化时保留只重置父
			var marker := Node2D.new()
			marker.set_meta("_vfx_kind", kind)
			var line_a := Line2D.new()
			line_a.width = 3.0
			line_a.default_color = Color(1.0, 0.3, 0.2, 1.0)
			line_a.joint_mode = Line2D.LINE_JOINT_ROUND
			line_a.end_cap_mode = Line2D.LINE_CAP_ROUND
			line_a.add_point(Vector2(-14, -14))
			line_a.add_point(Vector2(14, 14))
			marker.add_child(line_a)
			var line_b := Line2D.new()
			line_b.width = 3.0
			line_b.default_color = Color(1.0, 0.3, 0.2, 1.0)
			line_b.joint_mode = Line2D.LINE_JOINT_ROUND
			line_b.end_cap_mode = Line2D.LINE_CAP_ROUND
			line_b.add_point(Vector2(-14, 14))
			line_b.add_point(Vector2(14, -14))
			marker.add_child(line_b)
			return marker
		"radar_lock":
			# 雷达锁定圈：28 段实心圆（半径 30），ADD 混合。顶点固定，池化时只重设 color/position。
			var poly := Polygon2D.new()
			poly.set_meta("_vfx_kind", kind)
			poly.material = _get_add_mat()
			poly.polygon = _build_circle_polygon(28, 30.0)
			return poly
		"resonance":
			# 谐振环：24 段实心圆（半径 16），ADD 混合。顶点固定。
			var poly := Polygon2D.new()
			poly.set_meta("_vfx_kind", kind)
			poly.material = _get_add_mat()
			poly.polygon = _build_circle_polygon(24, 16.0)
			return poly
		_:
			# 未知 kind 兜底：返回普通 Node2D（不应发生）
			var fallback := Node2D.new()
			fallback.set_meta("_vfx_kind", "resonance")
			return fallback


## 归还指示器到池。kill 所有 tween、移除 parent、清 name、归还对应 kind 池。
## 设计与 _release_ring 一致：失效节点直接返回不操作（不计入 active，避免计数变负）。
## 指示器生命周期长（3-6s），战斗拆卸时 fade callback 可能不触发 → 计数有慢速泄漏风险，
## 但与现有 ring/spark 池同等行为，且泄漏只导致节流（不崩溃），可接受。
static func _release_indicator(node: Node2D) -> void:
	if node == null or not is_instance_valid(node):
		return  # 失效节点：不操作（不计入 active，避免计数变负）
	# kill 该节点所有 tween（通过 _vfx_tweens meta 记录的引用）
	_kill_indicator_tweens(node)
	# 移除 parent
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	# 清 name（radar_lock 防重复标记），避免池中残留 name 干扰下次 has_node 检查
	if not node.name.is_empty() and node.name.begins_with("combo_radar_lock_"):
		node.name = ""
	node.visible = false
	# 按 _vfx_kind meta 归还对应池
	var kind: String = node.get_meta("_vfx_kind", "")
	if kind.is_empty():
		kind = "resonance"  # 兜底（未知 kind 归到最简单的 resonance 池）
	var pool: Array = _indicator_pool.get(kind, [])
	if pool.size() < MAX_INDICATORS:
		pool.append(node)
		_indicator_pool[kind] = pool
	else:
		node.queue_free()
	_active_indicators -= 1


## kill 指示器节点记录的所有 tween（_vfx_tweens meta），清 meta。
## 脉动 tween 是 set_loops() 无限循环，release 时若不 kill 会继续跑并泄露。
static func _kill_indicator_tweens(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_meta("_vfx_tweens"):
		var tweens: Array = node.get_meta("_vfx_tweens", [])
		for tw in tweens:
			if tw is Tween and (tw as Tween).is_valid():
				(tw as Tween).kill()
		node.remove_meta("_vfx_tweens")


## 构建实心圆 Polygon2D 顶点数组（segments 段，radius 半径）。
## 供 radar_lock / resonance 指示器建顶点用（顶点固定，池化时不重建）。
static func _build_circle_polygon(segments: int, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var ang := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	return pts


## v9.x：战斗结束时重置指示器池（由 BattleManager.end_battle 调用）。
## 解决长生命周期指示器（3-6s）的计数泄漏：战斗中途结束/场景拆卸时 fade callback
## 可能不触发，节点被外部 free 而 _active_indicators 未 -1，累积多场后池被永久锁死。
## 本方法：① free 池中所有归还节点 ② 清空池 ③ 计数归零。
## 仍在场景树中活跃的指示器（未淡出）由场景树拆卸自然回收，不在此强行清理——
## reset 后计数归零即允许下场战斗重新分配，不再因计数泄漏阻塞节流。
static func reset_indicator_pool() -> void:
	for kind in _INDICATOR_KINDS:
		var pool: Array = _indicator_pool.get(kind, [])
		for node in pool:
			if node != null and is_instance_valid(node):
				node.queue_free()
		_indicator_pool[kind] = []
	_active_indicators = 0
