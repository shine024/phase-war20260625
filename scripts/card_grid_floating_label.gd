extends Node2D
class_name CardGridFloatingLabel
## v7.x 战场视觉反馈：单位卡顶/卡底漂浮文字（HP数值/等级徽章/buff标签）
##
## 为什么不用 Label（Control）？
## Label 作为 Control 挂在 Node2D（CharacterBody2D 单位）下时不会自动布局，
## size 默认 (0,0)，文字完全不渲染。即使显式设 size/custom_minimum_size，
## 在 Node2D 父节点下布局系统也不会触发更新。
##
## 本类用 Node2D + _draw() 直接绘制文字，确定性可见，不依赖 Control 布局。
## 参考实现：CardGridRankStrip（同样 Node2D + _draw 自绘图标）。

var _text: String = ""
var _font_size: int = 11
var _color: Color = Color.WHITE
var _outline_color: Color = Color(0, 0, 0, 0.85)
var _outline_size: int = 3
var _h_align: int = HORIZONTAL_ALIGNMENT_CENTER
var _bg_color: Color = Color(0, 0, 0, 0)  # 透明=不画背景
var _bg_padding: float = 2.0
var _cached_font: Font = null
var _text_width: float = 0.0
var _text_height: float = 0.0


func _ready() -> void:
	z_index = 16
	_cached_font = _get_default_font()
	_recompute_text_size()


func set_text(p_text: String) -> void:
	if _text == p_text:
		return
	_text = p_text
	_recompute_text_size()
	queue_redraw()


func set_style(
	p_font_size: int,
	p_color: Color,
	p_outline_color: Color = Color(0, 0, 0, 0.85),
	p_outline_size: int = 3,
	p_h_align: int = HORIZONTAL_ALIGNMENT_CENTER
) -> void:
	_font_size = p_font_size
	_color = p_color
	_outline_color = p_outline_color
	_outline_size = p_outline_size
	_h_align = p_h_align
	_recompute_text_size()
	queue_redraw()


## 背景色（可选）：半透明圆角矩形包裹文字。透明 alpha=0 则不画
func set_background(p_bg_color: Color, p_padding: float = 2.0) -> void:
	_bg_color = p_bg_color
	_bg_padding = p_padding
	queue_redraw()


func _recompute_text_size() -> void:
	if _cached_font == null:
		_cached_font = _get_default_font()
	if _cached_font == null:
		return
	_text_width = _cached_font.get_string_size(
		_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size
	).x
	_text_height = float(_font_size)


## Node2D 没有 get_theme_default_font()（那是 Control 方法）
## 通过 ThemeDB 取全局默认字体
static func _get_default_font() -> Font:
	var theme: Theme = ThemeDB.get_project_theme()
	if theme != null:
		var f: Font = theme.default_font
		if f != null:
			return f
	return ThemeDB.get_fallback_font() as Font


func _draw() -> void:
	if _text.is_empty() or _cached_font == null:
		return
	# 背景圆角矩形（可选）
	if _bg_color.a > 0.01:
		var bg_rect := Rect2(
			Vector2(-_text_width * 0.5 - _bg_padding, -_text_height * 0.5 - _bg_padding * 0.5),
			Vector2(_text_width + _bg_padding * 2.0, _text_height + _bg_padding)
		)
		draw_rect(bg_rect, _bg_color, true)
	# 文字位置：Node2D 原点为锚点，水平居中（_h_align=CENTER 时文字起点 = -width/2）
	var x: float = 0.0
	match _h_align:
		HORIZONTAL_ALIGNMENT_CENTER:
			x = -_text_width * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			x = -_text_width
		# LEFT/默认：x = 0
	# draw_string 的 y 是 baseline，文字高度向下偏移 font_size 即可
	var y: float = _text_height * 0.75
	# outline（描边）：用 draw_string_outline 画粗描边底，再画主色文字
	# Godot 4 签名：draw_string_outline(font, pos, text, alignment, width, font_size, size, outline_color)
	if _outline_size > 0:
		draw_string_outline(
			_cached_font, Vector2(x, y), _text,
			_h_align, _text_width + 4.0, _font_size,
			_outline_size, _outline_color
		)
	draw_string(
		_cached_font, Vector2(x, y), _text,
		_h_align, _text_width + 4.0, _font_size, _color
	)


## 文本宽度（外部定位用）
func get_text_width() -> float:
	return _text_width


## 文本高度（外部定位用）
func get_text_height() -> float:
	return _text_height
