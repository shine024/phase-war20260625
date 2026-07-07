extends Control
## v7.x(A5) 新手引导覆盖层（轻量接线版）
## 消费 TutorialProgressionManager（A 系统 autoload）的当前步骤数据，
## 在 tscn 预建的 TitleLabel/ContentLabel/SkipButton/NextButton 上渲染。
## 推进靠"下一步"按钮（complete_current_step → 显示下一步或 queue_free）。
# 注：历史版本（B 系统 managers/tutorial_manager.gd + interactive_tutorial）已弃用，
# A 系统是唯一在跑的高亮教程入口。quest tutorial 任务（C 系统）继续负责进阶系统教学。

var _tutorial_manager: Node
var _current_content: Dictionary = {}

signal tutorial_action_executed(action_target: String)

@onready var _title_label: Label = $TutorialBox/Margin/VBox/TitleLabel
@onready var _content_label: RichTextLabel = $TutorialBox/Margin/VBox/ContentLabel
@onready var _skip_button: Button = $TutorialBox/Margin/VBox/ButtonRow/SkipButton
@onready var _next_button: Button = $TutorialBox/Margin/VBox/ButtonRow/NextButton


func _ready() -> void:
	_tutorial_manager = get_node_or_null("/root/TutorialProgressionManager")
	if _skip_button:
		_skip_button.pressed.connect(_on_skip_pressed)
	if _next_button:
		_next_button.pressed.connect(_on_next_pressed)
	if _tutorial_manager == null or not _tutorial_manager.has_method("should_show_tutorial"):
		queue_free()
		return
	if not _tutorial_manager.should_show_tutorial():
		queue_free()
		return
	_show_current_step()


func _show_current_step() -> void:
	if _tutorial_manager == null:
		return
	_current_content = _tutorial_manager.get_tutorial_content()
	if _current_content.is_empty():
		# 无更多步骤，结束教程
		queue_free()
		return
	if _title_label:
		_title_label.text = str(_current_content.get("title", "引导"))
	if _content_label:
		var text_parts: Array = []
		text_parts.append(str(_current_content.get("description", "")))
		var highlights: Array = _current_content.get("highlights", [])
		if highlights.size() > 0:
			text_parts.append("")
			for h in highlights:
				text_parts.append("• " + str(h))
		_content_label.text = "\n".join(text_parts)
	if _next_button:
		# action_text 作为下一步按钮文案
		_next_button.text = str(_current_content.get("action_text", "下一步"))


func _on_next_pressed() -> void:
	if _tutorial_manager == null:
		queue_free()
		return
	# 执行 action_target（打开对应面板/进首关）
	var action_target: String = str(_current_content.get("action_target", ""))
	if not action_target.is_empty():
		tutorial_action_executed.emit(action_target)
		if _tutorial_manager.has_method("execute_tutorial_action"):
			_tutorial_manager.execute_tutorial_action(action_target)
	# 推进到下一步
	if _tutorial_manager.has_method("complete_current_step"):
		_tutorial_manager.complete_current_step()
	# 显示下一步或退出
	if _tutorial_manager.has_method("should_show_tutorial") and _tutorial_manager.should_show_tutorial():
		_show_current_step()
	else:
		queue_free()


func _on_skip_pressed() -> void:
	if _tutorial_manager != null and _tutorial_manager.has_method("skip_tutorial"):
		_tutorial_manager.skip_tutorial()
	queue_free()
