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
const UnitLineageConfig = preload("res://data/unit_lineage_config.gd")
const RankRules = preload("res://data/rank_rules.gd")
const CompanyDefinitions = preload("res://data/company_definitions.gd")
const StarConfig = preload("res://data/blueprint_star_config.gd")
const BasicResources = preload("res://data/basic_resources.gd")
const IntelManualItems = preload("res://data/intel_manual_items.gd")
const DEBUG_LOG_PATH = "debug-119cff.log"

const MOD_SLOT_LABELS: PackedStringArray = ["A", "B", "C"]

signal closed

## ── 子系统：强化动画/属性预览 ──
const EnhanceAnimSub = preload("res://scenes/ui/enhancement_animation.gd")
var _enhance_anim: EnhancementAnimation = null

# UI 组件引用
@onready var card_list_container = $VBoxContainer/HBoxContainer/ScrollContainer/CardListContainer
@onready var card_detail_panel = $VBoxContainer/HBoxContainer/DetailPanel
@onready var star_upgrade_button = $VBoxContainer/HBoxContainer/DetailPanel/StarUpgradeButton
@onready var mod_section = $VBoxContainer/HBoxContainer/DetailPanel/ModSection
@onready var mod_status_label = $VBoxContainer/HBoxContainer/DetailPanel/ModSection/ModStatusLabel
@onready var mod_req_label = $VBoxContainer/HBoxContainer/DetailPanel/ModSection/ModReqLabel
@onready var mod_offense_btn = $VBoxContainer/HBoxContainer/DetailPanel/ModSection/ModButtonsHBox/ModOffenseBtn
@onready var mod_defense_btn = $VBoxContainer/HBoxContainer/DetailPanel/ModSection/ModButtonsHBox/ModDefenseBtn
@onready var mod_utility_btn = $VBoxContainer/HBoxContainer/DetailPanel/ModSection/ModButtonsHBox/ModUtilityBtn
@onready var enhancement_button = $VBoxContainer/HBoxContainer/DetailPanel/EnhancementButton
@onready var evolve_button = $VBoxContainer/HBoxContainer/DetailPanel/EvolveButton
@onready var evolution_branch_selector: OptionButton = $VBoxContainer/HBoxContainer/DetailPanel/EvolutionBranchSelector
@onready var nano_label = $VBoxContainer/NanoLabel
@onready var research_label = $VBoxContainer/ResearchLabel
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
	_enhance_anim = EnhanceAnimSub.new()
	_enhance_anim.setup(self)
	# #region agent log
	_dbg_runtime("pre-fix", "H5", "card_enhancement_panel.gd:_ready", "card_enhancement_panel_ready_entered", {})
	# #endregion
	# 连接关闭按钮
	var close_btn = get_node_or_null("VBoxContainer/TitleRow/CloseButton")
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
			BlueprintManager.fragments_changed.connect(_on_nano_materials_changed)
		if BlueprintManager.has_signal("blueprint_star_upgraded"):
			BlueprintManager.blueprint_star_upgraded.connect(_on_blueprint_star_upgraded)

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

func _is_detail_panel_persist_child(child: Node) -> bool:
	if child == star_upgrade_button \
		or child == enhancement_button \
		or child == evolve_button \
		or child == evolution_branch_selector \
		or child == mod_section:
		return true
	if mod_section and child.get_parent() == mod_section:
		return true
	return false

func _init_card_list() -> void:
	"""初始化卡牌列表"""
	if not card_list_container:
		return
	selected_card_id = ""

	for child in card_list_container.get_children():
		child.queue_free()

	card_items.clear()

	var all_card_ids: Array = []
	# 仅展示“背包中的卡牌”
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
			card_data = null
		if card_data == null:
			continue

		# 创建卡牌项目按钮
		var item_button = Button.new()
		item_button.text = _get_card_display_name(card_id, card_data)
		item_button.custom_minimum_size = Vector2(200, 40)
		item_button.pressed.connect(_on_card_item_selected.bindv([card_id]))

		card_list_container.add_child(item_button)
		card_items.append({"id": card_id, "data": card_data, "button": item_button})

