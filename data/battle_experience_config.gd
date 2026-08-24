extends RefCounted
class_name BattleExperienceConfig

## ═══════════════════════════════════════════════════════════
##  战斗经验升级配置（v18.c 改版：星级 → 卡等级 Lv1-30）
##  战斗卡通过战斗获得经验，累积达阈值自动升 card_level（上限 30）。
##  v20.12 等级统一：card_level 是玩家卡唯一等级轴（强化①/ enhance_level 手动强化已退役，
##  进化等级门槛/全部 UI 等级显示/光环星级均读 card_level）。
##  card_level 驱动：派生 flat 属性成长（CardGrowthConfig）+ 词条节点（每 5 级）。
##  旧 star_level（0-9）废弃：经验存档在，等级从存量经验重算，零迁移。
##
##  节奏定标（2026-08-20 实测）：每卡约 25-80 经验/关（胜 50 基数 + 击杀×5，
##  按上场卡数平分）。满级总成本 ≈ 50770，按平均 60/关 ≈ 85 关满级——
##  前 10 级快（约 8 关）保新手成长感，后 20 级随关卡推进摊开。
##  曲线：每级需求 ≈ 1.4 × lv^1.7（累计取整到十位）。
## ═══════════════════════════════════════════════════════════

## card_level 经验阈值（index = level，值 = 升到该级所需累计经验；index0 = 初始锚点 0，
## 对外钳制最小 Lv1——见 get_card_level_for_exp）
const LEVEL_EXP_THRESHOLDS: Array = [
	0,      # Lv0（未获得经验的初始态）
	10, 60, 150, 300, 520,          # Lv1-5（前 5 级约 8-10 关）
	820, 1200, 1680, 2260, 2960,   # Lv6-10
	3780, 4720, 5800, 7030, 8400,  # Lv11-15
	9930, 11620, 13470, 15500, 17710, # Lv16-20
	20100, 22680, 25450, 28430, 31610, # Lv21-25
	35000, 38610, 42440, 46490, 50770, # Lv26-30
]

## 最大卡等级（与相位师上限 30 统一，见 CardGrowthConfig.MAX_CARD_LEVEL）
const MAX_CARD_LEVEL: int = 30

## 每场胜利基础经验（所有上场存活卡平分前，先加这个基数）
const BATTLE_WIN_EXP_BASE: int = 50

## 每次击杀敌人额外经验（全队平分）
const BATTLE_KILL_EXP: int = 5

## 失败也给少量经验（鼓励继续战斗），为基础的 30%
const BATTLE_LOSE_EXP_RATIO: float = 0.30


## 根据累计经验计算 card_level
## 对外语义 1 基：新卡（exp<10 的 Lv0 锚点态）对外显示/结算为 Lv1；
## 表内 th[i] = 累计经验达到即升到 Lv i（th[1]=10 → 首次升级，th[30]=50770 → 满级）。
static func get_card_level_for_exp(exp: int) -> int:
	var level: int = 0
	for i in range(LEVEL_EXP_THRESHOLDS.size()):
		if exp >= int(LEVEL_EXP_THRESHOLDS[i]):
			level = i
		else:
			break
	return clampi(level, 1, MAX_CARD_LEVEL)


## 升到下一级的累计经验目标（返回 -1 表示已满级）
static func get_exp_for_next_level(current_level: int) -> int:
	if current_level >= MAX_CARD_LEVEL:
		return -1
	var idx: int = mini(current_level + 1, LEVEL_EXP_THRESHOLDS.size() - 1)
	return int(LEVEL_EXP_THRESHOLDS[idx])


## 当前级的进度（0.0-1.0，用于 UI 进度条）
## Lv1 为钳制初始态：展示区间 [0, th[2])——th[1]=10 是内部 Lv0→Lv1 锚点，不参与展示进度。
static func get_level_progress(exp: int) -> float:
	var level: int = get_card_level_for_exp(exp)
	if level >= MAX_CARD_LEVEL:
		return 1.0
	var cur: int = 0 if level <= 1 else int(LEVEL_EXP_THRESHOLDS[level])
	var nxt: int = get_exp_for_next_level(level)
	if nxt <= cur:
		return 1.0
	return clampf(float(exp - cur) / float(nxt - cur), 0.0, 1.0)


# ─────────────────────────────────────────────────────────────
#  兼容层：旧 star_level 接口整体退役（star 概念让位给等级）
# ─────────────────────────────────────────────────────────────

## [DEPRECATED v18.c] 旧升星接口——等价返回等级值，仅过渡期兼容，调用方应迁移
static func get_star_level_for_exp(exp: int) -> int:
	return get_card_level_for_exp(exp)
