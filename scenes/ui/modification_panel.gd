extends Control
class_name ModificationPanel
## 改造面板（新系统 · v7.x UI 重设计 战术改造站）
## 显示军事技术改造模块
## 改造消耗：纳米材料 + 改造指南（根据稀有度）
## 签名色：青蓝（COLOR_CYAN_TECH）· 科技装配主题

signal closed

const IntelManualItems = preload("res://data/intel_manual_items.gd")
const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")
const GC = preload("res://resources/game_constants.gd")
const ModEffectLabels = preload("res://scripts/ui/mod_effect_labels.gd")

# v7.x UI 重设计基建
const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const GeoShapes = preload("res://scripts/ui/geo_shapes.gd")
# PowerTiers / ModManager 有 class_name 全局注册，无需 preload

# UI 组件引用（v7.x 重构：路径改为新三栏结构 LeftPanel/MiddlePanel/DetailPanel）
@onready var card_list_container = get_node_or_null("%CardListContainer")
@onready var mod_list_container = get_node_or_null("%ModListContainer")
@onready var card_info_panel = get_node_or_null("%DetailPanel")
@onready var research_label = get_node_or_null("%ResearchLabel")
@onready var result_label = get_node_or_null("%ResultLabel")
@onready var close_button: Button = get_node_or_null("%CloseButton")
@onready var alloy_label: Label = get_node_or_null("%AlloyLabel")
@onready var status_line_label: Label = get_node_or_null("%StatusLineLabel")
@onready var col_head_count: Label = get_node_or_null("%ColHeadCount")
@onready var mod_list_head_count: Label = get_node_or_null("%ModListHeadCount")
@onready var chip_all: Button = get_node_or_null("%ChipAll")
@onready var chip_mod: Button = get_node_or_null("%ChipMod")
@onready var chip_max: Button = get_node_or_null("%ChipMax")
@onready var left_panel: PanelContainer = get_node_or_null("%LeftPanel")
# v1.4 底部操作台（中栏底部，选中模块时显示核心属性+安装按钮）
@onready var action_deck: PanelContainer = get_node_or_null("%ActionDeck")
@onready var deck_empty: Label = get_node_or_null("%DeckEmpty")
@onready var deck_name_label: Label = get_node_or_null("%DeckNameLabel")
@onready var deck_core_label: Label = get_node_or_null("%DeckCoreLabel")
@onready var deck_req_label: Label = get_node_or_null("%DeckReqLabel")
@onready var deck_install_button: Button = get_node_or_null("%DeckInstallButton")
# v1.5 效果模拟抽屉（底部操作台次级按钮 + 展开式详情抽屉）
@onready var deck_sim_button: Button = get_node_or_null("%DeckSimButton")
@onready var sim_drawer: PanelContainer = get_node_or_null("%SimDrawer")
# v1.4 右栏单位面板（恒定显示战力/属性/已装列表，动态构建视觉块）
@onready var unit_panel: VBoxContainer = get_node_or_null("%UnitPanel")
# v1.5 右栏三档折叠按钮（完整280/紧凑200/收起0）
@onready var fold_button: Button = get_node_or_null("%FoldButton")
# v1.5 DetailInner（含 UnitScroll），折叠时整体隐藏
@onready var detail_inner: MarginContainer = get_node_or_null("VBoxContainer/HBoxContainer/DetailPanel/DetailVBox/DetailInner")

const FILTER_ALL := "all"
const FILTER_MOD := "mod"
const FILTER_MAX := "max"
var _filter_mode: String = FILTER_ALL

var selected_card: CardResource = null
var selected_mod_id: String = ""
var _embedded_mode: bool = false
# v7.x 性能优化：_refresh_mod_list 期间缓存选中卡的战力/档位，供 _create_mod_item 复用，
# 避免对每个改造条目重复走 estimate_power_score（会触发大量下游 push_warning）。
var _cached_card_power: float = 0.0
var _cached_card_tier: int = 0
# v1.5 右栏折叠档位：0完整280 / 1紧凑200 / 2收起0（右栏隐藏，靠 hover 浮卡看单位）
var _fold_state: int = 0
const _FOLD_WIDTHS := [340, 240, 0]
const _FOLD_LABELS := ["完整", "紧凑", "收起"]
# v8.x 性能：on_overlay_opened 拆帧重入守卫，避免打开动画/重复触发重叠刷新
var _open_refresh_inflight: bool = false
# v1.5 收起态 hover 浮卡（右栏收起时，hover 名册行弹迷你单位卡）
var _hover_card: PanelContainer = null
# v1.5 修复：hover 浮卡 await 竞态——_hide_hover_card bump token 作废 pending 的显示
var _hover_token: int = 0
# v1.5 修复：_show_result 多 timer 互相清空——新消息 bump token，旧 timer 自查 token 失配则不清
var _result_token: int = 0


## 计算当前选中卡的战力值（单次刷新内复用，避免 N 次重复 build_stats）。
func _compute_card_power_once() -> float:
	if selected_card == null or BlueprintManager == null:
		return 0.0
	var key: String = selected_card.instance_id if not selected_card.instance_id.is_empty() else selected_card.card_id
	if key.is_empty():
		return 0.0
	return EvolutionHelpers.estimate_power_score(key, BlueprintManager)

func _ready() -> void:
	# D1: 根框架统一 PanelStyles 签名框（覆盖 BgPanel 的 tscn 手写样式）
	var bg_panel := get_node_or_null("BgPanel")
	if bg_panel is Control:
		(bg_panel as Control).add_theme_stylebox_override("panel",
			PanelStyles.make_panel_frame(DT.get_system_color("modify")))
	# 连接关闭按钮
	if close_button:
		close_button.pressed.connect(_on_close)
	# v9.x: 连接"返回成长首页"按钮
	var back_btn: Button = get_node_or_null("%BackToGrowthButton")
	if back_btn:
		back_btn.pressed.connect(_on_back_to_growth)
	# chip 筛选
	if chip_all:
		chip_all.pressed.connect(_on_filter_pressed.bind(FILTER_ALL))
	if chip_mod:
		chip_mod.pressed.connect(_on_filter_pressed.bind(FILTER_MOD))
	if chip_max:
		chip_max.pressed.connect(_on_filter_pressed.bind(FILTER_MAX))
	# v1.5 右栏折叠按钮（三档循环：完整→紧凑→收起→完整）
	if fold_button:
		fold_button.pressed.connect(_on_fold_pressed)
		_apply_fold_state()  # 初始化按钮文案/样式
	# v1.5 效果模拟抽屉切换按钮
	if deck_sim_button:
		deck_sim_button.pressed.connect(_on_sim_button_pressed)

	# 批次三 B2d（2026-08-24）：tooltip 攻坚——chip/折叠/模拟/资源栏就地解释
	if chip_all:
		chip_all.tooltip_text = "显示全部拥有的卡牌"
	if chip_mod:
		chip_mod.tooltip_text = "只显示还有空改造槽（未满 9 格）的卡牌"
	if chip_max:
		chip_max.tooltip_text = "只显示改造槽已满（9/9）的卡牌"
	if fold_button:
		fold_button.tooltip_text = "折叠/展开右侧详情栏（三档：完整 → 紧凑 → 收起；收起时悬停名册行可看迷你浮卡）"
	if deck_sim_button:
		deck_sim_button.tooltip_text = "打开效果模拟抽屉：预览安装模块前后的属性变化"
	if research_label:
		research_label.tooltip_text = "改造消耗：纳米材料 + 改造指南（按模块稀有度），安装只影响当前选中的这张卡"

	# v7.x UI 重设计：给主要 Label 加载 Rajdhani 字体（战术感）
	_apply_title_fonts()
	_update_chip_styles()

	if _embedded_mode:
		_apply_embedded_layout()
	# v8.x 性能：非嵌入模式的 _refresh_card_list（遍历 133 卡 × N 实例重建名册）
	# 改由 on_overlay_opened 拆帧触发，避免 LazyLoader 实例化同帧卡顿。
	# 嵌入模式（背包情报 Tab）的列表刷新由 set_embedded_mode 调用方负责。
	# v1.5：键盘导航——面板可获焦接收 _gui_input
	focus_mode = Control.FOCUS_ALL

## v8.x 性能：外部打开面板时调用（main.gd._open_overlay 分发）。
## 将卡片名册重建拆到下一帧，避开打开同帧的实例化尖峰。
## 仿 store_panel.on_overlay_opened 模式（call_deferred + await process_frame + 可见性双重校验）。
func on_overlay_opened() -> void:
	if _embedded_mode:
		return  # 嵌入模式列表由外层 Tab 切换管，不重复刷
	if _open_refresh_inflight:
		return
	_open_refresh_inflight = true
	call_deferred("_run_open_refresh_pipeline")

func _run_open_refresh_pipeline() -> void:
	if not is_visible_in_tree():
		_open_refresh_inflight = false
		return
	await get_tree().process_frame
	if not is_visible_in_tree():
		_open_refresh_inflight = false
		return
	_refresh_card_list()
	_open_refresh_inflight = false


## v7.x：给标题/资源栏/主要 Label 加载 Rajdhani 字体（视觉焕新）
func _apply_title_fonts() -> void:
	var title_label = get_node_or_null("VBoxContainer/TitleRow/TitleHBox/TitleLabel")
	if title_label:
		title_label.add_theme_font_override("font", DT.get_title_font_bold())
		title_label.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH_SOFT)
	# 资源栏
	if research_label:
		research_label.add_theme_font_override("font", DT.get_body_font())
		research_label.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH_SOFT)
	# 详情面板关键 Label（v1.4：操作台模块名，单位面板动态构建的字体在构建时设置）
	for path in [
		"%DeckNameLabel",
	]:
		var lbl = get_node_or_null(path)
		if lbl:
			lbl.add_theme_font_override("font", DT.get_title_font())


## v7.x 新增：chip 筛选样式（active 高亮 cyan，非 active 灰）
func _update_chip_styles() -> void:
	var chips := {FILTER_ALL: chip_all, FILTER_MOD: chip_mod, FILTER_MAX: chip_max}
	for mode in chips:
		var btn: Button = chips[mode]
		if btn == null:
			continue
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(3)
		sb.set_border_width_all(1)
		sb.content_margin_left = 8
		sb.content_margin_top = 4
		sb.content_margin_right = 8
		sb.content_margin_bottom = 4
		if mode == _filter_mode:
			sb.bg_color = Color(0.024, 0.714, 0.831, 0.12)
			sb.border_color = DT.COLOR_CYAN_TECH
			btn.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH_SOFT)
		else:
			sb.bg_color = Color(0.05, 0.09, 0.16, 0.4)
			sb.border_color = Color(0.25, 0.35, 0.42, 0.3)
			btn.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.8))
		btn.add_theme_stylebox_override("normal", sb)
		var sb_h := sb.duplicate() as StyleBoxFlat
		sb_h.bg_color = Color(0.024, 0.714, 0.831, 0.06)
		btn.add_theme_stylebox_override("hover", sb_h)


## v7.x 新增：筛选 chip 回调
func _on_filter_pressed(mode: String) -> void:
	_filter_mode = mode
	_update_chip_styles()
	_refresh_card_list()


## v1.5：右栏折叠按钮回调——三档循环（完整→紧凑→收起→完整）
func _on_fold_pressed() -> void:
	_fold_state = (_fold_state + 1) % 3
	_apply_fold_state()


