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
## - v18.b 镜像口径更新：我方改造已分层（uncommon/rare 属性条=固定值+level_effects，
##   epic/legendary=百分比）——本表 ×1.30/1.75/2.00 的"镜像我方满改造"语义不变
##   （档位是养成总强度的标量镜像，不逐条对应改造算子类型）。
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
	# v9.x 平衡：阈值从 0.33/0.75 收紧到 0.15/0.55——
	# 时代边界（progress 1.0→0.0）从高档(×2.00)回低档(×1.30)的 -35% 断崖过大；
	# 收紧后低档只持续 in_era 1-3（3 关，原 7 关），第 4 关即回中档，断崖范围缩小。
	# 保留"新时代首关较低档"的教学友好，但不再持续 7 关。
	if era_progress < 0.15:
		return TIER_LOW   # 时代首 3 关：低配（in_era 1-3）
	elif era_progress < 0.55:
		return TIER_MID   # 时代中段：中配（in_era 4-11）
	else:
		return TIER_HIGH  # 时代后期：高配（in_era 12-20）

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

# ══════════════════════════════════════════════════════════════════
#  v21 P3-A（计划 A2）：敌方精英同源词条
#  档位 2/3（中配 ×1.75 / 高配 ×2.00）的敌人在现有数值乘区（档位×波数×势力×难度
#  + card_level flat）之外，从玩家侧词条池（AffixDefinitions.AFFIX_TABLE，即
#  AffixManager 用的词条定义文件）抽 1 条挂到该敌人身上。
#  - 同一关卡同批敌人词条可重复，但同单位仅 1 条（roll 恒返回 0 或 1 条）。
#  - 词条选择用 seeded 随机：seed = 关卡id×1000003 + 波次×10007 + 槽位序号×977 + 固定盐，
#    同关卡同槽位恒出同词条（可复现，情报/复打体验一致）。
#  - 效果消费走敌人 stats 既有路径：EnemyAffixes.apply_to_stats 把 effect_key 写进
#    UnitStats 字段，enemy_unit/_do_attack/take_damage/battle_damage_system 既有分支读取。
# ══════════════════════════════════════════════════════════════════

## 挂词条的最低档位（TIER_MID=2 中配起）
const LOADOUT_AFFIX_MIN_TIER: int = TIER_MID

## 档位 → 词条等级（档位越高词条越强；AffixResource.get_level_factor 折算数值）
const LOADOUT_AFFIX_LEVEL_BY_TIER: Dictionary = {
	TIER_MID: 2,   # 中配 → Lv2（×1.25）
	TIER_HIGH: 3,  # 高配 → Lv3（×1.55）
}

## 档位 → 词条稀有度（在定义 rarity_pool 内取；不在池内回退池末位）
const LOADOUT_AFFIX_RARITY_BY_TIER: Dictionary = {
	TIER_MID: "rare",
	TIER_HIGH: "epic",
}

## 敌方消费路径支持的 effect_key 白名单 = EnemyAffixes.apply_to_stats 既有分支的键。
## 排除玩家池中无敌方应用分支的三键（宁可少接不可乱接，避免"显示有词条但无效果"）：
##   attack_interval（敌方表用 attack_speed 语义，口径不同）
##   armor_penetration / shield_on_kill（字段消费点存在，但 apply_to_stats 无分支）
const LOADOUT_AFFIX_SUPPORTED_KEYS: Array = [
	"max_hp", "move_speed", "damage_reduction", "attack_damage", "attack_range",
	"crit_chance", "kill_repair", "splash_damage", "chain_chance", "defense",
	"hp_regen", "dodge_chance", "crit_damage_bonus",
]

## 波内槽位序号计数器（static，跨同波单位递增；波次号变化即重置）
## 说明：敌人生成按波次循环顺序创建（battle_spawn_system 波次循环逐个 setup），
## 此序号=同波内第 N 个符合条件的敌人，天然确定 ⇒ seed 可复现。
## 新战斗波次号从 1 重新开始，计数器随波次切换自动归零。
static var _loadout_seq_wave: int = -1
static var _loadout_seq_counter: int = 0

