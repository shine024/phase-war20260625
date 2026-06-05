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

const MOD_SLOT_LABELS: PackedStringArray = ["A", "B", "C", "D", "E", "F", "G", "H", "I"]

const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")

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
	# v7.1: 蓝图副本（进化后新卡在此）
	if BlueprintManager and BlueprintManager.has_method("get_all_blueprint_ids"):
		for id_raw in BlueprintManager.get_all_blueprint_ids():
			var sid: String = String(id_raw)
			if not sid.is_empty():
				all_card_ids.append(sid)
	# 背包中的卡牌
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
	var mod_now: int = BlueprintManager.get_modification_count(selected_card_id) if BlueprintManager.has_method("get_modification_count") else 0
	var inherit_ratio: float = float(can_info.get("inherit_ratio", UnitLineageConfig.DEFAULT_INHERIT_RATIO))
	var reason: String = _evolve_reason_display(can_info)
	tips.bbcode_enabled = true
	tips.text = "[color=#7fd3ff]进化得失提示[/color]\n" + \
		"[color=#8ef58e]获得[/color]：新单位成长上限、军衔重新评估、属性传承 %.0f%%\n" % (inherit_ratio * 100.0) + \
		"[color=#ffb37f]失去[/color]：强化等级重置（改造继承到新卡）\n" + \
		"当前：改造 %d/9，强化Lv需≥%d\n" % [mod_now, int(can_info.get("enhance_requirement", 5))] + \
		("状态：[color=#8ef58e]可进化[/color]" if can_evolve else "状态：[color=#ff7373]不可进化（%s）[/color]" % reason)
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
	var info: Dictionary = ModEffects.get_mod_info(option_id)
	if not info.is_empty():
		return String(info.get("name", option_id))
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
		"槽位 %s：消耗研究点 %d（当前 %d）" % [slot, int(req.get("research_points", 0)), BlueprintManager.get_research_points()],
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
	## v7.1: 统一到新改造系统（ModificationRegistry）
	var applied: Array = BlueprintManager.blueprint_mods.get(selected_card_id, [])
	var applied_parts: PackedStringArray = PackedStringArray()
	for i in range(applied.size()):
		var entry = applied[i]
		var mod_id: String = ""
		if entry is Dictionary:
			mod_id = String(entry.get("id", ""))
		else:
			mod_id = String(entry)
		var slot: String = MOD_SLOT_LABELS[i] if i < MOD_SLOT_LABELS.size() else "?"
		var mod_name: String = _new_mod_display_name(mod_id)
		applied_parts.append("%s:%s" % [slot, mod_name])
	var applied_text: String = " / ".join(applied_parts) if applied_parts.size() > 0 else "无"
	mod_status_label.text = "改造进度：%s（%d/9）" % [applied_text, applied.size()]
	var card_data: CardResource = DefaultCards.get_card_by_id(selected_card_id)
	if card_data == null:
		if mod_req_label:
			mod_req_label.text = "找不到卡牌数据"
		_set_mod_branch_buttons_enabled(false)
		return
	## 计算纳米消耗
	var nano_cost: int = int(card_data.power * 0.5)
	var have_nano: int = BlueprintManager.get_nano_materials() if BlueprintManager else 0
	if mod_req_label:
		mod_req_label.text = "下次改造消耗：%d纳米（当前：%d）\n选择下方的\"火力\"\"防护\"\"功能\"查看并安装具体改造模块" % [nano_cost, have_nano]
	_set_mod_branch_buttons_enabled(applied.size() < 9 and have_nano >= nano_cost)

## v7.1: 新改造系统名称解析
func _new_mod_display_name(mod_id: String) -> String:
	if mod_id.is_empty():
		return "?"
	## 旧MOD_XX格式（兼容旧存档）
	if mod_id.begins_with("MOD_"):
		return _mod_option_display_name(mod_id)
	## 新格式：从ModificationRegistry查询
	if ModificationRegistry and ModificationRegistry.has_method("get_data"):
		var mod_data: Dictionary = ModificationRegistry.get_data(mod_id)
		if not mod_data.is_empty():
			return String(mod_data.get("name", mod_id))
	return mod_id

