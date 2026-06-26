extends Control
class_name CardEnhancementPanel
## 卡牌强化UI面板
##
## 功能：
## - 显示所有可强化的卡牌列表
## - 显示当前强化等级和升级成本
## - 显示纳米材料余额
## - 执行强化操作
## - 显示强化结果反馈

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const EnemyBlueprints = preload("res://data/enemy_blueprints.gd")
const UnitLineageConfig = preload("res://data/unit_lineage_config.gd")
const RankRules = preload("res://data/rank_rules.gd")
const CompanyDefinitions = preload("res://data/company_definitions.gd")
# StarConfig removed - star_level system deprecated in v5.1
const BasicResources = preload("res://data/basic_resources.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")

# === 主题色（绿色强化主题） ===
const THEME_GREEN := Color(0.3, 0.92, 0.5, 1)
const THEME_GREEN_SOFT := Color(0.2, 0.7, 0.38, 1)
const THEME_CYAN := Color(0.0, 0.9, 1.0, 1)
const THEME_GOLD := Color(1.0, 0.85, 0.35, 1)
const THEME_PURPLE := Color(0.75, 0.55, 1.0, 1)
const THEME_RED := Color(0.95, 0.4, 0.4, 1)
const THEME_TEXT := Color(0.88, 0.92, 0.98, 1)
const THEME_TEXT_DIM := Color(0.6, 0.66, 0.78, 1)
const THEME_BG_CARD := Color(0.07, 0.12, 0.16, 0.92)
const THEME_BG_SLOT := Color(0.05, 0.08, 0.11, 0.95)
const THEME_BORDER_DIM := Color(0.25, 0.35, 0.42, 0.7)

signal closed

# UI 组件引用 - 新布局结构
@onready var card_list_container = $VBoxContainer/MainSplit/LeftPanel/ScrollContainer/CardListContainer
@onready var card_detail_panel = $VBoxContainer/MainSplit/RightPanel
@onready var no_selection_label = $VBoxContainer/MainSplit/RightPanel/NoSelectionLabel
@onready var detail_scroll = $VBoxContainer/MainSplit/RightPanel/DetailScroll
@onready var detail_panel = $VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel
@onready var star_upgrade_button = $VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel/StarUpgradeSection/StarUpgradeVBox/StarUpgradeButton
@onready var enhancement_button = $VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel/EnhancementSection/EnhancementVBox/EnhancementButton
@onready var evolve_button = $VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel/EvolutionSection/EvolutionVBox/EvolveButton
@onready var evolution_branch_selector: OptionButton = $VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel/EvolutionSection/EvolutionVBox/EvolutionBranchSelector
@onready var nano_label = $VBoxContainer/ResourceArea/ResourceHBox/NanoLabel
@onready var research_label = $VBoxContainer/ResourceArea/ResourceHBox/ResearchLabel
@onready var result_label = $VBoxContainer/ResultLabel
@onready var evolution_confirm_dialog: ConfirmationDialog = $EvolutionConfirmDialog

# 数据
var selected_card_id: String = ""
var card_items: Array = []
var _pending_evolution_target_id: String = ""
var _pending_evolution_candidates: Array[String] = []
var _is_syncing_evolution_selector: bool = false
var _evolution_selector_meta: Array[Dictionary] = []

func _ready() -> void:
	# 连接关闭按钮
	var close_btn = get_node_or_null("VBoxContainer/TitleArea/TitleHBox/CloseButton")
	if close_btn:
		close_btn.pressed.connect(_on_close)
	# 连接信号
	ManagerLazyLoader.ensure_loaded("card_enhancement")
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	if card_enh_mgr:
		card_enh_mgr.enhancement_completed.connect(_on_enhancement_completed)
		card_enh_mgr.enhancement_failed.connect(_on_enhancement_failed)

	if BlueprintManager:
		if BlueprintManager.has_signal("fragments_changed"):
			if not BlueprintManager.fragments_changed.is_connected(_on_nano_materials_changed):
				BlueprintManager.fragments_changed.connect(_on_nano_materials_changed)

	if star_upgrade_button:
		star_upgrade_button.pressed.connect(_on_star_upgrade_button_pressed)
	if BasicResourceManager and BasicResourceManager.has_signal("resources_changed"):
		if not BasicResourceManager.resources_changed.is_connected(_on_nano_materials_changed):
			BasicResourceManager.resources_changed.connect(_on_nano_materials_changed)
	if enhancement_button:
		enhancement_button.pressed.connect(_on_enhance_button_pressed)
	if evolve_button:
		evolve_button.pressed.connect(_on_evolve_button_pressed)
	if evolution_branch_selector and not evolution_branch_selector.item_selected.is_connected(_on_evolution_branch_selected):
		evolution_branch_selector.item_selected.connect(_on_evolution_branch_selected)
	if evolution_confirm_dialog and not evolution_confirm_dialog.confirmed.is_connected(_on_confirm_evolution):
		evolution_confirm_dialog.confirmed.connect(_on_confirm_evolution)
	if SignalBus and SignalBus.has_signal("card_added_to_backpack"):
		if not SignalBus.card_added_to_backpack.is_connected(_on_card_added_to_backpack):
			SignalBus.card_added_to_backpack.connect(_on_card_added_to_backpack)

	# 初始化卡牌列表
	_init_card_list()
	_update_resource_labels()

# v6.2 修复 M9：断开所有 _ready 中连接的信号，防止面板销毁后回调访问已释放节点
func _exit_tree() -> void:
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	if card_enh_mgr:
		if card_enh_mgr.enhancement_completed.is_connected(_on_enhancement_completed):
			card_enh_mgr.enhancement_completed.disconnect(_on_enhancement_completed)
		if card_enh_mgr.enhancement_failed.is_connected(_on_enhancement_failed):
			card_enh_mgr.enhancement_failed.disconnect(_on_enhancement_failed)
	if BlueprintManager and BlueprintManager.has_signal("fragments_changed"):
		if BlueprintManager.fragments_changed.is_connected(_on_nano_materials_changed):
			BlueprintManager.fragments_changed.disconnect(_on_nano_materials_changed)
	if BasicResourceManager and BasicResourceManager.has_signal("resources_changed"):
		if BasicResourceManager.resources_changed.is_connected(_on_nano_materials_changed):
			BasicResourceManager.resources_changed.disconnect(_on_nano_materials_changed)
	if SignalBus and SignalBus.has_signal("card_added_to_backpack"):
		if SignalBus.card_added_to_backpack.is_connected(_on_card_added_to_backpack):
			SignalBus.card_added_to_backpack.disconnect(_on_card_added_to_backpack)
	# 初始化详情面板为空状态
	_update_detail_panel()
	# 改造系统分区标题挂图标（改装/强化/进化）
	_apply_section_title_icons()

