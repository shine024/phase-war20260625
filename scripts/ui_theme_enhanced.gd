extends Node
## 增强UI主题管理器：提供统一的UI样式和美化效果

const DT = preload("res://resources/design_tokens.gd")

## 颜色主题
var _color_themes: Dictionary = {
	"default": {
		"primary": Color(0, 0.941, 1, 1),
		"secondary": Color(0.2, 0.6, 0.8, 1),
		"success": Color(0.2, 0.9, 0.4, 1),
		"warning": Color(0.9, 0.7, 0.2, 1),
		"danger": Color(0.9, 0.2, 0.2, 1),
		"info": Color(0.2, 0.7, 0.9, 1),
		"light": Color(0.95, 0.95, 0.97, 1),
		"dark": Color(0.1, 0.12, 0.15, 1)
	},
	"neon": {
		"primary": Color(0.2, 1.0, 0.8, 1),
		"secondary": Color(0.6, 0.2, 1.0, 1),
		"success": Color(0.4, 1.0, 0.3, 1),
		"warning": Color(1.0, 0.8, 0.2, 1),
		"danger": Color(1.0, 0.3, 0.4, 1),
		"info": Color(0.3, 0.8, 1.0, 1),
		"light": Color(0.98, 0.98, 1.0, 1),
		"dark": Color(0.05, 0.08, 0.12, 1)
	},
	"warm": {
		"primary": Color(1.0, 0.6, 0.2, 1),
		"secondary": Color(1.0, 0.3, 0.2, 1),
		"success": Color(0.8, 0.9, 0.3, 1),
		"warning": Color(1.0, 0.8, 0.2, 1),
		"danger": Color(1.0, 0.2, 0.2, 1),
		"info": Color(0.9, 0.6, 0.3, 1),
		"light": Color(1.0, 0.95, 0.9, 1),
		"dark": Color(0.15, 0.1, 0.08, 1)
	}
}

var _current_theme: String = "neon"

## 获取当前主题颜色
func get_theme_color(color_name: String) -> Color:
	var theme = _color_themes.get(_current_theme, _color_themes["default"])
	return theme.get(color_name, Color.WHITE)

## 设置主题
func set_theme(theme_name: String) -> void:
	if _color_themes.has(theme_name):
		_current_theme = theme_name

## 创建面板样式
func create_panel_style(background_color: Color = Color(), border_color: Color = Color(), corner_radius: float = 8.0) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()

	# 背景颜色
	if background_color == Color():
		background_color = DT.get_panel_color(true)
	style.bg_color = background_color

	# 边框
	if border_color == Color():
		border_color = get_theme_color("primary")
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2

	# 圆角
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius

	# 阴影效果
	style.shadow_color = border_color * Color(1, 1, 1, 0.3)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 2)

	return style

## 创建按钮样式
func create_button_style(state: String = "normal") -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	var colors = _get_button_colors(state)

	style.bg_color = colors.bg
	style.border_color = colors.border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2

	var corner_radius = 6.0
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius

	match state:
		"hover":
			style.shadow_color = colors.border * Color(1, 1, 1, 0.5)
			style.shadow_size = 8
		"pressed":
			style.shadow_color = colors.border * Color(1, 1, 1, 0.3)
			style.shadow_size = 2

	return style

func _get_button_colors(state: String) -> Dictionary:
	var theme_colors = _color_themes.get(_current_theme, _color_themes["default"])
	match state:
		"normal":
			return {
				"bg": Color(0.039, 0.055, 0.09, 0.9),
				"border": theme_colors.primary * Color(1, 1, 1, 0.6)
			}
		"hover":
			return {
				"bg": theme_colors.primary * Color(1, 1, 1, 0.15),
				"border": theme_colors.primary
			}
		"pressed":
			return {
				"bg": theme_colors.primary * Color(1, 1, 1, 0.25),
				"border": theme_colors.primary
			}
		"disabled":
			return {
				"bg": Color(0.1, 0.1, 0.15, 0.5),
				"border": Color(0.3, 0.3, 0.4, 0.3)
			}
		_:
			return _get_button_colors("normal")

