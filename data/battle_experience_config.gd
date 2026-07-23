extends RefCounted
class_name BattleExperienceConfig

## ═══════════════════════════════════════════════════════════
##  战斗经验升星配置（v8.x 新增）
##  战斗卡通过战斗获得经验，累积达阈值自动升 star_level。
##  star_level 与 enhance_level 独立——enhance_level 保留手动强化①，
##  star_level 驱动 affix 加成（替代原 on_blueprint_star_up 随机触发）。
## ═══════════════════════════════════════════════════════════

## star_level 经验阈值（index = star_level，值 = 升到该星所需累计经验）
## 0 星 = 0 经验（初始），1 星 = 100，2 星 = 250 ... 9 星 = 9500
const STAR_EXP_THRESHOLDS: Array = [0, 100, 250, 500, 900, 1500, 2400, 3800, 6000, 9500]

## 最大星级
const MAX_STAR_LEVEL: int = 9

## 每场胜利基础经验（所有上场存活卡平分前，先加这个基数）
const BATTLE_WIN_EXP_BASE: int = 50

## 每次击杀敌人额外经验（全队平分）
const BATTLE_KILL_EXP: int = 5

## 失败也给少量经验（鼓励继续战斗），为基础的 30%
const BATTLE_LOSE_EXP_RATIO: float = 0.30


## 根据累计经验计算 star_level
static func get_star_level_for_exp(exp: int) -> int:
	var star: int = 0
	for i in range(STAR_EXP_THRESHOLDS.size()):
		if exp >= int(STAR_EXP_THRESHOLDS[i]):
			star = i
		else:
			break
	return mini(star, MAX_STAR_LEVEL)


## 升到下一星所需经验（返回 -1 表示已满级）
static func get_exp_for_next_star(current_star: int) -> int:
	if current_star >= MAX_STAR_LEVEL:
		return -1
	return int(STAR_EXP_THRESHOLDS[current_star + 1])


## 当前星的进度（0.0-1.0，用于 UI 进度条）
static func get_star_progress(exp: int) -> float:
	var star: int = get_star_level_for_exp(exp)
	if star >= MAX_STAR_LEVEL:
		return 1.0
	var cur_threshold: int = int(STAR_EXP_THRESHOLDS[star])
	var next_threshold: int = int(STAR_EXP_THRESHOLDS[star + 1])
	if next_threshold <= cur_threshold:
		return 1.0
	return clampf(float(exp - cur_threshold) / float(next_threshold - cur_threshold), 0.0, 1.0)
