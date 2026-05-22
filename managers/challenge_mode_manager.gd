extends Node
## 挑战模式管理器：管理各种挑战模式

## 挑战模式类型
enum ChallengeType {
	SURVIVAL,        # 生存模式
	BOSS_RUSH,       # Boss连战
	TIME_ATTACK,     # 限时挑战
	NO_LOSS,         # 无损挑战
	RANDOM_DECK,     # 随机卡组
	MAX_DAMAGE       # 最大伤害
}

## 挑战难度
enum ChallengeDifficulty {
	NORMAL,
	HARD,
	EXPERT,
	MASTER
}

## 挑战记录
var _challenge_records: Dictionary = {}
var _active_challenge: Dictionary = {}

signal challenge_started(challenge_type: ChallengeType, difficulty: ChallengeDifficulty)
signal challenge_completed(challenge_type: ChallengeType, difficulty: ChallengeDifficulty, result: Dictionary)
signal challenge_failed(challenge_type: ChallengeType, reason: String)

func _ready() -> void:
	pass

## 开始生存模式挑战
func start_survival_challenge(difficulty: ChallengeDifficulty) -> void:
	var config = _get_survival_config(difficulty)

	_active_challenge = {
		"type": ChallengeType.SURVIVAL,
		"difficulty": difficulty,
		"config": config,
		"start_time": Time.get_unix_time_from_system(),
		"wave": 0,
		"kills": 0,
		"losses": 0
	}

	challenge_started.emit(ChallengeType.SURVIVAL, difficulty)

	# 启动挑战
	if GameManager and GameManager.has_method("start_survival_challenge"):
		GameManager.start_survival_challenge(config)

## 获取生存模式配置
func _get_survival_config(difficulty: ChallengeDifficulty) -> Dictionary:
	match difficulty:
		ChallengeDifficulty.NORMAL:
			return {
				"wave_interval": 15.0,
				"enemy_multiplier": 1.0,
				"max_waves": 20,
				"start_energy": 100
			}
		ChallengeDifficulty.HARD:
			return {
				"wave_interval": 12.0,
				"enemy_multiplier": 1.3,
				"max_waves": 30,
				"start_energy": 80
			}
		ChallengeDifficulty.EXPERT:
			return {
				"wave_interval": 10.0,
				"enemy_multiplier": 1.6,
				"max_waves": 50,
				"start_energy": 60
			}
		ChallengeDifficulty.MASTER:
			return {
				"wave_interval": 8.0,
				"enemy_multiplier": 2.0,
				"max_waves": 100,
				"start_energy": 50
			}
		_:
			return {}

## 开始Boss连战挑战
func start_boss_rush_challenge(difficulty: ChallengeDifficulty) -> void:
	var boss_list = _get_boss_list_for_difficulty(difficulty)

	_active_challenge = {
		"type": ChallengeType.BOSS_RUSH,
		"difficulty": difficulty,
		"boss_list": boss_list,
		"current_boss_index": 0,
		"start_time": Time.get_unix_time_from_system(),
		"total_time": 0.0,
		"losses": 0
	}

	challenge_started.emit(ChallengeType.BOSS_RUSH, difficulty)

	# 启动挑战
	if GameManager and GameManager.has_method("start_boss_rush_challenge"):
		GameManager.start_boss_rush_challenge(_active_challenge)

## 获取Boss列表
func _get_boss_list_for_difficulty(difficulty: ChallengeDifficulty) -> Array:
	match difficulty:
		ChallengeDifficulty.NORMAL:
			return ["phase_master_1", "phase_master_2", "phase_master_3"]
		ChallengeDifficulty.HARD:
			return ["phase_master_2", "phase_master_3", "phase_master_4", "phase_master_5"]
		ChallengeDifficulty.EXPERT:
			return ["phase_master_3", "phase_master_4", "phase_master_5", "phase_master_6", "phase_master_7"]
		ChallengeDifficulty.MASTER:
			return ["phase_master_1", "phase_master_2", "phase_master_3", "phase_master_4", "phase_master_5", "phase_master_6", "phase_master_7"]
		_:
			return []

## 更新挑战进度
func update_challenge_progress(progress_type: String, value) -> void:
	if _active_challenge.is_empty():
		return

	match progress_type:
		"wave":
			_active_challenge["wave"] = value
		"kill":
			_active_challenge["kills"] = _active_challenge.get("kills", 0) + value
		"loss":
			_active_challenge["losses"] = _active_challenge.get("losses", 0) + value
		"boss_defeated":
			_active_challenge["current_boss_index"] = _active_challenge.get("current_boss_index", 0) + 1

## 完成挑战
func complete_challenge(result: Dictionary) -> void:
	if _active_challenge.is_empty():
		return

	var challenge_type = _active_challenge["type"]
	var difficulty = _active_challenge["difficulty"]

	# 计算分数
	var score = _calculate_challenge_score()

	# 更新记录
	var challenge_id = _get_challenge_id(challenge_type, difficulty)
	if not _challenge_records.has(challenge_id):
		_challenge_records[challenge_id] = {
			"best_score": 0,
			"completion_count": 0,
			"best_time": INF,
			"attempts": 0
		}

	var record = _challenge_records[challenge_id]
	record["completion_count"] += 1
	record["attempts"] += 1

	if score > record["best_score"]:
		record["best_score"] = score

	if result.has("time") and result["time"] < record["best_time"]:
		record["best_time"] = result["time"]

	var final_result = {
		"score": score,
		"perfect_win": result.get("perfect_win", false),
		"time": result.get("time", 0),
		"wave": _active_challenge.get("wave", 0),
		"kills": _active_challenge.get("kills", 0),
		"losses": _active_challenge.get("losses", 0)
	}

	challenge_completed.emit(challenge_type, difficulty, final_result)
	_grant_challenge_rewards(challenge_type, difficulty, final_result)

	_active_challenge.clear()

