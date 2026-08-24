extends PanelContainer
## 公司商店面板：选择公司 → 直接购买卡牌（加入背包）

const CompanyDefs = preload("res://data/company_definitions.gd")
const CompanyStore = preload("res://data/company_store.gd")
const BasicResources = preload("res://data/basic_resources.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const GC = preload("res://resources/game_constants.gd")
const IntelManualItems = preload("res://data/intel_manual_items.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const ModRegistry = preload("res://scripts/systems/modification_registry.gd")
const StoreItemRowScene = preload("res://scenes/ui/store_item_row.tscn")
const StoreInstrumentRowScene = preload("res://scenes/ui/store_instrument_row.tscn")
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
var _buy_in_progress: bool = false
## 打开分帧单飞守卫：避免打开刷新管线重入（仿 backpack_presenter 模式）
var _open_refresh_inflight: bool = false
## 资源变动信号去重：购买流程自身会刷新 items，期间跳过 resources_changed 回弹触发的全量重建
var _suppress_resources_refresh: bool = false

## 缓存样式
var _row_style_normal: StyleBoxFlat
var _row_style_locked: StyleBoxFlat
var _instrument_row_style: StyleBoxFlat

## 全局访问声望阈值（8级 = 6200声望）
const GLOBAL_ACCESS_THRESHOLD: int = 6200

func _ready() -> void:
	# v7.x 面板统一：MEDIUM 档 + 金色签名框架 + PanelChrome 标题栏（右上 ✕ 关闭）
	custom_minimum_size = DT.PANEL_SIZE_MEDIUM
	var accent := DT.get_panel_accent("store")
	add_theme_stylebox_override("panel", PanelStyles.make_panel_frame(accent))
	var chrome = PanelChrome.attach_to($Margin/VBox, "公司商店", accent, "COMPANY STORE")
	chrome.closed.connect(_on_close)
	_init_cached_styles()
	_build_company_tabs()
	_refresh_balance()
	# 批次三 B2b：余额行就地解释"全域访问"的解锁条件
	balance_label.tooltip_text = "任一势力声望达到 6200（8 级）后激活全域访问：可在所有公司购物，不再受当前公司限制"
	# _ready 只做轻量初始化（余额 + 公司 tab），商品列表重建交给 on_overlay_opened 拆帧，
	# 避免首次实例化时 40+ 节点全挤一帧（LazyLoader 实例化即 visible 时由 _run_open_refresh_pipeline 兜底）。
	# 监听资源变动，实时刷新余额和购买按钮状态
	if BasicResourceManager and BasicResourceManager.has_signal("resources_changed"):
		BasicResourceManager.resources_changed.connect(_on_resources_changed)

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
	_row_style_normal = PanelStyles.make_panel_style(
		Color(DT.COLOR_CARD.r, DT.COLOR_CARD.g, DT.COLOR_CARD.b, 0.9),
		Color(DT.COLOR_GOLD.r, DT.COLOR_GOLD.g, DT.COLOR_GOLD.b, 0.30), 1, 4
	)
	_row_style_locked = PanelStyles.make_panel_style(
		Color(DT.COLOR_PANEL_DEEP.r, DT.COLOR_PANEL_DEEP.g, DT.COLOR_PANEL_DEEP.b, 0.7),
		Color(DT.COLOR_BORDER_DIM.r, DT.COLOR_BORDER_DIM.g, DT.COLOR_BORDER_DIM.b, 0.25), 1, 4
	)
	_instrument_row_style = PanelStyles.make_panel_style(
		Color(DT.COLOR_CARD.r, DT.COLOR_CARD.g, DT.COLOR_CARD.b, 0.92),
		Color(DT.COLOR_CYAN_TECH.r, DT.COLOR_CYAN_TECH.g, DT.COLOR_CYAN_TECH.b, 0.35), 1, 4
	)

func _on_close() -> void:
	closed.emit()

func _on_resources_changed() -> void:
	# v9 perf：面板隐藏时直接跳过——resources_changed 战斗中每次击杀都发，
	# 隐藏商店的全量重建是纯浪费；打开路径 on_overlay_opened 会全量刷新，余额/商品都不会漏
	if not is_visible_in_tree():
		return
	# 余额轻量，保持即时刷新（购买后用户立即看到扣减后的数字）
	_refresh_balance()
	# 购买流程自身会统一刷新 items，期间跳过回弹触发的全量重建（一次购买从 2-3 次降到 1 次）
	if _suppress_resources_refresh:
		return
	_refresh_items()

func _build_company_tabs() -> void:
	for c in company_tabs.get_children():
		c.queue_free()
	var companies: Array[Dictionary] = CompanyDefs.get_all()
	if companies.is_empty():
		return
	if _current_company_id.is_empty():
		_current_company_id = CompanyStore.get_default_company_id()
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
		var tab_styles := PanelStyles.make_button_styles(DT.get_panel_accent("store"))
		btn.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
		btn.add_theme_color_override("font_hover_color", DT.COLOR_TEXT_BRIGHT)
		btn.add_theme_color_override("font_pressed_color", DT.COLOR_TEXT_BRIGHT)
		btn.add_theme_color_override("font_focus_color", DT.COLOR_TEXT_BRIGHT)
		btn.add_theme_stylebox_override("normal", tab_styles["normal"])
		btn.add_theme_stylebox_override("hover", tab_styles["hover"])
		btn.add_theme_stylebox_override("pressed", tab_styles["pressed"])
		btn.add_theme_stylebox_override("disabled", tab_styles["disabled"])
		btn.add_theme_stylebox_override("focus", tab_styles["focus"])
		btn.pressed.connect(func() -> void:
			_current_company_id = cid
			_update_tab_states()
			_refresh_items()
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

## 检查是否启用全局访问（任一势力声望达到阈值）

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

## 获取玩家最高势力声望

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

	var base_text = "⬡ 纳米材料：%s　　⚡ 能量块：%s" % [FormatUtil.format_number(nano), FormatUtil.format_number(energy)]

	# 显示全局访问状态
	if _has_global_access():
		var max_rep = _get_max_faction_reputation()
		balance_label.text = "%s　　✨ 全域访问已激活（最高声望：%d）" % [base_text, max_rep]
	else:
		balance_label.text = base_text


func _refresh_items() -> void:
	for c in item_list.get_children():
		c.queue_free()
	if _current_company_id.is_empty():
		return
	var items: Array[Dictionary] = CompanyStore.get_items_for_company(_current_company_id)
	if items.is_empty():
		var empty_l := Label.new()
		empty_l.text = "该公司暂未开放商品。"
		empty_l.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		empty_l.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		empty_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_list.add_child(empty_l)
		return

	var current_nano: int = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS)

	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	var current_rep: int = 0
	if fsm != null and fsm.has_method("get_faction_reputation"):
		current_rep = int(fsm.get_faction_reputation(_current_company_id))
	var current_tier: int = current_rep / 10

	# 检查是否启用全局访问
	var global_access: bool = _has_global_access()

	for it in items:
		if not it is Dictionary:
			continue
		var card_id: String = it.get("card_id", "")
		var frag_amount: int = int(it.get("fragment_amount", 1))
		var price_nano: int = int(it.get("price_nano_materials", 0))
		var required_rep: int = int(it.get("required_rep", 0))
		var item_tier: int = required_rep / 10
		var card_name: String = card_id
		var card = null

		# v9.x 复查清理：原"先从敌方蓝图表查找"块删除——enemy_bp 恒 null（自 5 月起死代码），
		# 两个 elif 条件重复且永不可达；商品名直接走 DefaultCards 解析
		var enemy_bp = null
		card = DefaultCards.get_card_by_id(card_id)
		if card:
			card_name = card.display_name
		elif card_id.begins_with("permit_card_"):
			var target_id: String = card_id.trim_prefix("permit_card_")
			var target_card: CardResource = DefaultCards.get_card_by_id(target_id)
			var target_name: String = target_card.display_name if target_card != null else target_id
			card_name = "改造许可函·%s专属" % target_name
		elif LEGACY_BLUEPRINT_DISPLAY_NAMES.has(card_id):
			card_name = String(LEGACY_BLUEPRINT_DISPLAY_NAMES[card_id])
		# v3 后所有战斗卡都是 COMBAT_UNIT，可以正常在商店售卖
		# 原错误代码过滤了 COMBAT_UNIT 导致所有战斗卡被隐藏，现已移除
		# var inspect_card = enemy_bp if enemy_bp != null else card
		# if inspect_card != null and int(inspect_card.card_type) == GC.CardType.COMBAT_UNIT:
		# 	continue

		# 高等级商品名称打码（梯度差 > 1 视为超出当前进度）
		var masked: bool = item_tier > current_tier + 1
		if masked:
			card_name = "？？ 未知卡牌 ？？"

		var locked: bool = current_rep < required_rep and not global_access
		var afford: bool = current_nano >= price_nano

		var row_panel: PanelContainer = _build_store_item_row(
			card_id, card_name, frag_amount, price_nano, required_rep, current_rep,
			locked, afford, enemy_bp, card, masked, item_tier - current_tier
		)
		item_list.add_child(row_panel)

	# 相位仪（势力专属）
	if fsm != null and fsm.has_method("get_faction_phase_instruments"):
		var instruments: Array = fsm.get_faction_phase_instruments(_current_company_id)
		if not instruments.is_empty():
			var sep := HSeparator.new()
			item_list.add_child(sep)
			var title := Label.new()
			title.text = "相位仪（势力专属）"
			title.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
			title.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH)
			item_list.add_child(title)
			for cfg_raw in instruments:
				if not (cfg_raw is Dictionary):
					continue
				var cfg: Dictionary = cfg_raw
				var row_panel2: PanelContainer = _build_instrument_row(cfg, fsm)
				if row_panel2:
					item_list.add_child(row_panel2)

	# ═══ v6.2: 符文售卖区 ═══
	_build_rune_items_section(current_rep)

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
		effect_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
		effect_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
		effect_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(effect_lbl)
		# 价格
		var price_lbl := Label.new()
		price_lbl.text = "%d声望" % rep_cost
		price_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
		price_lbl.add_theme_color_override("font_color", DT.COLOR_GOLD)
		price_lbl.custom_minimum_size = Vector2(80, 0)
		hbox.add_child(price_lbl)
		# 购买按钮
		var buy_btn := Button.new()
		buy_btn.text = "购买" if not already_owned else "已拥有"
		buy_btn.custom_minimum_size = Vector2(60, 30)
		buy_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
		buy_btn.disabled = already_owned or current_rep < rep_cost
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
		rune_tip.append("价格：%d 声望（当前 %d）" % [rep_cost, current_rep])
		if already_owned:
			rune_tip.append("✓ 已拥有")
		elif current_rep < rep_cost:
			rune_tip.append("⚠ 声望不足，暂无法购买")
		row.tooltip_text = "\n".join(rune_tip)

		item_list.add_child(row)


## v6.2: 购买符文
func _on_buy_rune(rune_id: String, rep_cost: int, row_node: Control) -> void:
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm == null:
		return
	# 检查声望是否足够
	var current_rep: int = 0
	if fsm.has_method("get_faction_reputation"):
		current_rep = int(fsm.get_faction_reputation(_current_company_id))
	if current_rep < rep_cost:
		_flash_row(row_node, Color(DT.COLOR_DANGER.r, DT.COLOR_DANGER.g, DT.COLOR_DANGER.b, 0.3))
		# 批次三 B3：失败给具体原因（原仅红闪，玩家不知道差多少）
		_show_buy_error("声望不足：%s 需要声望 %d（当前 %d）" % [_get_company_name(_current_company_id), rep_cost, current_rep])
		return
	# v6.2 修复 M14：先发放符文并校验返回值，成功才扣声望（原顺序是先扣再发，
	# 若 add_owned_rune 因重复持有返回 false，声望会被误扣不退还）
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	var acquired: bool = false
	if pim and pim.has_method("add_owned_rune"):
		acquired = bool(pim.add_owned_rune(rune_id))
	if not acquired:
		_flash_row(row_node, Color(DT.COLOR_GOLD.r, DT.COLOR_GOLD.g, DT.COLOR_GOLD.b, 0.3))
		# 批次三 B3：add_owned_rune 仅在重复持有时返回 false（已核实）
		_show_buy_warning("已拥有该符文，无需重复购买")
		return
	# 扣除声望（仅在符文发放成功后）
	if fsm.has_method("add_faction_reputation"):
		fsm.add_faction_reputation(_current_company_id, -rep_cost)
	# 刷新（add_faction_reputation 不触发 resources_changed，无需 suppress 守卫）
	_flash_row(row_node, Color(DT.COLOR_GREEN_BRIGHT.r, DT.COLOR_GREEN_BRIGHT.g, DT.COLOR_GREEN_BRIGHT.b, 0.3))
	_refresh_items()


func _build_intel_items_section() -> void:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(DT.COLOR_VIOLET.r, DT.COLOR_VIOLET.g, DT.COLOR_VIOLET.b, 0.3))
	item_list.add_child(sep)
	var title := Label.new()
	title.text = "📋 情报道具"
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
		desc_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
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
		buy_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
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


