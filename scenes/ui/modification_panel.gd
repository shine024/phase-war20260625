extends Control
class_name ModificationPanel
## 改造面板（新系统）
## 显示军事技术改造模块
## 改造消耗：纳米材料 + 改造指南（根据稀有度）

signal closed

const IntelManualItems = preload("res://data/intel_manual_items.gd")
const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")

# UI 组件引用
@onready var card_list_container = get_node_or_null("VBoxContainer/HBoxContainer/ScrollContainer/CardListContainer")
@onready var mod_list_container = get_node_or_null("VBoxContainer/HBoxContainer/ModScrollContainer/ModListContainer")
@onready var card_info_panel = get_node_or_null("VBoxContainer/HBoxContainer/DetailPanel")
@onready var research_label = get_node_or_null("VBoxContainer/ResearchLabel")
@onready var result_label = get_node_or_null("VBoxContainer/ResultLabel")

var selected_card: CardResource = null
var selected_mod_id: String = ""
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

	var mod_count = card.mods.size()
	item.tooltip_text = "已安装改造：%d/9" % mod_count

	item.pressed.connect(func(): _on_card_selected(card))
	return item

func _refresh_mod_list() -> void:
	if not selected_card:
		return

	for child in mod_list_container.get_children():
		child.queue_free()

	# 获取可用改造
	var unit_type = selected_card.combat_kind
	var available_mods = ModificationRegistry.get_for_unit_type(unit_type)

	for mod_id in available_mods:
		var mod_data = ModificationRegistry.get_data(mod_id)
		var item = _create_mod_item(mod_id, mod_data)
		mod_list_container.add_child(item)

func _create_mod_item(mod_id: String, mod_data: Dictionary) -> Control:
	var item = Button.new()
	item.text = mod_data.get("name", mod_id)
	item.custom_minimum_size = Vector2(250, 40)

	# 显示详细信息
	var prototype = mod_data.get("prototype", "")
	var desc = mod_data.get("description", "")
	var rarity = mod_data.get("rarity", "common")
	item.tooltip_text = "%s\n%s\n稀有度：%s" % [prototype, desc, rarity]

	# 检查是否已安装
	var is_installed = _is_mod_installed(mod_id)
	var can_install = _can_install_mod(mod_id)

	if is_installed:
		item.disabled = true
		item.text += "（已安装）"
	elif not can_install:
		item.disabled = true
		item.text += "（冲突）"

	item.pressed.connect(func(): _on_mod_selected(mod_id, mod_data))
	return item

func _update_card_info() -> void:
	if card_info_panel == null:
		return
	if not selected_card:
		card_info_panel.visible = false
		return

	card_info_panel.visible = true

	var info_label = card_info_panel.get_node_or_null("InfoLabel")
	if info_label:
		var rank_info = selected_card.get_military_rank()
		info_label.text = "%s\n军衔：%s | 改造：%d/9" % [
			selected_card.display_name,
			rank_info.name,
			selected_card.mods.size()
		]

	# 显示已安装改造列表
	var installed_list = card_info_panel.get_node_or_null("InstalledList")
	if installed_list:
		_refresh_installed_list(installed_list)

	# 更新资源标签
	if research_label:
		var nano_amount = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS)
		var total_blueprints = 0
		if IntelItemBag:
			total_blueprints = IntelItemBag.get_total_count()
		research_label.text = "纳米：%d | 图纸总数：%d" % [nano_amount, total_blueprints]

func _refresh_installed_list(installed_list: Control) -> void:
	for child in installed_list.get_children():
		child.queue_free()

	for mod_entry in selected_card.mods:
		var mod_id = mod_entry.get("id", "") if mod_entry is Dictionary else ""
		var mod_data = ModificationRegistry.get_data(mod_id)

		var item = Label.new()
		item.text = "• %s" % mod_data.get("name", mod_id)
		installed_list.add_child(item)

## ─────────────────────────────────────────────
##  改造操作
## ─────────────────────────────────────────────

func _is_mod_installed(mod_id: String) -> bool:
	if not selected_card:
		return false

	for mod_entry in selected_card.mods:
		var entry_id = mod_entry.get("id", "") if mod_entry is Dictionary else ""
		if entry_id == mod_id:
			return true
	return false

