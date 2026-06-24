extends PanelContainer
## 统一情报面板：背包/相位仪/战场共用
## 4 Tab：情报 / 强化 / 改造 / 进化
## 模式：
##   MODE_BACKPACK(0)         → 拆解+装备按钮（背包场景）
##   MODE_PHASE_INSTRUMENT(1) → 卸下按钮（相位仪槽位）
##   MODE_BATTLEFIELD(2)      → 无操作按钮（战场点击，仅情报 Tab）

signal action_requested(action: String, card: CardResource)

enum PanelMode { MODE_BACKPACK = 0, MODE_PHASE_INSTRUMENT = 1, MODE_BATTLEFIELD = 2 }
enum TabIdx { INFO = 0, REINFORCE = 1, MODIFY = 2, EVOLVE = 3 }

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const BackpackCombatPreview = preload("res://scenes/ui/backpack_combat_preview.gd")
const RankDisplayUi = preload("res://scripts/rank_display_ui.gd")
const ReinforcePanelScene = preload("res://scenes/ui/reinforcement_panel.tscn")
const ModifyPanelScene = preload("res://scenes/ui/modification_panel.tscn")
const EvolvePanelScene = preload("res://scenes/ui/evolution_panel.tscn")
const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")

var current_card: CardResource = null
var _current_unit: Node = null
var _current_mode: int = PanelMode.MODE_BACKPACK
var _context_data: Dictionary = {}

# 节点引用
var action_buttons_container: HBoxContainer = null
var close_button: Button = null
var name_label: Label = null
var type_label: Label = null
var summary_label: Label = null
var affix_label: Label = null
var star_label: Label = null
var law_label: Label = null
var nurture_label: Label = null
var status_label: Label = null
var desc_label: Label = null
var flavor_label: Label = null
var rank_badge_host: HBoxContainer = null
var rarity_label: Label = null
var cost_label: Label = null
var status_section: PanelContainer = null
var _tab_container: TabContainer = null
# v6.4 图形化三维攻防卡节点
var _hp_value_label: Label = null
var _hp_sub_label: Label = null
var _atk_value_label: Label = null
var _atk_sub_label: Label = null
var _def_value_label: Label = null
var _def_sub_label: Label = null
var _extra_stat_label: Label = null
var _stats_section: PanelContainer = null
var _stat_cards_row: HBoxContainer = null
var _affix_flow: VBoxContainer = null
var _star_detail_label: Label = null

# 子面板实例（懒加载）
var _reinforce_instance: Control = null
var _modify_instance: Control = null
var _evolve_instance: Control = null

const ERA_NAMES := ["一战", "二战", "冷战", "现代", "近未来"]
const RARITY_COLORS := {
	"common": Color(0.75, 0.78, 0.85, 1),
	"uncommon": Color(0.4, 1.0, 0.6, 1),
	"rare": Color(0.4, 0.7, 1.0, 1),
	"epic": Color(0.8, 0.5, 1.0, 1),
	"legendary": Color(1.0, 0.6, 0.9, 1),
}
const RARITY_DISPLAY := {
	"common": "普通", "uncommon": "优秀", "rare": "稀有",
	"epic": "史诗", "legendary": "传说",
}

var _plm: Node = null
func _ensure_plm() -> Node:
	if _plm == null:
		_plm = get_node_or_null("/root/PhaseLawManager")
	return _plm

func _ready() -> void:
	visible = false
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resolve_nodes()
	_setup_tab_titles()
	_setup_action_buttons_container()
	if close_button:
		close_button.pressed.connect(hide_panel)

func _resolve_nodes() -> void:
	name_label = get_node_or_null("Margin/VBox/HeaderPanel/HeaderVBox/NameStarRow/NameLabel") as Label
	star_label = get_node_or_null("Margin/VBox/HeaderPanel/HeaderVBox/NameStarRow/StarLabel") as Label
	rarity_label = get_node_or_null("Margin/VBox/HeaderPanel/HeaderVBox/RarityCostRow/RarityLabel") as Label
	cost_label = get_node_or_null("Margin/VBox/HeaderPanel/HeaderVBox/RarityCostRow/CostLabel") as Label
	type_label = get_node_or_null("Margin/VBox/TypeLabel") as Label
	rank_badge_host = get_node_or_null("Margin/VBox/RankBadgeHost") as HBoxContainer
	_tab_container = get_node_or_null("Margin/VBox/TabBar") as TabContainer
	# v6.4 图形化三维攻防卡
	_hp_value_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/StatsSection/StatsVBox/StatCardsRow/HpCard/HpVBox/HpValue") as Label
	_hp_sub_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/StatsSection/StatsVBox/StatCardsRow/HpCard/HpVBox/HpSub") as Label
	_atk_value_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/StatsSection/StatsVBox/StatCardsRow/AtkCard/AtkVBox/AtkValue") as Label
	_atk_sub_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/StatsSection/StatsVBox/StatCardsRow/AtkCard/AtkVBox/AtkSub") as Label
	_def_value_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/StatsSection/StatsVBox/StatCardsRow/DefCard/DefVBox/DefValue") as Label
	_def_sub_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/StatsSection/StatsVBox/StatCardsRow/DefCard/DefVBox/DefSub") as Label
	_extra_stat_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/StatsSection/StatsVBox/ExtraStatLabel") as Label
	_stats_section = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/StatsSection") as PanelContainer
	_stat_cards_row = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/StatsSection/StatsVBox/StatCardsRow") as HBoxContainer
	summary_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/StatsSection/StatsVBox/SummaryLabel") as Label
	# 词条标签化容器
	_affix_flow = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/AffixSection/AffixVBox/AffixFlow") as VBoxContainer
	affix_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/AffixSection/AffixVBox/AffixLabel") as Label
	_star_detail_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/StarSection/StarVBox/StarLabel") as Label
	law_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/LawSection/LawVBox/LawLabel") as Label
	nurture_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/NurtureSection/NurtureVBox/NurtureLabel") as Label
	status_section = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/StatusSection") as PanelContainer
	status_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/StatusSection/StatusVBox/StatusLabel") as Label
	desc_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/DescSection/DescVBox/DescLabel") as Label
	flavor_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/FlavorLabel") as Label
	action_buttons_container = get_node_or_null("Margin/VBox/ActionButtons") as HBoxContainer
	close_button = get_node_or_null("Margin/VBox/CloseButton") as Button

func _setup_tab_titles() -> void:
	if _tab_container == null:
		return
	_tab_container.set_tab_title(TabIdx.INFO, "情报")
	_tab_container.set_tab_title(TabIdx.REINFORCE, "强化")
	_tab_container.set_tab_title(TabIdx.MODIFY, "改造")
	_tab_container.set_tab_title(TabIdx.EVOLVE, "进化")
	_hide_all_sub_tabs()

func _setup_action_buttons_container() -> void:
	if action_buttons_container:
		action_buttons_container.visible = false

## ── 公共接口 ──────────────────────────────────────────────────

func hide_panel() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	current_card = null
	_current_unit = null
	if action_buttons_container:
		action_buttons_container.visible = false
		_clear_action_buttons()
	if close_button:
		close_button.visible = false
	_hide_all_sub_tabs()

func set_panel_mode(mode: int, context_data: Dictionary = {}) -> void:
	_current_mode = mode
	_context_data = context_data

func get_action_buttons() -> HBoxContainer:
	return action_buttons_container

func show_card_info(card: CardResource, at_position: Vector2 = Vector2.ZERO) -> void:
	if card == null:
		hide_panel()
		return
	current_card = card
	_current_unit = null
	_refresh_header(card)
	_refresh_info_sections(card)
	_refresh_action_buttons()
	_apply_card_type_tab_visibility(card)
	if _tab_container:
		_tab_container.current_tab = TabIdx.INFO
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_position_at(at_position)
	set_close_button_visible(true)
	_refresh_sub_panels(card)

func show_unit_info(unit: Node, is_player: bool, at_position: Vector2 = Vector2.ZERO) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	current_card = null
	_current_unit = unit
	_refresh_unit_display(unit, is_player)
	_apply_unit_tab_visibility()
	if _tab_container:
		_tab_container.current_tab = TabIdx.INFO
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_position_at(at_position)
	set_close_button_visible(true)

