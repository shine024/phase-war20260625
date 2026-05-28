extends PanelContainer
## 背包面板 -- View 层（MVP 模式）
## 负责所有 UI 渲染和用户输入转发。
## 业务逻辑已拆分到 BackpackPresenter，数据管理已拆分到 BackpackData。
##
## 设计文档：背包 MVP 架构重构（MVP 模式拆分）
## 职责：
##   - 渲染卡片网格、详情弹窗
##   - 处理 UI 事件并转发给 Presenter
##   - 不持有业务逻辑，不做存档/装备/消耗等决策
##
## 公共接口（供外部系统调用，保持向后兼容）：
##   - get_extra_card_ids() -> Array
##   - get_all_card_ids() -> Array
##   - restore_extra_cards(ids: Array) -> void
##   - get_backpack_statistics() -> Dictionary
##   - set_filter_type(filter_type: int) -> void
##   - set_sort_type(sort_type: String) -> void
##   - reset_filters() -> void
##   - quick_filter_by_rarity(rarity: String) -> void
##   - _on_card_clicked(card, source_item) -> void  (被 phase_instrument_panel 调用)

signal closed

const DefaultCardsData = preload("res://data/default_cards.gd")
const CardItemScene = preload("res://scenes/ui/backpack_card_item.tscn")
const ResourceSlotScene = preload("res://scenes/ui/resource_slot_item.tscn")
const GC = preload("res://resources/game_constants.gd")
const BackpackDataScript = preload("res://scenes/ui/backpack/backpack_data.gd")
const BackpackPresenterScript = preload("res://scenes/ui/backpack/backpack_presenter.gd")
const NodeFinder = preload("res://scripts/node_finder.gd")
## 详情弹窗：仅展示竖向卡面（5:7），下方只保留说明/风味/操作
const DETAIL_CARD_FACE_SIZE := Vector2(210, 294)
const RankDisplayUi = preload("res://scripts/rank_display_ui.gd")
const BackpackCombatPreview = preload("res://scenes/ui/backpack_combat_preview.gd")

## 与相位仪槽位、背包卡条目同尺寸（见 PhaseSlot.SLOT_SIZE）
const CARD_SLOT_MIN: Vector2 = PhaseSlot.SLOT_SIZE
const MAX_CARD_SLOTS := 51
## 与 `backpack_panel.tscn` 中 CardGrid 的 `h_separation` 一致（勿与主题脱节）
const BACKPACK_GRID_H_SEP := 6
## 与 `backpack_panel.tscn` 中 BackpackPanel `custom_minimum_size.x` 对齐，按竖向槽位宽度取整列数
const BACKPACK_PANEL_DESIGN_WIDTH := 1000
## 每行列数：floor((W + sep) / (slot_w + sep))，与 PhaseSlot 竖向格宽一致
const BACKPACK_GRID_COLUMNS: int = (BACKPACK_PANEL_DESIGN_WIDTH + BACKPACK_GRID_H_SEP) / (int(PhaseSlot.SLOT_SIZE.x) + BACKPACK_GRID_H_SEP)

# MVP 引用
var _presenter: BackpackPresenter = null
var _data: BackpackData = null

## 内嵌滚动容器（用于程序化滚动定位）
@onready var _scroll: ScrollContainer = $VBoxOuter/ScrollContainer

## 相位仪快捷栏已移除（不再在背包内显示）

## 全量重建排到 idle 再执行：在背包卡 item 的 gui_input / 拖拽 / 装备信号栈内不能对其 free()，否则会报 Object is locked
var _rebuild_grid_snapshot: Array = []
var _rebuild_grid_scheduled: bool = false
var _empty_slot_style: StyleBoxFlat = null
var _card_item_pool: Array = []
var _resource_slot_pool: Array = []
var _lore_slot_pool: Array = []
var _stat_boost_slot_pool: Array = []
var _empty_slot_pool: Array = []
var _last_lore_signature: String = ""
var _last_stat_boost_signature: String = ""
var _loading_label: Label = null

## ============================================================
## 生命周期
## ============================================================

