extends PanelContainer
## 公司商店面板：选择公司 → 直接购买卡牌（加入背包）

const CompanyDefs = preload("res://data/company_definitions.gd")
const BasicResources = preload("res://data/basic_resources.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const GC = preload("res://resources/game_constants.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")  # v6.23: 特购卡行缩略图
const IntelManualItems = preload("res://data/intel_manual_items.gd")
const ModRegistry = preload("res://scripts/systems/modification_registry.gd")
const FormatUtil = preload("res://scripts/ui/format_util.gd")
const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const PanelChrome = preload("res://scenes/ui/components/panel_chrome.gd")
const LEGACY_BLUEPRINT_DISPLAY_NAMES: Dictionary = {
	"mini_rocket": "轻型斯托克斯迫击炮",
	"emp_pulse": "干扰手枪",
	"energy_leech": "光束步枪·续航型",
}

signal closed

@onready var company_tabs: HBoxContainer = $Margin/VBox/CompanyTabs
@onready var balance_label: Label = $Margin/VBox/BalanceLabel
@onready var item_list: VBoxContainer = $Margin/VBox/ScrollContainer/ItemList

var _current_company_id: String = ""
var _feedback_tween: Tween
## 购买防抖锁：购买流程（含 0.4s 反馈动画）期间禁止重复触发，避免快速连点导致多次 emit 多发卡。
## 打开分帧单飞守卫：避免打开刷新管线重入（仿 backpack_presenter 模式）
var _open_refresh_inflight: bool = false
## 资源变动信号去重：购买流程自身会刷新 items，期间跳过 resources_changed 回弹触发的全量重建
var _suppress_resources_refresh: bool = false
## v27.12 性能：面板不可见期间的商品行重建请求只置脏不重建（resources_changed 战斗中高频），
## 恢复可见时由 _on_visibility_refresh 统一补刷
var _items_dirty: bool = false

## 缓存样式
var _row_style_normal: StyleBox
var _row_style_locked: StyleBoxFlat

## 全局访问贡献阈值（8级 = 6200贡献）
const GLOBAL_ACCESS_THRESHOLD: int = 6200

func _ready() -> void:
	# v7.x 面板统一：MEDIUM 档 + 金色签名框架 + PanelChrome 标题栏（右上 ✕ 关闭）
	custom_minimum_size = DT.PANEL_SIZE_MEDIUM
	var accent := DT.get_panel_accent("store")
	add_theme_stylebox_override("panel", PanelStyles.make_panel_frame_textured(accent))
	var chrome = PanelChrome.attach_to($Margin/VBox, "补给舱", accent, "军需补给")
	chrome.closed.connect(_on_close)
	_init_cached_styles()
	_build_company_tabs()
	_refresh_balance()
	# 批次三 B2b：余额行就地解释"全域访问"的解锁条件
	balance_label.tooltip_text = "任一势力贡献达到 6200（8 级）后激活全域访问：可在所有公司购物，不再受当前公司限制"
	# _ready 只做轻量初始化（余额 + 公司 tab），商品列表重建交给 on_overlay_opened 拆帧，
	# 避免首次实例化时 40+ 节点全挤一帧（LazyLoader 实例化即 visible 时由 _run_open_refresh_pipeline 兜底）。
	# 监听资源变动，实时刷新余额和购买按钮状态
	if BasicResourceManager and BasicResourceManager.has_signal("resources_changed"):
		BasicResourceManager.resources_changed.connect(_on_resources_changed)
	# v27.12 性能：隐藏期间置脏的商品行在恢复可见时统一补刷
	if not visibility_changed.is_connected(_on_visibility_refresh):
		visibility_changed.connect(_on_visibility_refresh)

## 外部打开商店面板时调用：将刷新拆帧，先保证余额可见，再补齐商品列表（仿 backpack_presenter 模式）
func on_overlay_opened() -> void:
	if _open_refresh_inflight:
		return
	_open_refresh_inflight = true
	call_deferred("_run_open_refresh_pipeline")

## 打开刷新管线：余额先刷（轻量），商品列表延后一帧（重活），降低首开尖峰
func _run_open_refresh_pipeline() -> void:
	if not is_visible_in_tree():
		_open_refresh_inflight = false
		return
	# Step 1: 余额立即刷新，让用户先看到资源数字
	_refresh_balance()
	# Step 2: 商品列表延后一帧，避开打开同帧的实例化尖峰
	await get_tree().process_frame
	if not is_visible_in_tree():
		_open_refresh_inflight = false
		return
	_refresh_items()
	_open_refresh_inflight = false

func _init_cached_styles() -> void:
	# v28 T2: 商品行迁"面材"渐变底（金边卡底 / 青边仪更亮）；锁行保持 flat 灰
	_row_style_normal = PanelStyles.make_row_surface(DT.COLOR_GOLD)
	_row_style_locked = PanelStyles.make_panel_style(
		Color(DT.COLOR_PANEL_DEEP.r, DT.COLOR_PANEL_DEEP.g, DT.COLOR_PANEL_DEEP.b, 0.7),
		Color(DT.COLOR_BORDER_DIM.r, DT.COLOR_BORDER_DIM.g, DT.COLOR_BORDER_DIM.b, 0.25), 1, 4
	)

func _on_close() -> void:
	closed.emit()

func _on_resources_changed() -> void:
	# v9 perf：面板隐藏时直接跳过——resources_changed 战斗中每次击杀都发，
	# 隐藏商店的全量重建是纯浪费；打开路径 on_overlay_opened 会全量刷新，余额/商品都不会漏
	if not is_visible_in_tree():
		# v27.12 性能：隐藏时不裸丢刷新请求——置脏待恢复可见时补刷商品行
		_items_dirty = true
		return
	# 余额轻量，保持即时刷新（购买后用户立即看到扣减后的数字）
	_refresh_balance()
	# 购买流程自身会统一刷新 items，期间跳过回弹触发的全量重建（一次购买从 2-3 次降到 1 次）
	if _suppress_resources_refresh:
		return
	_refresh_items()


## v27.12 性能：恢复可见时补刷置脏的商品行（隐藏期间 resources_changed 只置脏不重建）
func _on_visibility_refresh() -> void:
	if is_visible_in_tree() and _items_dirty:
		_refresh_items()

func _build_company_tabs() -> void:
	for c in company_tabs.get_children():
		c.queue_free()
	var companies: Array[Dictionary] = CompanyDefs.get_all()
	if companies.is_empty():
		return
	if _current_company_id.is_empty():
		_current_company_id = String(companies[0].get("id", ""))
	for cfg in companies:
		if not cfg is Dictionary:
			continue
		var cid: String = cfg.get("id", "")
		var name: String = cfg.get("name", cid)
		var btn := Button.new()
		btn.text = name
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(0, 38)
		btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
		# 批次三 B2b：公司 Tab 悬停就地展示公司简介（desc 字段一直存在但从未显示）
		var cdesc: String = String(cfg.get("desc", ""))
		btn.tooltip_text = cdesc if not cdesc.is_empty() else "查看 %s 在售的商品" % name
		var tab_accent: Color = DT.get_panel_accent("store")
		var tab_styles := PanelStyles.make_button_styles(tab_accent)
		# v25 UI 统一：选中态对齐 TabContainer 的"顶部 accent 条"页签语言（原为整框高亮）
		var tab_selected := tab_styles["pressed"].duplicate() as StyleBoxFlat
		tab_selected.set_border_width_all(1)
		tab_selected.border_width_top = 2
		tab_selected.border_color = Color(tab_accent.r, tab_accent.g, tab_accent.b, 0.9)
		tab_selected.bg_color = DT.COLOR_CARD_HI
		btn.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
		btn.add_theme_color_override("font_hover_color", DT.COLOR_TEXT_BRIGHT)
		btn.add_theme_color_override("font_pressed_color", DT.COLOR_TEXT_BRIGHT)
		btn.add_theme_color_override("font_focus_color", DT.COLOR_TEXT_BRIGHT)
		btn.add_theme_stylebox_override("normal", tab_styles["normal"])
		btn.add_theme_stylebox_override("hover", tab_styles["hover"])
		btn.add_theme_stylebox_override("pressed", tab_selected)
		btn.add_theme_stylebox_override("disabled", tab_styles["disabled"])
		btn.add_theme_stylebox_override("focus", tab_styles["focus"])
		btn.pressed.connect(func() -> void:
			_current_company_id = cid
			_update_tab_states()
			_refresh_items()
			# 批次2：tab 切换内容淡入（原瞬跳白板）
			PanelAnim.fade_content_in(item_list)
		)
		company_tabs.add_child(btn)
	_update_tab_states()

func _update_tab_states() -> void:
	for child in company_tabs.get_children():
		if child is Button:
			var btn := child as Button
			btn.button_pressed = (btn.text == _get_company_name(_current_company_id))

func _get_company_name(cid: String) -> String:
	var cfg: Dictionary = CompanyDefs.get_by_id(cid)
	return cfg.get("name", cid)

## 检查是否启用全局访问（任一势力贡献达到阈值）

func _has_global_access() -> bool:
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm == null or not fsm.has_method("get_all_factions_info"):
		return false

	var all_factions: Array = fsm.get_all_factions_info()
	for faction_info in all_factions:
		if faction_info is Dictionary:
			var rep: int = int(faction_info.get("reputation", 0))
			if rep >= GLOBAL_ACCESS_THRESHOLD:
				return true

	return false

## 获取玩家最高势力贡献

func _get_max_faction_reputation() -> int:
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm == null or not fsm.has_method("get_all_factions_info"):
		return 0

	var all_factions: Array = fsm.get_all_factions_info()
	var max_rep: int = 0
	for faction_info in all_factions:
		if faction_info is Dictionary:
			var rep: int = int(faction_info.get("reputation", 0))
			if rep > max_rep:
				max_rep = rep

	return max_rep

func _refresh_balance() -> void:
	var totals: Dictionary = BasicResourceManager.get_all_totals()
	var nano: int = int(totals.get(BasicResources.ID_NANO_MATERIALS, 0))
	var energy: int = int(totals.get(BasicResources.ID_ENERGY_BLOCK, 0))

	# v6.23c: 余额行补功勋（主诉⑬"商店看不到自己数值"）——特购区/符文区消费货币
	var merit: int = 0
	var fsm_bal: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm_bal != null and fsm_bal.has_method("get_merit_points"):
		merit = int(fsm_bal.get_merit_points())
	var base_text = "纳米材料：%s　　能量块：%s　　功勋：%d" % [FormatUtil.format_number(nano), FormatUtil.format_number(energy), merit]

	# 显示全局访问状态
	if _has_global_access():
		var max_rep = _get_max_faction_reputation()
		balance_label.text = "%s　　全域访问已激活（最高贡献：%d）" % [base_text, max_rep]
	else:
		balance_label.text = base_text


func _refresh_items() -> void:
	# v27.12 性能：不可见时只置脏不重建（延迟购买刷新/资源回弹等统一挪到恢复可见时补刷）
	if not is_visible_in_tree():
		_items_dirty = true
		return
	_items_dirty = false
	for c in item_list.get_children():
		c.queue_free()
	if _current_company_id.is_empty():
		return
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	var current_rep: int = 0
	if fsm != null and fsm.has_method("get_faction_reputation"):
		current_rep = int(fsm.get_faction_reputation(_current_company_id))
	# v6.22: CompanyStore 纳米主卡列表已随双轨商店收口整删——四区结构收敛为三区
	# （符文功勋轨 / 势力补给功勋特购 / 情报道具纳米轨），卡片获取改走制造/掉落/任务。

	# ═══ v6.2: 符文售卖区 ═══
	_build_rune_items_section(current_rep)

	# ═══ v26.11(A1.2): 势力补给 · 功勋特购区 ═══
	_build_faction_shop_extras_section(current_rep)

	# ═══ v6.0: 情报道具售卖区 ═══
	_build_intel_items_section()


## v6.2: 构建符文售卖区 — 从 FactionShop 获取符文商品
func _build_rune_items_section(current_rep: int) -> void:
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm == null or not fsm.has_method("get_faction_store_items"):
		return
	# 获取当前势力的商店商品（含基础符文+专属符文）
	var all_items: Array = fsm.get_faction_store_items(_current_company_id)
	# 筛选出 RUNE 类型（StoreItemType.RUNE = 3）
	var rune_items: Array = []
	for it in all_items:
		if it == null:
			continue
		if int(it.item_type) == 3:  # StoreItemType.RUNE
			rune_items.append(it)
	if rune_items.is_empty():
		return
	# 标题
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(DT.COLOR_VIOLET.r, DT.COLOR_VIOLET.g, DT.COLOR_VIOLET.b, 0.3))
	item_list.add_child(sep)
	var title := Label.new()
	title.text = "◈ 符文（%d种）" % rune_items.size()
	title.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	title.add_theme_color_override("font_color", DT.COLOR_VIOLET)
	item_list.add_child(title)
	# 渲染每个符文商品
	var current_nano: int = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS)
	# v30 R2b：符文消费货币=功勋（不占用贡献等级）
	var merit_now: int = int(fsm.get_merit_points()) if fsm.has_method("get_merit_points") else 0
	var RuneDefsForStore = preload("res://data/runes.gd")
	for it in rune_items:
		var rune_id: String = it.item_id
		var rep_cost: int = int(it.reputation_cost)
		var rune_def: Dictionary = RuneDefsForStore.get_rune(rune_id)
		var rune_name: String = RuneDefsForStore.RUNE_NAMES.get(rune_id, rune_id)
		var rarity: String = rune_def.get("rarity", "common")
		var rarity_name: String = RuneDefsForStore.RARITY_NAMES.get(rarity, "")
		# 检查是否已拥有
		var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
		var already_owned: bool = false
		if pim and pim.has_method("has_rune"):
			already_owned = pim.has_rune(rune_id)
		var display_name: String = "符文·%s（%s）" % [rune_name, rarity_name]
		if already_owned:
			display_name += " ✓"
		# 构建商品行
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 44)
		var style := PanelStyles.make_panel_style(
			Color(DT.COLOR_VIOLET.r, DT.COLOR_VIOLET.g, DT.COLOR_VIOLET.b, 0.08),
			Color(DT.COLOR_ACCENT_PURPLE.r, DT.COLOR_ACCENT_PURPLE.g, DT.COLOR_ACCENT_PURPLE.b, 0.5), 1, 4
		)
		row.add_theme_stylebox_override("panel", style)
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		row.add_child(hbox)
		# 名称
		var name_lbl := Label.new()
		name_lbl.text = display_name
		name_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		name_lbl.custom_minimum_size = Vector2(280, 0)
		name_lbl.add_theme_color_override("font_color", RuneDefsForStore.RARITY_COLORS.get(rarity, Color.WHITE))
		hbox.add_child(name_lbl)
		# 效果（主 + 副效果拼接，data/runes.gd desc_secondary 字段此前未展示）
		var eff_parts := PackedStringArray()
		var dp: String = String(rune_def.get("desc_primary", ""))
		if not dp.is_empty():
			eff_parts.append(dp)
		var ds_raw = rune_def.get("desc_secondary", null)
		if ds_raw is String and not String(ds_raw).is_empty():
			eff_parts.append(String(ds_raw))
		var eff_line: String = " · ".join(eff_parts)
		var effect_lbl := Label.new()
		effect_lbl.text = eff_line
		effect_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		effect_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
		effect_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(effect_lbl)
		# 价格
		var price_lbl := Label.new()
		price_lbl.text = "%d功勋" % rep_cost
		price_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		price_lbl.add_theme_color_override("font_color", DT.COLOR_GOLD)
		price_lbl.custom_minimum_size = Vector2(80, 0)
		hbox.add_child(price_lbl)
		# 购买按钮
		var buy_btn := Button.new()
		buy_btn.text = "购买" if not already_owned else "已拥有"
		buy_btn.custom_minimum_size = Vector2(60, 30)
		buy_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		buy_btn.disabled = already_owned or merit_now < rep_cost
		var rune_btn_styles := PanelStyles.make_button_styles(DT.COLOR_VIOLET)
		buy_btn.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
		buy_btn.add_theme_color_override("font_hover_color", DT.COLOR_TEXT_BRIGHT)
		buy_btn.add_theme_color_override("font_pressed_color", DT.COLOR_TEXT_BRIGHT)
		buy_btn.add_theme_color_override("font_focus_color", DT.COLOR_TEXT_BRIGHT)
		buy_btn.add_theme_stylebox_override("normal", rune_btn_styles["normal"])
		buy_btn.add_theme_stylebox_override("hover", rune_btn_styles["hover"])
		buy_btn.add_theme_stylebox_override("pressed", rune_btn_styles["pressed"])
		buy_btn.add_theme_stylebox_override("disabled", rune_btn_styles["disabled"])
		var captured_rune_id := rune_id
		var captured_rep := rep_cost
		var captured_row := row
		buy_btn.pressed.connect(func() -> void:
			_on_buy_rune(captured_rune_id, captured_rep, captured_row)
		)
		hbox.add_child(buy_btn)

		# 悬浮情报
		var rune_tip := PackedStringArray()
		rune_tip.append(display_name)
		if not eff_line.is_empty():
			rune_tip.append(eff_line)
		rune_tip.append("价格：%d 功勋（当前 %d）" % [rep_cost, merit_now])
		rune_tip.append("功勋由战斗胜利/攻克关卡/任务获得，消费不占用贡献等级")
		if already_owned:
			rune_tip.append("✓ 已拥有")
		elif merit_now < rep_cost:
			rune_tip.append("⚠ 功勋不足，暂无法购买")
		row.tooltip_text = "\n".join(rune_tip)

		item_list.add_child(row)


