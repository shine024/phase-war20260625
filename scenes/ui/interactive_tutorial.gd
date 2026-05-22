extends Control
## 交互式教程显示：提供逐步引导和交互式教程体验

const TutorialDefs = preload("res://data/tutorial_definitions.gd")
const UIEnhanced = preload("res://scripts/ui_theme_enhanced.gd")

var _current_tutorial: String = ""
var _current_step: int = 0
var _tutorial_data: Dictionary = {}
var _theme_enhanced: UIEnhanced = null

# UI节点引用
@onready var _tutorial_panel: PanelContainer = $TutorialPanel
@onready var _title_label: Label = $TutorialPanel/VBoxContainer/Header/TitleLabel
@onready var _content_label: Label = $TutorialPanel/VBoxContainer/Content/ContentLabel
@onready var _highlight_rect: ColorRect = $HighlightRect
@onready var _next_button: Button = $TutorialPanel/VBoxContainer/Buttons/NextButton
@onready var _skip_button: Button = $TutorialPanel/VBoxContainer/Buttons/SkipButton
@onready var _progress_indicator: HBoxContainer = $TutorialPanel/VBoxContainer/Header/ProgressIndicator
@onready var _dim_background: ColorRect = $DimBackground

signal step_completed(tutorial_id: String, step: int)
signal tutorial_skipped(tutorial_id: String)
## tutorial_completed 已迁移至 SignalBus: SignalBus.tutorial_completed(tutorial_id)

func _ready() -> void:
	_setup_theme()
	_connect_signals()
	hide()

func _setup_theme() -> void:
	_theme_enhanced = UIEnhanced.new()
	add_child(_theme_enhanced)

	# 美化面板
	_theme_enhanced.apply_panel_style(_tutorial_panel, "info")

	# 美化按钮
	_theme_enhanced.apply_button_style(_next_button)
	_theme_enhanced.apply_button_style(_skip_button)

	# 美化标签
	_title_label.add_theme_color_override("font_color", _theme_enhanced.get_theme_color("primary"))
	_title_label.add_theme_font_size_override("font_size", 18)
	_content_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1.0))
	_content_label.add_theme_font_size_override("font_size", 14)

func _connect_signals() -> void:
	if _next_button:
		_next_button.pressed.connect(_on_next_pressed)
	if _skip_button:
		_skip_button.pressed.connect(_on_skip_pressed)

## 开始教程
func start_tutorial(tutorial_id: String) -> void:
	if not TutorialDefs.TUTORIALS.has(tutorial_id):
		push_error("教程不存在: " + tutorial_id)
		return

	_current_tutorial = tutorial_id
	_current_step = 0
	_tutorial_data = TutorialDefs.TUTORIALS[tutorial_id]

	show()
	_update_step_display()

## 更新步骤显示
func _update_step_display() -> void:
	var steps = _tutorial_data.get("steps", [])
	if _current_step >= steps.size():
		_complete_tutorial()
		return

	var step_data = steps[_current_step]

	# 更新文本
	if _title_label:
		_title_label.text = _tutorial_data.get("name", "教程")
	if _content_label:
		_content_label.text = step_data.get("text", "")

	# 更新按钮文本
	var is_last_step = _current_step >= steps.size() - 1
	if _next_button:
		_next_button.text = "完成" if is_last_step else "下一步"

	# 更新进度指示器
	_update_progress_indicator()

	# 高亮指定元素
	_highlight_element(step_data.get("highlight", ""))

## 更新进度指示器
func _update_progress_indicator() -> void:
	if not _progress_indicator:
		return

	# 清除旧的进度点
	for child in _progress_indicator.get_children():
		child.queue_free()

	var steps = _tutorial_data.get("steps", [])
	for i in range(steps.size()):
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.color = _theme_enhanced.get_theme_color("primary") if i == _current_step else Color(0.3, 0.3, 0.35, 1.0)
		_progress_indicator.add_child(dot)

