extends Control
class_name EvolutionPanel
## 进化面板（重新设计版本）
## 更大的显示区域，更合理的布局，更强的可读性

signal closed

const DefaultCards = preload("res://data/default_cards.gd")
const IntelManualItems = preload("res://data/intel_manual_items.gd")
const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")

# UI 组件引用 - 匹配新场景结构
var card_selector: OptionButton = null
var current_card_info: Label = null
var evolution_tree: VBoxContainer = null
var detail_content: VBoxContainer = null
var result_label: Label = null
var no_selection_label: Label = null
var target_name_label: Label = null
var info_details: Label = null
var req_details: Label = null
var resource_details: Label = null
var evolve_button: Button = null

# 统计标签
var stat_hp: Label = null
var stat_attack_light: Label = null
var stat_attack_armor: Label = null
var stat_attack_air: Label = null
var stat_defense_light: Label = null
var stat_defense_armor: Label = null
var stat_defense_air: Label = null
var stat_range: Label = null
var stat_speed: Label = null

var selected_card: CardResource = null
var selected_target_id: String = ""
var _embedded_mode: bool = false
var _card_list: Array[CardResource] = []
var _evolve_callable: Callable

func _ready() -> void:
	# 获取UI组件引用
	card_selector = get_node_or_null("VBoxContainer/CardSelectorArea/CardSelectorHBox/CardSelector")
	current_card_info = get_node_or_null("VBoxContainer/CardSelectorArea/CardSelectorHBox/CurrentCardInfo")
	evolution_tree = get_node_or_null("VBoxContainer/MainContentSplit/LeftPanel/EvolutionScroll/EvolutionTree")
	detail_content = get_node_or_null("VBoxContainer/MainContentSplit/RightPanel/DetailScroll/DetailContent")
	result_label = get_node_or_null("VBoxContainer/ResultLabel")

	# 详情面板组件
	no_selection_label = get_node_or_null("VBoxContainer/MainContentSplit/RightPanel/DetailScroll/DetailContent/NoSelectionLabel")
	target_name_label = get_node_or_null("VBoxContainer/MainContentSplit/RightPanel/DetailScroll/DetailContent/TargetNamePanel/TargetNameLabel")
	info_details = get_node_or_null("VBoxContainer/MainContentSplit/RightPanel/DetailScroll/DetailContent/InfoPanel/InfoContent/InfoDetails")
	req_details = get_node_or_null("VBoxContainer/MainContentSplit/RightPanel/DetailScroll/DetailContent/RequirementsPanel/ReqContent/ReqDetails")
	resource_details = get_node_or_null("VBoxContainer/MainContentSplit/RightPanel/DetailScroll/DetailContent/ResourcePanel/ResourceContent/ResourceDetails")
	evolve_button = get_node_or_null("VBoxContainer/MainContentSplit/RightPanel/DetailScroll/DetailContent/ButtonArea/EvolveButton")

	# 统计标签
	stat_hp = get_node_or_null("VBoxContainer/MainContentSplit/RightPanel/DetailScroll/DetailContent/StatsPanel/StatsContent/StatHP")
	stat_attack_light = get_node_or_null("VBoxContainer/MainContentSplit/RightPanel/DetailScroll/DetailContent/StatsPanel/StatsContent/StatAttackLight")
	stat_attack_armor = get_node_or_null("VBoxContainer/MainContentSplit/RightPanel/DetailScroll/DetailContent/StatsPanel/StatsContent/StatAttackArmor")
	stat_attack_air = get_node_or_null("VBoxContainer/MainContentSplit/RightPanel/DetailScroll/DetailContent/StatsPanel/StatsContent/StatAttackAir")
	stat_defense_light = get_node_or_null("VBoxContainer/MainContentSplit/RightPanel/DetailScroll/DetailContent/StatsPanel/StatsContent/StatDefenseLight")
	stat_defense_armor = get_node_or_null("VBoxContainer/MainContentSplit/RightPanel/DetailScroll/DetailContent/StatsPanel/StatsContent/StatDefenseArmor")
	stat_defense_air = get_node_or_null("VBoxContainer/MainContentSplit/RightPanel/DetailScroll/DetailContent/StatsPanel/StatsContent/StatDefenseAir")
	stat_range = get_node_or_null("VBoxContainer/MainContentSplit/RightPanel/DetailScroll/DetailContent/StatsPanel/StatsContent/StatRange")
	stat_speed = get_node_or_null("VBoxContainer/MainContentSplit/RightPanel/DetailScroll/DetailContent/StatsPanel/StatsContent/StatSpeed")

	# 连接关闭按钮
	var close_btn = get_node_or_null("VBoxContainer/TitleArea/TitleHBox/CloseButton")
	if close_btn:
		close_btn.pressed.connect(_on_close)

	# 连接卡牌选择器
	if card_selector:
		card_selector.item_selected.connect(_on_card_selector_changed)

	_evolve_callable = _on_evolve_pressed

	if _embedded_mode:
		_apply_embedded_layout()
	else:
		_refresh_card_selector()

