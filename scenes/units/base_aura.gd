extends Node2D
## BU-2（战斗界面美化，2026-08-24）：基地视觉组件——底座光环 + 落地阴影 + 核心 HP 条
## + 受击白闪/scale punch + 低血（≤30%）红脉动 + 呼吸微光。
## 我方相位场驱动器（青）与敌方相位场驱动器（红）共用；全程序绘制（_draw），零新美术。
## 尊重 DT.is_motion_reduce()：呼吸/脉动静止，受击 punch 关闭（白闪保留为快速衰减，不动画）。

const DT = preload("res://resources/design_tokens.gd")

const _AURA_BASE_ALPHA := 0.18
const _BREATH_PERIOD := 2.4
const _LOW_HP_PULSE_PERIOD := 0.785

var team_color: Color = Color(0.0, 0.85, 1.0, 1.0)
var hp_fill_color: Color = Color(0.2, 0.85, 0.4, 1.0)
var aura_radius: float = 46.0
var core_label: String = "核心"

var _hp_ratio: float = 1.0
var _shield_ratio: float = 0.0
var _hp_cur: float = 0.0
var _hp_max: float = 0.0
var _bar_width: float = 120.0
var _phase: float = 0.0
var _flash: float = 0.0
var _punch_tween: Tween = null
# ── BU-9（战斗界面美化）：能量脉冲 + 受创劣化 + 低血火花 ──
var _pulse_t: float = 0.0      # 能量脉冲计时（每 3s 一轮）
var _pulse_p: float = -1.0     # 当前脉冲进度 0~1；<0 = 无脉冲
var _smoke: CPUParticles2D = null

func setup(aura_color: Color, radius: float, label: String,
		bar_width: float = 120.0, fill_color: Color = Color(0.2, 0.85, 0.4, 1.0)) -> void:
	team_color = aura_color
	hp_fill_color = fill_color
	aura_radius = maxf(24.0, radius)
	core_label = label
	_bar_width = clampf(bar_width, 60.0, 200.0)
	z_index = -5
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_phase += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta / 0.15)
	# BU-9：能量脉冲——每 3s 一圈扩散环（0.9s），motion_reduce 停
	if not DT.is_motion_reduce():
		_pulse_t += delta
		if _pulse_t >= 3.0:
			_pulse_t = 0.0
			_pulse_p = 0.0
		if _pulse_p >= 0.0:
			_pulse_p += delta / 0.9
			if _pulse_p > 1.0:
				_pulse_p = -1.0
	queue_redraw()

func update_hp(cur: float, mx: float) -> void:
	_hp_cur = cur
	_hp_max = mx
	_hp_ratio = clampf(cur / maxf(mx, 1.0), 0.0, 1.0)
	_update_smoke_state()
	queue_redraw()

## boss 护盾占比（0~1，相对 max_hp）——HP 条上方叠一段蓝色护盾条。
func set_shield(ratio: float) -> void:
	_shield_ratio = clampf(ratio, 0.0, 1.0)
	queue_redraw()

