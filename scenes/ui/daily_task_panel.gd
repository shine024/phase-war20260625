extends Control
## 日常任务面板：显示每日任务和进度

const DailyTaskManagerClass = preload("res://managers/daily_task_manager.gd")

var daily_task_manager: Node

@onready var task_list = $VBox/ScrollContainer/TaskList
@onready var header_label = $VBox/Header/HeaderLabel
@onready var refresh_label = $VBox/Header/RefreshLabel
@onready var progress_bar = $VBox/Header/ProgressBar
@onready var claim_all_button = $VBox/Header/ClaimAllButton

func _ready() -> void:
	daily_task_manager = get_node_or_null("/root/DailyTaskManager")
	size = Vector2i(750, 650)

	_connect_signals()
	_refresh_tasks()
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	t.timeout.connect(_tick_refresh_countdown)
	add_child(t)
	_tick_refresh_countdown()

func _connect_signals() -> void:
	if daily_task_manager:
		if daily_task_manager.has_signal("daily_tasks_refreshed"):
			if not daily_task_manager.daily_tasks_refreshed.is_connected(_on_tasks_refreshed):
				daily_task_manager.daily_tasks_refreshed.connect(_on_tasks_refreshed)

		if daily_task_manager.has_signal("task_completed"):
			if not daily_task_manager.task_completed.is_connected(_on_task_completed):
				daily_task_manager.task_completed.connect(_on_task_completed)

	if claim_all_button:
		claim_all_button.pressed.connect(_on_claim_all_pressed)

func _refresh_tasks() -> void:
	if not task_list:
		return

	# 清空现有列表
	for child in task_list.get_children():
		child.queue_free()

	if not daily_task_manager:
		return

	var tasks = daily_task_manager.get_daily_tasks()
	for task in tasks:
		_add_task_item(task)

	_update_header()

func _update_header() -> void:
	if not daily_task_manager:
		return

	var stats = daily_task_manager.get_task_stats()
	var completion_rate = stats.get("completion_rate", 0.0)

	if header_label:
		header_label.text = "日常任务 - %d/%d" % [stats.get("completed", 0), stats.get("total", 0)]

	if progress_bar:
		progress_bar.value = completion_rate * 100.0

	if refresh_label:
		var countdown = daily_task_manager.get_refresh_countdown()
		var hours = countdown / 3600
		var minutes = (countdown % 3600) / 60
		refresh_label.text = "刷新: %02d:%02d" % [hours, minutes]

	if claim_all_button:
		var has_claimable = _has_claimable_tasks()
		claim_all_button.disabled = not has_claimable
		claim_all_button.text = "领取全部奖励" if has_claimable else "无可领取奖励"

func _add_task_item(task: Dictionary) -> void:
	var item = PanelContainer.new()
	item.custom_minimum_size = Vector2(0, 120)

	# 创建样式
	var style = StyleBoxFlat.new()
	if task["completed"]:
		style.bg_color = Color(0.15, 0.25, 0.20, 0.98)
		style.border_color = Color(0.4, 0.95, 0.6, 0.8)
	else:
		style.bg_color = Color(0.12, 0.15, 0.22, 0.98)
		style.border_color = Color(0.3, 0.35, 0.45, 0.6)

	style.border_width_left = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	item.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	item.add_child(hbox)

	# 难度标识
	var difficulty_label = Label.new()
	var difficulty = task["difficulty"]
	difficulty_label.text = DailyTaskManagerClass.get_difficulty_name(difficulty)
	difficulty_label.custom_minimum_size = Vector2(60, 0)
	difficulty_label.add_theme_font_size_override("font_size", 12)
	difficulty_label.add_theme_color_override("font_color", DailyTaskManagerClass.get_difficulty_color(difficulty))
	difficulty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(difficulty_label)

	# 任务信息
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	hbox.add_child(vbox)

	# 任务名称
	var task_type = task["type"]
	var name_label = Label.new()
	name_label.text = DailyTaskManagerClass.get_task_type_name(task_type)
	name_label.add_theme_font_size_override("font_size", 14)
	if task["completed"]:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
	else:
		name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85, 1.0))
	vbox.add_child(name_label)

	# 进度信息
	var progress_hbox = HBoxContainer.new()
	vbox.add_child(progress_hbox)

	var progress_label = Label.new()
	var current = task["current"]
	var target = task["target"]
	progress_label.text = "进度: %d/%d" % [current, target]
	progress_label.add_theme_font_size_override("font_size", 12)
	progress_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9, 1.0))
	progress_hbox.add_child(progress_label)

	# 进度条
	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(200, 12)
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.max_value = target
	progress_bar.value = current
	progress_hbox.add_child(progress_bar)

	# 状态标签
	if task["completed"]:
		var status_label = Label.new()
		status_label.text = "✓ 已完成" if not task["claimed"] else "✓ 已领取"
		status_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6, 1.0))
		progress_hbox.add_child(status_label)

	# 奖励信息
	var reward_label = Label.new()
	var reward_text = _format_reward(task["reward"])
	reward_label.text = "奖励: " + reward_text
	reward_label.add_theme_font_size_override("font_size", 11)
	reward_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6, 1.0))
	vbox.add_child(reward_label)

	# 领取按钮
	if task["completed"] and not task["claimed"]:
		var claim_button = Button.new()
		claim_button.text = "领取"
		claim_button.custom_minimum_size = Vector2(80, 35)
		claim_button.pressed.connect(_on_claim_pressed.bind(task["id"]))
		hbox.add_child(claim_button)

	task_list.add_child(item)

func _format_reward(reward: Dictionary) -> String:
	var parts = []

	for reward_type in reward:
		var amount = reward[reward_type]
		match reward_type:
			"nanomaterial":
				parts.append("纳米材料x%d" % amount)
			"energy_blocks":
				parts.append("能量块x%d" % amount)
			"common_fragment":
				parts.append("普通碎片x%d" % amount)
			"rare_fragment":
				parts.append("稀有碎片x%d" % amount)
			"epic_fragment":
				parts.append("史诗碎片x%d" % amount)
			"legendary_fragment":
				parts.append("传说碎片x%d" % amount)

	return ", ".join(PackedStringArray(parts))

func _on_claim_pressed(task_id: String) -> void:
	if daily_task_manager:
		if daily_task_manager.claim_task_reward(task_id):
			_refresh_tasks()

func _on_claim_all_pressed() -> void:
	if daily_task_manager:
		var tasks = daily_task_manager.get_daily_tasks()
		var claimed_count = 0

		for task in tasks:
			if task["completed"] and not task["claimed"]:
				if daily_task_manager.claim_task_reward(task["id"]):
					claimed_count += 1

		if claimed_count > 0:
			_refresh_tasks()

func _on_tasks_refreshed() -> void:
	_refresh_tasks()

func _on_task_completed(task: Dictionary) -> void:
	# 播放完成音效或特效
	if SignalBus and SignalBus.has_signal("play_sound"):
		SignalBus.play_sound.emit("task_complete")

func _has_claimable_tasks() -> bool:
	if not daily_task_manager:
		return false

	var tasks = daily_task_manager.get_daily_tasks()
	for task in tasks:
		if task["completed"] and not task["claimed"]:
			return true
	return false

func _tick_refresh_countdown() -> void:
	if refresh_label and daily_task_manager:
		var countdown = daily_task_manager.get_refresh_countdown()
		var hours = countdown / 3600
		var minutes = (countdown % 3600) / 60
		refresh_label.text = "刷新: %02d:%02d" % [hours, minutes]
