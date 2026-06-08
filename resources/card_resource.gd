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
@export_enum("common", "uncommon", "rare", "epic", "legendary", "mythic") var rarity: String = "common"
@export var type_line: String = ""      # 牌面类型行：如"战斗卡 — 装甲／坦克"
@export var summary_line: String = ""   # 上半行数值摘要：如"攻击 14｜射程 长｜耐久 110"
@export var flavor_text: String = ""    # 斜体风味文字

## v6.0: 标签系统（用于分类和筛选）
@export var tags: Array[String] = []    # 卡片标签：如["步兵", "反坦克", "突击"]

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
## @deprecated v5.0: 使用 per-target attack_X_speed 替代
## 保留此字段作为兼容后备（读取时若 per-target speed 为0则回退到此值）
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

## v5.0: 每种攻击目标独立的攻速参数
## 对轻装攻击参数
@export var attack_light_speed: float = 1.0   # 次/秒
@export var attack_light_windup: float = 0.2    # 前摇（秒）
@export var attack_light_active: float = 0.1    # 动作（秒）

## 对装甲攻击参数
@export var attack_armor_speed: float = 1.0   # 次/秒
@export var attack_armor_windup: float = 0.2  # 前摇（秒）
@export var attack_armor_active: float = 0.1   # 动作（秒）

## 对空中攻击参数
@export var attack_air_speed: float = 1.0   # 次/秒
@export var attack_air_windup: float = 0.2   # 前摇（秒）
@export var attack_air_active: float = 0.1    # 动作（秒）

## 防御维度（对不同武器类型的防御）
@export var defense_light: float = 0.0  # 防轻装武器
@export var defense_armor: float = 0.0  # 防装甲武器
@export var defense_air: float = 0.0    # 防空武器

## 多武器槽（每项 Dictionary：damage, range, interval, timer）
## 空数组=单武器模式，使用 base_damage/base_range/base_interval

# ─────────────────────────────────────────────
#  势力变体元数据（运行时，非序列化）
# ─────────────────────────────────────────────

## 势力ID（空字符串=非变体）
var faction_id: String = ""
## 势力等级（0=非变体，1-10）
var faction_level: int = 0
## 原始基础卡ID（空字符串=非变体）
var base_card_id: String = ""
## 是否为势力变体
var is_faction_variant: bool = false
var is_faction_exclusive: bool = false
var is_faction_hybrid: bool = false
var hybrid_second_faction: String = ""
var multi_weapons: Array = []

## 武器槽位名称（3个槽位：轻装/装甲/对空）
## 每项为具体武器名（如"MP18冲锋枪"），空字符串表示无武器
var weapon_names: Array[String] = ["", "", ""]

## 武器槽位数组（3个槽位：轻装/装甲/对空）
## 每个槽位可装配独立的 WeaponResource，可为空（enabled=false）
var weapon_slots: Array = []

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
#  v5.0 养成字段（运行时状态，不序列化为@export）
# ─────────────────────────────────────────────

## 强化等级 0-10（v5.0 替代旧 star_level；star_level 已废弃见 L160）
var enhance_level: int = 0

## 改造ID列表（最多9个 MOD_XX）
var mods: Array = []

## 可进化目标卡ID列表
var evolution_paths: Array = []

## 进化阶段 0=E0, 1=E1, 2=E2, 3=E3
var evolution_stage: int = 0

## 情报进度 0.0-1.0
var intel_progress: float = 0.0

## 是否已解锁进化（情报100%时解锁）
var is_unlocked: bool = false

# ─────────────────────────────────────────────
#  通用辅助字段
# ─────────────────────────────────────────────

## v6.0 词条槽位（强化=选词条系统）
## 最多5个 ModuleSlot，每个存储一个词条ID和等级(Lv1-3)。
## 通过 CardEnhancementManager 操作，不要直接修改。
var module_slots: Array = []  ## Array[ModuleSlot]

## @deprecated v6.0 — 保留仅供存档兼容读取，新代码不要写入
## 不要直接修改此字段，使用 AffixManager 的接口操作。
@export var affix_slot_ids: Array = []
## @deprecated v6.0 — 保留仅供存档兼容读取
@export var affix_slot_count: int = 4

