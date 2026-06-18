extends Node2D
## 子弹/激光/导弹等：按武器类型显示不同攻击动画，飞向目标造成伤害

const GC = preload("res://resources/game_constants.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const ActiveLawEffects = preload("res://managers/active_law_effects.gd")
const CardAbilityManager = preload("res://managers/card_ability_manager.gd")
const CardGridFx = preload("res://scripts/card_grid_fx.gd")
const WeaponProjectileVfx = preload("res://scripts/weapon_projectile_vfx.gd")
const AttackCalculator = preload("res://scripts/battle/attack_calculator.gd")
const RuneSpecialHandler = preload("res://managers/rune_special_handler.gd")
## 曲射弹道：炮口火焰和命中爆炸特效纹理（预加载，避免运行时 ResourceLoader.load 卡顿）
const ARTILLERY_MUZZLE_TEX := preload("res://assets/effects/projectiles/weapons_realistic/weapon_artillery_muzzle.png")
const ARTILLERY_IMPACT_TEX := preload("res://assets/effects/projectiles/weapons_realistic/weapon_artillery_impact.png")
## v6.4: 重型武器拖尾贴图（曲射/爆炸类），复用 omega_platform 拖尾资源
const HEAVY_TRAIL_TEX := preload("res://assets/effects/projectiles/omega_platform/omega_platform_projectile_trail.png")
## 启用拖尾的重型武器类型：INDIRECT(1)/AERIAL(2)/ROCKET(3)/FLAK(7)/MISSILE(9)/OMEGA(10)/RAIL(11)
const HEAVY_TRAIL_WEAPON_TYPES: Array = [1, 2, 3, 7, 9, 10, 11]
# ObjectPoolManager 为 autoload

var speed: float = 600.0
var damage: float = 5.0
var target: Node2D = null
var shooter_is_player: bool = true
var max_distance: float = 1600.0
var weapon_type: int = 0
var shooter: Node2D = null  # 射手引用（用于词条效果）
var shooter_stats: UnitStats = null  # 射手数值（用于词条效果计算）
## 超射程「哑弹」：飞过但不造成伤害（仍可对卡牌模式播放擦弹表现）
var forced_miss: bool = false
var _pre_calculated: bool = false  # 伤害已完整计算（防御/强化不再重复）
var _weapon_name: String = ""  # v6.0: 武器名（用于 VFX 贴图查找）
## v6.4: 重型武器标记（曲射/爆炸类启用拖尾与炮口火焰）
var _is_heavy: bool = false

# 行为参数：由武器类型决定
var pierce_count: int = 0          # 可额外穿透多少个目标（LASER/SNIPER 用）
var explosion_radius: float = 0.0  # >0 时命中产生范围伤害（ROCKET/MISSILE/FLAK）
var pellet_count: int = 1          # 霰弹多发
var spread_angle_deg: float = 0.0  # 多发散射角

## 曲射（INDIRECT）弹道参数
var _is_indirect: bool = false
var _indirect_apex: float = 200.0      # 抛物线顶点高度（相对于起点和目标连线）
var _indirect_progress: float = 0.0    # 0→1 飞行进度
var _indirect_duration: float = 1.2    # 全程飞行时间（秒）
var _indirect_start: Vector2           # 起点位置
var _indirect_end: Vector2             # 目标位置
var _indirect_prev_pos: Vector2  # 上一帧位置（用于计算朝向）
var _muzzle_spawned: bool = false      # 是否已生成炮口火焰
var _impact_spawned: bool = false      # 是否已生成爆炸效果

var _finished: bool = false  # 防重复归还：_finish_tex_bullet 幂等守卫
var _start_position: Vector2
var _sprite: Polygon2D
var _beam_line: Line2D
var _tex_sprite: Sprite2D
var _trail_sprite: Sprite2D
var _use_tex_sprite: bool = false
var _direction: Vector2 = Vector2.RIGHT
var _beam_visual_phase: int = 0
const BEAM_VISUAL_LEN: float = 52.0
var _beam_pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])

## v6.4: 弹道发光叠加材质（与轻武器/曲射批处理一致），所有视觉节点共享同一实例
static var _add_blend_mat: CanvasItemMaterial

