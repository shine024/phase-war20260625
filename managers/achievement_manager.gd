extends Node
## 成就管理器（委托层）：跟踪和管理玩家的成就解锁进度
##
## 本文件作为 Autoload 入口，保持对外公共 API 不变。
## 成就检查逻辑已拆分到 managers/achievement/achievement_checker.gd
## 奖励发放逻辑已拆分到 managers/achievement/achievement_rewards.gd
##
## 所有外部调用者（achievement_panel / battle_manager_addons / save_manager 等）
## 通过 /root/AchievementManager 访问，接口保持 100% 兼容。

const DEBUG_LOG := false

const DefaultCards = preload("res://data/default_cards.gd")

signal achievement_unlocked(achievement_id: String, achievement_name: String)
signal achievement_progress_updated(achievement_id: String, current_progress: int, max_progress: int)
signal all_achievements_completed()
## v7.x 数据一致性核对：原注释谎称"milestone_reached 已迁移至 SignalBus"，实际 SignalBus.milestone_reached
## 从未 emit/connect（预留声明）。里程碑若需全局推送，应在此 manager 发里程碑时补 SignalBus.milestone_reached.emit。

## 成就统计追踪
var battle_stats: Dictionary = {
	"total_wins": 0,
	"total_battles": 0,
	"total_kills": 0,
	"total_damage_dealt": 0,
	"no_damage_wins": 0,
	"fast_wins": 0,
	"win_streaks": 0,
	"max_win_streak": 0,
	"current_win_streak": 0,
	"masters_defeated": []
}

var collection_stats: Dictionary = {
	"unique_blueprints": [],
	"unique_cards": [],
	"legendary_count": 0,
	"epic_count": 0,
	"rare_count": 0
}

var progress_stats: Dictionary = {
	"max_level_reached": 0,
	"perfect_levels": 0,
	"era_completion": {},
	"total_playtime": 0
}

var challenge_stats: Dictionary = {
	"survival_modes_completed": 0,
	"boss_rushes_completed": 0,
	"time_attacks_completed": 0,
	"no_loss_challenges": 0,
	"max_damage_dealt": 0
}

var system_stats: Dictionary = {
	"total_saves": 0,
	"manual_saves": 0,
	"auto_saves": 0,
	"enhancement_operations": 0,
	"shop_purchases": 0
}

## 成就数据库 - 使用扩展定义
var ACHIEVEMENT_DATABASE: Dictionary = {}

## 成就进度数据
var achievement_progress: Dictionary = {}

## 已解锁的成就ID列表
var unlocked_achievements: Array[String] = []

## 成就奖励领取状态
var reward_claimed: Dictionary = {}

## 是否已完成延迟初始化
var _deferred_initialized: bool = false

func _ready() -> void:
	# 基础初始化已在变量声明处完成
	# 耗时的数据加载推迟到 _deferred_init() 执行
	call_deferred("_deferred_init")

## 延迟初始化：在主循环空闲时加载成就定义和进度数据
func _deferred_init() -> void:
	if _deferred_initialized:
		return
	_deferred_initialized = true
	_load_achievement_definitions()
	_load_achievement_progress()
	_setup_auto_save()

## 加载成就定义
func _load_achievement_definitions() -> void:
	var achievement_defs = get_node_or_null("/root/AchievementDefinitionsExtended")
	if achievement_defs != null:
		ACHIEVEMENT_DATABASE = achievement_defs.ACHIEVEMENT_DEFINITIONS.duplicate()
	else:
		_setup_basic_achievements()

## 设置基础成就定义（后备方案）
func _setup_basic_achievements() -> void:
	ACHIEVEMENT_DATABASE = {
		"ach_first_win": {
			"id": "ach_first_win",
			"name": "初战告捷",
			"category": "battle",
			"description": "赢得第一场战斗",
			"flavor_text": "\"千里之行，始于足下。\"",
			"icon": "⚔️",
			"requirements": {"type": "wins", "count": 1},
			"reward": {"type": "basic_nano", "amount": 100}
		},
		"ach_wins_10": {
			"id": "ach_wins_10",
			"name": "小有成就",
			"category": "battle",
			"description": "累计赢得10场战斗",
			"flavor_text": "\"胜利会成为习惯。\"",
			"icon": "🏆",
			"requirements": {"type": "wins", "count": 10},
			"reward": {"type": "basic_nano", "amount": 500}
		}
	}

