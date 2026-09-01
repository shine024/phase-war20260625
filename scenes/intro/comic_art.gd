extends Control
## 序章漫画 · 程序化画格绘制器（方案1 占位美术）
## 每格 motif 一幅 1280×720 逻辑画，全 _draw() 矢量生成，零外部贴图依赖；
## 正式美术就位后在 intro_comic_panels.gd 给该格加 "texture" 路径即整体替换。

const W := 1280.0
const H := 720.0

var _motif := ""
var _accent := Color(0.9, 0.7, 0.4)
var _rng := RandomNumberGenerator.new()

func setup(motif: String, accent: Color, seed_val: int) -> void:
	_motif = motif
	_accent = accent
	_rng.seed = seed_val * 1009 + hash(motif)
	queue_redraw()

func _draw() -> void:
	match _motif:
		"insomnia":
			_draw_insomnia()
		"invasion":
			_draw_invasion()
		"future_self":
			_draw_future_self()
		"overlap":
			_draw_overlap()
		"nebula":
			_draw_nebula()
		"cards":
			_draw_cards()
		"timeline":
			_draw_timeline()
		_:
			_grad_bg(Color(0.05, 0.05, 0.07), Color(0.01, 0.01, 0.02))

# ───────────────────── 通用元素 ─────────────────────

func _grad_bg(top: Color, bottom: Color) -> void:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)])
	draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))

func _vignette(strength := 0.55) -> void:
	var s := 150.0
	var k := strength
	var black := Color(0, 0, 0, 1)
	# 上 / 下 / 左 / 右 四边渐暗（外沿强内沿 0）
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, s), Vector2(0, s)]),
		PackedColorArray([Color(black.r, black.g, black.b, k), Color(black.r, black.g, black.b, k), black, black]))
	draw_polygon(PackedVector2Array([Vector2(0, H - s), Vector2(W, H - s), Vector2(W, H), Vector2(0, H)]),
		PackedColorArray([black, black, Color(black.r, black.g, black.b, k), Color(black.r, black.g, black.b, k)]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s, 0), Vector2(s, H), Vector2(0, H)]),
		PackedColorArray([Color(black.r, black.g, black.b, k), black, black, Color(black.r, black.g, black.b, k)]))
	draw_polygon(PackedVector2Array([Vector2(W - s, 0), Vector2(W, 0), Vector2(W, H), Vector2(W - s, H)]),
		PackedColorArray([black, Color(black.r, black.g, black.b, k), Color(black.r, black.g, black.b, k), black]))

func _stars(n: int, col := Color(1, 1, 1)) -> void:
	for i in n:
		var p := Vector2(_rng.randf_range(0, W), _rng.randf_range(0, H))
		var a := _rng.randf_range(0.25, 0.9)
		draw_circle(p, _rng.randf_range(0.6, 2.2), Color(col.r, col.g, col.b, a))

func _glow(pos: Vector2, radius: float, col: Color, steps := 6) -> void:
	for i in steps:
		var t := float(i) / float(steps)
		draw_circle(pos, radius * lerpf(1.0, 0.25, t), Color(col.r, col.g, col.b, col.a * lerpf(0.08, 0.5, t)))

func _crack_points(from: Vector2, to: Vector2, jag: float, depth: int) -> PackedVector2Array:
	var pts := PackedVector2Array([from, to])
	for d in depth:
		var next := PackedVector2Array()
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var perp := (b - a).normalized().orthogonal()
			next.append(a)
			next.append((a + b) * 0.5 + perp * _rng.randf_range(-jag, jag))
		next.append(pts[pts.size() - 1])
		pts = next
		jag *= 0.55
	return pts

func _figure(center: Vector2, height: float, col: Color, glowing := false) -> void:
	var head_r := height * 0.11
	var head_c := center + Vector2(0, -height * 0.5 + head_r)
	if glowing:
		_glow(head_c, head_r * 4.5, col, 5)
	var shoulder := center + Vector2(0, -height * 0.28)
	var w_sh := height * 0.16
	var hip := center + Vector2(0, height * 0.05)
	var w_hip := height * 0.10
	var foot := center + Vector2(0, height * 0.5)
	var pts := PackedVector2Array([
		shoulder + Vector2(-w_sh, 0), shoulder + Vector2(w_sh, 0),
		hip + Vector2(w_hip, 0), foot + Vector2(w_hip * 1.6, 0),
		foot + Vector2(-w_hip * 1.6, 0), hip + Vector2(-w_hip, 0),
	])
	draw_polygon(pts, PackedColorArray([col, col, col, col, col, col]))
	draw_circle(head_c, head_r, col)