func _position_at(at_position: Vector2) -> void:
	if at_position == Vector2.ZERO:
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var panel_w := size.x
	var panel_h := size.y
	var viewport := get_viewport()
	var screen_w: float = 1280.0
	var screen_h: float = 720.0
	if viewport:
		screen_w = float(viewport.get_visible_rect().size.x)
		screen_h = float(viewport.get_visible_rect().size.y)
	position = Vector2(
		clampf(at_position.x, 8.0, maxf(8.0, screen_w - panel_w - 8.0)),
		clampf(at_position.y, 8.0, maxf(8.0, screen_h - panel_h - 8.0))
	)

func set_action_buttons_visible(v: bool) -> void:
	if action_buttons_container:
		action_buttons_container.visible = v

func set_close_button_visible(v: bool) -> void:
	if close_button:
		close_button.visible = v

## ── Tab 可见性 ────────────────────────────────────────────────

func _hide_all_sub_tabs() -> void:
	if _tab_container == null:
		return
	_tab_container.set_tab_hidden(TabIdx.REINFORCE, true)
	_tab_container.set_tab_hidden(TabIdx.MODIFY, true)
	_tab_container.set_tab_hidden(TabIdx.EVOLVE, true)

func _apply_card_type_tab_visibility(card: CardResource) -> void:
	if _tab_container == null:
		return
	_hide_all_sub_tabs()
	if card.card_type == GC.CardType.COMBAT_UNIT:
		_tab_container.set_tab_hidden(TabIdx.REINFORCE, false)
		_tab_container.set_tab_hidden(TabIdx.MODIFY, false)
		_tab_container.set_tab_hidden(TabIdx.EVOLVE, false)

func _apply_unit_tab_visibility() -> void:
	if _tab_container == null:
		return
	_hide_all_sub_tabs()

## ── 子面板懒加载 ──────────────────────────────────────────────

func _ensure_reinforce_instance() -> void:
	if _reinforce_instance != null and is_instance_valid(_reinforce_instance):
		return
	var host = get_node_or_null("Margin/VBox/TabBar/TabReinforce")
	if host == null:
		return
	_reinforce_instance = ReinforcePanelScene.instantiate()
	host.add_child(_reinforce_instance)
	if _reinforce_instance.has_method("set_embedded_mode"):
		_reinforce_instance.set_embedded_mode(true)

func _ensure_modify_instance() -> void:
	if _modify_instance != null and is_instance_valid(_modify_instance):
		return
	var host = get_node_or_null("Margin/VBox/TabBar/TabModify")
	if host == null:
		return
	_modify_instance = ModifyPanelScene.instantiate()
	host.add_child(_modify_instance)
	if _modify_instance.has_method("set_embedded_mode"):
		_modify_instance.set_embedded_mode(true)

func _ensure_evolve_instance() -> void:
	if _evolve_instance != null and is_instance_valid(_evolve_instance):
		return
	var host = get_node_or_null("Margin/VBox/TabBar/TabEvolve")
	if host == null:
		return
	_evolve_instance = EvolvePanelScene.instantiate()
	host.add_child(_evolve_instance)
	if _evolve_instance.has_method("set_embedded_mode"):
		_evolve_instance.set_embedded_mode(true)

func _refresh_sub_panels(card: CardResource) -> void:
	if card.card_type != GC.CardType.COMBAT_UNIT:
		return
	_ensure_reinforce_instance()
	_ensure_modify_instance()
	_ensure_evolve_instance()
	if _reinforce_instance and _reinforce_instance.has_method("set_selected_card"):
		_reinforce_instance.set_selected_card(card)
	if _modify_instance and _modify_instance.has_method("set_selected_card"):
		_modify_instance.set_selected_card(card)
	if _evolve_instance and _evolve_instance.has_method("set_selected_card"):
		_evolve_instance.set_selected_card(card)

## ── 操作按钮 ──────────────────────────────────────────────────

func _refresh_action_buttons() -> void:
	if action_buttons_container == null:
		return
	_clear_action_buttons()
	if _current_mode == PanelMode.MODE_BATTLEFIELD:
		action_buttons_container.visible = false
		return
	action_buttons_container.visible = true
	match _current_mode:
		PanelMode.MODE_BACKPACK:
			if current_card:
				_add_action_button("拆解（研究点 + 纳米材料）", Color(1.0, 0.82, 0.35, 1.0), "dismantle")
				if current_card.card_type == GC.CardType.LAW or current_card.card_type == GC.CardType.ENERGY:
					_add_action_button("装备到相位仪", Color(0, 0.94, 1, 1), "equip")
		PanelMode.MODE_PHASE_INSTRUMENT:
			_add_action_button("卸下此卡", Color(0.9, 0.4, 0.4, 1), "unequip")

func _add_action_button(text: String, color: Color, action: String) -> void:
	if action_buttons_container == null:
		return
	var btn := Button.new()
	btn.name = action.capitalize().replace(" ", "") + "Button"
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 38)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	# v6.4: 圆角按钮 + 左侧色条样式
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.12, 0.15, 0.22, 0.95)
	sb_normal.border_color = color
	sb_normal.border_width_left = 3
	sb_normal.border_width_top = 1
	sb_normal.border_width_right = 1
	sb_normal.border_width_bottom = 1
	sb_normal.corner_radius_top_left = 6
	sb_normal.corner_radius_top_right = 6
	sb_normal.corner_radius_bottom_left = 6
	sb_normal.corner_radius_bottom_right = 6
	sb_normal.content_margin_left = 12.0
	sb_normal.content_margin_top = 6.0
	sb_normal.content_margin_right = 12.0
	sb_normal.content_margin_bottom = 6.0
	var sb_hover := sb_normal.duplicate()
	sb_hover.bg_color = Color(color.r * 0.25 + 0.1, color.g * 0.25 + 0.12, color.b * 0.25 + 0.16, 0.97)
	sb_hover.border_color = color.lightened(0.3)
	var sb_pressed := sb_normal.duplicate()
	sb_pressed.bg_color = Color(color.r * 0.15 + 0.08, color.g * 0.15 + 0.1, color.b * 0.15 + 0.13, 0.98)
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	var card_ref := current_card
	btn.pressed.connect(func() -> void:
		if card_ref != null:
			action_requested.emit(action, card_ref)
			# 延迟隐藏面板，确保信号处理完成后再清理按钮
			call_deferred(&"hide_panel")
	)
	action_buttons_container.add_child(btn)

func _clear_action_buttons() -> void:
	if action_buttons_container == null:
		return
	for ch in action_buttons_container.get_children():
		if is_instance_valid(ch):
			action_buttons_container.remove_child(ch)
			ch.queue_free()  # 使用 queue_free 而非 free，避免释放 locked 对象

## ── 卡牌头部刷新 ──────────────────────────────────────────────

## v6.4: 按稀有度染色 HeaderPanel 左侧色带（复制 section 样式并覆盖左边框色）
func _apply_header_rarity_band(rarity_key: String) -> void:
	var header := get_node_or_null("Margin/VBox/HeaderPanel") as PanelContainer
	if header == null:
		return
	var band_color: Color = RARITY_COLORS.get(rarity_key, Color(0.6, 0.65, 0.75, 1))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.14, 0.22, 0.9)
	sb.border_color = band_color
	sb.border_width_left = 4
	sb.border_width_top = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 0
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	header.add_theme_stylebox_override("panel", sb)

