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
## v9.3：_draw 圆角背景 stylebox（懒加载缓存，避免每帧 new）
var _bg_style: StyleBoxFlat = null

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
	if _host == null or not is_instance_valid(_host):
		visible = false
		return
	# v9.3：宿主被最近的 clip 祖先（如背包 ScrollContainer）裁出可视区时隐藏——
	# set_as_top_level 不受父级 clip 影响，否则滚动时费用数字会残留在面板其他区域。
	if _is_host_clipped_away():
		visible = false
		return
	visible = true
	_update_position()


## v9.3：遍历宿主祖先，若最近的 clip_contents=true 祖先的可见矩形不含宿主，则宿主已滚出可视区。
func _is_host_clipped_away() -> bool:
	if _host == null or not is_instance_valid(_host):
		return true
	var host_rect := _host.get_global_rect()
	var p: Node = _host.get_parent()
	while p != null:
		if p is Control and (p as Control).clip_contents:
			var clip_rect: Rect2 = (p as Control).get_global_rect()
			# Check if host intersects clip area - if not, host is scrolled out of view
			if not clip_rect.intersects(host_rect):
				return true
		p = p.get_parent()
	return false

func _update_position() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	var host_rect: Rect2 = _host.get_global_rect()
	var ts: Vector2 = get_theme_default_font().get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10) if get_theme_default_font() != null else Vector2(22, 12)
	size = Vector2(ts.x + 4.0, ts.y + 2.0)
	# v9.3：向内偏移（6→6 / 1→4），避开较宽的稀有度边框/发光，不被卡框盖住
	var px: float
	if _anchor_right:
		px = host_rect.end.x - size.x - 6.0
	else:
		px = host_rect.position.x + 6.0
	var py = host_rect.position.y + 4.0
	global_position = Vector2(px, py)
	
	# Additional check: ensure badge stays within safe bounds to prevent it from
	# appearing outside the backpack panel during scrolling
	# If the badge is too far from its host or outside reasonable viewport areas, hide it
	var badge_rect = Rect2(global_position, size)
	var host_min_x = min(host_rect.position.x, px)
	var host_max_x = max(host_rect.end.x, px + size.x)
	# Calculate the offset point on the host (left edge for left anchor, right edge for right anchor)
	var host_offset_x: float = 0
	if _anchor_right:
		host_offset_x = host_rect.end.x
	else:
		host_offset_x = host_rect.position.x
	# If badge is significantly separated from host (more than 50px), it's likely misplaced due to scroll/layout issues
	if abs(px - host_offset_x) > 50.0 or abs(py - host_rect.position.y) > 50.0:
		visible = false
	else:
		visible = true

func _draw() -> void:
	if _text.is_empty():
		return
	var font := get_theme_default_font()
	if font == null:
		return
	var fs: int = 10
	var ts: Vector2 = font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos: Vector2 = Vector2(2.0, 1.0 + ts.y)
	# v9.3：半透明深色圆角背景（原方形 draw_rect 不好看）
	if _bg_style == null:
		_bg_style = StyleBoxFlat.new()
		_bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
		_bg_style.set_corner_radius_all(3)
	draw_style_box(_bg_style, Rect2(1.0, 1.0, ts.x + 3.0, ts.y + 1.0))
	# 深色描边 + 金黄色文字
	font.draw_string_outline(get_canvas_item(), pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 1, Color(0.0, 0.0, 0.0, 0.95))
	font.draw_string(get_canvas_item(), pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.85, 0.30, 1.0))
