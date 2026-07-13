extends Node2D
## 子弹/激光/导弹等：按武器类型显示不同攻击动画，飞向目标造成伤害

const GC = preload("res://resources/game_constants.gd")
const DT = preload("res://resources/design_tokens.gd")
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
## v6.6: 抑制曲射炮口火焰（相位仪「超级火炮连击」从屏幕外飞入，无需炮口火）
var suppress_muzzle: bool = false

## v7.x: 目标的 combat_kind（命中时从 target.stats 提取，驱动命中色调/缩放/震动差异化）
## -1 = 未提取（走原逻辑，向后兼容）
var _target_combat_kind: int = -1

## v8.1: 命中特效待生效标记（在 _on_hit 判定时设，_spawn_tex_impact_at 读取后清）
var _pending_crit: bool = false
var _pending_pierce: bool = false
var _pierce_dir: Vector2 = Vector2.RIGHT  # 穿透光线方向

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
var _trail_particles: CPUParticles2D  # v8.1: 粒子拖尾（替代/补充静态 TrailSprite）
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
	_trail_particles = get_node_or_null("TrailParticles") as CPUParticles2D
	_apply_visual()
	_configure_behavior()
	_beam_visual_phase = 0
	# v8.3: 发射音效（所有武器类型，按 WeaponTypeLegacy 分流）
	_play_attack_sfx()

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
			## v7.x: 程序化子弹形状替代简陋三角箭头（弹头形 + 按武器类型差异化）
			_apply_bullet_shape(size_scale)
	if _beam_line:
		_beam_line.visible = use_beam
		if use_beam:
			_beam_line.default_color = beam_color
			_beam_line.width = 3.0 if weapon_type == 6 else 4.5


## v7.x: 程序化生成子弹多边形（替代原 3 点三角形）
## 形状 = 弹体（平底矩形段）+ 弹头（锥形过渡段），指向 +X（飞行方向）
## 按 weapon_type 差异化比例，让不同武器视觉上有辨识度
## v8.3 视觉增强：基准 ×2（body 4→8 / nose 2→4 / half_h 1.5→3.5），让弹体在战场上清晰可见
## 注意：整体尺寸需与放大后的基准 (12×8*scale) 保持一致，各 override 同步 ×2
func _apply_bullet_shape(size_scale: float) -> void:
	if _sprite == null:
		return
	var s := size_scale
	# 基准尺寸（v8.3 ×2）：总长约 12*scale，高约 8*scale
	var body_len: float = 8.0 * s   # 弹体长度（原 4.0）
	var nose_len: float = 4.0 * s   # 弹头锥形长度（原 2.0）
	var half_h: float = 3.5 * s     # 弹体半高（原 1.5）
	# 按武器类型调整比例（v8.3 同步 ×2）
	match weapon_type:
		5:  # SHOTGUN — 圆胖霰弹丸
			body_len = 6.0 * s
			nose_len = 3.0 * s
			half_h = 4.0 * s
		3, 9:  # ROCKET / MISSILE — 长粗导弹
			body_len = 9.0 * s
			nose_len = 4.0 * s
			half_h = 4.0 * s
		10, 11:  # OMEGA / RAIL — 细长高能弹
			body_len = 8.0 * s
			nose_len = 4.0 * s
			half_h = 1.6 * s
		7:  # FLAK — 短粗高炮弹
			body_len = 5.0 * s
			nose_len = 3.0 * s
			half_h = 3.6 * s
	var tip_x: float = body_len + nose_len  # 弹头顶点 X
	# 7 点顺时针多边形（从弹体底部后端起）：
	# 后端平底 → 弹体底前 → 锥面收窄 → 弹尖 → 锥面展开 → 弹体顶前 → 后端平顶
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(0.0,        -half_h),   # 弹体底部后端
		Vector2(body_len,   -half_h),   # 弹体底部前端
		Vector2(body_len,   -nose_len * 0.4),  # 弹头底部锥面（下）
		Vector2(tip_x,       0.0),      # 弹头顶点
		Vector2(body_len,    nose_len * 0.4),  # 弹头底部锥面（上）
		Vector2(body_len,    half_h),   # 弹体顶部前端
		Vector2(0.0,         half_h),   # 弹体顶部后端
	])
	_sprite.polygon = pts


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
## v8.1: 新增粒子拖尾——重型武器强粒子（导弹/火炮），轻武器微弱粒子（机枪/步枪增运动感）
func _apply_trail() -> void:
	# 静态贴图拖尾（保留给重型武器）
	if _trail_sprite != null:
		if not _is_heavy:
			_trail_sprite.visible = false
		else:
			_trail_sprite.visible = true
			_trail_sprite.texture = HEAVY_TRAIL_TEX
			_trail_sprite.centered = true
			_trail_sprite.scale = Vector2(0.35, 0.35)
			_trail_sprite.modulate = Color.WHITE if shooter_is_player else Color(1.0, 0.55, 0.45)
			_trail_sprite.material = _get_add_blend_mat()
			_trail_sprite.rotation = 0.0
			_trail_sprite.position = Vector2.ZERO
	# v8.3 视觉增强：粒子拖尾按 weapon_type 6 档分级（原 _is_heavy 二分太粗，轻武器几乎无轨迹）
	if _trail_particles != null:
		_trail_particles.material = _get_add_blend_mat()
		if DT.is_motion_reduce():
			# 减少动效模式：禁用粒子拖尾
			_trail_particles.emitting = false
			_trail_particles.visible = false
			return
		_apply_trail_tier()
		_trail_particles.color = _trail_color_for_weapon()
		_trail_particles.emitting = true
		_trail_particles.visible = true


