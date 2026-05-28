extends Control

## 势力商店面板

signal panel_closed
signal item_purchased(item_id: String, item_type: int)

var current_faction_id: String = ""
var store_items: Array = []

@onready var faction_name_label = $Panel/VBoxContainer/Header/FactionNameLabel
@onready var faction_level_label = $Panel/VBoxContainer/Header/FactionLevelLabel
@onready var reputation_progress = $Panel/VBoxContainer/Header/ReputationProgress
@onready var reputation_label = $Panel/VBoxContainer/Header/ReputationLabel
@onready var items_scroll = $Panel/VBoxContainer/Body/ItemsScroll
@onready var items_list = $Panel/VBoxContainer/Body/ItemsScroll/ItemsList
@onready var close_button = $Panel/VBoxContainer/Footer/CloseButton

func _ready():
	close_button.pressed.connect(_on_close_pressed)

## 设置要显示的势力
func set_faction(faction_id: String):
	current_faction_id = faction_id
	_update_header()
	_fetch_store_items()
	_display_items()

## 更新头部信息
func _update_header():
	if current_faction_id.is_empty():
		return

	var fsm = get_node_or_null("/root/FactionSystemManager")
	if not fsm:
		return

	# 显示"全部势力"而不是单个势力
	faction_name_label.text = "全部势力商店"
	faction_level_label.text = "所有势力商品"
	reputation_label.text = "声望 5000+ / 全可购买"

	# 更新进度条（显示满进度）
	reputation_progress.value = 100.0

## 获取商店物品（获取所有势力的商品）
func _fetch_store_items():
	var fsm = get_node_or_null("/root/FactionSystemManager")
	if not fsm:
		store_items = []
		return

	# 获取所有势力的商品
	var all_items = []
	var all_factions = fsm.get_all_factions_info() if fsm.has_method("get_all_factions_info") else []

	print("[FactionStorePanel] 开始获取所有势力的商品，势力数量: %d" % all_factions.size())

	for faction_info in all_factions:
		if faction_info is Dictionary:
			var faction_id = faction_info.get("id", "")
			if not faction_id.is_empty():
				var faction_items = fsm.get_faction_store_items(faction_id)
				# 为每个商品添加所属势力信息（使用元数据）
				for item in faction_items:
					item.set_meta("faction_id", faction_id)
					item.set_meta("faction_name", faction_info.get("name", ""))
				all_items.append_array(faction_items)

	store_items = all_items
	print("[FactionStorePanel] 商店加载完成，总商品数: %d" % store_items.size())

## 显示物品列表
func _display_items():
	# 清空列表
	for child in items_list.get_children():
		child.queue_free()

	if store_items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "暂无可购买物品"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.modulate = Color(0.6, 0.6, 0.6)
		items_list.add_child(empty_label)
		return

	# 显示每个物品
	for item in store_items:
		var item_ui = _create_store_item_ui(item)
		items_list.add_child(item_ui)

## 创建单个物品UI
func _create_store_item_ui(item: Variant) -> Control:
	var fsm = get_node_or_null("/root/FactionSystemManager")
	# 使用商品所属的势力ID进行检查
	var item_faction_id = current_faction_id
	if item.has_meta("faction_id"):
		item_faction_id = item.get_meta("faction_id")
	var can_purchase = fsm.can_purchase_item(item_faction_id, item) if fsm else {"ok": false}
	var can_buy = can_purchase.get("ok", false)

	var panel = Panel.new()
	panel.add_theme_stylebox_override("panel", _get_item_style(can_buy))

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	# 顶部：名称 + 价格
	var top_hbox = HBoxContainer.new()
	vbox.add_child(top_hbox)

	var name_label = Label.new()
	# 在商品名称前显示所属势力
	var faction_prefix = ""
	if item.has_meta("faction_name"):
		faction_prefix = item.get_meta("faction_name")
	if not faction_prefix.is_empty():
		name_label.text = "[%s] %s" % [faction_prefix, item.display_name]
	else:
		name_label.text = item.display_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(name_label)

	var price_label = Label.new()
	price_label.text = "%d 声望" % item.reputation_cost
	price_label.add_theme_font_size_override("font_size", 14)
	price_label.modulate = Color(0.3, 0.8, 0.3) if can_buy else Color(0.8, 0.3, 0.3)
	top_hbox.add_child(price_label)

	# 描述
	var desc_label = Label.new()
	desc_label.text = item.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(desc_label)

		# 获取并显示物品详细属性
		var details_text = _get_item_details_text(item)
		if not details_text.is_empty():
			var details_label = Label.new()
			details_label.text = details_text
			details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			details_label.add_theme_font_size_override("font_size", 11)
			details_label.modulate = Color(0.5, 0.8, 1.0)
			vbox.add_child(details_label)

		# 等级要求
	if item.required_level > 1:
		var level_label = Label.new()
		level_label.text = "需要等级: %d" % item.required_level
		level_label.add_theme_font_size_override("font_size", 11)
		level_label.modulate = Color(0.6, 0.7, 1.0)
		vbox.add_child(level_label)

	# 购买按钮
	var buy_button = Button.new()
	buy_button.text = "购买"
	buy_button.disabled = not can_buy
	buy_button.pressed.connect(_on_buy_button_pressed.bind(item))
	vbox.add_child(buy_button)

	# 不可购买原因提示
	if not can_buy:
		var reason_label = Label.new()
		var reason = can_purchase.get("reason", "")
		match reason:
			"level_too_low":
				reason_label.text = "声望等级不足"
			"reputation_insufficient":
				reason_label.text = "声望点数不足"
			"out_of_stock":
				reason_label.text = "已售罄"
			_:
				reason_label.text = "无法购买"
		reason_label.add_theme_font_size_override("font_size", 11)
		reason_label.modulate = Color(0.8, 0.3, 0.3)
		vbox.add_child(reason_label)

	return panel

