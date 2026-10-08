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

# v6.52（记录1#16）：战后同帧 burst 滴流——结算帧 10+ 条提示（掉落+成就+委托+首通+解锁）
# 同帧创建/驱逐 10 个 CJK autowrap 面板 = 实机"多条提示出来就卡死"主诉。池满且本帧已有
# 直接创建时改入队，0.18s/条放行；单条路径零额外延迟。
const _BURST_DRAIN_INTERVAL: float = 0.18
var _pending_queue: Array = []     # [{message, duration, color, feed}]
var _drain_timer: Timer = null
var _burst_frame: int = -1         # burst 判定：本帧是否已直接创建过一条

# 独立 toast 画布层 + 堆叠容器（_ready 时构建）
var _toast_layer: CanvasLayer = null
var _toast_container: VBoxContainer = null
var _feed_container: VBoxContainer = null   # 记录5#10: 左下 feed 通道（获得/解锁）

# toast 锚点：v36 实机验收——原"底部居中抬高"实际坐标落在屏幕中部（y≈200-280），
# 开场剧情/战斗中被读成居中弹窗很出戏；移右上角小堆叠。
# 记录5#7：原 margin_top=64 会与战况条（battle_status_strip，右上 y∈[72,200]）矩形重叠、
# layer 200 恒压 40 盖死敌方战况——现整体下移到战况条之下（bottom 200 + 8 间距）。
const _TOAST_MARGIN_TOP: float = 208.0       # 距顶部（避开战斗顶栏 chips + 右上战况条）
const _TOAST_MARGIN_RIGHT: float = 24.0
const _TOAST_WIDTH: float = 300.0
# 记录7#5: 战斗中的"战斗信息提示"两轮实机反馈"还是在右上角"——战斗态挪到顶中
# （战报播报带之下、战况条同高但水平错开），非战斗态维持右上角小堆叠。
const _TOAST_BATTLE_TOP: float = 150.0

# 记录5#10: 左下 feed 通道（获得/解锁类低优先级提示）——底缘抬高避开战斗日志折叠态
# 与基地底栏，向上堆叠。
const _FEED_MARGIN_LEFT: float = 16.0
const _FEED_MARGIN_BOTTOM: float = 150.0
const _FEED_WIDTH: float = 340.0


func _ready() -> void:
	# v6.6: 连接 SignalBus.show_toast，使全局 toast 提示（战斗/城市/背包等）能到达 ToastManager
	# 之前此信号全程无连接，导致所有 SignalBus.show_toast.emit(...) 静默失效
	SignalBus.show_toast.connect(show_toast)
	# 记录5#10：获得/解锁类提示走左下 feed 通道（右上角留操作反馈）
	if SignalBus.has_signal("feed_message") and not SignalBus.feed_message.is_connected(show_feed):
		SignalBus.feed_message.connect(show_feed)
	# 记录7#5: 战斗态锚点切换（battle_ended 带 player_won 参数，单独Handler吃掉）
	if SignalBus.has_signal("battle_started") and not SignalBus.battle_started.is_connected(_on_battle_started_anchor):
		SignalBus.battle_started.connect(_on_battle_started_anchor)
	if SignalBus.has_signal("battle_ended") and not SignalBus.battle_ended.is_connected(_on_battle_ended_anchor):
		SignalBus.battle_ended.connect(_on_battle_ended_anchor)
	# P1-6: 成就解锁视觉提示——v6.38 起由 achievement_manager 显式 emit feed_message
	# （左下 feed 通道），本钩子移除（原钩子+manager 显式 toast = 同一条成就弹两次）。
	_build_toast_layer()


func _on_achievement_unlocked(_achievement_id: String, achievement_name: String) -> void:
	# v6.38：保留函数防外部 connect 断链——视觉提示统一走 achievement_manager 的
	# feed_message（左下 feed），此处不再重复弹 toast。
	pass


## 记录7#5: 战斗中顶中 / 战斗外右上 的容器锚点切换。
## card_info_panel._avoid_toast_zone 读容器实时 rect 求交避让，容器搬家自动跟随。
func _on_battle_started_anchor() -> void:
	_apply_toast_anchor(true)


func _on_battle_ended_anchor(_player_won: bool) -> void:
	_apply_toast_anchor(false)


func _apply_toast_anchor(in_battle: bool) -> void:
	if _toast_container == null or not is_instance_valid(_toast_container):
		return
	if in_battle:
		_toast_container.anchor_left = 0.5
		_toast_container.anchor_right = 0.5
		_toast_container.anchor_top = 0.0
		_toast_container.anchor_bottom = 0.0
		_toast_container.offset_left = -_TOAST_WIDTH / 2.0
		_toast_container.offset_right = _TOAST_WIDTH / 2.0
		_toast_container.offset_top = _TOAST_BATTLE_TOP
		_toast_container.offset_bottom = _TOAST_BATTLE_TOP
	else:
		_toast_container.anchor_left = 1.0
		_toast_container.anchor_right = 1.0
		_toast_container.anchor_top = 0.0
		_toast_container.anchor_bottom = 0.0
		_toast_container.offset_left = -_TOAST_MARGIN_RIGHT - _TOAST_WIDTH
		_toast_container.offset_right = -_TOAST_MARGIN_RIGHT
		_toast_container.offset_top = _TOAST_MARGIN_TOP
		_toast_container.offset_bottom = _TOAST_MARGIN_TOP


