extends RefCounted
class_name IntelModThresholds
## 改造模块情报解锁点数阈值表
##
## 每个稀有度对应一个累积点数门槛，敌方卡每次击败/部署时向对应池注入点数，
## 达到门槛后该改造自动解锁。
##
## 点数获取参考（敌方卡 archetype 维度）：
##   首次遭遇：+0（仅 base_progress）
##   击败普通：+1 point（随机 common 池内一 mod）
##   击败精英：+2 points
##   击败 Boss：+3 points
##   部署一次：+2~5 points（按 mod rarity 浮动）
##   商店购卡：base=50%，mod_points 不变
##
## 达到 100% base intel 时，该卡所有改造无条件全解锁（绕过点数检查）。

# ── 阈值表（点数）───────────────────────────────────────────────────────────
const THRESHOLDS: Dictionary = {
	"common":    5,
	"uncommon": 12,
	"rare":      25,
	"epic":      50,
	"legendary": 80,
	"mythic":   120,
}

# ── 快捷常量 ────────────────────────────────────────────────────────────────
const T_COMMON:    int = 5
const T_UNCOMMON:  int = 12
const T_RARE:      int = 25
const T_EPIC:      int = 50
const T_LEGENDARY: int = 80
const T_MYTHIC:    int = 120

## 获取某稀有度所需的解锁点数
static func get_threshold(rarity: String) -> int:
	return int(THRESHOLDS.get(rarity, T_COMMON))

## 获取某稀有度的中文名称
static func get_rarity_name(rarity: String) -> String:
	match rarity:
		"common":    return "普通"
		"uncommon":  return "优秀"
		"rare":      return "稀有"
		"epic":      return "史诗"
		"legendary": return "传说"
		"mythic":    return "神话"
		_:           return rarity

## 检查某 mod 是否已解锁（需要 mod_data 和已累积点数）
static func is_unlocked(mod_data: Dictionary, current_points: int) -> bool:
	var rarity: String = String(mod_data.get("rarity", "common"))
	var threshold: int = get_threshold(rarity)
	return current_points >= threshold

## 获取解锁进度百分比（0.0~1.0，超过 1.0 表示已满）
static func get_unlock_progress(mod_data: Dictionary, current_points: int) -> float:
	var rarity: String = String(mod_data.get("rarity", "common"))
	var threshold: int = get_threshold(rarity)
	if threshold <= 0:
		return 1.0
	return clampf(float(current_points) / float(threshold), 0.0, 1.0)

## 获取还需要多少点才能解锁
static func points_needed(mod_data: Dictionary, current_points: int) -> int:
	var rarity: String = String(mod_data.get("rarity", "common"))
	var threshold: int = get_threshold(rarity)
	return maxi(0, threshold - current_points)
