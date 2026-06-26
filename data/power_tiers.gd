extends RefCounted
class_name PowerTiers
## v6.14: 战力档位统一表 —— 把离散 rank 与连续战力分值统一映射到 5 档。
##
## 设计理念：
## - "不同战力敌人/不同战力装改造"是本版的核心诉求，此前系统各自定义阈值（rank 三档、
##   星级、enhance_level），没有统一概念。本表作为共用基础，让改造掉落/安装门槛/
##   关卡掉落共享同一套档位语义。
## - 档位与现有 rank（normal/elite/boss）兼容：rank 直接映射到档位，避免破坏旧逻辑。
## - 档位与连续战力分值兼容：estimate_power_score_meta_only 的分值经阈值表映射到档位。
##
## 档位语义：
##   GRUNT     杂兵    —— 普通波次小怪，掉 common 改造，无安装门槛
##   VETERAN   老兵    —— 强化波次，掉 common/uncommon，门槛低
##   ELITE     精英    —— 精英单位/精英波，掉 uncommon/rare，需 VETERAN 装备
##   CHAMPION  勇士    —— 高阶敌人/相位师产兵，掉 rare/epic，需 ELITE 装备
##   OVERLORD  霸主    —— 相位师/Boss，掉 epic/legendary，需 CHAMPION 装备
##
## 查询接口：
##   PowerTiers.get_tier_by_rank(rank)          # "normal"|"elite"|"boss" → Tier
##   PowerTiers.get_tier_by_power(power_score)  # 连续分值 → Tier
##   PowerTiers.get_tier_name(tier)             # 中文名
##   PowerTiers.get_tier_color(tier)            # 配色（与稀有度色呼应）
##   PowerTiers.get_mod_drop_tier(tier)         # 该档位倾向掉落的改造稀有度（主稀有度）

enum Tier { GRUNT = 0, VETERAN = 1, ELITE = 2, CHAMPION = 3, OVERLORD = 4 }

const TIER_NAMES: Dictionary = {
	Tier.GRUNT: "杂兵",
	Tier.VETERAN: "老兵",
	Tier.ELITE: "精英",
	Tier.CHAMPION: "勇士",
	Tier.OVERLORD: "霸主",
}

const TIER_COLORS: Dictionary = {
	Tier.GRUNT: Color(0.70, 0.70, 0.70),       # 灰
	Tier.VETERAN: Color(0.40, 0.80, 0.40),     # 绿
	Tier.ELITE: Color(0.20, 0.50, 0.95),       # 蓝（与稀有 rare 呼应）
	Tier.CHAMPION: Color(0.65, 0.25, 0.90),    # 紫（与 epic 呼应）
	Tier.OVERLORD: Color(0.95, 0.65, 0.15),    # 金（与 legendary 呼应）
}

## 各档位倾向掉落的改造稀有度（主稀有度，实际抽取仍按权重，见 intel_manual_items）
const MOD_DROP_TIER: Dictionary = {
	Tier.GRUNT: "common",
	Tier.VETERAN: "common",
	Tier.ELITE: "rare",
	Tier.CHAMPION: "epic",
	Tier.OVERLORD: "legendary",
}

## 连续战力分值 → 档位 阈值（上界，与 evolution_helpers.estimate_power_score_meta_only 量级对齐）
## 分值公式参考：(80 + enhance_level×28 + mod_count×22) × rarity_mul × (1 + inherit_bonus)
## GRUNT < 150 < VETERAN < 300 < ELITE < 600 < CHAMPION < 1000 < OVERLORD
const POWER_THRESHOLDS: Array = [150, 300, 600, 1000]


## 按现有 rank（normal/elite/boss）映射到档位。未知值回退 GRUNT。
static func get_tier_by_rank(rank: String) -> int:
	match rank:
		"normal":
			return Tier.GRUNT
		"veteran":
			return Tier.VETERAN
		"elite":
			return Tier.ELITE
		"champion":
			return Tier.CHAMPION
		"boss":
			return Tier.OVERLORD
		_:
			return Tier.GRUNT


## 按连续战力分值映射到档位。
static func get_tier_by_power(power_score: float) -> int:
	var ps: float = float(power_score)
	for i in range(POWER_THRESHOLDS.size()):
		if ps < POWER_THRESHOLDS[i]:
			return i
	return POWER_THRESHOLDS.size()  # 超过最高阈值 → OVERLORD


## 档位中文名。
static func get_tier_name(tier: int) -> String:
	return String(TIER_NAMES.get(tier, "杂兵"))


## 档位配色。
static func get_tier_color(tier: int) -> Color:
	return TIER_COLORS.get(tier, TIER_COLORS[Tier.GRUNT])


## 该档位倾向掉落的改造稀有度（主稀有度）。
static func get_mod_drop_tier(tier: int) -> String:
	return String(MOD_DROP_TIER.get(tier, "common"))


## 档位是否达到安装某改造的要求（min_tier 为该改造定义的最小档位，缺省 GRUNT）。
static func meets_requirement(card_tier: int, min_tier: int) -> bool:
	return card_tier >= min_tier
