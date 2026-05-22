extends Node
## 视觉特效管理器：提供各种视觉特效和动画效果
const DEBUG_VFX_LOG := false

## 特效类型
enum EffectType {
	EXPLOSION,
	HIT,
	HEAL,
	SHIELD,
	BUFF,
	DEBUFF,
	LEVEL_UP,
	CRITICAL,
	MISS,
	SKILL_CAST
}

## 预加载特效场景
var _effect_scenes: Dictionary = {}
const _POOL_META_KEY := "_visual_effects_pool"
const DamageNumberScene = preload("res://scenes/effects/damage_number_display.tscn")
const CastEffectScene = preload("res://scenes/effects/cast_effect.tscn")
const ScreenShakeScene = preload("res://scenes/effects/screen_shake.tscn")

func _ready() -> void:
	_load_effect_scenes()

func _load_effect_scenes() -> void:
	# 预加载常用特效场景（路径均为编译时常量，直接 preload）
	_effect_scenes = {
		"damage_number": preload(_EFFECT_SCENE_PATHS["damage_number"]),
		"cast_effect": preload(_EFFECT_SCENE_PATHS["cast_effect"]),
		"screen_shake": preload(_EFFECT_SCENE_PATHS["screen_shake"]),
	}

static func _get_pool_bucket(effect_key: String) -> Array:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return []
	var root: Window = (loop as SceneTree).root
	if root == null:
		return []
	var pool: Dictionary = root.get_meta(_POOL_META_KEY, {})
	if not pool.has(effect_key):
		pool[effect_key] = []
		root.set_meta(_POOL_META_KEY, pool)
	return pool[effect_key]

static func _set_pool_bucket(effect_key: String, bucket: Array) -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var root: Window = (loop as SceneTree).root
	if root == null:
		return
	var pool: Dictionary = root.get_meta(_POOL_META_KEY, {})
	pool[effect_key] = bucket
	root.set_meta(_POOL_META_KEY, pool)

static func _acquire_effect(effect_key: String) -> Node2D:
	var bucket: Array = _get_pool_bucket(effect_key)
	while not bucket.is_empty():
		var n: Variant = bucket.pop_back()
		if n is Node2D and is_instance_valid(n):
			_set_pool_bucket(effect_key, bucket)
			return n as Node2D
	_set_pool_bucket(effect_key, bucket)
	var fx := Node2D.new()
	fx.name = "Pooled_%s" % effect_key
	match effect_key:
		"explosion":
			var p := CPUParticles2D.new()
			p.name = "P"
			fx.add_child(p)
			var ring := Polygon2D.new()
			ring.name = "Ring"
			fx.add_child(ring)
		"hit":
			var p2 := CPUParticles2D.new()
			p2.name = "P"
			fx.add_child(p2)
			var ring2 := Polygon2D.new()
			ring2.name = "Ring"
			fx.add_child(ring2)
		"heal":
			var p3 := CPUParticles2D.new()
			p3.name = "P"
			fx.add_child(p3)
			var ring3 := Polygon2D.new()
			ring3.name = "Ring"
			fx.add_child(ring3)
	return fx

static func _release_effect(effect_key: String, effect: Node2D) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	for c in effect.get_children():
		if c is CPUParticles2D:
			(c as CPUParticles2D).emitting = false
	effect.visible = false
	effect.position = Vector2.ZERO
	effect.scale = Vector2.ONE
	if effect.get_parent() != null:
		effect.get_parent().remove_child(effect)
	var bucket: Array = _get_pool_bucket(effect_key)
	bucket.append(effect)
	_set_pool_bucket(effect_key, bucket)

## 创建爆炸特效
static func create_explosion(parent: Node, position: Vector2, scale: float = 1.0, color: Color = Color()) -> Node2D:
	if not parent or not is_instance_valid(parent):
		return null

	var explosion: Node2D = _acquire_effect("explosion")
	explosion.position = position
	explosion.scale = Vector2(scale, scale)
	explosion.visible = true
	parent.add_child(explosion)
	var c: Color = color if color != Color() else Color(1.0, 0.6, 0.2, 1.0)
	# 轻量方案：复用 1个 CPUParticles2D + 1个扩散圈
	var p := explosion.get_node_or_null("P") as CPUParticles2D
	if p == null:
		p = CPUParticles2D.new()
		p.name = "P"
		explosion.add_child(p)
	p.amount = 24
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.55
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 180.0
	p.gravity = Vector2(0, 120)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = c
	p.emitting = true
	var ring := explosion.get_node_or_null("Ring") as Polygon2D
	if ring == null:
		ring = Polygon2D.new()
		ring.name = "Ring"
		explosion.add_child(ring)
	var points := PackedVector2Array()
	for i in range(24):
		var ang := (PI * 2.0 * i) / 24.0
		points.append(Vector2(cos(ang), sin(ang)) * 18.0)
	ring.polygon = points
	ring.color = c * Color(1, 1, 1, 0.45)
	ring.modulate.a = 1.0
	ring.scale = Vector2.ONE

	# 自动销毁
	var tween = explosion.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(2.4, 2.4), 0.55).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.55).set_ease(Tween.EASE_IN)
	tween.tween_interval(1.0)
	tween.tween_callback(func(): _release_effect("explosion", explosion))

	return explosion

