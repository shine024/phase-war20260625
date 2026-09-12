extends Node
class_name PhaseMasterSkillHost
## ═══════════════════════════════════════════════════════════
##  v25.4 相位师技能树统一启动器（A2 相位师成长页合并·第一刀）
##
##  背景：技能点与属性点同源（相位场等级），但入口分居两处——属性点在
##  phase_instrument_selector（底栏等级标签点击），技能树在 growth_panel 的
##  「技能树」按钮。本启动器把技能面板的宿主逻辑（root 级 CanvasLayer(110) +
##  Backdrop + 面板实例）从 growth_panel 抽成常驻节点，供两处共用：
##    · growth_panel「技能树」按钮 → host.open(tree, full_bleed=true)
##    · phase_instrument_selector 属性页「技能点」行 → host.open(tree, false)
##    · 技能面板状态行「属性点分配 →」反向跳回 selector（闭环）
##
##  独立成常驻节点的两个动机：
##  1. growth_panel 是可被懒加载修剪的面板（UILazyLoader 真懒加载全集成员），
##     此前由它持有 backdrop 的 gui_input 连接，修剪后悬空；host 挂 /root 常驻。
##  2. selector 打开技能面板时（growth 不在场）ESC 关闭有归属（host._input）。
##
##  节点命名与旧版完全一致（PhaseMasterSkillCanvas / PhaseMasterSkillPanel），
##  growth_panel 的按名查找关闭/ESC 链零改动。
## ═══════════════════════════════════════════════════════════

signal closed()

const DT = preload("res://resources/design_tokens.gd")
const PANEL_SCENE := "res://scenes/ui/phase_master_skill_panel.tscn"

## 打开（或复用）技能树面板。full_bleed=true 时铺满视口（growth 全出血惯例），
## false 时标准 960×640 居中（selector 之上的 drill-down 观感）。
static func open(tree: SceneTree, full_bleed: bool = true) -> Node:
	if tree == null or tree.root == null:
		return null
	var host: Node = tree.root.get_node_or_null("PhaseMasterSkillHost")
	if host == null:
		host = load("res://scripts/ui/phase_master_skill_host.gd").new()
		host.name = "PhaseMasterSkillHost"
		tree.root.add_child(host)
	host._open(full_bleed)
	return host

func _open(full_bleed: bool) -> void:
	FeatureUnlockPopup.show_once("skill_tree", "相位师技能树",
		"消耗技能点学习全局被动强化（指挥/智能化/火力/概念武器）。技能点随相位场等级获得。")
	var canvas: CanvasLayer = get_node_or_null("PhaseMasterSkillCanvas")
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "PhaseMasterSkillCanvas"
		canvas.layer = 110  # 高于 PopupLayer(100) 与各 overlay 的 Backdrop
		add_child(canvas)
		# 自带全屏 backdrop：拦截外部点击（点击空白处关闭），把面板与下层面板隔离
		var backdrop := ColorRect.new()
		backdrop.name = "Backdrop"
		backdrop.color = DT.COLOR_BACKDROP
		backdrop.anchors_preset = Control.PRESET_FULL_RECT
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		backdrop.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		backdrop.gui_input.connect(_on_backdrop_gui_input)
		canvas.add_child(backdrop)
	var panel: Node = canvas.get_node_or_null("PhaseMasterSkillPanel")
	if panel == null:
		var scene: PackedScene = load(PANEL_SCENE)
		if scene == null:
			push_error("[PhaseMasterSkillHost] 无法加载技能树面板场景")
			return
		panel = scene.instantiate()
		if panel == null:
			push_error("[PhaseMasterSkillHost] 技能树面板实例化失败")
			return
		canvas.add_child(panel)
		if panel.has_signal("closed") and not panel.closed.is_connected(_on_panel_closed):
			panel.closed.connect(_on_panel_closed)
	if panel is Control and "full_bleed" in panel:
		panel.set("full_bleed", full_bleed)
		if panel.has_method("_apply_viewport_fit"):
			panel.call("_apply_viewport_fit")
	# 批次1：收口统一开合（原 visible 硬切无声）——open_layer 处理面板淡入弹出、
	# backdrop 同步、canvas 收尾 tween 竞态守卫；开合音对齐 main overlay。
	if panel is Control:
		PanelAnim.open_layer(canvas, panel, canvas.get_node_or_null("Backdrop"))
	else:
		panel.visible = true
		canvas.visible = true
	if panel.has_method("_refresh"):
		panel.call("_refresh")
	if SignalBus and SignalBus.has_signal("play_sound"):
		SignalBus.play_sound.emit("panel_open")

func _on_panel_closed() -> void:
	close()
	closed.emit()

func _on_backdrop_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		close()
		closed.emit()

## 隐藏面板（连 CanvasLayer 一起，彻底释放点击拦截；退出全出血供下次开档切换）
## 批次1：统一淡出（0.15s）后再藏 canvas——close_layer 处理 backdrop 同步淡出
## 与收尾 tween 竞态守卫（_open 侧重开时杀掉）。
func close() -> void:
	var canvas: CanvasLayer = get_node_or_null("PhaseMasterSkillCanvas")
	if canvas == null:
		return
	var p: Node = canvas.get_node_or_null("PhaseMasterSkillPanel")
	if p != null and "full_bleed" in p:
		p.set("full_bleed", false)
	if p is Control:
		PanelAnim.close_layer(canvas, p, canvas.get_node_or_null("Backdrop"))
	else:
		canvas.visible = false
	if SignalBus and SignalBus.has_signal("play_sound"):
		SignalBus.play_sound.emit("panel_close")

## ESC 先关技能面板——canvas(110) 悬在 PopupLayer(100) 之上，不 consume 会
## 连带关掉底下面板。growth_panel 的同款 _input 并存无害（双方都幂等隐藏）。
func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE):
		return
	var canvas: CanvasLayer = get_node_or_null("PhaseMasterSkillCanvas")
	if canvas != null and canvas.visible:
		close()
		closed.emit()
		get_viewport().set_input_as_handled()