## 挑战失败
func fail_challenge(reason: String) -> void:
	if _active_challenge.is_empty():
		return

	var challenge_type = _active_challenge["type"]
	var difficulty = _active_challenge["difficulty"]

	challenge_failed.emit(challenge_type, reason)
	_active_challenge.clear()

## 计算挑战分数
func _calculate_challenge_score() -> int:
	if _active_challenge.is_empty():
		return 0

	var challenge_type = _active_challenge["type"]
	var difficulty = _active_challenge["difficulty"]

	var base_score = 1000

	match difficulty:
		ChallengeDifficulty.NORMAL: base_score = 1000
		ChallengeDifficulty.HARD: base_score = 3000
		ChallengeDifficulty.EXPERT: base_score = 8000
		ChallengeDifficulty.MASTER: base_score = 20000

	var score = base_score

	# 根据类型调整分数
	match challenge_type:
		ChallengeType.SURVIVAL:
			var waves = _active_challenge.get("wave", 0)
			var kills = _active_challenge.get("kills", 0)
			score += waves * 100 + kills * 10
		ChallengeType.BOSS_RUSH:
			var bosses_defeated = _active_challenge.get("current_boss_index", 0)
			var losses = _active_challenge.get("losses", 0)
			score += bosses_defeated * 500
			score -= losses * 200

	return maxi(0, score)

## 发放挑战奖励
func _grant_challenge_rewards(challenge_type: ChallengeType, difficulty: ChallengeDifficulty, result: Dictionary) -> void:
	var base_reward = 100

	match difficulty:
		ChallengeDifficulty.NORMAL: base_reward = 100
		ChallengeDifficulty.HARD: base_reward = 300
		ChallengeDifficulty.EXPERT: base_reward = 800
		ChallengeDifficulty.MASTER: base_reward = 2000

	# 根据结果调整奖励
	var final_reward = base_reward
	if result.get("perfect_win", false):
		final_reward *= 2

	if BasicResourceManager:
		BasicResourceManager.add_resource("nano_materials", final_reward)

	# 给予特殊奖励
	if difficulty == ChallengeDifficulty.MASTER:
		# 给予传说碎片
		var legendary_cards = ["omega_platform", "omega_cannon"]
		var random_card_id = legendary_cards.pick_random()
		if BlueprintManager and BlueprintManager.has_method("add_blueprint_copy"):
			BlueprintManager.add_blueprint_copy(random_card_id, 3)

## 获取挑战记录
func get_challenge_records(challenge_type: ChallengeType, difficulty: ChallengeDifficulty) -> Dictionary:
	var challenge_id = _get_challenge_id(challenge_type, difficulty)
	return _challenge_records.get(challenge_id, {})

## 获取挑战排行榜
## NOTIMPLEMENTED: 全局排行榜需要网络后端支持（服务端数据库、在线匹配、反作弊）
## 当前仅支持本地记录，未来接入多人在线后可实现跨玩家排名
func get_challenge_leaderboard(challenge_type: ChallengeType, _difficulty: ChallengeDifficulty) -> Array:
	return []

## 获取挑战ID
func _get_challenge_id(challenge_type: ChallengeType, difficulty: ChallengeDifficulty) -> String:
	return str(challenge_type) + "_" + str(difficulty)

## 保存挑战记录（已废弃 - SaveManager自动调用save_state）
## 加载挑战记录（已废弃 - SaveManager自动调用load_state）

## 保存状态（给SaveManager用）
func save_state() -> Dictionary:
	return _challenge_records.duplicate(true)

## 加载状态（给SaveManager用）
func load_state(data: Dictionary) -> void:
	if not data.is_empty():
		_challenge_records = data.duplicate(true)

## 获取当前挑战
func get_active_challenge() -> Dictionary:
	return _active_challenge.duplicate(true)

## 检查是否在挑战中
func is_in_challenge() -> bool:
	return not _active_challenge.is_empty()

## 获取挑战类型名称
static func get_challenge_type_name(challenge_type: ChallengeType) -> String:
	match challenge_type:
		ChallengeType.SURVIVAL: return "生存模式"
		ChallengeType.BOSS_RUSH: return "Boss连战"
		ChallengeType.TIME_ATTACK: return "限时挑战"
		ChallengeType.NO_LOSS: return "无损挑战"
		ChallengeType.RANDOM_DECK: return "随机卡组"
		ChallengeType.MAX_DAMAGE: return "最大伤害"
		_: return "未知挑战"

## 获取难度名称
static func get_challenge_difficulty_name(difficulty: ChallengeDifficulty) -> String:
	match difficulty:
		ChallengeDifficulty.NORMAL: return "普通"
		ChallengeDifficulty.HARD: return "困难"
		ChallengeDifficulty.EXPERT: return "专家"
		ChallengeDifficulty.MASTER: return "大师"
		_: return "未知"