## 给分区标题 Label 前置图标：把 Label 包进 HBox + TextureRect（运行时重构）
func _apply_section_title_icons() -> void:
	# 强化：mod_enhancement.png 在 mod_icons 子目录
	var enh_tex := UiAssetLoader.load_tex("res://assets/ui/icons/mod_icons/mod_enhancement.png")
	# 进化：根目录 svg
	var evo_tex := UiAssetLoader.ui_icon("icon_blueprint")
	_prepend_icon_to_label(
		get_node_or_null("VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel/EnhancementSection/EnhancementVBox/EnhancementTitle"),
		enh_tex, "强化系统")
	_prepend_icon_to_label(
		get_node_or_null("VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel/EvolutionSection/EvolutionVBox/EvolutionTitle"),
		evo_tex, "进化系统")

## 把 Label 包进新建的 HBoxContainer（图标 + 文字），替换原节点位置
func _prepend_icon_to_label(label: Label, tex: Texture2D, new_text: String) -> void:
	if label == null or tex == null:
		return
	label.text = new_text
	var parent := label.get_parent()
	if parent == null:
		return
	var idx := label.get_index()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = tex
	parent.remove_child(label)
	hbox.add_child(icon)
	hbox.add_child(label)
	parent.add_child(hbox)
	parent.move_child(hbox, idx)

## 检查子节点是否为 tscn 定义的持久化 Section（不应被清除）
func _is_detail_panel_persist_child(child: Node) -> bool:
	if child == null:
		return false
	var n: String = child.name
	return n == "CardInfoSection" or n == "StarUpgradeSection" \
		or n == "EnhancementSection" \
		or n == "EvolutionSection"

## 仅清除 detail_panel 中动态添加的子节点，保留 tscn Section
func _clear_dynamic_detail() -> void:
	if detail_panel:
		# 同步移除（同 _clear_dyn 的理由）：CenterContainer 下避免面板被撑高后不回缩
		for child in detail_panel.get_children():
			if not _is_detail_panel_persist_child(child):
				detail_panel.remove_child(child)
				child.free()
		# 清理 persist Section 内部的动态内容（进度条/槽位/tips 等）
		for rel in ["EnhancementSection/EnhancementVBox", "EvolutionSection/EvolutionVBox"]:
			var vbox = detail_panel.get_node_or_null(rel)
			if vbox:
				_clear_dyn(vbox)

func _init_card_list() -> void:
	if not card_list_container:
		return
	selected_card_id = ""

	# 同步移除旧列表项（remove_child + free）：卡牌项是纯运行时生成的 Button，
	# queue_free 延迟删除会让旧项与新项同帧共存，LeftPanel 列表容器同样会被撑高后不回缩。
	for child in card_list_container.get_children():
		card_list_container.remove_child(child)
		child.free()

	card_items.clear()

	var all_card_ids: Array = []
	# 仅展示"背包中的卡牌"
	if SaveManager and SaveManager.has_method("get_pending_backpack_ids"):
		all_card_ids.append_array(SaveManager.get_pending_backpack_ids())
	if SaveManager and SaveManager.has_method("get_last_known_backpack_ids"):
		all_card_ids.append_array(SaveManager.get_last_known_backpack_ids())
	# 去重
	var uniq: Dictionary = {}
	var filtered_ids: Array = []
	for idv in all_card_ids:
		var sid: String = String(idv)
		if sid.is_empty() or uniq.has(sid):
			continue
		uniq[sid] = true
		filtered_ids.append(sid)
	all_card_ids = filtered_ids

	# v7.0: 实例化养成——id 可能是 instance_id（cold_t72#1），查模板前先解析 card_id
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	for id_val in all_card_ids:
		var card_id: String = String(id_val)
		if card_id.is_empty():
			continue
		# 解析 instance_id → card_id（取模板用）
		var base_card_id: String = card_id
		if ir != null and ir.has_method("get_card_id_of"):
			base_card_id = ir.get_card_id_of(card_id)
		var card_data = DefaultCards.get_card_by_id(base_card_id)
		if card_data == null:
			card_data = EnemyBlueprints.get_card_by_id(base_card_id)
		if card_data == null:
			continue

		# 创建卡牌项目按钮
		var item_button = Button.new()
		item_button.text = _get_card_display_name(card_id, card_data)
		item_button.custom_minimum_size = Vector2(200, 42)
		item_button.add_theme_font_size_override("font_size", 14)
		# 防止长文本导致按钮过宽：设置文本截断+水平不扩展
		item_button.clip_text = true
		item_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_button.add_theme_stylebox_override("normal", _card_item_stylebox(false))
		item_button.add_theme_stylebox_override("hover", _make_sb(THEME_GREEN * Color(1, 1, 1, 0.1), THEME_GREEN_SOFT * Color(1, 1, 1, 0.6), 1, 5, Color(0, 0, 0, 0), 0, 10, 6, 10, 6))
		item_button.add_theme_stylebox_override("pressed", _card_item_stylebox(false))
		item_button.pressed.connect(_on_card_item_selected.bindv([card_id]))

		card_list_container.add_child(item_button)
		card_items.append({"id": card_id, "data": card_data, "button": item_button})

func _get_card_display_name(card_id: String, card_data: Variant) -> String:
	var name_str = card_id
	if card_data is Dictionary:
		name_str = str(card_data.get("display_name", card_id))
	elif card_data is Object:
		var object_name: Variant = card_data.get("display_name")
		name_str = str(object_name if object_name != null else card_id)
	var level = 1
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	if card_enh_mgr:
		level = card_enh_mgr.get_card_enhancement_level(card_id)
	# v7.0: 同名卡区分——若 card_id 含 #序号（instance_id），追加序号后缀
	var seq_suffix: String = ""
	var hash_idx: int = card_id.rfind("#")
	if hash_idx >= 0:
		seq_suffix = " #%s" % card_id.substr(hash_idx + 1)

	return "%s%s (Lv.%d)" % [name_str, seq_suffix, level]

func _on_card_item_selected(card_id: String) -> void:
	select_card_by_id(card_id)


## v7.0: 按 instance_id 解析出模板 CardResource（查 DefaultCards/EnemyBlueprints）
## instance_id（cold_t72#1）→ card_id（cold_t72）→ 模板对象
func _resolve_card_data(id_str: String) -> CardResource:
	if id_str.is_empty():
		return null
	var base_card_id: String = id_str
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_card_id_of"):
		base_card_id = ir.get_card_id_of(id_str)
	var card_data = DefaultCards.get_card_by_id(base_card_id)
	if card_data == null:
		card_data = EnemyBlueprints.get_card_by_id(base_card_id)
	return card_data


## 外部面板跳转时预选卡牌（如情报中心）
func select_card_by_id(card_id: String) -> void:
	if card_id.is_empty():
		return
	if card_list_container and card_list_container.get_child_count() == 0:
		_init_card_list()
	selected_card_id = card_id
	_refresh_card_selection_style()
	_update_detail_panel()