func _font() -> Font:
	return get_theme_default_font()

# ───────────────────── 七格 motif ─────────────────────

## B1 第七夜：黑卧室 + 03:47 + 心跳环 + 侧躺剪影
func _draw_insomnia() -> void:
	_grad_bg(Color(0.03, 0.045, 0.08), Color(0.01, 0.01, 0.02))
	var crack := _crack_points(Vector2(880, 40), Vector2(1230, 200), 26.0, 4)
	draw_polyline(crack, Color(0.5, 0.55, 0.65, 0.25), 1.6, true)
	var f := _font()
	if f != null:
		draw_string(f, Vector2(0, 330), "03:47", HORIZONTAL_ALIGNMENT_CENTER, W, 170, Color(0.75, 0.8, 0.9, 0.14))
	var c := Vector2(W * 0.5, 330)
	for i in 3:
		draw_arc(c, 150.0 + i * 62.0, 0, TAU, 64, Color(_accent.r, _accent.g, _accent.b, 0.16 - i * 0.045), 2.0, true)
	var bed_y := H - 130.0
	draw_rect(Rect2(140, bed_y + 40, 620, 18), Color(0.09, 0.10, 0.14))
	draw_rect(Rect2(160, bed_y + 4, 560, 40), Color(0.13, 0.14, 0.2))
	draw_rect(Rect2(160, bed_y - 26, 70, 18), Color(0.16, 0.17, 0.24))
	var body := Color(0.045, 0.05, 0.075)
	draw_circle(Vector2(250, bed_y + 2), 26, body)
	draw_rect(Rect2(280, bed_y - 14, 300, 36), body)
	draw_rect(Rect2(575, bed_y - 6, 110, 22), body)
	_vignette()

## B2 入侵：天裂 + 降临虫群 + 燃烧城市
func _draw_invasion() -> void:
	_grad_bg(Color(0.10, 0.02, 0.02), Color(0.01, 0.005, 0.01))
	_glow(Vector2(640, 100), 260.0, Color(1.0, 0.5, 0.2, 0.5), 6)
	var crack := _crack_points(Vector2(140, 60), Vector2(1150, 150), 40.0, 5)
	draw_polyline(crack, Color(1.0, 0.85, 0.6, 0.9), 4.0, true)
	var crack2 := _crack_points(Vector2(300, 30), Vector2(980, 120), 34.0, 4)
	draw_polyline(crack2, Color(1.0, 0.6, 0.3, 0.5), 2.0, true)
	for i in 46:
		var p := Vector2(_rng.randf_range(60, W - 60), _rng.randf_range(140, 420))
		var s := _rng.randf_range(6.0, 22.0)
		var col := Color(0.02, 0.01, 0.02, _rng.randf_range(0.7, 1.0))
		draw_polygon(PackedVector2Array([p + Vector2(0, s), p + Vector2(-s * 0.7, -s * 0.6), p + Vector2(s * 0.7, -s * 0.6)]),
			PackedColorArray([col, col, col]))
	var x := 0.0
	while x < W:
		var bw := _rng.randf_range(70, 150)
		var bh := _rng.randf_range(60, 190)
		draw_rect(Rect2(x, H - 120 - bh, bw, bh + 120), Color(0.03, 0.02, 0.03))
		for w_i in int(bw / 22.0):
			if _rng.randf() < 0.4:
				draw_rect(Rect2(x + 8 + w_i * 22.0, H - 120 - bh + 12 + _rng.randf_range(0, maxf(1.0, bh - 40)), 6, 9),
					Color(1.0, 0.55, 0.15, _rng.randf_range(0.3, 0.9)))
		x += bw + _rng.randf_range(6, 26)
	_glow(Vector2(W * 0.3, H - 110), 200.0, Color(1.0, 0.4, 0.1, 0.4), 5)
	_glow(Vector2(W * 0.75, H - 110), 160.0, Color(1.0, 0.45, 0.1, 0.35), 5)
	_vignette()

