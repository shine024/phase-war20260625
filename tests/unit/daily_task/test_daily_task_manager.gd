class_name DailyTaskManagerTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

const __source: String = 'res://managers/daily_task_manager.gd'

var _manager: Node


func before_test() -> void:
	_manager = Node.new()
	var script = load(__source)
	_manager.set_script(script)
	add_child(_manager)


func after_test() -> void:
	remove_child(_manager)
	_manager.free()


## 初始状态下没有日常任务
func test_initial_state_no_tasks() -> void:
	var tasks = _manager.get_daily_tasks()
	assert_array(tasks).is_empty()


## 初始完成率为 0
func test_initial_completion_rate_zero() -> void:
	assert_float(_manager.get_task_completion_rate()).is_equal(0.0)


## refresh_daily_tasks 生成 7 个任务
func test_refresh_generates_seven_tasks() -> void:
	_manager.refresh_daily_tasks()
	var tasks = _manager.get_daily_tasks()
	assert_int(tasks.size()).is_equal(7)


## 刷新后所有任务都未完成
func test_after_refresh_no_completed_tasks() -> void:
	_manager.refresh_daily_tasks()
	var tasks = _manager.get_daily_tasks()
	for task in tasks:
		assert_bool(task["completed"]).is_false()
		assert_bool(task["claimed"]).is_false()


## 每个任务有必需的字段
func test_tasks_have_required_fields() -> void:
	_manager.refresh_daily_tasks()
	var tasks = _manager.get_daily_tasks()
	for task in tasks:
		assert_dict(task).contains_key("id")
		assert_dict(task).contains_key("type")
		assert_dict(task).contains_key("difficulty")
		assert_dict(task).contains_key("target")
		assert_dict(task).contains_key("current")
		assert_dict(task).contains_key("reward")
		assert_dict(task).contains_key("completed")
		assert_dict(task).contains_key("claimed")


## 任务初始进度为 0，目标大于 0
func test_task_initial_progress_and_target() -> void:
	_manager.refresh_daily_tasks()
	var tasks = _manager.get_daily_tasks()
	for task in tasks:
		assert_int(task["current"]).is_equal(0)
		assert_int(task["target"]).is_greater(0)


## 难度分布：3 Easy + 2 Normal + 1 Hard + 1 Expert
func test_difficulty_distribution() -> void:
	_manager.refresh_daily_tasks()
	var tasks = _manager.get_daily_tasks()
	var easy_count = 0
	var normal_count = 0
	var hard_count = 0
	var expert_count = 0
	for task in tasks:
		match task["difficulty"]:
			0: easy_count += 1    # EASY
			1: normal_count += 1  # NORMAL
			2: hard_count += 1    # HARD
			3: expert_count += 1  # EXPERT
	assert_int(easy_count).is_equal(3)
	assert_int(normal_count).is_equal(2)
	assert_int(hard_count).is_equal(1)
	assert_int(expert_count).is_equal(1)


## 任务类型在 8 种之中且同一批无重复
func test_task_types_no_duplicates() -> void:
	_manager.refresh_daily_tasks()
	var tasks = _manager.get_daily_tasks()
	var types: Array = []
	for task in tasks:
		assert_int(task["type"]).is_in_range(0, 7)
		assert_bool(task["type"] in types).is_false()
		types.append(task["type"])


## update_task_progress 正确推进进度
func test_update_task_progress() -> void:
	_manager.refresh_daily_tasks()
	var tasks = _manager.get_daily_tasks()
	# 找到目标 > 1 的任务进行部分进度更新
	var target_task = tasks[0]
	if target_task["target"] <= 1:
		target_task = tasks[3]  # 尝试更难的任务
	if target_task["target"] > 1:
		_manager.update_task_progress(target_task["type"], 1)
		var updated = _manager.get_daily_tasks()
		assert_int(updated[0]["current"]).is_equal(1)
		assert_bool(updated[0]["completed"]).is_false()


