extends Control
## 全局存档按钮：在游戏任何位置都能快速存档

@onready var save_button: Button = $SaveButton
@onready var notification_label: Label = $NotificationLabel



func _ready() -> void:
	print("[GlobalSaveButton] ========== 初始化开始 ==========")

	# 确保在最上层显示（但不超过Godot的最大值）
	z_index = 100  # 合理的z_index值

	# 获取子节点引用
	save_button = $SaveButton
	notification_label = $NotificationLabel

	print("[GlobalSaveButton] 子节点引用获取完成")
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
		print("[GlobalSaveButton] 按钮信号已连接")

	# 设置按钮样式
	_setup_button_style()

	# 确保按钮可见
	visible = true
	if save_button:
		save_button.visible = true
		save_button.z_index = 101  # 比父容器稍高

	if notification_label:
		notification_label.z_index = 102  # 通知标签在按钮上方

	print("[GlobalSaveButton] 按钮可见性设置完成")
	print("[GlobalSaveButton] GlobalSaveButton visible: ", visible)
	print("[GlobalSaveButton] GlobalSaveButton anchors: ", anchor_left, ", ", anchor_top, ", ", anchor_right, ", ", anchor_bottom)
	print("[GlobalSaveButton] GlobalSaveButton offsets: ", offset_left, ", ", offset_top, ", ", offset_right, ", ", offset_bottom)
	print("[GlobalSaveButton] GlobalSaveButton z_index: ", z_index)

	# 监听窗口大小变化，重新调整位置
	if get_tree():
		get_tree().size_changed.connect(_on_window_resized)

	# 立即更新一次位置
	call_deferred("_on_window_resized")

	print("[GlobalSaveButton] ========== 初始化完成 ==========")

func _setup_button_style() -> void:
	if not save_button:
		return

	save_button.text = "💾 快速存档"
	save_button.custom_minimum_size = Vector2(120, 40)

	# 创建更醒目的样式
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.6, 0.9, 1.0)  # 亮蓝色背景
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	style_box.border_color = Color(0.3, 0.8, 1.0, 1.0)  # 亮蓝色边框
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.shadow_color = Color(0, 0, 0, 0.5)
	style_box.shadow_size = 8
	style_box.shadow_offset = Vector2(2, 2)

	# 悬停样式
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.2, 0.8, 1.0, 1.0)  # 更亮的蓝色
	hover_style.border_width_left = 3
	hover_style.border_width_top = 3
	hover_style.border_width_right = 3
	hover_style.border_width_bottom = 3
	hover_style.border_color = Color(0.5, 0.9, 1.0, 1.0)
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_left = 8
	hover_style.corner_radius_bottom_right = 8
	hover_style.shadow_color = Color(0, 0, 0, 0.6)
	hover_style.shadow_size = 10
	hover_style.shadow_offset = Vector2(2, 2)

	# 点击样式
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.05, 0.4, 0.7, 1.0)  # 深蓝色
	pressed_style.border_width_left = 3
	pressed_style.border_width_top = 3
	pressed_style.border_width_right = 3
	pressed_style.border_width_bottom = 3
	pressed_style.border_color = Color(0.2, 0.6, 0.9, 1.0)
	pressed_style.corner_radius_top_left = 8
	pressed_style.corner_radius_top_right = 8
	pressed_style.corner_radius_bottom_left = 8
	pressed_style.corner_radius_bottom_right = 8
	pressed_style.shadow_size = 0

	save_button.add_theme_stylebox_override("normal", style_box)
	save_button.add_theme_stylebox_override("hover", hover_style)
	save_button.add_theme_stylebox_override("pressed", pressed_style)

	# 字体样式
	save_button.add_theme_font_size_override("font_size", 16)
	save_button.add_theme_color_override("font_color", Color.WHITE)
	save_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.8))
	save_button.add_theme_color_override("font_pressed_color", Color(0.9, 0.95, 1.0))

	# 添加图标效果
	save_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _on_save_pressed() -> void:
	print("[GlobalSaveButton] 快速存档按钮被按下")

	# 禁用按钮防止重复点击
	if save_button:
		save_button.disabled = true
		save_button.text = "存档中..."

	# 显示存档中提示
	_show_notification("💾 正在存档...", Color(0.9, 0.9, 0.2))  # 黄色

	# 延迟一帧执行存档，避免阻塞UI
	await get_tree().process_frame
	_perform_save()