## v1.5：应用当前折叠档位（宽度 + DetailInner 可见性 + 按钮文案）
## 收起态（档2）：DetailPanel 宽度归零 + DetailInner 隐藏（RightHead 仍可见，供玩家点回展开）
func _apply_fold_state() -> void:
	if card_info_panel == null:
		return
	var w: int = _FOLD_WIDTHS[_fold_state]
	card_info_panel.custom_minimum_size.x = w
	# 收起态隐藏内容区（保留 RightHead 让玩家能点按钮展开回来）
	if detail_inner:
		detail_inner.visible = (_fold_state < 2)
	if fold_button:
		fold_button.text = _FOLD_LABELS[_fold_state]
		# 折叠按钮样式：收起态高亮（提示当前是折叠）
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(3)
		sb.set_border_width_all(1)
		sb.content_margin_left = 6
		sb.content_margin_top = 2
		sb.content_margin_right = 6
		sb.content_margin_bottom = 2
		if _fold_state == 2:
			sb.bg_color = Color(0.024, 0.714, 0.831, 0.12)
			sb.border_color = DT.COLOR_CYAN_TECH
			fold_button.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH_SOFT)
		else:
			sb.bg_color = Color(0.05, 0.09, 0.16, 0.4)
			sb.border_color = Color(0.25, 0.35, 0.42, 0.3)
			fold_button.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.8))
		fold_button.add_theme_stylebox_override("normal", sb)
	# 收起态若当前 hover 浮卡残留，隐藏掉
	if _fold_state != 2 and _hover_card != null:
		_hide_hover_card()


## v1.5：右栏收起态下，hover 名册行弹出迷你单位浮卡。
## 内容=精简右栏（名+战力大字+5档迷你条+已装N/9），约 180×130px。
## 仅当 _fold_state==2（收起）时显示，否则不弹（右栏已可见，浮卡冗余）。
func _maybe_show_hover_card(card: CardResource, anchor: Control) -> void:
	if _fold_state != 2 or card == null or not is_inside_tree():
		return
	_hover_token += 1
	var my_token := _hover_token
	if _hover_card == null:
		_hover_card = _build_hover_card()
		add_child(_hover_card)
	_refresh_hover_card(_hover_card, card)
	# 定位到 anchor 右侧 +8px，垂直居中对齐
	await get_tree().process_frame  # 等一帧让浮卡算出尺寸
	# 竞态守卫：await 期间若鼠标已离开（_hide_hover_card bump token）或节点失效，放弃显示
	if my_token != _hover_token or not is_instance_valid(_hover_card) or not is_instance_valid(anchor):
		return
	var anchor_rect: Rect2 = anchor.get_global_rect()
	var hc_size: Vector2 = _hover_card.size
	var pos := Vector2(anchor_rect.end.x + 8, anchor_rect.position.y)
	# 防溢出右边界
	var viewport_w: float = get_viewport_rect().size.x
	if pos.x + hc_size.x > viewport_w - 8:
		pos.x = anchor_rect.position.x - hc_size.x - 8  # 改弹左侧
	_hover_card.set_global_position(pos)
	_hover_card.visible = true
	# 提到最前
	_hover_card.z_index = 100


## v1.5：构建浮卡节点骨架（首次懒创建）
func _build_hover_card() -> PanelContainer:
	var pc := PanelContainer.new()
	pc.visible = false
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.z_index = 100
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.10, 0.18, 0.96)
	# 先设四边 1px cyan_soft，再把左边加粗到 3px（顺序：all 在前，left 覆盖在后）
	sb.set_border_width_all(1)
	sb.border_color = DT.COLOR_CYAN_TECH_SOFT
	sb.border_width_left = 3
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 8
	sb.content_margin_top = 6
	sb.content_margin_right = 8
	sb.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(180, 0)
	return pc


## v1.5：刷新浮卡内容（每次 hover 重建子节点）
func _refresh_hover_card(pc: PanelContainer, card: CardResource) -> void:
	for child in pc.get_children():
		pc.remove_child(child)
		child.free()
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	# 名行
	var name_lbl := Label.new()
	name_lbl.text = card.display_name if card.display_name else card.card_id
	name_lbl.add_theme_font_override("font", DT.get_title_font_bold())
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 1))
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)
	# 战力大字
	var power: float = 0.0
	var key: String = card.instance_id if not card.instance_id.is_empty() else card.card_id
	if not key.is_empty() and BlueprintManager != null:
		power = EvolutionHelpers.estimate_power_score(key, BlueprintManager)
	if power > 0:
		var power_row := HBoxContainer.new()
		power_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pl := Label.new()
		pl.text = "战力"
		pl.add_theme_font_size_override("font_size", 12)
		pl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 0.8))
		pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		power_row.add_child(pl)
		var pv := Label.new()
		pv.text = str(int(power))
		pv.add_theme_font_override("font", DT.get_title_font_bold())
		pv.add_theme_font_size_override("font_size", 20)
		pv.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH_SOFT)
		pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		power_row.add_child(pv)
		vbox.add_child(power_row)
		# 5 档迷你条
		var current_tier: int = PowerTiers.get_tier_by_power(power) if PowerTiers != null else 0
		vbox.add_child(_build_tier_progress(current_tier))
	# 已装 N/9
	var mod_count: int = card.mods.size() if "mods" in card else 0
	var mod_lbl := Label.new()
	mod_lbl.text = "已装改造  %d / 9" % mod_count
	mod_lbl.add_theme_font_size_override("font_size", 12)
	mod_lbl.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH_SOFT if mod_count > 0 else Color(0.5, 0.55, 0.65, 0.7))
	vbox.add_child(mod_lbl)
	pc.add_child(vbox)


## v1.5：隐藏浮卡
func _hide_hover_card() -> void:
	_hover_token += 1  # 作废所有 pending 的 _maybe_show_hover_card（防止 await 返回后又显示）
	if _hover_card != null and is_instance_valid(_hover_card):
		_hover_card.visible = false

## 内嵌模式：隐藏 TitleRow + 左侧卡牌列表
func set_embedded_mode(p_embedded: bool) -> void:
	_embedded_mode = p_embedded
	if is_inside_tree():
		_apply_embedded_layout()

func _apply_embedded_layout() -> void:
	var title_row = get_node_or_null("VBoxContainer/TitleRow")
	if title_row:
		title_row.visible = false
	# v7.x：隐藏整个左栏（含 chip 筛选 + 卡牌列表），而非仅 ScrollContainer
	if left_panel:
		left_panel.visible = false
	# v6.4: 内嵌模式下隐藏资源栏（背包场景冗余）
	var resource_bar = get_node_or_null("VBoxContainer/ResourceBar")
	if resource_bar:
		resource_bar.visible = false
	# v6.6: 嵌入模式尺寸适配——清零根节点最小尺寸，让其服从宿主 Tab 容器
	custom_minimum_size = Vector2.ZERO

## ─────────────────────────────────────────────
##  UI更新
## ─────────────────────────────────────────────

## v7.1: 同时获取通用改造
func _refresh_card_list() -> void:
	if card_list_container == null:
		return
	for child in card_list_container.get_children():
		child.queue_free()

	var DefaultCards = preload("res://data/default_cards.gd")
	var ir: Node = get_node_or_null("/root/InstanceRegistry")

	## 用 Dictionary 存 { card_id: { card: CardResource, instance_ids: Array } }
	## 2026-08-22：蓝图来源已随蓝图体系删除，列表只来自背包实例
	var card_entries: Dictionary = {}

	## 来源2：背包中的（可能是 instance_id 如 "cold_t72#1"）
	## v7.x 修复（铁律2）：优先读 InstanceRegistry 实例全集（真·实例数据源，永不被 consume）。
	## 原 ONLY 读 SaveManager 队列（pending+last_known），但该队列在 backpack_presenter 存活时
	## 会被 consume_pending_backpack_card_id 掏空，导致新买的卡看不到。SaveManager 队列降级为兜底。
	var sm: Node = get_node_or_null("/root/SaveManager")
	var all_backpack_ids: Array = []
	if ir != null and ir.has_method("get_all_instance_ids"):
		for iid in ir.get_all_instance_ids():
			all_backpack_ids.append(String(iid))
	if sm and sm.has_method("get_pending_backpack_ids"):
		all_backpack_ids.append_array(sm.get_pending_backpack_ids())
	if sm and sm.has_method("get_last_known_backpack_ids"):
		all_backpack_ids.append_array(sm.get_last_known_backpack_ids())

	for idv in all_backpack_ids:
		var sid: String = String(idv)
		if sid.is_empty():
			continue
		# 解析 instance_id → card_id
		var base_id: String = sid
		if ir != null and ir.has_method("get_card_id_of"):
			base_id = ir.get_card_id_of(sid)
		else:
			var hash_idx: int = sid.rfind("#")
			if hash_idx >= 0:
				base_id = sid.substr(0, hash_idx)
		# 记录 instance_id
		if not card_entries.has(base_id):
			card_entries[base_id] = { "card": null, "instance_ids": [] }
		# v7.x 修复（改造面板卡片重复）：pending 与 last_known 通常含同一 instance_id，
		# 原直接 append 会导致同一实例渲染两次。按 instance_id 去重后再入列。
		var _inst_arr: Array = card_entries[base_id]["instance_ids"]
		if not _inst_arr.has(sid):
			_inst_arr.append(sid)

	## 按 card_id 加载模板 CardResource
	## v7.x 修复：原版 DefaultCards.get_card_by_id 查不到模板就 continue，导致动态卡/迁移卡
	## （InstanceRegistry 里有实例，但模板未注册进 DefaultCards 缓存）被静默丢弃——
	## 背包能看到这些卡（走实例），但改造面板看不到。现在模板查不到时回退取首个实例，
	## 用实例的模板字段（display_name/combat_kind/rarity）渲染。
	for card_id in card_entries:
		var card: CardResource = DefaultCards.get_card_by_id(card_id)
		if card == null:
			# 模板查不到 → 回退取 Registry 首个同名实例（实例 clone 自模板，模板字段都在）
			if ir != null and ir.has_method("get_instances_by_card_id"):
				var _fb_ids: Array = ir.get_instances_by_card_id(card_id)
				if not _fb_ids.is_empty() and ir.has_method("get_instance"):
					card = ir.get_instance(String(_fb_ids[0]))
			if card == null:
				continue
		if card.card_type != GC.CardType.COMBAT_UNIT:
			continue
		card_entries[card_id]["card"] = card

	## 为每个 card_id 生成一个或多个列表项（应用 chip 筛选）
	var total_count: int = 0
	var shown_count: int = 0
	for card_id in card_entries:
		var entry = card_entries[card_id]
		var card: CardResource = entry["card"]
		if card == null:
			continue
		var instance_ids: Array = entry["instance_ids"]
		if not instance_ids.is_empty():
			# 有实例：为每个实例生成一个条目（带独立养成数据）
			for inst_id in instance_ids:
				var inst_card: CardResource = null
				if ir != null and ir.has_method("get_instance"):
					inst_card = ir.get_instance(inst_id)
				total_count += 1
				if not _passes_filter(inst_card if inst_card else card):
					continue
				var item = _create_card_item(card, inst_card)
				card_list_container.add_child(item)
				shown_count += 1
		else:
			# 无实例：仅显示模板（蓝图解锁但未入包的卡）
			total_count += 1
			if not _passes_filter(card):
				continue
			var item = _create_card_item(card, null)
			card_list_container.add_child(item)
			shown_count += 1
	# 更新计数（已显示 / 总数）
	if col_head_count:
		col_head_count.text = "%d / %d" % [shown_count, total_count]


## v7.x 新增：chip 筛选判定
## FILTER_ALL = 全部 / FILTER_MOD = 可改造(mod<9) / FILTER_MAX = 满槽(mod>=9)
func _passes_filter(card: CardResource) -> bool:
	if card == null:
		return true
	var mod_count: int = 0
	if "mods" in card and card.mods is Array:
		mod_count = card.mods.size()
	match _filter_mode:
		FILTER_MOD:
			return mod_count < 9
		FILTER_MAX:
			return mod_count >= 9
		_:
			return true

