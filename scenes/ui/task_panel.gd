extends Control
## 任务面板：显示和管理游戏中的任务

signal task_selected(task_id: String)
signal task_accepted(task_id: String)
signal task_abandoned(task_id: String)
reward_claimed(task_id: String)
signal panel_closed()

## UI组件引用
@onready var tab_container: TabContainer = $VBox/TabContainer
@onready var available_tab: Control = $VBox/TabContainer/AvailableTab
@onready var daily_tab: Control = $VBox/TabContainer/DailyTab
@onready var weekly_tab: Control = $VBox/TabContainer/WeeklyTab
@onready var completed_tab: Control = $VBox/TabContainer/CompletedTab

@onready var task_list: ScrollContainer = $VBox/TaskPanel/TaskList
@onready var task_details: Control = $VBox/TaskPanel/TaskDetails
@onready var task_name_label: Label = $VBox/TaskPanel/TaskDetails/NameLabel
@onready var task_description_label: Label = $VBox/TaskPanel/TaskDetails/DescriptionLabel
@onready var task_progress_bar: ProgressBar = $VBox/TaskPanel/TaskDetails/ProgressBar
@onready var task_objectives_list: VBoxContainer = $VBox/TaskPanel/TaskDetails/ObjectivesList
@onready var rewards_list: VBoxContainer = $VBox/TaskPanel/TaskDetails/RewardsList
@onready var accept_button: Button = $VBox/TaskPanel/TaskDetails/AcceptButton
@onready var abandon_button: Button = $VBox/TaskPanel/TaskDetails/AbandonButton
@onready var claim_button: Button = $VBox/TaskPanel/TaskDetails/ClaimButton
@onready var close_button: Button = $VBox/CloseButton

## 当前显示的任务类型
var current_task_type: int = -1  # -1 = all, other = TaskType

## 当前选择的任务
var current_task_id: String = ""

## 任务管理器引用
var task_manager: Node

func _ready() -> void:
	task_manager = get_node_or_null("/root/TaskManager")
	if task_manager == null:
		push_error("[TaskPanel] TaskManager not found")

	_setup_connections()
	_refresh_all_data()

## 设置信号连接
func _setup_connections() -> void:
	if accept_button != null:
		accept_button.pressed.connect(_on_accept_pressed)

	if abandon_button != null:
		abandon_button.pressed.connect(_on_abandon_pressed)

	if claim_button != null:
		claim_button.pressed.connect(_on_claim_pressed)

	if close_button != null:
		close_button.pressed.connect(_on_close_pressed)

	if task_manager != null:
		if task_manager.has_signal("task_progress_updated"):
			task_manager.task_progress_updated.connect(_on_progress_updated)
		if task_manager.has_signal("task_completed"):
			task_manager.task_completed.connect(_on_task_completed)
		if task_manager.has_signal("daily_tasks_refreshed"):
			task_manager.daily_tasks_refreshed.connect(_on_tasks_refreshed)
		if task_manager.has_signal("weekly_tasks_refreshed"):
			task_manager.weekly_tasks_refreshed.connect(_on_tasks_refreshed)

## 刷新所有数据
func _refresh_all_data() -> void:
	_refresh_task_list()
	_refresh_details()
	_refresh_statistics()

## 刷新任务列表
func _refresh_task_list() -> void:
	if task_list == null or task_manager == null:
		return

	// 清空现有内容
	var list_container = task_list.get_node_or_null("ListContainer")
	if list_container != null:
		for child in list_container.get_children():
			child.queue_free()

	// 获取要显示的任务
	var tasks_to_show = []
	if current_task_type == -1:
		tasks_to_show = task_manager.get_available_tasks()
	else:
		tasks_to_show = task_manager.get_tasks_by_type(current_task_type)

	// 创建任务项
	for task_data in tasks_to_show:
		var task_item = _create_task_item(task_data)
		list_container.add_child(task_item)

