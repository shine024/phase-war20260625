extends RefCounted
class_name PanelAnim
## 批次1（拼凑感修复·一致性收口）：统一面板开合动画单一真身。
## 从 main.gd _animate_overlay_in/out（v25 UI 规格）原样抽出，供旁路面板
## （相位师/技能树/卡车基地内嵌面板/标题屏弹窗）与 main 17 个 overlay 共用。
##
## 规格零变化：淡入 0.2s SINE + 内容 0.25s TRANS_BACK 弹出；淡出 0.15s 后隐藏；
## is_motion_reduce() 短路瞬切；close_tween meta 防"淡出途中重开"竞态。
##
## 本组件不播音效——_close_all_overlays 群关 15 面板时若各自发声会 15 重奏，
## 开合音（panel_open/panel_close）归调用点，与 main.gd _open/_close_overlay 现行约定一致。
##
## 无 await 协程（SceneTransition 注释的"无引用协程可被 GC"坑）——缩放枢轴的
## 一帧延迟用 tween 串行 callback 实现，等价于旧版的 await process_frame。

const DT = preload("res://resources/design_tokens.gd")

const CLOSE_TWEEN_META := "close_tween"
# 重复 open 守卫（UI 四级标准修复 R-A2：card_info_panel 隐藏→快速重开场景）——
# 杀掉上一轮未完成的淡入/弹出 tween，防双 tween 同帧竞写 modulate/scale。
const OPEN_TWEEN_META := "open_tween"
const OPEN_TWEEN_POP_META := "open_tween_pop"

## 内容缩放子节点命名兼容：main 系 overlay=CenterContainer；truck_base 嵌入链=EmbedCenter
static func _content_of(overlay: Control) -> Control:
	var cc := overlay.get_node_or_null("CenterContainer") as Control
	if cc == null:
		cc = overlay.get_node_or_null("EmbedCenter") as Control
	return cc


## 打开动画：overlay 需已 visible=true（与 main._open_overlay 先显示再动画同序）。
static func open(overlay: Control) -> void:
	_kill_pending_close(overlay)
	_kill_pending_open(overlay)
	if DT.is_motion_reduce():
		overlay.modulate.a = 1.0
		return
	var cc := _content_of(overlay)
	overlay.modulate.a = 0.0
	var tw := overlay.create_tween()
	overlay.set_meta(OPEN_TWEEN_META, tw)
	tw.tween_property(overlay, "modulate:a", 1.0, DT.MOTION_FADE_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if cc == null:
		return
	# 旧版此处 await 一帧取布局后真实 size 作缩放枢轴；tween callback 首帧执行
	# 天然等价（tween 下帧才开始推进），且无协程 GC 风险
	var tw2 := overlay.create_tween()
	overlay.set_meta(OPEN_TWEEN_POP_META, tw2)
	tw2.tween_callback(func() -> void:
		if not is_instance_valid(overlay) or not overlay.visible:
			tw2.kill()
			return
		cc.pivot_offset = cc.size * 0.5
		cc.scale = Vector2(0.96, 0.96)
	)
	tw2.tween_property(cc, "scale", Vector2.ONE, DT.MOTION_POP) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _kill_pending_open(overlay: Control) -> void:
	for meta_name in [OPEN_TWEEN_META, OPEN_TWEEN_POP_META]:
		if not overlay.has_meta(meta_name):
			continue
		var pending: Variant = overlay.get_meta(meta_name)
		if pending is Tween and (pending as Tween).is_valid():
			(pending as Tween).kill()
		overlay.remove_meta(meta_name)


## 关闭动画：淡出 0.15s 后 visible=false 并复位 modulate/scale。
static func close(overlay: Control) -> void:
	if DT.is_motion_reduce():
		overlay.visible = false
		return
	_kill_pending_close(overlay)
	var cc := _content_of(overlay)
	var tw := overlay.create_tween()
	overlay.set_meta(CLOSE_TWEEN_META, tw)
	tw.tween_property(overlay, "modulate:a", 0.0, DT.MOTION_FADE_OUT) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		overlay.visible = false
		overlay.modulate.a = 1.0
		if is_instance_valid(cc):
			cc.scale = Vector2.ONE
	)


## 杀掉未完成的关闭 tween（淡出途中重开场景），与 main 版守卫一致
static func _kill_pending_close(overlay: Control) -> void:
	if not overlay.has_meta(CLOSE_TWEEN_META):
		return
	var pending: Variant = overlay.get_meta(CLOSE_TWEEN_META)
	if pending is Tween and (pending as Tween).is_valid():
		(pending as Tween).kill()


# ── CanvasLayer 宿主适配（标题屏设置弹窗 / 技能树面板）──
## CanvasLayer 无 modulate——动画落在内容 Control 上，backdrop（若给）同步淡入淡出，
## 淡出完成后隐藏 layer 释放点击拦截（立即藏会截断内容淡出）。收尾 tween 挂 layer
## 的 close_tween meta，重开时 open_layer 杀掉防竞态。

