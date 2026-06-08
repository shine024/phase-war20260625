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
const DEBUG_LOG_PATH = "debug-119cff.log"

const MOD_SLOT_LABELS: PackedStringArray = ["A", "B", "C", "D", "E", "F", "G", "H", "I"]

signal closed

# UI 组件引用 - 新布局结构
@onready var card_list_container = $VBoxContainer/MainSplit/LeftPanel/ScrollContainer/CardListContainer
@onready var card_detail_panel = $VBoxContainer/MainSplit/RightPanel
@onready var no_selection_label = $VBoxContainer/MainSplit/RightPanel/NoSelectionLabel
@onready var detail_scroll = $VBoxContainer/MainSplit/RightPanel/DetailScroll
@onready var detail_panel = $VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel
@onready var star_upgrade_button = $VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel/StarUpgradeSection/StarUpgradeVBox/StarUpgradeButton
@onready var mod_section = $VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel/ModSection
@onready var mod_status_label = $VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel/ModSection/ModVBox/ModStatusLabel
@onready var mod_req_label = $VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel/ModSection/ModVBox/ModReqLabel
@onready var mod_offense_btn = $VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel/ModSection/ModVBox/ModButtonsHBox/ModOffenseBtn
@onready var mod_defense_btn = $VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel/ModSection/ModVBox/ModButtonsHBox/ModDefenseBtn
@onready var mod_utility_btn = $VBoxContainer/MainSplit/RightPanel/DetailScroll/DetailPanel/ModSection/ModVBox/ModButtonsHBox/ModUtilityBtn
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

