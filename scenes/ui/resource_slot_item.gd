extends PanelContainer
class_name ResourceSlotItem
## 背包网格中的槽位控件：情报页、属性提升、符文等（基础资源仅由左上角资源面板等展示，不再占用背包格）。
##
## v6.2: RUNE 类型支持点击——背包符文标签点击格子触发 rune_clicked 信号，
## 由 backpack_panel 接收后装备/卸下符文。

const BasicResources = preload("res://data/basic_resources.gd")

## 槽位尺寸（与PhaseSlot.SLOT_SIZE保持一致）
const SLOT_SIZE: Vector2 = Vector2(50, 80)

## v6.2: 符文格子被点击时发射，参数为 rune_id
signal rune_clicked(rune_id: String)

## 槽位类型
enum SlotType {
	RESOURCE,       # 基础资源
	LORE,           # 情报页
	STAT_BOOST,     # 属性提升
	RUNE,           # v6.2: 符文（依赖 extra_data 提供名称/描述/颜色，可点击）
}

var slot_type: SlotType = SlotType.RESOURCE
var resource_id: String = ""
var amount: int = 0
var display_name: String = ""
var description: String = ""

func _ready() -> void:
	clip_contents = true
	custom_minimum_size = SLOT_SIZE
	size_flags_horizontal = 0
	size_flags_vertical = 0
	# v6.2: 符文格子需要接收鼠标点击；默认 mouse_filter 已为 STOP（PanelContainer 默认），
	# 但显式确认避免被主题覆盖。仅 RUNE 类型连接 gui_input。
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	# v6.7 修复：节点路径前缀缺 "Margin/"，导致 VBox/Icon 尺寸初始化全部被跳过，
	# TextureRect 宽度坍缩为 0，符文图标不可见（texture 已正确加载但无渲染区域）
	var vbox = get_node_or_null("Margin/VBox")
	if vbox:
		vbox.custom_minimum_size = SLOT_SIZE
	var icon_rect: TextureRect = get_node_or_null("Margin/VBox/Icon") as TextureRect
	if icon_rect:
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER

## v6.2: 仅 RUNE 类型响应左键点击，发射 rune_clicked 信号
func _on_gui_input(event: InputEvent) -> void:
	if slot_type != SlotType.RUNE:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			rune_clicked.emit(resource_id)

## 设置数据 - 支持多种掉落类型
func set_data(id: String, stack_amount: int, type: SlotType = SlotType.RESOURCE, extra_data: Dictionary = {}) -> void:
	resource_id = id
	amount = max(0, stack_amount)
	slot_type = type

	var name_label: Label = get_node_or_null("Margin/VBox/NameLabel")
	var amount_label: Label = get_node_or_null("Margin/VBox/AmountLabel")
	var icon_rect: TextureRect = get_node_or_null("Margin/VBox/Icon")

	# 保存额外数据（包含图标路径和名称）
	description = extra_data.get("description", "")
	var custom_icon: String = extra_data.get("icon", "")
	var custom_name: String = extra_data.get("name", "")

	match slot_type:
		SlotType.RESOURCE:
			_refresh_resource(id, name_label, amount_label, icon_rect)
		SlotType.LORE:
			_refresh_lore(id, stack_amount, name_label, amount_label, icon_rect, custom_icon, custom_name)
		SlotType.STAT_BOOST:
			_refresh_stat_boost(id, stack_amount, name_label, amount_label, icon_rect)
		SlotType.RUNE:
			_refresh_rune(id, stack_amount, name_label, amount_label, icon_rect, extra_data)

## 刷新资源显示
func _refresh_resource(id: String, name_label: Label, amount_label: Label, icon_rect: TextureRect) -> void:
	var def: Dictionary = BasicResources.get_def(id)
	display_name = def.get("name", id)
	var icon_path: String = def.get("icon", "")

	if name_label:
		name_label.text = display_name
	if amount_label:
		amount_label.text = "%d / %d" % [amount, BasicResources.STACK_SIZE]
	if icon_rect and icon_path != "":
		if ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)
		else:
			icon_rect.texture = null

## 刷新情报显示
func _refresh_lore(lore_id: String, count: int, name_label: Label, amount_label: Label, icon_rect: TextureRect, custom_icon: String = "", custom_name: String = "") -> void:
	var lm = get_node_or_null("/root/LoreManager")

	# 优先使用自定义名称（用于蓝图物品）
	if not custom_name.is_empty():
		display_name = custom_name
	else:
		# 回退到 LoreManager
		if lm and lm.has_method("get_lore_data"):
			var lore_data = lm.get_lore_data(lore_id)
			display_name = lore_data.get("name", "情报资料")
			if description.is_empty():
				description = lore_data.get("description", "")
		else:
			display_name = _get_lore_default_name(lore_id)
			if description.is_empty():
				description = "通过战斗获得的情报资料。"

	if name_label:
		var max_name_len := 12 if slot_type == SlotType.LORE else 6
		name_label.text = _truncate_with_ellipsis(display_name, max_name_len)
	if amount_label:
		amount_label.text = ""
	if icon_rect:
		# 情报使用金色图标（无贴图时的默认染色）
		icon_rect.modulate = Color(0.8, 0.6, 0.2, 1.0)
		# 如果有自定义图标，尝试加载（背包"改造"标签依赖此分支显示改造图标）
		if not custom_icon.is_empty() and ResourceLoader.exists(custom_icon, "Texture2D"):
			icon_rect.texture = load(custom_icon)
			# 加载了真实贴图后恢复原色（贴图自身已有颜色，金色 modulate 会让它偏黄失真）
			icon_rect.modulate = Color.WHITE
			# v6.14 修复：_ready 默认 EXPAND_IGNORE_SIZE + SHRINK_CENTER + 无最小尺寸
			# 会让 TextureRect 宽度坍缩为 0，贴图加载成功却不可见（与 _refresh_rune 同类 bug）。
			# 切到 EXPAND_FIT_WIDTH 并给最小尺寸，确保有渲染区域。
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.custom_minimum_size = Vector2(36, 32)
			icon_rect.visible = true

