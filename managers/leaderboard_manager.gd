extends Node
## 排行榜管理器：管理游戏内各种排行榜

const LeaderboardDefs = preload("res://data/leaderboard_definitions.gd")

## 本地排行榜数据
var _local_leaderboards: Dictionary = {}
var _player_scores: Dictionary = {}

signal score_updated(leaderboard_id: String, player_entry: Dictionary)
signal new_high_score(leaderboard_id: String, old_rank: int, new_rank: int)

## 是否已完成延迟初始化
var _deferred_initialized: bool = false

func _ready() -> void:
	# 基础变量已在声明处初始化
	# 耗时的数据初始化推迟到 _deferred_init()
	call_deferred("_deferred_init")

## 延迟初始化：在主循环空闲时初始化玩家分数数据
func _deferred_init() -> void:
	if _deferred_initialized:
		return
	_deferred_initialized = true
	_initialize_player_scores()
	print("[LeaderboardManager] 延迟初始化完成")

## 初始化玩家分数
func _initialize_player_scores() -> void:
	_player_scores = {
		"total_wins": 0,
		"total_battles": 0,
		"highest_damage": 0,
		"total_damage": 0,
		"fastest_clear": INF,
		"survival_best": 0,
		"collection_completion": 0.0,
		"blueprint_count": 0,
		"highest_level": 1,
		"total_stars": 0
	}

## 提交分数到排行榜
func submit_score(leaderboard_id: String, score: float, additional_data: Dictionary = {}) -> Dictionary:
	if not LeaderboardDefs.LEADERBOARDS.has(leaderboard_id):
		push_error("排行榜不存在: " + leaderboard_id)
		return {}

	var leaderboard_def = LeaderboardDefs.LEADERBOARDS[leaderboard_id]
	var player_id = _get_player_id()
	var player_name = _get_player_name()

	# 创建排行榜条目
	var entry = LeaderboardDefs.create_leaderboard_entry(player_id, player_name, score, additional_data)

	# 更新本地排行榜
	if not _local_leaderboards.has(leaderboard_id):
		_local_leaderboards[leaderboard_id] = []

	var leaderboard = _local_leaderboards[leaderboard_id]
	var old_rank = _get_player_rank(leaderboard_id, player_id)

	# 更新或添加玩家分数
	var found = false
	for i in range(leaderboard.size()):
		if leaderboard[i].player_id == player_id:
			# 更新现有分数（如果更高）
			if score > leaderboard[i].score:
				leaderboard[i] = entry
			found = true
			break

	if not found:
		leaderboard.append(entry)

	# 排序并限制条目数量
	_sort_leaderboard(leaderboard_id)
	_limit_leaderboard_size(leaderboard_id)

	# 更新排名
	_update_ranks(leaderboard_id)

	# 获取新排名
	var new_rank = _get_player_rank(leaderboard_id, player_id)

	# 发送信号
	score_updated.emit(leaderboard_id, entry)
	if new_rank < old_rank:
		new_high_score.emit(leaderboard_id, old_rank, new_rank)

	return entry

## 获取排行榜前N名
func get_top_entries(leaderboard_id: String, count: int = 10) -> Array:
	if not _local_leaderboards.has(leaderboard_id):
		return []

	var leaderboard = _local_leaderboards[leaderboard_id]
	var top_entries = []

	for i in range(min(count, leaderboard.size())):
		top_entries.append(leaderboard[i])

	return top_entries

## 获取玩家排名
func get_player_rank(leaderboard_id: String) -> int:
	if not _local_leaderboards.has(leaderboard_id):
		return -1

	var player_id = _get_player_id()
	return _get_player_rank(leaderboard_id, player_id)

func _get_player_rank(leaderboard_id: String, player_id: String) -> int:
	if not _local_leaderboards.has(leaderboard_id):
		return -1

	var leaderboard = _local_leaderboards[leaderboard_id]
	for i in range(leaderboard.size()):
		if leaderboard[i].player_id == player_id:
			return i + 1  # 排名从1开始

	return -1

## 获取排行榜分数
func get_leaderboard_scores(leaderboard_id: String) -> Array:
	if not _local_leaderboards.has(leaderboard_id):
		return []

	return _local_leaderboards[leaderboard_id]

