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
## v8.0: 相位仪标签页所需的数据依赖
const PhaseInstruments = preload("res://data/phase_instruments.gd")
const CompanyDefs = preload("res://data/company_definitions.gd")
const DesignTokens = preload("res://resources/design_tokens.gd")
## 详情弹窗内的统一情报面板实例引用
var _detail_info_panel: Control = null
## ── 子系统：筛选/排序 ──
const FilterSortSub = preload("res://scripts/systems/backpack_filter_sort.gd")
var _filter_sort: BackpackFilterSort = null

## v8.0: 背包卡牌独立大卡面尺寸（80x120），不再跟随战场 PhaseSlot.SLOT_SIZE(50x80)。
## 战场槽位保持原尺寸，背包用大卡面展示，拖拽对齐由 backpack_card_item_drag 处理。
const CARD_SLOT_MIN: Vector2 = Vector2(80, 120)
## 背包卡槽上限，与 BackpackData.MAX_CARD_SLOTS 保持单一真相源（统计与 UI 必须一致）
const MAX_CARD_SLOTS := 50
## 与 `backpack_panel.tscn` 中 CardGrid 的 `h_separation` 一致（勿与主题脱节）
const BACKPACK_GRID_H_SEP := 6
## v8.0: 面板可用宽度（8 列 × 80px + 7 × 6px 间距 = 642px，留出滚动条与内边距）
const BACKPACK_PANEL_DESIGN_WIDTH := 680
## 每行列数：8 列大卡面（80x120），视觉更舒适、每张卡更突出
const BACKPACK_GRID_COLUMNS: int = 8

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
## v8.0: 相位仪标签页列表容器（垂直排列，相位仪卡片按星级降序）
@onready var _phase_inst_list: VBoxContainer = $VBoxOuter/TabContainer/PhaseInstTab/ScrollContainer/PhaseInstList
## v7.x: 符文右侧信息栏引用（从 rune_panel 合并而来）
var _rune_bonus_label: RichTextLabel = null
var _runeword_list_inner: VBoxContainer = null

## 相位仪快捷栏已移除（不再在背包内显示）