## 构建独立 CanvasLayer（layer=200）+ 右上角 VBox 堆叠容器 + 左下 feed 容器。
## toast 加到 VBox 下自动垂直排列，不会全叠在 (0,0)。v6.38：幂等（容器存活时不重建）。
func _build_toast_layer() -> void:
	if is_instance_valid(_toast_layer) and is_instance_valid(_toast_container):
		return
	if is_instance_valid(_toast_layer):
		_toast_layer.queue_free()
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
	# 记录5#10：左下 feed 堆叠容器（获得/解锁类；grow BEGIN=向上生长）
	_feed_container = VBoxContainer.new()
	_feed_container.name = "FeedContainer"
	_feed_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed_container.anchor_left = 0.0
	_feed_container.anchor_right = 0.0
	_feed_container.anchor_top = 1.0
	_feed_container.anchor_bottom = 1.0
	_feed_container.offset_left = _FEED_MARGIN_LEFT
	_feed_container.offset_right = _FEED_MARGIN_LEFT + _FEED_WIDTH
	_feed_container.offset_top = -_FEED_MARGIN_BOTTOM
	_feed_container.offset_bottom = -_FEED_MARGIN_BOTTOM
	_feed_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_feed_container.grow_horizontal = Control.GROW_DIRECTION_END
	_feed_container.add_theme_constant_override("separation", 6)
	_feed_container.alignment = BoxContainer.ALIGNMENT_END
	_toast_layer.add_child(_feed_container)
	add_child(_toast_layer)


## 供外部（如 toast_utils）复用高 z-order 的 toast layer。
func get_toast_layer() -> CanvasLayer:
	return _toast_layer


## 供外部（如 toast_utils）复用 toast 堆叠容器（推荐用这个，自动堆叠）。
func get_toast_container() -> VBoxContainer:
	return _toast_container


func show_toast(message: String, duration: float = 2.0, color: Color = Color(0.2, 0.8, 0.3), parent: Control = null) -> void:
	# v6.38（记录5#14）：容器失效一律重建独立层——旧的"回退 root 第一个 Control"会把
	# toast 落进主画布与 PopupLayer(100)/拖拽预览按树序混排（提示盖卡图/卡框盖提示交替
	# 出现的根因）。CanvasLayer(200) 恒在所有面板之上，不存在中间态。
	var target: Control = parent
	if target == null:
		if not is_instance_valid(_toast_container):
			_build_toast_layer()
		target = _toast_container
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
	# v6.52: 同帧 burst 滴流（战后结算 10+ 条同帧）——池满且本帧已直接创建过则入队
	if _maybe_enqueue_burst(message, duration, color, false):
		return
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
	show_toast(message, 2.5, Color(0.937, 0.267, 0.267), parent)

func show_warning(message: String, parent: Control = null) -> void:
	show_toast(message, 2.0, Color(0.9, 0.6, 0.2), parent)


## 记录5#10：左下 feed 通道——获得/解锁类低优先级提示（用户拍板不进右上角）。
## 同 left-bottom 容器堆叠、向上生长；颜色偏柔和（信息属性非告警）。
func show_feed(message: String, duration: float = 2.6, color: Color = Color(0.30, 0.62, 0.42)) -> void:
	if not is_instance_valid(_feed_container):
		_build_toast_layer()
	if not is_instance_valid(_feed_container):
		return
	# P1-7 同款同文案合并（feed 更易连发：批量掉落/多系统解锁）
	if _merge_map.has(message):
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
		_merge_map.erase(message)
	# v6.52: 同帧 burst 滴流（feed 更易连发：批量掉落/多系统解锁）
	if _maybe_enqueue_burst(message, duration, color, true):
		return
	while active_toasts.size() >= MAX_ACTIVE_TOASTS:
		_evict_oldest_toast()
	var panel = _create_toast_panel(message, color, _feed_container)
	_feed_container.add_child(panel)
	active_toasts.append(panel)
	var lbl: Label = panel.get_meta("toast_label", null)
	var tw2 = create_tween()
	_merge_map[message] = {"panel": panel, "label": lbl, "count": 1, "tween": tw2}
	_animate_toast(panel, duration, tw2)


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


## （v6.38 已删：旧的"回退 root 第一个 Control"路径会把 toast 落进主画布造成层级混排，
## 容器失效一律经 _build_toast_layer 重建独立层。）

## ═══ v6.52（记录1#16）同帧 burst 滴流 ═══

## 池满且本帧已有直接创建 → 入队返回 true（延迟显示）；否则返回 false 走即时路径。
func _maybe_enqueue_burst(message: String, duration: float, color: Color, feed: bool) -> bool:
	if active_toasts.size() < MAX_ACTIVE_TOASTS:
		return false
	var frame := Engine.get_process_frames()
	if _burst_frame != frame:
		_burst_frame = frame   # 本帧第一条：照旧驱逐最旧并直接显示
		return false
	_pending_queue.append({"message": message, "duration": duration, "color": color, "feed": feed})
	_ensure_drain_timer()
	return true

func _ensure_drain_timer() -> void:
	if _drain_timer != null and is_instance_valid(_drain_timer):
		return
	_drain_timer = Timer.new()
	_drain_timer.wait_time = _BURST_DRAIN_INTERVAL
	_drain_timer.one_shot = false
	_drain_timer.timeout.connect(_drain_pending_queue)
	add_child(_drain_timer)
	_drain_timer.start()

func _drain_pending_queue() -> void:
	if _pending_queue.is_empty():
		_drain_timer.stop()
		return
	if active_toasts.size() >= MAX_ACTIVE_TOASTS:
		return
	var item: Dictionary = _pending_queue.pop_front()
	if bool(item.get("feed", false)):
		show_feed(String(item["message"]), float(item["duration"]), item["color"])
	else:
		show_toast(String(item["message"]), float(item["duration"]), item["color"])
