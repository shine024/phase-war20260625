extends Control
## 存档槽管理器：提供多存档槽管理界面

## 信号定义
signal slot_selected(slot_id: String)
signal slot_deleted(slot_id: String)
signal slot_copied(source_slot: String, target_slot: String)
signal manager_closed()

## UI组件引用
@onready var slot_container: GridContainer = $VBox/SlotContainer
@onready var import_button: Button = $VBox/Toolbar/ImportButton
@onready var export_button: Button = $VBox/Toolbar/ExportButton
@onready var cleanup_button: Button = $VBox/Toolbar/CleanupButton
@onready var close_button: Button = $VBox/CloseButton

var selected_slot: String = ""

func _ready() -> void:
	if SaveManager == null:
		push_error("[SaveSlotManager] 无法找到存档管理器")

	_setup_connections()
	_refresh_all_slots()

## 设置信号连接
func _setup_connections() -> void:
	if import_button != null:
		import_button.pressed.connect(_on_import_pressed)

	if export_button != null:
		export_button.pressed.connect(_on_export_pressed)

	if cleanup_button != null:
		cleanup_button.pressed.connect(_on_cleanup_pressed)

	if close_button != null:
		close_button.pressed.connect(_on_close_pressed)

## 刷新所有存档槽
func _refresh_all_slots() -> void:
	if slot_container == null or SaveManager == null:
		return

	# 清空现有内容
	for child in slot_container.get_children():
		child.queue_free()

	# 等待清空完成
	await get_tree().process_frame

	# 获取存档槽信息
	var save_slots = {}
	if SaveManager.has_method("get_all_save_slots"):
		save_slots = SaveManager.get_all_save_slots()
	else:
		# 使用默认槽
		save_slots = {
			"slot_1": {"slot_id": "slot_1", "slot_name": "存档槽 1"},
			"slot_2": {"slot_id": "slot_2", "slot_name": "存档槽 2"},
			"slot_3": {"slot_id": "slot_3", "slot_name": "存档槽 3"}
		}

	# 为每个存档槽创建UI
	for slot_id in save_slots:
		var slot_info = save_slots[slot_id]
		var slot_panel = _create_slot_panel(slot_info)
		slot_container.add_child(slot_panel)

## 创建存档槽面板
func _create_slot_panel(slot_info: Dictionary) -> Control:
	var slot_id = slot_info.get("slot_id", "")
	var slot_name = slot_info.get("slot_name", "未知槽位")

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(200, 150)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	# 槽位名称
	var name_label = Label.new()
	name_label.text = slot_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# 存档信息
	var info_label = Label.new()
	var info_text = _get_slot_info_text(slot_id)
	info_label.text = info_text
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(info_label)

	# 按钮容器
	var button_box = HBoxContainer.new()
	vbox.add_child(button_box)

	# 加载按钮
	var load_button = Button.new()
	load_button.text = "加载"
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_button.pressed.connect(_on_load_slot.bind(slot_id))
	button_box.add_child(load_button)

	# 保存按钮
	var save_button = Button.new()
	save_button.text = "保存"
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(_on_save_slot.bind(slot_id))
	button_box.add_child(save_button)

	# 删除按钮（跳过自动存档和快速存档）
	if slot_id != "auto_save" and slot_id != "quick_save":
		var delete_button = Button.new()
		delete_button.text = "删除"
		delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		delete_button.pressed.connect(_on_delete_slot.bind(slot_id))
		button_box.add_child(delete_button)

	return panel

## 获取存档槽信息文本
func _get_slot_info_text(slot_id: String) -> String:
	if SaveManager == null:
		return "无存档信息"

	# 检查是否有存档
	var has_save = false
	if SaveManager.has_method("has_save_in_slot"):
		has_save = SaveManager.has_save_in_slot(slot_id)
	else:
		has_save = SaveManager.has_method("has_save") and SaveManager.has_save()

	if not has_save:
		return "空槽位"

	# 获取详细信息
	var info_lines = []

	if SaveManager.has_method("get_save_slot_info"):
		var slot_info = SaveManager.get_save_slot_info(slot_id)
		var preview = slot_info.get("preview_data", {})

		var last_modified = slot_info.get("last_modified", 0)
		if last_modified > 0:
			var datetime = Time.get_datetime_dict_from_unix_time(last_modified)
			var date_str = "%04d-%02d-%02d %02d:%02d" % [
				datetime.year, datetime.month, datetime.day,
				datetime.hour, datetime.minute
			]
			info_lines.append("保存时间: " + date_str)

		if not preview.is_empty():
			if preview.has("max_level"):
				info_lines.append("等级: %d" % preview["max_level"])
			if preview.has("playtime_minutes"):
				var playtime = preview["playtime_minutes"]
				var hours = playtime / 60
				var minutes = playtime % 60
				info_lines.append("游戏时间: %dh %dm" % [hours, minutes])
			if preview.has("achievements_unlocked"):
				info_lines.append("成就: %d" % preview["achievements_unlocked"])

	# 获取文件大小
	if SaveManager.has_method("get_save_file_size"):
		var file_size = SaveManager.get_save_file_size(slot_id)
		if file_size > 0:
			var size_kb = file_size / 1024
			info_lines.append("文件大小: %d KB" % size_kb)

	return "\n".join(info_lines) if not info_lines.is_empty() else "存档损坏"

