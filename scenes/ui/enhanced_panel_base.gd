extends PanelContainer
## 增强版面板基类：提供统一的UI美化效果

const DT = preload("res://resources/design_tokens.gd")
const UIEnhanced = preload("res://scripts/ui_theme_enhanced.gd")

var _theme_enhanced: UIEnhanced = null
var _panel_type: String = "default"  # default, success, warning, danger, info

## 面板类型枚举
enum PanelType {
	DEFAULT,
	SUCCESS,
	WARNING,
	DANGER,
	INFO
}

func _ready() -> void:
	_setup_enhanced_theme()
	_apply_default_styles()
	animate_open()

## 面板打开动画（缩放+淡入）
func animate_open() -> void:
	scale = Vector2(0.85, 0.85)
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)

## 面板关闭动画（缩放+淡出+回调）
func animate_close(callback: Callable = Callable()) -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.85, 0.85), 0.15).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(callback)

func _setup_enhanced_theme() -> void:
	_theme_enhanced = UIEnhanced.new()
	add_child(_theme_enhanced)

func _apply_default_styles() -> void:
	match _panel_type:
		"default":
			_theme_enhanced.apply_panel_style(self, "default")
		"success":
			_theme_enhanced.apply_panel_style(self, "success")
		"warning":
			_theme_enhanced.apply_panel_style(self, "warning")
		"danger":
			_theme_enhanced.apply_panel_style(self, "danger")
		"info":
			_theme_enhanced.apply_panel_style(self, "info")
		_:
			_theme_enhanced.apply_panel_style(self, "default")

func _setup_animations() -> void:
	# 入场动画
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

## 设置面板类型
func set_panel_type(type: PanelType) -> void:
	match type:
		PanelType.DEFAULT:
			_panel_type = "default"
		PanelType.SUCCESS:
			_panel_type = "success"
		PanelType.WARNING:
			_panel_type = "warning"
		PanelType.DANGER:
			_panel_type = "danger"
		PanelType.INFO:
			_panel_type = "info"

	if _theme_enhanced:
		_apply_default_styles()

## 美化面板中的所有按钮
func beautify_buttons() -> void:
	var buttons = find_children("", "Button", true, false)
	for button in buttons:
		if button is Button:
			_theme_enhanced.apply_button_style(button)

## 美化面板中的所有标签
func beautify_labels() -> void:
	var labels = find_children("", "Label", true, false)
	for label in labels:
		if label is Label:
			_theme_enhanced.create_glow_effect(label, Color(0, 0, 0, 0))

## 美化面板中的所有进度条
func beautify_progress_bars() -> void:
	var progress_bars = find_children("", "ProgressBar", true, false)
	for pb in progress_bars:
		if pb is ProgressBar:
			_theme_enhanced.beautify_progress_bar(pb)

## 美化整个面板
func beautify_all() -> void:
	beautify_buttons()
	beautify_labels()
	beautify_progress_bars()

## 添加关闭动画
func close_with_animation(callback: Callable = Callable()) -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.2).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if callback.is_valid():
			callback.call()
		queue_free()
	)

## 添加脉冲效果
func add_pulse_effect() -> Tween:
	return _theme_enhanced.create_pulse_animation(self)

## 添加发光边框效果
func add_glow_border(color: Color = Color(), intensity: float = 0.5) -> void:
	if color == Color():
		color = _theme_enhanced.get_theme_color("primary")

	if _theme_enhanced:
		var style = get_theme_stylebox("panel").duplicate()
		if style is StyleBoxFlat:
			style.shadow_color = color * Color(1, 1, 1, intensity)
			style.shadow_size = 8
			add_theme_stylebox_override("panel", style)

## 设置面板内容（自动美化）
func set_content(content: Control) -> void:
	# 清除现有内容
	for child in get_children():
		if not (child is UIEnhanced):
			child.queue_free()

	add_child(content)

	# 美化内容
	if content.has_method("beautify"):
		content.beautify()