## 内嵌模式：隐藏标题和卡牌选择器
func set_embedded_mode(p_embedded: bool) -> void:
	_embedded_mode = p_embedded
	if is_inside_tree():
		_apply_embedded_layout()

func _apply_embedded_layout() -> void:
	var title_area = get_node_or_null("VBoxContainer/TitleArea")
	if title_area:
		title_area.visible = false
	var selector_area = get_node_or_null("VBoxContainer/CardSelectorArea")
	if selector_area:
		selector_area.visible = false

## ─────────────────────────────────────────────
##  UI更新
## ─────────────────────────────────────────────

## 刷新卡牌选择器
func _refresh_card_selector() -> void:
	if card_selector == null:
		return

	card_selector.clear()
	_card_list.clear()

	# 添加所有卡牌到选择器
	for id_raw in BlueprintManager.get_all_blueprint_ids():
		var card_id: String = str(id_raw)
		var card: CardResource = DefaultCards.get_card_by_id(card_id)
		if card == null:
			continue
		_card_list.append(card)
		card_selector.add_item(card.display_name)

	# 选中第一张卡
	if _card_list.size() > 0:
		card_selector.selected = 0
		_on_card_selected(_card_list[0])

## 卡牌选择器变化时
func _on_card_selector_changed(index: int) -> void:
	if index >= 0 and index < _card_list.size():
		_on_card_selected(_card_list[index])

## 创建大型进化节点
func _create_evolution_node(target: Dictionary) -> Control:
	var node = PanelContainer.new()
	node.add_theme_stylebox_override("panel", get_theme_stylebox("Panel", "PanelContainer"))
	node.custom_minimum_size = Vector2(600, 140)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	node.add_child(content)

	# 顶部：名称和状态
	var top_row = HBoxContainer.new()
	content.add_child(top_row)

	var name_btn = Button.new()
	name_btn.text = target.name
	name_btn.custom_minimum_size = Vector2(400, 44)
	name_btn.add_theme_font_size_override("font_size", 18)
	name_btn.pressed.connect(func(): _on_target_selected(target.target_id, target.name))
	top_row.add_child(name_btn)

	# 状态指示
	var check_result = BlueprintManager.can_evolve_blueprint(selected_card.card_id, target.target_id)
	var status_label = Label.new()
	if check_result.get("ok", false):
		status_label.text = "✓ 可进化"
		status_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
		status_label.add_theme_font_size_override("font_size", 20)
	else:
		status_label.text = "✗ 条件不足"
		status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		status_label.add_theme_font_size_override("font_size", 20)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_row.add_child(status_label)

	# 中部：战力信息
	var target_card = DefaultCards.get_card_by_id(target.target_id)
	var current_power = _get_current_power_score()
	var target_power = target_card.power if target_card else 0

	var power_row = HBoxContainer.new()
	content.add_child(power_row)

	var power_label = Label.new()
	power_label.text = "战力要求： %d / %d" % [current_power, target_power]
	power_label.add_theme_font_size_override("font_size", 16)
	if current_power >= target_power:
		power_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
	else:
		power_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	power_row.add_child(power_label)

	# 右侧：路径类型
	var type_label = Label.new()
	type_label.text = " [%s] %s时代" % [target.path_type, target_card.era if target_card else ""]
	type_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	type_label.add_theme_font_size_override("font_size", 14)
	power_row.add_child(type_label)

	# 底部：条件详情
	var req_detail = Label.new()
	req_detail.add_theme_constant_override("separation", 0)
	if check_result.get("ok", false):
		req_detail.text = "✓ 所有条件已满足，可以进化"
		req_detail.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4))
		req_detail.add_theme_font_size_override("font_size", 14)
	else:
		var missing_text = "缺失条件：\n"
		var reason_zh: String = String(check_result.get("reason_zh", ""))
		if not reason_zh.is_empty():
			missing_text += "  • " + reason_zh + "\n"
		req_detail.text = missing_text
		req_detail.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
		req_detail.add_theme_font_size_override("font_size", 14)

	content.add_child(req_detail)

	return node

