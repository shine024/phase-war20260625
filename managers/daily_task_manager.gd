extends Node
## 日常任务管理器：管理和生成每日任务

## 任务类型
enum TaskType {
	BATTLE_VICTORY,      # 赢得战斗
	KILL_ENEMIES,        # 击败敌人
	COLLECT_CARDS,       # 收集卡牌
	UPGRADE_CARDS,       # 升级卡牌
	COMPLETE_LEVELS,     # 完成关卡
	USE_PHASE_LAWS,      # 使用相位法则
	EARN_XP              # 获得经验
}

## 任务难度
enum TaskDifficulty {
	EASY,      # 简单
	NORMAL,    # 普通
	HARD,      # 困难
	EXPERT     # 专家
}

var _daily_tasks: Array = []
var _last_refresh_time: int = 0
var _task_refresh_interval: int = 86400  # 24小时

## 任务奖励池
var _reward_pools: Dictionary = {
	TaskDifficulty.EASY: {
		"nano_materials": [50, 100],
		"energy_blocks": [2, 5],
		"common_fragment": [1, 2]
	},
	TaskDifficulty.NORMAL: {
		"nano_materials": [100, 200],
		"energy_blocks": [5, 10],
		"rare_fragment": [1, 2]
	},
	TaskDifficulty.HARD: {
		"nano_materials": [200, 400],
		"energy_blocks": [10, 20],
		"epic_fragment": [1, 2]
	},
	TaskDifficulty.EXPERT: {
		"nano_materials": [400, 800],
		"energy_blocks": [20, 40],
		"legendary_fragment": [1, 2]
	}
}

signal daily_tasks_refreshed()
signal task_completed(task: Dictionary)
signal all_tasks_completed()

func _ready() -> void:
	_check_refresh_needed()

## 检查是否需要刷新任务
func _check_refresh_needed() -> void:
	var current_time = Time.get_unix_time_from_system()
	var last_refresh = _load_last_refresh_time()

	if current_time - last_refresh >= _task_refresh_interval:
		refresh_daily_tasks()

## 刷新日常任务
func refresh_daily_tasks() -> void:
	_daily_tasks.clear()

	var used_types: Array = []

	# 按难度计划生成任务：3简单 + 2普通 + 1困难 + 1专家 = 7个任务
	# 8种类型分配7个任务，确保同一批任务中没有重复类型
	var plan = [
		[TaskDifficulty.EASY, TaskDifficulty.EASY, TaskDifficulty.EASY],
		[TaskDifficulty.NORMAL, TaskDifficulty.NORMAL],
		[TaskDifficulty.HARD],
		[TaskDifficulty.EXPERT]
	]
	for difficulties in plan:
		for diff in difficulties:
			var task = _generate_task(diff, used_types)
			_daily_tasks.append(task)
			used_types.append(task["type"])

	_save_refresh_time()

	daily_tasks_refreshed.emit()

## 生成单个任务
func _generate_task(difficulty: TaskDifficulty, exclude_types: Array = []) -> Dictionary:
	var available = _get_available_task_types().duplicate()
	for t in exclude_types:
		available.erase(t)
	if available.is_empty():
		available = _get_available_task_types().duplicate()  # fallback
	var task_type = available.pick_random()

	var target = _get_task_target(task_type, difficulty)
	var reward = _generate_reward(difficulty)

	var task = {
		"id": "daily_" + str(Time.get_unix_time_from_system()) + "_" + str(randi()),
		"type": task_type,
		"difficulty": difficulty,
		"target": target,
		"current": 0,
		"reward": reward,
		"completed": false,
		"claimed": false,
		"creation_time": Time.get_unix_time_from_system()
	}

	return task

## 获取可用任务类型
func _get_available_task_types() -> Array:
	return [
		TaskType.BATTLE_VICTORY,
		TaskType.KILL_ENEMIES,
		TaskType.COLLECT_CARDS,
		TaskType.UPGRADE_CARDS,
		TaskType.COMPLETE_LEVELS,
		TaskType.USE_PHASE_LAWS,
		TaskType.EARN_XP
	]

