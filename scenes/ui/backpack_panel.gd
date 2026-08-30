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
const ModEffectLabels = preload("res://scripts/ui/mod_effect_labels.gd")
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
## v9.0: 战斗卡格子改大 96×138（HTML 设计稿），承载更多信息（5星+兵种色块+Lv+战力+EQUIP徽章）
const CARD_SLOT_MIN: Vector2 = Vector2(108, 154)
## 背包卡槽上限，与 BackpackData.MAX_CARD_SLOTS 保持单一真相源（统计与 UI 必须一致）
const MAX_CARD_SLOTS := 50
## 与 `backpack_panel.tscn` 中 CardGrid 的 `h_separation` 一致（勿与主题脱节）
const BACKPACK_GRID_H_SEP := 6
## v9.3→背包打开态改版: 面板宽——tscn 根节点 custom_minimum_size 1180 是兜底最小宽；
## 主场景打开背包时由 main.gd._sync_backpack_panel_width 把 min 宽贴满视口（左右占满）。
## BACKPACK_PANEL_DESIGN_WIDTH 仅为文档性常量。
const BACKPACK_PANEL_DESIGN_WIDTH := 760
## v9.3: 战斗卡列数下限与回退基准。实际列数由 _compute_combat_grid_columns 按面板可用宽度
## 动态计算（列数随面板实际宽自适应，占满视口时 10~11 列），避免固定列数导致右侧大片空白。
const BACKPACK_GRID_COLUMNS: int = 6
## v9.0: 改造/符文瓷砖（resource_slot_item 64×96）独立列数（与战斗卡分流）
const _TILE_GRID_COLUMNS: int = 6
const _TILE_SLOT_MIN: Vector2 = Vector2(64, 96)

## v9.2: 工具栏本地过滤状态（chip 点击时写入，refresh_*_tab 渲染时读取）
## 默认值均为 "全部"，缺省行为与改动前 100% 一致（向后兼容）
var _combat_kind_filter: int = -1   ## -1 = 全部；0-4 = CombatKind
var _mod_bucket_filter: String = ""  ## "" = 全部；inf_/arm_/.../enh_ 前缀桶
var _rune_cat_filter: String = ""    ## "" = 全部；attack/defense/energy/mobility/special
var _inst_source_filter: String = "" ## "" = 全部；generic/faction/drop/star7
var _search_query: String = ""       ## 搜索关键字（卡名/ID 包含匹配，空=不过滤）

## v9.2: 相位仪静态总数（用于"解锁 N/68"分母）
const _PHASE_INSTRUMENT_TOTAL := 68

## v9.2: 改造前缀桶分类（mod_id 前缀 → 桶 key）
const _MOD_BUCKETS := {
	"inf_": "步兵", "arm_": "装甲", "art_": "炮兵", "aa_": "防空",
	"air_": "空军", "rec_": "侦察", "eng_": "工兵", "for_": "堡垒",
	"gen_": "通用", "enh_": "强化",
}

# MVP 引用
var _presenter: BackpackPresenter = null
var _data: BackpackData = null

## 标签页容器
@onready var _tab_container: TabContainer = $VBoxOuter/TabContainer

## v9.2: 顶部框架节点引用（顶线条 + 标题菱形 + 标题文字 + 元信息行）
@onready var _top_accent_strip: ColorRect = $VBoxOuter/TopAccentStrip
@onready var _title_mark: PanelContainer = $VBoxOuter/TitleRow/TitleMark
@onready var _title_label: Label = $VBoxOuter/TitleRow/TitleLabel
@onready var _meta_info_label: Label = $VBoxOuter/TitleRow/MetaInfoLabel

## v9.2: 工具栏节点引用（搜索 + chip 容器 + 容量 + 排序）
@onready var _search_edit: LineEdit = $VBoxOuter/Toolbar/ToolbarLeft/SearchEdit
@onready var _filter_chips_box: HBoxContainer = $VBoxOuter/Toolbar/ToolbarLeft/FilterChipsBox
@onready var _capacity_label: Label = $VBoxOuter/Toolbar/ToolbarRight/CapacityLabel
@onready var _sort_option: OptionButton = $VBoxOuter/Toolbar/ToolbarRight/SortOption

## 内嵌滚动容器（用于程序化滚动定位）
@onready var _scroll: ScrollContainer = $VBoxOuter/TabContainer/CombatCardsTab/ScrollContainer

## 各标签页的Grid引用
var _combat_cards_grid: GridContainer = null
var _resources_grid: GridContainer = null
var _intel_grid: GridContainer = null
var _stat_boosts_grid: GridContainer = null
var _runes_grid: GridContainer = null  ## v6.2: 符文格子
## v9.2: 改造左侧筛选侧栏容器（兵种/装配状态两层筛选）
var _mod_sidebar: VBoxContainer = null
## v8.0: 相位仪标签页列表容器（垂直排列，相位仪卡片按星级降序）
@onready var _phase_inst_list: VBoxContainer = $VBoxOuter/TabContainer/PhaseInstTab/ScrollContainer/PhaseInstList
## v7.x: 符文右侧信息栏引用（从 rune_panel 合并而来）
var _rune_bonus_label: RichTextLabel = null
var _runeword_list_inner: VBoxContainer = null

## 相位仪快捷栏已移除（不再在背包内显示）

## 标签页索引枚举
## v9.0 精简：6→4（砍掉 RESOURCES + STAT_BOOSTS，资源在顶部资源栏已有显示，属性提升极少用）
enum TabIndex {
	COMBAT_CARDS = 0,
	INTEL = 1,            ## 改造（v6.5：标题改为"改造"，内容是改造蓝图）
	RUNES = 2,            ## v6.2: 符文标签
	PHASE_INSTRUMENTS = 3, ## v8.0: 相位仪标签（已获得列表 + 装备切换）
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

## 选中卡的 instance_id 集合（含裸 card_id 回退）。用 instance_id 精确匹配各实例。

## ============================================================
## 生命周期
## ============================================================

func _ready() -> void:
	_filter_sort = FilterSortSub.new()
	_filter_sort.setup(self)
	add_to_group("backpack_panel")
	# D1: 根框架统一 PanelStyles 签名框（覆盖 tscn StyleBoxFlat_bg）
	var ps_d1 = preload("res://scripts/ui/panel_styles.gd")
	add_theme_stylebox_override("panel", ps_d1.make_panel_frame(DesignTokens.get_panel_accent("backpack")))

	# 初始化各标签页Grid引用
	_combat_cards_grid = get_node_or_null("VBoxOuter/TabContainer/CombatCardsTab/ScrollContainer/CardGrid") as GridContainer
	_intel_grid = get_node_or_null("VBoxOuter/TabContainer/IntelTab/IntelHSplit/IntelScroll/IntelGrid") as GridContainer
	_mod_sidebar = get_node_or_null("VBoxOuter/TabContainer/IntelTab/IntelHSplit/ModSidebarScroll/ModSidebar") as VBoxContainer
	_runes_grid = get_node_or_null("VBoxOuter/TabContainer/RunesTab/RunesHSplit/RunesScroll/RunesGrid") as GridContainer
	# v7.x: 符文右侧信息栏（加成 + 符文之语），从 rune_panel 迁移合并而来
	_rune_bonus_label = get_node_or_null("VBoxOuter/TabContainer/RunesTab/RunesHSplit/RuneInfoPanel/BonusLabel") as RichTextLabel
	_runeword_list_inner = get_node_or_null("VBoxOuter/TabContainer/RunesTab/RunesHSplit/RuneInfoPanel/RunewordScroll/RunewordList") as VBoxContainer

	# 必须先锁定列数再 setup（setup 会立刻 rebuild，不能在 rebuild 之后才设 columns）
	if _combat_cards_grid:
		_apply_backpack_grid_layout(_combat_cards_grid)
	if _intel_grid:
		_apply_backpack_grid_layout(_intel_grid)
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
		# v6.5 修复 M3：INTEL tab 实际显示改造蓝图（refresh_intel_tab 用 is_mod_blueprint 过滤），
		# 标题应为"改造"而非"情报"
		_tab_container.set_tab_title(TabIndex.INTEL, "改造")
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
	_loading_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
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

	# v9.2: 顶部框架 + 工具栏初始化（对齐 HTML 设计稿）
	_setup_title_bar_fonts()
	_setup_toolbar_signals()
	_refresh_title_bar(TabIndex.COMBAT_CARDS)
	_rebuild_toolbar_chips(TabIndex.COMBAT_CARDS)
	# v9.3: 延迟重排所有网格列数（首次 _ready 时父容器 size 可能未定）
	call_deferred("_reflow_grids_after_layout")
	# v9.3: 连接各网格父容器（ScrollContainer）的 resized——切 Tab 布局完成时 size 确定会触发，
	# 自动重排到准确列数，避免首次进入回退 4 列。
	_connect_grid_scroll_resized()
	# v9.4: 连接滚动条 value_changed——滚动时触发卡牌图标的视口裁切重扫，
	# 让离开视口的卡牌卸载图标纹理、进入视口的卡牌按需加载，避免 OOM。
	_connect_scroll_visibility_hooks()


## v9.2: 应用 Rajdhani 字体到标题栏 + Tab 标题（与养成面板统一设计语言）
## 仅做字体/字号覆盖；颜色与文字内容由 _refresh_title_bar(tab) 按当前 Tab 动态设
func _setup_title_bar_fonts() -> void:
	var title_font: Font = DesignTokens.get_title_font()
	if title_font == null:
		return
	if _title_label:
		_title_label.add_theme_font_override("font", title_font)
		_title_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_LARGE)
	if _meta_info_label:
		_meta_info_label.add_theme_font_override("font", title_font)
	# 关闭按钮：v7.x 面板统一 ✕ 模式（44x44、hover 红色发光，与 PanelChrome 同款）
	var close_btn: Button = get_node_or_null("VBoxOuter/TitleRow/CloseButton") as Button
	if close_btn:
		var _ps = preload("res://scripts/ui/panel_styles.gd")
		var close_styles: Dictionary = _ps.make_close_button_styles()
		close_btn.add_theme_font_override("font", title_font)
		close_btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_LARGE)
		close_btn.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MID)
		close_btn.add_theme_color_override("font_hover_color", DesignTokens.COLOR_TEXT_BRIGHT)
		close_btn.add_theme_color_override("font_pressed_color", DesignTokens.COLOR_TEXT_BRIGHT)
		close_btn.add_theme_color_override("font_focus_color", DesignTokens.COLOR_TEXT_BRIGHT)
		close_btn.add_theme_stylebox_override("normal", close_styles["normal"])
		close_btn.add_theme_stylebox_override("hover", close_styles["hover"])
		close_btn.add_theme_stylebox_override("pressed", close_styles["pressed"])
		close_btn.add_theme_stylebox_override("focus", close_styles["focus"])