func _dbg_runtime(run_id: String, hypothesis_id: String, location: String, message: String, data: Dictionary) -> void:
	# #region agent log
	var payload: Dictionary = {
		"sessionId": "119cff",
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	var f := FileAccess.open(DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(DEBUG_LOG_PATH, FileAccess.WRITE_READ)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(payload))
	f.close()
	# #endregion

func _ready() -> void:
	# #region agent log
	_dbg_runtime("pre-fix", "H5", "card_enhancement_panel.gd:_ready", "card_enhancement_panel_ready_entered", {})
	# #endregion
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
	if mod_offense_btn:
		mod_offense_btn.pressed.connect(_on_mod_option_pressed.bind("offense"))
	if mod_defense_btn:
		mod_defense_btn.pressed.connect(_on_mod_option_pressed.bind("defense"))
	if mod_utility_btn:
		mod_utility_btn.pressed.connect(_on_mod_option_pressed.bind("utility"))
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
	# 初始化详情面板为空状态
	_update_detail_panel()

## 检查子节点是否为 tscn 定义的持久化 Section（不应被清除）
func _is_detail_panel_persist_child(child: Node) -> bool:
	if child == null:
		return false
	var n: String = child.name
	return n == "CardInfoSection" or n == "StarUpgradeSection" \
		or n == "ModSection" or n == "EnhancementSection" \
		or n == "EvolutionSection"

## 仅清除 detail_panel 中动态添加的子节点，保留 tscn Section
func _clear_dynamic_detail() -> void:
	if detail_panel:
		for child in detail_panel.get_children():
			if not _is_detail_panel_persist_child(child):
				child.queue_free()

func _init_card_list() -> void:
	if not card_list_container:
		return
	selected_card_id = ""

	for child in card_list_container.get_children():
		child.queue_free()

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

	for card_id in all_card_ids:
		if card_id.is_empty():
			continue
		var card_data = DefaultCards.get_card_by_id(card_id)
		if card_data == null:
			card_data = EnemyBlueprints.get_card_by_id(card_id)
		if card_data == null:
			continue

		# 创建卡牌项目按钮
		var item_button = Button.new()
		item_button.text = _get_card_display_name(card_id, card_data)
		item_button.custom_minimum_size = Vector2(180, 40)
		item_button.add_theme_font_size_override("font_size", 15)
		# 防止长文本导致按钮过宽：设置文本截断+水平不扩展
		item_button.clip_text = true
		item_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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

	return "%s (Lv.%d)" % [name_str, level]

func _on_card_item_selected(card_id: String) -> void:
	select_card_by_id(card_id)


## 外部面板跳转时预选卡牌（如情报中心）
func select_card_by_id(card_id: String) -> void:
	if card_id.is_empty():
		return
	if card_list_container and card_list_container.get_child_count() == 0:
		_init_card_list()
	selected_card_id = card_id
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
		_reset_modification_section()
		return

	# 选中了卡牌：隐藏 NoSelection，显示 DetailScroll
	if no_selection_label:
		no_selection_label.visible = false
	if detail_scroll:
		detail_scroll.visible = true

	# 清空动态内容
	_clear_dynamic_detail()

	var card_data = DefaultCards.get_card_by_id(selected_card_id)
	if card_data == null:
		card_data = EnemyBlueprints.get_card_by_id(selected_card_id)

	if card_data == null:
		return

	# 显示卡牌名称 — 插入到 detail_panel 顶部（index 0）
	var name_label = Label.new()
	name_label.text = str(card_data.display_name if card_data else selected_card_id)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0, 0.9, 1, 1))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(name_label)
	detail_panel.move_child(name_label, 0)
	# 显示军衔
	if BlueprintManager and BlueprintManager.has_method("get_rank_info"):
		var rank_info: Dictionary = BlueprintManager.get_rank_info(selected_card_id)
		var rank_label := Label.new()
		rank_label.text = "当前军衔：%s（战力 %.0f）" % [
			String(rank_info.get("rank_name", "未定级")),
			float(rank_info.get("power_score", 0.0))
		]
		rank_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45, 1))
		rank_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rank_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_panel.add_child(rank_label)
		detail_panel.move_child(rank_label, 1)

	_update_star_upgrade_section()
	_update_modification_section()

	# 获取强化信息
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	var enhancement_info = card_enh_mgr.get_enhancement_info(selected_card_id) if card_enh_mgr else {}
	var current_level = enhancement_info.get("current_level", 1)
	var max_level = enhancement_info.get("max_level", 10)
	var can_enhance = enhancement_info.get("can_enhance", true)

	# 显示当前等级
	var level_label = Label.new()
	level_label.text = "当前等级：%d / %d" % [current_level, max_level]
	detail_panel.add_child(level_label)

	# 如果可以强化，显示升级成本
	if can_enhance and current_level < max_level:
		var next_level = enhancement_info.get("next_level", current_level + 1)
		var nano_cost = enhancement_info.get("nano_cost", 0)
		var level_action = String(enhancement_info.get("level_action", ""))

		# 获取当前纳米材料数量
		var current_nano: int = 0
		if BasicResourceManager and BasicResourceManager.has_method("get_total"):
			current_nano = int(BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS))
		elif BlueprintManager and BlueprintManager.has_method("get_nano_materials"):
			current_nano = int(BlueprintManager.get_nano_materials())

		# 显示升级成本（用颜色代替BBCode）
		var cost_label = Label.new()
		cost_label.text = "升级成本：%d纳米材料（当前：%d）" % [nano_cost, current_nano]
		cost_label.add_theme_color_override("font_color", Color.GREEN if current_nano >= nano_cost else Color.RED)
		cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_panel.add_child(cost_label)

		# 显示本次强化效果（v6.0词条系统）
		if not level_action.is_empty():
			var action_label = Label.new()
			match level_action:
				"new_slot":
					action_label.text = "本次强化：获得新词条槽"
					action_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6, 1))
				"upgrade_slot":
					action_label.text = "本次强化：升级已有词条"
					action_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 1))
				_:
					action_label.text = ""
			detail_panel.add_child(action_label)

		# 启用强化按钮
		if enhancement_button:
			enhancement_button.disabled = current_nano < nano_cost
			enhancement_button.text = "强化至 Lv.%d" % next_level
	else:
		# 已达最高等级
		var max_label = Label.new()
		max_label.text = "已达最高等级"
		max_label.add_theme_color_override("font_color", Color.YELLOW)
		detail_panel.add_child(max_label)

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
	# 显示得失提示
	var tips := RichTextLabel.new()
	tips.fit_content = true
	tips.scroll_active = false
	tips.custom_minimum_size = Vector2(0, 96)
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	var enhance_level_now: int = card_enh_mgr.get_card_enhancement_level(selected_card_id) if card_enh_mgr else 0
	var mod_now: int = BlueprintManager.get_modification_count(selected_card_id) if BlueprintManager.has_method("get_modification_count") else 0
	var inherit_ratio: float = float(can_info.get("inherit_ratio", UnitLineageConfig.DEFAULT_INHERIT_RATIO))
	var reason: String = _evolve_reason_display(can_info)
	tips.bbcode_enabled = true
	tips.text = "[color=#7fd3ff]进化得失提示[/color]\n" + \
		"[color=#8ef58e]获得[/color]：新单位成长上限、军衔重新评估、属性传承 %.0f%%\n" % (inherit_ratio * 100.0) + \
		"[color=#ffb37f]失去[/color]：当前改造进度清零（重走改造）\n" + \
		"当前：强化 Lv.%d，改造 %d/9\n" % [enhance_level_now, mod_now] + \
		("状态：可进化" if can_evolve else "状态：不可进化（%s）" % reason)
	detail_panel.add_child(tips)

