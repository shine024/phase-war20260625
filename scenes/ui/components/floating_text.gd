extends Label
## 通用战斗弹出文本：伤害数字等

const DT = preload("res://resources/design_tokens.gd")

var lifetime: float = 1.0
var rise_distance: float = 50.0

func _ready() -> void:
	add_theme_font_size_override("font_size", DT.get_font_size(DT.FONT_SIZE_MEDIUM))

func show_text(value: String, color: Color, start_position: Vector2) -> void:
	text = value
	modulate = color
	position = start_position
	var tween := create_tween()
	tween.tween_property(self, "position:y", start_position.y - rise_distance, lifetime).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, lifetime).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)