func _get_card_display_name(card_id: String, card_data: Variant) -> String:
	"""获取卡牌显示名称"""
	var name_str = card_id
	if card_data is Dictionary:
		name_str = str(card_data.get("display_name", card_id))
	elif card_data is Object:
		# Support Resource/Object-based card definitions.
		var object_name: Variant = card_data.get("display_name")
		name_str = str(object_name if object_name != null else card_id)
	# 如果仍等于 card_id，尝试统一安全查找
	if name_str == card_id:
		name_str = DefaultCards.get_safe_display_name(card_id)
	var level = 1
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	if card_enh_mgr:
		level = card_enh_mgr.get_card_enhancement_level(card_id)

	return "%s (Lv.%d)" % [name_str, level]

func _on_card_item_selected(card_id: String) -> void:
	"""卡牌项目被选中"""
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
	"""更新详细信息面板"""
	if not card_detail_panel:
		return

	# 如果没有选择卡牌，显示提示并禁用按钮
	if selected_card_id.is_empty():
		for child in card_detail_panel.get_children():
			if not _is_detail_panel_persist_child(child):
				child.queue_free()
		var tip_label = Label.new()
		tip_label.text = "请从左侧列表选择要强化的卡牌"
		tip_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 1))
		tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card_detail_panel.add_child(tip_label)
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

	# 清空现有内容（保留升星/强化/进化控件）
	for child in card_detail_panel.get_children():
		if not _is_detail_panel_persist_child(child):
			child.queue_free()

	var card_data = DefaultCards.get_card_by_id(selected_card_id)
	if card_data == null:
		card_data = null

	if card_data == null:
		return

	# 显示卡牌名称
	var name_label = Label.new()
	name_label.text = str(card_data.display_name if card_data else DefaultCards.get_safe_display_name(selected_card_id))
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0, 0.9, 1, 1))
	card_detail_panel.add_child(name_label)
	# 显示军衔
	if BlueprintManager and BlueprintManager.has_method("get_rank_info"):
		var rank_info: Dictionary = BlueprintManager.get_rank_info(selected_card_id)
		var rank_label := Label.new()
		rank_label.text = "当前军衔：%s（战力 %.0f）" % [
			String(rank_info.get("rank_name", "未定级")),
			float(rank_info.get("power_score", 0.0))
		]
		rank_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45, 1))
		card_detail_panel.add_child(rank_label)

	_update_star_upgrade_section()
	_update_modification_section()
	_update_enemy_origin_mod_section()  ## v6.0: D slot enemy origin mod

	# 获取强化信息
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	var enhancement_info = card_enh_mgr.get_enhancement_info(selected_card_id) if card_enh_mgr else {}
	var current_level = enhancement_info.get("current_level", 1)
	var max_level = enhancement_info.get("max_level", 10)
	var can_enhance = enhancement_info.get("can_enhance", true)

	# 显示当前等级
	var level_label = Label.new()
	level_label.text = "当前等级：%d / %d" % [current_level, max_level]
	card_detail_panel.add_child(level_label)

	# 如果可以强化，显示升级成本
	if can_enhance and current_level < max_level:
		var next_level = enhancement_info.get("next_level", current_level + 1)
		var nano_cost = enhancement_info.get("nano_cost", 0)
		var next_power_mult = enhancement_info.get("next_power_multiplier", 1.0)
		var attribute_bonus = enhancement_info.get("attribute_bonus", 0.0)

		# 显示升级成本
		var cost_label = Label.new()
		var current_nano = BlueprintManager.get_nano_materials() if BlueprintManager else 0
		var cost_color = "green" if current_nano >= nano_cost else "red"
		cost_label.text = "[color=%s]升级成本：%d纳米材料（当前：%d）[/color]" % [cost_color, nano_cost, current_nano]
		cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_detail_panel.add_child(cost_label)

		# v5.0: 显示强化成功率（100%）和战力倍率
		var rate_label = Label.new()
		rate_label.text = "成功率：100%%"
		card_detail_panel.add_child(rate_label)

		var power_label = Label.new()
		power_label.text = "升级后战力倍率：%.2f" % next_power_mult
		card_detail_panel.add_child(power_label)

		# 显示属性加成
		var bonus_label = Label.new()
		bonus_label.text = "属性加成：+%.0f%%" % (attribute_bonus * 100)
		card_detail_panel.add_child(bonus_label)

		# 启用强化按钮
		if enhancement_button:
			enhancement_button.disabled = current_nano < nano_cost
			enhancement_button.text = "强化至 Lv.%d" % next_level
	else:
		# 已达最高等级
		var max_label = Label.new()
		max_label.text = "[color=yellow]已达最高等级[/color]"
		card_detail_panel.add_child(max_label)

		if enhancement_button:
			enhancement_button.disabled = true
			enhancement_button.text = "已满级"
	# 进化区域
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
	if evolution_branch_selector:
		evolution_branch_selector.visible = not branches.is_empty()
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
			var gap_text: String = _build_permit_gap_text(can_info_for_item)
			var disabled_tag: String = "" if can_item else " [不可进化：%s%s]" % [reason_item, gap_text]
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
	var star_now: int = BlueprintManager.get_blueprint_star(selected_card_id) if BlueprintManager.has_method("get_blueprint_star") else 1
	var mod_now: int = BlueprintManager.get_modification_count(selected_card_id) if BlueprintManager.has_method("get_modification_count") else 0
	var inherit_ratio: float = float(can_info.get("inherit_ratio", UnitLineageConfig.DEFAULT_INHERIT_RATIO))
	var research_cost: int = int(can_info.get("research_cost", 0))
	var reason: String = _evolve_reason_display(can_info)
	var permit_gap_text: String = _build_permit_gap_text(can_info)
	tips.bbcode_enabled = true
	tips.text = "[color=#7fd3ff]进化得失提示[/color]\n" + \
		"[color=#8ef58e]获得[/color]：新单位成长上限、军衔重新评估、属性传承 %.0f%%\n" % (inherit_ratio * 100.0) + \
		"[color=#ffb37f]失去[/color]：当前改造A/B/C进度清零（重走改造）\n" + \
		"当前：星级 %d，改造 %d/3，进化消耗研究点 %d\n" % [star_now, mod_now, research_cost] + \
		("状态：可进化" if can_evolve else "状态：不可进化（%s%s）" % [reason, permit_gap_text])
	card_detail_panel.add_child(tips)

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
	if BlueprintManager and BlueprintManager.DEFAULT_MOD_OPTIONS.has(option_id):
		return String(BlueprintManager.DEFAULT_MOD_OPTIONS[option_id].get("name", option_id))
	return option_id

