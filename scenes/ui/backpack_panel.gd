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
const IntelManualItemsRef = preload("res://data/intel_manual_items.gd")
const BlueprintDefinitionsRef = preload("res://data/blueprint_definitions.gd")
const ModificationRegistryRef = preload("res://scripts/systems/modification_registry.gd")
const RankDisplayUi = preload("res://scripts/rank_display_ui.gd")
## 详情弹窗内的统一情报面板实例引用
var _detail_info_panel: Control = null
## ── 子系统：筛选/排序 ──
const FilterSortSub = preload("res://scripts/systems/backpack_filter_sort.gd")
var _filter_sort: BackpackFilterSort = null

## 与相位仪槽位、背包卡条目同尺寸（见 PhaseSlot.SLOT_SIZE）
const CARD_SLOT_MIN: Vector2 = PhaseSlot.SLOT_SIZE
## 背包卡槽上限，与 BackpackData.MAX_CARD_SLOTS 保持单一真相源（统计与 UI 必须一致）
const MAX_CARD_SLOTS := 50
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
var _runes_grid: GridContainer = null  ## v6.2: 符文格子

## 相位仪快捷栏已移除（不再在背包内显示）

## 标签页索引枚举
enum TabIndex {
	COMBAT_CARDS = 0,
	RESOURCES = 1,
	INTEL = 2,
	STAT_BOOSTS = 3,
	RUNES = 4,           ## v6.2: 符文标签
}

## 全量重建排到 idle 再执行：在背包卡 item 的 gui_input / 拖拽 / 装备信号栈内不能对其 free()，否则会报 Object is locked
var _rebuild_grid_snapshot: Array = []
var _rebuild_grid_scheduled: bool = false
var _empty_slot_style: StyleBoxFlat = null
var _card_item_pool: Array = []
var _resource_slot_pool: Array = []
var _lore_slot_pool: Array = []
var _stat_boost_slot_pool: Array = []
var _rune_slot_pool: Array = []          ## v6.2: 符文格子对象池
var _empty_slot_pool: Array = []
var _last_lore_signature: String = "__INIT__"
var _last_stat_boost_signature: String = "__INIT__"
var _last_resources_signature: String = "__INIT__"
var _last_runes_signature: String = "__INIT__"  ## v6.2: 符文签名去重
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
	_runes_grid = get_node_or_null("VBoxOuter/TabContainer/RunesTab/RunesScroll/RunesGrid") as GridContainer

	# 必须先锁定列数再 setup（setup 会立刻 rebuild，不能在 rebuild 之后才设 columns）
	if _combat_cards_grid:
		_apply_backpack_grid_layout(_combat_cards_grid)
	if _resources_grid:
		_apply_backpack_grid_layout(_resources_grid)
	if _intel_grid:
		_apply_backpack_grid_layout(_intel_grid)
	if _stat_boosts_grid:
		_apply_backpack_grid_layout(_stat_boosts_grid)
	if _runes_grid:
		_apply_backpack_grid_layout(_runes_grid)

	# 初始化 MVP
	_data = BackpackData.new()
	_presenter = BackpackPresenterScript.new()
	if _presenter != null:
		_presenter.setup(_data, self)
	else:
		push_error("[BackpackPanel] Failed to instantiate BackpackPresenter! Grid will use fallback init.")

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
		# v6.5 修复 M3：INTEL tab 实际显示改造蓝图（refresh_intel_tab 用 is_mod_blueprint 过滤），
		# 标题应为"改造"而非"情报"，原 158 行覆盖了 124 行的设置导致标签与内容不符
		_tab_container.set_tab_title(TabIndex.INTEL, "改造")
		_tab_container.set_tab_title(TabIndex.STAT_BOOSTS, "属性提升")
		_tab_container.set_tab_title(TabIndex.RUNES, "符文")
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

	# 防御性兜底：如果 presenter 初始化失败，手动从 SaveManager 恢复额外卡并构建网格
	if _presenter == null and _data != null:
		_fallback_init_from_save_manager()

	# v6.2: 监听符文获得信号——购买/掉落符文后实时刷新符文标签页，
	# 避免因 _aux_sections_initialized 仅首次刷新、签名缓存未失效导致新符文不显示。
	if SignalBus and SignalBus.has_signal("rune_acquired"):
		if not SignalBus.rune_acquired.is_connected(_on_rune_acquired):
			SignalBus.rune_acquired.connect(_on_rune_acquired)

