extends RefCounted
class_name RankRules

## 军衔规则（视觉层 + 轻度数值层）— v3 十三级：士3 / 尉3 / 校3 / 将3 / 元帅1

const RANK_ORDER: Array[String] = [
	"private",              # 1 列兵
	"corporal",             # 2 下士
	"sergeant",             # 3 中士
	"second_lieutenant",    # 4 少尉
	"first_lieutenant",     # 5 中尉
	"captain",              # 6 上尉
	"major",                # 7 少校
	"lieutenant_colonel", # 8 中校
	"colonel",              # 9 上校
	"brigadier",            # 10 少将
	"major_general",        # 11 中将
	"general",              # 12 上将
	"marshal",              # 13 元帅
]

const RANK_DISPLAY_NAMES: Dictionary = {
	"private": "列兵",
	"corporal": "下士",
	"sergeant": "中士",
	"second_lieutenant": "少尉",
	"first_lieutenant": "中尉",
	"captain": "上尉",
	"major": "少校",
	"lieutenant_colonel": "中校",
	"colonel": "上校",
	"brigadier": "少将",
	"major_general": "中将",
	"general": "上将",
	"marshal": "元帅",
}

const BASE_RANK_BY_PLATFORM_TYPE: Dictionary = {
	0: "corporal",
	1: "sergeant",
	2: "captain",
	3: "captain",
	4: "second_lieutenant",
	5: "major",
	6: "major",
	7: "sergeant",
	8: "captain",
	9: "captain",
	10: "major",
	11: "captain",   # OMEGA_PLATFORM
	12: "major",     # COMMAND
}

const POWER_THRESHOLDS: Dictionary = {
	# v7.x 战力公式全修（用户主导设计最终版）：HP×0.35 + DPS三维各自配对×0.75×(1+暴击×0.5)
	# + avg_speed×25 + (三维防御和)×2.1 + 穿甲×5 + 移速×0.25。
	# 新公式量级显著放大（终极卡裸卡 ~3600 分），阈值同步 ×2.5 防止"终极卡裸卡即元帅"。
	# 校准目标：初期卡裸卡=下士/中士、冷战卡裸卡=上尉、终极卡裸卡=上将（未到顶）、
	# 终极卡满养=元帅（养满才到顶）。养成有意义、时代递进清晰。
	# RANK_BONUS（hp/dmg 加成）不变——军衔数值加成与战力公式解耦。
	"private": 0.0,
	"corporal": 100.0,            # 40 → 100
	"sergeant": 250.0,            # 100 → 250
	"second_lieutenant": 400.0,   # 160 → 400
	"first_lieutenant": 550.0,    # 220 → 550
	"captain": 750.0,             # 300 → 750
	"major": 1000.0,              # 400 → 1000
	"lieutenant_colonel": 1300.0, # 520 → 1300
	"colonel": 1650.0,            # 660 → 1650
	"brigadier": 2050.0,          # 820 → 2050
	"major_general": 2500.0,      # 1000 → 2500
	"general": 3000.0,            # 1200 → 3000
	"marshal": 3625.0,            # 1450 → 3625（≈终极卡裸卡战力，满养才稳定破）
}

const RANK_BONUS: Dictionary = {
	"private": {"hp_mul": 1.00, "dmg_mul": 1.00},
	"corporal": {"hp_mul": 1.01, "dmg_mul": 1.01},
	"sergeant": {"hp_mul": 1.02, "dmg_mul": 1.02},
	"second_lieutenant": {"hp_mul": 1.025, "dmg_mul": 1.025},
	"first_lieutenant": {"hp_mul": 1.03, "dmg_mul": 1.03},
	"captain": {"hp_mul": 1.035, "dmg_mul": 1.035},
	"major": {"hp_mul": 1.04, "dmg_mul": 1.04},
	"lieutenant_colonel": {"hp_mul": 1.045, "dmg_mul": 1.045},
	"colonel": {"hp_mul": 1.05, "dmg_mul": 1.05},
	"brigadier": {"hp_mul": 1.055, "dmg_mul": 1.055},
	"major_general": {"hp_mul": 1.06, "dmg_mul": 1.06},
	"general": {"hp_mul": 1.065, "dmg_mul": 1.065},
	"marshal": {"hp_mul": 1.07, "dmg_mul": 1.07},
}