func _build_store_item_row(
	card_id: String, card_name: String, frag_amount: int,
	price_nano: int, required_rep: int, current_rep: int,
	locked: bool, afford: bool, enemy_bp, card,
	masked: bool = false, tier_gap: int = 0
) -> PanelContainer:
	var row_panel: PanelContainer = StoreItemRowScene.instantiate()

	# 样式
	row_panel.add_theme_stylebox_override("panel", _row_style_locked if locked else _row_style_normal)

	# 名称
	var name_label: Label = row_panel.get_node("RowMargin/RowHBox/InfoVBox/NameLabel")
	name_label.text = "%s  × %d 卡牌" % [card_name, frag_amount]
	if locked:
		name_label.add_theme_color_override("font_color", Color(DT.COLOR_TEXT_DIM.r, DT.COLOR_TEXT_DIM.g, DT.COLOR_TEXT_DIM.b, 0.7))
	else:
		name_label.add_theme_color_override("font_color", DT.COLOR_GOLD)

	# 卡牌信息
	var info_card = null
	if enemy_bp:
		info_card = enemy_bp
	elif card != null:
		info_card = card

	if masked:
		# 等级打码商品：只透露类型与梯度提示——情报可见性独立于购买能力，
		# 跨梯度商品保持神秘维持探索驱动（符合 IntelManual 揭示精神）
		var info_label_m: Label = row_panel.get_node("RowMargin/RowHBox/InfoVBox/InfoLabel")
		var m_parts: Array[String] = []
		if info_card != null:
			match info_card.card_type:
				GC.CardType.COMBAT_UNIT: m_parts.append("战斗卡")
				GC.CardType.ENERGY:      m_parts.append("能量卡")
		m_parts.append("超出当前进度的储备（梯度 +%d）" % maxi(tier_gap, 1))
		info_label_m.text = "  |  ".join(m_parts)
		info_label_m.visible = true
	elif info_card != null:
		# 声望锁不遮蔽情报：声望只锁交易不锁认知（玩家看得到目标才会规划声望投入）
		# 类型/稀有度/能量消耗行
		var info_label: Label = row_panel.get_node("RowMargin/RowHBox/InfoVBox/InfoLabel")
		var info_parts: Array[String] = []
		match info_card.card_type:
			GC.CardType.COMBAT_UNIT: info_parts.append("战斗卡")
			GC.CardType.ENERGY:      info_parts.append("能量卡")
		var rarity_text := ""
		match info_card.rarity:
			"uncommon":  rarity_text = "优秀"
			"rare":      rarity_text = "稀有"
			"epic":      rarity_text = "史诗"
			"legendary": rarity_text = "传说"
			"mythic":    rarity_text = "神话"
		if not rarity_text.is_empty():
			info_parts.append(rarity_text)
		if info_card.energy_cost > 0:
			info_parts.append("消耗 %d⚡" % info_card.energy_cost)
		if info_parts.size() > 0:
			info_label.text = "  |  ".join(info_parts)
			info_label.visible = true

		# 基础数值属性行
		# 攻/防/血必须走 UnitStatsTable 口径：防御由兵种派生（derive_defense_by_unit_type），
		# 模板 defense_* 是 v6.2 前旧语义字段，直读会显示错值；与 card_info_panel/背包预览同源
		var base_attrs_label: Label = row_panel.get_node("RowMargin/RowHBox/InfoVBox/BaseAttrsLabel")
		var base_attrs_parts: Array[String] = []
		match info_card.card_type:
			GC.CardType.COMBAT_UNIT:
				var stats := UnitStatsTable.build_stats_from_card(info_card)
				base_attrs_parts.append("生命 %d" % int(stats.max_hp))
				base_attrs_parts.append("攻 轻%d·甲%d·空%d" % [
					int(stats.attack_light), int(stats.attack_armor), int(stats.attack_air)])
				base_attrs_parts.append("防 轻%d·甲%d·空%d" % [
					int(stats.defense_light), int(stats.defense_armor), int(stats.defense_air)])
				if info_card.weight_capacity > 0:
					base_attrs_parts.append("承载 %d 重量" % info_card.weight_capacity)
				if info_card.max_weapons > 0:
					base_attrs_parts.append("武器槽 %d" % info_card.max_weapons)
				if info_card.weight > 0:
					base_attrs_parts.append("重量 %d" % info_card.weight)
			GC.CardType.ENERGY:
				if info_card.energy_cost > 0:
					base_attrs_parts.append("能量消耗 %d⚡" % info_card.energy_cost)
				if info_card.energy_grant > 0:
					base_attrs_parts.append("能量提供 %d⚡" % int(info_card.energy_grant))
		if base_attrs_parts.size() > 0:
			base_attrs_label.text = "  |  ".join(base_attrs_parts)
			base_attrs_label.visible = true

		# 战斗属性行
		var combat_label: Label = row_panel.get_node("RowMargin/RowHBox/InfoVBox/CombatLabel")
		if not info_card.summary_line.is_empty():
			combat_label.text = String(info_card.summary_line)
			combat_label.custom_minimum_size = Vector2(400, 0)
			combat_label.visible = true

		# 描述行
		var desc_label: Label = row_panel.get_node("RowMargin/RowHBox/InfoVBox/DescLabel")
		if not info_card.description.is_empty():
			desc_label.text = String(info_card.description)
			desc_label.custom_minimum_size = Vector2(400, 0)
			desc_label.visible = true

	# 价格
	var price_label: Label = row_panel.get_node("RowMargin/RowHBox/InfoVBox/PriceLabel")
	var req_text := "" if required_rep <= 0 else "（需声望 %d，当前 %d）" % [required_rep, current_rep]
	price_label.text = "花费 %d 纳米材料 %s" % [price_nano, req_text]
	if afford:
		price_label.add_theme_color_override("font_color", Color(DT.COLOR_TEXT_MID.r, DT.COLOR_TEXT_MID.g, DT.COLOR_TEXT_MID.b, 0.85))
	else:
		price_label.add_theme_color_override("font_color", Color(DT.COLOR_DANGER.r, DT.COLOR_DANGER.g, DT.COLOR_DANGER.b, 0.85))

	# 购买按钮
	var buy_btn: Button = row_panel.get_node("RowMargin/RowHBox/BuyBtn")
	var buy_styles := PanelStyles.make_button_styles(DT.COLOR_GOLD)
	buy_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	buy_btn.add_theme_stylebox_override("normal", buy_styles["normal"])
	buy_btn.add_theme_stylebox_override("hover", buy_styles["hover"])
	buy_btn.add_theme_stylebox_override("pressed", buy_styles["pressed"])
	buy_btn.add_theme_stylebox_override("disabled", buy_styles["disabled"])
	buy_btn.add_theme_stylebox_override("focus", buy_styles["focus"])
	if locked:
		buy_btn.disabled = true
		buy_btn.text = "未解锁"
		buy_btn.add_theme_color_override("font_color", Color(DT.COLOR_TEXT_DIM.r, DT.COLOR_TEXT_DIM.g, DT.COLOR_TEXT_DIM.b, 0.6))
	elif not afford:
		buy_btn.disabled = true
		buy_btn.add_theme_color_override("font_color", Color(DT.COLOR_DANGER.r, DT.COLOR_DANGER.g, DT.COLOR_DANGER.b, 0.8))
	else:
		buy_btn.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
		buy_btn.add_theme_color_override("font_hover_color", DT.COLOR_HOVER_WHITE)

	var cid_copy: String = card_id
	var frag_copy: int = frag_amount
	var price_copy: int = price_nano
	buy_btn.pressed.connect(func() -> void:
		_on_buy_pressed(cid_copy, frag_copy, price_copy, row_panel)
	)

	# 悬浮情报：行内文案之外的简明参考（价格/声望门槛/锁定原因一目了然）
	var tip := PackedStringArray()
	if masked:
		tip.append("？？ 未知商品 ？？")
		tip.append("超出当前进度的储备，推进关卡后揭示")
	else:
		tip.append("%s × %d" % [card_name, frag_amount])
		if info_card != null:
			if not String(info_card.summary_line).is_empty():
				tip.append(String(info_card.summary_line))
			if not String(info_card.description).is_empty():
				tip.append(String(info_card.description))
	tip.append("价格：%d 纳米材料" % price_nano)
	if required_rep > 0:
		tip.append("声望需求：%d（当前 %d）" % [required_rep, current_rep])
		if locked:
			tip.append("⚠ 声望不足，暂无法购买")
	row_panel.tooltip_text = "\n".join(tip)

	return row_panel