## v26.11(A1.2): 势力补给 · 功勋特购区。
## FactionShop.get_faction_store_items 的商品分四类，此前只有 RUNE 进了符文区，
## 其余被静默丢弃（TODO_BACKLOG 高价值#2："势力装备/卡牌商品全部不可见"）。本区补齐：
## - MATERIAL（type 1）：纳米/合金包、stat_boost 永久强化、lore_page 资料包
## - CARD（type 0）：全量渲染（v6.22: 公司目录 JSON 已删，无去重对象）
## - 有限库存商品显示"剩余N"，归零禁购——can_purchase_item 的 out_of_stock
##   分支首次有了 UI 呈现（库存侧的上下架消费端即此；add/remove_item_to_store
##   保留为预留接口）
func _build_faction_shop_extras_section(_current_rep: int) -> void:
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm == null or not fsm.has_method("get_faction_store_items"):
		return
	# v30 R2b：特购区消费货币=功勋（贡献等级不因消费下跌）
	var merit_now: int = int(fsm.get_merit_points()) if fsm.has_method("get_merit_points") else 0
	var all_items: Array = fsm.get_faction_store_items(_current_company_id)
	var extras: Array = []
	for it in all_items:
		if it == null:
			continue
		var t: int = int(it.item_type)
		if t == 1:  # StoreItemType.MATERIAL
			extras.append(it)
		elif t == 0:  # StoreItemType.CARD（v6.22: 主目录已删，CARD 全量渲染）
			extras.append(it)
		# RUNE(3) 已由符文区渲染；CARD_BUNDLE(2) 数据层无上架实例，跳过
	if extras.is_empty():
		return
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(DT.COLOR_GOLD.r, DT.COLOR_GOLD.g, DT.COLOR_GOLD.b, 0.3))
	item_list.add_child(sep)
	var title := Label.new()
	title.text = "◈ 势力补给 · 功勋特购（%d种）｜功勋余额 %d" % [extras.size(), merit_now]
	title.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	title.add_theme_color_override("font_color", DT.COLOR_GOLD)
	item_list.add_child(title)
	var merit_note := Label.new()
	merit_note.text = "功勋由战斗胜利/攻克关卡/任务/势力事件获得——消费不占用贡献等级"
	merit_note.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	merit_note.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	item_list.add_child(merit_note)
	for it in extras:
		_build_faction_extra_row(it, merit_now)