func _update_detail_panel() -> void:
	if not card_detail_panel:
		return

	# 如果没有选择卡牌，显示提示并禁用按钮
	if selected_card_id.is_empty():
		if no_selection_label:
			no_selection_label.visible = true
		if detail_scroll:
			detail_scroll.visible = false
		_clear_dynamic_detail()
		if star_upgrade_button:
			star_upgrade_button.disabled = true
			star_upgrade_button.text = "请选择卡牌升星"
		if enhancement_button:
			enhancement_button.disabled = true
			enhancement_button.text = "请选择卡牌"
		if evolve_button:
			evolve_button.disabled = true
			evolve_button.text = "请选择可进化卡牌"
		if evolution_branch_selector:
			evolution_branch_selector.disabled = true
			evolution_branch_selector.clear()
		return

	# 选中了卡牌：隐藏 NoSelection，显示 DetailScroll
	if no_selection_label:
		no_selection_label.visible = false
	if detail_scroll:
		detail_scroll.visible = true

	# 清空动态内容
	_clear_dynamic_detail()

	var card_data = _resolve_card_data(selected_card_id)

	if card_data == null:
		return

	# 隐藏冗余的 CardInfoSection（其信息已由 header 卡片取代）
	var card_info_sec = get_node_or_null("VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel/CardInfoSection")
	if card_info_sec:
		card_info_sec.visible = false
	# === 卡牌头部卡片：大字名称 + 军衔/战力胶囊 ===
	var header := PanelContainer.new()
	header.name = "_dyn_header"
	header.add_theme_stylebox_override("panel", _make_sb(THEME_BG_CARD, THEME_GREEN_SOFT * Color(1, 1, 1, 0.5), 1, 6, THEME_GREEN * Color(1, 1, 1, 0.12), 4, 14, 12, 14, 12))
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 6)
	var name_label := Label.new()
	name_label.text = str(card_data.display_name if card_data else selected_card_id)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", THEME_CYAN)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0.12, 0.18, 0.75))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_box.add_child(name_label)
	var chips_row := HBoxContainer.new()
	chips_row.add_theme_constant_override("separation", 8)
	chips_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if BlueprintManager and BlueprintManager.has_method("get_rank_info"):
		var rank_info: Dictionary = BlueprintManager.get_rank_info(selected_card_id)
		chips_row.add_child(_make_chip("🏅 %s" % String(rank_info.get("rank_name", "未定级")), THEME_GOLD * Color(1, 1, 1, 0.18), THEME_GOLD * Color(1, 1, 1, 0.7), THEME_GOLD, 13))
		chips_row.add_child(_make_chip("⚡ 战力 %d" % int(float(rank_info.get("power_score", 0.0))), THEME_CYAN * Color(1, 1, 1, 0.15), THEME_CYAN * Color(1, 1, 1, 0.6), THEME_CYAN, 13))
	name_box.add_child(chips_row)
	header_hbox.add_child(name_box)
	header.add_child(header_hbox)
	detail_panel.add_child(header)
	detail_panel.move_child(header, 0)

	_update_star_upgrade_section()

	# 获取强化信息
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	var enhancement_info = card_enh_mgr.get_enhancement_info(selected_card_id) if card_enh_mgr else {}
	var current_level = enhancement_info.get("current_level", 1)
	var max_level = enhancement_info.get("max_level", 10)
	var can_enhance = enhancement_info.get("can_enhance", true)

	# === 强化信息卡片：进度条 + 词条槽 + 成本（注入到 EnhancementVBox） ===
	var enh_vbox = get_node_or_null("VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel/EnhancementSection/EnhancementVBox")
	if enh_vbox:
		_clear_dyn(enh_vbox)
		# 进度条插到 Title(index 0) 之后
		var prog = _make_level_progress(current_level, max_level)
		enh_vbox.add_child(prog)
		enh_vbox.move_child(prog, 1)
		# 词条槽位
		var affix = _render_affix_slots(selected_card_id, current_level)
		enh_vbox.add_child(affix)
		enh_vbox.move_child(affix, 2)
	# 升级成本 / 强化按钮状态
	if can_enhance and current_level < max_level:
		var next_level = int(enhancement_info.get("next_level", current_level + 1))
		var nano_cost = int(enhancement_info.get("nano_cost", 0))
		var level_action = String(enhancement_info.get("level_action", ""))
		var current_nano: int = 0
		if BasicResourceManager and BasicResourceManager.has_method("get_total"):
			current_nano = int(BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS))
		elif BlueprintManager and BlueprintManager.has_method("get_nano_materials"):
			current_nano = int(BlueprintManager.get_nano_materials())
		var enough: bool = current_nano >= nano_cost
		if enh_vbox:
			var cost_row := HBoxContainer.new()
			cost_row.name = "_dyn_cost"
			cost_row.add_theme_constant_override("separation", 8)
			cost_row.add_child(_make_chip("🧪 消耗 %d" % nano_cost, (THEME_RED if not enough else THEME_GREEN) * Color(1, 1, 1, 0.16), (THEME_RED if not enough else THEME_GREEN) * Color(1, 1, 1, 0.7), THEME_RED if not enough else THEME_GREEN, 14))
			cost_row.add_child(_make_chip("持有 %d" % current_nano, THEME_TEXT_DIM * Color(1, 1, 1, 0.12), THEME_BORDER_DIM, THEME_TEXT, 13))
			enh_vbox.add_child(cost_row)
			enh_vbox.move_child(cost_row, 3)
			if not level_action.is_empty() and level_action != "none":
				match level_action:
					"new_slot":
						var b1 = _make_chip("✦ 本次强化：解锁新词条槽", THEME_GREEN * Color(1, 1, 1, 0.18), THEME_GREEN * Color(1, 1, 1, 0.7), THEME_GREEN, 13)
						b1.name = "_dyn_action"
						enh_vbox.add_child(b1)
						enh_vbox.move_child(b1, 4)
					"upgrade_slot":
						var b2 = _make_chip("↑ 本次强化：升级已有词条", THEME_CYAN * Color(1, 1, 1, 0.18), THEME_CYAN * Color(1, 1, 1, 0.7), THEME_CYAN, 13)
						b2.name = "_dyn_action"
						enh_vbox.add_child(b2)
						enh_vbox.move_child(b2, 4)
		if enhancement_button:
			enhancement_button.disabled = not enough
			enhancement_button.text = "💪 强化至 Lv.%d" % next_level
	else:
		# 已达最高等级
		if enh_vbox:
			var max_chip = _make_chip("★ 已达最高强化等级", THEME_GOLD * Color(1, 1, 1, 0.2), THEME_GOLD * Color(1, 1, 1, 0.8), THEME_GOLD, 14)
			max_chip.name = "_dyn_max"
			enh_vbox.add_child(max_chip)
			enh_vbox.move_child(max_chip, 3)
		if enhancement_button:
			enhancement_button.disabled = true
			enhancement_button.text = "已满级"
	# 进化区域
	if card_data != null:
		_update_evolution_section(card_data)

