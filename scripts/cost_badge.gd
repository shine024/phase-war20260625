## v7.x 费用角标：用 _draw 直接画费用文字（绕过 PanelContainer 对子节点的布局强制）。
## 关键：set_as_top_level(true) 脱离父节点坐标系，自己管理全局位置，
## Container 无法强制布局它。位置通过 follow_host() 跟随宿主卡牌的右上角。
extends Control

const DT = preload("res://resources/design_tokens.gd")

var energy_value: int = 0:
	set(v):
		energy_value = v
		_text = "%d⚡" % v
		_text_size_known = false
		_rect_known = false
		queue_redraw()

## BU-1：能量不足警示色——true 时费用文字由金色转红（槽位可负担状态机驱动）
var warn: bool = false:
	set(v):
		if warn == v:
			return
		warn = v
		queue_redraw()

var _text: String = ""
var _host: Control = null
## 锚定角：right=true 右上角，false 左上角
var _anchor_right: bool = false
## v9.3：_draw 圆角背景 stylebox（懒加载缓存，避免每帧 new）
var _bg_style: StyleBoxFlat = null
## v9.x（3b 性能批次）：文本尺寸缓存——get_string_size 只在文本变化时算一次，
## 不再每帧测量；宿主矩形快照——宿主未移动时跳过祖先 clip 链遍历（背包开
## 几十张卡时 = 每帧几十次字体测量 + 几十次祖先遍历的直接削减）。
var _text_size := Vector2.ZERO
var _text_size_known := false
var _last_host_rect := Rect2()
var _rect_known := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	set_as_top_level(true)

func follow_host(host: Control, anchor_right: bool = false) -> void:
	_host = host
	_anchor_right = anchor_right
	_rect_known = false
	# 首帧立即定位（_process 会在后续帧持续校正 + 裁剪判断）
	global_position = _compute_badge_global_position()

func _process(_delta: float) -> void:
	# 跟随宿主位置（宿主可能移动/重布局）
	if _host == null or not is_instance_valid(_host):
		visible = false
		return
	# v9.x 脏检查：宿主矩形未变 + 文本未变 → 位置/可见性维持现状，跳过全部重算
	var host_rect: Rect2 = _host.get_global_rect()
	if _rect_known and host_rect == _last_host_rect:
		return
	_rect_known = true
	_last_host_rect = host_rect
	# v9.3 修复：set_as_top_level 不受父级 clip 影响，必须手动判断角标的实际渲染位置
	# 是否落在最近 clip 祖先（背包 ScrollContainer）的可视矩形内。
	# 旧实现用 host_rect 与 clip_rect 的交集判断——交集只要有 1 像素重叠就为 false，
	# 导致卡牌大部分滚出、仅剩底边在可视区时，顶部费用角标仍被画在面板错误位置。
	var badge_target_pos := _compute_badge_global_position()
	if _is_point_clipped_away(badge_target_pos):
		visible = false
		return
	visible = true
	global_position = badge_target_pos


func _ensure_text_size() -> Vector2:
	if not _text_size_known:
		var font := get_theme_default_font()
		_text_size = font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10) if font != null else Vector2(22, 12)
		_text_size_known = true
	return _text_size

## v9.3 修复：计算角标应处的全局位置（不写入 global_position，仅用于裁剪判断）
func _compute_badge_global_position() -> Vector2:
	if _host == null or not is_instance_valid(_host):
		return Vector2.ZERO
	var host_rect: Rect2 = _host.get_global_rect()
	var ts: Vector2 = _ensure_text_size()
	if size != Vector2(ts.x + 4.0, ts.y + 2.0):
		size = Vector2(ts.x + 4.0, ts.y + 2.0)
	var px: float
	if _anchor_right:
		px = host_rect.end.x - size.x - 6.0
	else:
		px = host_rect.position.x + 6.0
	var py: float = host_rect.position.y + 4.0
	return Vector2(px, py)


## v9.3 修复：判断角标目标位置是否被最近 clip 祖先裁出可视区。
## 取角标矩形（含其自身尺寸），只要它不完全在最近 clip 祖先的可见矩形内，即视为被裁掉。
func _is_point_clipped_away(badge_pos: Vector2) -> bool:
	if _host == null or not is_instance_valid(_host):
		return true
	var badge_rect := Rect2(badge_pos, size)
	var p: Node = _host.get_parent()
	while p != null:
		if p is Control and (p as Control).clip_contents:
			var clip_rect: Rect2 = (p as Control).get_global_rect()
			# 角标必须完全在 clip 矩形内，否则隐藏（避免半溢出时残留在面板边界）
			if not clip_rect.encloses(badge_rect):
				return true
		p = p.get_parent()
	return false

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
	# 深色描边 + 金黄色文字（能量不足时转 DT.COLOR_DANGER 红）
	var text_color: Color = Color(1.0, 0.85, 0.30, 1.0) if not warn else DT.COLOR_DANGER
	font.draw_string_outline(get_canvas_item(), pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 1, Color(0.0, 0.0, 0.0, 0.95))
	font.draw_string(get_canvas_item(), pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
