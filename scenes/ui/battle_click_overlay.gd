extends Control
## 覆盖在战场上：暂停/继续时都可点单位显示信息；信息框打开时点击框外自动关闭；单位部署选点
## v9.x（P2-7范围B）：主动法则选点施放链已随法则系统退役移除

const LawTargetIndicatorScript = preload("res://scenes/effects/law_target_indicator.gd")
const NodeFinder = preload("res://scripts/node_finder.gd")
const DEBUG_DEPLOY_CLICK_LOG := false

var _deploy_target_indicator: Node2D = null
var _had_pending_input: bool = false
var _is_processing: bool = false  ## set_process(false) 空闲优化

# v7.x 战场视觉反馈：单位悬浮信息窗
var _hover_info: PanelContainer = null
var _hover_timer: float = 0.0
var _hover_current_unit: Node = null
var _hover_check_acc: float = 0.0  ## 悬停检测节流（每 0.1s 一次）
const _HOVER_DELAY_SEC: float = 0.3
const _HOVER_CHECK_INTERVAL_SEC: float = 0.1

# v26.13(D-2): 指令轮盘——长按我方单位弹出（集火/守住/自由）
const CommandWheelScript = preload("res://scenes/ui/deploy_command_wheel.gd")
const _LONG_PRESS_SEC := 0.35
## v30 R3（设计审查 F-06）：2→4——战中干预空间翻倍（布阵后 60-90s 的决策空洞主因之一
## 是额度封顶；DESIGN_COMBAT_DECISION_B0 的"挂机零损失底座不动"约束不变，手动仍为纯增益）。
## 击杀回点（击杀敌方单位返还 1 指令额度）为下一步候选，待本轮实测后决定。
const _MAX_ACTIVE_COMMANDS := 4  # 单场同时生效指令上限（防微操过载）
var _wheel: Control = null
var _lp_unit: Node2D = null      # 长按中的单位（弱引用语义由调用方 is_instance_valid 保证）
var _lp_pos: Vector2 = Vector2.ZERO
var _lp_time: float = 0.0
var _lp_down: bool = false
var _focus_pick: WeakRef = null  # 集火点选模式：待指定目标的命令单位
var _focus_pick_banner: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 5
	mouse_filter = Control.MOUSE_FILTER_STOP
	# v7.x：查找 UnitHoverInfo（挂在 InfoPanelLayer）
	_hover_info = get_node_or_null("/root/Main/InfoPanelLayer/UnitHoverInfo") as PanelContainer
	# 启用 _process 用于悬停检测（原 set_process(false) 在 _process 内空闲优化保留给选点逻辑，
	# 但悬停检测需要常驻，这里通过独立计时逻辑处理）
	set_process(true)


## 避免在脱离场景树或视口无效时调用 set_input_as_handled（Viewport::_push_unhandled_input_internal 断言）
func _safe_set_input_handled() -> void:
	if not is_inside_tree():
		return
	var vp: Viewport = get_viewport()
	if vp == null or not is_instance_valid(vp) or not vp.is_inside_tree():
		return
	vp.set_input_as_handled()

func _process(delta: float) -> void:
	# === v7.x 悬停检测（常驻，每 0.1s 一次）===
	_process_hover(delta)
	# === v26.13(D-2): 长按计时（按下中 0.35s → 弹指令轮盘）===
	if _lp_down and _lp_unit != null and is_instance_valid(_lp_unit):
		_lp_time += delta
		if _lp_time >= _LONG_PRESS_SEC:
			_open_command_wheel(_lp_unit)
			_lp_down = false
			_lp_unit = null
	else:
		_lp_down = false
	# === 原 _process 逻辑（部署指示器）===
	var has_pending := not BattleInputState.pending_deploy_platform_card_id.is_empty()
	if not has_pending:
		if _had_pending_input:
			_clear_deploy_target_indicator()
			_had_pending_input = false
			_is_processing = false
		# 注意：原 set_process(false) 已移除（悬停检测需要常驻）
		return
	if not _is_processing:
		_is_processing = true
	_had_pending_input = true

	# 单位部署选点指示器
	if SignalBus and not BattleInputState.pending_deploy_platform_card_id.is_empty():
		_update_deploy_target_indicator()
	else:
		_clear_deploy_target_indicator()


