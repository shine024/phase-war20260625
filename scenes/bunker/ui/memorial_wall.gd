extends Control
## 余烬要塞 P3 · 纪念墙（荣誉陈列室嵌入面板）
## 10×3 灯阵：纯手工定位（不依赖容器布局），确保全显。
## 点击亮灯显示英雄名；closed 信号对接嵌入包装层。

signal closed

const DT = preload("res://resources/design_tokens.gd")
const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")

const COL_LIT := Color(1.0, 0.82, 0.45)
const COL_LIT_GLOW := Color(1.0, 0.72, 0.3, 0.30)
const COL_DARK := Color(0.16, 0.17, 0.20)
const COL_DARK_RING := Color(0.28, 0.28, 0.33)

const GRID_COLS := 10
const GRID_ROWS := 3
const LAMP_SIZE := Vector2(60, 60)
const LAMP_H_SEP := 12
const LAMP_V_SEP := 16
const PAD_LEFT := 24.0

var _lamp_controls: Array[Control] = []
var _lamp_masters: Array = []
var _name_label: Label
var _count_label: Label
var _pulse_tween: Tween
var _host: Control   # 灯阵宿主（自绘），尺寸在 _layout_lamps() 时读取

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_masters()
	_build()

func _load_masters() -> void:
	_lamp_masters.clear()
	for era in range(5):
		for m in EnemyPhaseMasters.get_era_masters(era):
			_lamp_masters.append({
				"id": str(m.get("id", "")),
				"name": str(m.get("name", "？？？")),
				"title": str(m.get("title", "")),
			})
	_lamp_masters.sort_custom(func(a, b): return a["id"] < b["id"])

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 600)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.055, 0.09, 0.99)
	sb.border_color = Color(1.0, 0.82, 0.45, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(DT.CORNER_RADIUS)
	sb.set_content_margin_all(DT.PADDING_LARGE)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(outer)

	# 标题行
	var title_row := HBoxContainer.new()
	outer.add_child(title_row)
	var title := Label.new()
	title.text = "纪念墙"
	title.add_theme_font_size_override("font_size", DT.FONT_SIZE_TITLE - 6)
	title.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	_count_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	title_row.add_child(_count_label)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(func(): closed.emit())
	title_row.add_child(close_btn)

	var hint := Label.new()
	hint.text = "每一盏灯，都是一个名字。——击败驻守的相位师，把他们的遗物带回来。"
	hint.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	hint.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	outer.add_child(hint)

	# ── 灯阵宿主（自绘控制）：手动计算 10×3 网格位置 ──
	_host = Control.new()
	_host.custom_minimum_size = Vector2(800, 240)
	_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.draw.connect(_on_host_draw)   # 重绘所有灯
	outer.add_child(_host)

	for i in range(_lamp_masters.size()):
		var lamp := Control.new()
		lamp.custom_minimum_size = LAMP_SIZE
		lamp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lamp.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx := i
		lamp.draw.connect(func(): _draw_lamp(lamp, idx))
		lamp.gui_input.connect(_on_lamp_input.bind(idx))
		_host.add_child(lamp)
		_lamp_controls.append(lamp)
	# 延迟一帧：等 _host.size 稳定后居中布局
	call_deferred("_layout_lamps")

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_LARGE)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	_name_label.text = " "
	outer.add_child(_name_label)

	_start_pulse()
	refresh()

## 定位 10×3 灯阵（在 _host 尺寸稳定后调用）
func _layout_lamps() -> void:
	if _lamp_controls.is_empty() or _host == null:
		return
	var hw := _host.size.x
	if hw <= 0:
		return
	var cols := GRID_COLS
	var cell_w := LAMP_SIZE.x + LAMP_H_SEP
	var cell_h := LAMP_SIZE.y + LAMP_V_SEP
	var total_w := cols * cell_w - LAMP_H_SEP
	var gap_x := (hw - total_w) * 0.5
	var pad_y := 8.0
	for i in range(_lamp_controls.size()):
		var col_i := i % cols
		var row_i := i / cols
		var lamp := _lamp_controls[i]
		lamp.position = Vector2(PAD_LEFT + gap_x + col_i * cell_w, pad_y + row_i * cell_h)
		lamp.size = LAMP_SIZE

## 宿主自绘：背景深槽
func _on_host_draw() -> void:
	if _host == null:
		return
	_host.draw_rect(Rect2(Vector2.ZERO, _host.size), Color(0.04, 0.045, 0.07), true)

func _is_lit(idx: int) -> bool:
	var mgr: Node = get_node_or_null("/root/BunkerManager")
	if mgr == null or idx >= _lamp_masters.size():
		return false
	return mgr.has_hero_fragment(_lamp_masters[idx]["id"])

func _draw_lamp(lamp: Control, idx: int) -> void:
	var c := lamp.size * 0.5
	if _is_lit(idx):
		lamp.draw_circle(c, 22.0, COL_LIT_GLOW)
		lamp.draw_circle(c, 7.0, COL_LIT)
	else:
		lamp.draw_arc(c, 7.0, 0, TAU, 16, COL_DARK_RING, 1.5)
		lamp.draw_circle(c, 5.0, COL_DARK)

func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_method(func(v: float):
		for i in range(_lamp_controls.size()):
			_lamp_controls[i].modulate.a = 0.86 + 0.14 * v if _is_lit(i) else 1.0,
		0.0, 1.0, 2.0)
	_pulse_tween.tween_method(func(v: float):
		for i in range(_lamp_controls.size()):
			_lamp_controls[i].modulate.a = 1.0 - 0.14 * v if _is_lit(i) else 1.0,
		0.0, 1.0, 2.0)

func _on_lamp_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_lit(idx) and idx < _lamp_masters.size():
			var m: Dictionary = _lamp_masters[idx]
			_name_label.text = "%s —— %s" % [m["name"], m["title"]]
		else:
			_name_label.text = "（尚未点亮）"

func refresh() -> void:
	var lit := 0
	for i in range(_lamp_controls.size()):
		if _is_lit(i):
			lit += 1
	_count_label.text = "%d / 30" % lit
	for lamp in _lamp_controls:
		lamp.queue_redraw()