## v9.2: 按 Tab 刷新顶部框架（顶线条色 + 标题菱形 + 标题文字 + 元信息行）
## 4 张 Tab 各有独立签名色与英文副标题，对齐 HTML 设计稿 panel-frame
func _refresh_title_bar(tab_index: int) -> void:
	var accent: Color = DesignTokens.COLOR_AMBER
	var title_text: String = "战斗卡阵列 · COMBAT ROSTER"
	match tab_index:
		TabIndex.COMBAT_CARDS:
			accent = DesignTokens.COLOR_AMBER
			title_text = "战斗卡阵列 · COMBAT ROSTER"
		TabIndex.INTEL:
			accent = DesignTokens.COLOR_CYAN_TECH
			title_text = "改造模块库 · MOD REPOSITORY"
		TabIndex.RUNES:
			accent = DesignTokens.COLOR_VIOLET
			title_text = "符文图鉴 · RUNE ARCANUM"
		TabIndex.PHASE_INSTRUMENTS:
			accent = DesignTokens.COLOR_AMBER_SOFT  # gold = #fbbf24
			title_text = "相位仪中枢 · CORE NEXUS"
	# 顶线条（按 Tab 切换签名色，alpha 0.7 保持与原 SignatureStrip 一致）
	if _top_accent_strip:
		_top_accent_strip.color = Color(accent.r, accent.g, accent.b, 0.7)
	# 标题菱形标记
	_apply_title_mark_diamond(accent)
	# 标题文字（副标题用对应签名色染色）
	if _title_label:
		_title_label.text = title_text
	# 元信息行（每 Tab 不同统计）
	if _meta_info_label:
		_meta_info_label.text = _compute_meta_info(tab_index)
		_meta_info_label.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.95))


## v9.2: 构建/刷新标题菱形标记（外框 + 内嵌小色块，旋转 45°）
func _apply_title_mark_diamond(color: Color) -> void:
	if _title_mark == null:
		return
	# 外框 StyleBoxFlat（菱形描边，按 Tab 染色）
	var outer := StyleBoxFlat.new()
	outer.bg_color = DesignTokens.COLOR_TRANSPARENT  # 透明，仅描边
	outer.border_color = color
	outer.set_border_width_all(1)
	outer.set_corner_radius_all(2)
	outer.content_margin_left = 2.0
	outer.content_margin_right = 2.0
	outer.content_margin_top = 2.0
	outer.content_margin_bottom = 2.0
	_title_mark.add_theme_stylebox_override("panel", outer)
	_title_mark.rotation = PI / 4.0  # 旋转 45° 成菱形
	# 内嵌小色块（实心菱形，带辉光）
	var inner: PanelContainer = _title_mark.get_node_or_null("InnerDot") as PanelContainer
	if inner == null:
		inner = PanelContainer.new()
		inner.name = "InnerDot"
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		inner.custom_minimum_size = Vector2(10, 10)
		_title_mark.add_child(inner)
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = color
	inner_style.set_corner_radius_all(1)
	inner.add_theme_stylebox_override("panel", inner_style)


## v9.2: 计算标题栏右侧元信息文本（每 Tab 不同统计维度）
func _compute_meta_info(tab_index: int) -> String:
	match tab_index:
		TabIndex.COMBAT_CARDS:
			# 兵种数 / 时代数 / 满级数（card_level>=30）
			var stats: Dictionary = get_backpack_statistics()
			var total: int = int(stats.get("total_cards", 0))
			var kind_count: int = _count_distinct_kinds_in_backpack()
			var era_count: int = _count_distinct_eras_in_backpack()
			var max_stars: int = _count_max_stars_in_backpack()
			return "共 %d · 兵种 %d · 时代 %d · 满级 %d" % [total, kind_count, era_count, max_stars]
		TabIndex.INTEL:
			var installed: int = _count_installed_mods()
			var total_mods: int = _count_owned_mods()
			var pending: int = maxi(0, total_mods - installed)
			return "已装配 %d · 待装配 %d · 共 %d" % [installed, pending, total_mods]
		TabIndex.RUNES:
			var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
			var active_rw: int = 0
			var slot_used: int = 0
			var slot_total: int = 0
			if pim:
				if pim.has_method("get_active_runewords"):
					active_rw = pim.get_active_runewords().size()
				if pim.has_method("get_rune_slots"):
					for s in pim.get_rune_slots():
						if not str(s).is_empty():
							slot_used += 1
				if pim.has_method("get_rune_slot_count"):
					slot_total = pim.get_rune_slot_count()
			return "已激活符文之语 %d · 槽位 %d/%d" % [active_rw, slot_used, slot_total]
		TabIndex.PHASE_INSTRUMENTS:
			var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
			var unlocked: int = 0
			var cur_star: int = 0
			if pim and pim.has_method("get_unlocked_instrument_ids"):
				unlocked = pim.get_unlocked_instrument_ids().size()
			if pim and pim.has_method("get_current_instrument"):
				var cur: Dictionary = pim.get_current_instrument()
				cur_star = int(cur.get("star", 0))
			return "解锁 %d/%d · 当前装备 %d★" % [unlocked, _PHASE_INSTRUMENT_TOTAL, cur_star]
	return ""


## v9.2: 战斗卡元信息辅助——统计背包内不同兵种数
func _count_distinct_kinds_in_backpack() -> int:
	if _data == null:
		return 0
	var kinds: Dictionary = {}
	for card in _data.get_filtered_sorted_cards():
		if card is CardResource and card.card_type == GC.CardType.COMBAT_UNIT:
			kinds[int(card.combat_kind)] = true
	return kinds.size()


## v9.2: 战斗卡元信息辅助——统计背包内不同时代数
func _count_distinct_eras_in_backpack() -> int:
	if _data == null:
		return 0
	var eras: Dictionary = {}
	for card in _data.get_filtered_sorted_cards():
		if card is CardResource:
			eras[int(card.era)] = true
	return eras.size()


## v9.2: 战斗卡元信息辅助——统计背包内满级（card_level>=30）卡数
func _count_max_stars_in_backpack() -> int:
	## v9.2 满级口径：实例战斗等级 ≥30（原 get_card_xp_progress 恒 1 已移除）
	if _data == null:
		return 0
	var ir_node: Node = get_node_or_null("/root/InstanceRegistry")
	if ir_node == null or not ir_node.has_method("get_card_level"):
		return 0
	var count: int = 0
	for card in _data.get_filtered_sorted_cards():
		if not (card is CardResource):
			continue
		var key: String = card.instance_id if not card.instance_id.is_empty() else card.card_id
		if int(ir_node.get_card_level(key)) >= 30:
			count += 1
	return count


## v9.2: 改造元信息辅助——已装配在战斗卡上的不同 mod 数
func _count_installed_mods() -> int:
	var installed: Dictionary = {}
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
						installed[mid] = true
	return installed.size()


## v9.2: 改造元信息辅助——已获得的改造总数（IntelItemBag 内 blueprint_* 且非 evol）
func _count_owned_mods() -> int:
	var bag = get_node_or_null("/root/IntelItemBag")
	if bag == null or not bag.has_method("get_all_inventory"):
		return 0
	var items: Dictionary = bag.get_all_inventory()
	var count: int = 0
	for item_type in items.keys():
		if int(items[item_type]) <= 0:
			continue
		if IntelManualItemsRef.is_mod_blueprint(String(item_type)):
			count += 1
	return count


## ============================================================
## v9.2: 工具栏（搜索 + 筛选 chips + 容量 + 排序）
## ============================================================

## 工具栏信号连接（_ready 中调用一次）
func _setup_toolbar_signals() -> void:
	if _search_edit:
		_search_edit.text_changed.connect(_on_search_changed)
	if _sort_option:
		_sort_option.item_selected.connect(_on_sort_option_changed)


## 搜索框文本变化：写入 _search_query 并刷新当前 Tab
func _on_search_changed(text: String) -> void:
	_search_query = text.strip_edges().to_lower()
	_refresh_current_tab_after_filter()


## 排序下拉变化：映射到 BackpackData.SortType 并触发战斗卡重建
func _on_sort_option_changed(idx: int) -> void:
	# idx 对应 SortOption 的 item 顺序：0=默认 1=名称 2=费用 3=稀有度
	var sort_str: String = "default"
	match idx:
		0: sort_str = "default"
		1: sort_str = "name"
		2: sort_str = "cost"
		3: sort_str = "rarity"
	set_sort_type(sort_str)
	# 改造/符文/相位仪也按稀有度/名称本地重排（idx==3 或 1 时）
	if idx in [1, 3] and _tab_container != null:
		_refresh_current_tab_after_filter()


## chip 点击通用回调：把 chip 的 value 写入对应过滤变量后刷新当前 Tab
func _on_filter_chip_pressed(filter_kind: String, value) -> void:
	match filter_kind:
		"combat_kind":
			_combat_kind_filter = int(value)
		"mod_bucket":
			_mod_bucket_filter = String(value)
		"rune_cat":
			_rune_cat_filter = String(value)
		"inst_source":
			_inst_source_filter = String(value)
	# 更新 chip 激活态视觉
	_update_chip_active_states(filter_kind, value)
	_refresh_current_tab_after_filter()


## 刷新当前 Tab（chip/搜索/排序变化时调用）
func _refresh_current_tab_after_filter() -> void:
	if _tab_container == null:
		return
	match _tab_container.current_tab:
		TabIndex.COMBAT_CARDS:
			# 战斗卡：view 层过滤（隐藏不匹配项），不触发 data 层重建
			_apply_combat_view_filters()
			_refresh_capacity_label()
		TabIndex.INTEL:
			# 改造：签名失效 + 重建
			_last_lore_signature = "__INVALIDATED__"
			refresh_intel_tab()
		TabIndex.RUNES:
			_last_runes_signature = "__INVALIDATED__"
			refresh_runes_tab()
		TabIndex.PHASE_INSTRUMENTS:
			_last_phase_inst_signature = "__INVALIDATED__"
			refresh_phase_instruments_tab()


