extends RefCounted
class_name LeaderboardDefinitions
## 排行榜定义：各种排行榜类型和配置

## 排行榜类型
enum LeaderboardType {
	CHALLENGE_HIGHSCORE,    # 挑战模式高分榜
	FASTEST_CLEAR_TIME,     # 最快通关时间
	MOST_DAMAGE,            # 最高伤害
	MOST_WINS,              # 最多胜场
	LONGEST_SURVIVAL,       # 最长生存时间
	COLLECTION_COMPLETE,    # 收集完成度
	LEVEL_PROGRESS          # 关卡进度
}

## 排行榜定义
const LEADERBOARDS: Dictionary = {
	# ==================== 挑战模式排行 ====================
	"survival_highscore": {
		"id": "survival_highscore",
		"name": "生存挑战排行榜",
		"description": "在生存挑战中达到最高波次",
		"type": LeaderboardType.CHALLENGE_HIGHSCORE,
		"category": "survival",
		"score_format": "waves",
		"update_frequency": "realtime",
		"max_entries": 100,
		"reset_period": "weekly"
	},
	"time_attack_best": {
		"id": "time_attack_best",
		"name": "限时挑战排行榜",
		"description": "限时挑战中的最高击杀数",
		"type": LeaderboardType.CHALLENGE_HIGHSCORE,
		"category": "time_attack",
		"score_format": "kills",
		"update_frequency": "realtime",
		"max_entries": 50,
		"reset_period": "daily"
	},

	# ==================== 速度排行 ====================
	"fastest_clear_all": {
		"id": "fastest_clear_all",
		"name": "全关卡最快通关",
		"description": "完成所有关卡的最短时间",
		"type": LeaderboardType.FASTEST_CLEAR_TIME,
		"category": "speed",
		"score_format": "time",
		"update_frequency": "on_complete",
		"max_entries": 20,
		"reset_period": "never"
	},
	"fastest_level_clear": {
		"id": "fastest_level_clear",
		"name": "单关卡最快通关",
		"description": "单个关卡的最快通关时间",
		"type": LeaderboardType.FASTEST_CLEAR_TIME,
		"category": "speed",
		"score_format": "time",
		"update_frequency": "on_complete",
		"max_entries": 50,
		"reset_period": "monthly"
	},

	# ==================== 伤害排行 ====================
	"highest_single_damage": {
		"id": "highest_single_damage",
		"name": "单次最高伤害",
		"description": "单次攻击造成的最高伤害",
		"type": LeaderboardType.MOST_DAMAGE,
		"category": "damage",
		"score_format": "damage",
		"update_frequency": "realtime",
		"max_entries": 30,
		"reset_period": "weekly"
	},
	"total_damage_dealt": {
		"id": "total_damage_dealt",
		"name": "总伤害输出",
		"description": "累计造成的总伤害",
		"type": LeaderboardType.MOST_DAMAGE,
		"category": "damage",
		"score_format": "damage",
		"update_frequency": "realtime",
		"max_entries": 100,
		"reset_period": "monthly"
	},

	# ==================== 胜场排行 ====================
	"total_wins": {
		"id": "total_wins",
		"name": "总胜场排行",
		"description": "累计获得的总胜利次数",
		"type": LeaderboardType.MOST_WINS,
		"category": "wins",
		"score_format": "wins",
		"update_frequency": "realtime",
		"max_entries": 100,
		"reset_period": "never"
	},
	"win_rate": {
		"id": "win_rate",
		"name": "胜率排行榜",
		"description": "战斗胜率（至少20场）",
		"type": LeaderboardType.MOST_WINS,
		"category": "wins",
		"score_format": "percentage",
		"update_frequency": "on_battle_end",
		"max_entries": 50,
		"reset_period": "monthly"
	},

	# ==================== 收集排行 ====================
	"collection_completion": {
		"id": "collection_completion",
		"name": "收集完成度",
		"description": "卡牌收集完成百分比",
		"type": LeaderboardType.COLLECTION_COMPLETE,
		"category": "collection",
		"score_format": "percentage",
		"update_frequency": "on_change",
		"max_entries": 100,
		"reset_period": "never"
	},
	"blueprint_unlocked": {
		"id": "blueprint_unlocked",
		"name": "蓝图解锁数",
		"description": "已解锁的蓝图总数",
		"type": LeaderboardType.COLLECTION_COMPLETE,
		"category": "collection",
		"score_format": "count",
		"update_frequency": "on_change",
		"max_entries": 50,
		"reset_period": "never"
	},

	# ==================== 关卡进度排行 ====================
	"highest_level": {
		"id": "highest_level",
		"name": "最高关卡进度",
		"description": "到达的最高关卡数",
		"type": LeaderboardType.LEVEL_PROGRESS,
		"category": "progress",
		"score_format": "level",
		"update_frequency": "on_complete",
		"max_entries": 100,
		"reset_period": "never"
	},
	"all_stars": {
		"id": "all_stars",
		"name": "全星通关",
		"description": "获得最多星星的玩家",
		"type": LeaderboardType.LEVEL_PROGRESS,
		"category": "progress",
		"score_format": "stars",
		"update_frequency": "on_complete",
		"max_entries": 50,
		"reset_period": "never"
	}
}

