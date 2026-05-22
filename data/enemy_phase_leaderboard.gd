extends RefCounted
class_name EnemyPhaseLeaderboard
## 敌方相位师排行榜系统
##
## 功能：
## - 管理30位敌方相位师的排行榜数据
## - 根据等级、势力、难度分类显示
## - 提供详细的相位师信息查询
## - 动态排名更新

const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")
const LeaderboardEntry = preload("res://data/leaderboard_entry.gd")

## 所有排行榜数据
var _leaderboards: Dictionary = {}
## 按等级分组的排行榜
var _by_level: Dictionary = {}
## 按势力分组的排行榜
var _by_faction: Dictionary = {}
## 按难度分组的排行榜
var _by_difficulty: Dictionary = {}

## 初始化排行榜
func _init() -> void:
	_initialize_leaderboards()

## 初始化所有排行榜
func _initialize_leaderboards() -> void:
	# 主排行榜（综合排名）
	var main_leaderboard = _create_main_leaderboard()
	_leaderboards["main"] = main_leaderboard

	# 按等级分组
	for level in range(1, 31):
		var level_lb = _create_level_leaderboard(level)
		_by_level[str(level)] = level_lb

	# 按势力分组
	var factions = ["steel", "flame", "thunder", "void", "steel_flame", "thunder_steel", "void_flame", "steel_thunder", "flame_void", "all"]
	for faction in factions:
		var faction_lb = _create_faction_leaderboard(faction)
		_by_faction[faction] = faction_lb

	# 按难度分组
	var difficulties = ["easy", "medium", "hard", "expert", "legendary", "ultimate"]
	for difficulty in difficulties:
		var diff_lb = _create_difficulty_leaderboard(difficulty)
		_by_difficulty[difficulty] = diff_lb

## 创建主排行榜
func _create_main_leaderboard() -> Array:
	var leaderboard = []

	for master in EnemyPhaseMasters.ENEMY_MASTERS:
		var entry = _create_entry_from_master(master, 0)
		leaderboard.append(entry)

	# 计算分数：等级 * 100 + 难度加成
	for entry in leaderboard:
		var difficulty_bonus = 0
		match entry.difficulty:
			"easy": difficulty_bonus = 0
			"medium": difficulty_bonus = 200
			"hard": difficulty_bonus = 500
			"expert": difficulty_bonus = 1000
			"legendary": difficulty_bonus = 2000
			"ultimate": difficulty_bonus = 5000

		entry.score = entry.level * 100 + difficulty_bonus

	# 按分数排序
	leaderboard.sort_custom(func(a, b): return a.score > b.score)

	# 更新排名
	for i in range(leaderboard.size()):
		leaderboard[i].rank = i + 1

	return leaderboard

## 创建等级排行榜
func _create_level_leaderboard(level: int) -> Array:
	var masters = EnemyPhaseMasters.get_masters_by_level(level, level)
	var leaderboard = []

	for master in masters:
		var entry = _create_entry_from_master(master, 0)
		# 等级排行榜按胜率排序
		entry.score = entry.win_rate * 1000
		leaderboard.append(entry)

	leaderboard.sort_custom(func(a, b): return a.score > b.score)

	for i in range(leaderboard.size()):
		leaderboard[i].rank = i + 1

	return leaderboard

## 创建势力排行榜
func _create_faction_leaderboard(faction: String) -> Array:
	var masters = EnemyPhaseMasters.get_masters_by_faction(faction)
	var leaderboard = []

	for master in masters:
		var entry = _create_entry_from_master(master, 0)
		# 势力排行榜按等级和胜率综合排序
		entry.score = entry.level * 100 + entry.win_rate * 50
		leaderboard.append(entry)

	leaderboard.sort_custom(func(a, b): return a.score > b.score)

	for i in range(leaderboard.size()):
		leaderboard[i].rank = i + 1

	return leaderboard

## 创建难度排行榜
func _create_difficulty_leaderboard(difficulty: String) -> Array:
	var masters = EnemyPhaseMasters.get_masters_by_difficulty(difficulty)
	var leaderboard = []

	for master in masters:
		var entry = _create_entry_from_master(master, 0)
		# 难度排行榜按等级排序
		entry.score = entry.level * 100
		leaderboard.append(entry)

	leaderboard.sort_custom(func(a, b): return a.score > b.score)

	for i in range(leaderboard.size()):
		leaderboard[i].rank = i + 1

	return leaderboard

## 从相位师数据创建排行榜条目
func _create_entry_from_master(master: Dictionary, base_rank: int) -> LeaderboardEntry:
	return LeaderboardEntry.create_from_master(master, base_rank)

## 获取主排行榜前N名
func get_top_entries(count: int = 10) -> Array:
	return _leaderboards.get("main", []).slice(0, count)

## 获取指定等级的排行榜
func get_level_leaderboard(level: int) -> Array:
	return _by_level.get(str(level), [])

## 获取指定势力的排行榜
func get_faction_leaderboard(faction: String) -> Array:
	return _by_faction.get(faction, [])

## 获取指定难度的排行榜
func get_difficulty_leaderboard(difficulty: String) -> Array:
	return _by_difficulty.get(difficulty, [])

## 根据ID获取相位师详细信息
func get_master_details(master_id: String) -> Dictionary:
	var master = EnemyPhaseMasters.get_master_by_id(master_id)
	if master.is_empty():
		return {}

	return {
		"basic_info": {
			"id": master.get("id", ""),
			"name": master.get("name", ""),
			"title": master.get("title", ""),
			"level": master.get("level", 1),
			"faction": master.get("faction", ""),
			"difficulty": master.get("difficulty", "medium")
		},
		"active_spells": master.get("active_spells", []),
		"passive_spells": master.get("passive_spells", []),
		"equipment": master.get("equipment", {}),
		"stats": master.get("stats", {}),
		"leaderboard_data": _get_leaderboard_data_for_master(master_id)
	}