## v9.2: 战斗卡 view 层过滤（按兵种 + 搜索关键字隐藏不匹配卡）
## 复用 BackpackFilterSort 的"按 grid 子节点 visible 切换"模式
func _apply_combat_view_filters() -> void:
	if _combat_cards_grid == null:
		return
	for child in _combat_cards_grid.get_children():
		if not (child is Control):
			continue
		if child.has_meta("is_empty_slot") and child.get_meta("is_empty_slot"):
			continue
		if not child.has_method("set_card"):
			continue
		var card: CardResource = child.card if "card" in child else null
		if card == null:
			continue
		var visible := true
		# 兵种过滤
		if _combat_kind_filter >= 0 and card.card_type == GC.CardType.COMBAT_UNIT:
			if int(card.combat_kind) != _combat_kind_filter:
				visible = false
		# 搜索过滤（卡名/ID/兵种名 包含匹配）
		if visible and not _search_query.is_empty():
			var haystack := _card_search_haystack(card)
			if not haystack.contains(_search_query):
				visible = false
		child.visible = visible
	_refresh_capacity_label()


## v9.2: 构建战斗卡的搜索匹配字符串（卡名 + card_id + 兵种名，全部小写）
func _card_search_haystack(card: CardResource) -> String:
	if card == null:
		return ""
	var parts: PackedStringArray = []
	parts.append(String(card.card_id).to_lower())
	parts.append(DefaultCardsData.safe_name(card).to_lower())
	if card.card_type == GC.CardType.COMBAT_UNIT:
		parts.append(CardResource.get_combat_kind_name(int(card.combat_kind)).to_lower())
	return " ".join(parts)


## v9.2: 按 Tab 重建 FilterChipsBox 的 chip 集合
func _rebuild_toolbar_chips(tab_index: int) -> void:
	if _filter_chips_box == null:
		return
	for c in _filter_chips_box.get_children():
		_filter_chips_box.remove_child(c)
		c.queue_free()
	# 当前 Tab 签名色（chip 激活态边框色用）
	var accent: Color = _tab_accent_color(tab_index)
	match tab_index:
		TabIndex.COMBAT_CARDS:
			# 兵种：全部 + 5 兵种（CombatKind 0-4）
			_add_filter_chip("全部", "combat_kind", -1, accent, _combat_kind_filter == -1)
			_add_filter_chip("轻装", "combat_kind", 0, accent, _combat_kind_filter == 0)
			_add_filter_chip("装甲", "combat_kind", 1, accent, _combat_kind_filter == 1)
			_add_filter_chip("支援", "combat_kind", 2, accent, _combat_kind_filter == 2)
			_add_filter_chip("空中", "combat_kind", 3, accent, _combat_kind_filter == 3)
			_add_filter_chip("堡垒", "combat_kind", 4, accent, _combat_kind_filter == 4)
		TabIndex.INTEL:
			# 改造：按前缀桶（10 桶）。v9.3：去左侧栏后顶部 chips 为唯一分类入口。
			_add_filter_chip("全部", "mod_bucket", "", accent, _mod_bucket_filter.is_empty())
			for prefix in _MOD_BUCKETS.keys():
				var label: String = _MOD_BUCKETS[prefix]
				_add_filter_chip(label, "mod_bucket", prefix, accent, _mod_bucket_filter == prefix)
		TabIndex.RUNES:
			# 符文：5 类别
			_add_filter_chip("全部", "rune_cat", "", accent, _rune_cat_filter.is_empty())
			_add_filter_chip("攻击", "rune_cat", "attack", accent, _rune_cat_filter == "attack")
			_add_filter_chip("防御", "rune_cat", "defense", accent, _rune_cat_filter == "defense")
			_add_filter_chip("能量", "rune_cat", "energy", accent, _rune_cat_filter == "energy")
			_add_filter_chip("机动", "rune_cat", "mobility", accent, _rune_cat_filter == "mobility")
			_add_filter_chip("特殊", "rune_cat", "special", accent, _rune_cat_filter == "special")
		TabIndex.PHASE_INSTRUMENTS:
			# 相位仪：来源 + 星级
			_add_filter_chip("全部", "inst_source", "", accent, _inst_source_filter.is_empty())
			_add_filter_chip("通用", "inst_source", "generic", accent, _inst_source_filter == "generic")
			_add_filter_chip("势力", "inst_source", "faction", accent, _inst_source_filter == "faction")
			_add_filter_chip("掉落", "inst_source", "drop", accent, _inst_source_filter == "drop")
			_add_filter_chip("7★", "inst_source", "star7", accent, _inst_source_filter == "star7")
	_refresh_capacity_label()


## v9.2: 添加单个筛选 chip（toggle Button，激活态用 tab 签名色边框）
func _add_filter_chip(label: String, filter_kind: String, value, accent: Color, active: bool) -> void:
	if _filter_chips_box == null:
		return
	var btn := Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.button_pressed = active
	btn.custom_minimum_size = Vector2(0, 26)
	btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
	btn.add_theme_constant_override("h_separation", 0)
	# 样式：未激活=暗灰边框；激活=tab 签名色边框 + 半透填充
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.04, 0.07, 0.12, 0.5)
	style_normal.border_color = Color(0.25, 0.30, 0.40, 0.5)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(3)
	style_normal.content_margin_left = 8.0
	style_normal.content_margin_right = 8.0
	style_normal.content_margin_top = 3.0
	style_normal.content_margin_bottom = 3.0
	btn.add_theme_stylebox_override("normal", style_normal)
	var style_active := StyleBoxFlat.new()
	if active:
		style_active.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
		style_active.border_color = accent
		style_active.set_border_width_all(1)
		style_active.set_corner_radius_all(3)
		style_active.content_margin_left = 8.0
		style_active.content_margin_right = 8.0
		style_active.content_margin_top = 3.0
		style_active.content_margin_bottom = 3.0
		btn.add_theme_stylebox_override("normal", style_active)
		btn.add_theme_color_override("font_color", accent)
	else:
		btn.add_theme_color_override("font_color", Color(0.66, 0.71, 0.81, 0.9))
	# hover 样式
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.08, 0.12, 0.20, 0.7)
	style_hover.border_color = Color(accent.r, accent.g, accent.b, 0.5)
	style_hover.set_border_width_all(1)
	style_hover.set_corner_radius_all(3)
	style_hover.content_margin_left = 8.0
	style_hover.content_margin_right = 8.0
	style_hover.content_margin_top = 3.0
	style_hover.content_margin_bottom = 3.0
	btn.add_theme_stylebox_override("hover", style_hover)
	# 连接点击：传 filter_kind + value（value 类型可能是 int/String）
	btn.pressed.connect(_on_filter_chip_pressed.bind(filter_kind, value))
	_filter_chips_box.add_child(btn)


## v9.2: 更新所有 chip 激活态（chip 点击后重绘，避免依赖 toggle 默认视觉）
func _update_chip_active_states(filter_kind: String, value) -> void:
	if _filter_chips_box == null:
		return
	for c in _filter_chips_box.get_children():
		if not (c is Button):
			continue
		var btn := c as Button
		# 从按钮 meta 取回它的 filter_kind/value（_add_filter_chip 时写入）
		# 因 bind 的参数无法回读，这里用文本匹配当前 Tab 的过滤状态
		var active := _is_chip_active_for_current_state(filter_kind, value, btn.text)
		btn.button_pressed = active


## v9.2: 判断某 chip 文本在当前过滤状态下是否应激活
func _is_chip_active_for_current_state(filter_kind: String, value, label_text: String) -> bool:
	# 简化逻辑：刚点击的那个 chip 一定激活；"全部" 在过滤变量为空/-1 时激活
	# 这里依赖 _on_filter_chip_pressed 已更新过滤变量
	match filter_kind:
		"combat_kind":
			if label_text == "全部":
				return _combat_kind_filter < 0
			return _combat_kind_filter == value
		"mod_bucket":
			if label_text == "全部":
				return _mod_bucket_filter.is_empty()
			return _mod_bucket_filter == String(value)
		"rune_cat":
			if label_text == "全部":
				return _rune_cat_filter.is_empty()
			return _rune_cat_filter == String(value)
		"inst_source":
			if label_text == "全部":
				return _inst_source_filter.is_empty()
			return _inst_source_filter == String(value)
	return false


## v9.2: 取 Tab 对应的签名色
func _tab_accent_color(tab_index: int) -> Color:
	match tab_index:
		TabIndex.COMBAT_CARDS: return DesignTokens.COLOR_AMBER
		TabIndex.INTEL: return DesignTokens.COLOR_CYAN_TECH
		TabIndex.RUNES: return DesignTokens.COLOR_VIOLET
		TabIndex.PHASE_INSTRUMENTS: return DesignTokens.COLOR_AMBER_SOFT
	return DesignTokens.COLOR_AMBER


## v9.2: 刷新容量标签（按 Tab 显示不同容量）
func _refresh_capacity_label() -> void:
	if _capacity_label == null or _tab_container == null:
		return
	match _tab_container.current_tab:
		TabIndex.COMBAT_CARDS:
			var stats: Dictionary = get_backpack_statistics()
			var total: int = int(stats.get("total_cards", 0))
			_capacity_label.text = "容量 %d/%d" % [total, MAX_CARD_SLOTS]
		TabIndex.INTEL:
			_capacity_label.text = "改造 %d" % _count_owned_mods()
		TabIndex.RUNES:
			var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
			var n: int = 0
			if pim and pim.has_method("get_owned_runes"):
				n = pim.get_owned_runes().size()
			_capacity_label.text = "符文 %d" % n
		TabIndex.PHASE_INSTRUMENTS:
			var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
			var n: int = 0
			if pim and pim.has_method("get_unlocked_instrument_ids"):
				n = pim.get_unlocked_instrument_ids().size()
			_capacity_label.text = "解锁 %d/%d" % [n, _PHASE_INSTRUMENT_TOTAL]


## v9.2: mod_id → 前缀桶 key（取前 4 字符匹配 _MOD_BUCKETS 的 key）
func _mod_bucket_of(mod_id: String) -> String:
	if mod_id.is_empty():
		return ""
	# _MOD_BUCKETS 的 key 都是 4 字符前缀（inf_/arm_/art_/aa_/air_/rec_/eng_/for_/gen_/enh_）
	# aa_ 是 3 字符，需特殊处理
	if mod_id.begins_with("aa_"):
		return "aa_"
	var prefix4 := mod_id.substr(0, 4)
	if _MOD_BUCKETS.has(prefix4):
		return prefix4
	return ""


