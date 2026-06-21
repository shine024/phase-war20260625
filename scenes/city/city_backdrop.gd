extends Control
class_name CityBackdrop
## v6.6(剧情): 无限城几何形象背景 — 剧情模式独立主界面的视觉主体
##
## 设计概念（补剧情.txt 超空间设定）：
##   - 深空蓝渐变底色：超空间的"稳定间隙"
##   - 同心圆环：时间线交汇的层次（内圈=当前，外圈=遥远时间线）
##   - 放射状光带：时间线流向（从中心向外辐射的微光线条）
##   - 中心相位仪核心：玩家所在的位置，发光的深蓝色圆核
##   - 8个地点节点图标：分布在圆环上，对应 city_locations 的8个地点
##
## 纯 _draw() 绘制，无外部资源依赖，响应式适配任意分辨率。

const DesignTokens = preload("res://resources/design_tokens.gd")

## 8个地点的图标和位置角度（与 city_locations.gd 的 button_pos 呼应）
const LOCATION_ICONS: Array[Dictionary] = [
	{"icon": "⚑", "angle": -90.0, "label": "指挥部", "color": Color(0.0, 0.94, 1.0)},    # 上
	{"icon": "⚖", "angle": -45.0, "label": "中央市场", "color": Color(0.95, 0.85, 0.2)},  # 右上
	{"icon": "⚔", "angle": 0.0, "label": "训练场", "color": Color(0.9, 0.3, 0.3)},       # 右
	{"icon": "ǂ", "angle": 45.0, "label": "边境哨所", "color": Color(0.2, 0.9, 0.4)},    # 右下
	{"icon": "▲", "angle": 90.0, "label": "以太塔", "color": Color(0.3, 0.6, 1.0)},      # 下
	{"icon": "◉", "angle": 135.0, "label": "虚空裂隙", "color": Color(0.7, 0.2, 0.9)},   # 左下
	{"icon": "◈", "angle": 180.0, "label": "情报局", "color": Color(0.55, 0.36, 0.96)},  # 左
	{"icon": "☾", "angle": -135.0, "label": "休息区", "color": Color(0.6, 0.6, 0.65)},   # 左上
]

var _pulse_phase: float = 0.0  ## 核心脉冲动画相位

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不拦截点击，让地点按钮接收
	# 启动脉冲动画
	set_process(true)

func _process(delta: float) -> void:
	_pulse_phase += delta
	if _pulse_phase > 1000.0:
		_pulse_phase = 0.0
	queue_redraw()

func _draw() -> void:
	var size: Vector2 = get_size()
	if size.x < 10 or size.y < 10:
		return
	var center: Vector2 = size * 0.5
	# 圆环最大半径（取较短边的一半的 0.85，留出边缘余量）
	var max_radius: float = minf(size.x, size.y) * 0.42

	# 1. 底色渐变（深空蓝，中心略亮）
	_draw_background_gradient(center, max_radius * 1.3)

	# 2. 放射状时间线光带（16条，从中心向外）
	_draw_timeline_rays(center, max_radius)

	# 3. 同心圆环（5层，从内到外）
	_draw_concentric_rings(center, max_radius)

	# 4. 8个地点节点（分布在第三层圆环上）
	_draw_location_nodes(center, max_radius * 0.65)

	# 5. 中心相位仪核心（发光圆 + 脉冲环）
	_draw_phase_core(center, max_radius * 0.12)

## 绘制径向渐变背景（中心深蓝微亮，边缘极暗）
func _draw_background_gradient(center: Vector2, radius: float) -> void:
	# 用多个半透明圆叠加模拟径向渐变（避免 ShaderMaterial 复杂度）
	var layers: int = 6
	for i in range(layers):
		var t: float = float(i) / float(layers - 1)
		var r: float = radius * (1.0 - t * 0.7)
		var alpha: float = 0.08 * (1.0 - t)
		var col: Color = Color(0.08, 0.14, 0.28, alpha)
		draw_circle(center, r, col)

