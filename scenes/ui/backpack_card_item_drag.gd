## BackpackCardItem Drag handling logic
## 提取自 backpack_card_item.gd，class_name 用于跨文件引用
class_name BackpackCardItemDrag
extends RefCounted

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const CardFrameUi = preload("res://scripts/card_frame_ui.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")

## 拖拽预览外框同槽位；内图标竖向略小于外框
const DRAG_PREVIEW_ICON_DISPLAY_MIN := Vector2(36, 56)

## 检查拖拽状态（process_frame 回调，v7.3: 仅拖拽中连接）
static func check_drag_state(item: PanelContainer) -> void:
	if not is_instance_valid(item) or not item.is_inside_tree():
		item._disconnect_drag_frame()
		return
	if item._is_dragging:
		var mouse_pos = item.get_global_mouse_position()
		if item._drag_preview and is_instance_valid(item._drag_preview):
			item._drag_preview.global_position = mouse_pos - item._drag_preview.size / 2
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			end_drag(item)
	else:
		item._is_dragging = false
		item._disconnect_drag_frame()
		item.process_mode = Node.PROCESS_MODE_INHERIT

## 断开 process_frame 拖拽钩子（v7.3: 委托给 item 按需断开）
static func disconnect_drag_frame_hook(item: PanelContainer) -> void:
	if is_instance_valid(item):
		item._disconnect_drag_frame()

## 检查全局鼠标移动（拖拽过程中）
static func check_global_mouse_movement(item: PanelContainer) -> void:
	if not item._is_dragging:
		return
	var mouse_pos = item.get_global_mouse_position()
	if item._drag_preview and is_instance_valid(item._drag_preview):
		item._drag_preview.global_position = mouse_pos - item._drag_preview.size / 2

## gui_input 处理（鼠标/手势事件）
static func on_gui_input(item: PanelContainer, ev: InputEvent) -> void:
	if item.card == null:
		return

	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				item._click_start_position = mb.position
			else:
				if item._is_dragging:
					end_drag(item)
				else:
					var distance = mb.position.distance_to(item._click_start_position)
					if distance < item._drag_threshold:
						item.card_clicked.emit(item.card, item)

	elif ev is InputEventMouseMotion:
		if not item._is_dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var mouse_event = ev as InputEventMouseMotion
			var distance = mouse_event.position.distance_to(item._click_start_position)
			if distance >= item._drag_threshold:
				start_drag(item)
		if item._is_dragging:
			update_drag_preview(item)
			check_slot_under_mouse(item)
		else:
			check_global_mouse_movement(item)

## 开始拖拽
static func start_drag(item: PanelContainer) -> void:
	if item.card == null:
		return

	item._is_dragging = true
	item._drag_started_ms = Time.get_ticks_msec()

	# v7.3 性能优化：按需连接 process_frame（仅在拖拽期间监听，结束即断开，消除空闲空跑）
	item._connect_drag_frame()

	# 创建轻量拖拽预览
	item._drag_preview = PanelContainer.new()
	item._drag_preview.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	item._drag_preview.custom_minimum_size = item.SLOT_SIZE
	if item.ENABLE_IMAGE_DRAG_PREVIEW:
		var body := MarginContainer.new()
		body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("margin_left", 4)
		body.add_theme_constant_override("margin_top", 4)
		body.add_theme_constant_override("margin_right", 4)
		body.add_theme_constant_override("margin_bottom", 4)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var preview_icon := TextureRect.new()
		preview_icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tex_path3: String = item._card_icon_tex_path(item.card)
		UiAssetLoader.setup_card_unit_icon(preview_icon, item._get_cached_icon_texture(tex_path3), DRAG_PREVIEW_ICON_DISPLAY_MIN, true)
		if preview_icon.texture != null:
			body.add_child(preview_icon)
		else:
			var preview_lbl_fallback := Label.new()
			preview_lbl_fallback.text = DefaultCards.safe_name(item.card)
			preview_lbl_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			preview_lbl_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			body.add_child(preview_lbl_fallback)
		item._drag_preview.add_child(body)
	else:
		var preview_lbl := Label.new()
		preview_lbl.text = DefaultCards.safe_name(item.card)
		preview_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		preview_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item._drag_preview.add_child(preview_lbl)
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.1, 0.15, 0.25, 0.85)
	preview_style.border_color = Color(0.4, 0.7, 1.0, 0.8)
	preview_style.border_width_left = 2
	preview_style.border_width_top = 2
	preview_style.border_width_right = 2
	preview_style.border_width_bottom = 2
	preview_style.set_corner_radius_all(6)
	item._drag_preview.add_theme_stylebox_override(
		"panel",
		CardFrameUi.subtle_panel_style() if CardFrameUi.has_frame(item.card.rarity) else preview_style
	)
	if not item.ENABLE_IMAGE_DRAG_PREVIEW:
		item._drag_preview.custom_minimum_size = Vector2(item.SLOT_SIZE.x, 36)
	item._drag_preview.position = item.get_global_mouse_position()
	if item.ENABLE_IMAGE_DRAG_PREVIEW and item.card != null:
		CardFrameUi.apply_slot_chrome(item._drag_preview, item.card)
	item._drag_preview.top_level = true
	item._drag_preview.z_as_relative = false
	item._drag_preview.z_index = 4096
	item._drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview_parent: Node = get_drag_preview_parent(item)
	if preview_parent != null:
		preview_parent.add_child(item._drag_preview)
	else:
		item.get_tree().root.add_child(item._drag_preview)

	# 半透明显示原始卡牌
	item.modulate = Color(1, 1, 1, 0.3)
	hide_backpack_overlay(item)
	cache_slot_controls_for_drag(item)

