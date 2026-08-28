extends Control
## 余烬要塞 v22 · 纪念墙（纪念碑墙/荣誉陈列室嵌入面板）
## 30 盏灯 = 30 位牺牲相位师。击败驻守相位师带回遗物 → 灯亮，点击读名。
## v22：锚点修正（anchors+offsets，修入树后锚点被抵消导致出屏）；
##       面板框架/按钮走 PanelStyles 工厂 + 灯阵 GridContainer 化 + 逐灯 tooltip。

signal closed

const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")

const ACCENT := Color(1.0, 0.82, 0.45)          # 烛光琥珀
const COL_LIT := Color(1.0, 0.84, 0.5)
const COL_LIT_GLOW := Color(1.0, 0.72, 0.3, 0.28)
const COL_DARK := Color(0.16, 0.17, 0.20)
const COL_DARK_RING := Color(0.30, 0.30, 0.36)

const GRID_COLS := 10
const GRID_ROWS := 3
const LAMP_CELL := Vector2(58, 58)

var _lamp_controls: Array[Control] = []
var _lamp_masters: Array = []
var _name_label: Label
var _count_label: Label
var _pulse_tween: Tween

func _ready() -> void:
	# ⚠️ 入树后设锚点必须连偏移一起归零（v22 全弹层统一修正，防出屏）
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 0)
	panel.add_theme_stylebox_override("panel", PanelStyles.make_panel_frame(ACCENT))
	center.add_child(panel)

	var inner := PanelContainer.new()
	var inner_sb := StyleBoxFlat.new()
	inner_sb.bg_color = Color(0.05, 0.055, 0.09, 0.94)
	inner_sb.set_corner_radius_all(10)
	inner_sb.set_content_margin_all(20.0)
	inner.add_theme_stylebox_override("panel", inner_sb)
	panel.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	inner.add_child(vbox)

	# 标题行：发光竖条 + 标题 + 计数芯片 + 关闭
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	vbox.add_child(title_row)

	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(4, 0)
	bar.size_flags_vertical = Control.SIZE_FILL
	bar.add_theme_stylebox_override("panel", PanelStyles.make_title_accent_bar(ACCENT))
	title_row.add_child(bar)

	var title := Label.new()
	title.text = "纪念墙"
	title.add_theme_font_size_override("font_size", DT.FONT_SIZE_LARGE)
	title.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_count_label.add_theme_color_override("font_color", ACCENT)
	var chip_sb := StyleBoxFlat.new()
	chip_sb.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.12)
	chip_sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.45)
	chip_sb.set_border_width_all(1)
	chip_sb.set_corner_radius_all(4)
	chip_sb.content_margin_left = 8.0
	chip_sb.content_margin_right = 8.0
	chip_sb.content_margin_top = 3.0
	chip_sb.content_margin_bottom = 3.0
	_count_label.add_theme_stylebox_override("normal", chip_sb)
	title_row.add_child(_count_label)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var styles: Dictionary = PanelStyles.make_button_styles(ACCENT, "ghost")
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		close_btn.add_theme_stylebox_override(key, styles[key])
	close_btn.pressed.connect(func(): SignalBus.play_sound.emit("button"); closed.emit())
	title_row.add_child(close_btn)

	# 引文提示
	var hint := Label.new()
	hint.text = "每一盏灯，都是一个名字。——击败驻守的相位师，把他们的遗物带回来。"
	hint.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	hint.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	vbox.add_child(hint)

	# 灯阵槽（深槽底 + 网格）
	var slot := PanelContainer.new()
	var slot_sb := StyleBoxFlat.new()
	slot_sb.bg_color = Color(0.035, 0.04, 0.065, 0.9)
	slot_sb.border_color = Color(1, 1, 1, 0.06)
	slot_sb.set_border_width_all(1)
	slot_sb.set_corner_radius_all(8)
	slot_sb.set_content_margin_all(14.0)
	slot.add_theme_stylebox_override("panel", slot_sb)
	vbox.add_child(slot)

	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	slot.add_child(grid)

	for i in range(_lamp_masters.size()):
		var lamp := Control.new()
		lamp.custom_minimum_size = LAMP_CELL
		lamp.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var idx := i
		var m: Dictionary = _lamp_masters[i]
		lamp.tooltip_text = "第 %02d 位 · %s" % [i + 1, m["name"]] if _is_lit(i) \
			else "第 %02d 位 · ？？？（带回遗物点亮）" % [i + 1]
		lamp.draw.connect(func(): _draw_lamp(lamp, idx))
		lamp.gui_input.connect(_on_lamp_input.bind(idx))
		grid.add_child(lamp)
		_lamp_controls.append(lamp)

	# 名字展示区（引文风）
	var quote := PanelContainer.new()
	var quote_sb := StyleBoxFlat.new()
	quote_sb.bg_color = Color(1, 1, 1, 0.04)
	quote_sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
	quote_sb.border_width_left = 2
	quote_sb.set_corner_radius_all(4)
	quote_sb.content_margin_left = 12.0
	quote_sb.content_margin_right = 10.0
	quote_sb.content_margin_top = 8.0
	quote_sb.content_margin_bottom = 8.0
	quote.add_theme_stylebox_override("panel", quote_sb)
	vbox.add_child(quote)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	_name_label.text = "（点击亮起的灯，读一个名字）"
	_name_label.custom_minimum_size = Vector2(0, 26)
	quote.add_child(_name_label)

	_start_pulse()
	refresh()

func _is_lit(idx: int) -> bool:
	var mgr: Node = get_node_or_null("/root/BunkerManager")
	if mgr == null or idx >= _lamp_masters.size():
		return false
	return mgr.has_hero_fragment(_lamp_masters[idx]["id"])

func _draw_lamp(lamp: Control, idx: int) -> void:
	var c := lamp.size * 0.5
	if _is_lit(idx):
		# 烛心：三层光晕 + 亮核 + 底座刻线
		lamp.draw_circle(c, 24.0, COL_LIT_GLOW)
		lamp.draw_circle(c, 12.0, Color(1.0, 0.78, 0.42, 0.32))
		lamp.draw_circle(c, 5.5, COL_LIT)
		lamp.draw_rect(Rect2(c.x - 9.0, c.y + 20.0, 18.0, 2.0),
			Color(1.0, 0.82, 0.45, 0.35))
	else:
		# 熄灯：暗环 + 空心 + 微弱基座
		lamp.draw_arc(c, 8.0, 0, TAU, 20, COL_DARK_RING, 1.5)
		lamp.draw_circle(c, 5.5, COL_DARK)
		lamp.draw_rect(Rect2(c.x - 9.0, c.y + 20.0, 18.0, 2.0),
			Color(1, 1, 1, 0.08))

func _start_pulse() -> void:
	if DT.is_motion_reduce():
		return
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
	for i in range(_lamp_controls.size()):
		var m: Dictionary = _lamp_masters[i]
		_lamp_controls[i].tooltip_text = ("第 %02d 位 · %s" % [i + 1, m["name"]]) if _is_lit(i) \
			else "第 %02d 位 · ？？？（带回遗物点亮）" % [i + 1]
		_lamp_controls[i].queue_redraw()
