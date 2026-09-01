extends Control
class_name AFKLevelSelector
## 关卡选择器弹窗 — 供 AFKPanel 调用
## 显示 1~100 关卡按钮，点击选中后回调

signal level_selected(level: int)
signal cancelled

const DT = preload("res://resources/design_tokens.gd")   # v23.6.1 字号归档

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: Panel = $Panel
@onready var title: Label = $Panel/MarginContainer/VBox/Title
@onready var search_edit: LineEdit = $Panel/MarginContainer/VBox/SearchRow/SearchEdit
@onready var level_grid: GridContainer = $Panel/MarginContainer/VBox/LevelList/LevelGrid
@onready var cancel_btn: Button = $Panel/MarginContainer/VBox/HBox/CancelBtn
@onready var confirm_btn: Button = $Panel/MarginContainer/VBox/HBox/ConfirmBtn

var _selected_level: int = 0
var _all_buttons: Array[Button] = []
var _highlight_color := DT.COLOR_ACCENT_MINT
var _normal_color := Color(0.5, 0.5, 0.6, 0.8)
var _selected_bg := Color(0, 0.18, 0.32, 0.95)
var _normal_bg := Color(0.06, 0.1, 0.18, 0.85)
# 三态样式：已通关（绿 ✓）/ 已解锁未通关（蓝）/ 未解锁（灰、禁点）
var _cleared_color := Color(0.42, 0.92, 0.6, 1.0)
var _cleared_bg := Color(0.05, 0.17, 0.1, 0.92)
var _cleared_border := Color(0.25, 0.8, 0.5, 0.55)
var _cleared_hover_bg := Color(0.08, 0.22, 0.13, 0.95)
var _locked_color := Color(0.34, 0.36, 0.42, 0.55)
var _locked_bg := Color(0.03, 0.05, 0.08, 0.55)
var _locked_border := Color(0.12, 0.14, 0.2, 0.35)


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
		# 裸关卡号存 meta：已通关按钮文本带 ✓ 前缀，搜索/比较一律读 meta 不读 text
		btn.set_meta("level", i)
		btn.custom_minimum_size = Vector2(36, 32)
		btn.size_flags_horizontal = Control.SIZE_FILL
		btn.size_flags_vertical = Control.SIZE_FILL
		btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		btn.pressed.connect(func(): _select_level(i, btn))
		level_grid.add_child(btn)
		_all_buttons.append(btn)


func _select_level(level: int, _btn: Button) -> void:
	_selected_level = level
	_apply_level_states()


## 按 LevelProgressManager 刷新全部按钮的三态外观（已通关/已解锁/未解锁）。
## 每次打开选择器与每次点选时重刷——进度可能在两次打开之间推进。
## LevelProgressManager 不可用（异常环境）时退化为全可选的旧样式。
func _apply_level_states() -> void:
	var lp := get_node_or_null("/root/LevelProgressManager")
	for i in range(_all_buttons.size()):
		var level: int = i + 1
		var unlocked := true
		var cleared := false
		var stars := 0
		if lp != null:
			if lp.has_method("is_level_unlocked"):
				unlocked = bool(lp.is_level_unlocked(level))
			if lp.has_method("get_level_stars"):
				stars = int(lp.get_level_stars(level))
			# 通关判定双兜底：first_completion 记录 或 星级>0（胜利但 victory_stars 缺省 0 的场次）
			if lp.has_method("is_first_completion"):
				cleared = stars > 0 or not bool(lp.is_first_completion(level))
			else:
				cleared = stars > 0
		_style_level_button(_all_buttons[i], level, unlocked, cleared, stars)


func _style_level_button(btn: Button, level: int, unlocked: bool, cleared: bool, stars: int) -> void:
	var selected: bool = (level == _selected_level)
	var font_color: Color = _normal_color
	var bg: Color = _normal_bg
	var border: Color = Color(0.2, 0.45, 0.75, 0.3)
	var hover_bg: Color = Color(0.08, 0.16, 0.28, 0.95)
	var text := str(level)
	var tip := ""
	if not unlocked:
		btn.disabled = true
		font_color = _locked_color
		bg = _locked_bg
		border = _locked_border
		tip = "第 %d 关 · 未解锁（通关前一关后解锁）" % level
	elif cleared:
		btn.disabled = false
		font_color = _cleared_color
		bg = _cleared_bg
		border = _cleared_border
		hover_bg = _cleared_hover_bg
		text = "✓%d" % level
		tip = "第 %d 关 · 已通关" % level
		if stars > 0:
			tip += " " + "★".repeat(clampi(stars, 1, 3))
	else:
		btn.disabled = false
		tip = "第 %d 关 · 已解锁 · 未通关" % level
	if selected:
		font_color = _highlight_color
		border = _highlight_color
	btn.text = text
	btn.tooltip_text = tip
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_disabled_color", font_color)
	btn.add_theme_color_override("font_hover_color", _highlight_color if unlocked else font_color)
	btn.add_theme_color_override("font_pressed_color", _highlight_color if unlocked else font_color)
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		match state_name:
			"hover":
				style.bg_color = hover_bg
				style.border_color = _highlight_color if unlocked else border
				style.set_border_width_all(1)
			"pressed":
				style.bg_color = _selected_bg
				style.border_color = _highlight_color if unlocked else border
				style.set_border_width_all(2)
			_:
				style.bg_color = bg
				style.border_color = border
				style.set_border_width_all(2 if selected else 1)
		btn.add_theme_stylebox_override(state_name, style)


func show_selector(parent: Control, slot_idx: int = 0) -> void:
	"""显示选择器"""
	visible = true
	backdrop.visible = true
	panel.visible = true
	_selected_level = 0
	# 刷新通关/解锁三态（进度可能在两次打开之间推进）+ 恢复可见性（防上次搜索过滤残留）
	_apply_level_states()
	for b in _all_buttons:
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
	# 已通关按钮文本带 ✓ 前缀，比较一律读 meta 里的裸关卡号
	# 注意：GDScript 没有 try/except，int() 失败会返回 0 而非抛异常，故用 is_valid_int 判断
	if query.is_valid_int():
		for b in _all_buttons:
			b.visible = (str(int(b.get_meta("level", 0))) == query)
	else:
		for b in _all_buttons:
			b.visible = str(int(b.get_meta("level", 0))).contains(query)


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
			# P0: 不 consume 会让 main._close_top_overlay 再关一层（ESC 一次关两层）
			get_viewport().set_input_as_handled()