## 绘制放射状时间线光带（细线条，暗示时间线流向）
func _draw_timeline_rays(center: Vector2, radius: float) -> void:
	var ray_count: int = 16
	var ray_color: Color = Color(0.2, 0.5, 0.8, 0.06)
	for i in range(ray_count):
		var angle: float = TAU * float(i) / float(ray_count)
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var inner: Vector2 = center + dir * radius * 0.15
		var outer: Vector2 = center + dir * radius * 1.0
		draw_line(inner, outer, ray_color, 1.0)

## 绘制同心圆环（5层，越外越淡）
func _draw_concentric_rings(center: Vector2, max_radius: float) -> void:
	var ring_count: int = 5
	for i in range(ring_count):
		var t: float = float(i + 1) / float(ring_count)
		var r: float = max_radius * t
		var alpha: float = 0.15 * (1.0 - t * 0.5)
		var col: Color = Color(0.3, 0.6, 0.9, alpha)
		# 圆环用空心（draw_arc），不填充
		var point_count: int = 64
		draw_arc(center, r, 0, TAU, point_count, col, 1.5)

## 绘制8个地点节点（圆点 + 图标文字）
func _draw_location_nodes(center: Vector2, ring_radius: float) -> void:
	var font := get_theme_default_font()
	var font_size: int = 20
	for loc in LOCATION_ICONS:
		var angle_rad: float = deg_to_rad(float(loc.angle))
		var pos: Vector2 = center + Vector2(cos(angle_rad), sin(angle_rad)) * ring_radius
		var col: Color = loc.color
		# 节点圆点（实心，带半透明光晕）
		draw_circle(pos, 16.0, Color(col.r, col.g, col.b, 0.15))  # 光晕
		draw_circle(pos, 10.0, Color(col.r, col.g, col.b, 0.5))   # 主体
		draw_arc(pos, 10.0, 0, TAU, 24, Color(col.r, col.g, col.b, 0.9), 2.0)  # 边框
		# 图标文字（居中绘制）
		var icon_text: String = loc.icon
		var text_size: Vector2 = font.get_string_size(icon_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos: Vector2 = pos - text_size * 0.5 + Vector2(0, font_size * 0.35)
		draw_string(font, text_pos, icon_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

## 绘制中心相位仪核心（发光圆 + 脉冲呼吸环）
func _draw_phase_core(center: Vector2, radius: float) -> void:
	# 脉冲呼吸：sin 波驱动外环半径和透明度
	var pulse: float = (sin(_pulse_phase * 2.0) + 1.0) * 0.5  # 0..1
	var pulse_radius: float = radius * (1.2 + pulse * 0.4)
	var pulse_alpha: float = 0.3 * (1.0 - pulse)
	# 外环脉冲
	if pulse_alpha > 0.01:
		draw_arc(center, pulse_radius, 0, TAU, 48, Color(0.0, 0.94, 1.0, pulse_alpha), 2.0)
	# 核心光晕
	draw_circle(center, radius * 1.5, Color(0.0, 0.6, 0.9, 0.08))
	draw_circle(center, radius * 1.0, Color(0.0, 0.7, 0.95, 0.15))
	# 核心实体（深蓝色）
	draw_circle(center, radius * 0.6, Color(0.05, 0.25, 0.55, 0.95))
	draw_arc(center, radius * 0.6, 0, TAU, 32, Color(0.0, 0.94, 1.0, 0.8), 2.0)
	# 核心内的星点纹理（暗示"时间核变深蓝，浮现记忆图案"）
	var star_count: int = 5
	for i in range(star_count):
		var a: float = _pulse_phase * 0.5 + TAU * float(i) / float(star_count)
		var star_pos: Vector2 = center + Vector2(cos(a), sin(a)) * radius * 0.3
		draw_circle(star_pos, 1.5, Color(0.7, 0.9, 1.0, 0.8))