## 设置自动保存
func _setup_auto_save() -> void:
	pass

# ─── 内部辅助 ───

## 构建统计数据合集，传给 AchievementChecker
func _build_stats_map() -> Dictionary:
	return {
		"battle": battle_stats,
		"collection": collection_stats,
		"progress": progress_stats,
		"challenge": challenge_stats,
		"system": system_stats,
	}

## 检查并解锁成就（委托给 AchievementChecker）
func _check_and_unlock_achievement(achievement_id: String) -> void:
	if is_achievement_unlocked(achievement_id):
		return

	var ach_data: Dictionary = ACHIEVEMENT_DATABASE.get(achievement_id, {})
	if ach_data.is_empty():
		return

	if AchievementChecker.check_single(ach_data, _build_stats_map()):
		unlock_achievement(achievement_id)

## 旧版成就检查（向后兼容）
func _legacy_check_achievement(achievement_id: String, req_type: String, req_count: int) -> void:
	match req_type:
		"unique_blueprints":
			var blueprint_mgr = get_node_or_null("/root/BlueprintManager")
			if blueprint_mgr != null and blueprint_mgr.has_method("get_unlocked_blueprint_ids"):
				var unlocked_ids = blueprint_mgr.get_unlocked_blueprint_ids()
				if unlocked_ids.size() >= req_count:
					unlock_achievement(achievement_id)

		"legendary_blueprint":
			var blueprint_mgr = get_node_or_null("/root/BlueprintManager")
			if blueprint_mgr != null and blueprint_mgr.has_method("get_unlocked_blueprint_ids"):
				var unlocked_ids = blueprint_mgr.get_unlocked_blueprint_ids()
				for card_id in unlocked_ids:
					var card = DefaultCards.get_card_by_id(card_id)
					if card != null and card.rarity == "legendary":
						unlock_achievement(achievement_id)
						break

		"max_level":
			var level_mgr = get_node_or_null("/root/LevelProgressManager")
			if level_mgr != null and level_mgr.has_method("get_max_level"):
				var max_level = level_mgr.get_max_level()
				if max_level >= req_count:
					unlock_achievement(achievement_id)

## 检查所有指定分类的成就
func _check_category_achievements(category: String) -> void:
	var met: Array[String] = AchievementChecker.check_category(category, ACHIEVEMENT_DATABASE, _build_stats_map())
	for ach_id in met:
		if not is_achievement_unlocked(ach_id):
			unlock_achievement(ach_id)

func _check_all_battle_achievements() -> void:
	_check_category_achievements("battle")

func _check_all_collection_achievements() -> void:
	_check_category_achievements("collection")

func _check_all_progress_achievements() -> void:
	_check_category_achievements("progress")

func _check_all_challenge_achievements() -> void:
	_check_category_achievements("challenge")

func _check_all_system_achievements() -> void:
	_check_category_achievements("system")

## 获取当前进度值（委托给 AchievementChecker）
func _get_current_progress_for_requirement(req_type: String, requirements: Dictionary) -> int:
	return AchievementChecker.get_progress_value(req_type, requirements, _build_stats_map())

# ─── 公共 API（保持不变） ───

## 检查成就是否已解锁
func is_achievement_unlocked(achievement_id: String) -> bool:
	return unlocked_achievements.has(achievement_id)

## 获取成就数据
func get_achievement_data(achievement_id: String) -> Dictionary:
	return ACHIEVEMENT_DATABASE.get(achievement_id, {})

## 获取所有成就
func get_all_achievements() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ach_id in ACHIEVEMENT_DATABASE:
		result.append(ACHIEVEMENT_DATABASE[ach_id])
	return result

## 获取指定分类的成就
func get_achievements_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ach_id in ACHIEVEMENT_DATABASE:
		var ach_data = ACHIEVEMENT_DATABASE[ach_id]
		if ach_data.get("category", "") == category:
			result.append(ach_data)
	return result

