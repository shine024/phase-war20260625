extends RefCounted
class_name LeaderboardEntry
## 排行榜条目数据类

var master_id: String
var rank: int
var name: String
var title: String
var level: int
var faction: String
var difficulty: String
var score: float
var total_wins: int
var total_losses: int
var win_rate: float
var last_active: int

func _init(p_master_id: String = "", p_rank: int = 0, p_name: String = "", p_title: String = "",
		 p_level: int = 1, p_faction: String = "", p_difficulty: String = "medium",
		 p_score: float = 0.0, p_total_wins: int = 0, p_total_losses: int = 0,
			p_win_rate: float = 0.0, p_last_active: int = 0) -> void:
	master_id = p_master_id
	rank = p_rank
	name = p_name
	title = p_title
	level = p_level
	faction = p_faction
	difficulty = p_difficulty
	score = p_score
	total_wins = p_total_wins
	total_losses = p_total_losses
	win_rate = p_win_rate
	last_active = p_last_active

func _to_string() -> String:
	return "%d. %s (%s Lv.%d) - %.0f分" % [rank, name, title, level, score]

## 创建排行榜条目的便捷函数
static func create_from_master(master: Dictionary, base_rank: int) -> LeaderboardEntry:
	var entry = LeaderboardEntry.new()
	entry.master_id = master.get("id", "")
	entry.name = master.get("name", "未知")
	entry.title = master.get("title", "")
	entry.level = master.get("level", 1)
	entry.faction = master.get("faction", "")
	entry.difficulty = master.get("difficulty", "medium")
	entry.rank = base_rank

	# 模拟战斗数据
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var base_wins = entry.level * 15
	entry.total_wins = base_wins + rng.randi() % 50
	entry.total_losses = rng.randi() % 30
	entry.win_rate = float(entry.total_wins) / float(entry.total_wins + entry.total_losses)
	entry.last_active = rng.randi() % 7  # 0-6天前

	return entry