func _create_card_item(card: CardResource, instance_card: CardResource = null) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = ""
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_color_override("font_color", Color(0.91, 0.93, 0.96, 1))

	# v7.1: 使用实例数据（如有），否则用模板
	var display_card: CardResource = instance_card if instance_card != null else card
	var display_name: String = card.display_name if card.display_name else card.card_id
	var display_level: int = _card_level_of(display_card)  # v20.12 等级统一：战斗卡等级
	var display_mods: Array = display_card.mods if display_card else []
	var display_rarity: String = str(card.rarity) if card.has_method("get") else "common"
	if display_card != null and display_card is Object and "rarity" in display_card:
		display_rarity = str(display_card.rarity)
	elif card is Object and "rarity" in card:
		display_rarity = str(card.rarity)
	var display_instance_id: String = ""
	if display_card != null and display_card is Object and "instance_id" in display_card:
		display_instance_id = str(display_card.instance_id)

	# v7.x 新风格：选中态左侧 3px cyan 边框 + 深蓝背景
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.04, 0.07, 0.12, 0.4)
	sb_n.set_border_width_all(0)
	sb_n.set_corner_radius_all(3)
	sb_n.content_margin_left = 6
	sb_n.content_margin_top = 4
	sb_n.content_margin_right = 6
	sb_n.content_margin_bottom = 4
	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.1, 0.14, 0.22, 0.7)
	var sb_s := sb_n.duplicate() as StyleBoxFlat
	# v1.5：选中态背景仍用 cyan（保持"选中"语义识别），但左边框改用兵种色，
	# 让玩家一眼区分 combat_kind（v1.4 全 cyan，无法区分兵种）
	sb_s.bg_color = Color(0.024, 0.714, 0.831, 0.1)
	sb_s.border_width_left = 3
	sb_s.border_color = _get_kind_color(card.combat_kind)
	if selected_card and selected_card.instance_id == display_instance_id:
		btn.add_theme_stylebox_override("normal", sb_s)
		btn.add_theme_stylebox_override("hover", sb_s)
	else:
		btn.add_theme_stylebox_override("normal", sb_n)
		btn.add_theme_stylebox_override("hover", sb_h)

	# 内容 HBox：缩略卡图 + 信息列
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)

	# 缩略卡图（36×40，兵种色边框 + 稀有度顶色条 + 兵种字母）
	var thumb := PanelContainer.new()
	thumb.custom_minimum_size = Vector2(36, 40)
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var thumb_sb := StyleBoxFlat.new()
	thumb_sb.bg_color = Color(0.03, 0.06, 0.11, 1)
	thumb_sb.border_color = _get_kind_color(card.combat_kind)
	thumb_sb.set_border_width_all(1)
	thumb_sb.set_corner_radius_all(3)
	thumb.add_theme_stylebox_override("panel", thumb_sb)
	# v7.x 视觉审查：缩略区改用真实卡图（原为兵种字母占位）；无图时回退字母
	var thumb_tex: Texture2D = UiAssetLoader.card_icon_for_list(card)
	if thumb_tex != null:
		var thumb_icon := TextureRect.new()
		thumb_icon.texture = thumb_tex
		thumb_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb_icon.size_flags_horizontal = Control.SIZE_FILL
		thumb_icon.size_flags_vertical = Control.SIZE_FILL
		thumb_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.add_child(thumb_icon)
	else:
		var thumb_fallback := Label.new()
		thumb_fallback.text = _get_unit_icon(card)
		thumb_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		thumb_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		thumb_fallback.size_flags_vertical = Control.SIZE_EXPAND_FILL
		thumb_fallback.add_theme_font_size_override("font_size", 16)
		thumb_fallback.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		thumb_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.add_child(thumb_fallback)
	hbox.add_child(thumb)

	# 信息列
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 2)

	# 第一行：卡名 + 实例序号
	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_theme_constant_override("separation", 4)
	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_override("font", DT.get_title_font())
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 1) if (selected_card and selected_card.instance_id == display_instance_id) else Color(0.85, 0.88, 0.94, 1))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 单行不换行、不截断：左栏加宽到 360 容下绝大多数卡名；超长名左对齐单行显示
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = false
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(name_label)
	# 实例序号
	if instance_card != null and not str(instance_card.instance_id).is_empty():
		var iid: String = str(instance_card.instance_id)
		var h_idx: int = iid.rfind("#")
		if h_idx >= 0:
			var seq_label := Label.new()
			seq_label.text = "#" + iid.substr(h_idx + 1)
			seq_label.add_theme_font_size_override("font_size", 10)
			seq_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 0.7))
			seq_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			name_row.add_child(seq_label)
	info.add_child(name_row)

	# 第二行：Lv.N · Mx/9（单行内联）
	var meta_label := Label.new()
	meta_label.text = "Lv.%d  ·  M%d/9" % [display_level, display_mods.size()]
	meta_label.add_theme_font_override("font", DT.get_body_font())
	meta_label.add_theme_font_size_override("font_size", 12)
	meta_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 0.85))
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(meta_label)
	hbox.add_child(info)

	btn.add_child(hbox)
	btn.tooltip_text = "改造：%d/9" % display_mods.size()
	# v7.3: 选中绑定用实例对象（含养成）。实例取不到时传 null，
	# _on_card_selected 会拒绝选中（避免改造写到无养成的模板污染单例）。
	# display_card 仅用于列表项显示（含回退模板的展示），不参与养成写入。
	btn.pressed.connect(func(): _on_card_selected(instance_card))
	# v1.5：右栏收起态下 hover 弹迷你单位浮卡（替代被折叠的右栏单位面板）
	var captured_card: CardResource = display_card
	btn.mouse_entered.connect(func(): _maybe_show_hover_card(captured_card, btn))
	btn.mouse_exited.connect(_hide_hover_card)
	return btn

## v7.x 重构：显示所有已解锁（持有图纸）的改造，选了战斗卡时用状态标识区分可用性。
## 数据源从 ModificationRegistry.get_mods_for_card（硬编码 card_id 前缀白名单，不全）
## 改为从 IntelItemBag 读所有改造图纸（与背包"改造"Tab 同口径）——
## 这样背包里有的改造在面板里一定能看到，不会再出现"背包有、面板没有"。
## 兵种适用性由 _create_mod_item 的"⊘该兵种不适用"灰态标识，不再从列表里剔除。
func _refresh_mod_list() -> void:
	if not selected_card:
		return

	for child in mod_list_container.get_children():
		child.queue_free()

	## 从 IntelItemBag 读所有已解锁改造图纸（照搬 backpack_panel.refresh_intel_tab 的口径）
	var bag = get_node_or_null("/root/IntelItemBag")
	var unlocked_mod_ids: Array = []
	if bag and bag.has_method("get_all_inventory"):
		var inv: Dictionary = bag.get_all_inventory()
		for item_type in inv.keys():
			if int(inv[item_type]) <= 0:
				continue
			# 仅处理改造图纸（blueprint_ 前缀，排除 blueprint_evol_ 进化图纸）
			if not IntelManualItems.is_mod_blueprint(item_type):
				continue
			var mod_id: String = BlueprintDefinitions.extract_mod_id(item_type)
			if not mod_id.is_empty() and not unlocked_mod_ids.has(mod_id):
				unlocked_mod_ids.append(mod_id)

	## v7.x 修复（对齐设计稿）：按当前选中卡的兵种预过滤，只显示适用的改造。
	## 原版所有已解锁改造全列出，不适用的灰显写"⊘不适用"——视觉噪音巨大且不符合设计稿
	## "改造库只显示该单位能用的改造"的预期。复用 _is_mod_applicable_to_card 做数据层过滤。
	var applicable_mod_ids: Array = []
	var total_owned: int = unlocked_mod_ids.size()
	for mod_id in unlocked_mod_ids:
		if _is_mod_applicable_to_card(String(mod_id)):
			applicable_mod_ids.append(mod_id)

	if applicable_mod_ids.is_empty():
		var empty_label = Label.new()
		empty_label.text = "暂无可用改造\n（当前单位兵种不适用任何已解锁改造，或尚未获得图纸）"
		empty_label.add_theme_font_size_override("font_size", 13)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.8))
		mod_list_container.add_child(empty_label)
		if mod_list_head_count:
			mod_list_head_count.text = "可用 0 · 总持有 %d" % total_owned
		return

	## 按稀有度排序（高→低），让玩家先看到珍贵改造
	applicable_mod_ids.sort_custom(func(a: String, b: String):
		return _rarity_sort_value(String(ModificationRegistry.get_data(a).get("rarity", "common"))) \
			> _rarity_sort_value(String(ModificationRegistry.get_data(b).get("rarity", "common"))))

	# v7.x 性能优化：本次刷新期间缓存选中卡的战力值与档位，避免 _create_mod_item 对每个
	# 改造条目重复调用 estimate_power_score（O(N) 次完整 build_stats_from_card，会触发大量
	# 下游 push_warning 导致引擎 "Too many warnings" 限流，并显著拖慢面板刷新）。
	# 算一次、传给所有 mod item 复用。
	_cached_card_power = _compute_card_power_once()
	_cached_card_tier = PowerTiers.get_tier_by_power(_cached_card_power) if (_cached_card_power > 0 and PowerTiers != null) else 0

	for mod_id in applicable_mod_ids:
		var mod_data = ModificationRegistry.get_data(mod_id)
		if mod_data.is_empty():
			continue  # 找不到改造数据（旧/无效 mod_id），跳过避免渲染异常
		var item = _create_mod_item(mod_id, mod_data)
		mod_list_container.add_child(item)
	# v7.x：更新改造库计数（可用数 = 过滤后适用数；总持有 = 过滤前总数，让玩家知道还有其他兵种的改造）
	if mod_list_head_count:
		mod_list_head_count.text = "适用 %d · 总持有 %d" % [applicable_mod_ids.size(), total_owned]