func _permit_display_name(permit_id: String) -> String:
	var def: Dictionary = BasicResources.get_def(permit_id)
	return String(def.get("name", permit_id))

func _format_mod_requirements(card_id: String, mod_index: int) -> String:
	if BlueprintManager == null:
		return ""
	var need_star: int = StarConfig.get_mod_unlock_star(mod_index)
	var star_now: int = BlueprintManager.get_blueprint_star(card_id)
	var req: Dictionary = BlueprintManager.get_modification_requirements(card_id, mod_index)
	var slot: String = MOD_SLOT_LABELS[mod_index] if mod_index >= 0 and mod_index < MOD_SLOT_LABELS.size() else "?"
	var lines: Array[String] = [
		"槽位 %s：需 %d★（当前 %d★）" % [slot, need_star, star_now],
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
		applied_parts.append("%s:%s" % [slot, _mod_option_display_name(String(applied[i]))])
	var applied_text: String = " / ".join(applied_parts) if applied_parts.size() > 0 else "无"
	mod_status_label.text = "改装进度：%s（%d/3）" % [applied_text, applied.size()]
	var rarity: String = BlueprintManager.get_card_rarity(selected_card_id) if BlueprintManager.has_method("get_card_rarity") else "common"
	var max_times: int = StarConfig.get_max_mod_times(rarity)
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
	## v6.0: 消耗对应改装指南
	var mod_item_type: String = _get_mod_item_type_for_slot(mod_index)
	if not mod_item_type.is_empty():
		if not _consume_intel_item(mod_item_type):
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
	if star_upgrade_button == null or BlueprintManager == null or selected_card_id.is_empty():
		return
	var star_now: int = BlueprintManager.get_blueprint_star(selected_card_id) if BlueprintManager.has_method("get_blueprint_star") else 1
	var max_star: int = BlueprintManager.MAX_BLUEPRINT_LEVEL
	var sp: Dictionary = BlueprintManager.get_star_progress(selected_card_id) if BlueprintManager.has_method("get_star_progress") else {}
	var need_rp: int = int(sp.get("next_star_research", 0))
	var have_rp: int = int(sp.get("current_research", BlueprintManager.get_research_points()))
	if star_now >= max_star:
		star_upgrade_button.disabled = true
		star_upgrade_button.text = "已满星（%d★）" % star_now
		return
	var can_up: bool = BlueprintManager.can_upgrade_blueprint(selected_card_id) if BlueprintManager.has_method("can_upgrade_blueprint") else false
	## v6.0: 额外检查升星指南
	var bag: Node = get_node_or_null("/root/IntelItemBag")
	var has_guide: bool = bag.has_item(IntelManualItems.TYPE_STAR_UPGRADE) if bag else false
	star_upgrade_button.disabled = not can_up or not has_guide
	var guide_count: int = bag.get_count(IntelManualItems.TYPE_STAR_UPGRADE) if bag else 0
	star_upgrade_button.text = "升星至 %d★（研究点 %d，📋升星指南×%d）" % [star_now + 1, need_rp, guide_count]

func _on_star_upgrade_button_pressed() -> void:
	if selected_card_id.is_empty() or BlueprintManager == null:
		return
	if not BlueprintManager.has_method("upgrade_blueprint_level"):
		return
	## v6.0: 消耗升星指南
	if not _consume_intel_item(IntelManualItems.TYPE_STAR_UPGRADE):
		return
	var ok: bool = BlueprintManager.upgrade_blueprint_level(selected_card_id)
	if result_label:
		if ok:
			var new_star: int = BlueprintManager.get_blueprint_star(selected_card_id)
			result_label.text = "升星成功：%s 现为 %d★" % [DefaultCards.get_safe_display_name(selected_card_id), new_star]
			result_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1))
		else:
			result_label.text = "升星失败：研究点不足或已达满星。"
			result_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1))
	_init_card_list()
	_update_resource_labels()
	_update_detail_panel()

