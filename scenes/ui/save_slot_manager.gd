extends Control
## 存档槽管理器：基于 SaveManager 的真实多槽位 API（MAX_SLOTS=3）。
## v7.3 重写：原版调用 14 个不存在的 SaveManager 方法（has_save_in_slot /
## load_game_from_slot / save_game_to_slot / get_save_slot_info / get_save_file_size /
## delete_save / import_save / export_save / cleanup_old_saves / get_all_save_slots /
## configure_auto_save / quick_save / quick_load 等）全部静默失败。
## 现统一走真实 API：set_slot(int)/get_slot_info()/load_game()/save_game()/delete_slot()。

## 信号定义
signal slot_selected(slot_num: int)
signal slot_deleted(slot_num: int)
signal manager_closed()

## UI组件引用（路径与 save_slot_manager.tscn 一致）
@onready var slot_container: GridContainer = $VBox/SlotContainer
@onready var import_button: Button = $VBox/Toolbar/ImportButton
@onready var export_button: Button = $VBox/Toolbar/ExportButton
@onready var cleanup_button: Button = $VBox/Toolbar/CleanupButton
@onready var close_button: Button = $VBox/CloseButton

## 导入/导出文件对话框选中槽位（默认当前槽）
var _io_slot: int = 1

func _ready() -> void:
	if SaveManager == null:
		push_error("[SaveSlotManager] 无法找到存档管理器")
		return
	_io_slot = SaveManager.get_slot()
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

## 刷新所有存档槽（真实 API：get_slot_info() 返回 Array[{slot,exists,level}]）
func _refresh_all_slots() -> void:
	if slot_container == null or SaveManager == null:
		return
	for child in slot_container.get_children():
		child.queue_free()
	var slot_infos: Array = SaveManager.get_slot_info()
	# get_slot_info() 可能未含当前槽之外的排序保证，按 slot 字段排序确保 1/2/3 顺序
	slot_infos.sort_custom(func(a, b): return int(a.get("slot", 0)) < int(b.get("slot", 0)))
	for info in slot_infos:
		var slot_num: int = int(info.get("slot", 0))
		if slot_num <= 0:
			continue
		slot_container.add_child(_create_slot_panel(slot_num, info))

## 创建存档槽面板
func _create_slot_panel(slot_num: int, info: Dictionary) -> Control:
	var is_current: bool = (slot_num == SaveManager.get_slot())
	var exists: bool = bool(info.get("exists", false))
	var level: int = int(info.get("level", 0))

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(240, 160)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# 槽位标题
	var name_label = Label.new()
	name_label.text = "存档槽 %d%s" % [slot_num, " (当前)" if is_current else ""]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# 存档信息文本
	var info_label = Label.new()
	info_label.text = _get_slot_info_text(slot_num, exists, level)
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(info_label)

	# 按钮容器
	var button_box = HBoxContainer.new()
	vbox.add_child(button_box)

	var load_button = Button.new()
	load_button.text = "加载"
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_button.disabled = not exists
	load_button.pressed.connect(_on_load_slot.bind(slot_num))
	button_box.add_child(load_button)

	var save_button = Button.new()
	save_button.text = "保存"
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(_on_save_slot.bind(slot_num))
	button_box.add_child(save_button)

	var delete_button = Button.new()
	delete_button.text = "删除"
	delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_button.disabled = not exists
	delete_button.pressed.connect(_on_delete_slot.bind(slot_num))
	button_box.add_child(delete_button)

	return panel

## 获取存档槽信息文本（真实 API：get_slot_info 提供 level；文件大小直读磁盘）
func _get_slot_info_text(slot_num: int, exists: bool, level: int) -> String:
	if not exists:
		return "空槽位"
	var lines: PackedStringArray = []
	if level > 0:
		lines.append("最高关卡: %d" % level)
	# 文件大小：直接读取槽位主文件
	var path := "user://save_slot_%d.json" % slot_num
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var size_bytes := int(f.get_length())
			f.close()
			if size_bytes > 0:
				lines.append("文件大小: %d KB" % (size_bytes / 1024))
	return "\n".join(lines) if not lines.is_empty() else "存档存在"