func _refresh_header(card: CardResource) -> void:
	if rank_badge_host:
		RankDisplayUi.clear_host(rank_badge_host)
		rank_badge_host.visible = false
	if name_label:
		name_label.text = card.display_name if not card.display_name.is_empty() else DefaultCards.get_safe_display_name(card.card_id)
	# v6.4: 头部星级（★N，金色），仅战斗卡/能量卡显示
	if star_label:
		var star_val: int = int(card.enhance_level) if "enhance_level" in card else 0
		star_label.text = "★%d" % star_val if star_val > 0 else ""
	# v6.4: 稀有度色带——染色 HeaderPanel 左侧边框
	var r_key: String = card.rarity if card.rarity else "common"
	_apply_header_rarity_band(r_key)
	if rarity_label:
		rarity_label.text = RARITY_DISPLAY.get(r_key, r_key)
		rarity_label.add_theme_color_override("font_color", RARITY_COLORS.get(r_key, Color(0.75, 0.78, 0.85, 1)))
	if cost_label:
		if card.card_type == GC.CardType.ENERGY:
			# v6.2 修复 M8：能量卡应显示提供量（energy_grant）而非部署消耗（energy_cost）
			# 大部分能量卡是"消耗N提供M"模式，显示提供量对玩家更有意义
			cost_label.text = "+%d⚡" % int(card.energy_grant if card.energy_grant > 0 else card.energy_cost)
		else:
			cost_label.text = "%d⚡" % int(card.energy_cost)
	if type_label:
		match card.card_type:
			GC.CardType.COMBAT_UNIT:
				var parts: Array[String] = []
				parts.append("战斗卡 — %s" % DefaultCards.get_platform_display_name(card.combat_kind))
				if card.era >= 0 and card.era < ERA_NAMES.size():
					parts.append(ERA_NAMES[card.era])
				var wl: String = card.weapon_label if "weapon_label" in card else ""
				if wl.is_empty() and "weapon_names" in card:
					# v6.5: weapon_label 从未赋值，改为从 weapon_names[] 拼接具体武器配置名
					var wnames: Array = []
					for wn in card.weapon_names:
						var ws: String = String(wn)
						if not ws.is_empty() and not wnames.has(ws):
							wnames.append(ws)
					if wnames.size() > 0:
						wl = " / ".join(wnames)
				if not wl.is_empty():
					parts.append(wl)
				type_label.text = " · ".join(parts)
			GC.CardType.ENERGY:
				type_label.text = "能量卡 · 提供 %d 能量" % int(card.energy_cost)
			GC.CardType.LAW:
				var law_name: String = ""
				if "linked_law_id" in card and not str(card.linked_law_id).is_empty():
					var cfg: Dictionary = PhaseLaws.get_by_id(str(card.linked_law_id)) if PhaseLaws else {}
					law_name = str(cfg.get("name", ""))
				if law_name.is_empty():
					law_name = card.display_name if not card.display_name.is_empty() else "法则"
				type_label.text = "法则卡 · %s" % law_name
			_:
				type_label.text = card.type_line

## ── 情报 Tab 内容刷新 ──────────────────────────────────────────

func _refresh_info_sections(card: CardResource) -> void:
	if card == null:
		return
	# v6.4: 三维攻防——图形化三列数值卡
	_refresh_stat_cards(card)
	# 词条（标签化）
	_refresh_affix_tags(card)
	# 星级强化详情（情报 Tab 内，非头部星级）
	if _star_detail_label:
		_star_detail_label.text = _build_star_lines(card)
	# 法则影响
	if law_label:
		law_label.text = ""  # 卡牌模式无法则影响行（战场单位才会有）
	# 养成摘要
	if nurture_label:
		nurture_label.text = _build_nurture_text(card)
	# 描述
	if desc_label:
		desc_label.text = card.description
	# 风味
	if flavor_label:
		flavor_label.text = card.flavor_text
	# 隐藏战场专用状态区
	if status_section:
		status_section.visible = false

## v6.4: 三维攻防图形化——构建 UnitStats 后结构化填充 HP/攻击/防御三张数值卡
func _refresh_stat_cards(card: CardResource) -> void:
	var is_combat: bool = (card.card_type == GC.CardType.COMBAT_UNIT)
	# 非战斗卡：隐藏三维卡区，回退到纯文本 summary
	if not is_combat:
		if _stats_section:
			_stats_section.visible = false
		if summary_label:
			var preview: String = BackpackCombatPreview.build_line(card)
			if preview.begins_with("战斗中："):
				preview = preview.substr(5)
			summary_label.text = preview if not preview.is_empty() else card.summary_line
			summary_label.visible = true
		return
	# 战斗卡：显示三维卡，隐藏旧 summary
	if _stats_section:
		_stats_section.visible = true
	if _stat_cards_row:
		_stat_cards_row.visible = true
	if _extra_stat_label:
		_extra_stat_label.visible = true
	if summary_label:
		summary_label.visible = false
	# 构建 UnitStats（含时代缩放 + growth + affix）
	var stats: UnitStats = _build_display_stats(card)
	if stats == null:
		return
	# HP 卡
	if _hp_value_label:
		_hp_value_label.text = str(int(stats.max_hp))
	if _hp_sub_label:
		_hp_sub_label.text = "射程 %d" % int(stats.attack_range)
	# 攻击卡（取三维最大值作主数字，子项列三维）
	var atk_main: float = maxf(stats.attack_light, maxf(stats.attack_armor, stats.attack_air))
	if _atk_value_label:
		_atk_value_label.text = str(int(atk_main))
	if _atk_sub_label:
		_atk_sub_label.text = "轻%d·甲%d·空%d" % [int(stats.attack_light), int(stats.attack_armor), int(stats.attack_air)]
	# 防御卡（取三维最大值作主数字，子项列三维）
	var def_main: float = maxf(stats.defense_light, maxf(stats.defense_armor, stats.defense_air))
	if _def_value_label:
		_def_value_label.text = str(int(def_main))
	if _def_sub_label:
		_def_sub_label.text = "轻%d·甲%d·空%d" % [int(stats.defense_light), int(stats.defense_armor), int(stats.defense_air)]
	# 额外信息行（攻速/移速）
	if _extra_stat_label:
		# v6.2 修复 M6：DPS 应基于 atk_main 对应的目标类型攻速，原统一用 attack_interval（对轻装）
		# 会导致"对装甲攻击力÷对轻装攻速"算出虚高 DPS
		var atk_light: float = stats.attack_light
		var atk_armor: float = stats.attack_armor
		var atk_air: float = stats.attack_air
		# 找到最大攻击力对应的目标类型，用配对攻速算 DPS
		var best_atk: float = atk_light
		var best_speed: float = stats.attack_light_speed if stats.attack_light_speed > 0 else 1.0
		if atk_armor > best_atk:
			best_atk = atk_armor
			best_speed = stats.attack_armor_speed if stats.attack_armor_speed > 0 else 1.0
		if atk_air > best_atk:
			best_atk = atk_air
			best_speed = stats.attack_air_speed if stats.attack_air_speed > 0 else 1.0
		var dps: float = best_atk * best_speed
		var avg_spd: float = stats.attack_interval if stats.attack_interval > 0 else 1.0
		_extra_stat_label.text = "攻速 %.1f/s · DPS %d · 移速 %d" % [best_speed, int(dps), int(stats.move_speed)]

## v6.4: 构建 UnitStats（含时代缩放 + growth + affix），供三维卡显示
func _build_display_stats(card: CardResource) -> UnitStats:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var root: Node = tree.root
	var bm: Node = root.get_node_or_null("BlueprintManager")
	var am: Node = root.get_node_or_null("AffixManager")
	# v6.2 修复 M7：非战斗场景（背包/商店查看卡牌）应传 -1 让 build_stats_from_card 用卡牌自身 era，
	# 原强制取 GameManager.current_level 的 era 会导致非战斗场景按错误时代缩放（如看现代卡显示一战数值）
	var era: int = -1
	var gm: Node = root.get_node_or_null("GameManager")
	var bm_node: Node = root.get_node_or_null("BattleManager")
	# 仅在战斗进行中才用当前关卡的 era 缩放
	if bm_node != null and "battle_active" in bm_node and bm_node.battle_active and gm and "current_level" in gm:
		era = GC.get_era_for_level(int(gm.current_level))
	var stats: UnitStats = UnitStatsTable.build_stats_from_card(card, era)
	if bm and bm.has_method("apply_growth_to_stats"):
		bm.apply_growth_to_stats(stats, card, [])
	if am and am.has_method("apply_affixes_to_stats"):
		am.apply_affixes_to_stats(stats, card, [])
	return stats