func _build_instrument_row(cfg: Dictionary, fsm: Node) -> PanelContainer:
	var iid: String = String(cfg.get("id", ""))
	var iname: String = String(cfg.get("name", iid))
	var star: int = int(cfg.get("star", 1))
	var req_rep: int = int(cfg.get("required_rep", 0))
	var price_eb: int = int(cfg.get("price_energy_block", 0))
	# v7.x: 移除 energy_output_rate，改显示能量恢复
	var recovery_rate: float = float(cfg.get("energy_recovery_rate", 0.3))
	var spawn_ratio: float = float(cfg.get("spawn_range_ratio", 0.3))
	var can: Dictionary = fsm.can_buy_instrument(_current_company_id, cfg) if fsm.has_method("can_buy_instrument") else {"ok": false}
	var reason: String = String(can.get("reason", ""))
	var owned: bool = reason == "owned"

	var row_panel: PanelContainer = StoreInstrumentRowScene.instantiate()
	row_panel.add_theme_stylebox_override("panel", _instrument_row_style)
	# 批次三 B2b：相位仪行的属性词典——星级/能量恢复/部署范围就地解释
	row_panel.tooltip_text = "相位仪：星级决定槽位数量与能量上限；能量恢复加快战斗中能量回复；部署范围决定单位可放置的前沿位置（越大越靠前）"

	# 名称
	var name2: Label = row_panel.get_node("M2/HB2/VB2/NameLabel")
	name2.text = "★%d  %s" % [star, iname]

	# 描述
	var desc2: Label = row_panel.get_node("M2/HB2/VB2/DescLabel")
	desc2.text = "需声望 %d，价格 %d 能量块" % [req_rep, price_eb]

	# 基础属性
	var attr_label: Label = row_panel.get_node("M2/HB2/VB2/AttrLabel")
	var attr_parts: Array[String] = []
	attr_parts.append("星级 %d" % star)
	attr_parts.append("能量恢复 %.2f(实际%.1f/s)" % [recovery_rate, recovery_rate * 3.0])
	attr_parts.append("部署范围 %.0f%%" % (spawn_ratio * 100))
	attr_label.text = "  |  ".join(attr_parts)
	attr_label.custom_minimum_size = Vector2(350, 0)
	attr_label.visible = true

	# 高级属性
	var advanced_label: Label = row_panel.get_node("M2/HB2/VB2/AdvancedLabel")
	var advanced_parts: Array[String] = []
	var props: Array = cfg.get("properties", [])
	if props is Array and not props.is_empty():
		for p in props:
			if p is Dictionary:
				var display: String = String((p as Dictionary).get("display", ""))
				if not display.is_empty():
					advanced_parts.append(display)
	else:
		if cfg.has("card_damage_bonus"):
			var bonus = float(cfg.card_damage_bonus)
			if bonus > 0: advanced_parts.append("卡牌伤害+%.0f%%" % (bonus * 100))
		if cfg.has("defense_bonus"):
			var bonus = float(cfg.defense_bonus)
			if bonus > 0: advanced_parts.append("防御+%.0f%%" % (bonus * 100))
		if cfg.has("xp_bonus"):
			var bonus = float(cfg.xp_bonus)
			if bonus > 0: advanced_parts.append("经验+%.0f%%" % (bonus * 100))
		if cfg.has("energy_cost_reduction"):
			var reduction = int(cfg.energy_cost_reduction)
			if reduction > 0: advanced_parts.append("能量消耗-%d" % reduction)
	if advanced_parts.size() > 0:
		advanced_label.text = "  |  ".join(advanced_parts.slice(0, 5))
		advanced_label.custom_minimum_size = Vector2(350, 0)
		advanced_label.visible = true

	# 独特特性
	var trait_label: Label = row_panel.get_node("M2/HB2/VB2/TraitLabel")
	if cfg.has("special_traits"):
		var traits: Array = cfg.get("special_traits", [])
		if not traits.is_empty():
			trait_label.text = "✦ " + "  |  ".join(PackedStringArray(traits))
			trait_label.custom_minimum_size = Vector2(350, 0)
			trait_label.visible = true

	# v6.7: 主动特殊能力（active_ability）— 7星相位仪的招牌技能，原商店漏显示
	# 与 phase_instrument_selector.gd:331 的展示格式保持一致
	var ability_label: Label = row_panel.get_node_or_null("M2/HB2/VB2/AbilityLabel")
	if ability_label and cfg.has("active_ability"):
		var ability: Dictionary = cfg.get("active_ability", {})
		if not ability.is_empty():
			var ability_name: String = String(ability.get("name", ""))
			var ability_desc: String = String(ability.get("description", ""))
			if not ability_name.is_empty() and not ability_desc.is_empty():
				ability_label.text = "⚡ %s：%s" % [ability_name, ability_desc]
			elif not ability_desc.is_empty():
				ability_label.text = "⚡ %s" % ability_desc
			else:
				ability_label.text = "⚡ %s" % ability_name
			ability_label.custom_minimum_size = Vector2(350, 0)
			ability_label.visible = true

	# 购买按钮
	var btn2: Button = row_panel.get_node("M2/HB2/BuyBtn")
	if owned:
		btn2.disabled = true
		btn2.text = "已拥有"
		btn2.tooltip_text = "你已拥有这台相位仪"
	elif bool(can.get("ok", false)):
		btn2.text = "购买并装备"
		btn2.tooltip_text = "消耗 %d 能量块购买，并立即装备这台相位仪" % price_eb
	else:
		btn2.disabled = true
		# 批次三 B2b：禁用按钮挂具体原因 tooltip（点了没反应的困惑就地消解）
		if reason == "rep":
			btn2.text = "声望不足"
			btn2.tooltip_text = "需要 %s 声望 %d（当前最高声望 %d）" % [_get_company_name(_current_company_id), req_rep, _get_max_faction_reputation()]
		elif reason == "energy_block":
			btn2.text = "能量块不足"
			btn2.tooltip_text = "需要 %d 能量块——能量块可通过日常任务与战斗掉落获得" % price_eb
		else:
			btn2.text = "未解锁"
			btn2.tooltip_text = "尚未满足购买条件"

	var iid_copy: String = iid
	btn2.pressed.connect(func() -> void:
		_on_buy_instrument_pressed(iid_copy, row_panel)
	)

	return row_panel