## 获取相位师的排行榜数据
func _get_leaderboard_data_for_master(master_id: String) -> Dictionary:
	for entry in _leaderboards.get("main", []):
		if entry.master_id == master_id:
			return {
				"rank": entry.rank,
				"score": entry.score,
				"total_wins": entry.total_wins,
				"total_losses": entry.total_losses,
				"win_rate": entry.win_rate,
				"last_active": entry.last_active
			}
	return {}

## 搜索相位师
func search_masters(query: String) -> Array:
	var results = []
	var query_lower = query.to_lower()

	for master in EnemyPhaseMasters.ENEMY_MASTERS:
		var name = master.get("name", "").to_lower()
		var title = master.get("title", "").to_lower()
		var faction = master.get("faction", "").to_lower()

		if query_lower in name or query_lower in title or query_lower in faction:
			results.append(master)

	return results

## 获取势力显示信息
static func get_faction_display_info(faction: String) -> Dictionary:
	var faction_info = {
		"steel": {"name": "钢铁", "color": Color(0.7, 0.85, 1.0, 1), "icon": "🛡️"},
		"flame": {"name": "烈焰", "color": Color(1.0, 0.4, 0.2, 1), "icon": "🔥"},
		"thunder": {"name": "雷霆", "color": Color(0.5, 0.7, 1.0, 1), "icon": "⚡"},
		"void": {"name": "虚空", "color": Color(0.7, 0.3, 1.0, 1), "icon": "🌀"},
		"steel_flame": {"name": "钢铁烈焰", "color": Color(0.9, 0.6, 0.4, 1), "icon": "🔩"},
		"thunder_steel": {"name": "雷霆钢铁", "color": Color(0.6, 0.75, 0.95, 1), "icon": "⚙️"},
		"void_flame": {"name": "虚空烈焰", "color": Color(0.85, 0.35, 0.8, 1), "icon": "🔮"},
		"steel_thunder": {"name": "钢铁雷霆", "color": Color(0.65, 0.8, 1.0, 1), "icon": "🔧"},
		"flame_void": {"name": "烈焰虚空", "color": Color(0.9, 0.35, 0.6, 1), "icon": "💀"},
		"all": {"name": "全能", "color": Color(1.0, 0.9, 0.3, 1), "icon": "👑"}
	}

	return faction_info.get(faction, {"name": faction, "color": Color.WHITE, "icon": "❓"})

## 获取难度显示信息
static func get_difficulty_display_info(difficulty: String) -> Dictionary:
	var difficulty_info = {
		"easy": {"name": "初级", "color": Color(0.4, 0.8, 0.4, 1), "stars": 1},
		"medium": {"name": "中级", "color": Color(0.4, 0.7, 0.95, 1), "stars": 2},
		"hard": {"name": "高级", "color": Color(0.95, 0.7, 0.3, 1), "stars": 3},
		"expert": {"name": "专家", "color": Color(0.9, 0.4, 0.3, 1), "stars": 4},
		"legendary": {"name": "传说", "color": Color(0.8, 0.5, 1.0, 1), "stars": 5},
		"ultimate": {"name": "终极", "color": Color(1.0, 0.8, 0.2, 1), "stars": 6}
	}

	return difficulty_info.get(difficulty, {"name": difficulty, "color": Color.GRAY, "stars": 0})

## 格式化胜率
static func format_win_rate(win_rate: float) -> String:
	return "%.1f%%" % (win_rate * 100)

## 格式化时间
static func format_last_active(days_ago: int) -> String:
	if days_ago == 0:
		return "今天"
	elif days_ago == 1:
		return "昨天"
	elif days_ago < 7:
		return "%d天前" % days_ago
	elif days_ago < 30:
		var weeks = days_ago / 7
		return "%d周前" % weeks
	else:
		var months = days_ago / 30
		return "%d月前" % months

## 生成排行榜统计信息
func get_leaderboard_statistics() -> Dictionary:
	var all_masters = EnemyPhaseMasters.ENEMY_MASTERS

	var faction_counts = {}
	var difficulty_counts = {}
	var level_distribution = {}

	for master in all_masters:
		var faction = master.get("faction", "")
		var difficulty = master.get("difficulty", "")
		var level = master.get("level", 1)

		if not faction_counts.has(faction):
			faction_counts[faction] = 0
		faction_counts[faction] += 1

		if not difficulty_counts.has(difficulty):
			difficulty_counts[difficulty] = 0
		difficulty_counts[difficulty] += 1

		var level_range = "%d-%d" % [level - level % 5 + 1, level - level % 5 + 5]
		if not level_distribution.has(level_range):
			level_distribution[level_range] = 0
		level_distribution[level_range] += 1

	return {
		"total_masters": all_masters.size(),
		"faction_distribution": faction_counts,
		"difficulty_distribution": difficulty_counts,
		"level_distribution": level_distribution,
		"average_level": _calculate_average_level(all_masters),
		"highest_level": _get_highest_level(all_masters),
		"lowest_level": _get_lowest_level(all_masters)
	}

func _calculate_average_level(masters: Array) -> float:
	if masters.is_empty():
		return 0.0

	var total = 0
	for master in masters:
		total += master.get("level", 1)

	return float(total) / float(masters.size())

func _get_highest_level(masters: Array) -> int:
	var highest = 0
	for master in masters:
		var level = master.get("level", 1)
		if level > highest:
			highest = level
	return highest

func _get_lowest_level(masters: Array) -> int:
	var lowest = 100
	for master in masters:
		var level = master.get("level", 1)
		if level < lowest:
			lowest = level
	return lowest