# 卡片来源标记：true=战斗掉落成品卡，false=蓝图制造卡
@export var is_dropped_card: bool = false



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
		4: return "堡垒"
		_: return "未知"

## 战斗定位简短名称
static func get_combat_kind_short(kind: int) -> String:
	match kind:
		0: return "轻"
		1: return "甲"
		2: return "援"
		3: return "空"
		4: return "堡"
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
		"mythic":    return "神话"
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
	# v5.0 per-target attack speeds
	new_card.attack_light_speed = attack_light_speed
	new_card.attack_light_windup = attack_light_windup
	new_card.attack_light_active = attack_light_active
	new_card.attack_armor_speed = attack_armor_speed
	new_card.attack_armor_windup = attack_armor_windup
	new_card.attack_armor_active = attack_armor_active
	new_card.attack_air_speed = attack_air_speed
	new_card.attack_air_windup = attack_air_windup
	new_card.attack_air_active = attack_air_active
	new_card.defense_light = defense_light
	new_card.defense_armor = defense_armor
	new_card.defense_air = defense_air
	new_card.multi_weapons = multi_weapons.duplicate(true)
	# 武器槽位名称（v6.0）
	new_card.weapon_names = weapon_names.duplicate()
	# 武器槽位
	new_card.weapon_slots = Array()
	for weapon in weapon_slots:
		if weapon != null and weapon.has_method("clone"):
			new_card.weapon_slots.append(weapon.clone())
	# v5.0 养成字段
	new_card.enhance_level = enhance_level
	new_card.mods = mods.duplicate()
	new_card.evolution_paths = evolution_paths.duplicate()
	new_card.evolution_stage = evolution_stage
	new_card.intel_progress = intel_progress
	new_card.is_unlocked = is_unlocked
	# 能量卡字段
	new_card.energy_grant = energy_grant
	# 法则卡字段
	new_card.linked_law_id = linked_law_id
	# 通用辅助
	new_card.module_slots = []
	for s in module_slots:
		if s is ModuleSlot:
			new_card.module_slots.append(s.duplicate_slot())
	new_card.affix_slot_ids = affix_slot_ids.duplicate()
	new_card.affix_slot_count = affix_slot_count
	new_card.is_dropped_card = is_dropped_card
	new_card.faction_id = faction_id
	new_card.faction_level = faction_level
	new_card.base_card_id = base_card_id
	new_card.is_faction_variant = is_faction_variant
	new_card.is_faction_exclusive = is_faction_exclusive
	new_card.is_faction_hybrid = is_faction_hybrid
	new_card.hybrid_second_faction = hybrid_second_faction
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

# ─────────────────────────────────────────────
#  新扩展方法：强化改造与进化系统
# ─────────────────────────────────────────────

## 获取当前战力（基础属性 + 强化 + 改造加成）
func get_current_power() -> int:
	var base_p = power
	var level = enhance_level

	# 强化倍率（通过UnifiedRankSystem统一计算）
	var level_multiplier = UnifiedRankSystem.get_power_multiplier(level)

	# 改造加成
	var mod_bonus = _get_modifications_power_bonus()

	return int(base_p * level_multiplier) + mod_bonus

## 计算改造战力加成
func _get_modifications_power_bonus() -> int:
	var bonus = 0
	for mod_entry in mods:
		var mod_id = mod_entry.get("id", "") if mod_entry is Dictionary else ""
		# 通过ModificationRegistry获取数据（autoload，直接访问）
		var mod_data = ModificationRegistry.get_data(mod_id)
		var power_mult = mod_data.get("power_mult", 1.0)
		bonus += int(power_mult * 10)
	return bonus

## 获取军衔信息（动态计算）
func get_military_rank() -> Dictionary:
	var base_p = power
	var current_p = get_current_power()
	var unit_type = combat_kind

	# 通过MilitaryTitleRegistry获取数据（autoload，直接访问）
	return MilitaryTitleRegistry.get_military_title(base_p, current_p, unit_type)

