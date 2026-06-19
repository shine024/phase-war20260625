extends RefCounted
class_name DamageAttenuation
## v5.0: 射程衰减系统（仅直射有衰减，曲射和空射无衰减）

## 衰减系数映射
const ATTENUATION_FACTORS: Dictionary = {
	"SMG":    0.6,   # 冲锋枪 -60% 最大衰减
	"RIFLE":  0.4,   # 步枪 -40%
	"MG":     0.5,   # 机枪 -50%
	"TANK":   0.3,   # 坦克炮 -30%
	"AT":     0.2,   # 反坦克 -20%
	"SNIPER": 0.1,   # 狙击 -10%
}

## 根据单位属性推断武器子类型
static func infer_weapon_sub_type(combat_kind: int, range_value: int, attack_light: float, attack_armor: float, attack_air: float) -> String:
	# 全0攻击力 → 纯辅助单位
	if attack_light == 0.0 and attack_armor == 0.0 and attack_air == 0.0:
		return "SUPPORT"
	# LIGHT + short range → SMG
	if combat_kind == 0 and range_value <= 2:
		return "SMG"
	# LIGHT + medium range → RIFLE
	if combat_kind == 0 and range_value <= 4:
		return "RIFLE"
	# LIGHT + high anti-armor → AT (反坦克)
	if combat_kind == 0 and attack_armor > attack_light * 2.0:
		return "AT"
	# ARMOR → TANK
	if combat_kind == 1:
		return "TANK"
	# SUPPORT + anti-air focus → SNIPER
	if combat_kind == 2 and attack_air > 0.0 and attack_air > attack_light:
		return "SNIPER"
	# SUPPORT + high rate of fire → MG
	if combat_kind == 2:
		return "MG"
	# AIR → default
	if combat_kind == 3:
		return "RIFLE"
	# FORT → default
	if combat_kind == 4:
		return "TANK"
	return "RIFLE"

## 计算衰减倍率（仅直射武器调用）
## distance: 实际距离(格), max_range: 最大射程(格)
## 返回 0.0~1.0 的倍率
## v6.2: 直射武器已删除攻击力衰减设定，统一返回 1.0（无衰减）。
## 原衰减公式保留于下方注释，如需恢复可解开。
static func calculate_attenuation(distance: float, max_range: float, weapon_sub_type: String) -> float:
	return 1.0
#	if max_range <= 0.0:
#		return 1.0
#	if distance <= max_range:
#		return 1.0
#	var factor = float(ATTENUATION_FACTORS.get(weapon_sub_type, 0.4))
#	var over_ratio = (distance - max_range) / max_range
#	var attenuation = 1.0 - over_ratio * factor
#	return clampf(attenuation, 0.0, 1.0)

## 是否需要衰减（仅直射需要）
static func needs_attenuation(weapon_type: int) -> bool:
	return weapon_type == 0  # DIRECT