func _create_explosion_particles(color: Color) -> Node2D:
	var particles = Node2D.new()
	var particle_count = 20

	for i in range(particle_count):
		var particle = ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.position = Vector2.ZERO

		if color == Color():
			particle.color = Color(1.0, 0.6, 0.2, 1.0)  # 默认橙色
		else:
			particle.color = color

		particles.add_child(particle)

		# 随机方向和速度
		var angle = (PI * 2.0 * i) / particle_count
		var speed = randf_range(50, 150)
		var direction = Vector2(cos(angle), sin(angle))

		var tween = particles.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", direction * speed, 0.6).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)

	return particles

func _create_explosion_circles(color: Color) -> Node2D:
	var circles = Node2D.new()

	for i in range(3):
		var circle = Polygon2D.new()
		var points = PackedVector2Array()
		var segments = 32
		var radius = 20.0 + i * 15.0

		for j in range(segments):
			var angle = (PI * 2.0 * j) / segments
			points.append(Vector2(cos(angle), sin(angle)) * radius)

		circle.polygon = points

		if color == Color():
			circle.color = Color(1.0, 0.8, 0.4, 0.6 - i * 0.15)
		else:
			circle.color = color * Color(1, 1, 1, 0.6 - i * 0.15)

		circles.add_child(circle)

		# 扩散动画
		var tween = circles.create_tween()
		tween.set_parallel(true)
		tween.tween_property(circle, "scale", Vector2(2.5, 2.5), 0.8).set_ease(Tween.EASE_OUT)
		tween.tween_property(circle, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)

	return circles

## 创建命中特效
static func create_hit_effect(parent: Node, position: Vector2, is_critical: bool = false) -> void:
	if not parent or not is_instance_valid(parent):
		return

	var hit_effect: Node2D = _acquire_effect("hit")
	hit_effect.position = position
	hit_effect.visible = true
	parent.add_child(hit_effect)
	var p := hit_effect.get_node_or_null("P") as CPUParticles2D
	if p == null:
		p = CPUParticles2D.new()
		p.name = "P"
		hit_effect.add_child(p)
	p.amount = 12 if is_critical else 8
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.25
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 160.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.5
	p.color = Color(1.0, 0.95, 0.75, 1.0)
	p.emitting = true
	var shockwave := hit_effect.get_node_or_null("Ring") as Polygon2D
	if shockwave == null:
		shockwave = Polygon2D.new()
		shockwave.name = "Ring"
		hit_effect.add_child(shockwave)
	var points := PackedVector2Array()
	var r: float = 14.0 if is_critical else 10.0
	for i in range(20):
		var ang := (PI * 2.0 * i) / 20.0
		points.append(Vector2(cos(ang), sin(ang)) * r)
	shockwave.polygon = points
	shockwave.color = Color(1.0, 0.9, 0.6, 0.65)
	shockwave.modulate.a = 1.0
	shockwave.scale = Vector2.ONE

	# 闪烁动画
	var tween = hit_effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(shockwave, "scale", Vector2(2.6, 2.6), 0.28).set_ease(Tween.EASE_OUT)
	tween.tween_property(shockwave, "modulate:a", 0.0, 0.28).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _release_effect("hit", hit_effect))