func _exit_tree() -> void:
	# v6.2: 断开符文信号，防止面板销毁后回调访问已释放节点
	if SignalBus != null and SignalBus.has_signal("rune_acquired"):
		if SignalBus.rune_acquired.is_connected(_on_rune_acquired):
			SignalBus.rune_acquired.disconnect(_on_rune_acquired)
	if _presenter:
		_presenter.cleanup()
		_presenter = null
	_data = null

## v6.2: 符文获得回调——失效签名缓存并在可见时刷新符文标签
func _on_rune_acquired(_rune_id: String, _source: String) -> void:
	# 失效签名缓存，确保下次 refresh_runes_tab 一定会重建网格
	_last_runes_signature = "__INVALIDATED__"
	# 仅当背包可见且当前在符文标签页时立即刷新；否则等打开/切标签时自然会刷新
	if is_visible_in_tree() and _tab_container != null and _tab_container.current_tab == TabIndex.RUNES:
		refresh_runes_tab()

## Presenter 初始化失败时的兜底：直接从 SaveManager 恢复额外卡并构建网格，
## 确保用户至少能看到已有卡和空格子。
func _fallback_init_from_save_manager() -> void:
	push_warning("[BackpackPanel] Using fallback init (presenter unavailable)")
	# 从 SaveManager 恢复额外卡 ID
	var ids: Array = []
	if SaveManager and SaveManager.has_method("get_last_known_backpack_ids"):
		ids = SaveManager.get_last_known_backpack_ids()
	if ids.is_empty() and SaveManager and SaveManager.has_method("get_pending_backpack_ids"):
		ids = SaveManager.get_pending_backpack_ids()
	if not ids.is_empty():
		_data.restore_extra_cards(ids)
	# 连接全局信号以便后续卡牌变动能刷新
	if _data and not _data.cards_changed.is_connected(_fallback_on_cards_changed):
		_data.cards_changed.connect(_fallback_on_cards_changed)
	if SignalBus and SignalBus.has_signal("card_added_to_backpack"):
		if not SignalBus.card_added_to_backpack.is_connected(_fallback_on_card_added):
			SignalBus.card_added_to_backpack.connect(_fallback_on_card_added)
	if SignalBus and SignalBus.has_signal("card_equipped"):
		if not SignalBus.card_equipped.is_connected(_fallback_on_card_equipped):
			SignalBus.card_equipped.connect(_fallback_on_card_equipped)
	# 构建网格（至少显示空格子）
	var cards: Array = _data.get_filtered_sorted_cards()
	rebuild_card_grid(cards)

func _fallback_on_card_added(card: CardResource) -> void:
	if card == null or _data == null:
		return
	if SaveManager and SaveManager.has_method("consume_pending_backpack_card_id"):
		SaveManager.consume_pending_backpack_card_id(card.card_id)
	_data.add_extra_card(card.card_id, false)
	if SaveManager and SaveManager.has_method("enqueue_backpack_card_id"):
		SaveManager.enqueue_backpack_card_id(card.card_id)

func _fallback_on_cards_changed() -> void:
	if _data == null:
		return
	var cards: Array = _data.get_filtered_sorted_cards()
	rebuild_card_grid(cards)