## 获取拖拽预览的父节点
static func get_drag_preview_parent(item: PanelContainer) -> Node:
	var tree: SceneTree = item.get_tree()
	if tree == null:
		return null
	var current_scene: Node = tree.current_scene
	if current_scene != null:
		var popup_layer: Node = current_scene.get_node_or_null("PopupLayer")
		if popup_layer != null:
			return popup_layer
	return tree.root

## 更新拖拽预览位置
static func update_drag_preview(item: PanelContainer) -> void:
	if item._drag_preview and is_instance_valid(item._drag_preview):
		var mouse_pos = item.get_global_mouse_position()
		item._drag_preview.global_position = mouse_pos - item._drag_preview.size / 2

## 检查鼠标下的槽位
static func check_slot_under_mouse(item: PanelContainer) -> void:
	var mouse_pos = item.get_global_mouse_position()
	if item._cached_slot_controls.is_empty():
		cache_slot_controls_for_drag(item)
	if item._cached_slot_controls.is_empty():
		clear_slot_hover_feedback(item)
		return
	for child in item._cached_slot_controls:
		if not child is Control:
			continue
		if child.get_global_rect().has_point(mouse_pos) and child.has_meta("slot_color"):
			apply_slot_hover_feedback(item, child)
			if item._drag_preview and is_instance_valid(item._drag_preview):
				item._drag_preview.modulate = Color(0.4, 1.0, 0.4, 0.8)
			return
	clear_slot_hover_feedback(item)
	if item._drag_preview and is_instance_valid(item._drag_preview):
		item._drag_preview.modulate = Color(1, 1, 1, 0.8)

## 结束拖拽
static func end_drag(item: PanelContainer) -> void:
	if not item._is_dragging:
		return

	item._is_dragging = false
	# v7.3: 拖拽结束立即断开 process_frame（不等下一帧 check_drag_state）
	item._disconnect_drag_frame()

	# 先清理拖拽预览
	if item._drag_preview and is_instance_valid(item._drag_preview):
		item._drag_preview.queue_free()
		item._drag_preview = null

	# 恢复原始卡牌
	item.modulate = Color(1, 1, 1, 1)

	# 恢复 BackpackOverlay
	show_backpack_overlay(item)
	clear_slot_hover_feedback(item)

	# 尝试装备
	var slot = find_slot_under_mouse(item)
	if slot:
		try_equip_to_slot(item, slot)
	clear_drag_slot_cache(item)

## 槽位悬停高亮
static func apply_slot_hover_feedback(item: PanelContainer, slot: Control) -> void:
	if slot == null or not is_instance_valid(slot):
		return
	if item._last_hover_slot != null and item._last_hover_slot != slot:
		clear_single_slot_hover_feedback(item._last_hover_slot)
	item._last_hover_slot = slot
	var style := slot.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var sb := style as StyleBoxFlat
		if not slot.has_meta("_drag_prev_border"):
			slot.set_meta("_drag_prev_border", sb.border_color)
		if not slot.has_meta("_drag_prev_width"):
			slot.set_meta("_drag_prev_width", sb.border_width_left)
		sb.border_color = Color(0.45, 1.0, 0.65, 1.0)
		sb.set_border_width_all(3)
		slot.queue_redraw()

## 清除所有槽位悬停高亮
static func clear_slot_hover_feedback(item: PanelContainer) -> void:
	if item._last_hover_slot == null:
		return
	clear_single_slot_hover_feedback(item._last_hover_slot)
	item._last_hover_slot = null

## 清除单个槽位悬停高亮
static func clear_single_slot_hover_feedback(slot: Control) -> void:
	if slot == null or not is_instance_valid(slot):
		return
	var style := slot.get_theme_stylebox("panel")
	if not (style is StyleBoxFlat):
		return
	var sb := style as StyleBoxFlat
	if slot.has_meta("_drag_prev_border"):
		sb.border_color = slot.get_meta("_drag_prev_border")
		slot.remove_meta("_drag_prev_border")
	if slot.has_meta("_drag_prev_width"):
		sb.set_border_width_all(int(slot.get_meta("_drag_prev_width")))
		slot.remove_meta("_drag_prev_width")
	slot.queue_redraw()

