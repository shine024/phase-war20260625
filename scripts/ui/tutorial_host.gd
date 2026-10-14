extends RefCounted
## v5 教程整合批（2026-10-13）：教程宿主统一门面（静态类，镜像 PhaseMasterSkillHost 模式）。
##
## 此前 main.gd / truck_base.gd 各持一份镜像实现（_show_tutorial_overlay(_local)、
## _tutorial_layer(_local)、_on_tutorial_pointer_requested、_maybe_spawn_tutorial_pointer），
## 历史至少三次分叉事故：v32.3 B2（overlay_requested 只挂 main，教学步在基地被静默
## 消费）、v6.53 #6（基地教程层画在 layer 0 被弹层盖死）、指路标宿主不同层收不掉。
## 本类收口三件事，场景侧只留薄委托 + 场景特有守卫（busy 谓词注入）：
##   1. ensure_layer   —— TutorialLayer(105) 懒建（层号契约 40<100<105教程<110<130<200，
##                        test_tutorial_overlay_z_order 锁）
##   2. show_overlay   —— tutorial_overlay.tscn 防重复挂载（存活检查不建层）
##   3. refresh_pointer / dismiss_pointer —— 点播段指路标（聚光 0.30 柔和档），
##                        busy=任一弹层面板开着（防"提示悬浮在面板上"，v6.52 记录1#18）
##
## 使用（场景 _ready / TPM 信号回调）：
##   TutorialHost.show_overlay(self)
##   TutorialHost.refresh_pointer(self, func() -> bool: return _is_any_overlay_open())

const TutorialSpotlight = preload("res://scripts/ui/tutorial_spotlight.gd")

const OVERLAY_SCENE := "res://scenes/ui/tutorial_overlay.tscn"
const LAYER_NAME := "TutorialLayer"
const LAYER_NUM := 105


## 教程框宿主层（懒建；幂等）。overlay 与指路标共用同一层——tutorial_overlay._ready
## 用 dismiss_step_pointer(get_parent()) 收旧标，只有同宿主才收得掉（v6.53 同律）。
static func ensure_layer(scene: Node) -> CanvasLayer:
	if scene == null:
		return null
	var layer := scene.get_node_or_null(LAYER_NAME) as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = LAYER_NAME
		layer.layer = LAYER_NUM
		scene.add_child(layer)
	return layer


## 场景内是否已有教程框（纯查询，不建层）。
static func has_overlay(scene: Node) -> bool:
	return scene != null and scene.get_node_or_null(LAYER_NAME + "/TutorialOverlay") != null


## 拉起教程框（防重复）。场景特例（如 main 的符文页对齐 deferred）由调用方自理。
## 与原 main/truck_base 实现同语义：不设树内守卫（离树实例也可挂——
## test_main_overlay_hosted_in_tutorial_layer 依赖该行为锁防重复挂载）。
static func show_overlay(scene: Node) -> void:
	if scene == null:
		return
	if has_overlay(scene):
		return
	var packed := load(OVERLAY_SCENE) as PackedScene
	if packed == null:
		push_error("[TutorialHost] 无法加载教程覆盖层场景")
		return
	var overlay := packed.instantiate()
	overlay.name = "TutorialOverlay"
	ensure_layer(scene).add_child(overlay)


## 亮/刷点播段指路标。busy：场景注入的"有弹层面板在屏"谓词（true 则不亮——面板关闭
## 时 notify_surface_closed 会重亮）。解析不到可见目标（无工位/门控锁定）静默不亮。
static func refresh_pointer(scene: Node, busy: Callable) -> void:
	if scene == null or not scene.is_inside_tree():
		return  # 拆场守卫（记录5#16 同律）：deferred 回调可能落在已出树的场景上
	if busy.is_valid() and bool(busy.call()):
		return
	var tpm: Node = scene.get_tree().root.get_node_or_null("/root/TutorialProgressionManager")
	if tpm == null or not tpm.has_method("get_pending_surface"):
		return
	var surface := String(tpm.get_pending_surface())
	if surface.is_empty():
		return
	var target: Control = TutorialSpotlight.resolve_target(scene, surface)
	if target == null or not target.is_visible_in_tree():
		return
	if bool(target.get_meta("gate_locked", false)):
		return  # 锁定工位点了只会弹解锁 toast，指它=误导
	TutorialSpotlight.show_step_pointer(ensure_layer(scene), target, String(tpm.get_pointer_tip()))


## 收指路标（幂等；宿主=教程层，与 show_step_pointer 同层）。
static func dismiss_pointer(scene: Node) -> void:
	if scene == null or not scene.is_inside_tree():
		return
	TutorialSpotlight.dismiss_step_pointer(scene.get_node_or_null(LAYER_NAME))


## 教程是否进行中（未完成/未跳过）。**一次性提示气泡（FeatureUnlockPopup.show_once）
## 的防重影统一判定口**——教程步正在教的面，气泡同刻再教一遍=同题双窗（250 层压在
## 教程框 105 之上）。suppress 期间 show_once 不被调用即不标 seen，教程完成后下次
## 触发原样补弹（跳过教程的玩家由此兜底），先例=truck_base_intro（v32.3 B1）。
## 调用方无需在树内（纯 /root 查询）。
static func is_tutorial_active() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var tpm: Node = tree.root.get_node_or_null("/root/TutorialProgressionManager")
	return tpm != null and tpm.has_method("should_show_tutorial") \
		and bool(tpm.should_show_tutorial())