func _create_mod_item(mod_id: String, mod_data: Dictionary) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = ""
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_color_override("font_color", Color(0.91, 0.93, 0.96, 1))
	# v1.5：存 mod_id 元数据，供键盘导航（↑↓ 在改造库行间移动）读取
	btn.set_meta("mod_id", mod_id)
	btn.focus_mode = Control.FOCUS_NONE  # 焦点由面板根节点统一管理，避免子按钮抢焦

	var rarity: String = String(mod_data.get("rarity", "common"))
	var rarity_names := {"common": "普通", "uncommon": "优秀", "rare": "稀有", "epic": "史诗", "legendary": "传说", "mythic": "神话"}
	var rarity_cn: String = rarity_names.get(rarity, rarity)
	var rarity_col := _rarity_color(rarity)
	var is_installed := _is_mod_installed(mod_id)
	var is_applicable := _is_mod_applicable_to_card(mod_id)
	# 不适用时跳过 can_install_modification（它会因改造数据存在但兵种不符而返回误判），
	# 直接 block_reason = "不适用该兵种"；适用时才查具体 block 原因（冲突/槽满/情报不足）。
	var block_reason := ""
	if is_applicable and not is_installed:
		block_reason = _get_install_block_reason(mod_id)

	# v7.x 新风格：左侧 3px 稀有度色条 + 选中态 cyan 背景
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.06, 0.10, 0.18, 0.5)
	sb_n.border_width_left = 3
	sb_n.border_color = rarity_col
	sb_n.set_corner_radius_all(3)
	sb_n.content_margin_left = 6
	sb_n.content_margin_top = 4
	sb_n.content_margin_right = 6
	sb_n.content_margin_bottom = 4
	if selected_mod_id == mod_id:
		# v1.5：选中态背景 + 左边框同步切 cyan 并加粗 3→4（v1.4 只改 bg，边框仍是稀有度色，视觉不统一）
		sb_n.bg_color = Color(0.024, 0.714, 0.831, 0.12)
		sb_n.border_color = DT.COLOR_CYAN_TECH
		sb_n.border_width_left = 4
	if is_installed:
		# 已装的改造淡化（与设计稿 opacity 0.45 一致）
		sb_n.bg_color = sb_n.bg_color.darkened(0.2)
	btn.add_theme_stylebox_override("normal", sb_n)
	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.12, 0.08, 0.22, 0.6)
	btn.add_theme_stylebox_override("hover", sb_h)

	# 内容 HBox：图标 + 信息列 + 状态
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 6)

	# 图标（28×28）
	var icon_path: String = mod_data.get("icon", "")
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var tex_rect := TextureRect.new()
		tex_rect.texture = UiAssetLoader.load_tex(icon_path)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(26, 26)
		tex_rect.tooltip_text = mod_data.get("name", mod_id)
		tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(tex_rect)
	else:
		# 兜底：稀有度色边框 + 稀有度首字母（v1.5：原 v1.4 只是色块，色弱不友好）
		# 字母规则：common→C / uncommon→U / rare→R / epic→E / legendary→L / mythic→M
		var placeholder := PanelContainer.new()
		placeholder.custom_minimum_size = Vector2(26, 26)
		placeholder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ph_sb := StyleBoxFlat.new()
		ph_sb.bg_color = Color(0.05, 0.09, 0.16, 0.6)
		ph_sb.border_color = rarity_col
		ph_sb.set_border_width_all(1)
		ph_sb.set_corner_radius_all(3)
		placeholder.add_theme_stylebox_override("panel", ph_sb)
		# 稀有度首字母（颜色+字母双重编码）
		var rar_letter := rarity.substr(0, 1).to_upper() if not rarity.is_empty() else "?"
		var ph_lbl := Label.new()
		ph_lbl.text = rar_letter
		ph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ph_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ph_lbl.add_theme_font_override("font", DT.get_title_font_bold())
		ph_lbl.add_theme_font_size_override("font_size", 16)
		ph_lbl.add_theme_color_override("font_color", rarity_col)
		ph_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder.add_child(ph_lbl)
		hbox.add_child(placeholder)

	# 信息列（名 + 效果摘要）
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 1)
	info.custom_minimum_size = Vector2(150, 0)  # 锁宽：中栏被挤窄时信息列不塌缩（防名字被裁空）

	# v10 改造二分法：名字行 = 名字 + 机制/数值标签（机制改造改变战法，橙色高亮）
	var name_row := HBoxContainer.new()
	name_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_theme_constant_override("separation", 4)

	var name_label := Label.new()
	# 空名兜底：极少数改造数据缺 name 字段时用 mod_id，避免空白
	var mod_name := String(mod_data.get("name", ""))
	if mod_name.is_empty():
		mod_name = mod_id
	name_label.text = mod_name
	name_label.add_theme_font_override("font", DT.get_title_font())
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.91, 0.93, 0.96, 1))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 不裁切：clip_text 在窄列会把名字裁到 0px 致不可见；单行不换行，超长向右溢出可见
	name_label.clip_text = false
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(name_label)

	# v10 分类标签：机制=改变单位"怎么打"（可组合出新战法）；数值=交换比（更硬/更快）
	var class_disp: Dictionary = ModificationRegistry.get_mod_class_display(mod_id)
	var class_tag := Label.new()
	class_tag.text = "[%s]" % String(class_disp.get("tag", "数值"))
	class_tag.add_theme_font_size_override("font_size", 10)
	class_tag.add_theme_color_override("font_color", Color.from_string(String(class_disp.get("color", "#8a94a6")), Color(0.54, 0.58, 0.65, 1)))
	class_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	class_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	class_tag.tooltip_text = "机制改造：改变单位行为规则，可与其他机制组合形成新战法" if class_disp.get("class", "ratio") == "mechanic" else "数值改造：提升属性交换比（更硬/更快/更疼）"
	name_row.add_child(class_tag)
	info.add_child(name_row)

	# 效果摘要（取第一条 effect）
	var effect_summary := _format_effects_for_display(mod_data)
	if not effect_summary.is_empty():
		var effect_lbl := Label.new()
		effect_lbl.text = effect_summary[0]
		effect_lbl.add_theme_font_override("font", DT.get_body_font())
		effect_lbl.add_theme_font_size_override("font_size", 12)
		effect_lbl.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH_SOFT if is_applicable else Color(0.5, 0.55, 0.65, 0.7))
		effect_lbl.clip_text = false
		effect_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(effect_lbl)
	hbox.add_child(info)

	# 状态标签（右侧）
	# v7.x 增强（对齐设计稿）：在原有"冲突/槽满/情报不足"阻断之外，补检战力档位门槛。
	# 高稀有度改造（epic/legendary）需 CHAMPION/OVERLORD 档位才可安装，不达标时显示
	# "✗需CHAMPION（当前ELITE）"，让玩家明确知道为何装不上（而非只看到"冲突"二字）。
	# 性能：用 _refresh_mod_list 顶部算好的 _cached_card_power/_cached_card_tier，
	# 不再每个 mod item 重复调用 estimate_power_score（会触发 "Too many warnings" 限流）。
	var status_col := DT.COLOR_CYAN_TECH_SOFT
	var status_text := "可安装"
	var tier_blocked: bool = false
	if is_installed:
		status_col = DT.COLOR_GREEN_UP
		status_text = "✓已装"
	elif not is_applicable:
		status_col = Color(0.5, 0.5, 0.55, 0.7)
		status_text = "⊘不适用"
	elif not block_reason.is_empty():
		status_col = DT.COLOR_RED_DOWN
		status_text = "✗" + block_reason
	elif _cached_card_power > 0 and PowerTiers != null and ModManager != null:
		# 战力档位门槛检查：epic 需 CHAMPION、legendary 需 OVERLORD
		if not ModManager.can_install_by_power_tier(_cached_card_tier, mod_id):
			var min_tier: int = ModManager.get_min_power_tier_for_mod(mod_id)
			tier_blocked = true
			status_col = DT.COLOR_AMBER
			status_text = "✗需%s" % PowerTiers.get_tier_name(min_tier)
	var status_label := Label.new()
	status_label.text = status_text
	status_label.add_theme_font_override("font", DT.get_title_font())
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", status_col)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(status_label)

	btn.add_child(hbox)
	# 禁用规则：已安装、不适用、被 block（冲突/槽满/情报不足）、或战力档位不足时禁用点击
	btn.disabled = is_installed or not is_applicable or not block_reason.is_empty() or tier_blocked
	btn.tooltip_text = "%s\n稀有度：%s" % [String(mod_data.get("description", "")), rarity_cn]
	btn.pressed.connect(func(): _on_mod_selected(mod_id, mod_data))
	return btn

## 判断改造是否适用于选中卡的兵种。
## v7.x：数据源切到 IntelItemBag 后，列表会显示所有已解锁改造（不限兵种），
## 此函数用于在 _create_mod_item 里给不适用的改造标灰"⊘该兵种不适用"。
## 复用 ModificationRegistry 的 get_mods_for_card（card_id 精筛）+ get_for_unit_type（combat_kind 兜底）。
func _is_mod_applicable_to_card(mod_id: String) -> bool:
	if not selected_card:
		return true  # 无选中卡时不拦截，统一显示为"可安装"
	if ModificationRegistry and ModificationRegistry.has_method("get_mods_for_card"):
		if mod_id in ModificationRegistry.get_mods_for_card(selected_card.card_id):
			return true
	if ModificationRegistry and ModificationRegistry.has_method("get_for_unit_type"):
		if mod_id in ModificationRegistry.get_for_unit_type(selected_card.combat_kind):
			return true
	return false

## v20.12 等级统一：战斗卡等级（card_level 1-30）查询——InstanceRegistry 按实例身份；
## 未成长按 Lv1（与 growth_panel._card_level_of 同口径）
func _card_level_of(card: CardResource) -> int:
	if card == null:
		return 1
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_card_level"):
		var identity: String = String(card.instance_id) if not String(card.instance_id).is_empty() else String(card.card_id)
		return clampi(maxi(int(ir.get_card_level(identity)), 1), 1, 30)
	return 1

## 获取改造安装的阻断原因（空串表示可安装）。
## v7.x：透传 can_install_modification 的 reason，让"✗冲突"细分为冲突/槽满/情报不足。
func _get_install_block_reason(mod_id: String) -> String:
	if not selected_card:
		return ""
	var check_result: Dictionary = selected_card.can_install_modification(mod_id)
	if check_result.get("can_install", true):
		return ""
	return String(check_result.get("reason", "冲突"))

## v1.4：刷新右栏单位面板（恒定显示，不随模块选中切换）
## 动态构建 6 个视觉区块：Hero头部 / PowerBlock战力块 / TierProgress5档条 / 基础属性6格 / 已装改造列表
func _update_card_info() -> void:
	if card_info_panel == null:
		return
	if not selected_card:
		# 未选单位时 DetailPanel 保持可见并显示占位提示（v7.x 界面一致性修复：
		# 原 visible=false 会让 300px 右栏折叠，导致改造站右侧大面积空白）。
		card_info_panel.visible = true
		_show_unit_panel_placeholder()
		return
	card_info_panel.visible = true

	# 清空 UnitPanel 旧内容（同步 free，避免容器撑高）
	if unit_panel:
		for child in unit_panel.get_children():
			unit_panel.remove_child(child)
			child.free()

	# === 数据准备 ===
	var tier_str := _get_card_tier_str(selected_card)
	var key: String = selected_card.instance_id if not selected_card.instance_id.is_empty() else selected_card.card_id
	var power_val: float = 0.0
	if BlueprintManager != null and not key.is_empty():
		power_val = EvolutionHelpers.estimate_power_score(key, BlueprintManager)
	var current_tier: int = PowerTiers.get_tier_by_power(power_val) if power_val > 0 else 0
	var stats: Dictionary = selected_card.get_modified_stats()
	var mod_count: int = selected_card.mods.size() if "mods" in selected_card else 0

	# === 区块1：Hero 头部（缩略图 + 名#号 + 标签行） ===
	unit_panel.add_child(_build_unit_hero())

	# === 区块2：战力评分大块（左侧标签 + 右侧大数字） ===
	unit_panel.add_child(_build_power_block(power_val, current_tier, tier_str))

	# === 区块3：5 档进度条 ===
	unit_panel.add_child(_build_tier_progress(current_tier))

	# === 区块4：区段标题「基础属性」 ===
	unit_panel.add_child(_make_section_header("◆ 基础属性", "满血状态"))

	# === 区块5：属性 6 格网格 ===
	unit_panel.add_child(_build_stat_grid(stats))

	# === 区块6：已装改造列表 ===
	unit_panel.add_child(_make_section_header("◆ 已装改造", "%d / 9" % mod_count))
	var installed_list := VBoxContainer.new()
	installed_list.name = "InstalledList"
	installed_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	installed_list.add_theme_constant_override("separation", 4)
	unit_panel.add_child(installed_list)
	_refresh_installed_list(installed_list)

	# === 资源栏更新 ===
	var nano_amount: int = 0
	var alloy_amount: int = 0
	if BasicResourceManager != null and "ID_NANO_MATERIALS" in BasicResources:
		nano_amount = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS)
	if BasicResourceManager != null and "ID_ALLOY" in BasicResources:
		alloy_amount = BasicResourceManager.get_total(BasicResources.ID_ALLOY)
	if research_label:
		research_label.text = "纳米 %s" % _format_int(nano_amount)
	if alloy_label:
		alloy_label.text = "合金 %s" % _format_int(alloy_amount)
	if status_line_label:
		status_line_label.text = "当前战力档  %s" % tier_str if not tier_str.is_empty() else ""

	# v1.4：选中新卡时重置底部操作台到空态
	_show_deck_empty()


