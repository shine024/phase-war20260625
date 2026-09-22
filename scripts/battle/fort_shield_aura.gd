extends Node2D
## v7.1 堡垒类防护光环 / v7.2 护盾状态光环（纯视觉）
##
## 两种模式（由父节点 set_meta("mode", ...) 指定）：
##   "fort"   — 堡垒职业环（v7.1）：combat_kind==FORT 单位常驻，蓝色/红色呼吸环，
##              表示"这是个防御单位，正在防护"。受击时扩张闪亮。
##   "shield" — 护盾状态罩（v7.2 脚下环 → v38.x 上半穹顶弧重设计）：
##              任何 shield>0 的单位显示，青色穹顶罩在立绘上方（z=5，血条 z=20 之下），
##              护盾耗尽自动消失。护盾越少越淡。巨型能量罩(20000)等护盾源都走此路径。
##              三态动画：获得（scale-in+亮闪 0.25s）/ 持续（呼吸+比例透明度）/
##              击碎（宿主 set_meta("breaking") 触发 0.3s 扩张淡出后自隐藏）。
##
## 数据来源（父节点 set_meta 传入）：
##   mode        — "fort" / "shield"（默认 "fort"）
##   is_player   — 阵营配色（fort 模式用）
##   hit_boost   — 受击强化 0~1（fort 模式用，驱动扩张闪亮）
##   shield_ratio— 护盾比例 0~1（shield 模式用，控制透明度）
##   spawn_msec  — shield 模式：创建时刻（Time.get_ticks_msec()），驱动获得态
##   breaking_msec — shield 模式：盾破时刻，驱动击碎态（宿主在 shield 归零时写入）
##
## 呼吸用全局时间 Time.get_ticks_msec()，无需父节点每帧传动画值。

const MODE_FORT := "fort"
const MODE_SHIELD := "shield"

const AURA_RADIUS: float = 38.0          # 堡垒环基础半径（略大于单位占地）
const SHIELD_RADIUS: float = 52.0        # v7.x: 护盾环从46加大到52，更明显
const BREATH_PERIOD: float = 2.0         # 呼吸周期（秒）
const BREATH_AMP: float = 0.15           # 呼吸幅度
const RING_WIDTH: float = 3.0            # 圆环线宽
const SHIELD_RING_WIDTH: float = 4.5     # v7.x: 护盾环线宽加粗
const SEGMENTS: int = 40                 # 圆环分段
# v38.x G 条：护盾穹顶三态动画时长
const SHIELD_SPAWN_SEC: float = 0.25     # 获得态：scale-in + 亮闪
const SHIELD_BREAK_SEC: float = 0.30     # 击碎态：扩张 + 淡出
const DOME_OVERHANG_RAD: float = 0.35    # 穹顶弧两侧下垂角（弧度，~20°）

## 堡垒环配色（按阵营）
const FORT_COLOR_PLAYER := Color(0.35, 0.75, 1.0, 0.55)
const FORT_COLOR_ENEMY := Color(1.0, 0.45, 0.35, 0.55)
const FORT_COLOR_HIT_PLAYER := Color(0.7, 0.95, 1.0, 0.9)
const FORT_COLOR_HIT_ENEMY := Color(1.0, 0.75, 0.6, 0.9)
## 护盾环配色（青色，与堡垒蓝区分；护盾是临时状态，用更亮的青）
const SHIELD_COLOR := Color(0.3, 1.0, 0.95, 0.75)   # v7.x: 提高透明度0.6→0.75
const SHIELD_COLOR_HIT := Color(0.8, 1.0, 1.0, 1.0)  # v7.x: 受击时更亮


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