## 根据类型和难度获取目标值
func _get_task_target(task_type: TaskType, difficulty: TaskDifficulty) -> int:
	match task_type:
		TaskType.BATTLE_VICTORY:
			match difficulty:
				TaskDifficulty.EASY: return 1
				TaskDifficulty.NORMAL: return 3
				TaskDifficulty.HARD: return 5
				TaskDifficulty.EXPERT: return 10
				_: return 1
		TaskType.KILL_ENEMIES:
			match difficulty:
				TaskDifficulty.EASY: return 10
				TaskDifficulty.NORMAL: return 30
				TaskDifficulty.HARD: return 50
				TaskDifficulty.EXPERT: return 100
				_: return 10
		TaskType.COLLECT_CARDS:
			match difficulty:
				TaskDifficulty.EASY: return 1
				TaskDifficulty.NORMAL: return 3
				TaskDifficulty.HARD: return 5
				TaskDifficulty.EXPERT: return 10
				_: return 1
		TaskType.UPGRADE_CARDS:
			match difficulty:
				TaskDifficulty.EASY: return 1
				TaskDifficulty.NORMAL: return 3
				TaskDifficulty.HARD: return 5
				TaskDifficulty.EXPERT: return 10
				_: return 1
		TaskType.COMPLETE_LEVELS:
			match difficulty:
				TaskDifficulty.EASY: return 1
				TaskDifficulty.NORMAL: return 2
				TaskDifficulty.HARD: return 3
				TaskDifficulty.EXPERT: return 5
				_: return 1
		TaskType.USE_PHASE_LAWS:
			match difficulty:
				TaskDifficulty.EASY: return 1
				TaskDifficulty.NORMAL: return 3
				TaskDifficulty.HARD: return 5
				TaskDifficulty.EXPERT: return 10
				_: return 1
		TaskType.EARN_XP:
			match difficulty:
				TaskDifficulty.EASY: return 500
				TaskDifficulty.NORMAL: return 1500
				TaskDifficulty.HARD: return 3000
				TaskDifficulty.EXPERT: return 5000
				_: return 500
		_:
			return 1

## 生成奖励
func _generate_reward(difficulty: TaskDifficulty) -> Dictionary:
	var reward_pool = _reward_pools[difficulty]
	var reward = {}

	for reward_type in reward_pool:
		var range = reward_pool[reward_type]
		var amount = randi_range(range[0], range[1])
		if amount > 0:
			reward[reward_type] = amount

	return reward

## 更新任务进度
func update_task_progress(task_type: TaskType, amount: int = 1) -> void:
	for task in _daily_tasks:
		if task["type"] == task_type and not task["completed"]:
			task["current"] += amount
			if task["current"] >= task["target"]:
				task["completed"] = true
				_on_task_completed(task)

## 任务完成回调
func _on_task_completed(task: Dictionary) -> void:
	task_completed.emit(task)

	# 检查是否所有任务都完成
	if _are_all_tasks_completed():
		all_tasks_completed.emit()

## 检查是否所有任务都完成
func _are_all_tasks_completed() -> bool:
	for task in _daily_tasks:
		if not task["completed"]:
			return false
	return true

## 领取任务奖励
func claim_task_reward(task_id: String) -> bool:
	for task in _daily_tasks:
		if task["id"] == task_id and task["completed"] and not task["claimed"]:
			_grant_task_rewards(task)
			task["claimed"] = true
			return true
	return false

## 发放任务奖励
func _grant_task_rewards(task: Dictionary) -> void:
	var reward = task["reward"]

	for reward_type in reward:
		match reward_type:
			"nano_materials":
				if BasicResourceManager:
					BasicResourceManager.add_resource("nano_materials", reward[reward_type])
			"energy_blocks":
				if BasicResourceManager:
					BasicResourceManager.add_resource("energy_block", reward[reward_type])
			"common_fragment", "rare_fragment", "epic_fragment", "legendary_fragment":
				_grant_rarity_fragment(reward_type, reward[reward_type])

	# 发送奖励获得信号
	if SignalBus and SignalBus.has_signal("daily_task_reward_granted"):
		SignalBus.daily_task_reward_granted.emit(task)

## 给予稀有度碎片
func _grant_rarity_fragment(reward_type: String, amount: int) -> void:
	const CardDropGrantsScript = preload("res://scripts/card_drop_grants.gd")
	CardDropGrantsScript.grant_from_legacy_fragment_reward_pool(reward_type, amount)