## 获取物品面板样式
func _get_item_style(can_buy: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8

	if can_buy:
		style.bg_color = Color(0.15, 0.2, 0.25, 0.9)
		style.border_color = Color(0.3, 0.6, 0.8)
	else:
		style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
		style.border_color = Color(0.3, 0.3, 0.3)

	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5

	return style

## 购买按钮按下
func _on_buy_button_pressed(item: Variant):
	var fsm = get_node_or_null("/root/FactionSystemManager")
	if not fsm:
		return

	# 使用商品所属的势力ID进行购买
	var item_faction_id = current_faction_id
	if item.has_meta("faction_id"):
		item_faction_id = item.get_meta("faction_id")

	var result = fsm.purchase_item(item_faction_id, item)

	if result.get("ok", false):
		print("[FactionStorePanel] 购买成功: ", item.display_name)
		item_purchased.emit(item.item_id, item.item_type)

		# 刷新显示
		_update_header()
		_fetch_store_items()
		_display_items()
	else:
		print("[FactionStorePanel] 购买失败: ", result)

## 关闭面板
func _on_close_pressed():
	panel_closed.emit()
	queue_free()

## 获取物品详细属性文本
func _get_item_details_text(item: Variant) -> String:
	var details: Array[String] = []

	# 根据物品类型获取不同信息
	if item.item_type == 0:  # CARD
		const DefaultCardsData = preload("res://data/default_cards.gd")
		const GC = preload("res://resources/game_constants.gd")
		var card = DefaultCardsData.get_card_by_id(item.item_id)
		if card:
			# 第一行：卡牌类型、稀有度、能量消耗
			var type_parts: Array[String] = []

			# 添加类型信息
			match card.card_type:
				GC.CardType.COMBAT_UNIT:
					type_parts.append("载具卡")
				GC.CardType.COMBAT_UNIT:
					type_parts.append("武器卡")
				GC.CardType.ENERGY:
					type_parts.append("能量卡")
				GC.CardType.LAW:
					type_parts.append("法则卡")

			# 添加稀有度信息
			if not card.rarity.is_empty():
				var rarity_name = _get_rarity_name(card.rarity)
				type_parts.append(rarity_name)

			# 添加能量消耗
			if card.energy_cost > 0:
				type_parts.append("消耗 %d⚡" % card.energy_cost)

			if type_parts.size() > 0:
				details.append("  |  ".join(type_parts))

			# 第二行：基础数值属性
			var base_attrs: Array[String] = []
			match card.card_type:
				GC.CardType.COMBAT_UNIT:
					if card.weight_capacity > 0:
						base_attrs.append("承载 %d 重量" % card.weight_capacity)
					if card.max_weapons > 0:
						base_attrs.append("武器槽 %d" % card.max_weapons)
				GC.CardType.COMBAT_UNIT:
					if card.weight > 0:
						base_attrs.append("重量 %d" % card.weight)
				GC.CardType.ENERGY:
					if card.energy_cost > 0:
						base_attrs.append("能量消耗 %d" % card.energy_cost)
					if card.energy_grant > 0:
						base_attrs.append("能量提供 %.0f⚡" % card.energy_grant)
			GC.CardType.COMBAT_UNIT:
				if card.weight_capacity > 0:
					base_attrs.append("承载 %d 重量" % card.weight_capacity)
			GC.CardType.LAW:
					if card.energy_cost > 0:
						base_attrs.append("能量消耗 %d⚡" % card.energy_cost)

			if base_attrs.size() > 0:
				details.append("  |  ".join(base_attrs))

			# 第三行：战斗属性（从 summary_line 解析）
			if not card.summary_line.is_empty():
				details.append(String(card.summary_line))

			# 第四行：描述文字
			if not card.description.is_empty():
				details.append(String(card.description))

	elif item.item_type == 1:  # MATERIAL
		details.append("类型: 材料")
		details.append("使用: 点击背包中的材料图标查看详情")

	elif item.item_type == 2:  # CARD_BUNDLE（原 BLUEPRINT_FRAGMENT）
		details.append("类型: 蓝图数据")
		details.append("用途: 在蓝图工坊中解锁卡牌升级")

	return "\n".join(details)

## 获取稀有度名称
func _get_rarity_name(rarity: String) -> String:
	match rarity:
		"common": return "普通"
		"uncommon": return "优秀"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary": return "传说"
		_: return "未知"