func _evolve_reason_display(can_info: Dictionary) -> String:
	if can_info.has("reason_zh"):
		return String(can_info.get("reason_zh", ""))
	return UnitLineageConfig.localize_evolve_reason(String(can_info.get("reason", "invalid")))

func _build_permit_gap_text(can_info: Dictionary) -> String:
	if BlueprintManager == null or not BlueprintManager.has_method("_get_basic_resource_manager"):
		return ""
	var brm: Node = BasicResourceManager
	if brm == null or not brm.has_method("get_total"):
		return ""
	var need_g: int = int(can_info.get("permit_general_count", 0))
	var need_c: int = int(can_info.get("permit_category_count", 0))
	var need_s: int = int(can_info.get("permit_specific_count", 0))
	var id_g: String = String(can_info.get("permit_general_id", ""))
	var id_c: String = String(can_info.get("permit_category_id", ""))
	var id_s: String = String(can_info.get("permit_specific_id", ""))
	var have_g: int = int(brm.get_total(id_g))
	var have_c: int = int(brm.get_total(id_c))
	var have_s: int = int(brm.get_total(id_s))
	var gaps: Array[String] = []
	if have_g < need_g:
		gaps.append("通用许可-%d" % (need_g - have_g))
	if have_c < need_c:
		gaps.append("类型许可-%d" % (need_c - have_c))
	if have_s < need_s:
		gaps.append("专属许可-%d" % (need_s - have_s))
	if gaps.is_empty():
		return ""
	return "，缺口：" + " / ".join(PackedStringArray(gaps))

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
	_update_evolution_section(DefaultCards.get_card_by_id(selected_card_id))

func _reset_modification_section() -> void:
	if mod_status_label:
		mod_status_label.text = "改装进度：—"
	if mod_req_label:
		mod_req_label.text = ""
	_set_mod_branch_buttons_enabled(false)

func _set_mod_branch_buttons_enabled(enabled: bool) -> void:
	if mod_offense_btn:
		mod_offense_btn.disabled = not enabled
	if mod_defense_btn:
		mod_defense_btn.disabled = not enabled
	if mod_utility_btn:
		mod_utility_btn.disabled = not enabled

func _mod_option_display_name(option_id: String) -> String:
	var ModEffects = preload("res://data/mod_effects.gd")
	var mod_info: Dictionary = ModEffects.get_mod_info(option_id)
	if not mod_info.is_empty():
		return String(mod_info.get("name", option_id))
	return option_id

func _permit_display_name(permit_id: String) -> String:
	var def: Dictionary = BasicResources.get_def(permit_id)
	return String(def.get("name", permit_id))

func _format_mod_requirements(card_id: String, mod_index: int) -> String:
	if BlueprintManager == null:
		return ""
	var req: Dictionary = BlueprintManager.get_modification_requirements(card_id, mod_index)
	var slot: String = MOD_SLOT_LABELS[mod_index] if mod_index >= 0 and mod_index < MOD_SLOT_LABELS.size() else "?"
	var lines: Array[String] = [
		"槽位 %s" % slot,
		"消耗：研究点 %d（当前 %d）" % [int(req.get("research_points", 0)), BlueprintManager.get_research_points()],
	]
	var brm: Node = BasicResourceManager
	var n_general: int = int(req.get("permit_general_count", 0))
	if n_general > 0:
		var id_g: String = String(req.get("permit_general_id", ""))
		var have_g: int = int(brm.get_total(id_g)) if brm else 0
		lines.append("%s ×%d（拥有 %d）" % [_permit_display_name(id_g), n_general, have_g])
	var n_category: int = int(req.get("permit_category_count", 0))
	if n_category > 0:
		var id_c: String = String(req.get("permit_category_id", ""))
		var have_c: int = int(brm.get_total(id_c)) if brm else 0
		lines.append("%s ×%d（拥有 %d）" % [_permit_display_name(id_c), n_category, have_c])
	var n_specific: int = int(req.get("permit_specific_count", 0))
	if n_specific > 0:
		var id_s: String = String(req.get("permit_specific_id", ""))
		var have_s: int = int(brm.get_total(id_s)) if brm else 0
		lines.append("%s ×%d（拥有 %d）" % [_permit_display_name(id_s), n_specific, have_s])
	var gap: String = _build_permit_gap_text(req)
	if not gap.is_empty():
		lines.append("缺口%s" % gap)
	return "\n".join(lines)