## 备用：根据倍率获取等级
func _get_rank_by_ratio(ratio: float) -> int:
	if ratio < 1.05: return 1
	elif ratio < 1.10: return 2
	elif ratio < 1.15: return 3
	elif ratio < 1.20: return 4
	elif ratio < 1.25: return 5
	elif ratio < 1.30: return 6
	elif ratio < 1.35: return 7
	elif ratio < 1.50: return 8
	elif ratio < 1.60: return 9
	else: return 10

## 备用：获取军衔名称
func _get_rank_name(unit_type: int, level: int) -> String:
	match unit_type:
		0:  # 步兵
			match level:
				1: return "征召兵"
				2: return "合格步兵"
				3: return "老兵"
				4: return "精锐"
				5: return "士官"
				6: return "战斗老兵"
				7: return "三级军士长"
				8: return "二级军士长"
				9: return "一级军士长"
				10: return "战斗大师"
				_: return "步兵Lv%d" % level
		1:  # 装甲
			match level:
				1: return "装填手"
				2: return "驾驶员"
				3: return "炮手"
				4: return "车长"
				5: return "排长"
				6: return "连长"
				7: return "营长"
				8: return "装甲兵总监"
				9: return "装甲兵上将"
				10: return "钢铁战神"
				_: return "装甲Lv%d" % level
		_: return "军衔%d" % level

## 获取下一级军衔信息
func get_next_rank_info() -> Dictionary:
	var base_p = power
	var current_p = get_current_power()
	var unit_type = combat_kind

	# 通过MilitaryTitleRegistry获取数据（autoload，直接访问）
	return MilitaryTitleRegistry.get_next_rank_info(base_p, current_p, unit_type)

## 获取军衔进度（0-1）
func get_rank_progress() -> float:
	var base_p = power
	var current_p = get_current_power()
	if base_p <= 0:
		return 0.0
	var current_rank = _get_rank_by_ratio(float(current_p) / float(base_p))

	if current_rank >= 10:
		return 1.0

	# 简化计算
	var current_min = base_p * (1.0 + (current_rank - 1) * 0.05)
	var next_min = base_p * (1.0 + current_rank * 0.05)

	if next_min <= current_min:
		return 1.0

	var progress = (current_p - current_min) / (next_min - current_min)
	return clamp(progress, 0.0, 1.0)

## 检查改造冲突
func can_install_modification(mod_id: String) -> Dictionary:
	var result = {can_install = true, conflicts = [], reason = ""}

	# 检查槽位
	if mods.size() >= 9:
		result.can_install = false
		result.reason = "改造槽位已满（最多9个）"
		return result

	# 获取改造数据
	var mod_data = ModificationRegistry.get_data(mod_id)
	if mod_data.is_empty():
		result.can_install = false
		result.reason = "找不到改造数据"
		return result

	# 检查情报需求
	var intel_requirements = mod_data.get("intel_requirements", {})
	if not intel_requirements.is_empty():
		if IntelManual and IntelManual.has_method("get_intel_progress"):
			for intel_key in intel_requirements.keys():
				var required_progress = intel_requirements[intel_key]
				var target_card_id = intel_key.trim_prefix("intel_")
				var current_progress = IntelManual.get_intel_progress(target_card_id)

				if current_progress < required_progress:
					result.can_install = false
					result.reason = "情报不足：%s需要%.0f%%情报（当前%.0f%%）" % [
						target_card_id, required_progress * 100, current_progress * 100
					]
					return result

	# 检查冲突组
	var conflict_group = mod_data.get("conflict_group", "")

	if not conflict_group.is_empty():
		for installed_mod in mods:
			var installed_id = installed_mod.get("id", "") if installed_mod is Dictionary else ""
			var installed_data = ModificationRegistry.get_data(installed_id)
			var installed_group = installed_data.get("conflict_group", "")

			if installed_group == conflict_group:
				result.can_install = false
				result.conflicts.append(installed_id)
				result.reason = "与已安装改造冲突（%s）" % conflict_group
				break

	return result

## 获取应用改造后的属性
func get_modified_stats() -> Dictionary:
	var base_stats = {
		max_hp = base_hp,
		attack_light = attack_light,
		attack_armor = attack_armor,
		attack_air = attack_air,
		defense_light = defense_light,
		defense_armor = defense_armor,
		defense_air = defense_air,
		move_speed = base_speed,
		attack_range = range_value,
		attack_interval = 1.0 / attack_speed if attack_speed > 0 else 1.0,
		deploy_speed = deploy_speed,
	}

	# 通过ModificationRegistry应用改造效果（autoload，直接访问）
	return ModificationRegistry.apply_effects(base_stats, mods)

