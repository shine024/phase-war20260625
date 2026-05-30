class_name AttributeGrowth
extends RefCounted
## 属性成长计算系统（从 blueprint_manager.gd 拆分）
## 负责：属性成长计算、平台预览 HP、星级成长偏置、进化 HP 下限
## 注意：实际计算委托给 EvolutionHelpers，此处提供统一入口 + 文档

## ── 供 BlueprintManager 或其他系统调用（需 EvolutionHelpers） ──

## 将成长属性应用到 UnitStats（含武器卡、军衔奖励）
static func apply_growth_to_stats(stats: UnitStats, platform_card: CardResource, weapon_cards: Array, bp_manager: Node, apply_rank_bonus: bool = true) -> void:
	if not ClassDB.class_exists("EvolutionHelpers"):
		return
	EvolutionHelpers.apply_growth_to_stats(stats, platform_card, weapon_cards, bp_manager, apply_rank_bonus)

## 计算平台卡在指定时代的预览 HP
static func compute_platform_preview_hp(card_id: String, era: int, bp_manager: Node) -> float:
	if not ClassDB.class_exists("EvolutionHelpers"):
		return 0.0
	return EvolutionHelpers.compute_platform_preview_hp(card_id, era, bp_manager)

## 应用平台星级成长偏置（星级越高 HP 偏置越多）
static func apply_platform_star_growth_bias(stats: UnitStats, platform_card_id: String, bp_manager: Node) -> void:
	if not ClassDB.class_exists("EvolutionHelpers"):
		return
	EvolutionHelpers._apply_platform_star_growth_bias(stats, platform_card_id, bp_manager)

## 应用进化后 HP 下限保证（避免进化后 HP 反降）
static func apply_evolution_hp_floor(stats: UnitStats, platform_card_id: String, era: int, bp_manager: Node) -> void:
	if not ClassDB.class_exists("EvolutionHelpers"):
		return
	EvolutionHelpers._apply_evolution_hp_floor(stats, platform_card_id, era, bp_manager)

## 同步单武器伤害 = attack_damage（无武器卡时的兜底）
static func sync_single_weapon_damage_from_attack(stats: UnitStats) -> void:
	if not ClassDB.class_exists("EvolutionHelpers"):
		return
	EvolutionHelpers._sync_single_weapon_damage_from_attack(stats)

## 按乘数同步攻击伤害与武器槽数
static func multiply_attack_damage_and_weapon_slots(stats: UnitStats, factor: float) -> void:
	if not ClassDB.class_exists("EvolutionHelpers"):
		return
	EvolutionHelpers._multiply_attack_damage_and_weapon_slots(stats, factor)
