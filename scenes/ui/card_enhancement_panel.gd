extends Control
class_name CardEnhancementPanel
## 卡牌强化 UI 面板（v7.x UI 重设计 · 战术强化站）
##
## 职责（剥离进化后纯强化）：
## - 显示所有可强化的卡牌列表（左栏 roster）
## - 显示卡牌 Hero 信息 + 6 格属性对比卡 + 蜂巢词条槽 + 强化路径时间线
## - 执行强化操作（do_enhance）+ 词条选择/升级弹窗
## - 反馈强化结果
##
## 公开 API（不可改签名）：
## - signal closed
## - func select_card_by_id(card_id: String)
## - func close_embedded_popups()
##
## 签名色：琥珀金（COLOR_AMBER）· 强化主题
## 设计参考：docs/design_mockups/养成系统四面板设计.html#enhance

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const EnemyBlueprints = preload("res://data/enemy_blueprints.gd")
const BasicResources = preload("res://data/basic_resources.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const ModEffectLabels = preload("res://scripts/ui/mod_effect_labels.gd")

# v7.x UI 重设计基建
const DT = preload("res://resources/design_tokens.gd")
const GeoShapes = preload("res://scripts/ui/geo_shapes.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const UnifiedRankSystem = preload("res://data/military_titles/unified_rank_system.gd")

signal closed

# === UI 组件引用（路径与 tscn 节点一一对应） ===
@onready var card_list_container = $VBoxContainer/MainSplit/LeftPanel/ScrollContainer/CardListContainer
@onready var no_selection_label = $VBoxContainer/MainSplit/CenterPanel/NoSelectionLabel
@onready var detail_scroll = $VBoxContainer/MainSplit/CenterPanel/DetailScroll
@onready var detail_panel = $VBoxContainer/MainSplit/CenterPanel/DetailScroll/DetailPanel
@onready var enhancement_button = $VBoxContainer/MainSplit/CenterPanel/ActionBar/EnhanceButton
# v7.x 修复：ResourceArea 下多了一层 ResourceHBox，对齐 .tscn 实际结构
# （原路径 $VBoxContainer/ResourceArea/NanoLabel 找不到节点导致 _ready 报错）
@onready var nano_label = $VBoxContainer/ResourceArea/ResourceHBox/NanoLabel
@onready var research_label = $VBoxContainer/ResourceArea/ResourceHBox/ResearchLabel
@onready var alloy_label = $VBoxContainer/ResourceArea/ResourceHBox/AlloyLabel
@onready var result_label = $VBoxContainer/ResultLabel
@onready var path_container = $VBoxContainer/MainSplit/RightPanel/PathScroll/PathList

# === 数据状态 ===
var selected_card_id: String = ""
var card_items: Array = []

# === 主题色（v7.x 改用 DesignTokens 签名色系统） ===
# 向后兼容别名（避免内部代码大改）：指向 DT 新常量
const THEME_AMBER := Color(0.961, 0.620, 0.043, 1)
const THEME_AMBER_SOFT := Color(0.984, 0.749, 0.141, 1)
const THEME_CYAN := Color(0.024, 0.714, 0.831, 1)
const THEME_GOLD := Color(1.0, 0.85, 0.35, 1)
const THEME_GREEN_UP := Color(0.204, 0.827, 0.600, 1)
const THEME_RED := Color(0.937, 0.267, 0.267, 1)
const THEME_TEXT := Color(0.91, 0.93, 0.97, 1)
const THEME_TEXT_DIM := Color(0.42, 0.46, 0.57, 1)
const THEME_TEXT_FAINT := Color(0.27, 0.31, 0.39, 1)
const THEME_BG_CARD := Color(0.075, 0.102, 0.165, 1)
const THEME_BG_SLOT := Color(0.039, 0.059, 0.110, 1)
const THEME_BORDER_DIM := Color(0.25, 0.35, 0.42, 0.14)


func _ready() -> void:
	# 关闭按钮
	var close_btn = get_node_or_null("VBoxContainer/TitleArea/TitleHBox/CloseButton")
	if close_btn:
		close_btn.pressed.connect(_on_close)
	# v9.x: 返回成长首页按钮
	var back_btn = get_node_or_null("%BackToGrowthButton")
	if back_btn:
		back_btn.pressed.connect(_on_back_to_growth)

	# 信号连接
	var mll = get_node_or_null("/root/ManagerLazyLoader")
	if mll and mll.has_method("ensure_loaded"):
		mll.ensure_loaded("card_enhancement")
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	if card_enh_mgr:
		card_enh_mgr.enhancement_completed.connect(_on_enhancement_completed)
		card_enh_mgr.enhancement_failed.connect(_on_enhancement_failed)

	if BlueprintManager:
		if BlueprintManager.has_signal("fragments_changed"):
			if not BlueprintManager.fragments_changed.is_connected(_on_nano_materials_changed):
				BlueprintManager.fragments_changed.connect(_on_nano_materials_changed)

	if BasicResourceManager and BasicResourceManager.has_signal("resources_changed"):
		if not BasicResourceManager.resources_changed.is_connected(_on_nano_materials_changed):
			BasicResourceManager.resources_changed.connect(_on_nano_materials_changed)

	if enhancement_button:
		enhancement_button.pressed.connect(_on_enhance_button_pressed)

	if SignalBus and SignalBus.has_signal("card_added_to_backpack"):
		if not SignalBus.card_added_to_backpack.is_connected(_on_card_added_to_backpack):
			SignalBus.card_added_to_backpack.connect(_on_card_added_to_backpack)

	# 初始化
	_init_card_list()
	_update_resource_labels()
	_init_path_timeline()  # 右侧强化路径时间线骨架


func _exit_tree() -> void:
	# v6.2 修复 M9：断开所有 _ready 连接的信号
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	if card_enh_mgr:
		if card_enh_mgr.enhancement_completed.is_connected(_on_enhancement_completed):
			card_enh_mgr.enhancement_completed.disconnect(_on_enhancement_completed)
		if card_enh_mgr.enhancement_failed.is_connected(_on_enhancement_failed):
			card_enh_mgr.enhancement_failed.disconnect(_on_enhancement_failed)
	if BlueprintManager and BlueprintManager.has_signal("fragments_changed"):
		if BlueprintManager.fragments_changed.is_connected(_on_nano_materials_changed):
			BlueprintManager.fragments_changed.disconnect(_on_nano_materials_changed)
	if BasicResourceManager and BasicResourceManager.has_signal("resources_changed"):
		if BasicResourceManager.resources_changed.is_connected(_on_nano_materials_changed):
			BasicResourceManager.resources_changed.disconnect(_on_nano_materials_changed)
	if SignalBus and SignalBus.has_signal("card_added_to_backpack"):
		if SignalBus.card_added_to_backpack.is_connected(_on_card_added_to_backpack):
			SignalBus.card_added_to_backpack.disconnect(_on_card_added_to_backpack)


# ============================================================
# 公开 API（不可改签名）
# ============================================================

## 外部面板跳转时预选卡牌（如成长中枢 / 情报中心）
func select_card_by_id(card_id: String) -> void:
	if card_id.is_empty():
		return
	if card_list_container and card_list_container.get_child_count() == 0:
		_init_card_list()
	selected_card_id = card_id
	_refresh_card_selection_style()
	_update_detail_panel()


## 关闭所有动态弹窗（main.gd 关闭 overlay 时调用）
func close_embedded_popups() -> void:
	var root = get_node_or_null("_dyn_module_popup")
	if root:
		root.queue_free()
	# 同时清空 result_label
	if result_label:
		result_label.text = ""


# ============================================================
# 卡牌列表（左栏 roster）
# ============================================================

func _init_card_list() -> void:
	if not card_list_container:
		return
	selected_card_id = ""

	# 同步移除旧列表项（避免 queue_free 延迟导致列表容器撑高不回缩）
	for child in card_list_container.get_children():
		card_list_container.remove_child(child)
		child.free()
	card_items.clear()

	# v7.x 铁律2：优先 InstanceRegistry 实例全集，SaveManager 队列兜底
	var all_card_ids: Array = []
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_all_instance_ids"):
		for iid in ir.get_all_instance_ids():
			all_card_ids.append(String(iid))
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

	# 生成卡牌列表项（roster 风格：4px 稀有度色条 + 缩略图 + 名字/#序号/Lv/PWR）
	for id_val in all_card_ids:
		var card_id: String = String(id_val)
		if card_id.is_empty():
			continue
		var base_card_id: String = card_id
		if ir != null and ir.has_method("get_card_id_of"):
			base_card_id = ir.get_card_id_of(card_id)
		var card_data = DefaultCards.get_card_by_id(base_card_id)
		if card_data == null:
			card_data = EnemyBlueprints.get_card_by_id(base_card_id)
		if card_data == null:
			continue
		card_list_container.add_child(_make_roster_item(card_id, card_data))


## 构造单个 roster 卡牌项（签名色系统 + 稀有度色条 + PWR）
func _make_roster_item(card_id: String, card_data) -> Control:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 8)
	item.custom_minimum_size = Vector2(0, 44)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 1. 4px 稀有度色条（左侧）
	var rarity_bar := ColorRect.new()
	rarity_bar.custom_minimum_size = Vector2(4, 30)
	rarity_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rarity_bar.color = _rarity_color(card_data.rarity) if card_data else DT.COLOR_RARITY_COMMON
	item.add_child(rarity_bar)

	# 2. 32×32 缩略图（兵种代号）
	var thumb := PanelContainer.new()
	thumb.custom_minimum_size = Vector2(32, 32)
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	thumb.add_theme_stylebox_override("panel", PanelStyles.make_panel_style(DT.COLOR_BG_SLOT, DT.COLOR_BORDER_DIM, 1, 3))
	var thumb_label := Label.new()
	thumb_label.text = _get_thumb_code(card_data)
	thumb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thumb_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	thumb_label.add_theme_font_override("font", DT.get_title_font())
	thumb_label.add_theme_color_override("font_color", DT.COLOR_AMBER_SOFT)
	thumb_label.add_theme_font_size_override("font_size", 11)
	thumb.add_child(thumb_label)
	item.add_child(thumb)

	# 3. 信息列（名字 + Lv/#序号/MOD）
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_col.add_theme_constant_override("separation", 2)
	var name_label := Label.new()
	name_label.text = _get_card_display_name(card_id, card_data)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", DT.COLOR_TEXT)
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_child(name_label)
	var meta_label := Label.new()
	var lvl := _get_card_level(card_id)
	var seq := _get_seq_suffix(card_id)
	meta_label.text = "Lv.%d  %s" % [lvl, seq]
	meta_label.add_theme_font_override("font", DT.get_body_font())
	meta_label.add_theme_font_size_override("font_size", 10)
	meta_label.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	info_col.add_child(meta_label)
	item.add_child(info_col)

	# 4. PWR 数字（右侧）
	var pwr_col := VBoxContainer.new()
	pwr_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pwr_lbl := Label.new()
	pwr_lbl.text = "PWR"
	pwr_lbl.add_theme_font_override("font", DT.get_body_font())
	pwr_lbl.add_theme_font_size_override("font_size", 8)
	pwr_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_FAINT)
	pwr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pwr_col.add_child(pwr_lbl)
	var pwr_val := Label.new()
	pwr_val.text = str(_get_card_power(card_id, card_data))
	pwr_val.add_theme_font_override("font", DT.get_title_font())
	pwr_val.add_theme_font_size_override("font_size", 11)
	pwr_val.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH_SOFT)
	pwr_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pwr_col.add_child(pwr_val)
	item.add_child(pwr_col)

	# 点击 + 样式
	item.gui_input.connect(_make_roster_click_handler(card_id))
	_apply_roster_item_style(item, false)
	item.set_meta("card_id", card_id)
	card_items.append({"id": card_id, "data": card_data, "node": item})
	return item


