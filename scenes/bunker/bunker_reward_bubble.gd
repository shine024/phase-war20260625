extends Control
## 余烬要塞 · 战利品收取气泡 v23.6（归仓）
## 挂机/残留掉落存入 DropManager 归仓池后，在对应房间头顶冒出可点击气泡；
## 点击 = 收取该房间全部归仓类别（走 claim 同管线入账）。
## 交互参照辐射避难所的"房间产出气泡"：收集时刻发生在场景内，不进面板。

signal collected(categories: Array)

const DT = preload("res://resources/design_tokens.gd")

## 类别 → 显示名 / 主题色（与 drop_manager.escrow_category_for_type 的类别对齐）
## v23.6.1：与 DT 精确同值的（青/紫）收口 token；无对应 token 的语义色保留本地常量
const CATEGORY_INFO := {
	"material": {"name": "物资", "color": Color(1.0, 0.72, 0.32)},
	"card": {"name": "战利品", "color": DT.COLOR_ACCENT_CYAN},
	"lore": {"name": "情报", "color": DT.COLOR_ACCENT_PURPLE},
	"stat_boost": {"name": "强化", "color": Color(0.30, 0.90, 0.55)},
	"mod_blueprint": {"name": "图纸", "color": Color(0.40, 0.65, 1.0)},
}

const _BUBBLE_SIZE := 62.0
const _BG := Color(0.04, 0.07, 0.11, 0.95)

var _categories: Array = []
var _count: int = 0
var _accent: Color = Color(1.0, 0.72, 0.32)
var _panel: Panel
var _count_label: Label
var _cat_label: Label
var _bob_tween: Tween
var _base_pos: Vector2

## categories: 该气泡承载的归仓类别（同房间多类别合一泡）；count: 总件数
func setup(categories: Array, count: int, room_rect: Rect2, tooltip: String) -> void:
	_categories = categories.duplicate()
	_count = count
	# 主类别（列表首个）定主题色
	var key := String(_categories[0]) if not _categories.is_empty() else ""
	_accent = CATEGORY_INFO.get(key, {"color": Color(1.0, 0.72, 0.32)})["color"]

	# 定位：骑在房间底边中央（读作"战利品从房间里冒出来"）。
	# v23.6.1：底排房间房底 y≈699，直接骑边会越出 720 画布 15px——钳回屏内贴房底内缘悬浮。
	var center_x: float = room_rect.get_center().x
	var bottom_y: float = room_rect.end.y
	_base_pos = Vector2(center_x - _BUBBLE_SIZE * 0.5, bottom_y - _BUBBLE_SIZE * 0.42)
	_base_pos.y = minf(_base_pos.y, 720.0 - _BUBBLE_SIZE - 2.0)
	_base_pos.x = clampf(_base_pos.x, 2.0, 1280.0 - _BUBBLE_SIZE - 2.0)
	position = _base_pos
	size = Vector2(_BUBBLE_SIZE, _BUBBLE_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = tooltip

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_theme_stylebox_override("panel", _make_style(_accent, 2.0))
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)

	_count_label = Label.new()
	_count_label.text = "×%d" % _count
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	_count_label.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_count_label)

	_cat_label = Label.new()
	_cat_label.text = _category_names_text()
	_cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# v23.6.1：类别名是中文，按字号铁律 ≥12（10px 档仅限纯数字/英文角标）
	_cat_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_cat_label.add_theme_color_override("font_color", _accent)
	_cat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_cat_label)

	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	gui_input.connect(_on_gui_input)
	_start_bob()

func _category_names_text() -> String:
	var names: Array[String] = []
	for cat in _categories:
		var info: Dictionary = CATEGORY_INFO.get(String(cat), {})
		if info.has("name"):
			names.append(String(info["name"]))
	return "·".join(names) if not names.is_empty() else "待收"

func _make_style(accent: Color, border_w: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = _BG
	sb.border_color = accent
	sb.set_border_width_all(int(border_w))
	sb.set_corner_radius_all(int(_BUBBLE_SIZE * 0.5))
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
	sb.shadow_size = 8
	return sb

func _set_hover(on: bool) -> void:
	if _panel == null:
		return
	_panel.add_theme_stylebox_override("panel", _make_style(_accent, 3.0 if on else 2.0))
	_count_label.add_theme_color_override("font_color", Color.WHITE if on else DT.COLOR_TEXT_BRIGHT)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		collected.emit(_categories.duplicate())

## 悬浮呼吸（±3px 正弦；动效减弱选项下静止）
func _start_bob() -> void:
	if DT.is_motion_reduce():
		return
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(self, "position:y", _base_pos.y - 3.0, 0.9)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(self, "position:y", _base_pos.y, 0.9)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _exit_tree() -> void:
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()