## 未选单位时显示占位提示（v7.x 界面一致性修复：消除 DetailPanel 右侧空白）
func _show_unit_panel_placeholder() -> void:
	if unit_panel == null:
		return
	for child in unit_panel.get_children():
		unit_panel.remove_child(child)
		child.free()
	var ph := Label.new()
	ph.text = "← 选择左侧单位\n查看属性与已装改造"
	ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ph.add_theme_font_size_override("font_size", 14)
	ph.add_theme_color_override("font_color", Color(0.42, 0.48, 0.58, 0.7))
	unit_panel.add_child(ph)


## v1.4 字体统一辅助：给 Label 加载 Rajdhani 字体 + 设置字号/颜色/对齐/填充
## 设计稿核心视觉是 Rajdhani 窄体战术字体，默认字体会让视觉感大打折扣
func _style_lbl(lbl: Label, size: int, color: Color, align: int = -1, expand: bool = false, use_bold: bool = false) -> Label:
	lbl.add_theme_font_override("font", DT.get_title_font_bold() if use_bold else DT.get_title_font())
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	if align >= 0:
		lbl.horizontal_alignment = align
	if expand:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


## 构建单位 Hero 头部（缩略图 + 名#号 + 兵种/档位标签）
func _build_unit_hero() -> Control:
	var hero := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.024, 0.714, 0.831, 0.06)
	sb.border_color = Color(0.024, 0.714, 0.831, 0.2)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10; sb.content_margin_top = 10
	sb.content_margin_right = 10; sb.content_margin_bottom = 10
	hero.add_theme_stylebox_override("panel", sb)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	# 缩略图（兵种色边框 + 兵种字母）
	var art := PanelContainer.new()
	art.custom_minimum_size = Vector2(44, 44)
	var art_sb := StyleBoxFlat.new()
	art_sb.bg_color = Color(0.03, 0.06, 0.11, 1)
	art_sb.border_color = _get_kind_color(selected_card.combat_kind)
	art_sb.set_border_width_all(1)
	art_sb.set_corner_radius_all(4)
	art.add_theme_stylebox_override("panel", art_sb)
	var art_lbl := Label.new()
	art_lbl.text = _get_unit_icon(selected_card)
	art_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_lbl(art_lbl, 20, _get_kind_color(selected_card.combat_kind), HORIZONTAL_ALIGNMENT_CENTER)
	art.add_child(art_lbl)
	hbox.add_child(art)
	# 名 + 实例号 + 标签
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	var name_lbl := Label.new()
	var display_name: String = selected_card.display_name if selected_card.display_name else selected_card.card_id
	name_lbl.text = display_name
	var iid: String = str(selected_card.instance_id)
	if not iid.is_empty():
		var h_idx: int = iid.rfind("#")
		if h_idx >= 0:
			name_lbl.text += "  #" + iid.substr(h_idx + 1)
	name_lbl.clip_text = true
	_style_lbl(name_lbl, 16, Color(0.95, 0.96, 0.98, 1), -1, true, true)
	info.add_child(name_lbl)
	# 标签行：兵种 · Lv · 改造数（v20.12 等级统一：Lv=战斗卡等级 card_level）
	var tags := Label.new()
	tags.text = "%s · Lv.%d · 改造 %d/9" % [
		CardResource.get_combat_kind_name(selected_card.combat_kind),
		_card_level_of(selected_card),
		selected_card.mods.size()
	]
	tags.clip_text = true
	_style_lbl(tags, 11, Color(0.55, 0.6, 0.7, 0.85), -1, true)
	info.add_child(tags)
	hbox.add_child(info)
	hero.add_child(hbox)
	return hero


## 构建战力评分块（左侧标签+档位名 / 右侧大数字）
func _build_power_block(power_val: float, current_tier: int, tier_str: String) -> Control:
	var block := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.102, 0.165, 0.5)
	sb.border_color = Color(0.25, 0.35, 0.42, 0.18)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.border_color = DT.COLOR_CYAN_TECH_SOFT
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 10; sb.content_margin_top = 8
	sb.content_margin_right = 10; sb.content_margin_bottom = 8
	block.add_theme_stylebox_override("panel", sb)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	# 左侧：标签 + 档位名
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl1 := Label.new()
	lbl1.text = "战力评分"
	_style_lbl(lbl1, 10, Color(0.5, 0.55, 0.65, 0.85), -1, true)
	left.add_child(lbl1)
	var tier_name_cn := PowerTiers.get_tier_name(current_tier) if power_val > 0 else ""
	var lbl2 := Label.new()
	# v1.5：_get_card_tier_str 已返回中文档位名，此处直接显示，避免与 tier_name_cn 重复
	lbl2.text = tier_str if not tier_str.is_empty() else "—"
	lbl2.clip_text = true
	_style_lbl(lbl2, 12, DT.COLOR_CYAN_TECH_SOFT, -1, true, true)
	left.add_child(lbl2)
	hbox.add_child(left)
	# 右侧：战力大数字（26px Rajdhani Bold）
	var pwr_lbl := Label.new()
	pwr_lbl.text = str(int(power_val)) if power_val > 0 else "—"
	_style_lbl(pwr_lbl, 28, DT.COLOR_CYAN_TECH_SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
	pwr_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(pwr_lbl)
	block.add_child(hbox)
	return block


## 构建 5 档进度条（杂兵/老兵/精英/勇士/霸主）
func _build_tier_progress(current_tier: int) -> Control:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 3)
	# v1.5：档位名改读 PowerTiers.TIER_NAMES 单一源（原硬编码英文缩写数组，与中文 UI 风格不一致）
	var names := [
		PowerTiers.TIER_NAMES[PowerTiers.Tier.GRUNT],
		PowerTiers.TIER_NAMES[PowerTiers.Tier.VETERAN],
		PowerTiers.TIER_NAMES[PowerTiers.Tier.ELITE],
		PowerTiers.TIER_NAMES[PowerTiers.Tier.CHAMPION],
		PowerTiers.TIER_NAMES[PowerTiers.Tier.OVERLORD],
	] if PowerTiers != null else ["杂兵", "老兵", "精英", "勇士", "霸主"]
	# v1.5：阈值改读 PowerTiers.POWER_THRESHOLDS 单一源（原硬编码 [150,260,420,720]，改阈值会两处不同步）
	var thresholds: Array = PowerTiers.POWER_THRESHOLDS if PowerTiers != null else [150, 260, 420, 720]
	# 阈值标签对齐档位语义：GRUNT<首阈值（未达标）/ 后续档=达到该阈值进入该档
	# 与设计稿 GRUNT<150 / VETERAN 150+ / ELITE 260+ / CHAMP 420+ / OVER 720+ 一致
	var vals: Array = ["<" + str(int(thresholds[0]))]
	for i in range(thresholds.size() - 1):
		vals.append(str(int(thresholds[i])) + "+")
	vals.append(str(int(thresholds[thresholds.size() - 1])) + "+")  # 最后一档 "720+"
	for i in range(5):
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(2)
		sb.content_margin_left = 2; sb.content_margin_top = 3
		sb.content_margin_right = 2; sb.content_margin_bottom = 3
		if i < current_tier:
			sb.bg_color = Color(0.2, 0.9, 0.4, 0.04)
			sb.border_color = Color(0.2, 0.9, 0.4, 0.2)
		elif i == current_tier:
			sb.bg_color = Color(0.024, 0.714, 0.831, 0.12)
			sb.border_color = DT.COLOR_CYAN_TECH
		else:
			sb.bg_color = Color(0.03, 0.05, 0.10, 0.3)
			sb.border_color = Color(0.25, 0.35, 0.42, 0.18)
		cell.add_theme_stylebox_override("panel", sb)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 0)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		var n_lbl := Label.new()
		n_lbl.text = names[i]
		_style_lbl(n_lbl, 10, DT.COLOR_CYAN_TECH_SOFT if i == current_tier else (Color(0.6,0.65,0.75,0.8) if i < current_tier else Color(0.4,0.45,0.55,0.5)), HORIZONTAL_ALIGNMENT_CENTER, true, true)
		vbox.add_child(n_lbl)
		var v_lbl := Label.new()
		v_lbl.text = vals[i]
		_style_lbl(v_lbl, 9, Color(0.5, 0.55, 0.65, 0.6), HORIZONTAL_ALIGNMENT_CENTER, true)
		vbox.add_child(v_lbl)
		cell.add_child(vbox)
		grid.add_child(cell)
	return grid


## 区段标题（左标题 + 右附注）
func _make_section_header(title: String, extra: String) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	var t_lbl := Label.new()
	t_lbl.text = title
	_style_lbl(t_lbl, 12, Color(0.7, 0.75, 0.85, 0.9), -1, false, true)
	hbox.add_child(t_lbl)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	if not extra.is_empty():
		var e_lbl := Label.new()
		e_lbl.text = extra
		_style_lbl(e_lbl, 11, DT.COLOR_CYAN_TECH_SOFT, -1, false, true)
		hbox.add_child(e_lbl)
	return hbox


## 构建 6 格属性网格（HP/轻攻/甲攻/空攻/装甲防/部署档）
## v7.x 修复：原"移动速度"读 stats.move_speed（像素值，如 80/120/150），该字段是死属性
## （单位走格子战术，实际机动由 deploy_speed 0-7 档决定）。改为显示 deploy_speed 档位
## 更符合玩家直觉——数值 0-7 直观反映部署快慢（0=瞬间, 7=极快）。
func _build_stat_grid(stats: Dictionary) -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	var entries := [
		["生命值", "max_hp", true],
		["轻装攻击", "attack_light", false],
		["装甲攻击", "attack_armor", false],
		["对空攻击", "attack_air", false],
		["装甲防御", "defense_armor", false],
		["部署档", "deploy_speed", false],
	]
	for entry in entries:
		var key_name: String = entry[1]
		var val_raw = stats.get(key_name, 0)
		var val_int := int(val_raw) if val_raw != null else 0
		grid.add_child(_make_stat_cell(entry[0], val_int, entry[2]))
	return grid


## 单个属性格
func _make_stat_cell(label_text: String, value: int, is_hp: bool) -> Control:
	var cell := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.102, 0.165, 0.5)
	sb.border_color = Color(0.25, 0.35, 0.42, 0.18)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6; sb.content_margin_top = 5
	sb.content_margin_right = 6; sb.content_margin_bottom = 5
	cell.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	var lbl := Label.new()
	lbl.text = label_text
	_style_lbl(lbl, 10, Color(0.5, 0.55, 0.65, 0.85), HORIZONTAL_ALIGNMENT_CENTER, true)
	vbox.add_child(lbl)
	var val_lbl := Label.new()
	val_lbl.text = str(value)
	_style_lbl(val_lbl, 18, DT.COLOR_GREEN_UP if is_hp else Color(0.95, 0.96, 0.98, 1), HORIZONTAL_ALIGNMENT_CENTER, true, true)
	vbox.add_child(val_lbl)
	cell.add_child(vbox)
	return cell


## v1.4：显示底部操作台空态（未选模块时）
## v1.5：同时收起效果模拟抽屉
func _show_deck_empty() -> void:
	if action_deck:
		action_deck.visible = false
	if deck_empty:
		deck_empty.visible = true
	_close_sim_drawer()


## v1.5：效果模拟抽屉切换按钮回调
func _on_sim_button_pressed() -> void:
	if sim_drawer == null:
		return
	var will_open: bool = not sim_drawer.visible
	if will_open:
		_open_sim_drawer()
	else:
		_close_sim_drawer()