func _can_install_mod(mod_id: String) -> bool:
	if not selected_card:
		return false

	var check_result = selected_card.can_install_modification(mod_id)
	return check_result.can_install

func _install_modification(mod_id: String) -> void:
	if not selected_card:
		return

	var result = BlueprintManager.install_modification(selected_card, mod_id)

	if result.success:
		_show_result("改造安装成功：%s" % result.message)
		_refresh_mod_list()
		_update_card_info()
	else:
		_show_result("安装失败：%s" % result.message)

## ─────────────────────────────────────────────
##  事件处理
## ─────────────────────────────────────────────

func _on_card_selected(card: CardResource) -> void:
	selected_card = card
	selected_mod_id = ""
	_refresh_mod_list()
	_update_card_info()

func _on_mod_selected(mod_id: String, mod_data: Dictionary) -> void:
	selected_mod_id = mod_id
	# 显示改造详情
	_show_mod_details(mod_data)

func _show_mod_details(mod_data: Dictionary) -> void:
	var details_panel = card_info_panel.get_node_or_null("ModDetailsPanel")
	if details_panel:
		details_panel.visible = true

		var name_label = details_panel.get_node_or_null("NameLabel")
		if name_label:
			name_label.text = mod_data.get("name", "")

		var proto_label = details_panel.get_node_or_null("PrototypeLabel")
		if proto_label:
			proto_label.text = "原型：%s" % mod_data.get("prototype", "")

		var desc_label = details_panel.get_node_or_null("DescLabel")
		if desc_label:
			desc_label.text = mod_data.get("description", "")

		var effects_label = details_panel.get_node_or_null("EffectsLabel")
		if effects_label:
			var effects = mod_data.get("effects", {})
			var effect_texts = []
			for key in effects.keys():
				effect_texts.append("%s：%s" % [key, str(effects[key])])
			effects_label.text = "效果：\n" + "\n".join(effect_texts)



		var install_btn = details_panel.get_node_or_null("InstallButton")
		if install_btn:
			# 计算消耗：纳米材料（卡牌战力50%）
			var base_power = selected_card.get_current_power() if selected_card else 100
			var nano_cost = int(base_power * 0.5)

			# 计算特定蓝图ID
			var blueprint_id = BlueprintDefinitions.get_mod_blueprint_id(selected_mod_id)
			var blueprint_name = BlueprintDefinitions.get_mod_blueprint_name(selected_mod_id)
			var has_blueprint = false
			if IntelItemBag:
				has_blueprint = IntelItemBag.has_item(blueprint_id)

			# 检查纳米材料
			var has_nano = true
			if BasicResourceManager:
				var nano_amount = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS)
				has_nano = nano_amount >= nano_cost

			# 更新按钮文本和状态
			if not has_blueprint:
				install_btn.text = "缺少图纸：%s" % blueprint_name
				install_btn.disabled = true
			elif not has_nano:
				install_btn.text = "纳米不足（需要 %d）" % nano_cost
				install_btn.disabled = true
			else:
				install_btn.text = "安装（消耗：%d纳米 + %s）" % [nano_cost, blueprint_name]
				install_btn.disabled = false

			# v5.0: Godot 4 正确的信号断开方式：存储并移除所有现有连接
			var connections: Array = install_btn.pressed.get_connections()
			for conn in connections:
				if conn.callable.is_valid():
					install_btn.pressed.disconnect(conn.callable)
			var install_callable = func(): _install_modification(selected_mod_id)
			install_btn.pressed.connect(install_callable)


## 供外部调用的接口
func set_selected_card(card: CardResource) -> void:
	selected_card = card
	selected_mod_id = ""
	if has_node("VBoxContainer/HBoxContainer/DetailPanel"):
		_update_card_info()
	if has_node("VBoxContainer/HBoxContainer/ModScrollContainer"):
		_refresh_mod_list()

func show_panel() -> void:
	visible = true
	_refresh_card_list()

func _on_close() -> void:
	closed.emit()

func _show_result(message: String) -> void:
	if result_label:
		result_label.text = message
		result_label.visible = true
		await get_tree().create_timer(3.0).timeout
		result_label.visible = false
