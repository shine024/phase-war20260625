extends PanelContainer
## 公司商店面板：选择公司 → 直接购买卡牌（加入背包）

const CompanyDefs = preload("res://data/company_definitions.gd")
const CompanyStore = preload("res://data/company_store.gd")
const BasicResources = preload("res://data/basic_resources.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const EnemyBlueprints = preload("res://data/enemy_blueprints.gd")
const GC = preload("res://resources/game_constants.gd")
const IntelManualItems = preload("res://data/intel_manual_items.gd")
const StoreItemRowScene = preload("res://scenes/ui/store_item_row.tscn")
const StoreInstrumentRowScene = preload("res://scenes/ui/store_instrument_row.tscn")
const LEGACY_BLUEPRINT_DISPLAY_NAMES: Dictionary = {
	"mini_rocket": "轻型斯托克斯迫击炮",
	"emp_pulse": "干扰手枪",
	"energy_leech": "光束步枪·续航型",
}
const PERMIT_DISPLAY_NAMES: Dictionary = {
	"permit_general": "改造许可函·通用",
	"permit_type_assault": "改造许可函·突击型",
	"permit_type_heavy": "改造许可函·重装型",
	"permit_type_support": "改造许可函·支援型",
	"permit_type_law": "改造许可函·法则型",
}

signal closed

@onready var company_tabs: HBoxContainer = $Margin/VBox/CompanyTabs
@onready var balance_label: Label = $Margin/VBox/BalanceLabel
@onready var item_list: VBoxContainer = $Margin/VBox/ScrollContainer/ItemList
@onready var close_btn: Button = $Margin/VBox/CloseButton

var _current_company_id: String = ""
var _feedback_tween: Tween

## 缓存样式
var _row_style_normal: StyleBoxFlat
var _row_style_locked: StyleBoxFlat
var _instrument_row_style: StyleBoxFlat

## 全局访问声望阈值（8级 = 6200声望）
const GLOBAL_ACCESS_THRESHOLD: int = 6200

func _ready() -> void:
	_init_cached_styles()
	close_btn.pressed.connect(_on_close)
	_build_company_tabs()
	_refresh_balance()
	_refresh_items()
	# 监听资源变动，实时刷新余额和购买按钮状态
	if BasicResourceManager and BasicResourceManager.has_signal("resources_changed"):
		BasicResourceManager.resources_changed.connect(_on_resources_changed)

func _init_cached_styles() -> void:
	_row_style_normal = _make_style_box(
		Color(0.07, 0.1, 0.16, 0.9),
		Color(0.9, 0.6, 0.1, 0.3), 1, 4
	)
	_row_style_locked = _make_style_box(
		Color(0.05, 0.07, 0.11, 0.7),
		Color(0.3, 0.3, 0.35, 0.25), 1, 4
	)
	_instrument_row_style = _make_style_box(
		Color(0.06, 0.11, 0.14, 0.92),
		Color(0.35, 0.75, 0.95, 0.35), 1, 4
	)

func _make_style_box(bg: Color, border: Color, bw: int, cr: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(cr)
	return s

func _on_close() -> void:
	closed.emit()

func _on_resources_changed() -> void:
	_refresh_balance()
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
		btn.custom_minimum_size = Vector2(0, 34)
		btn.add_theme_font_size_override("font_size", 13)
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

	var base_text = "⬡ 纳米材料：%d　　⚡ 能量块：%d" % [nano, energy]

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
		empty_l.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.7))
		empty_l.add_theme_font_size_override("font_size", 13)
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

		# 先从敌方蓝图表查找
		var enemy_bp = EnemyBlueprints.get_card_by_id(card_id)
		if enemy_bp:
			if not String(enemy_bp.display_name).is_empty():
				card_name = String(enemy_bp.display_name)
			elif enemy_bp.card_type == GC.CardType.COMBAT_UNIT:
				card_name = DefaultCards.get_platform_display_name(int(enemy_bp.platform_type))
			elif enemy_bp.card_type == GC.CardType.COMBAT_UNIT:
				card_name = DefaultCards.get_weapon_display_name(int(enemy_bp.weapon_type))
		else:
			card = DefaultCards.get_card_by_id(card_id)
			if card:
				card_name = card.display_name
			elif card_id.begins_with("permit_card_"):
				var target_id: String = card_id.trim_prefix("permit_card_")
				var target_card: CardResource = DefaultCards.get_card_by_id(target_id)
				var target_name: String = target_card.display_name if target_card != null else target_id
				card_name = "改造许可函·%s专属" % target_name
			elif PERMIT_DISPLAY_NAMES.has(card_id):
				card_name = String(PERMIT_DISPLAY_NAMES[card_id])
			elif LEGACY_BLUEPRINT_DISPLAY_NAMES.has(card_id):
				card_name = String(LEGACY_BLUEPRINT_DISPLAY_NAMES[card_id])
		# v3 后所有战斗卡都是 COMBAT_UNIT，可以正常在商店售卖
		# 原错误代码过滤了 COMBAT_UNIT 导致所有战斗卡被隐藏，现已移除
		# var inspect_card = enemy_bp if enemy_bp != null else card
		# if inspect_card != null and int(inspect_card.card_type) == GC.CardType.COMBAT_UNIT:
		# 	continue

		# 高等级商品名称打码
		if item_tier > current_tier + 1:
			card_name = "？？ 未知卡牌 ？？"

		var locked: bool = current_rep < required_rep and not global_access
		var afford: bool = current_nano >= price_nano

		var row_panel: PanelContainer = _build_store_item_row(
			card_id, card_name, frag_amount, price_nano, required_rep, current_rep,
			locked, afford, enemy_bp, card
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
			title.add_theme_font_size_override("font_size", 13)
			title.add_theme_color_override("font_color", Color(0.65, 0.95, 1.0, 0.95))
			item_list.add_child(title)
			for cfg_raw in instruments:
				if not (cfg_raw is Dictionary):
					continue
				var cfg: Dictionary = cfg_raw
				var row_panel2: PanelContainer = _build_instrument_row(cfg, fsm)
				if row_panel2:
					item_list.add_child(row_panel2)

	# ═══ v6.0: 情报道具售卖区 ═══
	_build_intel_items_section()


func _build_intel_items_section() -> void:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.6, 0.4, 0.9, 0.3))
	item_list.add_child(sep)
	var title := Label.new()
	title.text = "📋 情报道具"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.75, 0.55, 0.95, 1.0))
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

		var row := PanelContainer.new()
		var row_style := _make_style_box(
			Color(0.08, 0.06, 0.14, 0.92),
			rarity_color * 0.4, 1, 4
		)
		row.add_theme_stylebox_override("panel", row_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		## 名称和描述
		var info_vbox := VBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = "%s  × %d" % [def.get("name", ""), count]
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", rarity_color)
		info_vbox.add_child(name_lbl)
		var desc_lbl := Label.new()
		desc_lbl.text = "  %s" % def.get("desc", "")
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 0.8))
		info_vbox.add_child(desc_lbl)
		hbox.add_child(info_vbox)

		hbox.add_child(VBoxContainer.new())  ## spacer

		## 价格
		var price_lbl := Label.new()
		price_lbl.text = "⬡ %d" % price
		price_lbl.add_theme_font_size_override("font_size", 12)
		price_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5, 1.0) if afford else Color(0.5, 0.5, 0.5, 0.6))
		hbox.add_child(price_lbl)

		## 购买按钮
		var buy_btn := Button.new()
		buy_btn.text = "购买"
		buy_btn.custom_minimum_size = Vector2(50, 26)
		buy_btn.disabled = not afford
		buy_btn.pressed.connect(_on_buy_intel_item.bind(item_type, price, row))
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.15, 0.1, 0.3, 0.9) if afford else Color(0.08, 0.08, 0.1, 0.7)
		btn_style.set_border_width_all(1)
		btn_style.set_border_color(rarity_color * 0.6)
		btn_style.set_corner_radius_all(4)
		buy_btn.add_theme_stylebox_override("normal", btn_style)
		buy_btn.add_theme_font_size_override("font_size", 11)
		buy_btn.add_theme_color_override("font_color", rarity_color if afford else Color(0.4, 0.4, 0.45, 0.6))
		hbox.add_child(buy_btn)

		row.add_child(hbox)
		item_list.add_child(row)