## v9.0: 改造效果键 → 简短显示（用于瓷砖主效果行）
## 2026-08-25：键名翻译改走唯一权威表 ModEffectLabels（原内联小表仅 ~14 键，
## 未覆盖键裸显 "accuracy_bonus: 0.5" 英文键名，146 改造档大面积出现）。
func _format_mod_effect_short(key: String, val) -> String:
	# 攻速：attack_interval 是攻击间隔，负值=间隔缩短=攻速提升，统一转正表述
	if key == "attack_interval":
		return "攻速 +%d%%" % int(round(absf(float(val)) * 100.0))
	# 2026-08-25 修④：雷达锁定是周期扫描（每 N 秒锁定一次），值是周期秒数而非加成，
	# 显示成"雷达锁定间隔 +12"无单位且像加数。带秒单位、不带正负号。
	if key == "radar_lock_interval":
		return "锁定扫描 %ds/次" % int(round(absf(float(val))))
	if key == "radar_lock_duration":
		return "锁定持续 %ds" % int(round(absf(float(val))))
	var label: String = ModEffectLabels.translate(key)
	if val is bool:
		return "✓ %s" % label
	return "%s %s" % [label, _format_tile_effect_number(val)]


## 瓷砖效果数值口径（与 modification_panel._format_effect_number 一致）：
## |v|<=1 或 v<-1 的小数 → 百分比；>1 的浮点在现网数据里是持续秒/半径/点数
## （非倍率），按加数显示、整值去小数；整数 → 整数加成。
## 2026-08-25 修②：百分比四舍五入为 0 但原值非 0 时保留 1 位小数
## （hp_regen=0.003 原显示"回血 +0%"，信息完全丢失）。
func _format_tile_effect_number(val) -> String:
	if val is float:
		if val == 0.0:
			return "0"
		if absf(val) <= 1.0 or val < -1.0:
			var pct: float = float(val) * 100.0
			if is_equal_approx(roundf(pct), 0.0):
				return "%+.1f%%" % pct
			return "%+.0f%%" % pct
		if is_equal_approx(val, roundf(val)):
			return "+%d" % int(round(val))
		return "+%.1f" % val
	if val is int:
		return "%+d" % val if val >= 0 else str(val)
	return str(val)

func _exit_tree() -> void:
	# v6.2: 断开符文信号，防止面板销毁后回调访问已释放节点
	if SignalBus != null and SignalBus.has_signal("rune_acquired"):
		if SignalBus.rune_acquired.is_connected(_on_rune_acquired):
			SignalBus.rune_acquired.disconnect(_on_rune_acquired)
	# v7.x: 清空批量选择（防游离 item 触发信号）
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
	# v9.2: 先刷新顶部框架（顶线条色 + 标题 + 元信息）和工具栏 chips
	_refresh_title_bar(tab_index)
	_rebuild_toolbar_chips(tab_index)
	# v7.x：切换时对内容区做一次透明度闪现（受 motion_reduce 守卫）
	_play_tab_change_fade()
	match tab_index:
		TabIndex.COMBAT_CARDS:
			# 战斗卡标签页切换时刷新（如有需要）
			_apply_combat_view_filters()
		TabIndex.INTEL:
			# v9.3：直接 refresh；首次切 Tab 若 IntelScroll size 未定会回退 4 列，
			# 但 resized 信号会在布局完成后自动重排到准确列数（见 _connect_grid_scroll_resized）。
			refresh_intel_tab()
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
				# v9.4: 回收入池前清空卡牌引用，释放图标纹理 + 装饰层，
				# 避免池化 item 长期持有旧 Texture2D 导致显存累积（OOM 根因之一）。
				# _set_empty_style 会把 icon_rect.texture 置 null 并隐藏装饰。
				child.set_card(null)
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
	# v9.4: rebuild 完成后 deferred 扫描视口可见性，触发可见区卡牌的图标懒加载。
	# 用 call_deferred 确保布局已完成（get_global_rect 可靠）。
	call_deferred("_apply_viewport_visibility_scan")


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
	hint.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_BODY)
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
	# v9.4: 回收入池前清空卡牌引用，释放图标纹理（同 _flush_rebuild_card_grid）。
	target.set_card(null)
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

	# 设置背包模式（面板内部自动添加装备按钮）
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
		"equip":
			if _presenter:
				_presenter.on_equip_button_pressed(card)




## ============================================================
## ============================================================





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
	# 收集所有已装配在战斗卡上的 mod_id（用于标注装配状态 + 装配计数）
	var installed_mod_ids: Dictionary = {}
	var mod_install_count: Dictionary = {}  # v9.0: mod_id → 装在多少张卡上
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
						mod_install_count[mid] = mod_install_count.get(mid, 0) + 1
	# 从 IntelItemBag 收集所有已获得的改造图纸
	var bag_items: Dictionary = {}
	if bag and bag.has_method("get_all_inventory"):
		bag_items = bag.get_all_inventory()
	# 签名（v9.1: install_count 纳入签名，装配计数变化时瓷砖"N 卡"徽章能刷新）
	var sig_parts: Array[String] = []
	for bk in bag_items.keys():
		sig_parts.append("bag:" + bk + ":" + str(bag_items[bk]))
	for mid in installed_mod_ids.keys():
		sig_parts.append("inst:" + mid + "#" + str(mod_install_count.get(mid, 0)))
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
		# v9.0: 取改造的 slot_type + prototype + 关键 effect 字符串（让 _refresh_lore 显示更丰富信息）
		var slot_type: String = String(mod_data.get("slot_type", "")) if not mod_data.is_empty() else ""
		var prototype: String = String(mod_data.get("prototype", "")) if not mod_data.is_empty() else ""
		var effect_text: String = ""
		# 2026-08-25 修①：enh_* 强化模块只有 level_effects（多档）没有 effects（单档），
		# 原只读 effects 导致 16 块强化瓷砖效果行空白。effects 为空时回退 level_effects
		# 最高档（与 modification_panel._format_effects_for_display 同口径）。
		var effect_lines: Array[String] = []
		if not mod_data.is_empty():
			var eff_dict: Dictionary = mod_data.get("effects", {}) as Dictionary
			if eff_dict.is_empty():
				var le: Dictionary = mod_data.get("level_effects", {}) as Dictionary
				if not le.is_empty():
					var sorted_lv: Array = le.keys()
					sorted_lv.sort()
					eff_dict = le[sorted_lv[sorted_lv.size() - 1]] as Dictionary
			for ek in eff_dict.keys():
				# weapon_type/slot_weapon_type 是弹道路由的内部机制值（非玩家效果），
				# 值恒 0-4，显示成"武器型号 +0"是噪音，跳过。
				if String(ek) in ["weapon_type", "legacy_weapon_type", "slot_weapon_type", "condition_slot"]:
					continue
				var line := _format_mod_effect_short(String(ek), eff_dict[ek])
				if not line.is_empty():
					effect_lines.append(line)
			if not effect_lines.is_empty():
				effect_text = effect_lines[0]
		acquired_blueprints.append({
			"item_type": item_type,
			"mod_id": mod_id,
			"name": display_name,
			"rarity": rarity,
			"icon": icon_path,
			"count": count,
			"installed": is_installed,
			"slot_type": slot_type,
			"prototype": prototype,
			"effect_text": effect_text,
			"effect_lines": effect_lines,
		})
	if acquired_blueprints.is_empty():
		_add_intel_placeholder(_intel_grid, "暂无已获得的改造\n（获得改造图纸后，所有取得过的改造会显示于此）")
		return
	# v9.2: 应用工具栏过滤（前缀桶 + 装配状态 + 搜索关键字）
	if not _mod_bucket_filter.is_empty() or not _mod_status_filter.is_empty() or not _search_query.is_empty():
		var filtered: Array[Dictionary] = []
		for bp in acquired_blueprints:
			# 前缀桶过滤
			if not _mod_bucket_filter.is_empty():
				if _mod_bucket_of(String(bp.mod_id)) != _mod_bucket_filter:
					continue
			# 装配状态过滤
			if not _mod_status_filter.is_empty():
				var is_installed: bool = bool(bp.get("installed", false))
				if _mod_status_filter == "installed" and not is_installed:
					continue
				if _mod_status_filter == "pending" and is_installed:
					continue
			# 搜索过滤（mod 名 / mod_id / prototype 包含匹配）
			if not _search_query.is_empty():
				var hay := String(bp.name).to_lower() + " " + String(bp.mod_id).to_lower() + " " + String(bp.get("prototype", "")).to_lower()
				if not hay.contains(_search_query):
					continue
			filtered.append(bp)
		acquired_blueprints = filtered
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
			# v9.0: name 不再带状态前缀（装配状态由右侧"N 卡"徽章 + 左侧稀有度色条更显眼）
			var extra_data: Dictionary = {
				"name": bp.name,
				"icon": String(bp.get("icon", "")),
				# 2026-08-25 修⑥：稀有度/装配状态已并入 _build_mod_tooltip 结构化头部，
				# description 只保留来源说明，不再重复拼"稀有度：xxx\n状态：xxx"。
				"description": "改造图纸（永久解锁，消耗纳米材料安装到具体卡牌）",
				# v9.0: 让 _refresh_lore 显示效果/原型/装配数/槽位类型
				"effect_text": String(bp.get("effect_text", "")),
				# 2026-08-25 修⑥：完整效果行数组（tooltip 用，瓷砖只放第一条）
				"effect_lines": bp.get("effect_lines", []),
				"prototype": String(bp.get("prototype", "")),
				"slot_type": String(bp.get("slot_type", "")),
				"install_count": int(mod_install_count.get(bp.mod_id, 0)),
				"rarity": String(bp.rarity),
				"installed": bool(bp.installed),
			}
			item.set_data(bp.item_type, bp.count, ResourceSlotItem.SlotType.LORE, extra_data)
		# v7.x：错峰入场动画
		_play_tile_enter_animation(item, _mod_idx)
		_mod_idx += 1
	_schedule_sync_card_grid_scroll_size_for_grid(_intel_grid)
	# v9.3：左侧栏已折叠（tscn IntelHSplit collapsed=true），分类改用顶部 chips，不再刷新侧栏。