func _fallback_on_card_equipped(_slot_index: int, card_id: String, _card_type: String) -> void:
	if _data == null or card_id.is_empty():
		return
	_data.remove_card(card_id, false)
	if SaveManager and SaveManager.has_method("_on_card_equipped_remove_fallback"):
		SaveManager._on_card_equipped_remove_fallback(_slot_index, card_id, _card_type)

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
			refresh_resources_tab()
		TabIndex.INTEL:
			# 情报标签页切换时刷新
			refresh_intel_tab()
		TabIndex.STAT_BOOSTS:
			# 属性提升标签页切换时刷新
			refresh_stat_boosts_tab()
		TabIndex.RUNES:
			# v6.2: 符文标签页刷新
			refresh_runes_tab()

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
	_rebuild_grid_scheduled = false
	if not is_inside_tree():
		_rebuild_grid_snapshot.clear()
		# [LOG-v5.1] print("[BP] _flush_rebuild: SKIP not in tree")
		return
	var cards: Array = _rebuild_grid_snapshot.duplicate()
	_rebuild_grid_snapshot.clear()
	var grid = _combat_cards_grid
	if grid == null:
		# [LOG-v5.1] print("[BP] _flush_rebuild: SKIP grid null")
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
	# signatures managed by individual tab refresh functions
	
	# 基础资源不在背包网格展示（见左上角资源面板等）；此处仅卡牌 + 空位，情报/属性由 refresh_* 增量维护。
	var added_count := 0
	for card in cards:
		if card is CardResource:
			_add_card_item(grid, card)
			added_count += 1
	_ensure_min_card_slots(grid)
	# 诊断：检查第一个卡片 item 的视觉状态
	var first_item = null
	for ch in grid.get_children():
		if ch.has_method("set_card") and ch.card != null:
			first_item = ch
			break
	if first_item:
		# [LOG-v5.1] print("[BP] _flush_rebuild: added=%d/%d grid_children=%d cols=%d item_visible=%s item_size=%s item_modulate=%s card_id=%s" % [added_count, cards.size(), grid.get_child_count(), grid.columns, first_item.visible, first_item.size, first_item.modulate, first_item.card.card_id if first_item.card else "null"])
		_diag_card_item_internals(first_item, grid)
	else:
		pass
		# [LOG-v5.1] print("[BP] _flush_rebuild: added=%d/%d BUT NO visible card item found! grid_children=%d" % [added_count, cards.size(), grid.get_child_count()])
	_sync_card_grid_scroll_size_for_grid(grid)
	_hide_loading_indicator()


func _diag_card_item_internals(item: Control, grid: GridContainer) -> void:
	var scroll = _scroll
	if scroll:
		pass
		# [LOG-v5.1] print("[BP DIAG] Scroll: vis=%s size=%s sv=%d" % [scroll.visible, scroll.size, scroll.scroll_vertical])
	var tab_ctr = _tab_container
	if tab_ctr:
		pass
		# [LOG-v5.1] print("[BP DIAG] TabCtr: tab=%d tabs=%d" % [tab_ctr.current_tab, tab_ctr.get_tab_count()])
	var combat_tab = get_node_or_null("VBoxOuter/TabContainer/CombatCardsTab")
	if combat_tab:
		pass
		# [LOG-v5.1] print("[BP DIAG] CombatTab: vis=%s size=%s" % [combat_tab.visible, combat_tab.size])
	# [LOG-v5.1] print("[BP DIAG] Grid: gpos=%s size=%s vis=%s" % [grid.global_position, grid.size, grid.visible])
	var vbox = item.get_node_or_null("VBox")
	if vbox:
		# [LOG-v5.1] print("[BP DIAG] VBox: vis=%s size=%s" % [vbox.visible, vbox.size])
		var cm = vbox.get_node_or_null("ContentMargin")
		if cm:
			# [LOG-v5.1] print("[BP DIAG] CM: vis=%s size=%s" % [cm.visible, cm.size])
			var ivb = cm.get_node_or_null("InnerVBox")
			if ivb:
				# [LOG-v5.1] print("[BP DIAG] InnerVB: vis=%s size=%s clip=%s" % [ivb.visible, ivb.size, ivb.clip_contents])
				var ir = ivb.get_node_or_null("IconRow")
				if ir:
					# [LOG-v5.1] print("[BP DIAG] IconRow: vis=%s size=%s ch=%d compact=%s" % [ir.visible, ir.size, ir.get_child_count(), ir.get_meta("_compact_slot_built", false)])
					for ic in ir.get_children():
						var sz = ic.size if ic is Control else "NA"
						# [LOG-v5.1] print("[BP DIAG]   %s: vis=%s size=%s" % [ic.name, ic.visible, sz])
						if ic.name == "CompactArtClip":
							var icon = ic.get_node_or_null("Icon")
							if icon:
								pass
								# [LOG-v5.1] print("[BP DIAG]     Icon: vis=%s size=%s tex=%s" % [icon.visible, icon.size, "YES" if icon.texture else "NULL"])
						if ic.name == "CompactTextVBox":
							for tc in ic.get_children():
								if tc is Label:
									pass
									# [LOG-v5.1] print("[BP DIAG]     %s: vis=%s text=%s" % [tc.name, tc.visible, tc.text])
	var sb = item.get_theme_stylebox("panel")
	if sb and sb is StyleBoxFlat:
		pass
		# [LOG-v5.1] print("[BP DIAG] panel: bg=%s bdr=%s" % [sb.bg_color, sb.border_color])
	# [LOG-v5.1] print("[BP DIAG] BPP: vis=%s size=%s gpos=%s" % [visible, size, global_position])

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

