extends Control
## 覆盖在战场上：暂停/继续时都可点单位显示信息；信息框打开时点击框外自动关闭；主动法则选点释放

const VIEWPORT_SIZE := Vector2(1280.0, 580.0)
const PhaseLaws = preload("res://data/phase_laws.gd")
const BasicResources = preload("res://data/basic_resources.gd")
const LawTargetIndicatorScript = preload("res://scenes/effects/law_target_indicator.gd")
const ToastUtilsScript = preload("res://scripts/toast_utils.gd")
const DEBUG_DEPLOY_CLICK_LOG := false

var _law_target_indicator: Node2D = null
var _deploy_target_indicator: Node2D = null
var _had_pending_input: bool = false
var _is_processing: bool = false  ## set_process(false) 空闲优化
var _cast_toast = null

#region agent log
func _agent_log(hypothesis_id: String, message: String, data: Dictionary) -> void:
	var f := FileAccess.open("debug-1776fa.log", FileAccess.WRITE_READ)
	if f == null:
		return
	f.seek_end()
	var payload := {
		"sessionId": "1776fa",
		"runId": "law_bullet_debug_v1",
		"hypothesisId": hypothesis_id,
		"location": "battle_click_overlay.gd",
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 5
	mouse_filter = Control.MOUSE_FILTER_STOP

## 避免在脱离场景树或视口无效时调用 set_input_as_handled（Viewport::_push_unhandled_input_internal 断言）
func _safe_set_input_handled() -> void:
	if not is_inside_tree():
		# #endregion
		return
	var vp: Viewport = get_viewport()
	if vp == null or not is_instance_valid(vp) or not vp.is_inside_tree():
		return
	vp.set_input_as_handled()

func _show_cast_fail_toast(message: String) -> void:
	if message.is_empty():
		return
	if _cast_toast == null:
		_cast_toast = ToastUtilsScript.new()
	# 挂在 BattleContainer 上，避免被 SubViewport 裁剪
	var parent_node: Node = get_parent() if get_parent() != null else self
	_cast_toast.show_toast(parent_node, message, true)

func _process(_delta: float) -> void:
	var has_pending := not BattleInputState.pending_cast_law_id.is_empty() or not BattleInputState.pending_deploy_platform_card_id.is_empty()
	if not has_pending:
		if _had_pending_input:
			_clear_law_target_indicator()
			_clear_deploy_target_indicator()
			_had_pending_input = false
			_is_processing = false
			set_process(false)
		return
	if not _is_processing:
		_is_processing = true
	_had_pending_input = true

	# 主动法则选点 / 单位部署选点：互斥指示器
	if SignalBus and not BattleInputState.pending_cast_law_id.is_empty():
		_clear_deploy_target_indicator()
		_update_law_target_indicator()
	elif SignalBus and not BattleInputState.pending_deploy_platform_card_id.is_empty():
		_clear_law_target_indicator()
		_update_deploy_target_indicator()
	else:
		_clear_law_target_indicator()
		_clear_deploy_target_indicator()

## 暂停时 _gui_input 可能不会被调用，用 _input 兜底（本节点 PROCESS_MODE_ALWAYS）
## 同时处理从底部栏拖到战场的释放事件（gui_input 无法跨控件接收）
func _input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	# 空闲时 _process=false，收到任何鼠标事件且有 pending 状态时重新启用
	if not _is_processing:
		var has_pending := not BattleInputState.pending_cast_law_id.is_empty() or not BattleInputState.pending_deploy_platform_card_id.is_empty()
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
			if not BattleInputState.pending_cast_law_id.is_empty():
				_cancel_pending_cast()
				_safe_set_input_handled()
				return
			if not BattleInputState.pending_deploy_platform_card_id.is_empty():
				_cancel_pending_deploy()
				_safe_set_input_handled()
				return
	# 主动法则/部署：左键按下直接尝试选点（无论是否暂停；避免 _gui_input 丢事件时无法施放）
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		if SignalBus and (not BattleInputState.pending_cast_law_id.is_empty() or not BattleInputState.pending_deploy_platform_card_id.is_empty()):
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
		if not BattleInputState.pending_cast_law_id.is_empty():
			_cancel_pending_cast()
			_safe_set_input_handled()
			return
		if not BattleInputState.pending_deploy_platform_card_id.is_empty():
			_cancel_pending_deploy()
			_safe_set_input_handled()
			return
		return
	# 选点模式中：左键直接释放（跳过信息框关闭逻辑）
	if SignalBus and not BattleInputState.pending_cast_law_id.is_empty() and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		var vp: Variant = _global_to_battle_viewport_pos(mb.global_position)
		if vp != null and _do_unit_pick(vp):
			_safe_set_input_handled()
		return
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
		var panel_rect = panel.get_global_rect()
		if not panel_rect.has_point(mb.global_position):
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
	# 施法与部署冲突时，优先施法（用户当前点击红槽/主动法则的期望）
	if SignalBus and not BattleInputState.pending_cast_law_id.is_empty():
		return _try_cast_active_law_at(viewport_pos)

	# 单位部署：点战场放置虚影
	if SignalBus and not BattleInputState.pending_deploy_platform_card_id.is_empty():
		if DEBUG_DEPLOY_CLICK_LOG:
			print("[BattleClickOverlay] 检测到待部署卡牌: card_id=%s, pos=%s" % [BattleInputState.pending_deploy_platform_card_id, viewport_pos])
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

func _try_cast_active_law_at(viewport_pos: Vector2) -> bool:
	var law_id: String = BattleInputState.pending_cast_law_id
	if law_id.is_empty():
		return false
	#region agent log
	_agent_log("H1_cast_gate", "cast_attempt_entry", {
		"law_id": law_id,
		"viewport_pos": viewport_pos,
		"has_plm": PhaseLawManager != null
	})
	#endregion
	if PhaseLawManager and PhaseLawManager.has_method("can_cast") and PhaseLawManager.has_method("record_cast"):
		var current_energy: float = 0.0
		if EnergyManager and EnergyManager.has_method("get_current"):
			current_energy = EnergyManager.get_current()
		var bf = _get_battlefield()
		var target_pos := viewport_pos
		if bf != null and bf.has_method("get_unit_at_position"):
			var pick: Dictionary = bf.get_unit_at_position(viewport_pos)
			if not pick.is_empty() and pick.has("unit"):
				var u: Node2D = pick.unit as Node2D
				if u != null:
					target_pos = u.global_position
		var extra: Dictionary = {"friendly_units": 0}
		if bf != null and bf.has_method("get_player_units_node"):
			var pu: Node = bf.get_player_units_node()
			if pu:
				extra["friendly_units"] = pu.get_child_count()
		var can_cast_now: bool = PhaseLawManager.can_cast(law_id, current_energy, extra)
		#region agent log
		_agent_log("H1_cast_gate", "cast_gate_checked", {
			"law_id": law_id,
			"current_energy": current_energy,
			"extra": extra,
			"can_cast": can_cast_now
		})
		#endregion
		if can_cast_now:
			var law: Dictionary = PhaseLaws.get_by_id(law_id) if PhaseLaws else {}
			var cost: Dictionary = law.get("battle_cost", {}) if not law.is_empty() else {}
			var need_energy: float = float(cost.get("energy", 0))
			if need_energy > 0 and EnergyManager and EnergyManager.has_method("spend"):
				if not EnergyManager.spend(need_energy):
					if SignalBus and SignalBus.has_signal("play_sound"):
						SignalBus.play_sound.emit("error")
					return true
			if SignalBus:
				SignalBus.active_law_cast_at.emit(law_id, target_pos)
				BattleInputState.pending_cast_law_id = ""
				BattleInputState.pending_cast_law_origin_global = Vector2.ZERO
		else:
			var fail_reason: String = ""
			var equipped_check = PhaseLawManager._resolve_equipped_active_key(law_id) if PhaseLawManager.has_method("_resolve_equipped_active_key") else ""
			if equipped_check.is_empty():
				fail_reason = "法则未正确装配"
			else:
				var law_cfg: Dictionary = PhaseLaws.get_by_id(law_id) if PhaseLaws else {}
				var bc: Dictionary = law_cfg.get("battle_cost", {}) if not law_cfg.is_empty() else {}
				var need_e: float = float(bc.get("energy", 0.0))
				var need_nano: int = int(bc.get("nano", 0))
				var casts_used: int = 0
				var casts_limit: int = 999999
				var active_states: Dictionary = PhaseLawManager.active_law_states if "active_law_states" in PhaseLawManager else {}
				if active_states.has(law_id):
					casts_used = int(active_states[law_id].get("casts_used", 0))
					casts_limit = int(active_states[law_id].get("casts_limit", 999999))
				var has_nano: int = 0
				if BasicResourceManager and BasicResourceManager.has_method("get_total"):
					has_nano = int(BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS))
				if current_energy < need_e:
					fail_reason = "能量不足"
				elif need_nano > 0 and has_nano < need_nano:
					fail_reason = "纳米材料不足"
				elif casts_used >= casts_limit:
					fail_reason = "施放次数已用完"
				else:
					fail_reason = "施放失败"
				_show_cast_fail_toast(fail_reason)
		return true
	BattleInputState.pending_cast_law_id = ""
	BattleInputState.pending_cast_law_origin_global = Vector2.ZERO
	return true

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

