extends Control
## v7.x(A5) 新手引导覆盖层（轻量接线版）
## 消费 TutorialProgressionManager（A 系统 autoload）的当前步骤数据，
## 在 tscn 预建的 TitleLabel/ContentLabel/SkipButton/NextButton 上渲染。
## 推进靠"下一步"按钮（complete_current_step → 显示下一步或 queue_free）。
## v6.20 教程指向可视化：步骤带 "spotlight_key" 时，聚光圈住真实入口按钮
##（scripts/ui/tutorial_spotlight.gd：暗幕挖孔+金色脉冲环+悬浮提示），玩家点
## 真按钮（spotlight_press_advances）等效点本步动作键——"哪里不会点哪里"。
# 注：历史版本（B 系统 managers/tutorial_manager.gd + interactive_tutorial）已弃用，
# A 系统是唯一在跑的高亮教程入口。quest tutorial 任务（C 系统）继续负责进阶系统教学。

const TutorialSpotlight = preload("res://scripts/ui/tutorial_spotlight.gd")

var _tutorial_manager: Node
var _current_content: Dictionary = {}
var _spotlight: Control = null
var _spot_target_btn: BaseButton = null

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

## v36 实机验收：欢迎步剧情化后文案变长——居中框半高 150→210（500×420），
## 其余居中步维持原 300 高（键 = TutorialStep 枚举值）。
const BOX_HALF_H_BY_STEP := {
	1: 210,      # INTRO_WELCOME 欢迎登车
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
	_update_spotlight()


## ── v6.20 教程聚光指向 ──────────────────────────────────────────
## 步骤带 "spotlight_key" 且能解析到真实按钮时：暗幕挖孔圈住按钮 + 金色脉冲环 +
## 悬浮提示（点读机）。点播段（chain_paused=面板已开盖住入口）不聚光；
## 聚光按钮本身可点击——带 "spotlight_press_advances" 的步骤点真按钮直接推进。
func _update_spotlight() -> void:
	_dismiss_spotlight()
	var key := str(_current_content.get("spotlight_key", ""))
	if key.is_empty():
		return
	if bool(_tutorial_manager.get("chain_paused")):
		return   # 点播段：面板开着盖住入口，聚光指向被盖住的按钮只会误导
	var target := _resolve_spotlight_target(key)
	if target == null or not target.is_visible_in_tree():
		return   # 找不到入口（如门控未解锁/场景不对）：纯文字兜底，不聚光
	if bool(target.get_meta("gate_locked", false)):
		return   # 锁定工位点了只会弹解锁 toast，聚光指它=误导（backpack 等常开工位不受影响）
	_spotlight = TutorialSpotlight.attach(self, target, str(_current_content.get("spotlight_tip", "")))
	if bool(_current_content.get("spotlight_press_advances", false)) and target is BaseButton:
		_spot_target_btn = target as BaseButton
		_spot_target_btn.pressed.connect(_on_spot_target_pressed)


func _dismiss_spotlight() -> void:
	if _spot_target_btn != null and is_instance_valid(_spot_target_btn):
		if _spot_target_btn.pressed.is_connected(_on_spot_target_pressed):
			_spot_target_btn.pressed.disconnect(_on_spot_target_pressed)
	_spot_target_btn = null
	if _spotlight != null and is_instance_valid(_spotlight):
		_spotlight.queue_free()
	_spotlight = null


## 解析聚光目标：基地链=truck_base 热区（get_hotspot_button_for_key）；
## 主场景链=底栏抽屉（get_button_for_key，growth 工位在底栏键名=progression）。
func _resolve_spotlight_target(key: String) -> Control:
	var host := get_parent()
	while host != null:
		if host.has_method("get_hotspot_button_for_key"):
			var hb: Button = host.get_hotspot_button_for_key(key)
			if hb != null:
				return hb
		host = host.get_parent()
	var bar_key := "progression" if key == "growth" else key
	for n in get_tree().root.find_children("BottomFunctionBar", "Control", true, false):
		if n.has_method("get_button_for_key"):
			var bb: BaseButton = n.get_button_for_key(bar_key)
			if bb != null:
				return bb
	return null


## 点真实入口按钮 = 等效点本步动作键（面板由真按钮自己的链路打开，跳过动作信号防重复 toggle）
func _on_spot_target_pressed() -> void:
	_advance(true)


func _exit_tree() -> void:
	_dismiss_spotlight()


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
		var half_h: float = float(BOX_HALF_H_BY_STEP.get(step, 150))
		_tutorial_box.anchor_left = 0.5
		_tutorial_box.anchor_top = 0.5
		_tutorial_box.anchor_right = 0.5
		_tutorial_box.anchor_bottom = 0.5
		_tutorial_box.offset_left = -250.0
		_tutorial_box.offset_top = -half_h
		_tutorial_box.offset_right = 250.0
		_tutorial_box.offset_bottom = half_h
		_tutorial_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_tutorial_box.grow_vertical = Control.GROW_DIRECTION_BOTH


func _on_next_pressed() -> void:
	_advance(false)


## v6.23b: 背包是否已打开（Main/PopupLayer/BackpackOverlay 可见性）
func _is_backpack_open() -> bool:
	var main := get_node_or_null("/root/Main")
	if main == null:
		return false
	var bp := main.get_node_or_null("PopupLayer/BackpackOverlay")
	return bp != null and bp.visible


## 推进本步。skip_action=true 时不再发动作信号（真实入口按钮已被玩家点开，
## 重复 toggle 会把刚打开的面板又关上——v6.20 聚光按钮推进路径）。
func _advance(skip_action: bool) -> void:
	if _tutorial_manager == null:
		queue_free()
		return
	# 执行 action_target（打开对应面板/进首关）
	var action_target: String = str(_current_content.get("action_target", ""))
	# v6.23b: 面板体验步防反向关闭——动作是"打开背包"但背包已开着时，toggle 会把它
	# 关掉：关闭通知先于 pending 挂起发出 → 挂起永远等不到（教程死链）。此时视为
	# 面板已就位，跳过 toggle，直接进入"关背包继续"节奏。
	if not skip_action and action_target == "open_backpack" and _is_backpack_open():
		skip_action = true
	if not skip_action and not action_target.is_empty():
		tutorial_action_executed.emit(action_target)
		if _tutorial_manager.has_method("execute_tutorial_action"):
			_tutorial_manager.execute_tutorial_action(action_target)
	# 推进到下一步
	if _tutorial_manager.has_method("complete_current_step"):
		_tutorial_manager.complete_current_step()
	# v38.3 教程节奏：面板体验步（开卡仓/装配）——面板保持打开让玩家自由浏览，
	# 关闭面板（main._close_overlay 通知）后才弹下一步；此处收起本步导航框。
	if _tutorial_manager.has_method("begin_close_wait_for_action") \
			and _tutorial_manager.begin_close_wait_for_action(action_target):
		queue_free()
		return
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