## 标签页索引枚举
enum TabIndex {
	COMBAT_CARDS = 0,
	RESOURCES = 1,
	INTEL = 2,
	STAT_BOOSTS = 3,
	RUNES = 4,           ## v6.2: 符文标签
	PHASE_INSTRUMENTS = 5, ## v8.0: 相位仪标签（已获得列表 + 装备切换）
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
var _last_rune_info_signature: String = "__INIT__"  ## 符文信息栏（符文之语）签名去重
var _last_phase_inst_signature: String = "__INIT__"  ## 相位仪标签签名去重
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
	_runes_grid = get_node_or_null("VBoxOuter/TabContainer/RunesTab/RunesHSplit/RunesScroll/RunesGrid") as GridContainer
	# v7.x: 符文右侧信息栏（加成 + 符文之语），从 rune_panel 迁移合并而来
	_rune_bonus_label = get_node_or_null("VBoxOuter/TabContainer/RunesTab/RunesHSplit/RuneInfoPanel/BonusLabel") as RichTextLabel
	_runeword_list_inner = get_node_or_null("VBoxOuter/TabContainer/RunesTab/RunesHSplit/RuneInfoPanel/RunewordScroll/RunewordList") as VBoxContainer

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
		# v8.0: 相位仪标签（显示已获得列表 + 装备切换）
		_tab_container.set_tab_title(TabIndex.PHASE_INSTRUMENTS, "相位仪")
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
	# v7.x：换装原子信号——fallback 路径同步处理，避免 presenter 失败时换装背包重复
	if SignalBus and SignalBus.has_signal("card_swapped"):
		if not SignalBus.card_swapped.is_connected(_fallback_on_card_swapped):
			SignalBus.card_swapped.connect(_fallback_on_card_swapped)
	# 构建网格（至少显示空格子）
	var cards: Array = _data.get_filtered_sorted_cards()
	rebuild_card_grid(cards)

func _fallback_on_card_added(card: CardResource) -> void:
	if card == null or _data == null:
		return
	# v7.0: 用 instance_id 作身份（实例化养成）；无 instance_id 回退 card_id
	var inst_id: String = card.instance_id if not card.instance_id.is_empty() else card.card_id
	if SaveManager and SaveManager.has_method("consume_pending_backpack_card_id"):
		SaveManager.consume_pending_backpack_card_id(inst_id)
	_data.add_extra_card(inst_id, false)
	if SaveManager and SaveManager.has_method("enqueue_backpack_card_id"):
		SaveManager.enqueue_backpack_card_id(inst_id)

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

## v7.x：换装原子 fallback——presenter 不可用时，panel 直接同步 _data 与 SaveManager。
## 顺序与 presenter._on_card_swapped 一致：先移新卡出包，再添旧卡入包。
func _fallback_on_card_swapped(_slot_index: int, old_card: CardResource, new_card_id: String) -> void:
	if _data == null:
		return
	# 1. 移新卡出包
	if not new_card_id.is_empty():
		_data.remove_card(new_card_id, false)
		if SaveManager and SaveManager.has_method("_on_card_equipped_remove_fallback"):
			SaveManager._on_card_equipped_remove_fallback(_slot_index, new_card_id, "")
	# 2. 添旧卡入包
	if old_card != null:
		var inst_id: String = old_card.instance_id if not old_card.instance_id.is_empty() else old_card.card_id
		if SaveManager and SaveManager.has_method("consume_pending_backpack_card_id"):
			SaveManager.consume_pending_backpack_card_id(inst_id)
		_data.add_extra_card(inst_id, false)
		if SaveManager and SaveManager.has_method("enqueue_backpack_card_id"):
			SaveManager.enqueue_backpack_card_id(inst_id)

## ============================================================
## 标签页事件处理
## ============================================================

## 标签页切换事件
func _on_tab_changed(tab_index: int) -> void:
	# v7.x：切换时对内容区做一次透明度闪现（受 motion_reduce 守卫）
	_play_tab_change_fade()
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
			# v6.2: 符文标签页刷新（内部会连带刷新右侧信息栏）
			refresh_runes_tab()
		TabIndex.PHASE_INSTRUMENTS:
			# v8.0: 相位仪标签页刷新（已获得列表 + 装备切换）
			refresh_phase_instruments_tab()

## v7.x：标签切换微动效——内容区透明度先降后升，制造切换感。tab 控件结构因 tab 而异
## （RunesTab 是 HSplit 而非纯 ScrollContainer），防御性查找失败则跳过。
func _play_tab_change_fade() -> void:
	if DesignTokens.is_motion_reduce():
		return
	if _tab_container == null:
		return
	var cur := _tab_container.get_current_tab_control()
	if cur == null:
		return
	# 优先找 ScrollContainer，回退到第一个 Control 子节点
	var target: Control = cur.get_node_or_null("ScrollContainer") as Control
	if target == null:
		for ch in cur.get_children():
			if ch is Control:
				target = ch
				break
	if target == null:
		return
	var t := create_tween()
	t.tween_property(target, "modulate:a", 0.6, 0.05)
	t.tween_property(target, "modulate:a", 1.0, 0.15)

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
	# 空状态提示：无卡牌时显示占位文字（区分"空背包"与"加载中"）
	if added_count == 0 and not _has_loading_indicator(grid):
		_show_backpack_empty_hint(grid)
	else:
		_hide_backpack_empty_hint(grid)
	_ensure_min_card_slots(grid)
	_sync_card_grid_scroll_size_for_grid(grid)
	_hide_loading_indicator()


## 检查网格中是否有加载指示器（区分"加载中"与"空背包"）
func _has_loading_indicator(grid: GridContainer) -> bool:
	for child in grid.get_children():
		if is_instance_valid(child) and child.has_meta("is_loading_indicator") and child.get_meta("is_loading_indicator"):
			return true
	return false

## 显示背包空状态提示
func _show_backpack_empty_hint(grid: GridContainer) -> void:
	if grid == null:
		return
	# 已存在则跳过
	for child in grid.get_children():
		if is_instance_valid(child) and child.has_meta("is_empty_hint"):
			return
	var hint := Label.new()
	hint.text = "背包暂无卡牌\n通过商店购买或战斗掉落获取卡牌"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 0.7))
	hint.add_theme_font_size_override("font_size", 14)
	hint.custom_minimum_size = Vector2(600, 120)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.set_meta("is_empty_hint", true)
	grid.add_child(hint)

## 隐藏背包空状态提示
func _hide_backpack_empty_hint(grid: GridContainer) -> void:
	if grid == null:
		return
	for child in grid.get_children():
		if is_instance_valid(child) and child.has_meta("is_empty_hint"):
			child.queue_free()


## 添加单张卡到网格末尾或顶部
func add_card(card: CardResource, at_top: bool = false) -> void:
	var grid = _combat_cards_grid
	if grid == null:
		return
	_apply_backpack_grid_layout(grid)
	_add_card_item(grid, card, at_top, true)
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
## v7.0: card_id 参数实际是 instance_id；优先匹配 instance_id，回退 card_id
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
			if card != null and _card_matches_id(card, card_id):
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
			if card != null and _card_matches_id(card, card_id):
				target = child
	if target:
		_highlight_card_item(target)