func _create_shockwave(is_critical: bool = false) -> Node2D:
	var shockwave = Polygon2D.new()
	var points = PackedVector2Array()
	var segments = 24
	var radius = 15.0 if is_critical else 10.0

	for i in range(segments):
		var angle = (PI * 2.0 * i) / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	shockwave.polygon = points
	shockwave.color = Color(1.0, 0.9, 0.6, 0.8)

	var tween = shockwave.create_tween()
	tween.set_parallel(true)
	tween.tween_property(shockwave, "scale", Vector2(3.0, 3.0), 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(shockwave, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)

	return shockwave

## 创建治疗特效
static func create_heal_effect(parent: Node, position: Vector2, amount: int = 0) -> void:
	if not parent or not is_instance_valid(parent):
		return

	var heal_effect: Node2D = _acquire_effect("heal")
	heal_effect.position = position
	heal_effect.visible = true
	parent.add_child(heal_effect)
	var aura := heal_effect.get_node_or_null("Ring") as Polygon2D
	if aura == null:
		aura = Polygon2D.new()
		aura.name = "Ring"
		heal_effect.add_child(aura)
	var points := PackedVector2Array()
	for i in range(20):
		var ang := (PI * 2.0 * i) / 20.0
		points.append(Vector2(cos(ang), sin(ang)) * 22.0)
	aura.polygon = points
	aura.color = Color(0.2, 1.0, 0.4, 0.55)
	aura.modulate.a = 1.0
	aura.scale = Vector2.ONE
	var p := heal_effect.get_node_or_null("P") as CPUParticles2D
	if p == null:
		p = CPUParticles2D.new()
		p.name = "P"
		heal_effect.add_child(p)
	p.amount = 10
	p.one_shot = true
	p.lifetime = 0.7
	p.direction = Vector2.UP
	p.spread = 45.0
	p.initial_velocity_min = 35.0
	p.initial_velocity_max = 85.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	p.color = Color(0.4, 1.0, 0.6, 0.95)
	p.emitting = true

	# 动画
	var tween = heal_effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(aura, "scale", Vector2(2.0, 2.0), 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(aura, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _release_effect("heal", heal_effect))

	# 显示治疗数字
	if amount > 0:
		DamageNumberDisplay.create_heal_number(parent, position + Vector2(0, -30), amount)

func _create_rising_particles(color: Color) -> Node2D:
	var particles = Node2D.new()
	var particle_count = 12

	for i in range(particle_count):
		var particle = ColorRect.new()
		particle.size = Vector2(3, 3)
		particle.position = Vector2(randf_range(-15, 15), randf_range(-15, 15))
		particle.color = color
		particles.add_child(particle)

		# 上升动画
		var rise_distance = randf_range(30, 60)
		var duration = randf_range(0.6, 1.0)

		var tween = particles.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position:y", particle.position.y - rise_distance, duration).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)

	return particles

## 创建护盾特效
static func create_shield_effect(parent: Node, position: Vector2) -> void:
	if not parent or not is_instance_valid(parent):
		return

	var shield_effect = Node2D.new()
	shield_effect.position = position
	parent.add_child(shield_effect)

	# 创建护盾圆圈
	var shield = Polygon2D.new()
	var points = PackedVector2Array()
	var segments = 32
	var radius = 30.0

	for i in range(segments):
		var angle = (PI * 2.0 * i) / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	shield.polygon = points
	shield.color = Color(0.2, 0.8, 1.0, 0.7)
	shield_effect.add_child(shield)

	# 护盾闪烁动画
	var tween = shield_effect.create_tween()
	tween.set_loops(2)
	tween.tween_property(shield, "modulate:a", 0.3, 0.3).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(shield, "modulate:a", 0.7, 0.3).set_ease(Tween.EASE_IN_OUT)

	# 自动销毁
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(shield_effect):
		shield_effect.queue_free()

## 创建升级特效
static func create_level_up_effect(parent: Node, position: Vector2) -> void:
	if not parent or not is_instance_valid(parent):
		return

	var level_effect = Node2D.new()
	level_effect.position = position
	parent.add_child(level_effect)

	# 创建升级光柱
	var beam = ColorRect.new()
	beam.size = Vector2(60, 200)
	beam.position = -beam.size / 2 + Vector2(0, -100)
	beam.color = Color(1.0, 0.8, 0.3, 0.4)
	level_effect.add_child(beam)

	# 创建扩散圆环
	for i in range(3):
		var ring = _create_level_up_ring(i)
		level_effect.add_child(ring)

	# 创建文字
	var level_text = Label.new()
	level_text.text = "LEVEL UP!"
	level_text.add_theme_font_size_override("font_size", 24)
	level_text.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	level_text.position = Vector2(-50, -30)
	level_effect.add_child(level_text)

	# 文字动画
	var text_tween = level_effect.create_tween()
	text_tween.set_parallel(true)
	text_tween.tween_property(level_text, "position:y", level_text.position.y - 50, 1.0).set_ease(Tween.EASE_OUT)
	text_tween.tween_property(level_text, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)

	# 自动销毁
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(level_effect):
		level_effect.queue_free()

func _create_level_up_ring(index: int) -> Polygon2D:
	var ring = Polygon2D.new()
	var points = PackedVector2Array()
	var segments = 32
	var radius = 20.0 + index * 15.0

	for i in range(segments):
		var angle = (PI * 2.0 * i) / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	ring.polygon = points
	ring.color = Color(1.0, 0.9, 0.4, 0.8 - index * 0.2)

	var tween = ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(3.0, 3.0), 1.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
	tween.tween_delay(0.2 * index)

	return ring

## 创建技能施放特效
static func create_skill_cast_effect(parent: Node, position: Vector2, skill_color: Color = Color()) -> void:
	if not parent or not is_instance_valid(parent):
		return

	var cast_effect = Node2D.new()
	cast_effect.position = position
	parent.add_child(cast_effect)

	if skill_color == Color():
		skill_color = Color(0.6, 0.4, 1.0, 1.0)  # 默认紫色

	# 创建法阵
	var magic_circle = _create_magic_circle(skill_color)
	cast_effect.add_child(magic_circle)

	# 创建能量聚集
	var energy_gather = _create_energy_gather(skill_color)
	cast_effect.add_child(energy_gather)

	# 自动销毁
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(cast_effect):
		cast_effect.queue_free()

func _create_magic_circle(color: Color) -> Node2D:
	var circle = Node2D.new()

	# 创建外圈
	var outer_ring = Polygon2D.new()
	var outer_points = PackedVector2Array()
	var outer_segments = 32

	for i in range(outer_segments):
		var angle = (PI * 2.0 * i) / outer_segments
		outer_points.append(Vector2(cos(angle), sin(angle)) * 40.0)

	outer_ring.polygon = outer_points
	outer_ring.color = color * Color(1, 1, 1, 0.6)
	circle.add_child(outer_ring)

	# 创建内圈
	var inner_ring = Polygon2D.new()
	var inner_points = PackedVector2Array()
	var inner_segments = 24

	for i in range(inner_segments):
		var angle = (PI * 2.0 * i) / inner_segments
		inner_points.append(Vector2(cos(angle), sin(angle)) * 25.0)

	inner_ring.polygon = inner_points
	inner_ring.color = color * Color(1, 1, 1, 0.8)
	circle.add_child(inner_ring)

	# 旋转动画
	var tween = circle.create_tween()
	tween.set_loops()
	tween.tween_property(circle, "rotation", 2.0 * PI, 2.0).set_ease(Tween.EASE_IN_OUT)

	return circle

func _create_energy_gather(color: Color) -> Node2D:
	var gather = Node2D.new()
	var particle_count = 16

	for i in range(particle_count):
		var particle = ColorRect.new()
		particle.size = Vector2(4, 4)
		var start_angle = (PI * 2.0 * i) / particle_count
		var start_distance = 80.0
		particle.position = Vector2(cos(start_angle), sin(start_angle)) * start_distance
		particle.color = color
		gather.add_child(particle)

		# 向中心聚集动画
		var duration = 0.8
		var tween = gather.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", Vector2.ZERO, duration).set_ease(Tween.EASE_IN)
		tween.tween_property(particle, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)

	return gather

## 创建屏幕震动效果
static func create_screen_shake(camera: Camera2D, intensity: float = 5.0, duration: float = 0.3) -> void:
	if not camera or not is_instance_valid(camera):
		return

	var original_offset = camera.offset
	var shake_count = 10

	var tween = camera.create_tween()
	for i in range(shake_count):
		var random_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(camera, "offset", random_offset, duration / shake_count)

	tween.tween_property(camera, "offset", original_offset, duration / shake_count)

## 创建连击特效
static func create_combo_effect(parent: Node, position: Vector2, combo_count: int) -> void:
	if not parent or not is_instance_valid(parent):
		return

	var combo_effect = Node2D.new()
	combo_effect.position = position + Vector2(0, -50)
	parent.add_child(combo_effect)

	# 创建连击文字
	var combo_label = Label.new()
	combo_label.text = "%d COMBO!" % combo_count
	combo_label.add_theme_font_size_override("font_size", 20 + min(combo_count, 10) * 2)
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.8 - min(combo_count * 0.05, 0.5), 0.2, 1.0))
	combo_effect.add_child(combo_label)

	# 文字动画
	var tween = combo_effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(combo_label, "position:y", -30, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(combo_label, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_property(combo_effect, "scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(combo_effect, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_IN)

	# 自动销毁
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(combo_effect):
		combo_effect.queue_free()
