extends Resource
class_name CardResource
## 单张卡片数据：平台卡 / 武器卡 / 能量卡

const GC = preload("res://resources/game_constants.gd")

@export var card_id: String = ""
@export var display_name: String = ""
@export var description: String = ""  # 详细规则文本
@export var card_type: int = 0  # GameConstants.CardType
@export var energy_cost: float = 5.0

# 展示用扩展字段
@export_enum("common", "uncommon", "rare", "legendary") var rarity: String = "common"
@export var type_line: String = ""      # 牌面类型行：如“平台 — 猎犬／侦察骚扰”
@export var summary_line: String = ""   # 上半行数值摘要：如“移速 120｜耐久 60”
@export var flavor_text: String = ""    # 斜体风味文字

# 平台卡专用
@export var platform_type: int = -1  # GameConstants.PlatformType
@export var max_weapons: int = 1     # 该平台最多可同时挂载的武器数量
@export var weight_capacity: int = 0 # 该平台可承载的总武器重量（0 表示使用默认推导）
@export var default_weapon_type: int = -1  # GameConstants.WeaponType：无武器模式下的默认武器（-1=未设置，回退到 RIFLE）

# 武器卡专用
@export var weapon_type: int = -1    # GameConstants.WeaponType
@export var weight: int = 0          # 武器自身重量（用于平台承载校验）

# 合成卡专用：多武器组合时所包含的所有武器类型（包括主武器）
@export var multi_weapon_types: Array = []

# 能量卡专用：使用后获得的能量
@export var energy_grant: float = 15.0

# 词条槽位：运行时词条由 AffixManager 管理，此处仅记录词条 ID 列表用于 UI 快速查询
# 不要直接修改此字段，使用 AffixManager 的接口操作词条
@export var affix_slot_ids: Array = []  # Array[String]：当前词条 ID 列表（只读镜像）
@export var affix_slot_count: int = 4   # 该卡允许的最大词条数（默认4）

# 合成卡专用：存储原始平台卡和武器卡的ID，用于追踪独立经验和强化
@export var source_platform_id: String = ""       # 合成卡的原始平台卡ID
@export var source_weapon_ids: Array = []        # 合成卡的原始武器卡ID列表

# 法则卡：对应 PhaseLaws 的 id（与 card_id 一致时可不填，装配时回退到 card_id）
@export var linked_law_id: String = ""

# 卡片来源标记：true=战斗掉落成品卡，false=蓝图制造卡
@export var is_dropped_card: bool = false

# 星级（1~9）：制造卡=蓝图星级，掉落卡=掉落时确定的固定星级
@export var star_level: int = 1

# 形状标识（用于 UI 图标）
# 静态映射表，避免重复的 match 语句
static var _platform_shape_map: Dictionary = {
	GC.PlatformType.HOUND: "hound",
	GC.PlatformType.GUARD: "guard",
	GC.PlatformType.TITAN: "titan",
	GC.PlatformType.FORTRESS: "fortress",
	GC.PlatformType.RADAR: "radar",
	GC.PlatformType.SCOUT: "scout",
	GC.PlatformType.RAIDER: "raider",
	GC.PlatformType.SIEGE: "siege",
	GC.PlatformType.CARRIER: "carrier",
	GC.PlatformType.MEDIC: "medic",
	GC.PlatformType.STEALTH: "stealth",
	GC.PlatformType.OMEGA_PLATFORM: "omega_platform",
}

func get_shape_key() -> String:
	if card_type == GC.CardType.PLATFORM:
		return _platform_shape_map.get(platform_type, "unknown")
	if card_type == GC.CardType.ENERGY:
		return "energy"
	if card_type == GC.CardType.COMBINED:
		# 无武器版：合成卡回退到平台图标，避免依赖 platform_weapon 组合图。
		return _platform_shape_map.get(platform_type, "unknown")
	if card_type == GC.CardType.LAW:
		return "law"
	return "unknown"

# ─────────────────────────────────────────────
#  显示信息方法
# ─────────────────────────────────────────────

## 获取卡片类型的中文名称
func get_card_type_name() -> String:
	if GC:
		return GC.get_card_type_name(card_type)
	return "未知卡片"

## 获取平台/武器类型的中文名称
func get_subtype_name() -> String:
	if GC == null:
		return "未知"

	if card_type == GC.CardType.PLATFORM:
		return GC.get_platform_type_name(platform_type)
	return "未知"