## v1.5：打开效果模拟抽屉——填充当前选中模块的完整 effect 列表 + 同类对比 + 战力预估
func _open_sim_drawer() -> void:
	if sim_drawer == null or selected_mod_id.is_empty():
		return
	var mod_data: Dictionary = ModificationRegistry.get_data(selected_mod_id) if ModificationRegistry != null else {}
	if mod_data.is_empty():
		return
	# 清空旧内容
	for child in sim_drawer.get_children():
		sim_drawer.remove_child(child)
		child.free()
	# 抽屉底色 + 内边距
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.12, 0.6)
	sb.border_width_top = 1
	sb.border_color = Color(0.024, 0.714, 0.831, 0.25)
	sb.content_margin_left = 12
	sb.content_margin_top = 8
	sb.content_margin_right = 12
	sb.content_margin_bottom = 8
	sim_drawer.add_theme_stylebox_override("panel", sb)
	# 三栏内容
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 栏1：完整效果列表（复用 _format_effects_for_display：兼容 effects/level_effects/grant_slot，
	# 修复吸血等 level_effects 机制改造原显示"（无效果数据）"的 bug）
	var col1 := VBoxContainer.new()
	col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1.add_theme_constant_override("separation", 2)
	col1.add_child(_make_sim_section_label("◆ 完整效果"))
	var effect_lines: PackedStringArray = _format_effects_for_display(mod_data)
	if effect_lines.is_empty():
		col1.add_child(_make_sim_kv("（无效果数据）", "", Color(0.5, 0.55, 0.65, 0.6)))
	else:
		for line in effect_lines:
			# 段头（"—— Lv.3（满级）——"）/ 布尔解锁（"✓ xxx"）走标题样式；数值行拆"标签 值"
			if line.begins_with("——") or line.begins_with("✓"):
				col1.add_child(_make_sim_section_label(line))
			else:
				var sp: int = line.find(" ")
				if sp > 0:
					col1.add_child(_make_sim_kv(line.substr(0, sp), line.substr(sp + 1), DT.COLOR_GREEN_UP))
				else:
					col1.add_child(_make_sim_kv(line, "", Color(0.9, 0.92, 0.96, 1)))
	hbox.add_child(col1)
	# 栏2：同类已装对比（当前已装该冲突组的模块数 + 战力前后）
	var col2 := VBoxContainer.new()
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2.add_theme_constant_override("separation", 2)
	col2.add_child(_make_sim_section_label("◆ 战力预估"))
	var before_power: float = _cached_card_power
	# v1.5 修复：原 after = before × power_mult 严重虚高（power_mult 是稀有度/成本权重，非战力增益倍率，
	# 1.35 会对 3000 战力卡显示 +1050）。改为克隆实例卡 + 追加候选改造，走与真实安装完全相同的
	# build_stats→combat_power 路径，预览值与右栏/intel 面板实际安装后显示的战力一致。
	var after_power: float = EvolutionHelpers.estimate_power_with_extra_mod(selected_card, selected_mod_id, BlueprintManager) if (selected_card != null and BlueprintManager != null) else before_power
	col2.add_child(_make_sim_kv("当前战力", str(int(before_power)) if before_power > 0 else "—", Color(0.55, 0.6, 0.7, 0.8)))
	col2.add_child(_make_sim_kv("装上后", str(int(after_power)), DT.COLOR_GREEN_UP))
	var delta: int = int(after_power - before_power)
	col2.add_child(_make_sim_kv("变化", ("+" if delta >= 0 else "") + str(delta), DT.COLOR_GREEN_UP if delta >= 0 else DT.COLOR_RED_DOWN))
	# 槽位占用
	var mod_count: int = selected_card.mods.size() if (selected_card and "mods" in selected_card) else 0
	col2.add_child(_make_sim_kv("槽位", "%d/9 → %d/9" % [mod_count, mod_count + 1], DT.COLOR_CYAN_TECH_SOFT))
	hbox.add_child(col2)
	sim_drawer.add_child(hbox)
	sim_drawer.visible = true
	if deck_sim_button:
		deck_sim_button.text = "效果模拟 ↑"
		deck_sim_button.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH_SOFT)


## v1.5：关闭效果模拟抽屉
func _close_sim_drawer() -> void:
	if sim_drawer != null:
		sim_drawer.visible = false
	if deck_sim_button:
		deck_sim_button.text = "效果模拟 ↓"
		deck_sim_button.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.8))


## v1.5：抽屉小区块标题
func _make_sim_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", DT.get_title_font_bold())
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.9))
	return lbl


## v1.5：抽屉 key-value 行（左标签右值）
func _make_sim_kv(key: String, val: String, val_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var kl := Label.new()
	kl.text = key
	kl.add_theme_font_size_override("font_size", 12)
	kl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 0.85))
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(kl)
	var vl := Label.new()
	vl.text = val
	vl.add_theme_font_override("font", DT.get_title_font_bold())
	vl.add_theme_font_size_override("font_size", 12)
	vl.add_theme_color_override("font_color", val_color)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(vl)
	return row


## v1.5：effect 值格式化——委托 _format_effect_number（与列表行同口径，eff_key 仅用于签名兼容）
func _format_effect_value(eff_key: String, eff_val) -> String:
	return _format_effect_number(eff_val)


## v7.x 辅助：整数千分位格式化
func _format_int(n: int) -> String:
	var s := str(n)
	var out := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		if cnt > 0 and cnt % 3 == 0:
			out = "," + out
		out = s[i] + out
		cnt += 1
	return out


## v7.x 辅助：取卡牌战力档位名（基于 EvolutionHelpers 估算）
## v1.5：阈值判定改调 PowerTiers.get_tier_by_power（原硬编码 [150,260,420,720] if 链，
## 改阈值会两处不同步）。返回中文档位名，与 UI 整体风格统一。
func _get_card_tier_str(card: CardResource) -> String:
	if card == null or BlueprintManager == null:
		return ""
	var key: String = card.instance_id if not card.instance_id.is_empty() else card.card_id
	if key.is_empty():
		return ""
	var power := EvolutionHelpers.estimate_power_score(key, BlueprintManager)
	if power <= 0:
		return ""
	# 中文档位名（直接读 PowerTiers.get_tier_name，单一数据源）
	if PowerTiers != null:
		return PowerTiers.get_tier_name(PowerTiers.get_tier_by_power(power))
	# PowerTiers 不可用时回退硬编码（防御性）
	if power < 150: return "杂兵"
	if power < 260: return "老兵"
	if power < 420: return "精英"
	if power < 720: return "勇士"
	return "霸主"

func _refresh_installed_list(installed_list: Control) -> void:
	# 同步移除（remove_child + free），不要用 queue_free：InstalledList 不在 ScrollContainer 内
	# （它是 DetailPanel→CardView 下的 VBox），而整个面板挂在 CenterContainer 下。
	# queue_free 延迟删除会让旧行与新行同帧共存，DetailPanel 的 combined_minimum_size 暂时膨胀，
	# CenterContainer 据此把面板撑高且永不回缩（切换到已装改造数量不同的卡时面板变长）。
	for child in installed_list.get_children():
		installed_list.remove_child(child)
		child.free()

	var mod_index := 0
	for mod_entry in selected_card.mods:
		var mod_id = mod_entry.get("id", "") if mod_entry is Dictionary else ""
		var mod_data = ModificationRegistry.get_data(mod_id)
		var rarity: String = String(mod_data.get("rarity", "common"))
		var slot_type: String = String(mod_data.get("slot_type", ""))
		var is_weapon_mod: bool = (slot_type == "weapon" or slot_type == "gun" or slot_type == "ammunition")
		# v6.5: 获取启用状态（武器类改造可切换）
		var enabled: bool = true
		if mod_entry is Dictionary and mod_entry.has("enabled"):
			enabled = bool(mod_entry["enabled"])

		var item := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.12, 0.2, 0.5) if enabled else Color(0.08, 0.08, 0.1, 0.5)
		sb.border_width_left = 2
		sb.border_color = _rarity_color(rarity) if enabled else (_rarity_color(rarity) * Color(1, 1, 1, 0.4))
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 8
		sb.content_margin_top = 3
		sb.content_margin_right = 8
		sb.content_margin_bottom = 3
		item.add_theme_stylebox_override("panel", sb)

		# v6.10: 改造列表每项用 VBox——第一行名字+图标+切换，第二行完整效果
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)

		# 已安装改造图标
		var icon_path: String = mod_data.get("icon", "")
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			var tex_rect := TextureRect.new()
			tex_rect.texture = UiAssetLoader.load_tex(icon_path)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.custom_minimum_size = Vector2(20, 20)
			tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(tex_rect)
		else:
			# v1.5：无图标兜底——稀有度色边框 + 首字母（与改造库 mod-ico 一致，原 v1.4 直接省略不统一）
			var rar_col := _rarity_color(rarity)
			var ph := PanelContainer.new()
			ph.custom_minimum_size = Vector2(20, 20)
			ph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var ph_sb := StyleBoxFlat.new()
			ph_sb.bg_color = Color(0.05, 0.09, 0.16, 0.6)
			ph_sb.border_color = rar_col if enabled else (rar_col * Color(1, 1, 1, 0.4))
			ph_sb.set_border_width_all(1)
			ph_sb.set_corner_radius_all(3)
			ph.add_theme_stylebox_override("panel", ph_sb)
			var rar_letter := rarity.substr(0, 1).to_upper() if not rarity.is_empty() else "?"
			var ph_lbl := Label.new()
			ph_lbl.text = rar_letter
			ph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ph_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ph_lbl.add_theme_font_override("font", DT.get_title_font_bold())
			ph_lbl.add_theme_font_size_override("font_size", 12)
			ph_lbl.add_theme_color_override("font_color", rar_col if enabled else (rar_col * Color(1, 1, 1, 0.4)))
			ph_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ph.add_child(ph_lbl)
			hbox.add_child(ph)

		var lbl := Label.new()
		var status_prefix: String = "✓ " if enabled else "⊘ "
		lbl.text = status_prefix + String(mod_data.get("name", mod_id))
		lbl.add_theme_font_size_override("font_size", 13)
		if enabled:
			lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95, 1))
		else:
			lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 0.7))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)

		# v6.5: 武器类改造显示启用/禁用切换按钮
		if is_weapon_mod:
			var toggle_btn := Button.new()
			toggle_btn.text = "启用" if not enabled else "禁用"
			toggle_btn.add_theme_font_size_override("font_size", 12)
			toggle_btn.custom_minimum_size = Vector2(54, 0)
			# 绑定切换回调（用 lambda 捕获 mod_index）
			var captured_index := mod_index
			toggle_btn.pressed.connect(func():
				_on_weapon_mod_toggled(captured_index, not enabled)
			)
			hbox.add_child(toggle_btn)

		# v1.5：对所有已装项追加"替换"按钮（卸载 API 未实装，语义对齐 replace_modification）
		# 点击后收起右栏详情、引导玩家从改造库选新模块；新模块若同冲突组会触发替换。
		var replace_btn := Button.new()
		replace_btn.text = "替换"
		replace_btn.add_theme_font_size_override("font_size", 10)
		replace_btn.custom_minimum_size = Vector2(44, 0)
		replace_btn.tooltip_text = "替换为同槽位新模块（从改造库另选一个）。注意：原改造的安装消耗不返还。"
		replace_btn.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.7))
		replace_btn.add_theme_color_override("font_hover_color", DT.COLOR_AMBER)
		replace_btn.pressed.connect(func():
			# 引导玩家去改造库选新模块（选中后若同冲突组，install_modification 内部走 replace）
			_show_deck_empty()
			_show_result("从左侧改造库选择新模块以替换「%s」（原消耗不返还）" % String(mod_data.get("name", mod_id)))
		)
		hbox.add_child(replace_btn)

		vbox.add_child(hbox)

		# v6.10: 第二行——显示完整改造效果（复用已修好的 _format_effects_for_display）
		# 让玩家一眼看到"装了什么、加什么"，而不只是改造名字
		var effect_lines := _format_effects_for_display(mod_data)
		if not effect_lines.is_empty():
			var effect_lbl := Label.new()
			effect_lbl.text = " · ".join(effect_lines)
			effect_lbl.add_theme_font_size_override("font_size", 12)
			if enabled:
				effect_lbl.add_theme_color_override("font_color", Color(0.65, 0.78, 0.62, 0.95))
			else:
				effect_lbl.add_theme_color_override("font_color", Color(0.45, 0.5, 0.45, 0.6))
			effect_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vbox.add_child(effect_lbl)

		item.add_child(vbox)
		installed_list.add_child(item)
		mod_index += 1


