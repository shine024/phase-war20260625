extends Node2D
## 部署进度条：显示虚影实体化的倒计时进度

const BAR_WIDTH: float = 40.0
const BAR_HEIGHT: float = 6.0
## v27.12: 填充渐变端点提常量（原每次 _update_view 都 new 两个 Color 字面量）
const _FILL_START := Color(0.3, 0.6, 1.0, 0.9)
const _FILL_END := Color(0.3, 1.0, 0.5, 0.9)

var _progress: float = 0.0  # 0.0 到 1.0
var _bg: Polygon2D
var _fill: Polygon2D
var _icon: Label

func _ready() -> void:
	position = Vector2(0, -50)  # 在血条上方显示
	_bg = get_node_or_null("Bg") as Polygon2D
	_fill = get_node_or_null("Fill") as Polygon2D
	_icon = get_node_or_null("Icon") as Label
	# v27.12 perf: bg 几何恒定不变，只在 _ready 建一次（原 set_progress 每次部署 tick
	# 都重设同一 bg polygon）
	if _bg:
		var half_w: float = BAR_WIDTH * 0.5
		var half_h: float = BAR_HEIGHT * 0.5
		_bg.polygon = PackedVector2Array([
			Vector2(-half_w, -half_h),
			Vector2(half_w, -half_h),
			Vector2(half_w, half_h),
			Vector2(-half_w, half_h)
		])
	_update_view()

## 设置进度（0.0 = 刚开始，1.0 = 完成）
func set_progress(progress: float) -> void:
	_progress = clampf(progress, 0.0, 1.0)
	_update_view()

func _update_view() -> void:
	var half_w: float = BAR_WIDTH * 0.5
	var half_h: float = BAR_HEIGHT * 0.5

	# v27.12: bg 恒定几何已移到 _ready 一次性构建，此处只更新填充

	# 更新填充（根据进度从右向左减少）
	if _fill:
		var fill_w: float = BAR_WIDTH * (1.0 - _progress)
		if fill_w < 2.0:
			fill_w = 0.0
		else:
			fill_w -= 2.0  # 留一点边距

		_fill.polygon = PackedVector2Array([
			Vector2(-half_w + 1, -half_h + 1),
			Vector2(-half_w + 1 + fill_w, -half_h + 1),
			Vector2(-half_w + 1 + fill_w, half_h - 1),
			Vector2(-half_w + 1, half_h - 1)
		])

		# 根据进度改变颜色
		_fill.color = _FILL_START.lerp(_FILL_END, _progress)
