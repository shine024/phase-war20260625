extends PanelContainer
## 背包面板 -- View 层（MVP 模式）
## 负责所有 UI 渲染和用户输入转发。
## 业务逻辑已拆分到 BackpackPresenter，数据管理已拆分到 BackpackData。
##
## v6.0 新增：标签页功能
## - 战斗卡标签：显示所有战斗单位卡片
## - 资源标签：显示基础资源
## - 情报标签：显示情报页
## - 属性提升标签：显示属性提升道具
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
const CardInfoPanel = preload("res://scenes/ui/card_info_panel.gd")
const RankDisplayUi = preload("res://scripts/rank_display_ui.gd")
## 详情弹窗内的统一情报面板实例引用
var _detail_info_panel: Control = null
## ── 子系统：筛选/排序 ──
const FilterSortSub = preload("res://scripts/systems/backpack_filter_sort.gd")
var _filter_sort: BackpackFilterSort = null

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

## 标签页容器
@onready var _tab_container: TabContainer = $VBoxOuter/TabContainer

## 内嵌滚动容器（用于程序化滚动定位）
@onready var _scroll: ScrollContainer = $VBoxOuter/TabContainer/CombatCardsTab/ScrollContainer

## 各标签页的Grid引用
var _combat_cards_grid: GridContainer = null
var _resources_grid: GridContainer = null
var _intel_grid: GridContainer = null
var _stat_boosts_grid: GridContainer = null

## 相位仪快捷栏已移除（不再在背包内显示）

## 标签页索引枚举
enum TabIndex {
	COMBAT_CARDS = 0,
	RESOURCES = 1,
	INTEL = 2,
	STAT_BOOSTS = 3,
}

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
	_filter_sort = FilterSortSub.new()
	_filter_sort.setup(self)
	add_to_group("backpack_panel")

	# 初始化各标签页Grid引用
	_combat_cards_grid = get_node_or_null("VBoxOuter/TabContainer/CombatCardsTab/ScrollContainer/CardGrid") as GridContainer
	_resources_grid = get_node_or_null("VBoxOuter/TabContainer/ResourcesTab/ResourcesScroll/ResourcesGrid") as GridContainer
	_intel_grid = get_node_or_null("VBoxOuter/TabContainer/IntelTab/IntelScroll/IntelGrid") as GridContainer
	_stat_boosts_grid = get_node_or_null("VBoxOuter/TabContainer/StatBoostsTab/StatBoostsScroll/StatBoostsGrid") as GridContainer

	# 必须先锁定列数再 setup（setup 会立刻 rebuild，不能在 rebuild 之后才设 columns）
	if _combat_cards_grid:
		_apply_backpack_grid_layout(_combat_cards_grid)
	if _resources_grid:
		_apply_backpack_grid_layout(_resources_grid)
	if _intel_grid:
		_apply_backpack_grid_layout(_intel_grid)
	if _stat_boosts_grid:
		_apply_backpack_grid_layout(_stat_boosts_grid)

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

	# 设置标签页标题
	if _tab_container:
		_tab_container.set_tab_title(TabIndex.COMBAT_CARDS, "战斗卡")
		_tab_container.set_tab_title(TabIndex.RESOURCES, "资源")
		_tab_container.set_tab_title(TabIndex.INTEL, "情报")
		_tab_container.set_tab_title(TabIndex.STAT_BOOSTS, "属性提升")
		_tab_container.tab_changed.connect(_on_tab_changed)

	# 初始化详情弹窗（信号连接延迟到首次显示时）
	var popup = get_node_or_null("CardDetailPopup")
	if popup:
		_init_detail_info_panel(popup)
		# 点弹窗外关闭时也触发 hide_panel，避免旧 action 按钮残留造成下次点击按钮数翻倍
		if popup.has_signal("popup_hide") and not popup.popup_hide.is_connected(_on_detail_popup_hide):
			popup.popup_hide.connect(_on_detail_popup_hide)

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
## 标签页事件处理
## ============================================================

## 标签页切换事件
func _on_tab_changed(tab_index: int) -> void:
	match tab_index:
		TabIndex.COMBAT_CARDS:
			# 战斗卡标签页切换时刷新（如有需要）
			pass
		TabIndex.RESOURCES:
			# 资源标签页切换时刷新（如有需要）
			pass
		TabIndex.INTEL:
			# 情报标签页切换时刷新
			refresh_intel_tab()
		TabIndex.STAT_BOOSTS:
			# 属性提升标签页切换时刷新
			refresh_stat_boosts_tab()

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
	print("[BackpackPanel] rebuild_card_grid: cards=%d scheduled=%s" % [cards.size(), _rebuild_grid_scheduled])
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
	print("[BackpackPanel] _flush_rebuild: snapshot_count=%d grid_null=%s" % [cards.size(), _combat_cards_grid == null])
	_rebuild_grid_snapshot.clear()
	var grid = _combat_cards_grid
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
	# 全量重建后重置增量签名，避免后续刷新因"签名未变"而误跳过重建。
	_last_lore_signature = ""
	_last_stat_boost_signature = ""
	# 基础资源不在背包网格展示（见左上角资源面板等）；此处仅卡牌 + 空位，情报/属性由 refresh_* 增量维护。
	for card in cards:
		if card is CardResource:
			_add_card_item(grid, card)
	_ensure_min_card_slots(grid)
	_sync_card_grid_scroll_size_for_grid(grid)
	_hide_loading_indicator()