func _clear_law_target_indicator() -> void:
	if _law_target_indicator != null and is_instance_valid(_law_target_indicator):
		_law_target_indicator.queue_free()
	_law_target_indicator = null

func _cancel_pending_cast() -> void:
	# 取消选点释放：清空待施放法则 + 起点，并立即移除指示器
	if SignalBus:
		BattleInputState.pending_cast_law_id = ""
		BattleInputState.pending_cast_law_origin_global = Vector2.ZERO
	_clear_law_target_indicator()

func _cancel_pending_deploy() -> void:
	if SignalBus:
		BattleInputState.pending_deploy_platform_card_id = ""
		BattleInputState.pending_deploy_origin_global = Vector2.ZERO
	_clear_deploy_target_indicator()

func _clear_deploy_target_indicator() -> void:
	if _deploy_target_indicator != null and is_instance_valid(_deploy_target_indicator):
		_deploy_target_indicator.queue_free()
	_deploy_target_indicator = null

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

func _ensure_law_target_indicator(bf: Node) -> void:
	if _law_target_indicator != null and is_instance_valid(_law_target_indicator):
		return
	if bf == null:
		return
	var ind := Node2D.new()
	ind.set_script(LawTargetIndicatorScript)
	ind.position = Vector2.ZERO
	ind.set_process(true)
	bf.add_child(ind)
	_law_target_indicator = ind