func _on_blueprint_star_upgraded(card_id: String, _new_star: int) -> void:
	if card_id != selected_card_id:
		return
	_update_resource_labels()
	_update_star_upgrade_section()
	_update_modification_section()

func _on_enhance_button_pressed() -> void:
	"""强化按钮被按下"""
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	if selected_card_id.is_empty() or not card_enh_mgr or not BlueprintManager:
		return
	## v6.0: 检查情报道具消耗
	if not _consume_intel_item(IntelManualItems.TYPE_ENHANCE):
		return
	# 执行强化
	card_enh_mgr.enhance(selected_card_id, BlueprintManager)

func _on_evolve_button_pressed() -> void:
	if BlueprintManager == null or selected_card_id.is_empty() or _pending_evolution_target_id.is_empty():
		return
	if evolution_confirm_dialog == null:
		_try_execute_evolution()
		return
	var target_card: CardResource = DefaultCards.get_card_by_id(_pending_evolution_target_id)
	var target_name: String = target_card.display_name if target_card != null else _pending_evolution_target_id
	var can_info: Dictionary = BlueprintManager.can_evolve_blueprint(selected_card_id, _pending_evolution_target_id) if BlueprintManager.has_method("can_evolve_blueprint") else {}
	var research_cost: int = int(can_info.get("research_cost", 0))
	var pg: int = int(can_info.get("permit_general_count", 0))
	var pc: int = int(can_info.get("permit_category_count", 0))
	var ps: int = int(can_info.get("permit_specific_count", 0))
	var inherit_ratio: float = float(can_info.get("inherit_ratio", UnitLineageConfig.DEFAULT_INHERIT_RATIO))
	## v6.0: 显示进化图纸需求
	var evolve_item_name: String = IntelManualItems.get_def(IntelManualItems.TYPE_EVOLVE).get("name", "进化图纸")
	var bag: Node = get_node_or_null("/root/IntelItemBag")
	var evolve_have: int = bag.get_count(IntelManualItems.TYPE_EVOLVE) if bag else 0
	if nano_label:
		nano_label.text = "纳米材料：%d" % [BlueprintManager.get_nano_materials() if BlueprintManager else 0]
	## TODO: evolution_confirm_dialog 可扩展显示情报需求
	evolution_confirm_dialog.popup_centered(Vector2i(520, 360))

func _on_confirm_evolution() -> void:
	_try_execute_evolution()

