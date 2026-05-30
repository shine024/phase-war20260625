extends RefCounted
class_name FactionSkillManager

const SkillTree = preload("res://data/faction_skill_tree.gd")

## 创建默认状态
static func create_default_state(faction_id: String) -> Dictionary:
	return {
		"unlocked_skills": [],
		"spent_points": 0,
		"bonus_points": 0,
	}

## 能否解锁技能
static func can_unlock_skill(state: Dictionary, faction_id: String, skill_id: String, faction_level: int) -> Dictionary:
	var skill: Dictionary = SkillTree.get_skill(faction_id, skill_id)
	if skill.is_empty():
		return {"ok": false, "reason": "skill_not_found"}
	if skill_id in state.get("unlocked_skills", []):
		return {"ok": false, "reason": "already_unlocked"}
	var tier: int = int(skill.get("tier", 99))
	if faction_level < tier:
		return {"ok": false, "reason": "level_not_enough"}
	var cost: int = int(skill.get("cost", 1))
	var total_spent: int = int(state.get("spent_points", 0))
	var max_pts: int = SkillTree.max_skill_points_at_level(faction_level) + int(state.get("bonus_points", 0))
	if total_spent + cost > max_pts:
		return {"ok": false, "reason": "not_enough_points"}
	# 检查分支互斥
	var branch: String = skill.get("branch", "")
	if not branch.is_empty():
		var same_tier: Array = SkillTree.get_skills_at_tier(faction_id, tier)
		for other in same_tier:
			if other.get("branch", "") == branch and other.get("id", "") != skill_id:
				if other.get("id", "") in state.get("unlocked_skills", []):
					return {"ok": false, "reason": "branch_conflict"}
	return {"ok": true, "cost": cost}

## 解锁技能
static func unlock_skill(state: Dictionary, faction_id: String, skill_id: String, faction_level: int) -> bool:
	var can: Dictionary = can_unlock_skill(state, faction_id, skill_id, faction_level)
	if not can.get("ok", false):
		return false
	var cost: int = int(can.get("cost", 1))
	if not state.has("unlocked_skills"):
		state["unlocked_skills"] = []
	state["unlocked_skills"].append(skill_id)
	state["spent_points"] = int(state.get("spent_points", 0)) + cost
	return true

## 获取所有已解锁技能效果（合并计算）
static func get_active_effects(state: Dictionary, faction_id: String) -> Dictionary:
	var merged: Dictionary = {"stat_bonus": {}, "deploy": {}, "resource": {}, "special": []}
	if not state.has("unlocked_skills"):
		return merged
	for sid in state["unlocked_skills"]:
		var skill: Dictionary = SkillTree.get_skill(faction_id, sid)
		var fx: Dictionary = skill.get("effects", {})
		# 合并 stat_bonus
		if fx.has("stat_bonus"):
			for k in fx["stat_bonus"]:
				var v: float = float(fx["stat_bonus"][k])
				if not merged["stat_bonus"].has(k):
					merged["stat_bonus"][k] = 0.0
				merged["stat_bonus"][k] += v
		# 收集 deploy
		if skill.get("effect_type", "") == "deploy":
			merged["deploy"] = fx
		# 收集 resource
		if skill.get("effect_type", "") == "resource":
			for k in fx:
				if not merged["resource"].has(k):
					merged["resource"][k] = 0.0
				merged["resource"][k] += float(fx[k])
		# 收集 special
		if skill.get("effect_type", "") == "special":
			merged["special"].append(fx)
	return merged

## 获取已花费点数
static func get_total_spent(state: Dictionary) -> int:
	return int(state.get("spent_points", 0))

## 获取可用点数
static func get_available_points(state: Dictionary, faction_level: int) -> int:
	var max_pts: int = SkillTree.max_skill_points_at_level(faction_level) + int(state.get("bonus_points", 0))
	return max_pts - int(state.get("spent_points", 0))

## 添加额外技能点（任务/事件奖励）
static func add_bonus_points(state: Dictionary, amount: int) -> void:
	state["bonus_points"] = int(state.get("bonus_points", 0)) + amount

## 重置指定分支的技能（返还点数）
## @param tier: 要重置的等级层
## @param branch: 要重置的分支（"A" 或 "B"）
## @return Array: 被移除的技能ID列表
static func reset_branch(state: Dictionary, faction_id: String, tier: int, branch: String) -> Array:
	var removed: Array = []
	if not state.has("unlocked_skills"):
		return removed
	var same_tier: Array = SkillTree.get_skills_at_tier(faction_id, tier)
	for other in same_tier:
		if other.get("branch", "") == branch:
			var sid: String = other.get("id", "")
			if sid in state["unlocked_skills"]:
				state["unlocked_skills"].erase(sid)
				state["spent_points"] = maxi(0, int(state.get("spent_points", 0)) - int(other.get("cost", 1)))
				removed.append(sid)
	return removed

## 重置整个技能树（返还所有点数）
## @return int: 返还的点数
static func reset_all(state: Dictionary) -> int:
	var total_spent: int = int(state.get("spent_points", 0))
	state["unlocked_skills"] = []
	state["spent_points"] = 0
	return total_spent

## 检查指定tier/branch是否已解锁
static func is_branch_unlocked(state: Dictionary, faction_id: String, tier: int, branch: String) -> bool:
	var same_tier: Array = SkillTree.get_skills_at_tier(faction_id, tier)
	for other in same_tier:
		if other.get("branch", "") == branch:
			if other.get("id", "") in state.get("unlocked_skills", []):
				return true
	return false