func _update_evolution_section(card_data: CardResource) -> void:
	if evolve_button == null:
		return
	_pending_evolution_target_id = ""
	_pending_evolution_candidates.clear()
	_evolution_selector_meta.clear()
	if BlueprintManager == null or selected_card_id.is_empty():
		evolve_button.disabled = true
		evolve_button.text = "请选择可进化卡牌"
		if evolution_branch_selector:
			evolution_branch_selector.disabled = true
			evolution_branch_selector.clear()
		return
	if not BlueprintManager.has_method("get_evolution_options"):
		evolve_button.disabled = true
		evolve_button.text = "当前版本未启用进化"
		if evolution_branch_selector:
			evolution_branch_selector.disabled = true
			evolution_branch_selector.clear()
		return
	var options: Dictionary = BlueprintManager.get_evolution_options(selected_card_id)
	var evo_1: String = String(options.get("evolution_1", ""))
	var branches: Dictionary = options.get("faction_branches", {})
	var intel_branches: Array = options.get("intel_branches", [])
	var target_id: String = ""
	if evolution_branch_selector:
		_is_syncing_evolution_selector = true
		evolution_branch_selector.clear()
	# 先放入同体系进化目标（作为基础分组）
	if not evo_1.is_empty():
		_pending_evolution_candidates.append(evo_1)
		_evolution_selector_meta.append({
			"target_id": evo_1,
			"group": "基础进化",
			"faction_id": "base",
		})
	# 再放势力分支目标（去重）
	for faction_id in branches.keys():
		var branch_target: String = String(branches.get(faction_id, ""))
		if branch_target.is_empty() or _pending_evolution_candidates.has(branch_target):
			continue
		_pending_evolution_candidates.append(branch_target)
		_evolution_selector_meta.append({
			"target_id": branch_target,
			"group": "势力特化",
			"faction_id": String(faction_id),
		})
	# v6.0: 情报进化分支
	for ib in intel_branches:
		if not ib is Dictionary:
			continue
		var ib_target: String = String(ib.get("target_card_id", ""))
		if ib_target.is_empty() or _pending_evolution_candidates.has(ib_target):
			continue
		_pending_evolution_candidates.append(ib_target)
		_evolution_selector_meta.append({
			"target_id": ib_target,
			"group": "情报进化",
			"faction_id": "intel",
		})
	# 构建可选列表
	if evolution_branch_selector:
		for i in range(_pending_evolution_candidates.size()):
			var cand_id: String = _pending_evolution_candidates[i]
			var meta: Dictionary = _evolution_selector_meta[i] if i < _evolution_selector_meta.size() else {}
			var cand_card: CardResource = DefaultCards.get_card_by_id(cand_id)
			var cand_name: String = cand_card.display_name if cand_card != null else cand_id
			var group: String = String(meta.get("group", "进化"))
			var faction_id: String = String(meta.get("faction_id", ""))
			var faction_text: String = "" if faction_id == "base" else "·%s" % _get_faction_display_name(faction_id)
			var can_info_for_item: Dictionary = BlueprintManager.can_evolve_blueprint(selected_card_id, cand_id) if BlueprintManager.has_method("can_evolve_blueprint") else {"ok": false, "reason": "invalid"}
			var can_item: bool = bool(can_info_for_item.get("ok", false))
			var reason_item: String = _evolve_reason_display(can_info_for_item)
			var disabled_tag: String = "" if can_item else " [不可进化：%s]" % reason_item
			evolution_branch_selector.add_item("[%s%s] %s%s" % [group, faction_text, cand_name, disabled_tag])
			# 禁用不可进化分支，但仍保留条目用于预览
			if evolution_branch_selector.has_method("set_item_disabled"):
				evolution_branch_selector.set_item_disabled(i, not can_item)
		evolution_branch_selector.disabled = _pending_evolution_candidates.is_empty()
		if not _pending_evolution_candidates.is_empty():
			var default_index: int = 0
			for j in range(_pending_evolution_candidates.size()):
				var can_info_for_default: Dictionary = BlueprintManager.can_evolve_blueprint(selected_card_id, _pending_evolution_candidates[j])
				if bool(can_info_for_default.get("ok", false)):
					default_index = j
					break
			evolution_branch_selector.select(default_index)
			target_id = _pending_evolution_candidates[default_index]
		_is_syncing_evolution_selector = false
	if target_id.is_empty():
		evolve_button.disabled = true
		evolve_button.text = "该卡暂无进化路径"
		return
	_pending_evolution_target_id = target_id
	var target_card: CardResource = DefaultCards.get_card_by_id(target_id)
	var target_name: String = target_card.display_name if target_card != null else target_id
	var can_info: Dictionary = BlueprintManager.can_evolve_blueprint(selected_card_id, target_id) if BlueprintManager.has_method("can_evolve_blueprint") else {"ok": false, "reason": "invalid"}
	var can_evolve: bool = bool(can_info.get("ok", false))
	evolve_button.disabled = not can_evolve
	evolve_button.text = "进化为：%s" % target_name
	# 显示得失提示（卡片化）
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	var enhance_level_now: int = card_enh_mgr.get_card_enhancement_level(selected_card_id) if card_enh_mgr else 0
	var mod_now: int = BlueprintManager.get_modification_count(selected_card_id) if BlueprintManager.has_method("get_modification_count") else 0
	var inherit_ratio: float = float(can_info.get("inherit_ratio", UnitLineageConfig.DEFAULT_INHERIT_RATIO))
	var reason: String = _evolve_reason_display(can_info)
	var evo_vbox = get_node_or_null("VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel/EvolutionSection/EvolutionVBox")
	if evo_vbox:
		_clear_dyn(evo_vbox)
		var tips_card := PanelContainer.new()
		tips_card.name = "_dyn_tips_card"
		tips_card.add_theme_stylebox_override("panel", _make_sb(THEME_BG_CARD, THEME_GOLD * Color(1, 1, 1, 0.35), 1, 6, Color(0, 0, 0, 0), 0, 12, 10, 12, 10))
		var tips := RichTextLabel.new()
		tips.fit_content = true
		tips.scroll_active = false
		tips.bbcode_enabled = true
		tips.add_theme_font_size_override("normal_font_size", 13)
		tips.text = "[color=#ffe9a8][b]进化得失[/b][/color]\n" + \
			"[color=#8ef58e]✅ 获得[/color]：新单位成长上限、军衔重评、属性传承 %.0f%%\n" % (inherit_ratio * 100.0) + \
			"[color=#ffb37f]⚠️ 失去[/color]：当前改造进度清零（重走改造）\n" + \
			"[color=#bcd4ff]当前[/color]：强化 Lv.%d，改造 %d/9\n" % [enhance_level_now, mod_now] + \
			("[color=#8ef58e]状态：可进化[/color]" if can_evolve else "[color=#ff8888]状态：不可进化（%s）[/color]" % reason)
		tips_card.add_child(tips)
		evo_vbox.add_child(tips_card)

