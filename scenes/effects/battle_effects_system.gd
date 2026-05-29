extends Node
## 战斗特效系统：创建炫酷的战斗视觉效果和特效

## 特效类型
enum EffectType {
	ATTACK_MELEE,          # 近战攻击
	ATTACK_RANGED,         # 远程攻击
	ABILITY_CAST,          # 技能释放
	IMPACT,                # 击中效果
	DAMAGE_NUMBER,         # 伤害数字
	BUFF_APPLY,            # 增益施加
	DEBUFF_APPLY,           # 减益施加
	HEAL,                  # 治疗
	DEATH,                 # 死亡
	SUMMON,                # 召唤
	TELEPORT,              # 传送
	SHIELD_BREAK,           # 护盾破碎
	CRITICAL_HIT,           # 暴击
	DODGE,                 # 闪避
	BLOCK,                 # 格挡
	ENVIRONMENTAL           # 环境特效
}

## 特效配置
var effect_config: Dictionary = {
	"enable_particle_effects": true,
	"enable_screen_shake": true,
	"enable_slow_motion": true,
	"effect_quality": "high",  # low, medium, high
	"max_concurrent_effects": 50,
	"effect_scale": 1.0,
	"sound_integration": true
}

## 特效实例池
var effect_pool: Dictionary = {}
var active_effects: Array = []
var _active_count: int = 0

## 材质缓存（避免每次创建 GPUParticles2D 时都 new ParticleProcessMaterial）
var _cached_impact_material: ParticleProcessMaterial = null
var _cached_explosion_material: ParticleProcessMaterial = null
var _cached_death_material: ParticleProcessMaterial = null
var _cached_trail_material: ParticleProcessMaterial = null

## GPUParticles2D 实例池（按类型分桶，减少战斗中的 new/free）
const _GPU_PARTICLE_POOL_MAX := 16
var _gpu_particle_pools: Dictionary = {}

## 场景引用
var effects_root: Node2D = null
var ui_effects_root: Control = null

func _ready() -> void:
	_initialize_effect_system()
	_setup_effect_pools()
	_cache_shared_materials()
	# 低质量预设：移动端、小屏幕、低端 GPU
	var _force_low := false
	if OS.has_feature("mobile"):
		_force_low = true
	elif DisplayServer.screen_get_size().length() < 1400.0:
		_force_low = false  # medium
	else:
		# 检测低端 GPU：OpenGL 3.3 或渲染器名称含关键字
		var rd := RenderingServer.get_rendering_device()
		if rd == null:
			# OpenGL 后端 —— 检查 GL 版本
			var gl_ver := RenderingServer.get_video_adapter_api_version()
			if gl_ver.begins_with("OpenGL 3.3") or gl_ver.begins_with("OpenGL ES 3."):
				_force_low = true
		if not _force_low:
			var gpu_name := RenderingServer.get_video_adapter_name()
			if gpu_name.findn("GeForce GT 6") >= 0 or gpu_name.findn("HD Graphics 4") >= 0 \
				or gpu_name.findn("Intel(R) HD") >= 0 or gpu_name.findn("Radeon HD 7") >= 0 \
				or gpu_name.findn("Mali-4") >= 0 or gpu_name.findn("Adreno 3") >= 0:
				_force_low = true
	if _force_low:
		apply_quality_preset("low")

## 初始化特效系统
func _initialize_effect_system() -> void:
	# 创建特效根节点
	effects_root = Node2D.new()
	effects_root.name = "EffectsRoot"
	get_tree().root.add_child(effects_root)

	ui_effects_root = Control.new()
	ui_effects_root.name = "UIEffectsRoot"
	ui_effects_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_effects_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(ui_effects_root)

	print("[BattleEffects] 战斗特效系统已初始化")

## 设置特效池
func _setup_effect_pools() -> void:
	var effect_types = [
		"slash_effect",
		"impact_effect",
		"magic_circle",
		"explosion",
		"heal_aura",
		"buff_glow",
		"death_burst"
	]

	for effect_type in effect_types:
		effect_pool[effect_type] = []

## 缓存共享材质（避免每次特效创建都 new ParticleProcessMaterial）
func _cache_shared_materials() -> void:
	_cached_impact_material = _create_impact_material()
	_cached_explosion_material = _create_explosion_material()
	_cached_death_material = _create_death_material()
	_cached_trail_material = _create_trail_material()


