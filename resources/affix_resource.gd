extends Resource
class_name AffixResource
## 词条资源类 - 单个词条实例（运行时数据）

## 词条ID（对应 affix_definitions.gd 中的 key）
var affix_id: String = ""

## 词条名称（显示用）
var affix_name: String = ""

## 词条简述
var description: String = ""

## 稀有度: common | rare | epic | legendary
var rarity: String = "common"

## 等级 1-5
var level: int = 1

## 是否变异（高级词条可能触发变异效果）
var is_mutated: bool = false

## 变异描述（变异时才有效）
var mutation_description: String = ""

## 是否锁定（锁定后不再变化）
var is_locked: bool = false

## 词条类型
## "base_property"  ─ 基础属性加成（血量/伤害/速度等）
## "combat_feature" ─ 战斗特性（暴击/溅射/吸血等）
## "special_mechanic" ─ 特殊机制
var affix_type: String = "base_property"

## 效果键（对应要修改的 UnitStats 字段或特殊标识）
## 例: "max_hp" / "attack_damage" / "move_speed" / "attack_range"
##     "attack_interval" (负值=加快) / "crit_chance" / "lifesteal"
var effect_key: String = ""

## 基础数值（Lv1 时的效果量，加成型为小数，如 0.15 = +15%）
var base_value: float = 0.0

## 稀有度倍率（由 AffixDefinitions 生成时注入）
var value_multiplier: float = 1.0

## 当前生效数值（base_value * value_multiplier * level_factor）
var current_value: float = 0.0

## 适用卡牌类型: 0=PLATFORM, 1=WEAPON, 2=BOTH
var card_type_filter: int = 2

## 适用武器类型（仅武器词条）: 对应 GameConstants.WeaponType，-1=所有武器
var weapon_type_filter: int = -1

# ─────────────────────────────────────────────
#  静态工具方法
# ─────────────────────────────────────────────

## 等级加成系数（相对于 Lv1 基础值的额外倍率）
static func get_level_factor(lv: int) -> float:
	match lv:
		1: return 1.0
		2: return 1.25
		3: return 1.55
		4: return 1.95
		5: return 2.5
		_: return 1.0

## 稀有度加成倍率
static func get_rarity_multiplier(rar: String) -> float:
	match rar:
		"common":    return 1.0
		"rare":      return 1.3
		"epic":      return 1.7
		"legendary": return 2.2
		_:           return 1.0

# ─────────────────────────────────────────────
#  实例方法
# ─────────────────────────────────────────────

## 重新计算 current_value（在 level / rarity 改变后调用）
func recalculate() -> void:
	value_multiplier = get_rarity_multiplier(rarity)
	current_value = base_value * value_multiplier * get_level_factor(level)

	# 应用平衡性最大值限制
	match effect_key:
		"crit_chance":
			current_value = minf(current_value, 0.35)  # 暴击率≤35%
		"lifesteal":
			current_value = minf(current_value, 0.25)  # 吸血≤25%
		"armor_penetration":
			current_value = minf(current_value, 0.50)  # 穿甲≤50%
		"splash_radius":
			current_value = minf(current_value, 120.0) # 溅射半径≤120px

## 获取带稀有度前缀的完整显示名
func get_display_name() -> String:
	var prefix: String
	match rarity:
		"common":    prefix = "◇"
		"rare":      prefix = "◆"
		"epic":      prefix = "★"
		"legendary": prefix = "✦"
		_:           prefix = "·"
	var mutated_mark: String = " [变]" if is_mutated else ""
	return "%s %s Lv%d%s" % [prefix, affix_name, level, mutated_mark]

## 获取详细描述（含当前数值和等级信息）
func get_detailed_description() -> String:
	var val_str: String
	if effect_key == "attack_interval":
		# 攻速词条：显示为加速百分比（正数=加快）
		val_str = "攻击间隔 ×%.2f" % (1.0 - current_value)
	elif current_value < 1.0 and current_value > 0.0:
		val_str = "+%.0f%%" % (current_value * 100.0)
	else:
		val_str = "+%.1f" % current_value
	var result: String = "%s  %s" % [affix_name, val_str]
	if level > 1:
		result += "  (Lv%d)" % level
	if is_mutated and not mutation_description.is_empty():
		result += "\n  变异: %s" % mutation_description
	return result

## 序列化为字典（用于存档）
func to_dict() -> Dictionary:
	return {
		"affix_id": affix_id,
		"level": level,
		"is_mutated": is_mutated,
		"rarity": rarity,
		"current_value": current_value,
		"is_locked": is_locked,
	}

## 从字典恢复（存档读取后由 AffixManager 调用完整重建）
static func from_dict(d: Dictionary) -> AffixResource:
	var a := AffixResource.new()
	a.affix_id     = str(d.get("affix_id", ""))
	a.level        = int(d.get("level", 1))
	a.is_mutated   = bool(d.get("is_mutated", false))
	a.rarity       = str(d.get("rarity", "common"))
	a.current_value = float(d.get("current_value", 0.0))
	a.is_locked    = bool(d.get("is_locked", false))
	return a