func _update_modification_section() -> void:
	if mod_status_label == null or BlueprintManager == null:
		return
	if selected_card_id.is_empty():
		_reset_modification_section()
		return
	var applied: Array = BlueprintManager.blueprint_mods.get(selected_card_id, [])
	var applied_parts: PackedStringArray = PackedStringArray()
	for i in range(applied.size()):
		var slot: String = MOD_SLOT_LABELS[i] if i < MOD_SLOT_LABELS.size() else "?"
		# applied[i] 是 Dictionary 格式 {"id": "MOD_XX"}，需要先获取 id
		var entry = applied[i]
		var mod_id: String = ""
		if entry is Dictionary:
			mod_id = String(entry.get("id", ""))
		else:
			mod_id = String(entry)  # 兼容旧格式
		applied_parts.append("%s:%s" % [slot, _mod_option_display_name(mod_id)])
	var applied_text: String = " / ".join(applied_parts) if applied_parts.size() > 0 else "无"
	mod_status_label.text = "改装进度：%s（%d/9）" % [applied_text, applied.size()]
	var max_times: int = 9  # v5.1: 改造次数固定为9次（与底层ModManager对齐）
	var mod_index: int = BlueprintManager.get_modification_count(selected_card_id)
	if mod_index >= max_times:
		if mod_req_label:
			mod_req_label.text = "已完成全部改装槽位。"
		_set_mod_branch_buttons_enabled(false)
		return
	var can_apply: bool = BlueprintManager.can_apply_modification(selected_card_id, mod_index)
	if mod_req_label:
		mod_req_label.text = _format_mod_requirements(selected_card_id, mod_index)
	_set_mod_branch_buttons_enabled(can_apply)

func _on_mod_option_pressed(option_id: String) -> void:
	if selected_card_id.is_empty() or BlueprintManager == null:
		return
	if not BlueprintManager.has_method("apply_modification"):
		return
	var mod_index: int = BlueprintManager.get_modification_count(selected_card_id)
	if not BlueprintManager.can_apply_modification(selected_card_id, mod_index):
		if result_label:
			result_label.text = "改装失败：星级、研究点或许可函不足。"
			result_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1))
		_update_modification_section()
		return
	var ok: bool = BlueprintManager.apply_modification(selected_card_id, option_id)
	if result_label:
		if ok:
			var slot: String = MOD_SLOT_LABELS[mod_index] if mod_index < MOD_SLOT_LABELS.size() else "?"
			result_label.text = "改装成功：槽位 %s 选择【%s】" % [slot, _mod_option_display_name(option_id)]
			result_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 1))
		else:
			result_label.text = "改装失败：请检查星级、研究点与许可函。"
			result_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1))
	_init_card_list()
	_update_resource_labels()
	_update_detail_panel()

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
		nano_label.text = "纳米材料：%d" % nano_amount
	if research_label:
		research_label.text = "研究点：%d" % rp_amount

func _on_close() -> void:
	closed.emit()

func _on_card_added_to_backpack(_card: CardResource) -> void:
	_init_card_list()
	_update_detail_panel()

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
		current_label.text = str(current_val)
		current_label.custom_minimum_size = Vector2(40, 0)
		stat_row.add_child(current_label)

		var arrow_label = Label.new()
		arrow_label.text = "→"
		arrow_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1.0))
		stat_row.add_child(arrow_label)

		var next_label = Label.new()
		next_label.text = str(next_val)
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
