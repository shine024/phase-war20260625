class_name HoverTip
extends CanvasLayer
## v6.42（记录6）：顶层悬停提示层——替代引擎内建 tooltip。
##
## 根因：内建 tooltip 由引擎画在根窗口默认画布（layer 0），而背包在 PopupLayer
## （CanvasLayer layer=100）里，符文瓷砖的卡框 CardFrameOverlay z_index=30（hover
## 抬升后有效 40）——内建提示必然被卡框整块盖住（实机主诉"符文的提示，面板在背包
## 上面，而卡框又在提示上面"）。跨 CanvasLayer 无法用 z_index 救，唯一正解=自建
## 更高层级的提示层。层号 130：> PopupLayer(100) / InfoPanelLayer(110)，< 结算(200)。
##
## 用法（两步）：
##   HoverTip.bind_control(ctrl)                       # 接 hover 显示/隐藏
##   HoverTip.set_tip(ctrl, "……")                      # 随时更新内容（悬停时才读，防旧文案残留）
## 内容在 mouse_entered 时才读取（对象池复用/数据晚写都安全）；鼠标跟随，全 IGNORE 不挡点击。

const LAYER_INDEX: int = 130
const OFFSET := Vector2(16, 20)
const MAX_WIDTH := 300.0

static var _instance: HoverTip = null

var _panel: PanelContainer = null
var _label: Label = null
var _tip_owner: Control = null


static func instance() -> HoverTip:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	var root: Window = Engine.get_main_loop().root if Engine.get_main_loop() != null else null
	if root == null:
		return null
	_instance = HoverTip.new()
	_instance.name = "HoverTipLayer"
	_instance.layer = LAYER_INDEX
	root.add_child(_instance)
	_instance._build()
	return _instance


## 绑定控件：mouse_entered 显示 set_tip 存的内容，mouse_exited/离树隐藏。
static func bind_control(ctrl: Control) -> void:
	if ctrl == null or ctrl.has_meta("hover_tip_bound"):
		return
	ctrl.set_meta("hover_tip_bound", true)
	ctrl.mouse_entered.connect(func() -> void: _show_for(ctrl))
	ctrl.mouse_exited.connect(func() -> void: _hide_for(ctrl))
	ctrl.tree_exiting.connect(func() -> void: _hide_for(ctrl))


## 存提示内容（悬停时读取——晚于 set 调用也生效；对象池复用重写即自动更新）
static func set_tip(ctrl: Control, text: String) -> void:
	if ctrl == null:
		return
	ctrl.set_meta("hover_tip_text", text)


static func _show_for(ctrl: Control) -> void:
	var text := String(ctrl.get_meta("hover_tip_text", ""))
	if text.is_empty():
		return
	var inst := instance()
	if inst == null:
		return
	inst._present(text)


static func _hide_for(ctrl: Control) -> void:
	if _instance == null or not is_instance_valid(_instance):
		return
	if _instance._tip_owner == ctrl:
		_instance._dismiss()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.09, 0.96)
	sb.border_color = Color(0.85, 0.72, 0.35, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 7.0
	_panel.add_theme_stylebox_override("panel", sb)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.93, 0.93, 0.9))
	_panel.add_child(_label)
	add_child(_panel)
	visible = false


func _present(text: String) -> void:
	if _label == null:
		return
	_label.text = text
	_label.custom_minimum_size = Vector2(MAX_WIDTH - 20.0, 0)
	_panel.reset_size()
	visible = true
	_follow_mouse()


func _dismiss() -> void:
	_tip_owner = null
	visible = false


func _process(_delta: float) -> void:
	if visible:
		_follow_mouse()


func _follow_mouse() -> void:
	if _panel == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var mouse := vp.get_mouse_position()
	var sz := _panel.size
	var pos := mouse + OFFSET
	var screen := vp.get_visible_rect().size
	if pos.x + sz.x > screen.x - 4.0:
		pos.x = maxf(4.0, mouse.x - sz.x - 8.0)
	if pos.y + sz.y > screen.y - 4.0:
		pos.y = maxf(4.0, mouse.y - sz.y - 8.0)
	_panel.position = pos