func _on_mod_option_pressed(option_id: String) -> void:
	## v7.1: 改为显示新系统改造选择面板
	if selected_card_id.is_empty():
		return
	var card_data: CardResource = DefaultCards.get_card_by_id(selected_card_id)
	if card_data == null:
		return
	## 根据选择的分类（offense/defense/utility）过滤改造
	_open_mod_selector_popup(card_data, option_id)

## v7.1: 打开改造选择弹窗
func _open_mod_selector_popup(card: CardResource, category: String) -> void:
	if not is_inside_tree():
		return
	var unit_type: int = card.combat_kind
	var available_mods: Array = []
	if ModificationRegistry and ModificationRegistry.has_method("get_for_unit_type"):
		available_mods = ModificationRegistry.get_for_unit_type(unit_type)
	## 同时获取通用改造
	if ModificationRegistry and ModificationRegistry.has_method("get_mods_for_card"):
		var card_mods: Array = ModificationRegistry.get_mods_for_card(card.card_id)
		for cm_id in card_mods:
			if not available_mods.has(cm_id):
				available_mods.append(cm_id)
	if available_mods.is_empty():
		if result_label:
			result_label.text = "该兵种暂无可用改造模块。"
			result_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3, 1))
		return
	## 按分类过滤
	var filtered_mods: Array = []
	for mod_id in available_mods:
		var mod_data: Dictionary = ModificationRegistry.get_data(mod_id) if ModificationRegistry else {}
		var slot_type: String = String(mod_data.get("slot_type", ""))
		if _mod_category_matches(slot_type, category):
			filtered_mods.append(mod_id)
	if filtered_mods.is_empty():
		## 如果过滤后为空，显示全部（让玩家看到所有选项）
		filtered_mods = available_mods.duplicate()
		if result_label:
			result_label.text = "该分类无可用改造，显示全部选项"
			result_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5, 1))
	## 创建弹窗
	_create_mod_popup(filtered_mods, card)

## 判断改造slot_type是否匹配分类
func _mod_category_matches(slot_type: String, category: String) -> bool:
	match category:
		"offense":
			return slot_type in ["gun", "ammunition", "autoloader", "fire_control"]
		"defense":
			return slot_type in ["armor", "active", "command", "optics", "engineering", "environment"]
		"utility":
			return slot_type in ["engine", "comms", "survival"]
		_:
			return true

