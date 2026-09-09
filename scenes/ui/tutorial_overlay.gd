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

## 批次③ Task 5：导航框按步骤锚定——面板介绍步靠左（不盖住被介绍面板主体，玩家可
## 直接操作右侧面板），欢迎/首战/移动基地居中。键 = TutorialStep 枚举值（存档兼容恒定）。
const BOX_POS_BY_STEP := {
	2: "left",   # CARD_COLLECTION 卡仓
	3: "left",   # PHASE_INSTRUMENT 装配
	4: "left",   # ENHANCEMENT 等级
	5: "left",   # MODIFICATION 改造
	6: "left",   # RUNES 符文
	8: "left",   # EVOLUTION 制造
	9: "left",   # FACTION_REP 势力
	10: "left",  # SHOP 商店
	11: "left",  # WORLD_MAP 地图
	12: "left",  # PHASE_FIELD_POINTS 加点
}

@onready var _title_label: Label = $TutorialBox/Margin/VBox/TitleLabel
@onready var _content_label: RichTextLabel = $TutorialBox/Margin/VBox/ContentLabel
@onready var _skip_button: Button = $TutorialBox/Margin/VBox/ButtonRow/SkipButton
@onready var _next_button: Button = $TutorialBox/Margin/VBox/ButtonRow/NextButton
@onready var _tutorial_box: PanelContainer = $TutorialBox


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
	_apply_box_pos()


## 批次③ Task 5：导航框锚定（left=屏幕左侧竖带；center=居中默认）
func _apply_box_pos() -> void:
	if _tutorial_box == null:
		return
	var step := 0
	if _tutorial_manager != null and "current_step" in _tutorial_manager:
		step = int(_tutorial_manager.current_step)
	if BOX_POS_BY_STEP.get(step, "center") == "left":
		_tutorial_box.anchor_left = 0.01
		_tutorial_box.anchor_top = 0.28
		_tutorial_box.anchor_right = 0.30
		_tutorial_box.anchor_bottom = 0.72
		_tutorial_box.offset_left = 0.0
		_tutorial_box.offset_top = 0.0
		_tutorial_box.offset_right = 0.0
		_tutorial_box.offset_bottom = 0.0
		_tutorial_box.grow_horizontal = Control.GROW_DIRECTION_END
		_tutorial_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	else:
		_tutorial_box.anchor_left = 0.5
		_tutorial_box.anchor_top = 0.5
		_tutorial_box.anchor_right = 0.5
		_tutorial_box.anchor_bottom = 0.5
		_tutorial_box.offset_left = -250.0
		_tutorial_box.offset_top = -150.0
		_tutorial_box.offset_right = 250.0
		_tutorial_box.offset_bottom = 150.0
		_tutorial_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_tutorial_box.grow_vertical = Control.GROW_DIRECTION_BOTH


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
	# v21.x（FTUE 审计 S2，2026-08-27）：第7步（首战）触发战斗后教程收起——
	# 战斗期间不再弹窗遮挡战场（面板类动作在战斗中本就被 _is_in_battle 拦截）；
	# 战斗结束（胜/负/撤退/僵持超时）由 main.gd _on_battle_ended_resume_tutorial 续播 8-13 步。
	if action_target == "start_first_battle":
		queue_free()
		return
	# 批次③ Task 5：下一步进入按需点播段（链暂停）——overlay 收起，等玩家首次
	# 打开对应面板时由 notify_surface_opened → overlay_requested 重新拉起
	if bool(_tutorial_manager.get("chain_paused")):
		queue_free()
		return
	# 显示下一步或退出
	if _tutorial_manager.has_method("should_show_tutorial") and _tutorial_manager.should_show_tutorial():
		_show_current_step()
	else:
		queue_free()


func _on_skip_pressed() -> void:
	if _tutorial_manager != null and _tutorial_manager.has_method("skip_tutorial"):
		_tutorial_manager.skip_tutorial()
	queue_free()