func _gpu_pool_bucket(pool_key: String) -> Array:
	if not _gpu_particle_pools.has(pool_key):
		_gpu_particle_pools[pool_key] = []
	return _gpu_particle_pools[pool_key] as Array


func _recycle_gpu_particle(pool_key: String, p: GPUParticles2D) -> void:
	if p == null or not is_instance_valid(p):
		return
	p.emitting = false
	var par := p.get_parent()
	if par != null:
		par.remove_child(p)
	var bucket: Array = _gpu_pool_bucket(pool_key)
	if bucket.size() < _GPU_PARTICLE_POOL_MAX:
		bucket.append(p)
	else:
		p.queue_free()


func _borrow_impact_particles() -> GPUParticles2D:
	var bucket: Array = _gpu_pool_bucket("impact")
	var p: GPUParticles2D = null
	while not bucket.is_empty():
		var cand: Variant = bucket.pop_back()
		if cand is GPUParticles2D and is_instance_valid(cand):
			p = cand as GPUParticles2D
			break
	if p == null:
		p = GPUParticles2D.new()
		p.name = "ImpactParticles"
		p.amount = 20
	p.process_material = _cached_impact_material if _cached_impact_material else _create_impact_material()
	p.emitting = true
	return p


func _borrow_trail_particles() -> GPUParticles2D:
	var bucket: Array = _gpu_pool_bucket("trail")
	var p: GPUParticles2D = null
	while not bucket.is_empty():
		var cand: Variant = bucket.pop_back()
		if cand is GPUParticles2D and is_instance_valid(cand):
			p = cand as GPUParticles2D
			break
	if p == null:
		p = GPUParticles2D.new()
		p.name = "Trail"
		p.amount = 50
	p.process_material = _cached_trail_material if _cached_trail_material else _create_trail_material()
	p.emitting = true
	return p


func _borrow_explosion_particles() -> GPUParticles2D:
	var bucket: Array = _gpu_pool_bucket("explosion")
	var p: GPUParticles2D = null
	while not bucket.is_empty():
		var cand: Variant = bucket.pop_back()
		if cand is GPUParticles2D and is_instance_valid(cand):
			p = cand as GPUParticles2D
			break
	if p == null:
		p = GPUParticles2D.new()
		p.name = "ExplosionParticles"
		p.amount = 100
	p.process_material = _cached_explosion_material if _cached_explosion_material else _create_explosion_material()
	p.emitting = true
	return p


func _borrow_death_particles() -> GPUParticles2D:
	var bucket: Array = _gpu_pool_bucket("death")
	var p: GPUParticles2D = null
	while not bucket.is_empty():
		var cand: Variant = bucket.pop_back()
		if cand is GPUParticles2D and is_instance_valid(cand):
			p = cand as GPUParticles2D
			break
	if p == null:
		p = GPUParticles2D.new()
		p.name = "DeathParticles"
		p.amount = 80
	p.process_material = _cached_death_material if _cached_death_material else _create_death_material()
	p.emitting = true
	return p


func _finish_impact_effect(impact: Node2D) -> void:
	if not is_instance_valid(impact):
		return
	_unregister_effect()
	for c in impact.get_children():
		if c is GPUParticles2D:
			_recycle_gpu_particle("impact", c as GPUParticles2D)
	_recycle_wrapper(impact)


func _finish_projectile_effect(projectile: Node2D) -> void:
	if not is_instance_valid(projectile):
		return
	_unregister_effect()
	for c in projectile.get_children():
		if c is GPUParticles2D:
			_recycle_gpu_particle("trail", c as GPUParticles2D)
	_recycle_wrapper(projectile)


func _finish_explosion_effect(explosion: Node2D) -> void:
	if not is_instance_valid(explosion):
		return
	for c in explosion.get_children():
		if c is GPUParticles2D:
			_recycle_gpu_particle("explosion", c as GPUParticles2D)
	_recycle_wrapper(explosion)
	_unregister_effect()


func _finish_death_effect(death: Node2D) -> void:
	if not is_instance_valid(death):
		return
	for c in death.get_children():
		if c is GPUParticles2D:
			_recycle_gpu_particle("death", c as GPUParticles2D)
	_recycle_wrapper(death)
	_unregister_effect()


## 检查并发限制
func _can_spawn_effect() -> bool:
	return _active_count < effect_config.get("max_concurrent_effects", 50)