func _make_roster_click_handler(card_id: String) -> Callable:
	return func(evt: InputEvent) -> void:
		if evt is InputEventMouseButton and evt.pressed and evt.button_index == MOUSE_BUTTON_LEFT:
			_on_card_item_selected(card_id)


func _apply_roster_item_style(item: HBoxContainer, selected: bool) -> void:
	var styles: Dictionary = PanelStyles.make_roster_item_style(selected, DT.COLOR_AMBER)
	# 用 PaddingContainer 模拟（HBox 直接挂 stylebox 不生效，包一层 PanelContainer 太重）
	# 这里用 modulate 边缘色 + 左侧色条变亮来反馈选中
	if selected:
		item.modulate = Color(1.15, 1.15, 1.15, 1.0)
		item.add_theme_constant_override("separation", 8)
	else:
		item.modulate = Color(1, 1, 1, 1)


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return DT.COLOR_RARITY_COMMON
		"uncommon": return DT.COLOR_RARITY_UNCOMMON
		"rare": return DT.COLOR_RARITY_RARE
		"epic": return DT.COLOR_RARITY_EPIC
		"legendary": return DT.COLOR_RARITY_LEGENDARY
		"mythic": return DT.COLOR_RARITY_MYTHIC
		_: return DT.COLOR_RARITY_COMMON