## v7.0: 卡牌身份匹配——优先 instance_id 精确匹配，回退 card_id（兼容）
func _card_matches_id(card: CardResource, id_str: String) -> bool:
	if card == null or id_str.is_empty():
		return false
	if not card.instance_id.is_empty():
		return card.instance_id == id_str
	return card.card_id == id_str

## 将顶级能量卡移动到网格最前面
## v7.x: 能量卡系统移除，此函数降级为仅刷新网格布局（保留函数签名避免破坏调用方）
func pin_top_energy_to_front() -> void:
	var grid = _combat_cards_grid
	if grid == null:
		return
	_apply_backpack_grid_layout(grid)

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
			_confirm_dismantle(card)
		"equip":
			if _presenter:
				_presenter.on_equip_button_pressed(card)

## 拆解确认弹窗（显示预览收益，确认后执行）
func _confirm_dismantle(card: CardResource) -> void:
	if card == null or _presenter == null:
		return
	if not _presenter.has_method("on_dismantle_button_pressed"):
		return
	# 获取拆解预览
	var preview: Dictionary = {}
	if _presenter.has_method("get_dismantle_preview"):
		preview = _presenter.get_dismantle_preview(card)
	var card_name: String = String(preview.get("name", card.card_id))
	var research: int = int(preview.get("research", 0))
	var nano: int = int(preview.get("nano", 0))

	var dialog := ConfirmationDialog.new()
	dialog.title = "拆解卡牌"
	dialog.dialog_text = "确定要拆解「%s」吗？\n\n拆解后该卡牌将从背包永久移除，你将获得：\n- %d 研究点\n- %d 纳米材料\n\n此操作不可撤销。" % [card_name, research, nano]
	dialog.ok_button_text = "确认拆解"
	dialog.get_cancel_button().text = "取消"
	# 用元数据绑定卡牌，确认回调取回
	dialog.set_meta("dismantle_card", card)
	dialog.confirmed.connect(_on_dismantle_confirmed.bind(dialog))
	dialog.canceled.connect(_on_dismantle_canceled.bind(dialog))
	add_child(dialog)
	dialog.popup_centered(Vector2i(440, 220))

## 拆解确认回调
func _on_dismantle_confirmed(dialog: ConfirmationDialog) -> void:
	var card: CardResource = dialog.get_meta("dismantle_card", null)
	dialog.queue_free()
	if card != null and _presenter and _presenter.has_method("on_dismantle_button_pressed"):
		_presenter.on_dismantle_button_pressed(card)

