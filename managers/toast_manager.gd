extends Node
## v7.x: 全局 Toast 管理器
## 自建独立 CanvasLayer（layer=200，高于 PopupLayer 的 100），确保 toast 永远在最上层，
## 不被 HUD(layer=40)/InfoPanelLayer(90)/PopupLayer(100) 盖住。
## 所有 toast 放到右上角 VBoxContainer（v36 实机验收：原底部居中抬高实落屏幕中部），
## 自动垂直向下堆叠（不再全叠在屏幕 (0,0)）。

var deploy_toast: Control = null
var save_toast: Control = null
var active_toasts: Array = []
# P1-7: 同文案合并表 message → {panel, label, count, tween}
var _merge_map: Dictionary = {}
# P1-7: 同屏上限——战斗播报密集时防止 VBox 无限向上堆叠
const MAX_ACTIVE_TOASTS: int = 5

# 独立 toast 画布层 + 堆叠容器（_ready 时构建）
var _toast_layer: CanvasLayer = null
var _toast_container: VBoxContainer = null

# toast 锚点：v36 实机验收——原"底部居中抬高"实际坐标落在屏幕中部（y≈200-280），
# 开场剧情/战斗中被读成居中弹窗很出戏；移右上角小堆叠（顶部 HUD 条之下、向下展开）。
const _TOAST_MARGIN_TOP: float = 64.0        # 距顶部（避开战斗顶栏 chips）
const _TOAST_MARGIN_RIGHT: float = 24.0
const _TOAST_WIDTH: float = 300.0


func _ready() -> void:
	# v6.6: 连接 SignalBus.show_toast，使全局 toast 提示（战斗/城市/背包等）能到达 ToastManager
	# 之前此信号全程无连接，导致所有 SignalBus.show_toast.emit(...) 静默失效
	SignalBus.show_toast.connect(show_toast)
	# P1-6: 成就解锁此前只有音效无任何视觉提示，这里补一条 toast
	if SignalBus.has_signal("achievement_unlocked") and not SignalBus.achievement_unlocked.is_connected(_on_achievement_unlocked):
		SignalBus.achievement_unlocked.connect(_on_achievement_unlocked)
	_build_toast_layer()


func _on_achievement_unlocked(_achievement_id: String, achievement_name: String) -> void:
	show_success("🏆 成就解锁：%s" % achievement_name)


## 构建独立 CanvasLayer（layer=200）+ 底部居中抬高的 VBox 堆叠容器。
## toast 加到 VBox 下自动垂直排列，不会全叠在 (0,0)。
func _build_toast_layer() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 200   # 高于 PopupLayer(100)，永远在最上层
	_toast_layer.name = "ToastLayer"

	_toast_container = VBoxContainer.new()
	_toast_container.name = "ToastContainer"
	_toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 右上角：anchor 全 1.0 偏左上（v36 屏中 → 角落）
	_toast_container.anchor_left = 1.0
	_toast_container.anchor_right = 1.0
	_toast_container.anchor_top = 0.0
	_toast_container.anchor_bottom = 0.0
	_toast_container.offset_left = -_TOAST_MARGIN_RIGHT - _TOAST_WIDTH
	_toast_container.offset_right = -_TOAST_MARGIN_RIGHT
	_toast_container.offset_top = _TOAST_MARGIN_TOP
	_toast_container.offset_bottom = _TOAST_MARGIN_TOP   # 高度由内容撑开（grow_vertical 向下）
	# VBox 子项顶到底排列：最新 toast 在最下（向下生长，不遮先到的）
	_toast_container.grow_vertical = Control.GROW_DIRECTION_END
	_toast_container.add_theme_constant_override("separation", 6)   # toast 间距 6px
	_toast_container.alignment = BoxContainer.ALIGNMENT_BEGIN

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
	# P1-7: 同文案合并——存活期内重复消息只刷新计数与时长，不重复堆叠
	if target == _toast_container and _merge_map.has(message):
		var m: Dictionary = _merge_map[message]
		var panel: PanelContainer = m.get("panel")
		if panel != null and is_instance_valid(panel):
			m["count"] = int(m.get("count", 1)) + 1
			var lbl: Label = m.get("label")
			if lbl != null and is_instance_valid(lbl):
				lbl.text = "%s ×%d" % [message, int(m["count"])]
			var old_tw: Tween = m.get("tween")
			if old_tw != null and old_tw is Tween and (old_tw as Tween).is_valid():
				(old_tw as Tween).kill()
			panel.modulate.a = 1.0
			var tw = create_tween()
			m["tween"] = tw
			tw.tween_interval(duration)
			tw.tween_property(panel, "modulate:a", 0.0, 0.35)
			tw.finished.connect(_on_toast_finished.bind(panel))
			return
		else:
			_merge_map.erase(message)
	# P1-7: 同屏上限——超出时快速淡出最旧一条
	while active_toasts.size() >= MAX_ACTIVE_TOASTS:
		_evict_oldest_toast()
	var panel = _create_toast_panel(message, color, target)
	target.add_child(panel)
	active_toasts.append(panel)
	if target == _toast_container:
		var lbl: Label = panel.get_meta("toast_label", null)
		var tw = create_tween()
		_merge_map[message] = {"panel": panel, "label": lbl, "count": 1, "tween": tw}
		_animate_toast(panel, duration, tw)
	else:
		_animate_toast(panel, duration)


