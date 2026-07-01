## v7.x 费用角标：用 _draw 直接画费用文字（绕过 PanelContainer 对子节点的布局强制）。
## 关键：set_as_top_level(true) 脱离父节点坐标系，自己管理全局位置，
## Container 无法强制布局它。位置通过 follow_host() 跟随宿主卡牌的右上角。
extends Control

var energy_value: int = 0:
	set(v):
		energy_value = v
		_text = "%d⚡" % v
		queue_redraw()

var _text: String = ""
var _host: Control = null
## 锚定角：right=true 右上角，false 左上角
var _anchor_right: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	set_as_top_level(true)

func follow_host(host: Control, anchor_right: bool = false) -> void:
	_host = host
	_anchor_right = anchor_right
	_update_position()

func _process(_delta: float) -> void:
	# 跟随宿主位置（宿主可能移动/重布局）
	if _host != null and is_instance_valid(_host):
		_update_position()

func _update_position() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	var host_rect: Rect2 = _host.get_global_rect()
	var ts: Vector2 = get_theme_default_font().get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10) if get_theme_default_font() != null else Vector2(22, 12)
	size = Vector2(ts.x + 4.0, ts.y + 2.0)
	var px: float
	if _anchor_right:
		px = host_rect.end.x - size.x - 2.0
	else:
		px = host_rect.position.x + 2.0
	global_position = Vector2(px, host_rect.position.y + 1.0)

func _draw() -> void:
	if _text.is_empty():
		return
	var font := get_theme_default_font()
	if font == null:
		return
	var fs: int = 10
	var ts: Vector2 = font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos: Vector2 = Vector2(2.0, 1.0 + ts.y)
	# 半透明深色小背景增强可读性
	draw_rect(Rect2(1.0, 1.0, ts.x + 3.0, ts.y + 1.0), Color(0.0, 0.0, 0.0, 0.55), true)
	# 深色描边 + 金黄色文字
	font.draw_string_outline(get_canvas_item(), pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 1, Color(0.0, 0.0, 0.0, 0.95))
	font.draw_string(get_canvas_item(), pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.85, 0.30, 1.0))