func _get_thumb_code(card_data) -> String:
	# 从卡牌 display_name 取前 2-3 字母作为缩略图代号
	if card_data == null:
		return "?"
	var n: String = str(card_data.display_name) if card_data.get("display_name") != null else "?"
	if n.length() >= 3:
		# 取大写字母或前两字
		var code := ""
		for ch in n:
			if ch >= "A" and ch <= "Z":
				code += ch
				if code.length() >= 2:
					break
		if code.length() >= 2:
			return code
		return n.substr(0, 2)
	return n


func _get_card_level(card_id: String) -> int:
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	if card_enh_mgr and card_enh_mgr.has_method("get_card_enhancement_level"):
		return int(card_enh_mgr.get_card_enhancement_level(card_id))
	return 0


func _get_seq_suffix(card_id: String) -> String:
	var hash_idx: int = card_id.rfind("#")
	if hash_idx >= 0:
		return "#%s" % card_id.substr(hash_idx + 1)
	return ""


func _get_card_power(card_id: String, card_data) -> int:
	# 优先用实例养成后的战力
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_instance"):
		var inst = ir.get_instance(card_id)
		if inst and inst.has_method("get_current_power"):
			return int(inst.get_current_power())
	if card_data and card_data.has_method("get_current_power"):
		return int(card_data.get_current_power())
	if card_data and card_data.get("power") != null:
		return int(card_data.power)
	return 0


func _get_card_display_name(card_id: String, card_data) -> String:
	var name_str = card_id
	if card_data is Dictionary:
		name_str = str(card_data.get("display_name", card_id))
	elif card_data is Object:
		var object_name: Variant = card_data.get("display_name")
		name_str = str(object_name if object_name != null else card_id)
	return name_str


func _on_card_item_selected(card_id: String) -> void:
	select_card_by_id(card_id)


func _refresh_card_selection_style() -> void:
	for item in card_items:
		var node = item.get("node")
		if node == null:
			continue
		var is_sel: bool = (String(item.get("id", "")) == selected_card_id)
		_apply_roster_item_style(node, is_sel)


## 按 instance_id 解析出模板 CardResource
func _resolve_card_data(id_str: String) -> CardResource:
	if id_str.is_empty():
		return null
	# 优先取实例（含养成数据）
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_instance"):
		var inst = ir.get_instance(id_str)
		if inst != null:
			return inst
	# 回退到模板
	var base_card_id: String = id_str
	if ir != null and ir.has_method("get_card_id_of"):
		base_card_id = ir.get_card_id_of(id_str)
	var card_data = DefaultCards.get_card_by_id(base_card_id)
	if card_data == null:
		card_data = EnemyBlueprints.get_card_by_id(base_card_id)
	return card_data


# ============================================================
# 详情面板渲染（中栏）
# ============================================================

func _update_detail_panel() -> void:
	if not detail_panel:
		return

	# 清空动态内容
	_clear_dynamic_detail()

	if selected_card_id.is_empty():
		if no_selection_label:
			no_selection_label.visible = true
		if detail_scroll:
			detail_scroll.visible = false
		if enhancement_button:
			enhancement_button.disabled = true
			enhancement_button.text = "请选择卡牌"
		return

	if no_selection_label:
		no_selection_label.visible = false
	if detail_scroll:
		detail_scroll.visible = true

	var card_data = _resolve_card_data(selected_card_id)
	if card_data == null:
		return

	# === Hero header ===
	detail_panel.add_child(_make_hero_header(card_data))

	# === 6 格属性对比卡 ===
	detail_panel.add_child(_make_stats_compare(card_data))

	# === 蜂巢词条槽 ===
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	var enhancement_info: Dictionary = card_enh_mgr.get_enhancement_info(selected_card_id) if card_enh_mgr else {}
	var current_level: int = int(enhancement_info.get("current_level", 1))
	detail_panel.add_child(_make_hex_slots(card_data, current_level))

	# === 强化按钮状态 ===
	_update_action_bar(enhancement_info, card_data)


func _clear_dynamic_detail() -> void:
	if detail_panel == null:
		return
	for child in detail_panel.get_children():
		detail_panel.remove_child(child)
		child.free()