func _register_effect() -> void:
	_active_count += 1

func _unregister_effect() -> void:
	_active_count = maxi(0, _active_count - 1)

## 战斗特效画质档位（可被设置 UI 调用）
func apply_quality_preset(level: String) -> void:
	match String(level).to_lower():
		"low":
			effect_config["enable_particle_effects"] = false
			effect_config["enable_screen_shake"] = false
			effect_config["enable_slow_motion"] = false
			effect_config["max_concurrent_effects"] = 15
			effect_config["effect_scale"] = 0.75
			effect_config["effect_quality"] = "low"
		"medium":
			effect_config["enable_particle_effects"] = true
			effect_config["enable_screen_shake"] = true
			effect_config["enable_slow_motion"] = false
			effect_config["max_concurrent_effects"] = 28
			effect_config["effect_scale"] = 0.9
			effect_config["effect_quality"] = "medium"
		"high", _:
			effect_config["enable_particle_effects"] = true
			effect_config["enable_screen_shake"] = true
			effect_config["enable_slow_motion"] = true
			effect_config["max_concurrent_effects"] = 50
			effect_config["effect_scale"] = 1.0
			effect_config["effect_quality"] = "high"

## 播放攻击特效
func play_attack_effect(attacker: Node2D, target: Node2D, attack_type: String = "melee") -> void:
	if not effect_config["enable_particle_effects"]:
		return
	if not _can_spawn_effect():
		return

	match attack_type:
		"melee":
		_play_melee_attack_effect(attacker, target)
		"ranged":
		_play_ranged_attack_effect(attacker, target)
		"magic":
		_play_magic_attack_effect(attacker, target)

## 播放近战攻击特效
func _play_melee_attack_effect(attacker: Node2D, target: Node2D) -> void:
	var attacker_pos = attacker.global_position
	var target_pos = target.global_position

	_register_effect()

	# 创建挥砍轨迹
	var slash_effect = _create_slash_effect(attacker_pos, target_pos)
	effects_root.add_child(slash_effect)

	# 创建击中特效
	var impact_effect = _create_impact_effect(target_pos)
	effects_root.add_child(impact_effect)

	# 屏幕震动
	if effect_config["enable_screen_shake"]:
		_apply_screen_shake(3.0, 0.2)

	# 播放音效
	_play_attack_sound("melee")

## 播放远程攻击特效
func _play_ranged_attack_effect(attacker: Node2D, target: Node2D) -> void:
	var attacker_pos = attacker.global_position
	var target_pos = target.global_position

	_register_effect()

	# 创建投射物轨迹
	var projectile = _create_projectile_effect(attacker_pos, target_pos)
	effects_root.add_child(projectile)

	# 创建击中特效
	var impact_effect = _create_impact_effect(target_pos)
	effects_root.add_child(impact_effect)

	_play_attack_sound("ranged")

## 播放魔法攻击特效
func _play_magic_attack_effect(attacker: Node2D, target: Node2D) -> void:
	var target_pos = target.global_position

	_register_effect()

	# 创建魔法圆
	var magic_circle = _create_magic_circle_effect(target_pos)
	effects_root.add_child(magic_circle)

	# 创建爆炸效果
	var explosion = _create_explosion_effect(target_pos)
	effects_root.add_child(explosion)

	if effect_config["enable_screen_shake"]:
		_apply_screen_shake(5.0, 0.3)

	_play_attack_sound("magic")

## 创建挥砍特效
func _create_slash_effect(start_pos: Vector2, end_pos: Vector2) -> Node2D:
	var slash = Line2D.new()
	slash.name = "SlashEffect"
	slash.add_point(start_pos)
	slash.add_point(end_pos)
	slash.default_color = Color(1.0, 0.9, 0.3, 0.8)
	slash.width = 3.0

	# 添加动画
	var tween = create_tween()
	tween.set_parallel(true)

	# 淡入淡出
	slash.modulate.a = 0.0
	tween.tween_property(slash, "modulate:a", 1.0, 0.1)
	tween.tween_property(slash, "modulate:a", 0.0, 0.2)# DELAY: 0.1

	# 移除
	tween.tween_callback(slash.queue_free)# DELAY: 0.3

	return slash