static func open_layer(layer: CanvasLayer, content: Control, backdrop: CanvasItem = null) -> void:
	_kill_pending_close_meta(layer)
	if backdrop != null:
		backdrop.modulate.a = 1.0
	layer.visible = true
	content.visible = true
	open(content)


static func close_layer(layer: CanvasLayer, content: Control, backdrop: CanvasItem = null) -> void:
	if DT.is_motion_reduce():
		layer.visible = false
		content.visible = false
		return
	_kill_pending_close_meta(layer)
	close(content)
	var tw := layer.create_tween()
	layer.set_meta(CLOSE_TWEEN_META, tw)
	if backdrop != null:
		tw.tween_property(backdrop, "modulate:a", 0.0, DT.MOTION_FADE_OUT) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		layer.visible = false
		if backdrop != null and is_instance_valid(backdrop):
			backdrop.modulate.a = 1.0
	)


static func _kill_pending_close_meta(host: Node) -> void:
	if not host.has_meta(CLOSE_TWEEN_META):
		return
	var pending: Variant = host.get_meta(CLOSE_TWEEN_META)
	if pending is Tween and (pending as Tween).is_valid():
		(pending as Tween).kill()
	host.remove_meta(CLOSE_TWEEN_META)


# ── 批次2：微交互 ──

const PRESS_SCALE := 0.97
const PRESS_DOWN_SEC := 0.05
const PRESS_UP_SEC := 0.12
const CONTENT_FADE_SEC := 0.18
const PRESS_TWEEN_META := "press_tween"
const CONTENT_TWEEN_META := "content_tween"


## 批次2：全局按钮按压微动效——按下缩小 0.97，松开回弹（TRANS_BACK 轻微过冲）。
## 由 AudioManager 的 node_added 钩子统一接入所有 BaseButton。button_up 在禁用/
## 拖出释放等所有路径都会触发（BaseButton._unpress 兜底），无卡死态；
## motion_reduce 时按下不缩（松开归位幂等无害）。
static func attach_press_feedback(btn: BaseButton) -> void:
	if btn.has_meta(PRESS_TWEEN_META + "_armed"):
		return
	btn.set_meta(PRESS_TWEEN_META + "_armed", true)
	btn.button_down.connect(func() -> void:
		if not is_instance_valid(btn) or DT.is_motion_reduce():
			return
		_kill_meta_tween(btn, PRESS_TWEEN_META)
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		btn.set_meta(PRESS_TWEEN_META, tw)
		tw.tween_property(btn, "scale", Vector2(PRESS_SCALE, PRESS_SCALE), PRESS_DOWN_SEC) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	btn.button_up.connect(func() -> void:
		if not is_instance_valid(btn):
			return
		_kill_meta_tween(btn, PRESS_TWEEN_META)
		var tw := btn.create_tween()
		btn.set_meta(PRESS_TWEEN_META, tw)
		tw.tween_property(btn, "scale", Vector2.ONE, PRESS_UP_SEC) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)


## 批次2：tab/列表切换后的内容微过渡——modulate 0→1 淡入（0.18s）。
## 只动 modulate 不动 position/scale（容器子节点的布局属性会被下一次排序覆盖打架）。
static func fade_content_in(ctrl: Control) -> void:
	if ctrl == null or not is_instance_valid(ctrl):
		return
	_kill_meta_tween(ctrl, CONTENT_TWEEN_META)
	if DT.is_motion_reduce():
		ctrl.modulate.a = 1.0
		return
	ctrl.modulate.a = 0.0
	var tw := ctrl.create_tween()
	ctrl.set_meta(CONTENT_TWEEN_META, tw)
	tw.tween_property(ctrl, "modulate:a", 1.0, CONTENT_FADE_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## S4 手柄菜单导航：把焦点落到面板内第一个可聚焦控件（十字键/摇杆即可移动）。
## 仅在检测到手柄连接时生效——纯键鼠用户不吞焦点环；延迟一帧调用由调用方
## call_deferred 负责（等面板布局落定再 grab）。
static func focus_first(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	if Input.get_connected_joypads().is_empty():
		return
	var first := _first_focusable(root)
	if first != null:
		first.grab_focus()


static func _first_focusable(node: Node) -> Control:
	var c := node as Control
	if c != null and c.focus_mode != Control.FOCUS_NONE and c.is_visible_in_tree():
		var b := c as BaseButton
		if b == null or not b.disabled:
			return c
	for child in node.get_children():
		var found := _first_focusable(child)
		if found != null:
			return found
	return null


static func _kill_meta_tween(host: Node, meta_name: String) -> void:
	if not host.has_meta(meta_name):
		return
	var pending: Variant = host.get_meta(meta_name)
	if pending is Tween and (pending as Tween).is_valid():
		(pending as Tween).kill()
