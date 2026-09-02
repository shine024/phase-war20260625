extends RefCounted
class_name EnemyLoadoutTiers
## v26: 敌方四档配装体系（新兵/老兵/精英/传奇，时代内循环，每 20 关一轮）
##
## 设计核心（v26 用户拍板）：
## - 档位由"时代内进度"切四段（in_era 1-5 新兵 / 6-11 老兵 / 12-17 精英 / 18-20 传奇），
##   每个时代都体验一轮档位爬升；相位师产兵恒传奇满配。
## - v26 起档位强度 = TIER_BONUS 标量 × 真实固定改造（enemy_fixed_loadouts.gd 逐卡配装，
##   挂载点 enemy_unit._apply_loadout_modifications）。改造贡献计入总量后标量相应下调，
##   目标总强度曲线 ≈ 新兵 1.40 / 老兵 1.65 / 精英 1.95 / 传奇 2.25（顶格，用户拍板），
##   终值以 tools/enemy_tier_strength_audit.gd 实测校准。
## - base 属性表已烤进时代递进（一战→近未来 hp 5-7×），公式不加时代系数。
## - v21 同源词条保留：精英起挂 1 条、传奇 2 条（稀有度随档）。
##
## 档位统一系数（裸卡=1.0；hp/atk/def 共用同一倍率；标量仅承担总量的一部分，
## 其余由真实改造贡献）：
##   新兵 = 5 改造 → ×1.20（标量）+ 改造 ≈ ×1.40 总
##   老兵 = 6-7 改造 → ×1.30 + 改造 ≈ ×1.65 总
##   精英 = 8-9 改造 → ×1.46 + 改造 ≈ ×1.95 总
##   传奇 = 9 改造满配 → ×1.66 + 改造 ≈ ×2.25 总（顶格）

## 档位枚举（v26 四档）
const TIER_RECRUIT: int = 1    # 新兵（时代内 1-5 关，5 改造）
const TIER_VETERAN: int = 2    # 老兵（6-11 关，6-7 改造）
const TIER_ELITE: int = 3      # 精英（12-17 关，8-9 改造）
const TIER_LEGENDARY: int = 4  # 传奇（18-20 关含末关 boss，9 改造满配）

## 旧三档常量别名（v25 前调用方兼容）：旧"高配"语义=满配 → 映射传奇；
## 旧"中配"→老兵；旧"低配"→新兵。新代码一律用新常量。
const TIER_LOW: int = TIER_RECRUIT
const TIER_MID: int = TIER_VETERAN
const TIER_HIGH: int = TIER_LEGENDARY

## 档位 → 加成配置（标量乘区；mod_count 为默认配装条数上限，逐卡 cuts 可微调）
const TIER_BONUS: Dictionary = {
	TIER_RECRUIT:   {"name": "新兵", "atk_pct": 0.20, "hp_pct": 0.20, "def_pct": 0.20, "mod_count": 5, "rune_count": 1, "enhance_level": 3},
	TIER_VETERAN:   {"name": "老兵", "atk_pct": 0.30, "hp_pct": 0.30, "def_pct": 0.30, "mod_count": 7, "rune_count": 3, "enhance_level": 6},
	TIER_ELITE:     {"name": "精英", "atk_pct": 0.46, "hp_pct": 0.46, "def_pct": 0.46, "mod_count": 9, "rune_count": 4, "enhance_level": 8},
	TIER_LEGENDARY: {"name": "传奇", "atk_pct": 0.66, "hp_pct": 0.66, "def_pct": 0.66, "mod_count": 9, "rune_count": 6, "enhance_level": 10},
}

## 档位显示名（world_map/UI 用）
static func get_tier_name(tier: int) -> String:
	return String(TIER_BONUS.get(tier, TIER_BONUS[TIER_RECRUIT]).get("name", "新兵"))

## 按档位取加成（产兵/敌兵核心调用）
static func get_bonus_for_tier(tier: int) -> Dictionary:
	return (TIER_BONUS.get(tier, TIER_BONUS[TIER_RECRUIT]) as Dictionary).duplicate()

## 按时代+关卡阶段选档位（普通关敌人用，v26 四段切分）
## era_progress: 时代内进度 0.0(早期)~1.0(后期)（in_era 1-20 → (in_era-1)/19）
static func get_tier_for_level_progress(era_progress: float, is_phase_master: bool = false) -> int:
	if is_phase_master:
		return TIER_LEGENDARY  # 相位师战固定传奇（旧路径保留，新代码用 get_phase_master_tier）
	# v26 四档：in_era 1-5 新兵（progress ≤0.21）/ 6-11 老兵 / 12-17 精英 / 18-20 传奇
	if era_progress < 0.24:
		return TIER_RECRUIT
	elif era_progress < 0.55:
		return TIER_VETERAN
	elif era_progress < 0.87:
		return TIER_ELITE
	else:
		return TIER_LEGENDARY

## 相位师产兵固定传奇满配（v26：旧"恒高配"语义升级为四档体系的顶格档）。
## 相位师的强弱差异由 base archetype 时代 + 自身 stats + 符文/相位仪决定，不靠产兵档位递进。
## 参数 era_progress 保留兼容签名，不再使用。
static func get_phase_master_tier(era_progress: float) -> int:
	return TIER_LEGENDARY

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

## 挂词条的最低档位（v26：精英档起挂——配装改造已承担新兵/老兵段的强度表达）
const LOADOUT_AFFIX_MIN_TIER: int = TIER_ELITE

## 档位 → 词条条数（v26：精英 1 条 / 传奇 2 条）
const LOADOUT_AFFIX_COUNT_BY_TIER: Dictionary = {
	TIER_ELITE: 1,
	TIER_LEGENDARY: 2,
}

## 档位 → 词条等级（档位越高词条越强；AffixResource.get_level_factor 折算数值）
const LOADOUT_AFFIX_LEVEL_BY_TIER: Dictionary = {
	TIER_ELITE: 3,     # 精英 → Lv3（×1.55）
	TIER_LEGENDARY: 3, # 传奇 → Lv3（×1.55，条数补偿 2 条）
}

## 档位 → 词条稀有度（在定义 rarity_pool 内取；不在池内回退池末位）
const LOADOUT_AFFIX_RARITY_BY_TIER: Dictionary = {
	TIER_ELITE: "epic",
	TIER_LEGENDARY: "epic",
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