## 添加单张卡到网格末尾或顶部
func add_card(card: CardResource, at_top: bool = false) -> void:
	var grid = _combat_cards_grid
	if grid == null:
		return
	_apply_backpack_grid_layout(grid)
	_add_card_item(grid, card, at_top)
	_ensure_min_card_slots(grid)
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
	var grid = _combat_cards_grid
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
	_ensure_min_card_slots(grid)
	_schedule_sync_card_grid_scroll_size()
	return true

## 高亮最后一个匹配 card_id 的卡
func highlight_last_card_by_id(card_id: String) -> void:
	var grid = _combat_cards_grid
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
	var grid = _combat_cards_grid
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

## 在 CardDetailPopup 内引用已嵌入的统一情报面板（.tscn 子场景实例）
func _init_detail_info_panel(popup: PopupPanel) -> void:
	_detail_info_panel = popup.get_node_or_null("Margin/VBox/DetailInfoPanel") as Control


## 显示卡片详情弹窗（使用统一情报面板）
func show_card_detail(card: CardResource, _source_item: Control) -> void:
	var popup = get_node_or_null("CardDetailPopup")
	if popup == null or _detail_info_panel == null:
		return

	# 先隐藏全局 CardInfoPanel（防止与背包弹窗中的面板同时显示）
	var global_info_panel = NodeFinder.get_card_info_panel()
	if global_info_panel and global_info_panel.has_method("hide_panel"):
		global_info_panel.hide_panel()

	# 清理旧版手动词条区（AffixSep / AffixBox），统一面板已在 desc_label 中包含词条
	_cleanup_legacy_popup_affixes(popup)

	# 设置背包模式（面板内部自动添加拆解/装备按钮）
	if _detail_info_panel.has_method("set_panel_mode"):
		_detail_info_panel.set_panel_mode(CardInfoPanel.PanelMode.MODE_BACKPACK)
	# 连接 action_requested 信号（仅连接一次）
	if not _detail_info_panel.action_requested.is_connected(_on_detail_action_requested):
		_detail_info_panel.action_requested.connect(_on_detail_action_requested)

	# 使用统一情报面板显示卡牌信息（show_card_info 内部已设置 visible = true）
	if _detail_info_panel.has_method("show_card_info"):
		_detail_info_panel.show_card_info(card)
		# 背包模式使用 CardDetailPopup 的关闭按钮，隐藏内部关闭按钮
		if _detail_info_panel.has_method("set_close_button_visible"):
			_detail_info_panel.set_close_button_visible(false)

	# 显示 CloseButton（.tscn 中定义，关闭弹窗用）
	var close_btn: Button = popup.get_node_or_null("Margin/VBox/CloseButton") as Button
	if close_btn:
		close_btn.visible = true
		# 连接关闭按钮（只连接一次，连接到 _on_detail_close 以确保正确清理）
		if not close_btn.pressed.is_connected(_on_detail_close):
			close_btn.pressed.connect(_on_detail_close)

	# 弹窗大小已由 .tscn 设定（340×460）
	popup.popup_centered()


## 隐藏详情弹窗
func hide_card_detail() -> void:
	var popup = get_node_or_null("CardDetailPopup")
	if popup:
		popup.hide()
	if _detail_info_panel and is_instance_valid(_detail_info_panel) and _detail_info_panel.has_method("hide_panel"):
		_detail_info_panel.hide_panel()


## 统一面板 action_requested 信号回调
func _on_detail_action_requested(action: String, card: CardResource) -> void:
	match action:
		"dismantle":
			if _presenter and _presenter.has_method("on_dismantle_button_pressed"):
				_presenter.on_dismantle_button_pressed(card)
		"equip":
			if _presenter:
				_presenter.on_equip_button_pressed(card)

## 供相位仪等外部 UI 直接打开详情
static func open_card_detail(card: CardResource, source_item: Control = null) -> void:
	if card == null:
		return
	var panel: Node = NodeFinder.get_backpack_panel()
	if panel and panel.has_method("show_card_detail"):
		panel.show_card_detail(card, source_item)


## 发射关闭信号
func emit_closed() -> void:
	closed.emit()

## 按稀有度过滤可见性（委托 → BackpackFilterSort）
func apply_rarity_filter(rarity: String) -> void:
	if _filter_sort:
		_filter_sort.apply_rarity_filter(rarity)

## 重置所有子节点可见性（委托 → BackpackFilterSort）
func reset_visibility() -> void:
	if _filter_sort:
		_filter_sort.reset_visibility()

## ============================================================
## 标签页刷新方法
## ============================================================

