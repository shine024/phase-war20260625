extends RefCounted
class_name AchievementDefinitions
## 扩展成就系统定义：包含100+成就，覆盖所有游戏内容

## 数据子模块预加载
const _Combat = preload("res://data/achievements_combat.gd")
const _Collection = preload("res://data/achievements_collection.gd")
const _Special = preload("res://data/achievements_special.gd")

## 成就状态枚举
enum Status {
	LOCKED,     # 未解锁
	UNLOCKED,   # 已解锁但未完成
	PROGRESS,   # 进行中
	COMPLETED   # 已完成
}

## 成就稀有度
enum Rarity {
	COMMON,     # 普通 (绿色)
	UNCOMMON,   # 稀有 (蓝色)
	RARE,       # 罕见 (紫色)
	EPIC,       # 史诗 (橙色)
	LEGENDARY    # 传说 (红色)
}

## 合并所有子模块数据
static func _build_achievements() -> Dictionary:
	var d: Dictionary = {}
	d.merge(_Combat.DATA)
	d.merge(_Collection.DATA)
	d.merge(_Special.DATA)
	return d

## 成就定义表（运行时合并，保持 const 名向后兼容）
const ACHIEVEMENTS: Dictionary = {}

## 运行时合并缓存
static var _achievements_initialized: bool = false
static var _merged_achievements: Dictionary = {}

static func _get_achievements() -> Dictionary:
	if not _achievements_initialized:
		_merged_achievements = _build_achievements()
		_achievements_initialized = true
	return _merged_achievements

## 获取成就定义
static func get_achievement(achievement_id: String) -> Dictionary:
	if _get_achievements().has(achievement_id):
		return _get_achievements()[achievement_id]
	return {}

## 获取分类成就
static func get_achievements_by_category(category: String) -> Array:
	var result = []
	for achievement_id in _get_achievements():
		var achievement = _get_achievements()[achievement_id]
		if achievement.get("category", "") == category:
			result.append(achievement)
	return result

## 获取稀有度成就
static func get_achievements_by_rarity(rarity: String) -> Array:
	var	result = []
	for achievement_id in _get_achievements():
		var achievement = _get_achievements()[achievement_id]
		if achievement.get("rarity", "") == rarity:
			result.append(achievement)
	return result

## 获取隐藏成就
static func get_hidden_achievements() -> Array:
	var result = []
	for achievement_id in _get_achievements():
		var achievement = _get_achievements()[achievement_id]
		if achievement.get("hidden", false):
			result.append(achievement)
	return result

## 获取可见成就
static func get_visible_achievements() -> Array:
	var result = []
	for achievement_id in _get_achievements():
		var achievement = _get_achievements()[achievement_id]
		if not achievement.get("hidden", false):
			result.append(achievement)
	return result

## 检查成就完成条件
static func check_achievement_requirements(achievement_id: String, player_data: Dictionary) -> Dictionary:
	var achievement = get_achievement(achievement_id)
	if achievement.is_empty():
		return {"completed": false, "progress": 0, "total": 0}

	var requirements = achievement.get("requirements", {})
	var requirement_type = requirements.get("type", "")
	var requirement_count = requirements.get("count", 1)
	var current_progress = 0
	var completed = false

	match requirement_type:
		"wins":
			current_progress = player_data.get("total_wins", 0)
			completed = current_progress >= requirement_count
		"kills":
			current_progress = player_data.get("total_kills", 0)
			completed = current_progress >= requirement_count
		"total_damage":
			current_progress = player_data.get("total_damage_dealt", 0)
			completed = current_progress >= requirement_count
		"no_damage_win":
			current_progress = player_data.get("no_damage_wins", 0)
			completed = current_progress >= requirement_count
		"fast_win":
			# 需要具体实现检查
			completed = false
		"win_streak":
			current_progress = player_data.get("current_win_streak", 0)
			completed = current_progress >= requirement_count
		"unique_blueprints":
			current_progress = player_data.get("unique_blueprints", []).size()
			completed = current_progress >= requirement_count
		"max_level":
			current_progress = player_data.get("max_level_reached", 1)
			completed = current_progress >= requirement_count
		"complete_era":
			var era = requirements.get("era", "")
			current_progress = player_data.get("completed_eras", {}).get(era, 0)
			completed = current_progress > 0
		"all_3_stars":
			# 需要检查所有关卡是否都是3星
			completed = false
		"survival_waves":
			current_progress = player_data.get("max_survival_waves", 0)
			completed = current_progress >= requirement_count
		"defeat_all_masters":
			current_progress = player_data.get("defeated_masters", []).size()
			completed = current_progress >= requirement_count
		_:
			completed = false
			current_progress = 0

	return {
		"completed": completed,
		"progress": current_progress,
		"total": requirement_count,
		"percentage": float(current_progress) / float(requirement_count) if requirement_count > 0 else 1.0
	}

## 获取成就奖励
static func get_achievement_rewards(achievement_id: String) -> Dictionary:
	var achievement = get_achievement(achievement_id)
	if achievement.is_empty():
		return {}
	return achievement.get("reward", {})

## 格式化成就进度
static func format_achievement_progress(achievement_id: String, current: int, total: int) -> String:
	var achievement = get_achievement(achievement_id)
	if achievement.is_empty():
		return ""

	var name = achievement.get("name", "")
	var requirement_type = achievement.get("requirements", {}).get("type", "")

	match requirement_type:
		"wins":
			return "%s: %d/%d 场胜利" % [name, current, total]
		"kills":
			return "%s: %d/%d 击杀" % [name, current, total]
		"total_damage":
			var damage_str = str(current) if current < 1000 else str(current / 1000) + "k"
			return "%s: %s/%s 伤害" % [name, damage_str, str(total / 1000) + "k"]
		"unique_blueprints":
			return "%s: %d/%d 蓝图" % [name, current, total]
		"max_level":
			return "%s: 第%d/%d 关" % [name, current, total]
		"survival_waves":
			return "%s: %d/%d 波" % [name, current, total]
		_:
			return "%s: %d/%d" % [name, current, total]