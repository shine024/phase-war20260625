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


# ===== v7.x 面板统一扩展：面板框架 / 按钮四态 / 标题饰条 =====
# 视觉规格对齐 docs/界面一致性/design_06_visual_direction.html：
# 2px 边框、8-12px 圆角、hover/pressed 发光反馈、半透明深色底。

## 面板主框架：深空黑底 + accent 边框 + 大圆角 + 外发光（视觉升级核心）。
## 用于面板根 PanelContainer 的 theme_override_styles/panel。
static func make_panel_frame(accent: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(DT.COLOR_VOID.r, DT.COLOR_VOID.g, DT.COLOR_VOID.b, 0.97)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	# 顶边饰条：accent 粗顶边表达"面板顶部有标题栏"的层次（几何切割语言）
	sb.border_width_top = 3
	# 外发光：accent 色低强度光晕（design_06 光效规范：普通态低强度）
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.22)
	sb.shadow_size = 10
	return sb


## 标题栏左侧发光竖条（PanelChrome 用，也可单独复用）。
static func make_title_accent_bar(accent: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent
	sb.set_corner_radius_all(2)
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.55)
	sb.shadow_size = 6
	return sb


## 按钮四态样式包。返回 {normal, hover, pressed, disabled, focus}（值全为 StyleBoxFlat）。
## kind: "solid"（accent 填充主按钮）/ "ghost"（描边次按钮，默认）/ "danger"（红）。
## 消费方式：btn.add_theme_stylebox_override("normal", styles.normal) 等逐键覆写。
static func make_button_styles(accent: Color, kind := "ghost") -> Dictionary:
	var fill_a := 0.14
	var border_a := 0.55
	if kind == "solid":
		fill_a = 0.85
		border_a = 1.0
	elif kind == "danger":
		accent = DT.COLOR_RED_DOWN

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent.r, accent.g, accent.b, fill_a * 0.7)
	normal.border_color = Color(accent.r, accent.g, accent.b, border_a * 0.8)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	_set_button_margins(normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(accent.r, accent.g, accent.b, fill_a)
	hover.border_color = Color(accent.r, accent.g, accent.b, border_a)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(6)
	# hover 外发光（design_06：光晕与语义色对应）
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
	hover.shadow_size = 6
	_set_button_margins(hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(accent.r, accent.g, accent.b, minf(fill_a * 1.4, 1.0))
	pressed.border_color = Color(accent.r, accent.g, accent.b, border_a)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(6)
	_set_button_margins(pressed)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.08, 0.10, 0.15, 0.6)
	disabled.border_color = Color(0.3, 0.34, 0.42, 0.4)
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(6)
	_set_button_margins(disabled)

	var focus := hover.duplicate()
	focus.set_border_width_all(2)

	return {
		"normal": normal,
		"hover": hover,
		"pressed": pressed,
		"disabled": disabled,
		"focus": focus,
	}


static func _set_button_margins(sb: StyleBoxFlat) -> void:
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6


## 关闭按钮（✕）四态：常态低调中性，hover 转红发光警示（PanelChrome 用）。
static func make_close_button_styles() -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.12, 0.18, 0.6)
	normal.border_color = Color(0.30, 0.34, 0.42, 0.5)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(DT.COLOR_RED_DOWN.r, DT.COLOR_RED_DOWN.g, DT.COLOR_RED_DOWN.b, 0.22)
	hover.border_color = Color(DT.COLOR_RED_DOWN.r, DT.COLOR_RED_DOWN.g, DT.COLOR_RED_DOWN.b, 0.9)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(8)
	hover.shadow_color = Color(DT.COLOR_RED_DOWN.r, DT.COLOR_RED_DOWN.g, DT.COLOR_RED_DOWN.b, 0.45)
	hover.shadow_size = 8

	var pressed := hover.duplicate()
	pressed.bg_color = Color(DT.COLOR_RED_DOWN.r, DT.COLOR_RED_DOWN.g, DT.COLOR_RED_DOWN.b, 0.38)
	pressed.shadow_size = 4

	return {"normal": normal, "hover": hover, "pressed": pressed, "focus": hover.duplicate()}


## P1-5: 递归给子树内所有 BaseButton 设手型光标。
## 实测 Godot 4.5 Button 的 mouse_default_cursor_shape 默认是箭头（仅 LinkButton 是手型），
## 全项目按钮此前一律显示箭头。启动时对主场景跑一次；运行期新增节点由
## SceneTree.node_added 钩子覆盖（见 main.gd _on_node_added）。
static func apply_pointing_hand(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	if root is BaseButton:
		(root as BaseButton).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for c in root.get_children():
		apply_pointing_hand(c)