## v8.3: 按 weapon_type 配置拖尾粒子参数（6 档 + 兜底）
## WeaponTypeLegacy: SMG=0,RIFLE=1,MG=2,ROCKET=3,PISTOL=4,SHOTGUN=5,SNIPER=6,FLAK=7,LASER=8,MISSILE=9,OMEGA=10,RAIL=11
func _apply_trail_tier() -> void:
	var amount: int = 16
	var life: float = 0.50
	var vmin: float = 15.0
	var vmax: float = 40.0
	var smin: float = 1.5
	var smax: float = 3.0
	match weapon_type:
		0, 1, 2, 4:  # SMG / RIFLE / MG / PISTOL — 轻武器，连发轨迹感
			amount = 16; life = 0.50; vmin = 15.0; vmax = 40.0; smin = 1.5; smax = 3.0
		5:  # SHOTGUN — 宽散布霰弹
			amount = 24; life = 0.45; vmin = 20.0; vmax = 60.0; smin = 2.0; smax = 4.0
		6:  # SNIPER — 高速细长
			amount = 12; life = 0.60; vmin = 40.0; vmax = 100.0; smin = 1.0; smax = 2.0
		3, 9, 7:  # ROCKET / MISSILE / FLAK — 浓烈爆炸类尾焰
			amount = 30; life = 0.70; vmin = 20.0; vmax = 50.0; smin = 2.5; smax = 5.0
		8:  # LASER — 细密能量
			amount = 10; life = 0.40; vmin = 60.0; vmax = 150.0; smin = 0.8; smax = 1.5
		10, 11:  # OMEGA / RAIL — 高能电弧
			amount = 20; life = 0.55; vmin = 30.0; vmax = 80.0; smin = 1.8; smax = 3.5
	_trail_particles.amount = amount
	_trail_particles.lifetime = life
	_trail_particles.initial_velocity_min = vmin
	_trail_particles.initial_velocity_max = vmax
	_trail_particles.scale_amount_min = smin
	_trail_particles.scale_amount_max = smax


## v8.1: 按武器类型获取拖尾粒子颜色
func _trail_color_for_weapon() -> Color:
	if not shooter_is_player:
		return Color(1.0, 0.45, 0.5, 0.7)  # 敌方粉红
	match weapon_type:
		8:  return Color(0.3, 0.8, 1.0, 0.8)   # LASER 蓝
		10, 11: return Color(0.5, 0.9, 1.0, 0.8)  # OMEGA/RAIL 青
		3, 7, 9, 1, 2: return Color(1.0, 0.55, 0.2, 0.8)  # 爆炸类 橙
		_: return Color(1.0, 0.95, 0.6, 0.7)   # 枪械 黄白


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

	# v8.1: 构造命中特效 opts（暴击/穿透标记），读取后清零
	var opts: Dictionary = {}
	if _pending_crit:
		opts["is_crit"] = true
	if _pending_pierce:
		opts["is_pierce"] = true
		opts["direction"] = _pierce_dir
	_pending_crit = false
	_pending_pierce = false

	# 曲射/空射/火箭/导弹 → 使用完整爆炸特效
	# 新枚举: INDIRECT=1, AERIAL=2
	# 旧枚举: ROCKET=3, FLAK=7, MISSILE=9
	if weapon_type in [1, 2, 3, 7, 9]:  # INDIRECT, AERIAL, ROCKET, FLAK, MISSILE
		_spawn_impact_explosion(world_pos, opts)
		return

	# v6.0: 武器名查 VFX → 旧 weapon_type 回退
	# v7.x: 透传 _target_combat_kind 实现按目标类型差异化命中色调/缩放
	# v8.1: 透传 opts（暴击/穿透）
	if not _weapon_name.is_empty():
		_spawn_impact_v2(parent, world_pos, _weapon_name, opts)
	else:
		WeaponProjectileVfx.spawn_impact_with_kind(parent, world_pos, weapon_type, shooter_is_player, _target_combat_kind, opts)