func _build_faction_extra_row(it, merit_now: int) -> void:
	var item_id: String = String(it.item_id)
	var is_card: bool = int(it.item_type) == 0
	var rep_cost: int = int(it.reputation_cost)
	var stock: int = int(it.stock)
	var out_of_stock: bool = stock == 0
	# 名称：卡走 DefaultCards/缴获蓝图表解析真实卡名；材料用 StoreItem.display_name（已含量词）
	var display_name: String = String(it.display_name)
	var card: CardResource = null
	if is_card:
		card = DefaultCards.get_card_by_id(item_id)
		if card == null:
			var EnemyBpForShop = preload("res://data/enemy_blueprints.gd")
			card = EnemyBpForShop.get_card_by_id(item_id)
		if card != null:
			display_name = card.display_name
		elif LEGACY_BLUEPRINT_DISPLAY_NAMES.has(item_id):
			display_name = String(LEGACY_BLUEPRINT_DISPLAY_NAMES[item_id])
	var desc_line: String = _describe_faction_extra_item(item_id, is_card, rep_cost)
	var rep_locked: bool = merit_now < rep_cost  # v30 R2b：功勋余额判定（变量名沿用旧 UI 链路）
	# 行容器（复用符文区行范式：金色调面板 + 名称/说明/价格/按钮）
	var row := PanelContainer.new()
	# v6.23（用户拍板）：特购卡行加卡片视觉——缩略图 + 品质色左边框 + 行高 64，
	# 向旧纳米买卡列表观感靠拢（v6.22 列表删除后买卡"没以前好"主诉）。
	# 材料行保持 44 高原样（卡 vs 材料的有意视觉区分）。只读模板取 rarity/图（铁律2）。
	row.custom_minimum_size = Vector2(0, 64) if is_card else Vector2(0, 44)
	var style := PanelStyles.make_panel_style(
		Color(DT.COLOR_GOLD.r, DT.COLOR_GOLD.g, DT.COLOR_GOLD.b, 0.08),
		Color(DT.COLOR_GOLD.r, DT.COLOR_GOLD.g, DT.COLOR_GOLD.b, 0.5), 1, 4
	)
	if is_card and card != null:
		style.border_width_left = 3
		style.border_color = GC.get_rarity_color(String(card.rarity))
	row.add_theme_stylebox_override("panel", style)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)
	if is_card:
		var thumb := TextureRect.new()
		thumb.custom_minimum_size = Vector2(48, 56)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if card != null:
			thumb.texture = UiAssetLoader.card_icon_for_list(card)  # 无图回 null 留空位
		hbox.add_child(thumb)
	var name_lbl := Label.new()
	name_lbl.text = display_name if not out_of_stock else "%s（售罄）" % display_name
	name_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	name_lbl.custom_minimum_size = Vector2(240, 0)
	name_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT if not out_of_stock else DT.COLOR_TEXT_FAINT)
	hbox.add_child(name_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = desc_line
	desc_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	desc_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(desc_lbl)
	var price_lbl := Label.new()
	price_lbl.text = "%d功勋" % rep_cost
	price_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	price_lbl.add_theme_color_override("font_color", DT.COLOR_GOLD)
	price_lbl.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(price_lbl)
	var buy_btn := Button.new()
	buy_btn.text = "购买"
	buy_btn.custom_minimum_size = Vector2(60, 30)
	buy_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	buy_btn.disabled = rep_locked or out_of_stock
	var btn_styles := PanelStyles.make_button_styles(DT.COLOR_GOLD)
	buy_btn.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	buy_btn.add_theme_color_override("font_hover_color", DT.COLOR_TEXT_BRIGHT)
	buy_btn.add_theme_color_override("font_pressed_color", DT.COLOR_TEXT_BRIGHT)
	buy_btn.add_theme_color_override("font_focus_color", DT.COLOR_TEXT_BRIGHT)
	for sb_key in ["normal", "hover", "pressed", "disabled", "focus"]:
		if btn_styles.has(sb_key):
			buy_btn.add_theme_stylebox_override(sb_key, btn_styles[sb_key])
	var captured_item = it
	var captured_row := row
	buy_btn.pressed.connect(func() -> void:
		_on_buy_faction_extra(captured_item, captured_row)
	)
	hbox.add_child(buy_btn)
	# 悬浮情报
	var tip := PackedStringArray()
	tip.append(display_name)
	tip.append(desc_line)
	tip.append("价格：%d 功勋（当前 %d）" % [rep_cost, merit_now])
	if stock > 0:
		tip.append("剩余库存：%d" % stock)
	if out_of_stock:
		tip.append("⚠ 已售罄")
	elif rep_locked:
		tip.append("⚠ 功勋不足，暂无法购买")
	row.tooltip_text = "\n".join(tip)
	item_list.add_child(row)

## 材料商品的购买效果描述（与 FactionShop.deliver_item 的发放口径一致，勿单边改）
func _describe_faction_extra_item(item_id: String, is_card: bool, rep_cost: int) -> String:
	if is_card:
		return "功勋特购卡 · 获得独立养成实例"
	if item_id.begins_with("mod_blueprint_pack_"):
		return "组织特供改造图纸包 · 按该组织专长随机获得一张图纸（对应当前时代）"
	match item_id:
		"nano_materials":
			return "纳米材料 ×%d" % (50 if rep_cost < 300 else 100)
		"alloy":
			return "合金 ×%d" % (20 if rep_cost < 300 else 50)
		"crystal", "energy_block":
			return "%s ×10" % item_id
		"stat_boost_hp":
			return "永久属性强化 · 生命"
		"stat_boost_atk":
			return "永久属性强化 · 攻击"
		"stat_boost_damage":
			return "永久属性强化 · 伤害"
		"lore_page":
			return "随机解锁一页势力背景档案"
	return "势力补给品"

## v26.11(A1.2): 购买势力补给/功勋特购商品（走 fsm.purchase_item 正规链：验功勋与贡献等级→扣→发放→失败回退）
func _on_buy_faction_extra(it, row_node: Control) -> void:
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm == null or not fsm.has_method("purchase_item"):
		return
	var result: Dictionary = fsm.purchase_item(_current_company_id, it)
	if not bool(result.get("ok", false)):
		var reason := String(result.get("reason", ""))
		if reason == "reputation_insufficient":
			_show_buy_error("功勋不足：需要 %d（当前 %d）——战斗胜利与任务可获得功勋" % [
				int(result.get("required_rep", 0)), int(result.get("current_rep", 0))])
		elif reason == "out_of_stock":
			_show_buy_warning("该商品已售罄")
		else:
			_show_buy_error("购买失败：%s" % (reason if not reason.is_empty() else "未知原因"))
		_flash_row(row_node, Color(DT.COLOR_DANGER.r, DT.COLOR_DANGER.g, DT.COLOR_DANGER.b, 0.3))
		return
	_flash_row(row_node, Color(DT.COLOR_GREEN_BRIGHT.r, DT.COLOR_GREEN_BRIGHT.g, DT.COLOR_GREEN_BRIGHT.b, 0.3))
	if SignalBus != null and SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit("已购买：%s" % String(it.display_name))
	_refresh_items()


## v6.2: 购买符文（v30 R2b：消费货币=功勋，不拉低贡献等级）
func _on_buy_rune(rune_id: String, rep_cost: int, row_node: Control) -> void:
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm == null:
		return
	# 检查功勋是否足够
	var merit_now: int = int(fsm.get_merit_points()) if fsm.has_method("get_merit_points") else 0
	if merit_now < rep_cost:
		_flash_row(row_node, Color(DT.COLOR_DANGER.r, DT.COLOR_DANGER.g, DT.COLOR_DANGER.b, 0.3))
		# 批次三 B3：失败给具体原因（原仅红闪，玩家不知道差多少）
		_show_buy_error("功勋不足：需要 %d（当前 %d）——战斗胜利与任务可获得功勋" % [rep_cost, merit_now])
		return
	# v6.2 修复 M14：先发放符文并校验返回值，成功才扣款（原顺序是先扣再发，
	# 若 add_owned_rune 因重复持有返回 false，货币会被误扣不退还）
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	var acquired: bool = false
	if pim and pim.has_method("add_owned_rune"):
		acquired = bool(pim.add_owned_rune(rune_id))
	if not acquired:
		_flash_row(row_node, Color(DT.COLOR_GOLD.r, DT.COLOR_GOLD.g, DT.COLOR_GOLD.b, 0.3))
		# 批次三 B3：add_owned_rune 仅在重复持有时返回 false（已核实）
		_show_buy_warning("已拥有该符文，无需重复购买")
		return
	# 扣除功勋（仅在符文发放成功后）
	if fsm.has_method("spend_merit"):
		fsm.spend_merit(rep_cost)
	# 刷新（功勋变化不触发 resources_changed，无需 suppress 守卫）
	_flash_row(row_node, Color(DT.COLOR_GREEN_BRIGHT.r, DT.COLOR_GREEN_BRIGHT.g, DT.COLOR_GREEN_BRIGHT.b, 0.3))
	_refresh_items()


func _build_intel_items_section() -> void:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(DT.COLOR_VIOLET.r, DT.COLOR_VIOLET.g, DT.COLOR_VIOLET.b, 0.3))
	item_list.add_child(sep)
	var title := Label.new()
	title.text = "情报道具"
	title.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	title.add_theme_color_override("font_color", DT.COLOR_VIOLET)
	item_list.add_child(title)

	var bag: Node = get_node_or_null("/root/IntelItemBag")
	var current_nano: int = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS)

	for item_type in IntelManualItems.ALL_TYPES:
		var def: Dictionary = IntelManualItems.get_def(item_type)
		if def.is_empty():
			continue
		var price: int = IntelManualItems.get_shop_price(item_type)
		var count: int = bag.get_count(item_type) if bag else 0
		var afford: bool = current_nano >= price
		var rarity_color: Color = IntelManualItems.get_rarity_color(def.get("rarity", "common"))

		# 简单情报：改造蓝图类道具附上所解锁模块的具体效果（买前知道解锁什么）
		# v9.x 复查修复：ModificationRegistry.get_data 是 static func——实例 has_method
		# 对静态方法返回 false，原实例式调用被守卫静默跳过（特性从未生效）；
		# 改为与全项目一致的 preload 静态调用
		var intel_desc: String = String(def.get("desc", ""))
		var mod_id: String = String(def.get("mod_id", ""))
		if not mod_id.is_empty():
			var mod_eff: String = String(ModRegistry.get_data(mod_id).get("description", ""))
			if not mod_eff.is_empty():
				intel_desc = "%s\n  效果：%s" % [intel_desc, mod_eff]

		var row := PanelContainer.new()
		var row_style := PanelStyles.make_panel_style(
			Color(DT.COLOR_CARD.r, DT.COLOR_CARD.g, DT.COLOR_CARD.b, 0.92),
			rarity_color * 0.4, 1, 4
		)
		row.add_theme_stylebox_override("panel", row_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		## 名称和描述
		var info_vbox := VBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = "%s  × %d" % [def.get("name", ""), count]
		name_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		name_lbl.add_theme_color_override("font_color", rarity_color)
		info_vbox.add_child(name_lbl)
		var desc_lbl := Label.new()
		desc_lbl.text = "  %s" % intel_desc
		desc_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		desc_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
		info_vbox.add_child(desc_lbl)
		hbox.add_child(info_vbox)

		hbox.add_child(VBoxContainer.new())  ## spacer

		## 价格
		var price_lbl := Label.new()
		price_lbl.text = "⬡ %d" % price
		price_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		price_lbl.add_theme_color_override("font_color", DT.COLOR_GOLD if afford else Color(DT.COLOR_TEXT_DIM.r, DT.COLOR_TEXT_DIM.g, DT.COLOR_TEXT_DIM.b, 0.6))
		hbox.add_child(price_lbl)

		## 购买按钮
		var buy_btn := Button.new()
		buy_btn.text = "购买"
		buy_btn.custom_minimum_size = Vector2(50, 26)
		buy_btn.disabled = not afford
		buy_btn.pressed.connect(_on_buy_intel_item.bind(item_type, price, row))
		var btn_styles := PanelStyles.make_button_styles(rarity_color)
		buy_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		buy_btn.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
		buy_btn.add_theme_color_override("font_hover_color", DT.COLOR_TEXT_BRIGHT)
		buy_btn.add_theme_color_override("font_pressed_color", DT.COLOR_TEXT_BRIGHT)
		buy_btn.add_theme_color_override("font_focus_color", DT.COLOR_TEXT_BRIGHT)
		buy_btn.add_theme_stylebox_override("normal", btn_styles["normal"])
		buy_btn.add_theme_stylebox_override("hover", btn_styles["hover"])
		buy_btn.add_theme_stylebox_override("pressed", btn_styles["pressed"])
		buy_btn.add_theme_stylebox_override("disabled", btn_styles["disabled"])
		hbox.add_child(buy_btn)

		row.add_child(hbox)
		item_list.add_child(row)

		# 悬浮情报
		var intel_tip := PackedStringArray()
		intel_tip.append("%s（持有 %d）" % [def.get("name", ""), count])
		intel_tip.append(intel_desc)
		intel_tip.append("价格：%d 纳米材料（当前 %d）" % [price, current_nano])
		row.tooltip_text = "\n".join(intel_tip)


func _on_buy_intel_item(item_type: String, price: int, row_node: Control) -> void:
	var bag: Node = get_node_or_null("/root/IntelItemBag")
	if bag == null or not bag.has_method("add_item"):
		return
	var current_nano: int = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS)
	if current_nano < price:
		_flash_row(row_node, Color(DT.COLOR_DANGER.r, DT.COLOR_DANGER.g, DT.COLOR_DANGER.b, 0.6))
		# 批次三 B3：失败给具体原因（与卡牌购买"还需 %d"口径一致）
		_show_buy_error("纳米材料不足（还需 %d）" % (price - current_nano))
		return
	# 屏蔽 add_resource 触发的 resources_changed 回弹（购买流程自身统一刷一次）
	_suppress_resources_refresh = true
	BasicResourceManager.add_resource(BasicResources.ID_NANO_MATERIALS, -price)
	_suppress_resources_refresh = false
	bag.add_item(item_type, 1)
	_flash_row(row_node, Color(DT.COLOR_GREEN_BRIGHT.r, DT.COLOR_GREEN_BRIGHT.g, DT.COLOR_GREEN_BRIGHT.b, 0.6))
	_refresh_balance()
	_refresh_items()



## 批次三 B3：购买失败反馈（ToastManager 红/橙；lazy 未加载时退化为 SignalBus 绿条）
func _show_buy_error(msg: String) -> void:
	var tm: Node = get_node_or_null("/root/ToastManager")
	if tm != null and tm.has_method("show_error"):
		tm.show_error(msg)
	elif SignalBus:
		SignalBus.show_toast.emit(msg)


func _show_buy_warning(msg: String) -> void:
	var tm: Node = get_node_or_null("/root/ToastManager")
	if tm != null and tm.has_method("show_warning"):
		tm.show_warning(msg)
	elif SignalBus:
		SignalBus.show_toast.emit(msg)


func _flash_row(row_node: Control, flash_color: Color) -> void:
	if not is_instance_valid(row_node):
		return
	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(row_node, "modulate", Color(flash_color.r, flash_color.g, flash_color.b, 1.0), 0.08)
	_feedback_tween.tween_property(row_node, "modulate", DT.COLOR_HOVER_WHITE, 0.3)

