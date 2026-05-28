extends Resource
class_name CardResource
## 单张卡片数据：战斗卡 / 能量卡 / 法则卡（三种卡统一模型）
##
## v3 重构：不再区分平台卡/武器卡/合成卡，武器是战斗卡的内嵌属性。
## 100种敌人卡是数据基础，每张卡自带完整属性。

const GC = preload("res://resources/game_constants.gd")

# ─────────────────────────────────────────────
#  通用字段（三种卡共有）
# ─────────────────────────────────────────────

@export var card_id: String = ""
@export var display_name: String = ""
@export var description: String = ""  # 详细规则文本
@export var card_type: int = 0  # GameConstants.CardType：COMBAT_UNIT=0, ENERGY=1, LAW=2
@export var energy_cost: float = 5.0

# 展示用扩展字段
@export_enum("common", "uncommon", "rare", "legendary") var rarity: String = "common"
@export var type_line: String = ""      # 牌面类型行：如"战斗卡 — 装甲／坦克"
@export var summary_line: String = ""   # 上半行数值摘要：如"攻击 14｜射程 长｜耐久 110"
@export var flavor_text: String = ""    # 斜体风味文字

# ─────────────────────────────────────────────
#  战斗卡专用字段（card_type == COMBAT_UNIT）
# ─────────────────────────────────────────────

## 时代（GameConstants.Era：WW1=0 .. NEAR_FUTURE=4）
@export var era: int = 0

## 战斗定位（0=轻装/1=装甲/2=支援/3=空中）
@export var combat_kind: int = 0

## 战力（进化门槛用，v3新增）
@export var power: int = 0

## 基础生命值
@export var base_hp: float = 100.0

## 攻击速度（次/秒，v3新增，替代base_interval）
@export var attack_speed: float = 1.0

## 基础攻击射程（格，v3新增，替代base_range）
@export var range_value: int = 3

## 基础移动速度（0=固定不动）
@export var base_speed: float = 80.0

## 武器外观标签（纯显示用，如"步枪"、"机枪"、"迫击炮"）
@export var weapon_label: String = ""

## 武器类型（GameConstants.WeaponType：DIRECT=0, INDIRECT=1, AERIAL=2）
@export var weapon_type: int = 0

## 部署速度（0-7，越大越快进入战场）
@export var deploy_speed: int = 3

## 攻击维度（对不同类型单位的伤害）
@export var attack_light: float = 0.0   # 对轻装
@export var attack_armor: float = 0.0   # 对装甲
@export var attack_air: float = 0.0     # 对空中

## 防御维度（对不同武器类型的防御）
@export var defense_light: float = 0.0  # 防轻装武器
@export var defense_armor: float = 0.0  # 防装甲武器
@export var defense_air: float = 0.0    # 防空武器

## 多武器槽（每项 Dictionary：damage, range, interval, timer）
## 空数组=单武器模式，使用 base_damage/base_range/base_interval
var multi_weapons: Array = []

# ─────────────────────────────────────────────
#  能量卡专用字段（card_type == ENERGY）
# ─────────────────────────────────────────────

## 使用后获得的能量
@export var energy_grant: float = 15.0

# ─────────────────────────────────────────────
#  法则卡专用字段（card_type == LAW）
# ─────────────────────────────────────────────

## 对应 PhaseLaws 的 id（与 card_id 一致时可不填，装配时回退到 card_id）
@export var linked_law_id: String = ""

# ─────────────────────────────────────────────
#  通用辅助字段
# ─────────────────────────────────────────────

# 词条槽位：运行时词条由 AffixManager 管理，此处仅记录词条 ID 列表用于 UI 快速查询
# 不要直接修改此字段，使用 AffixManager 的接口操作词条
@export var affix_slot_ids: Array = []  # Array[String]：当前词条 ID 列表（只读镜像）
@export var affix_slot_count: int = 4   # 该卡允许的最大词条数（默认4）

# 卡片来源标记：true=战斗掉落成品卡，false=蓝图制造卡
@export var is_dropped_card: bool = false

# 星级（1~9）：制造卡=蓝图星级，掉落卡=掉落时确定的固定星级
@export var star_level: int = 1


# ─────────────────────────────────────────────
#  旧字段兼容（渐进弃用，读取时自动迁移）
# ─────────────────────────────────────────────

## @deprecated 旧平台类型，仅供存档迁移读取，新代码不要写入
@export var platform_type: int = -1  # 旧 GameConstants.PlatformType

## @deprecated 旧武器类型，仅供存档迁移读取，新代码使用 weapon_type 字段存储新枚举值
@export var legacy_weapon_type: int = -1  # 旧 GameConstants.WeaponType

## @deprecated 旧默认武器类型
@export var default_weapon_type: int = -1

## @deprecated 旧合成卡来源追踪
@export var source_platform_id: String = ""
@export var source_weapon_ids: Array = []

## @deprecated 旧平台卡字段
@export var max_weapons: int = 1
@export var weight_capacity: int = 0
@export var weight: int = 0
@export var multi_weapon_types: Array = []