func _ready() -> void:
	add_to_group("backpack_panel")
	# 必须先锁定列数再 setup（setup 会立刻 rebuild，不能在 rebuild 之后才设 columns）
	var grid := get_node_or_null("VBoxOuter/ScrollContainer/CardGrid") as GridContainer
	if grid:
		_apply_backpack_grid_layout(grid)

	# 初始化 MVP
	_data = BackpackData.new()
	_presenter = BackpackPresenterScript.new()
	_presenter.setup(_data, self)

	# 设置拖拽穿透支持（占位，自定义拖拽在 backpack_card_item.gd 中）
	_setup_drag_through_support()

	# 连接关闭按钮
	var close_btn = get_node_or_null("VBoxOuter/TitleRow/CloseButton")
	if close_btn:
		close_btn.pressed.connect(_on_close)

	# 连接详情弹窗关闭按钮
	var popup = get_node_or_null("CardDetailPopup")
	if popup:
		var btn = popup.get_node_or_null("Margin/VBox/CloseButton")
		if btn:
			btn.pressed.connect(_on_detail_close)

	# 创建网格加载指示器（不加入场景树，需要时动态插入 CardGrid）
	_loading_label = Label.new()
	_loading_label.text = "刷新中..."
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 16)
	_loading_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9, 0.7))
	_loading_label.visible = false
	_loading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_label.set_meta("is_loading_indicator", true)

func _exit_tree() -> void:
	if _presenter:
		_presenter.cleanup()
		_presenter = null
	_data = null

## ============================================================
## 公共接口（向后兼容）
## ============================================================

## 供存档读取：当前背包中额外卡 ID 列表
func get_extra_card_ids() -> Array:
	if _data:
		return _data.get_extra_card_ids()
	return []

## 获取背包中所有卡牌 ID（默认卡 + 额外卡）
func get_all_card_ids() -> Array:
	if _data:
		return _data.get_all_card_ids()
	return []

## 读档后恢复额外卡牌
func restore_extra_cards(ids: Array) -> void:
	if _presenter:
		_presenter.restore_extra_cards(ids)

## 获取背包统计信息
func get_backpack_statistics() -> Dictionary:
	if _data:
		return _data.get_statistics()
	return {}

## 筛选（兼容旧接口，参数为 int）
func set_filter_type(filter_type: int) -> void:
	if _presenter:
		_presenter.set_filter_type(filter_type)

## 排序（兼容旧接口，参数为 String）
func set_sort_type(sort_type: String) -> void:
	if _presenter:
		var int_type: int = _sort_type_string_to_int(sort_type)
		_presenter.set_sort_type(int_type)

## 重置筛选
func reset_filters() -> void:
	if _presenter:
		_presenter.reset_filters()

## 快速稀有度筛选
func quick_filter_by_rarity(rarity: String) -> void:
	if _presenter:
		_presenter.quick_filter_by_rarity(rarity)

## ============================================================
## View 接口方法（供 Presenter 调用）
## ============================================================

## 重建整个卡片网格（实际在下一 idle 执行，避免装备/拖拽回调链内 free 子节点）
func rebuild_card_grid(cards: Array) -> void:
	_rebuild_grid_snapshot = cards.duplicate()
	if _rebuild_grid_scheduled:
		return
	_rebuild_grid_scheduled = true
	_show_loading_indicator()
	call_deferred("_flush_rebuild_card_grid")

func _flush_rebuild_card_grid() -> void:
	var t0: int = Time.get_ticks_msec()
	_rebuild_grid_scheduled = false
	if not is_inside_tree():
		_rebuild_grid_snapshot.clear()
		return
	var cards: Array = _rebuild_grid_snapshot.duplicate()
	_rebuild_grid_snapshot.clear()
	var grid = get_node_or_null("VBoxOuter/ScrollContainer/CardGrid") as GridContainer
	if grid == null:
		return
	_apply_backpack_grid_layout(grid)
	var to_clear: Array = grid.get_children().duplicate()
	for child in to_clear:
		if is_instance_valid(child):
			if child.has_meta("is_loading_indicator") and child.get_meta("is_loading_indicator"):
				continue
			if child.has_method("set_card"):
				grid.remove_child(child)
				if child.card_clicked.is_connected(_on_card_clicked):
					child.card_clicked.disconnect(_on_card_clicked)
				_card_item_pool.append(child)
			elif child.has_meta("is_resource_slot") and child.get_meta("is_resource_slot"):
				grid.remove_child(child)
				_resource_slot_pool.append(child)
			elif child.has_meta("is_empty_slot") and child.get_meta("is_empty_slot"):
				grid.remove_child(child)
				child.visible = false
				_empty_slot_pool.append(child)
			else:
				child.free()
	# 全量重建后重置增量签名，避免后续刷新因“签名未变”而误跳过重建。
	_last_lore_signature = ""
	_last_stat_boost_signature = ""
	# 基础资源不在背包网格展示（见左上角资源面板等）；此处仅卡牌 + 空位，情报/属性由 refresh_* 增量维护。
	for card in cards:
		if card is CardResource:
			_add_card_item(grid, card)
	_ensure_min_card_slots()
	_sync_card_grid_scroll_size()
	_hide_loading_indicator()

