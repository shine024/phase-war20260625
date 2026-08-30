extends RefCounted
class_name AuraData
## 光环数据表：定义光环类型、范围判定、星级参数。

const GC = preload("res://resources/game_constants.gd")
const GameCfg = preload("res://resources/game_config.gd")
const Layout = preload("res://scripts/card_grid_battle_layout.gd")

## v21 P0: 全场光环哨兵值（range_cells < 0 = 全场）
const AURA_RANGE_GLOBAL := -1
## v21 P0: 战术光环基础范围（带内切比雪夫距离，格）。3×3 带内最大距离=2：
## 基础 1（十字+斜角邻域）→ ★5 起 2（全带）→ ★9 起 3（全带，前瞻性余量）。
const TACTICAL_AURA_BASE_RANGE := 1

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
## v21 P0: 恢复真实范围——同阵营 3×3 槽位带内 (列,行) 切比雪夫距离 ≤ range_cells。
## - range_cells < 0（AURA_RANGE_GLOBAL）= 全场（指挥/载具维修）。
## - 任一槽位未知（-1，部署竞态/相位场等无槽实体）= 回退全场（宁可多给不误伤）。
## - 总开关关闭（GameConfig.aura_range_enabled=false）= 短路 true，完整回退 v6.2 全场行为。
static func is_in_aura_range(source_slot: int, target_slot: int, range_cells: int) -> bool:
	if not is_aura_ranging_enabled():
		return true
	if range_cells < 0:
		return true
	if source_slot < 0 or target_slot < 0:
		return true
	var a := slot_grid_coords(source_slot)
	var b := slot_grid_coords(target_slot)
	return maxi(absi(a.x - b.x), absi(a.y - b.y)) <= range_cells

## v21 P0: 总开关读取（GameConfig 单例缓存，读取廉价）
static func is_aura_ranging_enabled() -> bool:
	return bool(GameCfg.get_default().aura_range_enabled)

## v21 P0: 槽位编号 → (带内列, 行)。几何单一真身 = card_grid_battle_layout
## （3 行 × 每行 SLOTS_PER_SIDE 格，槽位按行主序编号：row = slot / SLOTS_PER_SIDE）。
static func slot_grid_coords(slot_index: int) -> Vector2i:
	if slot_index < 0:
		return Vector2i(-9999, -9999)
	var col: int = slot_index % Layout.SLOTS_PER_SIDE
	var row: int = Layout.get_row_for_slot(slot_index)
	return Vector2i(col, row)

## v21 P0: 统一读取单位槽位 meta（玩家=card_grid_slot，敌方=card_grid_enemy_slot）。
## 无槽 meta 返回 -1（判定回退全场）。与 card_grid_battle_layout.is_unit_in_upper_row 同款读法。
static func unit_slot_index(unit: Node) -> int:
	if unit == null or not is_instance_valid(unit):
		return -1
	if unit.has_meta("card_grid_slot"):
		return int(unit.get_meta("card_grid_slot", -1))
	if unit.has_meta("card_grid_enemy_slot"):
		return int(unit.get_meta("card_grid_enemy_slot", -1))
	return -1

## v21 P0: 按类别+星级取实际生效范围。★5 起 +1 格、★9 起 +2 格（只扩范围不动数值乘数）。
## 全场类别（-1）不受星级影响。
static func aura_range_for(category: int, star: int) -> int:
	var params: Dictionary = get_aura_params(category, maxi(1, star))
	var base: int = int(params.get("range_cells", AURA_RANGE_GLOBAL))
	if base < 0:
		return base
	var s: int = maxi(1, star)
	if s >= 9:
		return base + 2
	if s >= 5:
		return base + 1
	return base

## v21 P0: 改造光环（ally_*）范围——默认战术基础 1 格；
## summary meta 可携带 "range_override"（中继天线类改造写 -1 = 全场）。
static func get_mod_aura_range(summary: Dictionary) -> int:
	if summary.is_empty():
		return TACTICAL_AURA_BASE_RANGE
	if summary.has("range_override"):
		return int(summary["range_override"])
	return TACTICAL_AURA_BASE_RANGE

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
				"range_cells": TACTICAL_AURA_BASE_RANGE,   # v21 P0
			}
		Category.CARRIER_REPAIR:
			return {
				"heal_pct": 0.12 * m,       # ★1=12%, ★9=21.6%
				"interval": 3.0,
				"mechanical_only": true,
				"is_global": false,
				"range_cells": AURA_RANGE_GLOBAL,          # v21 P0: 战略光环恒全场
			}
		Category.SCOUT_CRIT:
			return {
				"crit_bonus": 0.08 * m,      # ★1=+8%, ★9=+14.4%
				"hit_bonus": 5.0 * m,        # ★1=+5, ★9=+9
				"is_global": false,
				"range_cells": TACTICAL_AURA_BASE_RANGE,   # v21 P0
			}
		Category.RADAR_RANGE:
			return {
				"crit_bonus": 0.15 * m,      # ★1=+15%, ★10≈+21.75%（v20.14 核心单位增强）
				"is_global": false,
				"range_cells": TACTICAL_AURA_BASE_RANGE,   # v21 P0
			}
		Category.FORTRESS_DEF:
			return {
				"damage_reduction_bonus": 0.06 * m,  # ★1=+6%, ★9=+10.8%
				"defense_bonus": 2.0 * m,             # ★1=+2, ★9=+3.6
				"is_global": false,
				"range_cells": TACTICAL_AURA_BASE_RANGE,   # v21 P0
			}
		Category.COMMAND_GLOBAL:
			return {
				"attack_mul": 0.08 * m,      # ★1=+8%, ★10≈+11.6%（v20.14 核心单位增强）
				"speed_mul": 0.08 * m,       # ★1=+8%, ★10≈+11.6%
				"crit_mul": 0.04 * m,        # ★1=+4%, ★10≈+5.8%
				"is_global": true,
				"range_cells": AURA_RANGE_GLOBAL,          # v21 P0: 战略光环恒全场
			}
	return {}