## 更新成就进度
func update_achievement_progress(achievement_id: String, current_value: int, max_value: int) -> void:
	if is_achievement_unlocked(achievement_id):
		return

	achievement_progress[achievement_id] = current_value
	achievement_progress_updated.emit(achievement_id, current_value, max_value)
	# v6.6: 镜像到 SignalBus
	SignalBus.achievement_progress_updated.emit(achievement_id, current_value, max_value)
	_check_and_unlock_achievement(achievement_id)

## 解锁成就
func unlock_achievement(achievement_id: String) -> void:
	if not ACHIEVEMENT_DATABASE.has(achievement_id):
		push_error("[AchievementManager] 未知的成就ID: %s" % achievement_id)
		return

	if is_achievement_unlocked(achievement_id):
		return

	unlocked_achievements.append(achievement_id)
	var ach_data = ACHIEVEMENT_DATABASE[achievement_id]
	achievement_unlocked.emit(achievement_id, ach_data.get("name", achievement_id))
	# v6.6: 镜像到 SignalBus（audio_manager 订阅此版本以播音效）
	SignalBus.achievement_unlocked.emit(achievement_id, ach_data.get("name", achievement_id))
	if DEBUG_LOG:
		pass
		# [LOG-v5.1] print("[AchievementManager] 解锁成就: ", ach_data.get("name", achievement_id))
	_save_achievement_progress()

## 记录战斗胜利
func record_battle_victory(battle_data: Dictionary = {}) -> void:
	battle_stats["total_wins"] += 1
	battle_stats["total_battles"] += 1

	battle_stats["current_win_streak"] += 1
	if battle_stats["current_win_streak"] > battle_stats["max_win_streak"]:
		battle_stats["max_win_streak"] = battle_stats["current_win_streak"]

	if battle_data.get("no_damage", false):
		battle_stats["no_damage_wins"] += 1

	if battle_data.get("battle_time", 999) <= 180:
		battle_stats["fast_wins"] += 1

	var kills = battle_data.get("kills", 0)
	var damage = battle_data.get("damage_dealt", 0)
	battle_stats["total_kills"] += kills
	battle_stats["total_damage_dealt"] += damage

	var defeated_master = battle_data.get("defeated_master", "")
	if not defeated_master.is_empty():
		if not defeated_master in battle_stats["masters_defeated"]:
			battle_stats["masters_defeated"].append(defeated_master)

	_check_all_battle_achievements()

## 记录战斗失败
func record_battle_defeat() -> void:
	battle_stats["total_battles"] += 1
	battle_stats["current_win_streak"] = 0

## 记录收集品
func record_collection(card_id: String, rarity: String) -> void:
	if not card_id in collection_stats["unique_cards"]:
		collection_stats["unique_cards"].append(card_id)

	match rarity:
		"legendary":
			collection_stats["legendary_count"] += 1
		"epic":
			collection_stats["epic_count"] += 1
		"rare":
			collection_stats["rare_count"] += 1

	var blueprint_mgr = get_node_or_null("/root/BlueprintManager")
	if blueprint_mgr != null and blueprint_mgr.has_method("has_unlocked_blueprint"):
		if blueprint_mgr.has_unlocked_blueprint(card_id):
			if not card_id in collection_stats["unique_blueprints"]:
				collection_stats["unique_blueprints"].append(card_id)

	_check_all_collection_achievements()

## 记录关卡进度
func record_level_progress(level: int, stars: int = 0) -> void:
	if level > progress_stats["max_level_reached"]:
		progress_stats["max_level_reached"] = level

	if stars >= 3:
		progress_stats["perfect_levels"] += 1

	_check_all_progress_achievements()

## 记录时代完成
func record_era_completion(era_id: String) -> void:
	progress_stats["era_completion"][era_id] = true
	_check_all_progress_achievements()

## 记录挑战完成
func record_challenge_completion(challenge_type: String, challenge_data: Dictionary = {}) -> void:
	match challenge_type:
		"survival":
			challenge_stats["survival_modes_completed"] += 1
		"boss_rush":
			challenge_stats["boss_rushes_completed"] += 1
		"time_attack":
			challenge_stats["time_attacks_completed"] += 1
		"no_loss":
			challenge_stats["no_loss_challenges"] += 1

	var damage = challenge_data.get("damage_dealt", 0)
	if damage > challenge_stats["max_damage_dealt"]:
		challenge_stats["max_damage_dealt"] = damage

	_check_all_challenge_achievements()