static func _get_add_blend_mat() -> CanvasItemMaterial:
	if _add_blend_mat == null:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_add_blend_mat = m
	return _add_blend_mat


func _apply_shield_wall_mitigation(raw_damage: float, target: Node) -> float:
	if target == null or not is_instance_valid(target):
		return raw_damage
	# 护盾墙主要保护我方单位/基地，且只对敌方射弹生效
	if shooter_is_player:
		return raw_damage
	if not (target is CharacterBody2D or target.is_in_group("phase_driver")):
		return raw_damage
	var mitigation: float = ActiveLawEffects.get_shield_wall_mitigation_for_point(target.global_position, "ALLY")
	if mitigation <= 0.0:
		return raw_damage
	return raw_damage * (1.0 - mitigation)

func setup(p_target: Node2D, p_damage: float, p_is_player: bool, p_weapon_type: int = -1, p_shooter: Node2D = null, p_shooter_stats: UnitStats = null, p_forced_miss: bool = false, p_weapon_name: String = "", p_pre_calculated: bool = false) -> void:
	visible = true
	_finished = false  # 复用：清除归还守卫
	target = p_target
	damage = p_damage
	shooter_is_player = p_is_player
	shooter = p_shooter
	shooter_stats = p_shooter_stats
	forced_miss = p_forced_miss
	_weapon_name = p_weapon_name
	_pre_calculated = p_pre_calculated
	if p_weapon_type >= 0:
		weapon_type = p_weapon_type
	_start_position = global_position
	_direction = Vector2.RIGHT
	_sprite = get_node_or_null("Sprite") as Polygon2D
	_beam_line = get_node_or_null("BeamLine") as Line2D
	_tex_sprite = get_node_or_null("TexSprite") as Sprite2D
	_trail_sprite = get_node_or_null("TrailSprite") as Sprite2D
	_apply_visual()
	_configure_behavior()
	_beam_visual_phase = 0

func _configure_behavior() -> void:
	# 基础：大多数子弹直线追踪目标
	speed = 600.0
	max_distance = 1600.0
	pierce_count = 0
	explosion_radius = 0.0
	pellet_count = 1
	spread_angle_deg = 0.0
	# v6.4: 重型武器启用拖尾
	_is_heavy = weapon_type in HEAVY_TRAIL_WEAPON_TYPES

	match weapon_type:
		0, 4:
			speed = 720.0
			max_distance = 1200.0
		1:  # INDIRECT (新枚举)
			speed = 800.0
			max_distance = 1600.0
			_is_indirect = true
		2:  # AERIAL (新枚举)
			speed = 680.0
			max_distance = 1400.0
			_is_indirect = true
		5:
			speed = 650.0
			max_distance = 900.0
			pellet_count = 6
			spread_angle_deg = 18.0
		6:
			speed = 1100.0
			max_distance = 2200.0
			pierce_count = 1
		8:
			speed = 1400.0
			max_distance = 2200.0
			pierce_count = 3
		3:
			speed = 420.0
			max_distance = 2000.0
			explosion_radius = 40.0
			## 曲射武器：使用抛物线弹道
			_is_indirect = true
		9:
			speed = 380.0
			max_distance = 2300.0
			explosion_radius = 55.0
			_is_indirect = true
		7:
			speed = 520.0
			max_distance = 1500.0
			explosion_radius = 36.0
			_is_indirect = true
		11:  # RAIL_CANNON
			speed = 560.0
			max_distance = 2500.0
			explosion_radius = 58.0
			pierce_count = 1
		10:  # OMEGA_CANNON
			speed = 520.0
			max_distance = 2600.0
			explosion_radius = 70.0
			pierce_count = 2

	# 霰弹：在本弹上直接设置随机初始方向偏移
	if pellet_count > 1:
		var base_dir := Vector2.RIGHT
		if target and is_instance_valid(target):
			base_dir = (target.global_position - global_position).normalized()
		var half_spread := spread_angle_deg * 0.5
		var rand_angle := randf_range(-half_spread, half_spread)
		_direction = base_dir.rotated(deg_to_rad(rand_angle))
	else:
		if target and is_instance_valid(target):
			_direction = (target.global_position - global_position).normalized()