## 创建改造选择弹窗
func _create_mod_popup(mod_ids: Array, card: CardResource) -> void:
	## 移除旧弹窗
	var old_popup = get_node_or_null("_ModSelectorPopup")
	if old_popup:
		old_popup.queue_free()
	## 创建容器
	var popup := PopupPanel.new()
	popup.name = "_ModSelectorPopup"
	popup.size = Vector2i(480, 520)
	## 标题
	var title := Label.new()
	title.text = "选择改造模块（%s）" % card.display_name
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0, 0.9, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	## 滚动容器
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 400)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)
	## 获取已安装的改造列表
	var installed_ids: Array = []
	var applied: Array = BlueprintManager.blueprint_mods.get(card.card_id, []) if BlueprintManager else []
	for entry in applied:
		var eid: String = String(entry.get("id", "")) if entry is Dictionary else String(entry)
		installed_ids.append(eid)
	for mod_id in mod_ids:
		var mod_data: Dictionary = ModificationRegistry.get_data(mod_id) if ModificationRegistry else {}
		var mod_name: String = String(mod_data.get("name", mod_id))
		var mod_desc: String = String(mod_data.get("description", ""))
		var mod_rarity: String = String(mod_data.get("rarity", "common"))
		var conflict_group: String = String(mod_data.get("conflict_group", ""))
		## 检查是否已安装
		var is_installed: bool = installed_ids.has(mod_id)
		## 检查是否冲突
		var conflict_with: String = ""
		if not conflict_group.is_empty():
			for inst_id in installed_ids:
				var inst_data: Dictionary = ModificationRegistry.get_data(inst_id) if ModificationRegistry else {}
				if inst_data.get("conflict_group", "") == conflict_group:
					conflict_with = String(inst_data.get("name", inst_id))
					break
		## 检查蓝图持有
		var blueprint_id: String = BlueprintDefinitions.get_mod_blueprint_id(mod_id)
		var has_blueprint: bool = false
		if IntelItemBag:
			has_blueprint = IntelItemBag.has_item(blueprint_id)
		## 纳米消耗
		var nano_cost: int = int(card.power * 0.5)
		var have_nano: int = BlueprintManager.get_nano_materials() if BlueprintManager else 0
		var rarity_color := Color(0.7, 0.8, 0.7, 1)
		match mod_rarity:
			"uncommon": rarity_color = Color(0.3, 0.75, 0.3, 1)
			"rare": rarity_color = Color(0.3, 0.5, 1.0, 1)
			"epic": rarity_color = Color(0.7, 0.3, 0.9, 1)
			"legendary": rarity_color = Color(1.0, 0.6, 0.2, 1)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(440, 60)
		var rarity_names := {"common": "普通", "uncommon": "精良", "rare": "稀有", "epic": "史诗", "legendary": "传说"}
		var rarity_text: String = rarity_names.get(mod_rarity, mod_rarity)
		var status_text: String = ""
		if is_installed:
			btn.text = "%s [%s]（已安装）" % [mod_name, rarity_text]
			btn.disabled = true
		elif not conflict_with.is_empty():
			btn.text = "%s [%s]（与「%s」冲突）" % [mod_name, rarity_text, conflict_with]
			btn.disabled = true
		elif not has_blueprint:
			btn.text = "%s [%s]（缺少图纸）" % [mod_name, rarity_text]
			btn.disabled = true
		elif have_nano < nano_cost:
			btn.text = "%s [%s]（纳米不足 %d）" % [mod_name, rarity_text, nano_cost]
			btn.disabled = true
		else:
			btn.text = "%s [%s] — %d纳米 + 图纸" % [mod_name, rarity_text, nano_cost]
			btn.pressed.connect(_on_new_mod_selected.bind(card, mod_id))
		btn.add_theme_color_override("font_color", rarity_color)
		btn.tooltip_text = "%s\n%s\n冲突组：%s" % [mod_name, mod_desc, conflict_group if not conflict_group.is_empty() else "无"]
		vbox.add_child(btn)
	## 布局
	var main_vbox := VBoxContainer.new()
	main_vbox.add_child(title)
	main_vbox.add_child(scroll)
	popup.add_child(main_vbox)
	add_child(popup)
	popup.popup_centered()

## v7.1: 新系统改造安装回调
func _on_new_mod_selected(card: CardResource, mod_id: String) -> void:
	## 移除弹窗
	var popup = get_node_or_null("_ModSelectorPopup")
	if popup:
		popup.queue_free()
	var result: Dictionary = BlueprintManager.install_modification(card, mod_id)
	if result_label:
		if result.get("success", false):
			result_label.text = "改造安装成功：%s" % String(result.get("message", ""))
			result_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 1))
		else:
			result_label.text = "改造安装失败：%s" % String(result.get("message", "未知错误"))
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
	star_upgrade_button.disabled = not can_up
	star_upgrade_button.text = "升星至 %d★（研究点 %d）" % [star_now + 1, need_rp]