func _evolve_reason_display(can_info: Dictionary) -> String:
	if can_info.has("reason_zh"):
		return String(can_info.get("reason_zh", ""))
	return UnitLineageConfig.localize_evolve_reason(String(can_info.get("reason", "invalid")))

func _get_faction_display_name(faction_id: String) -> String:
	if faction_id.is_empty() or faction_id == "base":
		return "基础"
	var cfg: Dictionary = CompanyDefinitions.get_by_id(faction_id)
	var display_name: String = String(cfg.get("name", "")).strip_edges()
	return display_name if not display_name.is_empty() else faction_id

func _on_evolution_branch_selected(index: int) -> void:
	if _is_syncing_evolution_selector:
		return
	if index < 0 or index >= _pending_evolution_candidates.size():
		return
	_pending_evolution_target_id = _pending_evolution_candidates[index]
	# 分支切换后刷新提示和按钮状态
	_update_evolution_section(_resolve_card_data(selected_card_id))

func _permit_display_name(permit_id: String) -> String:
	var def: Dictionary = BasicResources.get_def(permit_id)
	return String(def.get("name", permit_id))

# v6.6: _format_mod_requirements 和 _build_permit_gap_text 已移除（死代码）。
# 原改造消耗展示依赖旧系统 get_modification_requirements（已删），现改造消耗由
# modification_panel 内部通过 install_modification 动态计算并提示。

func _update_star_upgrade_section() -> void:
	# v5.1: star_level system removed - hide the entire section
	if star_upgrade_button:
		star_upgrade_button.disabled = true
		star_upgrade_button.text = "已合并至强化系统"
	var section = get_node_or_null("VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel/StarUpgradeSection")
	if section:
		section.visible = false

func _on_star_upgrade_button_pressed() -> void:
	pass  # v5.1: star_level system removed

func _on_enhance_button_pressed() -> void:
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	if selected_card_id.is_empty() or not card_enh_mgr:
		return

	# 获取纳米材料数量（从 BasicResourceManager）
	var current_nano: int = 0
	if BasicResourceManager and BasicResourceManager.has_method("get_total"):
		current_nano = int(BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS))
	elif BlueprintManager and BlueprintManager.has_method("get_nano_materials"):
		current_nano = int(BlueprintManager.get_nano_materials())

	# 执行强化（v6.0：使用 do_enhance）
	var result = card_enh_mgr.do_enhance(selected_card_id, current_nano)
	if not result.get("ok", false):
		if result_label:
			result_label.text = "强化失败：" + str(result.get("reason", "纳米材料不足"))
			result_label.add_theme_color_override("font_color", Color.RED)
		return

	# 扣费：通过 BasicResourceManager 消耗纳米材料
	var nano_cost: int = card_enh_mgr.get_enhance_nano_cost(selected_card_id, int(result.get("level", 0)))
	if BasicResourceManager and BasicResourceManager.has_method("spend_resource"):
		BasicResourceManager.spend_resource(BasicResources.ID_NANO_MATERIALS, nano_cost)
	elif BlueprintManager and BlueprintManager.has_method("add_nano_materials"):
		BlueprintManager.add_nano_materials(-nano_cost)

	# v6.6: 强化到新槽位/升级槽位等级时，弹出词条选择
	var action: String = String(result.get("action", "none"))
	if action == "new_slot":
		_show_module_selection_popup(selected_card_id, int(result.get("level", 0)))
	elif action == "upgrade_slot":
		_show_module_upgrade_popup(selected_card_id)

	# 刷新面板
	_init_card_list()
	_update_detail_panel()
	_update_resource_labels()

func _on_evolve_button_pressed() -> void:
	if BlueprintManager == null or selected_card_id.is_empty() or _pending_evolution_target_id.is_empty():
		return
	if evolution_confirm_dialog == null:
		_try_execute_evolution()
		return
	var target_card: CardResource = DefaultCards.get_card_by_id(_pending_evolution_target_id)
	var target_name: String = target_card.display_name if target_card != null else _pending_evolution_target_id
	var can_info: Dictionary = BlueprintManager.can_evolve_blueprint(selected_card_id, _pending_evolution_target_id) if BlueprintManager.has_method("can_evolve_blueprint") else {}
	var inherit_ratio: float = float(can_info.get("inherit_ratio", UnitLineageConfig.DEFAULT_INHERIT_RATIO))
	evolution_confirm_dialog.dialog_text = "将进化为：%s\n\n你将获得：\n- 新单位成长上限\n- 属性传承 %.0f%%\n\n你将失去：\n- 当前改造进度（清零）\n\n是否确认进化？" % [target_name, inherit_ratio * 100.0]
	evolution_confirm_dialog.popup_centered(Vector2i(520, 360))

func _on_confirm_evolution() -> void:
	_try_execute_evolution()

func _try_execute_evolution() -> void:
	if BlueprintManager == null or selected_card_id.is_empty() or _pending_evolution_target_id.is_empty():
		return
	var ok: bool = BlueprintManager.evolve_blueprint(selected_card_id, _pending_evolution_target_id) if BlueprintManager.has_method("evolve_blueprint") else false
	if result_label:
		if ok:
			var target_card: CardResource = DefaultCards.get_card_by_id(_pending_evolution_target_id)
			var target_name: String = target_card.display_name if target_card != null else _pending_evolution_target_id
			result_label.text = "进化成功：%s -> %s" % [selected_card_id, target_name]
			result_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6, 1))
			selected_card_id = _pending_evolution_target_id
		else:
			result_label.text = "进化失败：请检查强化等级、改造数量与进化蓝图是否满足。"
			result_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1))
	_init_card_list()
	_update_resource_labels()
	_update_detail_panel()

func _on_enhancement_completed(success: bool, card_id: String, action: String, message: String) -> void:
	if card_id == selected_card_id:
		# 更新结果标签
		if result_label:
			result_label.text = message
			if success:
				result_label.add_theme_color_override("font_color", Color.GREEN)
			else:
				result_label.add_theme_color_override("font_color", Color.RED)

		# 刷新列表和详情面板
		_init_card_list()
		_update_detail_panel()
		_update_resource_labels()

func _on_enhancement_failed(card_id: String, reason: String) -> void:
	if card_id == selected_card_id:
		if result_label:
			result_label.text = reason
			result_label.add_theme_color_override("font_color", Color.RED)

func _on_nano_materials_changed(_old_value: int = 0, _new_value: int = 0) -> void:
	_update_resource_labels()
	_update_detail_panel()