## 添加单张卡到网格末尾或顶部
func add_card(card: CardResource, at_top: bool = false) -> void:
	var grid = get_node_or_null("VBoxOuter/ScrollContainer/CardGrid") as GridContainer
	if grid == null:
		return
	_apply_backpack_grid_layout(grid)
	_add_card_item(grid, card, at_top)
	_ensure_min_card_slots()
	_schedule_sync_card_grid_scroll_size()
	# 滚动到新卡位置
	if get_tree():
		await get_tree().process_frame
	_schedule_sync_card_grid_scroll_size()
	var sc := _scroll
	if sc:
		var sb := sc.get_v_scroll_bar()
		if sb:
			if at_top:
				sc.scroll_vertical = 0
			else:
				sc.scroll_vertical = int(sb.max_value)

## 从网格中移除一张匹配 card_id 的卡（默认移除最后一张，兼容同 ID 重复卡）
func remove_last_card_by_id(card_id: String) -> bool:
	if card_id.is_empty():
		return false
	var grid = get_node_or_null("VBoxOuter/ScrollContainer/CardGrid") as GridContainer
	if grid == null:
		return false
	var target: Node = null
	for child in grid.get_children():
		if not (child is Control):
			continue
		if child.has_meta("is_resource_slot") and child.get_meta("is_resource_slot"):
			continue
		if child.has_meta("is_empty_slot") and child.get_meta("is_empty_slot"):
			continue
		if child.has_method("set_card"):
			var card: CardResource = child.card if "card" in child else null
			if card != null and card.card_id == card_id:
				target = child
	if target == null:
		return false
	grid.remove_child(target)
	if target.has_signal("card_clicked") and target.card_clicked.is_connected(_on_card_clicked):
		target.card_clicked.disconnect(_on_card_clicked)
	_card_item_pool.append(target)
	_ensure_min_card_slots()
	_schedule_sync_card_grid_scroll_size()
	return true

## 高亮最后一个匹配 card_id 的卡
func highlight_last_card_by_id(card_id: String) -> void:
	var grid = get_node_or_null("VBoxOuter/ScrollContainer/CardGrid")
	if grid == null:
		return
	var target: Control = null
	for child in grid.get_children():
		if child.has_meta("is_resource_slot") and child.get_meta("is_resource_slot"):
			continue
		if child.has_method("set_card"):
			var card: CardResource = child.card if "card" in child else null
			if card != null and card.card_id == card_id:
				target = child
	if target:
		_highlight_card_item(target)

## 将顶级能量卡移动到网格最前面
func pin_top_energy_to_front() -> void:
	var grid = get_node_or_null("VBoxOuter/ScrollContainer/CardGrid") as GridContainer
	if grid == null:
		return
	_apply_backpack_grid_layout(grid)
	for child in grid.get_children():
		if child.has_meta("is_resource_slot") and child.get_meta("is_resource_slot"):
			continue
		var card: CardResource = child.card if "card" in child else null
		if card == null:
			continue
		if card.card_id == "energy_start_3" or card.card_id == "energy_start_7":
			grid.move_child(child, 0)
			return

## 能量卡无 MTG 竖卡面，仍用弹窗文本区展示
func _detail_uses_card_face_only(card: CardResource) -> bool:
	return card != null and card.card_type != GC.CardType.ENERGY


func _set_detail_popup_header_fields_visible(popup: PopupPanel, visible: bool) -> void:
	for node_path in [
		"Margin/VBox/Header",
		"Margin/VBox/LevelLabel",
		"Margin/VBox/TypeLineLabel",
		"Margin/VBox/SummaryLabel",
	]:
		var n: Node = popup.get_node_or_null(node_path)
		if n:
			n.visible = visible