## 创建任务项
func _create_task_item(task_data: Dictionary) -> Control:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 60)
	container.add_theme_constant_override("separation", 4)

	// 任务标题行
	var header_row = HBoxContainer.new()

	// 任务类型图标
	var type_icon = Label.new()
	type_icon.text = _get_task_type_icon(task_data["type"])
	type_icon.custom_minimum_size = Vector2(30, 0)
	type_icon.add_theme_font_size_override("font_size", 18)
	header_row.add_child(type_icon)

	// 任务名称和状态
	var name_box = VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	name_label.text = task_data["name"]
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", _get_task_type_color(task_data["type"]))
	name_box.add_child(name_label)

	var status_label = Label.new()
	var status_text = _get_task_status_text(task_data)
	status_label.text = status_text
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))
	name_box.add_child(status_label)

	header_row.add_child(name_box)

	// 难度星级
	var difficulty_label = Label.new()
	difficulty_label.text = _get_difficulty_stars(task_data.get("difficulty", 0))
	difficulty_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0, 1))
	header_row.add_child(difficulty_label)

	container.add_child(header_row)

	// 进度条
	if task_data["status"] == "IN_PROGRESS":
		var progress_data = task_data.get("progress", {})
		var current = progress_data.get("current_progress", 0)
		var max_val = progress_data.get("max_progress", 1)

		if max_val > 0:
			var progress_bar = ProgressBar.new()
			progress_bar.custom_minimum_size = Vector2(0, 8)
			progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			progress_bar.value = float(current) / float(max_val) * 100.0
			progress_bar.tooltip_text = str(current) + "/" + str(max_val)
			container.add_child(progress_bar)

	// 添加点击事件
	var button = Button.new()
	button.flat = true
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(button)
	button.pressed.connect(_on_task_item_clicked.bind(task_data["id"]))

	// 存储任务ID
	container.set_meta("task_id", task_data["id"])

	return container

## 获取任务类型图标
func _get_task_type_icon(task_type: int) -> String:
	match task_type:
		0: return "📖"  # MAIN_STORY
		1: return "📜"  # SIDE_QUEST
		2: return "📅"  # DAILY
		3: return "📆"  # WEEKLY
		4: return "🏆"  # ACHIEVEMENT
		5: return "⚔️"  # CHALLENGE
		6: return "🎓"  # TUTORIAL
		7: return "🎉"  # EVENT
		8: return "🔄"  # REPEATABLE
		_: return "•"

## 获取任务类型颜色
func _get_task_type_color(task_type: int) -> Color:
	match task_type:
		0: return Color(1.0, 0.9, 0.3, 1)     # MAIN_STORY - 金色
		1: return Color(0.3, 0.9, 0.5, 1)      # SIDE_QUEST - 绿色
		2: return Color(0.2, 0.6, 1.0, 1)      # DAILY - 蓝色
		3: return Color(0.6, 0.4, 1.0, 1)      # WEEKLY - 紫色
		5: return Color(1.0, 0.4, 0.2, 1)      # CHALLENGE - 红色
		_: return Color(1.0, 1.0, 1.0, 1)

## 获取任务状态文本
func _get_task_status_text(task_data: Dictionary) -> String:
	var status = task_data["status"]
	match status:
		"LOCKED":
			return "🔒 未解锁"
		"AVAILABLE":
			return "✓ 可接受"
		"IN_PROGRESS":
			var progress_data = task_data.get("progress", {})
			var current = progress_data.get("current_progress", 0)
			var max_val = progress_data.get("max_progress", 1)
			return "进行中: %d/%d" % [current, max_val]
		"COMPLETED":
			return "✅ 已完成"
		"CLAIMED":
			return "✅ 已领取"
		"ABANDONED":
			return "❌ 已放弃"
		_:
			return ""

## 获取难度星级
func _get_difficulty_stars(difficulty: int) -> String:
	match difficulty:
		0: return "☆"       # TUTORIAL
		1: return "★"       # EASY
		2: return "★★"      # NORMAL
		3: return "★★★"     # HARD
		4: return "★★★★"    # EXPERT
		5: return "★★★★★"   # LEGENDARY
		_: return "?"

## 刷新任务详情
func _refresh_details() -> void:
	if current_task_id.is_empty():
		_clear_details()
		return

	if task_manager == null:
		return

	var task_details = task_manager.get_task_details(current_task_id)
	if task_details.is_empty():
		_clear_details()
		return

	// 显示任务名称
	if task_name_label != null:
		var icon = _get_task_type_icon(task_details["type"])
		task_name_label.text = "%s %s" % [icon, task_details["name"]]

	// 显示任务描述
	if task_description_label != null:
		task_description_label.text = task_details["description"]

	// 显示进度
	if task_progress_bar != null:
		var progress_data = task_details.get("progress", {})
		var current = progress_data.get("current_progress", 0)
		var max_val = progress_data.get("max_progress", 1)

		if max_val > 0:
			task_progress_bar.value = float(current) / float(max_val) * 100.0
			task_progress_bar.tooltip_text = "%d/%d" % [current, max_val]
		else:
			task_progress_bar.value = 0

	// 显示目标列表
	if task_objectives_list != null:
		// 清空现有目标
		for child in task_objectives_list.get_children():
			child.queue_free()

		var objectives = task_details.get("objectives", [])
		for i in range(objectives.size()):
			var objective = objectives[i]
			var objective_label = Label.new()
			var progress_data = task_details.get("progress", {}).get("objectives", {})
			var current_progress = progress_data.get(i, 0)
			var target = objective.get("target", 1)

			objective_label.text = "• %s (%d/%d)" % [objective["description"], current_progress, target]
			objective_label.add_theme_font_size_override("font_size", 11)
			objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			task_objectives_list.add_child(objective_label)

	// 显示奖励列表
	if rewards_list != null:
		// 清空现有奖励
		for child in rewards_list.get_children():
			child.queue_free()

		var rewards = task_details.get("rewards", [])
		for reward in rewards:
			var reward_label = Label.new()
			reward_label.text = _format_reward(reward)
			reward_label.add_theme_font_size_override("font_size", 10)
			reward_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 1))
			rewards_list.add_child(reward_label)

	// 更新按钮状态
	var status = task_details["status"]
	if accept_button != null:
		accept_button.visible = (status == "AVAILABLE")
		accept_button.disabled = false

	if abandon_button != null:
		abandon_button.visible = (status == "IN_PROGRESS")
		abandon_button.disabled = (task_details["type"] == TaskManager.TaskType.MAIN_STORY)

	if claim_button != null:
		claim_button.visible = (status == "COMPLETED")
		claim_button.disabled = false
		claim_button.text = "领取奖励"