## 查找鼠标下的槽位
static func find_slot_under_mouse(item: PanelContainer) -> Control:
	var mouse_pos = item.get_global_mouse_position()
	if item._cached_slot_controls.is_empty():
		cache_slot_controls_for_drag(item)
	if item._cached_slot_controls.is_empty():
		return null
	for child in item._cached_slot_controls:
		if not child is Control:
			continue
		if child.get_global_rect().has_point(mouse_pos) and child.has_meta("slot_color"):
			return child
	return null

## 获取相位仪可放置槽位节点
static func get_phase_slot_controls(instrument_section: Node) -> Array:
	var out: Array = []
	if instrument_section == null:
		return out
	for child in instrument_section.get_children():
		if child is Control and child.has_meta("slot_color"):
			out.append(child)
	var slot_section = instrument_section.get_node_or_null("SlotSection")
	if slot_section:
		for child in slot_section.get_children():
			if child is Control and child.has_meta("slot_color"):
				out.append(child)
	return out

## 缓存槽位控件
static func cache_slot_controls_for_drag(item: PanelContainer) -> void:
	item._cached_slot_controls.clear()
	var bottom_bar = item.get_node_or_null("/root/Main/HudLayer/BattleBottomBar/BottomInstrumentBar")
	if bottom_bar == null:
		bottom_bar = item.get_node_or_null("/root/Main/HudLayer/BottomInstrumentBar")
	if bottom_bar == null:
		var main_root: Node = item.get_node_or_null("/root/Main")
		if main_root != null:
			bottom_bar = main_root.find_child("BottomInstrumentBar", true, false)
	if not bottom_bar or not is_instance_valid(bottom_bar):
		return
	var section = bottom_bar.get("instrument_section")
	if section == null:
		section = bottom_bar.get_node_or_null("Margin/HBox/InstrumentSection")
	if section == null:
		return
	item._cached_slot_controls = get_phase_slot_controls(section)

## 清除槽位缓存
static func clear_drag_slot_cache(item: PanelContainer) -> void:
	item._cached_slot_controls.clear()

## 尝试装备到槽位
static func try_equip_to_slot(item: PanelContainer, slot: Control) -> void:
	if not slot:
		return
	var slot_color = slot.get_meta("slot_color") if slot.has_meta("slot_color") else ""
	var slot_index = slot.get_meta("slot_index") if slot.has_meta("slot_index") else -1
	if slot_color.is_empty() or slot_index < 0:
		return
	var flat_index = calculate_flat_index(item, slot_color, slot_index)
	if flat_index < 0:
		return
	if not PhaseInstrumentManager or not PhaseInstrumentManager.has_method("equip_card"):
		return
	PhaseInstrumentManager.equip_card(flat_index, item.card, null)

## 计算扁平索引
static func calculate_flat_index(_item: PanelContainer, slot_color: String, slot_index: int) -> int:
	if slot_index < 0:
		return -1
	if not PhaseInstrumentManager or not PhaseInstrumentManager.has_method("get_current_instrument"):
		return -1
	var cfg: Dictionary = PhaseInstrumentManager.get_current_instrument()
	var slot_counts: Dictionary = cfg.get("slot_counts", {})
	var red_count = int(slot_counts.get("red", 0))
	var blue_count = int(slot_counts.get("blue", 0))
	var green_count = int(slot_counts.get("green", 0))
	match slot_color:
		"red":
			return slot_index
		"blue":
			return red_count + slot_index
		"green":
			return red_count + blue_count + slot_index
		"yellow":
			return red_count + blue_count + green_count + slot_index
		_:
			return -1

## 隐藏 BackpackOverlay
static func hide_backpack_overlay(item: PanelContainer) -> void:
	var overlay = item.get_node_or_null("/root/Main/PopupLayer/BackpackOverlay")
	if overlay == null:
		overlay = item.get_tree().root.find_child("BackpackOverlay", true, false)
	if overlay and overlay is Control:
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

## 显示 BackpackOverlay
static func show_backpack_overlay(item: PanelContainer) -> void:
	var overlay = item.get_node_or_null("/root/Main/PopupLayer/BackpackOverlay")
	if overlay == null:
		overlay = item.get_tree().root.find_child("BackpackOverlay", true, false)
	if overlay and overlay is Control:
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP

## 退出场景树清理
static func exit_tree_cleanup(item: PanelContainer) -> void:
	item._is_dragging = false
	if item._drag_preview and is_instance_valid(item._drag_preview):
		item._drag_preview.queue_free()
		item._drag_preview = null
	disconnect_drag_frame_hook(item)