func _try_execute_evolution() -> void:
	if BlueprintManager == null or selected_card_id.is_empty() or _pending_evolution_target_id.is_empty():
		return
	## v6.0: 消耗进化图纸
	if not _consume_intel_item(IntelManualItems.TYPE_EVOLVE):
		return
	var ok: bool = BlueprintManager.evolve_blueprint(selected_card_id, _pending_evolution_target_id) if BlueprintManager.has_method("evolve_blueprint") else false
	if result_label:
		if ok:
			var target_card: CardResource = DefaultCards.get_card_by_id(_pending_evolution_target_id)
			var target_name: String = target_card.display_name if target_card != null else DefaultCards.get_safe_display_name(_pending_evolution_target_id)
			result_label.text = "进化成功：%s -> %s" % [DefaultCards.get_safe_display_name(selected_card_id), target_name]
			result_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6, 1))
			selected_card_id = _pending_evolution_target_id
		else:
			result_label.text = "进化失败：请检查星级、改造次数与研究点是否满足。"
			result_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1))
	_init_card_list()
	_update_resource_labels()
	_update_detail_panel()

func _on_enhancement_completed(success: bool, card_id: String, new_stats: Dictionary, message: String) -> void:
	"""强化完成回调"""
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
	"""强化失败回调"""
	if card_id == selected_card_id:
		if result_label:
			result_label.text = reason
			result_label.add_theme_color_override("font_color", Color.RED)

func _on_nano_materials_changed(_old_value: int = 0, _new_value: int = 0) -> void:
	_update_resource_labels()
	_update_detail_panel()

func _update_resource_labels() -> void:
	if BlueprintManager == null:
		return
	if nano_label:
		nano_label.text = "纳米材料：%d" % BlueprintManager.get_nano_materials()
	if research_label:
		research_label.text = "研究点：%d" % BlueprintManager.get_research_points()

# ═══ v6.0: 敌源改造D槽 ═══

## 更新敌源改造区域
func _update_enemy_origin_mod_section() -> void:
	## 在detail_panel中查找或创建敌源MOD区域
	var section: Control = card_detail_panel.get_node_or_null("EomSection")
	if section == null:
		section = _create_eom_section()
		card_detail_panel.add_child(section)
		section.name = "EomSection"
	## 更新内容
	_update_eom_section_content(section)

## 创建敌源改造区域UI
func _create_eom_section() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	## 分隔线
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.25, 0.55, 0.35, 0.3))
	vbox.add_child(sep)

	## 标题
	var title := Label.new()
	title.text = "🧬 敌源改造 (D槽)"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.3, 0.85, 0.55, 1.0))
	vbox.add_child(title)

	## 内容容器
	var content := VBoxContainer.new()
	content.name = "EomContent"
	content.add_theme_constant_override("separation", 3)
	vbox.add_child(content)

	## 更换按钮
	var btn := Button.new()
	btn.name = "EomChangeBtn"
	btn.text = "选择敌源改造"
	btn.custom_minimum_size = Vector2(0, 28)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.25, 0.15, 0.9)
	btn_style.set_border_width_all(1)
	btn_style.set_border_color(Color(0.3, 0.6, 0.4, 0.5))
	btn_style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color(0.7, 0.95, 0.8, 1.0))
	btn.pressed.connect(_on_eom_change_pressed)
	vbox.add_child(btn)

	return vbox

## 更新敌源改造区域内容
func _update_eom_section_content(section: Control) -> void:
	var content: VBoxContainer = section.get_node_or_null("EomContent")
	var btn: Button = section.get_node_or_null("EomChangeBtn")
	if content == null:
		return

	## 清空旧内容
	for child in content.get_children():
		child.queue_free()

	## 检查D槽是否解锁
	var eom_mgr: Node = get_node_or_null("/root/EnemyOriginModManager")
	if eom_mgr == null or not eom_mgr.has_method("is_slot_unlocked_for_card"):
		var lock_lbl := Label.new()
		lock_lbl.text = "  ⚙ 敌源改造系统加载中..."
		lock_lbl.add_theme_font_size_override("font_size", 11)
		lock_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))
		content.add_child(lock_lbl)
		if btn:
			btn.disabled = true
		return

	if not eom_mgr.is_slot_unlocked_for_card():
		var lock_lbl := Label.new()
		lock_lbl.text = "  🔒 需要任意敌人素材情报 ≥ 30% 解锁D槽"
		lock_lbl.add_theme_font_size_override("font_size", 11)
		lock_lbl.add_theme_color_override("font_color", Color(0.55, 0.45, 0.5, 1.0))
		content.add_child(lock_lbl)
		if btn:
			btn.disabled = true
		return

	if selected_card_id.is_empty():
		if btn:
			btn.disabled = true
		return

	## 显示当前装备
	var equipped_id: String = eom_mgr.get_equipped_eom(selected_card_id)
	if not equipped_id.is_empty():
		var EOM = preload("res://data/enemy_origin_mods.gd")
		var mod: Dictionary = EOM.get_mod(equipped_id)
		if not mod.is_empty():
			var tier: int = eom_mgr.get_effective_tier(equipped_id)
			var name_lbl := Label.new()
			name_lbl.text = "  ◆ %s [Tier %d]" % [mod.get("name", "?"), tier]
			name_lbl.add_theme_font_size_override("font_size", 12)
			name_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.65, 1.0))
			content.add_child(name_lbl)
			var effects: Dictionary = EOM.get_tier_effects(equipped_id, tier)
			var effect_lbl := Label.new()
			effect_lbl.text = "    %s" % mod.get("tiers", [{}])[min(tier, 2)].get("desc", "")
			effect_lbl.add_theme_font_size_override("font_size", 10)
			effect_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.75, 1.0))
			content.add_child(effect_lbl)
	else:
		var empty_lbl := Label.new()
		empty_lbl.text = "  ○ 未装备敌源改造"
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6, 1.0))
		content.add_child(empty_lbl)

	if btn:
		btn.disabled = false