func _update_evolution_tree() -> void:
	if evolution_tree == null:
		return
	if not selected_card:
		_clear_evolution_tree()
		return

	# 清空进化树
	_clear_evolution_tree()

	# 获取进化路径
	var targets = selected_card.get_evolution_targets()

	if targets.is_empty():
		var no_target_label = Label.new()
		no_target_label.text = "该卡牌无可进化目标"
		no_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_target_label.add_theme_font_size_override("font_size", 18)
		no_target_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		evolution_tree.add_child(no_target_label)
		return

	# 添加间距
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	evolution_tree.add_child(spacer)

	# 创建进化树节点
	for target in targets:
		var target_node = _create_evolution_node(target)
		evolution_tree.add_child(target_node)

		# 节点之间添加间距
		var gap = Control.new()
		gap.custom_minimum_size = Vector2(0, 16)
		evolution_tree.add_child(gap)

func _clear_evolution_tree() -> void:
	for child in evolution_tree.get_children():
		child.queue_free()

## 更新当前卡牌信息显示
func _update_current_card_info() -> void:
	if current_card_info == null or selected_card == null:
		return

	var rank_info = selected_card.get_military_rank()
	var power = _get_current_power_score()
	current_card_info.text = "军衔：%s | 战力：%d | 改造：%d/9" % [
		rank_info.name, power, selected_card.mods.size()
	]

## 获取当前卡牌的战力评分
func _get_current_power_score() -> int:
	if not selected_card:
		return 0
	if BlueprintManager and BlueprintManager.has_method("_estimate_power_score"):
		return int(BlueprintManager._estimate_power_score(selected_card.card_id))
	return selected_card.power

func _update_detail_panel() -> void:
	if detail_content == null:
		return
	if not selected_card or selected_target_id.is_empty():
		_clear_detail_panel()
		return

	# 隐藏默认提示，显示详情面板
	if no_selection_label:
		no_selection_label.visible = false
	_set_detail_panel_visible(true)

	# 显示目标信息
	var target_card = DefaultCards.get_card_by_id(selected_target_id)
	if not target_card:
		return

	# 更新目标名称
	if target_name_label:
		target_name_label.text = "→ " + target_card.display_name

	# 更新基础信息
	if info_details:
		var rank_info = target_card.get_military_rank()
		info_details.text = "军衔：%s | 战力：%d\n" % [rank_info.name, target_card.power]
		info_details.text += "时代：%s | 类型：%s\n" % [target_card.era, target_card.combat_kind]
		info_details.text += "武器：%s\n" % target_card.weapon_type

	# 显示条件检查
	var check_result = BlueprintManager.can_evolve_blueprint(selected_card.card_id, selected_target_id)
	if req_details:
		if check_result.get("ok", false):
			req_details.text = "✓ 所有条件满足，可以进化"
			req_details.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		else:
			var req_text = "缺失条件：\n"
			var reason_zh: String = String(check_result.get("reason_zh", ""))
			if not reason_zh.is_empty():
				req_text += "  • " + reason_zh + "\n"
			req_details.text = req_text
			req_details.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))

	# 更新属性预览
	var new_stats = selected_card.calculate_evolved_stats(selected_target_id)
	if stat_hp:
		stat_hp.text = "生命值：%d" % new_stats.get("max_hp", 0)
	if stat_attack_light:
		stat_attack_light.text = "攻击轻甲：%d" % new_stats.get("attack_light", 0)
	if stat_attack_armor:
		stat_attack_armor.text = "攻击重甲：%d" % new_stats.get("attack_armor", 0)
	if stat_attack_air:
		stat_attack_air.text = "攻击空中：%d" % new_stats.get("attack_air", 0)
	if stat_defense_light:
		stat_defense_light.text = "防御轻甲：%d" % new_stats.get("defense_light", 0)
	if stat_defense_armor:
		stat_defense_armor.text = "防御重甲：%d" % new_stats.get("defense_armor", 0)
	if stat_defense_air:
		stat_defense_air.text = "防御空中：%d" % new_stats.get("defense_air", 0)
	if stat_range:
		stat_range.text = "射程：%d" % new_stats.get("attack_range", 0)
	if stat_speed:
		stat_speed.text = "移速：%d" % new_stats.get("move_speed", 0)

	# 显示资源信息
	var nano_amount = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS)
	var nano_cost = int(target_card.power * 2.0)

	if resource_details:
		var res_text = ""
		if nano_amount >= nano_cost:
			res_text += "✓ 纳米材料：%d / %d\n" % [nano_amount, nano_cost]
		else:
			res_text += "✗ 纳米材料：%d / %d（不足）\n" % [nano_amount, nano_cost]

		var evo_blueprint_id = BlueprintDefinitions.get_evolution_blueprint_id(selected_card.card_id, selected_target_id)
		var has_blueprint = false
		if IntelItemBag:
			has_blueprint = IntelItemBag.has_item(evo_blueprint_id)
		res_text += "进化图纸：" + ("✓ 已拥有" if has_blueprint else "✗ 未获得")

		resource_details.text = res_text
		if has_blueprint and nano_amount >= nano_cost:
			resource_details.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		else:
			resource_details.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))

	# 进化按钮
	if evolve_button:
		var evo_blueprint_id = BlueprintDefinitions.get_evolution_blueprint_id(selected_card.card_id, selected_target_id)
		var has_blueprint = false
		if IntelItemBag:
			has_blueprint = IntelItemBag.has_item(evo_blueprint_id)

		var has_nano = nano_amount >= nano_cost

		if not has_blueprint:
			evolve_button.text = "缺少进化图纸"
			evolve_button.disabled = true
		elif not has_nano:
			evolve_button.text = "纳米材料不足（需要 %d）" % nano_cost
			evolve_button.disabled = true
		elif not check_result.get("ok", false):
			evolve_button.text = "进化条件未满足"
			evolve_button.disabled = true
		else:
			evolve_button.text = "执行进化（消耗 %d 纳米）" % nano_cost
			evolve_button.disabled = false

		if not evolve_button.pressed.is_connected(_evolve_callable):
			evolve_button.pressed.connect(_evolve_callable)

