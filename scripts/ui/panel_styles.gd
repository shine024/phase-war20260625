extends RefCounted
class_name PanelStyles
## 统一面板样式工厂（v7.x UI 重设计 · 四养成面板共用）。
##
## 用途：把"如何用 StyleBoxFlat 画出带边框/圆角/阴影/内边距的容器"这一重复样板
## 收敛为一组静态工厂，让 card_enhancement / modification / evolution 等面板统一口径。
##
## 消费方（保持向后兼容，签名以 card_enhancement_panel.gd / modification_panel.gd
## 实际调用点为准）：
##   - make_panel_style(bg, border, border_w, corner_r)                 # 4 参
##   - make_panel_style(bg, border, border_w, corner_r, shadow, size)   # 6 参（默认值统一）
##   - make_card_style(bg, border, border_w, corner_r, padding)         # 5 参（卡片+内边距）
##   - make_chip_style(color)                                           # 标签 chip
##   - make_stat_cell_style(color)                                      # 属性对比格
##   - make_roster_item_style(selected, accent) -> Dictionary           # 列表项（返回字典）

const DT = preload("res://resources/design_tokens.gd")


## 通用平面样式（带边框 + 圆角，可选外发光阴影）。
## shadow_color 传 null 或 alpha=0 时不画阴影。
static func make_panel_style(
		bg: Color,
		border: Color,
		border_w: int,
		corner_r: int,
		shadow_color: Color = Color(0, 0, 0, 0),
		shadow_size: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(maxi(0, border_w))
	sb.set_corner_radius_all(maxi(0, corner_r))
	# 内边距：用 corner_r 的 1/3 保持留白，避免贴边（消费方如需更大留白会再包 MarginContainer）
	var pad: int = int(maxf(2.0, float(corner_r) / 3.0))
	# 逐边赋值（set_content_margin_all 在 Godot 4.5 不存在，且项目惯例也是逐边赋值，见 main.gd:855-858）
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	if shadow_color != null and shadow_color.a > 0.0 and shadow_size > 0:
		sb.shadow_color = shadow_color
		sb.shadow_size = shadow_size
	return sb


## 卡片样式（带固定内边距，用于蜂巢槽外框等"明显留白"容器）。
## padding 为四向统一内边距（像素）。
static func make_card_style(
		bg: Color,
		border: Color,
		border_w: int,
		corner_r: int,
		padding: int) -> StyleBoxFlat:
	var sb := make_panel_style(bg, border, border_w, corner_r)
	var pad: int = maxi(0, padding)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


## 标签 chip（半透明 accent 填充 + 同色边框 + 小圆角）。
static func make_chip_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.18)
	sb.border_color = Color(color.r, color.g, color.b, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb


## 属性对比格（深底 + accent 色边框强调）。
## 6 格属性卡：提升时传 COLOR_GREEN_UP，否则 COLOR_BORDER_DIM。
## 注：StyleBoxFlat 单边异色成本高（需双 box 叠加），这里统一用 accent 色边框 + 粗顶边
## 表达"强调"语义，视觉上顶边更厚、其余偏细。
static func make_stat_cell_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = DT.COLOR_CARD_HI
	sb.border_color = color
	# 四向独立边宽：顶边略粗表达"顶饰"强调
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 2
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb


## 列表项样式（roster item）。
## 返回 Dictionary（消费方仅读取键做轻量覆写，键集宽松保留）。
## selected=true 时 accent 高亮，否则暗边框中性。
static func make_roster_item_style(selected: bool, accent: Color) -> Dictionary:
	var bg: Color = DT.COLOR_CARD_HI if selected else DT.COLOR_CARD
	var border: Color = accent if selected else DT.COLOR_BORDER_DIM
	var border_w: int = 2 if selected else 1
	return {
		"bg": bg,
		"border": border,
		"border_width": border_w,
		"corner_radius": 4,
		"accent": accent,
		"selected": selected,
		"stylebox": make_panel_style(bg, border, border_w, 4),
	}