## 护盾状态罩（v38.x G 条重设计）：上半穹顶弧 + 渐变填充，罩在立绘上方。
## 三态：获得（scale-in+亮闪）→ 持续（呼吸 + 比例透明度 + 受击闪亮）→ 击碎（扩张淡出）。
func _draw_shield() -> void:
	var shield_ratio: float = clampf(float(get_meta(&"shield_ratio", 0.0)), 0.0, 1.0)
	var hit_boost: float = float(get_meta(&"hit_boost", 0.0))
	if shield_ratio <= 0.0 and not has_meta(&"breaking_msec"):
		return  # 护盾耗尽且非击碎态，不绘制（父节点会隐藏本节点，此处兜底）

	var now_msec: int = Time.get_ticks_msec()
	var t: float = now_msec / 1000.0

	# ── 击碎态：半径扩张 + 整体淡出，动画结束后自隐藏 ──
	var break_k: float = -1.0
	if has_meta(&"breaking_msec"):
		break_k = float(now_msec - int(get_meta(&"breaking_msec"))) / (SHIELD_BREAK_SEC * 1000.0)
		if break_k >= 1.0:
			visible = false
			remove_meta(&"breaking_msec")
			return
		break_k = clampf(break_k, 0.0, 1.0)

	# ── 获得态：scale-in（0.35→1 ease-out）+ 亮闪 ──
	var spawn_k: float = 1.0
	if has_meta(&"spawn_msec"):
		spawn_k = float(now_msec - int(get_meta(&"spawn_msec"))) / (SHIELD_SPAWN_SEC * 1000.0)
		if spawn_k >= 1.0:
			remove_meta(&"spawn_msec")
			spawn_k = 1.0
		else:
			spawn_k = clampf(spawn_k, 0.0, 1.0)
	var ease_in_k: float = 1.0 - pow(1.0 - spawn_k, 3.0)  # ease-out cubic
	var spawn_flash: float = 1.0 - spawn_k                 # 获得闪亮衰减

	# 呼吸（护盾是稳定状态，轻微）+ 受击扩张 + 获得态从 0.35 倍撑开 + 击碎态再扩 20%
	var breath: float = 1.0 + (BREATH_AMP * 0.6) * (0.5 + 0.5 * sin(t * TAU / (BREATH_PERIOD * 1.5)))
	var hit_scale: float = 1.0 + hit_boost * 0.18
	var radius: float = SHIELD_RADIUS * breath * hit_scale * lerpf(0.35, 1.0, ease_in_k)
	if break_k >= 0.0:
		radius *= 1.0 + 0.2 * break_k

	# 透明度 = 基础 × 护盾比例 + 受击/获得/击碎动态；击碎态整体线性淡出
	var base_alpha: float = (0.5 + 0.35 * shield_ratio) * ease_in_k
	if break_k >= 0.0:
		base_alpha = (0.5 + 0.35 * maxf(shield_ratio, 0.4)) * (1.0 - break_k)
	var ring_color := Color(SHIELD_COLOR.r, SHIELD_COLOR.g, SHIELD_COLOR.b, base_alpha)
	ring_color = ring_color.lerp(SHIELD_COLOR_HIT, maxf(hit_boost, spawn_flash * 0.8))

	# 穹顶弧角域：上半圆 + 两侧下垂（PI-oh → TAU+oh，y 负为上）
	var a0: float = PI - DOME_OVERHANG_RAD
	var a1: float = TAU + DOME_OVERHANG_RAD

	# 渐变填充：穹顶扇形多边形，顶点亮、底边淡（draw_polygon 逐顶点色）
	var fill_pts := PackedVector2Array()
	var fill_cols := PackedColorArray()
	var seg_n: int = 16
	fill_pts.append(Vector2.ZERO)
	fill_cols.append(Color(SHIELD_COLOR.r, SHIELD_COLOR.g, SHIELD_COLOR.b, base_alpha * 0.30))
	for i in range(seg_n + 1):
		var ang: float = lerpf(a0, a1, float(i) / float(seg_n))
		var p := Vector2(cos(ang), sin(ang)) * radius
		fill_pts.append(p)
		var k: float = (ang - PI) / PI  # 0=左底 0.5=顶 1=右底
		var top_k: float = 1.0 - absf(k - 0.5) * 2.0  # 顶部 1，两底 0
		fill_cols.append(Color(SHIELD_COLOR.r, SHIELD_COLOR.g, SHIELD_COLOR.b,
			base_alpha * (0.16 + 0.26 * top_k)))
	draw_polygon(fill_pts, fill_cols)

	# 主穹顶描边（加粗）
	draw_arc(Vector2.ZERO, radius, a0, a1, SEGMENTS + 1, ring_color, SHIELD_RING_WIDTH, true)
	# 内层细弧（层次感）
	var inner_color := Color(SHIELD_COLOR.r, SHIELD_COLOR.g, SHIELD_COLOR.b, base_alpha * 0.5)
	draw_arc(Vector2.ZERO, radius * 0.92, a0 + 0.1, a1 - 0.1, SEGMENTS + 1, inner_color, 1.5, true)
	# 底部收口横线（两垂脚之间，罩"坐"在地面的锚定感）
	var left_foot := Vector2(cos(a0), sin(a0)) * radius
	var right_foot := Vector2(cos(a1), sin(a1)) * radius
	var foot_color := Color(SHIELD_COLOR.r, SHIELD_COLOR.g, SHIELD_COLOR.b, base_alpha * 0.45)
	draw_line(left_foot.lerp(right_foot, 0.10), left_foot.lerp(right_foot, 0.90), foot_color, 1.5, true)

	# 护盾承压时（受击）追加更亮的内描边
	if hit_boost > 0.05 and break_k < 0.0:
		var stress_color := Color(SHIELD_COLOR_HIT.r, SHIELD_COLOR_HIT.g, SHIELD_COLOR_HIT.b, hit_boost * 0.7)
		draw_arc(Vector2.ZERO, radius * 0.88, a0 + 0.15, a1 - 0.15, SEGMENTS + 1, stress_color, SHIELD_RING_WIDTH * 0.7, true)


## 绘制一个闭合圆环（描边）
## v35.x perf: 引擎内置 draw_arc 替代手搓 40 点数组 + duplicate——承压期父节点每帧
## queue_redraw（construct_unit:1325），常态每 4 帧，每帧最多 3 个环；draw_arc 几何
## 等价（SEGMENTS+1 点 = SEGMENTS 段、end=TAU 闭合、antialiased 对齐），零 GDScript 分配。
func _draw_ring(radius: float, color: Color, width: float) -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, SEGMENTS + 1, color, width, true)