func _apply_visual() -> void:
	var is_player: bool = shooter_is_player
	# v6.4: 弹道发光叠加（与轻武器/曲射批处理保持一致）
	var blend_mat := _get_add_blend_mat()
	if _sprite:
		_sprite.material = blend_mat
	if _beam_line:
		_beam_line.material = blend_mat
	_use_tex_sprite = WeaponProjectileVfx.has_proj_texture(weapon_type)
	if _use_tex_sprite:
		_apply_tex_sprite_visual(is_player)
		return
	_hide_tex_sprite_visual()
	var bullet_color: Color
	var beam_color: Color
	var use_beam: bool = false
	var size_scale: float = 1.0
	match weapon_type:
		0, 4:
			bullet_color = Color(0.95, 0.9, 0.3) if is_player else Color(1, 0.4, 0.2)
			size_scale = 0.8
		1, 2:
			bullet_color = Color(0.85, 0.85, 0.9) if is_player else Color(0.9, 0.5, 0.3)
			size_scale = 1.0
		5:
			bullet_color = Color(0.9, 0.85, 0.5) if is_player else Color(1, 0.5, 0.2)
			size_scale = 1.2
		6:
			use_beam = true
			beam_color = Color(0.4, 0.9, 1) if is_player else Color(1, 0.5, 0.4)
		8:
			use_beam = true
			beam_color = Color(0.2, 0.85, 1) if is_player else Color(1, 0.3, 0.6)
		3, 9:
			bullet_color = Color(0.9, 0.5, 0.1) if is_player else Color(1, 0.35, 0.15)
			size_scale = 1.8
		7:
			bullet_color = Color(0.8, 0.75, 0.6) if is_player else Color(0.95, 0.6, 0.3)
			size_scale = 0.6
		11:  # RAIL_CANNON
			bullet_color = Color(0.5, 0.55, 1) if is_player else Color(1, 0.25, 0.45)
			size_scale = 1.85
		_:
			bullet_color = Color(0.9, 0.9, 0.95) if is_player else Color(0.9, 0.35, 0.25)
	if _sprite:
		_sprite.visible = not use_beam
		if not use_beam:
			_sprite.color = bullet_color
			var pts: PackedVector2Array = PackedVector2Array([Vector2(-2,-2)*size_scale, Vector2(4,0)*size_scale, Vector2(-2,2)*size_scale])
			_sprite.polygon = pts
	if _beam_line:
		_beam_line.visible = use_beam
		if use_beam:
			_beam_line.default_color = beam_color
			_beam_line.width = 3.0 if weapon_type == 6 else 4.5


func _apply_tex_sprite_visual(is_player: bool) -> void:
	if _sprite:
		_sprite.visible = false
	if _beam_line:
		_beam_line.visible = false
	var tint := Color.WHITE if is_player else Color(1.0, 0.38, 0.52)
	# v6.0: 优先使用武器名查贴图
	var sc: float
	var tex: Texture2D
	if not _weapon_name.is_empty():
		tex = WeaponProjectileVfx.proj_texture_by_name(_weapon_name)
		sc = WeaponProjectileVfx.proj_scale_by_name(_weapon_name)
	if tex == null:
		tex = WeaponProjectileVfx.proj_texture(weapon_type)
		sc = WeaponProjectileVfx.proj_scale(weapon_type)
	if _tex_sprite:
		_tex_sprite.visible = true
		_tex_sprite.texture = tex
		_tex_sprite.scale = Vector2(sc, sc)
		_tex_sprite.modulate = tint
		# v6.4: 贴图弹道发光叠加
		_tex_sprite.material = _get_add_blend_mat()
	_apply_trail()


func _hide_tex_sprite_visual() -> void:
	if _tex_sprite:
		_tex_sprite.visible = false
	_apply_trail()