## update_task_progress 完成任务
func test_update_task_progress_completes_task() -> void:
	_manager.refresh_daily_tasks()
	var tasks = _manager.get_daily_tasks()
	var task = tasks[0]
	# 确保达到目标值
	_manager.update_task_progress(task["type"], task["target"])
	var updated = _manager.get_daily_tasks()
	assert_bool(updated[0]["completed"]).is_true()


## task_completed 信号在任务完成时发射
func test_task_completed_signal_emitted() -> void:
	_manager.refresh_daily_tasks()
	var tasks = _manager.get_daily_tasks()
	var task = tasks[0]
	var signal_watcher = watch_signals(_manager)
	_manager.update_task_progress(task["type"], task["target"])
	assert_signal(_manager, 'task_completed').is_emitted(1)


## daily_tasks_refreshed 信号在刷新时发射
func test_daily_tasks_refreshed_signal() -> void:
	var signal_watcher = watch_signals(_manager)
	_manager.refresh_daily_tasks()
	assert_signal(_manager, 'daily_tasks_refreshed').is_emitted(1)


## claim_task_reward 对已完成的任务返回 true
func test_claim_task_reward_completed() -> void:
	_manager.refresh_daily_tasks()
	var tasks = _manager.get_daily_tasks()
	var task = tasks[0]
	_manager.update_task_progress(task["type"], task["target"])
	var result = _manager.claim_task_reward(task["id"])
	# 注意：claim 需要真实的 autoload (BasicResourceManager 等)
	# 如果 autoload 不存在，_grant_task_rewards 内部会跳过但仍返回 true
	assert_bool(result).is_true()


## claim_task_reward 后 claimed 标记为 true
func test_claim_sets_claimed_flag() -> void:
	_manager.refresh_daily_tasks()
	var tasks = _manager.get_daily_tasks()
	var task = tasks[0]
	_manager.update_task_progress(task["type"], task["target"])
	_manager.claim_task_reward(task["id"])
	var updated = _manager.get_daily_tasks()
	assert_bool(updated[0]["claimed"]).is_true()


## claim_task_reward 对未完成任务返回 false
func test_claim_incomplete_task_returns_false() -> void:
	_manager.refresh_daily_tasks()
	var tasks = _manager.get_daily_tasks()
	var result = _manager.claim_task_reward(tasks[0]["id"])
	assert_bool(result).is_false()


## claim_task_reward 对已领取任务返回 false
func test_claim_already_claimed_returns_false() -> void:
	_manager.refresh_daily_tasks()
	var tasks = _manager.get_daily_tasks()
	var task = tasks[0]
	_manager.update_task_progress(task["type"], task["target"])
	_manager.claim_task_reward(task["id"])
	var result2 = _manager.claim_task_reward(task["id"])
	assert_bool(result2).is_false()


## claim_task_reward 对不存在的任务 ID 返回 false
func test_claim_nonexistent_task_returns_false() -> void:
	_manager.refresh_daily_tasks()
	var result = _manager.claim_task_reward("fake_task_id_999")
	assert_bool(result).is_false()


## get_task_completion_rate 计算正确
func test_completion_rate_after_partial() -> void:
	_manager.refresh_daily_tasks()
	var tasks = _manager.get_daily_tasks()
	# 完成第一个任务
	_manager.update_task_progress(tasks[0]["type"], tasks[0]["target"])
	assert_float(_manager.get_task_completion_rate()).is_equal_approx(1.0 / 7.0, 0.001)


## get_task_stats 返回正确的统计
func test_get_task_stats() -> void:
	_manager.refresh_daily_tasks()
	_manager.update_task_progress(
		_manager.get_daily_tasks()[0]["type"],
		_manager.get_daily_tasks()[0]["target"]
	)
	var stats = _manager.get_task_stats()
	assert_int(stats["total"]).is_equal(7)
	assert_int(stats["completed"]).is_equal(1)
	assert_int(stats["claimed"]).is_equal(0)
	assert_float(stats["completion_rate"]).is_equal_approx(1.0 / 7.0, 0.001)