## 更新战斗统计
func update_battle_stats(player_won: bool, damage_dealt: int, time_taken: float) -> void:
	_player_scores.total_battles += 1
	if player_won:
		_player_scores.total_wins += 1

	_player_scores.total_damage += damage_dealt
	if damage_dealt > _player_scores.highest_damage:
		_player_scores.highest_damage = damage_dealt

	# 自动提交到相关排行榜
	submit_score("total_damage_dealt", _player_scores.total_damage)
	submit_score("highest_single_damage", _player_scores.highest_damage)
	submit_score("total_wins", _player_scores.total_wins)

## 更新关卡进度
func update_level_progress(level: int, stars: int = 1) -> void:
	if level > _player_scores.highest_level:
		_player_scores.highest_level = level
		submit_score("highest_level", level)

	_player_scores.total_stars += stars
	submit_score("all_stars", _player_scores.total_stars)

## 更新收集进度
func update_collection_progress(total_cards: int, unlocked_cards: int) -> void:
	var completion = float(unlocked_cards) / float(total_cards) * 100.0
	_player_scores.collection_completion = completion
	submit_score("collection_completion", completion)

## 更新蓝图数量
func update_blueprint_count(count: int) -> void:
	_player_scores.blueprint_count = count
	submit_score("blueprint_unlocked", count)

## 更新生存挑战最佳成绩
func update_survival_best(waves: int) -> void:
	if waves > _player_scores.survival_best:
		_player_scores.survival_best = waves
		submit_score("survival_highscore", waves)

## 排序排行榜
func _sort_leaderboard(leaderboard_id: String) -> void:
	if not _local_leaderboards.has(leaderboard_id):
		return

	var leaderboard = _local_leaderboards[leaderboard_id]
	var lb_def = LeaderboardDefs.get_leaderboard(leaderboard_id)

	# 根据排行榜类型排序
	match lb_def.type:
		LeaderboardDefs.LeaderboardType.FASTEST_CLEAR_TIME:
			# 时间越短越好
			leaderboard.sort_custom(func(a, b): return a.score < b.score)
		_:
			# 分数越高越好
			leaderboard.sort_custom(func(a, b): return a.score > b.score)

## 限制排行榜大小
func _limit_leaderboard_size(leaderboard_id: String) -> void:
	if not _local_leaderboards.has(leaderboard_id):
		return

	var lb_def = LeaderboardDefs.get_leaderboard(leaderboard_id)
	var max_entries = lb_def.get("max_entries", 100)
	var leaderboard = _local_leaderboards[leaderboard_id]

	if leaderboard.size() > max_entries:
		leaderboard.resize(max_entries)

## 更新排名
func _update_ranks(leaderboard_id: String) -> void:
	if not _local_leaderboards.has(leaderboard_id):
		return

	var leaderboard = _local_leaderboards[leaderboard_id]
	for i in range(leaderboard.size()):
		leaderboard[i].rank = i + 1

## 获取玩家ID
func _get_player_id() -> String:
	# 简单实现：使用系统时间作为ID
	# 实际项目中应该使用唯一标识符
	return "player_" + str(OS.get_unique_id())

## 获取玩家名称
func _get_player_name() -> String:
	var social = get_node_or_null("/root/SocialSystemManager")
	if social and social.player_profile.has("player_name") and not social.player_profile["player_name"].is_empty():
		return social.player_profile["player_name"]
	return "Player"


## 保存状态（给SaveManager用）
func save_state() -> Dictionary:
	return {
		"leaderboards": _local_leaderboards,
		"player_scores": _player_scores
	}

## 加载状态（给SaveManager用）
func load_state(data: Dictionary) -> void:
	if data.has("leaderboards"):
		_local_leaderboards = data.leaderboards
	if data.has("player_scores"):
		_player_scores = data.player_scores

## 获取玩家统计
func get_player_stats() -> Dictionary:
	return _player_scores.duplicate()

## 重置排行榜
func reset_leaderboard(leaderboard_id: String) -> void:
	if _local_leaderboards.has(leaderboard_id):
		_local_leaderboards[leaderboard_id].clear()

## 清空所有排行榜
func clear_all_leaderboards() -> void:
	_local_leaderboards.clear()

## 导出排行榜数据
func export_leaderboard(leaderboard_id: String) -> String:
	if not _local_leaderboards.has(leaderboard_id):
		return ""

	var leaderboard = _local_leaderboards[leaderboard_id]
	var json = JSON.new()
	return json.stringify(leaderboard)

## 导入排行榜数据
func import_leaderboard(leaderboard_id: String, data: String) -> bool:
	var json = JSON.new()
	var error = json.parse(data)
	if error != OK:
		return false

	if json.data is Array:
		_local_leaderboards[leaderboard_id] = json.data
		return true

	return false
