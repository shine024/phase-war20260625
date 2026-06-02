extends Control
class_name EvolutionPanel
## 进化面板（新系统）
## 显示进化路径，改造保留信息

signal closed

const DefaultCards = preload("res://data/default_cards.gd")

# UI 组件引用
var card_list_container = get_node_or_null("VBoxContainer/HBoxContainer/ScrollContainer/CardListContainer")
var evolution_tree = get_node_or_null("VBoxContainer/HBoxContainer/EvolutionTree")
var detail_panel = get_node_or_null("VBoxContainer/HBoxContainer/DetailPanel")
var result_label = get_node_or_null("VBoxContainer/ResultLabel")

var selected_card: CardResource = null
var selected_target_id: String = ""
var _embedded_mode: bool = false

func _ready() -> void:
	# 连接关闭按钮
	var close_btn = get_node_or_null("VBoxContainer/TitleRow/CloseButton")
	if close_btn:
		close_btn.pressed.connect(_on_close)

	if _embedded_mode:
		_apply_embedded_layout()
	else:
		_refresh_card_list()

## 内嵌模式：隐藏 TitleRow + 左侧卡牌列表
func set_embedded_mode(p_embedded: bool) -> void:
	_embedded_mode = p_embedded
	if is_inside_tree():
		_apply_embedded_layout()

func _apply_embedded_layout() -> void:
	var title_row = get_node_or_null("VBoxContainer/TitleRow")
	if title_row:
		title_row.visible = false
	var scroll = get_node_or_null("VBoxContainer/HBoxContainer/ScrollContainer")
	if scroll:
		scroll.visible = false

## ─────────────────────────────────────────────
##  UI更新
## ─────────────────────────────────────────────

func _refresh_card_list() -> void:
	if card_list_container == null:
		return
	for child in card_list_container.get_children():
		child.queue_free()

	for id_raw in BlueprintManager.get_all_blueprint_ids():
		var card_id: String = str(id_raw)
		var card: CardResource = DefaultCards.get_card_by_id(card_id)
		if card == null:
			continue
		var item = _create_card_item(card)
		card_list_container.add_child(item)

func _create_card_item(card: CardResource) -> Control:
	var item = Button.new()
	item.text = card.display_name
	item.custom_minimum_size = Vector2(200, 40)

	var rank_info = card.get_military_rank()
	item.tooltip_text = "军衔：%s | 改造：%d/9" % [rank_info.name, card.mods.size()]

	item.pressed.connect(func(): _on_card_selected(card))
	return item

func _update_evolution_tree() -> void:
	if evolution_tree == null:
		return
	if not selected_card:
		evolution_tree.visible = false
		return

	evolution_tree.visible = true

	# 清空进化树
	for child in evolution_tree.get_children():
		child.queue_free()

	# 获取进化路径
	var targets = selected_card.get_evolution_targets()

	if targets.is_empty():
		var no_target_label = Label.new()
		no_target_label.text = "无可进化目标"
		evolution_tree.add_child(no_target_label)
		return

	# 创建进化树
	for target in targets:
		var target_node = _create_evolution_node(target)
		evolution_tree.add_child(target_node)

func _create_evolution_node(target: Dictionary) -> Control:
	var node = VBoxContainer.new()
	node.custom_minimum_size = Vector2(300, 80)

	var name_btn = Button.new()
	name_btn.text = target.name
	name_btn.custom_minimum_size = Vector2(280, 40)
	name_btn.pressed.connect(func(): _on_target_selected(target.target_id, target.name))

	var type_label = Label.new()
	type_label.text = "路径：%s | 阶段：E%d" % [target.path_type, target.stage]
	type_label.add_theme_color_override("font_color", Color.GRAY)

	var req_label = Label.new()
	var check_result = selected_card.check_evolution_requirements(target.target_id)
	if check_result.passed:
		req_label.text = "✓ 可进化"
		req_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		req_label.text = "✗ " + ", ".join(check_result.missing)
		req_label.add_theme_color_override("font_color", Color.RED)

	node.add_child(name_btn)
	node.add_child(type_label)
	node.add_child(req_label)

	return node