## 刷新属性提升显示
func _refresh_stat_boost(boost_id: String, count: int, name_label: Label, amount_label: Label, icon_rect: TextureRect) -> void:
	display_name = _get_boost_display_name(boost_id)
	description = _get_boost_description(boost_id)

	if name_label:
		# 属性提升名称截断到 6 字符
		name_label.text = _truncate_with_ellipsis(display_name, 6)
	if amount_label:
		amount_label.text = "Lv.%d" % count
	if icon_rect:
		# 属性提升使用橙色图标
		icon_rect.modulate = Color(1.0, 0.5, 0.0, 1.0)

## v6.2: 刷新符文显示——名称/描述/颜色全部来自 extra_data（由 backpack_panel._add_rune_item 准备）
func _refresh_rune(rune_id: String, count: int, name_label: Label, amount_label: Label, icon_rect: TextureRect, extra_data: Dictionary) -> void:
	# 优先使用 extra_data 提供的显示名（含"✓ 已装备"标记），否则回退到 rune_id
	var custom_name: String = extra_data.get("name", "")
	if not custom_name.is_empty():
		display_name = custom_name
	else:
		display_name = rune_id
	# 描述同样优先用 extra_data
	var custom_desc: String = extra_data.get("description", "")
	if not custom_desc.is_empty():
		description = custom_desc

	if name_label:
		# 符文名允许较长（最多8字符），避免"神盾壁垒"等被截断
		name_label.text = _truncate_with_ellipsis(display_name, 8)
		# 稀有度颜色染色：让符文名一眼可辨稀有度
		var rune_color: Color = extra_data.get("rune_color", Color(0.85, 0.85, 0.85))
		name_label.add_theme_color_override("font_color", rune_color)
	if amount_label:
		# 符文数量通常为1，仅在 >1 时显示数量
		if count > 1:
			amount_label.text = "×%d" % count
		else:
			amount_label.text = ""
	if icon_rect:
		# 符文用稀有度颜色染色图标，无贴图时仅靠颜色区分
		var icon_color: Color = extra_data.get("rune_color", Color(0.75, 0.45, 0.95))
		icon_rect.modulate = icon_color
		# v6.2: 加载符文专属图标贴图（优先用 extra_data 传入的 icon 路径，否则按 rune_id 查找）
		# 贴图缺失时保持现状（仅颜色染色），不退化
		var rune_tex: Texture2D = null
		var icon_path: String = String(extra_data.get("icon", ""))
		if not icon_path.is_empty():
			if ResourceLoader.exists(icon_path, "Texture2D"):
				rune_tex = load(icon_path)
		else:
			var UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
			rune_tex = UiAssetLoader.rune_icon(rune_id)
		if rune_tex != null:
			icon_rect.texture = rune_tex
			# v6.7 修复：EXPAND_IGNORE_SIZE 会让 TextureRect 忽略纹理固有尺寸，
			# 在 SHRINK_CENTER + custom_minimum_size.x=0 下宽度坍缩为 0，图标不可见。
			# 改用 EXPAND_FIT_WIDTH + 给一个最小宽度，确保有渲染区域。
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.custom_minimum_size = Vector2(36, 32)
			icon_rect.visible = true

## 获取情报默认名称
func _get_lore_default_name(lore_id: String) -> String:
	match lore_id:
		"lore_ww1_trench": return "堑壕战术手册"
		"lore_ww2_blitzkrieg": return "闪电战档案"
		"lore_cold_berlin": return "柏林墙日记"
		"lore_modern_drone": return "无人机作战手册"
		"lore_future_phase": return "相位技术纲要"
		_: return "情报资料"

## 获取属性提升显示名称
func _get_boost_display_name(boost_id: String) -> String:
	match boost_id:
		"stat_boost_hp": return "生命强化"
		"stat_boost_damage": return "攻击强化"
		"stat_boost_speed": return "速度强化"
		"stat_boost_defense": return "防御强化"
		"stat_boost_attack_speed": return "攻速强化"
		"stat_boost_crit": return "暴击强化"
		"stat_boost_crit_damage": return "暴伤强化"
		_: return "属性提升"

## 获取属性提升描述
func _get_boost_description(boost_id: String) -> String:
	match boost_id:
		"stat_boost_hp": return "单位最大生命值 +5%"
		"stat_boost_damage": return "单位造成的伤害 +3%"
		"stat_boost_speed": return "单位移动速度 +4%"
		"stat_boost_defense": return "单位受到的伤害 -3%"
		"stat_boost_attack_speed": return "单位攻击速度 +5%"
		"stat_boost_crit": return "单位暴击率 +2%"
		"stat_boost_crit_damage": return "单位暴击伤害 +10%"
		_: return "提升单位属性"

## v6.2 修复 L2：字符串超长截断并加省略号（原 substr 直接截断无提示，中文可能切掉半个词）
func _truncate_with_ellipsis(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, max_len) + "…"

## 获取悬停提示文本
func _get_slot_tooltip_text() -> String:
	match slot_type:
		SlotType.RESOURCE:
			return "%s\n基础资源" % display_name
		SlotType.LORE:
			return "%s\n%s" % [display_name, description]
		SlotType.STAT_BOOST:
			return "%s\n%s\n当前层数: %d" % [display_name, description, amount]
		SlotType.RUNE:
			return "%s\n%s" % [display_name, description]
		_:
			return display_name