## 拆解取消回调
func _on_dismantle_canceled(dialog: ConfirmationDialog) -> void:
	dialog.queue_free()

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
	_clear_grid_to_pool(_intel_grid, _resource_slot_pool, "is_resource_slot")
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
		var icon_path: String = String(mod_data.get("icon", "")) if not mod_data.is_empty() else ""
		var is_installed: bool = installed_mod_ids.has(mod_id)
		acquired_blueprints.append({
			"item_type": item_type,
			"mod_id": mod_id,
			"name": display_name,
			"rarity": rarity,
			"icon": icon_path,
			"count": count,
			"installed": is_installed,
		})
	if acquired_blueprints.is_empty():
		_add_intel_placeholder(_intel_grid, "暂无已获得的改造
	（获得改造图纸后，所有取得过的改造会显示于此）")
		return
	# 按稀有度排序（稀有→普通）
	acquired_blueprints.sort_custom(func(a, b): return _rarity_sort_value(a.rarity) > _rarity_sort_value(b.rarity))
	var _mod_idx := 0
	for bp in acquired_blueprints:
		var item = _acquire_slot_from_pool(_resource_slot_pool, ResourceSlotScene, "is_resource_slot")
		if item == null:
			continue
		_intel_grid.add_child(item)
		# v7.x：写入稀有度 meta（_refresh_lore 在 set_data 内调用，需先于 set_data 写入）
		item.set_meta("_tile_rarity", String(bp.rarity))
		if item.has_method("set_data"):
			# 名称前缀标注装配状态：✓已装配 / ○未装配
			var status_mark: String = "✓ " if bp.installed else "○ "
			var extra_data: Dictionary = {
				"name": status_mark + bp.name,
				"icon": String(bp.get("icon", "")),
				"description": "改造图纸（永久解锁）\n稀有度：%s\n状态：%s" % [
					IntelManualItemsRef.get_rarity_name(bp.rarity),
					"已装配" if bp.installed else "未装配",
				],
			}
			item.set_data(bp.item_type, bp.count, ResourceSlotItem.SlotType.LORE, extra_data)
		# v7.x：错峰入场动画
		_play_tile_enter_animation(item, _mod_idx)
		_mod_idx += 1
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
		_clear_grid_to_pool(_stat_boosts_grid, _stat_boost_slot_pool, "is_stat_boost")
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

	# 清空现有内容（池化回收）
	_clear_grid_to_pool(_stat_boosts_grid, _stat_boost_slot_pool, "is_stat_boost")

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
		_clear_grid_to_pool(_runes_grid, _rune_slot_pool, "is_rune_slot")
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
	_clear_grid_to_pool(_runes_grid, _rune_slot_pool, "is_rune_slot")
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
	var _rune_idx := 0
	for rid in sorted_ids:
		var rune_id: String = str(rid)
		var count: int = int(rune_counts[rune_id])
		_add_rune_item(_runes_grid, rune_id, count, equipped_runes.has(rune_id), _rune_idx)
		_rune_idx += 1
	_schedule_sync_card_grid_scroll_size_for_grid(_runes_grid)
	# v7.x: 连带刷新右侧加成/符文之语信息栏（合并自 rune_panel，所有 refresh_runes_tab 调用点自动生效）
	refresh_rune_info_panel()


## v7.x: 刷新右侧符文信息栏（加成总览 + 已激活符文之语列表）
## 逻辑迁移自 rune_panel.gd 的 _refresh_detail + _refresh_runeword_list。
## 读 PhaseInstrumentManager 的 get_rune_bonus / get_active_runewords API 拼装展示文本。
func refresh_rune_info_panel() -> void:
	if _rune_bonus_label == null and _runeword_list_inner == null:
		return
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim == null:
		return
	# ── 加成总览（单符文 + 符文之语数值合并展示）──
	if _rune_bonus_label != null:
		var bonus: Dictionary = pim.get_rune_bonus() if pim.has_method("get_rune_bonus") else {}
		var rune_stats: Dictionary = bonus.get("rune_stats", {})
		var rune_specials: Array = bonus.get("rune_specials", [])
		var runeword_bonuses: Array = bonus.get("runeword_bonuses", [])
		if rune_stats.is_empty() and rune_specials.is_empty() and runeword_bonuses.is_empty():
			_rune_bonus_label.text = "[color=gray]当前无符文加成[/color]"
		else:
			var lines: PackedStringArray = []
			if not rune_stats.is_empty() or not rune_specials.is_empty():
				lines.append("[b]单符文加成：[/b]")
				for key in rune_stats:
					var pct := int(round(float(rune_stats[key]) * 100.0))
					if String(key) == "energy_cost_reduction" or String(key) == "damage_reduction":
						lines.append("  %s -%d%%" % [RuneDefinitions.stat_display_name(String(key)), pct])
					else:
						lines.append("  %s +%d%%" % [RuneDefinitions.stat_display_name(String(key)), pct])
				for sp in rune_specials:
					var chance := int(round(float(sp.get("chance", 1.0)) * 100.0))
					lines.append("  %s (%d%%概率)" % [RuneDefinitions.special_display_name(String(sp.get("special", ""))), chance])
			if not runeword_bonuses.is_empty():
				lines.append("[b]符文之语加成：[/b]")
				for rw in runeword_bonuses:
					var rw_name: String = String(rw.get("name", ""))
					var rw_stats: Dictionary = rw.get("stats", {})
					var rw_parts: Array[String] = []
					for key in rw_stats:
						var pct := int(round(float(rw_stats[key]) * 100.0))
						if String(key) == "energy_cost_reduction" or String(key) == "damage_reduction":
							rw_parts.append("%s -%d%%" % [RuneDefinitions.stat_display_name(String(key)), pct])
						else:
							rw_parts.append("%s +%d%%" % [RuneDefinitions.stat_display_name(String(key)), pct])
					for sp in rw.get("specials", []):
						var chance := int(round(float(sp.get("chance", 1.0)) * 100.0))
						rw_parts.append("%s (%d%%概率)" % [RuneDefinitions.special_display_name(String(sp.get("special", ""))), chance])
					if not rw_parts.is_empty():
						lines.append("  [color=#c9a0ff][%s][/color] %s" % [rw_name, " | ".join(rw_parts)])
			_rune_bonus_label.text = "\n".join(lines)
	# ── 已激活符文之语列表 ──
	if _runeword_list_inner != null:
		for child in _runeword_list_inner.get_children():
			child.queue_free()
		var active: Array = pim.get_active_runewords() if pim.has_method("get_active_runewords") else []
		if active.is_empty():
			var empty_label := Label.new()
			empty_label.text = "（暂无激活的符文之语）"
			empty_label.add_theme_font_size_override("font_size", 12)
			empty_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 1))
			_runeword_list_inner.add_child(empty_label)
		else:
			for rw in active:
				var entry := VBoxContainer.new()
				entry.add_theme_constant_override("separation", 2)
				var rw_id: String = String(rw.get("id", ""))
				var tier: int = int(rw.get("tier", 2))
				var tier_color: Color = RunewordDefinitions.TIER_COLORS.get(tier, Color(0.545, 0.361, 0.965))
				var name_label := Label.new()
				name_label.text = "★ %s (T%d)" % [RunewordDefinitions.get_runeword_name(rw_id), tier]
				name_label.add_theme_font_size_override("font_size", 13)
				name_label.add_theme_color_override("font_color", tier_color)
				entry.add_child(name_label)
				var effect_label := Label.new()
				effect_label.text = RunewordDefinitions.get_effects_description(rw_id)
				effect_label.add_theme_font_size_override("font_size", 11)
				effect_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9, 1))
				effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				entry.add_child(effect_label)
				_runeword_list_inner.add_child(entry)


