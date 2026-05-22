extends Node2D
## 部署进度条：显示虚影实体化的倒计时进度

const BAR_WIDTH: float = 40.0
const BAR_HEIGHT: float = 6.0

var _progress: float = 0.0  # 0.0 到 1.0
var _bg: Polygon2D
var _fill: Polygon2D
var _icon: Label

func _ready() -> void:
	position = Vector2(0, -50)  # 在血条上方显示
	_bg = get_node_or_null("Bg") as Polygon2D
	_fill = get_node_or_null("Fill") as Polygon2D
	_icon = get_node_or_null("Icon") as Label
	_update_view()

## 设置进度（0.0 = 刚开始，1.0 = 完成）
func set_progress(progress: float) -> void:
	_progress = clampf(progress, 0.0, 1.0)
	_update_view()

func _update_view() -> void:
	var half_w: float = BAR_WIDTH * 0.5
	var half_h: float = BAR_HEIGHT * 0.5

	# 更新背景
	if _bg:
		_bg.polygon = PackedVector2Array([
			Vector2(-half_w, -half_h),
			Vector2(half_w, -half_h),
			Vector2(half_w, half_h),
			Vector2(-half_w, half_h)
		])

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
		var color_ratio = _progress
		var start_color := Color(0.3, 0.6, 1.0, 0.9)
		var end_color := Color(0.3, 1.0, 0.5, 0.9)
		_fill.color = start_color.lerp(end_color, color_ratio)
