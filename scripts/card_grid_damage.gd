extends RefCounted
class_name CardGridDamage
## 格子战术：攻击力与护甲对比后的扣血与受击反馈（百分比减伤 + 闪避）。

const DEFENSE_SOFT_CAP_CONSTANT: float = 50.0

static func effective_defense(base_defense: float, armor_penetration: float) -> float:
	var pen: float = clampf(armor_penetration, 0.0, 1.0)
	return maxf(0.0, base_defense * (1.0 - pen))


## 护甲减伤倍率：def / (def + K)
static func defense_damage_multiplier(defense: float) -> float:
	var d: float = maxf(0.0, defense)
	return 1.0 - d / (d + DEFENSE_SOFT_CAP_CONSTANT)


## 返回 { hp_loss, apply_stun, apply_recoil }
static func resolve_hit(raw_attack: float, defense: float, dodge_chance: float = 0.0) -> Dictionary:
	if dodge_chance > 0.0 and randf() < clampf(dodge_chance, 0.0, 0.95):
		return {"hp_loss": 0.0, "apply_stun": false, "apply_recoil": false}
	var attack_val: float = maxf(0.0, raw_attack)
	var mult: float = defense_damage_multiplier(defense)
	var hp_loss: float = maxf(1.0, attack_val * mult)
	var heavy_hit: bool = mult < 0.85 and attack_val > 12.0
	return {
		"hp_loss": hp_loss,
		"apply_stun": heavy_hit,
		"apply_recoil": true,
	}
