extends RefCounted
class_name EnemyLoadoutTiers
## v7.2: 敌方统一配置档位表（3/6/9 改造分档，镜像我方养成）
##
## 设计核心（用户思路）：
## - 敌方产兵/敌兵 = 3 档配置，对称我方养成档位：
##     低配 = 我方强化改造3档（3改造槽 + ~3级强化）
##     中配 = 我方强化改造6档（6改造槽 + ~6级强化）
##     高配 = 我方强化改造9档（9改造槽满 + 9级强化满）
## - 数值等量对称：敌方某档位产兵加成 = 我方同档位养成加成
## - 相位师产兵固定走高配档；普通关敌人按时代/关卡选低/中/高配
## - "同一时代前中后"：时代早期出低配、中期中配、后期/相位师战高配
##
## 档位定义（改造+符文+强化倍率，等量我方 apply_growth_to_stats + get_rune_bonus）：
##   我方满改造(9槽)约贡献 atk+18%/hp+15%；满符文(6格)约 atk+12%/hp+10%
##   高配档 = 满改造+满符文+9级强化 ≈ atk+35%/hp+30%
##   中配档 = 6改造+3符文+6级强化 ≈ atk+20%/hp+18%
##   低配档 = 3改造+1符文+3级强化 ≈ atk+10%/hp+10%

## 档位枚举
const TIER_LOW: int = 1     # 低配（3改造档）
const TIER_MID: int = 2     # 中配（6改造档）
const TIER_HIGH: int = 3    # 高配（9改造档满配）

## 档位 → 加成配置（atk_pct/hp_pct/def_pct，等量我方同档位养成总加成）
const TIER_BONUS: Dictionary = {
	TIER_LOW:  {"atk_pct": 0.10, "hp_pct": 0.10, "def_pct": 0.05, "mod_count": 3, "rune_count": 1, "enhance_level": 3},
	TIER_MID:  {"atk_pct": 0.20, "hp_pct": 0.18, "def_pct": 0.10, "mod_count": 6, "rune_count": 3, "enhance_level": 6},
	TIER_HIGH: {"atk_pct": 0.35, "hp_pct": 0.30, "def_pct": 0.15, "mod_count": 9, "rune_count": 6, "enhance_level": 9},
}

## 改造槽组合（按档位，用于展示/UI，实际加成走 TIER_BONUS）
const TIER_MODIFICATIONS: Dictionary = {
	TIER_LOW:  ["e_mod_t1_reinforced", "e_mod_t1_heavy_gun", "e_mod_t1_reinforced"],
	TIER_MID:  ["e_mod_t3_composite", "e_mod_t3_apfsds", "e_mod_t3_reactive", "e_mod_t3_fc", "e_mod_t3_composite", "e_mod_t3_reactive"],
	TIER_HIGH: ["e_mod_t5_nanocomp", "e_mod_t5_targeting", "e_mod_t5_shield_gen", "e_mod_t5_nanocomp", "e_mod_t5_targeting", "e_mod_t5_shield_gen", "e_mod_t6_singularity", "e_mod_t6_phase_drive", "e_mod_t6_omega_core"],
}

## 符文槽组合（按档位）
const TIER_RUNES: Dictionary = {
	TIER_LOW:  ["e_rune_t1_iron"],
	TIER_MID:  ["e_rune_t3_storm", "e_rune_t3_bulwark", "e_rune_t3_precision"],
	TIER_HIGH: ["e_rune_t5_apex", "e_rune_t5_eternity", "e_rune_t5_apex", "e_rune_t5_eternity", "e_rune_t6_genesis", "e_rune_t6_void"],
}

## 按档位取加成（产兵/敌兵核心调用）
static func get_bonus_for_tier(tier: int) -> Dictionary:
	return (TIER_BONUS.get(tier, TIER_BONUS[TIER_LOW]) as Dictionary).duplicate()

## 按时代+关卡阶段选档位（普通关敌人用）
## era_progress: 时代内进度 0.0(早期)~1.0(后期)
static func get_tier_for_level_progress(era_progress: float, is_phase_master: bool = false) -> int:
	if is_phase_master:
		return TIER_HIGH  # 相位师战固定高配
	if era_progress < 0.33:
		return TIER_LOW   # 时代前1/3：低配
	elif era_progress < 0.75:
		return TIER_MID   # 时代中段：中配
	else:
		return TIER_HIGH  # 时代后期：高配

## 取档位的改造槽 ID 列表（UI展示/缴获用）
static func get_modifications_for_tier(tier: int) -> Array:
	return (TIER_MODIFICATIONS.get(tier, []) as Array).duplicate()

## 取档位的符文槽 ID 列表
static func get_runes_for_tier(tier: int) -> Array:
	return (TIER_RUNES.get(tier, []) as Array).duplicate()