func _on_buy_intel_item(item_type: String, price: int, row_node: Control) -> void:
	var bag: Node = get_node_or_null("/root/IntelItemBag")
	if bag == null or not bag.has_method("add_item"):
		return
	var current_nano: int = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS)
	if current_nano < price:
		_flash_row(row_node, Color(1, 0.3, 0.3, 0.6))
		return
	BasicResourceManager.add_resource(BasicResources.ID_NANO_MATERIALS, -price)
	bag.add_item(item_type, 1)
	_flash_row(row_node, Color(0.3, 0.8, 0.5, 0.6))
	_refresh_balance()
	_refresh_items()


func _build_store_item_row(
	card_id: String, card_name: String, frag_amount: int,
	price_nano: int, required_rep: int, current_rep: int,
	locked: bool, afford: bool, enemy_bp, card
) -> PanelContainer:
	var row_panel: PanelContainer = StoreItemRowScene.instantiate()

	# 样式
	row_panel.add_theme_stylebox_override("panel", _row_style_locked if locked else _row_style_normal)

	# 名称
	var name_label: Label = row_panel.get_node("RowMargin/RowHBox/InfoVBox/NameLabel")
	name_label.text = "%s  × %d 卡牌" % [card_name, frag_amount]
	if locked:
		name_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 0.7))
	else:
		name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5, 1.0))

	# 卡牌信息
	var info_card = null
	if enemy_bp:
		info_card = enemy_bp
	elif card != null:
		info_card = card

	if info_card != null and not locked:
		# 类型/稀有度/能量消耗行
		var info_label: Label = row_panel.get_node("RowMargin/RowHBox/InfoVBox/InfoLabel")
		var info_parts: Array[String] = []
		match info_card.card_type:
			GC.CardType.COMBAT_UNIT: info_parts.append("战斗卡")
			GC.CardType.COMBAT_UNIT:   info_parts.append("战斗卡")
			GC.CardType.ENERGY:   info_parts.append("能量卡")
			GC.CardType.COMBAT_UNIT: info_parts.append("战斗卡")
			GC.CardType.LAW:      info_parts.append("法则卡")
		var rarity_text := ""
		match info_card.rarity:
			"uncommon":  rarity_text = "优秀"
			"rare":      rarity_text = "稀有"
			"epic":      rarity_text = "史诗"
			"legendary": rarity_text = "传说"
		if not rarity_text.is_empty():
			info_parts.append(rarity_text)
		if info_card.energy_cost > 0:
			info_parts.append("消耗 %d⚡" % info_card.energy_cost)
		if info_parts.size() > 0:
			info_label.text = "  |  ".join(info_parts)
			info_label.visible = true

		# 基础数值属性行
		var base_attrs_label: Label = row_panel.get_node("RowMargin/RowHBox/InfoVBox/BaseAttrsLabel")
		var base_attrs_parts: Array[String] = []
		match info_card.card_type:
			GC.CardType.COMBAT_UNIT:
				if info_card.weight_capacity > 0:
					base_attrs_parts.append("承载 %d 重量" % info_card.weight_capacity)
				if info_card.max_weapons > 0:
					base_attrs_parts.append("武器槽 %d" % info_card.max_weapons)
			GC.CardType.COMBAT_UNIT:
				if info_card.weight > 0:
					base_attrs_parts.append("重量 %d" % info_card.weight)
			GC.CardType.ENERGY:
				if info_card.energy_cost > 0:
					base_attrs_parts.append("能量消耗 %d" % info_card.energy_cost)
				if info_card.energy_grant > 0:
					base_attrs_parts.append("能量提供 %.0f⚡" % info_card.energy_grant)
			GC.CardType.COMBAT_UNIT:
				if info_card.weight_capacity > 0:
					base_attrs_parts.append("承载 %d 重量" % info_card.weight_capacity)
			GC.CardType.LAW:
				if info_card.energy_cost > 0:
					base_attrs_parts.append("能量消耗 %d⚡" % info_card.energy_cost)
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
	var req_text := "" if required_rep <= 0 else "（需贡献 %d，当前 %d）" % [required_rep, current_rep]
	price_label.text = "花费 %d 纳米材料 %s" % [price_nano, req_text]
	if afford:
		price_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8, 0.8))
	else:
		price_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 0.8))

	# 购买按钮
	var buy_btn: Button = row_panel.get_node("RowMargin/RowHBox/BuyBtn")
	if locked:
		buy_btn.disabled = true
		buy_btn.text = "未解锁"
		buy_btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45, 0.6))
	elif not afford:
		buy_btn.disabled = true
		buy_btn.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 0.8))
	else:
		buy_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
		buy_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))

	var cid_copy: String = card_id
	var frag_copy: int = frag_amount
	var price_copy: int = price_nano
	buy_btn.pressed.connect(func() -> void:
		_on_buy_pressed(cid_copy, frag_copy, price_copy, row_panel)
	)

	return row_panel


