extends RefCounted
class_name EnemyLoadoutTiers
## v7.2: 敌方统一配置档位表（3/6/9 改造分档，镜像我方养成）
##
## 设计核心（用户思路）：
## - 敌方产兵/敌兵 = 3 档配置，对称我方养成档位：
##     低配 = 我方3级强化+3改造槽
##     中配 = 我方6级强化+6改造槽
##     高配 = 我方10级强化(满)+9改造槽(满)
## - base 属性表已烤进时代递进（一战→近未来 hp 5-7×），公式不加时代系数/关卡线性乘数，
##   跨时代递进全靠 base 数据本身（平衡时更直观）。
## - 相位师产兵固定走高配档；普通关敌人按时代前/中/后选低/中/高配
## - "同一时代前中后"：时代早期出低配、中期中配、后期/相位师战高配
##
## 档位统一系数（裸卡=1.0；hp/atk/def 共用同一倍率，平衡调一处即可）：
##   低配档 = 3强化+3改造+1符文 → ×1.30
##   中配档 = 6强化+6改造+3符文 → ×1.75
##   高配档 = 10强化(满)+9改造(满)+6符文 → ×2.00

## 档位枚举
const TIER_LOW: int = 1     # 低配（3强化+3改造档）
const TIER_MID: int = 2     # 中配（6强化+6改造档）
const TIER_HIGH: int = 3    # 高配（10强化满+9改造满配）

## 档位 → 加成配置（统一系数：atk_pct=hp_pct=def_pct，对应 1.30/1.75/2.00）
const TIER_BONUS: Dictionary = {
	TIER_LOW:  {"name": "低配", "atk_pct": 0.30, "hp_pct": 0.30, "def_pct": 0.30, "mod_count": 3, "rune_count": 1, "enhance_level": 3},
	TIER_MID:  {"name": "中配", "atk_pct": 0.75, "hp_pct": 0.75, "def_pct": 0.75, "mod_count": 6, "rune_count": 3, "enhance_level": 6},
	TIER_HIGH: {"name": "高配", "atk_pct": 1.00, "hp_pct": 1.00, "def_pct": 1.00, "mod_count": 9, "rune_count": 6, "enhance_level": 10},
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
		return TIER_HIGH  # 相位师战固定高配（旧路径保留，新代码用 get_phase_master_tier）
	if era_progress < 0.33:
		return TIER_LOW   # 时代前1/3：低配
	elif era_progress < 0.75:
		return TIER_MID   # 时代中段：中配
	else:
		return TIER_HIGH  # 时代后期：高配

## v8.2: 相位师产兵固定高档（用户要求"敌方相位师都是高配置敌人"）。
## 恒返回 TIER_HIGH（enh10 + 满改造 + 满符文 + ×2.00 系数）。
## 相位师的强弱差异由 base archetype 时代 + 自身 stats + 符文/相位仪决定，不靠产兵档位递进。
## 参数 era_progress 保留兼容签名，不再使用。
static func get_phase_master_tier(era_progress: float) -> int:
	return TIER_HIGH

## 取档位的改造槽 ID 列表（UI展示/缴获用）
static func get_modifications_for_tier(tier: int) -> Array:
	return (TIER_MODIFICATIONS.get(tier, []) as Array).duplicate()

## 取档位的符文槽 ID 列表
static func get_runes_for_tier(tier: int) -> Array:
	return (TIER_RUNES.get(tier, []) as Array).duplicate()
