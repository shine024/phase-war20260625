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
		shadow_color: Color = DT.COLOR_TRANSPARENT,
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
	# R-D3：阴影档位取 DT.SHADOW_SIZE_PANEL（面板阴影两档之一；浮层档=SHADOW_SIZE_FLOAT）
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.22)
	sb.shadow_size = DT.SHADOW_SIZE_PANEL
	return sb


# ===== v25 UI 品质批次：九宫格渐变面板框 =====
# 纯 StyleBoxFlat 无渐变能力，"纯色块+描边"是面板廉价感的主因之一。
# 这里按 accent 程序生成一张 128×128 圆角渐变面板贴图（SDF 圆角 + 垂直微渐变 +
# 边框烘焙进贴图），经 StyleBoxTexture 九宫格拉伸——四角圆角与 2px 边框 1:1 不变形，
# 中心区垂直渐变自由拉伸。按 accent 色缓存，每色只生成一次。

const _PANEL_TEX_SIZE := 128
const _PANEL_TEX_RADIUS := 14

static var _panel_tex_cache: Dictionary = {}

## SDF 圆角矩形：返回点到圆角矩形的有符号距离（<0 在内部）
static func _rounded_rect_sdf(px: float, py: float, half: float, radius: float) -> float:
	var qx: float = maxf(absf(px - half) - (half - radius), 0.0)
	var qy: float = maxf(absf(py - half) - (half - radius), 0.0)
	return sqrt(qx * qx + qy * qy) - radius


