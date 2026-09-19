extends Control
## 蓝图网格背景（v6.14.8 改造视图美化，C 版兵工厂方向的签名装饰）。
## 纯装饰：细钢蓝网格 + 主网格线 + 四角十字工程标，垫在面板底纹之上、内容之下。
## 用法：作为 PanelContainer 的首个子节点（叠底纹上方、内容下方）；不接收鼠标。
## 消费方：modification_panel.tscn（BgPanel 首子节点）。

const GRID_STEP := 24
const MAJOR_EVERY := 4
const LINE_COLOR := Color(0.365, 0.545, 0.816, 0.07)  # #5d8bd0 钢蓝 · 细网格
const MAJOR_COLOR := Color(0.365, 0.545, 0.816, 0.13) # 主网格线（每 4 格）
const CROSS_COLOR := Color(0.365, 0.545, 0.816, 0.35) # 角部十字标

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	var x := 0
	while x <= int(w):
		var col := MAJOR_COLOR if (x / GRID_STEP) % MAJOR_EVERY == 0 else LINE_COLOR
		draw_line(Vector2(x, 0), Vector2(x, h), col, 1.0)
		x += GRID_STEP
	var y := 0
	while y <= int(h):
		var col2 := MAJOR_COLOR if (y / GRID_STEP) % MAJOR_EVERY == 0 else LINE_COLOR
		draw_line(Vector2(0, y), Vector2(w, y), col2, 1.0)
		y += GRID_STEP
	# 四角十字工程标
	for corner in [Vector2(0, 0), Vector2(w, 0), Vector2(0, h), Vector2(w, h)]:
		draw_line(corner + Vector2(-8, 0), corner + Vector2(8, 0), CROSS_COLOR, 1.0)
		draw_line(corner + Vector2(0, -8), corner + Vector2(0, 8), CROSS_COLOR, 1.0)