## v9.2: 刷新改造左侧筛选侧栏（对齐 HTML .mods-sidebar）
## 两层筛选：① 兵种桶（全部/步兵/装甲/.../强化）② 装配状态（全部/已装配/待装配）
## 每项显示对应数量，点击切换 _mod_bucket_filter / 新增 _mod_status_filter
var _mod_status_filter: String = ""  ## "" = 全部；"installed" = 已装配；"pending" = 待装配
func _refresh_mod_sidebar(visible_blueprints: Array, install_count_map: Dictionary) -> void:
	if _mod_sidebar == null:
		return
	# 统计各桶数量（基于全部已获改造，非过滤后）
	var bucket_counts: Dictionary = {}  # bucket_key → count
	var installed_total: int = 0
	var pending_total: int = 0
	# 重新从 IntelItemBag 统计（visible_blueprints 可能已被过滤）
	var bag = get_node_or_null("/root/IntelItemBag")
	var all_items: Dictionary = {}
	if bag and bag.has_method("get_all_inventory"):
		all_items = bag.get_all_inventory()
	for item_type in all_items.keys():
		if int(all_items[item_type]) <= 0:
			continue
		if not IntelManualItemsRef.is_mod_blueprint(String(item_type)):
			continue
		var mid: String = BlueprintDefinitionsRef.extract_mod_id(String(item_type))
		if mid.is_empty():
			continue
		var bucket: String = _mod_bucket_of(mid)
		if not bucket.is_empty():
			bucket_counts[bucket] = bucket_counts.get(bucket, 0) + 1
		if install_count_map.has(mid):
			installed_total += 1
		else:
			pending_total += 1
	# 清空侧栏旧内容
	for c in _mod_sidebar.get_children():
		c.queue_free()
	# ── 第一层：兵种桶 ──
	var section1 := _make_sidebar_section("兵种类型")
	_mod_sidebar.add_child(section1)
	# "全部"
	var total_all := 0
	for bk in bucket_counts.keys():
		total_all += int(bucket_counts[bk])
	section1.add_child(_make_sidebar_item("▣ 全部", total_all, _mod_bucket_filter.is_empty(),
		func(): _on_sidebar_bucket_pressed("")))
	# 10 个桶
	for prefix in _MOD_BUCKETS.keys():
		var label_text: String = _MOD_BUCKETS[prefix]
		var cnt: int = int(bucket_counts.get(prefix, 0))
		if cnt == 0:
			continue  # 没有该桶改造就不显示
		section1.add_child(_make_sidebar_item("%s %s" % [_mod_bucket_glyph(prefix), label_text], cnt,
			_mod_bucket_filter == prefix, _on_sidebar_bucket_pressed.bind(prefix)))
	# ── 第二层：装配状态 ──
	var section2 := _make_sidebar_section("装配状态")
	_mod_sidebar.add_child(section2)
	section2.add_child(_make_sidebar_item("● 全部", installed_total + pending_total,
		_mod_status_filter.is_empty(), _on_sidebar_status_pressed.bind("")))
	section2.add_child(_make_sidebar_item("● 已装配", installed_total,
		_mod_status_filter == "installed", _on_sidebar_status_pressed.bind("installed")))
	section2.add_child(_make_sidebar_item("○ 待装配", pending_total,
		_mod_status_filter == "pending", _on_sidebar_status_pressed.bind("pending")))


## v9.2: 兵种桶前缀 → glyph 符号（与工具栏 chip 风格统一）
const _MOD_BUCKET_GLYPHS = {
	"inf_": "⚔", "arm_": "◈", "art_": "◎", "aa_": "↑",
	"air_": "✈", "rec_": "◉", "eng_": "⚙", "for_": "■",
	"gen_": "○", "enh_": "★",
}
func _mod_bucket_glyph(prefix: String) -> String:
	return _MOD_BUCKET_GLYPHS.get(prefix, "•")


## v9.2: 侧栏分组标题（小标题 + 下划线）
func _make_sidebar_section(title: String) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
	lbl.add_theme_font_override("font", DesignTokens.get_title_font())
	lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.78, 0.7))
	vbox.add_child(lbl)
	var sep := HSeparator.new()
	vbox.add_child(sep)
	return vbox


## v9.2: 侧栏单个筛选项（icon+文字 + 右侧数量）
func _make_sidebar_item(text: String, count: int, active: bool, callable: Callable) -> Button:
	var row := Button.new()
	row.text = "%s  %d" % [text, count]
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
	row.custom_minimum_size = Vector2(0, 26)
	# 样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.10, 0.15, 0.3) if active else DesignTokens.COLOR_TRANSPARENT
	style.border_color = DesignTokens.COLOR_CYAN_TECH if active else Color(0.25, 0.30, 0.40, 0.3)
	style.set_border_width_all(0)
	style.border_width_left = 2 if active else 0
	style.set_corner_radius_all(2)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	row.add_theme_stylebox_override("normal", style)
	row.add_theme_color_override("font_color",
		DesignTokens.COLOR_CYAN_TECH_SOFT if active else Color(0.66, 0.71, 0.81, 0.85))
	row.pressed.connect(callable)
	return row


## v9.2: 侧栏兵种桶筛选点击
func _on_sidebar_bucket_pressed(bucket: String) -> void:
	_mod_bucket_filter = bucket
	_last_lore_signature = "__INVALIDATED__"
	refresh_intel_tab()


## v9.2: 侧栏装配状态筛选点击
func _on_sidebar_status_pressed(status: String) -> void:
	_mod_status_filter = status
	_last_lore_signature = "__INVALIDATED__"
	refresh_intel_tab()


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
	lbl.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_BODY)
	# 固定 950 宽曾把网格最小宽撑到 4列×950=3818px，远超 1176px 面板（占位符被
	# _effective_slot_width 当瓷砖宽采样）。改为随父滚动容器可用宽收缩 + 打占位标记。
	lbl.custom_minimum_size = Vector2(_grid_placeholder_width(grid), 80.0)
	lbl.set_meta("_grid_placeholder", true)
	grid.add_child(lbl)


## 占位符横幅宽度：随父滚动容器可用宽收缩（预留滚动条+边距 28），父尺寸未定时保守取 640。
func _grid_placeholder_width(grid: GridContainer) -> float:
	if grid != null and is_instance_valid(grid):
		var sc: Node = grid.get_parent()
		if sc is Control and (sc as Control).size.x > 1.0:
			return clampf((sc as Control).size.x - 28.0, 320.0, 950.0)
	return 640.0


# v9.0: refresh_stat_boosts_tab + _add_stat_boosts_placeholder 已移除（STAT_BOOSTS Tab 砍掉）
# _add_stat_boost_item 保留但不再被调用（_stat_boost_slot_pool 也保留为空，不破坏对象池逻辑）

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
	# v9.2: 应用工具栏过滤（类别 + 搜索关键字）
	if not _rune_cat_filter.is_empty() or not _search_query.is_empty():
		var filtered_ids: Array = []
		for rid in sorted_ids:
			var rune_id_str: String = str(rid)
			var rune_def: Dictionary = RuneClass.get_rune(rune_id_str)
			# 类别过滤
			if not _rune_cat_filter.is_empty():
				if String(rune_def.get("category", "")) != _rune_cat_filter:
					continue
			# 搜索过滤（符文名 / rune_id 包含匹配）
			if not _search_query.is_empty():
				var hay := RuneClass.get_rune_name(rune_id_str).to_lower() + " " + rune_id_str.to_lower()
				if not hay.contains(_search_query):
					continue
			filtered_ids.append(rid)
		sorted_ids = filtered_ids
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
			empty_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
			empty_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 1))
			_runeword_list_inner.add_child(empty_label)
		else:
			for rw in active:
				var entry := VBoxContainer.new()
				entry.add_theme_constant_override("separation", 2)
				var rw_id: String = String(rw.get("id", ""))
				var tier: int = int(rw.get("tier", 2))
				var tier_color: Color = RunewordDefinitions.TIER_COLORS.get(tier, DesignTokens.COLOR_ACCENT_PURPLE)
				var name_label := Label.new()
				name_label.text = "★ %s (T%d)" % [RunewordDefinitions.get_runeword_name(rw_id), tier]
				name_label.add_theme_font_size_override("font_size", 13)
				name_label.add_theme_color_override("font_color", tier_color)
				entry.add_child(name_label)
				var effect_label := Label.new()
				effect_label.text = RunewordDefinitions.get_effects_description(rw_id)
				effect_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
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
	# v9.2: 应用工具栏过滤（来源 + 星级 + 搜索关键字）
	if not _inst_source_filter.is_empty() or not _search_query.is_empty():
		var filtered_insts: Array = []
		for cfg in sorted_instruments:
			# 来源过滤：generic/faction/drop/star7
			if not _inst_source_filter.is_empty():
				if not _matches_inst_source_filter(cfg, _inst_source_filter):
					continue
			# 搜索过滤（名字 / id 包含匹配）
			if not _search_query.is_empty():
				var hay := String(cfg.get("name", "")).to_lower() + " " + String(cfg.get("id", "")).to_lower()
				if not hay.contains(_search_query):
					continue
			filtered_insts.append(cfg)
		sorted_instruments = filtered_insts

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


