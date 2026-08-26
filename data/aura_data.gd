extends RefCounted
class_name AuraData
## 光环数据表：定义光环类型、范围判定、星级参数。

const GC = preload("res://resources/game_constants.gd")

## 光环类别枚举
enum Category {
	MEDIC_HEAL,       # 0  医疗：治疗所有友军
	CARRIER_REPAIR,   # 1  维修：仅治疗机械类
	SCOUT_CRIT,       # 2  侦查：暴击+命中
	RADAR_RANGE,      # 3  雷达：暴击率加成
	FORTRESS_DEF,     # 4  堡垒：减伤+防御
	COMMAND_GLOBAL    # 5  指挥：全场攻/速/暴（不攻击）
}

## 星级乘数：1.0 + (star - 1) * 0.1，即 ★1=1.0, ★5=1.4, ★9=1.8
static func star_multiplier(star: int) -> float:
	# v6.11: 系数 0.1→0.05（迁移到 enhance_level 0-10，避免高强化光环过强）
	# 原 star 1-9 → 现 enhance_level 0-10：★10=1.45（原★9=1.8），★5=1.20
	return 1.0 + float(maxi(1, star) - 1) * 0.05

## 光环范围判定
## v6.2: 所有光环（含普通光环）均影响我方全体，不再受槽位距离限制
static func is_in_aura_range(source_slot: int, target_slot: int, is_global: bool) -> bool:
	# 所有光环均为全局范围（全体我方单位）
	return true

## 机械类平台判定（CARRIER_REPAIR 只治疗机械平台）
static func is_mechanical_platform(platform_type: int) -> bool:
	match platform_type:
		2, 3, 7, 4, 8, 11, 12:  # TITAN, FORTRESS, SIEGE, RADAR, CARRIER, OMEGA_PLATFORM, COMMAND
				return true
		_:
				return false

## v20.15: 双口径机械类判定——我方卡（CombatKind 口径）优先按 stats card_tags 判定：
## infantry=非机械；vehicle/armored/aircraft/fortress/immobile/support=机械（支援班组视为
## 随队可抢修单位）。敌方无 card_tags，回退 legacy platform_type 旧表。
## 修复点：玩家装甲（CombatKind 1）不在旧表 {2,3,7,4,8,11,12}，旧表口径会漏修玩家坦克。
static func is_mechanical_ally(ally: Node2D) -> bool:
	if ally == null or not is_instance_valid(ally):
		return false
	var stats = ally.get("stats")
	if stats == null:
		return false
	if stats.has_meta("card_tags"):
		var tags: Array = stats.get_meta("card_tags", [])
		if tags is Array and not tags.is_empty():
			return not tags.has("infantry")
	return is_mechanical_platform(int(stats.platform_type))

## 获取光环参数（返回 Dictionary，由 CardAbilityManager 消费）
## star: 星级（1~9），乘数已在内部应用
static func get_aura_params(category: int, star: int) -> Dictionary:
	var m: float = star_multiplier(star)
	match category:
		Category.MEDIC_HEAL:
			return {
				"heal_pct": 0.08 * m,       # ★1=8%, ★9=14.4%
				"interval": 3.0,
				"is_global": false,
			}
		Category.CARRIER_REPAIR:
			return {
				"heal_pct": 0.12 * m,       # ★1=12%, ★9=21.6%
				"interval": 3.0,
				"mechanical_only": true,
				"is_global": false,
			}
		Category.SCOUT_CRIT:
			return {
				"crit_bonus": 0.08 * m,      # ★1=+8%, ★9=+14.4%
				"hit_bonus": 5.0 * m,        # ★1=+5, ★9=+9
				"is_global": false,
			}
		Category.RADAR_RANGE:
			return {
				"crit_bonus": 0.15 * m,      # ★1=+15%, ★10≈+21.75%（v20.14 核心单位增强）
				"is_global": false,
			}
		Category.FORTRESS_DEF:
			return {
				"damage_reduction_bonus": 0.06 * m,  # ★1=+6%, ★9=+10.8%
				"defense_bonus": 2.0 * m,             # ★1=+2, ★9=+3.6
				"is_global": false,
			}
		Category.COMMAND_GLOBAL:
			return {
				"attack_mul": 0.08 * m,      # ★1=+8%, ★10≈+11.6%（v20.14 核心单位增强）
				"speed_mul": 0.08 * m,       # ★1=+8%, ★10≈+11.6%
				"crit_mul": 0.04 * m,        # ★1=+4%, ★10≈+5.8%
				"is_global": true,
			}
	return {}