## 创建击中特效
func _create_impact_effect(position: Vector2) -> Node2D:
	var impact = _borrow_wrapper()
	impact.name = "ImpactEffect"
	impact.global_position = position

	# 创建粒子系统
	var particles = _create_impact_particles()
	impact.add_child(particles)

	# 创建闪光
	var flash = ColorRect.new()
	flash.size = Vector2(40, 40)
	flash.position = Vector2(-20, -20)
	flash.color = Color(1.0, 1.0, 1.0, 0.8)
	impact.add_child(flash)

	var tween = create_tween()
	flash.modulate.a = 0.0
	tween.tween_property(flash, "modulate:a", 1.0, 0.05)
	tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	tween.parallel().tween_property(flash, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_callback(_finish_impact_effect.bind(impact))

	return impact

## 创建冲击粒子（池化）
func _create_impact_particles() -> GPUParticles2D:
	return _borrow_impact_particles()

## 创建冲击材质
func _create_impact_material() -> ParticleProcessMaterial:
	var material = ParticleProcessMaterial.new()

	# 设置重力
	material.gravity = Vector3(0, 98, 0)

	# 设置初始速度
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	material.direction = Vector3(0, -1, 0)
	material.spread = 0.5
	material.initial_velocity_min = 50.0
	material.initial_velocity_max = 100.0

	# 设置颜色
	material.color = Color(1.0, 0.8, 0.3, 1.0)

	return material

## 创建投射物特效
func _create_projectile_effect(start_pos: Vector2, target_pos: Vector2) -> Node2D:
	var projectile = _borrow_wrapper()
	projectile.name = "ProjectileEffect"
	projectile.global_position = start_pos

	# 创建投射体精灵
	var sprite = ColorRect.new()
	sprite.size = Vector2(15, 8)
	sprite.position = Vector2(-7.5, -4)
	sprite.color = Color(0.3, 0.8, 1.0, 1.0)
	projectile.add_child(sprite)

	# 创建尾迹粒子
	var trail = _create_projectile_trail()
	projectile.add_child(trail)

	# 移动动画
	var direction = (target_pos - start_pos).normalized()
	var distance = start_pos.distance_to(target_pos)
	var duration = distance / 500.0  # 速度500像素/秒

	var tween = create_tween()
	tween.tween_property(projectile, "global_position", target_pos, duration)

	# 自动清理（回收尾迹粒子）
	tween.tween_callback(_finish_projectile_effect.bind(projectile))

	return projectile

## 创建投射物尾迹（池化）
func _create_projectile_trail() -> GPUParticles2D:
	return _borrow_trail_particles()

## 创建尾迹材质
func _create_trail_material() -> ParticleProcessMaterial:
	var material = ParticleProcessMaterial.new()

	material.gravity = Vector3(0, 0, 0)
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	material.spread = 0.1
	material.initial_velocity_min = 10.0
	material.initial_velocity_max = 20.0
	material.color = Color(0.3, 0.8, 1.0, 0.5)

	return material

## 创建魔法圆特效
func _create_magic_circle_effect(position: Vector2) -> Node2D:
	var magic_circle = _borrow_wrapper()
	magic_circle.name = "MagicCircle"
	magic_circle.global_position = position

	# 创建圆环
	var ring1 = _create_magic_ring(30.0, Color(0.6, 0.4, 1.0, 0.8))
	magic_circle.add_child(ring1)

	var ring2 = _create_magic_ring(50.0, Color(0.3, 0.6, 1.0, 0.6))
	magic_circle.add_child(ring2)

	var ring3 = _create_magic_ring(70.0, Color(0.2, 0.4, 1.0, 0.4))
	magic_circle.add_child(ring3)

	# 旋转动画
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(magic_circle, "rotation", 360.0, 2.0)
	tween.tween_property(magic_circle, "modulate:a", 0.0, 0.5)# DELAY: 1.5

	# 自动清理（回收 wrapper）
	tween.tween_callback(_recycle_wrapper.bind(magic_circle))# DELAY: 2.0

	return magic_circle

## 创建魔法环
func _create_magic_ring(radius: float, color: Color) -> Node2D:
	var ring = Node2D.new()

	var circle = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(0, 64):
		var angle = (PI * 2.0 / 64.0) * i
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	circle.polygon = points
	circle.color = color
	ring.add_child(circle)

	return ring

## 创建爆炸特效
func _create_explosion_effect(position: Vector2) -> Node2D:
	var explosion = _borrow_wrapper()
	explosion.name = "ExplosionEffect"
	explosion.global_position = position

	# 创建爆炸粒子
	var particles = _create_explosion_particles()
	explosion.add_child(particles)

	# 创建冲击波
	var shockwave = _create_shockwave_effect()
	explosion.add_child(shockwave)

	# 屏幕震动
	if effect_config["enable_screen_shake"]:
		_apply_screen_shake(8.0, 0.4)

	# 自动清理（使用 create_timer 避免 Timer.new() 节点）
	var tree = get_tree()
	if tree:
		tree.create_timer(1.0).timeout.connect(_finish_explosion_effect.bind(explosion))

	return explosion

## 创建爆炸粒子（池化）
func _create_explosion_particles() -> GPUParticles2D:
	return _borrow_explosion_particles()

## 创建爆炸材质
func _create_explosion_material() -> ParticleProcessMaterial:
	var material = ParticleProcessMaterial.new()

	material.gravity = Vector3(0, 98, 0)
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 10.0
	material.direction = Vector3(0, 0, 0)
	material.spread = 1.0
	material.initial_velocity_min = 100.0
	material.initial_velocity_max = 200.0
	material.color = Color(1.0, 0.6, 0.2, 1.0)

	return material

## 创建冲击波特效
func _create_shockwave_effect() -> Node2D:
	var shockwave = Node2D.new()

	var wave = ColorRect.new()
	wave.size = Vector2(10, 10)
	wave.position = Vector2(-5, -5)
	wave.color = Color(1.0, 0.9, 0.7, 0.8)
	shockwave.add_child(wave)

	var tween = create_tween()
	tween.set_parallel(true)

	# 扩散动画
	tween.tween_property(wave, "size", Vector2(200, 200), 0.4)
	tween.tween_property(wave, "position", Vector2(-100, -100), 0.4)
	tween.tween_property(wave, "modulate:a", 0.0, 0.4)

	return shockwave

## 播放伤害数字特效
func show_damage_number(target: Node2D, damage: int, damage_type: String = "normal", is_critical: bool = false) -> void:
	var damage_label = _create_damage_label(damage, damage_type, is_critical)
	ui_effects_root.add_child(damage_label)

	# 设置位置
	var screen_pos = _world_to_screen(target.global_position)
	damage_label.position = screen_pos + Vector2(0, -30)

	# 添加动画
	_animate_damage_number(damage_label, is_critical)

## 创建伤害标签
func _create_damage_label(damage: int, damage_type: String, is_critical: bool) -> Label:
	var label = Label.new()
	label.text = str(damage)
	label.add_theme_font_size_override("font_size", 24 if is_critical else 18)
	label.add_theme_color_override("font_color", _get_damage_color(damage_type))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	label.add_theme_color_override("font_shadow_offset", Vector2(2, 2))

	if is_critical:
		label.add_theme_outline_size(2)
		label.add_theme_font_size_override("font_size", 32)
		label.add_theme_color_override("font_outline_color", Color(1.0, 0.2, 0.2, 1))

	return label

## 获取伤害颜色
func _get_damage_color(damage_type: String) -> Color:
	match damage_type:
		"normal":
			return Color(1.0, 1.0, 1.0, 1.0)
		"fire":
			return Color(1.0, 0.5, 0.2, 1.0)
		"ice":
			return Color(0.3, 0.8, 1.0, 1.0)
		"lightning":
			return Color(1.0, 0.9, 0.3, 1.0)
		"poison":
			return Color(0.4, 0.8, 0.3, 1.0)
		"critical":
			return Color(1.0, 0.2, 0.2, 1.0)
		"heal":
			return Color(0.3, 1.0, 0.3, 1.0)
		_:
		return Color(1.0, 1.0, 1.0, 1.0)

## 伤害数字动画
func _animate_damage_number(label: Label, is_critical: bool) -> void:
	var tween = create_tween()
	tween.set_parallel(true)

	# 上升动画
	var start_pos = label.position
	var end_pos = start_pos + Vector2(0, -50)
	tween.tween_property(label, "position", end_pos, 0.8)

	# 淡出动画
	label.modulate.a = 1.0
	tween.tween_property(label, "modulate:a", 0.0, 0.8)

	# 缩放动画（仅暴击）
	if is_critical:
		label.scale = Vector2(0.5, 0.5)
		tween.tween_property(label, "scale", Vector2(1.5, 1.5), 0.2)
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.6)# DELAY: 0.2

	# 清理
	tween.tween_callback(label.queue_free)# DELAY: 0.8