# ═══ v6.0: 情报道具消耗逻辑 ═══

## 消耗一个情报道具，失败时显示提示
func _consume_intel_item(item_type: String) -> bool:
	var bag: Node = get_node_or_null("/root/IntelItemBag")
	if bag == null or not bag.has_method("has_item"):
		if result_label:
			result_label.text = "情报道具系统未加载。"
			result_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3, 1.0))
		return false
	var item_def: Dictionary = IntelManualItems.get_def(item_type)
	var item_name: String = item_def.get("name", "情报道具") if not item_def.is_empty() else item_type
	if not bag.has_item(item_type):
		if result_label:
			result_label.text = "缺少【%s】！可在战斗中获得或商店购买。" % item_name
			result_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3, 1.0))
		return false
	var ok: bool = bag.consume_item(item_type)
	if ok and result_label:
		result_label.text = "使用【%s】..." % item_name
		result_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0, 1.0))
	return ok

## 根据改装槽位返回对应的情报道具类型
func _get_mod_item_type_for_slot(slot_index: int) -> String:
	match slot_index:
		0:
			return IntelManualItems.TYPE_MOD_A
		1:
			return IntelManualItems.TYPE_MOD_B
		2:
			return IntelManualItems.TYPE_MOD_C
		_:
			return ""

## 更换敌源改造按钮回调
func _on_eom_change_pressed() -> void:
	if selected_card_id.is_empty():
		return
	var eom_mgr: Node = get_node_or_null("/root/EnemyOriginModManager")
	if eom_mgr == null:
		return
	var available: Array = eom_mgr.get_available_mods_for_card(selected_card_id)
	if available.is_empty():
		return
	## 简化实现：轮流装备第一个可用的敌源MOD
	## TODO: 弹出选择器弹窗
	var current: String = eom_mgr.get_equipped_eom(selected_card_id)
	if not current.is_empty():
		eom_mgr.unequip_eom(selected_card_id)
	elif available.size() > 0:
		var mod_id: String = available[0].get("id", "") if available[0] is Dictionary else ""
		if not mod_id.is_empty():
			eom_mgr.equip_eom(selected_card_id, mod_id)
	_update_detail_panel()

func _on_close() -> void:
	closed.emit()

func _on_card_added_to_backpack(_card: CardResource) -> void:
	_init_card_list()
	_update_detail_panel()

## 添加属性预览功能
func _add_attribute_preview(parent: Control, card_data: Variant, current_level: int, next_level: int) -> void:
	"""显示强化前后的属性对比"""
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
	"""根据卡牌数据获取当前等级的属性"""
	var stats = {}

	if card_data is Dictionary:
		var display_name = card_data.get("display_name", "")
		var energy_cost = card_data.get("energy_cost", 0)
		var card_type = card_data.get("card_type", 0)

		stats["能量消耗"] = energy_cost

		# 根据卡牌类型获取不同属性
		if card_type == GC.CardType.COMBAT_UNIT:
			var max_hp = card_data.get("max_hp", 100)
			var move_speed = card_data.get("move_speed", 100)
			stats["生命值"] = int(max_hp * (1.0 + (level - 1) * 0.1))
			stats["移速"] = int(move_speed * (1.0 + (level - 1) * 0.05))

	return stats