## 显示卡片详情弹窗
func show_card_detail(card: CardResource, _source_item: Control) -> void:
	var popup = get_node_or_null("CardDetailPopup")
	if popup == null:
		return

	var use_face: bool = _detail_uses_card_face_only(card)
	if use_face:
		_refresh_detail_card_face(popup, card)
	else:
		var vbox_clear: VBoxContainer = popup.get_node_or_null("Margin/VBox") as VBoxContainer
		_clear_detail_card_faces(vbox_clear)

	_set_detail_popup_header_fields_visible(popup, not use_face)

	var name_l = popup.get_node_or_null("Margin/VBox/Header/NameLabel")
	var cost_l = popup.get_node_or_null("Margin/VBox/Header/CostLabel")
	var level_l = popup.get_node_or_null("Margin/VBox/LevelLabel")
	var type_l = popup.get_node_or_null("Margin/VBox/TypeLineLabel")
	var sum_l = popup.get_node_or_null("Margin/VBox/SummaryLabel")
	var desc_l = popup.get_node_or_null("Margin/VBox/DescLabel")
	var flavor_l = popup.get_node_or_null("Margin/VBox/FlavorLabel")
	var detail_star: int = card.star_level if card.star_level > 0 else BlueprintManager.get_blueprint_star(card.card_id)

	if not use_face:
		if name_l:
			name_l.text = card.display_name
		if cost_l:
			cost_l.text = "%d⚡" % int(card.energy_cost)
		if level_l:
			var dropped_mark: String = " [掉落卡]" if card.is_dropped_card else ""
			var star_line: String = "★%d%s" % [detail_star, dropped_mark]
			var rank_line: String = RankDisplayUi.format_line(RankDisplayUi.resolve_from_card_resource(card))
			if not rank_line.is_empty():
				rank_line = "\n" + rank_line
			level_l.text = star_line + rank_line
		if type_l:
			type_l.text = card.type_line
		if sum_l:
			var combat_line: String = BackpackCombatPreview.build_line(card)
			var use_combat_only: bool = (
				not combat_line.is_empty()
				and (
					card.card_type == GC.CardType.COMBAT_UNIT
					or card.card_type == GC.CardType.COMBAT_UNIT
					or card.card_type == GC.CardType.COMBAT_UNIT
				)
			)
			if use_combat_only:
				sum_l.text = combat_line
			else:
				sum_l.text = card.summary_line

	if desc_l:
		desc_l.text = card.description
	if flavor_l:
		flavor_l.text = card.flavor_text

	if desc_l and BlueprintManager and BlueprintManager.has_method("get_star_enhancement_lines"):
		var enhance_lines: Array[String] = BlueprintManager.get_star_enhancement_lines(card.card_id, detail_star)
		if not enhance_lines.is_empty():
			desc_l.text += "\n\n【星级强化（★%d）】\n- %s" % [detail_star, "\n- ".join(enhance_lines)]

	_refresh_popup_affixes(popup, card)
	_clear_popup_action_buttons(popup)

	if card.card_type == GC.CardType.LAW or card.card_type == GC.CardType.ENERGY:
		_add_equip_button(popup, card)
	_add_dismantle_button(popup, card)

	if use_face:
		popup.size = Vector2i(360, 580)
	else:
		popup.size = Vector2i(320, 380)
	popup.popup_centered()


## 移除详情弹窗内所有卡面预览（queue_free 会延迟一帧，重复点击会叠多张）
func _clear_detail_card_faces(vbox: VBoxContainer) -> void:
	if vbox == null:
		return
	var to_remove: Array[Node] = []
	for ch in vbox.get_children():
		if ch.name == "CardFacePreview":
			to_remove.append(ch)
	for ch in to_remove:
		vbox.remove_child(ch)
		ch.free()


## 详情弹窗顶部：完整竖卡面（MTG 排版，5:7 缩略）
func _refresh_detail_card_face(popup: PopupPanel, card: CardResource) -> void:
	var vbox: VBoxContainer = popup.get_node_or_null("Margin/VBox") as VBoxContainer
	if vbox == null or card == null:
		return
	_clear_detail_card_faces(vbox)
	var wrap := CenterContainer.new()
	wrap.name = "CardFacePreview"
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var item: Control = CardItemScene.instantiate()
	if item == null:
		return
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if "SLOT_SIZE" in item:
		item.SLOT_SIZE = DETAIL_CARD_FACE_SIZE
	if item is Control:
		(item as Control).custom_minimum_size = DETAIL_CARD_FACE_SIZE
	if item.has_method("set_meta"):
		item.set_meta("_pv_mtg_layout", true)
		item.set_meta("_pv_mtg_art_pct", 62)
		item.set_meta("_pv_name_ml", 6)
	wrap.add_child(item)
	if item.has_method("set_card"):
		item.set_card(card)
	if item.has_method("mtg_preview_refresh_art_layout"):
		item.call_deferred("mtg_preview_refresh_art_layout")
	vbox.add_child(wrap)
	vbox.move_child(wrap, 0)


## 供相位仪等外部 UI 直接打开详情（含完整卡面）
static func open_card_detail(card: CardResource, source_item: Control = null) -> void:
	if card == null:
		return
	var panel: Node = NodeFinder.get_backpack_panel()
	if panel and panel.has_method("show_card_detail"):
		panel.show_card_detail(card, source_item)


## 隐藏详情弹窗
func hide_card_detail() -> void:
	var popup = get_node_or_null("CardDetailPopup")
	if popup:
		var vbox: VBoxContainer = popup.get_node_or_null("Margin/VBox") as VBoxContainer
		_clear_detail_card_faces(vbox)
		popup.hide()

## 发射关闭信号
func emit_closed() -> void:
	closed.emit()