## 加载存档槽
func _on_load_slot(slot_id: String) -> void:
	if SaveManager == null:
		return

	var success = false
	if SaveManager.has_method("load_game_from_slot"):
		success = SaveManager.load_game_from_slot(slot_id)
	elif SaveManager.has_method("load_game"):
		success = SaveManager.load_game()

	if success:
		# [LOG-v5.1] print("[SaveSlotManager] 成功加载存档槽: ", slot_id)
		slot_selected.emit(slot_id)
		_refresh_all_slots()
	else:
		push_error("[SaveSlotManager] 加载存档槽失败: ", slot_id)

## 保存到存档槽
func _on_save_slot(slot_id: String) -> void:
	if SaveManager == null:
		return

	var success = false
	if SaveManager.has_method("save_game_to_slot"):
		success = SaveManager.save_game_to_slot(slot_id)
	elif SaveManager.has_method("save_game"):
		success = SaveManager.save_game()

	if success:
		# [LOG-v5.1] print("[SaveSlotManager] 成功保存到槽位: ", slot_id)
		_refresh_all_slots()
	else:
		push_error("[SaveSlotManager] 保存到槽位失败: ", slot_id)

## 删除存档槽
func _on_delete_slot(slot_id: String) -> void:
	if SaveManager == null:
		return

	# 确认删除
	# 这里可以添加确认对话框

	var success = false
	if SaveManager.has_method("delete_save"):
		success = SaveManager.delete_save(slot_id)

	if success:
		# [LOG-v5.1] print("[SaveSlotManager] 成功删除存档槽: ", slot_id)
		slot_deleted.emit(slot_id)
		_refresh_all_slots()
	else:
		push_error("[SaveSlotManager] 删除存档槽失败: ", slot_id)

## 导入存档
func _on_import_pressed() -> void:
	# 打开文件选择对话框
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.title = "选择要导入的存档文件"
	dialog.add_filter("*.json", "JSON存档文件")
	dialog.access = FileDialog.ACCESS_USERDATA
	dialog.file_selected.connect(_on_import_file_selected.bind(dialog))
	add_child(dialog)
	dialog.popup_centered()

## 导入文件选择处理
func _on_import_file_selected(file_path: String, dialog: FileDialog) -> void:
	dialog.queue_free()

	if SaveManager == null:
		return

	# 选择目标槽位
	var target_slot = "slot_1"  # 默认槽位
	# 这里可以添加槽位选择对话框

	var success = false
	if SaveManager.has_method("import_save"):
		success = SaveManager.import_save(file_path, target_slot)

	if success:
		# [LOG-v5.1] print("[SaveSlotManager] 成功导入存档到: ", target_slot)
		_refresh_all_slots()
	else:
		push_error("[SaveSlotManager] 导入存档失败")

## 导出存档
func _on_export_pressed() -> void:
	# 打开文件保存对话框
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.title = "选择导出存档的位置"
	dialog.add_filter("*.json", "JSON存档文件")
	dialog.access = FileDialog.ACCESS_USERDATA

	# 默认文件名
	var current_time = Time.get_datetime_dict_from_system()
	var default_filename = "save_%04d%02d%02d_%02d%02d.json" % [
		current_time.year, current_time.month, current_time.day,
		current_time.hour, current_time.minute
	]
	dialog.current_file = default_filename

	dialog.file_selected.connect(_on_export_file_selected.bind(dialog))
	add_child(dialog)
	dialog.popup_centered()

## 导出文件选择处理
func _on_export_file_selected(file_path: String, dialog: FileDialog) -> void:
	dialog.queue_free()

	if SaveManager == null:
		return

	# 导出当前槽位
	var source_slot = "slot_1"  # 默认槽位
	# 这里可以使用当前选中的槽位

	var success = false
	if SaveManager.has_method("export_save"):
		success = SaveManager.export_save(source_slot, file_path)

	if success:
		pass
		# [LOG-v5.1] print("[SaveSlotManager] 成功导出存档: ", file_path)
	else:
		push_error("[SaveSlotManager] 导出存档失败")

## 清理旧存档
func _on_cleanup_pressed() -> void:
	# 确认清理
	# 这里可以添加确认对话框

	if SaveManager == null:
		return

	var max_age_days = 30  # 默认清理30天前的存档
	# 这里可以添加年龄设置对话框

	if SaveManager.has_method("cleanup_old_saves"):
		SaveManager.cleanup_old_saves(max_age_days)
		# [LOG-v5.1] print("[SaveSlotManager] 清理旧存档完成")
		_refresh_all_slots()

## 关闭管理器
func _on_close_pressed() -> void:
	manager_closed.emit()
	queue_free()

## 获取存档统计信息
func get_save_statistics() -> Dictionary:
	if SaveManager != null and SaveManager.has_method("get_save_statistics"):
		return SaveManager.get_save_statistics()
	return {}

## 自动存档配置
func configure_auto_save(enabled: bool, interval_minutes: int) -> void:
	if SaveManager != null and SaveManager.has_method("configure_auto_save"):
		SaveManager.configure_auto_save(enabled, interval_minutes)
		# [LOG-v5.1] print("[SaveSlotManager] 自动存档配置: %s, 间隔: %d 分钟" % [enabled, interval_minutes])

## 快速存档
func quick_save() -> bool:
	if SaveManager != null and SaveManager.has_method("quick_save"):
		return SaveManager.quick_save()
	return false

## 快速读档
func quick_load() -> bool:
	if SaveManager != null and SaveManager.has_method("quick_load"):
		return SaveManager.quick_load()
	return false