## 加载存档槽（真实 API：set_slot + load_game）
func _on_load_slot(slot_num: int) -> void:
	if SaveManager == null:
		return
	SaveManager.set_slot(slot_num)
	var success: bool = SaveManager.load_game()
	if success:
		slot_selected.emit(slot_num)
		_refresh_all_slots()
	else:
		push_error("[SaveSlotManager] 加载存档槽 %d 失败" % slot_num)

## 保存到存档槽（真实 API：set_slot + save_game）
func _on_save_slot(slot_num: int) -> void:
	if SaveManager == null:
		return
	var prev_slot := SaveManager.get_slot()
	SaveManager.set_slot(slot_num)
	var success: bool = SaveManager.save_game()
	if success:
		slot_selected.emit(slot_num)
		_refresh_all_slots()
	else:
		# 保存失败回退槽位
		SaveManager.set_slot(prev_slot)
		push_error("[SaveSlotManager] 保存到槽位 %d 失败" % slot_num)

## 删除存档槽（真实 API：delete_slot）
func _on_delete_slot(slot_num: int) -> void:
	if SaveManager == null:
		return
	SaveManager.delete_slot(slot_num)
	slot_deleted.emit(slot_num)
	_refresh_all_slots()

## ─── 导入存档 ───
## 直接文件复制到目标槽位的 user://save_slot_N.json（绕过 SaveManager 内部状态，
## 导入后玩家点"加载"该槽即可应用）。
func _on_import_pressed() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.title = "选择要导入的存档文件"
	dialog.add_filter("*.json", "JSON存档文件")
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_selected.connect(_on_import_file_selected.bind(dialog))
	add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))

func _on_import_file_selected(file_path: String, dialog: FileDialog) -> void:
	dialog.queue_free()
	if SaveManager == null:
		return
	var target := _io_slot
	var dest := "user://save_slot_%d.json" % target
	var err := DirAccess.copy_absolute(file_path, ProjectSettings.globalize_path(dest))
	if err == OK:
		# 清缓存让 get_slot_info 重读
		SaveManager.force_slot_info_refresh()
		_refresh_all_slots()
	else:
		push_error("[SaveSlotManager] 导入存档失败 (错误码 %d)" % err)

## ─── 导出存档 ───
## 复制当前槽位主文件到玩家选择的目标路径。
func _on_export_pressed() -> void:
	var source := "user://save_slot_%d.json" % _io_slot
	if not FileAccess.file_exists(source):
		push_warning("[SaveSlotManager] 当前槽位 %d 无存档可导出" % _io_slot)
		return
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.title = "选择导出存档的位置"
	dialog.add_filter("*.json", "JSON存档文件")
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	var current_time := Time.get_datetime_dict_from_system()
	dialog.current_file = "save_slot_%d_%04d%02d%02d_%02d%02d.json" % [
		_io_slot,
		current_time.year, current_time.month, current_time.day,
		current_time.hour, current_time.minute
	]
	dialog.file_selected.connect(_on_export_file_selected.bind(dialog, source))
	add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))

func _on_export_file_selected(file_path: String, dialog: FileDialog, source: String) -> void:
	dialog.queue_free()
	var err := DirAccess.copy_absolute(ProjectSettings.globalize_path(source), file_path)
	if err != OK:
		push_error("[SaveSlotManager] 导出存档失败 (错误码 %d)" % err)

## ─── 清理备份文件 ───
## SaveManager 每 SAVE_BACKUP_INTERVAL_MS 生成 *_backup.json；本按钮清理所有槽位的备份档
## （主档不受影响）。原版的 cleanup_old_saves(max_age_days) 不存在，已替换为真实清理。
func _on_cleanup_pressed() -> void:
	if SaveManager == null:
		return
	var max_slots := 3
	if "MAX_SLOTS" in SaveManager:
		max_slots = int(SaveManager.MAX_SLOTS)
	var dir := DirAccess.open("user://")
	if dir == null:
		push_warning("[SaveSlotManager] 无法打开 user:// 目录")
		return
	var removed := 0
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		# 匹配 save_slot_N_backup.json
		if fname.begins_with("save_slot_") and fname.ends_with("_backup.json"):
			if dir.remove(fname) == OK:
				removed += 1
		fname = dir.get_next()
	dir.list_dir_end()
	if removed > 0:
		_refresh_all_slots()

## 关闭管理器
func _on_close_pressed() -> void:
	manager_closed.emit()
	queue_free()
