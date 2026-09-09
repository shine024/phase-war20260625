class_name SortieInterstitial
extends CanvasLayer
## 批次③ Task 1：出征过场（批次③计划书 Task 1，裁决 A2「黑屏战报」）。
## 黑屏全屏 + 目的地行 + 战报行组 + 单一暖橙横线扫过（0.6s，全屏唯一暖色）；
## ESC / 点击任意处立即 skip（emit finished）。
##
## 用法（main_battle_setup.run_start_battle_sequence 头部消费拍点）：
##   await SortieInterstitial.present("第 1 关 · 一战", ["车队向目标阵地开进。"])
##
## 实现要点：
## - 挂 /root（CanvasLayer 400）：PopupLayer=100 / Toast=200 之上，SceneTransition=500 之下
##   ——场景切换黑遮罩盖在本层之上，黑屏期间无闪帧；
## - 战场活于 main.tscn SubViewport，本层只是黑屏上的 UI 层：不切场景、不碰 battle_ended
##   信号协议（旁听者 8+）；
## - 静态入口命名 present 而非 show：CanvasLayer 自带实例方法 show()，同名静态函数会被
##   引擎判为覆写冲突；
## - 节点驱动而非 static 协程——避开 GDScript 无引用协程可能被 GC 的坑（同 SceneTransition）。

signal finished

## 出征战拍点 meta：出征入口写（truck_base._launch_battle / world_map._enter_level_from_popup），
## main_battle_setup.run_start_battle_sequence 头部一次性消费。挂机推图链与教程首战不带此
## meta，不触发过场。
const META_PENDING := "sortie_beat_pending"

const LAYER_ORDER := 400
const TEXT_FADE_SEC := 0.18
const LINE_SWEEP_SEC := 0.6            # 计划书：横线 0.6s 从左 20% 扫到 80%
const FADE_OUT_SEC := 0.12             # 结束/跳过后揭幕淡出（skip 后战场 ≤0.5s 可见预算内）
const DEFAULT_DURATION := 1.5          # 计划书 A2：黑屏 1.2-1.8s（取中偏下，给转场留 2.5s 总预算）
const MOTION_REDUCE_DURATION := 0.6
const COLOR_WARM := Color(0.961, 0.620, 0.043, 1)   # = DesignTokens.COLOR_AMBER（暖橙）

static var _active: SortieInterstitial = null

var _duration: float = DEFAULT_DURATION
var _dest_text: String = ""
var _lines: Array[String] = []
var _root: Control = null
var _text_box: VBoxContainer = null
var _line: ColorRect = null
var _done: bool = false
var _tween: Tween = null


## 出征过场入口：创建全屏黑屏战报层并返回 finished 信号（await 之）。
## 树不可用（理论上不发生）时返回一个下一帧即发的空信号，调用方零等待直通。
static func present(dest_text: String, lines: Array[String], duration: float = DEFAULT_DURATION) -> Signal:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		push_warning("[SortieInterstitial] 无可用场景树，过场跳过")
		return _instant_finished_signal()
	if _active != null and is_instance_valid(_active):
		_active.request_skip()   # 防重入：上一张未收尾的过场立即让位
	var inst: SortieInterstitial = SortieInterstitial.new()
	inst._dest_text = dest_text
	inst._lines = lines.duplicate()
	inst._duration = maxf(0.2, duration)
	tree.root.add_child(inst)
	_active = inst
	return inst.finished


class _InstantFire:
	extends RefCounted
	signal finished

	func _init() -> void:
		# 下一帧再发：await 侧先挂上连接，避免"先发后听"丢拍
		call_deferred("_fire")

	func _fire() -> void:
		finished.emit()


static func _instant_finished_signal() -> Signal:
	var h := _InstantFire.new()
	return h.finished


func _ready() -> void:
	add_to_group("sortie_interstitial")
	layer = LAYER_ORDER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	# 等一帧：黑底先落一拍，再起文本/横线
	await get_tree().process_frame
	if _done or not is_inside_tree():
		return
	_play_timeline()