## v7.x 悬停检测：每 0.1s 检查鼠标下单位，悬停 0.3s 显示悬浮窗
func _process_hover(delta: float) -> void:
	if _hover_info == null:
		return
	# 选点/部署模式中不显示悬浮窗（避免干扰）
	var in_pick_mode: bool = (SignalBus != null and not BattleInputState.pending_deploy_platform_card_id.is_empty())
	if in_pick_mode:
		_hide_hover()
		return
	_hover_check_acc += delta
	if _hover_check_acc < _HOVER_CHECK_INTERVAL_SEC:
		return
	_hover_check_acc = 0.0
	# 获取鼠标位置对应的战场视口坐标
	var mouse_global: Vector2 = get_global_mouse_position()
	var viewport_pos: Variant = _global_to_battle_viewport_pos(mouse_global)
	if viewport_pos == null or not (viewport_pos is Vector2):
		_hover_timer = 0.0
		_hide_hover_if_changed(null)
		return
	# 检测鼠标下单位
	var unit: Node = _pick_unit_for_hover(viewport_pos)
	if unit == _hover_current_unit and unit != null:
		# 同一单位继续悬停，累计计时
		_hover_timer += _HOVER_CHECK_INTERVAL_SEC
		if _hover_timer >= _HOVER_DELAY_SEC and not _hover_info.visible:
			_hover_info.show_for_unit(unit, mouse_global)
	elif unit != null:
		# 切换到新单位，重置计时
		_hover_current_unit = unit
		_hover_timer = _HOVER_CHECK_INTERVAL_SEC
	else:
		# 鼠标移出单位
		_hover_timer = 0.0
		_hide_hover_if_changed(null)


func _hide_hover_if_changed(new_unit: Node) -> void:
	if new_unit == _hover_current_unit:
		return
	_hover_current_unit = new_unit
	if _hover_info != null and _hover_info.visible:
		_hover_info.hide_delayed()


func _hide_hover() -> void:
	_hover_timer = 0.0
	_hover_current_unit = null
	if _hover_info != null:
		_hover_info.hide_immediate()


## 悬停用的单位拾取（复用 Battlefield.get_unit_at_position，轻量版不做施法判定）
func _pick_unit_for_hover(viewport_pos: Vector2) -> Node:
	var battlefield := _get_battlefield()
	if battlefield == null or not battlefield.has_method("get_unit_at_position"):
		return null
	var result: Dictionary = battlefield.get_unit_at_position(viewport_pos)
	return result.get("unit", null)

## 暂停时 _gui_input 可能不会被调用，用 _input 兜底（本节点 PROCESS_MODE_ALWAYS）
## 同时处理从底部栏拖到战场的释放事件（gui_input 无法跨控件接收）
func _input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	# 空闲时 _process=false，收到任何鼠标事件且有 pending 状态时重新启用
	if not _is_processing:
		var has_pending := not BattleInputState.pending_deploy_platform_card_id.is_empty()
		if has_pending:
			_is_processing = true
			_had_pending_input = true
			set_process(true)
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	var tree := get_tree()
	# 拖放部署：从底部栏按下后拖到战场释放（无论是否暂停）
	if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		if SignalBus and not BattleInputState.pending_deploy_platform_card_id.is_empty():
			if _try_deploy_from_global_pos(mb.global_position):
				_safe_set_input_handled()
				return
	# 右键取消：从底部栏拖到战场时取消（无论是否暂停）
	if mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed:
		if SignalBus:
			if not BattleInputState.pending_deploy_platform_card_id.is_empty():
				_cancel_pending_deploy()
				_safe_set_input_handled()
				return
	# 单位部署：左键按下直接尝试选点（无论是否暂停；避免 _gui_input 丢事件时无法部署）
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		if SignalBus and not BattleInputState.pending_deploy_platform_card_id.is_empty():
			var vp_any: Variant = _global_to_battle_viewport_pos(mb.global_position)
			if vp_any != null and _do_unit_pick(vp_any as Vector2):
				_safe_set_input_handled()
				return
	# 以下仅在暂停时处理
	if tree == null or not tree.paused:
		return
	# 用父节点（BattleContainer）的全局矩形判断，避免 overlay 在暂停时布局未更新
	var click_rect := get_parent_control().get_global_rect() if get_parent() is Control else get_global_rect()
	if not click_rect.has_point(mb.global_position):
		return
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_handle_click_paused(mb.global_position)