## v6.4: 重型武器拖尾配置（仅在 _is_heavy 时启用，否则隐藏）
## 拖尾贴图置于弹体后方，运行时随 _direction 旋转（见 _process / _process_indirect）
func _apply_trail() -> void:
	if _trail_sprite == null:
		return
	if not _is_heavy:
		_trail_sprite.visible = false
		return
	_trail_sprite.visible = true
	_trail_sprite.texture = HEAVY_TRAIL_TEX
	_trail_sprite.centered = true
	# 拖尾贴图较大，统一缩放到与弹体视觉匹配的尺寸
	_trail_sprite.scale = Vector2(0.35, 0.35)
	_trail_sprite.modulate = Color.WHITE if shooter_is_player else Color(1.0, 0.55, 0.45)
	_trail_sprite.material = _get_add_blend_mat()
	# 初始方向朝右（与 _direction 默认一致），运行时由 _update_trail_transform 旋转
	_trail_sprite.rotation = 0.0
	_trail_sprite.position = Vector2.ZERO


## v6.4: 每帧更新拖尾朝向。Bullet 节点已旋转到 _direction，
## 拖尾作为子节点继承父旋转，故只需固定向弹体后方（局部 -X）偏移。
func _update_trail_transform() -> void:
	if _trail_sprite == null or not _trail_sprite.visible:
		return
	# 拖尾贴图尾部在弹体后方，约 -28px（基于 0.35 缩放）
	_trail_sprite.rotation = PI  # 贴图朝右，旋转 180° 使其向弹体后方延伸
	_trail_sprite.position = Vector2(-28.0, 0.0)


## v6.1 性能优化：轻武器跳过命中特效
## 旧枚举: SMG=0, RIFLE=1, MG=2, PISTOL=4 → 跳过（高速直射已有弹体动画）
## 新枚举: DIRECT=0 → 跳过；INDIRECT=1 和 AERIAL=2 → 必须有爆炸效果
## 因此跳过列表只包含旧枚举值 0(SMG)、4(PISTOL)
const _SKIP_IMPACT_WEAPON_TYPES: Array = [0, 4]

func _spawn_tex_impact_at(world_pos: Vector2) -> void:
	if weapon_type in _SKIP_IMPACT_WEAPON_TYPES:
		return
	var parent := get_parent()
	if parent == null:
		return

	# 曲射/空射/火箭/导弹 → 使用完整爆炸特效
	# 新枚举: INDIRECT=1, AERIAL=2
	# 旧枚举: ROCKET=3, FLAK=7, MISSILE=9
	if weapon_type in [1, 2, 3, 7, 9]:  # INDIRECT, AERIAL, ROCKET, FLAK, MISSILE
		_spawn_impact_explosion(world_pos)
		return

	# v6.0: 武器名查 VFX → 旧 weapon_type 回退
	if not _weapon_name.is_empty():
		_spawn_impact_v2(parent, world_pos, _weapon_name)
	else:
		WeaponProjectileVfx.spawn_impact(parent, world_pos, weapon_type, shooter_is_player)


## v6.0: 新版命中特效（按武器名）— 使用 WeaponProjectileVfx 对象池
func _spawn_impact_v2(parent: Node2D, world_pos: Vector2, weapon_name: String) -> void:
	var tex: Texture2D = WeaponProjectileVfx.impact_texture_by_name(weapon_name)
	if tex == null:
		return
	if WeaponProjectileVfx._active_impacts >= WeaponProjectileVfx.MAX_ACTIVE_IMPACTS:
		return
	WeaponProjectileVfx._active_impacts += 1
	var fx: Sprite2D = WeaponProjectileVfx._acquire_impact_sprite()
	fx.texture = tex
	fx.centered = true
	var sc := WeaponProjectileVfx.impact_scale_by_name(weapon_name)
	fx.scale = Vector2.ONE * sc
	fx.global_position = world_pos
	if not shooter_is_player:
		fx.modulate = Color(1.0, 0.45, 0.55)
	parent.add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", fx.scale * 1.22, 0.07)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.20)
	tw.finished.connect(func(): WeaponProjectileVfx._release_impact_sprite(fx))


func _finish_tex_bullet() -> void:
	if _finished:
		return
	_finished = true
	ObjectPoolManager.return_object("bullets", self)


