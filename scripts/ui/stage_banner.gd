class_name StageBanner
extends CanvasLayer
## 批次3（流程缝合）：全屏中央战报横幅——直开入战「交战开始」/ 结算回整备「返回整备」。
## 视觉方言对齐 SortieInterstitial（黑带 + 白字 + 暖橙细线），与其构成同一套军语
## 过场体系：战报(400) 是重仪式（出征 1.5s 黑屏），本横幅(350) 是轻节拍（~1s 不挡操作）。
##
## 要点：
## - mouse_filter 全链 IGNORE——横幅出现时战斗已在跑/操作已恢复，绝不拦点击；
## - 不切场景、不碰信号协议、不暂停（纯装饰层，node 驱动自清理）；
## - 防重入：上一条未收尾时立即让位（快速连打"开始战斗"不堆叠）；
## - motion_reduce 降档：无淡入淡出，0.5s 驻留即走。

const LAYER_ORDER := 350
const FADE_IN_SEC := 0.15
const HOLD_SEC := 0.6
const FADE_OUT_SEC := 0.25
const MOTION_REDUCE_SEC := 0.5
const COLOR_WARM := Color(0.961, 0.620, 0.043, 1)   # = DesignTokens.COLOR_AMBER（同 SortieInterstitial）

static var _active: StageBanner = null

var _text: String = ""
var _root: Control = null
var _tween: Tween = null
var _done: bool = false


## 横幅入口（静态，fire-and-forget）。树不可用时静默跳过——横幅是装饰，
## 任何环境缺失都不该影响主流程。
static func post(text: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	if _active != null and is_instance_valid(_active):
		_active._finish()   # 防重入：上一条立即让位
	var inst := StageBanner.new()
	inst._text = text
	tree.root.add_child(inst)
	_active = inst


## v30.2 R4：演出串入口——按序逐条播完（[时代独白…, 驻守台词…, 交战开始]）。
## 与单条 post 的分工：post=交互节拍（立即让位插队）；post_queue=叙事演出（严格串行，
## 每条走完完整淡入-驻留-淡出生命周期才轮下一条）。空闲时立即起泵；占用中入队等续。
static var _queue: Array[String] = []

static func post_queue(lines: Array) -> void:
	for line in lines:
		var text := String(line)
		if not text.is_empty():
			_queue.append(text)
	_pump()


## 泵：仅在空闲（无活动横幅）时取队首播一条；占用中由 _finish/_exit_tree 续泵。
static func _pump() -> void:
	if _active != null and is_instance_valid(_active):
		return
	if _queue.is_empty():
		return
	post(_queue.pop_front())


func _ready() -> void:
	layer = LAYER_ORDER
	_build()
	if DesignTokens.is_motion_reduce():
		_tween = create_tween()
		_tween.tween_interval(MOTION_REDUCE_SEC)
		_tween.tween_callback(_finish)
		return
	_root.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 1.0, FADE_IN_SEC)
	_tween.tween_interval(HOLD_SEC)
	_tween.tween_property(_root, "modulate:a", 0.0, FADE_OUT_SEC)
	_tween.tween_callback(_finish)


func _exit_tree() -> void:
	if _active == self:
		_active = null


func _build() -> void:
	_root = Control.new()
	_root.name = "StageBanner"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# 黑带：屏幕 45%~55% 高度带，全宽，半透明黑
	var band := ColorRect.new()
	band.name = "Band"
	band.color = Color(0, 0, 0, 0.78)
	band.anchor_top = 0.45
	band.anchor_bottom = 0.55
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(band)

	# 文本：带内居中，白字加粗（标题字体，同 PanelChrome 标题档）
	var label := Label.new()
	label.name = "BannerText"
	label.text = _text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", DesignTokens.get_title_font_bold())
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_BRIGHT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)

	# 暖橙细线：黑带底缘上方，全宽 20%→80%（同战报横线的锚点语言）
	var line := ColorRect.new()
	line.name = "WarmLine"
	line.color = COLOR_WARM
	line.anchor_left = 0.2
	line.anchor_right = 0.8
	line.anchor_top = 0.55
	line.anchor_bottom = 0.55
	line.offset_top = -7.0
	line.offset_bottom = -5.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(line)


func _finish() -> void:
	if _done:
		return
	_done = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	# v30.2 R4：先让位再续泵（tween 回调=正常处理阶段，add_child 安全）。不在
	# _exit_tree 泵——删除阶段里 add_child 的横幅其 tween 不再推进（实测第三条饿死）。
	if _active == self:
		_active = null
	queue_free()
	_pump()
