extends Node2D
## BU-4（战斗界面美化，2026-08-24）：战场氛围层——阵营地面着色 + 前线分界。
## 我方半场青色渐变、敌方半场红色渐变（alpha 上限 0.07 硬约束，再浓会干扰读单位），
## 中间空带正中一条 2px 极淡竖线作"前线"。全部 GradientTexture2D 程序生成，零新美术。
## 层级：z=-9（关卡背景贴图 -10 之上、基地光环 -5 与单位 0 之下）。
## BU-7 预留：时代氛围粒子与暗角后续挂在本节点下。

const Layout = preload("res://scripts/card_grid_battle_layout.gd")
const DT = preload("res://resources/design_tokens.gd")

const VIEWPORT_H: float = 648.0
const TINT_ALPHA_MAX: float = 0.07
const PLAYER_TINT := Color(0.0, 0.7, 0.9)
const ENEMY_TINT := Color(0.85, 0.2, 0.2)
const FRONT_LINE_ALPHA: float = 0.06
## BU-7：粒子预算（gl_compatibility 下 CPUParticles2D 安全，总量 <24 保性能）
const AMBIENCE_PARTICLE_COUNT: int = 20

func _ready() -> void:
	z_index = -9
	_build_ground_tint()
	_build_ambience_particles()

func _build_ground_tint() -> void:
	var mid_x: float = (Layout.BATTLE_X0 + Layout.BATTLE_X1) * 0.5  # = 640，空带正中
	var half_w: float = mid_x - Layout.BATTLE_X0
	var player_tint := _make_tint("PlayerGroundTint", Layout.BATTLE_X0, half_w, PLAYER_TINT, false)
	var enemy_tint := _make_tint("EnemyGroundTint", mid_x, half_w, ENEMY_TINT, true)
	if player_tint != null:
		add_child(player_tint)
	if enemy_tint != null:
		add_child(enemy_tint)
	# 前线分界：极淡竖线（两军对垒的叙事锚点）
	var line := ColorRect.new()
	line.name = "FrontLine"
	line.position = Vector2(mid_x - 1.0, 0.0)
	line.size = Vector2(2.0, VIEWPORT_H)
	line.color = Color(1, 1, 1, FRONT_LINE_ALPHA)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

## 半场着色：强色在外缘、向中线衰减（渐变轴 0=左 → 1=右；右侧半场交换端点即可镜像）。
func _make_tint(node_name: String, x0: float, w: float, tint: Color, fade_from_right: bool) -> TextureRect:
	var grad := Gradient.new()
	var strong := Color(tint.r, tint.g, tint.b, TINT_ALPHA_MAX)
	var weak := Color(tint.r, tint.g, tint.b, 0.0)
	if fade_from_right:
		grad.colors = PackedColorArray([weak, strong])
	else:
		grad.colors = PackedColorArray([strong, weak])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	var tr := TextureRect.new()
	tr.name = node_name
	tr.texture = tex
	tr.position = Vector2(x0, 0.0)
	tr.size = Vector2(w, VIEWPORT_H)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	return tr

## BU-7：时代氛围粒子——按关卡时代切预设（一战/二战飘烟尘、冷战细尘缓落、
## 现代稀尘、近未来青色微粒上浮），发射区覆盖全战场。尊重 is_motion_reduce（停发）。
func _build_ambience_particles() -> void:
	if DT.is_motion_reduce():
		return
	var era := 0
	if GameManager != null and GameManager.has_method("get_era"):
		era = clampi(int(GameManager.get_era(int(GameManager.get("current_level")))), 0, 4)
	var p := CPUParticles2D.new()
	p.name = "EraAmbience"
	p.z_index = 1  # 挂在 z=-9 的本节点下 → 有效 -8（背景之上、单位之下）
	p.position = Vector2(640.0, 290.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(640.0, 290.0)
	p.amount = AMBIENCE_PARTICLE_COUNT
	p.lifetime = 8.0
	p.preprocess = 8.0  # 开局即铺满，不等粒子逐渐出现
	p.local_coords = false
	p.texture = _make_particle_texture()
	match era:
		0, 1:  # 一战/二战：战场烟尘横向漂
			p.color = Color(0.75, 0.74, 0.70, 0.16)
			p.direction = Vector2(1.0, 0.1)
			p.spread = 12.0
			p.gravity = Vector2(8.0, 3.0)
			p.initial_velocity_min = 14.0
			p.initial_velocity_max = 30.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
		2:  # 冷战：细尘/雪意缓落
			p.color = Color(0.85, 0.9, 1.0, 0.20)
			p.direction = Vector2(0.1, 1.0)
			p.spread = 8.0
			p.gravity = Vector2(2.0, 10.0)
			p.initial_velocity_min = 8.0
			p.initial_velocity_max = 18.0
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.0
		3:  # 现代：稀疏尘埃
			p.color = Color(0.8, 0.78, 0.72, 0.13)
			p.direction = Vector2(0.6, 1.0)
			p.spread = 20.0
			p.gravity = Vector2(3.0, 6.0)
			p.initial_velocity_min = 6.0
			p.initial_velocity_max = 14.0
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.5
		_:  # 近未来：全息微粒上浮
			p.color = Color(0.2, 0.9, 1.0, 0.26)
			p.direction = Vector2(0.0, -1.0)
			p.spread = 15.0
			p.gravity = Vector2(0.0, -8.0)
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 24.0
			p.scale_amount_min = 1.2
			p.scale_amount_max = 2.5
	add_child(p)

## 4×4 软圆点贴图（手写径向衰减，纯程序生成零新美术）。
func _make_particle_texture() -> ImageTexture:
	var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for x in range(4):
		for y in range(4):
			var dx: float = float(x) - 1.5
			var dy: float = float(y) - 1.5
			var d: float = sqrt(dx * dx + dy * dy) / 2.12  # 0(中心)~1(角)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
