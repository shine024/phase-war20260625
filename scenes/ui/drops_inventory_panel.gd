extends PanelContainer
## 掉落物品背包面板 - 显示所有类型的掉落物品

signal closed

const UiAssetLoaderClass = preload("res://scripts/ui_asset_loader.gd")
const DefaultCardsData = preload("res://data/default_cards.gd")
const DropTables = preload("res://resources/drop_tables.gd")
const StarConfig = preload("res://data/blueprint_star_config.gd")
const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const PanelChrome = preload("res://scenes/ui/components/panel_chrome.gd")

## 资源图标映射（v7.x 视觉审查：原 TextureRect 无贴图=灰占位；AI 生成 res_* 系列）
const MATERIAL_ICONS := {
	"nano_materials": "res_nano", "basic_nano": "res_nano",
	"alloy": "res_alloy", "crystal": "res_crystal",
	"energy_block": "res_energy", "research_points": "res_research",
	"permit_steel": "res_permit", "permit_flame": "res_permit",
	"permit_thunder": "res_permit", "permit_void": "res_permit",
}
## 许可按法则家族着色（同一张证卡图标 tint）
const PERMIT_TINT := {
	"permit_steel": Color(0.55, 0.62, 0.72),
	"permit_flame": Color(0.9, 0.6, 0.1),
	"permit_thunder": Color(0.024, 0.714, 0.831),
	"permit_void": Color(0.653, 0.546, 0.980),
}

## UI引用
@onready var _tabs_container: TabContainer = $VBoxOuter/TabsContainer
@onready var _all_items_grid: GridContainer = $VBoxOuter/TabsContainer/AllItems/ScrollContainer/ItemsGrid
@onready var _materials_grid: GridContainer = $VBoxOuter/TabsContainer/Materials/ScrollContainer/MaterialsGrid
@onready var _blueprints_grid: GridContainer = $VBoxOuter/TabsContainer/Blueprints/ScrollContainer/BlueprintsGrid
@onready var _lore_grid: GridContainer = $VBoxOuter/TabsContainer/Lore/ScrollContainer/LoreGrid

## 数据
var _all_drops: Array = []  # 存储所有掉落物品
var _drop_tables: DropTables = null  # 缓存实例
# v9 perf：隐藏期间的 backpack_changed 置脏（战后/拆解触发的 4 网格全量重建是纯浪费），
# 重新显示时补刷一次
var _display_dirty: bool = false

func _ready() -> void:
	# v7.x 面板统一：SMALL 档 + 橙色签名框架 + PanelChrome 标题栏（右上 ✕ 关闭）
	custom_minimum_size = DT.PANEL_SIZE_SMALL
	var accent := DT.get_panel_accent("drops")
	add_theme_stylebox_override("panel", PanelStyles.make_panel_frame(accent))
	var chrome = PanelChrome.attach_to($VBoxOuter, "掉落物品", accent, "DROPS")
	chrome.closed.connect(_on_close)

	# 连接信号更新（v9 perf：隐藏时置脏，可见时才重建）
	if SignalBus:
		SignalBus.backpack_changed.connect(_on_backpack_changed)
	visibility_changed.connect(_on_visibility_refresh)

	# 初始化显示
	_refresh_all_displays()

## v9 perf：backpack_changed 回调——隐藏时跳过重建
func _on_backpack_changed() -> void:
	if not is_visible_in_tree():
		_display_dirty = true
		return
	_refresh_all_displays()

## v9 perf：重新显示时补刷隐藏期间积累的变化
func _on_visibility_refresh() -> void:
	if is_visible_in_tree() and _display_dirty:
		_display_dirty = false
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
	empty_label.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	empty_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	grid.add_child(empty_label)