## 受击反馈：白闪（0.15s 衰减）+ scale punch（motion_reduce 时只留白闪）。
func flash_hit() -> void:
	_flash = 1.0
	if DT.is_motion_reduce():
		return
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()
	_punch_tween = create_tween()
	_punch_tween.tween_property(self, "scale", Vector2(1.06, 1.06), 0.06)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(self, "scale", Vector2.ONE, 0.10)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _draw() -> void:
	var ground_y: float = aura_radius * 0.55
	# 1) 落地阴影（透视扁圆，增加体积感）
	draw_colored_polygon(
		_ellipse_points(Vector2(0, ground_y), aura_radius * 0.9, aura_radius * 0.28, 20),
		Color(0, 0, 0, 0.35))
	# 2) 底座光环：常态队伍色呼吸；受创劣化（<60%）降饱和+慢闪烁；
	# 低血（≤30%）转红脉动（对齐单位血条低血语言）
	var aura_color: Color = team_color
	var alpha: float = _AURA_BASE_ALPHA
	if _hp_ratio <= 0.3:
		aura_color = DT.COLOR_DANGER
		if not DT.is_motion_reduce():
			var pulse: float = 0.5 + 0.5 * sin(_phase / _LOW_HP_PULSE_PERIOD * TAU)
			alpha = 0.12 + 0.20 * pulse
		else:
			alpha = 0.22
	else:
		if _hp_ratio < 0.6:
			# BU-9：受创劣化——光环降饱和 + 间歇明暗（慢闪烁，1.6s）
			aura_color = team_color.lerp(Color(0.5, 0.5, 0.5), 0.35)
			if not DT.is_motion_reduce():
				var flick: float = 0.5 + 0.5 * sin(_phase / 1.6 * TAU)
				alpha = _AURA_BASE_ALPHA * (0.75 + 0.35 * flick)
		elif not DT.is_motion_reduce():
			alpha = _AURA_BASE_ALPHA + 0.06 * (0.5 + 0.5 * sin(_phase / _BREATH_PERIOD * TAU))
	var ring := _ellipse_points(Vector2(0, ground_y), aura_radius, aura_radius * 0.34, 28)
	draw_colored_polygon(ring, Color(aura_color.r, aura_color.g, aura_color.b, alpha))
	# 光环外缘亮线（首尾闭合）
	var ring_line := ring.duplicate()
	ring_line.append(ring_line[0])
	draw_polyline(ring_line, Color(aura_color.r, aura_color.g, aura_color.b, minf(alpha * 2.2, 0.6)), 2.0)
	# 3) 受击白闪（叠加在光环上，快速衰减）
	if _flash > 0.0:
		draw_colored_polygon(
			_ellipse_points(Vector2(0, ground_y), aura_radius * 1.05, aura_radius * 0.38, 28),
			Color(1, 1, 1, 0.35 * _flash))
	# BU-9：能量脉冲扩散环（scale 0.35→1.4 + alpha 0.5→0）
	if _pulse_p >= 0.0:
		var pr: float = lerpf(aura_radius * 0.35, aura_radius * 1.4, _pulse_p)
		var pa: float = 0.5 * (1.0 - _pulse_p)
		var pring := _ellipse_points(Vector2(0, ground_y), pr, pr * 0.34, 28)
		var pl := pring.duplicate()
		pl.append(pl[0])
		draw_polyline(pl, Color(aura_color.r, aura_color.g, aura_color.b, pa), 2.0)
	# 4) 核心 HP 条（本体上方：护盾段 + HP 段 + 深底）
	var bar_y: float = -(aura_radius + 26.0)
	var w: float = _bar_width
	var h: float = 8.0
	draw_colored_polygon(_rect_points(Vector2(-w * 0.5, bar_y), w, h), Color(0.10, 0.12, 0.16, 0.92))
	if _hp_ratio > 0.0:
		draw_colored_polygon(
			_rect_points(Vector2(-w * 0.5 + 1.0, bar_y + 1.0), (w - 2.0) * _hp_ratio, h - 2.0),
			Color(hp_fill_color.r, hp_fill_color.g, hp_fill_color.b, 0.95))
	if _shield_ratio > 0.0:
		draw_colored_polygon(
			_rect_points(Vector2(-w * 0.5 + 1.0, bar_y - 4.0), (w - 2.0) * _shield_ratio, 3.0),
			Color(0.3, 0.7, 1.0, 0.9))
	# 5) 标签 + 数值（条上方一行，12pt 白字黑描边）
	var font := ThemeDB.fallback_font
	if font != null:
		var text: String = "%s %d/%d" % [core_label, int(ceil(maxf(_hp_cur, 0.0))), int(_hp_max)]
		var pos := Vector2(-w * 0.5, bar_y - 8.0)
		font.draw_string_outline(get_canvas_item(), pos, text,
			HORIZONTAL_ALIGNMENT_CENTER, w, 12, 2, Color(0, 0, 0, 0.85))
		font.draw_string(get_canvas_item(), pos, text,
			HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.92, 0.95, 0.98, 1.0))

static func _ellipse_points(center: Vector2, rx: float, ry: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var ang: float = TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts

## BU-9：低血（<30%）受创火花/烟（12 粒，克制；motion_reduce 不创建）。
func _update_smoke_state() -> void:
	if _hp_ratio < 0.3:
		if _smoke == null:
			_ensure_smoke()
		if _smoke != null:
			_smoke.emitting = true
	elif _smoke != null:
		_smoke.emitting = false

func _ensure_smoke() -> void:
	if DT.is_motion_reduce():
		return
	var p := CPUParticles2D.new()
	p.name = "DamageSmoke"
	p.position = Vector2(0, aura_radius * 0.55)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(aura_radius * 0.5, 6.0)
	p.amount = 12
	p.lifetime = 1.6
	p.local_coords = false
	p.direction = Vector2(0, -1)
	p.spread = 18.0
	p.gravity = Vector2(0, -30.0)
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 26.0
	p.color = Color(0.25, 0.22, 0.2, 0.5)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.texture = _make_dot_texture()
	add_child(p)
	_smoke = p

## 4×4 软圆点贴图（程序生成）。
func _make_dot_texture() -> ImageTexture:
	var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for x in range(4):
		for y in range(4):
			var dx: float = float(x) - 1.5
			var dy: float = float(y) - 1.5
			var d: float = sqrt(dx * dx + dy * dy) / 2.12
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

static func _rect_points(top_left: Vector2, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		top_left,
		top_left + Vector2(w, 0),
		top_left + Vector2(w, h),
		top_left + Vector2(0, h),
	])