## 清除详情显示
func _clear_details() -> void:
	if task_name_label != null:
		task_name_label.text = "选择一个任务查看详情"

	if task_description_label != null:
		task_description_label.text = ""

	if task_progress_bar != null:
		task_progress_bar.value = 0

	if task_objectives_list != null:
		for child in task_objectives_list.get_children():
			child.queue_free()

	if rewards_list != null:
		for child in rewards_list.get_children():
			child.queue_free()

	if accept_button != null:
		accept_button.visible = false

	if abandon_button != null:
		abandon_button.visible = false

	if claim_button != null:
		claim_button.visible = false

## 格式化奖励文本
func _format_reward(reward: Dictionary) -> String:
	var reward_type = reward.get("type", "")
	var amount = reward.get("amount", 0)

	match reward_type:
		"experience":
			return "经验值 x%d" % amount
		"basic_nano":
			return "基础纳米颗粒 x%d" % amount
		"energy_block":
			return "能量块 x%d" % amount
		"card":
			var card_id = reward.get("card_id", "")
			return "卡牌: %s" % card_id
		"blueprint_fragment":
			var fragment_id = reward.get("fragment_id", "")
			return "蓝图碎片: %s x%d" % [fragment_id, amount]
		_:
			return "%s x%d" % [reward_type, amount]

## 任务项点击处理
func _on_task_item_clicked(task_id: String) -> void:
	current_task_id = task_id
	task_selected.emit(task_id)
	_refresh_details()

## 接受任务按钮处理
func _on_accept_pressed() -> void:
	if current_task_id.is_empty() or task_manager == null:
		return

	if task_manager.accept_task(current_task_id):
		task_accepted.emit(current_task_id)
		_refresh_all_data()

## 放弃任务按钮处理
func _on_abandon_pressed() -> void:
	if current_task_id.is_empty() or task_manager == null:
		return

	// 确认放弃
	if task_manager.abandon_task(current_task_id):
		task_abandoned.emit(current_task_id)
		current_task_id = ""
		_refresh_all_data()

## 领取奖励按钮处理
func _on_claim_pressed() -> void:
	if current_task_id.is_empty() or task_manager == null:
		return

	if task_manager.claim_task_rewards(current_task_id):
		reward_claimed.emit(current_task_id)
		_refresh_all_data()

## 进度更新处理
func _on_progress_updated(task_id: String, current: int, max_val: int) -> void:
	if task_id == current_task_id:
		_refresh_details()

## 任务完成处理
func _on_task_completed(task_id: String) -> void:
	if task_id == current_task_id:
		_refresh_details()
	_refresh_task_list()

## 任务刷新处理
func _on_tasks_refreshed() -> void:
	_refresh_all_data()

## 刷新统计信息
func _refresh_statistics() -> void:
	// 可以添加统计信息显示
	pass

## 设置当前任务类型
func set_task_type(task_type: int) -> void:
	current_task_type = task_type
	_refresh_task_list()

## 搜索任务
func search_tasks(query: String) -> void:
	if task_manager == null:
		return

	var results = task_manager.search_tasks(query)
	// 显示搜索结果

## 获取推荐任务
func show_recommendations() -> void:
	if task_manager == null:
		return

	var recommended = task_manager.get_recommended_tasks(5)
	// 显示推荐任务

## 关闭面板
func _on_close_pressed() -> void:
	panel_closed.emit()
	queue_free()

## 获取面板统计信息
func get_panel_statistics() -> Dictionary:
	if task_manager == null:
		return {}

	return task_manager.get_task_statistics()