## 按稀有度过滤可见性
func apply_rarity_filter(rarity: String) -> void:
	var grid = get_node_or_null("VBoxOuter/ScrollContainer/CardGrid")
	if not grid:
		return
	for child in grid.get_children():
		if child.has_meta("is_resource_slot") and child.get_meta("is_resource_slot"):
			continue
		if child.has_method("set_card"):
			var card: CardResource = child.card if "card" in child else null
			if card != null and card.rarity != rarity:
				child.visible = false
			else:
				child.visible = true

## 重置所有子节点可见性
func reset_visibility() -> void:
	var grid = get_node_or_null("VBoxOuter/ScrollContainer/CardGrid")
	if not grid:
		return
	for child in grid.get_children():
		child.visible = true

## 刷新情报页显示
func refresh_lore_pages() -> void:
	var grid = get_node_or_null("VBoxOuter/ScrollContainer/CardGrid") as GridContainer
	if grid == null:
		return
	_apply_backpack_grid_layout(grid)
	var lm = get_node_or_null("/root/LoreManager")
	if lm == null or not lm.has_method("get_unlocked_lore"):
		return
	var unlocked_lore: Array[Dictionary] = lm.get_unlocked_lore()
	var target_ids: Array[String] = []
	for lore_data in unlocked_lore:
		var lore_id: String = str(lore_data.get("id", ""))
		if not lore_id.is_empty():
			target_ids.append(lore_id)
	var lore_signature := "|".join(target_ids)
	if lore_signature == _last_lore_signature:
		return
	var existing_by_id: Dictionary = {}
	for child in grid.get_children():
		if child.has_meta("is_lore_page") and child.get_meta("is_lore_page"):
			var lore_id_existing: String = str(child.get_meta("lore_id", ""))
			if lore_id_existing.is_empty():
				continue
			existing_by_id[lore_id_existing] = child
	var target_set: Dictionary = {}
	for lore_id in target_ids:
		target_set[lore_id] = true
	# 移除已失效项
	for lore_id_existing in existing_by_id.keys():
		if target_set.has(lore_id_existing):
			continue
		var stale_item: Node = existing_by_id[lore_id_existing]
		if stale_item != null and is_instance_valid(stale_item):
			grid.remove_child(stale_item)
			_lore_slot_pool.append(stale_item)
	# 补齐新增项
	for lore_id in target_ids:
		if existing_by_id.has(lore_id):
			continue
		_add_lore_page_item(grid, lore_id)
	_last_lore_signature = lore_signature
	_schedule_sync_card_grid_scroll_size()

## 刷新属性提升显示
func refresh_stat_boosts() -> void:
	var grid = get_node_or_null("VBoxOuter/ScrollContainer/CardGrid") as GridContainer
	if grid == null:
		return
	_apply_backpack_grid_layout(grid)
	var sbm = get_node_or_null("/root/StatBoostManager")
	if sbm == null or not sbm.has_method("get_all_boosts"):
		return
	var boosts: Array[Dictionary] = sbm.get_all_boosts()
	var target_counts: Dictionary = {}
	var signature_parts: Array[String] = []
	for boost_data in boosts:
		var boost_id: String = str(boost_data.get("id", ""))
		var count: int = boost_data.get("count", 0)
		if boost_id.is_empty() or count <= 0:
			continue
		target_counts[boost_id] = count
		signature_parts.append("%s:%d" % [boost_id, count])
	signature_parts.sort()
	var stat_signature := "|".join(signature_parts)
	if stat_signature == _last_stat_boost_signature:
		return
	var existing_by_id: Dictionary = {}
	for child in grid.get_children():
		if child.has_meta("is_stat_boost") and child.get_meta("is_stat_boost"):
			var boost_id_existing: String = str(child.get_meta("boost_id", ""))
			if boost_id_existing.is_empty():
				continue
			existing_by_id[boost_id_existing] = child
	# 移除已失效项
	for boost_id_existing in existing_by_id.keys():
		if target_counts.has(boost_id_existing):
			continue
		var stale_item: Node = existing_by_id[boost_id_existing]
		if stale_item != null and is_instance_valid(stale_item):
			grid.remove_child(stale_item)
			_stat_boost_slot_pool.append(stale_item)
	# 增量更新/新增
	for boost_id in target_counts.keys():
		var count: int = int(target_counts[boost_id])
		if existing_by_id.has(boost_id):
			var existing_item: Node = existing_by_id[boost_id]
			if existing_item != null and is_instance_valid(existing_item) and existing_item.has_method("set_data"):
				existing_item.set_data(boost_id, count, ResourceSlotItem.SlotType.STAT_BOOST)
			continue
		_add_stat_boost_item(grid, boost_id, count)
	_last_stat_boost_signature = stat_signature
	_schedule_sync_card_grid_scroll_size()