func _update_resource_labels() -> void:
	var nano_amount: int = 0
	var rp_amount: int = 0
	if BasicResourceManager and BasicResourceManager.has_method("get_total"):
		nano_amount = int(BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS))
	elif BlueprintManager and BlueprintManager.has_method("get_nano_materials"):
		nano_amount = int(BlueprintManager.get_nano_materials())
	if BlueprintManager and BlueprintManager.has_method("get_research_points"):
		rp_amount = BlueprintManager.get_research_points()
	if nano_label:
		nano_label.text = "🧪 纳米材料：%d" % nano_amount
	if research_label:
		research_label.text = "🔬 研究点：%d" % rp_amount

func _on_close() -> void:
	closed.emit()

func _on_card_added_to_backpack(_card: CardResource) -> void:
	_init_card_list()
	_update_detail_panel()

# ─────────────────────────────────────────────
#  UI 美化 helper
# ─────────────────────────────────────────────

## 生成可复用 StyleBoxFlat（参数化主题色）
func _make_sb(bg: Color, border: Color, border_w: float, corner: float, \
		shadow_color := Color(0, 0, 0, 0), shadow_size := 0, \
		ml := 0.0, mt := 0.0, mr := 0.0, mb := 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_w
	sb.border_width_top = border_w
	sb.border_width_right = border_w
	sb.border_width_bottom = border_w
	sb.corner_radius_top_left = corner
	sb.corner_radius_top_right = corner
	sb.corner_radius_bottom_left = corner
	sb.corner_radius_bottom_right = corner
	if shadow_size > 0:
		sb.shadow_color = shadow_color
		sb.shadow_size = shadow_size
	if ml > 0 or mt > 0 or mr > 0 or mb > 0:
		sb.content_margin_left = ml
		sb.content_margin_top = mt
		sb.content_margin_right = mr
		sb.content_margin_bottom = mb
	return sb

## 清除父节点下所有 "_dyn_" 前缀的动态子节点
func _clear_dyn(parent: Node) -> void:
	if parent == null:
		return
	# 同步移除（remove_child + free），不要用 queue_free：本面板挂在 CenterContainer 下，
	# queue_free 是延迟删除，旧 _dyn_ 与新 _dyn_ 会在同一帧共存，导致内容容器 combined_minimum_size
	# 暂时膨胀，CenterContainer 据此把面板撑高且永不回缩（强化一张卡后再强化另一张时面板变长）。
	for c in parent.get_children():
		if c is Node and String(c.name).begins_with("_dyn_"):
			parent.remove_child(c)
			c.free()

## 创建带背景的胶囊标签（chip）
func _make_chip(text: String, bg: Color, border: Color, fg: Color = THEME_TEXT, size := 13) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "_dyn_chip"
	p.add_theme_stylebox_override("panel", _make_sb(bg, border, 1, 4, Color(0, 0, 0, 0), 0, 8, 3, 8, 3))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", fg)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

## 创建强化等级进度条（绿色填充）
func _make_level_progress(current: int, total: int) -> Control:
	var wrap := VBoxContainer.new()
	wrap.name = "_dyn_level_prog"
	wrap.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "强化等级"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", THEME_GREEN_SOFT)
	row.add_child(title)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = total
	bar.value = current
	bar.custom_minimum_size = Vector2(0, 16)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _make_sb(Color(0.04, 0.08, 0.05, 0.95), THEME_GREEN_SOFT * Color(1, 1, 1, 0.4), 1, 3))
	bar.add_theme_stylebox_override("fill", _make_sb(THEME_GREEN * Color(1, 1, 1, 0.78), Color(0, 0, 0, 0), 0, 3))
	row.add_child(bar)
	var num := Label.new()
	num.text = "%d/%d" % [current, total]
	num.add_theme_font_size_override("font_size", 14)
	num.add_theme_color_override("font_color", THEME_GREEN)
	num.custom_minimum_size = Vector2(48, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(num)
	wrap.add_child(row)
	return wrap

## 创建词条槽位可视化（5槽，随强化等级解锁）
func _render_affix_slots(card_id: String, current_level: int) -> Control:
	var wrap := VBoxContainer.new()
	wrap.name = "_dyn_affix"
	wrap.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "词条槽位"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", THEME_TEXT_DIM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var unlock_label := Label.new()
	unlock_label.add_theme_font_size_override("font_size", 12)
	unlock_label.add_theme_color_override("font_color", THEME_CYAN)
	# 解锁规则：Lv2/4/6/8/10 解锁槽1-5
	var max_slots := ModuleDefinitions.get_max_slots_for_level(current_level)
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	var slots: Array = []
	if card_enh_mgr and card_enh_mgr.has_method("get_module_slots"):
		slots = card_enh_mgr.get_module_slots(card_id)
	unlock_label.text = "已解锁 %d / 5" % max_slots
	head.add_child(unlock_label)
	wrap.add_child(head)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 6)
	for i in range(5):
		var unlocked := (i < max_slots)
		var slot_cell := PanelContainer.new()
		slot_cell.custom_minimum_size = Vector2(0, 34)
		slot_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if unlocked:
			var has_mod := i < slots.size()
			if has_mod:
				slot_cell.add_theme_stylebox_override("panel", _make_sb(THEME_GREEN * Color(1, 1, 1, 0.18), THEME_GREEN * Color(1, 1, 1, 0.75), 1, 4, THEME_GREEN * Color(1, 1, 1, 0.25), 3))
			else:
				slot_cell.add_theme_stylebox_override("panel", _make_sb(THEME_GREEN_SOFT * Color(1, 1, 1, 0.1), THEME_GREEN_SOFT * Color(1, 1, 1, 0.45), 1, 4))
		else:
			slot_cell.add_theme_stylebox_override("panel", _make_sb(THEME_BG_SLOT, THEME_BORDER_DIM * Color(1, 1, 1, 0.5), 1, 4))
		var cell_label := Label.new()
		cell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell_label.add_theme_font_size_override("font_size", 13)
		if not unlocked:
			cell_label.text = "🔒"
			cell_label.add_theme_color_override("font_color", THEME_TEXT_DIM * Color(1, 1, 1, 0.5))
		else:
			var disp := _slot_display(slots, i)
			if disp.is_empty():
				# 已解锁但无词条
				cell_label.text = "空"
				cell_label.add_theme_color_override("font_color", THEME_GREEN_SOFT * Color(1, 1, 1, 0.7))
			else:
				# 有词条：显示词条名 + 等级
				cell_label.text = disp
				cell_label.add_theme_color_override("font_color", THEME_GREEN)
		slot_cell.add_child(cell_label)
		grid.add_child(slot_cell)
	wrap.add_child(grid)
	return wrap

## 字符串超长截断并加省略号（避免中文被半截）
func _truncate_with_ellipsis(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, max_len) + "…"