## v6.4: 词条标签化——把 affix 摘要拆成多个带色点的小标签填入 AffixFlow
func _refresh_affix_tags(card: CardResource) -> void:
	if _affix_flow == null:
		# 回退：用旧 AffixLabel
		if affix_label:
			affix_label.text = _build_card_affix_summary(card) if card.card_type == GC.CardType.COMBAT_UNIT else ""
			affix_label.visible = not affix_label.text.is_empty()
		return
	# 清空旧标签
	for ch in _affix_flow.get_children():
		if is_instance_valid(ch):
			_affix_flow.remove_child(ch)
			ch.queue_free()
	if affix_label:
		affix_label.visible = false
	if card.card_type != GC.CardType.COMBAT_UNIT:
		return
	var tags: Array = _build_affix_tag_list(card)
	if tags.is_empty():
		var empty := Label.new()
		empty.text = "无特殊词条"
		empty.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.7))
		empty.add_theme_font_size_override("font_size", 11)
		_affix_flow.add_child(empty)
		return
	for tag in tags:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var dot := Label.new()
		dot.text = "●"
		dot.add_theme_color_override("font_color", tag.color)
		dot.add_theme_font_size_override("font_size", 11)
		var txt := Label.new()
		txt.text = tag.text
		txt.add_theme_color_override("font_color", Color(0.85, 0.85, 0.92, 1))
		txt.add_theme_font_size_override("font_size", 12)
		row.add_child(dot)
		row.add_child(txt)
		_affix_flow.add_child(row)

func _build_card_affix_summary(card: CardResource) -> String:
	if card.card_type != GC.CardType.COMBAT_UNIT:
		return ""
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return ""
	var root: Node = tree.root
	var mll: Node = root.get_node_or_null("ManagerLazyLoader")
	if mll and mll.has_method("ensure_loaded"):
		mll.ensure_loaded("affix")
	var bm: Node = root.get_node_or_null("BlueprintManager")
	var am: Node = root.get_node_or_null("AffixManager")
	var era: int = 0
	var gm: Node = root.get_node_or_null("GameManager")
	if gm and "current_level" in gm:
		era = GC.get_era_for_level(int(gm.current_level))

	# v5.0: 使用新的 build_stats_from_card 方法，不再检查已弃用的 platform_type
	if card.card_type == GC.CardType.COMBAT_UNIT:
		var stats: UnitStats = UnitStatsTable.build_stats_from_card(card, era)
		if bm and bm.has_method("apply_growth_to_stats"):
			bm.apply_growth_to_stats(stats, card, [])
		if am and am.has_method("apply_affixes_to_stats"):
			am.apply_affixes_to_stats(stats, card, [])
		return _build_affix_summary_lines(stats)
	return ""

func _build_star_lines(card: CardResource) -> String:
	if BlueprintManager == null or not BlueprintManager.has_method("get_star_enhancement_lines"):
		return ""
	var detail_star: int = int(card.enhance_level)
	var lines: Array[String] = BlueprintManager.get_star_enhancement_lines(card.card_id, detail_star)
	if lines.is_empty():
		return "★%d（无加成）" % detail_star
	return "★%d\n- %s" % [detail_star, "\n- ".join(lines)]

func _build_nurture_text(card: CardResource) -> String:
	if card == null or BlueprintManager == null:
		return ""
	var parts: Array[String] = []
	if card.card_type == GC.CardType.COMBAT_UNIT:
		parts.append("强化 Lv.%d" % card.enhance_level)
		var power: int = card.get_current_power() if card.has_method("get_current_power") else 0
		parts.append("战力：%d" % power)
	if BlueprintManager.has_method("get_card_xp_progress"):
		var prog: Dictionary = BlueprintManager.get_card_xp_progress(card.card_id)
		var lvl: int = int(prog.get("level", 1))
		var lv_text: String = "Lv.%d" % lvl
		if BlueprintManager.has_method("get_card_breakthroughs"):
			var bt: int = BlueprintManager.get_card_breakthroughs(card.card_id)
			if bt > 0:
				lv_text += " (突破 %d)" % bt
		parts.append(lv_text)
	if "evolution_stage" in card and str(card.evolution_stage) != "":
		var stage: String = str(card.evolution_stage)
		if not stage.is_empty():
			parts.append("进化 %s" % stage)
	# v6.5: 情报标签下显示已获得改造的具体名称列表
	var mod_list_text: String = ""
	if card.card_type == GC.CardType.COMBAT_UNIT and "mods" in card:
		var mod_names: Array[String] = []
		for mod_entry in card.mods:
			var mod_id: String = ""
			var mod_disabled: bool = false
			if mod_entry is Dictionary:
				mod_id = String(mod_entry.get("id", ""))
				if mod_entry.has("enabled") and not bool(mod_entry.get("enabled", true)):
					mod_disabled = true
			else:
				mod_id = String(mod_entry)
			if not mod_id.is_empty():
				var mod_data: Dictionary = ModificationRegistry.get_data(mod_id)
				var mod_name: String = String(mod_data.get("name", mod_id)) if not mod_data.is_empty() else mod_id
				# v6.5: 禁用的武器改造标注（禁用）
				if mod_disabled:
					mod_name += "（禁用）"
				mod_names.append(mod_name)
		parts.append("改造 %d/9" % mod_names.size())
		if not mod_names.is_empty():
			mod_list_text = "\n已装改造：\n    · " + "\n    · ".join(mod_names)
	# v6.5: 战力星级信息
	var battle_star_text: String = ""
	var bs: int = int(card.battle_star) if "battle_star" in card else 0
	var bsp: float = float(card.battle_star_power) if "battle_star_power" in card else 0.0
	if bs > 0:
		var BattleStarCfg = preload("res://data/battle_star_config.gd")
		var star_display: String = "⭐" + "★".repeat(bs)
		var bonus_text: String = BattleStarCfg.format_stat_bonus_text(card.combat_kind, bs)
		var next_thresh: float = BattleStarCfg.get_next_star_threshold(bs)
		var progress_text: String = ""
		if next_thresh > 0.0:
			progress_text = "\n累计战力 %d / %d" % [int(bsp), int(next_thresh)]
		battle_star_text = "\n战力星级 %s\n    %s%s" % [star_display, bonus_text, progress_text]
	if not parts.is_empty():
		return " · ".join(parts) + mod_list_text + battle_star_text
	return ""

## ── 战场单位显示刷新 ─────────────────────────────────────────

func _refresh_unit_display(unit: Node, is_player: bool) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	# v6.4: 战场单位模式——隐藏图形化三维卡区，恢复纯文本 summary/affix。
	# 注意：不能隐藏整个 _stats_section（summary_label 是其子节点，父节点 visible=false
	# 会使整棵子树不渲染，导致只显示名字、属性 summary 不显示）。改为保持 section 可见，
	# 仅隐藏其内的图形化卡片行，让 summary_label 正常显示。
	if _stats_section:
		_stats_section.visible = true
	if _stat_cards_row:
		_stat_cards_row.visible = false
	if _extra_stat_label:
		_extra_stat_label.visible = false
	if summary_label:
		summary_label.visible = true
	if _affix_flow:
		for ch in _affix_flow.get_children():
			if is_instance_valid(ch):
				_affix_flow.remove_child(ch)
				ch.queue_free()
	if affix_label:
		affix_label.visible = true
	_refresh_rank_badge(unit)
	var is_ally: bool = _resolve_unit_is_player(unit, is_player)
	if unit.is_in_group("enemy_phase_driver"):
		_show_enemy_phase_driver(unit)
	elif is_ally and "stats" in unit:
		_show_player_unit(unit)
	else:
		_show_enemy_unit(unit)
	if status_section:
		status_section.visible = true

func _refresh_rank_badge(unit: Node) -> void:
	if rank_badge_host == null:
		return
	if unit == null or not is_instance_valid(unit) or unit.is_in_group("enemy_phase_driver"):
		RankDisplayUi.clear_host(rank_badge_host)
		rank_badge_host.visible = false
		return
	var info: Dictionary = RankDisplayUi.resolve_from_unit(unit)
	RankDisplayUi.apply_to_host(rank_badge_host, info, 24)
	if info.is_empty():
		return
	var name_lbl: Label = rank_badge_host.get_node_or_null("RankName") as Label
	if name_lbl:
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45, 1))
		name_lbl.add_theme_font_size_override("font_size", 13)
		var power: float = float(info.get("power_score", 0.0))
		if power > 0.0:
			name_lbl.text = "%s（战力 %d）" % [str(info.get("rank_name", "")), int(power)]