func show_success(message: String, parent: Control = null) -> void:
	show_toast(message, 2.0, Color(0.2, 0.8, 0.3), parent)

func show_error(message: String, parent: Control = null) -> void:
	show_toast(message, 2.5, Color(0.9, 0.2, 0.2), parent)

func show_warning(message: String, parent: Control = null) -> void:
	show_toast(message, 2.0, Color(0.9, 0.6, 0.2), parent)


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
	# P1-7: 挂 label 引用供同文案合并计数复写
	panel.set_meta("toast_label", lbl)
	return panel


func _animate_toast(panel: PanelContainer, duration: float = 2.0, tw_param = null):
	panel.modulate.a = 0.0
	var tw = tw_param if tw_param is Tween and (tw_param as Tween).is_valid() else create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.12)
	tw.tween_interval(duration)
	tw.tween_property(panel, "modulate:a", 0.0, 0.35)
	tw.finished.connect(_on_toast_finished.bind(panel))


func _on_toast_finished(panel: PanelContainer) -> void:
	active_toasts.erase(panel)
	# P1-7: 清理合并表项（按 panel 反查）
	for msg in _merge_map.keys():
		var m: Dictionary = _merge_map[msg]
		if m.get("panel") == panel:
			_merge_map.erase(msg)
			break
	if is_instance_valid(panel):
		panel.queue_free()


## P1-7: 立即淘汰最旧 toast（快速淡出 0.15s），用于同屏上限约束
func _evict_oldest_toast() -> void:
	var victim = null
	for p in active_toasts:
		if p != deploy_toast and p != save_toast:
			victim = p
			break
	if victim == null:
		victim = active_toasts[0] if not active_toasts.is_empty() else null
	if victim == null:
		return
	active_toasts.erase(victim)
	# 找到 victim 对应的合并表项：杀掉其计时 tween（避免二次 queue_free），并移除表项
	var victim_msg: String = ""
	for msg in _merge_map.keys():
		if (_merge_map[msg] as Dictionary).get("panel") == victim:
			victim_msg = msg
			break
	if not victim_msg.is_empty():
		var m: Dictionary = _merge_map[victim_msg]
		var tw: Variant = m.get("tween")
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
		_merge_map.erase(victim_msg)
	if is_instance_valid(victim):
		var tw2 = create_tween()
		tw2.tween_property(victim, "modulate:a", 0.0, 0.15)
		tw2.tween_callback(victim.queue_free)


## 在 root 的子节点中找第一个 Control（兼容 fallback 路径）。
func _find_first_control_child(root_node: Node) -> Control:
	for c in root_node.get_children():
		if c is Control:
			return c
	return null
