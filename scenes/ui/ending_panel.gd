extends Control
## v6.4 结局面板 — 365天循环模式的通关结算

const DesignTokens = preload("res://resources/design_tokens.gd")
const StoryNodes = preload("res://data/main_story_nodes.gd")

var _title_label: Label = null
var _text_label: RichTextLabel = null
var _restart_button: Button = null
var _is_good_ending: bool = true

func _ready() -> void:
	_build_ui()
	visible = false

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.01, 0.01, 0.03, 0.95)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 400)
	center.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = DesignTokens.COLOR_PANEL
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = DesignTokens.CORNER_RADIUS
	style.corner_radius_top_right = DesignTokens.CORNER_RADIUS
	style.corner_radius_bottom_left = DesignTokens.CORNER_RADIUS
	style.corner_radius_bottom_right = DesignTokens.CORNER_RADIUS
	style.content_margin_left = DesignTokens.PADDING_LARGE
	style.content_margin_right = DesignTokens.PADDING_LARGE
	style.content_margin_top = DesignTokens.PADDING_LARGE
	style.content_margin_bottom = DesignTokens.PADDING_LARGE
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", DesignTokens.PADDING_MEDIUM)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = ""
	_title_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_TITLE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_text_label = RichTextLabel.new()
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.bbcode_enabled = true
	_text_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
	_text_label.fit_content = true
	vbox.add_child(_text_label)

	_restart_button = Button.new()
	_restart_button.text = "开始二周目（继承符文）"
	_restart_button.custom_minimum_size = Vector2(250, DesignTokens.BUTTON_HEIGHT + 8)
	_restart_button.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_LARGE)
	_restart_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_restart_button.pressed.connect(_on_restart_pressed)
	vbox.add_child(_restart_button)

## 显示结局
func show_ending(is_good: bool) -> void:
	_is_good_ending = is_good
	var ending: Dictionary = StoryNodes.get_ending_node(is_good)
	if is_good:
		_title_label.text = "✦ " + ending.get("title", "好结局")
		_title_label.add_theme_color_override("font_color", DesignTokens.COLOR_HEALTH)
		# 边框金色
		_restart_button.text = "开始二周目（继承符文）"
	else:
		_title_label.text = "✕ " + ending.get("title", "坏结局")
		_title_label.add_theme_color_override("font_color", DesignTokens.COLOR_DANGER)
		_restart_button.text = "时间线重置（继承符文）"
	# 结局文字
	var lines: PackedStringArray = []
	for dlg in ending.get("dialogues", []):
		var speaker: String = dlg.get("speaker", "")
		var text: String = dlg.get("text", "")
		lines.append("[b]%s[/b]：%s" % [speaker, text])
	lines.append("")
	lines.append("[color=aqua]你的全部符文将继承到下一个轮回。[/color]")
	_text_label.text = "\n".join(lines)
	visible = true

func _on_restart_pressed() -> void:
	visible = false
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("start_ng_plus"):
		sm.start_ng_plus()
	# 重新加载主场景
	get_tree().reload_current_scene()
