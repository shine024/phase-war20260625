extends Node
class_name SceneTransition
## v26.11(A2.1): 全局场景转场管理器——黑屏淡入 → 切场景 → 淡出。
## 背景：全项目 25 处 get_tree().change_scene_to_file() 裸切，无任何过渡反馈，
## 是打磨层"生硬感"的主要来源（品质差距调研 A2 轨）。
##
## 用法（替换裸切）：
##   SceneTransition.change(get_tree(), "res://scenes/main.tscn")
##
## 实现要点：
## - 转场节点与遮罩 CanvasLayer(layer=500) 挂在 root 下——跨场景切换存续，
##   淡出完成后自清理；
## - 防重入：转场进行中再次调用 → 直接裸切兜底（不吞导航）；
## - 遮罩 MOUSE_FILTER_STOP 挡住转场期误点；
## - 减少动效（DesignTokens.is_motion_reduce）→ 近瞬时切换（0.05s）；
## - 节点驱动而非 static 协程——避开 GDScript 无引用协程可能被 GC 的坑。

const FADE_IN_SEC := 0.18
const FADE_OUT_SEC := 0.22
const REDUCED_MOTION_SEC := 0.05
const LAYER_ORDER := 500  # PopupLayer=100 / Toast=200 之上，全屏遮罩最高层

static var _busy: bool = false

static func is_busy() -> bool:
	return _busy

## 场景切换入口（见类注释）。fade 期间输入被遮罩拦截。
static func change(tree: SceneTree, scene_path: String) -> void:
	if tree == null or tree.root == null:
		return
	if _busy:
		# 防重入兜底：正在转场时的导航请求直接裸切，不吞
		tree.change_scene_to_file(scene_path)
		return
	_busy = true
	var t := SceneTransition.new()
	t._scene_path = scene_path
	tree.root.add_child.call_deferred(t)

# ── 实例逻辑（由静态入口创建，挂 root）──
var _scene_path: String = ""
var _fi: float = FADE_IN_SEC
var _fo: float = FADE_OUT_SEC
var _layer: CanvasLayer = null
var _rect: ColorRect = null

func _ready() -> void:
	var DT := preload("res://resources/design_tokens.gd")
	if DT.is_motion_reduce():
		_fi = REDUCED_MOTION_SEC
		_fo = REDUCED_MOTION_SEC
	_layer = CanvasLayer.new()
	_layer.layer = LAYER_ORDER
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_rect)
	get_tree().root.add_child(_layer)
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, _fi)
	await tw.finished
	_switch_and_fade_out()

func _switch_and_fade_out() -> void:
	var tree := get_tree()
	if tree == null:
		_cleanup()
		return
	tree.change_scene_to_file(_scene_path)
	# 等一帧让新场景进树再淡出，避免旧帧闪回
	await tree.process_frame
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 0.0, _fo)
	await tw.finished
	_cleanup()

func _cleanup() -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
	_busy = false
	queue_free()