## Hero header：头像 + 卡名 + tags + Lv/10 大数字
func _make_hero_header(card_data) -> Control:
	var header := HBoxContainer.new()
	header.name = "_dyn_header"
	header.add_theme_constant_override("separation", 16)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 80×80 头像（切角模拟）
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(80, 80)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.add_theme_stylebox_override("panel", PanelStyles.make_panel_style(
		DT.COLOR_BG_SLOT, DT.COLOR_AMBER, 1, 8))
	var portrait_label := Label.new()
	portrait_label.text = _get_thumb_code(card_data)
	portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_label.add_theme_font_override("font", DT.get_title_font_bold())
	portrait_label.add_theme_font_size_override("font_size", 22)
	portrait_label.add_theme_color_override("font_color", DT.COLOR_AMBER)
	portrait.add_child(portrait_label)
	header.add_child(portrait)

	# 信息列（卡名 + tags）
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_col.add_theme_constant_override("separation", 6)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	var name_label := Label.new()
	name_label.text = str(card_data.display_name) if card_data.get("display_name") != null else selected_card_id
	name_label.add_theme_font_override("font", DT.get_title_font_bold())
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", DT.COLOR_TEXT)
	name_row.add_child(name_label)
	# card_id 小字
	var id_label := Label.new()
	id_label.text = selected_card_id
	id_label.add_theme_font_override("font", DT.get_body_font())
	id_label.add_theme_font_size_override("font_size", 10)
	id_label.add_theme_color_override("font_color", DT.COLOR_TEXT_FAINT)
	id_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(id_label)
	info_col.add_child(name_row)

	# tags 行
	var tags_row := HBoxContainer.new()
	tags_row.add_theme_constant_override("separation", 6)
	tags_row.add_child(_make_tag(_era_name(card_data), DT.COLOR_CYAN_TECH_SOFT))
	tags_row.add_child(_make_tag(_combat_kind_name(card_data), DT.COLOR_AMBER))
	var rank_tag := _make_rank_tag(card_data)
	if rank_tag:
		tags_row.add_child(rank_tag)
	info_col.add_child(tags_row)

	header.add_child(info_col)

	# 右侧 Lv/10 大数字
	var lvl_col := VBoxContainer.new()
	lvl_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	var lvl: int = 1
	if card_enh_mgr and card_enh_mgr.has_method("get_card_enhancement_level"):
		lvl = int(card_enh_mgr.get_card_enhancement_level(selected_card_id))
	var lvl_label := Label.new()
	lvl_label.text = "%d/10" % lvl
	lvl_label.add_theme_font_override("font", DT.get_title_font_bold())
	lvl_label.add_theme_font_size_override("font_size", 32)
	lvl_label.add_theme_color_override("font_color", DT.COLOR_AMBER)
	lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lvl_col.add_child(lvl_label)
	var lvl_caption := Label.new()
	lvl_caption.text = "强化等级"
	lvl_caption.add_theme_font_override("font", DT.get_body_font())
	lvl_caption.add_theme_font_size_override("font_size", 9)
	lvl_caption.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	lvl_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lvl_caption.add_theme_constant_override("letter_spacing", 2)
	lvl_col.add_child(lvl_caption)
	header.add_child(lvl_col)

	return header


func _make_tag(text: String, color: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", PanelStyles.make_chip_style(color))
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", DT.get_title_font())
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", color)
	p.add_child(l)
	return p


func _make_rank_tag(card_data) -> Control:
	if BlueprintManager and BlueprintManager.has_method("get_rank_info"):
		var info: Dictionary = BlueprintManager.get_rank_info(selected_card_id)
		var rank_name: String = String(info.get("rank_name", ""))
		if rank_name.is_empty():
			return null
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", PanelStyles.make_chip_style(DT.COLOR_AMBER_SOFT))
		var l := Label.new()
		l.text = rank_name
		l.add_theme_font_override("font", DT.get_title_font())
		l.add_theme_font_size_override("font_size", 10)
		l.add_theme_color_override("font_color", DT.COLOR_AMBER_SOFT)
		p.add_child(l)
		return p
	return null


func _era_name(card_data) -> String:
	if card_data == null or card_data.get("era") == null:
		return "?"
	var era: int = int(card_data.era)
	match era:
		0: return "一战"
		1: return "二战"
		2: return "冷战"
		3: return "现代"
		4: return "近未来"
		_: return "?"


func _combat_kind_name(card_data) -> String:
	if card_data == null or card_data.get("combat_kind") == null:
		return "?"
	var ck: int = int(card_data.combat_kind)
	match ck:
		0: return "轻装"
		1: return "装甲"
		2: return "支援"
		3: return "空中"
		4: return "堡垒"
		_: return "?"


## 6 格属性对比卡（HP/三攻/防/射程）：强化前→后
func _make_stats_compare(card_data) -> Control:
	var wrap := VBoxContainer.new()
	wrap.name = "_dyn_stats"
	wrap.add_theme_constant_override("separation", 8)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 标题行
	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "作战参数 · 强化前 → 后"
	title.add_theme_font_override("font", DT.get_title_font())
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	title.add_theme_constant_override("letter_spacing", 2)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var cur_lvl := _get_card_level(selected_card_id)
	var next_lvl := cur_lvl + 1
	var mult_info := Label.new()
	mult_info.text = "×%.2f → ×%.2f" % [
		UnifiedRankSystem.get_power_multiplier(cur_lvl),
		UnifiedRankSystem.get_power_multiplier(next_lvl)]
	mult_info.add_theme_font_override("font", DT.get_body_font())
	mult_info.add_theme_font_size_override("font_size", 10)
	mult_info.add_theme_color_override("font_color", DT.COLOR_TEXT_FAINT)
	title_row.add_child(mult_info)
	wrap.add_child(title_row)

	# 6 格网格
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var cur_mult := UnifiedRankSystem.get_power_multiplier(cur_lvl)
	var next_mult := UnifiedRankSystem.get_power_multiplier(next_lvl)
	var stats := _get_base_stats(card_data)
	var max_level := 10
	var at_max := cur_lvl >= max_level

	# 6 个属性：HP/轻攻/重攻/对空/防御/射程
	grid.add_child(_make_stat_cell("生命值", "HP", stats.hp, stats.hp, false, at_max))
	grid.add_child(_make_stat_cell("轻装攻击", "ATK·L", int(stats.atk_light * cur_mult), int(stats.atk_light * next_mult), true, at_max))
	grid.add_child(_make_stat_cell("装甲攻击", "ATK·A", int(stats.atk_armor * cur_mult), int(stats.atk_armor * next_mult), true, at_max))
	grid.add_child(_make_stat_cell("对空攻击", "ATK·AIR", int(stats.atk_air * cur_mult), int(stats.atk_air * next_mult), stats.atk_air > 0, at_max))
	grid.add_child(_make_stat_cell("装甲防御", "DEF", int(stats.def_armor * cur_mult), int(stats.def_armor * next_mult), true, at_max))
	grid.add_child(_make_stat_cell("射程", "RNG", stats.range_value, stats.range_value, false, at_max))

	wrap.add_child(grid)
	return wrap


func _make_stat_cell(name_str: String, cat: String, before_val: int, after_val: int, can_change: bool, at_max: bool) -> Control:
	var cell := PanelContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var is_up: bool = can_change and (after_val > before_val) and not at_max
	cell.add_theme_stylebox_override("panel", PanelStyles.make_stat_cell_style(
		DT.COLOR_GREEN_UP if is_up else DT.COLOR_BORDER_DIM))

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 10)
	inner.add_theme_constant_override("margin_right", 10)
	inner.add_theme_constant_override("margin_top", 8)
	inner.add_theme_constant_override("margin_bottom", 8)
	cell.add_child(inner)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	inner.add_child(col)

	# 顶部：名字 + 类目
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_BEGIN
	var name_label := Label.new()
	name_label.text = name_str
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var cat_label := Label.new()
	cat_label.text = cat
	cat_label.add_theme_font_override("font", DT.get_body_font())
	cat_label.add_theme_font_size_override("font_size", 8)
	cat_label.add_theme_color_override("font_color", DT.COLOR_TEXT_FAINT)
	cat_label.add_theme_constant_override("letter_spacing", 1)
	head.add_child(cat_label)
	col.add_child(head)

	# 数值行：before → after + delta
	var vals := HBoxContainer.new()
	vals.add_theme_constant_override("separation", 6)
	var before_label := Label.new()
	before_label.text = str(before_val)
	before_label.add_theme_font_override("font", DT.get_body_font())
	before_label.add_theme_font_size_override("font_size", 13)
	before_label.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
	# 删除线效果（Godot 无原生 strikethrough，用 modulate 暗 + 字号小模拟）
	before_label.modulate.a = 0.55
	vals.add_child(before_label)

	if is_up:
		var arrow := Label.new()
		arrow.text = "→"
		arrow.add_theme_font_override("font", DT.get_body_font())
		arrow.add_theme_font_size_override("font_size", 11)
		arrow.add_theme_color_override("font_color", DT.COLOR_GREEN_UP)
		vals.add_child(arrow)
		var after_label := Label.new()
		after_label.text = str(after_val)
		after_label.add_theme_font_override("font", DT.get_body_font())
		after_label.add_theme_font_size_override("font_size", 16)
		after_label.add_theme_color_override("font_color", DT.COLOR_GREEN_UP)
		vals.add_child(after_label)
		var delta := Label.new()
		delta.text = "+%d" % (after_val - before_val)
		delta.add_theme_font_override("font", DT.get_body_font())
		delta.add_theme_font_size_override("font_size", 10)
		delta.add_theme_color_override("font_color", DT.COLOR_GREEN_UP)
		delta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vals.add_child(delta)
	else:
		# 无变化或满级
		var dash := Label.new()
		dash.text = "—" if not can_change or before_val == 0 else "="
		dash.add_theme_font_override("font", DT.get_body_font())
		dash.add_theme_font_size_override("font_size", 11)
		dash.add_theme_color_override("font_color", DT.COLOR_TEXT_FAINT)
		vals.add_child(dash)
		var after_label2 := Label.new()
		after_label2.text = str(after_val)
		after_label2.add_theme_font_override("font", DT.get_body_font())
		after_label2.add_theme_font_size_override("font_size", 14)
		after_label2.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		after_label2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		after_label2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vals.add_child(after_label2)

	col.add_child(vals)
	return cell