func _on_buy_pressed(card_id: String, card_count: int, price_nano: int, row_node: Control) -> void:
	# 防抖：购买流程（含反馈动画）期间禁止重复触发，避免快速连点多次 emit 导致多发卡。
	if _buy_in_progress:
		return
	if not BasicResourceManager:
		return
	if not BasicResourceManager.has_method("get_total") or not BasicResourceManager.has_method("add_resource"):
		return
	var current_nano: int = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS)
	if current_nano < price_nano:
		# 余额不足闪烁提示 + toast（原来只有闪烁，玩家可能没注意到）
		_flash_row(row_node, Color(DT.COLOR_DANGER.r, DT.COLOR_DANGER.g, DT.COLOR_DANGER.b, 0.6))
		SignalBus.show_toast.emit("纳米材料不足（还需 %d）" % (price_nano - current_nano))
		SignalBus.play_sound.emit("error")
		return
	_buy_in_progress = true
	# 屏蔽 add_resource 触发的 resources_changed 回弹（购买流程末尾统一刷一次）
	_suppress_resources_refresh = true
	# 扣除资源并直接发放卡牌到背包
	BasicResourceManager.add_resource(BasicResources.ID_NANO_MATERIALS, -price_nano)
	if card_id.begins_with("permit_"):
		BasicResourceManager.add_resource(card_id, maxi(1, card_count))
	_suppress_resources_refresh = false
	if not card_id.begins_with("permit_"):
		var template_card: CardResource = DefaultCards.get_card_by_id(card_id)
		if template_card == null:
			template_card = null
		# [LOG-v5.1] print("[StorePanel] _on_buy_pressed: Buying card_id=%s template_card=%s" % [card_id, template_card != null])
		# v7.0: 商店购买的卡牌实例化（独立养成身份）
		var ir: Node = get_node_or_null("/root/InstanceRegistry")
		for i in range(maxi(1, card_count)):
			if template_card != null and SignalBus:
				var out_card: CardResource = null
				if ir != null and ir.has_method("create_instance"):
					out_card = ir.create_instance(card_id)
				else:
					out_card = template_card.clone() if template_card.has_method("clone") else template_card
				# [LOG-v5.1] print("[StorePanel] _on_buy_pressed: Emitting card_added_to_backpack for card_id=%s (i=%d)" % [out_card.card_id, i])
				SignalBus.card_added_to_backpack.emit(out_card)
				# [LOG-v5.1] print("[StorePanel] _on_buy_pressed: Signal emitted")
	# 通知任务系统
	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("notify_item_bought"):
		qm.notify_item_bought()
	# P1-6: 购买成功反馈——此前只有行内绿闪，无 toast/音效（买了卡感知弱）
	if card_id.begins_with("permit_"):
		SignalBus.show_toast.emit("已购入：许可函 ×%d" % maxi(1, card_count))
	else:
		var bought_name: String = DefaultCards.get_safe_display_name(card_id)
		SignalBus.show_toast.emit("已购入：%s%s" % [bought_name, (" ×%d" % maxi(1, card_count)) if card_count > 1 else ""])
	SignalBus.play_sound.emit("card_place")
	# 购买成功闪烁绿色
	_flash_row(row_node, Color(DT.COLOR_GREEN_BRIGHT.r, DT.COLOR_GREEN_BRIGHT.g, DT.COLOR_GREEN_BRIGHT.b, 0.6))
	_refresh_balance()
	# 延迟刷新，让购买反馈动画先完成（call_deferred 避免挤在反馈动画同帧）
	await get_tree().create_timer(0.4).timeout
	_buy_in_progress = false
	if is_instance_valid(row_node):
		call_deferred("_refresh_items")

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

func _on_buy_instrument_pressed(instrument_id: String, row_node: Control) -> void:
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm == null or not fsm.has_method("buy_instrument"):
		return
	# 屏蔽 buy_instrument 内部 add_resource 触发的 resources_changed 回弹
	_suppress_resources_refresh = true
	var res: Dictionary = fsm.buy_instrument(_current_company_id, instrument_id)
	_suppress_resources_refresh = false
	if bool(res.get("ok", false)):
		var qm2 = get_node_or_null("/root/QuestManager")
		if qm2 and qm2.has_method("notify_item_bought"):
			qm2.notify_item_bought()
		_flash_row(row_node, Color(DT.COLOR_GREEN_BRIGHT.r, DT.COLOR_GREEN_BRIGHT.g, DT.COLOR_GREEN_BRIGHT.b, 0.65))
	else:
		_flash_row(row_node, Color(DT.COLOR_DANGER.r, DT.COLOR_DANGER.g, DT.COLOR_DANGER.b, 0.65))
	_refresh_balance()
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(row_node):
		call_deferred("_refresh_items")
