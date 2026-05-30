extends CanvasLayer
## 通知覆盖层：显示游戏内的通知消息

## 通知项类
class NotificationItem extends Control:
	var notification_data: Dictionary = {}
	var _timer_cancelled: bool = false

	func _init(data: Dictionary) -> void:
		notification_data = data

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		position = Vector2(-400, 100)  # 从右侧开始

		# 创建通知UI
		_create_notification_ui()

		# 设置自动关闭定时器
		var duration = notification_data.get("duration", 5.0)
		if duration > 0:
			var item = self
			get_tree().create_timer(duration).timeout.connect(func() -> void:
				if not item._timer_cancelled:
					item._on_timeout()
			)

		# 添加动画效果
		_add_entry_animation()

	func _create_notification_ui() -> void:
		var container = VBoxContainer.new()
		container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(container)

		# 通知背景
		var background = Panel.new()
		background.custom_minimum_size = Vector2(350, 80)
		container.add_child(background)

		var content_margin = MarginContainer.new()
		content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_margin.add_theme_constant_override("margin_left", 10)
		content_margin.add_theme_constant_override("margin_right", 10)
		content_margin.add_theme_constant_override("margin_top", 8)
		content_margin.add_theme_constant_override("margin_bottom", 8)
		background.add_child(content_margin)

		var content_vbox = VBoxContainer.new()
		content_margin.add_child(content_vbox)

		# 标题行
		var header_hbox = HBoxContainer.new()
		content_vbox.add_child(header_hbox)

		# 图标
		var icon_label = Label.new()
		icon_label.text = _get_notification_icon()
		icon_label.add_theme_font_size_override("font_size", 20)
		header_hbox.add_child(icon_label)

		# 标题
		var title_label = Label.new()
		title_label.text = notification_data.get("title", "")
		title_label.add_theme_font_size_override("font_size", 14)
		title_label.add_theme_color_override("font_color", _get_notification_color())
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_hbox.add_child(title_label)

		# 关闭按钮
		var close_button = Button.new()
		close_button.text = "×"
		close_button.custom_minimum_size = Vector2(20, 20)
		close_button.pressed.connect(_on_close_pressed)
		header_hbox.add_child(close_button)

		# 消息内容
		var message_label = Label.new()
		message_label.text = notification_data.get("message", "")
		message_label.add_theme_font_size_override("font_size", 11)
		message_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		message_label.custom_minimum_size = Vector2(330, 0)
		content_vbox.add_child(message_label)

		# 时间戳
		var timestamp = notification_data.get("timestamp", 0)
		if timestamp > 0:
			var time_label = Label.new()
			var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
			time_label.text = "%02d:%02d" % [datetime.hour, datetime.minute]
			time_label.add_theme_font_size_override("font_size", 9)
			time_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			content_vbox.add_child(time_label)

	func _get_notification_icon() -> String:
		var type = notification_data.get("type", 0)
		match type:
			0: return "ℹ️"    # INFO
			1: return "✅"    # SUCCESS
			2: return "⚠️"    # WARNING
			3: return "❌"    # ERROR
			4: return "🏆"    # ACHIEVEMENT
			5: return "📜"    # QUEST
			6: return "⚙️"    # SYSTEM
			7: return "👥"    # SOCIAL
			_: return "•"

	func _get_notification_color() -> Color:
		var type = notification_data.get("type", 0)
		match type:
			0: return Color(0.2, 0.6, 1.0)    # INFO - 蓝
			1: return Color(0.3, 0.9, 0.5)    # SUCCESS - 绿
			2: return Color(1.0, 0.8, 0.2)    # WARNING - 黄
			3: return Color(1.0, 0.3, 0.3)    # ERROR - 红
			4: return Color(1.0, 0.9, 0.3)    # ACHIEVEMENT - 金
			5: return Color(0.6, 0.4, 1.0)    # QUEST - 紫
			6: return Color(0.5, 0.5, 0.5)    # SYSTEM - 灰
			7: return Color(0.9, 0.4, 0.8)    # SOCIAL - 粉
			_: return Color(1.0, 1.0, 1.0)

	func _add_entry_animation() -> void:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)

		# 滑入动画
		tween.tween_property(self, "position:x", -20.0, 0.5)
		# 淡入动画
		modulate.a = 0.0
		tween.tween_property(self, "modulate:a", 1.0, 0.3)

	func _on_timeout() -> void:
		_close_notification()

	func _on_close_pressed() -> void:
		_timer_cancelled = true
		_close_notification()

	func _close_notification() -> void:
		# 添加退出动画
		var tween = create_tween()
		tween.set_parallel(true)
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_QUAD)

		# 滑出动画
		tween.tween_property(self, "position:x", -400.0, 0.3)
		# 淡出动画
		tween.tween_property(self, "modulate:a", 0.0, 0.3)

		# 动画结束后删除
		tween.tween_callback(queue_free)# DELAY: 0.3)

## 通知容器
var notification_container: VBoxContainer = null
var max_notifications: int = 5
var notification_gap: float = 10.0

func _ready() -> void:
	_create_notification_container()

## 创建通知容器
func _create_notification_container() -> void:
	notification_container = VBoxContainer.new()
	notification_container.name = "NotificationContainer"
	notification_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	notification_container.position = Vector2(-20, 100)
	notification_container.add_theme_constant_override("separation", notification_gap)
	add_child(notification_container)

## 显示通知
func show_notification(notification_data: Dictionary) -> void:
	# 检查是否超过最大通知数
	if notification_container.get_child_count() >= max_notifications:
		_remove_oldest_notification()

	# 创建通知项
	var notification_item = NotificationItem.new(notification_data)
	notification_container.add_child(notification_item)

	# 连接点击信号
	notification_item.gui_input.connect(_on_notification_input.bind(notification_data))

## 通知输入处理
func _on_notification_input(event: InputEvent, notification_data: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# 处理通知点击
			var action = notification_data.get("action", {})
			if not action.is_empty():
				_execute_notification_action(action)

## 执行通知动作
func _execute_notification_action(action: Dictionary) -> void:
	var action_type = action.get("type", "")
	var action_data = action.get("data", {})

	match action_type:
		"open_panel":
			_open_panel(action_data.get("panel", ""))
		"navigate_to":
			_navigate_to(action_data.get("target", ""))
		"run_command":
			_run_command(action_data.get("command", ""))

## 打开面板
func _open_panel(panel_name: String) -> void:
	# 实现打开面板的逻辑

## 导航到目标
func _navigate_to(target: String) -> void:
	# 实现导航逻辑

## 运行命令
func _run_command(command: String) -> void:
	# 实现命令执行逻辑

## 移除最旧的通知
func _remove_oldest_notification() -> void:
	if notification_container.get_child_count() > 0:
		var oldest = notification_container.get_child(0)
		oldest.queue_free()

## 清除所有通知
func clear_all_notifications() -> void:
	for child in notification_container.get_children():
			child.queue_free()

## 设置最大通知数
func set_max_notifications(count: int) -> void:
	max_notifications = count

## 设置通知间距
func set_notification_gap(gap: float) -> void:
	notification_gap = gap
	if notification_container != null:
		notification_container.add_theme_constant_override("separation", gap)