static func _make_panel_texture(accent: Color) -> ImageTexture:
	var n := _PANEL_TEX_SIZE
	var radius := float(_PANEL_TEX_RADIUS)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var base := DT.COLOR_VOID
	var top := base.lightened(0.055)  # 顶部微亮：单一光源的"顶光"错觉
	for y in n:
		var row: Color = top.lerp(base, float(y) / float(n - 1))
		for x in n:
			var d := _rounded_rect_sdf(float(x), float(y), float(n - 1) * 0.5, radius)
			if d > 0.75:
				continue
			var c: Color
			if d > -2.0:
				c = Color(accent.r, accent.g, accent.b, 0.55)  # 边框烘焙
			else:
				c = row
			c.a *= clampf(0.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## 面板主框架（质感版）：渐变底 + 九宫格圆角 + 烘焙边框 + 外发光。
## 与 make_panel_frame 同语义（弹窗/养成面板根框架），HUD 常驻条仍用 flat 版。
static func make_panel_frame_textured(accent: Color) -> StyleBoxTexture:
	var key := accent.to_html()
	if not _panel_tex_cache.has(key):
		_panel_tex_cache[key] = _make_panel_texture(accent)
	var sb := StyleBoxTexture.new()
	sb.texture = _panel_tex_cache[key]
	var m := _PANEL_TEX_RADIUS + 2  # 四角不拉伸区 = 半径 + 边框
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	sb.content_margin_top = 3
	sb.content_margin_bottom = 2
	sb.modulate_color = Color(1, 1, 1, 0.98)
	# 注：StyleBoxTexture 无 shadow 属性（glow 仅 flat 版有）；渐变底+烘焙边框承担质感
	return sb


## 结算/大事记面板框：accent 边框 + 带 bg 色相的渐变底（保留胜利绿底/失败红底语义）。
## 与 make_panel_frame_textured 同构造但 bg 不锁 COLOR_VOID，按 (accent,bg) 缓存。
## ⚠️ 缓存的是 StyleBoxTexture 不是贴图（v28 跟进批修复：原缓存命中分支返回裸
## ImageTexture，同色第二次调用必炸——同会话第二张结算页/二次打开商店都触发）。
static func make_result_frame(accent: Color, bg: Color) -> StyleBoxTexture:
	var key := "res|%s|%s" % [accent.to_html(), bg.to_html()]
	if _surface_tex_cache.has(key):
		# 命中即复制：贴图（烘焙贵）共享，StyleBox 壳独立——调用方普遍事后改
		# content_margin，共享实例会让两个弹窗互相踩边距（offline 20/18 vs afk 22/20）
		return (_surface_tex_cache[key] as StyleBoxTexture).duplicate()
	var tex := _bake_surface_texture(_PANEL_TEX_SIZE, float(_PANEL_TEX_RADIUS),
		bg.lightened(0.055), bg,
		Color(accent.r, accent.g, accent.b, 0.80))
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	var m := _PANEL_TEX_RADIUS + 2
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	sb.content_margin_top = 3
	sb.content_margin_bottom = 2
	_surface_tex_cache[key] = sb
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


# ===== v28 质感轮 T2：渐变"面材"按钮 / 列表行（StyleBoxTexture 九宫格） =====
# StyleBoxFlat 无渐变，"纯色块按钮/列表行"是标题/结算/商店/背包四屏平感主因。
# 沿用 _make_panel_texture 的 SDF 圆角+烘焙边框思路，推广为通用表面烘焙器；
# 新工厂 make_button_styles_graded / make_row_surface 只迁新目标屏，
# 旧 make_button_styles 返回 StyleBoxFlat 不动（多处消费方 duplicate() as StyleBoxFlat 强转改属性）。

static func _bake_surface_texture(size: int, radius: float, top: Color, bottom: Color, border: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		var row: Color = top.lerp(bottom, float(y) / float(size - 1))
		for x in size:
			var d := _rounded_rect_sdf(float(x), float(y), float(size - 1) * 0.5, radius)
			if d > 0.75:
				continue
			var c: Color
			if d > -2.0:
				c = border
			else:
				c = row
			c.a *= clampf(0.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


const _BTN_TEX_SIZE := 64
const _BTN_TEX_RADIUS := 6
const _ROW_TEX_SIZE := 64
const _ROW_TEX_RADIUS := 6

static var _surface_tex_cache: Dictionary = {}


## 渐变按钮贴图：solid=实底亮渐变 / ghost=低掺量罩；state 分 normal/hover/pressed 三档亮度
static func _make_button_surface_tex(accent: Color, solid: bool, state: String) -> ImageTexture:
	var key := "btn|%s|%s|%s" % [accent.to_html(), solid, state]
	if _surface_tex_cache.has(key):
		return _surface_tex_cache[key]
	var top: Color
	var bottom: Color
	var border: Color
	if solid:
		match state:
			"hover":
				top = accent.lightened(0.26); bottom = accent.darkened(0.16)
				border = accent.lightened(0.55); border.a = 1.0
			"pressed":
				top = accent.darkened(0.08); bottom = accent.darkened(0.38)
				border = accent.lightened(0.20); border.a = 1.0
			_:
				top = accent.lightened(0.16); bottom = accent.darkened(0.28)
				border = accent.lightened(0.35); border.a = 0.95
	else:
		match state:
			"hover":
				top = Color(accent.r, accent.g, accent.b, 0.30); bottom = Color(accent.r, accent.g, accent.b, 0.12)
				border = Color(accent.r, accent.g, accent.b, 0.95)
			"pressed":
				top = Color(accent.r, accent.g, accent.b, 0.34); bottom = Color(accent.r, accent.g, accent.b, 0.16)
				border = Color(accent.r, accent.g, accent.b, 1.0)
			_:
				top = Color(accent.r, accent.g, accent.b, 0.20); bottom = Color(accent.r, accent.g, accent.b, 0.07)
				border = Color(accent.r, accent.g, accent.b, 0.60)
	var tex := _bake_surface_texture(_BTN_TEX_SIZE, float(_BTN_TEX_RADIUS), top, bottom, border)
	_surface_tex_cache[key] = tex
	return tex


## 按钮四态（渐变版）。返回键集与 make_button_styles 一致：
## normal/hover/pressed = StyleBoxTexture（SDF 圆角渐变 + 烘焙边框），
## disabled/focus = StyleBoxFlat（disabled 灰哑光；focus 仅描边环，叠在常态之上）。
## kind: "solid"（accent 实底主按钮）/ "ghost"（描边次按钮，默认）/ "danger"（红 ghost）。
static func make_button_styles_graded(accent: Color, kind := "ghost") -> Dictionary:
	var a: Color = DT.COLOR_RED_DOWN if kind == "danger" else accent
	var solid := kind == "solid"
	var result := {}
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxTexture.new()
		sb.texture = _make_button_surface_tex(a, solid, st)
		var m := _BTN_TEX_RADIUS + 2
		sb.texture_margin_left = m
		sb.texture_margin_right = m
		sb.texture_margin_top = m
		sb.texture_margin_bottom = m
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		result[st] = sb
	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.08, 0.10, 0.15, 0.6)
	disabled.border_color = Color(0.3, 0.34, 0.42, 0.4)
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(6)
	_set_button_margins(disabled)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(a.r, a.g, a.b, 0.9)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(6)
	result["disabled"] = disabled
	result["focus"] = focus
	return result


## 列表行"面材"：深底微渐变 + accent 暗边（商店商品行/设置行等）。
## emphasized=true 用亮一点的底（行内重要条目）；每 accent 缓存 StyleBox（同
## make_result_frame 的修复：缓存命中必须返回 StyleBox，不能返回裸贴图）。
static func make_row_surface(accent: Color, emphasized := false) -> StyleBoxTexture:
	var key := "row|%s|%s" % [accent.to_html(), emphasized]
	if _surface_tex_cache.has(key):
		return (_surface_tex_cache[key] as StyleBoxTexture).duplicate()  # 命中即复制（同 make_result_frame）
	var base := DT.COLOR_CARD_HI if emphasized else DT.COLOR_CARD
	var top: Color = base.lightened(0.045)
	var bottom: Color = base.darkened(0.03)
	var border: Color = Color(accent.r, accent.g, accent.b, 0.32 if emphasized else 0.22)
	var tex := _bake_surface_texture(_ROW_TEX_SIZE, float(_ROW_TEX_RADIUS), top, bottom, border)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	var m := _ROW_TEX_RADIUS + 2
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	# 内边距归零：行容器（MarginContainer/RowMargin）自管 padding，避免双份
	_surface_tex_cache[key] = sb
	return sb


static func _set_button_margins(sb: StyleBoxFlat) -> void:
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6


# ===== v25 UI 品质批次：战斗 HUD 紧凑家族 =====
# 战斗层常驻条（资源栏/战斗日志/连携状态条/折叠卡）与弹窗面板不同：要更薄更透明，
# 不抢战场视线。统一规格：PANEL_DEEP a0.72 底 + 1px 描边 + 6px 圆角 + 无外发光。

## HUD 底板。border_alpha 调描边强度（默认弱 0.28；需强调传 0.4）。
static func make_hud_panel(border_alpha := 0.28) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(DT.COLOR_PANEL_DEEP.r, DT.COLOR_PANEL_DEEP.g, DT.COLOR_PANEL_DEEP.b, 0.72)
	sb.border_color = Color(DT.COLOR_BORDER.r, DT.COLOR_BORDER.g, DT.COLOR_BORDER.b, border_alpha)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	return sb


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