## v3：根据战斗定位（combat_kind）获取基础军衔
static func get_base_rank_by_combat_kind(combat_kind: int) -> String:
	match combat_kind:
		0:  # LIGHT
			return "corporal"
		1:  # ARMOR
			return "sergeant"
		2:  # SUPPORT
			return "captain"
		3:  # AIR
			return "second_lieutenant"
		4:  # FORT（v5.0）
			return "major"
		_:
			return "corporal"

static func get_base_rank(platform_type: int) -> String:
	return String(BASE_RANK_BY_PLATFORM_TYPE.get(platform_type, "corporal"))

static func get_rank_display_name(rank_id: String) -> String:
	return String(RANK_DISPLAY_NAMES.get(rank_id, rank_id))

static func get_rank_by_power(base_rank: String, power_score: float) -> String:
	var best: String = base_rank
	var base_index: int = RANK_ORDER.find(base_rank)
	if base_index < 0:
		base_index = 0
	for i in range(base_index, RANK_ORDER.size()):
		var rank_id: String = RANK_ORDER[i]
		var need: float = float(POWER_THRESHOLDS.get(rank_id, 99999.0))
		if power_score >= need:
			best = rank_id
	return best

static func get_rank_bonus(rank_id: String) -> Dictionary:
	return (RANK_BONUS.get(rank_id, {"hp_mul": 1.0, "dmg_mul": 1.0}) as Dictionary).duplicate(true)


## 卡顶军衔条：1–12 为士/尉/校/将（每层 3 格），13 = 元帅（第 5 层首格）
const RANK_LEVEL_MAX: int = 13
const RANK_TIER_ROW_COUNT: int = 5
const RANK_ICONS_PER_ROW: int = 3

const LEGACY_RANK_TO_LEVEL: Dictionary = {
	"private": 1,
	"corporal": 2,
	"sergeant": 3,
	"second_lieutenant": 4,
	"first_lieutenant": 5,
	"lieutenant": 5,
	"captain": 6,
	"major": 7,
	"lieutenant_colonel": 8,
	"colonel": 9,
	"brigadier": 10,
	"major_general": 11,
	"general": 12,
	"marshal": 13,
}


static func rank_id_to_level(rank_id: String) -> int:
	return clampi(int(LEGACY_RANK_TO_LEVEL.get(rank_id, 1)), 0, RANK_LEVEL_MAX)


static func visible_tier_count(rank_level: int) -> int:
	rank_level = clampi(rank_level, 0, RANK_LEVEL_MAX)
	if rank_level <= 0:
		return 0
	if rank_level >= RANK_LEVEL_MAX:
		return RANK_TIER_ROW_COUNT
	return mini(4, int((rank_level - 1) / RANK_ICONS_PER_ROW) + 1)


static func is_rank_icon_shown(rank_level: int, tier_index: int, slot_in_row: int) -> bool:
	if tier_index >= visible_tier_count(rank_level):
		return false
	if tier_index == 4:
		return slot_in_row == 0
	return true


static func is_rank_icon_lit(rank_level: int, tier_index: int, slot_in_row: int) -> bool:
	if not is_rank_icon_shown(rank_level, tier_index, slot_in_row):
		return false
	if tier_index == 4:
		return rank_level >= RANK_LEVEL_MAX
	var global_slot: int = tier_index * RANK_ICONS_PER_ROW + slot_in_row + 1
	return global_slot <= mini(rank_level, 12)