## 获取可进化目标列表
func get_evolution_targets() -> Array:
	var card_dict = {
		id = card_id,
		level = enhance_level,
		installed_modifications = mods,
		power = power,
		combat_kind = combat_kind,
	}
	# 通过EvolutionPathRegistry获取数据（autoload，直接访问）
	return EvolutionPathRegistry.get_evolution_targets(card_dict)

## 检查进化条件
func check_evolution_requirements(target_card_id: String) -> Dictionary:
	var card_dict = {
		id = card_id,
		level = enhance_level,
		installed_modifications = mods,
		power = power,
		combat_kind = combat_kind,
	}
	# 通过EvolutionPathRegistry获取数据（autoload，直接访问）
	return EvolutionPathRegistry.check_evolution_requirements(card_dict, target_card_id)

## 计算进化后属性
func calculate_evolved_stats(target_card_id: String) -> Dictionary:
	var card_dict = {
		id = card_id,
		level = enhance_level,
		installed_modifications = mods,
		power = power,
	}
	# 通过EvolutionPathRegistry获取数据（autoload，直接访问）
	return EvolutionPathRegistry.calculate_evolved_stats(card_dict, target_card_id)

## 记录进化历史
func record_evolution(from_id: String, to_id: String, preserved_mods: Array) -> void:
	if not has_meta("evolution_history"):
		set_meta("evolution_history", [])

	var history = get_meta("evolution_history")
	history.append({
		from_id = from_id,
		to_id = to_id,
		at_time = Time.get_unix_time_from_system(),
		preserved_mods = preserved_mods,
	})

## 获取进化历史
func get_evolution_history() -> Array:
	if has_meta("evolution_history"):
		return get_meta("evolution_history")
	return []

## 获取最初卡牌ID
func get_original_card_id() -> String:
	var history = get_evolution_history()
	if history.is_empty():
		return card_id
	## 安全检查：确保第一个元素存在且为字典类型
	if history[0] == null or not (history[0] is Dictionary):
		return card_id
	return history[0].get("from_id", card_id)

## 武器槽位初始化（向后兼容）
func _ensure_weapon_slots_initialized() -> void:
	if not weapon_slots.is_empty():
		return  # 已初始化

	# 从现有字段创建默认槽位
	weapon_slots = Array()
	weapon_slots.append(_create_slot_from_legacy(0, attack_light, attack_light_speed, attack_light_windup, attack_light_active))
	weapon_slots.append(_create_slot_from_legacy(1, attack_armor, attack_armor_speed, attack_armor_windup, attack_armor_active))
	weapon_slots.append(_create_slot_from_legacy(2, attack_air, attack_air_speed, attack_air_windup, attack_air_active))

## 从旧字段创建槽位武器（向后兼容）
func _create_slot_from_legacy(slot_idx: int, base_damage: float, base_speed: float, base_windup: float, base_active: float) -> Resource:
	var w = load("res://resources/weapon_resource.gd").new()
	w.slot_type = slot_idx
	w.damage = base_damage
	w.attack_speed = base_speed if base_speed > 0 else 1.0
	w.windup = base_windup
	w.active = base_active
	w.weapon_type = weapon_type
	w.range_value = range_value
	w.enabled = base_damage > 0

	# 设置默认显示名称
	if has_method("_get_weapon_name_for_slot"):
		var fallback = get_weapon_name_for_slot(slot_idx)
		if fallback != "":
			w.display_name = fallback

	match slot_idx:
		0: w.display_name = "轻装武器"
		1: w.display_name = "装甲武器"
		2: w.display_name = "对空武器"

	return w

## 获取武器槽位名称（v6.0：从 weapon_names 数组读取）
func get_weapon_name_for_slot(slot_idx: int) -> String:
	if slot_idx >= 0 and slot_idx < weapon_names.size():
		return weapon_names[slot_idx]
	return ""