## 获取完整的类型行显示（用于UI）
## 格式：卡片类型 — 子类型名称
func get_full_type_line() -> String:
	var card_type_str: String = get_card_type_name()
	var subtype_str: String = get_subtype_name()

	if not subtype_str.is_empty() and subtype_str != "未知":
		return "%s — %s" % [card_type_str, subtype_str]
	return card_type_str

## 获取稀有度的颜色
func get_rarity_color() -> Color:
	if GC:
		return GC.get_rarity_color(rarity)
	return Color(0.75, 0.75, 0.75, 1.0)

## 获取格式化的稀有度显示（带颜色BBCode）
func get_formatted_rarity() -> String:
	var color: Color = get_rarity_color()
	var rarity_name: String = _get_rarity_display_name()
	return "[color=#%s]%s[/color]" % [color.to_html(), rarity_name]

## 获取稀有度显示名称
func _get_rarity_display_name() -> String:
	if GC:
		return GC.get_rarity_name(rarity)
	match rarity:
		"common":    return "普通"
		"uncommon":  return "优秀"
		"rare":      return "稀有"
		"epic":      return "史诗"
		"legendary": return "传说"
		_:           return "普通"

## 获取卡片的完整显示信息（用于tooltip等）
func get_display_info() -> Dictionary:
	return {
		"card_id": card_id,
		"display_name": display_name,
		"card_type_name": get_card_type_name(),
		"subtype_name": get_subtype_name(),
		"full_type_line": get_full_type_line(),
		"rarity_name": _get_rarity_display_name(),
		"rarity_color": get_rarity_color(),
		"energy_cost": energy_cost,
		"description": description,
		"type_line": type_line if not type_line.is_empty() else get_full_type_line(),
		"summary_line": summary_line,
		"flavor_text": flavor_text
	}

## 获取卡片的简短描述（用于列表显示）
func get_short_description() -> String:
	if not summary_line.is_empty():
		return summary_line
	var parts: Array = []
	if card_type == GC.CardType.PLATFORM:
		parts.append("重量: %d" % weight_capacity)
		parts.append("槽位: %d" % max_weapons)
	return " | ".join(parts)

## 检查卡片是否可以装备到指定平台
func can_equip_on(platform: CardResource) -> bool:
	return false

## 获取卡片的详细属性文本（用于UI显示）
func get_attributes_text() -> String:
	var attrs: Array = []

	if card_type == GC.CardType.PLATFORM:
		attrs.append("重量承载: %d" % weight_capacity)
		attrs.append("武器槽位: %d" % max_weapons)
	elif card_type == GC.CardType.ENERGY:
		attrs.append("能量提供: %.1f" % energy_grant)
	elif card_type == GC.CardType.COMBINED:
		attrs.append("来源平台: %s" % source_platform_id)
		attrs.append("武器数量: %d" % source_weapon_ids.size())

	return "\n".join(attrs)

## 克隆卡片数据（用于创建副本）
func clone() -> CardResource:
	var new_card = CardResource.new()
	new_card.card_id = card_id
	new_card.display_name = display_name
	new_card.description = description
	new_card.card_type = card_type
	new_card.energy_cost = energy_cost
	new_card.rarity = rarity
	new_card.type_line = type_line
	new_card.summary_line = summary_line
	new_card.flavor_text = flavor_text
	new_card.platform_type = platform_type
	new_card.max_weapons = max_weapons
	new_card.weight_capacity = weight_capacity
	new_card.default_weapon_type = default_weapon_type
	new_card.weapon_type = weapon_type
	new_card.weight = weight
	new_card.multi_weapon_types = multi_weapon_types.duplicate()
	new_card.energy_grant = energy_grant
	new_card.affix_slot_ids = affix_slot_ids.duplicate()
	new_card.affix_slot_count = affix_slot_count
	new_card.source_platform_id = source_platform_id
	new_card.source_weapon_ids = source_weapon_ids.duplicate()
	new_card.linked_law_id = linked_law_id
	new_card.is_dropped_card = is_dropped_card
	new_card.star_level = star_level
	return new_card

## 验证卡片数据的完整性
func validate() -> bool:
	if card_id.is_empty():
		return false
	if display_name.is_empty():
		return false
	if card_type == GC.CardType.PLATFORM:
		if platform_type < 0:
			return false
		if max_weapons < 1:
			return false
	return true
