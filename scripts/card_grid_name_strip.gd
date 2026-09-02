extends Node2D
class_name CardGridNameStrip
## 格子战卡内名称条：在卡片立绘底部"卡框内部"绘制单位名称（我方青色 / 敌方橙红）。
## 与 CardGridRankStrip（卡顶军衔图标）对称，补齐"战场上看不出是哪个单位"的可读性缺口。
## 注：定位由宿主 CardGridUnitVisuals.sync_name_strip() 设置（紧贴卡底边内侧）；本类只负责绘制。
##
## v26.x 战场名牌整治：
## - 字体从 ThemeDB 回退字体换成项目打包 Noto Sans SC——回退字体的 U+2026 省略号
##   画在基线底部，视觉上像下划线"_"（"混凝土机_"的观感即此缺陷）。
## - 名牌条比卡宽加宽 12%（居中外溢 ±3.5px，相邻槽距下无碰撞），配合 short_name
##   数据层让绝大多数名字完整显示。
## - 变体后缀（·精锐/·敌方/·Boss/·改）在战场条上剥离——精英金框/敌方红名已是
##   同信息的视觉语言；悬停详情仍显示 display_name 全名。

const CardGridBattleLayout = preload("res://scripts/card_grid_battle_layout.gd")
const DT = preload("res://resources/design_tokens.gd")

## 名称条高度（像素），与卡宽按比例缩放
const NAME_BAR_HEIGHT_FRAC: float = 0.30
## 字号占卡宽比例（按未加宽的卡宽算，避免加宽后字号上涨反吃可容字符数）
const FONT_SIZE_FRAC: float = 0.20
## 名牌条相对卡宽的加宽系数（居中外溢）
const BAR_WIDEN: float = 1.12
## 文本左右内边距（单侧）
const TEXT_PAD: float = 2.0

## 战场条剥离的变体后缀（完整名在图鉴/悬停保留）。时代后缀（守护者系列）同剥——
## 时代信息由战场环境自明，悬停可见全名。
const VARIANT_SUFFIXES: Array[String] = ["·精锐", "·敌方", "·Boss", "·改", "·一战", "·二战", "·冷战", "·现代", "·近未来"]

const COLOR_PLAYER: Color = Color(0.30, 0.92, 1.00, 1.0)
const COLOR_ENEMY: Color = Color(1.00, 0.55, 0.40, 1.0)
const COLOR_BAR_BG: Color = Color(0.04, 0.07, 0.11, 0.78)
const COLOR_BAR_BORDER: Color = Color(0.5, 0.6, 0.7, 0.55)

static var _cjk_font: Font = null

var _card_art_width: float = 0.0
var _card_art_height: float = 0.0
var _display_name: String = ""
var _is_player: bool = true
var _bar_rect: Rect2 = Rect2()
var _font_size: int = 11


## 项目打包中文字体（DesignTokens 单一来源），加载失败回退 ThemeDB 字体。
static func _get_font() -> Font:
	if _cjk_font == null:
		_cjk_font = load(DT.CJK_BUNDLED_BODY) as Font
	if _cjk_font != null:
		return _cjk_font
	return ThemeDB.get_fallback_font()


## 战场名牌显示名：short_name 优先，否则 display_name 剥变体后缀。
static func battlefield_display_name(card: CardResource) -> String:
	if card == null:
		return ""
	var base: String = card.short_name if not card.short_name.is_empty() else card.display_name
	var changed := true
	while changed:
		changed = false
		for suf in VARIANT_SUFFIXES:
			if base.ends_with(suf):
				base = base.trim_suffix(suf)
				changed = true
	return base


## 指定字号下文本是否放得进 max_width（供势力前缀取舍判断）。
static func text_fits(text: String, max_width: float, font_size: int) -> bool:
	var font: Font = _get_font()
	if font == null:
		return true
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width


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
	# 字号随卡宽缩放，但限定在合理区间（基准是未加宽卡宽，保持 11px 档）
	_font_size = clampi(int(_card_art_width * FONT_SIZE_FRAC), 10, 14)
	# 名称条尺寸：卡宽 × BAR_WIDEN（居中外溢），高度按未加宽卡宽比例
	# _bar_rect 从 strip 局部原点(0,0) 起算；绝对定位由宿主在外部设置 position。
	var bar_h: float = maxf(_card_art_width * NAME_BAR_HEIGHT_FRAC, 14.0)
	var bar_w: float = _card_art_width * BAR_WIDEN
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
	var truncated: String = _fit_name(_display_name, _bar_rect.size.x - TEXT_PAD * 2.0)
	var font: Font = _get_font()
	if font == null:
		return
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
	var font: Font = _get_font()
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
