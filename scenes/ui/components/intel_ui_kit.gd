extends RefCounted
class_name IntelUIKit
## 情报家族共享视觉构建器（v26 UI 品质批次：情报中心/结算收获/揭示弹窗三面板统一）。
##
## 背景：此前三个情报面板各自手写 StyleBox（lore 卡圆角 8 / 符文行边框 2-2-1-1 /
## 符文之语紫底 0.08 / 敌方情报行边框 3-1-1-1），状态全靠「[已获得]」方括号文本，
## 区块标题是 ◈✦◆ unicode 纯文本——面板之间零一致性，即「乱七八糟」的根源。
##
## 统一视觉语言（对齐 PanelChrome / design_06 军事科幻方向）：
## - 区块标题 = 4px 发光竖条 + 粗体标题 + 1px 签名色底线；计数右对齐
## - 状态 chip = 半透明色底 + 同色描边（语义唯一：金=解锁/满档，绿=可激活/已获得，
##   青=进行/新增，灰=未获得/不足）
## - 列表行 = 深卡底 + 状态色描边（左侧 3px 粗边做状态锚点），圆角 4（chip 档）
## - 进度条 = 深槽底 + 状态色填充，圆角 3（格子档），高 8
##
## 颜色/字号一律走 DesignTokens；本类无状态，全静态。

const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")


# ── 文本 ─────────────────────────────────────────────────────────────

## 统一小标签。min_width > 0 时定宽（列表列对齐用）；align 常配 HORIZONTAL_ALIGNMENT_RIGHT。
static func label(text: String, font_size: int, color: Color, min_width := 0.0,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if min_width > 0.0:
		l.custom_minimum_size = Vector2(min_width, 0)
	l.horizontal_alignment = align
	return l


# ── 区块标题 ─────────────────────────────────────────────────────────

## 区块标题：accent 发光竖条 + 粗体标题 + 1px 签名色底线；count_text 非空时右对齐。
## 返回 VBoxContainer（标题行 + 底线），调用方直接 add_child 进内容列。
static func section_header(title: String, accent: Color, count_text := "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(4, 16)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("panel", PanelStyles.make_title_accent_bar(accent))
	row.add_child(bar)

	var title_lbl := label(title, DT.FONT_SIZE_MEDIUM, DT.COLOR_TEXT_BRIGHT)
	title_lbl.add_theme_font_override("font", DT.get_title_font_bold())
	row.add_child(title_lbl)

	if not count_text.is_empty():
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		row.add_child(label(count_text, DT.FONT_SIZE_SMALL, DT.COLOR_TEXT_DIM))

	box.add_child(row)

	var rule := ColorRect.new()
	rule.color = Color(accent.r, accent.g, accent.b, 0.22)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 纯装饰分隔线，不吃点击（记录4 视觉体检 C 类误报源）
	box.add_child(rule)
	return box


# ── 状态 chip ────────────────────────────────────────────────────────

## 状态 chip：替代旧「[已获得]」「图纸✓」方括号文本。dim=true 转灰（未获得/不足语义）。
static func status_chip(text: String, color: Color, dim := false) -> PanelContainer:
	var c := DT.COLOR_TEXT_FAINT if dim else color
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", PanelStyles.make_chip_style(c))
	chip.add_child(label(text, DT.FONT_SIZE_SMALL, c))
	return chip


# ── 列表行 ───────────────────────────────────────────────────────────

## 统一列表行样式：深卡底 + 状态色描边（左 3px 状态锚点），圆角 4（chip 档）。
## strong=true 高亮态（底色提亮 + 描边全亮）；accent 传中性灰即普通行。
static func list_row_style(accent: Color, strong := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = DT.COLOR_CARD_HI if strong else DT.COLOR_CARD
	sb.border_color = accent if strong else Color(accent.r, accent.g, accent.b, 0.38)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


# ── 进度条 ───────────────────────────────────────────────────────────

## 细进度条（值域 0-1）：深槽底 + fill 色填充，圆角 3（格子档），高 8，无内置百分比。
static func thin_progress(value01: float, fill: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.value = clampf(value01, 0.0, 1.0)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 8)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(DT.COLOR_VOID.r, DT.COLOR_VOID.g, DT.COLOR_VOID.b, 0.85)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	return pb