## 取本波下一个槽位序号（仅对符合条件的敌人调用，保证序号连续确定）
static func next_loadout_slot_ordinal(wave_index: int) -> int:
	if wave_index != _loadout_seq_wave:
		_loadout_seq_wave = wave_index
		_loadout_seq_counter = 0
	var ordinal: int = _loadout_seq_counter
	_loadout_seq_counter += 1
	return ordinal

## v21 P3-A：按 seed 抽 1 条玩家池词条，返回 EnemyAffixes 兼容的应用/显示字典。
## 返回 {} 表示无可挂词条（档位不足或池过滤后为空——调用方跳过）。
## 字段口径与 EnemyAffixes.ENEMY_AFFIXES roll 结果一致：
##   id/name/description（显示）+ effect_key/base_value（apply_to_stats 消费）+ rarity（int 显示档位色）。
## base_value 已折算最终量级 = 定义 base_value × 稀有度倍率 × 等级系数
## （apply_to_stats 直读 base_value，与玩家侧 AffixResource.recalculate 口径对齐）。
static func roll_loadout_affix_def(level_id: int, wave_index: int, slot_ordinal: int, combat_kind: int, uct_tier: int, tier: int) -> Dictionary:
	var pool: Array = []
	for def_id in AffixDefinitions.AFFIX_TABLE.keys():
		var def: Dictionary = AffixDefinitions.AFFIX_TABLE[def_id] as Dictionary
		# 效果键白名单（无敌方消费分支的键不进池）
		if not LOADOUT_AFFIX_SUPPORTED_KEYS.has(String(def.get("effect_key", ""))):
			continue
		# v21 P3-B: wired=false（执行挂点待接）的词条不进池（与玩家侧 roll 池同口径）
		if not bool(def.get("wired", true)):
			continue
		# 兵种/独特档门槛过滤（与敌方词缀 roll_affixes 同口径；敌人不受玩家 boss 解锁门控）
		var kinds: Array = def.get("combat_kinds", []) as Array
		if not kinds.is_empty() and not kinds.has(combat_kind):
			continue
		if int(def.get("min_tier", 0)) > uct_tier:
			continue
		pool.append(String(def_id))
	if pool.is_empty():
		return {}
	# seeded 随机：同关卡+同波+同槽位 ⇒ 同词条
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level_id) * 1000003 + int(wave_index) * 10007 + int(slot_ordinal) * 977 + 20260901
	var def_id: String = String(pool[rng.randi() % pool.size()])
	return build_loadout_affix_entry(def_id, tier)

## 把玩家词条定义折算成敌方应用/显示字典（roll 结果 → apply_to_stats + _elite_affixes 显示）。
## 稀有度 int 映射 EnemyAffixes.AffixRarity 显示档：common=0(白◇)/rare=1(紫◆)/epic·legendary=2(橙★)。
static func build_loadout_affix_entry(def_id: String, tier: int) -> Dictionary:
	var def: Dictionary = AffixDefinitions.get_definition(def_id)
	if def.is_empty():
		return {}
	var lv: int = int(LOADOUT_AFFIX_LEVEL_BY_TIER.get(tier, 2))
	var rarity: String = String(LOADOUT_AFFIX_RARITY_BY_TIER.get(tier, "rare"))
	# 稀有度须在定义 rarity_pool 内，否则回退池末位（防御异常配置）
	var rarity_pool: Array = def.get("rarity_pool", ["common"]) as Array
	if not rarity_pool.is_empty() and not rarity_pool.has(rarity):
		rarity = String(rarity_pool[rarity_pool.size() - 1])
	# 最终量级 = base × 稀有度倍率 × 等级系数（与 AffixResource.recalculate 同公式）
	var final_val: float = float(def.get("base_value", 0.0)) \
		* AffixResource.get_rarity_multiplier(rarity) * AffixResource.get_level_factor(lv)
	var rarity_int: int = 0
	match rarity:
		"rare": rarity_int = 1
		"epic", "legendary": rarity_int = 2
	return {
		"id": "loadout_%s" % def_id,          # 前缀区分同源词条与原生敌方词缀
		"name": String(def.get("affix_name", def_id)),
		"description": String(def.get("description", "")),
		"effect_key": String(def.get("effect_key", "")),
		"base_value": final_val,
		"rarity": rarity_int,
		"source_affix_id": def_id,            # 玩家池源词条 id（追溯用）
		"level": lv,
	}