## 播放增益特效
func play_buff_effect(target: Node2D, buff_type: String = "generic") -> void:
	var buff_effect = _create_buff_effect(target.global_position, buff_type)
	effects_root.add_child(buff_effect)

## 创建增益特效
func _create_buff_effect(position: Vector2, buff_type: String) -> Node2D:
	var buff = _borrow_wrapper()
	buff.name = "BuffEffect"
	buff.global_position = position

	var ring = _create_magic_ring(40.0, _get_buff_color(buff_type))
	buff.add_child(ring)

	# 持续光环效果
	var glow = _create_glow_effect(40.0, _get_buff_color(buff_type))
	buff.add_child(glow)

	# 自动清理（回收 wrapper）
	var tree = get_tree()
	if tree:
		tree.create_timer(3.0).timeout.connect(_recycle_wrapper.bind(buff))

	return buff

## 获取增益颜色
func _get_buff_color(buff_type: String) -> Color:
	match buff_type:
		"attack":
			return Color(1.0, 0.3, 0.3, 0.6)
		"defense":
			return Color(0.3, 0.6, 1.0, 0.6)
		"speed":
			return Color(0.3, 1.0, 0.3, 0.6)
		"generic":
			return Color(0.8, 0.8, 0.8, 0.4)
		_:
		return Color(1.0, 1.0, 1.0, 0.4)