## v6.5: 武器类改造启用/禁用切换
func _on_weapon_mod_toggled(mod_index: int, enable: bool) -> void:
	if selected_card == null:
		return
	if BlueprintManager and BlueprintManager.has_method("set_mod_enabled"):
		# v7.0: 用 instance_id 操作（实例化养成）；无 instance_id 回退 card_id
		var ok: bool = BlueprintManager.set_mod_enabled(_selected_id(), mod_index, enable)
		if ok:
			# 刷新已安装列表 + 单位面板属性（改造变化会影响属性）
			# v1.4：InstalledList 现在是动态创建在 unit_panel 下，按名字查找
			var installed_list = unit_panel.get_node_or_null("InstalledList") if unit_panel else null
			if installed_list:
				_refresh_installed_list(installed_list)
			_update_card_info()


## v7.0: 取当前选中卡的身份标识（优先 instance_id，回退 card_id）
func _selected_id() -> String:
	if selected_card == null:
		return ""
	return selected_card.instance_id if not selected_card.instance_id.is_empty() else selected_card.card_id


## ─────────────────────────────────────────────
## 改造操作
## ─────────────────────────────────────────────

func _is_mod_installed(mod_id: String) -> bool:
	if not selected_card:
		return false
	# 优先从 BlueprintManager 的持久存储读取（比 card.mods 更可靠）
	# v7.0: 用 instance_id 查（blueprint_mods key 已改 instance_id）
	var sid: String = _selected_id()
	if BlueprintManager and BlueprintManager.blueprint_mods.has(sid):
		var saved_mods = BlueprintManager.blueprint_mods[sid] as Array
		if saved_mods:
			for entry in saved_mods:
				var eid = entry.get("id", "") if entry is Dictionary else ""
				if eid == mod_id:
					return true
	# 回退到 card.mods（实例对象）
	for mod_entry in selected_card.mods:
		var entry_id = mod_entry.get("id", "") if mod_entry is Dictionary else ""
		if entry_id == mod_id:
			return true
	return false

func _can_install_mod(mod_id: String) -> bool:
	if not selected_card:
		return false

	var check_result = selected_card.can_install_modification(mod_id)
	return check_result.can_install

func _install_modification(mod_id: String) -> void:
	if not selected_card:
		return
	# v7.3: 双重保险——改造必须写到实例对象。无 instance_id 的卡是模板/残留，
	# install_modification 会把改造写到模板污染单例。在此拦截，与 _on_card_selected 的守卫呼应。
	if selected_card.instance_id.is_empty():
		push_warning("[modification_panel] _install_modification: 选中卡 '%s' 无 instance_id，拒绝安装（避免污染模板）" % selected_card.card_id)
		_show_result("该卡牌实例不可用，无法改造")
		return

	var result = BlueprintManager.install_modification(selected_card, mod_id)

	if result.success:
		_show_result("改造安装成功：%s" % result.message)
		selected_mod_id = ""  # v1.5 修复：清空选中，避免安装后 SPACE/ENTER 重复触发
		_refresh_mod_list()
		_update_card_info()
	else:
		_show_result("安装失败：%s" % result.message)

## ─────────────────────────────────────────────
##  事件处理
## ─────────────────────────────────────────────

func _on_card_selected(card: CardResource) -> void:
	# v7.x 修复：原版收到 instance_id 为空的卡（模板/残留）直接 return 并报错，
	# 导致独立改造面板点击"无实例但列表里显示的卡"时毫无反应。
	# 列表项绑定的 instance_card（_create_card_item:227）在 Registry 缺失该实例
	# （但 SaveManager 兜底队列里有）时为 null → 回退到模板 → 被原守卫拦死。
	# 现复用 _resolve_instance_or_warn 回退查同名实例；仍查不到才真的拒绝。
	var resolved_card: CardResource = _resolve_instance_or_warn(card)
	if resolved_card == null:
		_show_result("该卡牌实例不可用，无法改造（请重新获取该卡）")
		return
	selected_card = resolved_card
	selected_mod_id = ""
	_refresh_mod_list()
	_update_card_info()

func _on_mod_selected(mod_id: String, mod_data: Dictionary) -> void:
	selected_mod_id = mod_id
	# 显示改造详情
	_show_mod_details(mod_data)

## v1.4：刷新底部操作台（选中模块时显示核心属性+要求+安装按钮）
## 替代原 _show_mod_details 的右栏切换逻辑，详情沉到中栏底部
func _show_mod_details(mod_data: Dictionary) -> void:
	# 显示操作台，隐藏空态
	if action_deck:
		action_deck.visible = true
	if deck_empty:
		deck_empty.visible = false

	# 操作台图标：按稀有度着色边框（视觉化区分模块品质）
	var mod_rarity := String(mod_data.get("rarity", "common"))
	var rarity_col := _rarity_color(mod_rarity)
	var deck_icon := get_node_or_null("%DeckIcon")
	if deck_icon and deck_icon is PanelContainer:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.06)
		sb.border_color = rarity_col
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		deck_icon.add_theme_stylebox_override("panel", sb)
		# 图标内字母用 Rajdhani
		var icon_inner := deck_icon.get_node_or_null("DeckIconLabel")
		if icon_inner is Label:
			icon_inner.add_theme_font_override("font", DT.get_title_font_bold())
			icon_inner.add_theme_color_override("font_color", rarity_col)

	# 操作台三个 Label 统一加载 Rajdhani 字体（设计稿核心视觉）
	if deck_name_label:
		deck_name_label.add_theme_font_override("font", DT.get_title_font_bold())
	if deck_core_label:
		deck_core_label.add_theme_font_override("font", DT.get_title_font())
	if deck_req_label:
		deck_req_label.add_theme_font_override("font", DT.get_body_font())
	if deck_install_button:
		deck_install_button.add_theme_font_override("font", DT.get_title_font_bold())

	# 模块名 + 稀有度（mod_rarity 已在上方 DeckIcon 段声明）
	if deck_name_label:
		var rarity_names := {"common": "普通", "uncommon": "优秀", "rare": "稀有", "epic": "史诗", "legendary": "传说", "mythic": "神话"}
		var slot_type: String = String(mod_data.get("slot_type", ""))
		var meta_parts: Array = []
		if not slot_type.is_empty():
			meta_parts.append(_translate_slot_type(slot_type))
		meta_parts.append(rarity_names.get(mod_rarity, mod_rarity))
		deck_name_label.text = "%s  [%s]" % [mod_data.get("name", ""), " · ".join(meta_parts)]

	# 核心属性（取改造效果首行 + 属性预览）
	if deck_core_label:
		var effect_texts := _format_effects_for_display(mod_data)
		# 过滤段头（"—— Lv.N（满级）——"），它属于抽屉的分组标题，拼进单行核心摘要会丑
		var core_lines: Array = []
		for ln in effect_texts:
			if not ln.begins_with("——"):
				core_lines.append(ln)
		if not core_lines.is_empty():
			deck_core_label.text = " · ".join(core_lines)
		else:
			deck_core_label.text = String(mod_data.get("description", ""))

	# 要求行：解锁条件 + 纳米 + 图纸（单行紧凑）
	if deck_req_label:
		var req_parts: Array = []
		# 解锁条件
		var unlock = mod_data.get("unlock_conditions", {})
		if unlock is Dictionary and unlock.has("required_level"):
			req_parts.append("强化≥%d" % int(unlock["required_level"]))
		# 纳米成本
		var base_power: float = BlueprintManager.get_base_power_for_mod_cost(selected_card.card_id) if selected_card else 100.0
		var nano_cost = int(base_power * 0.5)
		req_parts.append("纳米%d" % nano_cost)
		# 图纸
		var blueprint_id = BlueprintDefinitions.get_mod_blueprint_id(selected_mod_id)
		var has_blueprint = false
		var _iib = Engine.get_main_loop().get_root().get_node_or_null("IntelItemBag")
		if _iib:
			has_blueprint = _iib.has_item(blueprint_id)
		req_parts.append("图纸" + ("✓" if has_blueprint else "✗"))
		deck_req_label.text = " · ".join(req_parts)

	# 安装按钮状态 + 重连
	if deck_install_button:
		var base_power2: float = BlueprintManager.get_base_power_for_mod_cost(selected_card.card_id) if selected_card else 100.0
		var nano_cost2 = int(base_power2 * 0.5)
		var has_blueprint2 = false
		var _iib2 = Engine.get_main_loop().get_root().get_node_or_null("IntelItemBag")
		if _iib2:
			has_blueprint2 = _iib2.has_item(BlueprintDefinitions.get_mod_blueprint_id(selected_mod_id))
		var nano_amount = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS) if BasicResourceManager else 0
		var has_nano = nano_amount >= nano_cost2
		var is_installed = _is_mod_installed(selected_mod_id)

		if is_installed:
			deck_install_button.text = "已安装"
			deck_install_button.disabled = true
			deck_install_button.tooltip_text = "该模块已安装在当前这张卡上"
		elif not has_blueprint2:
			deck_install_button.text = "缺图纸"
			deck_install_button.disabled = true
			# 批次三 B2d：禁用按钮就地说明缺什么、去哪拿
			deck_install_button.tooltip_text = "缺少【%s】——改造图纸可通过战斗掉落与情报道具获得" % BlueprintDefinitions.get_mod_blueprint_name(selected_mod_id)
		elif not has_nano:
			deck_install_button.text = "纳米不足"
			deck_install_button.disabled = true
			deck_install_button.tooltip_text = "需要 %d 纳米材料（当前 %d）" % [nano_cost2, nano_amount]
		else:
			deck_install_button.text = "安装"
			deck_install_button.disabled = false
			deck_install_button.tooltip_text = "消耗 %d 纳米材料安装到当前选中的这张卡（只影响该实例）" % nano_cost2

		# v5.0: 信号重连（先断开所有旧 callable，再绑定新的）
		var connections: Array = deck_install_button.pressed.get_connections()
		for conn in connections:
			if conn.callable.is_valid():
				deck_install_button.pressed.disconnect(conn.callable)
		var install_callable = func(): _install_modification(selected_mod_id)
		deck_install_button.pressed.connect(install_callable)

	# v1.5：选中模块即展开效果抽屉——完整效果直接可见，无需按"效果模拟"
	if sim_drawer != null:
		_open_sim_drawer()

## 槽位类型翻译
func _translate_slot_type(raw: String) -> String:
	var maps: Dictionary = {
		"weapon": "武器",
		"weapons": "武器",
		"armor": "装甲",
		"gun": "火炮",
		"ammunition": "弹药",
		"active": "主动",
		"aerodynamics": "气动",
		"autoloader": "自动装填",
		"automation": "自动化",
		"barrel": "枪管",
		"bridge": "舰桥",
		"command": "指挥",
		"comms": "通信",
		"countermeasure": "对抗",
		"deception": "欺骗",
		"demolition": "爆破",
		"designator": "指示",
		"digging": "挖掘",
		"drone": "无人机",
		"ecm": "电子对抗",
		"electronics": "电子",
		"engine": "引擎",
		"engineering": "工程",
		"enhancement": "强化",
		"environment": "环境",
		"ergonomics": "人体工学",
		"exoskeleton": "外骨骼",
		"fire_control": "火控",
		"fortification": "筑城",
		"fuze": "引信",
		"guidance": "制导",
		"helmet": "头盔",
		"laser": "激光",
		"logistics": "后勤",
		"medical": "医疗",
		"minefield": "布雷",
		"missile": "导弹",
		"mobility": "机动",
		"mount": "炮塔",
		"navigation": "导航",
		"network": "网络",
		"obstacle": "障碍",
		"optics": "光学",
		"power": "动力",
		"protection": "防护",
		"radar": "雷达",
		"recon": "侦察",
		"recovery": "抢修",
		"repair": "维修",
		"shield": "盾牌",
		"stealth": "隐身",
		"survival": "生存",
		"system": "系统",
		"thrust": "推力",
	}
	return maps.get(raw, raw)

