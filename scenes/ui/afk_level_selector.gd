extends Control
class_name AFKLevelSelector
## 关卡选择器弹窗 — 供 AFKPanel 调用
## 显示 1~100 关卡按钮，点击选中后回调

signal level_selected(level: int)
signal cancelled

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: Panel = $Panel
@onready var title: Label = $Panel/MarginContainer/VBox/Title
@onready var search_edit: LineEdit = $Panel/MarginContainer/VBox/SearchRow/SearchEdit
@onready var level_grid: GridContainer = $Panel/MarginContainer/VBox/LevelList/LevelGrid
@onready var cancel_btn: Button = $Panel/MarginContainer/VBox/HBox/CancelBtn
@onready var confirm_btn: Button = $Panel/MarginContainer/VBox/HBox/ConfirmBtn

var _selected_level: int = 0
var _all_buttons: Array[Button] = []
var _highlight_color := Color(0, 0.94, 0.7, 1.0)
var _normal_color := Color(0.5, 0.5, 0.6, 0.8)
var _selected_bg := Color(0, 0.18, 0.32, 0.95)
var _normal_bg := Color(0.06, 0.1, 0.18, 0.85)


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_build_level_buttons()
	search_edit.text_changed.connect(_on_search_changed)
	cancel_btn.pressed.connect(_on_cancel)
	confirm_btn.pressed.connect(_on_confirm)


func _build_level_buttons() -> void:
	for btn in _all_buttons:
		btn.queue_free()
	_all_buttons.clear()
	level_grid.columns = 10
	
	for i in range(1, 101):
		var btn := Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = Vector2(36, 32)
		btn.size_flags_horizontal = Control.SIZE_FILL
		btn.size_flags_vertical = Control.SIZE_FILL
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", _normal_color)
		var style := StyleBoxFlat.new()
		style.bg_color = _normal_bg
		style.border_color = Color(0.2, 0.45, 0.75, 0.3)
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", style)
		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color(0.08, 0.16, 0.28, 0.95)
		hover_style.border_color = _highlight_color
		hover_style.set_border_width_all(1)
		hover_style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("hover", hover_style)
		var pressed_style := StyleBoxFlat.new()
		pressed_style.bg_color = _selected_bg
		pressed_style.border_color = _highlight_color
		pressed_style.set_border_width_all(2)
		pressed_style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("pressed", pressed_style)
		btn.pressed.connect(func(): _select_level(i, btn))
		level_grid.add_child(btn)
		_all_buttons.append(btn)


func _select_level(level: int, _btn: Button) -> void:
	_selected_level = level
	# 重置所有按钮为默认色，再高亮选中项
	for b in _all_buttons:
		b.add_theme_color_override("font_color", _normal_color)
	var sel_idx: int = level - 1
	if sel_idx >= 0 and sel_idx < _all_buttons.size():
		_all_buttons[sel_idx].add_theme_color_override("font_color", _highlight_color)


func show_selector(parent: Control, slot_idx: int = 0) -> void:
	"""显示选择器"""
	visible = true
	backdrop.visible = true
	panel.visible = true
	_selected_level = 0
	# 清除高亮 + 恢复可见性（防止上次搜索过滤残留）
	for b in _all_buttons:
		b.add_theme_color_override("font_color", _normal_color)
		b.visible = true
	search_edit.text = ""


func hide_selector() -> void:
	visible = false
	backdrop.visible = false
	panel.visible = false


func _on_search_changed(text: String) -> void:
	var query = text.strip_edges()
	if query.is_empty():
		for b in _all_buttons:
			b.visible = true
		return
	# 纯数字 → 精确匹配该关卡号；非数字 → 模糊匹配
	# 注意：GDScript 没有 try/except，int() 失败会返回 0 而非抛异常，故用 is_valid_int 判断
	if query.is_valid_int():
		for b in _all_buttons:
			b.visible = (b.text == query)
	else:
		for b in _all_buttons:
			b.visible = b.text.contains(query)


func _on_cancel() -> void:
	cancelled.emit()
	hide_selector()


func _on_confirm() -> void:
	if _selected_level > 0:
		level_selected.emit(_selected_level)
	hide_selector()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if visible:
			_on_cancel()