## get_task_type_name 返回正确的中文名称
func test_get_task_type_name() -> void:
	assert_str(_manager.get_task_type_name(_manager.TaskType.BATTLE_VICTORY)).is_equal("赢得战斗")
	assert_str(_manager.get_task_type_name(_manager.TaskType.KILL_ENEMIES)).is_equal("击败敌人")
	assert_str(_manager.get_task_type_name(_manager.TaskType.COLLECT_CARDS)).is_equal("收集卡牌")
	assert_str(_manager.get_task_type_name(_manager.TaskType.UPGRADE_CARDS)).is_equal("升级卡牌")
	assert_str(_manager.get_task_type_name(_manager.TaskType.COMPLETE_LEVELS)).is_equal("完成关卡")
	assert_str(_manager.get_task_type_name(_manager.TaskType.USE_PHASE_LAWS)).is_equal("使用相位法则")
	assert_str(_manager.get_task_type_name(_manager.TaskType.EARN_XP)).is_equal("获得经验")


## get_difficulty_name 返回正确名称
func test_get_difficulty_name() -> void:
	assert_str(_manager.get_difficulty_name(_manager.TaskDifficulty.EASY)).is_equal("简单")
	assert_str(_manager.get_difficulty_name(_manager.TaskDifficulty.NORMAL)).is_equal("普通")
	assert_str(_manager.get_difficulty_name(_manager.TaskDifficulty.HARD)).is_equal("困难")
	assert_str(_manager.get_difficulty_name(_manager.TaskDifficulty.EXPERT)).is_equal("专家")


## get_difficulty_color 返回有效颜色
func test_get_difficulty_color() -> void:
	var easy = _manager.get_difficulty_color(_manager.TaskDifficulty.EASY)
	assert_float(easy.a).is_equal(1.0)
	assert_float(easy.r).is_greater_or_equal(0.0)
	assert_float(easy.g).is_greater_or_equal(0.0)
	assert_float(easy.b).is_greater_or_equal(0.0)


## save_state / load_state 往返
func test_save_load_state_roundtrip() -> void:
	_manager.refresh_daily_tasks()
	var state = _manager.save_state()
	assert_dict(state).contains_key("tasks")
	assert_dict(state).contains_key("last_refresh")

	# 创建新管理器加载状态
	var manager2 = Node.new()
	var script = load(__source)
	manager2.set_script(script)
	add_child(manager2)
	manager2.load_state(state)
	assert_int(manager2.get_daily_tasks().size()).is_equal(7)
	remove_child(manager2)
	manager2.free()


## _get_task_target 对已知类型和难度返回正数
func test_get_task_target_known_combinations() -> void:
	# 使用反射调用私有方法
	var difficulties = [0, 1, 2, 3]
	var types = [0, 1, 2, 3, 4, 5, 6, 7]
	for diff in difficulties:
		for t in types:
			var target = _manager._get_task_target(t, diff)
			assert_int(target).is_greater(0)


## force_refresh 重新生成任务
func test_force_refresh_resets_tasks() -> void:
	_manager.refresh_daily_tasks()
	var first_tasks = _manager.get_daily_tasks()
	_manager.force_refresh()
	var second_tasks = _manager.get_daily_tasks()
	# 数量应相同
	assert_int(second_tasks.size()).is_equal(7)
	# 任务 ID 应该不同（因为包含时间戳和随机数）
	assert_str(second_tasks[0]["id"]).is_not_equal(first_tasks[0]["id"])


## 重复刷新不会报错
func test_multiple_refreshes_no_errors() -> void:
	for i in range(5):
		_manager.refresh_daily_tasks()
		assert_int(_manager.get_daily_tasks().size()).is_equal(7)