## ============================================================
## UI 事件回调（转发给 Presenter）
## ============================================================

## 卡牌点击（被 backpack_card_item 的 card_clicked 信号调用）
## 同时被 phase_instrument_panel.gd 跨节点调用，必须保持此签名
func _on_card_clicked(card: CardResource, source_item: Control) -> void:
	if _presenter:
		_presenter.on_card_clicked(card, source_item)

func _on_detail_close() -> void:
	if _presenter:
		_presenter.on_detail_close()

func _on_close() -> void:
	if _presenter:
		_presenter.on_close()

## 外部打开背包面板时调用：仅在隐藏期间有脏数据时做一次刷新
func on_overlay_opened() -> void:
	if _presenter and _presenter.has_method("on_overlay_opened"):
		_presenter.on_overlay_opened()

func _refresh_aux_sections_after_open() -> void:
	if not is_visible_in_tree():
		return
	refresh_lore_pages()
	refresh_stat_boosts()

## ============================================================
## 内部 UI 方法
## ============================================================

func _add_card_item(grid: GridContainer, card: CardResource, at_top: bool = false) -> void:
	var item = null
	if not _card_item_pool.is_empty():
		item = _card_item_pool.pop_back()
	else:
		item = CardItemScene.instantiate()
	if item == null:
		push_error("[backpack_panel] Failed to instantiate CardItemScene!")
		return
	# 池化节点可能继承了上一次筛选后的隐藏状态，复用时必须显式复位。
	if item is CanvasItem:
		(item as CanvasItem).visible = true
	if item is Control:
		(item as Control).modulate = Color(1, 1, 1, 1)
	grid.add_child(item)
	item.set_card(card)
	if not item.card_clicked.is_connected(_on_card_clicked):
		item.card_clicked.connect(_on_card_clicked)
	var insert_idx := 0 if at_top else _find_first_empty_slot_index(grid)
	if insert_idx >= 0:
		grid.move_child(item, insert_idx)

func _find_first_empty_slot_index(grid: GridContainer) -> int:
	if grid == null:
		return -1
	var idx := 0
	for child in grid.get_children():
		if child.has_meta("is_empty_slot") and child.get_meta("is_empty_slot"):
			return idx
		idx += 1
	return -1

func _highlight_card_item(item: Control) -> void:
	if item == null or not is_instance_valid(item):
		return
	var t := create_tween()
	t.tween_property(item, "modulate", Color(0.4, 1.0, 0.9, 1.0), 0.0)
	t.tween_property(item, "modulate", Color(1, 1, 1, 1), 0.5).set_ease(Tween.EASE_OUT)

func _ensure_min_card_slots() -> void:
	var grid = get_node_or_null("VBoxOuter/ScrollContainer/CardGrid") as GridContainer
	if grid == null:
		return
	var card_count := 0
	for child in grid.get_children():
		if child.has_meta("is_resource_slot") and child.get_meta("is_resource_slot"):
			continue
		card_count += 1
	# 不再强制补满固定格数：按「至少一行 + 多一行余量」扩展，上限 MAX_CARD_SLOTS
	var target_total: int = mini(
		MAX_CARD_SLOTS,
		maxi(BACKPACK_GRID_COLUMNS, card_count + BACKPACK_GRID_COLUMNS)
	)
	while card_count < target_total:
		# 空槽用轻量 Panel 占位，避免实例化完整 backpack_card_item
		var placeholder: Panel
		if _empty_slot_pool.size() > 0:
			placeholder = _empty_slot_pool.pop_back() as Panel
			placeholder.visible = true
		else:
			placeholder = Panel.new()
			placeholder.set_meta("is_empty_slot", true)
			placeholder.custom_minimum_size = CARD_SLOT_MIN
			placeholder.mouse_filter = Control.MOUSE_FILTER_STOP
			placeholder.add_theme_stylebox_override("panel", _get_empty_slot_style())
		grid.add_child(placeholder)
		card_count += 1

func _get_empty_slot_style() -> StyleBoxFlat:
	if _empty_slot_style != null:
		return _empty_slot_style
	_empty_slot_style = StyleBoxFlat.new()
	_empty_slot_style.bg_color = Color(0.06, 0.10, 0.17, 0.45)
	_empty_slot_style.set_border_width_all(1)
	_empty_slot_style.border_color = Color(0.25, 0.35, 0.5, 0.4)
	_empty_slot_style.set_corner_radius_all(5)
	return _empty_slot_style