func _gui_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	# v26.13(D-2): 集火点选模式——下一击指定集火目标（敌=生效 / 其他=取消）
	if _focus_pick != null:
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_resolve_focus_pick(mb.global_position)
			_safe_set_input_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_focus_pick()
			_safe_set_input_handled()
		return
	# v26.13(D-2): 长按登记/提前释放回退（仅战斗进行中、非挂机、非部署选点）
	if _wheel_long_press_allowed():
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var vp_lp: Variant = _global_to_battle_viewport_pos(mb.global_position)
			var hit_lp: Dictionary = _pick_own_unit(vp_lp) if vp_pos_ok(vp_lp) else {}
			if not hit_lp.is_empty():
				_lp_unit = hit_lp["unit"]
				_lp_pos = (hit_lp["unit"] as Node2D).global_position
				_lp_time = 0.0
				_lp_down = true
				_safe_set_input_handled()  # 吞掉按下：短按在释放事件里补普通点选
				return
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _lp_down:
			_lp_down = false
			if _lp_unit != null and is_instance_valid(_lp_unit) and _lp_time < _LONG_PRESS_SEC:
				# 短按：回退到普通点选（信息框）语义
				var unit_held := _lp_unit
				_lp_unit = null
				if SignalBus:
					SignalBus.unit_selected.emit(unit_held, true, Vector2.ZERO)
				_safe_set_input_handled()
				return
			_lp_unit = null
	if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT and SignalBus:
		if not mb.pressed:
			return
		if not BattleInputState.pending_deploy_platform_card_id.is_empty():
			_cancel_pending_deploy()
			_safe_set_input_handled()
			return
		return
	# 选点模式中：左键直接释放（跳过信息框关闭逻辑）
	if SignalBus and not BattleInputState.pending_deploy_platform_card_id.is_empty() and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		var vp2: Variant = _global_to_battle_viewport_pos(mb.global_position)
		if vp2 != null and _do_unit_pick(vp2):
			_safe_set_input_handled()
		return
	# 支持拖放：左键释放时若有待部署卡，直接在释放点尝试部署
	if SignalBus and not BattleInputState.pending_deploy_platform_card_id.is_empty() and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		if _try_deploy_from_global_pos(mb.global_position):
			_safe_set_input_handled()
		return
	if not mb.pressed:
		return
	var panel = _get_unit_info_panel()
	# 若信息框已打开且点击在框外，关闭信息框
	if panel != null and panel.visible:
		if panel.has_method("hide_panel"):
			panel.hide_panel()
		else:
			panel.hide()
		_safe_set_input_handled()
		return
	# 点击战场区域：做单位检测并显示信息框（暂停/继续都由此处或 _input 处理）
	var viewport_pos: Variant = _global_to_battle_viewport_pos(mb.global_position)
	if mb.button_index == MOUSE_BUTTON_LEFT and viewport_pos != null and _do_unit_pick(viewport_pos):
		_safe_set_input_handled()

func _handle_click_paused(global_pos: Vector2) -> void:
	var viewport_pos: Variant = _global_to_battle_viewport_pos(global_pos)
	if viewport_pos == null:
		return
	if _do_unit_pick(viewport_pos):
		_safe_set_input_handled()

