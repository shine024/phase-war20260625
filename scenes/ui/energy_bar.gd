extends HBoxContainer
## 能量条 UI：neon 风格 + 平滑动画 + 设计令牌

const DT = preload("res://resources/design_tokens.gd")

@onready var progress: ProgressBar = $ProgressBarBg/ProgressBar
@onready var label: Label = $LabelBg/Label

var _tween: Tween
var _current: float = 0.0
var _max: float = 0.0

func _ready() -> void:
	_apply_design_tokens()
	if SignalBus:
		SignalBus.energy_changed.connect(_on_energy_changed)
	# 初始
	if EnergyManager:
		_on_energy_changed(EnergyManager.get_current(), EnergyManager.get_max())

func _apply_design_tokens(high_contrast: bool = DT.HIGH_CONTRAST_ENABLED, large_type: bool = DT.LARGE_TYPE_ENABLED) -> void:
	if label:
		label.add_theme_color_override("font_color", DT.get_accent_color("energy", high_contrast))
		label.add_theme_font_size_override("font_size", DT.get_font_size(DT.FONT_SIZE_SMALL, large_type))
	if progress:
		progress.add_theme_color_override("fg_color", DT.COLOR_ENERGY)
		progress.add_theme_color_override("bg_color", DT.get_panel_color(high_contrast))

func _on_energy_changed(current: float, maximum: float) -> void:
	_current = maxf(0.0, current)
	_max = maxf(1.0, maximum)
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if progress:
		progress.max_value = _max
		_tween.tween_property(progress, "value", _current, 0.25).set_ease(Tween.EASE_OUT)
	if label:
		_tween.tween_callback(func() -> void:
			label.text = "能量: %d / %d" % [int(_current), int(_max)]
		)