## 卡牌基础属性（无强化倍率）
func _get_base_stats(card_data) -> Dictionary:
	if card_data == null:
		return {}
	return {
		"hp": int(card_data.base_hp) if card_data.get("base_hp") != null else 0,
		"atk_light": int(card_data.attack_light) if card_data.get("attack_light") != null else 0,
		"atk_armor": int(card_data.attack_armor) if card_data.get("attack_armor") != null else 0,
		"atk_air": int(card_data.attack_air) if card_data.get("attack_air") != null else 0,
		"def_light": int(card_data.defense_light) if card_data.get("defense_light") != null else 0,
		"def_armor": int(card_data.defense_armor) if card_data.get("defense_armor") != null else 0,
		"def_air": int(card_data.defense_air) if card_data.get("defense_air") != null else 0,
		"range_value": int(card_data.range_value) if card_data.get("range_value") != null else 0,
	}


## 蜂巢词条槽（5 格 HexagonSlot）
func _make_hex_slots(card_data, current_level: int) -> Control:
	var wrap := VBoxContainer.new()
	wrap.name = "_dyn_hex_slots"
	wrap.add_theme_constant_override("separation", 8)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 标题
	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "改装词条槽"
	title.add_theme_font_override("font", DT.get_title_font())
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	title.add_theme_constant_override("letter_spacing", 2)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var max_slots := _get_max_slots(current_level)
	var unlock_label := Label.new()
	unlock_label.text = "%d / 5 已解锁" % max_slots
	unlock_label.add_theme_font_override("font", DT.get_body_font())
	unlock_label.add_theme_font_size_override("font_size", 10)
	unlock_label.add_theme_color_override("font_color", DT.COLOR_AMBER_SOFT)
	title_row.add_child(unlock_label)
	wrap.add_child(title_row)

	# 蜂巢槽位容器
	var slots_wrap := PanelContainer.new()
	slots_wrap.add_theme_stylebox_override("panel", PanelStyles.make_card_style(
		DT.COLOR_BG_CARD, DT.COLOR_BORDER_DIM, 1, 4, 12))
	var slots_margin := MarginContainer.new()
	slots_margin.add_theme_constant_override("margin_left", 12)
	slots_margin.add_theme_constant_override("margin_right", 12)
	slots_margin.add_theme_constant_override("margin_top", 12)
	slots_margin.add_theme_constant_override("margin_bottom", 12)
	slots_wrap.add_child(slots_margin)
	var slots_grid := HBoxContainer.new()
	slots_grid.add_theme_constant_override("separation", 8)
	slots_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_margin.add_child(slots_grid)

	# 读取已装词条
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	var slots: Array = []
	if card_enh_mgr and card_enh_mgr.has_method("get_module_slots"):
		slots = card_enh_mgr.get_module_slots(selected_card_id)

	# 生成 5 个 HexagonSlot
	for i in range(5):
		var hex = GeoShapes.HexagonSlot.new()
		hex.accent_color = DT.COLOR_AMBER
		var unlocked := i < max_slots
		if not unlocked:
			# 锁定，显示解锁等级
			var unlock_level := (i + 1) * 2  # Lv2/4/6/8/10
			hex.set_data(GeoShapes.HexagonSlot.State.LOCKED, "", 0, "LV.%d" % unlock_level)
		else:
			var disp := _slot_display(slots, i)
			if disp.is_empty():
				# 已解锁但无词条
				var will_unlock := (current_level + 1) % 2 == 0 and (i == max_slots)
				hex.set_data(GeoShapes.HexagonSlot.State.EMPTY, "即将解锁" if will_unlock else "", 0)
			else:
				# 有词条：解析名字和等级
				var parts := disp.split(" Lv.", true, 1)
				var mod_name: String = parts[0] if parts.size() > 0 else disp
				var mod_lvl: int = int(parts[1]) if parts.size() > 1 else 1
				# 名字截断
				if mod_name.length() > 4:
					mod_name = mod_name.substr(0, 4)
				hex.set_data(GeoShapes.HexagonSlot.State.FILLED, mod_name, mod_lvl)
		slots_grid.add_child(hex)
	wrap.add_child(slots_wrap)

	return wrap


