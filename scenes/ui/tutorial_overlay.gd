extends Control
## 教程覆盖层：显示教程内容和引导

var tutorial_manager: Node
var current_content: Dictionary = {}
var highlight_elements: Array = []

signal tutorial_action_executed(action_target: String)

func _ready() -> void:
	tutorial_manager = get_node_or_null("/root/TutorialProgressionManager")
	if tutorial_manager and tutorial_manager.should_show_tutorial():
		_show_tutorial()
	else:
		queue_free()

func _show_tutorial() -> void:
	current_content = tutorial_manager.get_tutorial_content()
	highlight_elements = tutorial_manager.get_highlight_elements()

	# 创建半透明背景
	_create_background()

	# 创建教程内容面板
	_create_content_panel()

	# 高亮目标元素
	_highlight_elements()

func _create_background() -> void:
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.85)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

func _create_content_panel() -> void:
	var panel = PanelContainer.new()
	panel.size = Vector2(500, 400)
	panel.position = (get_viewport_rect().size - panel.size) / 2

	# 创建面板样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.22, 0.98)
	style.border_color = Color(0.4, 0.85, 1.0, 0.9)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)

	add_child(panel)

	# 创建内容容器
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	margin.add_child(vbox)

	# 标题
	var title_label = Label.new()
	title_label.text = current_content.get("title", "")
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6, 1.0))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	# 分隔线
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 8)
	separator.add_theme_color_override("color", Color(0.6, 0.85, 1.0, 0.4))
	vbox.add_child(separator)

	# 描述
	var desc_label = Label.new()
	desc_label.text = current_content.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 1.0))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	# 高亮要点
	if current_content.has("highlights"):
		var highlights_vbox = VBoxContainer.new()
		highlights_vbox.add_theme_constant_override("separation", 8)

		var highlights_title = Label.new()
		highlights_title.text = "要点："
		highlights_title.add_theme_font_size_override("font_size", 13)
		highlights_title.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 1.0))
		highlights_vbox.add_child(highlights_title)

		for highlight in current_content["highlights"]:
			var highlight_label = Label.new()
			highlight_label.text = "• " + highlight
			highlight_label.add_theme_font_size_override("font_size", 12)
			highlight_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6, 1.0))
			highlights_vbox.add_child(highlight_label)

		vbox.add_child(highlights_vbox)

	# 操作按钮
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 12)
	vbox.add_child(button_container)

	# 跳过按钮
	var skip_button = Button.new()
	skip_button.text = "跳过教程"
	skip_button.custom_minimum_size = Vector2(120, 40)
	skip_button.pressed.connect(_on_skip_pressed)
	button_container.add_child(skip_button)

	# 继续/操作按钮
	var action_button = Button.new()
	action_button.text = current_content.get("action_text", "继续")
	action_button.custom_minimum_size = Vector2(200, 40)
	action_button.pressed.connect(_on_action_pressed)
	button_container.add_child(action_button)

	# 居中按钮容器
	button_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _highlight_elements() -> void:
	for element_name in highlight_elements:
		var target_node = _find_node_by_name(element_name)
		if target_node:
			_create_highlight(target_node)

func _find_node_by_name(name: String) -> Node:
	# 在场景树中查找节点
	var tree = get_tree()
	if tree:
		var root = tree.root
		return _find_node_recursive(root, name)
	return null

func _find_node_recursive(node: Node, name: String) -> Node:
	if node.name == name:
		return node

	for child in node.get_children():
		var result = _find_node_recursive(child, name)
		if result:
			return result

	return null

func _create_highlight(target: Control) -> void:
	if not (target is Control):
		return

	# 获取目标的全局位置
	var global_rect = target.get_global_rect()

	# 创建高亮边框
	var highlight = ColorRect.new()
	highlight.color = Color.TRANSPARENT
	highlight.position = global_rect.position
	highlight.size = global_rect.size
	highlight.z_index = 100

	# 创建边框样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color(1.0, 0.85, 0.4, 1.0)
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	# 添加脉冲动画
	var tween = create_tween()
	tween.set_loops()
	tween.set_parallel(true)
	tween.tween_method(_update_highlight_alpha.bind(style), 0.3, 1.0, 1.0)
	tween.tween_method(_update_highlight_alpha.bind(style), 1.0, 0.3, 1.0)

	highlight.add_theme_stylebox_override("panel", style)
	get_tree().root.add_child(highlight)

func _update_highlight_alpha(style: StyleBoxFlat, alpha: float) -> void:
	style.border_color = Color(1.0, 0.85, 0.4, alpha)

func _on_action_pressed() -> void:
	var action_target = current_content.get("action_target", "")
	if not action_target.is_empty():
		tutorial_action_executed.emit(action_target)
		tutorial_manager.execute_tutorial_action(action_target)

	tutorial_manager.complete_current_step()
	queue_free()

func _on_skip_pressed() -> void:
	# 确认对话框
	var confirm_dialog = AcceptDialog.new()
	confirm_dialog.title = "确认跳过"
	confirm_dialog.size = Vector2i(300, 150)

	var label = Label.new()
	label.text = "确定要跳过新手教程吗？\n你随时可以在设置中重新开始教程。"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	confirm_dialog.add_child(label)

	confirm_dialog.confirmed.connect(func():
		tutorial_manager.skip_tutorial()
		queue_free()
		confirm_dialog.queue_free()
	)

	confirm_dialog.canceled.connect(func():
		confirm_dialog.queue_free()
	)

	get_tree().root.add_child(confirm_dialog)
	confirm_dialog.popup_centered()