func _build_instrument_row(cfg: Dictionary, fsm: Node) -> PanelContainer:
	var iid: String = String(cfg.get("id", ""))
	var iname: String = String(cfg.get("name", iid))
	var star: int = int(cfg.get("star", 1))
	var req_rep: int = int(cfg.get("required_rep", 0))
	var price_eb: int = int(cfg.get("price_energy_block", 0))
	var output_rate: float = float(cfg.get("energy_output_rate", 1.0))
	var spawn_ratio: float = float(cfg.get("spawn_range_ratio", 0.3))
	var can: Dictionary = fsm.can_buy_instrument(_current_company_id, cfg) if fsm.has_method("can_buy_instrument") else {"ok": false}
	var reason: String = String(can.get("reason", ""))
	var owned: bool = reason == "owned"

	var row_panel: PanelContainer = StoreInstrumentRowScene.instantiate()
	row_panel.add_theme_stylebox_override("panel", _instrument_row_style)

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
	attr_parts.append("能量输出 %.2f(实际%.1f)" % [output_rate, output_rate * 5.0])
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
		if cfg.has("drop_bonus"):
			var bonus = float(cfg.drop_bonus)
			if bonus > 0: advanced_parts.append("掉落+%.0f%%" % (bonus * 100))
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

	# 购买按钮
	var btn2: Button = row_panel.get_node("M2/HB2/BuyBtn")
	if owned:
		btn2.disabled = true
		btn2.text = "已拥有"
	elif bool(can.get("ok", false)):
		btn2.text = "购买并装备"
	else:
		btn2.disabled = true
		if reason == "rep":
			btn2.text = "声望不足"
		elif reason == "energy_block":
			btn2.text = "能量块不足"
		else:
			btn2.text = "未解锁"

	var iid_copy: String = iid
	btn2.pressed.connect(func() -> void:
		_on_buy_instrument_pressed(iid_copy, row_panel)
	)

	return row_panel