## ============================================================
## v8.0 相位仪标签页
## ============================================================

## 刷新相位仪标签页：列出所有已解锁的相位仪，点击装备切换。
## UI 逻辑复用自 phase_instrument_selector.gd（保持两处外观一致）。
func refresh_phase_instruments_tab() -> void:
	if _phase_inst_list == null:
		return
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim == null or not pim.has_method("get_unlocked_instrument_ids"):
		_clear_phase_inst_list()
		_add_phase_inst_placeholder("相位仪系统未初始化")
		return

	var current_instrument_id: String = ""
	if pim.has_method("get_current_instrument"):
		var cur_cfg: Dictionary = pim.get_current_instrument()
		current_instrument_id = String(cur_cfg.get("id", ""))

	var unlocked_ids: Array = pim.get_unlocked_instrument_ids()

	# 签名去重：已解锁集合 + 当前装备 + 星级不变则跳过全量手搓重建（每 item 10+ 节点）
	var sig_parts: Array[String] = []
	for iid in unlocked_ids:
		var sid := String(iid)
		var star_raw = _safe_get_instrument_star(pim, sid)
		sig_parts.append(sid + ":s" + str(star_raw))
	sig_parts.append("[CUR]" + current_instrument_id)
	sig_parts.sort()
	var phase_sig := "|".join(sig_parts)
	if phase_sig == _last_phase_inst_signature:
		return
	_last_phase_inst_signature = phase_sig

	_clear_phase_inst_list()

	if unlocked_ids.is_empty():
		_add_phase_inst_placeholder("暂无已解锁的相位仪\n通过商店购买、战斗掉落或势力声望获取")
		return

	# 按星级降序排列（统一走 manager 接口，含运行时掉落定义）
	var sorted_instruments: Array = []
	for iid in unlocked_ids:
		var cfg: Dictionary = pim.get_instrument_cfg(String(iid)) if pim.has_method("get_instrument_cfg") else PhaseInstruments.get_by_id(String(iid))
		if not cfg.is_empty():
			sorted_instruments.append(cfg)
	sorted_instruments.sort_custom(func(a, b): return int(a.get("star", 0)) > int(b.get("star", 0)))

	for inst_cfg in sorted_instruments:
		var item: Control = _create_phase_inst_item(inst_cfg, String(inst_cfg.get("id", "")) == current_instrument_id)
		_phase_inst_list.add_child(item)


## 清空相位仪列表（不 queue_free 已移除的节点，避免在 _ready 阶段触发）
func _clear_phase_inst_list() -> void:
	if _phase_inst_list == null:
		return
	for child in _phase_inst_list.get_children():
		child.queue_free()


## 空状态占位文本
func _add_phase_inst_placeholder(msg: String) -> void:
	if _phase_inst_list == null:
		return
	var label := Label.new()
	label.text = msg
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.8))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(0, 80)
	_phase_inst_list.add_child(label)


## 类型安全地取仪器星级：避免 star 字段为非 int 时 String() 构造报错。
## 优先走 manager 统一接口（含运行时掉落定义），回退静态表。
func _safe_get_instrument_star(pim: Node, instrument_id: String) -> int:
	var cfg: Dictionary
	if pim != null and pim.has_method("get_instrument_cfg"):
		cfg = pim.get_instrument_cfg(instrument_id)
	else:
		cfg = PhaseInstruments.get_by_id(instrument_id)
	if cfg.is_empty():
		return 0
	var raw = cfg.get("star", 0)
	# star 必须是数字；防御性地拒绝字符串/对象等异常类型
	if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
		return int(raw)
	return 0