func _do_unit_pick(viewport_pos: Vector2) -> bool:
	# 单位部署：点战场放置虚影
	if SignalBus and not BattleInputState.pending_deploy_platform_card_id.is_empty():
		if BattleManager and BattleManager.battle_active and BattleManager.has_method("request_player_deploy_at"):
			var cid: String = BattleInputState.pending_deploy_platform_card_id
			if BattleManager.request_player_deploy_at(cid, viewport_pos):
				BattleInputState.pending_deploy_platform_card_id = ""
				BattleInputState.pending_deploy_origin_global = Vector2.ZERO
				_clear_deploy_target_indicator()
		return true
	# 常规点击：检测单位或移动
	var bf = _get_battlefield()
	if bf == null or not bf.has_method("get_unit_at_position"):
		return false
	var result: Dictionary = bf.get_unit_at_position(viewport_pos)
	if not result.is_empty():
		# v7.x：单击单位时立即隐藏悬浮窗（让位给全屏 CardInfoPanel）
		_hide_hover()
		# 发射信号给选中高亮等监听者（UnitInfoPanel 会显示战场情报面板）
		if SignalBus:
			SignalBus.unit_selected.emit(result.unit, result.is_player, Vector2.ZERO)
		return true
	# 没点到单位时，如果当前有选中的我方单位，则视为移动指令
	if SignalBus and BattleInputState.current_selected_unit != null and is_instance_valid(BattleInputState.current_selected_unit):
		var u: Node = BattleInputState.current_selected_unit
		if u.is_in_group("player_units"):
			SignalBus.unit_move_command.emit(u, viewport_pos)
			return true
	return false

func _try_deploy_from_global_pos(global_pos: Vector2) -> bool:
	if SignalBus == null or BattleInputState.pending_deploy_platform_card_id.is_empty():
		return false
	var vp: Variant = _global_to_battle_viewport_pos(global_pos)
	if vp == null:
		return false
	if BattleManager and BattleManager.battle_active and BattleManager.has_method("request_player_deploy_at"):
		var cid: String = BattleInputState.pending_deploy_platform_card_id
		if BattleManager.request_player_deploy_at(cid, vp as Vector2):
			BattleInputState.pending_deploy_platform_card_id = ""
			BattleInputState.pending_deploy_origin_global = Vector2.ZERO
			_clear_deploy_target_indicator()
			return true
	return false

func _clear_deploy_target_indicator() -> void:
	if _deploy_target_indicator != null and is_instance_valid(_deploy_target_indicator):
		_deploy_target_indicator.queue_free()
	_deploy_target_indicator = null

func _cancel_pending_deploy() -> void:
	if SignalBus:
		BattleInputState.pending_deploy_platform_card_id = ""
		BattleInputState.pending_deploy_origin_global = Vector2.ZERO
		if SignalBus.has_signal("play_sound"):
			SignalBus.play_sound.emit("cancel")
	_clear_deploy_target_indicator()

func _ensure_deploy_target_indicator(bf: Node) -> void:
	if _deploy_target_indicator != null and is_instance_valid(_deploy_target_indicator):
		return
	if bf == null:
		return
	var ind := Node2D.new()
	ind.set_script(LawTargetIndicatorScript)
	ind.position = Vector2.ZERO
	ind.set_process(true)
	bf.add_child(ind)
	_deploy_target_indicator = ind

func _update_deploy_target_indicator() -> void:
	var global_mouse: Vector2 = get_global_mouse_position()
	var target_variant: Variant = _global_to_battle_viewport_pos(global_mouse)
	if target_variant == null:
		return
	var target_local: Vector2 = target_variant as Vector2
	var origin_local: Vector2 = target_local
	if SignalBus and BattleInputState.pending_deploy_origin_global != Vector2.ZERO:
		var origin_var: Variant = _global_to_battle_viewport_pos(BattleInputState.pending_deploy_origin_global)
		if origin_var != null:
			origin_local = origin_var as Vector2
	var bf := _get_battlefield()
	_ensure_deploy_target_indicator(bf)
	if _deploy_target_indicator == null:
		return
	_deploy_target_indicator.origin_local = origin_local
	_deploy_target_indicator.target_local = target_local
	_deploy_target_indicator.target_radius = 0.0