func _on_buy_pressed(card_id: String, card_count: int, price_nano: int, row_node: Control) -> void:
	if not BasicResourceManager:
		return
	if not BasicResourceManager.has_method("get_total") or not BasicResourceManager.has_method("add_resource"):
		return
	var current_nano: int = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS)
	if current_nano < price_nano:
		# 余额不足闪烁提示
		_flash_row(row_node, Color(1, 0.3, 0.3, 0.6))
		return
	# 扣除资源并直接发放卡牌到背包
	BasicResourceManager.add_resource(BasicResources.ID_NANO_MATERIALS, -price_nano)
	if card_id.begins_with("permit_"):
		BasicResourceManager.add_resource(card_id, maxi(1, card_count))
	else:
		var template_card: CardResource = DefaultCards.get_card_by_id(card_id)
		if template_card == null:
			template_card = EnemyBlueprints.get_card_by_id(card_id)
		for i in range(maxi(1, card_count)):
			if template_card != null and SignalBus:
				var out_card: CardResource = template_card.clone() if template_card.has_method("clone") else template_card
				SignalBus.card_added_to_backpack.emit(out_card)
	# 通知任务系统
	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("notify_item_bought"):
		qm.notify_item_bought()
	# 购买成功闪烁绿色
	_flash_row(row_node, Color(0.3, 0.9, 0.5, 0.6))
	_refresh_balance()
	# 延迟刷新，让购买反馈动画先完成
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(row_node):
		_refresh_items()

func _flash_row(row_node: Control, flash_color: Color) -> void:
	if not is_instance_valid(row_node):
		return
	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(row_node, "modulate", Color(flash_color.r, flash_color.g, flash_color.b, 1.0), 0.08)
	_feedback_tween.tween_property(row_node, "modulate", Color(1, 1, 1, 1), 0.3)

func _on_buy_instrument_pressed(instrument_id: String, row_node: Control) -> void:
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm == null or not fsm.has_method("buy_instrument"):
		return
	var res: Dictionary = fsm.buy_instrument(_current_company_id, instrument_id)
	if bool(res.get("ok", false)):
		var qm2 = get_node_or_null("/root/QuestManager")
		if qm2 and qm2.has_method("notify_item_bought"):
			qm2.notify_item_bought()
		_flash_row(row_node, Color(0.35, 0.95, 0.55, 0.65))
	else:
		_flash_row(row_node, Color(1.0, 0.35, 0.35, 0.65))
	_refresh_balance()
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(row_node):
		_refresh_items()