## v9.0: 构建单个相位仪卡片（三列水平条带，对齐 HTML 设计稿）
## 左列(160w)：7星点阵 + 名字 + 势力/通用标签
## 中列(自适应)：槽位可视化格子 + 关键属性
## 右列(220w)：主动能力 chip + 装备/已装备按钮
func _create_phase_inst_item(cfg: Dictionary, is_equipped: bool) -> Control:
	var container := PanelContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 当前装备：金色边框 + 左侧金条；未装备：暗色卡片
	var style := StyleBoxFlat.new()
	if is_equipped:
		style.bg_color = Color(0.15, 0.18, 0.10, 0.95)
		style.border_color = Color(DesignTokens.COLOR_AMBER_SOFT.r, DesignTokens.COLOR_AMBER_SOFT.g, DesignTokens.COLOR_AMBER_SOFT.b, 0.85)  # 金色 border
		style.border_width_left = 3  # 左侧加粗金条（HTML 设计稿的当前装备高亮签名）
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.shadow_color = Color(DesignTokens.COLOR_AMBER_SOFT.r, DesignTokens.COLOR_AMBER_SOFT.g, DesignTokens.COLOR_AMBER_SOFT.b, 0.25)
		style.shadow_size = 8
	else:
		style.bg_color = Color(0.08, 0.10, 0.15, 0.92)
		style.border_color = Color(0.3, 0.35, 0.45, 0.6)
		style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	container.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	container.add_child(margin)

	# 三列横向布局
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	margin.add_child(cols)

	# === 数据准备 ===
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	var inst_name: String = String(cfg.get("name", "未知相位仪"))
	var star: int = int(cfg.get("star", 0))
	var faction_id: String = String(cfg.get("faction_id", ""))
	var is_generic: bool = bool(cfg.get("is_generic", false))
	var slot_counts: Dictionary = cfg.get("slot_counts", {})
	var green_count: int = int(slot_counts.get("green", 0))
	var yellow_count: int = int(slot_counts.get("yellow", 0))
	var rune_count: int = int(slot_counts.get("rune", 0))
	if rune_count == 0:
		rune_count = int(slot_counts.get("red", 0)) + int(slot_counts.get("blue", 0))
	var recovery_rate: float = float(cfg.get("energy_recovery_rate", 0.3))
	# v21.x: 移除 spawn_range_ratio 读取（部署带功能下线）
	var actual_recovery: float = recovery_rate * 3.0
	# v9.2: 查询当前装备中的卡/符文，判断哪些槽位已填充（用于空槽虚线占位）
	var green_filled: int = 0
	var rune_filled: int = 0
	if is_equipped:
		if pim != null:
			if pim.has_method("get_slot_card_ids"):
				for cid in pim.get_slot_card_ids():
					if not String(cid).is_empty():
						green_filled += 1
			if pim.has_method("get_rune_slots"):
				for rid in pim.get_rune_slots():
					# get_rune_slots() 返回 Array[String | null]，空槽为 null。
					# 不能用 String(rid)：String 构造函数不接受 null 会抛错；
					# str(null) 会得到非空 "null" 字符串误判为已填充，故单独判 null。
					if rid != null and str(rid) != "":
						rune_filled += 1

	# === 左列：星级点阵 + 名字 + 势力 ===
	var left_col := VBoxContainer.new()
	left_col.custom_minimum_size.x = 160.0
	left_col.add_theme_constant_override("separation", 6)
	cols.add_child(left_col)

	# 7 颗星点（亮的金色，暗的灰色）
	var stars_row := HBoxContainer.new()
	stars_row.add_theme_constant_override("separation", 2)
	for i in range(7):
		var star_dot := Label.new()
		star_dot.text = "★" if i < star else "☆"
		star_dot.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_BODY)
		if i < star:
			star_dot.add_theme_color_override("font_color", DesignTokens.COLOR_AMBER_SOFT)
		else:
			star_dot.add_theme_color_override("font_color", Color(0.35, 0.4, 0.5, 0.6))
		stars_row.add_child(star_dot)
	left_col.add_child(stars_row)

	var name_label := Label.new()
	name_label.text = inst_name
	name_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
	if is_equipped:
		name_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6, 1.0))
	else:
		name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.78, 1.0))
	left_col.add_child(name_label)

	var faction_label := Label.new()
	if not is_generic:
		var faction_cfg: Dictionary = CompanyDefs.get_by_id(faction_id)
		if not faction_cfg.is_empty():
			faction_label.text = String(faction_cfg.get("name", "")) + " · 专属"
			faction_label.add_theme_color_override("font_color", Color(DesignTokens.COLOR_CYAN_TECH.r, DesignTokens.COLOR_CYAN_TECH.g, DesignTokens.COLOR_CYAN_TECH.b, 0.95))  # 青色
		else:
			faction_label.text = "专属"
			faction_label.add_theme_color_override("font_color", Color(0.75, 0.55, 0.95, 0.9))
	else:
		faction_label.text = "通用"
		faction_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.85))
	faction_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
	left_col.add_child(faction_label)

	# === 中列：槽位格子可视化 + 关键属性 ===
	var mid_col := VBoxContainer.new()
	mid_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_col.add_theme_constant_override("separation", 6)
	cols.add_child(mid_col)

	# 战斗卡槽位格子可视化（绿色小格）
	if green_count > 0:
		var green_row := HBoxContainer.new()
		green_row.add_theme_constant_override("separation", 6)
		var green_lbl := Label.new()
		green_lbl.text = "战斗卡"
		green_lbl.custom_minimum_size.x = 60.0
		green_lbl.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
		green_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.78, 0.9))
		green_row.add_child(green_lbl)
		for i in range(green_count):
			var cell := PanelContainer.new()
			cell.custom_minimum_size = Vector2(12, 14)
			var cell_style := StyleBoxFlat.new()
			if is_equipped and i < green_filled:
				# v9.2: 已填充槽位——实色绿格
				cell_style.bg_color = Color(0.05, 0.18, 0.12, 0.7)
				cell_style.border_color = Color(0.2, 0.83, 0.6, 0.6)
			else:
				# v9.2: 空槽位——虚线占位（设计稿 .slot-cell.empty）
				cell_style.bg_color = DesignTokens.COLOR_TRANSPARENT
				cell_style.border_color = Color(0.25, 0.35, 0.45, 0.4)
			cell_style.set_border_width_all(1)
			cell_style.set_corner_radius_all(2)
			cell.add_theme_stylebox_override("panel", cell_style)
			green_row.add_child(cell)
		mid_col.add_child(green_row)

	# 符文槽位格子可视化（紫色小格）
	if rune_count > 0:
		var rune_row := HBoxContainer.new()
		rune_row.add_theme_constant_override("separation", 6)
		var rune_lbl := Label.new()
		rune_lbl.text = "符文"
		rune_lbl.custom_minimum_size.x = 60.0
		rune_lbl.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
		rune_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.78, 0.9))
		rune_row.add_child(rune_lbl)
		for i in range(rune_count):
			var cell := PanelContainer.new()
			cell.custom_minimum_size = Vector2(12, 14)
			var cell_style := StyleBoxFlat.new()
			if is_equipped and i < rune_filled:
				# v9.2: 已填充槽位——实色紫格
				cell_style.bg_color = Color(0.15, 0.08, 0.24, 0.7)
				cell_style.border_color = Color(0.65, 0.45, 0.95, 0.6)
			else:
				# v9.2: 空槽位——虚线占位
				cell_style.bg_color = DesignTokens.COLOR_TRANSPARENT
				cell_style.border_color = Color(0.25, 0.35, 0.45, 0.4)
			cell_style.set_border_width_all(1)
			cell_style.set_corner_radius_all(2)
			cell.add_theme_stylebox_override("panel", cell_style)
			rune_row.add_child(cell)
		mid_col.add_child(rune_row)

	# 关键属性行（能量恢复 + 卡伤/防御等；v21.x: 部署范围移除）
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 16)
	mid_col.add_child(stats_row)
	_add_phase_stat_mini(stats_row, "能量恢复", "%.1f/s" % actual_recovery, false)
	if cfg.has("card_damage_bonus") and float(cfg.card_damage_bonus) > 0:
		_add_phase_stat_mini(stats_row, "卡伤", "+%.0f%%" % (float(cfg.card_damage_bonus) * 100), true)
	if cfg.has("defense_bonus") and float(cfg.defense_bonus) > 0:
		_add_phase_stat_mini(stats_row, "防御", "+%.0f%%" % (float(cfg.defense_bonus) * 100), true)
	if cfg.has("xp_bonus") and float(cfg.xp_bonus) > 0:
		_add_phase_stat_mini(stats_row, "经验", "+%.0f%%" % (float(cfg.xp_bonus) * 100), true)
	if cfg.has("energy_cost_reduction") and int(cfg.energy_cost_reduction) > 0:
		_add_phase_stat_mini(stats_row, "能耗", "-%d" % int(cfg.energy_cost_reduction), true)

	# 特性文字行（如有）
	var traits: Array = cfg.get("special_traits", [])
	if traits is Array and not traits.is_empty():
		var trait_label := Label.new()
		trait_label.text = "✦ " + "  |  ".join(PackedStringArray(traits))
		trait_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
		trait_label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0, 0.85))
		trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		mid_col.add_child(trait_label)

	# === 右列：主动能力 chip + 装备按钮 ===
	var right_col := VBoxContainer.new()
	right_col.custom_minimum_size.x = 220.0
	right_col.add_theme_constant_override("separation", 8)
	right_col.alignment = BoxContainer.ALIGNMENT_END
	cols.add_child(right_col)

	# 主动能力 chip（7★ 才有，否则灰色"无主动能力"）
	var ability: Dictionary = cfg.get("active_ability", {})
	var ability_chip := HBoxContainer.new()
	ability_chip.add_theme_constant_override("separation", 6)
	var chip_style := StyleBoxFlat.new()
	chip_style.set_corner_radius_all(3)
	chip_style.set_border_width_all(1)
	chip_style.content_margin_left = 10.0
	chip_style.content_margin_right = 10.0
	chip_style.content_margin_top = 5.0
	chip_style.content_margin_bottom = 5.0
	var ability_chip_panel := PanelContainer.new()
	if not ability.is_empty():
		var ability_name: String = String(ability.get("name", "主动能力"))
		chip_style.bg_color = Color(0.98, 0.75, 0.14, 0.08)
		chip_style.border_color = Color(0.98, 0.75, 0.14, 0.4)
		ability_chip_panel.add_theme_stylebox_override("panel", chip_style)
		var ability_dot := Label.new()
		ability_dot.text = "◆"
		ability_dot.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
		ability_dot.add_theme_color_override("font_color", DesignTokens.COLOR_AMBER_SOFT)
		ability_chip.add_child(ability_dot)
		var ability_text := Label.new()
		ability_text.text = ability_name
		ability_text.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
		ability_text.add_theme_color_override("font_color", DesignTokens.COLOR_AMBER_SOFT)
		ability_chip.add_child(ability_text)
	else:
		chip_style.bg_color = Color(0.04, 0.07, 0.12, 0.0)
		chip_style.border_color = Color(0.25, 0.3, 0.4, 0.5)
		ability_chip_panel.add_theme_stylebox_override("panel", chip_style)
		var none_text := Label.new()
		none_text.text = "无主动能力"
		none_text.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
		none_text.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55, 0.7))
		ability_chip.add_child(none_text)
	ability_chip_panel.add_child(ability_chip)
	right_col.add_child(ability_chip_panel)

	# 装备按钮 / 当前装备标记
	if is_equipped:
		var equipped_btn := Button.new()
		equipped_btn.text = "✓ 当前装备"
		equipped_btn.disabled = true
		equipped_btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
		equipped_btn.custom_minimum_size = Vector2(160, 30)
		var eq_style := StyleBoxFlat.new()
		eq_style.bg_color = Color(0.13, 0.40, 0.23, 0.18)
		eq_style.border_color = Color(0.2, 0.83, 0.6, 0.5)
		eq_style.set_border_width_all(1)
		eq_style.set_corner_radius_all(3)
		equipped_btn.add_theme_stylebox_override("normal", eq_style)
		equipped_btn.add_theme_color_override("font_color", DesignTokens.COLOR_GREEN_UP)
		right_col.add_child(equipped_btn)
	else:
		var equip_btn := Button.new()
		equip_btn.text = "装备"
		equip_btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
		equip_btn.custom_minimum_size = Vector2(160, 30)
		right_col.add_child(equip_btn)
		var iid_copy: String = String(cfg.get("id", ""))
		equip_btn.pressed.connect(_on_phase_inst_equip_pressed.bind(iid_copy))

	return container


