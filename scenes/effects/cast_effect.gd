extends Node2D
## 主动法则施放位置的短暂视觉反馈

var _timer: float = 0.0
## v7.x 性能优化：_draw 节流累加器（仿 law_target_indicator.gd:17 的 0.05s 节流模式）。
## 原 _process 每帧 queue_redraw，寿命 1 秒期间持续重绘，与战斗热点叠加时放大尖峰。
## 视觉上是渐隐圆环，20Hz 重绘（0.05s）肉眼无感知差异。
var _redraw_acc: float = 0.0
const REDRAW_INTERVAL: float = 0.05

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 1.0:
		queue_free()
		return
	_redraw_acc += delta
	if _redraw_acc >= REDRAW_INTERVAL:
		_redraw_acc = 0.0
		queue_redraw()

func _draw() -> void:
	var alpha: float = 1.0 - (_timer / 1.0)
	draw_arc(Vector2.ZERO, 35.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.3, alpha * 0.8))
	draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 20, Color(1.0, 0.95, 0.5, alpha * 0.5))