func _get_max_slots(level: int) -> int:
	# Lv2/4/6/8/10 解锁 1/2/3/4/5 槽（规则：level/2，封顶 5）
	return mini(level / 2, 5)


## 解析第 i 个槽位的词条显示文本（"词条名 Lv.x"）；无词条返回空串
func _slot_display(slots: Array, i: int) -> String:
	if i >= slots.size():
		return ""
	var s = slots[i]
	if s == null:
		return ""
	var mid: String = ""
	var lvl: int = 1
	if s is Dictionary:
		mid = String(s.get("module_id", ""))
		lvl = int(s.get("level", 1))
	elif s is ModuleSlot:
		mid = String(s.module_id)
		lvl = int(s.level)
	elif s is Object:
		var mid_val = s.get("module_id")
		if mid_val != null:
			mid = String(mid_val)
		var lvl_val = s.get("level")
		if lvl_val != null:
			lvl = int(lvl_val)
	if mid.is_empty():
		return ""
	# v9.x 修复：ModuleDefinitions 是 class_name 静态类（非 autoload），直接用类名调用
	var name_str: String = ModuleDefinitions.get_module_name(mid)
	if name_str.length() > 4:
		name_str = name_str.substr(0, 4)
	return "%s Lv.%d" % [name_str, lvl]


## 更新底部 ActionBar（强化按钮 + 消耗）
func _update_action_bar(enhancement_info: Dictionary, card_data) -> void:
	if enhancement_button == null:
		return
	var current_level: int = int(enhancement_info.get("current_level", 1))
	var max_level: int = int(enhancement_info.get("max_level", 10))
	var can_enhance: bool = bool(enhancement_info.get("can_enhance", true))

	if not can_enhance or current_level >= max_level:
		enhancement_button.disabled = true
		enhancement_button.text = "已达最高强化等级"
		return

	var next_level: int = int(enhancement_info.get("next_level", current_level + 1))
	var nano_cost: int = int(enhancement_info.get("nano_cost", 0))
	var current_nano: int = _get_nano_balance()
	var enough: bool = current_nano >= nano_cost

	enhancement_button.disabled = not enough
	enhancement_button.text = "强化至 Lv.%d（消耗 %d 纳米）" % [next_level, nano_cost]


func _get_nano_balance() -> int:
	if BasicResourceManager and BasicResourceManager.has_method("get_total"):
		return int(BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS))
	elif BlueprintManager and BlueprintManager.has_method("get_nano_materials"):
		return int(BlueprintManager.get_nano_materials())
	return 0


# ============================================================
# 右侧强化路径时间线（Lv1-Lv10）
# ============================================================

func _init_path_timeline() -> void:
	if path_container == null:
		return
	# 先清空（若有静态节点）
	for child in path_container.get_children():
		path_container.remove_child(child)
		child.free()
	_refresh_path_timeline(0)  # 默认 0 级


func _refresh_path_timeline(current_level: int) -> void:
	if path_container == null:
		return
	for child in path_container.get_children():
		path_container.remove_child(child)
		child.free()
	for lvl in range(1, 11):
		var node := _make_path_node(lvl, current_level)
		path_container.add_child(node)


func _make_path_node(lvl: int, current_level: int) -> Control:
	var wrap := HBoxContainer.new()
	wrap.add_theme_constant_override("separation", 10)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 状态判定
	var state: String = "future"
	if lvl <= current_level:
		state = "done"
	elif lvl == current_level + 1:
		state = "current"

	# 圆点
	var dot := PanelContainer.new()
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dot_color: Color
	match state:
		"done": dot_color = DT.COLOR_AMBER_DEEP if "COLOR_AMBER_DEEP" in DT else DT.COLOR_AMBER.darkened(0.3)
		"current": dot_color = DT.COLOR_AMBER
		_: dot_color = DT.COLOR_SLOT_LOCKED
	dot.add_theme_stylebox_override("panel", PanelStyles.make_panel_style(
		dot_color, DT.COLOR_AMBER if state == "current" else DT.COLOR_BORDER_DIM,
		1 if state != "current" else 2, 7))

	# 等级标签
	var lvl_label := Label.new()
	var unlock_event := ""
	if lvl % 2 == 0 and lvl <= 10:
		unlock_event = " · 解锁槽%d" % (lvl / 2)
	lvl_label.text = "Lv.%d%s" % [lvl, unlock_event]
	lvl_label.add_theme_font_override("font", DT.get_title_font())
	lvl_label.add_theme_font_size_override("font_size", 11)
	match state:
		"done": lvl_label.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		"current": lvl_label.add_theme_color_override("font_color", DT.COLOR_AMBER)
		_: lvl_label.add_theme_color_override("font_color", DT.COLOR_TEXT_FAINT)
	lvl_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lvl_label.clip_text = true

	# 倍率（右侧）
	var mult_label := Label.new()
	var mult := UnifiedRankSystem.get_power_multiplier(lvl)
	var mult_str := "×%.2f" % mult
	if lvl == 9 or lvl == 10:
		mult_str += " 跃升"
	if lvl == 10:
		mult_str += " · 全属性+10%"
	mult_label.text = mult_str
	mult_label.add_theme_font_override("font", DT.get_body_font())
	mult_label.add_theme_font_size_override("font_size", 9)
	match state:
		"done": mult_label.add_theme_color_override("font_color", DT.COLOR_TEXT_FAINT)
		"current": mult_label.add_theme_color_override("font_color", DT.COLOR_AMBER_SOFT)
		_: mult_label.add_theme_color_override("font_color", DT.COLOR_TEXT_FAINT)
	mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	wrap.add_child(dot)
	wrap.add_child(lvl_label)
	wrap.add_child(mult_label)
	return wrap