## v9.0: 相位仪属性 mini 标签（label + value 上下结构）
func _add_phase_stat_mini(parent: HBoxContainer, lbl_text: String, val_text: String, is_up: bool) -> void:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 1)
	var lbl := Label.new()
	lbl.text = lbl_text
	lbl.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.58, 0.7, 0.9))
	cell.add_child(lbl)
	var val := Label.new()
	val.text = val_text
	val.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
	if is_up:
		val.add_theme_color_override("font_color", DesignTokens.COLOR_GREEN_UP)  # 绿色提升
	else:
		val.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 1.0))
	cell.add_child(val)
	parent.add_child(cell)


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


## v9.2: 判断相位仪 cfg 是否匹配来源/星级过滤
## filter_key: "generic" / "faction" / "drop" / "star7"
func _matches_inst_source_filter(cfg: Dictionary, filter_key: String) -> bool:
	if cfg.is_empty():
		return false
	match filter_key:
		"generic":
			# 通用 = is_generic true 且 acquire_rule = generic_store
			return bool(cfg.get("is_generic", false)) and String(cfg.get("acquire_rule", "")) == "generic_store"
		"faction":
			# 势力专属 = acquire_rule = faction_reputation
			return String(cfg.get("acquire_rule", "")) == "faction_reputation"
		"drop":
			# 掉落 = acquire_rule = phase_master_drop 或 source = drop
			return String(cfg.get("acquire_rule", "")) == "phase_master_drop" or String(cfg.get("source", "")) == "drop"
		"star7":
			# 7★ = star == 7
			return int(cfg.get("star", 0)) == 7
	return false


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
	var star_req: int = int(rune_def.get("star_requirement", 1))
	# v9.0: 检测该符文是否参与了已激活的符文之语（决定瓷砖是否带紫色符文之语角标）
	var runeword_active := _is_rune_in_active_runeword(rune_id)
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
	# v9.0: 主效果简短显示（primary_effect.stat + value）
	var effect_short: String = _format_rune_primary_effect(rune_def)
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
		# v9.0: 装饰层数据
		"star_requirement": star_req,
		"runeword_active": runeword_active,
		"effect_short": effect_short,
	}
	# 复用符文对象池（_acquire_slot_from_pool 统一复位 visible/modulate + 打 is_rune_slot 标记）
	var item = _acquire_slot_from_pool(_rune_slot_pool, ResourceSlotScene, "is_rune_slot")
	if item == null:
		return
	grid.add_child(item)
	if item.has_method("set_data"):
		# v6.2: 使用 RUNE 槽位类型，让 ResourceSlotItem 走 _refresh_rune 分支
		item.set_data(rune_id, count, ResourceSlotItem.SlotType.RUNE, extra_data)
	# v6.2: 连接点击信号（对象池复用时先断开旧连接，避免重复连接报错）
	if item.has_signal("rune_clicked"):
		if item.rune_clicked.is_connected(_on_backpack_rune_clicked):
			item.rune_clicked.disconnect(_on_backpack_rune_clicked)
		item.rune_clicked.connect(_on_backpack_rune_clicked)
	# v9.1: 移除死代码（border_color 计算后未使用），modulate 直接置白；
	# 已装备状态靠 extra_data.runeword_active 边框 + RuneEquippedDot 区分，不靠整体变暗
	item.modulate = DesignTokens.COLOR_HOVER_WHITE
	# 设置 tooltip
	if "tooltip_text" in item:
		item.tooltip_text = "【%s】%s\n%s\n（点击装备/卸下）" % [rarity_name, rune_name, desc]
	# v7.x：错峰入场动画（anim_idx < 0 时不动画，兼容其他调用点）
	if anim_idx >= 0:
		_play_tile_enter_animation(item, anim_idx)


## v9.0: 检测某符文是否参与了已激活的符文之语（用于瓷砖角标）
func _is_rune_in_active_runeword(rune_id: String) -> bool:
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim == null or not pim.has_method("get_active_runewords"):
		return false
	var active_rws: Array = pim.get_active_runewords()
	for rw in active_rws:
		if rw is Dictionary:
			var required: Array = rw.get("required_runes", [])
			if required.has(rune_id):
				return true
	return false


## v9.0: 符文主效果 → 简短显示（"攻击 +12%" 等）
func _format_rune_primary_effect(rune_def: Dictionary) -> String:
	var primary: Dictionary = rune_def.get("primary_effect", {})
	if primary.is_empty():
		return ""
	var stat: String = String(primary.get("stat", ""))
	var value = primary.get("value", 0)
	var stat_name := _rune_stat_short_name(stat)
	if stat_name.is_empty():
		return ""
	var f: float = float(value)
	if absf(f) < 0.5:
		# 0~0.5 多半是百分比（如 0.12 = 12%）
		return "%s +%d%%" % [stat_name, int(round(f * 100))]
	else:
		return "%s +%s" % [stat_name, str(int(f))]


## v9.0: 符文 stat key → 简短中文名
func _rune_stat_short_name(stat: String) -> String:
	match stat:
		"attack": return "攻击"
		"defense": return "防御"
		"hp": return "HP"
		"attack_speed": return "攻速"
		"deploy_speed": return "部署"
		"energy_regen": return "能量"
		"energy_cost_reduction": return "能耗"
		"range": return "射程"
		"dodge": return "闪避"
		"crit": return "暴击"
		"accuracy": return "命中"
		"hp_regen": return "回血"
		"damage_reduction": return "减伤"
		"attack_penetration": return "穿透"
		_: return ""

## v6.2: 背包符文格子点击 → 装备到首个空槽；已装备则卸下
func _on_backpack_rune_clicked(rune_id: String) -> void:
	if rune_id.is_empty():
		return
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim == null or not pim.has_method("equip_rune"):
		_show_rune_action_hint("符文系统未就绪")
		_play_rune_sound("error")
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
		_play_rune_sound("card_pickup")
		refresh_runes_tab()
		return
	# 未装备 → 找第一个空槽装备
	var slot_count: int = pim.get_rune_slot_count() if pim.has_method("get_rune_slot_count") else 0
	if slot_count <= 0:
		_show_rune_action_hint("当前相位仪没有符文槽位")
		_play_rune_sound("error")
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
		_play_rune_sound("error")
		return
	var ok: bool = pim.equip_rune(target_slot, rune_id)
	if ok:
		_show_rune_action_hint("已装备：%s" % RuneClass.get_rune_name(rune_id))
		_play_rune_sound("card_place")
		refresh_runes_tab()
	else:
		_show_rune_action_hint("装备失败（槽位不可用）")
		_play_rune_sound("error")

## B2: 符文操作音效（此前全路径有 toast 但静音）
func _play_rune_sound(name: String) -> void:
	if SignalBus and SignalBus.has_signal("play_sound"):
		SignalBus.play_sound.emit(name)

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
	lbl.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_BODY)
	# 同 _add_intel_placeholder：固定 950 宽会撑爆网格，改为随父容器收缩 + 占位标记
	lbl.custom_minimum_size = Vector2(_grid_placeholder_width(grid), 80.0)
	lbl.set_meta("_grid_placeholder", true)
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
		(item as Control).modulate = DesignTokens.COLOR_HOVER_WHITE
	item.set_meta(meta_key, true)
	return item


# v9.0: refresh_resources_tab / refresh_lore_pages / refresh_stat_boosts / refresh_stat_boosts_tab 已移除
# （RESOURCES + STAT_BOOSTS Tab 被砍）。保留 refresh_lore_pages / refresh_stat_boosts 作为 no-op stub，
# 因 backpack_presenter 用 has_method 守卫调用这两个方法，删了虽不崩但保留更显式。
func refresh_lore_pages() -> void:
	# v9.0: lore 改造内容已在 INTEL Tab 展示，外部 lore_unlocked 信号回调转发为 refresh_intel_tab
	if _tab_container and _tab_container.current_tab == TabIndex.INTEL:
		refresh_intel_tab()

## v9.0 no-op stub：STAT_BOOSTS Tab 已移除，属性提升不再在背包显示。保留方法避免 presenter 链路报错。
func refresh_stat_boosts() -> void:
	pass

## ============================================================
## UI 事件回调（转发给 Presenter）
## ============================================================

## 卡牌点击（被 backpack_card_item 的 card_clicked 信号调用）
## 同时被 phase_instrument_panel.gd 跨节点调用，必须保持此签名
func _on_card_clicked(card: CardResource, source_item: Control) -> void:
	if _presenter:
		_presenter.on_card_clicked(card, source_item)
	# B5: 详情打开期间持续轻提亮"刚点的是哪张"——详情关闭后网格此前回到无选中状态，
	# 玩家从详情返回找不到刚才看的是哪张卡
	_set_last_detail_item(source_item)

## B5: 记录详情来源卡牌格并施加持续轻提亮；换目标时复位旧格
var _detail_source_item: Control = null

func _set_last_detail_item(item: Control) -> void:
	if _detail_source_item != null and is_instance_valid(_detail_source_item) and _detail_source_item != item:
		_detail_source_item.modulate = DesignTokens.COLOR_HOVER_WHITE
	_detail_source_item = item
	if item != null and is_instance_valid(item):
		item.modulate = Color(1.12, 1.12, 1.12)

## B5: 清除详情来源高亮（详情关闭/背包关闭时）
func _clear_last_detail_item() -> void:
	if _detail_source_item != null and is_instance_valid(_detail_source_item):
		_detail_source_item.modulate = DesignTokens.COLOR_HOVER_WHITE
	_detail_source_item = null

func _on_detail_close() -> void:
	if _presenter:
		_presenter.on_detail_close()
	_clear_last_detail_item()