## 刷新改造标签页（v6.5: 显示所有已获得的改造，标注装配状态）
func refresh_intel_tab() -> void:
	if _intel_grid == null:
		return
	_apply_backpack_grid_layout(_intel_grid)
	var bag = get_node_or_null("/root/IntelItemBag")
	# 收集所有已装配在战斗卡上的 mod_id（用于标注装配状态）
	var installed_mod_ids: Dictionary = {}
	if BlueprintManager and "blueprint_mods" in BlueprintManager:
		for card_id in BlueprintManager.blueprint_mods:
			var mods_list = BlueprintManager.blueprint_mods[card_id]
			if mods_list is Array:
				for mod_entry in mods_list:
					var mid: String = ""
					if mod_entry is Dictionary:
						mid = String(mod_entry.get("id", ""))
					else:
						mid = String(mod_entry)
					if not mid.is_empty():
						installed_mod_ids[mid] = true
	# 从 IntelItemBag 收集所有已获得的改造图纸
	var bag_items: Dictionary = {}
	if bag and bag.has_method("get_all_inventory"):
		bag_items = bag.get_all_inventory()
	# 签名
	var sig_parts: Array[String] = []
	for bk in bag_items.keys():
		sig_parts.append("bag:" + bk + ":" + str(bag_items[bk]))
	for mid in installed_mod_ids.keys():
		sig_parts.append("inst:" + mid)
	sig_parts.sort()
	var sig := "|".join(sig_parts)
	if sig == _last_lore_signature:
		return
	_last_lore_signature = sig
	_clear_grid_children(_intel_grid)
	# 筛选：所有改造图纸（永久解锁，全部显示）
	var acquired_blueprints: Array[Dictionary] = []
	for item_type in bag_items.keys():
		var count: int = int(bag_items[item_type])
		if count <= 0:
			continue
		# 仅处理改造图纸（blueprint_ 前缀，排除 blueprint_evol_ 进化图纸）
		if not IntelManualItemsRef.is_mod_blueprint(item_type):
			continue
		var mod_id: String = BlueprintDefinitionsRef.extract_mod_id(item_type)
		if mod_id.is_empty():
			continue
		var mod_data: Dictionary = ModificationRegistryRef.get_data(mod_id)
		var display_name: String = String(mod_data.get("name", mod_id)) if not mod_data.is_empty() else mod_id
		var rarity: String = String(mod_data.get("rarity", "common")) if not mod_data.is_empty() else "common"
		var is_installed: bool = installed_mod_ids.has(mod_id)
		acquired_blueprints.append({
			"item_type": item_type,
			"mod_id": mod_id,
			"name": display_name,
			"rarity": rarity,
			"count": count,
			"installed": is_installed,
		})
	if acquired_blueprints.is_empty():
		_add_intel_placeholder(_intel_grid, "暂无已获得的改造
	（获得改造图纸后，所有取得过的改造会显示于此）")
		return
	# 按稀有度排序（稀有→普通）
	acquired_blueprints.sort_custom(func(a, b): return _rarity_sort_value(a.rarity) > _rarity_sort_value(b.rarity))
	for bp in acquired_blueprints:
		var item = ResourceSlotScene.instantiate()
		if item == null:
			continue
		_intel_grid.add_child(item)
		if item.has_method("set_data"):
			# 名称前缀标注装配状态：✓已装配 / ○未装配
			var status_mark: String = "✓ " if bp.installed else "○ "
			var extra_data: Dictionary = {
				"name": status_mark + bp.name,
				"description": "改造图纸（永久解锁）\n稀有度：%s\n状态：%s" % [
					IntelManualItemsRef.get_rarity_name(bp.rarity),
					"已装配" if bp.installed else "未装配",
				],
			}
			item.set_data(bp.item_type, bp.count, ResourceSlotItem.SlotType.LORE, extra_data)
	_schedule_sync_card_grid_scroll_size_for_grid(_intel_grid)


## 稀有度排序权重（legendary 最大）
func _rarity_sort_value(rarity: String) -> int:
	match rarity:
		"legendary": return 5
		"epic": return 4
		"rare": return 3
		"uncommon": return 2
		"common": return 1
		_: return 0


func _add_intel_placeholder(grid: GridContainer, message: String) -> void:
	var lbl := Label.new()
	lbl.text = message
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 0.9))
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.custom_minimum_size = Vector2(950.0, 80.0)
	grid.add_child(lbl)