func _update_law_target_indicator() -> void:
	var bf := _get_battlefield()
	if bf == null:
		return

	var law_id: String = BattleInputState.pending_cast_law_id
	var cfg: Dictionary = PhaseLaws.get_by_id(law_id) if PhaseLaws else {}
	var rt: Dictionary = cfg.get("runtime_tags", {})
	var radius: float = float(rt.get("radius", 200.0))

	# 目标：永远按鼠标当前落点（与点击释放一致）
	var global_mouse: Vector2 = get_global_mouse_position()
	var target_variant: Variant = _global_to_battle_viewport_pos(global_mouse)
	if target_variant == null:
		return
	var target_local: Vector2 = target_variant as Vector2

	# 原点：来自“选定法则格”的屏幕坐标（映射到战场子视口坐标）
	var origin_local: Vector2 = target_local
	if SignalBus and BattleInputState.pending_cast_law_origin_global != Vector2.ZERO:
		var origin_variant: Variant = _global_to_battle_viewport_pos(BattleInputState.pending_cast_law_origin_global)
		if origin_variant != null:
			origin_local = origin_variant as Vector2
	else:
		# 兜底：战场中心
		var container := get_parent()
		if container != null:
			var sub_container := container.get_node_or_null("SubViewportContainer") as Control
			if sub_container != null:
				var rect := sub_container.get_global_rect()
				var center_global := rect.position + rect.size * 0.5
				var center_variant: Variant = _global_to_battle_viewport_pos(center_global)
				if center_variant != null:
					origin_local = center_variant as Vector2

	_ensure_law_target_indicator(bf)
	if _law_target_indicator == null:
		return

	_law_target_indicator.origin_local = origin_local
	_law_target_indicator.target_local = target_local
	_law_target_indicator.target_radius = radius

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
	var container = get_parent()
	if container != null:
		var local_panel := container.get_node_or_null("UnitInfoPanel") as Control
		if local_panel != null:
			return local_panel
	# HUD 重构后 UnitInfoPanel 位于 Main/HudLayer
	var main_root := get_node_or_null("/root/Main")
	if main_root != null:
		return main_root.get_node_or_null("HudLayer/UnitInfoPanel") as Control
	return null
