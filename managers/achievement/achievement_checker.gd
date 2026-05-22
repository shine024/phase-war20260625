extends RefCounted
## 成就检查器：负责检查成就解锁条件
##
## 从 achievement_manager.gd 拆分的职责：
## - 遍历成就数据库，比对统计数据与条件
## - 支持 20+ 种条件类型（wins / kills / damage_dealt / collection / progress ...）
## - 提供按分类批量检查、进度查询

class_name AchievementChecker

## 检查单个成就是否满足解锁条件
## @param ach_data: 成就定义字典（来自 ACHIEVEMENT_DATABASE）
## @param stats_map: 统计数据合集，包含 battle_stats / collection_stats / progress_stats / challenge_stats / system_stats
## @return bool
static func check_single(ach_data: Dictionary, stats_map: Dictionary) -> bool:
	var requirements: Dictionary = ach_data.get("requirements", {})
	if requirements.is_empty():
		return false

	var req_type: String = requirements.get("type", "")
	var req_count: int = requirements.get("count", 0)
	var req_target: String = requirements.get("target", "")

	var battle: Dictionary = stats_map.get("battle", {})
	var collection: Dictionary = stats_map.get("collection", {})
	var progress: Dictionary = stats_map.get("progress", {})
	var challenge: Dictionary = stats_map.get("challenge", {})
	var system: Dictionary = stats_map.get("system", {})

	match req_type:
		"wins":
			return int(battle.get("total_wins", 0)) >= req_count
		"kills":
			return int(battle.get("total_kills", 0)) >= req_count
		"damage_dealt":
			return int(battle.get("total_damage_dealt", 0)) >= req_count
		"no_damage_wins":
			return int(battle.get("no_damage_wins", 0)) >= req_count
		"fast_wins":
			return int(battle.get("fast_wins", 0)) >= req_count
		"win_streaks":
			return int(battle.get("win_streaks", 0)) >= req_count
		"max_win_streak":
			return int(battle.get("max_win_streak", 0)) >= req_count
		"defeat_master":
			return Array(battle.get("masters_defeated", [])).has(req_target)
		"defeat_all_masters":
			var defeated: Array = battle.get("masters_defeated", [])
			var required_masters: Array = requirements.get("masters", [])
			for master_id in required_masters:
				if not defeated.has(master_id):
					return false
			return defeated.size() >= req_count
		"unique_blueprints":
			return int(collection.get("unique_blueprints", []).size()) >= req_count
		"unique_cards":
			return int(collection.get("unique_cards", []).size()) >= req_count
		"legendary_blueprint":
			return int(collection.get("legendary_count", 0)) >= req_count
		"rarity_collection":
			var rarity: String = req_target
			var required_count: int = requirements.get("rarity_count", 0)
			var current_count: int = 0
			match rarity:
				"legendary": current_count = int(collection.get("legendary_count", 0))
				"epic": current_count = int(collection.get("epic_count", 0))
				"rare": current_count = int(collection.get("rare_count", 0))
			return current_count >= required_count
		"max_level":
			return int(progress.get("max_level_reached", 0)) >= req_count
		"perfect_levels":
			return int(progress.get("perfect_levels", 0)) >= req_count
		"complete_era":
			var era_data: Dictionary = progress.get("era_completion", {})
			return bool(era_data.get(req_target, false))
		"playtime":
			return int(progress.get("total_playtime", 0)) >= req_count
		"survival_modes":
			return int(challenge.get("survival_modes_completed", 0)) >= req_count
		"boss_rushes":
			return int(challenge.get("boss_rushes_completed", 0)) >= req_count
		"time_attacks":
			return int(challenge.get("time_attacks_completed", 0)) >= req_count
		"no_loss_challenges":
			return int(challenge.get("no_loss_challenges", 0)) >= req_count
		"max_damage_single_battle":
			return int(challenge.get("max_damage_dealt", 0)) >= req_count
		"total_saves":
			return int(system.get("total_saves", 0)) >= req_count
		"enhancement_operations":
			return int(system.get("enhancement_operations", 0)) >= req_count
		"shop_purchases":
			return int(system.get("shop_purchases", 0)) >= req_count
		"special":
			return false  # 特殊成就需手动触发
		_:
			return false

## 按分类批量检查
## @param category: 分类名称（battle / collection / progress / challenge / system）
## @param database: 完整成就数据库
## @param stats_map: 统计数据合集
## @return Array[String] 本次新满足条件的成就 ID 列表
static func check_category(category: String, database: Dictionary, stats_map: Dictionary) -> Array[String]:
	var newly_met: Array[String] = []
	for ach_id in database:
		var ach_data: Dictionary = database[ach_id]
		if ach_data.get("category", "") == category:
			if check_single(ach_data, stats_map):
				newly_met.append(ach_id)
	return newly_met

## 查询指定成就的当前进度值
## @param req_type: 需求类型
## @param requirements: 需求字典（含 target 等子字段）
## @param stats_map: 统计数据合集
## @return int 当前进度值
static func get_progress_value(req_type: String, requirements: Dictionary, stats_map: Dictionary) -> int:
	var battle: Dictionary = stats_map.get("battle", {})
	var collection: Dictionary = stats_map.get("collection", {})
	var progress: Dictionary = stats_map.get("progress", {})
	var challenge: Dictionary = stats_map.get("challenge", {})
	var system: Dictionary = stats_map.get("system", {})

	match req_type:
		"wins": return int(battle.get("total_wins", 0))
		"kills": return int(battle.get("total_kills", 0))
		"damage_dealt": return int(battle.get("total_damage_dealt", 0))
		"no_damage_wins": return int(battle.get("no_damage_wins", 0))
		"fast_wins": return int(battle.get("fast_wins", 0))
		"win_streaks": return int(battle.get("win_streaks", 0))
		"max_win_streak": return int(battle.get("max_win_streak", 0))
		"unique_blueprints": return int(collection.get("unique_blueprints", []).size())
		"unique_cards": return int(collection.get("unique_cards", []).size())
		"legendary_blueprint": return int(collection.get("legendary_count", 0))
		"max_level": return int(progress.get("max_level_reached", 0))
		"perfect_levels": return int(progress.get("perfect_levels", 0))
		"survival_modes": return int(challenge.get("survival_modes_completed", 0))
		"boss_rushes": return int(challenge.get("boss_rushes_completed", 0))
		"time_attacks": return int(challenge.get("time_attacks_completed", 0))
		"no_loss_challenges": return int(challenge.get("no_loss_challenges", 0))
		"total_saves": return int(system.get("total_saves", 0))
		"enhancement_operations": return int(system.get("enhancement_operations", 0))
		"shop_purchases": return int(system.get("shop_purchases", 0))
		_: return 0