## 刷新情报标签页
func refresh_intel_tab() -> void:
	if _intel_grid == null:
		return
	_apply_backpack_grid_layout(_intel_grid)
	var lm = get_node_or_null("/root/LoreManager")
	if lm == null or not lm.has_method("get_unlocked_lore"):
		_add_intel_placeholder(_intel_grid, "情报系统未初始化")
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

	# 清空现有内容
	for child in _intel_grid.get_children():
		child.queue_free()

	if unlocked_lore.is_empty():
		_add_intel_placeholder(_intel_grid, "暂无已解锁情报\n（战斗掉落情报页后显示于此）")
		_last_lore_signature = lore_signature
		return

	# 添加情报页
	for lore_data in unlocked_lore:
		var lore_id: String = str(lore_data.get("id", ""))
		_add_intel_item(_intel_grid, lore_id)

	_last_lore_signature = lore_signature
	_schedule_sync_card_grid_scroll_size_for_grid(_intel_grid)

func _add_intel_placeholder(grid: GridContainer, message: String) -> void:
	var lbl := Label.new()
	lbl.text = message
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 0.9))
	grid.add_child(lbl)

func _add_intel_item(grid: GridContainer, lore_id: String) -> void:
	var item = ResourceSlotScene.instantiate()
	if item == null:
		return
	grid.add_child(item)
	if item.has_method("set_data"):
		item.set_data(lore_id, 1, ResourceSlotItem.SlotType.LORE)

## 刷新属性提升标签页
func refresh_stat_boosts_tab() -> void:
	if _stat_boosts_grid == null:
		return
	_apply_backpack_grid_layout(_stat_boosts_grid)
	var sbm = get_node_or_null("/root/StatBoostManager")
	if sbm == null or not sbm.has_method("get_all_boosts"):
		_add_stat_boosts_placeholder(_stat_boosts_grid, "属性提升系统未初始化")
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

	# 清空现有内容
	for child in _stat_boosts_grid.get_children():
		child.queue_free()

	if target_counts.is_empty():
		_add_stat_boosts_placeholder(_stat_boosts_grid, "暂无属性提升")
		_last_stat_boost_signature = stat_signature
		return

	# 添加属性提升项
	for boost_id in target_counts.keys():
		var count: int = int(target_counts[boost_id])
		_add_stat_boost_item(_stat_boosts_grid, boost_id, count)

	_last_stat_boost_signature = stat_signature
	_schedule_sync_card_grid_scroll_size_for_grid(_stat_boosts_grid)

func _add_stat_boosts_placeholder(grid: GridContainer, message: String) -> void:
	var lbl := Label.new()
	lbl.text = message
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 0.9))
	grid.add_child(lbl)

## ============================================================
## 向后兼容方法（已废弃，保留以避免破坏现有调用）
## ============================================================

## 刷新情报页显示（废弃：使用 refresh_intel_tab 代替）
func refresh_lore_pages() -> void:
	# 如果当前在情报标签页，则刷新
	if _tab_container and _tab_container.current_tab == TabIndex.INTEL:
		refresh_intel_tab()

## 刷新属性提升显示（废弃：使用 refresh_stat_boosts_tab 代替）
func refresh_stat_boosts() -> void:
	# 如果当前在属性提升标签页，则刷新
	if _tab_container and _tab_container.current_tab == TabIndex.STAT_BOOSTS:
		refresh_stat_boosts_tab()

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

## PopupPanel.popup_hide 信号回调：点弹窗外区域/系统关闭时触发，确保内嵌情报面板状态清空
func _on_detail_popup_hide() -> void:
	if _detail_info_panel and is_instance_valid(_detail_info_panel) and _detail_info_panel.has_method("hide_panel"):
		_detail_info_panel.hide_panel()

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
	refresh_intel_tab()
	refresh_stat_boosts_tab()

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

func _ensure_min_card_slots(grid: GridContainer) -> void:
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

func _schedule_sync_card_grid_scroll_size_for_grid(grid: GridContainer) -> void:
	if not is_inside_tree():
		return
	call_deferred("_sync_card_grid_scroll_size_for_grid", grid)

func _sync_card_grid_scroll_size() -> void:
	_sync_card_grid_scroll_size_for_grid(_combat_cards_grid)

func _sync_card_grid_scroll_size_for_grid(grid: GridContainer) -> void:
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
	var grid = _combat_cards_grid
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
## 清理旧版手动词条区（已被统一情报面板 desc_label 内的词条摘要替代）
func _cleanup_legacy_popup_affixes(popup: Window) -> void:
	var vbox: VBoxContainer = popup.get_node_or_null("Margin/VBox")
	if vbox == null:
		return
	var old_affix_box: Node = vbox.get_node_or_null("AffixBox")
	if old_affix_box:
		old_affix_box.queue_free()
	var old_sep: Node = vbox.get_node_or_null("AffixSep")
	if old_sep:
		old_sep.queue_free()


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
	if _filter_sort:
		return _filter_sort.sort_type_string_to_int(sort_type)
	return BackpackData.SortType.DEFAULT