## 构建单个相位仪卡片（外观与 phase_instrument_selector 一致）
func _create_phase_inst_item(cfg: Dictionary, is_equipped: bool) -> Control:
	var container := PanelContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	if is_equipped:
		style.bg_color = Color(0.15, 0.25, 0.35, 0.95)
		style.border_color = Color(0.4, 0.85, 1.0, 0.9)
	else:
		style.bg_color = Color(0.08, 0.10, 0.15, 0.92)
		style.border_color = Color(0.3, 0.35, 0.45, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	container.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	container.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# ── 标题行：名称 + 星级 + 势力/通用 ──
	var header_row := HBoxContainer.new()
	vbox.add_child(header_row)

	var name_label := Label.new()
	var inst_name: String = String(cfg.get("name", "未知相位仪"))
	var star: int = int(cfg.get("star", 0))
	if is_equipped:
		name_label.text = "✓ %s ★%d" % [inst_name, star]
		name_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6, 1.0))
	else:
		name_label.text = "%s ★%d" % [inst_name, star]
		name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7, 1.0))
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(name_label)

	var faction_id: String = String(cfg.get("faction_id", ""))
	var is_generic: bool = bool(cfg.get("is_generic", false))
	var faction_label := Label.new()
	if not is_generic:
		var faction_cfg: Dictionary = CompanyDefs.get_by_id(faction_id)
		if not faction_cfg.is_empty():
			faction_label.text = String(faction_cfg.get("name", ""))
			faction_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95, 0.9))
		else:
			faction_label.text = "专属"
			faction_label.add_theme_color_override("font_color", Color(0.75, 0.55, 0.95, 0.9))
	else:
		faction_label.text = "通用"
		faction_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7, 0.9))
	faction_label.add_theme_font_size_override("font_size", 11)
	header_row.add_child(faction_label)

	# ── 槽位配置行 ──
	var slot_row := HBoxContainer.new()
	vbox.add_child(slot_row)

	var slot_counts: Dictionary = cfg.get("slot_counts", {})
	var green_count: int = int(slot_counts.get("green", 0))
	var yellow_count: int = int(slot_counts.get("yellow", 0))
	var rune_count: int = int(slot_counts.get("rune", 0))
	# 兼容旧数据：无 rune 字段时回退读 red/blue
	if rune_count == 0:
		rune_count = int(slot_counts.get("red", 0)) + int(slot_counts.get("blue", 0))
	var total_slots: int = green_count + yellow_count + rune_count

	var config_label := Label.new()
	config_label.text = "槽位配置: "
	config_label.add_theme_font_size_override("font_size", 11)
	config_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85, 0.9))
	slot_row.add_child(config_label)

	if green_count > 0:
		var green_label := Label.new()
		green_label.text = "绿%d " % green_count
		green_label.add_theme_font_size_override("font_size", 11)
		green_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5, 1.0))
		slot_row.add_child(green_label)

	if yellow_count > 0:
		var yellow_label := Label.new()
		yellow_label.text = "黄%d " % yellow_count
		yellow_label.add_theme_font_size_override("font_size", 11)
		yellow_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.2, 1.0))
		slot_row.add_child(yellow_label)

	if rune_count > 0:
		var rune_label := Label.new()
		rune_label.text = "符%d " % rune_count
		rune_label.add_theme_font_size_override("font_size", 11)
		rune_label.add_theme_color_override("font_color", Color(0.75, 0.55, 0.95, 1.0))
		slot_row.add_child(rune_label)

	var total_label := Label.new()
	total_label.text = "(总计: %d)" % total_slots
	total_label.add_theme_font_size_override("font_size", 11)
	total_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85, 0.9))
	slot_row.add_child(total_label)

	# ── 属性加成行 ──
	var stats_parts: Array = []
	var recovery_rate: float = float(cfg.get("energy_recovery_rate", 0.3))
	var spawn_ratio: float = float(cfg.get("spawn_range_ratio", 0.3))
	var actual_recovery: float = recovery_rate * 3.0
	stats_parts.append("可上场: %d单位" % green_count)
	stats_parts.append("能量恢复: %.2f (实际: %.1f/秒)" % [recovery_rate, actual_recovery])
	stats_parts.append("部署范围: %.0f%%" % (spawn_ratio * 100))

	var stats_label := Label.new()
	stats_label.text = "  |  ".join(PackedStringArray(stats_parts))
	stats_label.add_theme_font_size_override("font_size", 10)
	stats_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 0.85))
	vbox.add_child(stats_label)

	# ── 进阶属性行（相位仪 properties + bonus） ──
	var advanced_parts: Array = []
	var props: Array = cfg.get("properties", [])
	if props is Array and not props.is_empty():
		for p in props:
			if p is Dictionary:
				var display: String = String((p as Dictionary).get("display", ""))
				if not display.is_empty():
					advanced_parts.append("[相位仪] " + display)
	else:
		if cfg.has("card_damage_bonus") and float(cfg.card_damage_bonus) > 0:
			advanced_parts.append("[相位仪] 卡伤+%.0f%%" % (float(cfg.card_damage_bonus) * 100))
		if cfg.has("defense_bonus") and float(cfg.defense_bonus) > 0:
			advanced_parts.append("[相位仪] 防御+%.0f%%" % (float(cfg.defense_bonus) * 100))
		if cfg.has("xp_bonus") and float(cfg.xp_bonus) > 0:
			advanced_parts.append("[相位仪] 相位场经验+%.0f%%" % (float(cfg.xp_bonus) * 100))
		if cfg.has("energy_cost_reduction") and int(cfg.energy_cost_reduction) > 0:
			advanced_parts.append("[相位仪] 能耗-%d" % int(cfg.energy_cost_reduction))

	if not advanced_parts.is_empty():
		var advanced_label := Label.new()
		advanced_label.text = "  |  ".join(PackedStringArray(advanced_parts.slice(0, 5)))
		advanced_label.add_theme_font_size_override("font_size", 10)
		advanced_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35, 0.9))
		advanced_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		advanced_label.custom_minimum_size = Vector2(400, 0)
		vbox.add_child(advanced_label)

	# ── 特性行 ──
	var traits: Array = cfg.get("special_traits", [])
	if traits is Array and not traits.is_empty():
		var trait_label := Label.new()
		trait_label.text = "✦ " + "  |  ".join(PackedStringArray(traits))
		trait_label.add_theme_font_size_override("font_size", 10)
		trait_label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0, 0.95))
		trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		trait_label.custom_minimum_size = Vector2(400, 0)
		vbox.add_child(trait_label)

	# ── 主动能力行（7星相位仪）──
	var ability: Dictionary = cfg.get("active_ability", {})
	if not ability.is_empty():
		var ability_name: String = String(ability.get("name", ""))
		var ability_desc: String = String(ability.get("description", ""))
		var ability_label := Label.new()
		if not ability_name.is_empty() and not ability_desc.is_empty():
			ability_label.text = "⚡ %s：%s" % [ability_name, ability_desc]
		elif not ability_desc.is_empty():
			ability_label.text = "⚡ %s" % ability_desc
		else:
			ability_label.text = "⚡ %s" % ability_name
		ability_label.add_theme_font_size_override("font_size", 10)
		ability_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
		ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		ability_label.custom_minimum_size = Vector2(400, 0)
		vbox.add_child(ability_label)

	# ── 装备按钮 / 当前装备标记 ──
	if is_equipped:
		var equipped_label := Label.new()
		equipped_label.text = "当前装备中"
		equipped_label.add_theme_font_size_override("font_size", 11)
		equipped_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.5, 1.0))
		vbox.add_child(equipped_label)
	else:
		var equip_btn := Button.new()
		equip_btn.text = "装备此相位仪"
		equip_btn.add_theme_font_size_override("font_size", 12)
		equip_btn.custom_minimum_size = Vector2(120, 32)
		vbox.add_child(equip_btn)
		var iid_copy: String = String(cfg.get("id", ""))
		equip_btn.pressed.connect(_on_phase_inst_equip_pressed.bind(iid_copy))

	return container