func _exit_tree() -> void:
	if _active == self:
		_active = null


func _build_ui() -> void:
	var reduce: bool = DesignTokens.is_motion_reduce()
	_root = Control.new()
	_root.name = "SortieReport"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var bg := ColorRect.new()
	bg.name = "Blackout"
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)

	# 战报文本带（屏幕 34%~52% 高度带，全宽居中）
	_text_box = VBoxContainer.new()
	_text_box.name = "ReportLines"
	_text_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_text_box.anchor_top = 0.34
	_text_box.anchor_bottom = 0.52
	_text_box.offset_left = 40.0
	_text_box.offset_right = -40.0
	_text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_text_box.add_theme_constant_override("separation", 10)
	_text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_text_box)

	var dest := Label.new()
	dest.name = "DestLine"
	dest.text = _dest_text
	dest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dest.add_theme_font_size_override("font_size", 26)
	dest.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_BRIGHT)
	_text_box.add_child(dest)

	for line in _lines:
		var l := Label.new()
		l.name = "ReportLine"
		l.text = line
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_DIM)
		_text_box.add_child(l)

	# 单一暖橙横线：锚点 20%→80%（Tween anchor_right，分辨率无关）
	_line = ColorRect.new()
	_line.name = "WarmLine"
	_line.color = COLOR_WARM
	_line.anchor_left = 0.2
	_line.anchor_right = 0.2
	_line.anchor_top = 0.56
	_line.anchor_bottom = 0.56
	_line.offset_top = -1.0
	_line.offset_bottom = 1.0
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_line)

	# 跳过提示（弱化到角落，不参与战报正文）
	var hint := Label.new()
	hint.name = "SkipHint"
	hint.text = "ESC 跳过"
	hint.add_theme_font_size_override("font_size", 11)
	var dim := DesignTokens.COLOR_TEXT_DIM
	hint.add_theme_color_override("font_color", Color(dim.r, dim.g, dim.b, 0.7))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -110.0
	hint.offset_top = -34.0
	hint.offset_right = -16.0
	hint.offset_bottom = -14.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hint)

	if reduce:
		_line.anchor_right = 0.8
	else:
		_text_box.modulate.a = 0.0


func _play_timeline() -> void:
	_tween = create_tween()
	if DesignTokens.is_motion_reduce():
		# 减少动效：无扫线无淡入，短驻留即走（对齐 SceneTransition 的降档策略）
		_tween.tween_interval(MOTION_REDUCE_DURATION)
		_tween.tween_callback(_finish)
		return
	_tween.tween_property(_text_box, "modulate:a", 1.0, TEXT_FADE_SEC)
	# 横线与文本淡入同step并行（自身再延 0.15s 起扫）：0.15+0.6=0.75s 处收束
	_tween.parallel().tween_property(_line, "anchor_right", 0.8, LINE_SWEEP_SEC) \
		.set_delay(0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_interval(maxf(0.1, _duration - LINE_SWEEP_SEC - 0.15))
	_tween.tween_callback(_finish)


func _input(event: InputEvent) -> void:
	if _done:
		return
	var skip := false
	if event.is_action_pressed("ui_cancel"):
		skip = true
	elif event is InputEventMouseButton and event.pressed:
		skip = true
	if skip:
		get_viewport().set_input_as_handled()
		request_skip()


## 立即收尾（ESC/点击/防重入共用）
func request_skip() -> void:
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _active == self:
		_active = null
	# 先发 finished（await 侧随即开战/亮战场），本层再快速淡出揭幕
	finished.emit()
	if _root != null and is_instance_valid(_root):
		var tw := create_tween()
		tw.tween_property(_root, "modulate:a", 0.0, FADE_OUT_SEC)
		tw.finished.connect(queue_free)
	else:
		queue_free()
