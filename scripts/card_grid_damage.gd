extends RefCounted
class_name CardGridDamage
## 格子战术：攻击力与护甲对比后的扣血与受击反馈（百分比减伤 + 闪避）。
##
## v7.5: resolve_hit 接入 damage_reduction 参数——此前该字段全链路空转：
## 8 个系统（强化/改造/相位仪/势力/词缀/进化/卡牌能力/StatBoost）都在写入
## UnitStats.damage_reduction，但 take_damage 从不读取它，导致"减伤 X%"类
## 改造/词条/相位仪加成完全不生效。现接入 resolve_hit 末尾乘以减伤系数。

const DEFENSE_SOFT_CAP_CONSTANT: float = 50.0
## damage_reduction 减伤上限（与 module_effect_handler._apply_target_reduction 的 0.60 对齐）
const DAMAGE_REDUCTION_CAP: float = 0.60

static func effective_defense(base_defense: float, armor_penetration: float) -> float:
	var pen: float = clampf(armor_penetration, 0.0, 1.0)
	return maxf(0.0, base_defense * (1.0 - pen))


## 护甲减伤倍率：def / (def + K)
static func defense_damage_multiplier(defense: float) -> float:
	var d: float = maxf(0.0, defense)
	return 1.0 - d / (d + DEFENSE_SOFT_CAP_CONSTANT)


## 返回 { hp_loss, apply_stun, apply_recoil, dodged }
## raw_attack:    攻击者原始伤害（已含暴击，由调用方/bullet 决定）
## defense:       经穿透结算后的有效防御值
## dodge_chance:  闪避率（0~1）
## damage_reduction: 额外百分比减伤（0~1，来自 damage_reduction 字段，上限 0.60）
##   v7.5 新增。与护甲减伤独立乘算（先吃护甲，再吃减伤词条），避免互相稀释语义混乱。
static func resolve_hit(
	raw_attack: float,
	defense: float,
	dodge_chance: float = 0.0,
	damage_reduction: float = 0.0
) -> Dictionary:
	if dodge_chance > 0.0 and randf() < clampf(dodge_chance, 0.0, 0.95):
		return {"hp_loss": 0.0, "apply_stun": false, "apply_recoil": false, "dodged": true}
	var attack_val: float = maxf(0.0, raw_attack)
	var mult: float = defense_damage_multiplier(defense)
	# 修复：移除最低伤害保证，改为允许0伤害（高防御免疫低攻击）
	var hp_loss: float = attack_val * mult
	# v7.5: 应用 damage_reduction 减伤（独立乘区，上限保护）
	if damage_reduction > 0.0:
		hp_loss *= (1.0 - clampf(damage_reduction, 0.0, DAMAGE_REDUCTION_CAP))
	var heavy_hit: bool = mult < 0.85 and attack_val > 12.0
	return {
		"hp_loss": hp_loss,
		"apply_stun": heavy_hit,
		"apply_recoil": true,
		"dodged": false,
	}