func _update_detail_panel() -> void:
	if detail_panel == null:
		return
	if not selected_card or selected_target_id.is_empty():
		detail_panel.visible = false
		return

	detail_panel.visible = true

	# 显示目标信息
	var target_card = DefaultCards.get_card_by_id(selected_target_id)
	if not target_card:
		return

	var info_text = "进化目标：%s\n" % target_card.display_name
	info_text += "─────────────────\n"
	info_text += "战力：%d | 时代：%s\n" % [target_card.power, target_card.era]
	info_text += "类型：%s | 武器：%s\n" % [target_card.combat_kind, target_card.weapon_type]
	info_text += "─────────────────\n"
	
	var info_label = detail_panel.get_node_or_null("InfoLabel")
	if info_label:
		info_label.text = info_text

	# 显示条件检查
	var check_result = selected_card.check_evolution_requirements(selected_target_id)
	var req_label = detail_panel.get_node_or_null("RequirementsLabel")
	if req_label:
		if check_result.passed:
			req_label.text = "✓ 所有条件满足"
			req_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			req_label.text = "未满足条件：\n" + "\n".join(check_result.missing)
			req_label.add_theme_color_override("font_color", Color.RED)

	# 显示改造保留信息
	var mod_label = detail_panel.get_node_or_null("PreservedModsLabel")
	if mod_label:
		mod_label.text = "改造保留：%d个改造将完整保留" % selected_card.mods.size()

	# 计算新属性
	var new_stats = selected_card.calculate_evolved_stats(selected_target_id)
	var stats_text = "进化后属性预览\n─────────────────\n"
	stats_text += "HP %d｜攻 %d/%d/%d｜防 %d/%d/%d\n" % [
			new_stats.get("max_hp", 0),
			new_stats.get("attack_light", 0),
			new_stats.get("attack_armor", 0),
			new_stats.get("attack_air", 0),
			new_stats.get("defense_light", 0),
			new_stats.get("defense_armor", 0),
			new_stats.get("defense_air", 0),
		]
	stats_text += "─────────────────\n"
	stats_text += "射程 %d｜攻速 %.1f｜移速 %d" % [
		new_stats.get("attack_range", 0),
		new_stats.get("attack_speed", 1.0),
		new_stats.get("move_speed", 0),
	]
	
	var stats_label = detail_panel.get_node_or_null("NewStatsLabel")
	if stats_label:
		stats_label.text = stats_text

	# 进化按钮
	var evolve_btn = detail_panel.get_node_or_null("EvolveButton")
	if evolve_btn:
		evolve_btn.disabled = not check_result.passed
		evolve_btn.pressed.disconnect_all()
		evolve_btn.pressed.connect(func(): _on_evolve_pressed())

## ─────────────────────────────────────────────
##  进化操作
## ─────────────────────────────────────────────

func _on_evolve_pressed() -> void:
	if not selected_card or selected_target_id.is_empty():
		return

	var result = BlueprintManager.evolve_card(selected_card, selected_target_id)

	if result.success:
		_show_result("进化成功！%s" % result.message)
		# 刷新UI
		selected_card = result.new_card
		_refresh_card_list()
		_update_evolution_tree()
	else:
		_show_result("进化失败：%s" % result.message)

## ─────────────────────────────────────────────
##  事件处理
## ─────────────────────────────────────────────

func _on_card_selected(card: CardResource) -> void:
	selected_card = card
	selected_target_id = ""
	_update_evolution_tree()
	detail_panel.visible = false

func _on_target_selected(target_id: String, target_name: String) -> void:
	selected_target_id = target_id
	_update_detail_panel()


## 供外部调用的接口
func set_selected_card(card: CardResource) -> void:
	selected_card = card
	selected_target_id = ""
	if has_node("VBoxContainer/HBoxContainer/EvolutionTree"):
		_update_evolution_tree()
	if has_node("VBoxContainer/HBoxContainer/DetailPanel"):
		_update_detail_panel()

func show_panel() -> void:
	visible = true
	if not _embedded_mode:
		_refresh_card_list()

func _on_close() -> void:
	closed.emit()

func _show_result(message: String) -> void:
	if result_label:
		result_label.text = message
		result_label.visible = true
		await get_tree().create_timer(3.0).timeout
		result_label.visible = false
