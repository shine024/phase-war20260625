extends Node2D
class_name CardGridNameStrip
## 格子战卡底名称条：在卡片立绘正下方绘制单位名称（我方青色 / 敌方橙红）。
## 与 CardGridRankStrip（卡顶军衔图标）对称，补齐"战场上看不出是哪个单位"的可读性缺口。

const CardGridBattleLayout = preload("res://scripts/card_grid_battle_layout.gd")

## 名称条高度（像素），与卡宽按比例缩放
const NAME_BAR_HEIGHT_FRAC: float = 0.30
## 字号占卡宽比例
const FONT_SIZE_FRAC: float = 0.20
## 名称条相对卡片底部的下移量（卡高的一半 + 少量间隙）
const OFFSET_BELOW_CARD_FRAC: float = 0.55

const COLOR_PLAYER: Color = Color(0.30, 0.92, 1.00, 1.0)
const COLOR_ENEMY: Color = Color(1.00, 0.55, 0.40, 1.0)
const COLOR_BAR_BG: Color = Color(0.04, 0.07, 0.11, 0.78)
const COLOR_BAR_BORDER: Color = Color(0.5, 0.6, 0.7, 0.55)

var _card_art_width: float = 0.0
var _card_art_height: float = 0.0
var _display_name: String = ""
var _is_player: bool = true
var _bar_rect: Rect2 = Rect2()
var _font_size: int = 11


## 重建名称条。
## card_art_width / card_art_height: 卡片立绘的实际像素尺寸（用于定位和对齐）。
func rebuild(display_name: String, is_player: bool, card_art_width: float = -1.0, card_art_height: float = -1.0) -> void:
	_display_name = display_name
	_is_player = is_player
	if card_art_width > 1.0:
		_card_art_width = card_art_width
	else:
		_card_art_width = CardGridBattleLayout.battle_card_width_px()
	if card_art_height > 1.0:
		_card_art_height = card_art_height
	else:
		# 默认卡高 = 卡宽 × 8/5（与 apply_battle_card_chrome 的 5:8 比例一致）
		_card_art_height = _card_art_width * 8.0 / 5.0
	if _display_name.is_empty():
		visible = false
		queue_redraw()
		return
	visible = true
	# 字号随卡宽缩放，但限定在合理区间
	_font_size = clampi(int(_card_art_width * FONT_SIZE_FRAC), 9, 14)
	# 名称条尺寸：与卡宽等宽，高度按比例
	# _bar_rect 从 strip 局部原点(0,0) 起算；绝对定位由宿主在外部设置 position。
	var bar_h: float = maxf(_card_art_width * NAME_BAR_HEIGHT_FRAC, 14.0)
	var bar_w: float = _card_art_width
	_bar_rect = Rect2(-bar_w * 0.5, 0.0, bar_w, bar_h)
	queue_redraw()


func _draw() -> void:
	if not visible or _display_name.is_empty():
		return
	# 背景
	draw_rect(_bar_rect, COLOR_BAR_BG, true)
	# 边框
	var border_col: Color = COLOR_PLAYER if _is_player else COLOR_ENEMY
	border_col.a = 0.7
	draw_rect(_bar_rect, border_col, false, 1.0)
	# 名称文本（居中，自适应缩放避免溢出）
	var text_col: Color = COLOR_PLAYER if _is_player else COLOR_ENEMY
	var truncated: String = _fit_name(_display_name, _bar_rect.size.x - 4.0)
	# Node2D 无 get_theme_default_font()，使用 ThemeDB 回退字体
	var font: Font = ThemeDB.get_fallback_font()
	var text_size: Vector2 = font.get_string_size(truncated, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size)
	var text_pos: Vector2 = Vector2(
		_bar_rect.position.x + (_bar_rect.size.x - text_size.x) * 0.5,
		_bar_rect.position.y + (_bar_rect.size.y + text_size.y) * 0.5 - 2.0
	)
	# 描边（增强对比）：签名 draw_string_outline(font, pos, text, alignment, width, font_size, outline_size, modulate)
	draw_string_outline(font, text_pos, truncated, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, 2, Color(0, 0, 0, 0.85))
	draw_string(font, text_pos, truncated, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, text_col)


## 按可用宽度截断名称（超出加省略号），避免长名溢出名称条
func _fit_name(name_str: String, max_width: float) -> String:
	var font: Font = ThemeDB.get_fallback_font()
	if font == null:
		return name_str
	var full_w: float = font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	if full_w <= max_width:
		return name_str
	# 二分截断
	var lo: int = 1
	var hi: int = name_str.length()
	var best: String = name_str.left(1)
	while lo <= hi:
		var mid: int = (lo + hi) / 2
		var candidate: String = name_str.left(mid) + "…"
		var w: float = font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
		if w <= max_width:
			best = candidate
			lo = mid + 1
		else:
			hi = mid - 1
	return best