func _global_to_battle_viewport_pos(global_pos: Vector2) -> Variant:
	var container := get_parent()
	if container == null:
		return null
	var sub_container := container.get_node_or_null("SubViewportContainer")
	var sub_viewport := container.get_node_or_null("SubViewportContainer/SubViewport")
	if sub_container == null or sub_viewport == null:
		return null
	var rect: Rect2 = (sub_container as Control).get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return null
	var local_in_sub := global_pos - rect.position
	var sv_size: Vector2 = Vector2((sub_viewport as SubViewport).size)
	var mapped := Vector2(
		(local_in_sub.x / rect.size.x) * sv_size.x,
		(local_in_sub.y / rect.size.y) * sv_size.y
	)
	return mapped

func _get_battlefield() -> Node:
	var container = get_parent()
	if container == null:
		return null
	return container.get_node_or_null("SubViewportContainer/SubViewport/Battlefield")

func _get_unit_info_panel() -> Control:
	return NodeFinder.get_card_info_panel() as Control

# ═══ v26.13(D-2): 指令轮盘 ═══

## 长按可用条件：战斗进行中、非暂停、非挂机、无待部署卡
func _wheel_long_press_allowed() -> bool:
	if BattleManager == null or not ("battle_active" in BattleManager) or not BattleManager.battle_active:
		return false
	var tree := get_tree()
	if tree != null and tree.paused:
		return false
	if SignalBus and not BattleInputState.pending_deploy_platform_card_id.is_empty():
		return false
	var main: Node = get_node_or_null("/root/Main")
	if main != null and "_afk_manager" in main and main._afk_manager != null \
			and "is_running" in main._afk_manager and main._afk_manager.is_running:
		return false  # 挂机模式不出现轮盘（设计约束）
	return true

## 拾取点位上的我方单位（复用 battlefield.get_unit_at_position）
func _pick_own_unit(viewport_pos: Variant) -> Dictionary:
	if viewport_pos == null:
		return {}
	var bf = _get_battlefield()
	if bf == null or not bf.has_method("get_unit_at_position"):
		return {}
	var r: Dictionary = bf.get_unit_at_position(viewport_pos)
	if r.is_empty() or not bool(r.get("is_player", false)):
		return {}
	# 相位师基地（phase_driver）不参与指令轮盘——它是核心不是作战单位
	var u: Node = r["unit"]
	if u is Node and (u as Node).is_in_group("phase_driver"):
		return {}
	return r

func vp_pos_ok(v: Variant) -> bool:
	return v != null

func _open_command_wheel(unit: Node2D) -> void:
	if _wheel == null or not is_instance_valid(_wheel):
		_wheel = CommandWheelScript.new()
		get_parent().add_child(_wheel)
		if not _wheel.command_chosen.is_connected(_on_wheel_command):
			_wheel.command_chosen.connect(_on_wheel_command)
	# 锚点：单位战场视口坐标 → overlay 局部坐标（overlay 与战场同域缩放）
	var vp: Variant = _global_to_battle_viewport_pos(unit.get_global_transform_with_viewport().origin)
	var anchor: Vector2 = (vp as Vector2) if vp != null else unit.global_position
	(_wheel as Control).open(_battle_viewport_to_local(anchor))
	if SignalBus and SignalBus.has_signal("play_sound"):
		SignalBus.play_sound.emit("button")

## battle 视口坐标 → overlay 局部坐标（战斗视口与 overlay 布局域可能不同）
func _battle_viewport_to_local(viewport_pos: Vector2) -> Vector2:
	var bf = _get_battlefield()
	if bf != null and bf is Node2D:
		return (bf as Node2D).get_global_transform_with_viewport().affine_inverse() * viewport_pos
	return viewport_pos

func _on_wheel_command(cmd: String) -> void:
	if _lp_unit == null or not is_instance_valid(_lp_unit):
		_lp_unit = null
		return
	var unit: Node2D = _lp_unit
	_lp_unit = null
	match cmd:
		"focus":
			_focus_pick = weakref(unit)
			_show_focus_pick_banner(unit)
		"hold":
			_assign_command(unit, "hold")
		"free":
			_clear_unit_commands(unit)

