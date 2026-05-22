extends PanelContainer
## 掉落物品背包面板 - 显示所有类型的掉落物品

signal closed

const DefaultCardsData = preload("res://data/default_cards.gd")
const DropTables = preload("res://resources/drop_tables.gd")
const StarConfig = preload("res://data/blueprint_star_config.gd")

## UI引用
@onready var _tabs_container: TabContainer = $VBoxOuter/TabsContainer
@onready var _all_items_grid: GridContainer = $VBoxOuter/TabsContainer/AllItems/ItemsGrid
@onready var _materials_grid: GridContainer = $VBoxOuter/TabsContainer/Materials/MaterialsGrid
@onready var _blueprints_grid: GridContainer = $VBoxOuter/TabsContainer/Blueprints/BlueprintsGrid
@onready var _lore_grid: GridContainer = $VBoxOuter/TabsContainer/Lore/LoreGrid

## 数据
var _all_drops: Array = []  # 存储所有掉落物品

func _ready() -> void:
	# 连接关闭按钮
	var close_btn = get_node_or_null("VBoxOuter/TitleRow/CloseButton")
	if close_btn:
		close_btn.pressed.connect(_on_close)

	# 连接信号更新
	if SignalBus:
		SignalBus.backpack_changed.connect(_refresh_all_displays)

	# 初始化显示
	_refresh_all_displays()

## 刷新所有显示
func _refresh_all_displays() -> void:
	_refresh_materials()
	_refresh_blueprints()
	_refresh_lore()
	_refresh_all_items()

## 刷新素材显示
func _refresh_materials() -> void:
	if _materials_grid == null:
		return

	# 清空现有内容
	for child in _materials_grid.get_children():
		child.queue_free()

	# 获取素材数据
	if not BasicResourceManager or not BasicResourceManager.has_method("get_all_totals"):
		return

	var totals: Dictionary = BasicResourceManager.get_all_totals()
	for item_id in totals.keys():
		var amount: int = int(totals[item_id])
		if amount > 0:
			_add_material_item(_materials_grid, item_id, amount)

## 刷新蓝图显示
func _refresh_blueprints() -> void:
	if _blueprints_grid == null:
		return

	# 清空现有内容
	for child in _blueprints_grid.get_children():
		child.queue_free()

	if BlueprintManager == null:
		return

	# 获取所有已解锁的卡牌ID
	var unlocked_ids: Array = BlueprintManager.get_unlocked_blueprint_ids() if BlueprintManager.has_method("get_unlocked_blueprint_ids") else []

	# 为每个有蓝图的卡牌创建显示项
	for card_id in unlocked_ids:
		var copy_count: int = BlueprintManager.get_blueprint_copies(card_id) if BlueprintManager.has_method("get_blueprint_copies") else 0
		if copy_count > 0:
			_add_blueprint_item(_blueprints_grid, card_id, copy_count)

## 刷新情报显示
func _refresh_lore() -> void:
	if _lore_grid == null:
		return

	# 清空现有内容
	for child in _lore_grid.get_children():
		child.queue_free()

	# 获取情报管理器
	var lore_manager: Node = get_node_or_null("/root/LoreManager")
	if lore_manager == null:
		_show_empty_lore(_lore_grid, "情报系统未初始化")
		return

	# 获取已解锁的情报
	var unlocked_lore: Array = []
	if lore_manager.has_method("get_unlocked_lore"):
		unlocked_lore = lore_manager.get_unlocked_lore()

	if unlocked_lore.is_empty():
		_show_empty_lore(_lore_grid, "暂无已解锁情报")
		return

	# 显示情报列表
	for lore_data in unlocked_lore:
		_add_lore_item(_lore_grid, lore_data)

## 显示空情报提示
func _show_empty_lore(grid: GridContainer, message: String) -> void:
	var empty_label = Label.new()
	empty_label.text = message
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.7))
	empty_label.add_theme_font_size_override("font_size", 13)
	grid.add_child(empty_label)

## 添加情报物品项
func _add_lore_item(grid: GridContainer, lore_data: Dictionary) -> void:
	var item_container = PanelContainer.new()
	item_container.custom_minimum_size = Vector2(200, 100)

	var vbox = VBoxContainer.new()
	item_container.add_child(vbox)

	# 情报名称
	var name_label = Label.new()
	name_label.text = lore_data.get("name", "未知情报")
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5, 1.0))
	vbox.add_child(name_label)

	# 分类标签
	var category_label = Label.new()
	var category_text = _get_category_display_name(lore_data.get("category", ""))
	category_label.text = "[" + category_text + "]"
	category_label.add_theme_font_size_override("font_size", 10)
	category_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9, 0.8))
	vbox.add_child(category_label)

	# 描述
	var desc_label = Label.new()
	desc_label.text = lore_data.get("description", "")
	desc_label.autowrap_mode = TextServer.AUTOWORD
	desc_label.custom_minimum_size = Vector2(180, 0)
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.9))
	vbox.add_child(desc_label)

	grid.add_child(item_container)

## 获取分类显示名称
func _get_category_display_name(category: String) -> String:
	match category:
		"tactics": return "战术"
		"technology": return "技术"
		"history": return "历史"
		_: return category