## 添加情报物品项
func _add_lore_item(grid: GridContainer, lore_data: Dictionary) -> void:
	var item_container = PanelContainer.new()
	item_container.custom_minimum_size = Vector2(200, 100)
	item_container.add_theme_stylebox_override("panel",
		PanelStyles.make_card_style(Color(DT.COLOR_CARD.r, DT.COLOR_CARD.g, DT.COLOR_CARD.b, 0.9), DT.COLOR_BORDER_DIM, 1, 4, 8))

	var vbox = VBoxContainer.new()
	item_container.add_child(vbox)

	# 情报名称
	var name_label = Label.new()
	name_label.text = lore_data.get("name", "未知情报")
	name_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	name_label.add_theme_color_override("font_color", DT.COLOR_GOLD)
	vbox.add_child(name_label)

	# 分类标签
	var category_label = Label.new()
	var category_text = _get_category_display_name(lore_data.get("category", ""))
	category_label.text = "[" + category_text + "]"
	category_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
	category_label.add_theme_color_override("font_color", Color(DT.COLOR_KIND_ARMOR.r, DT.COLOR_KIND_ARMOR.g, DT.COLOR_KIND_ARMOR.b, 0.85))
	vbox.add_child(category_label)

	# 描述
	var desc_label = Label.new()
	desc_label.text = lore_data.get("description", "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(180, 0)
	desc_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
	desc_label.add_theme_color_override("font_color", Color(DT.COLOR_TEXT_MID.r, DT.COLOR_TEXT_MID.g, DT.COLOR_TEXT_MID.b, 0.9))
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
	empty_label.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	empty_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	grid.add_child(empty_label)

## 添加情报物品项（紧凑版，用于综合显示）
func _add_lore_item_compact(grid: GridContainer, lore_data: Dictionary) -> void:
	var item_container = PanelContainer.new()
	item_container.custom_minimum_size = Vector2(120, 80)
	item_container.add_theme_stylebox_override("panel",
		PanelStyles.make_card_style(Color(DT.COLOR_CARD.r, DT.COLOR_CARD.g, DT.COLOR_CARD.b, 0.9), DT.COLOR_BORDER_DIM, 1, 4, 6))

	var vbox = VBoxContainer.new()
	item_container.add_child(vbox)

	# 情报图标（AI 生成的文献图标，替代原 emoji 占位）
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(36, 36)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = UiAssetLoaderClass.ui_icon("res_lore")
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon_rect)

	# 情报名称
	var name_label = Label.new()
	name_label.text = lore_data.get("name", "未知情报")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(100, 0)
	name_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
	name_label.add_theme_color_override("font_color", DT.COLOR_GOLD)
	vbox.add_child(name_label)

	grid.add_child(item_container)

## 添加素材物品项
func _add_material_item(grid: GridContainer, item_id: String, amount: int) -> void:
	var item_container = PanelContainer.new()
	item_container.custom_minimum_size = Vector2(80, 80)
	item_container.add_theme_stylebox_override("panel",
		PanelStyles.make_card_style(Color(DT.COLOR_CARD.r, DT.COLOR_CARD.g, DT.COLOR_CARD.b, 0.9), DT.COLOR_BORDER_DIM, 1, 4, 6))

	var vbox = VBoxContainer.new()
	item_container.add_child(vbox)

	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_name: String = String(MATERIAL_ICONS.get(item_id, ""))
	if not icon_name.is_empty():
		icon.texture = UiAssetLoaderClass.ui_icon(icon_name)
		if icon.texture == null:
			icon.texture = UiAssetLoaderClass.ui_icon("icon_blueprint")
		if PERMIT_TINT.has(item_id) and icon.texture != null:
			icon.modulate = PERMIT_TINT[item_id]
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
	item_container.add_theme_stylebox_override("panel",
		PanelStyles.make_card_style(Color(DT.COLOR_CARD.r, DT.COLOR_CARD.g, DT.COLOR_CARD.b, 0.9), DT.COLOR_BORDER_DIM, 1, 4, 6))

	var vbox = VBoxContainer.new()
	item_container.add_child(vbox)

	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = UiAssetLoaderClass.ui_icon("icon_blueprint")
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
		star_progress.add_theme_color_override("fill", DT.COLOR_GOLD)
		star_progress.add_theme_color_override("background", Color(DT.COLOR_SLOT_LOCKED.r, DT.COLOR_SLOT_LOCKED.g, DT.COLOR_SLOT_LOCKED.b, 0.8))
		star_progress.tooltip_text = "蓝图星 %d/%d" % [disp_star, max_star]
		vbox.add_child(star_progress)

	grid.add_child(item_container)

## 获取卡牌掉落显示名称（与 drop_tables CARD_DATA 一致）
func _get_blueprint_fragment_display_name(card_id: String) -> String:
	var entry = DropTables.DropEntry.new(card_id, DropTables.DropType.CARD_DATA)
	if _drop_tables == null:
		_drop_tables = DropTables.new()
	return _drop_tables.get_drop_display_name(entry)

## 获取素材显示名称
func _get_material_display_name(material_id: String) -> String:
	# v6.2 修复 L4：补全所有基础资源中文名（原仅翻译 3/10 种）
	match material_id:
		"nano_materials", "basic_nano": return "纳米材料"
		"alloy": return "合金"
		"crystal": return "晶体"
		"energy_block": return "能量块"
		"research_points": return "研究点数"
		"permit_steel": return "钢铁许可"
		"permit_flame": return "烈焰许可"
		"permit_thunder": return "雷霆许可"
		"permit_void": return "虚空许可"
		_: return material_id

## 关闭面板
func _on_close() -> void:
	closed.emit()
	queue_free()
