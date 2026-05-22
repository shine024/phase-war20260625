extends Node

## 关卡进度管理器：管理关卡解锁、星级评价、首次通关奖励等

signal level_unlocked(level: int)
signal level_completed(level: int, stars: int)
signal stars_updated(level: int, stars: int)
signal era_unlocked(era: int)

## 已解锁关卡列表（从1开始）
var unlocked_levels: Array = [1]  # 默认解锁第1关

## 关卡星级记录（level -> stars）
var level_stars: Dictionary = {}

## 首次通关记录（level -> bool）
var first_completion: Dictionary = {}

## 当前解锁到的最大关卡
var max_unlocked_level: int = 1

## 已解锁的时代（era -> bool）
var unlocked_eras: Dictionary = {
	1: true  # 默认解锁一战时代
}

func _ready() -> void:
	_load_progress()

## 检查关卡是否已解锁
func is_level_unlocked(level: int) -> bool:
	if level < 1 or level > 100:
		return false
	return level in unlocked_levels

## 检查时代是否已解锁
func is_era_unlocked(era: int) -> bool:
	if era < 1 or era > 5:
		return false
	return unlocked_eras.get(era, false)

## 获取关卡星级
func get_level_stars(level: int) -> int:
	return level_stars.get(level, 0)

## 检查是否首次通关
func is_first_completion(level: int) -> bool:
	return not first_completion.has(level)

## 完成关卡（由GameManager调用）
func complete_level(level: int, stars: int) -> void:
	var prev_stars = get_level_stars(level)
	var is_first = is_first_completion(level)

	# 更新星级（保留最高星级）
	if stars > prev_stars:
		level_stars[level] = stars
		stars_updated.emit(level, stars)
		print("[LevelProgress] 关卡 %d 星级更新: %d -> %d" % [level, prev_stars, stars])

	# 记录首次通关
	if is_first:
		first_completion[level] = true
		print("[LevelProgress] 关卡 %d 首次通关！" % level)

	# 发放首次通关奖励
	if is_first:
		_grant_first_completion_rewards(level)

	level_completed.emit(level, stars)

	# 解锁下一关
	_unlock_next_level(level)

	# 检查是否解锁新时代
	_check_era_unlock(level)

## 解锁下一关
func _unlock_next_level(completed_level: int) -> void:
	var next_level = completed_level + 1

	if next_level > 100:
		return  # 已是最后一关

	if next_level not in unlocked_levels:
		unlocked_levels.append(next_level)
		max_unlocked_level = max(max_unlocked_level, next_level)
		level_unlocked.emit(next_level)
		print("[LevelProgress] 解锁关卡: %d" % next_level)

## 检查是否解锁新时代
func _check_era_unlock(level: int) -> void:
	# Boss关卡：20, 40, 60, 80, 100
	var boss_levels = [20, 40, 60, 80, 100]

	if level in boss_levels:
		var era = int(level / 20.0) + 1
		if era <= 5 and not unlocked_eras.get(era, false):
			unlocked_eras[era] = true
			era_unlocked.emit(era)
			print("[LevelProgress] 解锁时代: %d" % era)

## 首次通关奖励
func _grant_first_completion_rewards(level: int) -> void:
	print("[LevelProgress] 发放关卡 %d 首次通关奖励" % level)

	# 基础奖励：纳米材料
	var brm = get_node_or_null("/root/BasicResourceManager")
	if brm and brm.has_method("add_basic_resource"):
		var base_amount = 50 + (level * 5)
		brm.add_basic_resource("nano_materials", base_amount)
		print("[LevelProgress]  + %d 纳米材料" % base_amount)

	# Boss关卡额外奖励
	if level % 20 == 0:
		var boss_bonus = 500
		brm.add_basic_resource("nano_materials", boss_bonus)
		print("[LevelProgress]  Boss关卡额外 + %d 纳米材料" % boss_bonus)

		# 解锁新时代的消息
		var era = level / 20
		if era < 5:
			print("[LevelProgress]  解锁新时代: %d" % (era + 1))