## 刷新所有物品显示
func _refresh_all_items() -> void:
	if _all_items_grid == null:
		return

	# 清空现有内容
	for child in _all_items_grid.get_children():
		child.queue_free()

	# 合并显示所有类型的物品
	# 1. 添加素材
	if BasicResourceManager and BasicResourceManager.has_method("get_all_totals"):
		var totals: Dictionary = BasicResourceManager.get_all_totals()
		for item_id in totals.keys():
			var amount: int = int(totals[item_id])
			if amount > 0:
				_add_material_item(_all_items_grid, item_id, amount)

	# 2. 添加蓝图
	if BlueprintManager != null and BlueprintManager.has_method("get_unlocked_blueprint_ids"):
		var unlocked_ids: Array = BlueprintManager.get_unlocked_blueprint_ids()
		for card_id in unlocked_ids:
			var copy_count: int = BlueprintManager.get_blueprint_copies(card_id)
			if copy_count > 0:
				_add_blueprint_item(_all_items_grid, card_id, copy_count)

	# 3. 添加情报
	var lore_manager: Node = get_node_or_null("/root/LoreManager")
	if lore_manager != null and lore_manager.has_method("get_unlocked_lore"):
		var unlocked_lore: Array = lore_manager.get_unlocked_lore()
		if unlocked_lore.size() > 0:
			for lore_data in unlocked_lore:
				_add_lore_item_compact(_all_items_grid, lore_data)

	# 如果没有任何物品，显示提示
	if _all_items_grid.get_child_count() == 0:
		_show_empty_items(_all_items_grid)

## 显示空物品提示
func _show_empty_items(grid: GridContainer) -> void:
	var empty_label = Label.new()
	empty_label.text = "暂无任何掉落物品\n通过战斗获得素材、蓝图和情报"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.7))
	empty_label.add_theme_font_size_override("font_size", 12)
	grid.add_child(empty_label)

## 添加情报物品项（紧凑版，用于综合显示）
func _add_lore_item_compact(grid: GridContainer, lore_data: Dictionary) -> void:
	var item_container = PanelContainer.new()
	item_container.custom_minimum_size = Vector2(120, 80)

	var vbox = VBoxContainer.new()
	item_container.add_child(vbox)

	# 情报图标（用emoji代替）
	var icon_label = Label.new()
	icon_label.text = "📜"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(icon_label)

	# 情报名称
	var name_label = Label.new()
	name_label.text = lore_data.get("name", "未知情报")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWORD
	name_label.custom_minimum_size = Vector2(100, 0)
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5, 1.0))
	vbox.add_child(name_label)

	grid.add_child(item_container)

## 添加素材物品项
func _add_material_item(grid: GridContainer, item_id: String, amount: int) -> void:
	var item_container = PanelContainer.new()
	item_container.custom_minimum_size = Vector2(80, 80)

	var vbox = VBoxContainer.new()
	item_container.add_child(vbox)

	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_RATIO
	vbox.add_child(icon)

	var label = Label.new()
	label.text = _get_material_display_name(item_id) + "\n×" + str(amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	grid.add_child(item_container)

## 添加蓝图项
func _add_blueprint_item(grid: GridContainer, card_id: String, count: int) -> void:
	var item_container = PanelContainer.new()
	item_container.custom_minimum_size = Vector2(80, 80)

	var vbox = VBoxContainer.new()
	item_container.add_child(vbox)

	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_RATIO
	vbox.add_child(icon)

	var card_name = _get_blueprint_fragment_display_name(card_id)

	var label = Label.new()
	label.text = "%s\n×%d" % [card_name, count]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	# 星级进度条（与蓝图库一致：按累计副本换算的星级）
	if BlueprintManager and BlueprintManager.has_method("get_star_progress"):
		var star_progress = ProgressBar.new()
		var sp: Dictionary = BlueprintManager.get_star_progress(card_id)
		var current_star: int = int(sp.get("current_star", 0))
		var max_star: int = StarConfig.MAX_STAR_LEVEL
		var disp_star: int = mini(current_star, max_star)
		star_progress.max_value = max_star
		star_progress.value = disp_star
		star_progress.step = 1.0
		star_progress.show_percentage = false
		star_progress.custom_minimum_size = Vector2(60, 8)
		star_progress.add_theme_color_override("fill", Color(1, 0.9, 0, 1))
		star_progress.add_theme_color_override("background", Color(0.2, 0.2, 0.2, 0.5))
		star_progress.tooltip_text = "星级 %d/%d" % [disp_star, max_star]
		vbox.add_child(star_progress)

	grid.add_child(item_container)

## 获取卡牌掉落显示名称（与 drop_tables CARD_DATA 一致）
func _get_blueprint_fragment_display_name(card_id: String) -> String:
	var entry = DropTables.DropEntry.new(card_id, DropTables.DropType.CARD_DATA)
	return DropTables.new().get_drop_display_name(entry)

## 获取素材显示名称
func _get_material_display_name(material_id: String) -> String:
	match material_id:
		"nano_materials": return "纳米材料"
		"alloy": return "合金"
		"crystal": return "晶体"
		_: return material_id

## 关闭面板
func _on_close() -> void:
	closed.emit()
	queue_free()
