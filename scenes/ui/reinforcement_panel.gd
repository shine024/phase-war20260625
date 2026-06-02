extends Control
class_name ReinforcementPanel
## 强化面板（新系统）
## 显示军事称号而非数字等级

signal closed

# UI 组件引用
@onready var card_list_container = $VBoxContainer/HBoxContainer/ScrollContainer/CardListContainer
@onready var card_detail_panel = $VBoxContainer/HBoxContainer/DetailPanel
@onready var reinforce_button = $VBoxContainer/HBoxContainer/DetailPanel/ReinforceButton
@onready var nano_label = $VBoxContainer/NanoLabel
@onready var result_label = $VBoxContainer/ResultLabel

var selected_card: CardResource = null
var _embedded_mode: bool = false

func _ready() -> void:
	# 连接关闭按钮
	var close_btn = get_node_or_null("VBoxContainer/TitleRow/CloseButton")
	if close_btn:
		close_btn.pressed.connect(_on_close)

	if _embedded_mode:
		_apply_embedded_layout()
	else:
		# 刷新卡牌列表
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
	# 清空列表
	for child in card_list_container.get_children():
		child.queue_free()

	# 获取所有蓝图卡牌
	var DefaultCards = preload("res://data/default_cards.gd")
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

	# 获取当前军衔
	var rank_info = card.get_military_rank()
	var level = card.enhance_level
	item.tooltip_text = "Lv%d %s | 战力：%d" % [level, rank_info.name, card.get_current_power()]

	item.pressed.connect(func(): _on_card_selected(card))
	return item

func _update_detail_panel() -> void:
	if not selected_card:
		card_detail_panel.visible = false
		return

	card_detail_panel.visible = true

	# 获取军衔信息
	var rank_info = selected_card.get_military_rank()
	var next_rank_info = selected_card.get_next_rank_info()

	# 更新UI文本
	_update_card_info()
	_update_rank_info(rank_info, next_rank_info)
	_update_reinforce_button(rank_info)

	# 更新资源标签
	var nano_amount = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS)
	nano_label.text = "纳米材料：%d" % nano_amount

func _update_card_info() -> void:
	var info_label = card_detail_panel.get_node_or_null("InfoLabel")
	if info_label:
		var current_power = selected_card.get_current_power()
		info_label.text = "%s\n战力：%d | 强化等级：%d" % [
			selected_card.display_name,
			current_power,
			selected_card.enhance_level
		]

func _update_rank_info(rank_info: Dictionary, next_rank_info: Dictionary) -> void:
	var rank_label = card_detail_panel.get_node_or_null("RankLabel")
	if rank_label:
		rank_label.text = "当前军衔：%s" % rank_info.name

	var desc_label = card_detail_panel.get_node_or_null("RankDescLabel")
	if desc_label:
		desc_label.text = rank_info.desc

	var progress_bar = card_detail_panel.get_node_or_null("RankProgressBar")
	if progress_bar and progress_bar is ProgressBar:
		progress_bar.value = selected_card.get_rank_progress() * 100

	# 显示下一级信息
	if not next_rank_info.is_empty():
		var next_label = card_detail_panel.get_node_or_null("NextRankLabel")
		if next_label:
			var progress_pct = int(next_rank_info.progress * 100)
			next_label.text = "下一级：%s (%d%%)" % [next_rank_info.next_name, progress_pct]

func _update_reinforce_button(rank_info: Dictionary) -> void:
	if not reinforce_button:
		return

	var current_level = selected_card.enhance_level
	if current_level >= 10:
		reinforce_button.disabled = true
		reinforce_button.text = "已达最高等级"
		return

	reinforce_button.disabled = false

	# 计算消耗
	var next_level = current_level + 1
	var cost_multiplier = UnifiedRankSystem.get_cost_multiplier(next_level)
	var nano_cost = int(selected_card.power * cost_multiplier)

	reinforce_button.text = "晋升（消耗：%d纳米）" % nano_cost

## ─────────────────────────────────────────────
##  事件处理
## ─────────────────────────────────────────────

func _on_card_selected(card: CardResource) -> void:
	selected_card = card
	_update_detail_panel()

func _on_reinforce_pressed() -> void:
	if not selected_card:
		return

	var current_level = selected_card.enhance_level
	if current_level >= 10:
		_show_result("已达最高等级")
		return

	var next_level = current_level + 1
	var result = BlueprintManager.apply_reinforcement(selected_card, next_level)

	if result.success:
		_show_result("强化成功！%s → %s" % [result.message, selected_card.get_military_rank().name])
		_update_detail_panel()
	else:
		_show_result("强化失败：%s" % result.message)


## 供外部调用的接口
func set_selected_card(card: CardResource) -> void:
	selected_card = card
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
		# 3秒后自动隐藏
		await get_tree().create_timer(3.0).timeout
		result_label.visible = false