## B3 梦中的“我”：双身影对望 + 递出的手 + 悬浮卡牌
func _draw_future_self() -> void:
	_grad_bg(Color(0.02, 0.04, 0.07), Color(0.005, 0.008, 0.02))
	_stars(50, Color(0.6, 0.75, 1.0))
	draw_rect(Rect2(0, H - 110, W, 110), Color(0.02, 0.03, 0.05))
	draw_line(Vector2(0, H - 110), Vector2(W, H - 110), Color(0.3, 0.5, 0.7, 0.25), 1.5)
	var col_dark := Color(0.05, 0.06, 0.09)
	_figure(Vector2(430, H - 240), 260, col_dark, false)
	_figure(Vector2(850, H - 240), 272, _accent, true)
	draw_line(Vector2(790, H - 210), Vector2(520, H - 205), Color(_accent.r, _accent.g, _accent.b, 0.8), 5.0)
	_glow(Vector2(520, H - 207), 30.0, _accent, 4)
	draw_dashed_line(Vector2(470, H - 300), Vector2(810, H - 300), Color(0.5, 0.7, 0.8, 0.3), 1.2, 8.0)
	var card_c := Vector2(640, H - 345)
	draw_set_transform(card_c, -0.12, Vector2.ONE)
	draw_rect(Rect2(-34, -50, 68, 100), Color(_accent.r, _accent.g, _accent.b, 0.85), false, 2.5)
	draw_circle(card_c + Vector2(0, 0), 6.0, Color(_accent.r, _accent.g, _accent.b, 0.7))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_vignette()

## B4 空间重叠：双圈叠加示意 + 消解粒子
func _draw_overlap() -> void:
	_grad_bg(Color(0.04, 0.02, 0.08), Color(0.01, 0.005, 0.02))
	var ca := Vector2(470, 340)
	var cb := Vector2(810, 340)
	var r := 210.0
	draw_line(Vector2(640, 80), Vector2(640, 600), Color(1, 1, 1, 0.06), 1.0)
	draw_line(Vector2(300, 340), Vector2(980, 340), Color(1, 1, 1, 0.06), 1.0)
	draw_circle(ca, r, Color(0.4, 0.85, 0.95, 0.06))
	draw_arc(ca, r, 0, TAU, 96, Color(0.4, 0.85, 0.95, 0.8), 3.0, true)
	draw_circle(cb, r, Color(0.55, 0.35, 0.95, 0.22))
	draw_arc(cb, r, 0, TAU, 96, Color(0.65, 0.45, 0.95, 0.85), 3.0, true)
	for i in 40:
		var ang := _rng.randf_range(-1.2, 1.2)
		var dist := r + _rng.randf_range(10, 160)
		var p := cb + Vector2(cos(ang), sin(ang)) * dist
		draw_circle(p, _rng.randf_range(1.2, 3.4), Color(0.65, 0.45, 0.95, _rng.randf_range(0.06, 0.4)))
	_glow(Vector2(640, 340), 120.0, Color(0.9, 0.8, 1.0, 0.5), 6)
	draw_circle(Vector2(640, 340), 46.0, Color(0.95, 0.9, 1.0, 0.16))
	var f := _font()
	if f != null:
		draw_string(f, ca + Vector2(-40, -r - 18), "空间 A", HORIZONTAL_ALIGNMENT_CENTER, 80, 20, Color(0.6, 0.85, 0.9, 0.6))
		draw_string(f, cb + Vector2(-40, -r - 18), "空间 B", HORIZONTAL_ALIGNMENT_CENTER, 80, 20, Color(0.75, 0.6, 1.0, 0.6))
	_vignette()