func _process(delta: float) -> void:
	# 曲射弹道：抛物线飞行
	if _is_indirect:
		_process_indirect(delta)
		return
	# 目标死亡时：直接消失（曲射由 _process_indirect 单独处理）
	if target == null or not is_instance_valid(target):
		_finish_tex_bullet()
		return
	else:
		# 激光/狙击等保持精准指向目标，其他武器略带跟踪
		if weapon_type in [8, 6, 9]:
			_direction = (target.global_position - global_position).normalized()
		else:
			var desired := (target.global_position - global_position).normalized()
			_direction = _direction.lerp(desired, 1.0 - exp(-4.5 * delta)).normalized()
		global_position += _direction * speed * delta
	if _use_tex_sprite:
		rotation = _direction.angle()
	# v6.4: 重型武器拖尾跟随飞行方向（直射类，如 RAIL/OMEGA）
	_update_trail_transform()
	# 光束类：每 3 帧更新线段（命中判定仍每帧）
	if _beam_line and _beam_line.visible:
		if _beam_visual_phase % 3 == 0:
			var tail_world: Vector2 = global_position - _direction.normalized() * BEAM_VISUAL_LEN
			_beam_pts.set(0, to_local(tail_world))
			_beam_pts.set(1, Vector2.ZERO)
			_beam_line.points = _beam_pts
		_beam_visual_phase += 1
	var max_d2: float = max_distance * max_distance
	if global_position.distance_squared_to(_start_position) > max_d2:
		_finish_tex_bullet()
		return
	if target and is_instance_valid(target) and global_position.distance_squared_to(target.global_position) < 100.0:
		_on_hit(target)

## v6.5: 不同曲射武器的弧线高度倍率
## 迫击炮最高弧线（高抛物线），火箭筒最低弧线（接近平射）
static func _get_indirect_arc_multiplier(wt: int) -> float:
	match wt:
		1:   # INDIRECT 迫击炮/野战炮 — 高弧线
			return 1.6
		7:   # FLAK 高射炮 — 较高弧线
			return 1.3
		9:   # MISSILE 导弹 — 中等弧线（默认基准）
			return 1.0
		2:   # AERIAL 空射 — 低弧线（俯冲）
			return 0.5
		3:   # ROCKET 火箭筒 — 最低弧线（直瞄反坦克）
			return 0.3
		_:
			return 1.0


func _process_indirect(delta: float) -> void:
	## 曲射（INDIRECT）弹道：抛物线飞行
	## 初始化（仅第一帧执行）
	if _indirect_progress == 0.0:
		_indirect_start = global_position
		_indirect_end = target.global_position if target and is_instance_valid(target) else global_position + _direction * 500.0
		_muzzle_spawned = false
		_impact_spawned = false
		# 根据距离计算飞行时间
		var dist = _indirect_start.distance_to(_indirect_end)
		_indirect_duration = 0.6 + dist / 2000.0 * 0.8  # 0.6~1.4秒
		# v6.5: 不同曲射武器的弧线高低不同（按 weapon_type 差异化）
		# 基础弧线 = 100 + dist × 0.25，再乘以武器弧线倍率
		_indirect_apex = (100.0 + dist * 0.25) * _get_indirect_arc_multiplier(weapon_type)

	# 记录旧位置，用于计算朝向
	_indirect_prev_pos = global_position

	_indirect_progress += delta / _indirect_duration
	if _indirect_progress >= 1.0:
		_indirect_progress = 1.0
		# 命中目标
		if target and is_instance_valid(target):
			# 命中特效在弹道落点（global_position），避免与移动目标视觉脱节
			_spawn_tex_impact_at(global_position)
			_on_hit(target)
		_finish_tex_bullet()
		return

	# 计算抛物线位置（二次贝塞尔曲线）
	var t = _indirect_progress
	var mid := (_indirect_start + _indirect_end) * 0.5
	var apex_point := mid + Vector2.UP * _indirect_apex

	global_position = (1.0 - t) * (1.0 - t) * _indirect_start + 2.0 * (1.0 - t) * t * apex_point + t * t * _indirect_end

	# 计算朝向：用移动方向（只需一次 Vector2 减法，无额外贝塞尔计算）
	_direction = (global_position - _indirect_prev_pos).normalized() if global_position != _indirect_prev_pos else _direction

	# v6.4: 曲射发射炮口火焰（仅首帧，重型武器）
	if not _muzzle_spawned:
		_muzzle_spawned = true
		if _is_heavy:
			_spawn_muzzle_effect(_indirect_start)

	# v6.4: 曲射弹道拖尾跟随飞行切线方向
	_update_trail_transform()

	# 更新朝向（Sprite2D 旋转）
	if _use_tex_sprite:
		rotation = _direction.angle()

	# 目标死亡：沿抛物线继续飞完
	if target == null or not is_instance_valid(target):
		pass

