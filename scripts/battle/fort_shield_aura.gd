extends Node2D
## v7.1 堡垒类防护光环 / v7.2 护盾状态光环（纯视觉）
##
## 两种模式（由父节点 set_meta("mode", ...) 指定）：
##   "fort"   — 堡垒职业环（v7.1）：combat_kind==FORT 单位常驻，蓝色/红色呼吸环，
##              表示"这是个防御单位，正在防护"。受击时扩张闪亮。
##   "shield" — 护盾状态环（v7.2）：任何 shield>0 的单位显示，青色环，
##              护盾耗尽自动消失。护盾越少环越淡。巨型能量罩(20000)等护盾源都走此路径。
##
## 数据来源（父节点 set_meta 传入）：
##   mode        — "fort" / "shield"（默认 "fort"）
##   is_player   — 阵营配色（fort 模式用）
##   hit_boost   — 受击强化 0~1（fort 模式用，驱动扩张闪亮）
##   shield_ratio— 护盾比例 0~1（shield 模式用，控制透明度）
##
## 呼吸用全局时间 Time.get_ticks_msec()，无需父节点每帧传动画值。

const MODE_FORT := "fort"
const MODE_SHIELD := "shield"

const AURA_RADIUS: float = 38.0          # 堡垒环基础半径（略大于单位占地）
const SHIELD_RADIUS: float = 46.0        # 护盾环半径（外层，比堡垒环大，表示"罩"在外面）
const BREATH_PERIOD: float = 2.0         # 呼吸周期（秒）
const BREATH_AMP: float = 0.15           # 呼吸幅度
const RING_WIDTH: float = 3.0            # 圆环线宽
const SEGMENTS: int = 40                 # 圆环分段

## 堡垒环配色（按阵营）
const FORT_COLOR_PLAYER := Color(0.35, 0.75, 1.0, 0.55)
const FORT_COLOR_ENEMY := Color(1.0, 0.45, 0.35, 0.55)
const FORT_COLOR_HIT_PLAYER := Color(0.7, 0.95, 1.0, 0.9)
const FORT_COLOR_HIT_ENEMY := Color(1.0, 0.75, 0.6, 0.9)
## 护盾环配色（青色，与堡垒蓝区分；护盾是临时状态，用更亮的青）
const SHIELD_COLOR := Color(0.4, 0.95, 0.85, 0.6)
const SHIELD_COLOR_HIT := Color(0.8, 1.0, 0.95, 0.9)


func _draw() -> void:
	var mode: String = String(get_meta(&"mode", MODE_FORT))
	if mode == MODE_SHIELD:
		_draw_shield()
	else:
		_draw_fort()


## 堡垒职业环：呼吸 + 受击扩张闪亮
func _draw_fort() -> void:
	var is_player: bool = bool(get_meta(&"is_player", true))
	var hit_boost: float = float(get_meta(&"hit_boost", 0.0))

	var t: float = Time.get_ticks_msec() / 1000.0
	var breath: float = 1.0 + BREATH_AMP * (0.5 + 0.5 * sin(t * TAU / BREATH_PERIOD))
	var hit_scale: float = 1.0 + hit_boost * 0.20
	var radius: float = AURA_RADIUS * breath * hit_scale

	var base_color: Color = FORT_COLOR_PLAYER if is_player else FORT_COLOR_ENEMY
	var hit_color: Color = FORT_COLOR_HIT_PLAYER if is_player else FORT_COLOR_HIT_ENEMY
	var ring_color: Color = base_color.lerp(hit_color, hit_boost)

	# 外层柔光晕
	var glow_color := Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * 0.18)
	draw_circle(Vector2.ZERO, radius * 1.25, glow_color)
	# 主圆环
	_draw_ring(radius, ring_color, RING_WIDTH)
	# 受击内环（强化反馈）
	if hit_boost > 0.05:
		var inner_color := Color(hit_color.r, hit_color.g, hit_color.b, hit_boost * 0.7)
		_draw_ring(radius * 0.82, inner_color, RING_WIDTH * 0.7)


## 护盾状态环：护盾存在时显示，透明度随护盾比例衰减；轻微呼吸 + 受击闪亮
func _draw_shield() -> void:
	var shield_ratio: float = clampf(float(get_meta(&"shield_ratio", 0.0)), 0.0, 1.0)
	var hit_boost: float = float(get_meta(&"hit_boost", 0.0))
	if shield_ratio <= 0.0:
		return  # 护盾耗尽，不绘制（父节点会隐藏本节点，此处兜底）

	var t: float = Time.get_ticks_msec() / 1000.0
	# 护盾环呼吸更轻微（护盾是稳定状态，不需要太活跃）
	var breath: float = 1.0 + (BREATH_AMP * 0.6) * (0.5 + 0.5 * sin(t * TAU / (BREATH_PERIOD * 1.5)))
	var hit_scale: float = 1.0 + hit_boost * 0.18
	var radius: float = SHIELD_RADIUS * breath * hit_scale

	# 透明度 = 基础透明度 × 护盾比例（满护盾最实，快耗尽时变淡）+ 受击闪亮叠加
	var base_alpha: float = 0.35 + 0.45 * shield_ratio  # 0.35~0.8
	var ring_color := Color(SHIELD_COLOR.r, SHIELD_COLOR.g, SHIELD_COLOR.b, base_alpha)
	ring_color = ring_color.lerp(SHIELD_COLOR_HIT, hit_boost)

	# 外层柔光晕（护盾罩的扩散感）
	var glow_color := Color(SHIELD_COLOR.r, SHIELD_COLOR.g, SHIELD_COLOR.b, base_alpha * 0.15)
	draw_circle(Vector2.ZERO, radius * 1.3, glow_color)
	# 主护盾环
	_draw_ring(radius, ring_color, RING_WIDTH)
	# 护盾承压时（受击）追加更亮的内描边
	if hit_boost > 0.05:
		var stress_color := Color(SHIELD_COLOR_HIT.r, SHIELD_COLOR_HIT.g, SHIELD_COLOR_HIT.b, hit_boost * 0.6)
		_draw_ring(radius * 0.88, stress_color, RING_WIDTH * 0.6)


## 绘制一个闭合圆环（描边）
func _draw_ring(radius: float, color: Color, width: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(SEGMENTS)
	for i in SEGMENTS:
		var ang: float = TAU * i / SEGMENTS
		pts[i] = Vector2(cos(ang), sin(ang)) * radius
	var closed_pts := pts.duplicate()
	closed_pts.append(pts[0])
	draw_polyline(closed_pts, color, width, true)