## PopupPanel.popup_hide 信号回调：点弹窗外区域/系统关闭时触发，确保内嵌情报面板状态清空
func _on_detail_popup_hide() -> void:
	if _detail_info_panel and is_instance_valid(_detail_info_panel) and _detail_info_panel.has_method("hide_panel"):
		_detail_info_panel.hide_panel()
	_clear_last_detail_item()

func _on_close() -> void:
	if _presenter:
		_presenter.on_close()
	_clear_last_detail_item()

## 外部打开背包面板时调用：仅在隐藏期间有脏数据时做一次刷新
func on_overlay_opened() -> void:
	if _presenter and _presenter.has_method("on_overlay_opened"):
		_presenter.on_overlay_opened()

func _refresh_aux_sections_after_open() -> void:
	if not is_visible_in_tree():
		return
	# v9.0: 砍掉 RESOURCES + STAT_BOOSTS Tab，只刷新剩下的 3 个非战斗卡 tab
	refresh_intel_tab()
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
		(item as Control).modulate = DesignTokens.COLOR_HOVER_WHITE
	grid.add_child(item)
	item.set_card(card)
	if not item.card_clicked.is_connected(_on_card_clicked):
		item.card_clicked.connect(_on_card_clicked)
	# v7.x: 连接批量选择信号（仅 backpack_card_item 有此信号）
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
	# 批次三 B14：同值字面量收口 MOTION token（淡入 SINE+EASE_OUT / 弹出 BACK+EASE_OUT 由调用侧定）
	t.tween_property(item, "modulate:a", 1.0, DesignTokens.MOTION_FADE_IN).set_ease(Tween.EASE_OUT)
	t.tween_property(item, "scale", Vector2(1.0, 1.0), DesignTokens.MOTION_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	t.tween_property(item, "modulate", DesignTokens.COLOR_HOVER_WHITE, 0.5).set_ease(Tween.EASE_OUT)

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

## v9.2：空槽位添加居中两行内容（"空槽位" / "— 未获得 —"）。
## 对齐 HTML 设计稿 .card-tile[空槽位] 视觉：虚线边框 + 居中小字。
## 池化复用时复用已有 VBoxContainer。
func _ensure_empty_slot_plus(placeholder: Panel) -> void:
	if placeholder == null:
		return
	placeholder.tooltip_text = "空槽位（未获得）"
	var vbox: VBoxContainer = placeholder.get_node_or_null("EmptyContentBox") as VBoxContainer
	if vbox == null:
		vbox = VBoxContainer.new()
		vbox.name = "EmptyContentBox"
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 第一行："空槽位"
		var line1 := Label.new()
		line1.name = "EmptyTitleLabel"
		line1.text = "空槽位"
		line1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line1.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
		line1.add_theme_color_override("font_color", Color(0.42, 0.47, 0.57, 0.6))
		line1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(line1)
		# 第二行："— 未获得 —"
		var line2 := Label.new()
		line2.name = "EmptySubtitleLabel"
		line2.text = "— 未获得 —"
		line2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line2.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
		line2.add_theme_color_override("font_color", Color(0.35, 0.40, 0.50, 0.5))
		line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(line2)
		placeholder.add_child(vbox)
	vbox.visible = true

func _get_empty_slot_style() -> StyleBoxFlat:
	if _empty_slot_style != null:
		return _empty_slot_style
	_empty_slot_style = StyleBoxFlat.new()
	# v9.2：对齐 HTML 设计稿空槽位视觉——深底 + 虚线感暗灰边框（Godot StyleBoxFlat 无原生虚线，
	# 用较低 alpha 的 1px 边框 + 偏暗的色调近似）
	_empty_slot_style.bg_color = Color(0.039, 0.059, 0.110, 0.5)  # bg-slot-locked
	_empty_slot_style.set_border_width_all(1)
	_empty_slot_style.border_color = Color(0.25, 0.35, 0.5, 0.35)
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
## v9.0: 改造/符文瓷砖（resource_slot_item 64×96）比战斗卡（96×138）小，列数独立计算
func _apply_backpack_grid_layout(grid: GridContainer) -> void:
	if grid == null or not is_instance_valid(grid):
		return
	var sep_h: int = grid.get_theme_constant("h_separation", "GridContainer")
	# v9.3：战斗卡 + 改造/符文瓷砖都按可用宽度动态算列数，填满面板（避免右侧大片空白）。
	var slot_min_w: float = CARD_SLOT_MIN.x
	var min_cols: int = BACKPACK_GRID_COLUMNS
	var max_cols: int = 14
	if grid != _combat_cards_grid:
		slot_min_w = _TILE_SLOT_MIN.x
		min_cols = 4
		max_cols = 20
	# 实际子节点宽（瓷砖含边框可能 > slot_min）——用实际宽避免按 slot_min 算多列、排开超 viewport 溢出
	var effective_w: float = _effective_slot_width(grid, slot_min_w)
	var cols: int = _compute_grid_columns(effective_w, sep_h, grid, min_cols, max_cols)
	# v9.3：EXPAND_FILL 左对齐铺满（固定宽瓷砖/卡片右侧 < 1 列余量不可避免；SHRINK_CENTER 会把余量均分到两侧显得左右都空）
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = cols
	grid.custom_minimum_size.x = float(
		cols * int(effective_w) + maxi(0, cols - 1) * sep_h
	)


## v9.3: 取网格子节点的实际宽度做列宽基准；无子时回退 fallback。
## 2026-08-25 改为取"最宽子节点"而非首块：效果文字长度不一会造出宽窄不一的瓷砖，
## 按首块窄瓷砖算列数、排开后整行溢出（168 改造档实测：5 列 + 横向滚动条）。
## 占位符横幅（_grid_placeholder 标记）不参与采样——其宽度是横幅展示宽，非瓷砖宽。
func _effective_slot_width(grid: GridContainer, fallback: float) -> float:
	var w: float = 0.0
	if grid != null and is_instance_valid(grid):
		for ch in grid.get_children():
			if ch is Control and not (ch as Control).has_meta("_grid_placeholder"):
				w = maxf(w, (ch as Control).size.x)
	return w if w > 1.0 else fallback


## v9.3: 按父容器（ScrollContainer）可用宽度计算一行能容纳的列数——填满且不溢出。
## 可用宽度 = 父容器宽 - 垂直滚动条实际宽 - 容差；父容器 size 未定时回退最小列数（保守）。
func _compute_grid_columns(slot_w: float, sep: int, grid: GridContainer, min_cols: int, max_cols: int) -> int:
	var parent: Node = grid.get_parent() if is_instance_valid(grid) else null
	if parent is Control and (parent as Control).size.x > 1.0:
		var avail: float = float((parent as Control).size.x)
		# 扣垂直滚动条实际宽（瓷砖多时垂直滚动出现，占去内容宽）
		if parent is ScrollContainer:
			var vsb: VScrollBar = (parent as ScrollContainer).get_v_scroll_bar()
			if vsb != null and vsb.is_visible_in_tree():
				avail -= float(vsb.size.x)
		avail -= 8.0  # 边距/舍入容差
		var c: int = floori((avail + float(sep)) / (slot_w + float(sep)))
		return clampi(c, min_cols, max_cols)
	# 父容器 size 未定时回退最小列数（保守，绝不按估算算多导致溢出）
	return min_cols


## v9.3: 布局完成后的延迟重排：首次 _ready 时父容器 size 可能未定，此处用实际宽度重算所有网格。
func _reflow_grids_after_layout() -> void:
	for g in [_combat_cards_grid, _intel_grid, _runes_grid]:
		if g != null and is_instance_valid(g):
			_apply_backpack_grid_layout(g)


## v9.3: 连接各网格父容器（ScrollContainer）的 resized 信号——父容器布局完成、size 确定时触发，
## 自动重排该网格列数。解决首次切 Tab 时 size 跨帧布局未定导致回退 min_cols 的问题。
func _connect_grid_scroll_resized() -> void:
	for g in [_combat_cards_grid, _intel_grid, _runes_grid]:
		if g == null or not is_instance_valid(g):
			continue
		var sc: Node = g.get_parent()
		if sc is Control:
			var ctrl: Control = sc as Control
			if not ctrl.resized.is_connected(_on_grid_scroll_resized):
				ctrl.resized.connect(_on_grid_scroll_resized.bind(g))


## v9.3: 网格父容器尺寸变化时重排该网格列数（确保切 Tab 布局完成后列数按实际尺寸准确）。
func _on_grid_scroll_resized(grid: GridContainer) -> void:
	if grid != null and is_instance_valid(grid):
		_apply_backpack_grid_layout(grid)


## v9.4: 连接战斗卡 ScrollContainer 的滚动条 value_changed + resized 信号。
## 滚动/缩放时重扫所有卡牌的视口可见性，让 CardItem 按需加载/卸载图标纹理。
## 连接是幂等的（用 is_connected 守卫），重复 _ready 安全。
func _connect_scroll_visibility_hooks() -> void:
	if _scroll == null or not is_instance_valid(_scroll):
		return
	var vsb: VScrollBar = _scroll.get_v_scroll_bar()
	if vsb and not vsb.value_changed.is_connected(_on_card_grid_scroll_changed):
		vsb.value_changed.connect(_on_card_grid_scroll_changed)
	if not _scroll.resized.is_connected(_on_card_grid_scroll_changed):
		_scroll.resized.connect(_on_card_grid_scroll_changed)


## v9.4: 滚动/尺寸变化时遍历战斗卡网格，触发每个 CardItem 的视口可见性重扫。
## 用 call_deferred 避免在滚动信号回调里直接改节点树引发布局抖动。
func _on_card_grid_scroll_changed(_v: float = 0.0) -> void:
	call_deferred("_apply_viewport_visibility_scan")


## v9.4: 扫描战斗卡网格所有子项，对每个 CardItem 调用其视口裁切钩子。
func _apply_viewport_visibility_scan() -> void:
	var grid: GridContainer = _combat_cards_grid
	if grid == null or not is_instance_valid(grid):
		return
	if _scroll == null or not is_instance_valid(_scroll):
		return
	var viewport_rect: Rect2 = _scroll.get_global_rect()
	for child in grid.get_children():
		if not is_instance_valid(child):
			continue
		# v9.4: 用鸭子类型（backpack_card_item.gd 无 class_name 声明，不能 is BackpackCardItem）。
		# 仅对持有视口裁切钩子的卡牌 item 做重扫（空槽/加载指示器跳过）。
		if child.has_method("_check_viewport_visibility"):
			child._check_viewport_visibility(viewport_rect)

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