## 获取已解锁关卡列表
func get_unlocked_levels() -> Array:
	return unlocked_levels.duplicate()

## 获取最大解锁关卡
func get_max_unlocked_level() -> int:
	return max_unlocked_level

## 获取时代进度
func get_era_progress(era: int) -> Dictionary:
	var start_level = (era - 1) * 20 + 1
	var end_level = era * 20

	var completed_count = 0
	var total_stars = 0

	for level in range(start_level, end_level + 1):
		var stars = get_level_stars(level)
		if stars > 0:
			completed_count += 1
			total_stars += stars

	return {
		"era": era,
		"start_level": start_level,
		"end_level": end_level,
		"completed": completed_count,
		"total": 20,
		"total_stars": total_stars,
		"max_stars": 60,
	}

## 获取关卡所属时代
func get_level_era(level: int) -> int:
	return int((level - 1) / 20.0) + 1

## 保存进度
func save_state() -> Dictionary:
	return {
		"unlocked_levels": unlocked_levels,
		"level_stars": level_stars,
		"first_completion": first_completion,
		"max_unlocked_level": max_unlocked_level,
		"unlocked_eras": unlocked_eras
	}

## 加载进度
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		push_warning("[LevelProgress] 收到空存档数据，保持默认初始状态")
		return

	if state.has("unlocked_levels") and state["unlocked_levels"] is Array:
		var loaded_levels = state["unlocked_levels"]
		unlocked_levels.clear()
		for level in loaded_levels:
			if level is int and level >= 1 and level <= 100:
				unlocked_levels.append(level)
	elif state.has("unlocked_levels"):
		push_warning("[LevelProgress] unlocked_levels 类型错误: %s，已跳过" % type_string(typeof(state["unlocked_levels"])))

	if state.has("level_stars") and state["level_stars"] is Dictionary:
		level_stars = state["level_stars"].duplicate()
	else:
		push_warning("[LevelProgress] level_stars 缺失或类型错误，已清空")
		level_stars = {}

	if state.has("first_completion") and state["first_completion"] is Dictionary:
		first_completion = state["first_completion"].duplicate()
	else:
		first_completion = {}

	if state.has("unlocked_eras") and state["unlocked_eras"] is Dictionary:
		unlocked_eras = state["unlocked_eras"].duplicate()
	else:
		unlocked_eras = {1: true}

	# 确保 max_unlocked_level 与 unlocked_levels 一致
	if state.has("max_unlocked_level") and state["max_unlocked_level"] is int:
		max_unlocked_level = int(state["max_unlocked_level"])
	elif not unlocked_levels.is_empty():
		max_unlocked_level = unlocked_levels.max()
	else:
		max_unlocked_level = 1

	# 如果 max_unlocked_level 大于 unlocked_levels 中的最大值，修正它
	if not unlocked_levels.is_empty():
		var actual_max: int = unlocked_levels.max()
		if max_unlocked_level > actual_max:
			max_unlocked_level = actual_max

	# 确保至少第1关已解锁
	if 1 not in unlocked_levels:
		unlocked_levels.insert(0, 1)
	if max_unlocked_level < 1:
		max_unlocked_level = 1

	print("[LevelProgress] 进度已加载: max_level=%d, unlocked=%d关, stars=%d关" % [
		max_unlocked_level, unlocked_levels.size(), level_stars.size()])

## 重置进度（用于新游戏）
func reset_progress() -> void:
	unlocked_levels = [1]
	max_unlocked_level = 1
	level_stars.clear()
	first_completion.clear()
	unlocked_eras = {1: true}
	print("[LevelProgress] 进度已重置")

## 内部加载（初始化时调用）
## 注意：不再主动读取存档，而是等待 SaveManager 调用 load_state()
func _load_progress() -> void:
	# 进度数据将由 SaveManager.load_game() 通过 load_state() 加载
	# 这里只做初始化日志
	print("[LevelProgress] 进度管理器已初始化，等待存档加载...")
