extends Node
## v7.x: 全局 Toast 管理器
## 自建独立 CanvasLayer（layer=200，高于 PopupLayer 的 100），确保 toast 永远在最上层，
## 不被 HUD(layer=40)/InfoPanelLayer(90)/PopupLayer(100) 盖住。
## 所有 toast 放到顶部居中的 VBoxContainer，自动垂直堆叠（不再全叠在屏幕 (0,0)）。

var deploy_toast: Control = null
var save_toast: Control = null
var active_toasts: Array = []

# 独立 toast 画布层 + 堆叠容器（_ready 时构建）
var _toast_layer: CanvasLayer = null
var _toast_container: VBoxContainer = null

# toast 锚点：底部居中抬高（避开战斗日志 496-592 / 底部栏 596-720）
const _TOAST_OFFSET_BOTTOM: float = -440.0   # 距屏幕底部 440px（即 y≈720-440=280 起，向上展开）
const _TOAST_WIDTH_HALF: float = 240.0       # toast 宽度的一半（offset_left/right 用）


func _ready() -> void:
	# v6.6: 连接 SignalBus.show_toast，使全局 toast 提示（战斗/城市/背包等）能到达 ToastManager
	# 之前此信号全程无连接，导致所有 SignalBus.show_toast.emit(...) 静默失效
	SignalBus.show_toast.connect(show_toast)
	_build_toast_layer()


## 构建独立 CanvasLayer（layer=200）+ 底部居中抬高的 VBox 堆叠容器。
## toast 加到 VBox 下自动垂直排列，不会全叠在 (0,0)。
func _build_toast_layer() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 200   # 高于 PopupLayer(100)，永远在最上层
	_toast_layer.name = "ToastLayer"

	_toast_container = VBoxContainer.new()
	_toast_container.name = "ToastContainer"
	_toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 底部居中：anchor 全 1.0（右下角），offset 用负值往左上偏
	_toast_container.anchor_left = 0.5
	_toast_container.anchor_right = 0.5
	_toast_container.anchor_top = 1.0
	_toast_container.anchor_bottom = 1.0
	_toast_container.offset_left = -_TOAST_WIDTH_HALF
	_toast_container.offset_right = _TOAST_WIDTH_HALF
	_toast_container.offset_top = _TOAST_OFFSET_BOTTOM - 80.0   # 容器顶缘位置（多 toast 向上扩展留余量）
	_toast_container.offset_bottom = _TOAST_OFFSET_BOTTOM        # 容器底缘位置
	# VBox 的子项从顶到底排列；用 size_flags 让 toast 在容器内贴底排列（最新 toast 在最下）
	_toast_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_container.add_theme_constant_override("separation", 6)   # toast 间距 6px
	_toast_container.alignment = BoxContainer.ALIGNMENT_END         # 底部对齐：新 toast 出现在最下方

	_toast_layer.add_child(_toast_container)
	add_child(_toast_layer)


## 供外部（如 toast_utils）复用高 z-order 的 toast layer。
func get_toast_layer() -> CanvasLayer:
	return _toast_layer


## 供外部（如 toast_utils）复用 toast 堆叠容器（推荐用这个，自动堆叠）。
func get_toast_container() -> VBoxContainer:
	return _toast_container


func show_toast(message: String, duration: float = 2.0, color: Color = Color(0.2, 0.8, 0.3), parent: Control = null) -> void:
	# 优先使用自建堆叠容器；调用方主动传 parent 时回退兼容（不影响已有调用方）
	var target: Control = parent
	if target == null:
		if is_instance_valid(_toast_container):
			target = _toast_container
		else:
			# 容器未就绪（_ready 未跑或被释放）：回退到 root 的直接子 Control
			var tree := get_tree()
			if tree != null:
				target = _find_first_control_child(tree.root)
	if target == null:
		return
	var panel = _create_toast_panel(message, color, target)
	target.add_child(panel)
	active_toasts.append(panel)
	_animate_toast(panel, duration)


func show_success(message: String, parent: Control = null) -> void:
	show_toast(message, 2.0, Color(0.2, 0.8, 0.3), parent)

func show_error(message: String, parent: Control = null) -> void:
	show_toast(message, 2.5, Color(0.9, 0.2, 0.2), parent)

func show_warning(message: String, parent: Control = null) -> void:
	show_toast(message, 2.0, Color(0.9, 0.6, 0.2), parent)

func show_deploy_failure(message: String, parent: Control):
	if deploy_toast and is_instance_valid(deploy_toast):
		deploy_toast.queue_free()
	var target: Control = parent
	if target == null and is_instance_valid(_toast_container):
		target = _toast_container
	if target == null:
		return
	var panel = _create_toast_panel(message, Color.RED, target)
	target.add_child(panel)
	deploy_toast = panel
	_animate_toast(panel)

func show_save_result(message: String, is_error: bool, parent: Control):
	if save_toast and is_instance_valid(save_toast):
		save_toast.queue_free()
	var color = Color.RED if is_error else Color.GREEN
	var target: Control = parent
	if target == null and is_instance_valid(_toast_container):
		target = _toast_container
	if target == null:
		return
	var panel = _create_toast_panel(message, color, target)
	target.add_child(panel)
	save_toast = panel
	_animate_toast(panel)


func _create_toast_panel(message: String, color: Color, _parent: Control) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 放进 VBoxContainer 时让 toast 横向铺满容器宽度（容器宽度由 offset 控制）
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb = StyleBoxFlat.new()
	sb.bg_color = color * 0.92
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	var lbl = Label.new()
	lbl.text = message
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	margin.add_child(lbl)
	panel.add_child(margin)
	return panel


func _animate_toast(panel: PanelContainer, duration: float = 2.0):
	panel.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.12)
	tw.tween_interval(duration)
	tw.tween_property(panel, "modulate:a", 0.0, 0.35)
	tw.finished.connect(_on_toast_finished.bind(panel))


func _on_toast_finished(panel: PanelContainer) -> void:
	active_toasts.erase(panel)
	if is_instance_valid(panel):
		panel.queue_free()


## 在 root 的子节点中找第一个 Control（兼容 fallback 路径）。
func _find_first_control_child(root_node: Node) -> Control:
	for c in root_node.get_children():
		if c is Control:
			return c
	return null