## 记录系统操作
func record_system_operation(operation_type: String) -> void:
	match operation_type:
		"manual_save":
			system_stats["manual_saves"] += 1
			system_stats["total_saves"] += 1
		"auto_save":
			system_stats["auto_saves"] += 1
			system_stats["total_saves"] += 1
		"enhancement":
			system_stats["enhancement_operations"] += 1
		"shop_purchase":
			system_stats["shop_purchases"] += 1

	_check_all_system_achievements()

## 手动解锁特殊成就
func unlock_special_achievement(achievement_id: String) -> void:
	if not ACHIEVEMENT_DATABASE.has(achievement_id):
		push_error("[AchievementManager] 未知的成就ID: %s" % achievement_id)
		return

	var ach_data = ACHIEVEMENT_DATABASE[achievement_id]
	if ach_data.get("requirements", {}).get("type", "") == "special":
		unlock_achievement(achievement_id)

## 获取成就进度
func get_achievement_progress(achievement_id: String) -> Dictionary:
	var ach_data = ACHIEVEMENT_DATABASE.get(achievement_id, {})
	if ach_data.is_empty():
		return {}

	var requirements = ach_data.get("requirements", {})
	var req_type: String = requirements.get("type", "")
	var req_count: int = requirements.get("count", 0)
	var current: int = _get_current_progress_for_requirement(req_type, requirements)

	var progress_percentage: float = 0.0
	if req_count > 0:
		progress_percentage = float(current) / float(req_count) * 100.0

	return {
		"current": current,
		"max": req_count,
		"percentage": progress_percentage,
		"unlocked": is_achievement_unlocked(achievement_id),
		"reward_claimed": reward_claimed.get(achievement_id, false)
	}

## 获取解锁进度
func get_unlock_progress() -> Dictionary:
	var total = ACHIEVEMENT_DATABASE.size()
	var unlocked = unlocked_achievements.size()

	var category_progress = {}
	var categories = ["battle", "collection", "progress", "challenge", "system", "special"]
	for category in categories:
		var category_achievements = get_achievements_by_category(category)
		var category_unlocked = 0
		for ach in category_achievements:
			if is_achievement_unlocked(ach.get("id", "")):
				category_unlocked += 1
		category_progress[category] = {
			"total": category_achievements.size(),
			"unlocked": category_unlocked,
			"percentage": float(category_unlocked) / float(category_achievements.size()) * 100.0 if category_achievements.size() > 0 else 0.0
		}

	return {
		"total": total,
		"unlocked": unlocked,
		"percentage": float(unlocked) / float(total) * 100.0 if total > 0 else 0.0,
		"category_progress": category_progress
	}

## 领取成就奖励（委托给 AchievementRewards）
func claim_achievement_reward(achievement_id: String) -> bool:
	if not is_achievement_unlocked(achievement_id):
		push_error("[AchievementManager] 成就未解锁，无法领取奖励: %s" % achievement_id)
		return false

	if reward_claimed.get(achievement_id, false):
		push_error("[AchievementManager] 奖励已领取: %s" % achievement_id)
		return false

	var ach_data = ACHIEVEMENT_DATABASE.get(achievement_id, {})
	var reward = ach_data.get("reward", {})

	if not AchievementRewards.has_reward(reward):
		return false

	if not AchievementRewards.grant(reward):
		return false

	reward_claimed[achievement_id] = true
	var reward_type = reward.get("type", "")
	var reward_amount = reward.get("amount", 0)
	if DEBUG_LOG:
		pass
		# [LOG-v5.1] print("[AchievementManager] 已领取成就奖励: %s (%s x%d)" % [achievement_id, reward_type, reward_amount])
	return true

## 获取可领取奖励的成就列表
func get_claimable_rewards() -> Array[String]:
	var claimable: Array[String] = []
	for ach_id in unlocked_achievements:
		if not reward_claimed.get(ach_id, false):
			var ach_data = ACHIEVEMENT_DATABASE.get(ach_id, {})
			if AchievementRewards.has_reward(ach_data.get("reward", {})):
				claimable.append(ach_id)
	return claimable

## 获取最近解锁的成就
func get_recent_achievements(count: int = 5) -> Array[Dictionary]:
	var recent: Array[Dictionary] = []
	for ach_id in unlocked_achievements:
		if recent.size() >= count:
			break
		recent.append(ACHIEVEMENT_DATABASE.get(ach_id, {}))
	return recent

