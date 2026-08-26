extends Panel
## 余烬要塞 · 房间覆盖层 v21 P2
## 基于静态背景图（bunker_background.png），房间以半透明遮罩叠加显示状态。
## 状态视觉：
##   废弃/锁定 → 暗色遮罩 + 🔒 废弃标签
##   修复中    → 橙色呼吸边框 + 底部进度条 + 🔧 修复中
##   可用      → 几乎无遮罩，保留背景图的家具细节
## 点击穿透到 bunker_main._on_room_clicked(room_id)

signal room_clicked(room_id: String)

const BunkerRoomDefs = preload("res://data/bunker_room_defs.gd")
const DT = preload("res://resources/design_tokens.gd")

const COL_LOCKED_TINT  := Color(0.04, 0.04, 0.06, 0.72)   # 废弃：深色遮罩
const COL_REPAIRING_BG := Color(0.14, 0.11, 0.07, 0.88)   # 修复中：暖暗底
const COL_ACTIVE_TINT  := Color(0.0, 0.0, 0.0, 0.0)       # 可用：几乎无遮罩

var _room_id := ""
var _bg: ColorRect
var _state_label: Label
var _progress_bg: ColorRect
var _progress_fill: ColorRect
var _breath_overlay: ColorRect
var _breath_tween: Tween

func setup(room_id: String, x: float, y: float, w: float, h: float) -> void:
	_room_id = room_id
	set_anchors_preset(Control.PRESET_NONE)
	position = Vector2(x, y)
	size = Vector2(w, h)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

func _build() -> void:
	# 遮罩背景（覆盖状态）
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# 状态文字（左上）
	_state_label = Label.new()
	_state_label.anchor_left = 0.04
	_state_label.anchor_right = 0.72
	_state_label.anchor_top = 0.06
	_state_label.anchor_bottom = 0.34
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_state_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	_state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_state_label)

	# 进度条（底部，仅修复中显示）
	_progress_bg = ColorRect.new()
	_progress_bg.anchor_left = 0.05
	_progress_bg.anchor_right = 0.95
	_progress_bg.anchor_top = 0.92
	_progress_bg.anchor_bottom = 0.97
	_progress_bg.color = Color(0, 0, 0, 0.6)
	_progress_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bg.visible = false
	add_child(_progress_bg)

	_progress_fill = ColorRect.new()
	_progress_fill.anchor_left = 0.05
	_progress_fill.anchor_top = 0.92
	_progress_fill.anchor_bottom = 0.97
	_progress_fill.color = Color(0.9, 0.6, 0.15)
	_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_fill.visible = false
	add_child(_progress_fill)

	# 呼吸覆层（修复中橙色脉动）
	_breath_overlay = ColorRect.new()
	_breath_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_breath_overlay.color = Color(0.9, 0.6, 0.1, 0.0)
	_breath_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_breath_overlay.visible = false
	add_child(_breath_overlay)

func refresh(state: int, _level: int, progress: float, frozen: bool) -> void:
	var sb := StyleBoxFlat.new()
	match state:
		BunkerRoomDefs.STATE_LOCKED:
			_bg.color = COL_LOCKED_TINT
			sb.border_color = Color(0.16, 0.14, 0.12, 0.5)
			sb.set_border_width_all(1)
			_state_label.text = "🔒 废弃"
			_state_label.add_theme_color_override("font_color", Color(0.4, 0.38, 0.33))
			_progress_bg.visible = false
			_progress_fill.visible = false
			_breath_overlay.visible = false
			_stop_breath()
		BunkerRoomDefs.STATE_REPAIRING:
			_bg.color = COL_REPAIRING_BG
			sb.border_color = Color(0.9, 0.6, 0.1, 0.9)
			sb.set_border_width_all(1)
			_state_label.text = "🔧 修复中" if frozen else "🔧 %d%%" % int(round(progress * 100.0))
			_state_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.1))
			_progress_bg.visible = true
			_progress_fill.visible = true
			_breath_overlay.visible = true
			_layout_progress(progress)
			_start_breath()
		_:  # STATE_ACTIVE
			_bg.color = COL_ACTIVE_TINT
			sb.border_color = Color(0.72, 0.55, 0.36, 0.6)
			sb.set_border_width_all(1)
			_state_label.text = ""
			_progress_bg.visible = false
			_progress_fill.visible = false
			_breath_overlay.visible = false
			_stop_breath()
	add_theme_stylebox_override("panel", sb)

func _layout_progress(progress: float) -> void:
	var frac := clampf(progress, 0.0, 1.0)
	_progress_fill.anchor_left = 0.05
	_progress_fill.anchor_right = 0.05 + frac * 0.90

func _start_breath() -> void:
	_stop_breath()
	_breath_tween = create_tween().set_loops()
	_breath_tween.tween_property(_breath_overlay, "color:a", 0.10, 0.7)
	_breath_tween.tween_property(_breath_overlay, "color:a", 0.0, 0.7)

func _stop_breath() -> void:
	if _breath_tween and _breath_tween.is_valid():
		_breath_tween.kill()
	_breath_tween = null
	_breath_overlay.color.a = 0.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		room_clicked.emit(_room_id)

func _exit_tree() -> void:
	_stop_breath()