## 刷新属性提升标签页
func refresh_stat_boosts_tab() -> void:
	if _stat_boosts_grid == null:
		return
	_apply_backpack_grid_layout(_stat_boosts_grid)
	# [LOG-v5.1] print("[BP TAB] stat: grid=%s sig=%s" % [_stat_boosts_grid != null, _last_stat_boost_signature])
	var mll = get_node_or_null("/root/ManagerLazyLoader")
	if mll and mll.has_method("ensure_loaded"): mll.ensure_loaded("stat_boost")
	var sbm = get_node_or_null("/root/StatBoostManager")
	# [LOG-v5.1] print("[BP TAB] stat: sbm=%s" % [sbm != null])
	if sbm == null or not sbm.has_method("get_all_boosts"):
		# [LOG-v5.1] print("[BP TAB] stat: ADDING placeholder (no sbm)")
		_clear_grid_children(_stat_boosts_grid)
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
		_stat_boosts_grid.remove_child(child)
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
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.custom_minimum_size = Vector2(950.0, 80.0)
	grid.add_child(lbl)

## ────────────────────────────────────────────────────────────────
## v6.2: 符文标签页
## ────────────────────────────────────────────────────────────────

var RuneClass = RuneDefinitions

## 刷新符文标签页：显示已获得的所有符文（名称+稀有度+数量）
func refresh_runes_tab() -> void:
	if _runes_grid == null:
		return
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim == null or not pim.has_method("get_owned_runes"):
		_clear_grid_children(_runes_grid)
		_add_runes_placeholder(_runes_grid, "符文系统未初始化")
		return
	var owned_runes: Array = pim.get_owned_runes()
	# 获取当前装备中的符文（用于显示"已装备"标记 + 纳入签名）
	var equipped_runes: Array = []
	if pim.has_method("get_rune_slots"):
		equipped_runes = pim.get_rune_slots()
	# 签名去重：必须把装备状态也纳入签名，否则装备/卸下符文时 owned 列表不变、
	# 签名不变，导致 refresh_runes_tab 直接 return，已装备的 ✓ 标记无法更新。
	var sig_parts: Array[String] = []
	for rid in owned_runes:
		var rid_str: String = str(rid)
		# 已装备的符文签名加 [E] 前缀，装备状态变化时签名随之变化
		var equipped_mark: String = "[E]" if equipped_runes.has(rid_str) else ""
		sig_parts.append(equipped_mark + rid_str)
	sig_parts.sort()
	var sig := "|".join(sig_parts)
	if sig == _last_runes_signature:
		return
	_last_runes_signature = sig
	_clear_grid_children(_runes_grid)
	if owned_runes.is_empty():
		_add_runes_placeholder(_runes_grid, "暂无符文\n通过战斗掉落或势力商店获取")
		return
	# 统计每种符文的数量（理论上每种符文只有1个，但防御性处理）
	var rune_counts: Dictionary = {}
	for rid in owned_runes:
		var key: String = str(rid)
		rune_counts[key] = rune_counts.get(key, 0) + 1
	# 按稀有度排序（传说>史诗>稀有>常见）
	var sorted_ids: Array = rune_counts.keys()
	sorted_ids.sort_custom(func(a, b):
		return _rune_rarity_sort_value(a) > _rune_rarity_sort_value(b))
	# 渲染
	for rid in sorted_ids:
		var rune_id: String = str(rid)
		var count: int = int(rune_counts[rune_id])
		_add_rune_item(_runes_grid, rune_id, count, equipped_runes.has(rune_id))
	_schedule_sync_card_grid_scroll_size_for_grid(_runes_grid)

