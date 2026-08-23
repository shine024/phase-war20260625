extends Node2D
## 子弹/激光/导弹等：按武器类型显示不同攻击动画，飞向目标造成伤害

const GC = preload("res://resources/game_constants.gd")
const DT = preload("res://resources/design_tokens.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const CardAbilityManager = preload("res://managers/card_ability_manager.gd")
const CardGridFx = preload("res://scripts/card_grid_fx.gd")
const WeaponProjectileVfx = preload("res://scripts/weapon_projectile_vfx.gd")
const WeaponVisuals = preload("res://data/weapon_visual_profiles.gd")  # v17: 武器视觉档案（名字优先解析）
const AttackCalculator = preload("res://scripts/battle/attack_calculator.gd")
const RuneSpecialHandler = preload("res://managers/rune_special_handler.gd")
const FactionSkillEffectHandler = preload("res://scripts/battle/faction_skill_effect_handler.gd")
# v9.1: 组合技套路机制（光束反射/多重攻击/弱点暴露/化学腐蚀等乘区）
const ComboEngine = preload("res://scripts/battle/combo_engine.gd")
const DirectWeaponFlavor = preload("res://data/direct_weapon_flavor.gd")
## 曲射弹道：炮口火焰特效纹理（预加载，避免运行时 ResourceLoader.load 卡顿）
## v9.x 修复：原 weapons_realistic/weapon_artillery_muzzle.png 从未进 git（机器间缺失导致整脚本 Parse Error），
## 改用已入库的 muzzle_heavy.png（火炮炮口焰语义一致）。
## v6.1: 能量武器（LASER/OMEGA/RAIL）使用方向性长条纹理 weapon_artillery_muzzle.png（1024×1024 已入库），
## 配合窄锥角喷射形态，替代圆形爆发贴图。
const ARTILLERY_MUZZLE_TEX := preload("res://assets/effects/particle_textures/muzzle_heavy.png")   # 默认/轻型枪口火（橙红爆发）
const MUZZLE_JET_TEX       := preload("res://assets/effects/particle_textures/muzzle_jet_sym.png")      # v17e: 侧视前向喷流（白核居中+两侧橙尾，朝左朝右都对）
const FLAME_STAR_TEX       := preload("res://assets/effects/particle_textures/flame_star.png")    # v17d: 8 放射火舌（已被 FLAME_JET_TEX 替代，保留兼容）
## v18-R5: 重型枪口水平火舌（对称 ±X，内容 149×25px）——放射星被 AI 读成"径向爆散"。
const FLAME_JET_TEX        := preload("res://assets/effects/particle_textures/flame_jet_sym.png")
## v18-R9: 摄影感火舌 v2（黑体色序+噪声边缘，内容 160×45px）。
const FLAME_JET_V2_TEX     := preload("res://assets/effects/particle_textures/flame_jet_v2.png")
const ENERGY_MUZZLE_TEX    := preload("res://assets/effects/projectiles/weapons_realistic/weapon_artillery_muzzle.png")  # 能量喷射流（白青，LASER/OMEGA/RAIL）
const HEAVY_TRAIL_TEX := preload("res://assets/effects/projectiles/omega_platform/omega_platform_projectile_trail.png")
## 启用拖尾的重型武器类型：INDIRECT(1)/AERIAL(2)/ROCKET(3)/FLAK(7)/MISSILE(9)/OMEGA(10)/RAIL(11)
const HEAVY_TRAIL_WEAPON_TYPES: Array = [1, 2, 3, 7, 9, 10, 11]
## v9.2: 拖尾粒子贴图——按武器类型分流，让拖尾形状区分武器级别
## v17d: 动能拖尾换 spark_streak（白热头+橙尾拖痕，内容 118×17px）——旧 spark_metal 是软条，
## 且 v9.2 的 scale 表按"32px 贴图"标定而实为 128px → 拖尾渲染成 190-380px 光雾（弹道问题的主因）。
## 新 scale 表按内容实寸重标定（见 _apply_trail_tier）。
const TRAIL_TEX_SPARK_STREAK := preload("res://assets/effects/particle_textures/spark_streak.png") # 动能轻武器（火花拖痕，指向+X→局部-X向后）
const TRAIL_TEX_SPARK_ENERGY := preload("res://assets/effects/particle_textures/spark_energy.png")  # 能量武器（蓝白电弧）
const TRAIL_TEX_SMOKE_GENERIC := preload("res://assets/effects/particle_textures/smoke_generic.png") # 重型爆炸（灰烟）
## v18-R12f: 光束轨迹水平光带贴图（256×16，白热中心+透明边缘）
## -- R12l 回退：Sprite2D 光束在审计矩阵中与其他子弹光束交叉干扰，净效果为负。
## const BEAM_TEX_H_STRIP := preload("res://assets/effects/particle_textures/beam_h_strip.png")
# ObjectPoolManager 为 autoload

var speed: float = 600.0
var damage: float = 5.0
var target: Node2D = null
var shooter_is_player: bool = true
var max_distance: float = 1600.0
var weapon_type: int = 0
## v17d: 拖光线——弹体后方速度方向 ADD 亮线。v9.4 弃用长条弹体后轻武器弹体仅 12×7px
## 混战不可追踪；细拖光线补"一发子弹正在飞"的可读性（曳光弹视觉），随弹体旋转恒对齐。
var _tracer_line: Line2D = null
## v17: 视觉专用 wt——经 WeaponVisualProfiles.resolve_visual_wt 解析（武器名优先+域感知
## 兜底）。weapon_type 本体保留原始值供弹道物理（_configure_behavior）使用，严禁混用。
## 所有枪口火/命中/贴图消费点统一读 _visual_wt，槽位漏配签名武器时消费侧仍能按名纠正。
var _visual_wt: int = 0
var shooter: Node2D = null  # 射手引用（用于词条效果）
var shooter_stats: UnitStats = null  # 射手数值（用于词条效果计算）
## 超射程「哑弹」：飞过但不造成伤害（仍可对卡牌模式播放擦弹表现）
var forced_miss: bool = false
var _pre_calculated: bool = false  # 伤害已完整计算（防御/强化不再重复）
var _weapon_name: String = ""  # v6.0: 武器名（用于 VFX 贴图查找）
## v8.4: 武器类改造专属视觉标识（cluster/thermobaric/proximity/guided/gun_missile）
## 由 weapon_resource._mod_effects 读出，开火时传入，命中时透传给 spawn_impact_with_kind opts
var _vfx_variant: String = ""
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
## v9.4: 标记本次穿透由相位仪 piercing_shot 能力触发（区别于武器自带 pierce_count）。
## 后续穿透命中据此走 enhanced 加宽版穿甲光线（spawn_pierce_beam），让"技能穿透"更醒目。
var _pierce_from_ability: bool = false
## v9.3: TANK_GUN 单发重炮快速消失（避免与下一发重叠，重炮视觉清晰）
var _tank_gun_terminate: bool = false  # TANK_GUN 命中后开始淡出计时
var _tank_gun_timer: float = 0.0       # 命中后保持可见的帧数（0.2s ≈ 12 帧）

# 行为参数：由武器类型决定
var pierce_count: int = 0          # 可额外穿透多少个目标（LASER/SNIPER 用）
var _blitz_applied: bool = false   # v8.5: 闪电穿插 pierce 补充已应用标记（避免重复加）
var explosion_radius: float = 0.0  # >0 时命中产生范围伤害（ROCKET/MISSILE/FLAK）
var pellet_count: int = 1          # 霰弹多发
var spread_angle_deg: float = 0.0  # 多发散射角
# v9.2: 多单位穿透伤害衰减（每穿一个目标，后续伤害 × (1 - falloff)）。
# 默认 0.0 = 不衰减（保持现有狙击/激光/磁轨/欧米茄行为）。
# 相位仪直射穿透等显式配置衰减的来源会设置此值（见 _on_hit 能力检测块）。
var _pierce_falloff: float = 0.0
var _pierce_damage_mult: float = 1.0  # 当前穿透命中的伤害乘数（每次穿透递减）
# v9.2: 穿透子弹已撞目标记录——避免同一颗子弹反复命中同一目标（穿透次数变多后尤其重要）。
var _pierce_hit_targets: Array = []
# v9.2: 标签克制命中复用——_on_hit 高频，原每次 new Array + new Dictionary，改成员复用（reset 时清理）
var _cached_atk_tags: Array = []
var _tag_result_cache: Dictionary = {}

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
## v9.4: 弹体是否随飞行方向旋转（贴图弹道 _use_tex_sprite 和程序化弹头都需旋转）。
## 光束类（SNIPER/LASER）不旋转（用 Line2D 端点）。命中特效也据此判断走贴图路径。
var _rotates_with_direction: bool = false
var _direction: Vector2 = Vector2.RIGHT
var _beam_visual_phase: int = 0
# v18-R12f: 光束轨迹 Sprite2D 方案已回退，恢复 Line2D 光束
# const BEAM_VISUAL_LEN: float = 100.0
# const BEAM_FADEOUT_DIST: float = 120.0

## v6.4: 弹道发光叠加材质
static var _add_blend_mat: CanvasItemMaterial

static func _get_add_blend_mat() -> CanvasItemMaterial:
	if _add_blend_mat == null:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_add_blend_mat = m
	return _add_blend_mat


func _apply_shield_wall_mitigation(raw_damage: float, _target: Node) -> float:
	# v9.x（P2-7范围B）：护盾墙法则已随法则系统退役——保留函数形态作直通，
	# 多个伤害调用点（主伤害/溅射两套路径）无需逐一改动
	return raw_damage

func setup(p_target: Node2D, p_damage: float, p_is_player: bool, p_weapon_type: int = -1, p_shooter: Node2D = null, p_shooter_stats: UnitStats = null, p_forced_miss: bool = false, p_weapon_name: String = "", p_pre_calculated: bool = false, p_vfx_variant: String = "") -> void:
	visible = true
	_finished = false  # 复用：清除归还守卫
	target = p_target
	damage = p_damage
	shooter_is_player = p_is_player
	shooter = p_shooter
	shooter_stats = p_shooter_stats
	forced_miss = p_forced_miss
	_weapon_name = p_weapon_name
	_vfx_variant = p_vfx_variant  # v8.4: 武器类改造专属视觉
	_pre_calculated = p_pre_calculated
	if p_weapon_type >= 0:
		weapon_type = p_weapon_type
	_visual_wt = WeaponVisuals.resolve_visual_wt(_weapon_name, weapon_type, shooter_is_player)
	_start_position = global_position
	_direction = Vector2.RIGHT
	_sprite = get_node_or_null("Sprite") as Polygon2D
	_beam_line = get_node_or_null("BeamLine") as Line2D
	_tex_sprite = get_node_or_null("TexSprite") as Sprite2D
	_trail_sprite = get_node_or_null("TrailSprite") as Sprite2D
	_trail_particles = get_node_or_null("TrailParticles") as CPUParticles2D
	# _beam_sprite removed: R12l reverted
	# v17d: 拖光线节点（speed≥400 的重武器配）——随子弹旋转，恒对齐飞行方向向后拉出
	if _tracer_line == null or not is_instance_valid(_tracer_line):
		_tracer_line = Line2D.new()
		_tracer_line.width = 2.5
		_tracer_line.joint_mode = Line2D.LINE_JOINT_ROUND
		_tracer_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		_tracer_line.add_point(Vector2(0, 0))      # 子弹根部（中心）
		_tracer_line.add_point(Vector2(-10.0, 0))  # 尾端（局部-X，世界飞行反方向）
		add_child(_tracer_line)
		_tracer_line.visible = false
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
			pellet_count = GC.SHOTGUN_PELLET_COUNT
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
	# v6.4: 弹道发光叠加
	var blend_mat := _get_add_blend_mat()
	if _sprite:
		_sprite.material = blend_mat
	if _beam_line:
		_beam_line.material = blend_mat
	if _tracer_line:
		_tracer_line.material = blend_mat
	# v9.4: 直射轻武器（SMG/RIFLE/MG/PISTOL，wt 0/1/2/4）改用程序化弹头多边形（与直射 batch 的
	# ArrayMesh 弹头视觉一致），弃用横向长条贴图——长条贴图（weapon_rifle/smg/mg_projectile.png
	# 比例 5:1~12:1）旋转到斜向弹道时视觉违和（长条横躺）。程序化弹头短粗（12×7）、指向 +X、
	# 原点居中，rotation=_direction.angle() 后任意角度自然对齐飞行方向。
	# 重型/能量/曲射武器（wt 3/5/6/7/8/9/10/11）保留贴图（形状语义明确：火箭/导弹/激光等）。
	# v19-R36: 狙击(6)改程序化动能弹形——与激光光束分流（用户反馈"狙击不应该和
	# 激光一样的弹道"，族规格也区分"狙击=轻型动能 / 激光=光束"）。进程序化列表
	# 同时拦截旧投射贴图路径（v18-R8 批评的"离散断点"弹体不再回归）。
	var _use_procedural_bullet := weapon_type in [0, 1, 2, 4, 6]
	# v18-R8: 激光(8)强制 Line2D 光束渲染——族规格"弹体=光束"（v19-R36 起狙击不再共用）。
	# 旧路径因有投射贴图走 tex-sprite 提前 return，光束分支成死代码；贴图弹体+
	# 电弧拖尾(spark_energy)被 AI 读成"离散闪电碎片/弹丸断点"（f08 traj 2-3、f06 traj 3 分）。
	var _use_beam_render := weapon_type == 8
	_use_tex_sprite = WeaponProjectileVfx.has_proj_texture(weapon_type) and not _use_procedural_bullet and not _use_beam_render
	if _use_tex_sprite:
		_apply_tex_sprite_visual(is_player)
		_rotates_with_direction = true   # 贴图弹道随飞行方向旋转
		return
	_hide_tex_sprite_visual()
	var bullet_color: Color
	var beam_color: Color
	var use_beam: bool = false
	var size_scale: float = 1.0
	match weapon_type:
		0, 4:
			bullet_color = Color(1.0, 0.95, 0.2) if is_player else Color(1, 0.4, 0.2)
			size_scale = 1.0   # v6.1: 0.8→1.0，v18-R11d 我方1.3实验回退（影响敌muzzle）
		1, 2:
			bullet_color = Color(0.6, 0.95, 1.0) if is_player else Color(0.9, 0.5, 0.3)
			size_scale = 1.15  # v6.1: 1.0→1.15，步枪/机枪弹体更粗壮
		5:
			bullet_color = Color(1.0, 0.95, 0.2) if is_player else Color(1, 0.5, 0.2)
			size_scale = 1.2
		6:
			# v19-R36: 动能曳光弹——白热穿甲弹头（程序化长杆形）+ 110px 细曳光（speed×0.1），
			# 高速划过读作"狙击步枪"，与激光的能量光束带完全分流。
			bullet_color = Color(1.0, 0.97, 0.82) if is_player else Color(1.0, 0.62, 0.35)
			size_scale = 1.4
		8:
			use_beam = true
			# v18-R8: 敌方激光束改红橙——与命中签名 spawn_laser_burn 的敌我配色对齐
			# （玩家青白冷光/敌方红橙热光），光束与灼烧命中同一套色彩语言。
			beam_color = Color(0.2, 0.85, 1) if is_player else Color(1.0, 0.45, 0.30)
		3, 9:
			bullet_color = Color(1.0, 0.7, 0.1) if is_player else Color(1, 0.35, 0.15)
			size_scale = 1.8
		7:
			bullet_color = Color(1.0, 0.9, 0.3) if is_player else Color(0.95, 0.6, 0.3)
			size_scale = 0.6
		11:  # RAIL_CANNON
			bullet_color = Color(0.3, 0.85, 1.0) if is_player else Color(1, 0.25, 0.45)
			size_scale = 1.85
		_:
			bullet_color = Color(1.0, 0.95, 0.4) if is_player else Color(0.9, 0.35, 0.25)
	if _sprite:
		_sprite.visible = not use_beam
		if not use_beam:
			_sprite.color = bullet_color
			## v7.x: 程序化子弹形状替代简陋三角箭头（弹头形 + 按武器类型差异化）
			_apply_bullet_shape(size_scale)
			_rotates_with_direction = true   # v9.4: 程序化弹头随飞行方向旋转
	if _beam_line:
		_beam_line.visible = use_beam
		if use_beam:
			_beam_line.default_color = beam_color
			# v19-R34: 激光束收窄回 20（R14e 曾加粗到 28，用户反馈"太宽了"）；
			# v19-R36: 狙击改动能弹后此分支仅激光使用。可见度由 R27 白热内芯承担。
			_beam_line.width = 20.0
			_beam_line.default_color.a = 1.0
			# v19-R27: 白热内芯——复用 TracerLine 节点作为聚焦能量束亮核（AI 批
			# "矩形色块/扁平条带缺聚焦感"）。2.5px 白线叠加在宽色光束上产生"热核"读感。
			if _tracer_line:
				_tracer_line.visible = true
				_tracer_line.default_color = Color(1.0, 1.0, 1.0, 0.95)
				_tracer_line.width = 3.0
	if _tracer_line:
		# v19-R27: 光束类用 TracerLine 做亮核（而非尾部曳光），非光束类保持原有逻辑。
		if not use_beam:
			_tracer_line.visible = (speed >= 400.0)
			if _tracer_line.visible:
				_tracer_line.default_color = bullet_color
				_tracer_line.width = 2.5
				_tracer_line.set_point_position(1, Vector2(-speed * 0.10, 0.0))  # 拖长=当前速度×0.1s 视觉长度


## v7.x: 程序化生成子弹多边形（替代原 3 点三角形）
## 形状 = 弹体（平底矩形段）+ 弹头（锥形过渡段），指向 +X（飞行方向）
## 按 weapon_type 差异化比例，让不同武器视觉上有辨识度
## v8.3 视觉增强：基准 ×2（body 4→8 / nose 2→4 / half_h 1.5→3.5），让弹体在战场上清晰可见
## v9.4: 几何算法迁移到 WeaponProjectileVfx.build_bullet_points（与 MultiMesh batch 共享单一真理源）。
##       新版本原点居中（绕弹头中心旋转，比原左端原点更自然）。
## 注意：整体尺寸需与放大后的基准 (12×8*scale) 保持一致，各 override 同步 ×2
func _apply_bullet_shape(size_scale: float) -> void:
	if _sprite == null:
		return
	_sprite.polygon = WeaponProjectileVfx.build_bullet_points(weapon_type, size_scale)


## v18-R11a: 光束辉光底层——实验性修改，R11e 确认无效（像素多 6 倍但 AI 分数不变），已移除调用，保留函数供后续参考。


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
	# v18-R8b: 贴图弹体补曳光线——_apply_visual 的 tracer 配置块在 tex 路径提前 return
	# 之后，对贴图弹体是死代码（与 wt6/8 光束死代码同类病根）。炮弹/导弹贴图是暗色
	# 实物（暗橄榄弹体 78×13px），无曳光在暗背景完全不可见（AI 批"弹体不可见/无曳光痕迹"）。
	# 曳光线随弹体旋转恒对齐飞行反方向，高速弹（≥400）一条 2.5px 亮线即可读"正在飞"。
	if _tracer_line:
		var _show_tracer: bool = speed >= 400.0
		_tracer_line.visible = _show_tracer
		if _show_tracer:
			_tracer_line.default_color = _trail_color_for_weapon()
			_tracer_line.width = 2.5
			_tracer_line.set_point_position(1, Vector2(-speed * 0.10, 0.0))
	_apply_trail()


func _hide_tex_sprite_visual() -> void:
	if _tex_sprite:
		_tex_sprite.visible = false
	_apply_trail()


## v6.4: 重型武器拖尾配置（仅在 _is_heavy 时启用，否则隐藏）
## 拖尾贴图置于弹体后方，运行时随 _direction 旋转（见 _process / _process_indirect）
## v8.1: 新增粒子拖尾——重型武器强粒子（导弹/火炮），轻武器微弱粒子（机枪/步枪增运动感）
func _apply_trail() -> void:
	# v18-R8: 光束渲染时禁粒子拖尾——Line2D 光束即弹体视觉，电弧/火花粒子
	# 会让连续光束读成"离散碎片"（AI f08/f06 弹道格主诉）。
	# v19-R36b: 狙击已改动能曳光弹，仅激光(8)保持禁用——恢复 wt6 的高频细长火花拖尾。
	if weapon_type == 8:
		if _trail_sprite != null:
			_trail_sprite.visible = false
		if _trail_particles != null:
			_trail_particles.emitting = false
			_trail_particles.visible = false
		return
	# 静态贴图拖尾（保留给重型武器）
	if _trail_sprite != null:
		if not _is_heavy:
			_trail_sprite.visible = false
		else:
			_trail_sprite.visible = true
			_trail_sprite.texture = HEAVY_TRAIL_TEX
	# v8.3 视觉增强：粒子拖尾按 weapon_type 6 档分级（原 _is_heavy 二分太粗，轻武器几乎无轨迹）
	if _trail_particles != null:
		_trail_particles.material = _get_add_blend_mat()
		if DT.is_motion_reduce():
			# 减少动效模式：禁用粒子拖尾
			_trail_particles.emitting = false
			_trail_particles.visible = false
			return
		# v9.3: TANK_GUN（重型单发炮）禁用粒子拖尾——单发重炮只需要清晰弹体，火星拖尾会让多发射击重叠成杂乱光带
		if DirectWeaponFlavor.classify(_weapon_name, weapon_type) == DirectWeaponFlavor.Flavor.TANK_GUN:
			_trail_particles.emitting = false
			_trail_particles.visible = false
			return
		# v6.1: 恢复直射轻武器（SMG/RIFLE/MG/PISTOL，wt 0/1/2/4）的微弱粒子拖尾。
		# v9.4 曾完全禁用以避免杂乱，但效果检查发现混战时弹道不可见。
		# 改为调用 _apply_trail_tier 的低强度档位（亚类分流已覆盖 wt 0/1/2/4），
		# 粒子数/寿命取各亚类下限值，保持轨迹感但不糊屏。
		# v9.2: 拖尾粒子赋贴图（按武器类型分流）——告别方块拖尾，让弹道轨迹有形状辨识度
		#   能量武器（LASER/OMEGA）→ 蓝白电弧贴图（能量光带感）
		#   磁轨(11)→ SPARK_STREAK 高亮度方向拖痕（avg_lum=190.8），semantic="超音速穿甲"
		#   重型爆炸（ROCKET/FLAK/MISSILE）→ 灰烟贴图（浓烈尾焰感）
		#   动能轻武器（SMG/PISTOL/RIFLE/MG/SHOTGUN/SNIPER）→ 金属火花贴图（细碎火星轨迹）
		if weapon_type in [8, 10]:
			_trail_particles.texture = TRAIL_TEX_SPARK_ENERGY
		elif weapon_type == 11:
			# v18-R12b: 磁轨去电弧拖痕——SPARK_ENERGY 蓝白读成"等离子武器"。
			# SPARK_STREAK 高亮度+方向性拖痕，色调用 bullet_color 白热。
			_trail_particles.texture = TRAIL_TEX_SPARK_STREAK
		elif weapon_type in [1, 2, 3, 7, 9]:
			# v19-R19: 1/2(INDIRECT/AERIAL)归组——旧代码误落 else 火花分支（双枚举碰撞：
			# 1/2 在新枚举=曲射/空射，旧表按旧枚举当 RIFLE/MG），曲射弧线无烟迹可读。
			_trail_particles.texture = TRAIL_TEX_SMOKE_GENERIC
		else:
			_trail_particles.texture = TRAIL_TEX_SPARK_STREAK
		_apply_trail_tier()
		# v17d: 拖尾定向收紧——旧默认全向低速扩散=弹道后跟一朵"蘑菇云"。
		# 弹体已旋转到飞行方向，局部 -X 即世界飞行反方向；窄锥+提速=利落尾迹。
		_trail_particles.direction = Vector2(-1, 0)
		_trail_particles.spread = 16.0
		_trail_particles.gravity = Vector2(0, 0)
		# v19-R20: 世界空间模拟——local_coords 默认 true 时粒子在弹体本地空间，
		# 弹体飞走把全部已发射粒子拖走，拖尾只是身后 ~22px 的尾巴（初速×寿命），
		# 曲射弧线/直射弹道线永远画不出来（AI 批"完全缺失弹道/曳光"的根因）。
		# false = 粒子留在发射点世界坐标，沿飞行路径沉积出可见轨迹。
		# R22 曾尝试仅 wt1/2 启用，实测总分 4.03 低于全局的 4.16——全局 false 净收益更大。
		_trail_particles.local_coords = false
		_trail_particles.initial_velocity_min *= 1.8
		_trail_particles.initial_velocity_max *= 1.8
		_trail_particles.color = _trail_color_for_weapon()
		_trail_particles.emitting = true
		_trail_particles.visible = true


## v8.3: 按 weapon_type 配置拖尾粒子参数（6 档 + 兜底）
## v17d: scale 全表按贴图内容实寸（~128px）重标定——v9.2 表按"32px"标定，
## 实渲染超 2-4 倍（1.5-5.0 → 190-640px 光雾）。新值目标：轻武器尾迹 26-70px、
## 重型烟尾 60-130px。velocity 由调用处统一 ×1.8（云→尾迹）。
## WeaponTypeLegacy: SMG=0,RIFLE=1,MG=2,ROCKET=3,PISTOL=4,SHOTGUN=5,SNIPER=6,FLAK=7,LASER=8,MISSILE=9,OMEGA=10,RAIL=11
func _apply_trail_tier() -> void:
	var amount: int = 16
	var life: float = 0.50
	var vmin: float = 15.0
	var vmax: float = 40.0
	var smin: float = 0.35
	var smax: float = 0.65
	match weapon_type:
		0, 4:  # DIRECT 系轻武器（SMG/RIFLE/MG/PISTOL，flavor 细分），连发轨迹感
			# v19-R19: 1/2 移出本分支——新枚举 1=INDIRECT/2=AERIAL 是曲射炮弹，
			# 误入轻武器档（16 粒 0.35-0.65 火花）导致弧线无烟迹。
			# v19-R34: 世界空间(local_coords=false)下轻武器拖尾在枪口→弹道间
			# 沉积成"长条火花链"（用户反馈"开火枪口有一个长条火花"）——
			# 缩寿命(≤0.30s)+减量，让枪口只留短促闪光尾巴。
			match DirectWeaponFlavor.classify(_weapon_name, weapon_type):
				DirectWeaponFlavor.Flavor.MG:
					# 机枪：连发弹幕轨迹（量最多但寿命短，沉积密度靠连发频率堆）
					amount = 20; life = 0.30; vmin = 18.0; vmax = 48.0; smin = 0.4; smax = 0.7
				DirectWeaponFlavor.Flavor.TANK_GUN:
					# 坦克炮：加粗粒子单发厚实尾焰（可稍长，重炮语义）
					amount = 14; life = 0.35; vmin = 12.0; vmax = 35.0; smin = 0.5; smax = 0.9
				DirectWeaponFlavor.Flavor.RIFLE:
					# 步枪：细碎短尾
					amount = 10; life = 0.26; vmin = 25.0; vmax = 55.0; smin = 0.25; smax = 0.45
				DirectWeaponFlavor.Flavor.SMALL_ARMS:
					# 手枪/卡宾：最弱拖尾（仅一闪）
					amount = 6; life = 0.22; vmin = 10.0; vmax = 25.0; smin = 0.18; smax = 0.32
				_:
					# GENERIC/UNKNOWN：原基准档（冲锋枪/通用直射）
					amount = 12; life = 0.28; vmin = 15.0; vmax = 40.0; smin = 0.3; smax = 0.5
		5:  # SHOTGUN — 宽散布霰弹
			# v18-R11c 实验性修改已回退：缩短拖尾使弹丸"独立"但导致弹体不可见，反噬更大。
			amount = 24; life = 0.45; vmin = 20.0; vmax = 60.0; smin = 0.4; smax = 0.7
		6:  # SNIPER — 单发精确保留一丝火星（对齐 TANK_GUN 豁免思路）
			# v19-R37: 原 12粒/0.60s 沿路径沉积成串珠（AI 读作 3-4 颗独立弹体"多发弹幕"，
			# 与单发狙击语义矛盾）。砍到 4粒/0.20s：弹体+曳光线读"一发"，火星仅点缀。
			amount = 4; life = 0.20; vmin = 40.0; vmax = 100.0; smin = 0.22; smax = 0.4
		1, 2:  # INDIRECT / AERIAL — 曲射炮弹烟迹（v19-R19 归组修复）
			# v19-R26: life 0.55→0.90s。R29 实测 f01/f02 轨迹仍 3/10——18 粒沿弧线
			# 沉积过稀疏（~16 粒在空中），AI 读不出弧线。R30 提量至 36 粒 + 延寿 1.0s，
			# 密度翻倍使弧线中段清晰可读。
			amount = 36; life = 1.00; vmin = 15.0; vmax = 40.0; smin = 0.18; smax = 0.32
		3, 9, 7:  # ROCKET / MISSILE / FLAK — 尾焰烟
			# v18-R6: 128px 烟贴图 × 0.5-1.0 = 64-128px 烟团把 30-50px 弹体完全吞没
			# （AI 批"拖尾烟雾膨胀失控/弹体不可见"）。缩烟提密度：30→16 粒、
			# 0.28-0.5 缩放（36-64px，<弹体）、寿命 0.70→0.50——尾迹可见但不反客为主。
			amount = 16; life = 0.50; vmin = 20.0; vmax = 50.0; smin = 0.28; smax = 0.50
		8:  # LASER — 细密能量
			amount = 10; life = 0.40; vmin = 60.0; vmax = 150.0; smin = 0.25; smax = 0.45
		10:  # OMEGA — 单发放电（v19-R37b: 用户确认欧米茄也读单发；20粒→6粒/0.25s 同 RAIL 档）
			amount = 6; life = 0.25; vmin = 30.0; vmax = 80.0; smin = 0.4; smax = 0.75
		11:  # RAIL — 单发动能穿透（v19-R37: 20粒→6粒/0.25s，理由同 SNIPER——串珠读作多发）
			amount = 6; life = 0.25; vmin = 30.0; vmax = 80.0; smin = 0.4; smax = 0.75
	_trail_particles.amount = amount
	_trail_particles.lifetime = life
	_trail_particles.initial_velocity_min = vmin
	_trail_particles.initial_velocity_max = vmax
	_trail_particles.scale_amount_min = smin
	_trail_particles.scale_amount_max = smax


## v8.1: 按武器类型获取拖尾粒子颜色
func _trail_color_for_weapon() -> Color:
	if not shooter_is_player:
		# v18-R9b: 敌方拖尾粉红→橙红（AI 批"粉红色棉花糖状完全失真"——粉红是
		# 阵营代码色不是物理色；橙红保持敌我区分且符合燃烧语义）
		return Color(1.0, 0.42, 0.22, 0.7)
	match weapon_type:
		8:  return Color(0.3, 0.8, 1.0, 0.8)   # LASER 蓝
		10: return Color(0.45, 0.65, 1.0, 0.8)  # OMEGA 能量蓝
		11: return Color(0.55, 0.95, 1.0, 0.8)  # RAIL 电磁青
		1, 2: return Color(0.85, 0.85, 0.80, 0.8)  # INDIRECT/AERIAL 灰白硝烟（v19-R21: R20 中位火球误读→改灰）
		3, 7, 9: return Color(1.0, 0.55, 0.2, 0.8)  # 爆炸类 橙（火箭/高炮/导弹尾焰）
		0, 4:  # 直射系——按亚类细分配色
			# v8.x/6.1: MG 亮黄/步枪冷白/坦克炮橙白/手枪亮黄，让连发混战也能辨出武器类型
			match DirectWeaponFlavor.classify(_weapon_name, weapon_type):
				DirectWeaponFlavor.Flavor.MG: return Color(1.0, 0.95, 0.3, 0.85)   # 机枪 亮黄
				DirectWeaponFlavor.Flavor.TANK_GUN: return Color(1.0, 0.75, 0.3, 0.85)  # 坦克炮 橙白
				DirectWeaponFlavor.Flavor.RIFLE: return Color(0.6, 0.95, 1.0, 0.85)  # 步枪 冷青白
				DirectWeaponFlavor.Flavor.SMALL_ARMS: return Color(1.0, 0.9, 0.3, 0.75)  # 手枪 亮黄
				_: return Color(1.0, 0.95, 0.5, 0.8)   # 通用直射 亮黄
		_: return Color(1.0, 0.95, 0.5, 0.8)   # 枪械 亮黄


## v6.4: 每帧更新拖尾朝向。Bullet 节点已旋转到 _direction，
## 拖尾作为子节点继承父旋转，故只需固定向弹体后方（局部 -X）偏移。
func _update_trail_transform() -> void:
	if _trail_sprite == null or not _trail_sprite.visible:
		return
	# 拖尾贴图尾部在弹体后方，约 -28px（基于 0.35 缩放）
	_trail_sprite.rotation = PI  # 贴图朝右，旋转 180° 使其向弹体后方延伸
	_trail_sprite.position = Vector2(-28.0, 0.0)


## v8.4: 轻武器命中特效说明
## 原先有 _SKIP_IMPACT_WEAPON_TYPES=[0,4] 跳过 SMG/PISTOL 命中特效（v6.1 性能优化）。
## 实测发现 SMG/PISTOL 因 attack_speed>2.0 走直射 batch（simple_player/enemy_projectile_batch），
## batch 命中时本就无条件调用 spawn_impact_with_kind，所以跳过列表对它们是死代码。
## 已移除跳过逻辑——batch 路径已有特效，bullet 回退路径（batch 不可用时）也应有特效。
## 轻武器配方在 vfx_impact_factory._impact_recipe 的 0,4 分支（v8.4 已重平衡：少粒子高亮度）。


func _spawn_tex_impact_at(world_pos: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return

	# v8.1: 构造命中特效 opts（暴击/穿透标记），读取后清零
	var opts: Dictionary = {}
	# v12d: 始终传攻击方向(弹丸飞行 _direction)给命中特效——签名武器(轨道炮贯穿/激光灼烧/
	# 欧米茄放电)按真实来弹方向定向。原仅穿透技能传 direction,普通直射命中方向恒为默认右
	# (vfx_impact_factory 里 opts.get("direction", RIGHT) 永远取 RIGHT → 方向错乱)。
	opts["direction"] = _direction
	if _pending_crit:
		opts["is_crit"] = true
	if _pending_pierce:
		opts["is_pierce"] = true
		opts["direction"] = _pierce_dir
		# v9.4: 技能穿透(piercing_shot)标记→首次命中穿甲光线走 enhanced 加宽版
		opts["pierce_enhanced"] = _pierce_from_ability
	_pending_crit = false
	_pending_pierce = false
	# v9.4: 计算 power_tier（命中特效威力分级）——用 damage+explosion_radius 复合判据。
	# 写入 opts 透传给 spawn_impact_with_kind，驱动核武级/重型/中型/轻型视觉分级。
	opts["power_tier"] = WeaponProjectileVfx.compute_power_tier(_visual_wt, explosion_radius, damage)

	# 曲射/空射/火箭/导弹 → 使用完整爆炸特效（v17: 分支键用解析后的 _visual_wt——
	# 武器名明确指向爆炸族（如"防空导弹"）时即使槽位 wt 被降级也走爆炸特效）
	# 新枚举: INDIRECT=1, AERIAL=2
	# 旧枚举: ROCKET=3, FLAK=7, MISSILE=9
	if _visual_wt in [1, 2, 3, 7, 9]:  # INDIRECT, AERIAL, ROCKET, FLAK, MISSILE
		_spawn_impact_explosion(world_pos, opts)
		return

	# v6.0: 武器名查 VFX → 旧 weapon_type 回退
	# v7.x: 透传 _target_combat_kind 实现按目标类型差异化命中色调/缩放
	# v8.1: 透传 opts（暴击/穿透）
	# v17: 全部消费点改用 _visual_wt（WeaponVisualProfiles 解析值）
	if not _weapon_name.is_empty():
		_spawn_impact_v2(parent, world_pos, _weapon_name, opts)
	else:
		WeaponProjectileVfx.spawn_impact_with_kind(parent, world_pos, _visual_wt, shooter_is_player, _target_combat_kind, opts)


## v6.0/v8.0: 新版命中特效（按武器名）— 粒子化
## v8.1: 透传 opts（暴击/穿透）
## v8.4: 透传 weapon_name（重型爆炸武器命中贴图）+ _vfx_variant（改造专属视觉）
func _spawn_impact_v2(parent: Node2D, world_pos: Vector2, weapon_name: String, opts: Dictionary = {}) -> void:
	# v8.0: 统一走 spawn_impact_with_kind（内部自动选颜色+粒子+贴图）
	var _final_opts: Dictionary = opts
	if not _vfx_variant.is_empty():
		_final_opts = opts.duplicate()
		_final_opts["vfx_variant"] = _vfx_variant
	WeaponProjectileVfx.spawn_impact_with_kind(parent, world_pos, _visual_wt, shooter_is_player, _target_combat_kind, _final_opts, weapon_name)


func _finish_tex_bullet() -> void:
	if _finished:
		return
	_finished = true
	if _beam_line:
		_beam_line.visible = false
	# v9.x: 池满回退实例化的游离子弹不在对象池 in_use 字典中，return_object 会被拒导致泄漏。
	# 此前 4 个调用点（construct_unit_ai/enemy_unit/swarm/phase_instrument_abilities）在
	# ObjectPoolManager.get_object("bullets") 返回 null 时回退到 BulletScene.instantiate()，
	# 这些游离子弹从未登记进 in_use，飞完调 return_object 撞上 in_use.has(self) 守卫被直接丢弃，
	# 既不归池也不 queue_free，永久驻留场景树（_process 仍跑、内存只增不减）。
	# 修复：检测自身是否在池的 in_use 字典中，不在则走 queue_free 销毁。
	var pool = ObjectPoolManager._pools.get("bullets", null)
	if pool != null and pool.in_use.has(self):
		ObjectPoolManager.return_object("bullets", self)
	else:
		queue_free()


func _process(delta: float) -> void:
	# 曲射弹道：抛物线飞行
	if _is_indirect:
		_process_indirect(delta)
		return
	# TANK_GUN 命中后淡出计时
	if _tank_gun_terminate:
		_tank_gun_timer += delta
		var life_pct := 1.0 - _tank_gun_timer / TANK_GUN_DISAPPEAR_AFTER
		if _tex_sprite:
			_tex_sprite.modulate.a = maxf(0.0, life_pct)
		if _trail_particles:
			# CPUParticles2D 无 process_material；停止 emitting 后粒子按自身 lifetime 自然消散
			_trail_particles.emitting = _tank_gun_timer < TANK_GUN_DISAPPEAR_AFTER
		return
	# v19-R35: 光束改回【定长尾段】——R16 的"枪口锚定连续光束"在读图时被感知为
	# "一条常亮长条"（用户反馈"激光不能是一直长条施放的"；f08 弹道格亮区横跨 797px）。
	# 真实激光武器 VFX 应是"飞行的弹体 + 身后一段短尾迹"，不是从枪口到弹体的
	# 持续照射线。定长 BEAM_TAIL_LEN，随弹体移动，命中即消失。
	const BEAM_TAIL_LEN: float = 160.0
	if weapon_type == 8 and _beam_line and _beam_line.visible:
		var _tail_local: Vector2 = to_local(global_position - _direction.normalized() * BEAM_TAIL_LEN)
		_beam_line.set_point_position(0, Vector2.ZERO)
		_beam_line.set_point_position(1, _tail_local)
		# v19-R27: 白热内芯同步尾段——与外层宽光束同起点同终点。
		if _tracer_line and _tracer_line.visible:
			_tracer_line.set_point_position(0, Vector2.ZERO)
			_tracer_line.set_point_position(1, _tail_local)
	# v10(H12): 帧前位置（供命中扫掠判定，见下方 _seg_point_dist_sq）
	var _prev_pos: Vector2 = global_position
	# 目标死亡时：直接消失（曲射由 _process_indirect 单独处理）。
	# v10(H13)：穿透中的子弹（已撞过≥1目标且还有穿透次数）不随目标死亡销毁——
	# 沿飞行方向扇形重找下一穿透目标，找不到才回收（原提前销毁使穿透链随目标死亡中断）
	if target == null or not is_instance_valid(target):
		if _pierce_hit_targets.size() > 0 and pierce_count > 0:
			var _next_t: Node2D = _find_next_pierce_target(global_position, _direction)
			if _next_t != null:
				target = _next_t
			else:
				_finish_tex_bullet()
				return
		else:
			_finish_tex_bullet()
			return
	else:
		# v9.3: 穿透子弹（已撞过至少1个目标）保持直线飞行，不跟踪新目标——
		# 穿透语义是"子弹沿原方向直线穿过多个单位"，跟踪会让子弹急转弯不合理
		if _pierce_hit_targets.size() > 0:
			# 保持 _direction 不变，直线继续飞向下一个穿透目标
			pass
		elif weapon_type in [8, 6, 9]:
			# 激光/狙击等保持精准指向目标，其他武器略带跟踪
			_direction = (target.global_position - global_position).normalized()
		else:
			var desired := (target.global_position - global_position).normalized()
			_direction = _direction.lerp(desired, 1.0 - exp(-4.5 * delta)).normalized()
		global_position += _direction * speed * delta
	if _rotates_with_direction:
		rotation = _direction.angle()
	# v6.4: 重型武器拖尾跟随飞行方向（直射类，如 RAIL/OMEGA）
	_update_trail_transform()
	var max_d2: float = max_distance * max_distance
	if _tank_gun_terminate and _tank_gun_timer >= TANK_GUN_DISAPPEAR_AFTER:
		_finish_tex_bullet()
		return
	if global_position.distance_squared_to(_start_position) > max_d2:
		_finish_tex_bullet()
		return
	if target and is_instance_valid(target):
		# v10(H12): 扫掠命中——线段（帧前位置→当前位置）最近点距离 ≤10px 即命中。
		# 高速弹（LASER 1400 / SNIPER 1100 px/s）帧位移 18~23px 超过判定圈直径 20px，
		# 原逐帧点检查存在隧穿漏命中
		if _seg_point_dist_sq(_prev_pos, global_position, target.global_position) < 100.0:
			# v9.2: 穿透去重——同一颗子弹不反复撞已撞过的目标（穿透次数多时尤其重要）
			if target not in _pierce_hit_targets:
				_on_hit(target)

## v10(H12): 点到线段最近距离的平方（扫掠命中判定用，替代逐帧点检查的隧穿缺口）
func _seg_point_dist_sq(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq < 0.0001:
		return a.distance_squared_to(p)
	var t: float = clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	return (a + ab * t).distance_squared_to(p)


## v6.5: 不同曲射武器的弧线高度倍率
## 迫击炮最高弧线（高抛物线），火箭筒最低弧线（接近平射）
# v19-R25: wt1 倍率 1.6→1.0——原弧顶 376px 高于中点，世界 y≈54（屏幕顶边），
# 弹体在截图边缘成小斑点，AI 批"完全缺失弹体"。降至 1.0 后弧顶≈141px，
# 世界 y≈289（画面中部），弧线完整可见。感知优先于弹道学精确。
static func _get_indirect_arc_multiplier(wt: int) -> float:
	match wt:
		1:   # INDIRECT 迫击炮/野战炮 — 中弧线
			# v19-R33: 1.0→0.5——R25 降到 1.0 后弧顶仍在 y=195（画面上 1/3），
			# R32 AI 批"弹道完全缺失只看到枪口火"=弹体飞出 AI 关注区。降至 0.5
			# 使弧顶 y=312（画面中部），弹体始终在可读区域。
			return 0.5
		7:   # FLAK 高射炮 — 较高弧线
			return 1.3
		9:   # MISSILE 导弹 — 低弧线（v19-R33: 1.0→0.5，同 AERIAL；R32 AI 批"弹道缺失"）
			return 0.5
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
	if _rotates_with_direction:
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
	# v17: 枪口火类别键用 _visual_wt（WeaponVisualProfiles 解析值，武器名优先）
	VfxImpactFactory.spawn_muzzle_flash(host, pos, shooter_is_player, _visual_wt)
	# v17c: 枪口贴图层去火球化（AI 评分基线：枪口格均分 3.67，"贴图=命中爆炸效果"高频批评）
	#   ①轻武器（步枪/机枪/手枪/霰弹/动能狙击）撤掉贴图层——真实步枪枪口无大火球，
	#     v17c 粒子参数（瞬发锥形火星）已足够；原 0.35×128px=45px 火球图是"像爆炸"主因之一。
	#   ②贴图按【实测内容尺寸】标定（v16.1 注释误标 32/64px 实为 128px / 1024px 内容 974×597）：
	#     能量喷流 0.11 → ~107px 定向喷流（原 0.50 → 512px 喷满半屏读成能量爆炸）；
	#     重炮爆闪 0.35 → ~44px（原 0.65 → 81px 火球）。
	var muzzle_scale: float = 0.0   # 0 = 不生成贴图层
	var muzzle_life: float = 0.14
	var muzzle_tex: Texture2D = ARTILLERY_MUZZLE_TEX
	if _visual_wt in [8, 10, 11]:  # LASER/OMEGA/RAIL — 能量喷流
		muzzle_scale = 0.14   # v17c-R2: 0.11→0.14 复测批"低功率余晖"，喷流亮体加码
		muzzle_life = 0.14
		muzzle_tex = ENERGY_MUZZLE_TEX
	# v18-R10: 动能狙击(wt=6)也必须有枪口闪光——原条件只覆盖"光束名字武器"，
	# 普通狙击（如 M4A1-Sniper）完全漏配导致 f06_player_muzzle=1/10。
	elif _visual_wt == 6:
		muzzle_scale = 0.10
		muzzle_life = 0.12
		muzzle_tex = ENERGY_MUZZLE_TEX
	elif _visual_wt in HEAVY_TRAIL_WEAPON_TYPES:
		muzzle_scale = 0.42   # v18-R9: flame_jet_v2 内容 160×45 → ~67×19px 水平火舌
		muzzle_life = 0.16
		# v18-R10d: 枪口贴图层回退 MUZZLE_JET_TEX——v2 摄影版暗色基底在枪口位置
		# 被 AI 判为"画面为空"（f00/f04 枪口 6→1/4）。摄影版保留于工厂粒子层
		# （重型枪口粒子 + 拖尾），那里 v2 的黑体色序摄影感更有效。
		muzzle_tex = MUZZLE_JET_TEX
	elif _visual_wt == 0 or _visual_wt == 4:  # v17e: 轻武器 SMG/PISTOL 用前向喷流
		muzzle_scale = 0.30   # v17k: 0.20→0.30（19px 太小，手枪族 3.5 分批"火花不可见"；29px 侧视喷流）
		muzzle_life = 0.14
		muzzle_tex = MUZZLE_JET_TEX
	elif _visual_wt == 5:  # v17k: 霰弹枪口喷流（此前无贴图层，族 3.5 分）
		muzzle_scale = 0.44  # v17m: 0.34→0.44（AI 批"缺散射爆发体量感"）
		muzzle_life = 0.16
		muzzle_tex = MUZZLE_JET_TEX
	if muzzle_scale > 0.0:
		VfxImpactFactory.spawn_impact_sprite(host as Node2D, pos, muzzle_tex, muzzle_scale, muzzle_life)

## wt=6 族混合了动能狙击与光束武器——只有名字带能量语义的才给喷流贴图（v17c）
func _is_beam_named_weapon() -> bool:
	for kw in ["激光", "雷射", "光束", "粒子束", "电磁", "轨道", "磁轨", "射线", "等离子"]:
		if _weapon_name.find(kw) >= 0:
			return true
	return false

func _spawn_impact_explosion(pos: Vector2, opts: Dictionary = {}) -> void:
	# v8.0: 统一走 spawn_impact_with_kind（粒子化）
	# v8.1: 透传 opts（暴击/穿透）
	# v8.4: 透传 _weapon_name（重型爆炸武器命中贴图）+ _vfx_variant（改造专属视觉）
	# v17: wt 用 _visual_wt（WeaponVisualProfiles 解析值）
	var _final_opts: Dictionary = opts
	if not _vfx_variant.is_empty():
		_final_opts = opts.duplicate()
		_final_opts["vfx_variant"] = _vfx_variant
	WeaponProjectileVfx.spawn_impact_with_kind(self, pos, _visual_wt, shooter_is_player, _target_combat_kind, _final_opts, _weapon_name)


## v6.4: 命中时触发屏幕震动——曲射/爆炸类中震动，直射轻震动
## v7.x: 优先用 combat_kind 的震动参数（对轻装轻震/对装甲中震/对空重震），无 combat_kind 走原逻辑
## v9.2: 爆炸震动强度按 explosion_radius 线性映射——大爆炸(OMEGA70/RAIL58)震动显著强于小爆炸(FLAK36)
func _request_hit_shake() -> void:
	if BattleManager == null or not is_instance_valid(BattleManager):
		return
	if not BattleManager.has_method("request_screen_shake"):
		return
	# v9.2: 爆炸震动倍率——半径 40 基准 8.0，每多 1 像素 +0.15（OMEGA70→12.5, RAIL58→10.5, FLAK36→7.7）
	var explosion_mag: float = 8.0
	if explosion_radius > 0.0:
		explosion_mag = maxf(8.0, 8.0 + (explosion_radius - 40.0) * 0.15)
	# v7.x: 有 combat_kind 时按目标类型定震动强度
	if _target_combat_kind >= 0:
		var shake: Vector2 = WeaponProjectileVfx.impact_shake_for_kind(_target_combat_kind)
		if shake.x > 0.0:
			# 爆炸/曲射类增强：combat_kind 基础值 + 爆炸加成（按半径）
			var mag: float = shake.x
			if _is_indirect or explosion_radius > 0.0:
				mag = maxf(mag, explosion_mag)
			BattleManager.request_screen_shake(mag, shake.y)
			return
	# v8.3 视觉增强：fallback 直射 1.8→3.0 / 爆炸按半径
	if _is_indirect or explosion_radius > 0.0:
		BattleManager.request_screen_shake(explosion_mag, 0.35)
	else:
		# v9.4: 按 power_tier 分级震屏（补齐 radius-only 盲区：直射终极武器 radius=0 但伤害高）
		var tier: int = WeaponProjectileVfx.compute_power_tier(weapon_type, explosion_radius, damage)
		match tier:
			3:  # NUCLEAR — 极限震动（与战术核武对齐）
				BattleManager.request_screen_shake(20.0, 0.8)
			2:  # HEAVY — 重打击（直射终极武器：高能弹/重型加农炮）
				BattleManager.request_screen_shake(10.0, 0.45)
			_:
				# v9.3: TANK_GUN 重炮应有重打击感（5.5 vs 原 3.0），与 OMEGA/RAIL 量级对齐
				if DirectWeaponFlavor.classify(_weapon_name, weapon_type) == DirectWeaponFlavor.Flavor.TANK_GUN:
					BattleManager.request_screen_shake(5.5, 0.25)
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
	# P1 性能优化：BattleManager 是 autoload 全局单例，直接引用，
	# 替代原 get_tree().root.get_node_or_null("BattleManager") 的每次命中全树遍历
	var bm: Node = BattleManager if (BattleManager != null and is_instance_valid(BattleManager)) else null
	if bm != null and bm.get("battle_active") == true:
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

## v9.3: 穿透子弹找下一个目标——沿子弹飞行方向，找前方扇形区域内最近且未撞过的敌方单位。
## 复用 spatial_grid.query_nearby 做候选收集（避免全树遍历），再用方向点积筛选"前方"目标。
## search_radius：扫描半径（像素），覆盖三行布局单位间距（约 150~200px）
## dir_threshold：方向点积下限（cos 阈值），>0 表示只选飞行方向前方的目标（不选身后的）
func _find_next_pierce_target(origin: Vector2, fly_dir: Vector2, search_radius: float = 300.0, dir_threshold: float = 0.3) -> Node2D:
	var dir: Vector2 = fly_dir.normalized()
	# P1 性能优化：直接用 autoload 全局引用，替代全树遍历
	var bm: Node = BattleManager if (BattleManager != null and is_instance_valid(BattleManager)) else null
	if bm == null or bm.get("battle_active") != true:
		return null
	var grid: Variant = bm.get("spatial_grid")
	if grid == null or not is_instance_valid(grid) or not grid.has_method("query_nearby"):
		return null
	var best: Node2D = null
	var best_d2: float = 1e12
	for node in grid.query_nearby(origin, search_radius):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue
		if not node.has_method("take_damage"):
			continue
		# 跳过已撞过的目标（穿透去重）
		if _pierce_hit_targets.has(node):
			continue
		var np: Node2D = node as Node2D
		var to_node: Vector2 = (np.global_position - origin)
		var dist: float = to_node.length()
		if dist < 1.0 or dist > search_radius:
			continue
		# 方向筛选：只选飞行方向前方的目标（点积 > 阈值），避免穿透子弹回头打身后的
		var dot: float = to_node.normalized().dot(dir)
		if dot < dir_threshold:
			continue
		var d2: float = dist * dist
		if d2 < best_d2:
			best_d2 = d2
			best = np
	return best

## v9.3: TANK_GUN 命中后淡出（避免与下一发射击叠加，让重炮视觉清晰）
const TANK_GUN_DISAPPEAR_AFTER: float = 0.20  # 命中后保持可见 0.2s（约 12 帧）

## v10(G-4) 结构豁免说明：本函数 ~370 行，按固定段落顺序执行（基础守卫→穿透检测→暴击→
## 武器变异→卡牌能力→TAG 克制→组合技→溅射/连锁→直击结算→命中副作用）。每段自带早退守卫，
## 单次命中只走命中段落；热路径已做缓存优化（out_result/复用字典），拆分收益低于回归风险，
## 按"性能注释豁免"保留；后续重构建议按上述段落拆私有函数。
func _on_hit(primary: Node2D) -> void:
	# v9.3: TANK_GUN 命中后立即开始淡出计时
	if DirectWeaponFlavor.classify(_weapon_name, weapon_type) == DirectWeaponFlavor.Flavor.TANK_GUN:
		_tank_gun_terminate = true
		_tank_gun_timer = 0.0
	# v9.2: 记录已撞目标（穿透去重用，非穿透子弹仅撞一次无副作用）
	if primary != null and not _pierce_hit_targets.has(primary):
		_pierce_hit_targets.append(primary)
	# v8.5: 闪电穿插机制——首次命中时读 shooter 的 _blitz_pierce_bonus meta，加到本弹 pierce_count
	# （meta 由 construct_unit_ai.do_attack_with_damage 在 _blitz_pierce_ready 时挂上，一次性消费）
	if not _blitz_applied and shooter != null and is_instance_valid(shooter):
		_blitz_applied = true
		var bonus: int = int(shooter.get_meta("_blitz_pierce_bonus", 0))
		if bonus > 0:
			pierce_count += bonus
			shooter.remove_meta("_blitz_pierce_bonus")  # 一次性消费
	# v7.x: 提取目标 combat_kind（用于命中特效按目标类型差异化色调/缩放/震动）
	if primary != null:
		var _ts: UnitStats = primary.get("stats") as UnitStats if "stats" in primary else null
		if _ts != null:
			_target_combat_kind = int(_ts.combat_kind)
	if forced_miss:
		var miss_pos: Vector2 = primary.global_position if primary else global_position
		CombatFeedback.show_miss(miss_pos, primary)
		if _rotates_with_direction:
			_spawn_tex_impact_at(miss_pos)
		elif GameManager != null:
			var root := get_parent() as Node2D
			if root != null:
				CardGridFx.spawn_impact(root, miss_pos, weapon_type)
		_finish_tex_bullet()
		return
	if not _rotates_with_direction and GameManager != null:
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
	# v10(C6/C7) 修复：删除"未预计算时再乘防御+强化"块。格子战（唯一战斗模式）中防御由
	# 受击侧 take_damage→CardGridDamage.resolve_hit 统一结算，强化曲线仅在
	# AttackCalculator.calculate_damage_with_weapon 应用一次。原块与受击侧叠加造成：
	# 防御双曲线（100/(100+def) 与 def/(def+50) 各扣一次）+ 强化双乘（0.08 与 0.05 两曲线复合）。
	# _pre_calculated 字段保留仅为 setup API 兼容（第 9 参），已无结算消费方。
	# 词缀战斗效果已移除：直接使用已计算的 damage 值
	var final_damage: float = damage * (1.0 - defender_reduction)
	# v8.1: 穿透检测——命中特效紫色穿甲光线 + pierce 伤害数字样式
	# 检测相位仪 piercing_shot 能力 或 符文 on_attack_penetration（与 attack_calculator 逻辑对齐）
	# v9.2: piercing_shot 能力此前只设 VFX 标记 + 护甲穿透，"穿多目标+衰减"承诺空转。
	#       现真正接通：检测到能力时给 pierce_count 加次数 + 设 _pierce_falloff，让子弹穿透多目标并衰减。
	#       本块由 if not _pending_pierce 守卫，仅首次命中进入（一次性，不重复累加）。
	if not _pending_pierce:
		var pen_ratio: float = 0.0
		# 相位仪直射穿透
		var ability: Dictionary = PhaseInstrumentAbilities.get_active_ability(PhaseInstrumentAbilities.Owner.PLAYER)
		if not ability.is_empty() and String(ability.get("id", "")) == "piercing_shot":
			pen_ratio = maxf(pen_ratio, float(ability.get("params", {}).get("pen_ratio", 0.0)))
			_pierce_from_ability = true  # v9.4: 标记技能穿透，后续命中走 enhanced 穿甲光线
			# v9.2: 接通多单位穿透——加穿透次数 + 设衰减系数（params.pierce_targets 默认 0 兼容旧数据）
			var p_targets: int = int(ability.get("params", {}).get("pierce_targets", 0))
			if p_targets > 0:
				pierce_count += p_targets
			var p_falloff: float = float(ability.get("params", {}).get("falloff_per_target", 0.0))
			if p_falloff > 0.0:
				_pierce_falloff = p_falloff
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
	# v10(L5) 判定顺序声明：暴击在此处（攻击侧）结算 → 受击侧 take_damage→resolve_hit 再做
	# 闪避/防御/减伤——即闪避可以躲掉已判暴击的一击（先攻方暴击、后验守方闪避，设计语义）
	var is_crit: bool = false
	var effective_crit: float = shooter_stats.crit_chance
	if effective_crit > 0.0 and primary != null:
		var target_stats_v: UnitStats = primary.get("stats") as UnitStats if "stats" in primary else null
		if target_stats_v != null and target_stats_v.crit_resist > 0.0:
			effective_crit = maxf(0.0, effective_crit - target_stats_v.crit_resist)
	# v10(H3): ECM 暴击削弱——射手带激活中的 _ecm_crit_penalty 时扣减暴击率（此前四处写零读）
	var _ecm_crit_pen: float = ModuleEffectHandler.get_ecm_crit_penalty(shooter if is_instance_valid(shooter) else null)
	if _ecm_crit_pen > 0.0:
		effective_crit = maxf(0.0, effective_crit - _ecm_crit_pen)
	# v8.x: 暴击标注——被标注目标受到攻击时暴击率额外提升（独立乘区，不受 crit_resist 扣减）
	if primary != null and primary.has_meta("_crit_marked_until"):
		var _cm_expire: float = float(primary.get_meta("_crit_marked_until", 0.0))
		if Time.get_ticks_msec() / 1000.0 < _cm_expire:
			effective_crit += float(primary.get_meta("_crit_mark_bonus", 0.0))
	# v8.x: 指挥光环——射手（shooter）处于 for_13_command_bunker 等光环范围内时暴击率额外提升
	# _apply_command_aura 在 on_tick 里把 meta 挂给范围内友军（射手），此处读取。
	# 此前 meta 写入端完整但战斗侧零读取，现复活 for_13_command_bunker 改造。
	if is_instance_valid(shooter) and shooter.has_meta("_command_aura_until"):
		var _ca_expire: float = float(shooter.get_meta("_command_aura_until", 0.0))
		if Time.get_ticks_msec() / 1000.0 < _ca_expire:
			effective_crit += float(shooter.get_meta("_command_aura_bonus", 0.0))
	# v8.x: SNIPER 首击必爆——射手首次攻击强制暴击（meta 由 construct_unit_ai.do_attack_with_damage 设置）
	if is_instance_valid(shooter) and shooter.has_meta("_first_attack_force_crit"):
		effective_crit = 1.0  # 强制 100% 暴击
		shooter.remove_meta("_first_attack_force_crit")  # 一次性消费
	if effective_crit > 0.0 and randf() < effective_crit:
		is_crit = true
		final_damage *= (1.5 + shooter_stats.crit_damage_bonus)
		_pending_crit = true  # v8.1: 命中特效暴击光环标记
		# v10 转换型：相位偏移（air_16）——目标受暴击时储能，下次攻击必暴
		# （复用 _first_attack_force_crit 既有必暴机制，敌方暴击优势转我方反击）
		if primary != null and is_instance_valid(primary) and "stats" in primary:
			var _ps_stats = primary.get("stats")
			if _ps_stats != null and bool(_ps_stats.get("phase_shift_counter")) and not primary.has_meta("_first_attack_force_crit"):
				primary.set_meta("_first_attack_force_crit", true)
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
	# v8.x: 标签硬克制加成（SNIPER 打 Boss +50%、STEALTH 打指挥 +30%、FORT 对空 +40% 等）
	# v9.2: _atk_tags 改成员数组复用（原每次 new Array）+ compute_tag_counter 按引用填 _tag_result_cache
	if is_instance_valid(shooter) and primary != null:
		_cached_atk_tags.clear()
		if "_behavior_tags_cached" in shooter:
			var _st = shooter.get("_behavior_tags_cached")
			if _st is Array:
				_cached_atk_tags.append_array(_st)  # 复制，避免直接引用外部数组导致 clear 时破坏原数组
		# 兼容 construct_unit：读 stats meta 的 is_stalker/is_sniper 等转成标签
		if _cached_atk_tags.is_empty() and "stats" in shooter and shooter.stats != null:
			if shooter.stats.has_meta("is_sniper") and bool(shooter.stats.get_meta("is_sniper", false)):
				_cached_atk_tags.append("sniper")
			if shooter.stats.has_meta("is_stalker") and bool(shooter.stats.get_meta("is_stalker", false)):
				_cached_atk_tags.append("stalker")
				_cached_atk_tags.append("stealth")
			if shooter.stats.has_meta("is_ecm") and bool(shooter.stats.get_meta("is_ecm", false)):
				_cached_atk_tags.append("ecm")
			if shooter.stats.has_meta("is_engineer") and bool(shooter.stats.get_meta("is_engineer", false)):
				_cached_atk_tags.append("engineer")
		if not _cached_atk_tags.is_empty():
			AttackCalculator.compute_tag_counter_multiplier(_cached_atk_tags, primary, _tag_result_cache)
			final_damage *= float(_tag_result_cache.get("mult", 1.0))
			# v10 解题式玩法：巷战命中惩罚——装甲打巷战步兵"打不中而非打不动"（miss 而非减伤）。
			# 命中惩罚走 forced_miss 同款流程（飘 MISS + 弹着特效 + 回收）。
			var _acc_pen: float = float(_tag_result_cache.get("accuracy_penalty", 0.0))
			if _acc_pen > 0.0 and randf() < _acc_pen:
				var _urban_miss_pos: Vector2 = primary.global_position if primary else global_position
				CombatFeedback.show_miss(_urban_miss_pos, primary)
				if _rotates_with_direction:
					_spawn_tex_impact_at(_urban_miss_pos)
				_finish_tex_bullet()
				return
			# v10 打破型质变效果（strip_fort_aura / ground_aircraft / interrupt_cast / guaranteed_crit）
			var _break_fx: Dictionary = _tag_result_cache.get("break_effect", {})
			if not _break_fx.is_empty() and primary != null and is_instance_valid(primary):
				var _applied: bool = ModuleEffectHandler.apply_break_effect(primary, _break_fx, shooter)
				# guaranteed_crit：狙击对高价值目标必暴（此前未暴时补强制暴击，倍率与主路径一致；
				# 已随机暴击则不叠加）
				if String(_break_fx.get("type", "")) == "guaranteed_crit" and not is_crit:
					is_crit = true
					final_damage *= (1.5 + shooter_stats.crit_damage_bonus)
					_pending_crit = true
				# v10 反馈：质变命中打金色 counter_break 伤害数字（take_damage → unit_damaged 消费）
				# + 广播瓦解横幅信号（Announcer 播报"敌方优势瓦解"）
				if String(_break_fx.get("type", "")) != "guaranteed_crit":
					primary.set_meta("_vfx_counter_pending", true)
					if SignalBus != null and SignalBus.has_signal("counter_break_triggered"):
						var _cb_name: String = String(primary.get("display_name")) if "display_name" in primary else ""
						if _cb_name.is_empty():
							_cb_name = "敌方单位"
						SignalBus.counter_break_triggered.emit(String(_break_fx.get("type", "")), _cb_name)
		# v8.5: 无人机定时标记易伤——目标有 _drone_marked_until（未过期）则伤害 ×(1+vuln)
		if primary != null and is_instance_valid(primary) and primary.has_meta("_drone_marked_until"):
			var _dm_until: int = int(primary.get_meta("_drone_marked_until", 0))
			if Time.get_ticks_msec() < _dm_until:
				var _dm_vuln: float = float(primary.get_meta("_drone_mark_vuln", 0.25))
				final_damage *= (1.0 + _dm_vuln)

		# v10 组合规则③：集火协同——3 秒内被不同友军攻击过的目标，后续攻击伤害 +5%/层（max +15%）
		if primary != null and is_instance_valid(primary):
			var _ff_mult: float = ModuleEffectHandler.apply_focus_fire_multiplier(primary, shooter)
			if _ff_mult > 1.0:
				final_damage *= _ff_mult

	# v9.1: 组合技套路乘区（光束谐振/弱点暴露/化学腐蚀/激光谐振标记）
	# 读 shooter 的 _special flags + 全队激活机制（通过 combo_engine 查询）。
	# 光束武器判定：weapon_type 为 LASER(8)/RAIL(11)。
	var _is_beam: bool = (weapon_type == 8 or weapon_type == 11)
	# v9.1 光束武器伤害加成（套路4 beam_damage_bonus，光纤链路）
	if _is_beam and shooter_stats != null and shooter_stats.beam_damage_bonus > 0.0:
		final_damage *= (1.0 + shooter_stats.beam_damage_bonus)
	var _combo_eng: RefCounted = null
	# P1 性能优化：直接用 autoload 全局引用，替代每次命中全树遍历
	var _bm_combo: Node = BattleManager if (BattleManager != null and is_instance_valid(BattleManager)) else null
	if _bm_combo != null and _bm_combo.has_method("get_combo_engine"):
		_combo_eng = _bm_combo.get_combo_engine()
		if _combo_eng != null and _combo_eng.has_method("get_active_mechanisms"):
			var _mechs: Array = _combo_eng.get_active_mechanisms()
			# 套路4 光束谐振：多重攻击（beam_split）+ 反射（beam_reflect）
			if _is_beam and is_instance_valid(shooter) and primary != null:
				var _beam_res: Dictionary = ComboEngine.try_beam_resonance(_mechs, _combo_eng.get_field_state(), shooter, primary, _is_beam)
				if _beam_res.get("split", false):
					# 多重攻击：追加 2 道次级光束伤害（每道 40%，直接 take_damage 不再生成子弹）
					for _si in range(2):
						if primary.has_method("take_damage"):
							primary.take_damage(final_damage * 0.4, shooter)
					# v9.1 光束分裂 VFX：从主目标射向相邻 2 个敌人
					var _split_pos: Vector2 = (primary.global_position if primary is Node2D else global_position)
					var _split_grp: String = "enemy_units" if shooter_is_player else "player_units"
					var _split_targets: Array = []
					for _n in (get_tree().get_nodes_in_group(_split_grp) if get_tree() != null else []):
						if _n == null or not is_instance_valid(_n) or not (_n is Node2D) or _n == primary:
							continue
						if _split_pos.distance_to((_n as Node2D).global_position) <= 120.0:
							_split_targets.append((_n as Node2D).global_position)
							if _split_targets.size() >= 2:
								break
					var _vfx_parent := get_parent() as Node2D
					if _vfx_parent != null:
						VfxImpactFactory.spawn_beam_split_arcs(_vfx_parent, _split_pos, _split_targets, Color(0.9, 0.8, 1.0))
				if _beam_res.get("reflect", false):
					# 反射：找 1 个相邻敌方单位，衰减 60% 伤害（衰减后 40%）
					var _tpos: Vector2 = (primary.global_position if primary is Node2D else global_position)
					var _grp: String = "enemy_units" if shooter_is_player else "player_units"
					var _reflect_pos: Vector2 = _tpos
					for _n in (get_tree().get_nodes_in_group(_grp) if get_tree() != null else []):
						if _n == null or not is_instance_valid(_n) or not (_n is Node2D) or _n == primary:
							continue
						if _tpos.distance_to((_n as Node2D).global_position) <= 120.0:
							if _n.has_method("take_damage"):
								_n.take_damage(final_damage * 0.4, shooter)   # 衰减 60% → 40%
							_reflect_pos = (_n as Node2D).global_position
							# v9.1 光束反射 VFX
							var _rp := get_parent() as Node2D
							if _rp != null:
								VfxImpactFactory.spawn_beam_reflect_arc(_rp, _tpos, _reflect_pos)
							break
			# 套路5 集火链式弱点暴露：读 shooter _special weakpoint_trigger + 目标有双标记
			if is_instance_valid(shooter) and primary != null:
				var _shooter_stats_v = shooter.get("stats") if "stats" in shooter else null
				var _has_weakpoint_trigger: bool = false
				if _shooter_stats_v != null and _shooter_stats_v.has_meta("mod_special_flags"):
					_has_weakpoint_trigger = (_shooter_stats_v.get_meta("mod_special_flags", {}) as Dictionary).has("weakpoint_trigger")
				if _has_weakpoint_trigger and _mechs.has("weakpoint_expose"):
					var _exposed: bool = ComboEngine.try_weakpoint_expose(_mechs, _combo_eng.get_field_state(), shooter, primary)
					# v9.1 弱点暴露成功 → 在目标身上生成红色 X 指示器
					if _exposed and primary is Node2D:
						var _wp_parent := (primary as Node2D).get_parent() as Node2D
						if _wp_parent != null:
							VfxImpactFactory.spawn_weakpoint_indicator(_wp_parent, (primary as Node2D).global_position, 3.0)
			# v9.1 弱点暴露消费：目标有 _weakpoint_until（未过期）且本次命中是暴击 → 暴击伤害额外 +
			if primary != null and is_instance_valid(primary) and primary.has_meta("_weakpoint_until"):
				var _wp_until: float = float(primary.get_meta("_weakpoint_until", 0.0))
				if Time.get_ticks_msec() / 1000.0 < _wp_until and is_crit:
					var _wp_bonus: float = float(primary.get_meta("_weakpoint_bonus", 0.5))
					final_damage += final_damage * _wp_bonus
					primary.remove_meta("_weakpoint_until")   # 一次性消费
			# v9.1 化学腐蚀（套路6）：目标 _chem_stacks ≥5 时护甲穿透 +20%（通过伤害放大实现）
			if primary != null and is_instance_valid(primary) and _mechs.has("chem_corrosion"):
				if primary.has_meta("_chem_stacks") and int(primary.get_meta("_chem_stacks", 0)) >= 5:
					final_damage *= 1.20
			# v9.1 套路5 雷达锁定易伤：目标有 _radar_locked_until（未过期）则伤害 ×(1+vuln)
			# P1-1：sup_targeting_drone 的 drone_mark_vuln_bonus 已在 _apply_radar_lock_on_hit 叠加进 vuln
			if primary != null and is_instance_valid(primary) and primary.has_meta("_radar_locked_until"):
				var _rl_until: float = float(primary.get_meta("_radar_locked_until", 0.0))
				if Time.get_ticks_msec() / 1000.0 < _rl_until:
					var _rl_vuln: float = float(primary.get_meta("_radar_vuln", 0.15))
					final_damage *= (1.0 + _rl_vuln)

	# 范围伤害
	if explosion_radius > 0.0:
		# v8.1: AOE 爆炸冲击波环（半径=爆炸范围），强化范围感
		var aoe_parent := get_parent() as Node2D
		if aoe_parent != null:
			VfxImpactFactory.spawn_shockwave(aoe_parent, global_position, explosion_radius)
		# v9.2: 大型爆炸全屏微闪——下放核武闪白范式给 OMEGA/RAIL/MISSILE 等大爆炸。
		# 仅 explosion_radius >= 50 触发（OMEGA70/RAIL58/MISSILE55），强度按半径线性增长（0.18~0.32）。
		# 小爆炸(FLAK36/ROCKET40)不闪，避免频繁闪屏；受 BattleSpectacle 内 motion_reduce 控制。
		if explosion_radius >= 50.0 and BattleSpectacle != null and is_instance_valid(BattleSpectacle) and BattleSpectacle.has_method("play_explosion_flash"):
			var _flash_intensity: float = clampf((explosion_radius - 50.0) * 0.004 + 0.18, 0.18, 0.32)
			BattleSpectacle.play_explosion_flash(_flash_intensity)
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
	if primary != null and primary.has_method("take_damage"):
		var final_after_wall: float = _apply_shield_wall_mitigation(final_damage, primary)
		# v9.2: 多单位穿透伤害衰减——主目标命中时 mult=1.0 不衰减；
		# 穿透到后续目标时 mult 已在上一轮 pierce 消费中递减，此处自然应用。
		if _pierce_damage_mult < 1.0:
			final_after_wall *= _pierce_damage_mult
		var atk_primary: Variant = shooter if is_instance_valid(shooter) else null
		# v8.6: 势力技能 first_hit_damage（首次命中伤害加成，take_damage 前乘到伤害上）
		if is_instance_valid(shooter):
			var _fs_extra: float = FactionSkillEffectHandler.on_attack_hit(shooter, primary, is_crit)
			if _fs_extra > 0.0:
				final_after_wall *= (1.0 + _fs_extra)
		primary.take_damage(final_after_wall, atk_primary)
		# v6.2: 符文之语特殊效果 — 攻击命中时触发（闪电链/溅射）
		if is_instance_valid(shooter):
			RuneSpecialHandler.on_hit(shooter, primary, final_after_wall)
			# v6.6: 应用改造命中副作用（连锁/溅射；击杀修复走 unit_killed）——补全低速直射路径缺失的效果
			ModuleEffectHandler.apply_on_hit_side_effects(shooter, primary, final_after_wall)
			# v8.6: 势力技能 extra_attack_chance（概率触发额外一次伤害结算）
			if FactionSkillEffectHandler.roll_extra_attack(shooter):
				primary.take_damage(final_after_wall, atk_primary)
	# v9.2: 多目标穿透视觉——子弹穿透到后续目标（非首次命中）时，在命中点播紫色冲击波环+短穿甲光线，
	# 让玩家清楚看到"这颗子弹穿过了几个单位"。首次命中（_pierce_hit_targets.size()==1）由既有
	# _pending_pierce 机制在命中特效里处理紫色光线，此处只补"后续穿透命中"的视觉。
	if _pierce_hit_targets.size() > 1 and primary != null and is_instance_valid(primary) and primary is Node2D:
		var _pfx_parent: Node2D = get_parent() as Node2D
		if _pfx_parent != null:
			var _pierce_pos: Vector2 = (primary as Node2D).global_position
			# 紫色冲击波环（半径 26，区别于溅射的橙黄大环；技能穿透时加宽环）
			var _pierce_ring_r: float = 36.0 if _pierce_from_ability else 26.0
			VfxImpactFactory.spawn_shockwave(_pfx_parent, _pierce_pos, _pierce_ring_r, Color(0.85, 0.55, 1.0, 0.9))
			# 沿子弹飞行方向的短紫色穿甲光线（强调"穿过"的方向感）
			# v9.4: 技能穿透(piercing_shot)走 enhanced 加宽加长版，区别于普通穿甲
			VfxImpactFactory.spawn_pierce_beam(_pfx_parent, _pierce_pos, _direction, Color(0.85, 0.55, 1.0, 1.0), _pierce_from_ability)
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
	# v9.2: 穿透到下一个目标时递减伤害乘数（每穿一个 ×(1-falloff)，falloff=0 时无衰减=旧行为）
	if _rotates_with_direction:
		_spawn_tex_impact_at(primary.global_position if primary else global_position)
	if pierce_count > 0:
		pierce_count -= 1
		if _pierce_falloff > 0.0:
			_pierce_damage_mult *= (1.0 - _pierce_falloff)
			# 衰减下限保护：避免穿透太多次后伤害趋近 0（保留至少 10% 伤害）
			_pierce_damage_mult = maxf(_pierce_damage_mult, 0.10)
		# v9.3: 穿透后获取下一个目标——沿子弹飞行方向找最近未撞过的敌方单位，
		# 重新赋给 target，让 _process 下一帧的距离检测能命中它。
		# 之前只递减计数/衰减伤害但未重设 target，子弹穿透后永远撞不到第二个目标（既有 bug）。
		var _next_target: Node2D = _find_next_pierce_target(global_position, _direction)
		if _next_target != null:
			target = _next_target
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
	if primary != null and primary.has_method("take_damage"):
		var basic_primary: float = _apply_shield_wall_mitigation(damage, primary)
		var atk_bp: Variant = shooter if is_instance_valid(shooter) else null
		primary.take_damage(basic_primary, atk_bp)
	if _rotates_with_direction:
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
	_weapon_name = ""  # v8.4: 对象池卫生（防复用残留）
	_vfx_variant = ""  # v8.4: 改造视觉标识重置

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
	# v8.x: TANK_GUN 命中淡出状态重置（防对象池复用残留——上一发 TANK_GUN 的淡出
	# 状态会延续到下一发任意武器类型，导致新子弹一出生就立刻淡出消失）
	_tank_gun_terminate = false
	_tank_gun_timer = 0.0
	# v9.2: 穿透去重 + 衰减状态重置
	_pierce_falloff = 0.0
	_pierce_damage_mult = 1.0
	_pierce_hit_targets.clear()
	# v9.2: 标签克制复用清理（防对象池复用残留）
	_cached_atk_tags.clear()
	_tag_result_cache.clear()

	_start_position = Vector2.ZERO
	_direction = Vector2.RIGHT
	_beam_visual_phase = 0
	_use_tex_sprite = false
	_use_tex_sprite = false
	_rotates_with_direction = false  # v9.4: 对象池卫生（防复用残留）

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
