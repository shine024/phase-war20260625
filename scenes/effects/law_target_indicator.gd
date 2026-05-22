extends Node2D
## 主动法则“选点释放”指示器：曲线+箭头 + 范围圆圈脉动
##
## 坐标约定：所有传入都是“战场局部坐标”（与附加到 Battlefield 下的 Node2D 同一坐标系）

var origin_local: Vector2 = Vector2.ZERO
var target_local: Vector2 = Vector2.ZERO
var target_radius: float = 200.0

var _t: float = 0.0
var _redraw_accum: float = 0.0
const REDRAW_INTERVAL_SEC := 0.05

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	_redraw_accum += delta
	if _redraw_accum >= REDRAW_INTERVAL_SEC:
		_redraw_accum = 0.0
		queue_redraw()

func _draw() -> void:
	# 目标半径小到接近 0 时不画范围
	if target_radius <= 0.1:
		_draw_curve_and_arrow()
		return

	var pulse: float = 0.5 + 0.5 * sin(_t * 7.0)
	var alpha_a: float = 0.35 + pulse * 0.35
	var alpha_b: float = 0.15 + pulse * 0.25

	# 范围圆圈（外圈/内圈两层）
	_draw_circle_outline(target_local, target_radius, alpha_a, Color(1.0, 0.85, 0.3, 1.0))
	_draw_circle_outline(target_local, max(1.0, target_radius * 0.75), alpha_b, Color(1.0, 0.95, 0.5, 1.0))

	_draw_curve_and_arrow()

func _draw_circle_outline(center: Vector2, radius: float, alpha: float, base_color: Color) -> void:
	var segments: int = 24
	var c := base_color
	c.a = alpha
	# draw_arc 在 Godot 4 中可作为“轮廓圆”
	draw_arc(center, radius, 0.0, TAU, segments, c)

func _draw_curve_and_arrow() -> void:
	# 由 origin_local 到 target_local 的二次贝塞尔曲线
	var p0: Vector2 = origin_local
	var p2: Vector2 = target_local
	var delta: Vector2 = p2 - p0
	if delta.length() < 0.01:
		return

	# 控制点：中点 + 垂直偏移，让曲线在视觉上有“弧度”
	var mid: Vector2 = (p0 + p2) * 0.5
	var dist: float = delta.length()
	var dir: Vector2 = delta / dist
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	# 统一让弧线朝屏幕下方弯，避免左右方向切换时出现“向上拱”。
	if perp.y < 0.0:
		perp = -perp
	var bend: float = clamp(dist * 0.08, 8.0, 40.0)
	var p1: Vector2 = mid + perp * bend

	var points: Array[Vector2] = []
	var steps: int = 20
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var pt: Vector2 = _quad_bezier(p0, p1, p2, t)
		points.append(pt)

	# 曲线主体
	var curve_alpha: float = 0.55 + 0.25 * sin(_t * 5.0)
	draw_polyline(points, Color(0.35, 0.95, 1.0, curve_alpha), 2.0)

	# 箭头头部
	var p_last: Vector2 = points[points.size() - 1]
	var p_prev: Vector2 = points[points.size() - 2]
	var d: Vector2 = (p_last - p_prev)
	if d.length() < 0.01:
		return
	var n: Vector2 = d.normalized()

	var arrow_len: float = 16.0
	var arrow_half: float = 6.0
	var base: Vector2 = p_last - n * arrow_len
	var side: Vector2 = Vector2(-n.y, n.x) * arrow_half
	var left: Vector2 = base + side
	var right: Vector2 = base - side

	var arrow_color: Color = Color(1.0, 0.95, 0.5, 0.9)
	draw_line(p_last, left, arrow_color, 2.0)
	draw_line(p_last, right, arrow_color, 2.0)
	draw_line(left, base, arrow_color, 2.0)
	draw_line(right, base, arrow_color, 2.0)

func _quad_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	# 二次贝塞尔： (1-t)^2*p0 + 2*(1-t)*t*p1 + t^2*p2
	var u: float = 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

