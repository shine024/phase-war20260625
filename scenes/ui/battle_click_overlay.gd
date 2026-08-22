extends Control
## 覆盖在战场上：暂停/继续时都可点单位显示信息；信息框打开时点击框外自动关闭；单位部署选点
## v9.x（P2-7范围B）：主动法则选点施放链已随法则系统退役移除

const VIEWPORT_SIZE := Vector2(1280.0, 580.0)
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
var _hover_check_acc: float = 0.0  # 悬停检测节流（每 0.1s 一次）
const _HOVER_DELAY_SEC: float = 0.3
const _HOVER_CHECK_INTERVAL_SEC: float = 0.1

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
