extends PanelContainer

const DesignTokens = preload("res://resources/design_tokens.gd")
## 统一情报面板：背包/相位仪/战场共用
## 4 Tab：情报 / 强化 / 改造 / 进化
## 模式：
##   MODE_BACKPACK(0)         → 装备按钮（背包场景；拆解已随蓝图体系移除）
##   MODE_PHASE_INSTRUMENT(1) → 卸下按钮（相位仪槽位）
##   MODE_BATTLEFIELD(2)      → 无操作按钮（战场点击，仅情报 Tab）

signal action_requested(action: String, card: CardResource)

enum PanelMode { MODE_BACKPACK = 0, MODE_PHASE_INSTRUMENT = 1, MODE_BATTLEFIELD = 2 }
enum TabIdx { INFO = 0, REINFORCE = 1, MODIFY = 2, EVOLVE = 3 }

const GC = preload("res://resources/game_constants.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const BattleExperienceConfig = preload("res://data/battle_experience_config.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")
const MasterPowerEvaluator = preload("res://scripts/master_power_evaluator.gd")
const MasterPlayerAssembler = preload("res://scripts/master_player_assembler.gd")
const RuneDefs = preload("res://data/runes.gd")
const RunewordDefs = preload("res://data/runewords.gd")
const RunewordMatcher = preload("res://managers/runeword_matcher.gd")
const EnemyPhaseEquipment = preload("res://data/enemy_phase_equipment.gd")
# v18 四源重构: 技能树/势力树/专属相位仪真身（敌方加成来源展示）
const EnemyMasterSkillTree = preload("res://data/enemy_master_skill_tree.gd")
const EnemyFactionSkills = preload("res://data/enemy_faction_skills.gd")
const EnemyMasterInstruments = preload("res://data/enemy_master_instruments.gd")
const CardGrowthConfig = preload("res://data/card_growth_config.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const BackpackCombatPreview = preload("res://scenes/ui/backpack_combat_preview.gd")
const RankDisplayUi = preload("res://scripts/rank_display_ui.gd")
const ModifyPanelScene = preload("res://scenes/ui/modification_panel.tscn")
const EvolvePanelScene = preload("res://scenes/ui/evolution_panel.tscn")
const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")
const ModEffectLabels = preload("res://scripts/ui/mod_effect_labels.gd")
const AuraData = preload("res://data/aura_data.gd")
const EvolutionHelpers = preload("res://managers/evolution/evolution_helpers.gd")
const ModEffects = preload("res://data/mod_effects.gd")  # v7.x: MAX_MOD_SLOTS 槽位上限权威源
const CardPeriodicSkills = preload("res://data/card_periodic_skills.gd")  # 卡片定时技能（关联技能显示）
const PowerTiers = preload("res://data/power_tiers.gd")
const UnifiedCardTable = preload("res://data/unified_card_table.gd")  # v20.13c: 每卡部署次数口径

var current_card: CardResource = null
var _current_unit: Node = null
var _current_mode: int = PanelMode.MODE_BACKPACK
var _status_refresh_accum: float = 0.0  ## v9.x 当前状态区低频刷新累加器（仅战场单位模式）
var _context_data: Dictionary = {}
# v7.3 性能优化：单次 show_card_info 内复用的 UnitStats 缓存。
# 原 _refresh_stat_cards 和 _build_affix_tag_list 各自调 _build_display_stats（含 build_stats_from_card 重操作），
# 一次点卡跑2遍。改为 _refresh_info_sections 顶部构建一次，子函数共用。
var _cached_display_stats: UnitStats = null
var _cached_display_stats_key: String = ""

# 节点引用
var action_buttons_container: HBoxContainer = null
var close_button: Button = null
var name_label: Label = null
var type_label: Label = null
var tier_label: Label = null
var summary_label: Label = null
var affix_label: Label = null
var star_label: Label = null
var _star_detail_label: Label = null
var _star_section: PanelContainer = null
var _nurture_section: PanelContainer = null
var nurture_label: Label = null
# 关联卡片技能显示段（该卡作为 source_tag 触发源的已解锁卡片定时技能）
var _card_skill_section: PanelContainer = null
var _card_skill_label: Label = null
# v7.x(敌方加成来源明细): 敌方单位"为什么这么强"的加成来源 section
var _bonus_section: PanelContainer = null
var _bonus_label: Label = null
var status_label: RichTextLabel = null
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

# 子面板实例（懒加载；v20.12 强化①面板退役，_reinforce_instance 已移除）
var _modify_instance: Control = null
var _evolve_instance: Control = null
# 子面板按需刷新：标记哪个子面板数据已变（用户切到对应 Tab 时才真正刷新，避免点卡时同步刷 3 个）
var _sub_panel_dirty: Dictionary = {}
var _info_tab_changed_connected: bool = false

const ERA_NAMES := ["一战", "二战", "冷战", "现代", "近未来"]
# 稀有度色统一走 GC.get_rarity_color（全项目唯一权威源，v7.x 界面一致性修复）。
# 原本地字典 RARITY_COLORS legendary 为粉色(1.0,0.6,0.9)，与 GC 琥珀色冲突导致同一张传说卡不同面板显色不同；已删除本地字典，两处 header 色带改用 GC.get_rarity_color。
const RARITY_DISPLAY := {
	"common": "普通", "uncommon": "优秀", "rare": "稀有",
	"epic": "史诗", "legendary": "传说", "mythic": "神话",
}

# v9.x（P2-7范围B）：_plm/_ensure_plm 已随 PhaseLawManager 退役移除

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
	tier_label = get_node_or_null("Margin/VBox/TierLabel") as Label
	rank_badge_host = get_node_or_null("Margin/VBox/RankBadgeHost") as HBoxContainer
	_tab_container = get_node_or_null("Margin/VBox/TabBar") as TabContainer
	# 子面板按需刷新：连接 tab_changed，切到强化/改造/进化 Tab 时才刷新对应子面板
	if _tab_container and not _info_tab_changed_connected:
		_tab_container.tab_changed.connect(_on_info_tab_changed)
		_info_tab_changed_connected = true
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
	_star_section = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/StarSection") as PanelContainer
	_nurture_section = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/NurtureSection") as PanelContainer
	nurture_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/NurtureSection/NurtureVBox/NurtureLabel") as Label
	_card_skill_section = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/CardSkillSection") as PanelContainer
	_card_skill_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/CardSkillSection/CardSkillVBox/CardSkillLabel") as Label
	# v7.x(敌方加成来源明细): 加成来源 section 节点连接
	_bonus_section = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/BonusSection") as PanelContainer
	_bonus_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/BonusSection/BonusVBox/BonusLabel") as Label
	status_section = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/StatusSection") as PanelContainer
	status_label = get_node_or_null("Margin/VBox/TabBar/TabInfo/InfoVBox/StatusSection/StatusVBox/StatusLabel") as RichTextLabel
	# v9.x 当前状态区用 BBCode 渲染彩色 [正面]/[负面] 标记
	if status_label:
		status_label.bbcode_enabled = true
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
	# 批次三 B2e：Tab 悬停就地解释（强化 Tab 恒隐藏，tooltip 仅作兜底无害）
	_tab_container.set_tab_tooltip(TabIdx.INFO, "卡牌/单位的详细属性、词条与说明")
	_tab_container.set_tab_tooltip(TabIdx.MODIFY, "为这张卡安装/调整改造模块（最多 9 格，只影响本实例）")
	_tab_container.set_tab_tooltip(TabIdx.EVOLVE, "查看进化路线与条件，满足后变为全新卡牌")
	_hide_all_sub_tabs()
	# 批次三 B2e：头部与三维攻防卡 tooltip（新玩家最常困惑的数值语义）
	if star_label:
		star_label.tooltip_text = "光环/能力星级：由卡牌等级折算（每 3 级 = 1 星，Lv30 满星 10★）"
	if rarity_label:
		rarity_label.tooltip_text = "稀有度：普通/优秀/稀有/史诗/传说/神话，影响基础属性与掉落概率"
	if cost_label:
		cost_label.tooltip_text = "部署能耗：战斗中放置该单位消耗的能量（按战力定价 4~15 点）"
	if _hp_value_label:
		_hp_value_label.tooltip_text = "耐久（HP）：归零即被摧毁"
	if _atk_value_label:
		_atk_value_label.tooltip_text = "攻击：对轻装/装甲/空中三类目标分别有独立伤害值"
	if _def_value_label:
		_def_value_label.tooltip_text = "防御：对轻装/装甲/空中三类攻击分别有独立减免"

func _setup_action_buttons_container() -> void:
	if action_buttons_container:
		action_buttons_container.visible = false

## ── 公共接口 ──────────────────────────────────────────────────

## P0: ESC 关闭详情面板——原实现无 ESC 处理，战场模式按 ESC 会切换暂停而非关弹窗。
## 守卫：更高层 PopupLayer(100) 有 overlay 打开时让位（ESC 应先关最上层）；
## 背包内嵌实例随背包 overlay 一起关闭，不抢事件。consume 防止穿透。
func _input(event: InputEvent) -> void:
	if not (visible and event.is_action_pressed("ui_cancel")):
		return
	var popup_layer := get_node_or_null("/root/Main/PopupLayer")
	if popup_layer != null:
		for child in popup_layer.get_children():
			if child is CanvasLayer:
				for cc in child.get_children():
					if cc is Control and cc.visible:
						return
			elif child is Control and child.visible:
				return
	hide_panel()
	get_viewport().set_input_as_handled()

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
	# v7.x 修复头部残留：战场单位模式入口统一清空卡牌模式遗留的星级/稀有度/费用三标签 + 色带。
	# 根因：同一面板实例复用于卡牌模式和战场单位模式，卡牌模式 _refresh_header 和我方单位 _show_player_unit
	# 会设置这三项；敌方 5 个显示函数（_show_enemy_phase_driver/_show_player_phase_driver/_show_enemy_construct_unit/
	# _show_enemy_phase_master_unit/_show_generic_enemy_unit）全部不碰它们，导致从卡牌模式切到敌方单位时
	# 头部残留上次卡牌的 ★5/传说/50⚡。入口统一清理后，敌方单位不设值即默认清空；我方单位 _show_player_unit
	# 会重设这三项，不受影响。
	_clear_header_rarity_extras()
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
		# v20.12 等级统一：强化① Tab 退役（强化等级轴 enhance_level 已废，
		# 唯一等级轴为战斗卡等级 card_level，上阵攒经验自动升级）。Tab 恒隐藏，
		# TabIdx.REINFORCE 枚举与 tscn 节点保留（占位保 TabContainer 索引不错位）。
		_tab_container.set_tab_hidden(TabIdx.MODIFY, false)
		_tab_container.set_tab_hidden(TabIdx.EVOLVE, false)

func _apply_unit_tab_visibility() -> void:
	if _tab_container == null:
		return
	_hide_all_sub_tabs()

## ── 子面板懒加载 ──────────────────────────────────────────────

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
	# 按需刷新：不再点卡时同步刷 3 个子面板，改为标记 dirty，
	# 等用户切到对应 Tab 时（_on_info_tab_changed）才真正实例化+刷新。
	# 点卡后默认停在情报 Tab（show_card_info 末尾 current_tab = INFO），用户看不到子面板无需刷。
	_sub_panel_dirty[TabIdx.MODIFY] = true
	_sub_panel_dirty[TabIdx.EVOLVE] = true

## 用户切换 Tab 时按需刷新对应子面板（首次也在此实例化，避免点卡首帧 instantiate 3 个 .tscn）
func _on_info_tab_changed(tab_index: int) -> void:
	if current_card == null:
		return
	match tab_index:
		TabIdx.MODIFY:
			_ensure_modify_instance()
			if _modify_instance and _modify_instance.has_method("set_selected_card"):
				_modify_instance.set_selected_card(current_card)
			_sub_panel_dirty[TabIdx.MODIFY] = false
		TabIdx.EVOLVE:
			_ensure_evolve_instance()
			if _evolve_instance and _evolve_instance.has_method("set_selected_card"):
				_evolve_instance.set_selected_card(current_card)
			_sub_panel_dirty[TabIdx.EVOLVE] = false

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
			pass  # v9.x（P2-7范围A）：法则卡"装备到相位仪"入口随法则卡链路退役移除
		PanelMode.MODE_PHASE_INSTRUMENT:
			_add_action_button("卸下此卡", Color(0.9, 0.4, 0.4, 1), "unequip", "将这张卡从相位仪槽位移除，返还背包（不会丢失养成数据）")

func _add_action_button(text: String, color: Color, action: String, tooltip: String = "") -> void:
	if action_buttons_container == null:
		return
	var btn := Button.new()
	btn.name = action.capitalize().replace(" ", "") + "Button"
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 38)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", DesignTokens.COLOR_HOVER_WHITE)
	# 批次三 B2e：操作按钮就地解释后果
	if not tooltip.is_empty():
		btn.tooltip_text = tooltip
	# 批次三 B6：手写三态样式收口 PanelStyles 工厂（原缺 disabled/focus 两态）
	var styles: Dictionary = PanelStyles.make_button_styles(color)
	btn.add_theme_stylebox_override("normal", styles["normal"])
	btn.add_theme_stylebox_override("hover", styles["hover"])
	btn.add_theme_stylebox_override("pressed", styles["pressed"])
	btn.add_theme_stylebox_override("disabled", styles["disabled"])
	btn.add_theme_stylebox_override("focus", styles["focus"])
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
	var band_color: Color = GC.get_rarity_color(rarity_key)
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

## v7.x 修复：清空头部星级/稀有度/费用三标签 + 移除稀有度色带 override。
## 用于战场单位模式入口（show_unit_info），消除从卡牌模式切到敌方单位时的头部残留。
## 我方单位 _show_player_unit 随后会重设这三项，敌方单位保持清空状态。
func _clear_header_rarity_extras() -> void:
	if star_label:
		star_label.text = ""
	if rarity_label:
		rarity_label.text = ""
	if cost_label:
		cost_label.text = ""
	# 移除 HeaderPanel 的稀有度色带 override，恢复 tscn 默认样式
	var header := get_node_or_null("Margin/VBox/HeaderPanel") as PanelContainer
	if header:
		header.remove_theme_stylebox_override("panel")

## v7.x 修复：刷新稀有度色带 + 标签（文本/颜色）。
## 卡牌模式(_refresh_header)与战场单位模式(_show_player_unit)共用，
## 避免战场单位漏刷 rarity_label 导致"相位仪显示稀有、战场显示普通"的残留 bug。
func _apply_header_rarity_for_card(card: CardResource) -> void:
	if card == null:
		return
	var r_key: String = card.rarity if card.rarity else "common"
	_apply_header_rarity_band(r_key)
	if rarity_label:
		rarity_label.text = RARITY_DISPLAY.get(r_key, r_key)
		rarity_label.add_theme_color_override("font_color", GC.get_rarity_color(r_key))

func _refresh_header(card: CardResource) -> void:
	if rank_badge_host:
		RankDisplayUi.clear_host(rank_badge_host)
		rank_badge_host.visible = false
	if name_label:
		# v7.x：同名卡追加序号后缀（#1/#2…），区分同名实例
		var _hdr_name: String = card.display_name if not card.display_name.is_empty() else DefaultCards.get_safe_display_name(card.card_id)
		name_label.text = _hdr_name + DefaultCards.seq_suffix(card)
	# v19: 头部等级（三十级制 card_level，Lv1-30；与血条等级文字同口径）——仅战斗卡显示
	if star_label:
		star_label.text = ("Lv%d" % _card_level_for_display(card)) if card.card_type == GC.CardType.COMBAT_UNIT else ""
	# v6.4: 稀有度色带——染色 HeaderPanel 左侧边框
	_apply_header_rarity_for_card(card)
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
				# v20: 档位徽标（tier 可见性）——仅战斗卡展示
				if tier_label != null:
					var _t: int = clampi(int(card.tier), 0, 6)
					tier_label.text = PowerTiers.get_tier_name(_t)
					tier_label.visible = _t > 0
			GC.CardType.ENERGY:
				type_label.text = "能量卡 · 提供 %d 能量" % int(card.energy_cost)
			_:
				# v9.x（P2-7范围B）：法则卡类型标签分支已随法则系统退役移除
				type_label.text = card.type_line

## ── 情报 Tab 内容刷新 ──────────────────────────────────────────

func _refresh_info_sections(card: CardResource) -> void:
	if card == null:
		return
	# v7.x：卡牌模式恢复所有 section 可见性（战场单位模式可能 visible=false 残留）
	if _star_section: _star_section.visible = true
	if _nurture_section: _nurture_section.visible = true
	if _card_skill_section: _card_skill_section.visible = true
	# v7.x(敌方加成来源明细): 卡牌模式不显示战场加成来源（那是敌方单位专属），确保隐藏
	if _bonus_section: _bonus_section.visible = false
	if _bonus_label: _bonus_label.text = ""
	# v7.3 性能优化：顶部构建一次 UnitStats 缓存，子函数共用（原各调一次 _build_display_stats = build_stats_from_card 跑2遍）
	_prepare_display_stats_cache(card)
	# v6.4: 三维攻防——图形化三列数值卡
	_refresh_stat_cards(card)
	# 词条（标签化）
	_refresh_affix_tags(card)
	# 星级强化详情（情报 Tab 内，非头部星级）
	if _star_detail_label:
		_star_detail_label.text = _build_star_lines(card)
	# 养成摘要
	if nurture_label:
		var _nurture: String = _build_nurture_text(card)
		# v7.x：tags 定位标签（战斗卡）+ 部署后光环预览（无战场 unit 时从 platform_type 反推）
		var _tags_cn: String = _format_tags_cn(card.tags) if "tags" in card else ""
		if not _tags_cn.is_empty() and card.card_type == GC.CardType.COMBAT_UNIT:
			_nurture = "定位：%s\n" % _tags_cn + _nurture
		# v8.x：兵种机制描述（STALKER隐身/SNIPER首击/ECM光环/ENGINEER 等）
		# v7.x 修复：card.tags 字段在数据层从不填充（default_cards.gd 0 个 .tags= 赋值），
		# _format_unit_mechanism_cn(card.tags) 恒返回空。改为优先读 _cached_display_stats 的
		# is_stalker/is_sniper/is_ecm/is_engineer meta（由 _apply_v8_unit_type_meta 通过 card_id
		# 前缀打标，是兵种特性真实生效路径），字面量 tags 作兜底。
		var _mech_desc: String = _format_unit_mechanism_from_stats(_cached_display_stats)
		if _mech_desc.is_empty() and "tags" in card:
			_mech_desc = _format_unit_mechanism_cn(card.tags)
		if not _mech_desc.is_empty():
			_nurture = "兵种机制：%s\n" % _mech_desc + _nurture
		_nurture += _build_aura_preview_text(card, _cached_display_stats)
		nurture_label.text = _nurture
	# 关联卡片技能（source_tag 命中该卡 + 已解锁）
	_refresh_card_skill_section(card)
	# 描述
	if desc_label:
		desc_label.text = card.description
	# 风味
	if flavor_label:
		flavor_label.text = card.flavor_text
	# 隐藏战场专用状态区
	if status_section:
		status_section.visible = false

## 显示该卡作为 source_tag 触发源关联的、已解锁的卡片定时技能。
## 数据源：override_stats（战场单位模式传 unit.stats）或 _cached_display_stats（卡牌查看模式，已含 law_family meta，与单位侧同源）。
## 仅显示已解锁且 source_tag 命中本卡的技能；空 source_tag 技能（cps_steel_storm）无特定触发源不显示。
func _refresh_card_skill_section(card: CardResource, override_stats: UnitStats = null) -> void:
	if _card_skill_label == null:
		return
	var lines: Array[String] = []
	# 战场单位模式：优先用传入的 unit.stats（已含全部 meta）；卡牌查看模式：用 _cached_display_stats
	var stats_for_tags: UnitStats = override_stats if override_stats != null else _cached_display_stats
	var tag_list: Array = []
	if card != null and card.card_type == GC.CardType.COMBAT_UNIT and stats_for_tags != null:
		var tags: Array = CardPeriodicSkills.compute_source_tags_for_stats(stats_for_tags)
		tag_list = tags
		var sm: Node = get_node_or_null("/root/PhaseMasterSkillManager")
		for sid in CardPeriodicSkills.get_all_skill_ids():
			var sk: Dictionary = CardPeriodicSkills.get_skill(sid)
			var st: String = String(sk.get("source_tag", ""))
			if st.is_empty():
				continue  # 空 source_tag 全局终极技（如 cps_steel_storm）不在单位卡显示，改由相位师面板承载
			if not (st in tags):
				continue  # 本卡不带该 source_tag
			# 仅显示已解锁（未解锁则战斗中也不会触发，避免噪声）
			var unlocked: bool = sm != null and sm.has_method("is_content_unlocked") and sm.is_content_unlocked("card_skill", sid)
			if not unlocked:
				continue
			var nm: String = String(sk.get("name", sid))
			var ulti: String = " [终极]" if bool(sk.get("is_ultimate", false)) else ""
			var itv: float = float(sk.get("interval", 0.0))
			var itv_s: String = ("每%.0fs" % itv) if itv > 0.0 else ""
			var eff_cn: String = _card_skill_effect_summary(sk.get("effect", {}))
			lines.append("  · %s%s（%s）：%s" % [nm, ulti, itv_s, eff_cn])
	var text: String = "\n".join(lines)
	_card_skill_label.text = text
	# 悬浮情报：来源标签清单（标签命中即触发上列技能，由兵种/阵营/法则家族决定）
	if not tag_list.is_empty():
		_card_skill_label.tooltip_text = "来源标签：%s\n（标签命中的周期技能见上；标签由兵种/阵营/法则家族决定）" % "、".join(PackedStringArray(tag_list))
	else:
		_card_skill_label.tooltip_text = ""
	_set_section_visible_by_content(_card_skill_section, text)

## 卡片技能 effect.type → 中文摘要（情报面板紧凑单行）
func _card_skill_effect_summary(effect: Dictionary) -> String:
	match String(effect.get("type", "")):
		"area_damage": return "范围伤害"
		"single_target_damage": return "单体打击"
		"global_damage": return "全图打击"
		"chain_damage": return "链式打击"
		"debuff_target": return "单体减益"
		"debuff_area": return "范围减益"
		"debuff_global": return "全图减益"
		"debuff_spread": return "减益传染"
		"buff_allies": return "友军增益"
		"execute": return "斩杀"
		_: return "特效"

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
		_extra_stat_label.text = "攻速 %.1f/s · 秒伤 %d · 移速 %d" % [best_speed, int(dps), int(stats.move_speed)]

## 相位师技能树解锁签名（供 _cached_display_stats 缓存 key 使用）。
## 解锁 unit_mechanism（战术核武等）后机制 meta 才写入 stats；若不纳入 key，
## 解锁前打开过的卡会在解锁后命中旧缓存 → 机制 meta 缺失 → 情报面板不显示兵种机制。
func _get_pmsm_unlock_sig() -> String:
	# P1 性能优化：直接用 autoload 全局引用（原每次经 Engine.get_main_loop + 全树遍历）
	if PhaseMasterSkillManager != null and PhaseMasterSkillManager.has_method("get_unlocked_signature"):
		return PhaseMasterSkillManager.get_unlocked_signature()
	return ""


## v7.3 性能优化：在 _refresh_info_sections 顶部构建一次 UnitStats 缓存，供子函数共用。
## 避免 _refresh_stat_cards 和 _build_affix_tag_list 各自调 _build_display_stats（build_stats_from_card 重操作）跑2遍。
func _prepare_display_stats_cache(card: CardResource) -> void:
	_cached_display_stats = _build_display_stats(card)
	# 缓存键：card 身份 + 当前战斗态（era 影响构建结果）
	var era_key: String = ""
	# P1 性能优化：直接用 autoload 全局引用（原经 Engine.get_main_loop + 全树遍历）
	if BattleManager != null and "battle_active" in BattleManager and BattleManager.battle_active:
		if GameManager != null and "current_level" in GameManager:
			era_key = str(int(GameManager.current_level))
	var id_str: String = String(card.instance_id) if (card != null and "instance_id" in card and not String(card.instance_id).is_empty()) else (String(card.card_id) if card != null else "")
	_cached_display_stats_key = id_str + "|" + era_key + "|" + _get_pmsm_unlock_sig()

## v6.4: 构建 UnitStats（含时代缩放 + growth + affix），供三维卡显示
func _build_display_stats(card: CardResource) -> UnitStats:
	# v7.3 性能优化：若缓存键匹配（同一卡同一战斗态），直接返回缓存，避免重复 build_stats_from_card
	var id_str: String = String(card.instance_id) if ("instance_id" in card and not String(card.instance_id).is_empty()) else String(card.card_id)
	# P1 性能优化：直接用 autoload 全局引用（原经 Engine.get_main_loop + 全树遍历）
	var era_key: String = ""
	if BattleManager != null and "battle_active" in BattleManager and BattleManager.battle_active:
		if GameManager != null and "current_level" in GameManager:
			era_key = str(int(GameManager.current_level))
	if _cached_display_stats != null and _cached_display_stats_key == (id_str + "|" + era_key + "|" + _get_pmsm_unlock_sig()):
		return _cached_display_stats

	var bm: Node = BlueprintManager
	var am: Node = AffixManager
	# v6.2 修复 M7：非战斗场景（背包/商店查看卡牌）应传 -1 让 build_stats_from_card 用卡牌自身 era，
	# 原强制取 GameManager.current_level 的 era 会导致非战斗场景按错误时代缩放（如看现代卡显示一战数值）
	var era: int = -1
	# 仅在战斗进行中才用当前关卡的 era 缩放（P1 优化：autoload 全局引用）
	if BattleManager != null and "battle_active" in BattleManager and BattleManager.battle_active \
			and GameManager != null and "current_level" in GameManager:
		era = GC.get_era_for_level(int(GameManager.current_level))
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
			var _fb_text: String = _build_card_affix_summary(card) if card.card_type == GC.CardType.COMBAT_UNIT else ""
			# v19: 真词条行置顶（标签化容器缺席时拼纯文本）
			var _fb_tags: Array = []
			if card.card_type == GC.CardType.COMBAT_UNIT:
				_fb_tags = AffixDisplayFormat.fmt_player_affix_tags(_card_identity_id(card), AffixManager)
				_fb_text = AffixDisplayFormat.merge_affix_text(_fb_tags, _fb_text, "词条")
			affix_label.text = _fb_text
			affix_label.tooltip_text = AffixDisplayFormat.tags_tooltip(_fb_tags)
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
	# v19: 真词条标签置顶（词条名+稀有度符号+等级），stats 派生标签为效果摘要，互补保留
	var tags: Array = AffixDisplayFormat.fmt_player_affix_tags(_card_identity_id(card), AffixManager) + _build_affix_tag_list(card)
	if tags.is_empty():
		var empty := Label.new()
		empty.text = "无特殊词条"
		empty.add_theme_color_override("font_color", DesignTokens.COLOR_SLATE_A70)
		empty.add_theme_font_size_override("font_size", 12)
		_affix_flow.add_child(empty)
		return
		for tag in tags:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			var tip: String = String(tag.get("tooltip", ""))
			if not tip.is_empty():
				row.tooltip_text = tip
			var dot := Label.new()
			dot.text = "●"
			dot.add_theme_color_override("font_color", tag.color)
			dot.add_theme_font_size_override("font_size", 12)
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
	# P1 性能优化：直接用 autoload 全局引用（原经 Engine.get_main_loop + 全树遍历）
	if ManagerLazyLoader != null and ManagerLazyLoader.has_method("ensure_loaded"):
		ManagerLazyLoader.ensure_loaded("affix")
	var bm: Node = BlueprintManager
	var am: Node = AffixManager
	var era: int = 0
	if GameManager != null and "current_level" in GameManager:
		era = GC.get_era_for_level(int(GameManager.current_level))

	# v5.0: 使用新的 build_stats_from_card 方法，不再检查已弃用的 platform_type
	if card.card_type == GC.CardType.COMBAT_UNIT:
		var stats: UnitStats = UnitStatsTable.build_stats_from_card(card, era)
		if bm and bm.has_method("apply_growth_to_stats"):
			bm.apply_growth_to_stats(stats, card, [])
		if am and am.has_method("apply_affixes_to_stats"):
			am.apply_affixes_to_stats(stats, card, [])
		return _build_affix_summary_lines(stats)
	return ""

## v7.3: 取卡牌养成身份 ID——优先 instance_id（实例化养成），空时回退 card_id（兼容旧卡）
## 养成相关 manager（CardEnhancementManager/BlueprintManager.blueprint_mods 等）的查询必须用实例身份，
## 否则用裸 card_id 查 InstanceRegistry 必返回 null（key 是 card_id#序号），回退到无养成的模板，
## 导致"强化/改造词条显示为空"。此函数统一收敛这条身份解析逻辑。
func _card_identity_id(card: CardResource) -> String:
	if card == null:
		return ""
	if "instance_id" in card and not String(card.instance_id).is_empty():
		return String(card.instance_id)
	return String(card.card_id)

## v19: 真词条/词缀格式化统一走 AffixDisplayFormat（scripts/affix_display_format.gd）——
## 独立零依赖工具，敌我双方显示与 headless 测试共用（本面板依赖链裸引用 autoload，--script 不可测）。

## v19: 面板统一等级口径（三十级制 card_level，Lv1-30）——实例经 InstanceRegistry 查经验等级；
## 未成长/无实例按 Lv1（与血条等级文字同口径）。旧 enhance_level 不再作为等级显示。
func _card_level_for_display(card: CardResource) -> int:
	if card == null:
		return 1
	var lv: int = 0
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_card_level"):
		lv = int(ir.get_card_level(_card_identity_id(card)))
	return clampi(maxi(lv, 1), 1, 30)

## v6.11: 强化详情（情报 Tab）→ v19: 等级统一三十级制 card_level
## 旧存档 module_slots 的词条效果行保留（旧加成不丢原则），仅等级口径切换
func _build_star_lines(card: CardResource) -> String:
	if card == null or card.card_type != GC.CardType.COMBAT_UNIT:
		return ""
	var detail_lv: int = _card_level_for_display(card)
	var cem: Node = get_node_or_null("/root/CardEnhancementManager")
	if cem and cem.has_method("get_module_effect_lines"):
		# v7.3: 用实例身份查词条（实例化养成后词条存实例对象，按裸 card_id 查永远空）
		var lines: Array = cem.get_module_effect_lines(_card_identity_id(card))
		if not lines.is_empty():
			return "等级 Lv%d\n- %s" % [detail_lv, "\n- ".join(lines)]
	return "等级 Lv%d" % detail_lv

func _build_nurture_text(card: CardResource, _stats: UnitStats = null, include_power: bool = true) -> String:
	if card == null or BlueprintManager == null:
		return ""
	var parts: Array[String] = []
	var mech_list_text: String = ""
	if card.card_type == GC.CardType.COMBAT_UNIT:
		var detail_lv: int = _card_level_for_display(card)
		parts.append("等级 Lv%d" % detail_lv)
		# v21.x: 显示战斗经验值和升级进度
		var ir_node: Node = get_node_or_null("/root/InstanceRegistry")
		if ir_node != null and ir_node.has_method("get_battle_experience"):
			var identity: String = _card_identity_id(card)
			var exp: int = ir_node.get_battle_experience(identity)
			var next_exp: int = BattleExperienceConfig.get_exp_for_next_level(detail_lv)
			if next_exp > 0:
				var progress_pct: int = int(float(exp) / next_exp * 100.0)
				parts.append("经验 %d/%d (%d%%)" % [exp, next_exp, progress_pct])
		# v20.13c: 每卡部署次数（静态总量预览；战场单位模式由实时行展示剩余/总量，此处跳过防重复）
		if _current_unit == null:
			var du_entry := UnifiedCardTable.get_entry(card.card_id)
			if not du_entry.is_empty():
				var du_uses := UnifiedCardTable.get_deploy_uses(du_entry, card)
				if du_uses < 99:
					parts.append("可上场×%d/场" % du_uses)
		# v20.15: 固定机制文案（雷达/指挥/医疗/维修/补给/中继等 tag 机制）
		var mech_lines: Array[String] = CardMechanismDesc.get_mechanism_lines(card.tags)
		if not mech_lines.is_empty():
			mech_list_text = "\n固定机制：\n    · " + "\n    · ".join(mech_lines)
		# v7.x：战场单位情报面板已把战力移到 summary 行（属性口径，敌我可对比），
		# 故 include_power=false 时此处不再重复显示养成战力。卡牌查看模式默认 true（养成口径不变）。
		if include_power:
			var power: int = card.get_current_power() if card.has_method("get_current_power") else 0
			parts.append("战力：%d" % power)
	# v6.11: 强化词条效果行（调用现成的 get_module_effect_lines，之前是孤儿接口从未被调用）
	var enhance_effect_text: String = ""
	if card.card_type == GC.CardType.COMBAT_UNIT:
		var cem: Node = get_node_or_null("/root/CardEnhancementManager")
		if cem and cem.has_method("get_module_effect_lines"):
			# v7.3: 用实例身份查词条（实例化养成后词条存实例对象，按裸 card_id 查永远空）
			var eff_lines: Array = cem.get_module_effect_lines(_card_identity_id(card))
			if not eff_lines.is_empty():
				enhance_effect_text = "\n词条效果：" + " · ".join(eff_lines)
	if "evolution_stage" in card and str(card.evolution_stage) != "":
		var stage: String = str(card.evolution_stage)
		if not stage.is_empty():
			parts.append("进化 %s" % stage)
	# v6.11: 情报标签下显示已获得改造的名称 + 效果摘要（让玩家看到装了什么、加什么）
	var mod_list_text: String = ""
	if card.card_type == GC.CardType.COMBAT_UNIT and "mods" in card:
		var mod_lines: Array[String] = []
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
				# 追加效果摘要（复用 modification_panel 的格式化逻辑）
				var mod_text: String = mod_name
				if not mod_data.is_empty() and mod_data.has("effects"):
					var eff_lines: PackedStringArray = _format_mod_effects_brief(mod_data)
					if not eff_lines.is_empty():
						mod_text += "（%s）" % " · ".join(eff_lines)
				elif not mod_data.is_empty() and mod_data.has("level_effects"):
					var eff_lines: PackedStringArray = _format_mod_effects_brief(mod_data)
					if not eff_lines.is_empty():
						mod_text += "（%s）" % " · ".join(eff_lines)
				# v6.5: 禁用的武器改造标注（禁用）
				if mod_disabled:
					mod_text += "（禁用）"
				mod_lines.append(mod_text)
		parts.append("改造 %d/%d" % [mod_lines.size(), ModEffects.MAX_MOD_SLOTS])
		if not mod_lines.is_empty():
			mod_list_text = "\n已装改造：\n    · " + "\n    · ".join(mod_lines)
	# v6.11: 战力星级信息已移除（系统②合并到强化等级①，详见 _build_star_lines 的强化加成）
	if not parts.is_empty():
		return " · ".join(parts) + enhance_effect_text + mod_list_text + mech_list_text
	return ""

## v6.11: 格式化改造效果摘要（用于情报面板已装改造列表，紧凑单行）
## 兼容 effects（单档）和 level_effects（取最高档）。
## v7.x 修复：① 追加 grant_slot（赋予新攻击维度）显示；② 条数上限 3→6 避免关键效果被吞；
##            ③ else 分支补回数值（像素值整数如 vision:50 不再丢数值）。
func _format_mod_effects_brief(mod_data: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	var eff: Dictionary = {}
	if mod_data.has("effects") and (mod_data["effects"] as Dictionary).size() > 0:
		eff = mod_data["effects"]
	elif mod_data.has("level_effects") and (mod_data["level_effects"] as Dictionary).size() > 0:
		var le: Dictionary = mod_data["level_effects"]
		var sorted_levels = le.keys()
		sorted_levels.sort()
		eff = le[sorted_levels[sorted_levels.size() - 1]]
	for key in eff.keys():
		var val = eff[key]
		var disp: String = _translate_mod_key(String(key))
		if val is float and val >= 0.01 and val < 100.0:
			lines.append("%s+%d%%" % [disp, int(val * 100)])
		elif val is float and val <= -0.01:
			lines.append("%s%d%%" % [disp, int(val * 100)])
		elif val is int:
			lines.append("%s%+d" % [disp, val])
		elif val is bool and val:
			lines.append("✓%s" % disp)
		else:
			lines.append("%s: %d" % [disp, int(val)])
		if lines.size() >= 6:
			break
	# v7.x: grant_slot（赋予新攻击维度，如炮射导弹激活对空槽）——此前完全被跳过
	if mod_data.has("grant_slot") and (mod_data["grant_slot"] as Dictionary).size() > 0:
		lines.append(ModEffectLabels.format_grant_slot(mod_data["grant_slot"]))
	return lines

## 改造效果键翻译（薄封装，委托 ModEffectLabels 共享表）。
## v7.x 统一：情报/改造/强化三面板共用 ModEffectLabels.translate，消除多套分叉表。
func _translate_mod_key(key: String) -> String:
	return ModEffectLabels.translate(key)

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
	# v7.x(敌方加成来源明细): 调度入口统一隐藏加成来源 section，敌方显示函数按需重新填充。
	# 避免从敌方单位切到我方单位时 BonusSection 残留（我方加成走养成摘要，不在此显示）。
	if _bonus_label:
		_bonus_label.text = ""
	if _bonus_section:
		_bonus_section.visible = false
	_refresh_rank_badge(unit)
	var is_ally: bool = _resolve_unit_is_player(unit, is_player)
	if unit.is_in_group("enemy_phase_driver"):
		_show_enemy_phase_driver(unit)
	elif is_ally and unit.is_in_group("phase_driver"):
		_show_player_phase_driver(unit)
	elif is_ally and "stats" in unit:
		_show_player_unit(unit)
	else:
		_show_enemy_unit(unit)
	if status_section:
		status_section.visible = true
	# v9.x 当前状态区：战场单位模式立即填充一次（之后由 _process 周期刷新）
	_refresh_status_section(unit)

# v9.x 战场单位模式：周期刷新"当前状态"区（单位 buff/debuff 随战斗变化）
func _process(delta: float) -> void:
	# P2 性能优化：面板隐藏时直接跳过（status_section 可能未随面板隐藏而清除）
	if not visible:
		return
	# 仅当处于战场单位模式、单位有效、状态区可见时才刷新（避免静态面板空跑）
	if status_section == null or not status_section.visible:
		return
	if _current_unit == null or not is_instance_valid(_current_unit):
		return
	_status_refresh_accum += delta
	if _status_refresh_accum >= 0.4:
		_status_refresh_accum = 0.0
		_refresh_status_section(_current_unit)

## 填充"当前状态"区：复用 UnitStatusCollector 收集激活的 buff/debuff，每条显示
## [正面/负面] 名称：效果说明。无激活状态时给出提示并隐藏明细。
func _refresh_status_section(unit: Node) -> void:
	if status_label == null:
		return
	if unit == null or not is_instance_valid(unit):
		status_label.text = ""
		if status_section:
			status_section.visible = false
		return
	var entries: Array = UnitStatusCollector.collect(unit)
	if entries.is_empty():
		# 无激活状态：保留"当前状态"标题，正文提示无加成
		status_label.text = "[color=#9a9a9a]当前无激活的正面/负面状态[/color]"
		return
	var lines: PackedStringArray = []
	for e in entries:
		lines.append(UnitStatusCollector.format_status_line(e as Dictionary, unit))
	status_label.text = "\n".join(lines)

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
		hp_text = "生命 %d/%d" % [int(cur_hp), int(stats.max_hp)]
	else:
		hp_text = "生命 %d" % int(stats.max_hp)
	
	# 获取武器名称（v7.x: 附带 per-slot 弹道类型后缀）
	var weapon_names: Array[String] = ["", "", ""]
	if not stats.weapon_slots.is_empty():
		for i in range(min(stats.weapon_slots.size(), 3)):
			var w = stats.weapon_slots[i]
			if w is WeaponResource and w.enabled:
				var _wname: String = w.display_name
				# v7.x: 追加弹道类型短名（如"直射/穿甲/导弹"），让玩家看到 per-slot 弹道差异
				var _traj: String = RealWorldUnitLabels.weapon_kind_short(int(w.weapon_type))
				if not _traj.is_empty() and _traj != "未知":
					_wname += "［" + _traj + "］"
				weapon_names[i] = _wname
	
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

## v7.x：战场单位战力后缀——敌我统一用「属性战力」口径（combat_power_from_unit_stats），
## 让情报面板的战力敌我可直接对比（卡牌查看模式仍用养成战力 get_current_power）。
## 供 _format_unit_stats_summary / _format_enemy_combat_summary 的 extra_suffix 透传。
func _combat_power_suffix(stats: UnitStats) -> String:
	if stats == null:
		return ""
	return "｜战力 %d" % int(EvolutionHelpers.combat_power_from_unit_stats(stats))

## 战场单位动态描述——基于单位实际特殊机制生成定位句，不写过时模板。
## 扫描 stats 的特殊功能字段，拼成反映当前机制的描述；无特殊机制时回退 base_text。
func _build_unit_description(stats: UnitStats, is_player: bool, base_text: String) -> String:
	if stats == null:
		return base_text
	var roles: Array[String] = []
	# ── 单位固有特征（非改造，基于卡牌本身属性）──
	# 射程定位
	var rng_cells: float = stats.attack_range / 100.0
	if rng_cells >= 4.0:
		roles.append("远程火力")
	elif rng_cells >= 2.0:
		roles.append("中程交战")
	else:
		roles.append("近战突击")
	# 武器弹道（曲射/对空）
	var wt: int = int(stats.weapon_type)
	if wt == GC.WeaponType.INDIRECT:
		roles.append("曲射越过前排")
	elif wt == GC.WeaponType.AERIAL:
		roles.append("对空能力")
	# 兵种定位（combat_kind）
	match int(stats.combat_kind):
		GC.CombatKind.FORT:
			roles.append("堡垒固守")
		GC.CombatKind.SUPPORT:
			roles.append("支援职能")
		GC.CombatKind.AIR:
			roles.append("空中单位")
	# 固定单位（不移动）
	if stats.move_speed < 1.0:
		roles.append("固定部署")
	# ── 改造/养成驱动的特殊机制 ──
	if stats.splash_damage > 0.001 or stats.splash_radius_bonus > 0.001:
		roles.append("范围溅射")
	if stats.chain_chance > 0.001:
		roles.append("连锁攻击")
	if stats.attack_fort_bonus > 0.001 or stats.siege_bonus_pct > 0.001:
		roles.append("攻城特化")
	if stats.mark_chance > 0.001 or stats.laser_mark_on_hit:
		roles.append("目标标记")
	if stats.armor_break_per_hit > 0.001:
		roles.append("破甲叠加")
	if stats.combo_max > 0:
		roles.append("连击输出")
	if stats.rage_max > 0:
		roles.append("狂怒增益")
	if stats.reflect_damage_pct > 0.001:
		roles.append("爆反反伤")
	if stats.intercept_chance > 0.001:
		roles.append("拦截格挡")
	if stats.revive_on_death:
		roles.append("濒死复活")
	if stats.phase_shield_pool > 0.001:
		roles.append("相位护盾")
	if stats.urban_defense_bonus > 0.001:
		roles.append("巷战防御")
	if stats.death_heal_allies_pct > 0.001:
		roles.append("亡语治疗")
	if stats.slow_aura_pct > 0.001:
		roles.append("减速光环")
	if stats.command_aura_bonus > 0.001:
		roles.append("指挥光环")
	if stats.kill_repair > 0.001:
		roles.append("战场回收")
	if stats.hp_regen > 0.001:
		roles.append("自我回复")
	# 动态描述：按阵营措辞，反映"这个单位能干什么"
	var role_str := "、".join(roles)
	var side_verb := "推进" if is_player else "来袭"
	return "%s，%s交战。" % [role_str, side_verb]

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
	if stats.kill_repair > 0.001:
		parts.append("击杀修复 %d%%" % int(stats.kill_repair * 100.0))
	if stats.armor_penetration > 0.001:
		parts.append("穿甲 %d%%" % int(stats.armor_penetration * 100.0))
	if stats.splash_damage > 0.001:
		parts.append("溅射 %d%%" % int(stats.splash_damage * 100.0))
	if stats.chain_chance > 0.001:
		parts.append("连锁 %d%%" % int(stats.chain_chance * 100.0))
	if stats.shield_on_kill > 0.001:
		parts.append("击杀护盾 %d%%生命" % int(stats.shield_on_kill * 100.0))
	if stats.hp_regen > 0.001:
		parts.append("每秒回血 %d%%生命" % int(stats.hp_regen * 100.0))
	# ── 特殊机制（改造驱动，v7.x 补全：之前这批 live 字段有值却从不显示）──
	# v8.x: 同步补齐兵种固定机制的数值字段（碾压/空域封锁/堡垒庇护光环），让数值与机制说明行双路径可见
	if stats.attack_fort_bonus > 0.001:
		parts.append("对堡垒特攻 +%d%%" % int(stats.attack_fort_bonus * 100.0))
	if stats.attack_light_bonus > 0.001:
		parts.append("对轻装/支援 +%d%%（碾压）" % int(stats.attack_light_bonus * 100.0))
	if stats.attack_air_bonus > 0.001:
		parts.append("对空军 +%d%%（空域封锁）" % int(stats.attack_air_bonus * 100.0))
	if stats.fort_shelter_aura > 0.001:
		parts.append("半径%d内地面友军减伤 %d%%（阵地坚守光环）" % [250, int(stats.fort_shelter_aura * 100.0)])
	if stats.splash_radius_bonus > 0.001:
		parts.append("溅射范围 +%d%%" % int(stats.splash_radius_bonus * 100.0))
	if stats.single_target_penalty < -0.001:
		parts.append("主目标分散伤害 %d%%" % int(stats.single_target_penalty * 100.0))
	if stats.armor_break_per_hit > 0.001:
		parts.append("破甲叠加（每击降%d防，%d层）" % [int(stats.armor_break_per_hit), stats.armor_break_max_stacks])
	if stats.mark_chance > 0.001:
		var mark_s := "标记 %d%%" % int(stats.mark_chance * 100.0)
		if stats.mark_vuln_bonus > 0.001:
			mark_s += "（易伤+%d%%）" % int(stats.mark_vuln_bonus * 100.0)
		parts.append(mark_s)
	if stats.siege_bonus_pct > 0.001:
		parts.append("对装甲/堡垒 +%d%%当前生命真实伤害" % int(stats.siege_bonus_pct * 100.0))
	if stats.urban_defense_bonus > 0.001:
		parts.append("受装甲/空军攻击减伤 %d%%" % int(stats.urban_defense_bonus * 100.0))
	if stats.has_counter_battery:
		var cb_s := "反炮兵（受击标记攻击者，下%d次优先射击）" % stats.counter_battery_shots
		parts.append(cb_s)
	if stats.revive_on_death:
		parts.append("濒死复活（%d%%生命）" % int(stats.revive_hp_ratio * 100.0))
	if stats.reflect_damage_pct > 0.001:
		parts.append("爆反反伤 %d%%" % int(stats.reflect_damage_pct * 100.0))
	if stats.intercept_chance > 0.001:
		var inter_s := "拦截 %d%%" % int(stats.intercept_chance * 100.0)
		if stats.intercept_charges > 0:
			inter_s += "（%d次）" % stats.intercept_charges
		parts.append(inter_s)
	if stats.death_heal_allies_pct > 0.001:
		parts.append("亡语治疗友军 %d%%生命" % int(stats.death_heal_allies_pct * 100.0))
	if stats.slow_aura_pct > 0.001:
		parts.append("减速光环 %d%%" % int(stats.slow_aura_pct * 100.0))
	if stats.command_aura_bonus > 0.001:
		parts.append("指挥光环 +%d%%" % int(stats.command_aura_bonus * 100.0))
	if stats.phase_shield_pool > 0.001:
		parts.append("相位护盾 %d" % int(stats.phase_shield_pool))
	if stats.laser_mark_on_hit:
		parts.append("激光标记（命中必标记）")
	if stats.combo_max > 0:
		parts.append("连击系统（%d层+%d%%伤害）" % [stats.combo_max, int(stats.combo_bonus_mult * 100.0)])
	if stats.rage_max > 0:
		parts.append("狂怒系统（%d层+%d%%伤害）" % [stats.rage_max, int(stats.rage_bonus_mult * 100.0)])
	var mutations: Array[String] = []
	if stats.has_weapon_dmg_mutation: mutations.append("伤害变异")
	if stats.has_weapon_atkspd_mutation: mutations.append("攻速变异")
	if stats.has_crit_mutation: mutations.append("暴击变异")
	if stats.has_kill_repair_mutation: mutations.append("回收变异")
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
	var C_VAMP := Color(0.85, 0.3, 0.55, 1)   # 击杀修复-粉红
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
	if stats.kill_repair > 0.001:
		tags.append({text = "击杀修复 %d%%" % int(stats.kill_repair * 100.0), color = C_VAMP})
	if stats.armor_penetration > 0.001:
		tags.append({text = "穿甲 %d%%" % int(stats.armor_penetration * 100.0), color = C_PEN})
	if stats.splash_damage > 0.001:
		tags.append({text = "溅射 %d%%" % int(stats.splash_damage * 100.0), color = C_AOE})
	if stats.chain_chance > 0.001:
		tags.append({text = "连锁 %d%%" % int(stats.chain_chance * 100.0), color = C_AOE})
	if stats.shield_on_kill > 0.001:
			tags.append({text = "击杀护盾 %d%%生命" % int(stats.shield_on_kill * 100.0), color = C_SHIELD})
	if stats.hp_regen > 0.001:
		tags.append({text = "每秒回血 %d%%生命" % int(stats.hp_regen * 100.0), color = C_SHIELD})
	var mutations: Array[String] = []
	if stats.has_weapon_dmg_mutation: mutations.append("伤害变异")
	if stats.has_weapon_atkspd_mutation: mutations.append("攻速变异")
	if stats.has_crit_mutation: mutations.append("暴击变异")
	if stats.has_kill_repair_mutation: mutations.append("回收变异")
	if stats.has_hp_regen_mutation: mutations.append("回血变异")
	if stats.has_platform_hp_mutation: mutations.append("HP变异")
	if not mutations.is_empty():
		tags.append({text = "变异：%s" % " · ".join(mutations), color = C_MUT})
	return tags

func _enemy_surface_combat_stats(unit: Node) -> Array:
	# v6.11: 优先读 max_hp（满血上限），让残血敌人的血量显示稳定，符合"这个敌人有多少血"的直觉；
	# 单位无 max_hp 字段时回退 hp（防御性，兼容所有单位类型）
	var hp: float = float(unit.get("max_hp")) if "max_hp" in unit else (float(unit.get("hp")) if "hp" in unit else 0.0)
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
	return "生命 %d｜防 %d｜攻 %d｜射程 %d｜攻速 %.2f%s" % [int(hp), int(def), int(dmg), int(rng), itv, extra_suffix]

## ── 敌方相位驱动器 ──

## v9.1: 将 trait.effects dict 格式化为中文数值描述（如"防御+10%、攻击+8%"）。
## 用于情报面板 trait 显示，让玩家直观感知 trait 带来的具体加成。
## 支持 key：atk_*/def_*/hp/crit_chance/dodge_chance/all_stat_boost/unit_limit_bonus。
## 不识别的 key 跳过（如 void_damage_boost/auto_resurrect 等复杂 effect 留待后续）。
## 无 effects 或 effects 为空 → 返回空串（调用方回退到 description 文字）。
## 注：参数 `trait_def` 是 trait 条目字典（Godot 4.5 起 `trait` 已为保留关键字，故参数不命名 trait）。
## v18 四源重构·批次4: 技能树数值节点 effects 格式化（"三维攻击+8% / 生命+15%"）
func _format_skill_tree_effects(fx: Dictionary) -> String:
	if fx.is_empty():
		return ""
	var parts: Array[String] = []
	if fx.has("atk_light") or fx.has("atk_armor") or fx.has("atk_air"):
		var v_a: float = float(fx.get("atk_light", fx.get("atk_armor", 0.0)))
		parts.append("三维攻击+%d%%" % int(round(v_a * 100.0)))
	if fx.has("def_light") or fx.has("def_armor") or fx.has("def_air"):
		var v_d: float = float(fx.get("def_light", fx.get("def_armor", 0.0)))
		parts.append("三维防御+%d%%" % int(round(v_d * 100.0)))
	if fx.has("hp"):
		parts.append("生命+%d%%" % int(round(float(fx.get("hp", 0.0)) * 100.0)))
	if fx.has("crit_chance"):
		parts.append("暴击+%d%%" % int(round(float(fx.get("crit_chance", 0.0)) * 100.0)))
	if fx.has("dodge_chance"):
		parts.append("闪避+%d%%" % int(round(float(fx.get("dodge_chance", 0.0)) * 100.0)))
	return " / ".join(parts)


## v18 四源重构·批次4: 技能树机制节点 kind → 中文
func _mech_kind_zh(kind: String) -> String:
	match kind:
		"aura_damage": return "范围伤害光环"
		"aura_heal": return "治疗光环"
		"thorn": return "反伤"
		"shield": return "自身护盾"
		"high_energy": return "能量阈值攻速"
		"death_shield": return "亡语回盾"
		"death_explosion": return "死亡爆炸"
		"todo": return "待实装"
	return kind


## v18 四源重构·批次4: 元素亲和 → 中文
func _elem_affinity_zh(a: int) -> String:
	match a:
		1: return "火"
		2: return "雷"
		3: return "虚"
	return "无"


## v18 四源重构·批次4: 敌方势力短名 → 中文
func _enemy_faction_zh(f: String) -> String:
	match f:
		"steel": return "钢"
		"flame": return "焰"
		"thunder": return "雷"
		"void": return "虚"
	return f

func _format_trait_effects(trait_def: Dictionary) -> String:
	if not (trait_def is Dictionary):
		return ""
	var fx: Dictionary = trait_def.get("effects", {})
	if fx.is_empty():
		return ""
	var parts: Array[String] = []
	# 先处理 all_stat_boost（合并显示，避免重复"攻击+X% 防御+X%"）
	if fx.has("all_stat_boost"):
		var val: float = float(fx["all_stat_boost"])
		if val != 0.0:
			parts.append("全属性+%d%%" % int(val * 100))
		fx.erase("all_stat_boost")  # 避免后续重复处理
	# 处理 hp（特殊标签）
	if fx.has("hp"):
		var val: float = float(fx["hp"])
		if val != 0.0:
			parts.append("生命+%d%%" % int(val * 100))
	# 处理 unit_limit_bonus（整数加成）
	if fx.has("unit_limit_bonus"):
		var val: int = int(fx["unit_limit_bonus"])
		if val != 0:
			parts.append("出兵上限+%d" % val)
	# 处理三维攻击/防御（合并同维显示，如 atk_light+atk_armor+atk_air 全相同 → "攻击+8%"）
	var atk_val: float = -1.0
	var atk_consistent: bool = true
	for k in ["atk_light", "atk_armor", "atk_air"]:
		if fx.has(k):
			var v: float = float(fx[k])
			if atk_val < 0.0:
				atk_val = v
			elif atk_val != v:
				atk_consistent = false
	if atk_val > 0.0:
		if atk_consistent:
			parts.append("攻击+%d%%" % int(atk_val * 100))
		else:
			# 三维不一致，分别显示
			for k in ["atk_light", "atk_armor", "atk_air"]:
				if fx.has(k):
					parts.append("%s+%d%%" % [_trait_key_to_label(k), int(float(fx[k]) * 100)])
	var def_val: float = -1.0
	var def_consistent: bool = true
	for k in ["def_light", "def_armor", "def_air"]:
		if fx.has(k):
			var v: float = float(fx[k])
			if def_val < 0.0:
				def_val = v
			elif def_val != v:
				def_consistent = false
	if def_val > 0.0:
		if def_consistent:
			parts.append("防御+%d%%" % int(def_val * 100))
		else:
			for k in ["def_light", "def_armor", "def_air"]:
				if fx.has(k):
					parts.append("%s+%d%%" % [_trait_key_to_label(k), int(float(fx[k]) * 100)])
	# 暴击/闪避（加值）
	if fx.has("crit_chance"):
		var val: float = float(fx["crit_chance"])
		if val != 0.0:
			parts.append("暴击率+%d%%" % int(val * 100))
	if fx.has("dodge_chance"):
		var val: float = float(fx["dodge_chance"])
		if val != 0.0:
			parts.append("闪避+%d%%" % int(val * 100))
	return "、".join(parts)

## v9.1: trait effect key → 中文标签映射（供 _format_trait_effects 在三维不一致时使用）
func _trait_key_to_label(key: String) -> String:
	match key:
		"atk_light": return "轻攻"
		"atk_armor": return "重攻"
		"atk_air":   return "防空攻"
		"def_light": return "轻防"
		"def_armor": return "重防"
		"def_air":   return "防空防"
		_: return ""

## v6.14: 获取敌方相位仪显示名（解析 enemy_phase_instruments 数据）
func _get_enemy_instrument_display_name(instrument_id: String) -> String:
	if instrument_id.is_empty():
		return ""
	var cfg: Dictionary = EnemyPhaseEquipment.get_phase_instrument(instrument_id)
	if cfg.is_empty():
		return instrument_id  # 查不到返回 ID 兜底
	return str(cfg.get("name", instrument_id))

## v18.c: master cfg.era 字符串 → 数字时代（与 driver._era_string_to_int 同口径；
## 无 era 字段时按等级推算，与 driver._era_from_level 一致）
func _enemy_master_era_int(cfg: Dictionary) -> int:
	match str(cfg.get("era", "")).to_lower():
		"ww1": return 0
		"ww2": return 1
		"cold": return 2
		"modern": return 3
		"future", "near_future": return 4
		_:
			return clampi(floori(float(maxi(int(cfg.get("level", 15)), 5) - 5) / 5.0), 0, 4)

## v6.14: 格式化敌方相位师符文列表为可读字符串（"符文名×稀有度"）
func _format_enemy_runes(rune_ids: Array) -> String:
	if rune_ids.is_empty():
		return ""
	var parts: Array[String] = []
	for rid in rune_ids:
		var rd: Dictionary = RuneDefs.get_rune(str(rid))
		if rd.is_empty():
			parts.append(str(rid))
		else:
			var rn: String = str(rd.get("id", rid))
			var rarity: String = str(rd.get("rarity", ""))
			var rarity_short: String = ""
			match rarity:
				"common": rarity_short = "常见"
				"uncommon": rarity_short = "优秀"
				"rare": rarity_short = "稀有"
				"epic": rarity_short = "史诗"
				"legendary": rarity_short = "传说"
				"mythic": rarity_short = "神话"
			if not rarity_short.is_empty():
				parts.append("%s(%s)" % [rn, rarity_short])
			else:
				parts.append(rn)
	return "、".join(parts)

## v7.x: 敌方相位师符文完整显示（与我方 _show_player_phase_driver 对齐）。
## 敌方相位仪无 rune_slot_count 硬数据，沿用 _derive_runes 的派生上限 clampi(2+level/10,2,4) 作槽位分母，
## 反映"派生时即按此上限选符文"的语义。符文之语用 RunewordMatcher 查激活词。
## [return] "N/槽位上限（符文之语：名/名）符文列表"；无符文返回空串
func _format_enemy_runes_full(runes: Array, level: int) -> String:
	if runes.is_empty():
		return ""
	var slot_cap: int = clampi(2 + int(level / 10), 2, 4)
	var rune_str: String = _format_enemy_runes(runes)
	# 符文之语：slot_count 用 max(符文数, 2)（与 RunewordMatcher 标准判定同口径）
	var clean_ids: Array[String] = []
	for rid in runes:
		var rid_s: String = String(rid)
		if not rid_s.is_empty():
			clean_ids.append(rid_s)
	var rw_part: String = ""
	if not clean_ids.is_empty():
		var active_rw: Array[Dictionary] = RunewordMatcher.check_active_runewords(clean_ids, maxi(clean_ids.size(), 2))
		if not active_rw.is_empty():
			var rw_names: Array[String] = []
			for rw in active_rw:
				var rwid: String = String(rw.get("id", ""))
				var rn: String = RunewordDefs.get_runeword_name(rwid) if not rwid.is_empty() else ""
				if rn.is_empty():
					rn = rwid
				if not rw_names.has(rn):
					rw_names.append(rn)
			if not rw_names.is_empty():
				rw_part = "（符文之语：" + " / ".join(rw_names) + "）"
	return "%d/%d 槽位%s%s" % [clean_ids.size(), slot_cap, rw_part, "" if rune_str.is_empty() else " " + rune_str]

## v7.x: 敌方相位仪稀有度→中文（对齐我方"★星级"维度；敌方相位仪无 star 字段，用 rarity）。
func _enemy_instrument_rarity_zh(rarity: String) -> String:
	match rarity:
		"common": return "普通"
		"uncommon": return "精良"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary": return "传说"
		"mythic": return "神话"
		"": return ""
		_: return rarity

## v7.x: 敌方相位师主动能力+相位仪特殊效果完整显示（用户选"两者都显示"）。
## master.active_spells（带 name/description/cooldown）+ 相位仪 special_effects（字符串ID数组，复用
## LeaderboardPresenter._translate_special_tag 56 条翻译表）。两路径共用。
## [return] 格式化文本块（多行）；无内容返回空串
func _format_enemy_active_abilities(pm_id: String, inst_id: String) -> String:
	var blocks: Array[String] = []
	# 1. master.active_spells（逐条 name + description + cooldown）
	if not pm_id.is_empty() and EnemyPhaseMasters != null:
		var spells: Array = EnemyPhaseMasters.get_master_active_spells(pm_id)
		for sp in spells:
			if not (sp is Dictionary):
				continue
			var sp_name: String = str(sp.get("name", ""))
			var sp_desc: String = str(sp.get("description", ""))
			var sp_cd: float = float(sp.get("cooldown", 0.0))
			if sp_name.is_empty() and sp_desc.is_empty():
				continue
			var line: String = "◆ "
			if not sp_name.is_empty():
				line += sp_name
				if sp_cd > 0.0:
					line += "（冷却%.0f秒）" % sp_cd
				if not sp_desc.is_empty():
					line += "：" + sp_desc
			else:
				line += sp_desc
			blocks.append(line)
	# 2. 相位仪 special_traits（v7.x: 统一池中文描述，直接 join）
	if not inst_id.is_empty():
		var inst_cfg: Dictionary = EnemyPhaseEquipment.get_phase_instrument(inst_id)
		var traits: Array = inst_cfg.get("special_traits", []) as Array
		if not traits.is_empty():
			var trait_names: Array[String] = []
			for t in traits:
				var ts: String = String(t)
				if not ts.is_empty() and not trait_names.has(ts):
					trait_names.append(ts)
			if not trait_names.is_empty():
				blocks.append("特殊效果：" + "、".join(trait_names))
	return "\n".join(blocks)

func _show_enemy_phase_driver(unit: Node) -> void:
	var mname: String = str(unit.get("master_name")) if "master_name" in unit else "相位师"
	if name_label: name_label.text = "敌方相位师基地"
	if type_label: type_label.text = "【%s】· 相位场驱动器" % mname
	var cur_hp: float = float(unit.get("hp")) if "hp" in unit else 0.0
	var mx_hp: float = float(unit.get("max_hp")) if "max_hp" in unit else 1.0
	if summary_label: summary_label.text = "基地生命 %d / %d" % [int(cur_hp), int(mx_hp)]
	var lines: Array[String] = []
	lines.append("摧毁敌方相位场驱动器即可获胜；对方会持续生产战斗单位。")
	if GameManager and GameManager.has_method("get_current_phase_master"):
		var cfg: Dictionary = GameManager.get_current_phase_master()
		if not cfg.is_empty():
			var disp: String = str(cfg.get("name", mname))
			if disp != mname and not disp.is_empty():
				lines.append("档案名：%s" % disp)
			# v7.x: 显示相位场等级（原始 level 设计基准）+ 军团战力（含星名档位）
			var raw_level: int = int(cfg.get("level", 0))
			if raw_level > 0:
				lines.append("相位场等级：Lv.%d" % raw_level)
			# 军团战力行（原派生Lv由战力换算，与战力同义重复，已移除；只保留军团战力+星级档位）
			var er: Dictionary = MasterPowerEvaluator.evaluate(cfg)
			var stars: int = int(er.get("stars", 0))
			var star_name: String = str(er.get("star_name", ""))
			if stars > 0 and not star_name.is_empty():
				lines.append("军团战力：%d · %d★ %s" % [int(er.get("total_score", 0)), stars, star_name])
			else:
				lines.append("军团战力：%d" % int(er.get("total_score", 0)))
			# v7.x: 澄清口径——军团战力是相位师裸装固有战力（6张载卡+相位师属性/符文/相位仪），
			# 不含本关难度加成（wave/level/pressure/faction_buff）。战场单位实战值会高于此数。
			lines.append("（相位师固有战力，战场单位会叠加本关难度加成）")
			var fac: String = str(cfg.get("faction", ""))
			if not fac.is_empty():
				lines.append("所属势力：%s" % fac)
			var title: String = str(cfg.get("title", ""))
			if not title.is_empty():
				lines.append("称号：%s" % title)
			# v6.14: 取 enriched equipment（程序化派生 runes/spawn_sequence）
			var pm_id: String = str(cfg.get("id", ""))
			var eq: Dictionary = cfg.get("equipment", {}) as Dictionary
			if not pm_id.is_empty() and EnemyPhaseMasters != null:
				var enriched_eq: Dictionary = EnemyPhaseMasters.get_enriched_equipment(pm_id)
				if not enriched_eq.is_empty():
					eq = enriched_eq
			var plats: Array = eq.get("platforms", []) as Array
			var weps: Array = eq.get("weapons", []) as Array
			if not plats.is_empty() or not weps.is_empty():
				lines.append("上场装备：平台种类 %d · 武器种类 %d（由其基地持续部署）" % [plats.size(), weps.size()])
			# v7.x: 显示相位仪名+稀有度（对齐我方"★星级"维度）
			var inst_id: String = str(eq.get("phase_instrument", ""))
			var inst_name: String = _get_enemy_instrument_display_name(inst_id)
			if not inst_name.is_empty():
				var inst_cfg_e: Dictionary = EnemyPhaseEquipment.get_phase_instrument(inst_id) if not inst_id.is_empty() else {}
				var rarity_zh: String = _enemy_instrument_rarity_zh(str(inst_cfg_e.get("rarity", "")))
				if not rarity_zh.is_empty():
					lines.append("相位仪：%s（%s）" % [inst_name, rarity_zh])
				else:
					lines.append("相位仪：%s" % inst_name)
			# v7.x: 显示符文（含槽位比+符文之语，与我方对齐）
			var runes: Array = eq.get("runes", []) as Array
			if not runes.is_empty():
				var runes_line: String = _format_enemy_runes_full(runes, raw_level)
				if not runes_line.is_empty():
					lines.append("符文：%s" % runes_line)
			# v18 四源重构·批次4: 相位师特性区改为四源加成展示（等级属性/技能树/势力树 + 元素）。
			# 相位仪大招在下方【主动能力】区展示（专属相位仪变体即其归宿）。
			if not pm_id.is_empty() and raw_level > 0:
				var comp: Dictionary = EnemyMasterSkillTree.get_composition(pm_id, raw_level)
				# v18.c: 等级属性换 flat 统一——不再有全局 % 曲线，改按产兵兵种派生固定值（加算）。
				# 展示口径：以 LIGHT 兵种为代表值（实际按兵种权重浮动：堡垒血厚攻弱/空军攻锐血薄）。
				var lv_flat: Dictionary = CardGrowthConfig.total_growth_raw(_enemy_master_era_int(cfg), 0, "rare", raw_level)
				lines.append("【等级属性】Lv.%d 成长flat：攻+%.0f / 血+%.0f / 防+%.1f（按兵种派生，加算）" % [raw_level, float(lv_flat.atk), float(lv_flat.hp), float(lv_flat.def)])
				var num_nodes: Array = comp.get("num", []) as Array
				var mech_nodes: Array = comp.get("mech", []) as Array
				var todo_nodes: Array = comp.get("todo", []) as Array
				if not num_nodes.is_empty() or not mech_nodes.is_empty():
					var todo_part: String = " · 待实装%d项" % todo_nodes.size() if not todo_nodes.is_empty() else ""
					lines.append("【相位师技能树】数值%d项 · 机制%d项%s" % [num_nodes.size(), mech_nodes.size(), todo_part])
					for n in num_nodes:
						if n is Dictionary:
							lines.append("◆ %s：%s" % [str(n.get("name", "")), _format_skill_tree_effects((n.get("effects", {}) as Dictionary))])
					for n in mech_nodes:
						if n is Dictionary:
							lines.append("◆ %s（%s）" % [str(n.get("name", "")), _mech_kind_zh(str(n.get("kind", "")))])
				var elem_e: Dictionary = comp.get("element", {}) as Dictionary
				if not elem_e.is_empty():
					lines.append("元素亲和：%s系 · 伤害×%.2f" % [_elem_affinity_zh(int(elem_e.get("affinity", 0))), float(elem_e.get("mult", 1.0))])
				var syn_e: Dictionary = EnemyFactionSkills.get_synergy(pm_id)
				if not syn_e.is_empty():
					var syn_types: Array = syn_e.get("types", []) as Array
					var type_names: Array[String] = []
					for st in syn_types:
						type_names.append(_enemy_faction_zh(str(st)))
					lines.append("【势力技能树】%s（%s 协同 +%d%%）" % [str(syn_e.get("name", "")), "+".join(type_names), int(round(float(syn_e.get("synergy_boost", 0.0)) * 100.0))])
			# v7.x: 主动能力（master.active_spells + 相位仪 special_effects，与我方对齐）
			var abilities_text: String = _format_enemy_active_abilities(pm_id, inst_id)
			if not abilities_text.is_empty():
				lines.append("【主动能力】")
				lines.append(abilities_text)
	if desc_label: desc_label.text = "\n".join(lines)
	if flavor_label: flavor_label.text = "“相位师的意志锚定在这片场上。”"
	_clear_non_summary_info_sections()

## v7.x: 点击我方相位场驱动器（基地）——显示玩家相位场等级+情报+军团等级+战力
## 与敌方 _show_enemy_phase_driver 对称：相位场Lv / 军团战力·星级 / 相位仪 / 符文 / 主动能力
func _show_player_phase_driver(unit: Node) -> void:
	if name_label: name_label.text = "我方相位师基地"
	if type_label: type_label.text = "相位场驱动器"
	var cur_hp: float = float(unit.get("hp")) if "hp" in unit else 0.0
	var mx_hp: float = float(unit.get("max_hp")) if "max_hp" in unit else 1.0
	if summary_label: summary_label.text = "基地生命 %d / %d" % [int(cur_hp), int(mx_hp)]
	var lines: Array[String] = []
	lines.append("保护我方相位场驱动器，摧毁敌方即获胜；己方会持续部署战斗单位。")
	var pm: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pm != null:
		# ── 相位场等级（Lv1-30，养成进度）──
		var pf_level: int = 1
		if pm.has_method("get_phase_field_level"):
			pf_level = int(pm.get_phase_field_level())
		lines.append("相位场等级：Lv.%d" % pf_level)
		# ── 相位仪情报 ──
		var inst_cfg: Dictionary = pm.get_current_instrument() if pm.has_method("get_current_instrument") else {}
		if not inst_cfg.is_empty():
			var inst_name: String = str(inst_cfg.get("name", "未知相位仪"))
			var inst_star: int = int(inst_cfg.get("star", 0))
			if inst_star > 0:
				lines.append("相位仪：%s ★%d" % [inst_name, inst_star])
			else:
				lines.append("相位仪：%s" % inst_name)
		# ── 军团战力·星级（真实值，原派生Lv由战力换算与战力同义重复，已移除）──
		var ev: Dictionary = {}
		if pm.has_method("get_cached_player_master_eval"):
			ev = pm.get_cached_player_master_eval()
		if ev.is_empty():
			ev = MasterPlayerAssembler.evaluate_player_stars(pm)
		if not ev.is_empty():
			var stars: int = int(ev.get("stars", 3))
			var star_name: String = str(ev.get("star_name", ""))
			var raw: float = float(ev.get("raw_total_score", 0.0))
			if stars > 0 and not star_name.is_empty():
				lines.append("军团战力：%d · %d★ %s" % [int(raw), stars, star_name])
			else:
				lines.append("军团战力：%d" % int(raw))
		# ── 军团构成情报：战斗卡/符文/主动能力 ──
		var loadouts: Array = pm.get_loadouts() if pm.has_method("get_loadouts") else []
		if not loadouts.is_empty():
			lines.append("上场军团：%d 张战斗卡" % loadouts.size())
		var rune_slots: Array = pm.get_rune_slots() if pm.has_method("get_rune_slots") else []
		var active_runes: int = 0
		for slot_v in rune_slots:
			if slot_v != null and not str(slot_v).is_empty():
				active_runes += 1
		if active_runes > 0:
			var active_rw: Array = pm.get_active_runewords() if pm.has_method("get_active_runewords") else []
			var rw_str: String = ""
			if not active_rw.is_empty():
				var rw_names: Array[String] = []
				for rw in active_rw:
					var rn: String = str(rw.get("name", str(rw.get("id", ""))))
					if not rn.is_empty():
						rw_names.append(rn)
				if not rw_names.is_empty():
					rw_str = "（符文之语：" + " / ".join(rw_names) + "）"
			lines.append("符文：%d / %d 槽位%s" % [active_runes, rune_slots.size(), rw_str])
		var ability: Dictionary = pm.get_active_ability() if pm.has_method("get_active_ability") else {}
		if not ability.is_empty():
			var ab_name: String = str(ability.get("name", ""))
			var ab_desc: String = str(ability.get("description", ""))
			if not ab_name.is_empty():
				lines.append("主动能力：%s" % ab_name)
			if not ab_desc.is_empty():
				lines.append("  %s" % ab_desc)
		# ── 已解锁卡片技能（相位师面板承载全局终极技）──
		# 本卡触发的 source_tag 技能在各战斗卡的 _refresh_card_skill_section 显示；
		# 空 source_tag 的全局终极技（如 cps_steel_storm 钢铁风暴）无特定触发源，
		# 按用户决策只在相位师面板统一列出全部已解锁 CPS 技能（含全局终极技）。
		var sm: Node = get_node_or_null("/root/PhaseMasterSkillManager")
		if sm != null and sm.has_method("is_content_unlocked"):
			var skill_lines: Array[String] = []
			for sid in CardPeriodicSkills.get_all_skill_ids():
				if not sm.is_content_unlocked("card_skill", sid):
					continue
				var sk: Dictionary = CardPeriodicSkills.get_skill(sid)
				var nm: String = String(sk.get("name", sid))
				var ulti: String = " [终极]" if bool(sk.get("is_ultimate", false)) else ""
				var itv: float = float(sk.get("interval", 0.0))
				var itv_s: String = ("每%.0fs" % itv) if itv > 0.0 else ""
				var eff_cn: String = _card_skill_effect_summary(sk.get("effect", {}))
				skill_lines.append("  · %s%s（%s）：%s" % [nm, ulti, itv_s, eff_cn])
			if not skill_lines.is_empty():
				lines.append("已解锁卡片技能：")
				for sl in skill_lines:
					lines.append(sl)
	if desc_label: desc_label.text = "\n".join(lines)
	if flavor_label: flavor_label.text = "“守护这片相位场，即是守护军团存续。”"
	_clear_non_summary_info_sections()

func _clear_non_summary_info_sections() -> void:
	if affix_label: affix_label.text = ""
	if _star_detail_label: _star_detail_label.text = ""
	_set_section_visible_by_content(_star_section, "")
	if nurture_label: nurture_label.text = ""
	_set_section_visible_by_content(_nurture_section, "")
	if _card_skill_label: _card_skill_label.text = ""
	_set_section_visible_by_content(_card_skill_section, "")

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
	# v7.5: 产兵 platform_card_id 可能是敌方装备平台 ID（不在 DefaultCards 表），card_res 为 null。
	# 此处先判空，避免 safe_name(null) 触发无意义警告（下方 fallback 链已正确处理 null 情况）。
	var dn := DefaultCards.safe_name(card_res) if card_res != null else ""
	# v9.x: 势力前缀平台产兵（一战 4 相位师）名称加势力前缀。
	# faction_prefix meta 由 enemy_phase_field_driver 在产兵时按 LEGACY_PLATFORM_TO_ARCHETYPE 记录。
	var _faction_prefix: String = String(unit.get_meta("faction_prefix", ""))
	if not _faction_prefix.is_empty():
		if not dn.is_empty():
			dn = "%s·%s" % [_faction_prefix, dn]
		elif not safe_name.is_empty():
			safe_name = "%s·%s" % [_faction_prefix, safe_name]
	if name_label:
		name_label.text = dn if not dn.is_empty() else (safe_name if not safe_name.is_empty() else "敌方构装单位")
	var platform_name := dn if not dn.is_empty() else (safe_name if not safe_name.is_empty() else DefaultCards.get_platform_display_name(stats.platform_type))
	# v6.5: 优先用 card.weapon_names[] 显示具体武器型号，而非笼统的战斗方式
	var weapon_label_text: String = _build_weapon_label_text(card_res, stats)
	# v6.13: 产兵 platform_card_id 是敌方装备平台 ID（不在 DefaultCards 表）→ card_res 为 null，
	# _build_weapon_label_text 会落到第3兜底只给笼统"直射/曲射/空射"。
	# 此处用 stats.legacy_weapon_type（具体枪型，如 MG=2/MISSILE=9）查具体名"车载机枪/导弹"，
	# 比"空射武器"等笼统名更准确（legacy 值由产兵 _build_stats_from_archetype 从 archetype 透传）。
	if card_res == null and not weapon_label_text.is_empty():
		var legacy_wt: int = int(stats.legacy_weapon_type)
		if legacy_wt >= 0:
			weapon_label_text = RealWorldUnitLabels.weapon_kind_short(legacy_wt)
	if type_label:
		type_label.text = "相位师部署 · %s / %s" % [platform_name, weapon_label_text]
	var cur_hp: float = float(unit.get("hp")) if "hp" in unit else stats.max_hp
	if summary_label:
		summary_label.text = _format_unit_stats_summary(stats, cur_hp, _combat_power_suffix(stats))
	var base_desc := _build_unit_description(stats, false, "由敌方相位师基地生产的构装单位，自动推进并攻击我方。")
	# v19: 词缀行置顶——产兵词缀挂在 meta elite_affixes（enemy_phase_field_driver 词缀产兵写入）
	var _sp_affix_tags: Array = []
	if unit.has_meta("elite_affixes"):
		_sp_affix_tags = AffixDisplayFormat.fmt_enemy_affix_tags(unit.get_meta("elite_affixes"))
	if affix_label:
		affix_label.text = AffixDisplayFormat.merge_affix_text(_sp_affix_tags, _build_affix_summary_lines(stats), "词缀")
	# v7.x：敌方产兵无玩家养成，强化 section 置空并隐藏（避免占位）。
	# 原 _build_star_enhancement_effects_for_stats 是 v5.1 废弃的孤儿函数恒返回空。
	if _star_detail_label:
		_star_detail_label.text = ""
	_set_section_visible_by_content(_star_section, "")
	# v7.x：敌方构装单位显示其提供的平台光环（敌方 platform_type 同样驱动 AuraManager 注册，
	# 影响敌方群体）。无养成/符文，只显示光环段；无光环时 nurture section 自动隐藏。
	var enemy_nurture := _build_enemy_aura_text(unit)
	# v7.x：兵种机制——敌方产兵同样走 build_stats_from_card → _apply_v8_unit_type_meta，
	# stats 上有 is_stalker/is_sniper/is_ecm/is_engineer meta，与卡牌模式/我方单位同源显示。
	var _enemy_mech := _format_unit_mechanism_from_stats(stats)
	if not _enemy_mech.is_empty():
		enemy_nurture = "兵种机制：%s\n" % _enemy_mech + enemy_nurture
	if nurture_label:
		nurture_label.text = enemy_nurture
	_set_section_visible_by_content(_nurture_section, enemy_nurture)
	if desc_label:
		desc_label.text = base_desc
	if flavor_label:
		flavor_label.text = "“同一套装甲，站在战场的另一侧。”"
	# v7.x(敌方加成来源明细): 显示产兵 7 层加成来源明细
	var _spawn_bonus_text := _build_bonus_breakdown_text(unit)
	if _bonus_label: _bonus_label.text = _spawn_bonus_text
	_set_section_visible_by_content(_bonus_section, _spawn_bonus_text)

## ── 我方单位 ──

## v7.x：从战场单位反查带养成的实例卡（强化/改造数据所在）。
## 回退链：① unit 的 source_instance_id meta → InstanceRegistry.get_instance（精确）
##       ② 裸 card_id → get_instances_by_card_id 取首个实例（旧单位无 instance_id meta 时）
##       ③ 全失败 → DefaultCards 模板（无养成，仅显示基础信息，不会是常态）
## 非实例卡/旧存档单位 instance_id 为空 → 直接走 ②/③，行为与改动前一致。
func _resolve_source_instance_card(unit: Node) -> CardResource:
	if unit == null or not is_instance_valid(unit):
		return null
	var platform_card_id: String = ""
	if "stats" in unit and unit.stats != null:
		platform_card_id = String(unit.stats.platform_card_id)
	var inst_id: String = String(unit.get_meta("source_instance_id", ""))
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	# ① instance_id 精确取
	if ir != null and ir.has_method("get_instance") and not inst_id.is_empty():
		var inst: CardResource = ir.get_instance(inst_id)
		if inst != null:
			return inst
	# ② 裸 card_id → 该 card_id 的首个实例
	if ir != null and ir.has_method("get_instances_by_card_id") and not platform_card_id.is_empty():
		var insts: Array = ir.get_instances_by_card_id(platform_card_id)
		if not insts.is_empty() and ir.has_method("get_instance"):
			var fb: CardResource = ir.get_instance(String(insts[0]))
			if fb != null:
				return fb
	# ③ 兜底：共享模板（无养成）
	if not platform_card_id.is_empty():
		return DefaultCards.get_card_by_id(platform_card_id)
	return null

func _show_player_unit(unit: Node) -> void:
	var stats: UnitStats = unit.stats
	# v7.x：优先取带养成的实例卡（强化/改造数据在实例对象上，模板卡为空），
	# 让 nurture_label 能显示"等级 LvN（v19 三十级制）/ 改造 N/9 / 已装改造列表"。stats（HP/攻防）已含养成不变。
	var card_res: CardResource = _resolve_source_instance_card(unit)
	if card_res == null:
		card_res = DefaultCards.get_card_by_id(stats.platform_card_id)
	var safe_name := DefaultCards.get_safe_display_name(stats.platform_card_id)
	var dn := DefaultCards.safe_name(card_res)
	if name_label:
		# v7.x：同名卡追加序号后缀（#1/#2…），用实例卡 card_res 提取 instance_id
		var _unit_name: String = dn if not dn.is_empty() else (safe_name if not safe_name.is_empty() else "我方单位")
		name_label.text = _unit_name + DefaultCards.seq_suffix(card_res)
	# v7.x 修复：战场单位也要刷新稀有度标签/色带/星级，否则残留上次卡牌模式或 tscn 默认值
	# （此前相位仪显示"稀有"、战场却显示"普通"的根因：本函数从不设置 rarity_label）
	_apply_header_rarity_for_card(card_res)
	# v19: 头部等级（三十级制 card_level，与血条等级文字同口径）
	if star_label:
		star_label.text = ("Lv%d" % _card_level_for_display(card_res)) if card_res != null else ""
	# 战场单位已部署，费用无意义，清空避免残留
	if cost_label:
		cost_label.text = ""
	var platform_name := dn if not dn.is_empty() else (safe_name if not safe_name.is_empty() else DefaultCards.get_platform_display_name(stats.platform_type))
	# v6.5: 优先用 card.weapon_names[] 显示具体武器型号
	var weapon_label_text: String = _build_weapon_label_text(card_res, stats)
	if type_label:
		type_label.text = "%s / %s" % [platform_name, weapon_label_text]
	if summary_label:
		summary_label.text = _format_unit_stats_summary(stats, -1.0, _combat_power_suffix(stats))
	if affix_label:
		# v19: 真词条行（名称+稀有度+等级）置顶，stats 数值摘要保留在后
		var _p_affix_tags: Array = AffixDisplayFormat.fmt_player_affix_tags(_card_identity_id(card_res) if card_res != null else "", AffixManager)
		affix_label.text = AffixDisplayFormat.merge_affix_text(_p_affix_tags, _build_affix_summary_lines(stats), "词条")
		affix_label.tooltip_text = AffixDisplayFormat.tags_tooltip(_p_affix_tags)
	# v7.x 修复：战场单位强化详情改用 _build_star_lines（读实例卡养成），
	# 原 _build_star_enhancement_effects_for_stats(stats) 是 v5.1 废弃的孤儿函数恒返回空。
	# 内容为空时整个 StarSection 隐藏，避免空 section 占位。
	var star_detail_text := _build_star_lines(card_res) if card_res != null else ""
	if _star_detail_label:
		_star_detail_label.text = star_detail_text
	_set_section_visible_by_content(_star_section, star_detail_text)
	# v7.x：显示养成（强化等级/战力/改造列表 + 当前光环 + 相位仪符文）。
	# 光环仅我方单位有（construct_unit 注册），符文读 PhaseInstrumentManager。
	# 战场单位战力已移至 summary 行（属性口径，敌我可对比），此处 include_power=false 避免重复。
	var nurture_text := _build_nurture_text(card_res, null, false) if card_res != null else ""
	# v7.x：兵种机制（STALKER隐身/SNIPER首击/ECM光环/ENGINEER）——读 stats meta，
	# 与卡牌查看模式同源。部署后仍需显示，让玩家看到该单位的特殊机制。
	var _player_mech := _format_unit_mechanism_from_stats(stats)
	if not _player_mech.is_empty():
		nurture_text = "兵种机制：%s\n" % _player_mech + nurture_text
	nurture_text += _build_aura_text(unit)
	nurture_text += _build_rune_text()
	# v20.13c: 战场模式追加本场剩余部署次数（实时值，与底栏 ×N 角标同源）
	nurture_text += _build_battlefield_deploy_uses_line(card_res)
	# v20.15: 固定机制文案（战场单位模式与卡牌查看模式同源）
	var _mech_lines_bf: Array[String] = CardMechanismDesc.get_mechanism_lines(card_res.tags) if card_res != null else []
	if not _mech_lines_bf.is_empty():
		nurture_text += "固定机制：\n    · " + "\n    · ".join(_mech_lines_bf) + "\n"
	if nurture_label:
		nurture_label.text = nurture_text
	_set_section_visible_by_content(_nurture_section, nurture_text)
	if desc_label:
		desc_label.text = _build_unit_description(stats, true, "向敌侧推进，在射程内交战。选中后可点击地面微调站位。")
	if flavor_label:
		flavor_label.text = "“装甲军团永不疲倦。”"
	# v8.x：战场单位也显示关联卡片技能（source_tag 命中本单位 + 已解锁），口径与卡牌查看模式一致。
	# 直接传 unit.stats（已含 law_family/is_engineer 等 meta），无需构建显示缓存。
	_refresh_card_skill_section(card_res, stats)

## v20.13c: 战场情报面板——该卡本场剩余/总部署次数（实时值）。
## remaining 查 BattleManager._spawn_system.get_deploy_uses_remaining（战斗中实时追踪，
## 与底栏 ×N 角标同源）；total 走 UnifiedCardTable 口径（与商店/背包预览一致）。
## 非战斗卡/无限次/无 UCT 条目返回空。
func _build_battlefield_deploy_uses_line(card_res: CardResource) -> String:
	if card_res == null or card_res.card_type != GC.CardType.COMBAT_UNIT:
		return ""
	var base_id := card_res.card_id
	var hi := base_id.rfind("#")
	if hi > 0:
		base_id = base_id.substr(0, hi)
	var du_entry := UnifiedCardTable.get_entry(base_id)
	if du_entry.is_empty():
		return ""
	var total := UnifiedCardTable.get_deploy_uses(du_entry, card_res)
	if total >= 99:
		return ""  # 显式无限次配置，不显示
	var remaining := total
	if BattleManager != null and "battle_active" in BattleManager and BattleManager.battle_active \
			and "_spawn_system" in BattleManager and BattleManager._spawn_system != null:
		var ss = BattleManager._spawn_system
		if ss.has_method("get_deploy_uses_remaining"):
			# v20.16：次数池按实例分池——查询键用部署身份（实例卡 instance_id 优先）
			var du_id: String = String(card_res.instance_id) if not String(card_res.instance_id).is_empty() else base_id
			remaining = int(ss.get_deploy_uses_remaining(du_id))
	return "本场部署次数：%d / %d\n" % [remaining, total]

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
	var master_faction: String = ""
	var master_power_text: String = ""   # v7.x: 军团战力 · 星级 显示文本
	var trait_lines: Array[String] = []
	if GameManager and GameManager.has_method("get_current_phase_master"):
		master_cfg = GameManager.get_current_phase_master()
	if master_cfg.is_empty():
		var pm_id := "enemy_master_" + master_name.replace("unit_", "").lstrip("0")
		master_cfg = EnemyPhaseMasters.get_master_by_id(pm_id)
	if not master_cfg.is_empty():
		master_disp_name = str(master_cfg.get("name", ""))
		master_title = str(master_cfg.get("title", ""))
		master_faction = str(master_cfg.get("faction", ""))
		# v7.x: 计算军团战力/星级显示（原派生Lv由战力换算与战力同义重复，已移除）
		var _er_m: Dictionary = MasterPowerEvaluator.evaluate(master_cfg)
		master_power_text = "军团战力：%d · %s" % [int(_er_m.get("total_score", 0)), MasterPowerEvaluator.get_stars_display(master_cfg)]
		# v7.x: 澄清口径——军团战力是相位师裸装固有战力，不含本关难度加成（战场单位实战值会高于此数）
		master_power_text += "\n（相位师固有战力，战场单位会叠加本关难度加成）"
		# v9.1: trait 数值化——优先展示 effects 数值（如"攻击+15%"），无 effects 才回退 description
		# v18 四源重构: traits 已迁入技能树——直接读为空时经访问器回退（num 节点形态兼容）
		var traits: Array = master_cfg.get("traits", []) as Array
		if traits.is_empty():
			traits = EnemyPhaseMasters.get_master_traits(str(master_cfg.get("id", "")))
		for t in traits:
			if t is Dictionary:
				var tn: String = str(t.get("name", ""))
				var val_str: String = _format_trait_effects(t)
				if not tn.is_empty():
					if not val_str.is_empty():
						trait_lines.append("◆ %s：%s" % [tn, val_str])
					else:
						var td: String = str(t.get("description", ""))
						if not td.is_empty():
							trait_lines.append("◆ %s：%s" % [tn, td])
						else:
							trait_lines.append("◆ %s" % tn)
	if name_label:
		name_label.text = master_disp_name if not master_disp_name.is_empty() else "敌方相位师"
	var type_parts: Array[String] = []
	if not master_title.is_empty(): type_parts.append(master_title)
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
	if not master_power_text.is_empty():
		base_desc += "\n" + master_power_text
	if not trait_lines.is_empty():
		base_desc += "\n\n【相位师特性】\n" + "\n".join(trait_lines)
	# v7.x: 补全相位仪名+稀有度 + 符文（槽位比+符文之语）+ 主动能力（与基地路径一致）
	if not master_cfg.is_empty():
		var pm_id_m: String = str(master_cfg.get("id", ""))
		var eq_m: Dictionary = master_cfg.get("equipment", {}) as Dictionary
		if not pm_id_m.is_empty() and EnemyPhaseMasters != null:
			var enriched_eq_m: Dictionary = EnemyPhaseMasters.get_enriched_equipment(pm_id_m)
			if not enriched_eq_m.is_empty():
				eq_m = enriched_eq_m
		var inst_id_m: String = str(eq_m.get("phase_instrument", ""))
		var inst_name_m: String = _get_enemy_instrument_display_name(inst_id_m)
		var runes_m: Array = eq_m.get("runes", []) as Array
		var raw_level_m: int = int(master_cfg.get("level", 0))
		if not inst_name_m.is_empty() or not runes_m.is_empty():
			base_desc += "\n\n【相位师装备】"
			if not inst_name_m.is_empty():
				var inst_cfg_m: Dictionary = EnemyPhaseEquipment.get_phase_instrument(inst_id_m) if not inst_id_m.is_empty() else {}
				var rarity_zh_m: String = _enemy_instrument_rarity_zh(str(inst_cfg_m.get("rarity", "")))
				if not rarity_zh_m.is_empty():
					base_desc += "\n相位仪：%s（%s）" % [inst_name_m, rarity_zh_m]
				else:
					base_desc += "\n相位仪：%s" % inst_name_m
			if not runes_m.is_empty():
				var runes_line_m: String = _format_enemy_runes_full(runes_m, raw_level_m)
				if not runes_line_m.is_empty():
					base_desc += "\n符文：%s" % runes_line_m
		# 主动能力（master.active_spells + 相位仪 special_effects）
		var abilities_m: String = _format_enemy_active_abilities(pm_id_m, inst_id_m)
		if not abilities_m.is_empty():
			base_desc += "\n\n【主动能力】\n" + abilities_m
	# 敌方相位师的本体属性/装备/符文已在 base_desc 里展示。
	if desc_label:
		desc_label.text = base_desc
	if flavor_label:
		flavor_label.text = "“相位师的威严不容侵犯。”"
	_clear_other_unit_sections()
	# v7.x(敌方加成来源明细): 相位师单位是产兵路径来的（带 enemy_bonus_breakdown meta），
	# _clear_other_unit_sections 清空后重新填充加成来源明细。
	var _pm_bonus_text := _build_bonus_breakdown_text(unit)
	if _bonus_label: _bonus_label.text = _pm_bonus_text
	_set_section_visible_by_content(_bonus_section, _pm_bonus_text)

## v7.x(敌方加成来源明细): 从单位 meta 读取加成明细，构建"为什么这么强"的可读文本。
## 格式（总倍率+标签粒度）：
##   基础: 生命80｜攻10｜防5
##   加成: 波次×1.24 关卡(第40关)×1.36 势力(钢壁Lv5)×1.18 相位师×1.32 难度(普通)×1.0
##   二周目×1.2  ← 仅经典敌人/蜂群有
##   总倍率: 生命×4.0 攻击×4.0
##   最终: 生命320｜攻40｜防5
## 无明细返回空字符串（section 自动隐藏）。
func _build_bonus_breakdown_text(unit: Node) -> String:
	if unit == null or not is_instance_valid(unit):
		return ""
	if not unit.has_meta("enemy_bonus_breakdown"):
		return ""
	var bd: Dictionary = unit.get_meta("enemy_bonus_breakdown")
	if bd.is_empty():
		return ""
	var lines: Array = []
	# 基础值
	var base_hp: float = float(bd.get("base_hp", 0.0))
	var base_atk: float = float(bd.get("base_atk", 0.0))
	var base_def: float = float(bd.get("base_def", 0.0))
	lines.append("基础: 生命%d｜攻%d｜防%d" % [int(round(base_hp)), int(round(base_atk)), int(round(base_def))])
	# 加成来源标签
	var sources: Array = bd.get("sources", [])
	var labels: Array = []
	for s in sources:
		labels.append(String(s.get("label", "")))
	if not labels.is_empty():
		lines.append("加成: " + " ".join(labels))
	# 二周目（经典敌人/蜂群可能有，产兵恒 1.0）
	var ng_plus: float = float(bd.get("ng_plus", 1.0))
	if absf(ng_plus - 1.0) > 0.005:
		lines.append("二周目×%.2f" % ng_plus)
	# 总倍率（含二周目）
	var total_hp: float = float(bd.get("total_hp_mul", 1.0)) * ng_plus
	var total_atk: float = float(bd.get("total_atk_mul", 1.0)) * ng_plus
	lines.append("总倍率: 生命×%.1f 攻击×%.1f" % [total_hp, total_atk])
	# 最终值
	var final_hp: float = float(bd.get("final_hp", base_hp * total_hp))
	var final_atk: float = float(bd.get("final_atk", base_atk * total_atk))
	var final_def: float = float(bd.get("final_def", base_def))
	lines.append("最终: 生命%d｜攻%d｜防%d" % [int(round(final_hp)), int(round(final_atk)), int(round(final_def))])
	return "\n".join(lines)


func _clear_other_unit_sections() -> void:
	if affix_label: affix_label.text = ""
	if _star_detail_label: _star_detail_label.text = ""
	_set_section_visible_by_content(_star_section, "")
	if nurture_label: nurture_label.text = ""
	_set_section_visible_by_content(_nurture_section, "")
	if _card_skill_label: _card_skill_label.text = ""
	_set_section_visible_by_content(_card_skill_section, "")
	# v7.x(敌方加成来源明细): 切换到无明细单位时隐藏加成来源 section
	if _bonus_label: _bonus_label.text = ""
	_set_section_visible_by_content(_bonus_section, "")

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
	# v7.x 修复"碉堡显示冲锋枪"：weapon_type 字段在不同数据源用了两套互斥的枚举语义——
	#   ① enemy_archetypes_*.gd 固定敌人用 12 值 WeaponTypeLegacy（0=冲锋枪…11=轨道炮）
	#   ② enemy_unit_manifest / captured_card_stats 用 4 值 WeaponType（0=直射/1=曲射/2=空射/3=支援）
	# 显示层不能再无脑按 12 值 legacy 查表（会把 4 值语义的 0=直射 错译成"冲锋枪"）。
	# 新的显示优先级：
	#   ① weapon_label（具体武器名，如"机枪"/"88mm高射炮"）——最可靠，manifest/缴获卡已补全
	#   ② stats.legacy_weapon_type > 0 → 按 12 值 legacy 查 weapon_kind_short（改造指定型号）
	#   ③ weapon_type ∈ [0,11] 且来源是固定敌人（无 weapon_label）→ 按 12 值 legacy 查表
	#      （机枪巢=2=车载机枪 这种正确显示要保留）
	#   ④ 否则按 4 值语义给出泛称（0=直射武器/1=曲射武器/2=对空武器/3=支援设备）
	var show_wt: int = weapon_type_val
	var show_atk: float = attack_damage_val
	var show_label: String = ""
	# 取 archetype cfg 的 weapon_label（若有）
	if "archetype_id" in unit and unit.archetype_id is String:
		var _cfg2 = EnemyArchetypes.get_config(unit.archetype_id)
		if not _cfg2.is_empty():
			show_label = String(_cfg2.get("weapon_label", ""))
	if show_wt < 0 or show_atk <= 0.0:
		if "stats" in unit and unit.stats != null:
			show_wt = int(unit.stats.weapon_type)
			show_atk = float(unit.stats.attack_damage)
			if show_label.is_empty():
				# v7.5: UnitStats 是 Resource，Godot 4 的 Object.get() 只接受 1 参数，
				# 不支持 Dictionary 风格的 get(key, default)。改用直接属性访问。
				show_label = String(unit.stats.weapon_label)
	if show_wt >= 0 and show_atk > 0.0:
		var weapon_text := ""
		# ① 优先用具体武器名
		if not show_label.is_empty():
			weapon_text = show_label
		# ② legacy_weapon_type > 0 按 12 值 legacy 查表（改造型号优先）
		elif "stats" in unit and unit.stats != null and int(unit.stats.legacy_weapon_type) > 0:
			weapon_text = RealWorldUnitLabels.weapon_kind_short(int(unit.stats.legacy_weapon_type))
		# ③ weapon_type ∈ [0,11] 按 12 值 legacy 查表（兼容固定敌人 legacy 语义）
		elif show_wt >= 0 and show_wt <= 11:
			weapon_text = RealWorldUnitLabels.weapon_kind_short(show_wt)
		# ④ 兜底泛称（理论上 show_wt 已在 [0,11] 不会走到这）
		else:
			match show_wt:
				0: weapon_text = "直射武器"
				1: weapon_text = "曲射武器"
				2: weapon_text = "对空武器"
				3: weapon_text = "支援设备"
				_: weapon_text = "武器"
		type_text += "\n武装：%s" % weapon_text
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
		summary_label.text = _format_enemy_combat_summary(unit, s2, speed_text + _combat_power_suffix(unit.stats if ("stats" in unit and unit.stats != null) else null))
	if desc_label:
		var _e_stats: UnitStats = unit.stats if ("stats" in unit and unit.stats != null) else null
		desc_label.text = _build_unit_description(_e_stats, false, "来袭的敌方单位，优先攻击我方单位，其次攻击相位场驱动器。")
	# v19: 词缀行（名称+档位色）置顶——EnemyUnit.get_elite_affixes()（elite/boss 词缀怪）
	var _e_affix_tags: Array = []
	if unit.has_method("get_elite_affixes"):
		_e_affix_tags = AffixDisplayFormat.fmt_enemy_affix_tags(unit.get_elite_affixes())
	if "stats" in unit and unit.stats != null:
		if affix_label: affix_label.text = AffixDisplayFormat.merge_affix_text(_e_affix_tags, _build_affix_summary_lines(unit.stats), "词缀")
	elif affix_label:
		affix_label.text = AffixDisplayFormat.affix_tags_to_text(_e_affix_tags, "词缀")
	if flavor_label:
		flavor_label.text = "“相位裂隙的另一侧，总有人在看着你。”"
	# v7.x：敌方普通单位无玩家养成，强化 section 置空隐藏；但敌方 platform_type 驱动的
	# 光环（医疗/雷达/侦查/指挥）需显示——nurture section 改为填光环文本，空时才隐藏。
	if _star_detail_label: _star_detail_label.text = ""
	_set_section_visible_by_content(_star_section, "")
	var enemy_aura_text := _build_enemy_aura_text(unit)
	if nurture_label: nurture_label.text = enemy_aura_text
	_set_section_visible_by_content(_nurture_section, enemy_aura_text)
	# v7.x(敌方加成来源明细): 显示经典敌人/蜂群的加成来源明细
	var _bonus_text := _build_bonus_breakdown_text(unit)
	if _bonus_label: _bonus_label.text = _bonus_text
	_set_section_visible_by_content(_bonus_section, _bonus_text)

## ── 法则效果构建 ──

# v7.x: 按 label 文本是否为空，决定其所在 section（父 PanelContainer）的可见性。
# 用于战场单位模式：强化/养成等 section 内容为空时整个隐藏，避免空 section 占位。
func _set_section_visible_by_content(section: PanelContainer, text: String) -> void:
	if section:
		section.visible = not text.is_empty()

# ── 光环显示（提供/受到两段 + 数值 + MEDIC 补丁 + 敌方 + 卡牌预览） ──
#
# 平台光环类型枚举索引（与 AuraData.Category 一致）：
#   0 MEDIC_HEAL / 1 CARRIER_REPAIR / 2 SCOUT_CRIT / 3 RADAR_RANGE / 4 FORTRESS_DEF / 5 COMMAND_GLOBAL
# platform_type → 光环映射（复用 construct_unit.gd setup 的 register_aura match 表）：
#   3→FORTRESS_DEF / 4→RADAR_RANGE / 5,10→SCOUT_CRIT / 8→CARRIER_REPAIR / 9→MEDIC_HEAL / 12→COMMAND_GLOBAL

const _AURA_TYPE_NAMES := {
	0: "医疗光环",
	1: "运输维修",
	2: "侦查暴击",
	3: "雷达侦测",
	4: "堡垒防御",
	5: "指挥全局",
}

## platform_type → 平台光环类型（-1 表示该平台不提供光环）。
## 须与 construct_unit.gd setup 的 register_aura match 分支保持一致。
static func _platform_to_aura_type(platform_type: int) -> int:
	match platform_type:
		3: return 4  # FORTRESS_DEF
		4: return 3  # RADAR_RANGE
		5, 10: return 2  # SCOUT_CRIT
		8: return 1  # CARRIER_REPAIR
		9: return 0  # MEDIC_HEAL（自驱，不注册 AuraManager，显示层补）
		12: return 5  # COMMAND_GLOBAL
	return -1

## 将单条光环类型的参数格式化为可读效果（如"治疗8%/3秒""暴击+10%"）。
func _format_aura_effect_desc(aura_type: int, star: int) -> String:
	var params: Dictionary = AuraData.get_aura_params(aura_type, star)
	if params.is_empty():
		return ""
	match aura_type:
		0:  # MEDIC_HEAL
			return "每3秒治疗全体友军%d%%最大生命" % [int(float(params.get("heal_pct", 0.08)) * 100)]
		1:  # CARRIER_REPAIR
			return "每3秒维修机械类友军%d%%最大生命" % [int(float(params.get("heal_pct", 0.12)) * 100)]
		2:  # SCOUT_CRIT
			return "全体友军暴击+%d%%" % [int(float(params.get("crit_bonus", 0.08)) * 100)]
		3:  # RADAR_RANGE
			return "全体友军暴击+%d%%" % [int(float(params.get("crit_bonus", 0.10)) * 100)]
		4:  # FORTRESS_DEF
			return "全体友军减伤+%d%%、防御+%d" % [int(float(params.get("damage_reduction_bonus", 0.06)) * 100), int(float(params.get("defense_bonus", 2.0)))]
		5:  # COMMAND_GLOBAL
			return "全体友军攻击+%d%%、攻速+%d%%、暴击+%d%%" % [int(float(params.get("attack_mul", 0.05)) * 100), int(float(params.get("speed_mul", 0.05)) * 100), int(float(params.get("crit_mul", 0.02)) * 100)]
	return ""

# v7.x: 战场单位光环文本——分「提供的光环」和「受到的光环加成」两段。
# 提供段：本单位激活的平台光环（AuraManager 查询 + MEDIC 补丁）+ 改造光环（mod_aura_summary）。
# 受到段：本单位当前接收的改造光环（mod_aura_applied）+ 平台光环（遍历同阵营友军的一次性光环）。
# 仅我方单位调用此函数（_show_player_unit）；敌方用 _build_enemy_aura_text。
func _build_aura_text(unit: Node) -> String:
	if unit == null or not is_instance_valid(unit):
		return ""
	var am: Node = get_node_or_null("/root/AuraManager")
	var provide_lines: Array[String] = []
	var receive_lines: Array[String] = []

	# ── 提供段：平台光环 ──
	var star: int = 1
	if am != null and am.has_method("get_unit_star"):
		star = am.get_unit_star(unit)
	var aura_types: Array[int] = []
	if am != null and am.has_method("get_unit_aura_types"):
		aura_types = am.get_unit_aura_types(unit)
	# MEDIC 补丁：platform_type==9 自驱不注册 AuraManager，显示层补一条
	if "stats" in unit and unit.stats != null and unit.stats.platform_type == 9:
		if not aura_types.has(0):
			aura_types.append(0)
	for t in aura_types:
		var idx: int = int(t)
		var nm: String = _AURA_TYPE_NAMES.get(idx, "")
		if nm.is_empty():
			continue
		var desc: String = _format_aura_effect_desc(idx, star)
		if not desc.is_empty():
			provide_lines.append("  · %s：%s" % [nm, desc])
		else:
			provide_lines.append("  · %s" % nm)

	# ── 提供段：改造光环（本单位装了 ally_* 改造 → 给友军的 buff） ──
	if unit.has_meta("mod_aura_summary"):
		var summary = unit.get_meta("mod_aura_summary")
		if summary is Dictionary and not summary.is_empty():
			var effects: Array[String] = []
			for sf in summary:
				var rule: Dictionary = summary[sf]
				var op: String = rule.get("op", "add")
				var raw: float = float(rule.get("raw", 0.0))
				effects.append(_mod_aura_stat_desc(sf, op, raw))
			if not effects.is_empty():
				provide_lines.append("  · 改造光环（给予友军）：%s" % ", ".join(effects))

	# ── 受到段：改造光环（来自友军的 ally_* 改造广播） ──
	if unit.has_meta("mod_aura_applied"):
		var applied = unit.get_meta("mod_aura_applied")
		if applied is Array and not applied.is_empty():
			for entry in applied:
				if not (entry is Dictionary):
					continue
				var summary: Dictionary = entry.get("summary", {})
				if summary.is_empty():
					continue
				var effects: Array[String] = []
				for sf in summary:
					var rule: Dictionary = summary[sf]
					var op: String = rule.get("op", "add")
					var raw: float = float(rule.get("raw", 0.0))
					effects.append(_mod_aura_stat_desc(sf, op, raw))
				if not effects.is_empty():
					receive_lines.append("  · 改造光环：%s" % ", ".join(effects))

	# ── 受到段：平台光环（遍历同阵营友军的一次性光环 RADAR/SCOUT/FORTRESS/COMMAND） ──
	# MEDIC/CARRIER 是周期治疗，不列在"持续 buff"避免与治疗结算口径冲突
	if am != null and am.has_method("get_unit_aura_types"):
		var source_labels: Dictionary = {}  # aura_type -> 友军名列表
		var allies: Array = _get_same_side_allies(unit)
		for ally in allies:
			if not is_instance_valid(ally):
				continue
			var ally_types: Array[int] = am.get_unit_aura_types(ally)
			for at in ally_types:
				var ati: int = int(at)
				# 仅一次性光环（非周期治疗）才计入"受到"
				if ati == 0 or ati == 1:  # MEDIC_HEAL / CARRIER_REPAIR 周期类跳过
					continue
				var ally_name: String = _ally_display_name(ally)
				if not source_labels.has(ati):
					source_labels[ati] = []
				(source_labels[ati] as Array).append(ally_name)
		# 去重友军名后格式化
		for ati in source_labels.keys():
			var nm: String = _AURA_TYPE_NAMES.get(int(ati), "")
			if nm.is_empty():
				continue
			var desc: String = _format_aura_effect_desc(int(ati), star)
			var src_names: Array = source_labels[ati]
			# 去重
			var uniq: Array[String] = []
			for s in src_names:
				if not uniq.has(String(s)):
					uniq.append(String(s))
			var src_str: String = ", ".join(uniq) if not uniq.is_empty() else ""
			if not src_str.is_empty():
				if not desc.is_empty():
					receive_lines.append("  · %s（来自 %s）：%s" % [nm, src_str, desc])
				else:
					receive_lines.append("  · %s（来自 %s）" % [nm, src_str])

	# 组装两段
	var parts: Array[String] = []
	if not provide_lines.is_empty():
		parts.append("【提供的光环】\n" + "\n".join(provide_lines))
	if not receive_lines.is_empty():
		parts.append("【受到的光环加成】\n" + "\n".join(receive_lines))
	if parts.is_empty():
		return ""
	return "\n" + "\n".join(parts)

## 卡牌模式（背包/商店/相位仪查看）光环预览——无战场 unit，从 stats.platform_type 反推。
func _build_aura_preview_text(card: CardResource, stats: UnitStats) -> String:
	if card == null or stats == null:
		return ""
	if card.card_type != GC.CardType.COMBAT_UNIT:
		return ""
	# v20.x 口径守卫：我方卡 stats.platform_type = combat_kind(0-4)，与 legacy 光环平台值
	# 3=FORTRESS/4=RADAR 撞值（空中卡会误预览"堡垒防御"、堡垒卡误预览"雷达侦测"）。
	# 我方卡的平台光环本就不经 legacy 注册（construct_unit 已 is_player 守卫），
	# 「pt==ck 且 ≤4」判定为卡牌口径 → 不做平台光环预览（改造光环预览不受影响）。
	var _is_card_kind_scope: bool = int(stats.platform_type) == int(stats.combat_kind) and int(stats.platform_type) <= 4
	var aura_type: int = -1 if _is_card_kind_scope else _platform_to_aura_type(stats.platform_type)
	var lines: Array[String] = []
	# 平台光环预览
	if aura_type >= 0:
		# v20.12 等级统一：光环星级从战斗卡等级换算（30级÷3 → 1-10 星，与战场 get_unit_star 同口径）
		var star: int = clampi(int(round(float(_card_level_for_display(card)) / 3.0)), 1, 10)
		var nm: String = _AURA_TYPE_NAMES.get(aura_type, "")
		var desc: String = _format_aura_effect_desc(aura_type, star)
		if not nm.is_empty():
			if not desc.is_empty():
				lines.append("  · %s：%s" % [nm, desc])
			else:
				lines.append("  · %s" % nm)
	# 改造光环预览：读 stats 的 mod_aura_summary meta（build_stats_from_card 时 _apply_mod_stat_effects 写入）
	if stats.has_meta("mod_aura_summary"):
		var summary = stats.get_meta("mod_aura_summary")
		if summary is Dictionary and not summary.is_empty():
			var effects: Array[String] = []
			for sf in summary:
				var rule: Dictionary = summary[sf]
				var op: String = rule.get("op", "add")
				var raw: float = float(rule.get("raw", 0.0))
				effects.append(_mod_aura_stat_desc(sf, op, raw))
			if not effects.is_empty():
				lines.append("  · 改造光环（给予友军）：%s" % ", ".join(effects))
	if lines.is_empty():
		return ""
	return "\n部署后光环：\n" + "\n".join(lines)

## 敌方构装单位光环文本——只显示「提供的光环」段（敌方无养成，不显示强化/改造）。
func _build_enemy_aura_text(unit: Node) -> String:
	if unit == null or not is_instance_valid(unit):
		return ""
	var am: Node = get_node_or_null("/root/AuraManager")
	var provide_lines: Array[String] = []
	# 敌方 platform_type 同样驱动 register_aura（construct_unit.gd 对 player/enemy 都执行）
	var aura_types: Array[int] = []
	if am != null and am.has_method("get_unit_aura_types"):
		aura_types = am.get_unit_aura_types(unit)
	# MEDIC 补丁（敌方医疗车同样自驱不注册）
	if "stats" in unit and unit.stats != null and unit.stats.platform_type == 9:
		if not aura_types.has(0):
			aura_types.append(0)
	var star: int = 1
	if am != null and am.has_method("get_unit_star"):
		star = am.get_unit_star(unit)
	for t in aura_types:
		var idx: int = int(t)
		var nm: String = _AURA_TYPE_NAMES.get(idx, "")
		if nm.is_empty():
			continue
		var desc: String = _format_aura_effect_desc(idx, star)
		if not desc.is_empty():
			provide_lines.append("  · %s：%s" % [nm, desc])
		else:
			provide_lines.append("  · %s" % nm)
	if provide_lines.is_empty():
		return ""
	return "\n【敌方光环】\n" + "\n".join(provide_lines)

## 获取同阵营友军列表（不含自身），用于查"受到的平台光环"。
func _get_same_side_allies(unit: Node) -> Array:
	if unit == null or not is_instance_valid(unit):
		return []
	var tree: SceneTree = unit.get_tree()
	if tree == null:
		return []
	var is_player: bool = bool(unit.get("is_player")) if "is_player" in unit else true
	var group_name: String = "player_units" if is_player else "enemy_units"
	var bm: Node = tree.root.get_node_or_null("BattleManager")
	var group_nodes: Array = []
	if bm != null and is_instance_valid(bm) and bm.has_method("get_cached_nodes_in_group"):
		var active: bool = bool(bm.get("battle_active")) if "battle_active" in bm else false
		if active:
			group_nodes = bm.get_cached_nodes_in_group(group_name)
	if group_nodes.is_empty():
		group_nodes = tree.get_nodes_in_group(group_name)
	var result: Array = []
	for node in group_nodes:
		if is_instance_valid(node) and node != unit:
			result.append(node)
	return result

## 友军显示名（用于"受到的光环（来自 X）"标注）。
func _ally_display_name(unit: Node) -> String:
	if unit == null or not is_instance_valid(unit):
		return ""
	var dn: String = ""
	if "stats" in unit and unit.stats != null:
		var card_res: CardResource = _resolve_source_instance_card(unit)
		if card_res != null:
			dn = DefaultCards.safe_name(card_res)
		if dn.is_empty():
			dn = DefaultCards.get_safe_display_name(unit.stats.platform_card_id)
		if dn.is_empty():
			dn = DefaultCards.get_platform_display_name(unit.stats.platform_type)
	return dn if not dn.is_empty() else "友军"

## 将 mod_aura stat_field 转换为可读描述（如"攻击+10%"、"暴击率+5%"）
func _mod_aura_stat_desc(stat_field: String, op: String, raw: float) -> String:
	# 映射 stat_field 到中文名称
	const STAT_NAMES := {
		"attack_light": "轻攻",
		"attack_armor": "重攻",
		"attack_air": "空攻",
		"attack_all": "全攻",
		"defense_light": "轻防",
		"defense_armor": "重防",
		"defense_air": "空防",
		"defense_all": "全防",
		"attack_light_speed": "轻攻速",
		"attack_armor_speed": "重攻速",
		"attack_air_speed": "空攻速",
		"crit_chance": "暴击率",
		"dodge_chance": "闪避率",
		"armor_penetration": "穿甲率",
		"hp_regen": "生命恢复",
		"kill_repair": "击杀修复",
		"move_speed": "移速",
		"attack_range": "射程",
		"vision": "视野",
		"attack_interval": "攻速间隔",
		"detection": "侦测",
	}
	var name: String = STAT_NAMES.get(stat_field, stat_field)
	if op == "add" or op == "abs_add":
		if raw > 0:
			return "%s+%d%%" % [name, int(raw * 100)]
		return "%s%d%%" % [name, int(raw * 100)]
	elif op == "mult_int":
		var pct: float = raw * 100.0
		return "%s×%.0f%%" % [name, pct]
	elif op == "ammo":
		var pct: float = raw * 100.0
		return "%s-%.0f%%" % [name, pct]
	elif op == "river":
		return "%s+%d" % [name, int(raw * 80)]
	return "%s:%.1f" % [name, raw]

## tags 标签中文翻译（unified_card_table 的英制 tag → 中文定位标签）
# v8.x: 扩展新兵种标签（stalker/sniper/ecm/engineer/stealth 等）
const _TAG_NAMES_CN := {
	"infantry": "步兵",
	"vehicle": "载具",
	"armored": "装甲",
	"support": "支援",
	"aircraft": "空中",
	"fortress": "堡垒",
	"immobile": "固定",
	"boss": "BOSS",
	"elite": "精英",
	# v8.x 新兵种标签
	"stalker": "渗透者",
	"sniper": "狙击手",
	"ecm": "电子战",
	"engineer": "工程兵",
	"stealth": "潜行",
	# v8.x 战术标签
	"fast": "快攻",
	"artillery": "火炮",
	"antitank": "反坦克",
	"command": "指挥",
	"recon": "侦察",
}

## v8.x: 兵种机制描述表（标签 → 机制说明，用于卡片信息面板显示）
# v8.x 修订：补全 9 个传统兵种固定机制（apply_combat_kind_modifiers 写入的字段/meta）。
#           文案严格对齐实际生效数值，不提未实装内容（如地雷、烟雾、射程加成等空转项）。
#           stealth 描述从未被读取（_format_unit_mechanism_from_stats 不读 stealth meta，且 card.tags
#           全链路不填充），保留但标注死代码，避免误导。
const _UNIT_MECHANISM_DESC := {
	# ── 传统兵种固定机制（由 combat_kind + unit_subtype 派生，所有同兵种单位共有）──
	"infantry": "步兵：受装甲/空军攻击减伤15%（巷战掩蔽）",
	"recon": "侦察：部署后前15秒受伤-40%（潜入开局）",
	"armor": "装甲：对轻装/支援目标伤害+20%（碾压）",
	"artillery": "炮兵：曲射弹道，受击时标记攻击者（反炮兵）",
	"anti_air": "防空：对空军伤害+25%（空域封锁），优先锁定空中目标",
	"air": "空军：部署后前10秒攻速×1.5（突袭击速）",
	"engineer_class": "工兵：对装甲/堡垒目标造成2%当前生命额外真实伤害（爆破专精）",
	"fort": "堡垒：自身减伤30%+半径250内地面友军减伤10%（阵地坚守光环）",
	# ── 新兵种标签机制（由 card_id 前缀/tag 打 meta，仅特定单位有）──
	"stalker": "渗透者：部署后前4秒受伤-60%，首次攻击伤害×1.5",
	"sniper": "狙击手：射程+30%，首次攻击必暴击，优先锁定高价值目标",
	"ecm": "电子战：半径250内敌方攻速-25%、暴击-15%、闪避-20%",
	"engineer": "工程兵：对装甲/堡垒目标造成额外真实伤害（见下方爆破专精）",
	# ── v8.5 兵种机制技能（技能树解锁后，由 meta 触发显示）──
	"is_demolition": "定向爆破：每12秒自动爆破最近敌方堡垒/装甲（8%最大生命真实伤害）",
	"is_sniper_aim": "瞄准狙击：每15秒进入瞄准，下次攻击必暴+50%伤（对Boss×2）",
	"is_blitz_pierce": "闪电穿插：每10秒下次攻击穿透打后排2个单位",
	"is_jamming_field": "电子屏蔽：每18秒释放屏蔽波，敌方攻击失效3秒",
		"is_nuclear_strike": "战术核武：每45秒由导弹发射井发射战术核弹，弹道飞行后对敌方密集区半径200内造成35%最大生命（保底200）范围伤害",
	"is_shield_projector": "护盾投射：每20秒为3个低血友军投射护盾",
	"is_drone_mark": "定时标记：每14秒标记2个最高威胁敌方+25%易伤",
	# ⚠️ stealth 为死代码：_format_unit_mechanism_from_stats 不读 stealth meta，
	#    且 card.tags 全链路不填充，此条永不显示。保留仅供 _format_unit_mechanism_cn 兜底。
	"stealth": "潜行：前4秒受伤-60%",
}

## 将 card.tags 翻译为中文定位标签字符串（如"装甲·载具"），空则返回 ""。
func _format_tags_cn(tags) -> String:
	if tags == null:
		return ""
	var arr: Array = tags if tags is Array else []
	if arr.is_empty():
		return ""
	var names: Array[String] = []
	for t in arr:
		var key: String = String(t)
		var cn: String = _TAG_NAMES_CN.get(key, "")
		if not cn.is_empty() and not names.has(cn):
			names.append(cn)
	if names.is_empty():
		return ""
	return "·".join(names)

## v8.x: 提取卡牌 tags 中的兵种机制描述（STALKER/SNIPER/ECM/ENGINEER/STEALTH）
## 返回机制说明字符串（多条用换行分隔），无则返回 ""
func _format_unit_mechanism_cn(tags) -> String:
	if tags == null:
		return ""
	var arr: Array = tags if tags is Array else []
	if arr.is_empty():
		return ""
	var descs: Array = []
	for t in arr:
		var key: String = String(t)
		if _UNIT_MECHANISM_DESC.has(key):
			var d: String = String(_UNIT_MECHANISM_DESC[key])
			if not descs.has(d):
				descs.append(d)
	return "\n".join(descs)

## v7.x→v8.x: 从 UnitStats 提取兵种机制描述。
## 优先级：新兵种 meta（is_stalker/is_sniper/is_ecm/is_engineer）→ 传统兵种（combat_kind+subtype 派生）。
## meta 由 unit_stats_table._apply_v8_unit_type_meta 通过 card_id 前缀打标（card.tags 全链路不填充，故不读）；
## 传统兵种由 apply_combat_kind_modifiers（unit_stats_table.gd:583）按 combat_kind+subtype 写入对应字段/meta。
## 卡牌查看模式（_cached_display_stats 已含 meta）与战场单位模式（unit.stats 已含 meta）统一用此函数。
## 返回机制说明字符串（多条用换行分隔），无则返回 ""
func _format_unit_mechanism_from_stats(stats: UnitStats) -> String:
	if stats == null:
		return ""
	var descs: Array[String] = []
	# ── 新兵种 meta（is_stalker/is_sniper/is_ecm/is_engineer），与 _apply_v8_unit_type_meta 写入的 key 对齐 ──
	var is_engineer_tag := stats.has_meta("is_engineer") and bool(stats.get_meta("is_engineer", false))
	if stats.has_meta("is_stalker") and bool(stats.get_meta("is_stalker", false)):
		descs.append(String(_UNIT_MECHANISM_DESC.get("stalker", "")))
	if stats.has_meta("is_sniper") and bool(stats.get_meta("is_sniper", false)):
		descs.append(String(_UNIT_MECHANISM_DESC.get("sniper", "")))
	if stats.has_meta("is_ecm") and bool(stats.get_meta("is_ecm", false)):
		descs.append(String(_UNIT_MECHANISM_DESC.get("ecm", "")))
	if is_engineer_tag:
		descs.append(String(_UNIT_MECHANISM_DESC.get("engineer", "")))

	# ── 传统兵种固定机制（v8.x 补全：按 combat_kind + unit_subtype 派生）──
	# 与 apply_combat_kind_modifiers 的写入条件对齐，确保"有该机制才显示该说明"。
	var ck: int = stats.combat_kind
	var sub: int = stats.unit_subtype
	var is_recon := stats.has_meta("is_recon_unit") and bool(stats.get_meta("is_recon_unit", false))
	# 工兵是 SUPPORT/SUPPORT 子类，但有独立爆破专精；engineer_class 与 engineer 标签文案不重复（前者讲爆破，后者讲技能触发源）
	# 防空/炮兵/工兵都属 SUPPORT 主类，靠 subtype 区分：ARTILLERY=1 / SUPPORT=2 / ANTI_AIR=4
	if ck == GC.CombatKind.LIGHT:
		# LIGHT 主类：步兵（含侦察分支）
		if is_recon:
			descs.append(String(_UNIT_MECHANISM_DESC.get("recon", "")))
		elif sub == GC.UnitSubType.NONE:
			descs.append(String(_UNIT_MECHANISM_DESC.get("infantry", "")))
	elif ck == GC.CombatKind.ARMOR:
		# ARMOR 主类：装甲（堡垒走 FORT 子类，由 ARMOR+FORT 分支处理）
		if sub != GC.UnitSubType.FORT:
			descs.append(String(_UNIT_MECHANISM_DESC.get("armor", "")))
	elif ck == GC.CombatKind.SUPPORT:
		# SUPPORT 主类：按 subtype 区分炮兵/防空/工兵
		match sub:
			GC.UnitSubType.ARTILLERY:
				descs.append(String(_UNIT_MECHANISM_DESC.get("artillery", "")))
			GC.UnitSubType.ANTI_AIR:
				descs.append(String(_UNIT_MECHANISM_DESC.get("anti_air", "")))
			GC.UnitSubType.SUPPORT:
				# 工兵（SUPPORT 子类）有爆破专精；若已有 engineer 标签，只补爆破说明避免重复
				descs.append(String(_UNIT_MECHANISM_DESC.get("engineer_class", "")))
	elif ck == GC.CombatKind.AIR:
		descs.append(String(_UNIT_MECHANISM_DESC.get("air", "")))
	elif ck == GC.CombatKind.FORT:
		descs.append(String(_UNIT_MECHANISM_DESC.get("fort", "")))

	# ── v8.5 兵种机制技能（技能树解锁后由 _apply_v8_unit_type_meta 打 meta）──
	# 7 个机制 meta：仅在技能树解锁 + 兵种匹配时才写入，故检测到即显示
	for meta_key in ["is_demolition", "is_sniper_aim", "is_blitz_pierce", "is_jamming_field",
					 "is_nuclear_strike", "is_shield_projector", "is_drone_mark"]:
		if stats.has_meta(meta_key) and bool(stats.get_meta(meta_key, false)):
			descs.append(String(_UNIT_MECHANISM_DESC.get(meta_key, "")))

	# 过滤空串（_UNIT_MECHANISM_DESC 缺 key 时 get 返回 ""）
	var filtered: Array[String] = []
	for d in descs:
		if not d.is_empty() and not filtered.has(d):
			filtered.append(d)
	return "\n".join(filtered)

# v7.x: 玩家相位仪符文文本——读 PhaseInstrumentManager 的符文槽位 + 激活的符文之语。
# 返回空串表示无任何符文；非空形如：
#   "\n相位仪符文：攻击符文Ⅰ(稀有) · 防御符文Ⅰ(稀有)\n激活符文之语：锐利(2符文之语)"
func _build_rune_text() -> String:
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim == null:
		return ""
	# 符文加成汇总——只显示数值加成与特殊效果，不列符文/符文之语的名字明细
	# （符文属相位仪全局，不是这张战斗卡本身的属性；玩家只需看到它带来的加成）。
	var bonus: Dictionary = pim.get_rune_bonus() if pim.has_method("get_rune_bonus") else {}
	if bonus.is_empty():
		return ""
	var stat_map: Dictionary = bonus.get("stats", {})
	var specials: Array = bonus.get("specials", [])
	if stat_map.is_empty() and specials.is_empty():
		return ""
	var parts: Array[String] = []
	# 数值加成（值是小数 0.5 = +50%，统一按百分比显示）
	if not stat_map.is_empty():
		var stat_lines: Array[String] = []
		for sk in stat_map.keys():
			var nm: String = String(RuneDefs.STAT_SHORT_NAMES.get(sk, sk))
			var val: float = float(stat_map[sk])
			if val > 0.0:
				stat_lines.append("%s+%d%%" % [nm, int(val * 100.0)])
			elif val < 0.0:
				stat_lines.append("%s%d%%" % [nm, int(val * 100.0)])
		if not stat_lines.is_empty():
			parts.append("符文加成：" + " · ".join(stat_lines))
	# 特殊效果（去重后列名称）
	if not specials.is_empty():
		var seen: Dictionary = {}
		var sp_lines: Array[String] = []
		for sp in specials:
			if not (sp is Dictionary):
				continue
			var sp_key: String = String(sp.get("special", ""))
			if sp_key.is_empty() or seen.has(sp_key):
				continue
			seen[sp_key] = true
			sp_lines.append(String(RuneDefs.SPECIAL_DISPLAY_NAMES.get(sp_key, sp_key)))
		if not sp_lines.is_empty():
			parts.append("符文特效：" + " · ".join(sp_lines))
	if parts.is_empty():
		return ""
	return "\n" + "\n".join(parts)