func _spawn_muzzle_effect(pos: Vector2) -> void:
	if ARTILLERY_MUZZLE_TEX == null:
		return
	WeaponProjectileVfx._active_impacts += 1
	var fx: Sprite2D = WeaponProjectileVfx._acquire_impact_sprite()
	fx.texture = ARTILLERY_MUZZLE_TEX
	fx.centered = true
	fx.scale = Vector2(0.60, 0.60)
	fx.global_position = pos
	if not shooter_is_player:
		fx.scale.x = -fx.scale.x
	get_parent().add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", fx.scale * 1.3, 0.12)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.25)
	tw.finished.connect(func(): WeaponProjectileVfx._release_impact_sprite(fx))

func _spawn_impact_explosion(pos: Vector2) -> void:
	if ARTILLERY_IMPACT_TEX == null:
		return
	WeaponProjectileVfx._active_impacts += 1
	var fx: Sprite2D = WeaponProjectileVfx._acquire_impact_sprite()
	fx.texture = ARTILLERY_IMPACT_TEX
	fx.centered = true
	fx.scale = Vector2(0.75, 0.75)
	fx.global_position = pos
	if not shooter_is_player:
		fx.scale.x = -fx.scale.x
	get_parent().add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", fx.scale * 1.5, 0.15)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.3)
	tw.finished.connect(func(): WeaponProjectileVfx._release_impact_sprite(fx))


## v6.4: 命中时触发屏幕震动——曲射/爆炸类中震动，直射轻震动
func _request_hit_shake() -> void:
	if BattleManager == null or not is_instance_valid(BattleManager):
		return
	if not BattleManager.has_method("request_screen_shake"):
		return
	if _is_indirect or explosion_radius > 0.0:
		BattleManager.request_screen_shake(5.0, 0.25)
	else:
		BattleManager.request_screen_shake(1.8, 0.1)


## 爆炸/溅射候选：优先空间网格，避免遍历父节点下全部子节点。
func _get_aoe_damage_targets(center: Vector2, radius: float, primary: Node2D) -> Array:
	var targets: Array = []
	var r2: float = radius * radius
	var tree := get_tree()
	var bm: Node = tree.root.get_node_or_null("BattleManager") if tree else null
	if bm != null and is_instance_valid(bm) and bm.get("battle_active") == true:
		var grid: Variant = bm.get("spatial_grid")
		if grid != null and is_instance_valid(grid) and grid.has_method("query_nearby"):
			for node in grid.query_nearby(center, radius):
				if node == primary or not is_instance_valid(node):
					continue
				if not (node is Node2D):
					continue
				if not node.has_method("take_damage"):
					continue
				if node.global_position.distance_squared_to(center) > r2:
					continue
				targets.append(node)
			return targets
	if primary.get_parent():
		var parent := primary.get_parent()
		for child in parent.get_children():
			if child == primary:
				continue
			if child is Node2D and child.has_method("take_damage"):
				if child.global_position.distance_squared_to(center) <= r2:
					targets.append(child)
	return targets

