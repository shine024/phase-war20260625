extends Node
## UI主题管理器：提供统一的UI样式和主题管理

## 主题颜色定义
var colors: Dictionary = {
	# 主要颜色
	"primary": Color(0.3, 0.6, 1.0, 1.0),           # 主色（蓝色）
	"secondary": Color(0.4, 0.85, 1.0, 1.0),       # 次要色（浅蓝）
	"accent": Color(1.0, 0.85, 0.4, 1.0),          # 强调色（金色）

	# 功能颜色
	"success": Color(0.4, 0.95, 0.6, 1.0),         # 成功（绿色）
	"warning": Color(0.95, 0.75, 0.35, 0.9),       # 警告（橙色）
	"error": Color(0.95, 0.3, 0.3, 1.0),           # 错误（红色）
	"info": Color(0.6, 0.8, 1.0, 1.0),             # 信息（浅蓝）

	# 槽位颜色
	"slot_green": Color(0.3, 0.9, 0.5, 1.0),       # 绿色槽位
	"slot_red": Color(0.9, 0.3, 0.3, 1.0),         # 红色槽位
	"slot_blue": Color(0.3, 0.6, 1.0, 1.0),        # 蓝色槽位
	"slot_yellow": Color(0.95, 0.85, 0.2, 1.0),    # 黄色槽位

	# 背景颜色
	"bg_dark": Color(0.08, 0.10, 0.15, 0.95),      # 深色背景
	"bg_medium": Color(0.12, 0.15, 0.22, 0.95),    # 中等背景
	"bg_light": Color(0.18, 0.22, 0.30, 0.95),     # 浅色背景

	# 文本颜色
	"text_primary": Color(0.95, 0.9, 0.85, 1.0),   # 主要文本
	"text_secondary": Color(0.75, 0.8, 0.85, 0.9), # 次要文本
	"text_disabled": Color(0.5, 0.5, 0.6, 0.8),   # 禁用文本
	"text_hint": Color(0.6, 0.7, 0.8, 0.85),      # 提示文本

	# 边框颜色
	"border_normal": Color(0.3, 0.35, 0.45, 0.6),  # 普通边框
	"border_active": Color(0.4, 0.85, 1.0, 0.9),   # 激活边框
	"border_hover": Color(0.5, 0.9, 1.0, 0.7),     # 悬停边框
}

## 字体大小定义
var font_sizes: Dictionary = {
	"title_large": 20,        # 大标题
	"title_medium": 16,       # 中标题
	"title_small": 14,        # 小标题
	"body_large": 13,         # 大正文
	"body_normal": 12,        # 普通正文
	"body_small": 11,         # 小正文
	"caption": 10,            # 说明文字
}

## 间距定义
var spacing: Dictionary = {
	"tiny": 2,      # 极小间距
	"small": 4,     # 小间距
	"medium": 8,    # 中等间距
	"large": 12,    # 大间距
	"huge": 16,     # 超大间距
}

## 圆角定义
var corner_radius: Dictionary = {
	"small": 4,     # 小圆角
	"medium": 6,    # 中等圆角
	"large": 10,    # 大圆角
}

## 应用主题到Control节点
func apply_theme(control: Control, theme_type: String = "default") -> void:
	if control == null or not is_instance_valid(control):
		return

	match theme_type:
		"panel":
			_apply_panel_theme(control)
		"button":
			_apply_button_theme(control)
		"label":
			_apply_label_theme(control)
		"input":
			_apply_input_theme(control)
		_:
			_apply_default_theme(control)

## 应用面板主题
func _apply_panel_theme(control: Control) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = colors.bg_dark
	style.border_color = colors.border_normal
	style.set_border_width_all(2)
	style.set_corner_radius_all(corner_radius.medium)

	control.add_theme_stylebox_override("panel", style)

## 应用按钮主题
func _apply_button_theme(control: Control) -> void:
	if control is Button:
		control.add_theme_font_size_override("font_size", font_sizes.body_normal)
		control.add_theme_color_override("font_color", colors.text_primary)

## 应用标签主题
func _apply_label_theme(control: Control) -> void:
	if control is Label:
		control.add_theme_font_size_override("font_size", font_sizes.body_normal)
		control.add_theme_color_override("font_color", colors.text_primary)

## 应用输入框主题
func _apply_input_theme(control: Control) -> void:
	if control is LineEdit or control is TextEdit:
		control.add_theme_font_size_override("font_size", font_sizes.body_normal)
		control.add_theme_color_override("font_color", colors.text_primary)

## 应用默认主题
func _apply_default_theme(control: Control) -> void:
	control.add_theme_font_size_override("font_size", font_sizes.body_normal)

## 创建样式框（面板背景）
func create_panel_style(bg_color: Color = Color(), border_color: Color = Color(), border_width: int = 2) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()

	style.bg_color = bg_color if bg_color != Color() else colors.bg_dark
	style.border_color = border_color if border_color != Color() else colors.border_normal
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius.medium)

	return style

