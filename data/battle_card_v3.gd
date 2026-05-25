extends RefCounted
class_name BattleCardV3
## 战斗卡 v3 数值公式（与 docs/BATTLE_CARD_V3.md §1.3、§3.1 一致）。
## 完整设定与列表见该文档；架构见 docs/BATTLE_CARD_V3_SCHEMA.md。

## era: GameConstants.Era 枚举值 0~4（WW1..NEAR_FUTURE）
static func era_damage_multiplier(era: int) -> float:
	# 重平衡：1.00 / 1.20 / 1.40 / 1.65 / 1.90（原每级+0.25，现曲线微降）
	var multipliers := [1.00, 1.20, 1.40, 1.65, 1.90]
	return multipliers[clampi(era, 0, 4)]


static func era_range_multiplier(era: int) -> float:
	return 1.0 + float(clampi(era, 0, 4)) * 0.10


static func era_hp_multiplier(era: int) -> float:
	return 1.0 + float(clampi(era, 0, 4)) * 0.15


## star: 1~9；用于 HP/ATK 等同步缩放（§3.1）。rarity 提供额外每星系数。
static func star_stat_multiplier(star: int, rarity: String = "common") -> float:
	var s: int = maxi(1, star)
	var base: float = 1.0 + float(s - 1) * 0.08
	var rarity_extra: float = 0.0
	match rarity:
		"rare":
			rarity_extra = 0.01
		"epic":
			rarity_extra = 0.02
		"legendary":
			rarity_extra = 0.03
		"mythic":
			rarity_extra = 0.04
	return base + float(s - 1) * rarity_extra


## §6.4 继承加成（返回 0~1 的加成比例，如 0.12 表示 +12%）
static func evolution_inherit_bonus(star: int, enhance_level: int) -> float:
	var st: int = maxi(1, star)
	var en: int = maxi(0, enhance_level)
	return clampf(float(st - 1) * 0.04 + float(en) * 0.01, 0.0, 0.40)