## 获取所有日常任务
func get_daily_tasks() -> Array:
	return _daily_tasks.duplicate(true)

## 获取任务完成进度
func get_task_completion_rate() -> float:
	if _daily_tasks.is_empty():
		return 0.0

	var completed_count = 0
	for task in _daily_tasks:
		if task["completed"]:
			completed_count += 1

	return float(completed_count) / _daily_tasks.size()

## 获取任务统计
func get_task_stats() -> Dictionary:
	var total_tasks = _daily_tasks.size()
	var completed_tasks = 0
	var claimed_tasks = 0
	var total_rewards = 0

	for task in _daily_tasks:
		if task["completed"]:
			completed_tasks += 1
		if task["claimed"]:
			claimed_tasks += 1

		# 计算奖励价值
		for reward_type in task["reward"]:
			var amount = task["reward"][reward_type]
			match reward_type:
				"nano_materials":
					total_rewards += amount
				"energy_blocks":
					total_rewards += amount * 20  # 假设每能量块价值20纳米材料

	return {
		"total": total_tasks,
		"completed": completed_tasks,
		"claimed": claimed_tasks,
		"completion_rate": float(completed_tasks) / total_tasks if total_tasks > 0 else 0.0,
		"total_rewards_value": total_rewards
	}

## 获取下次刷新时间
func get_next_refresh_time() -> int:
	var last_refresh = _load_last_refresh_time()
	return last_refresh + _task_refresh_interval

## 获取刷新倒计时（秒）
func get_refresh_countdown() -> int:
	var next_refresh = get_next_refresh_time()
	var current_time = Time.get_unix_time_from_system()
	var countdown = next_refresh - current_time
	return maxi(0, countdown)

## 保存日常任务（已废弃 - SaveManager自动调用save_state）
## 保存日常任务
## 加载日常任务（已废弃 - SaveManager自动调用load_state）

## 保存刷新时间
func _save_refresh_time() -> void:
	_last_refresh_time = Time.get_unix_time_from_system()

## 加载刷新时间
func _load_last_refresh_time() -> int:
	return _last_refresh_time

## 强制刷新（测试用）
func force_refresh() -> void:
	refresh_daily_tasks()

## 获取任务类型名称
static func get_task_type_name(task_type: TaskType) -> String:
	match task_type:
		TaskType.BATTLE_VICTORY: return "赢得战斗"
		TaskType.KILL_ENEMIES: return "击败敌人"
		TaskType.COLLECT_CARDS: return "收集卡牌"
		TaskType.UPGRADE_CARDS: return "升级卡牌"
		TaskType.COMPLETE_LEVELS: return "完成关卡"
		TaskType.USE_PHASE_LAWS: return "使用相位法则"
		TaskType.EARN_XP: return "获得经验"
		_: return "未知任务"

## 获取难度名称
static func get_difficulty_name(difficulty: TaskDifficulty) -> String:
	match difficulty:
		TaskDifficulty.EASY: return "简单"
		TaskDifficulty.NORMAL: return "普通"
		TaskDifficulty.HARD: return "困难"
		TaskDifficulty.EXPERT: return "专家"
		_: return "未知"

## 获取难度颜色
static func get_difficulty_color(difficulty: TaskDifficulty) -> Color:
	match difficulty:
		TaskDifficulty.EASY: return Color(0.6, 0.9, 0.6, 1.0)
		TaskDifficulty.NORMAL: return Color(0.6, 0.8, 1.0, 1.0)
		TaskDifficulty.HARD: return Color(1.0, 0.7, 0.3, 1.0)
		TaskDifficulty.EXPERT: return Color(1.0, 0.3, 0.3, 1.0)
		_: return Color.WHITE

## 保存状态（给SaveManager用）
func save_state() -> Dictionary:
	return {
		"tasks": _daily_tasks,
		"last_refresh": _last_refresh_time
	}

## 加载状态（给SaveManager用）
func load_state(data: Dictionary) -> void:
	_daily_tasks = data.get("tasks", [])
	_last_refresh_time = data.get("last_refresh", 0)
	# 检查是否需要刷新
	_check_refresh_needed()