## ScrollContainer 内 Grid 在部分布局下不会把内容高度传给滚动条，导致无法向下滚；延迟一帧写入最小高度
func _schedule_sync_card_grid_scroll_size() -> void:
	if not is_inside_tree():
		return
	call_deferred("_sync_card_grid_scroll_size")

func _sync_card_grid_scroll_size() -> void:
	var grid := get_node_or_null("VBoxOuter/ScrollContainer/CardGrid") as GridContainer
	if grid == null or not is_instance_valid(grid):
		return
	grid.update_minimum_size()
	var ms: Vector2 = grid.get_combined_minimum_size()
	var h: float = ms.y
	if h <= 1.0:
		var cols: int = BACKPACK_GRID_COLUMNS
		var cnt: int = grid.get_child_count()
		var rows: int = ceili(float(cnt) / float(cols))
		var sep: int = grid.get_theme_constant("v_separation", "GridContainer")
		var row_h: int = int(CARD_SLOT_MIN.y)
		for c in grid.get_children():
			if c is Control:
				row_h = maxi(row_h, int((c as Control).get_combined_minimum_size().y))
				break
		h = float(rows * row_h + maxi(0, rows - 1) * sep)
	grid.custom_minimum_size.y = maxf(h, 1.0)

## 固定列数 + 横向最小宽度（避免列数被意外改写）
func _apply_backpack_grid_layout(grid: GridContainer) -> void:
	if grid == null or not is_instance_valid(grid):
		return
	grid.columns = BACKPACK_GRID_COLUMNS
	var sep_h: int = grid.get_theme_constant("h_separation", "GridContainer")
	grid.custom_minimum_size.x = float(
		BACKPACK_GRID_COLUMNS * int(CARD_SLOT_MIN.x) + maxi(0, BACKPACK_GRID_COLUMNS - 1) * sep_h
	)

func _setup_drag_through_support() -> void:
	# 自定义拖拽系统在 backpack_card_item.gd 中实现
	pass

func _show_loading_indicator() -> void:
	if not _loading_label or not is_instance_valid(_loading_label):
		return
	var grid = get_node_or_null("VBoxOuter/ScrollContainer/CardGrid") as GridContainer
	if grid == null:
		return
	if _loading_label.get_parent() != grid:
		grid.add_child(_loading_label)
	grid.move_child(_loading_label, 0)
	_loading_label.visible = true

func _hide_loading_indicator() -> void:
	if not _loading_label or not is_instance_valid(_loading_label):
		return
	_loading_label.visible = false
	if _loading_label.get_parent():
		_loading_label.get_parent().remove_child(_loading_label)

## ============================================================
## 详情弹窗辅助
## ============================================================

const POPUP_ACTION_BUTTON_NAMES: Array[StringName] = [
	&"DismantleButton",
	&"EquipToPhaseButton",
]

func _clear_popup_action_buttons(popup: Window) -> void:
	var vbox_popup: VBoxContainer = popup.get_node_or_null("Margin/VBox") as VBoxContainer
	if vbox_popup == null:
		return
	var to_remove: Array[Node] = []
	for ch in vbox_popup.get_children():
		if ch.name in POPUP_ACTION_BUTTON_NAMES:
			to_remove.append(ch)
	for ch in to_remove:
		vbox_popup.remove_child(ch)
		ch.free()

func _add_equip_button(popup: Window, card: CardResource) -> void:
	var vbox_popup = popup.get_node_or_null("Margin/VBox")
	if vbox_popup == null:
		return
	var equip_btn := Button.new()
	equip_btn.name = "EquipToPhaseButton"
	equip_btn.text = "装备到相位仪"
	equip_btn.custom_minimum_size = Vector2(200, 36)
	equip_btn.add_theme_font_size_override("font_size", 13)
	equip_btn.add_theme_color_override("font_color", Color(0, 0.94, 1, 1))
	var _card_ref = card
	equip_btn.pressed.connect(func():
		if _presenter:
			_presenter.on_equip_button_pressed(_card_ref)
	)
	vbox_popup.add_child(equip_btn)
	var close_btn = vbox_popup.get_node_or_null("CloseButton")
	if close_btn:
		vbox_popup.move_child(equip_btn, close_btn.get_index())

func _add_dismantle_button(popup: Window, card: CardResource) -> void:
	var vbox_popup = popup.get_node_or_null("Margin/VBox")
	if vbox_popup == null:
		return
	var dismantle_btn := Button.new()
	dismantle_btn.name = "DismantleButton"
	dismantle_btn.text = "拆解（研究点 + 纳米材料）"
	dismantle_btn.custom_minimum_size = Vector2(200, 36)
	dismantle_btn.add_theme_font_size_override("font_size", 13)
	dismantle_btn.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35, 1.0))
	var _card_ref = card
	dismantle_btn.pressed.connect(func():
		if _presenter and _presenter.has_method("on_dismantle_button_pressed"):
			_presenter.on_dismantle_button_pressed(_card_ref)
	)
	vbox_popup.add_child(dismantle_btn)
	var close_btn = vbox_popup.get_node_or_null("CloseButton")
	if close_btn:
		vbox_popup.move_child(dismantle_btn, close_btn.get_index())