func _resolve_unit_is_player(unit: Node, hinted: bool) -> bool:
	if unit == null or not is_instance_valid(unit):
		return hinted
	if unit.is_in_group("player_units") or unit.is_in_group("phase_driver"):
		return true
	if unit.is_in_group("enemy_units") or unit.is_in_group("enemy_phase_driver"):
		return false
	if "is_player" in unit:
		return bool(unit.is_player)
	return hinted

## 判断单位是否为载具类型（装甲/支援/堡垒）
func _is_vehicle_unit(unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	if "stats" in unit:
		var stats: UnitStats = unit.stats
		if stats != null:
			# v5.0: 使用 combat_kind 判断是否为载具类型（装甲/支援/堡垒）
			return stats.combat_kind in [GC.CombatKind.ARMOR, GC.CombatKind.SUPPORT, GC.CombatKind.FORT]
	return true

func _law_targets_this_unit(rt: Dictionary, unit: Node, is_player_side: bool) -> bool:
	var target_side: String = String(rt.get("target_side", "ALLY"))
	if target_side == "ALLY" and not is_player_side:
		return false
	if target_side == "ENEMY" and is_player_side:
		return false
	var target_type: String = String(rt.get("target_type", "ALL"))
	if target_type == "ALL":
		return true
	if target_type == "VEHICLE":
		return _is_vehicle_unit(unit)
	return false

func _format_effect_line(law_name: String, effect: String, value: float, duration: float, radius: float) -> String:
	match effect:
		"armor_buff": return "%s：最大生命 +%d%%" % [law_name, int(value * 100.0)]
		"aegis_link": return "%s：最大生命 +%d%%（护阵联结）" % [law_name, int(value * 100.0)]
		"fortify_protocol": return "%s：最大生命 +%d%%（固壁）" % [law_name, int(value * 100.0)]
		"resonant_plate": return "%s：最大生命 +%d%%（共振）" % [law_name, int(value * 100.0)]
		"regen_out_of_combat": return "%s：脱战回复 %.1f/秒" % [law_name, value]
		"afterburn": return "%s：伤害 +%d%%" % [law_name, int(value * 100.0)]
		"entropy_lens": return "%s：伤害 +%d%%（熵镜）" % [law_name, int(value * 100.0)]
		"arc_beacon": return "%s：攻速提升（约 +%d%%）" % [law_name, int(value * 100.0)]
		"burn_on_hit": return "%s：受击伤害提高（系数 +%.0f%%）" % [law_name, value * 5.0]
		"aoe_emp": return "%s：范围EMP 伤害 %.1f，半径 %.0f，持续 %.1fs" % [law_name, value, radius, duration]
		"line_bombard": return "%s：线性轰炸 伤害 %.1f，长度 %.0f" % [law_name, value, radius]
		"chain_lightning": return "%s：链式放电 总伤害 %.1f，半径 %.0f" % [law_name, value, radius]
		"burn_mark": return "%s：灼烧标记 %.1f/s，持续 %.1fs，半径 %.0f" % [law_name, value, duration, radius]
		"global_time_slow": return "%s：全局时缓 %.0f%%，持续 %.1fs" % [law_name, value * 100.0, duration]
		"spawn_shield_wall": return "%s：护盾墙 减伤 %.0f%%，持续 %.1fs，半径 %.0f" % [law_name, value * 100.0, duration, radius]
		"hp_shield_shift": return "%s：护盾转移 %.0f%%，持续 %.1fs，半径 %.0f" % [law_name, value * 100.0, duration, radius]
		"anchor_field": return "%s：锚定减速 %.0f%%，持续 %.1fs，半径 %.0f" % [law_name, value * 100.0, duration, radius]
		"scorch_wave": return "%s：灼浪伤害 %.1f，半径 %.0f" % [law_name, value, radius]
		"ember_screen": return "%s：灰烬护幕 护盾 %.0f%%，持续 %.1fs，半径 %.0f" % [law_name, value * 100.0, duration, radius]
		"core_rupture": return "%s：核心破裂 伤害 %.1f，半径 %.0f" % [law_name, value, radius]
		"ion_net": return "%s：离子网 减速 %.0f%%，持续 %.1fs，半径 %.0f" % [law_name, value * 100.0, duration, radius]
		"surge_drive": return "%s：激涌驱动 速度/攻速 +%.0f%%，持续 %.1fs" % [law_name, value * 100.0, duration]
		"static_domain": return "%s：静电域 伤害 %.1f，持续 %.1fs，半径 %.0f" % [law_name, value, duration, radius]
		"phase_cloak": return "%s：相位披幕 护盾 %.0f%%，持续 %.1fs，半径 %.0f" % [law_name, value * 100.0, duration, radius]
		"gravity_well": return "%s：引力井 束缚 %.0f%%，持续 %.1fs，半径 %.0f" % [law_name, value * 100.0, duration, radius]
		_: return "%s：效果 %s，数值 %.2f" % [law_name, effect, value]

func _is_construct_unit_script(unit: Node) -> bool:
	var sc: Variant = unit.get_script()
	if sc == null:
		return false
	return String(sc.resource_path).ends_with("construct_unit.gd")

func _format_unit_stats_summary(stats: UnitStats, cur_hp: float = -1.0, extra_suffix: String = "") -> String:
	if stats == null:
		return ""
	var hp_text: String
	if cur_hp >= 0.0:
		hp_text = "HP %d/%d" % [int(cur_hp), int(stats.max_hp)]
	else:
		hp_text = "HP %d" % int(stats.max_hp)
	
	# 获取武器名称
	var weapon_names: Array[String] = ["", "", ""]
	if not stats.weapon_slots.is_empty():
		for i in range(min(stats.weapon_slots.size(), 3)):
			var w = stats.weapon_slots[i]
			if w is WeaponResource and w.enabled:
				weapon_names[i] = w.display_name
	
	var atk_light: float = stats.attack_light if stats.attack_light > 0.001 else 0.0
	var atk_armor: float = stats.attack_armor if stats.attack_armor > 0.001 else 0.0
	var atk_air: float = stats.attack_air if stats.attack_air > 0.001 else 0.0
	var def_light: float = stats.defense_light if stats.defense_light > 0.001 else 0.0
	var def_armor: float = stats.defense_armor if stats.defense_armor > 0.001 else 0.0
	var def_air: float = stats.defense_air if stats.defense_air > 0.001 else 0.0
	var spd_light: float = stats.attack_light_speed if stats.attack_light_speed > 0.001 else 0.0
	var spd_armor: float = stats.attack_armor_speed if stats.attack_armor_speed > 0.001 else 0.0
	var spd_air: float = stats.attack_air_speed if stats.attack_air_speed > 0.001 else 0.0
	
	# 构建攻击部分（包含武器名）
	var atk_part: String
	if weapon_names[0].is_empty() and weapon_names[1].is_empty() and weapon_names[2].is_empty():
		atk_part = "%d/%d/%d" % [int(atk_light), int(atk_armor), int(atk_air)]
	else:
		var a0: String = weapon_names[0] + "%d" % atk_light if not weapon_names[0].is_empty() else "%d" % atk_light
		var a1: String = weapon_names[1] + "%d" % atk_armor if not weapon_names[1].is_empty() else "%d" % atk_armor
		var a2: String = weapon_names[2] + "%d" % atk_air if not weapon_names[2].is_empty() else "%d" % atk_air
		atk_part = "%s/%s/%s" % [a0, a1, a2]

	return "%s｜攻 %s｜防 %d/%d/%d｜射程 %d｜攻速 %.1f/%.1f/%.1f｜移速 %d%s" % [
		hp_text,
		atk_part,
		int(def_light), int(def_armor), int(def_air),
		int(stats.attack_range),
		spd_light, spd_armor, spd_air,
		int(stats.move_speed),
		extra_suffix,
	]

func _build_affix_summary_lines(stats: UnitStats) -> String:
	if stats == null:
		return ""
	var parts: Array[String] = []
	if stats.damage_reduction > 0.001:
		parts.append("减伤 %d%%" % int(stats.damage_reduction * 100.0))
	if stats.dodge_chance > 0.001:
		parts.append("闪避 %d%%" % int(stats.dodge_chance * 100.0))
	if stats.crit_chance > 0.001:
		var cd_total: float = 1.5 + stats.crit_damage_bonus
		parts.append("暴击 %d%%（%.1fx）" % [int(stats.crit_chance * 100.0), cd_total])
	if stats.lifesteal > 0.001:
		parts.append("吸血 %d%%" % int(stats.lifesteal * 100.0))
	if stats.armor_penetration > 0.001:
		parts.append("穿甲 %d%%" % int(stats.armor_penetration * 100.0))
	if stats.splash_damage > 0.001:
		parts.append("溅射 %d%%" % int(stats.splash_damage * 100.0))
	if stats.chain_chance > 0.001:
		parts.append("连锁 %d%%" % int(stats.chain_chance * 100.0))
	if stats.shield_on_kill > 0.001:
		parts.append("击杀护盾 %d%%HP" % int(stats.shield_on_kill * 100.0))
	if stats.hp_regen > 0.001:
		parts.append("每秒回血 %d%%HP" % int(stats.hp_regen * 100.0))
	var mutations: Array[String] = []
	if stats.has_weapon_dmg_mutation: mutations.append("伤害变异")
	if stats.has_weapon_atkspd_mutation: mutations.append("攻速变异")
	if stats.has_crit_mutation: mutations.append("暴击变异")
	if stats.has_lifesteal_mutation: mutations.append("吸血变异")
	if stats.has_hp_regen_mutation: mutations.append("回血变异")
	if stats.has_platform_hp_mutation: mutations.append("HP变异")
	if not mutations.is_empty():
		parts.append("变异：%s" % " · ".join(mutations))
	if parts.is_empty():
		return ""
	return " · ".join(parts)

## v6.4: 词条标签化——返回 [{text, color}] 数组，每个词条带语义色
func _build_affix_tag_list(card: CardResource) -> Array:
	var stats: UnitStats = _build_display_stats(card)
	if stats == null:
		return []
	var tags: Array = []
	var C_DEF := Color(0.3, 0.8, 0.45, 1)    # 减伤/防御类-绿
	var C_DODGE := Color(0.4, 0.85, 0.95, 1)  # 闪避-青
	var C_CRIT := Color(1.0, 0.7, 0.3, 1)     # 暴击-橙
	var C_VAMP := Color(0.85, 0.3, 0.55, 1)   # 吸血-粉红
	var C_PEN := Color(0.7, 0.5, 1, 1)        # 穿甲-紫
	var C_AOE := Color(0.9, 0.6, 0.9, 1)      # 溅射/连锁-粉
	var C_SHIELD := Color(0.5, 0.7, 1, 1)     # 护盾/回血-蓝
	var C_MUT := Color(0.95, 0.82, 0.4, 1)    # 变异-金
	if stats.damage_reduction > 0.001:
		tags.append({text = "减伤 %d%%" % int(stats.damage_reduction * 100.0), color = C_DEF})
	if stats.dodge_chance > 0.001:
		tags.append({text = "闪避 %d%%" % int(stats.dodge_chance * 100.0), color = C_DODGE})
	if stats.crit_chance > 0.001:
		var cd_total: float = 1.5 + stats.crit_damage_bonus
		tags.append({text = "暴击 %d%%（%.1fx）" % [int(stats.crit_chance * 100.0), cd_total], color = C_CRIT})
	if stats.lifesteal > 0.001:
		tags.append({text = "吸血 %d%%" % int(stats.lifesteal * 100.0), color = C_VAMP})
	if stats.armor_penetration > 0.001:
		tags.append({text = "穿甲 %d%%" % int(stats.armor_penetration * 100.0), color = C_PEN})
	if stats.splash_damage > 0.001:
		tags.append({text = "溅射 %d%%" % int(stats.splash_damage * 100.0), color = C_AOE})
	if stats.chain_chance > 0.001:
		tags.append({text = "连锁 %d%%" % int(stats.chain_chance * 100.0), color = C_AOE})
	if stats.shield_on_kill > 0.001:
		tags.append({text = "击杀护盾 %d%%HP" % int(stats.shield_on_kill * 100.0), color = C_SHIELD})
	if stats.hp_regen > 0.001:
		tags.append({text = "每秒回血 %d%%HP" % int(stats.hp_regen * 100.0), color = C_SHIELD})
	var mutations: Array[String] = []
	if stats.has_weapon_dmg_mutation: mutations.append("伤害变异")
	if stats.has_weapon_atkspd_mutation: mutations.append("攻速变异")
	if stats.has_crit_mutation: mutations.append("暴击变异")
	if stats.has_lifesteal_mutation: mutations.append("吸血变异")
	if stats.has_hp_regen_mutation: mutations.append("回血变异")
	if stats.has_platform_hp_mutation: mutations.append("HP变异")
	if not mutations.is_empty():
		tags.append({text = "变异：%s" % " · ".join(mutations), color = C_MUT})
	return tags

func _enemy_surface_combat_stats(unit: Node) -> Array:
	var hp: float = float(unit.get("hp")) if "hp" in unit else 0.0
	var dmg: float = float(unit.get("attack_damage")) if "attack_damage" in unit else 0.0
	var rng: float = float(unit.get("attack_range")) if "attack_range" in unit else 0.0
	var itv: float = float(unit.get("attack_interval")) if "attack_interval" in unit else 1.0
	var def: float = 0.0
	if "stats" in unit and unit.stats != null:
		var st: UnitStats = unit.stats
		if dmg == 0.0: dmg = st.attack_damage
		if rng == 0.0: rng = st.attack_range
		if _is_construct_unit_script(unit):
			itv = st.attack_interval
		def = st.defense
	return [hp, dmg, rng, itv, def]

func _format_enemy_combat_summary(unit: Node, scombat: Array, extra_suffix: String = "") -> String:
	var hp: float = float(scombat[0]) if scombat.size() > 0 else 0.0
	var dmg: float = float(scombat[1]) if scombat.size() > 1 else 0.0
	var rng: float = float(scombat[2]) if scombat.size() > 2 else 0.0
	var itv: float = float(scombat[3]) if scombat.size() > 3 else 1.0
	var def: float = float(scombat[4]) if scombat.size() > 4 else 0.0
	if "stats" in unit and unit.stats != null:
		return _format_unit_stats_summary(unit.stats as UnitStats, hp, extra_suffix)
	return "HP %d｜防 %d｜攻 %d｜射程 %d｜攻速 %.2f%s" % [int(hp), int(def), int(dmg), int(rng), itv, extra_suffix]

## ── 敌方相位驱动器 ──

func _show_enemy_phase_driver(unit: Node) -> void:
	var mname: String = str(unit.get("master_name")) if "master_name" in unit else "相位师"
	if name_label: name_label.text = "敌方相位师基地"
	if type_label: type_label.text = "【%s】· 相位场驱动器" % mname
	var cur_hp: float = float(unit.get("hp")) if "hp" in unit else 0.0
	var mx_hp: float = float(unit.get("max_hp")) if "max_hp" in unit else 1.0
	if summary_label: summary_label.text = "基地 HP %d / %d" % [int(cur_hp), int(mx_hp)]
	var lines: Array[String] = []
	lines.append("摧毁敌方相位场驱动器即可获胜；对方会持续生产战斗单位。")
	if GameManager and GameManager.has_method("get_current_phase_master"):
		var cfg: Dictionary = GameManager.get_current_phase_master()
		if not cfg.is_empty():
			var disp: String = str(cfg.get("name", mname))
			if disp != mname and not disp.is_empty():
				lines.append("档案名：%s" % disp)
			var fac: String = str(cfg.get("faction", ""))
			if not fac.is_empty():
				lines.append("所属势力：%s" % fac)
			var title: String = str(cfg.get("title", ""))
			if not title.is_empty():
				lines.append("称号：%s" % title)
			var eq: Dictionary = cfg.get("equipment", {}) as Dictionary
			var plats: Array = eq.get("platforms", []) as Array
			var weps: Array = eq.get("weapons", []) as Array
			if not plats.is_empty() or not weps.is_empty():
				lines.append("上场装备：平台种类 %d · 武器种类 %d（由其基地持续部署）" % [plats.size(), weps.size()])
	if desc_label: desc_label.text = "\n".join(lines)
	if flavor_label: flavor_label.text = "“相位师的意志锚定在这片场上。”"
	_clear_non_summary_info_sections()

func _clear_non_summary_info_sections() -> void:
	if affix_label: affix_label.text = ""
	if _star_detail_label: _star_detail_label.text = ""
	if law_label: law_label.text = ""
	if nurture_label: nurture_label.text = ""

## v6.5: 构建武器名标签文本。
## 优先级：card.weapon_names[]（具体型号）> weapon_id 名称 > 战斗方式（直射/曲射等）
func _build_weapon_label_text(card_res: CardResource, stats: UnitStats) -> String:
	# 1. 优先：卡牌的 weapon_names[] 具体武器型号（最准确）
	if card_res != null and "weapon_names" in card_res:
		var wnames: Array = []
		for wn in card_res.weapon_names:
			var ws: String = String(wn)
			if not ws.is_empty() and not wnames.has(ws):
				wnames.append(ws)
		if wnames.size() > 0:
			return " / ".join(wnames)
	# 2. 次选：从 stats.weapons 的 weapon_id 查具体名称
	if stats != null and stats.weapons.size() > 0:
		var wnames: Array = []
		for w in stats.weapons:
			if not (w is Dictionary):
				continue
			var cfg: Dictionary = w
			if cfg.has("weapon_id"):
				var wid: String = String(cfg["weapon_id"])
				var wn: String = DefaultCards.get_safe_display_name(wid)
				if not wn.is_empty() and not wnames.has(wn):
					wnames.append(wn)
		if wnames.size() > 0:
			return " / ".join(wnames)
	# 3. 兜底：战斗方式描述（直射武器/曲射武器/空射武器/支援设备）
	if stats != null:
		return DefaultCards.get_weapon_display_name(stats.weapon_type)
	return ""

## ── 敌方构装单位 ──

func _show_enemy_construct_unit(unit: Node) -> void:
	var stats: UnitStats = unit.stats
	var card_res: CardResource = DefaultCards.get_card_by_id(stats.platform_card_id)
	var safe_name := DefaultCards.get_safe_display_name(stats.platform_card_id)
	var dn := DefaultCards.safe_name(card_res)
	if name_label:
		name_label.text = dn if not dn.is_empty() else (safe_name if not safe_name.is_empty() else "敌方构装单位")
	var platform_name := dn if not dn.is_empty() else (safe_name if not safe_name.is_empty() else DefaultCards.get_platform_display_name(stats.platform_type))
	# v6.5: 优先用 card.weapon_names[] 显示具体武器型号，而非笼统的战斗方式
	var weapon_label_text: String = _build_weapon_label_text(card_res, stats)
	if type_label:
		type_label.text = "相位师部署 · %s / %s" % [platform_name, weapon_label_text]
	var cur_hp: float = float(unit.get("hp")) if "hp" in unit else stats.max_hp
	if summary_label:
		summary_label.text = _format_unit_stats_summary(stats, cur_hp)
	var base_desc := "由敌方相位师基地生产的构装单位，自动推进并攻击我方。"
	if affix_label:
		affix_label.text = _build_affix_summary_lines(stats)
	if _star_detail_label:
		_star_detail_label.text = _build_star_enhancement_effects_for_stats(stats)
	if law_label:
		law_label.text = _build_phase_law_effects_for_unit(unit, false)
	if desc_label:
		desc_label.text = base_desc
	if flavor_label:
		flavor_label.text = "“同一套装甲，站在战场的另一侧。”"

## ── 我方单位 ──

func _show_player_unit(unit: Node) -> void:
	var stats: UnitStats = unit.stats
	var card_res: CardResource = DefaultCards.get_card_by_id(stats.platform_card_id)
	var safe_name := DefaultCards.get_safe_display_name(stats.platform_card_id)
	var dn := DefaultCards.safe_name(card_res)
	if name_label:
		name_label.text = dn if not dn.is_empty() else (safe_name if not safe_name.is_empty() else "我方单位")
	var platform_name := dn if not dn.is_empty() else (safe_name if not safe_name.is_empty() else DefaultCards.get_platform_display_name(stats.platform_type))
	# v6.5: 优先用 card.weapon_names[] 显示具体武器型号
	var weapon_label_text: String = _build_weapon_label_text(card_res, stats)
	if type_label:
		type_label.text = "%s / %s" % [platform_name, weapon_label_text]
	if summary_label:
		summary_label.text = _format_unit_stats_summary(stats)
	if affix_label:
		affix_label.text = _build_affix_summary_lines(stats)
	if _star_detail_label:
		_star_detail_label.text = _build_star_enhancement_effects_for_stats(stats)
	if law_label:
		law_label.text = _build_phase_law_effects_for_unit(unit, true)
	if desc_label:
		desc_label.text = "自动向敌侧推进，在射程内交战。选中后可点击地面微调站位。"
	if flavor_label:
		flavor_label.text = "“装甲军团永不疲倦。”"

## ── 敌方单位 ──

func _show_enemy_unit(unit: Node) -> void:
	var is_phase_master: bool = false
	var master_name: String = ""
	if "archetype_id" in unit and unit.archetype_id is String:
		if unit.archetype_id.begins_with("phase_master_"):
			is_phase_master = true
			master_name = unit.archetype_id.substr(13)
	if is_phase_master:
		_show_enemy_phase_master_unit(unit, master_name)
	elif _is_construct_unit_script(unit) and "stats" in unit and unit.stats != null:
		_show_enemy_construct_unit(unit)
	else:
		_show_generic_enemy_unit(unit)

func _show_enemy_phase_master_unit(unit: Node, master_name: String) -> void:
	var master_cfg: Dictionary = {}
	var master_disp_name: String = ""
	var master_title: String = ""
	var master_level: int = 0
	var master_faction: String = ""
	var trait_lines: Array[String] = []
	if GameManager and GameManager.has_method("get_current_phase_master"):
		master_cfg = GameManager.get_current_phase_master()
	if master_cfg.is_empty():
		var pm_id := "enemy_master_" + master_name.replace("unit_", "").lstrip("0")
		master_cfg = EnemyPhaseMasters.get_master_by_id(pm_id)
	if not master_cfg.is_empty():
		master_disp_name = str(master_cfg.get("name", ""))
		master_title = str(master_cfg.get("title", ""))
		master_level = int(master_cfg.get("level", 0))
		master_faction = str(master_cfg.get("faction", ""))
		var traits: Array = master_cfg.get("traits", []) as Array
		for t in traits:
			if t is Dictionary:
				var tn: String = str(t.get("name", ""))
				var td: String = str(t.get("description", ""))
				if not tn.is_empty():
					if not td.is_empty():
						trait_lines.append("◆ %s：%s" % [tn, td])
					else:
						trait_lines.append("◆ %s" % tn)
	if name_label:
		name_label.text = master_disp_name if not master_disp_name.is_empty() else "敌方相位师"
	var type_parts: Array[String] = []
	if not master_title.is_empty(): type_parts.append(master_title)
	if master_level > 0: type_parts.append("Lv.%d" % master_level)
	var faction_names := {"steel": "钢铁", "thunder": "雷霆", "frost": "霜寒", "void": "虚空", "shadow": "暗影", "inferno": "炼狱"}
	if not master_faction.is_empty():
		type_parts.append(faction_names.get(master_faction, master_faction))
	var type_text := " · ".join(type_parts)
	if type_text.is_empty():
		type_text = "【未知相位师】"
	else:
		type_text = "【%s】%s" % [master_disp_name if not master_disp_name.is_empty() else "相位师", type_text]
	var platform_name := "未知平台"
	var stats: UnitStats = unit.stats if "stats" in unit else null
	var pm_safe_name := DefaultCards.get_safe_display_name(stats.platform_card_id if stats else "")
	var pm_card_res: CardResource = DefaultCards.get_card_by_id(stats.platform_card_id) if stats else null
	var pm_dn := DefaultCards.safe_name(pm_card_res) if pm_card_res != null else ""
	if not pm_dn.is_empty():
		platform_name = pm_dn
	elif not pm_safe_name.is_empty():
		platform_name = pm_safe_name
	else:
		platform_name = DefaultCards.get_platform_display_name(stats.platform_type) if stats else platform_name
	# v6.5: 优先用 card.weapon_names[] 显示具体武器型号
	var weapon_label_text: String = _build_weapon_label_text(pm_card_res, stats)
	if weapon_label_text.is_empty():
		weapon_label_text = "未知武器"
	if type_label:
		type_label.text = "%s\n%s / %s" % [type_text, platform_name, weapon_label_text]
	var scombat: Array = _enemy_surface_combat_stats(unit)
	if summary_label:
		summary_label.text = _format_enemy_combat_summary(unit, scombat)
	var base_desc := "敌方相位师单位，拥有强大的战斗力。"
	if not trait_lines.is_empty():
		base_desc += "\n\n【相位师特性】\n" + "\n".join(trait_lines)
	if law_label:
		var passive := _build_phase_law_effects_for_unit(unit, false)
		var active := _build_active_law_effects_for_unit(unit, false)
		var law_text := ""
		if not passive.is_empty():
			law_text += "【被动法则影响】\n" + passive
		if not active.is_empty():
			if not law_text.is_empty(): law_text += "\n\n"
			law_text += "【敌方被动法则】\n" + active
		law_label.text = law_text
	if desc_label:
		desc_label.text = base_desc
	if flavor_label:
		flavor_label.text = "“相位师的威严不容侵犯。”"
	_clear_other_unit_sections()

func _clear_other_unit_sections() -> void:
	if affix_label: affix_label.text = ""
	if _star_detail_label: _star_detail_label.text = ""
	if nurture_label: nurture_label.text = ""

func _show_generic_enemy_unit(unit: Node) -> void:
	var display_name := "敌方单位"
	var type_text := "敌方单位"
	var era_text := ""
	var tags_text := ""
	var speed_val: float = 0.0
	var weapon_type_val: int = -1
	var attack_damage_val: float = 0.0
	if "archetype_id" in unit and unit.archetype_id is String:
		var cfg = EnemyArchetypes.get_config(unit.archetype_id)
		if not cfg.is_empty():
			type_text = cfg.get("display_name", type_text)
			display_name = type_text
			era_text = str(cfg.get("era", ""))
			speed_val = float(cfg.get("speed", 0.0))
			weapon_type_val = int(cfg.get("weapon_type", -1))
			attack_damage_val = float(cfg.get("attack_damage", 0.0))
			var tags: Array = cfg.get("tags", []) as Array
			if not tags.is_empty():
				var tag_names: Array = []
				for t in tags:
					var ts: String = str(t)
					match ts:
						"infantry": tag_names.append("步兵")
						"vehicle": tag_names.append("载具")
						"turret": tag_names.append("炮塔")
						"sustained": tag_names.append("持续射击")
						"frontline": tag_names.append("前排")
						"backline": tag_names.append("后排")
						"fast": tag_names.append("高速")
						"heavy": tag_names.append("重型")
						"elite": tag_names.append("精英")
						"boss": tag_names.append("Boss")
						"armored": tag_names.append("装甲")
						"artillery": tag_names.append("火炮")
						"support": tag_names.append("支援")
						"swarm": tag_names.append("蜂群")
						_: tag_names.append(ts)
				tags_text = " · ".join(tag_names)
	if "wave_index" in unit:
		type_text += " · 波次 %d" % unit.wave_index
	var era_names := ["一战", "二战", "冷战", "现代", "近未来"]
	if not era_text.is_empty():
		var ei: int = int(era_text)
		if ei >= 0 and ei < era_names.size():
			type_text += " · %s" % era_names[ei]
	if not tags_text.is_empty():
		type_text += "\n类型：%s" % tags_text
	# v6.2c: 武装显示——有武器给具体名字，没武器显示"无"
	# 敌方原型的 weapon_type 是旧 12 值 WeaponTypeLegacy，必须用 weapon_kind_short 查表
	# 判断"有没有武器"：weapon_type >= 0 且 attack_damage > 0
	if weapon_type_val >= 0 and attack_damage_val > 0.0:
		type_text += "\n武装：%s" % RealWorldUnitLabels.weapon_kind_short(weapon_type_val)
	else:
		type_text += "\n武装：无"
	if type_label: type_label.text = type_text
	if name_label: name_label.text = display_name
	var s2: Array = _enemy_surface_combat_stats(unit)
	var speed_display: float = float(unit.get("speed")) if "speed" in unit else speed_val
	var speed_text: String = ""
	if speed_display < -0.1:
			speed_text = "｜移速 %d" % int(absf(speed_display))
	elif speed_display > 0.1:
			speed_text = "｜移速 %d" % int(speed_display)
	if summary_label:
		summary_label.text = _format_enemy_combat_summary(unit, s2, speed_text)
	if desc_label:
		desc_label.text = "向左推进的敌方单位，会优先攻击我方单位，其次攻击相位场驱动器。"
	if "stats" in unit and unit.stats != null:
		if affix_label: affix_label.text = _build_affix_summary_lines(unit.stats)
	if law_label:
		law_label.text = _build_phase_law_effects_for_unit(unit, false)
	if flavor_label:
		flavor_label.text = "“相位裂隙的另一侧，总有人在看着你。”"
	if _star_detail_label: _star_detail_label.text = ""
	if nurture_label: nurture_label.text = ""

## ── 法则效果构建 ──

func _build_phase_law_effects_for_unit(unit: Node, is_player_side: bool) -> String:
	var plm := _ensure_plm()
	if not plm or not ("equipped_passive_laws" in plm):
		return ""
	var law_ids: Array = plm.equipped_passive_laws
	if law_ids.is_empty():
		return ""
	var lines: Array[String] = []
	for law_id in law_ids:
		var cfg: Dictionary = PhaseLaws.get_by_id(String(law_id))
		if cfg.is_empty(): continue
		var rt: Dictionary = cfg.get("runtime_tags", {})
		if rt.is_empty(): continue
		var affects_unit: bool = _law_targets_this_unit(rt, unit, is_player_side)
		if not affects_unit: continue
		var effect: String = String(rt.get("effect", ""))
		var value: float = float(rt.get("value", 0.0))
		var duration: float = float(rt.get("duration", 0.0))
		var radius: float = float(rt.get("radius", 0.0))
		var law_name: String = String(cfg.get("name", law_id))
		lines.append(_format_effect_line(law_name, effect, value, duration, radius))
	return "\n".join(lines)

func _build_active_law_effects_for_unit(unit: Node, is_player_side: bool) -> String:
	var plm := _ensure_plm()
	if not plm or not ("equipped_active_laws" in plm):
		return ""
	var law_ids: Array = plm.equipped_active_laws
	if law_ids.is_empty():
		return ""
	var lines: Array[String] = []
	for law_id in law_ids:
		var cfg: Dictionary = PhaseLaws.get_by_id(String(law_id))
		if cfg.is_empty(): continue
		var rt: Dictionary = cfg.get("runtime_tags", {})
		var affects_unit: bool = _law_targets_this_unit(rt, unit, is_player_side)
		if not affects_unit: continue
		var law_name: String = String(cfg.get("name", law_id))
		var desc: String = String(cfg.get("description", ""))
		var cost: Dictionary = cfg.get("battle_cost", {})
		var nano_cost: int = int(cost.get("nano", 0))
		var energy_cost: float = float(cost.get("energy", 0))
		var value: float = float(rt.get("value", 0.0))
		var duration: float = float(rt.get("duration", 0.0))
		var radius: float = float(rt.get("radius", 0.0))
		var line := _format_effect_line(law_name, String(rt.get("effect", "")), value, duration, radius)
		if nano_cost > 0: line += " (消耗%d纳米)" % nano_cost
		if energy_cost > 0: line += " (消耗%d能量)" % int(energy_cost)
		if not desc.is_empty(): line += "：%s" % desc
		lines.append(line)
	return "\n".join(lines)

func _build_star_enhancement_effects_for_stats(stats: UnitStats) -> String:
	# v5.1: star_level system removed
	return ""