## 排行榜条目结构
const LEADERBOARD_ENTRY: Dictionary = {
	"player_id": "",          # 玩家ID
	"player_name": "",        # 玩家名称
	"score": 0,               # 分数
	"rank": 0,                # 排名
	"timestamp": 0,           # 时间戳
	"additional_data": {}     # 额外数据
}

## 排行榜分类
const LEADERBOARD_CATEGORIES: Dictionary = {
	"challenge": {
		"name": "挑战排行",
		"leaderboards": ["survival_highscore", "time_attack_best"]
	},
	"speed": {
		"name": "速度排行",
		"leaderboards": ["fastest_clear_all", "fastest_level_clear"]
	},
	"damage": {
		"name": "伤害排行",
		"leaderboards": ["highest_single_damage", "total_damage_dealt"]
	},
	"wins": {
		"name": "胜场排行",
		"leaderboards": ["total_wins", "win_rate"]
	},
	"collection": {
		"name": "收集排行",
		"leaderboards": ["collection_completion", "blueprint_unlocked"]
	},
	"progress": {
		"name": "进度排行",
		"leaderboards": ["highest_level", "all_stars"]
	}
}

## 获取排行榜定义
static func get_leaderboard(leaderboard_id: String) -> Dictionary:
	if LEADERBOARDS.has(leaderboard_id):
		return LEADERBOARDS[leaderboard_id]
	return {}

## 获取分类下的所有排行榜
static func get_leaderboards_by_category(category: String) -> Array:
	if LEADERBOARD_CATEGORIES.has(category):
		var category_data = LEADERBOARD_CATEGORIES[category]
		var leaderboards = []
		for lb_id in category_data.leaderboards:
			leaderboards.append(get_leaderboard(lb_id))
		return leaderboards
	return []

## 格式化分数显示
static func format_score(score: float, format_type: String) -> String:
	match format_type:
		"waves":
			return "波次 %d" % int(score)
		"kills":
			return "击杀 %d" % int(score)
		"time":
			var minutes = int(score / 60)
			var seconds = int(int(score) % 60)
			return "%02d:%02d" % [minutes, seconds]
		"damage":
			return format_number(int(score)) + " 伤害"
		"wins":
			return "胜场 %d" % int(score)
		"percentage":
			return "%.1f%%" % score
		"count":
			return str(int(score))
		"level":
			return "关卡 %d" % int(score)
		"stars":
			return "⭐ %d" % int(score)
		_:
			return str(score)

## 格式化数字（带逗号）
static func format_number(num: int) -> String:
	var str_num = str(num)
	var result = ""
	var count = 0
	for i in range(str_num.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = str_num[i] + result
		count += 1
	return result

## 获取排名颜色
static func get_rank_color(rank: int) -> Color:
	if rank == 1:
		return Color(1.0, 0.8, 0.2, 1.0)  # 金色
	elif rank == 2:
		return Color(0.75, 0.75, 0.75, 1.0)  # 银色
	elif rank == 3:
		return Color(0.8, 0.5, 0.2, 1.0)  # 铜色
	elif rank <= 10:
		return Color(0.2, 0.8, 0.4, 1.0)  # 绿色（前10）
	elif rank <= 50:
		return Color(0.3, 0.6, 0.9, 1.0)  # 蓝色（前50）
	else:
		return Color(0.7, 0.7, 0.75, 1.0)  # 灰色

## 创建排行榜条目
static func create_leaderboard_entry(player_id: String, player_name: String, score: float, additional_data: Dictionary = {}) -> Dictionary:
	return {
		"player_id": player_id,
		"player_name": player_name,
		"score": score,
		"rank": 0,
		"timestamp": Time.get_unix_time_from_system(),
		"additional_data": additional_data
	}