## 装备相位仪按钮回调：调用 PhaseInstrumentManager.equip_instrument 后刷新列表
func _on_phase_inst_equip_pressed(instrument_id: String) -> void:
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim == null or not pim.has_method("equip_instrument"):
		return
	var success: bool = pim.equip_instrument(instrument_id)
	if success:
		refresh_phase_instruments_tab()
		if SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit("已装备相位仪")


## v8.0: 外部入口：打开背包并切到相位仪 Tab
func switch_to_phase_instruments_tab() -> void:
	if _tab_container != null:
		_tab_container.current_tab = TabIndex.PHASE_INSTRUMENTS


## v7.x: 外部入口（main.gd 底部栏"法则区"点击 / 教程引导调用）：打开背包并切到符文 Tab
func switch_to_runes_tab() -> void:
	if _tab_container != null:
		_tab_container.current_tab = TabIndex.RUNES

## 单个符文格子渲染
func _add_rune_item(grid: GridContainer, rune_id: String, count: int, is_equipped: bool, anim_idx: int = -1) -> void:
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
		# v7.x：补 rarity + is_equipped，供 _refresh_rune 应用稀有度底色+激活态发光
		"rarity": rarity,
		"is_equipped": is_equipped,
	}
	# 复用符文对象池（_acquire_slot_from_pool 统一复位 visible/modulate + 打 is_rune_slot 标记）
	var item = _acquire_slot_from_pool(_rune_slot_pool, ResourceSlotScene, "is_rune_slot")
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
	# v7.x：错峰入场动画（anim_idx < 0 时不动画，兼容其他调用点）
	if anim_idx >= 0:
		_play_tile_enter_animation(item, anim_idx)

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