# ============================================================
# 强化执行（保留原逻辑）
# ============================================================

func _on_enhance_button_pressed() -> void:
	var card_enh_mgr = get_node_or_null("/root/CardEnhancementManager")
	if selected_card_id.is_empty() or not card_enh_mgr:
		return
	# v7.4 修复：缓存 selected_card_id，防止信号回调清空成员变量
	var card_id_cached: String = selected_card_id
	var current_nano: int = _get_nano_balance()
	var result = card_enh_mgr.do_enhance(card_id_cached, current_nano)
	if not result.get("ok", false):
		if result_label:
			result_label.text = "强化失败：" + str(result.get("reason", "纳米材料不足"))
			result_label.add_theme_color_override("font_color", DT.COLOR_RED_DOWN)
		return
	# 扣费
	var nano_cost: int = card_enh_mgr.get_enhance_nano_cost(card_id_cached, int(result.get("level", 0)))
	if BasicResourceManager and BasicResourceManager.has_method("spend_resource"):
		BasicResourceManager.spend_resource(BasicResources.ID_NANO_MATERIALS, nano_cost)
	elif BlueprintManager and BlueprintManager.has_method("add_nano_materials"):
		BlueprintManager.add_nano_materials(-nano_cost)

	# 词条弹窗
	var action: String = String(result.get("action", "none"))
	if action == "new_slot":
		_show_module_selection_popup(card_id_cached, int(result.get("level", 0)))
	elif action == "upgrade_slot":
		_show_module_upgrade_popup(card_id_cached)

	# 刷新（用缓存值重新选中）
	_init_card_list()
	selected_card_id = card_id_cached
	_refresh_card_selection_style()
	_update_detail_panel()
	_refresh_path_timeline(int(result.get("level", 0)))
	_update_resource_labels()


func _on_enhancement_completed(success: bool, card_id: String, action: String, message: String) -> void:
	if card_id == selected_card_id:
		if result_label:
			result_label.text = message
			result_label.add_theme_color_override("font_color",
				DT.COLOR_GREEN_UP if success else DT.COLOR_RED_DOWN)
		_init_card_list()
		_update_detail_panel()
		_update_resource_labels()


func _on_enhancement_failed(card_id: String, reason: String) -> void:
	if card_id == selected_card_id:
		if result_label:
			result_label.text = reason
			result_label.add_theme_color_override("font_color", DT.COLOR_RED_DOWN)


func _on_nano_materials_changed(_old_value: int = 0, _new_value: int = 0) -> void:
	_update_resource_labels()
	_update_detail_panel()


func _update_resource_labels() -> void:
	var nano_amount: int = _get_nano_balance()
	var rp_amount: int = 0
	if BlueprintManager and BlueprintManager.has_method("get_research_points"):
		rp_amount = BlueprintManager.get_research_points()
	if nano_label:
		nano_label.text = "纳米材料 %d" % nano_amount
	if research_label:
		research_label.text = "研究点 %d" % rp_amount
	if alloy_label:
		var alloy: int = 0
		if BasicResourceManager and BasicResourceManager.has_method("get_total"):
			alloy = int(BasicResourceManager.get_total(BasicResources.ID_ALLOY))
		alloy_label.text = "合金 %d" % alloy


func _on_close() -> void:
	closed.emit()


## v9.x: 返回成长面板首页（关闭当前面板 + 打开成长面板）
func _on_back_to_growth() -> void:
	closed.emit()
	var main = get_node_or_null("/root/Main")
	if main and main.has_method("_toggle_overlay"):
		var overlay = main._overlay_for_panel_key("growth") if main.has_method("_overlay_for_panel_key") else null
		if overlay:
			main._toggle_overlay(overlay, "growth")


func _on_card_added_to_backpack(_card: CardResource) -> void:
	_init_card_list()
	_update_detail_panel()


# ============================================================
# 词条选择/升级弹窗（保留原逻辑，颜色更新到新签名色）
# ============================================================

func _show_module_selection_popup(card_id: String, enhance_level: int) -> void:
	# v9.x 修复：ModuleDefinitions 是 class_name 静态类（非 autoload），
	# 不能用 get_node_or_null("/root/ModuleDefinitions")，直接用类名调用静态方法。
	var available: Array = ModuleDefinitions.get_available_modules(enhance_level)
	if available.is_empty():
		return
	var overlay := _create_module_overlay("✦ 选择新词条", "强化至 Lv.%d，解锁新词条槽位，请选择一个词条：" % enhance_level)
	var list_box: VBoxContainer = overlay["list_box"]
	for module_id in available:
		var mid := String(module_id)
		var module_name: String = ModuleDefinitions.get_module_name(mid)
		var effect_key: String = ModuleDefinitions.get_effect_key(mid)
		var effect_type: String = ModuleDefinitions.get_effect_type(mid)
		var base_val: float = ModuleDefinitions.get_base_value(mid)
		var effect_desc: String = _format_module_effect(effect_key, base_val, effect_type)
		var btn := Button.new()
		btn.text = "%s  (%s)" % [module_name, effect_desc]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_override("font", DT.get_body_font())
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_stylebox_override("normal", PanelStyles.make_panel_style(
			DT.COLOR_BG_SLOT, DT.COLOR_AMBER_SOFT.darkened(0.2), 1, 5))
		btn.add_theme_color_override("font_color", DT.COLOR_TEXT)
		btn.add_theme_stylebox_override("hover", PanelStyles.make_panel_style(
			Color(DT.COLOR_AMBER.r, DT.COLOR_AMBER.g, DT.COLOR_AMBER.b, 0.15),
			DT.COLOR_AMBER_SOFT, 1, 5))
		btn.pressed.connect(_on_module_selected.bind(card_id, mid, overlay["root"]))
		list_box.add_child(btn)


