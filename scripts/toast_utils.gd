extends RefCounted
## Toast 提示工具：在指定父节点上显示临时提示消息
## 从 main.gd 拆分出来的 toast 系统
##
## v7.x: 改为优先挂到 ToastManager 的独立 CanvasLayer（layer=200），
## 避免被战斗 HUD（layer=40）/弹窗（layer=100）盖住"只看到一半"。
## 定位从"底部贴底（-200~-130，压在战斗日志上）"改为"底部抬高（-440~-380）"，
## 避开战斗日志区(496-592)和底部卡牌栏(596-720)。

var _toast: Control = null
var _toast_tween: Tween = null


func show_toast(parent: Node, message: String, is_error: bool = false, \
		rect_left: float = -240.0, rect_right: float = 240.0, \
		rect_top: float = -440.0, rect_bottom: float = -380.0, \
		show_duration: float = 2.2) -> void:

	if message.is_empty():
		return
	_dispose_existing()

	# 优先复用 ToastManager 的 layer=200（永远在最上层）；回退到调用方传入的 parent
	var host_parent: Node = _get_toast_host(parent)

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

	host_parent.add_child(panel)
	_toast = panel
	panel.modulate.a = 0.0
	var tw := host_parent.create_tween()
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


## 优先复用 ToastManager 的独立 CanvasLayer（layer=200，永远在最上层），
## 找不到时回退到调用方传入的 parent（保持向后兼容）。
func _get_toast_host(fallback_parent: Node) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var tm: Node = tree.root.get_node_or_null("/root/ToastManager")
		if tm != null and tm.has_method("get_toast_layer"):
			var layer: CanvasLayer = tm.get_toast_layer()
			if layer != null and is_instance_valid(layer):
				return layer
	return fallback_parent