## 获取成就统计信息
func get_achievement_statistics() -> Dictionary:
	return {
		"total_achievements": ACHIEVEMENT_DATABASE.size(),
		"unlocked_count": unlocked_achievements.size(),
		"completion_rate": float(unlocked_achievements.size()) / float(ACHIEVEMENT_DATABASE.size()) * 100.0 if ACHIEVEMENT_DATABASE.size() > 0 else 0.0,
		"claimable_rewards": get_claimable_rewards().size(),
		"total_rewards_claimed": reward_claimed.size(),
		"battle_stats": battle_stats.duplicate(),
		"collection_stats": collection_stats.duplicate(),
		"progress_stats": progress_stats.duplicate(),
		"challenge_stats": challenge_stats.duplicate(),
		"system_stats": system_stats.duplicate()
	}

## 搜索成就
func search_achievements(query: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var query_lower = query.to_lower()

	for ach_id in ACHIEVEMENT_DATABASE:
		var ach_data = ACHIEVEMENT_DATABASE[ach_id]
		var name = ach_data.get("name", "").to_lower()
		var description = ach_data.get("description", "").to_lower()

		if query_lower in name or query_lower in description:
			results.append(ach_data)

	return results

## 获取推荐成就（即将完成）
func get_recommended_achievements(count: int = 3) -> Array[Dictionary]:
	var recommendations: Array[Dictionary] = []

	for ach_id in ACHIEVEMENT_DATABASE:
		if is_achievement_unlocked(ach_id):
			continue

		var progress = get_achievement_progress(ach_id)
		if progress.get("percentage", 0) >= 50:
			recommendations.append(ACHIEVEMENT_DATABASE[ach_id])

		if recommendations.size() >= count:
			break

	return recommendations

## 保存成就进度
func _save_achievement_progress() -> void:
	pass

## 加载成就进度
func _load_achievement_progress() -> void:
	pass

## 保存状态（给SaveManager用）
func save_state() -> Dictionary:
	return {
		"unlocked_achievements": unlocked_achievements,
		"achievement_progress": achievement_progress,
		"reward_claimed": reward_claimed,
		"battle_stats": battle_stats,
		"collection_stats": collection_stats,
		"progress_stats": progress_stats,
		"challenge_stats": challenge_stats,
		"system_stats": system_stats
	}

## 加载状态（给SaveManager用）
func load_state(data: Dictionary) -> void:
	unlocked_achievements.clear()
	achievement_progress.clear()
	reward_claimed.clear()

	var saved_unlocked = data.get("unlocked_achievements", [])
	for ach_id in saved_unlocked:
		if ACHIEVEMENT_DATABASE.has(ach_id):
			unlocked_achievements.append(ach_id)

	var saved_progress = data.get("achievement_progress", {})
	for ach_id in saved_progress:
		if ACHIEVEMENT_DATABASE.has(ach_id):
			achievement_progress[ach_id] = saved_progress[ach_id]

	var saved_rewards = data.get("reward_claimed", {})
	for ach_id in saved_rewards:
		if ACHIEVEMENT_DATABASE.has(ach_id):
			reward_claimed[ach_id] = saved_rewards[ach_id]

	var saved_battle = data.get("battle_stats", {})
	if not saved_battle.is_empty():
		battle_stats = saved_battle.duplicate()

	var saved_collection = data.get("collection_stats", {})
	if not saved_collection.is_empty():
		collection_stats = saved_collection.duplicate()

	var saved_progress_stats = data.get("progress_stats", {})
	if not saved_progress_stats.is_empty():
		progress_stats = saved_progress_stats.duplicate()

	var saved_challenge = data.get("challenge_stats", {})
	if not saved_challenge.is_empty():
		challenge_stats = saved_challenge.duplicate()

	var saved_system = data.get("system_stats", {})
	if not saved_system.is_empty():
		system_stats = saved_system.duplicate()

	if DEBUG_LOG:
		pass
		# [LOG-v5.1] print("[AchievementManager] 加载成就状态，已解锁: ", unlocked_achievements.size(), "/", ACHIEVEMENT_DATABASE.size())