## B5 暗能量星域：星海 + 星云 + 地球航点
func _draw_nebula() -> void:
	_grad_bg(Color(0.015, 0.01, 0.03), Color(0.0, 0.0, 0.005))
	_stars(150, Color(0.85, 0.9, 1.0))
	_glow(Vector2(950, 360), 330.0, Color(0.5, 0.35, 0.95, 0.5), 8)
	_glow(Vector2(300, 190), 190.0, Color(0.3, 0.7, 0.95, 0.35), 6)
	draw_arc(Vector2(-80, 820), 620.0, -0.55, -0.1, 64, Color(0.5, 0.8, 1.0, 0.3), 2.0, true)
	var earth := Vector2(430, 470)
	_glow(earth, 26.0, Color(0.4, 0.75, 1.0, 0.9), 5)
	draw_circle(earth, 9.0, Color(0.55, 0.8, 1.0))
	draw_dashed_line(Vector2(760, 60), Vector2(620, 660), Color(0.6, 0.5, 1.0, 0.25), 1.5, 12.0)
	var f := _font()
	if f != null:
		draw_string(f, Vector2(770, 640), "暗能量活跃星域", HORIZONTAL_ALIGNMENT_LEFT, 300, 18, Color(0.75, 0.65, 1.0, 0.55))
	_vignette()

## B6 卡牌：桌面扇形五卡 + 中央金卡高亮
func _draw_cards() -> void:
	_grad_bg(Color(0.06, 0.045, 0.03), Color(0.015, 0.01, 0.01))
	draw_set_transform(Vector2(640, 500), 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 430.0, Color(0.10, 0.08, 0.06, 0.8))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var n := 5
	for i in n:
		var t := float(i) - float(n - 1) * 0.5
		var raised := i == 2
		var pos := Vector2(640 + t * 150.0, 470.0 + absf(t) * 26.0 - (60.0 if raised else 0.0))
		var col := Color(1.0, 0.78, 0.4) if raised else Color(0.75, 0.62, 0.45, 0.5)
		if raised:
			_glow(pos, 120.0, Color(1.0, 0.72, 0.32, 0.55), 6)
		draw_set_transform(pos, t * 0.14, Vector2.ONE)
		draw_rect(Rect2(-58, -88, 116, 176), Color(0.05, 0.04, 0.05, 0.95))
		draw_rect(Rect2(-58, -88, 116, 176), col, false, 3.0)
		draw_rect(Rect2(-44, -74, 88, 148), Color(col.r, col.g, col.b, 0.18))
		draw_circle(Vector2(0, -6), 14.0, Color(col.r, col.g, col.b, 0.55))
		draw_circle(Vector2(0, -6), 6.0, Color(col.r, col.g, col.b, 0.9))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_vignette()

## B7 毁灭的时间线：断线 + 玻璃碴飞散 + 一枚金色碎片
func _draw_timeline() -> void:
	_grad_bg(Color(0.02, 0.02, 0.03), Color(0.005, 0.004, 0.008))
	var y := 360.0
	var shatter := Vector2(760.0, y)
	draw_line(Vector2(60, y), Vector2(shatter.x - 40, y), Color(0.7, 0.72, 0.8, 0.7), 3.0)
	_glow(shatter, 120.0, Color(1.0, 0.8, 0.35, 0.5), 6)
	for i in 16:
		var ang := _rng.randf_range(0, TAU)
		var dist := _rng.randf_range(30, 260)
		var p := shatter + Vector2(cos(ang), sin(ang)) * dist
		var s := _rng.randf_range(8, 30)
		var a := clampf(0.75 - dist / 400.0, 0.08, 0.75)
		var col := Color(0.8, 0.82, 0.9, a)
		if i == 3:
			col = Color(1.0, 0.84, 0.4, 0.95)
			_glow(p, 40.0, col, 4)
		draw_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.8, s * 0.5), p + Vector2(-s * 0.7, s * 0.6)]),
			PackedColorArray([col, col, col]))
	draw_dashed_line(Vector2(shatter.x + 60, y), Vector2(1220, y), Color(0.5, 0.5, 0.6, 0.25), 2.0, 10.0)
	var f := _font()
	if f != null:
		draw_string(f, Vector2(80, y - 26), "时间线 · 已毁灭", HORIZONTAL_ALIGNMENT_LEFT, 300, 18, Color(0.7, 0.72, 0.8, 0.5))
	_vignette()
