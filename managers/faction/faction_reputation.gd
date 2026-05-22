extends RefCounted
## 势力声望子系统：管理声望值、等级计算、关卡攻克反应
##
## 从 faction_system_manager.gd 拆分的职责：
## - 声望增减与等级晋升
## - 关卡攻克后的势力反应公式（慕强心理 + 关系系数）
## - 等级进度查询

class_name FactionReputation

## 声望上限
const MAX_REPUTATION: int = 10000

## 新游戏 / 存档缺键时各势力默认声望
const DEFAULT_STARTING_REPUTATION: int = 5000

## 等级阈值表（索引 = 等级 - 1）
## Lv1: 0-500, Lv2: 500-1200, ... Lv10: 9000+
const LEVEL_THRESHOLDS: Array = [0, 500, 1200, 2000, 2900, 3900, 5000, 6200, 7500, 9000]

## 全局访问的等级阈值（8级 = 6200+）
const GLOBAL_ACCESS_THRESHOLD: int = 6200

## 各关系类型对应的声望系数
const RELATIONSHIP_EFFECT: Dictionary = {
	"allied": -15,
	"rival": 10,
	"enemy": 20,
	"neutral": 0,
}

## 根据声望值计算势力等级（1-10）
## @param rep: int 当前声望值
## @return int 等级 1-10
static func get_level_from_reputation(rep: int) -> int:
	for i in range(LEVEL_THRESHOLDS.size()):
		if rep < LEVEL_THRESHOLDS[i]:
			return i
	return 10

## 计算声望变化后的新值
## @param current_rep: int 当前声望
## @param delta: int 变化量
## @return Dictionary { "new_rep": int, "old_level": int, "new_level": int, "leveled_up": bool }
static func apply_delta(current_rep: int, delta: int) -> Dictionary:
	var old_level: int = get_level_from_reputation(current_rep)
	var new_rep: int = clampi(current_rep + delta, 0, MAX_REPUTATION)
	var new_level: int = get_level_from_reputation(new_rep)
	return {
		"new_rep": new_rep,
		"old_level": old_level,
		"new_level": new_level,
		"leveled_up": new_level > old_level,
	}

## 获取升级进度
## @param current_rep: int 当前声望
## @param current_level: int 当前等级
## @return Dictionary { "level": int, "progress": float, "current": int, "needed": int }
static func get_progress_to_next_level(current_rep: int, current_level: int) -> Dictionary:
	if current_level >= 10:
		return {"level": 10, "progress": 1.0, "current": current_rep, "needed": current_rep}

	var idx: int = current_level - 1
	var current_threshold: int = LEVEL_THRESHOLDS[idx] if idx < LEVEL_THRESHOLDS.size() else 0
	var next_threshold: int = LEVEL_THRESHOLDS[idx + 1] if idx + 1 < LEVEL_THRESHOLDS.size() else current_threshold

	var progress: float = float(current_rep - current_threshold) / float(next_threshold - current_threshold)

	return {
		"level": current_level,
		"progress": clampf(progress, 0.0, 1.0),
		"current": current_rep - current_threshold,
		"needed": next_threshold - current_threshold,
	}

## 计算关卡攻克后的势力声望反应
## @param conquered_faction: String 被攻占势力ID
## @param faction_relations: Dictionary 势力关系矩阵
## @param all_faction_ids: Array[String] 所有势力ID
## @return Dictionary { faction_id: delta } 每个势力的声望变化量
static func calculate_conquest_reaction(conquered_faction: String, faction_relations: Dictionary, all_faction_ids: Array) -> Dictionary:
	var reactions: Dictionary = {}

	# 被攻占势力：-10（领地失守）
	reactions[conquered_faction] = -10

	# 其他势力根据关系反应
	var relations: Dictionary = faction_relations.get(conquered_faction, {})
	for other_fid in all_faction_ids:
		if other_fid == conquered_faction:
			continue
		var rel_type: String = relations.get(other_fid, "neutral")
		var delta: int = RELATIONSHIP_EFFECT.get(rel_type, 5)
		if delta != 0:
			reactions[other_fid] = delta

	return reactions

## 检查是否拥有全局访问（任一势力声望达到阈值）
## @param faction_reputation: Dictionary { faction_id: rep_value }
## @return bool
static func has_global_access(faction_reputation: Dictionary) -> bool:
	for fid in faction_reputation:
		if int(faction_reputation[fid]) >= GLOBAL_ACCESS_THRESHOLD:
			return true
	return false
