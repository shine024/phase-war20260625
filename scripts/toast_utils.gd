extends RefCounted
## Toast 提示工具：在指定父节点上显示临时提示消息
## 从 main.gd 拆分出来的 toast 系统

var _toast: Control = null
var _toast_tween: Tween = null


func show_toast(parent: Node, message: String, is_error: bool = false, \
		rect_left: float = -220.0, rect_right: float = 220.0, \
		rect_top: float = -200.0, rect_bottom: float = -130.0, \
		show_duration: float = 2.2) -> void:

	if message.is_empty():
		return
	_dispose_existing()

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = rect_left
	panel.offset_right = rect_right
	panel.offset_top = rect_top
	panel.offset_bottom = rect_bottom

	var sb := StyleBoxFlat.new()
	if is_error:
		sb.bg_color = Color(0.12, 0.06, 0.08, 0.92)
		sb.border_color = Color(0.95, 0.4, 0.35, 0.85)
	else:
		sb.bg_color = Color(0.05, 0.12, 0.10, 0.92)
		sb.border_color = Color(0.35, 0.9, 0.65, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var lbl := Label.new()
	lbl.text = message
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 13)
	if is_error:
		lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.82, 1.0))
	else:
		lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
	margin.add_child(lbl)

	parent.add_child(panel)
	_toast = panel
	panel.modulate.a = 0.0
	var tw := parent.create_tween()
	_toast_tween = tw
	tw.tween_property(panel, "modulate:a", 1.0, 0.12)
	tw.tween_interval(show_duration)
	tw.tween_property(panel, "modulate:a", 0.0, 0.35)
	tw.finished.connect(_on_finished.bind(panel))


func _dispose_existing() -> void:
	if _toast_tween != null and is_instance_valid(_toast_tween):
		_toast_tween.kill()
		_toast_tween = null
	if _toast != null and is_instance_valid(_toast):
		_toast.queue_free()
		_toast = null


func _on_finished(panel: Control) -> void:
	_toast_tween = null
	if not panel.is_inside_tree():
		if _toast == panel:
			_toast = null
		return
	if is_instance_valid(panel):
		panel.queue_free()
	if _toast == panel:
		_toast = null


func cleanup() -> void:
	_dispose_existing()