## 创建发光特效
func _create_glow_effect(radius: float, color: Color) -> Node2D:
	var glow = Node2D.new()

	var sprite = ColorRect.new()
	sprite.size = Vector2(radius * 2, radius * 2)
	sprite.position = Vector2(-radius, -radius)
	sprite.color = color
	glow.add_child(sprite)

	# 脉冲动画
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "modulate:a", 0.3, 1.0)
	tween.tween_property(sprite, "modulate:a", 0.6, 1.0)

	return glow

## 播放死亡特效
func play_death_effect(target: Node2D) -> void:
	if not _can_spawn_effect():
		return
	var death_effect = _create_death_effect(target.global_position)
	effects_root.add_child(death_effect)

	# 播放死亡音效
	_play_death_sound()

## 创建死亡特效
func _create_death_effect(position: Vector2) -> Node2D:
	var death = _borrow_wrapper()
	death.name = "DeathEffect"
	death.global_position = position

	# 创建死亡粒子
	var particles = _create_death_particles()
	death.add_child(particles)

	# 创建消散效果
	var dissipate = _create_dissipate_effect()
	death.add_child(dissipate)

	# 自动清理（使用 create_timer 避免 Timer.new() 节点）
	var tree = get_tree()
	if tree:
		var t = tree.create_timer(1.5)
		t.timeout.connect(_finish_death_effect.bind(death))

	return death

## 创建死亡粒子（池化）
func _create_death_particles() -> GPUParticles2D:
	return _borrow_death_particles()

## Wrapper 节点池（减少频繁 add_child/queue_free 循环，复用 Node2D 容器）
const _MAX_WRAPPER_POOL: int = 32
var _wrapper_pool: Array = []

func _borrow_wrapper() -> Node2D:
	while not _wrapper_pool.is_empty():
		var candidate: Variant = _wrapper_pool.pop_back()
		if candidate is Node2D and is_instance_valid(candidate):
			for c in candidate.get_children():
				c.get_parent().remove_child(c)
			return candidate
	return Node2D.new()

func _recycle_wrapper(wrapper: Node2D) -> void:
	if not is_instance_valid(wrapper):
		return
	var par := wrapper.get_parent()
	if par != null:
		par.remove_child(wrapper)
	for c in wrapper.get_children():
		if c is GPUParticles2D:
			var type_key := ""
			if c.name.begins_with("Impact"):
				type_key = "impact"
			elif c.name.begins_with("Trail"):
				type_key = "trail"
			elif c.name.begins_with("Explosion"):
				type_key = "explosion"
			elif c.name.begins_with("Death"):
				type_key = "death"
			if not type_key.is_empty():
				_recycle_gpu_particle(type_key, c as GPUParticles2D)
				continue
			if is_instance_valid(c):
				c.get_parent().remove_child(c)
	if _wrapper_pool.size() < _MAX_WRAPPER_POOL:
		_wrapper_pool.append(wrapper)
	else:
		wrapper.queue_free()