func _clear_detail_panel() -> void:
	if no_selection_label:
		no_selection_label.visible = true

	# 显示详情面板（让 NoSelectionLabel 可见），但隐藏子面板
	_set_detail_panel_visible(true)
	if target_name_label:
		target_name_label.visible = false
	if info_details:
		info_details.visible = false
	if req_details:
		req_details.visible = false
	if stat_hp:
		stat_hp.visible = false
	if resource_details:
		resource_details.visible = false
	if evolve_button:
		evolve_button.visible = false

func _restore_detail_sub_panels() -> void:
	if target_name_label:
		target_name_label.visible = true
	if info_details:
		info_details.visible = true
	if req_details:
		req_details.visible = true
	if stat_hp:
		stat_hp.visible = true
	if resource_details:
		resource_details.visible = true
	if evolve_button:
		evolve_button.visible = true

func _set_detail_panel_visible(visible: bool) -> void:
	if detail_content:
		detail_content.visible = visible

## ─────────────────────────────────────────────
##  进化操作
## ─────────────────────────────────────────────

func _on_evolve_pressed() -> void:
	if not selected_card or selected_target_id.is_empty():
		return

	if BlueprintManager and BlueprintManager.has_method("can_evolve_blueprint") and BlueprintManager.has_method("evolve_blueprint"):
		var ok: bool = BlueprintManager.evolve_blueprint(selected_card.card_id, selected_target_id)
		if ok:
			_show_result("进化成功：%s → %s" % [selected_card.display_name, DefaultCards.get_safe_display_name(selected_target_id)])
			# 刷新UI - 选中进化后的新卡
			var new_card: CardResource = DefaultCards.get_card_by_id(selected_target_id)
			if new_card:
				selected_card = new_card
				# 更新选择器
				_refresh_card_selector()
				# 找到新卡的索引并选中
				for i in range(_card_list.size()):
					if _card_list[i].card_id == selected_target_id:
						card_selector.selected = i
						break
			_update_evolution_tree()
			_clear_detail_panel()
		else:
			var fail_info: Dictionary = BlueprintManager.can_evolve_blueprint(selected_card.card_id, selected_target_id)
			var fail_reason: String = String(fail_info.get("reason_zh", "条件未满足"))
			_show_result("进化失败：%s" % fail_reason)
	else:
		_show_result("进化系统未加载")

## ─────────────────────────────────────────────
##  事件处理
## ─────────────────────────────────────────────

func _on_card_selected(card: CardResource) -> void:
	selected_card = card
	selected_target_id = ""
	_update_current_card_info()
	_update_evolution_tree()
	_clear_detail_panel()

func _on_target_selected(target_id: String, target_name: String) -> void:
	selected_target_id = target_id
	_restore_detail_sub_panels()
	_update_detail_panel()

## 供外部调用的接口
func set_selected_card(card: CardResource) -> void:
	selected_card = card
	selected_target_id = ""
	if has_node("VBoxContainer/MainContentSplit/LeftPanel/EvolutionScroll/EvolutionTree"):
		_update_evolution_tree()
	if has_node("VBoxContainer/MainContentSplit/RightPanel/DetailScroll/DetailContent"):
		_update_detail_panel()
	_update_current_card_info()

func show_panel() -> void:
	visible = true
	if not _embedded_mode:
		_refresh_card_selector()

func _on_close() -> void:
	closed.emit()

func _show_result(message: String) -> void:
	if result_label:
		result_label.text = message
		result_label.visible = true
		await get_tree().create_timer(3.0).timeout
		result_label.visible = false
