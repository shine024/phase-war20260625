extends Node2D
## 主动法则施放位置的短暂视觉反馈

var _timer: float = 0.0

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 1.0:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var alpha: float = 1.0 - (_timer / 1.0)
	draw_arc(Vector2.ZERO, 35.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.3, alpha * 0.8))
	draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 20, Color(1.0, 0.95, 0.5, alpha * 0.5))
