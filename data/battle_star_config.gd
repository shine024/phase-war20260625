extends RefCounted
class_name BattleStarConfig
## 战力星级系统配置（v6.5）
## 每张战斗卡通过在战斗中击杀敌人累计"击溃战力"，达到阈值后提升战力星级（0-7星）。
## 星级提供固定数值加成（按兵种差异化）+ 特殊能力（复用 Affix effect_key）。

# ── 星级阈值（累计击溃战力达到此值时升星）──
const STAR_THRESHOLDS: Array[float] = [
	0.0,       # 0星（初始）
	500.0,     # 1星
	2000.0,    # 2星
	5000.0,    # 3星
	12000.0,   # 4星
	25000.0,   # 5星
	50000.0,   # 6星
	100000.0,  # 7星（满星）
]

const MAX_STAR: int = 7

## 根据累计击溃战力计算当前星级
static func get_star_from_power(power: float) -> int:
	var star: int = 0
	for i in range(1, STAR_THRESHOLDS.size()):
		if power >= STAR_THRESHOLDS[i]:
			star = i
		else:
			break
	return star

## 升到下一星所需的累计战力（已满星返回 -1）
static func get_next_star_threshold(star: int) -> float:
	if star >= MAX_STAR:
		return -1.0
	return STAR_THRESHOLDS[star + 1]

# ── 兵种差异化数值加成（每星固定值）──
# combat_kind → {hp_pct, atk_pct, extra_key, extra_per_star}
# extra_key: "dodge"/"damage_reduction"/"hp_regen"/"move_speed"
static func get_stat_bonus_per_star(combat_kind: int) -> Dictionary:
	match combat_kind:
		0:  # 轻装
			return {"hp_pct": 0.03, "atk_pct": 0.04, "extra_key": "dodge", "extra_per_star": 0.015}
		1:  # 装甲
			return {"hp_pct": 0.05, "atk_pct": 0.03, "extra_key": "damage_reduction", "extra_per_star": 0.01}
		2:  # 支援
			return {"hp_pct": 0.04, "atk_pct": 0.03, "extra_key": "hp_regen", "extra_per_star": 0.02}
		3:  # 空中
			return {"hp_pct": 0.025, "atk_pct": 0.05, "extra_key": "move_speed", "extra_per_star": 0.015}
		4:  # 堡垒
			return {"hp_pct": 0.06, "atk_pct": 0.015, "extra_key": "damage_reduction", "extra_per_star": 0.02}
		_:
			return {"hp_pct": 0.03, "atk_pct": 0.03, "extra_key": "", "extra_per_star": 0.0}

# ── 特殊能力解锁（按兵种 × 星级阈值 3/5/7星）──
# 每个能力返回 {effect_key, value, name} 格式，复用 Affix 的 effect_key 逻辑
static func get_unlocked_abilities(combat_kind: int, star: int) -> Array[Dictionary]:
	var abilities: Array[Dictionary] = []
	var all := _get_all_abilities(combat_kind)
	for ability in all:
		if star >= int(ability.get("unlock_star", 99)):
			abilities.append(ability)
	return abilities

## 返回该兵种的所有能力定义（含解锁星级），用于 UI 显示
static func get_all_ability_defs(combat_kind: int) -> Array[Dictionary]:
	return _get_all_abilities(combat_kind)

static func _get_all_abilities(combat_kind: int) -> Array[Dictionary]:
	match combat_kind:
		0:  # 轻装
			return [
				{"unlock_star": 3, "effect_key": "crit_chance", "value": 0.10, "name": "暴击+10%"},
				{"unlock_star": 5, "effect_key": "lifesteal", "value": 0.08, "name": "吸血+8%"},
				{"unlock_star": 7, "effect_key": "armor_penetration", "value": 0.20, "name": "穿透+20%"},
			]
		1:  # 装甲
			return [
				{"unlock_star": 3, "effect_key": "damage_reduction", "value": 0.05, "name": "减伤+5%"},
				{"unlock_star": 5, "effect_key": "shield_on_kill", "value": 30.0, "name": "击杀获盾+30"},
				{"unlock_star": 7, "effect_key": "damage_reduction", "value": 0.10, "name": "减伤+10%"},
			]
		2:  # 支援
			return [
				{"unlock_star": 3, "effect_key": "splash_damage", "value": 0.10, "name": "范围伤害+10%"},
				{"unlock_star": 5, "effect_key": "hp_regen", "value": 5.0, "name": "回血+5/s"},
				{"unlock_star": 7, "effect_key": "splash_damage", "value": 0.20, "name": "范围伤害+20%"},
			]
		3:  # 空中
			return [
				{"unlock_star": 3, "effect_key": "crit_chance", "value": 0.10, "name": "暴击+10%"},
				{"unlock_star": 5, "effect_key": "chain_chance", "value": 0.10, "name": "连锁+10%"},
				{"unlock_star": 7, "effect_key": "armor_penetration", "value": 0.20, "name": "穿透+20%"},
			]
		4:  # 堡垒
			return [
				{"unlock_star": 3, "effect_key": "damage_reduction", "value": 0.05, "name": "减伤+5%"},
				{"unlock_star": 5, "effect_key": "hp_regen", "value": 3.0, "name": "回血+3/s"},
				{"unlock_star": 7, "effect_key": "damage_reduction", "value": 0.10, "name": "减伤+10%"},
			]
		_:
			return []

## 格式化数值加成的显示文本（用于 UI）
static func format_stat_bonus_text(combat_kind: int, star: int) -> String:
	if star <= 0:
		return "无加成"
	var bonus: Dictionary = get_stat_bonus_per_star(combat_kind)
	var lines: Array[String] = []
	var star_f: float = float(star)
	lines.append("HP+%d%%" % int(bonus.hp_pct * star_f * 100))
	lines.append("攻击+%d%%" % int(bonus.atk_pct * star_f * 100))
	var extra_key: String = bonus.extra_key
	if not extra_key.is_empty():
		var extra_val: float = bonus.extra_per_star * star_f
		match extra_key:
			"dodge":
				lines.append("闪避+%d%%" % int(extra_val * 100))
			"damage_reduction":
				lines.append("减伤+%d%%" % int(extra_val * 100))
			"hp_regen":
				lines.append("回血+%.0f/s" % extra_val)
			"move_speed":
				lines.append("移速+%d%%" % int(extra_val * 100))
	# 特殊能力
	var abilities := get_unlocked_abilities(combat_kind, star)
	for ab in abilities:
		lines.append("【能力】%s" % String(ab.get("name", "")))
	return " · ".join(lines)