## v6.0/v8.0: 新版命中特效（按武器名）— 粒子化，零贴图绑定
## v8.1: 透传 opts（暴击/穿透）
func _spawn_impact_v2(parent: Node2D, world_pos: Vector2, weapon_name: String, opts: Dictionary = {}) -> void:
	# v8.0: 统一走 spawn_impact_with_kind（内部自动选颜色+粒子）
	WeaponProjectileVfx.spawn_impact_with_kind(parent, world_pos, weapon_type, shooter_is_player, _target_combat_kind, opts)


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
	# v6.6: suppress_muzzle 时跳过（相位仪炮击从屏幕外飞入，无炮口）
	if not _muzzle_spawned:
		_muzzle_spawned = true
		if _is_heavy and not suppress_muzzle:
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
	# v7.4: 炮口火焰改用 VfxImpactFactory 的 spark 池（原每次 new CPUParticles2D+Gradient）
	# parent 用 get_parent()（子弹父节点，通常是 PlayerUnits/EnemyUnits 容器）
	var host: Node = get_parent()
	if host == null or not (host is Node2D):
		return
	VfxImpactFactory.spawn_muzzle_flash(host, pos, shooter_is_player)

func _spawn_impact_explosion(pos: Vector2, opts: Dictionary = {}) -> void:
	# v8.0: 统一走 spawn_impact_with_kind（粒子化，零贴图绑定）
	# v8.1: 透传 opts（暴击/穿透）
	WeaponProjectileVfx.spawn_impact_with_kind(self, pos, weapon_type, shooter_is_player, _target_combat_kind, opts)


## v6.4: 命中时触发屏幕震动——曲射/爆炸类中震动，直射轻震动
## v7.x: 优先用 combat_kind 的震动参数（对轻装轻震/对装甲中震/对空重震），无 combat_kind 走原逻辑
func _request_hit_shake() -> void:
	if BattleManager == null or not is_instance_valid(BattleManager):
		return
	if not BattleManager.has_method("request_screen_shake"):
		return
	# v7.x: 有 combat_kind 时按目标类型定震动强度
	if _target_combat_kind >= 0:
		var shake: Vector2 = WeaponProjectileVfx.impact_shake_for_kind(_target_combat_kind)
		if shake.x > 0.0:
			# 爆炸/曲射类增强：combat_kind 基础值 + 爆炸加成
			var mag: float = shake.x
			if _is_indirect or explosion_radius > 0.0:
				mag = maxf(mag, 8.0)  # v8.3: 5.0→8.0
			BattleManager.request_screen_shake(mag, shake.y)
			return
	# v8.3 视觉增强：fallback 直射 1.8→3.0 / 爆炸 5.0→8.0
	if _is_indirect or explosion_radius > 0.0:
		BattleManager.request_screen_shake(8.0, 0.35)
	else:
		BattleManager.request_screen_shake(3.0, 0.15)


## v8.3: 发射音效——按 weapon_type（WeaponTypeLegacy）+ 敌我分流，直接调 AudioManager（autoload）
func _play_attack_sfx() -> void:
	if not (AudioManager and AudioManager.has_method("play_sfx")):
		return
	# reduce_motion 不影响音效（音效是无障碍辅助，仅视觉减动）
	var pitch := randf_range(0.9, 1.1)
	var vol: float = 0.7 if not shooter_is_player else 1.0
	if not shooter_is_player:
		pitch *= 0.92  # 敌方轻微降调，潜意识区分敌我
	match weapon_type:
		0:       AudioManager.play_sfx("gun_smg", vol * 0.6, pitch)
		1:       AudioManager.play_sfx("gun_rifle", vol * 0.6, pitch)
		2:       AudioManager.play_sfx("gun_mg", vol * 0.7, pitch * 0.9)
		3:       AudioManager.play_sfx("rocket_launch", vol * 1.0, pitch * 0.8)
		4:       AudioManager.play_sfx("gun_pistol", vol * 0.5, pitch * 1.1)
		5:       AudioManager.play_sfx("gun_shotgun", vol * 0.9, pitch)
		6:       AudioManager.play_sfx("gun_sniper", vol * 0.7, pitch * 1.2)
		7:       AudioManager.play_sfx("flak_fire", vol * 0.9, pitch * 0.9)
		8:       AudioManager.play_sfx("laser_fire", vol * 0.5, pitch * 2.0)
		9:       AudioManager.play_sfx("missile_hum", vol * 0.8, pitch)
		10:      AudioManager.play_sfx("omega_cannon", vol * 0.8, pitch * 0.5)
		11:      AudioManager.play_sfx("rail_cannon", vol * 0.7, pitch * 1.5)


