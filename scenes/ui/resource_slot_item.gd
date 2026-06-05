extends PanelContainer
class_name ResourceSlotItem
## 背包网格中的槽位控件：情报页、属性提升等（基础资源仅由左上角资源面板等展示，不再占用背包格）。

const BasicResources = preload("res://data/basic_resources.gd")

const SLOT_SIZE: Vector2 = PhaseSlot.SLOT_SIZE

## 槽位类型
enum SlotType {
	RESOURCE,       # 基础资源
	LORE,           # 情报页
	STAT_BOOST,     # 属性提升
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
	var vbox = get_node_or_null("VBox")
	if vbox:
		vbox.custom_minimum_size = SLOT_SIZE
	var icon_rect: TextureRect = get_node_or_null("VBox/Icon") as TextureRect
	if icon_rect:
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER

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
		name_label.text = display_name.substr(0, 6)  # 限制长度
	if amount_label:
		amount_label.text = ""
	if icon_rect:
		# 情报使用金色图标
		icon_rect.modulate = Color(0.8, 0.6, 0.2, 1.0)
		# 如果有自定义图标，尝试加载
		if not custom_icon.is_empty() and ResourceLoader.exists(custom_icon):
			icon_rect.texture = load(custom_icon)

## 刷新属性提升显示
func _refresh_stat_boost(boost_id: String, count: int, name_label: Label, amount_label: Label, icon_rect: TextureRect) -> void:
	display_name = _get_boost_display_name(boost_id)
	description = _get_boost_description(boost_id)

	if name_label:
		name_label.text = display_name.substr(0, 6)
	if amount_label:
		amount_label.text = "Lv.%d" % count
	if icon_rect:
		# 属性提升使用橙色图标
		icon_rect.modulate = Color(1.0, 0.5, 0.0, 1.0)

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

## 获取悬停提示文本
func _get_slot_tooltip_text() -> String:
	match slot_type:
		SlotType.RESOURCE:
			return "%s\n基础资源" % display_name
		SlotType.LORE:
			return "%s\n%s" % [display_name, description]
		SlotType.STAT_BOOST:
			return "%s\n%s\n当前层数: %d" % [display_name, description, amount]
		_:
			return display_name
