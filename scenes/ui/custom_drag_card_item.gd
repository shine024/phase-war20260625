extends PanelContainer
## 自定义拖拽卡牌项：完全自定义的拖拽实现

signal card_clicked(card: CardResource, source_item: Control)
signal drag_completed(card: CardResource, target_slot: Control)

var card: CardResource = null

const GC = preload("res://resources/game_constants.gd")
const SLOT_SIZE: Vector2 = PhaseSlot.SLOT_SIZE

# 拖拽相关
var _is_dragging := false
var _drag_preview: Control = null
var _drag_start_position: Vector2
var _original_modulate: Color

# 各卡片类型对应的顶部色条颜色
const TYPE_BAR_COLORS := {
	GC.CardType.COMBAT_UNIT: Color(0.1, 0.5, 0.9, 1.0),
	GC.CardType.COMBAT_UNIT:   Color(0.85, 0.45, 0.1, 1.0),
	GC.CardType.COMBAT_UNIT: Color(0.55, 0.25, 0.9, 1.0),
	GC.CardType.ENERGY:   Color(0.15, 0.75, 0.35, 1.0),
}

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	set_custom_minimum_size(SLOT_SIZE)
	custom_minimum_size = SLOT_SIZE
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_card(c: CardResource) -> void:
	card = c
	# ... 保持原有的 set_card 逻辑 ...

func _on_mouse_entered() -> void:
	if _is_dragging:
		return
	# 保持原有的悬停逻辑 ...

func _on_mouse_exited() -> void:
	# 保持原有的悬停逻辑 ...

func _on_gui_input(ev: InputEvent) -> void:
	if card == null:
		return

	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# 开始拖拽
				_start_drag()
			else:
				# 结束拖拽
				_end_drag()
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and not _is_dragging:
			# 普通点击
			card_clicked.emit(card, self)

	elif ev is InputEventMouseMotion and _is_dragging:
		# 更新拖拽预览位置
		_update_drag_preview()

func _start_drag() -> void:
	if card == null:
		return

	_is_dragging = true
	_drag_start_position = get_global_mouse_position()
	_original_modulate = modulate

	# 创建拖拽预览
	_drag_preview = duplicate()
	_drag_preview.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_drag_preview.position = get_global_mouse_position()
	_drag_preview.modulate = Color(1, 1, 1, 0.8)
	_drag_preview.z_index = 1000
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	get_tree().root.add_child(_drag_preview)

	# 隐藏原始卡牌
	modulate = Color(1, 1, 1, 0.3)

	# 临时隐藏 BackpackOverlay
	_hide_backpack_overlay()

func _update_drag_preview() -> void:
	if _drag_preview and is_instance_valid(_drag_preview):
		_drag_preview.global_position = get_global_mouse_position() - _drag_preview.size / 2

func _end_drag() -> void:
	if not _is_dragging:
		return


	_is_dragging = false

	# 检查是否在槽位上方
	var slot = _find_slot_under_mouse()
	if slot and slot is Control:
		# 尝试装备
		_try_equip_to_slot(slot)

	# 清理拖拽预览
	if _drag_preview and is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
		_drag_preview = null

	# 恢复原始卡牌
	modulate = _original_modulate

	# 恢复 BackpackOverlay
	_show_backpack_overlay()

func _find_slot_under_mouse() -> Control:
	var mouse_pos = get_global_mouse_position()

	# 查找相位仪面板
	var phase_panel = get_tree().get_first_node_in_group("phase_instrument_panel")
	if not phase_panel:
		# 尝试通过路径查找
		phase_panel = get_node_or_null("/root/BottomInstrumentBar/PhaseInstrumentPanel")

	if not phase_panel:
		return null

	# 检查所有子节点（槽位）
	for child in phase_panel.get_children():
		if child is Control:
			var rect = child.get_global_rect()
			if rect.has_point(mouse_pos):
				return child

	return null

func _try_equip_to_slot(slot: Control) -> void:
	# 发送信号到相位仪面板
	if slot.has_method("get_card"):
		# 这是有效的槽位

		# 通过 SignalBus 发送装备请求
		if SignalBus and SignalBus.has_signal("card_equipped"):
			# 需要获取槽位索引
			var slot_index = slot.get("slot_index") if slot.has_method("get") else -1
			if slot_index >= 0:
				# 直接触发槽位的 drop 请求
				if slot.has_signal("slot_drop_requested"):
					slot.emit_signal("slot_drop_requested", slot_index, card)

func _hide_backpack_overlay() -> void:
	var overlay = get_node("../../../../BackpackOverlay")
	if overlay and overlay is Control:
		overlay.visible = false

func _show_backpack_overlay() -> void:
	var overlay = get_node("../../../../BackpackOverlay")
	if overlay and overlay is Control:
		overlay.visible = true