## 单个符文格子渲染
func _add_rune_item(grid: GridContainer, rune_id: String, count: int, is_equipped: bool) -> void:
	var rune_def: Dictionary = RuneClass.get_rune(rune_id)
	var rune_name: String = RuneClass.get_rune_name(rune_id)
	var rarity: String = rune_def.get("rarity", "common")
	var rarity_name: String = RuneClass.RARITY_NAMES.get(rarity, "")
	var category: String = rune_def.get("category", "")
	var rune_color: Color = RuneClass.get_color(rune_id)
	var desc: String = RuneClass.get_description(rune_id)
	# 显示名称：已装备的加 [装] 前缀，让玩家一眼看出该符文正在槽位中（点击可卸下）
	var display_name: String = rune_name
	if is_equipped:
		display_name = "[装]" + rune_name
	# 描述：已装备的注明状态，提示点击可卸下
	var status_line: String = ""
	if is_equipped:
		status_line = "\n[已装备·点击卸下]"
	else:
		status_line = "\n[点击装备]"
	# 数量：每种符文数量（通常为1，但显示出来更清晰）
	var count_text: String = "×%d" % count
	# extra_data 让 ResourceSlotItem 显示自定义名称和描述
	# 已装备的符文格子整体变暗（modulate），表明已在使用中
	var display_color: Color = rune_color if not is_equipped else rune_color.darkened(0.35)
	var extra_data: Dictionary = {
		"name": display_name,
		"description": "【%s】%s\n%s%s" % [rarity_name, _rune_category_name(category), desc, status_line],
		"rune_color": display_color,
		"icon": RuneClass.icon_path_for(rune_id),
	}
	# 复用 stat_boost 对象池
	var item = null
	if not _rune_slot_pool.is_empty():
		item = _rune_slot_pool.pop_back()
	else:
		item = ResourceSlotScene.instantiate()
	if item == null:
		return
	grid.add_child(item)
	if item.has_method("set_data"):
		# v6.2: 使用 RUNE 槽位类型，让 ResourceSlotItem 走 _refresh_rune 分支，
		# 正确应用 extra_data 里的符文名/描述/稀有度颜色（原误用 STAT_BOOST 导致全部显示为"属性提升"）
		item.set_data(rune_id, count, ResourceSlotItem.SlotType.RUNE, extra_data)
	# v6.2: 连接点击信号（对象池复用时先断开旧连接，避免重复连接报错）
	if item.has_signal("rune_clicked"):
		if item.rune_clicked.is_connected(_on_backpack_rune_clicked):
			item.rune_clicked.disconnect(_on_backpack_rune_clicked)
		item.rune_clicked.connect(_on_backpack_rune_clicked)
	# 设置稀有度边框颜色
	if "modulate" in item:
		var border_color: Color = rune_color
		item.modulate = Color(1, 1, 1, 1)
	# 设置 tooltip
	if "tooltip_text" in item:
		item.tooltip_text = "【%s】%s\n%s\n（点击装备/卸下）" % [rarity_name, rune_name, desc]

## v6.2: 背包符文格子点击 → 装备到首个空槽；已装备则卸下
func _on_backpack_rune_clicked(rune_id: String) -> void:
	if rune_id.is_empty():
		return
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim == null or not pim.has_method("equip_rune"):
		_show_rune_action_hint("符文系统未就绪")
		return
	# 已装备 → 卸下（从槽位移除，保留所有权）
	if pim.has_method("get_rune_slots") and pim.get_rune_slots().has(rune_id):
		var slots: Array = pim.get_rune_slots()
		for i in range(slots.size()):
			if str(slots[i]) == rune_id:
				if pim.has_method("unequip_rune"):
					pim.unequip_rune(i)
				break
		_show_rune_action_hint("已卸下：%s" % RuneClass.get_rune_name(rune_id))
		refresh_runes_tab()
		return
	# 未装备 → 找第一个空槽装备
	var slot_count: int = pim.get_rune_slot_count() if pim.has_method("get_rune_slot_count") else 0
	if slot_count <= 0:
		_show_rune_action_hint("当前相位仪没有符文槽位")
		return
	var slots: Array = pim.get_rune_slots() if pim.has_method("get_rune_slots") else []
	var target_slot: int = -1
	for i in range(slot_count):
		var v = slots[i] if i < slots.size() else null
		if v == null or str(v).is_empty():
			target_slot = i
			break
	if target_slot < 0:
		_show_rune_action_hint("符文槽位已满，请先卸下其他符文")
		return
	var ok: bool = pim.equip_rune(target_slot, rune_id)
	if ok:
		_show_rune_action_hint("已装备：%s" % RuneClass.get_rune_name(rune_id))
		refresh_runes_tab()
	else:
		_show_rune_action_hint("装备失败（槽位不可用）")