func _on_hit(primary: Node2D) -> void:
	if forced_miss:
		var miss_pos: Vector2 = primary.global_position if primary else global_position
		CombatFeedback.show_miss(miss_pos, primary)
		if _use_tex_sprite:
			_spawn_tex_impact_at(miss_pos)
		elif GameManager and GameManager.has_method("is_card_grid_battle") and GameManager.is_card_grid_battle():
			var root := get_parent() as Node2D
			if root != null:
				CardGridFx.spawn_impact(root, miss_pos, weapon_type)
		_finish_tex_bullet()
		return
	if not _use_tex_sprite and GameManager and GameManager.has_method("is_card_grid_battle") and GameManager.is_card_grid_battle():
		var root2 := get_parent() as Node2D
		if root2 != null:
			CardGridFx.spawn_impact(root2, primary.global_position if primary else global_position, weapon_type)
	# 如果没有射手数值信息，使用基础伤害逻辑
	if shooter_stats == null:
		_on_hit_basic(primary)
		return

	# 格子战：百分比护甲减伤与闪避在 take_damage（CardGridDamage）结算；穿甲仍作用于 shooter_stats
	var defender_reduction: float = 0.0
	if GameManager == null or not GameManager.is_card_grid_battle():
		defender_reduction = primary.damage_reduction if primary != null and "damage_reduction" in primary else 0.0
	# v5.0: 击穿检查 + 三维防御减免（仅当伤害未预计算时）
	if not _pre_calculated:
		var primary_stats: UnitStats = primary.get("stats") as UnitStats if primary != null else null
		if primary_stats != null and shooter_stats != null:
			# v6.2: 攻防维度对齐——按攻击者单位类型选防御值
			var def_val: float = AttackCalculator.get_defense_vs(primary_stats, shooter_stats.combat_kind)
		# 修复：统一应用防御减免，移除错误的击穿跳过逻辑
			damage = damage * (100.0 / (100.0 + def_val))
		# 强化加成
		if shooter_stats != null and shooter_stats.enhance_level > 0:
			var enhance_mult: float
			if shooter_stats.enhance_level >= 10:
				enhance_mult = 1.60
			elif shooter_stats.enhance_level >= 9:
				enhance_mult = 1.50
			else:
				enhance_mult = 1.0 + float(shooter_stats.enhance_level) * 0.05
			damage *= enhance_mult
	# 词缀战斗效果已移除：直接使用已计算的 damage 值
	var final_damage: float = damage * (1.0 - defender_reduction)
	# v6.3: 真实暴击判定（基于 crit_chance；基础1.5x + crit_damage_bonus 每级+0.2x）
	var is_crit: bool = false
	if shooter_stats.crit_chance > 0.0 and randf() < shooter_stats.crit_chance:
		is_crit = true
		final_damage *= (1.5 + shooter_stats.crit_damage_bonus)

	# 武器伤害变异：15% 概率双倍伤害
	if shooter_stats.has_weapon_dmg_mutation and randf() < 0.15:
		final_damage *= 2.0

	# 卡牌特殊能力：命中前修改伤害（射手节点已释放时禁止传入 on_bullet_hit 的 Node2D 形参）
	var ability_result: Dictionary = {"damage_bonus": 0.0, "damage_mult_bonus": 0.0}
	if is_instance_valid(shooter):
		ability_result = CardAbilityManager.on_bullet_hit(
			shooter, primary, shooter_stats, global_position,
			damage, final_damage, shooter_is_player
		)
	final_damage += ability_result["damage_bonus"]
	final_damage *= (1.0 + ability_result["damage_mult_bonus"])

	# 范围伤害
	if explosion_radius > 0.0:
		for child in _get_aoe_damage_targets(global_position, explosion_radius, primary):
			var splash_red: float = 0.0
			if GameManager == null or not GameManager.is_card_grid_battle():
				splash_red = child.damage_reduction if child != null and "damage_reduction" in child else 0.0
			var splash_base: float = damage * shooter_stats.splash_damage
			# v5.0: 溅射目标也做击穿检查+防御减免
			var child_stats: UnitStats = child.get("stats") as UnitStats if child != null else null
			if child_stats != null and shooter_stats != null:
				# v6.2: 攻防维度对齐——按攻击者单位类型选防御值
				var child_def: float = AttackCalculator.get_defense_vs(child_stats, shooter_stats.combat_kind)
				if splash_base > child_def:
					splash_base = splash_base * (100.0 / (100.0 + child_def))
				else:
					splash_base = 0.0
			if splash_base <= 0.0:
				continue
			var splash_damage: float = _apply_shield_wall_mitigation(splash_base * (1.0 - splash_red), child)
			var atk_splash: Variant = shooter if is_instance_valid(shooter) else null
			child.take_damage(splash_damage, atk_splash)

	# 直击伤害
	if primary.has_method("take_damage"):
		var final_after_wall: float = _apply_shield_wall_mitigation(final_damage, primary)
		var atk_primary: Variant = shooter if is_instance_valid(shooter) else null
		primary.take_damage(final_after_wall, atk_primary)
		# v6.2: 符文之语特殊效果 — 攻击命中时触发（闪电链/溅射）
		if is_instance_valid(shooter):
			RuneSpecialHandler.on_hit(shooter, primary, final_after_wall)

	# v6.3: 暴击伤害数字（暴击时由弹道直接显示，并通过 meta 标记让 unit_damaged 跳过普通数字，避免双数字）
	if is_crit and is_instance_valid(primary):
		primary.set_meta("_vfx_crit_pending", true)
		CombatFeedback.show_damage(global_position, final_damage, primary, true, "critical")

	# v6.4: 命中屏幕震动（曲射/爆炸中震动，直射轻震动）
	_request_hit_shake()

	# 卡牌特殊能力：命中后施加效果（同上，避免已释放 shooter）
	if is_instance_valid(shooter):
		CardAbilityManager.on_bullet_hit_post(
			shooter, primary, shooter_stats, global_position,
			final_damage, shooter_is_player
		)

	# 穿透：减少一次计数，>0 时继续飞行
	if _use_tex_sprite:
		_spawn_tex_impact_at(primary.global_position if primary else global_position)
	if pierce_count > 0:
		pierce_count -= 1
		return

	_finish_tex_bullet()