## 指令上限守卫：新指令前检查（focus 在点选落定时也再查一次）
func _active_command_count() -> int:
	var n: int = 0
	for u in get_tree().get_nodes_in_group("player_units"):
		if u is Node and is_instance_valid(u) and ((u as Node).has_meta("_cmd_hold") or (u as Node).has_meta("_focus_target_ref")):
			n += 1
	return n

func _assign_command(unit: Node2D, cmd: String) -> void:
	var already: bool = (unit.has_meta("_cmd_hold") or unit.has_meta("_focus_target_ref"))
	if not already and _active_command_count() >= _MAX_ACTIVE_COMMANDS:
		_toast_cmd("最多同时 %d 条指令——先解除一条再下达" % _MAX_ACTIVE_COMMANDS)
		return
	if cmd == "hold":
		unit.set_meta("_cmd_hold", true)
		_set_cmd_marker(unit, "守", Color(0.15, 0.75, 0.9))
	if SignalBus and SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit("🛡 已下达：守住（不主动切换目标）")

func _clear_unit_commands(unit: Node2D) -> void:
	unit.remove_meta("_cmd_hold") if unit.has_meta("_cmd_hold") else null
	unit.remove_meta("_focus_target_ref") if unit.has_meta("_focus_target_ref") else null
	var old := unit.get_node_or_null("CmdMarker")
	if old != null and is_instance_valid(old):
		old.queue_free()

# ── 集火点选模式 ──
func _show_focus_pick_banner(unit: Node2D) -> void:
	_cancel_focus_pick_banner()
	_focus_pick_banner = Label.new()
	_focus_pick_banner.text = "🎯 点击敌方单位指定集火目标（右键取消）"
	_focus_pick_banner.add_theme_font_size_override("font_size", 14)
	_focus_pick_banner.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_focus_pick_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_focus_pick_banner.position = Vector2(-170, 60)
	add_child(_focus_pick_banner)

func _cancel_focus_pick_banner() -> void:
	if _focus_pick_banner != null and is_instance_valid(_focus_pick_banner):
		_focus_pick_banner.queue_free()
	_focus_pick_banner = null

func _cancel_focus_pick() -> void:
	_focus_pick = null
	_cancel_focus_pick_banner()

func _resolve_focus_pick(global_pos: Vector2) -> void:
	var commander = _focus_pick.get_ref() if _focus_pick != null else null
	_cancel_focus_pick()
	if commander == null or not is_instance_valid(commander):
		return
	var bf = _get_battlefield()
	var vp: Variant = _global_to_battle_viewport_pos(global_pos)
	if bf == null or vp == null or not bf.has_method("get_unit_at_position"):
		return
	var r: Dictionary = bf.get_unit_at_position(vp)
	if r.is_empty() or bool(r.get("is_player", true)):
		_toast_cmd("未命中敌方单位，集火取消")
		return
	if not (r["unit"] is Node) or not is_instance_valid(r["unit"]):
		return
	if not already(commander) and _active_command_count() >= _MAX_ACTIVE_COMMANDS:
		_toast_cmd("最多同时 %d 条指令——先解除一条再下达" % _MAX_ACTIVE_COMMANDS)
		return
	(commander as Node).set_meta("_focus_target_ref", weakref(r["unit"]))
	_set_cmd_marker(commander, "集火", Color(0.7, 0.4, 0.95))

func already(u: Node) -> bool:
	return u.has_meta("_cmd_hold") or u.has_meta("_focus_target_ref")

# ── 指令标记（挂单位头顶，随单位死亡自动消失）──
func _set_cmd_marker(unit: Node, text: String, color: Color) -> void:
	var old := unit.get_node_or_null("CmdMarker")
	if old != null and is_instance_valid(old):
		old.queue_free()
	var lbl := Label.new()
	lbl.name = "CmdMarker"
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = Vector2(-14, -48)
	(unit as Node).add_child(lbl)

func _toast_cmd(msg: String) -> void:
	if SignalBus and SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit(msg)