## 创建按钮样式
func create_button_style(normal: bool = true, hover: bool = false, pressed: bool = false) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()

	if pressed:
		style.bg_color = colors.primary
		style.border_color = colors.border_active
	elif hover:
		style.bg_color = colors.bg_light
		style.border_color = colors.border_hover
	else:
		style.bg_color = colors.bg_medium
		style.border_color = colors.border_normal

	style.set_border_width_all(2)
	style.set_corner_radius_all(corner_radius.medium)

	return style

## 获取颜色
func get_color(color_name: String) -> Color:
	return colors.get(color_name, Color.WHITE)

## 获取字体大小
func get_font_size(size_name: String) -> int:
	return font_sizes.get(size_name, 12)

## 获取间距
func get_spacing(spacing_name: String) -> int:
	return spacing.get(spacing_name, 8)

## 获取圆角
func get_corner_radius(radius_name: String) -> int:
	return corner_radius.get(radius_name, 6)

## 设置主题颜色（运行时修改）
func set_color(color_name: String, color: Color) -> void:
	colors[color_name] = color

## 设置字体大小
func set_font_size(size_name: String, size: int) -> void:
	font_sizes[size_name] = size

## 应用主题到整个场景树
func apply_theme_to_scene(scene: Node) -> void:
	if scene == null or not is_instance_valid(scene):
		return

	for child in scene.get_children():
		if child is Control:
			apply_theme(child)

		apply_theme_to_scene(child)

## 创建带主题的Label
func create_themed_label(text: String, size_name: String = "body_normal", color_name: String = "text_primary") -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", get_font_size(size_name))
	label.add_theme_color_override("font_color", get_color(color_name))
	return label

## 创建带主题的Button
func create_themed_button(text: String, theme_type: String = "default") -> Button:
	var button = Button.new()
	button.text = text
	apply_theme(button, theme_type)
	return button

## 创建带主题的Panel
func create_themed_panel(theme_type: String = "panel") -> Panel:
	var panel = Panel.new()
	apply_theme(panel, theme_type)
	return panel

## 获取槽位颜色（根据颜色名称）
func get_slot_color(color_name: String) -> Color:
	match color_name:
		"green": return colors.slot_green
		"red": return colors.slot_red
		"blue": return colors.slot_blue
		"yellow": return colors.slot_yellow
		_: return Color.WHITE

## 获取稀有度颜色（委托给 GameConstants 权威来源）
func get_rarity_color(rarity: String) -> Color:
	return GameConstants.get_rarity_color(rarity)

## 应用高对比度模式（可访问性）
func set_high_contrast_mode(enabled: bool) -> void:
	if enabled:
		colors.text_primary = Color(1.0, 1.0, 1.0, 1.0)
		colors.bg_dark = Color(0.0, 0.0, 0.0, 1.0)
		colors.border_normal = Color(1.0, 1.0, 1.0, 0.8)
	else:
		# 恢复默认颜色
		colors.text_primary = Color(0.95, 0.9, 0.85, 1.0)
		colors.bg_dark = Color(0.08, 0.10, 0.15, 0.95)
		colors.border_normal = Color(0.3, 0.35, 0.45, 0.6)

## 从JSON配置文件加载主题
func load_theme_from_config(config_path: String) -> bool:
	if not FileAccess.file_exists(config_path):
		return false

	var file = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return false

	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK or json.data == null or not json.data is Dictionary:
		return false

	var data = json.data as Dictionary

	if data.has("colors") and data["colors"] is Dictionary:
		for key in data["colors"]:
			var c = data["colors"][key]
			if c is Dictionary:
				colors[key] = Color(c.get("r", 1.0), c.get("g", 1.0), c.get("b", 1.0), c.get("a", 1.0))
			elif c is String and c.begins_with("#"):
				colors[key] = Color(c)

	if data.has("font_sizes") and data["font_sizes"] is Dictionary:
		for key in data["font_sizes"]:
			font_sizes[key] = int(data["font_sizes"][key])

	if data.has("spacing") and data["spacing"] is Dictionary:
		for key in data["spacing"]:
			spacing[key] = int(data["spacing"][key])

	if data.has("corner_radius") and data["corner_radius"] is Dictionary:
		for key in data["corner_radius"]:
			corner_radius[key] = int(data["corner_radius"][key])

	return true

## 保存主题到JSON配置文件
func save_theme_to_config(config_path: String) -> bool:
	var data := {
		"colors": {},
		"font_sizes": font_sizes.duplicate(),
		"spacing": spacing.duplicate(),
		"corner_radius": corner_radius.duplicate()
	}

	for key in colors:
		var c: Color = colors[key]
		data["colors"][key] = {"r": c.r, "g": c.g, "b": c.b, "a": c.a}

	var json = JSON.new()
	var json_str = json.stringify(data, "\t")
	if json_str.is_empty():
		return false

	var file = FileAccess.open(config_path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(json_str)
	return true