## 基础伤害处理（不带词条效果）
func _on_hit_basic(primary: Node2D) -> void:
	if forced_miss:
		_finish_tex_bullet()
		return
	# 范围伤害
	if explosion_radius > 0.0:
		for child in _get_aoe_damage_targets(global_position, explosion_radius, primary):
			var basic_splash: float = _apply_shield_wall_mitigation(damage, child)
			var atk_b: Variant = shooter if is_instance_valid(shooter) else null
			child.take_damage(basic_splash, atk_b)
	# 直击伤害
	if primary.has_method("take_damage"):
		var basic_primary: float = _apply_shield_wall_mitigation(damage, primary)
		var atk_bp: Variant = shooter if is_instance_valid(shooter) else null
		primary.take_damage(basic_primary, atk_bp)
	if _use_tex_sprite:
		_spawn_tex_impact_at(primary.global_position if primary else global_position)
	if pierce_count > 0:
		pierce_count -= 1
		return
	_finish_tex_bullet()

## 对象池：重置子弹状态
func reset_pool_object() -> void:
	# 重置所有状态到初始值
	speed = 600.0
	damage = 5.0
	target = null
	shooter_is_player = true
	max_distance = 1600.0
	weapon_type = 0
	shooter = null
	shooter_stats = null
	forced_miss = false
	_pre_calculated = false

	pierce_count = 0
	explosion_radius = 0.0
	pellet_count = 1
	spread_angle_deg = 0.0
	_is_heavy = false  # v6.4: 重型武器标记重置

	_start_position = Vector2.ZERO
	_direction = Vector2.RIGHT
	_beam_visual_phase = 0
	_use_tex_sprite = false

	# 曲射弹道重置
	_is_indirect = false
	_indirect_progress = 0.0
	_indirect_apex = 200.0
	_indirect_duration = 1.2
	_muzzle_spawned = false
	_impact_spawned = false

	global_position = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE

	_hide_tex_sprite_visual()
	# v6.4: 拖尾节点隐藏（_apply_trail 已由 _hide_tex_sprite_visual 调用，此处兜底）
	if _trail_sprite:
		_trail_sprite.visible = false
	if _sprite:
		_sprite.visible = true
	if _beam_line:
		_beam_line.visible = false

	visible = false