func _perform_save() -> void:
	if SaveManager == null:
		_show_notification("❌ 存档失败：管理器未找到", Color(0.9, 0.2, 0.2))
		_reenable_button()
		return

	if not SaveManager.has_method("save_game"):
		_show_notification("❌ 存档失败：方法不可用", Color(0.9, 0.2, 0.2))
		_reenable_button()
		return

	var success = SaveManager.save_game()

	if success:
		print("[GlobalSaveButton] 存档成功")
		_show_notification("✅ 存档成功！", Color(0.2, 0.8, 0.2))  # 绿色
	else:
		print("[GlobalSaveButton] 存档失败")
		_show_notification("❌ 存档失败，请检查存储空间", Color(0.9, 0.2, 0.2))  # 红色

	_reenable_button()

func _reenable_button() -> void:
	# 延迟重新启用按钮
	await get_tree().create_timer(0.5).timeout
	if save_button:
		save_button.disabled = false
		save_button.text = "💾 快速存档"

func _on_load_pressed() -> void:
	print("[GlobalSaveButton] 快速读档触发")

	if save_button:
		save_button.disabled = true
		save_button.text = "读档中..."

	_show_notification("📥 正在读档...", Color(0.9, 0.9, 0.2))

	await get_tree().process_frame
	_perform_load()

func _perform_load() -> void:
	if SaveManager == null:
		_show_notification("❌ 读档失败：管理器未找到", Color(0.9, 0.2, 0.2))
		_reenable_button()
		return

	if not SaveManager.has_method("load_game"):
		_show_notification("❌ 读档失败：方法不可用", Color(0.9, 0.2, 0.2))
		_reenable_button()
		return

	var success = SaveManager.load_game()

	if success:
		print("[GlobalSaveButton] 读档成功")
		_show_notification("📥 读档成功！", Color(0.2, 0.8, 0.2))
	else:
		print("[GlobalSaveButton] 读档失败")
		_show_notification("❌ 读档失败，存档不存在或已损坏", Color(0.9, 0.2, 0.2))

	_reenable_button()

func _show_notification(message: String, color: Color) -> void:
	if not notification_label:
		return

	notification_label.text = message
	notification_label.add_theme_color_override("font_color", color)
	notification_label.add_theme_font_size_override("font_size", 18)
	notification_label.z_index = 1001  # 确保在按钮上方
	notification_label.visible = true

	# 添加背景让文字更清晰
	var bg = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_label.add_child(bg)
	bg.z_index = -1

	# 启动计时器自动隐藏
	get_tree().create_timer(max(0.1, 2.0)).timeout.connect(_hide_notification)

func _hide_notification() -> void:
	if notification_label:
		notification_label.visible = false
		# 移除背景
		for child in notification_label.get_children():
			if child is ColorRect:
				child.queue_free()

# 快捷键支持
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# F5 快速存档
		if event.keycode == KEY_F5:
			_on_save_pressed()
			_safe_set_input_handled()
		# F9 快速读档（如果需要）
		elif event.keycode == KEY_F9:
			_on_load_pressed()
			_safe_set_input_handled()

func _safe_set_input_handled() -> void:
	if not is_inside_tree():
		return
	var vp: Viewport = get_viewport()
	if vp != null and is_instance_valid(vp) and vp.is_inside_tree():
		vp.set_input_as_handled()

## 窗口大小变化处理
func _on_window_resized() -> void:
	# 对于BOTTOM_RIGHT锚点（anchor_right=1.0, anchor_bottom=1.0）：
	# offset_left: 从右边界向左的距离（正值）
	# offset_top: 从底边界向上的距离（正值）
	# offset_right: 从右边界向左的距离（必须 > offset_left）
	# offset_bottom: 从底边界向上的距离（必须 > offset_top）

	# 设置按钮位置：距离右边15px，距离底部15px
	# 按钮宽度120px，高度40px
	offset_left = 15.0     # 从右边向左15px开始
	offset_top = 15.0      # 从底部向上15px开始
	offset_right = 135.0   # 从右边向左135px结束（15 + 120宽度）
	offset_bottom = 55.0   # 从底部向上55px结束（15 + 40高度）

	print("[GlobalSaveButton] 位置已更新到右下角")
	print("[GlobalSaveButton] offset_left: ", offset_left, " (距离右边)")
	print("[GlobalSaveButton] offset_top: ", offset_top, " (距离底部)")
	print("[GlobalSaveButton] offset_right: ", offset_right)
	print("[GlobalSaveButton] offset_bottom: ", offset_bottom)
	print("[GlobalSaveButton] 最终位置: x=", position.x, " y=", position.y)

	# 更新通知标签位置（在按钮右侧）
	if notification_label:
		# 通知标签使用TOP_LEFT锚点，相对于父容器定位
		notification_label.offset_left = 130.0   # 在按钮右侧
		notification_label.offset_top = 10.0     # 垂直居中
		notification_label.offset_right = 260.0  # 宽度130px
		notification_label.offset_bottom = 30.0  # 高度20px
