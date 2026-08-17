extends RefCounted
class_name PowerTiers
## v6.14: 战力档位统一表 —— 把离散 rank 与连续战力分值统一映射到 5 档。
##
## 设计理念：
## - "不同战力敌人/不同战力装改造"是本版的核心诉求，此前系统各自定义阈值（rank 三档、
##   星级、enhance_level），没有统一概念。本表作为共用基础，让改造掉落/安装门槛/
##   关卡掉落共享同一套档位语义。
## - 档位与现有 rank（normal/elite/boss）兼容：rank 直接映射到档位，避免破坏旧逻辑。
## - 档位与连续战力分值兼容：战斗公式战力分（evolution_helpers.estimate_power_score）经阈值表映射到档位（v9.x 重标，见 POWER_THRESHOLDS 注释）。
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

## 连续战力分值 → 档位 阈值（上界）
## v9.x 重设：标尺统一为战斗公式 EvolutionHelpers.estimate_power_score（combat_power_from_unit_stats）。
## 全部 5 个调用方（install_modification 门槛 + modification_panel 显示×4）传的本就是战斗公式值，
## 原阈值 [150,260,420,720] 却是按 meta_only 简化公式校准的——两套量级差 2-3 倍，判定长期错位。
##
## 实测分布（tests/power_calibration_probe.gd，白板/强化5+2改/强化10+5改）：
##   战斗公式下投入养成仅抬升 ~10% 战力，时代+兵种决定主体——阈值语义从"投入深度"
##   改为"时代台阶"：步兵与装甲同类同时代差 ~2.6 倍，各档位含义如下：
##   VETERAN 250+ : 一战/二战步兵（253/365）起步即达
##   ELITE   600+ : 早期装甲（WW1 662/WW2 715）与现代步兵（786）
##   CHAMPION 900+: 冷战装甲（917）、现代侦察（906）、未来步兵（1095）
##   OVERLORD 1300+: 现代坦克（白板 1296 需轻度投入跨线 → 强化5 1418）与未来全系（1869+）
## 与掉落节奏自洽：rare 改造从 ELITE 敌人掉落时，玩家手上已有 WW2+ 装甲可装。
##
## 历史校准记录：
##   v7.x H4: [150,300,600,1000]→[150,260,420,720]（当时按 meta_only 公式校准，见旧注释）
##   v9.x: →[250,600,900,1300]（战斗公式重标，上表）
const POWER_THRESHOLDS: Array = [250, 600, 900, 1300]


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


## v7.x: rank + 关卡进度 混合档位 —— 让普通关卡的改造蓝图稀有度随关卡进度提升。
## 解决"第1关和第100关打杂兵，改造蓝图稀有度完全一样"的失衡：
## 杂兵 rank 恒为 normal→GRUNT，但高关杂兵理应掉更好的改造。
##
## 关卡偏移（前20关一战教学不加，避免新手过早拿到高档改造）：
##   level 1-20  → +0（一战时代，掉落最朴素）
##   level 21-40 → +1（二战时代）
##   level 41-70 → +2（冷战/现代）
##   level 71-100 → +3（近未来，杂兵也能掉 epic 为主）
##
## 与 rank 叠加后 clamp 到 OVERLORD，保证不会超过真正的 boss。
## 注意：boss rank 本身已是 OVERLORD，叠加 level 偏移后仍为 OVERLORD，行为不变。
static func get_tier_by_rank_and_level(rank: String, level: int) -> int:
	var base_tier: int = get_tier_by_rank(rank)
	var lvl_offset: int = 0
	var lvl: int = maxi(1, int(level))
	if lvl <= 20:
		lvl_offset = 0
	elif lvl <= 40:
		lvl_offset = 1
	elif lvl <= 70:
		lvl_offset = 2
	else:
		lvl_offset = 3
	return clampi(base_tier + lvl_offset, Tier.GRUNT, Tier.OVERLORD)


## 按连续战力分值映射到档位。
static func get_tier_by_power(power_score: float) -> int:
	var ps: float = float(power_score)
	for i in range(POWER_THRESHOLDS.size()):
		if ps < POWER_THRESHOLDS[i]:
			return i
	return POWER_THRESHOLDS.size()  # 超过最高阈值 → OVERLORD


## v7.x: 按相位师星级（MasterPowerEvaluator 1-7★）映射到档位。
## 用于 game_manager 相位师击败后的改造蓝图掉落梯度（替代原 level*40 的 ad-hoc 换算）。
## 映射：1★→GRUNT, 2★→VETERAN, 3★→ELITE, 4★/5★→CHAMPION, 6★/7★→OVERLORD。
## 越界值 clamp 到 [1, 7]。
static func get_tier_by_stars(stars: int) -> int:
	match clampi(stars, 1, 7):
		1:
			return Tier.GRUNT
		2:
			return Tier.VETERAN
		3:
			return Tier.ELITE
		4, 5:
			return Tier.CHAMPION
		_:
			return Tier.OVERLORD   # 6, 7


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
