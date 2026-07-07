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
	# v7.x(A3): 可访问性运行时切换后即时重绘（经 SignalBus 广播）。
	if SignalBus and SignalBus.has_signal("accessibility_changed"):
		SignalBus.accessibility_changed.connect(_apply_design_tokens)
	# 初始
	if EnergyManager:
		_on_energy_changed(EnergyManager.get_current(), EnergyManager.get_max())

# v7.x(A3): 参数保留以兼容既有调用，但内部一律读实时 static var（默认参数是定义时
# 求值，不随设置面板切换更新）。被 accessibility_changed 信号触发时无参调用也安全。
func _apply_design_tokens(_high_contrast: bool = false, _large_type: bool = false) -> void:
	var hc: bool = DT.is_high_contrast()
	var lt: bool = DT.is_large_type()
	if label:
		label.add_theme_color_override("font_color", DT.get_accent_color("energy", hc))
		label.add_theme_font_size_override("font_size", DT.get_font_size(DT.FONT_SIZE_SMALL, lt))
	if progress:
		progress.add_theme_color_override("fg_color", DT.COLOR_ENERGY)
		progress.add_theme_color_override("bg_color", DT.get_panel_color(hc))

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