## 创建死亡材质
func _create_death_material() -> ParticleProcessMaterial:
	var material = ParticleProcessMaterial.new()

	material.gravity = Vector3(0, -50, 0)  # 向上飘散
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 20.0
	material.direction = Vector3(0, -1, 0)
	material.spread = 0.8
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 80.0
	material.color = Color(0.5, 0.5, 0.5, 1.0)

	return material

## 创建消散特效
func _create_dissipate_effect() -> Node2D:
	var dissipate = Node2D.new()

	# 创建多个碎片
	for i in range(8):
		var shard = _create_shard_effect()
		var angle = (PI * 2.0 / 8.0) * i
		var distance = 30.0
		shard.position = Vector2(cos(angle), sin(angle)) * distance
		dissipate.add_child(shard)

	return dissipate

## 创建碎片特效
func _create_shard_effect() -> Node2D:
	var shard = ColorRect.new()
	shard.size = Vector2(8, 8)
	shard.position = Vector2(-4, -4)
	shard.color = Color(0.6, 0.6, 0.6, 1.0)

	# 飞散动画
	var direction = Vector2(randf() - 0.5, randf() - 0.5).normalized()
	var distance = randf_range(30.0, 50.0)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(shard, "position", shard.position + direction * distance, 0.6)
	tween.tween_property(shard, "modulate:a", 0.0, 0.6)
	tween.tween_property(shard, "rotation", randf() * 360.0, 0.6)

	return shard
## 震动 tween 引用，防止 set_loops 堆积
var _shake_tween: Tween = null

func _apply_screen_shake(intensity: float, duration: float) -> void:
	if not effect_config["enable_screen_shake"]:
		return
	# kill 前一个震动 tween，防止 set_loops 堆积
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	var camera = get_viewport().get_camera_2d()
	if camera == null:
		return

	var original_offset = camera.offset
	var shake_amount = intensity

	_shake_tween = create_tween()
	_shake_tween.set_loops()

	# 随机震动
	for i in range(int(duration * 60)):  # 60fps
		var shake_offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
	_shake_tween.tween_property(camera, "offset", original_offset + shake_offset, 0.016)

# 恢复原位
	_shake_tween.tween_property(camera, "offset", original_offset, 0.1)

## 应用慢动作
func apply_slow_motion(scale: float = 0.5, duration: float = 1.0) -> void:
	if not effect_config["enable_slow_motion"]:
		return

	Engine.time_scale = scale

	var tree = get_tree()
	if tree:
		tree.create_timer(duration).timeout.connect(func():
			Engine.time_scale = 1.0
		)

## 播放攻击音效
func _play_attack_sound(attack_type: String) -> void:
	if not effect_config["sound_integration"]:
		return

	if AudioManager and AudioManager.has_method("play_sfx"):
		match attack_type:
			"melee":
				AudioManager.play_sfx("sword_hit")
			"ranged":
				AudioManager.play_sfx("arrow_hit")
			"magic":
				AudioManager.play_sfx("magic_cast")

## 播放死亡音效
func _play_death_sound() -> void:
	if not effect_config["sound_integration"]:
		return

	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("unit_death")

## 世界坐标转屏幕坐标
func _world_to_screen(world_pos: Vector2) -> Vector2:
	var camera = get_viewport().get_camera_2d()
	if camera != null:
		return camera.get_screen_center_position() + (world_pos - camera.global_position)
	return world_pos

## 清理所有特效
func clear_all_effects() -> void:
	for effect in active_effects:
		if is_instance_valid(effect):
			effect.queue_free()

	active_effects.clear()

## 获取特效配置
func get_effect_config() -> Dictionary:
	return effect_config.duplicate()

## 设置特效配置
func set_effect_config(key: String, value: Variant) -> void:
	if effect_config.has(key):
		effect_config[key] = value

## 获取特效统计
func get_effect_statistics() -> Dictionary:
	return {
		"active_effects": active_effects.size(),
		"effect_config": effect_config,
		"particles_enabled": effect_config["enable_particle_effects"],
		"screen_shake_enabled": effect_config["enable_screen_shake"],
		"slow_motion_enabled": effect_config["enable_slow_motion"]
	}