## 池化清空：按 meta_key 分流，命中标记的节点回收到 pool 复用，其余 queue_free
## （参考 _flush_rebuild_card_grid L419-437 的按 meta 分流回收模式）
func _clear_grid_to_pool(grid: GridContainer, pool: Array, meta_key: String) -> void:
	if grid == null:
		return
	for child in grid.get_children():
		grid.remove_child(child)
		if is_instance_valid(child) and child.has_meta(meta_key):
			child.visible = false
			pool.append(child)
		else:
			child.queue_free()

## 池化获取：优先从 pool 弹出一个节点，空则实例化新节点；复用前复位可见性/调制
## （参考 _add_card_item 的 acquire + 复用前复位模式）
func _acquire_slot_from_pool(pool: Array, scene: PackedScene, meta_key: String) -> Control:
	var item: Control = null
	if not pool.is_empty():
		item = pool.pop_back()
	else:
		item = scene.instantiate()
	if item == null:
		return null
	if item is CanvasItem:
		(item as CanvasItem).visible = true
	if item is Control:
		(item as Control).modulate = Color(1, 1, 1, 1)
	item.set_meta(meta_key, true)
	return item


func refresh_resources_tab() -> void:
	if _resources_grid == null:
		return
	_apply_backpack_grid_layout(_resources_grid)
	# [LOG-v5.1] print("[BP TAB] res: grid=%s sig=%s" % [_resources_grid != null, _last_resources_signature])
	var brm = get_node_or_null("/root/BasicResourceManager")
	if brm == null or not brm.has_method("get_all_totals"):
		_clear_grid_to_pool(_resources_grid, _resource_slot_pool, "is_resource_slot")
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
	_clear_grid_to_pool(_resources_grid, _resource_slot_pool, "is_resource_slot")
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
		var item = _acquire_slot_from_pool(_resource_slot_pool, ResourceSlotScene, "is_resource_slot")
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
	refresh_phase_instruments_tab()  # v8.0: 刷新相位仪标签页

## ============================================================
## 内部 UI 方法
## ============================================================

func _add_card_item(grid: GridContainer, card: CardResource, at_top: bool = false, animate: bool = false) -> void:
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
	if animate:
		_play_card_enter_animation(item)

## v7.x：新卡入场动画——淡入 + 回弹缩放。受 motion_reduce 守卫（关闭时直接显示无缩放）。
func _play_card_enter_animation(item: Control) -> void:
	if item == null or not is_instance_valid(item):
		return
	if DesignTokens.is_motion_reduce():
		item.modulate.a = 1.0
		item.scale = Vector2(1.0, 1.0)
		return
	item.modulate.a = 0.0
	item.scale = Vector2(0.85, 0.85)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(item, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
	t.tween_property(item, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## v7.x：改造/符文瓷砖入场动画——淡入 + 缩放，带 index 错峰（批量重建时逐个入场，避免同步闪现）。
func _play_tile_enter_animation(item: Control, index: int) -> void:
	if item == null or not is_instance_valid(item):
		return
	if DesignTokens.is_motion_reduce():
		item.modulate.a = 1.0
		item.scale = Vector2(1.0, 1.0)
		return
	item.modulate.a = 0.0
	item.scale = Vector2(0.88, 0.88)
	# 错峰：每张延迟 0.03s，上限 8 张后不再增加（避免长列表等待过久）
	var delay: float = minf(float(index) * 0.03, 0.24)
	# 两条独立顺序 Tween：先延迟，再淡入 / 先延迟，再缩放（避免 set_parallel 与 chain 混用歧义）
	var t_a := create_tween()
	t_a.tween_interval(delay)
	t_a.tween_property(item, "modulate:a", 1.0, 0.18).set_ease(Tween.EASE_OUT)
	var t_s := create_tween()
	t_s.tween_interval(delay)
	t_s.tween_property(item, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
		_ensure_empty_slot_plus(placeholder)
		grid.add_child(placeholder)
		card_count += 1

## v7.x：空槽位添加居中 "+" 号标识（Label 字符，零美术依赖）。池化复用时复用已有 Label。
func _ensure_empty_slot_plus(placeholder: Panel) -> void:
	if placeholder == null:
		return
	placeholder.tooltip_text = "空格位"
	var plus: Label = placeholder.get_node_or_null("EmptyPlusLabel") as Label
	if plus == null:
		plus = Label.new()
		plus.name = "EmptyPlusLabel"
		plus.text = "+"
		plus.add_theme_font_size_override("font_size", 20)
		plus.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6, 0.5))
		plus.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder.add_child(plus)
	plus.visible = true

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
	# 复用属性提升对象池（_acquire_slot_from_pool 统一复位 visible/modulate + 打 is_stat_boost 标记）
	var item = _acquire_slot_from_pool(_stat_boost_slot_pool, ResourceSlotScene, "is_stat_boost")
	if item == null:
		return
	grid.add_child(item)
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
