extends Control
## 余烬要塞 · 日结算面板 v21 P2
## 睡觉后弹出：新天数 / 精神恢复 / 今日完成修复 / 阶段文案。替代 P1 的纯 toast。

signal closed

const BunkerRoomDefs = preload("res://data/bunker_room_defs.gd")
const DT = preload("res://resources/design_tokens.gd")

const STAGE_LINES := {
	1: "又是重复的一天。反正……只是个梦吧。",
	2: "开始在意进度了。也许……我该认真对待这件事。",
	3: "我记得你们每一个人的名字。我不想忘记。",
	4: "所有的灯都亮着。是时候了。",
}

var _dim: ColorRect
var _title_label: Label
var _body_label: RichTextLabel
var _continue_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func _build() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.6)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 320)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.075, 0.12, 0.98)
	sb.border_color = Color(0.77, 0.58, 0.42, 0.7)   # 暖橙边——晨光语义
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(DT.CORNER_RADIUS)
	sb.set_content_margin_all(DT.PADDING_LARGE)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_TITLE - 6)
	_title_label.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	vbox.add_child(_title_label)

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = false
	_body_label.fit_content = true
	_body_label.custom_minimum_size = Vector2(0, 110)
	_body_label.add_theme_font_size_override("normal_font_size", DT.FONT_SIZE_BODY)
	_body_label.add_theme_color_override("default_color", DT.COLOR_TEXT_DIM)
	vbox.add_child(_body_label)

	_continue_btn = Button.new()
	_continue_btn.text = "迎接新的一天"
	_continue_btn.custom_minimum_size = Vector2(0, 42)
	_continue_btn.pressed.connect(func(): closed.emit())
	vbox.add_child(_continue_btn)

## summary 来自 BunkerManager.sleep() 的返回值
func open(summary: Dictionary) -> void:
	var day: int = int(summary.get("day", 1))
	var sb_: float = float(summary.get("sanity_before", 100.0))
	var sa: float = float(summary.get("sanity_after", 100.0))
	var completed: Array = summary.get("completed_today", [])
	var stage: int = int(summary.get("stage", 1))

	_title_label.text = "—— 第 %d 天 ——" % day

	var lines: Array[String] = []
	lines.append("睡了一觉。精神值 %d → %d。" % [int(round(sb_)), int(round(sa))])
	if completed.is_empty():
		lines.append("昨天没有房间完工。黑暗还在等灯。")
	else:
		var names: Array[String] = []
		for rid in completed:
			var def := BunkerRoomDefs.get_room(str(rid))
			names.append(str(def.get("name", rid)))
		lines.append("昨天完工：%s。" % "、".join(names))
	lines.append("")
	lines.append(STAGE_LINES.get(stage, ""))
	_body_label.text = "\n".join(lines)

	visible = true

func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()