## 高亮指定元素
func _highlight_element(element_path: String) -> void:
	if _highlight_rect:
		_highlight_rect.hide()

	if element_path.is_empty():
		if _dim_background:
			_dim_background.hide()
		return

	# 查找要高亮的元素
	var target_node = _find_node_by_path(element_path)
	if target_node and target_node is Control:
		if _dim_background:
			_dim_background.show()

		if _highlight_rect:
			_highlight_rect.show()
			_highlight_rect.global_position = target_node.global_position
			_highlight_rect.size = target_node.size

			# 添加高亮动画
			var tween = _highlight_rect.create_tween()
			tween.set_loops()
			tween.tween_property(_highlight_rect, "modulate:a", 0.5, 0.8).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(_highlight_rect, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN_OUT)

func _find_node_by_path(path: String) -> Node:
	# 简化的节点查找，可以根据需要扩展
	var root = get_tree().root
	return root.find_child(path, true, false)

func _on_next_pressed() -> void:
	step_completed.emit(_current_tutorial, _current_step)
	_current_step += 1
	_update_step_display()

func _on_skip_pressed() -> void:
	tutorial_skipped.emit(_current_tutorial)
	_complete_tutorial()

func _complete_tutorial() -> void:
	SignalBus.tutorial_completed.emit(_current_tutorial)
	_close_tutorial()

func _close_tutorial() -> void:
	if _dim_background:
		_dim_background.hide()
	if _highlight_rect:
		_highlight_rect.hide()

	# 关闭动画
	var tween = create_tween()
	tween.tween_property(_tutorial_panel, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		hide()
		_tutorial_panel.modulate.a = 1.0
	)

## 设置教程完成回调
func set_completion_callback(callback: Callable) -> void:
	SignalBus.tutorial_completed.connect(callback)

## 检查教程是否完成
func is_tutorial_completed(tutorial_id: String) -> bool:
	var tutorial_manager = get_node_or_null("/root/TutorialProgressionManager")
	if tutorial_manager and tutorial_manager.has_method("is_tutorial_completed"):
		return tutorial_manager.is_tutorial_completed(tutorial_id)
	return false

## 显示快速提示
func show_quick_tip(text: String, position: Vector2 = Vector2(), duration: float = 3.0) -> void:
	var tip_panel = PanelContainer.new()
	_theme_enhanced.apply_panel_style(tip_panel, "info")

	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1.0))
	label.add_theme_font_size_override("font_size", 13)
	tip_panel.add_child(label)

	add_child(tip_panel)

	if position != Vector2():
		tip_panel.position = position
	else:
		tip_panel.position = Vector2(
			(size.x - tip_panel.size.x) / 2,
			(size.y - tip_panel.size.y) / 2
		)

	# 自动关闭
	var tween = create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(func():
		if is_instance_valid(tip_panel):
			var fade_tween = tip_panel.create_tween()
			fade_tween.tween_property(tip_panel, "modulate:a", 0.0, 0.3)
			fade_tween.tween_callback(func():
				if is_instance_valid(tip_panel):
					tip_panel.queue_free()
			)
	)

## 显示操作提示
func show_action_tip(action_text: String, target_position: Vector2) -> void:
	var tip = Label.new()
	tip.text = "▼ " + action_text
	tip.add_theme_color_override("font_color", _theme_enhanced.get_theme_color("warning"))
	tip.add_theme_font_size_override("font_size", 14)
	tip.z_index = 200

	add_child(tip)
	tip.position = target_position + Vector2(-20, -40)

	# 添加跳动动画
	var tween = tip.create_tween()
	tween.set_loops()
	tween.tween_property(tip, "position:y", tip.position.y - 10, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(tip, "position:y", tip.position.y, 0.5).set_ease(Tween.EASE_IN)

	# 自动移除
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(tip):
		tip.queue_free()