func _show_module_upgrade_popup(card_id: String) -> void:
	var cem: Node = get_node_or_null("/root/CardEnhancementManager")
	if cem == null:
		return
	var slots: Array = cem.get_module_slots(card_id)
	if slots.is_empty():
		return
	var upgradable: Array = []
	for i in range(slots.size()):
		var s = slots[i]
		if s == null:
			continue
		var lvl: int = 1
		var mid: String = ""
		if s is Dictionary:
			mid = String(s.get("module_id", ""))
			lvl = int(s.get("level", 1))
		elif s is ModuleSlot:
			mid = String(s.module_id)
			lvl = int(s.level)
		if mid.is_empty() or lvl >= 3:
			continue
		upgradable.append({"slot_index": i, "module_id": mid, "level": lvl})
	if upgradable.is_empty():
		var msg := "所有词条均已满级，本次强化无可升级词条（强化等级已提升）"
		if result_label:
			result_label.text = msg
			result_label.add_theme_color_override("font_color", DT.COLOR_AMBER_SOFT)
		if SignalBus and SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit(msg)
		return
	var overlay := _create_module_overlay("↑ 升级词条", "本次强化可升级一个已有词条，请选择：")
	var list_box: VBoxContainer = overlay["list_box"]
	# v9.x 修复：ModuleDefinitions 是 class_name 静态类，直接用类名调用
	for u in upgradable:
		var mid: String = String(u["module_id"])
		var si: int = int(u["slot_index"])
		var old_lvl: int = int(u["level"])
		var module_name: String = ModuleDefinitions.get_module_name(mid)
		var btn := Button.new()
		btn.text = "%s  Lv.%d → Lv.%d" % [module_name, old_lvl, old_lvl + 1]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_override("font", DT.get_body_font())
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_stylebox_override("normal", PanelStyles.make_panel_style(
			DT.COLOR_BG_SLOT, DT.COLOR_CYAN_TECH_SOFT.darkened(0.3), 1, 5))
		btn.add_theme_color_override("font_color", DT.COLOR_TEXT)
		btn.add_theme_stylebox_override("hover", PanelStyles.make_panel_style(
			Color(DT.COLOR_CYAN_TECH.r, DT.COLOR_CYAN_TECH.g, DT.COLOR_CYAN_TECH.b, 0.15),
			DT.COLOR_CYAN_TECH_SOFT, 1, 5))
		btn.pressed.connect(_on_module_upgrade.bind(card_id, si, overlay["root"]))
		list_box.add_child(btn)


func _create_module_overlay(title_text: String, desc_text: String) -> Dictionary:
	# v9.x 修复：词条选择弹窗用独立 CanvasLayer（layer=110，高于 PopupLayer 的 100），
	# 彻底脱离强化面板（PanelContainer 被 CenterContainer 包裹会强制居中布局）的影响。
	# 之前用 Control + set_as_top_level + PRESET_FULL_RECT，三者与父节点布局管线时序冲突，
	# 导致弹窗 root 被推到 viewport 之外（看不到）。
	# 用 CanvasLayer 后：1) 永远在最上层 2) 不继承任何父节点变换 3) 永远铺满 viewport。
	var layer := CanvasLayer.new()
	layer.name = "_dyn_module_popup_layer"
	layer.layer = 110   # 高于 PopupLayer(100)，确保盖住强化面板自身
	add_child(layer)
	# CanvasLayer 下挂一个 Control 铺满 viewport，承载遮罩 + 中央面板
	var root := Control.new()
	root.name = "_dyn_module_popup"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	# 暗色遮罩
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	# 中央面板
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	panel.add_theme_stylebox_override("panel", PanelStyles.make_panel_style(
		DT.COLOR_BG_CARD, DT.COLOR_AMBER_SOFT, 2, 8,
		Color(DT.COLOR_AMBER.r, DT.COLOR_AMBER.g, DT.COLOR_AMBER.b, 0.25), 8))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	# 标题
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", DT.get_title_font_bold())
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", DT.COLOR_AMBER)
	vbox.add_child(title)
	# 描述
	var desc := Label.new()
	desc.text = desc_text
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_override("font", DT.get_body_font())
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)
	# 滚动列表
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 240)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var list_box := VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(list_box)
	# 跳过按钮
	var skip_btn := Button.new()
	skip_btn.text = "稍后再选（词条槽位保留为空）"
	skip_btn.add_theme_font_override("font", DT.get_body_font())
	skip_btn.add_theme_font_size_override("font_size", 12)
	skip_btn.add_theme_stylebox_override("normal", PanelStyles.make_panel_style(
		DT.COLOR_BG_SLOT, DT.COLOR_BORDER_DIM, 1, 4))
	skip_btn.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	skip_btn.pressed.connect(_close_module_popup.bind(layer))
	vbox.add_child(skip_btn)
	return {"root": layer, "list_box": list_box}


func _on_module_selected(card_id: String, module_id: String, popup_root: Node) -> void:
	var cem: Node = get_node_or_null("/root/CardEnhancementManager")
	if cem and cem.has_method("choose_module"):
		var r: Dictionary = cem.choose_module(card_id, module_id)
		if r.get("ok", false):
			_close_module_popup(popup_root)
			if result_label:
				result_label.text = "词条已装配：" + String(r.get("module_name", module_id))
				result_label.add_theme_color_override("font_color", DT.COLOR_GREEN_UP)
			_update_detail_panel()
		else:
			if result_label:
				result_label.text = "装配失败：" + String(r.get("reason", ""))
				result_label.add_theme_color_override("font_color", DT.COLOR_RED_DOWN)


func _on_module_upgrade(card_id: String, slot_index: int, popup_root: Node) -> void:
	var cem: Node = get_node_or_null("/root/CardEnhancementManager")
	if cem and cem.has_method("upgrade_module"):
		var r: Dictionary = cem.upgrade_module(card_id, slot_index)
		if r.get("ok", false):
			_close_module_popup(popup_root)
			if result_label:
				result_label.text = "词条升级：" + String(r.get("module_name", ""))
				result_label.add_theme_color_override("font_color", DT.COLOR_GREEN_UP)
			_update_detail_panel()
		else:
			if result_label:
				result_label.text = "升级失败：" + String(r.get("reason", ""))
				result_label.add_theme_color_override("font_color", DT.COLOR_RED_DOWN)


func _close_module_popup(popup_root: Node) -> void:
	if popup_root:
		popup_root.queue_free()


func _format_module_effect(effect_key: String, base_val: float, effect_type: String) -> String:
	# 简化版：直接拼接（ModEffectLabels 是 class_name 静态类，无法 has_method 检测，
	# 后续可改为查找其具体静态方法名）
	return "%s +%.0f%%" % [effect_key, base_val * 100.0]