## 创建进度条样式
func create_progress_bar_style(fg_color: Color = Color(), bg_color: Color = Color()) -> Dictionary:
	var theme_colors = _color_themes.get(_current_theme, _color_themes["default"])

	if fg_color == Color():
		fg_color = theme_colors.primary
	if bg_color == Color():
		bg_color = DT.get_panel_color(true)

	var fg_style = StyleBoxFlat.new()
	fg_style.bg_color = fg_color
	fg_style.corner_radius_top_left = 4
	fg_style.corner_radius_top_right = 4
	fg_style.corner_radius_bottom_right = 4
	fg_style.corner_radius_bottom_left = 4

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = bg_color
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_right = 4
	bg_style.corner_radius_bottom_left = 4

	return {
		"fg": fg_style,
		"bg": bg_style
	}

## 应用样式到控件
func apply_panel_style(control: Control, style_type: String = "default") -> void:
	match style_type:
		"default":
			control.add_theme_stylebox_override("panel", create_panel_style())
		"success":
			control.add_theme_stylebox_override("panel", create_panel_style(get_theme_color("success"), get_theme_color("success")))
		"warning":
			control.add_theme_stylebox_override("panel", create_panel_style(get_theme_color("warning"), get_theme_color("warning")))
		"danger":
			control.add_theme_stylebox_override("panel", create_panel_style(get_theme_color("danger"), get_theme_color("danger")))

func apply_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", create_button_style("normal"))
	button.add_theme_stylebox_override("hover", create_button_style("hover"))
	button.add_theme_stylebox_override("pressed", create_button_style("pressed"))
	button.add_theme_stylebox_override("disabled", create_button_style("disabled"))

## 创建动画效果
func create_pulse_animation(control: Control, duration: float = 1.0) -> Tween:
	var tween = control.create_tween()
	tween.set_loops()
	tween.tween_property(control, "modulate:a", 0.7, duration * 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "modulate:a", 1.0, duration * 0.5).set_ease(Tween.EASE_IN_OUT)
	return tween

func create_slide_in_animation(control: Control, direction: Vector2 = Vector2.UP, duration: float = 0.3) -> Tween:
	var start_pos = control.position
	var end_pos = control.position + direction * 50

	control.position = end_pos
	control.modulate.a = 0.0

	var tween = control.create_tween()
	tween.parallel().tween_property(control, "position", start_pos, duration).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(control, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT)
	return tween

func create_scale_animation(control: Control, scale: float = 1.1, duration: float = 0.2) -> Tween:
	var original_scale = control.scale
	var tween = control.create_tween()
	tween.tween_property(control, "scale", original_scale * scale, duration * 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", original_scale, duration * 0.5).set_ease(Tween.EASE_IN)
	return tween

## 创建发光效果
func create_glow_effect(control: Control, color: Color = Color(), intensity: float = 0.5) -> void:
	if color == Color():
		color = get_theme_color("primary")

	if control is Label:
		control.add_theme_color_override("font_shadow_color", color * Color(1, 1, 1, intensity))
		control.add_theme_constant_override("shadow_offset_x", 2)
		control.add_theme_constant_override("shadow_offset_y", 2)

## 应用按钮交互效果（悬停、按下、释放的缩放反馈）
static func apply_button_effects(button: BaseButton) -> void:
	if not button or not button.is_inside_tree():
		return

	# 连接信号
	if not button.mouse_entered.is_connected(_on_button_hover_enter):
		button.mouse_entered.connect(_on_button_hover_enter.bind(button))
	if not button.mouse_exited.is_connected(_on_button_hover_exit):
		button.mouse_exited.connect(_on_button_hover_exit.bind(button))
	if not button.button_down.is_connected(_on_button_down):
		button.button_down.connect(_on_button_down.bind(button))
	if not button.button_up.is_connected(_on_button_up):
		button.button_up.connect(_on_button_up.bind(button))

## 按钮悬停进入
static func _on_button_hover_enter(button: BaseButton) -> void:
	var tween = button.create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)

## 按钮悬停退出
static func _on_button_hover_exit(button: BaseButton) -> void:
	var tween = button.create_tween()
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)

## 按钮按下
static func _on_button_down(button: BaseButton) -> void:
	var tween = button.create_tween()
	tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05).set_ease(Tween.EASE_OUT)

## 按钮释放
static func _on_button_up(button: BaseButton) -> void:
	var tween = button.create_tween()
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