## 解析第 i 个槽位的词条显示文本（"词条名 Lv.x"）；无词条返回空串
## slot 可能是 ModuleSlot 对象（.module_id/.level）或 Dictionary（module_id/level）
func _slot_display(slots: Array, i: int) -> String:
	if i >= slots.size():
		return ""
	var s = slots[i]
	if s == null:
		return ""
	var mid: String = ""
	var lvl: int = 1
	if s is Dictionary:
		mid = String(s.get("module_id", ""))
		lvl = int(s.get("level", 1))
	elif "module_id" in s:
		mid = String(s.module_id)
		lvl = int(s.level)
	if mid.is_empty():
		return ""
	var name: String = ModuleDefinitions.get_module_name(mid)
	# 词条名过长时截断（槽位宽度有限），保留等级后缀
	if name.length() > 4:
		name = _truncate_with_ellipsis(name, 4)
	return "%s Lv.%d" % [name, lvl]

## 卡牌列表项样式（选中/未选中）
func _card_item_stylebox(selected: bool) -> StyleBoxFlat:
	if selected:
		return _make_sb(THEME_GREEN * Color(1, 1, 1, 0.18), THEME_GREEN * Color(1, 1, 1, 0.85), 1, 5, THEME_GREEN * Color(1, 1, 1, 0.3), 4, 10, 6, 10, 6)
	return _make_sb(THEME_BG_CARD * Color(1, 1, 1, 0.6), THEME_BORDER_DIM, 1, 5, Color(0, 0, 0, 0), 0, 10, 6, 10, 6)

## 刷新卡牌列表项的选中高亮
func _refresh_card_selection_style() -> void:
	for item in card_items:
		var btn = item.get("button")
		if btn == null:
			continue
		var is_sel: bool = (String(item.get("id", "")) == selected_card_id)
		btn.add_theme_stylebox_override("normal", _card_item_stylebox(is_sel))
		btn.add_theme_stylebox_override("pressed", _card_item_stylebox(is_sel))

## 添加属性预览功能
func _add_attribute_preview(parent: Control, card_data: Variant, current_level: int, next_level: int) -> void:
	if not card_data:
		return

	# 添加分割线
	var sep = VSeparator.new()
	sep.custom_minimum_size = Vector2(2, 0)
	parent.add_child(sep)

	var preview_label = Label.new()
	preview_label.text = "━━━ 属性预览 ━━━"
	preview_label.add_theme_font_size_override("font_size", 12)
	preview_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1.0))
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(preview_label)

	# 显示当前属性和预计属性
	var current_stats = _get_card_attributes(card_data, current_level)
	var next_stats = _get_card_attributes(card_data, next_level)

	for key in current_stats.keys():
		var current_val = current_stats[key]
		var next_val = next_stats[key]
		var increase = next_val - current_val

		var stat_row = HBoxContainer.new()
		stat_row.add_theme_constant_override("separation", 8)

		var key_label = Label.new()
		key_label.text = key + "："
		key_label.custom_minimum_size = Vector2(60, 0)
		key_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 1.0))
		stat_row.add_child(key_label)

		var current_label = Label.new()
		current_label.text = str(int(current_val))
		current_label.custom_minimum_size = Vector2(40, 0)
		stat_row.add_child(current_label)

		var arrow_label = Label.new()
		arrow_label.text = "→"
		arrow_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1.0))
		stat_row.add_child(arrow_label)

		var next_label = Label.new()
		next_label.text = str(int(next_val))
		next_label.custom_minimum_size = Vector2(40, 0)
		next_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1.0))
		stat_row.add_child(next_label)

		var increase_label = Label.new()
		increase_label.text = "(+%d)" % increase if increase > 0 else "(=)"
		increase_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0, 1.0))
		stat_row.add_child(increase_label)

		parent.add_child(stat_row)

## 获取卡牌属性
func _get_card_attributes(card_data: Variant, level: int) -> Dictionary:
	var stats = {}

	if card_data is Dictionary:
		var display_name = card_data.get("display_name", "")
		var energy_cost = card_data.get("energy_cost", 0)
		var card_type = card_data.get("card_type", 0)

		stats["能量消耗"] = energy_cost

		# 根据卡牌类型获取不同属性
		if card_type == GC.CardType.PLATFORM:
			var max_hp = card_data.get("max_hp", 100)
			var move_speed = card_data.get("move_speed", 100)
			stats["生命值"] = int(max_hp * (1.0 + (level - 1) * 0.1))
			stats["移速"] = int(move_speed * (1.0 + (level - 1) * 0.05))

	return stats


# ═══════════════════════════════════════════════════════════
#  v6.6: 词条选择弹窗（强化到新槽位/升级槽位等级时触发）
# ═══════════════════════════════════════════════════════════

const ModuleDefinitions = preload("res://data/module_definitions.gd")

## 新槽位：弹出可选词条列表，玩家选一个
func _show_module_selection_popup(card_id: String, enhance_level: int) -> void:
	var cem: Node = get_node_or_null("/root/CardEnhancementManager")
	if cem == null:
		return
	var available: Array = ModuleDefinitions.get_available_modules(enhance_level)
	if available.is_empty():
		return
	# 构建弹窗
	var overlay := _create_module_overlay("✦ 选择新词条", "强化至 Lv.%d，解锁新词条槽位，请选择一个词条：" % enhance_level)
	var list_box: VBoxContainer = overlay["list_box"]
	# 候选词条按钮
	for module_id in available:
		var mid := String(module_id)
		var module_name: String = ModuleDefinitions.get_module_name(mid)
		var effect_key: String = ModuleDefinitions.get_effect_key(mid)
		var effect_type: String = ModuleDefinitions.get_effect_type(mid)
		var base_val: float = ModuleDefinitions.get_base_value(mid)
		var effect_desc: String = _format_module_effect(effect_key, base_val, effect_type)
		var btn := Button.new()
		btn.text = "%s  (%s)" % [module_name, effect_desc]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_stylebox_override("normal", _make_sb(THEME_BG_SLOT, THEME_GREEN_SOFT * Color(1, 1, 1, 0.5), 1, 5))
		btn.add_theme_color_override("font_color", THEME_TEXT)
		btn.add_theme_stylebox_override("hover", _make_sb(THEME_GREEN * Color(1, 1, 1, 0.15), THEME_GREEN_SOFT, 1, 5))
		btn.pressed.connect(_on_module_selected.bind(card_id, mid, overlay["root"]))
		list_box.add_child(btn)