## v8.3: 命中音效——按 weapon_type + is_crit 分流（暴击降调加重击感）
func _play_impact_sfx(is_crit: bool) -> void:
	if not (AudioManager and AudioManager.has_method("play_sfx")):
		return
	var vol: float = 0.6
	var pitch: float = randf_range(0.95, 1.05)
	match weapon_type:
		3, 9:    vol = 1.0                              # ROCKET/MISSILE 爆炸最响
		8:       vol = 0.4; pitch = randf_range(3.0, 5.0)  # LASER 高频
		7:       vol = 0.8                              # FLAK 空爆
		5:       vol = 0.7                              # SHOTGUN 碎屑
		6:       vol = 0.7; pitch *= 1.3                # SNIPER 清脆
		_:       vol = 0.6
	if is_crit:
		vol = minf(vol * 1.5, 1.0)
		pitch *= 0.8
	AudioManager.play_sfx("impact_generic", vol, pitch)


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
	# v7.x: 提取目标 combat_kind（用于命中特效按目标类型差异化色调/缩放/震动）
	if primary != null:
		var _ts: UnitStats = primary.get("stats") as UnitStats if "stats" in primary else null
		if _ts != null:
			_target_combat_kind = int(_ts.combat_kind)
	if forced_miss:
		var miss_pos: Vector2 = primary.global_position if primary else global_position
		CombatFeedback.show_miss(miss_pos, primary)
		if _use_tex_sprite:
			_spawn_tex_impact_at(miss_pos)
		elif GameManager != null:
			var root := get_parent() as Node2D
			if root != null:
				CardGridFx.spawn_impact(root, miss_pos, weapon_type)
		_finish_tex_bullet()
		return
	if not _use_tex_sprite and GameManager != null:
		var root2 := get_parent() as Node2D
		if root2 != null:
			CardGridFx.spawn_impact(root2, primary.global_position if primary else global_position, weapon_type)
	# 如果没有射手数值信息，使用基础伤害逻辑
	if shooter_stats == null:
		_on_hit_basic(primary)
		return

	# v7.5: 删除误导性死分支（原 `if GameManager == null: defender_reduction = ...`）。
	# GameManager 是 autoload 永不为 null，该分支从未执行，导致 damage_reduction 看似在
	# bullet 消费实际全链路空转。现格子战的 damage_reduction 已在 take_damage→resolve_hit
	# 正确结算，bullet 这里不再处理减伤。保留 defender_reduction=0 让下方公式行为不变。
	var defender_reduction: float = 0.0
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
	# v8.1: 穿透检测——命中特效紫色穿甲光线 + pierce 伤害数字样式
	# 检测相位仪 piercing_shot 能力 或 符文 on_attack_penetration（与 attack_calculator 逻辑对齐）
	if not _pending_pierce:
		var pen_ratio: float = 0.0
		# 相位仪直射穿透
		var ability: Dictionary = PhaseInstrumentAbilities.get_active_ability()
		if not ability.is_empty() and String(ability.get("id", "")) == "piercing_shot":
			pen_ratio = maxf(pen_ratio, float(ability.get("params", {}).get("pen_ratio", 0.0)))
		# 符文穿透
		if shooter_stats != null and shooter_stats.has_meta("rune_specials"):
			var specials = shooter_stats.get_meta("rune_specials")
			if specials is Array:
				for sp in specials:
					if sp is Dictionary and sp.get("special", "") == "on_attack_penetration":
						pen_ratio = maxf(pen_ratio, float(sp.get("value", 0)) / 100.0)
		if pen_ratio > 0.0:
			_pending_pierce = true
			_pierce_dir = _direction
	# v6.3: 真实暴击判定（基于 crit_chance；基础1.5x + crit_damage_bonus 每级+0.2x）
	# v7.x: 目标的 crit_resist 降低被暴击概率（暴抗从攻击者 crit_chance 中扣减，下限 0）
	var is_crit: bool = false
	var effective_crit: float = shooter_stats.crit_chance
	if effective_crit > 0.0 and primary != null:
		var target_stats_v: UnitStats = primary.get("stats") as UnitStats if "stats" in primary else null
		if target_stats_v != null and target_stats_v.crit_resist > 0.0:
			effective_crit = maxf(0.0, effective_crit - target_stats_v.crit_resist)
	if effective_crit > 0.0 and randf() < effective_crit:
		is_crit = true
		final_damage *= (1.5 + shooter_stats.crit_damage_bonus)
		_pending_crit = true  # v8.1: 命中特效暴击光环标记
	# v8.3: 命中音效（暴击判定后，用 is_crit 调音高/音量）
	_play_impact_sfx(is_crit)

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
		# v8.1: AOE 爆炸冲击波环（半径=爆炸范围），强化范围感
		var aoe_parent := get_parent() as Node2D
		if aoe_parent != null:
			VfxImpactFactory.spawn_shockwave(aoe_parent, global_position, explosion_radius)
		for child in _get_aoe_damage_targets(global_position, explosion_radius, primary):
			# v7.5: 删除原 `if GameManager == null: splash_red = ...` 死分支（同主目标修复理由）
			var splash_red: float = 0.0
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

	# v6.3/v6.6: 暴击伤害数字统一由 take_damage → unit_damaged 信号驱动（用实际扣血值）。
	# 暴击 meta 必须在 take_damage 之前设置：take_damage 内部 emit unit_damaged 时，
	# _on_unit_damaged_combat_feedback 据此 meta 用金色 critical 样式显示并清除 meta。
	# 此前直接 show_damage(final_damage) 会绕过 take_damage 内部处理（护盾/bulwark/倍率），
	# 导致暴击数字与血条实际扣血矛盾。
	if is_crit and is_instance_valid(primary):
		primary.set_meta("_vfx_crit_pending", true)
	# v8.1: 穿透 meta——take_damage → unit_damaged 时据此用紫色 pierce 样式显示伤害数字
	if _pending_pierce and is_instance_valid(primary):
		primary.set_meta("_vfx_pierce_pending", true)

	# 直击伤害
	if primary.has_method("take_damage"):
		var final_after_wall: float = _apply_shield_wall_mitigation(final_damage, primary)
		var atk_primary: Variant = shooter if is_instance_valid(shooter) else null
		primary.take_damage(final_after_wall, atk_primary)
		# v6.2: 符文之语特殊效果 — 攻击命中时触发（闪电链/溅射）
		if is_instance_valid(shooter):
			RuneSpecialHandler.on_hit(shooter, primary, final_after_wall)
			# v6.6: 应用改造命中副作用（吸血/连锁/溅射）——补全低速直射路径缺失的效果
			ModuleEffectHandler.apply_on_hit_side_effects(shooter, primary, final_after_wall)
	# 兜底：若目标无 take_damage（不应发生），meta 不会经信号清除，此处手动清避免残留
	elif is_instance_valid(primary):
		if is_crit and primary.has_meta("_vfx_crit_pending"):
			primary.remove_meta("_vfx_crit_pending")
		if _pending_pierce and primary.has_meta("_vfx_pierce_pending"):
			primary.remove_meta("_vfx_pierce_pending")

	# v6.4: 命中屏幕震动（曲射/爆炸中震动，直射轻震动）
	_request_hit_shake()
	# v8.1: 能量武器(LASER/OMEGA/RAIL)命中光束余晖——shooter→命中点发光线段
	if weapon_type in [8, 10, 11] and is_instance_valid(shooter) and primary is Node2D:
		var fx_parent := get_parent() as Node2D
		if fx_parent != null:
			var beam_color := Color(0.3, 0.8, 1.0, 0.9) if weapon_type == 8 else Color(0.5, 0.9, 1.0, 0.9)
			VfxImpactFactory.spawn_laser_beam(fx_parent, shooter.global_position, (primary as Node2D).global_position, beam_color)

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
	# v8.3: 命中音效（basic 路径无暴击判定，统一非暴击）
	_play_impact_sfx(false)
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
	suppress_muzzle = false  # v6.6: 炮口火抑制重置

	# v8.1: 命中特效 pending 标记重置（防对象池复用残留）
	_pending_crit = false
	_pending_pierce = false
	_pierce_dir = Vector2.RIGHT
	_target_combat_kind = -1

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
	# v8.1: 粒子拖尾也停止发射
	if _trail_particles:
		_trail_particles.emitting = false
		_trail_particles.visible = false
	if _sprite:
		_sprite.visible = true
	if _beam_line:
		_beam_line.visible = false

	visible = false
