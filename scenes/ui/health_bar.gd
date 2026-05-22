extends HBoxContainer
## 生命值条 UI：支持平滑动画与设计令牌

const DT = preload("res://resources/design_tokens.gd")

@onready var progress: ProgressBar = $ProgressBarBg/ProgressBar
@onready var label: Label = $LabelBg/Label

var _tween: Tween
var _current: float = 0.0
var _max: float = 100.0

func _ready() -> void:
	_apply_design_tokens()
	_update_immediate(_current, _max)

func _apply_design_tokens(high_contrast: bool = DT.HIGH_CONTRAST_ENABLED, large_type: bool = DT.LARGE_TYPE_ENABLED) -> void:
	if label:
		label.add_theme_color_override("font_color", DT.get_accent_color("health", high_contrast))
		label.add_theme_font_size_override("font_size", DT.get_font_size(DT.FONT_SIZE_SMALL, large_type))
	if progress:
		progress.add_theme_color_override("fg_color", DT.COLOR_HEALTH)
		progress.add_theme_color_override("bg_color", DT.get_panel_color(high_contrast))

func _update_immediate(current: float, maximum: float) -> void:
	_current = maxf(0.0, current)
	_max = maxf(1.0, maximum)
	if progress:
		progress.max_value = _max
		progress.value = _current
	if label:
		label.text = "HP: %d / %d" % [int(_current), int(_max)]

func set_values(current: float, maximum: float, animate: bool = true) -> void:
	current = maxf(0.0, current)
	maximum = maxf(1.0, maximum)
	if not animate or _tween == null:
		_update_immediate(current, maximum)
		return
	if _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	var from_value := _current
	var to_value := current
	_current = current
	_max = maximum
	if progress:
		progress.max_value = _max
		_tween.tween_property(progress, "value", to_value, 0.25).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void:
		if label:
			label.text = "HP: %d / %d" % [int(_current), int(_max)]
	)

