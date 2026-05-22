extends Control
class_name FactionPanel
## 势力系统UI面板
## 
## 功能：
## - 显示7个势力的信息（名称、描述、声望等级）
## - 显示势力升级进度
## - 显示势力控制的关卡数量
## - 显示势力商店库存预览
## - 实时更新势力声望变化

const GC = preload("res://resources/game_constants.gd")

signal closed

# UI 组件引用
@onready var faction_scroll = $VBoxContainer/HBoxContainer/ScrollContainer/FactionListContainer
@onready var faction_detail = $VBoxContainer/HBoxContainer/DetailPanel

# 数据
var selected_faction_id: String = ""
var faction_items: Array = []

func _ready() -> void:
	# 连接关闭按钮
	var close_btn = get_node_or_null("VBoxContainer/TitleRow/CloseButton")
	if close_btn:
		close_btn.pressed.connect(_on_close)
	# 连接信号
	ManagerLazyLoader.ensure_loaded("faction")
	var faction_mgr = get_node_or_null("/root/FactionSystemManager")
	if faction_mgr:
		faction_mgr.faction_reputation_changed.connect(_on_faction_reputation_changed)
		faction_mgr.faction_level_up.connect(_on_faction_level_up)
		faction_mgr.faction_store_updated.connect(_on_faction_store_updated)
	
	# 初始化势力列表
	_init_faction_list()
	
	# 选择第一个势力
	if faction_items.size() > 0:
		_on_faction_item_selected(faction_items[0]["id"])

func _init_faction_list() -> void:
	"""初始化势力列表"""
	var faction_mgr = get_node_or_null("/root/FactionSystemManager")
	if not faction_scroll or not faction_mgr:
		return
	
	# 清空现有列表
	for child in faction_scroll.get_children():
		child.queue_free()
	
	faction_items.clear()
	
	# 获取所有势力信息
	var all_factions = faction_mgr.get_all_factions_info()
	
	for faction_info in all_factions:
		var faction_id = faction_info.get("id", "")
		if faction_id.is_empty():
			continue
		
		# 创建势力项目按钮
		var item_button = Button.new()
		var faction_name = faction_info.get("name", "")
		var level = faction_info.get("level", 1)
		item_button.text = "%s (Lv.%d)" % [faction_name, level]
		item_button.custom_minimum_size = Vector2(200, 50)
		var logo: Texture2D = UiAssetLoader.faction_logo_128(faction_id)
		if logo != null:
			item_button.icon = logo
			item_button.expand_icon = true
			item_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_button.pressed.connect(_on_faction_item_selected.bindv([faction_id]))
		
		faction_scroll.add_child(item_button)
		faction_items.append({"id": faction_id, "button": item_button})

func _on_faction_item_selected(faction_id: String) -> void:
	"""势力项目被选中"""
	selected_faction_id = faction_id
	_update_faction_detail()

func _update_faction_detail() -> void:
	"""更新势力详细信息"""
	var faction_mgr = get_node_or_null("/root/FactionSystemManager")
	if not faction_detail or selected_faction_id.is_empty() or not faction_mgr:
		return
	
	# 清空现有内容
	for child in faction_detail.get_children():
		child.queue_free()
	
	var faction_info = faction_mgr.get_faction_info(selected_faction_id)
	
	# 势力名称
	var name_label = Label.new()
	name_label.text = faction_info.get("name", "")
	name_label.add_theme_font_size_override("font_size", 24)
	faction_detail.add_child(name_label)
	
	# 势力描述
	var desc_label = Label.new()
	desc_label.text = faction_info.get("description", "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(0, 60)
	faction_detail.add_child(desc_label)
	
	# 势力等级和声望
	var reputation = faction_info.get("reputation", 0)
	var level = faction_info.get("level", 1)
	var level_progress = faction_info.get("level_progress", {})
	
	var level_label = Label.new()
	level_label.text = "等级：%d" % level
	faction_detail.add_child(level_label)
	
	var rep_label = Label.new()
	rep_label.text = "声望：%d" % reputation
	faction_detail.add_child(rep_label)
	
	# 升级进度条
	if level < 10:
		var progress_label = Label.new()
		var progress = level_progress.get("progress", 0.0)
		var current = level_progress.get("current", 0)
		var needed = level_progress.get("needed", 1)
		progress_label.text = "升级进度：%.0f%% (%d/%d)" % [progress * 100, current, needed]
		faction_detail.add_child(progress_label)
		
		var progress_bar = ProgressBar.new()
		progress_bar.value = progress * 100
		progress_bar.custom_minimum_size = Vector2(0, 30)
		faction_detail.add_child(progress_bar)
	else:
		var max_label = Label.new()
		max_label.text = "[color=yellow]已达最高等级[/color]"
		faction_detail.add_child(max_label)
	
	# 控制的关卡数量
	var controlled_levels = faction_info.get("controlled_levels", [])
	var levels_label = Label.new()
	levels_label.text = "控制关卡数：%d" % int(controlled_levels.size())
	faction_detail.add_child(levels_label)
	
	# 显示商店库存预览
	var store_label = Label.new()
	store_label.text = "势力商店库存"
	store_label.add_theme_font_size_override("font_size", 14)
	faction_detail.add_child(store_label)
	
	var store_inventory = faction_info.get("store_inventory", [])
	if store_inventory.size() > 0:
		var store_preview = Label.new()
		var store_text = ""
		for card_id in store_inventory:
			if not store_text.is_empty():
				store_text += ", "
			var default_cards = preload("res://data/default_cards.gd")
			var card_data = default_cards.get_card_by_id(card_id) if default_cards else null
			var card_name = card_data.display_name if card_data else String(card_id)
			store_text += card_name
		store_preview.text = store_text
		store_preview.autowrap_mode = TextServer.AUTOWRAP_WORD
		store_preview.custom_minimum_size = Vector2(0, 40)
		faction_detail.add_child(store_preview)
	else:
		var empty_label = Label.new()
		empty_label.text = "暂无库存"
		faction_detail.add_child(empty_label)

func _on_faction_reputation_changed(faction_id: String, delta: int, new_value: int) -> void:
	"""势力声望变化回调"""
	if faction_id == selected_faction_id:
		_update_faction_detail()
	
	# 更新列表中的等级显示
	_update_faction_list_display(faction_id)

func _on_faction_level_up(faction_id: String, new_level: int) -> void:
	"""势力升级回调"""
	if faction_id == selected_faction_id:
		_update_faction_detail()
	
	_update_faction_list_display(faction_id)

func _on_faction_store_updated(faction_id: String) -> void:
	"""势力商店更新回调"""
	if faction_id == selected_faction_id:
		_update_faction_detail()

func _update_faction_list_display(faction_id: String) -> void:
	"""更新列表中的势力显示"""
	var faction_mgr = get_node_or_null("/root/FactionSystemManager")
	if not faction_mgr:
		return
	
	for item in faction_items:
		if item["id"] == faction_id:
			var faction_info = faction_mgr.get_faction_info(faction_id)
			var faction_name = faction_info.get("name", "")
			var level = faction_info.get("level", 1)
			item["button"].text = "%s (Lv.%d)" % [faction_name, level]

func _on_close() -> void:
	closed.emit()