## 效果键翻译（薄封装，委托 ModEffectLabels 共享表）。
## v7.x 统一：情报/改造/强化三面板共用 ModEffectLabels.translate（简短词口径），
## 消除原先与 card_info_panel 的"完整词 vs 简短词"分叉。
func _translate_effect_key(key: String) -> String:
	return ModEffectLabels.translate(key)


## v7.2: 格式化改造效果为展示文本（兼容 effects 单档 + level_effects 多档）
## 返回行数组（供 effects_label 展示）
func _format_effects_for_display(mod_data: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	# 优先 effects（单档），其次 level_effects（Lv1/2/3 多档，enhancement 词条用）
	if mod_data.has("effects") and (mod_data["effects"] as Dictionary).size() > 0:
		var eff: Dictionary = mod_data["effects"]
		for key in eff.keys():
			lines.append(_format_one_effect(String(key), eff[key]))
	elif mod_data.has("level_effects") and (mod_data["level_effects"] as Dictionary).size() > 0:
		var le: Dictionary = mod_data["level_effects"]
		# level_effects = {1: {...}, 2: {...}, 3: {...}}，取最高档展示（max_level 对应满级数值）
		var sorted_levels = le.keys()
		sorted_levels.sort()
		var top_level = sorted_levels[sorted_levels.size() - 1]
		var top_eff: Dictionary = le[top_level]
		lines.append("—— Lv.%d（满级）——" % int(top_level))
		for key in top_eff.keys():
			lines.append(_format_one_effect(String(key), top_eff[key]))
	# v6.13: grant_slot 赋予新攻击维度（如炮射导弹激活对空槽）
	if mod_data.has("grant_slot") and (mod_data["grant_slot"] as Dictionary).size() > 0:
		lines.append(_format_grant_slot(mod_data["grant_slot"]))
	return lines


## v7.2: 格式化单条效果（key + value）为一行文本
## 数值格式统一走 _format_effect_number（与效果模拟抽屉同口径）
func _format_one_effect(key: String, val) -> String:
	var key_display = _translate_effect_key(key)
	if val is bool and val:
		return "✓ %s" % key_display
	return "%s %s" % [key_display, _format_effect_number(val)]


## v1.5：统一的改造效果数值格式化（列表行 / 效果模拟抽屉共用，消除 +150% vs ×1.50 分叉）
## 规则：|v|<=1 的非零小数 → 百分比（+30% / -20%）；v>1 → 倍率（×1.50）；int → 整数加成（+5 / -3）
func _format_effect_number(val) -> String:
	if val is bool:
		return "✓" if val else ""
	if val is float:
		if val == 0.0:
			return "0"
		if absf(val) <= 1.0 or val < -1.0:
			return "%+.0f%%" % (val * 100.0)
		return "×%.2f" % val
	if val is int:
		return "%+d" % val if val >= 0 else str(val)
	return str(val)


## v6.13: 格式化 grant_slot（赋予新攻击维度）为一行展示文本
## v7.x: 复用 ModEffectLabels.format_grant_slot，与情报面板 grant 文案完全一致。
## grant = {slot, base_damage, damage_ratio, speed, weapon_type, display_name, ...}
func _format_grant_slot(grant: Dictionary) -> String:
	return ModEffectLabels.format_grant_slot(grant)


## 解析卡牌为实例：instance_id 非空直接用；为空（模板/残留）则回退查 Registry 同名实例。
## 返回 null 表示确实无可用实例（此时调用方 return）。
## v7.x 修复：原 set_selected_card/_on_card_selected 收到 instance_id 为空的卡直接 return，
## 导致改造 Tab 永远空。但背包 backpack_data 在 Registry 缺失某实例时会回退到 DefaultCards 模板
## （instance_id 空），而该 card_id 的实例可能其实存在于 Registry（只是引用对不上）——
## 改造数据挂在实例上，不回退就永远读不到。此处复用战场 _resolve_source_instance_card 的回退链模式。
func _resolve_instance_or_warn(card: CardResource) -> CardResource:
	if card == null:
		return null
	if not card.instance_id.is_empty():
		return card
	# instance_id 为空（模板/残留）→ 按 card_id 查首个同名实例
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_instances_by_card_id") and not card.card_id.is_empty():
		var insts: Array = ir.get_instances_by_card_id(card.card_id)
		if not insts.is_empty() and ir.has_method("get_instance"):
			var fb: CardResource = ir.get_instance(String(insts[0]))
			if fb != null:
				push_warning("[modification_panel] 卡 '%s' 无 instance_id，已回退到同名实例 '%s'" % [card.card_id, fb.instance_id])
				return fb
	push_warning("[modification_panel] 卡 '%s' 无 instance_id 且 Registry 无同名实例，拒绝选中" % card.card_id)
	return null

## 供外部调用的接口
func set_selected_card(card: CardResource) -> void:
	# v7.x 修复：原版收到 instance_id 为空的卡直接 return，导致嵌入模式（背包→情报面板改造 Tab）
	# 改造 Tab 永远空。现回退查同名实例（Registry 缺失某实例但 backpack_data 回退到模板的场景）。
	var resolved_card: CardResource = _resolve_instance_or_warn(card)
	if resolved_card == null:
		_show_result("该卡牌实例不可用，无法改造（请重新获取该卡）")
		return
	selected_card = resolved_card
	selected_mod_id = ""
	# v7.x 修复（Bug2）：非嵌入模式下进入面板时补刷卡片列表。
	# 根因：面板被 ui_lazy_loader 缓存（整个会话只实例化一次），_refresh_card_list 只在首帧 _ready 跑一次。
	# 从 growth_panel 跳转进来走 set_selected_card（而非 show_panel），原版不刷列表，导致卡片列表永远停留在首帧快照。
	# 嵌入模式（card_info_panel 内嵌）下卡片列表本就被 _apply_embedded_layout 隐藏，无需刷新。
	if not _embedded_mode and card_list_container != null:
		_refresh_card_list()
	if card_info_panel != null:
		_update_card_info()
	if mod_list_container != null:
		_refresh_mod_list()

func show_panel() -> void:
	visible = true
	_refresh_card_list()

## v1.5：键盘导航（面板获焦时触发，嵌入模式不会全局拦截宿主输入）
## ↑↓：改造库行间移动选中；SPACE/ENTER：安装当前选中模块；ESC：逐级退出
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_UP, KEY_DOWN:
			if _navigate_mod_list(event.keycode == KEY_DOWN):
				get_viewport().set_input_as_handled()
		KEY_SPACE, KEY_ENTER:
			if not selected_mod_id.is_empty():
				_install_modification(selected_mod_id)
				get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if _handle_escape():
				get_viewport().set_input_as_handled()


## v1.5：改造库 ↑↓ 导航，返回是否消费了按键
func _navigate_mod_list(go_down: bool) -> bool:
	if mod_list_container == null:
		return false
	var rows: Array = []
	var indices: Array = []
	for i in range(mod_list_container.get_child_count()):
		var child = mod_list_container.get_child(i)
		if child is Button and child.has_meta("mod_id"):
			rows.append(child)
			indices.append(i)
	if rows.is_empty():
		return false
	# 找当前选中行位置
	var cur_idx: int = -1
	for i in range(rows.size()):
		if str(rows[i].get_meta("mod_id")) == selected_mod_id:
			cur_idx = i
			break
	var next_idx: int
	if cur_idx < 0:
		next_idx = 0
	else:
		next_idx = cur_idx + (1 if go_down else -1)
		next_idx = clampi(next_idx, 0, rows.size() - 1)
	if next_idx == cur_idx:
		return false  # 已到头/尾
	var mod_id: String = str(rows[next_idx].get_meta("mod_id"))
	var mod_data: Dictionary = ModificationRegistry.get_data(mod_id) if ModificationRegistry != null else {}
	if mod_data.is_empty():
		return false
	_on_mod_selected(mod_id, mod_data)
	return true


## v1.5：ESC 逐级退出（抽屉→选中模块→嵌入仅取消/独立关闭面板），返回是否消费
func _handle_escape() -> bool:
	# 1. 抽屉开→先关
	if sim_drawer != null and sim_drawer.visible:
		_close_sim_drawer()
		return true
	# 2. 有选中模块→回空态
	if not selected_mod_id.is_empty():
		selected_mod_id = ""
		_show_deck_empty()
		# 刷新改造库选中态视觉
		if mod_list_container:
			for child in mod_list_container.get_children():
				if child is Button:
					child.queue_redraw()
		return true
	# 3. 嵌入模式：不关闭面板（避免连带关闭宿主 card_info_panel），仅取消选中单位
	if _embedded_mode:
		if selected_card != null:
			selected_card = null
			_update_card_info()
		return true
	# 4. 独立模式：关闭面板
	_on_close()
	return true


func _on_close() -> void:
	closed.emit()


## v9.x: 返回成长面板首页（关闭当前面板 + 打开成长面板）
func _on_back_to_growth() -> void:
	closed.emit()
	var main = get_node_or_null("/root/Main")
	if main and main.has_method("_toggle_overlay"):
		var overlay = main._overlay_for_panel_key("growth") if main.has_method("_overlay_for_panel_key") else null
		if overlay:
			main._toggle_overlay(overlay, "growth")

func _show_result(message: String) -> void:
	if result_label:
		# v7.x：ResultLabel 始终占位（custom_minimum_size.y = 22），不切换 visible，
		# 避免显示/隐藏时撑高/塌缩 VBox 导致下方布局抖动。
		result_label.text = message
		# 失败用红，成功用绿
		var is_fail := message.findn("失败") >= 0 or message.findn("不足") >= 0 or message.findn("缺少") >= 0
		result_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35, 1) if is_fail else Color(0.2, 0.9, 0.4, 1))
		_result_token += 1
		var my_token := _result_token
		await get_tree().create_timer(3.0).timeout
		if not is_inside_tree():
			return
		# 仅当期间无新消息（token 未变）才清空，避免前一条 timer 擦掉后一条还在显示的消息
		if my_token == _result_token:
			result_label.text = ""


# ========== 辅助函数 ==========

func _get_unit_icon(card: CardResource) -> String:
	# v1.5：枚举只有 5 档（轻装/装甲/支援/空中/堡垒），旧代码匹配"步兵/炮兵/防空..."
	# 导致除装甲外全 fallback。改用 combat_kind int 直接索引。
	# 保留图形化 emoji（比单字更直观），键值与 CardResource.CombatKind 对齐。
	match card.combat_kind:
		0: return "⚔"   # LIGHT 轻装/步兵
		1: return "◈"   # ARMOR 装甲
		2: return "◎"   # SUPPORT 支援/炮兵
		3: return "✈"   # AIR 空军
		4: return "■"   # FORT 堡垒
		_: return "⚔"

func _get_kind_color(combat_kind: int) -> Color:
	# v1.5：收敛到 DesignTokens 单一源（旧本地 match 键名错位，除装甲外全灰）
	return DT.get_kind_color(combat_kind)

## v7.x 稀有度配色统一到 GC.get_rarity_color（单一数据源），避免与背包卡牌/卡框配色不一致。
func _rarity_color(rarity: String) -> Color:
	return GC.get_rarity_color(rarity)

## 稀有度排序权重（mythic 最大，用于已解锁改造列表按稀有度降序排列）
func _rarity_sort_value(rarity: String) -> int:
	match rarity:
		"common": return 1
		"uncommon": return 2
		"rare": return 3
		"epic": return 4
		"legendary": return 5
		"mythic": return 6
		_: return 0