## 从旧字段自动迁移到新字段（存档加载后调用）
func migrate_from_legacy() -> void:
	# 如果新字段已有值（非默认），说明已迁移过
	if era > 0 or base_hp != 100.0 or combat_kind != 0:
		return
	# 从旧的 card_type 迁移：PLATFORM/COMBINED → COMBAT_UNIT
	if card_type == 3 or card_type == 5:  # PLATFORM or COMBINED
		card_type = 0  # COMBAT_UNIT


# ─────────────────────────────────────────────
#  显示信息方法
# ─────────────────────────────────────────────

## 战斗定位中文名称
static func get_combat_kind_name(kind: int) -> String:
	match kind:
		0: return "轻装"
		1: return "装甲"
		2: return "支援"
		3: return "空中"
		_: return "未知"

## 战斗定位简短名称
static func get_combat_kind_short(kind: int) -> String:
	match kind:
		0: return "轻"
		1: return "甲"
		2: return "援"
		3: return "空"
		_: return "?"

## 获取形状标识（用于 UI 图标）
func get_shape_key() -> String:
	if card_type == GC.CardType.COMBAT_UNIT:
		return get_combat_kind_short(combat_kind)
	if card_type == GC.CardType.ENERGY:
		return "energy"
	if card_type == GC.CardType.LAW:
		return "law"
	return "unknown"

## 获取卡片类型的中文名称
func get_card_type_name() -> String:
	if GC:
		return GC.get_card_type_name(card_type)
	return "未知卡片"

## 获取子类型中文名称
func get_subtype_name() -> String:
	if card_type == GC.CardType.COMBAT_UNIT:
		return get_combat_kind_name(combat_kind)
	return ""

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
		"flavor_text": flavor_text,
	}

## 获取卡片的简短描述（用于列表显示）
func get_short_description() -> String:
	if not summary_line.is_empty():
		return summary_line
	if card_type == GC.CardType.COMBAT_UNIT:
		var total_attack = attack_light + attack_armor + attack_air
		return "攻击 %d｜耐久 %d" % [int(total_attack), int(base_hp)]
	return ""

## 检查卡片是否可以装备到指定平台
func can_equip_on(platform: CardResource) -> bool:
	return false

## 获取卡片的详细属性文本（用于UI显示）
func get_attributes_text() -> String:
	var attrs: Array = []

	if card_type == GC.CardType.COMBAT_UNIT:
		attrs.append("对轻装: %.0f" % attack_light)
		attrs.append("对装甲: %.0f" % attack_armor)
		attrs.append("对空中: %.0f" % attack_air)
		attrs.append("射程: %.0f" % range_value)
		attrs.append("耐久: %.0f" % base_hp)
		attrs.append("防轻装: %.0f" % defense_light)
		attrs.append("防装甲: %.0f" % defense_armor)
		attrs.append("防空: %.0f" % defense_air)
		if not weapon_label.is_empty():
			attrs.append("武器: %s" % weapon_label)
	elif card_type == GC.CardType.ENERGY:
		attrs.append("能量提供: %.1f" % energy_grant)

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
	# 战斗卡字段
	new_card.era = era
	new_card.combat_kind = combat_kind
	new_card.base_hp = base_hp
	new_card.range_value = range_value
	new_card.attack_speed = attack_speed
	new_card.base_speed = base_speed
	new_card.weapon_label = weapon_label
	new_card.weapon_type = weapon_type
	new_card.deploy_speed = deploy_speed
	new_card.attack_light = attack_light
	new_card.attack_armor = attack_armor
	new_card.attack_air = attack_air
	new_card.defense_light = defense_light
	new_card.defense_armor = defense_armor
	new_card.defense_air = defense_air
	new_card.multi_weapons = multi_weapons.duplicate(true)
	# 能量卡字段
	new_card.energy_grant = energy_grant
	# 法则卡字段
	new_card.linked_law_id = linked_law_id
	# 通用辅助
	new_card.affix_slot_ids = affix_slot_ids.duplicate()
	new_card.affix_slot_count = affix_slot_count
	new_card.is_dropped_card = is_dropped_card
	new_card.star_level = star_level
	# 旧字段（兼容）
	new_card.platform_type = platform_type
	new_card.legacy_weapon_type = legacy_weapon_type
	new_card.default_weapon_type = default_weapon_type
	new_card.source_platform_id = source_platform_id
	new_card.source_weapon_ids = source_weapon_ids.duplicate()
	new_card.max_weapons = max_weapons
	new_card.weight_capacity = weight_capacity
	new_card.weight = weight
	new_card.multi_weapon_types = multi_weapon_types.duplicate()
	return new_card

## 验证卡片数据的完整性
func validate() -> bool:
	if card_id.is_empty():
		return false
	if display_name.is_empty():
		return false
	if card_type == GC.CardType.COMBAT_UNIT:
		if base_hp <= 0.0:
			return false
		if attack_light <= 0.0 and attack_armor <= 0.0 and attack_air <= 0.0:
			return false
	return true
