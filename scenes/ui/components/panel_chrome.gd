extends HBoxContainer
class_name PanelChrome
## 统一面板外壳标题栏（v7.x 面板统一 · 视觉升级核心组件）。
##
## 结构：[accent 发光竖条] [标题(+副标题)] [弹簧] [右上 ✕ 关闭按钮]
## 视觉规格对齐 docs/界面一致性/design_06_visual_direction.html：
## 军事科幻 · 几何切割 · hover 发光 · 200ms 过渡感（Godot 内为即时光效）。
##
## 接入方式（面板 _ready 内一行）：
##   var chrome: PanelChrome = PanelChrome.attach_to($Margin/VBox, "公司商店", DesignTokens.get_panel_accent("store"))
##   chrome.closed.connect(func() -> void: closed.emit())  # 转发面板自身 closed 信号
##
## 接入后应删除面板旧标题 Label 与底部"关闭"按钮（关闭统一为本组件右上 ✕）。

signal closed

const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")

var title_label: Label
var subtitle_label: Label
var close_button: Button

var _accent: Color = DT.COLOR_ACCENT_CYAN
var _title_text: String = ""
var _subtitle_text: String = ""

## 挂到目标容器顶部并返回自身。box 通常是面板内容 VBox 的第一层。
static func attach_to(box: BoxContainer, title: String, accent: Color, subtitle := "") -> PanelChrome:
	var chrome := new()
	chrome._accent = accent
	chrome._title_text = title
	chrome._subtitle_text = subtitle
	box.add_child(chrome)
	box.move_child(chrome, 0)
	return chrome


func _ready() -> void:
	_build()


func _build() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# —— accent 发光竖条 ——
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(4, 0)
	bar.size_flags_vertical = Control.SIZE_FILL
	bar.add_theme_stylebox_override("panel", PanelStyles.make_title_accent_bar(_accent))
	add_child(bar)

	# —— 标题（+可选副标题）——
	var title_vbox := VBoxContainer.new()
	title_vbox.add_theme_constant_override("separation", 0)
	title_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(title_vbox)

	title_label = Label.new()
	title_label.text = _title_text
	title_label.add_theme_font_override("font", DT.get_title_font_bold())
	title_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_LARGE)
	title_label.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	title_vbox.add_child(title_label)

	if not _subtitle_text.is_empty():
		subtitle_label = Label.new()
		subtitle_label.text = _subtitle_text
		subtitle_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
		subtitle_label.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
		title_vbox.add_child(subtitle_label)

	# —— 弹簧 ——
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)

	# —— 右上 ✕ 关闭按钮（44×44 点击区，hover 红色发光警示）——
	close_button = Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(44, 44)
	close_button.add_theme_font_size_override("font_size", DT.FONT_SIZE_LARGE)
	close_button.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
	close_button.add_theme_color_override("font_hover_color", DT.COLOR_TEXT_BRIGHT)
	close_button.add_theme_color_override("font_pressed_color", DT.COLOR_TEXT_BRIGHT)
	close_button.add_theme_color_override("font_focus_color", DT.COLOR_TEXT_BRIGHT)
	var styles := PanelStyles.make_close_button_styles()
	close_button.add_theme_stylebox_override("normal", styles["normal"])
	close_button.add_theme_stylebox_override("hover", styles["hover"])
	close_button.add_theme_stylebox_override("pressed", styles["pressed"])
	close_button.add_theme_stylebox_override("focus", styles["focus"])
	close_button.pressed.connect(func() -> void: closed.emit())
	add_child(close_button)


## 标题下方新增一行状态文本（如余额/进度），返回 Label 供调用方后续更新。
func add_status_line(initial_text := "") -> Label:
	if subtitle_label != null and title_label != null:
		# 已有副标题则复用为状态行
		subtitle_label.text = initial_text
		return subtitle_label
	var lbl := Label.new()
	lbl.text = initial_text
	lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	if title_label != null:
		var parent := title_label.get_parent() as BoxContainer
		parent.add_child(lbl)
	return lbl