## 在详情弹窗中刷新词条区域
func _refresh_popup_affixes(popup: Window, card: CardResource) -> void:
	ManagerLazyLoader.ensure_loaded("affix")
	var AffixManager = get_node_or_null("/root/AffixManager")
	if card == null or AffixManager == null:
		return
	var vbox: VBoxContainer = popup.get_node_or_null("Margin/VBox")
	if vbox == null:
		return
	var old_affix_box: Node = vbox.get_node_or_null("AffixBox")
	if old_affix_box:
		old_affix_box.queue_free()
	var old_sep: Node = vbox.get_node_or_null("AffixSep")
	if old_sep:
		old_sep.queue_free()

	var affixes: Array = AffixManager.get_card_affixes(card.card_id)
	if affixes.is_empty():
		return

	var sep := HSeparator.new()
	sep.name = "AffixSep"
	sep.add_theme_color_override("color", Color(0.60, 0.35, 1.0, 0.4))
	vbox.add_child(sep)
	var close_btn: Node = vbox.get_node_or_null("CloseButton")
	if close_btn:
		vbox.move_child(sep, close_btn.get_index())

	var affix_box := VBoxContainer.new()
	affix_box.name = "AffixBox"
	affix_box.add_theme_constant_override("separation", 3)
	vbox.add_child(affix_box)
	var close_btn2: Node = vbox.get_node_or_null("CloseButton")
	if close_btn2:
		vbox.move_child(affix_box, close_btn2.get_index())

	var title := Label.new()
	title.text = "词条加成"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.80, 0.50, 1.0, 1.0))
	affix_box.add_child(title)

	for a_raw in affixes:
		var affix: AffixResource = a_raw as AffixResource
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		affix_box.add_child(row)

		var dot := Label.new()
		match affix.rarity:
			"common":    dot.text = "◇"
			"rare":      dot.text = "◆"
			"epic":      dot.text = "★"
			"legendary": dot.text = "✦"
			_:           dot.text = "·"
		dot.add_theme_font_size_override("font_size", 11)
		dot.add_theme_color_override("font_color", GC.get_rarity_color(affix.rarity))
		dot.custom_minimum_size = Vector2(16, 0)
		row.add_child(dot)

		var lbl := Label.new()
		lbl.text = affix.get_detailed_description()
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.88, 0.95))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(lbl)

		if affix.is_mutated:
			var mut_dot := Label.new()
			mut_dot.text = "⚡"
			mut_dot.add_theme_font_size_override("font_size", 11)
			mut_dot.add_theme_color_override("font_color", Color(1.0, 0.80, 0.1, 1.0))
			mut_dot.tooltip_text = affix.mutation_description
			row.add_child(mut_dot)


## ============================================================
## 资源/情报/属性提升 添加方法
## ============================================================

func _add_lore_page_item(grid: GridContainer, lore_id: String) -> void:
	var item = null
	if not _lore_slot_pool.is_empty():
		item = _lore_slot_pool.pop_back()
	else:
		item = ResourceSlotScene.instantiate()
	if item == null:
		return
	grid.add_child(item)
	item.set_meta("is_lore_page", true)
	item.set_meta("lore_id", lore_id)
	if item.has_method("set_data"):
		item.set_data(lore_id, 1, ResourceSlotItem.SlotType.LORE)

func _add_stat_boost_item(grid: GridContainer, boost_id: String, count: int) -> void:
	var item = null
	if not _stat_boost_slot_pool.is_empty():
		item = _stat_boost_slot_pool.pop_back()
	else:
		item = ResourceSlotScene.instantiate()
	if item == null:
		return
	grid.add_child(item)
	item.set_meta("is_stat_boost", true)
	item.set_meta("boost_id", boost_id)
	if item.has_method("set_data"):
		item.set_data(boost_id, count, ResourceSlotItem.SlotType.STAT_BOOST)

## ============================================================
## 辅助
## ============================================================

func _sort_type_string_to_int(sort_type: String) -> int:
	match sort_type:
		"default": return BackpackData.SortType.DEFAULT
		"name": return BackpackData.SortType.NAME
		"cost": return BackpackData.SortType.COST
		"rarity": return BackpackData.SortType.RARITY
		_: return BackpackData.SortType.DEFAULT