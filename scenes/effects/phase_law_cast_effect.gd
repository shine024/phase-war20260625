extends Node2D
## 相位法则施放特效：简洁电光效果

const _EffectScene = preload("res://scenes/effects/phase_law_cast_effect.tscn")

var effect_color: Color = Color.CYAN
var effect_radius: float = 120.0
var effect_duration: float = 1.8

var _lifetime: float = 0.0

func _ready() -> void:
	_create_lightning_bolts()
	_create_spark_particles()
	_create_ground_ring()

## 电光闪线：从中心向外放射的多条闪电线段
func _create_lightning_bolts() -> void:
	var bolt_count := 8
	for i in range(bolt_count):
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = effect_color
		line.z_index = 10
		add_child(line)

		var angle: float = (TAU / bolt_count) * i + randf_range(-0.2, 0.2)
		var points := PackedVector2Array()
		var segments := 6
		var dist: float = effect_radius * randf_range(0.6, 1.0)
		for s in range(segments + 1):
			var t: float = float(s) / segments
			var base: Vector2 = Vector2(cos(angle), sin(angle)) * dist * t
			var jitter: Vector2 = Vector2(randf_range(-15, 15), randf_range(-15, 15)) * t
			points.append(base + jitter)
		line.points = points

		# 快速淡出
		var tw := create_tween()
		tw.tween_property(line, "modulate:a", 0.0, 0.3 + randf() * 0.2)
		tw.tween_callback(line.queue_free)

## 电火花粒子
func _create_spark_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.lifetime = 0.8
	particles.amount = 30
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 20.0
	particles.speed_scale = 3.0
	particles.gravity = Vector2(0, 100)

	var gradient := Gradient.new()
	gradient.add_point(0.0, Color.WHITE)
	gradient.add_point(0.4, effect_color)
	gradient.add_point(1.0, Color.TRANSPARENT)
	particles.color_ramp = gradient

	var size_curve := Curve.new()
	size_curve.add_point(Vector2(0.0, 1.0))
	size_curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = size_curve

	add_child(particles)

## 简单爆炸：实心圆从中心快速扩大并淡出
func _create_ground_ring() -> void:
	var ring := Polygon2D.new()
	var segments := 48
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = (TAU / segments) * i
		var point: Vector2 = Vector2(cos(angle), sin(angle)) * effect_radius
		points.append(point)
	ring.polygon = points
	ring.color = Color(effect_color.r, effect_color.g, effect_color.b, 0.6)
	ring.z_index = 1
	ring.scale = Vector2(0.1, 0.1)
	add_child(ring)

	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector2(1.0, 1.0), 0.25).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "color:a", 0.0, 0.5)
	tw.tween_callback(ring.queue_free)

func _process(delta: float) -> void:
	_lifetime += delta
	if _lifetime >= effect_duration:
		queue_free()

## 静态创建方法
static func create_phase_law_effect(parent: Node, pos: Vector2, color: Color = Color.CYAN) -> void:
	if not parent or not is_instance_valid(parent):
		return

	# 尝试加载场景文件，如果不存在则直接创建脚本实例
	var effect = null

	if _EffectScene:
		effect = _EffectScene.instantiate()

	if not effect:
		# 如果场景文件不存在，直接创建脚本实例
		effect = new()

	effect.effect_color = color
	effect.position = pos
	parent.add_child(effect)

## 创建钢铁法则效果
static func create_steel_effect(parent: Node, pos: Vector2) -> void:
	create_phase_law_effect(parent, pos, Color(0.7, 0.7, 0.8, 1.0))

## 创建烈焰法则效果
static func create_flame_effect(parent: Node, pos: Vector2) -> void:
	create_phase_law_effect(parent, pos, Color(1.0, 0.4, 0.2, 1.0))

## 创建雷霆法则效果
static func create_thunder_effect(parent: Node, pos: Vector2) -> void:
	create_phase_law_effect(parent, pos, Color(0.4, 0.6, 1.0, 1.0))

## 创建虚空法则效果
static func create_void_effect(parent: Node, pos: Vector2) -> void:
	create_phase_law_effect(parent, pos, Color(0.6, 0.2, 0.8, 1.0))
