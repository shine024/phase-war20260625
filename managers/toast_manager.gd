extends Node

var deploy_toast: Control = null
var save_toast: Control = null
var active_toasts: Array = []

func _ready() -> void:
	# v6.6: 连接 SignalBus.show_toast，使全局 toast 提示（战斗/城市/背包等）能到达 ToastManager
	# 之前此信号全程无连接，导致所有 SignalBus.show_toast.emit(...) 静默失效
	SignalBus.show_toast.connect(show_toast)

func show_toast(message: String, duration: float = 2.0, color: Color = Color(0.2, 0.8, 0.3), parent: Control = null) -> void:
	if parent == null:
		var tree := get_tree()
		if tree == null:
			return
		var root = tree.root
		if root is Control:
			parent = root as Control
	if parent == null:
		return
	var panel = _create_toast_panel(message, color, parent)
	parent.add_child(panel)
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
	var panel = _create_toast_panel(message, Color.RED, parent)
	parent.add_child(panel)
	deploy_toast = panel
	_animate_toast(panel)

func show_save_result(message: String, is_error: bool, parent: Control):
	if save_toast and is_instance_valid(save_toast):
		save_toast.queue_free()
	var color = Color.RED if is_error else Color.GREEN
	var panel = _create_toast_panel(message, color, parent)
	parent.add_child(panel)
	save_toast = panel
	_animate_toast(panel)

func _create_toast_panel(message: String, color: Color, parent: Control) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb = StyleBoxFlat.new()
	sb.bg_color = color * 0.92
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	var lbl = Label.new()
	lbl.text = message
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