func _on_star_upgrade_button_pressed() -> void:
	if selected_card_id.is_empty() or BlueprintManager == null:
		return
	if not BlueprintManager.has_method("upgrade_blueprint_level"):
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
	var source_name: String = DefaultCards.get_safe_display_name(selected_card_id)
	var can_info: Dictionary = BlueprintManager.can_evolve_blueprint(selected_card_id, _pending_evolution_target_id) if BlueprintManager.has_method("can_evolve_blueprint") else {}
	var inherit_ratio: float = float(can_info.get("inherit_ratio", UnitLineageConfig.DEFAULT_INHERIT_RATIO))
	var current_nano: int = BlueprintManager.get_nano_materials() if BlueprintManager else 0
	var current_research: int = BlueprintManager.get_research_points() if BlueprintManager else 0
	## v7.1: 构建清晰的确认对话框内容
	var lines: Array[String] = []
	lines.append("▶ 进化：%s → %s" % [source_name, target_name])
	lines.append("")
	lines.append("【条件要求】")
	var stage: String = String(can_info.get("stage", "e1"))
	var req_enhance: int = int(can_info.get("enhance_requirement", UnitLineageConfig.E1_MIN_ENHANCE_LEVEL))
	var req_mod: int = int(can_info.get("mod_requirement", UnitLineageConfig.E1_MIN_MOD_COUNT))
	var cur_enhance: int = int(can_info.get("current_enhance", 0))
	var cur_mod: int = int(can_info.get("current_mod_count", 0))
	lines.append("  强化等级：%d（需≥%d）%s" % [cur_enhance, req_enhance, "✓" if cur_enhance >= req_enhance else "✗"])
	lines.append("  改造数量：%d（需≥%d）%s" % [cur_mod, req_mod, "✓" if cur_mod >= req_mod else "✗"])
	if UnitLineageConfig.get_enemy_mod_required(stage):
		lines.append("  敌源改造：需要1个 %s" % ("✓" if can_info.get("ok", false) else "✗"))
	var req_faction_lv: int = UnitLineageConfig.get_faction_level_required(stage)
	if req_faction_lv > 0:
		lines.append("  势力等级：需≥%d" % req_faction_lv)
	lines.append("  进化蓝图：需要（已获得后永久可用）")
	lines.append("")
	lines.append("【获得】属性传承 %.0f%%、新成长上限" % (inherit_ratio * 100.0))
	lines.append("【失去】强化等级重置、改造继承到新卡")
	lines.append("")
	lines.append("当前资源：纳米 %d | 研究点 %d" % [current_nano, current_research])
	evolution_confirm_dialog.title = "进化确认"
	evolution_confirm_dialog.dialog_text = "\n".join(lines)
	evolution_confirm_dialog.popup_centered(Vector2i(460, 380))

func _on_confirm_evolution() -> void:
	_try_execute_evolution()

func _try_execute_evolution() -> void:
	if BlueprintManager == null or selected_card_id.is_empty() or _pending_evolution_target_id.is_empty():
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
			## v7.1: 精确错误信息
			var fail_reason: String = ""
			var fail_info: Dictionary = BlueprintManager.can_evolve_blueprint(selected_card_id, _pending_evolution_target_id) if BlueprintManager.has_method("can_evolve_blueprint") else {}
			if not fail_info.is_empty():
				fail_reason = String(fail_info.get("reason_zh", ""))
			if fail_reason.is_empty():
				fail_reason = "条件未满足"
			result_label.text = "进化失败：%s" % fail_reason
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

		if _enhance_anim:
			if success:
				_enhance_anim.play_success_animation(card_id)
			else:
				_enhance_anim.play_failure_animation()

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
		if _enhance_anim:
			_enhance_anim.play_failure_animation()

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

## 根据改装槽位返回对应的情报道具类型（v7.0: 已废弃，使用特定蓝图系统）
func _get_mod_item_type_for_slot(slot_index: int) -> String:
	## 蓝图系统现在由BlueprintManager在apply_modification中检查特定蓝图
	## 此函数返回空表示不再消耗通用许可函
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