## v6.2: 简易操作反馈——复用 ToastManager（若可用），否则用 print 兜底
func _show_rune_action_hint(msg: String) -> void:
	var toast_mgr: Node = get_node_or_null("/root/ToastManager")
	if toast_mgr and toast_mgr.has_method("show_toast"):
		toast_mgr.show_toast(msg)
	else:
		print("[BackpackPanel] %s" % msg)

## 符文稀有度排序值
func _rune_rarity_sort_value(rune_id: String) -> int:
	var rune_def: Dictionary = RuneClass.get_rune(rune_id)
	var rarity: String = rune_def.get("rarity", "common")
	match rarity:
		"legendary": return 4
		"epic": return 3
		"rare": return 2
		"common": return 1
	return 0

## 符文分类中文名
func _rune_category_name(category: String) -> String:
	match category:
		"attack": return "攻击符文"
		"defense": return "防御符文"
		"energy": return "能量符文"
		"mobility": return "机动符文"
		"special": return "特殊符文"
	return "符文"

## 符文标签空状态占位
func _add_runes_placeholder(grid: GridContainer, message: String) -> void:
	var lbl := Label.new()
	lbl.text = message
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 0.9))
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.custom_minimum_size = Vector2(950.0, 80.0)
	grid.add_child(lbl)
## 向后兼容方法（已废弃，保留以避免破坏现有调用）
## ============================================================

## 刷新情报页显示（废弃：使用 refresh_intel_tab 代替）
func _clear_grid_children(grid: GridContainer) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()


func refresh_resources_tab() -> void:
	if _resources_grid == null:
		return
	_apply_backpack_grid_layout(_resources_grid)
	# [LOG-v5.1] print("[BP TAB] res: grid=%s sig=%s" % [_resources_grid != null, _last_resources_signature])
	var brm = get_node_or_null("/root/BasicResourceManager")
	if brm == null or not brm.has_method("get_all_totals"):
		_clear_grid_children(_resources_grid)
		var lbl := Label.new()
		lbl.text = "资源系统未初始化"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 0.9))
		_resources_grid.add_child(lbl)
		return
	var resources_raw: Dictionary = brm.get_all_totals()
	var res_parts: Array[String] = []
	for k in resources_raw.keys():
		var v: int = int(resources_raw[k])
		if v > 0:
			res_parts.append("%s:%d" % [k, v])
	res_parts.sort()
	var res_signature := "|".join(res_parts)
	if res_signature == _last_resources_signature:
		return
	_last_resources_signature = res_signature
	_clear_grid_children(_resources_grid)
	if res_parts.is_empty():
		var lbl := Label.new()
		lbl.text = "暂无资源"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 0.9))
		_resources_grid.add_child(lbl)
		return
	for k in resources_raw.keys():
		var count: int = int(resources_raw[k])
		if count <= 0:
			continue
		# v6.2 修复 M4：跳过兼容性 key（如 basic_nano），它们与正式 ID（nano_materials）映射同一值，
		# 不过滤会导致资源标签页重复显示纳米材料
		if String(k).begins_with("basic_"):
			continue
		var item = ResourceSlotScene.instantiate()
		if item == null:
			continue
		_resources_grid.add_child(item)
		if item.has_method("set_data"):
			item.set_data(k, count, 0)
	_schedule_sync_card_grid_scroll_size_for_grid(_resources_grid)
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
	refresh_resources_tab()
	refresh_intel_tab()
	refresh_stat_boosts_tab()
	refresh_runes_tab()  # v6.2: 刷新符文标签页

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