## 升级槽位：列出已有词条，玩家选一个升级
func _show_module_upgrade_popup(card_id: String) -> void:
	var cem: Node = get_node_or_null("/root/CardEnhancementManager")
	if cem == null:
		return
	var slots: Array = cem.get_module_slots(card_id)
	if slots.is_empty():
		return
	var upgradable: Array = []
	for i in range(slots.size()):
		var s = slots[i]
		if s == null:
			continue
		var lvl: int = 1
		var mid: String = ""
		if s is Dictionary:
			mid = String(s.get("module_id", ""))
			lvl = int(s.get("level", 1))
		elif "module_id" in s:
			mid = String(s.module_id)
			lvl = int(s.level)
		if mid.is_empty() or lvl >= 3:
			continue
		upgradable.append({"slot_index": i, "module_id": mid, "level": lvl})
	if upgradable.is_empty():
		# v6.13: 所有词条已满级Lv3，本次升级无可升级项 —— 给明确提示，
		# 之前静默 return 导致玩家扣了纳米却看不到任何反馈
		var msg := "所有词条均已满级，本次强化无可升级词条（强化等级已提升）"
		if result_label:
			result_label.text = msg
			result_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3, 1))
		if SignalBus and SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit(msg)
		return
	var overlay := _create_module_overlay("↑ 升级词条", "本次强化可升级一个已有词条，请选择：")
	var list_box: VBoxContainer = overlay["list_box"]
	for u in upgradable:
		var mid: String = String(u["module_id"])
		var si: int = int(u["slot_index"])
		var old_lvl: int = int(u["level"])
		var module_name: String = ModuleDefinitions.get_module_name(mid)
		var btn := Button.new()
		btn.text = "%s  Lv.%d → Lv.%d" % [module_name, old_lvl, old_lvl + 1]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_stylebox_override("normal", _make_sb(THEME_BG_SLOT, THEME_CYAN * Color(1, 1, 1, 0.5), 1, 5))
		btn.add_theme_color_override("font_color", THEME_TEXT)
		btn.add_theme_stylebox_override("hover", _make_sb(THEME_CYAN * Color(1, 1, 1, 0.15), THEME_CYAN, 1, 5))
		btn.pressed.connect(_on_module_upgrade.bind(card_id, si, overlay["root"]))
		list_box.add_child(btn)

## 创建词条选择弹窗覆盖层（返回 {root, list_box}）
func _create_module_overlay(title_text: String, desc_text: String) -> Dictionary:
	var root := Control.new()
	root.name = "_dyn_module_popup"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	# 暗色遮罩
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	# 中央面板
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", _make_sb(THEME_BG_CARD, THEME_GREEN_SOFT * Color(1, 1, 1, 0.7), 2, 8, THEME_GREEN * Color(1, 1, 1, 0.2), 6))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	# 标题
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", THEME_GREEN)
	vbox.add_child(title)
	# 描述
	var desc := Label.new()
	desc.text = desc_text
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", THEME_TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)
	# 列表区（可滚动）
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var list_box := VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(list_box)
	# 跳过按钮
	var skip_btn := Button.new()
	skip_btn.text = "稍后再选（词条槽位保留为空）"
	skip_btn.add_theme_font_size_override("font_size", 12)
	skip_btn.add_theme_stylebox_override("normal", _make_sb(THEME_BG_SLOT, THEME_BORDER_DIM, 1, 4))
	skip_btn.add_theme_color_override("font_color", THEME_TEXT_DIM)
	skip_btn.pressed.connect(_close_module_popup.bind(root))
	vbox.add_child(skip_btn)
	return {"root": root, "list_box": list_box}

## 选中新词条
func _on_module_selected(card_id: String, module_id: String, popup_root: Control) -> void:
	var cem: Node = get_node_or_null("/root/CardEnhancementManager")
	if cem and cem.has_method("choose_module"):
		var r: Dictionary = cem.choose_module(card_id, module_id)
		if r.get("ok", false):
			_close_module_popup(popup_root)
			_safe_refresh_after_module_popup()
			return
		# 失败：显示原因（之前静默无提示，玩家体感"点了没反应"）
		_report_module_action_failure(r, "选择词条")
	# 失败：保持弹窗，玩家可重选

## 升级已有词条
func _on_module_upgrade(card_id: String, slot_index: int, popup_root: Control) -> void:
	var cem: Node = get_node_or_null("/root/CardEnhancementManager")
	if cem and cem.has_method("upgrade_module"):
		var r: Dictionary = cem.upgrade_module(card_id, slot_index)
		if r.get("ok", false):
			_close_module_popup(popup_root)
			_safe_refresh_after_module_popup()
			return
		# 失败：显示原因
		_report_module_action_failure(r, "升级词条")

## 词条操作失败时统一反馈（v6.13: 修复"点了词条没反应"——
## choose_module/upgrade_module 返回 ok:false 时原本静默，现显示 reason）
func _report_module_action_failure(result: Dictionary, action_label: String) -> void:
	var reason: String = String(result.get("reason", "未知原因"))
	var msg: String = "%s失败：%s" % [action_label, reason]
	if result_label:
		result_label.text = msg
		result_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1))
	if SignalBus and SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit(msg)

## 关闭词条弹窗
func _close_module_popup(popup_root: Control) -> void:
	if popup_root and is_instance_valid(popup_root):
		popup_root.queue_free()

## 弹窗关闭后安全刷新面板（避免空引用）
func _safe_refresh_after_module_popup() -> void:
	if not is_inside_tree():
		return
	_update_detail_panel()
	_update_resource_labels()

## 格式化词条效果描述（v6.10: 用 effect_type 精确格式化，修复"生命+0"——
## base_value 全是小数百分比如 max_hp=0.12，旧逻辑 int(0.12)=0 导致显示+0）
func _format_module_effect(effect_key: String, base_val: float, effect_type: String = "") -> String:
	var name_map := {
		"max_hp": "生命", "attack_damage": "攻击", "attack_light": "轻攻", "attack_armor": "重攻",
		"attack_air": "防空", "defense": "防御", "defense_light": "轻防", "defense_armor": "重防",
		"defense_air": "空防", "damage_reduction": "减伤", "crit_chance": "暴击",
		"crit_damage_bonus": "暴伤", "lifesteal": "吸血", "splash_damage": "溅射",
		"armor_penetration": "穿甲", "chain_chance": "连锁", "shield_on_kill": "击杀护盾",
		"hp_regen": "回血", "deploy_speed": "部署", "move_speed": "移速",
		"attack_range": "射程", "attack_interval": "攻速", "dodge_chance": "闪避",
		"faction_accuracy_bonus": "命中",
	}
	var label: String = name_map.get(effect_key, effect_key)
	# 百分比类统一换算：×100，≥1% 显示整数、<1% 保留1位小数（避免 hp_regen=0.003→+0%）
	var pct_str := func(p: float) -> String:
		var pct := p * 100.0
		if abs(pct) >= 1.0:
			return "%+.0f%%" % pct
		return "%+.1f%%" % pct
	# 按 effect_type 决定数值格式（百分比类 ×100，固定值类直接整数）
	match effect_type:
		"percent_mult", "percent_flat", "range_mult", "interval_mult":
			return "%s%s" % [label, pct_str.call(base_val)]
		"flat_add", "speed_add":
			return "%s%+d" % [label, int(base_val)]
		_:
			# 兜底：小数按百分比，整数按固定值（向后兼容无 effect_type 的调用）
			if abs(base_val) < 1.0 and base_val != 0.0:
				return "%s%s" % [label, pct_str.call(base_val)]
			return "%s%+d" % [label, int(base_val)]
