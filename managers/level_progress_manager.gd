extends Node

## 关卡进度管理器：管理关卡解锁、星级评价、首次通关奖励等

const DEBUG_LOG := false

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

## v34 渐进解锁仪式待播队列（仅运行期，不入存档）：跨级解锁发生在战斗结算中时，
## 玩家不在基地收不到即时仪式——由 truck_base._ready / main 返回整备时调
## consume_pending_feature_unlocks 取走并批量弹 FeatureUnlockPopup。
var _pending_feature_unlocks: Array = []

## 取走并清空待播解锁仪式（返回 [{key,level,title,desc}]，空数组=无待播）
func consume_pending_feature_unlocks() -> Array:
	var out := _pending_feature_unlocks.duplicate()
	_pending_feature_unlocks.clear()
	return out

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
		if DEBUG_LOG:
			pass
			# [LOG-v5.1] print("[LevelProgress] 关卡 %d 星级更新: %d -> %d" % [level, prev_stars, stars])

	# 记录首次通关
	if is_first:
		first_completion[level] = true
		if DEBUG_LOG:
			pass
			# [LOG-v5.1] print("[LevelProgress] 关卡 %d 首次通关！" % level)

	# 2026-09-19 双首通收敛：遗留纳米首通（50+5lv + Boss 500）发放已删——
	# 首通奖励唯一真身 = GameManager._grant_first_clear_if_eligible（B3 三/四资源套餐），
	# 此前两套叠加双发。first_completion 记账结构保留（存档兼容 + 首通判定仍用）。

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
		var prev_max := max_unlocked_level
		unlocked_levels.append(next_level)
		max_unlocked_level = max(max_unlocked_level, next_level)
		level_unlocked.emit(next_level)
		# v34 渐进解锁：跨过节奏表阈值 → 广播系统解锁（基地热区开张高亮/底栏刷新/
		# 教程步重挂）。prev_max 守卫确保只在"首次跨过该阈值"时发（重打旧关不重弹）。
		# 战斗结算中玩家不在基地 → 同时入待播队列，回基地/返回整备时由场景补播仪式。
		if GameConfig.get_default().feature_gates_enabled and prev_max < next_level:
			for key in FeatureUnlockSchedule.keys_unlocked_at(next_level):
				var info: Dictionary = FeatureUnlockSchedule.SCHEDULE[key]
				var _desc: String = String(info["desc"])
				# 2026-09-19 衔接提示：改造解锁时清点情报包库存，明示"已攒图纸"（L1 起掉落
				# 而 L6 才开装的时序差，此前无任何衔接文案，玩家不知道期货已攒在包里）
				if key == "modification":
					var _iib: Node = get_node_or_null("/root/IntelItemBag")
					if _iib != null and _iib.has_method("count_by_prefix"):
						var _n: int = int(_iib.count_by_prefix("blueprint_"))
						if _n > 0:
							_desc += "\n◆ 情报包已攒 %d 张改造图纸，现在可以安装了" % _n
				_pending_feature_unlocks.append({
					"key": key,
					"level": next_level,
					"title": String(info["title"]),
					"desc": _desc,
				})
				SignalBus.feature_unlocked.emit(key)
		if DEBUG_LOG:
			pass
			# [LOG-v5.1] print("[LevelProgress] 解锁关卡: %d" % next_level)

## 检查是否解锁新时代
func _check_era_unlock(level: int) -> void:
	# Boss关卡：20, 40, 60, 80, 100
	var boss_levels = [20, 40, 60, 80, 100]

	if level in boss_levels:
		var era = int(level / 20.0) + 1
		if era <= 5 and not unlocked_eras.get(era, false):
			unlocked_eras[era] = true
			era_unlocked.emit(era)
			if DEBUG_LOG:
				pass
				# [LOG-v5.1] print("[LevelProgress] 解锁时代: %d" % era)

## 首次通关奖励已随 2026-09-19 双首通收敛删除（原遗留纳米发放 50+5lv + Boss 500）——
## 唯一真身 = GameManager._grant_first_clear_if_eligible + data/first_clear_rewards.gd。

## 获取已解锁关卡列表
func get_unlocked_levels() -> Array:
	return unlocked_levels.duplicate()

## 获取最大解锁关卡
func get_max_unlocked_level() -> int:
	return max_unlocked_level

# ── v34 渐进解锁门控（真身查询；节奏表 = data/feature_unlock_schedule.gd）──
## 系统入口是否已解锁。判定链（短路顺序）：
## 总开关关 = 全开 → 不在节奏表 = 常开不设防 → 教程已完成 = 全开（老档兜底）→ 关卡阈值。
## 消费方：truck_base 热区/时代chips、bottom_function_bar、main._open_overlay 守卫。
func is_feature_unlocked(key: String) -> bool:
	if not GameConfig.get_default().feature_gates_enabled:
		return true
	if not FeatureUnlockSchedule.has_key(key):
		return true
	var tm := get_node_or_null("/root/TutorialProgressionManager")
	if tm != null and tm.has_method("is_tutorial_completed") and tm.is_tutorial_completed():
		return true
	return max_unlocked_level >= FeatureUnlockSchedule.unlock_level_for(key)

## 未解锁入口的点击提示文案（"通关第 N 关解锁：XX"）
func feature_gate_hint(key: String) -> String:
	if not FeatureUnlockSchedule.has_key(key):
		return ""
	return "通关第 %d 关解锁：%s" % [
		FeatureUnlockSchedule.unlock_level_for(key),
		String(FeatureUnlockSchedule.SCHEDULE[key]["title"]),
	]

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
			# v38.4 修复：Godot JSON 把裸整数解析成 float，此前 `level is int` 过滤
			# 会把 JSON 读档的所有元素全拒——unlocked_levels 清零、max 落回 1，
			# 随后任何存档经 current_level←max 同步把玩家进度拖回第 1 关。
			# 与下方 v26.6 字典 int(k) 强转对称：接受 int/float，int() 强转 + 值域钳制。
			if level is int or level is float:
				var lv := int(level)
				if lv >= 1 and lv <= 100:
					unlocked_levels.append(lv)
	elif state.has("unlocked_levels"):
		push_warning("[LevelProgress] unlocked_levels 类型错误: %s，已跳过" % type_string(typeof(state["unlocked_levels"])))

	# v26.6 修复：三个字典以 int 为 key，JSON 写盘往返后 key 全部变 String——此前直接
	# duplicate 导致 get_level_stars/is_first_completion/is_era_unlocked 永远查空
	# （读档星级归零、首通奖励重复发放、时代解锁状态回退）。此处统一重建 int key 并钳值域。
	level_stars = {}
	if state.has("level_stars") and state["level_stars"] is Dictionary:
		for k in state["level_stars"]:
			var lv := int(k)
			if lv >= 1 and lv <= 100:
				level_stars[lv] = clampi(int(state["level_stars"][k]), 0, 3)
	else:
		push_warning("[LevelProgress] level_stars 缺失或类型错误，已清空")

	first_completion = {}
	if state.has("first_completion") and state["first_completion"] is Dictionary:
		for k in state["first_completion"]:
			var f_lv := int(k)
			if f_lv >= 1 and f_lv <= 100:
				first_completion[f_lv] = bool(state["first_completion"][k])

	unlocked_eras = {1: true}
	if state.has("unlocked_eras") and state["unlocked_eras"] is Dictionary:
		for k in state["unlocked_eras"]:
			var era := int(k)
			if era >= 1 and era <= 5:
				unlocked_eras[era] = bool(state["unlocked_eras"][k])

	# 确保 max_unlocked_level 与 unlocked_levels 一致
	# v38.4 修复：同上——JSON 读档的整数是 float，`is int` 恒 false，
	# max 恒落 else 回退 1（再经存档 current_level←max 同步拖垮玩家进度）。
	var mv: Variant = state.get("max_unlocked_level")
	if mv is int or mv is float:
		max_unlocked_level = clampi(int(mv), 1, 100)
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

	if DEBUG_LOG:
		pass  # [LOG-v5.1] print("[LevelProgress] 进度已加载: max_level=%d, unlocked=%d关, stars=%d关" % [max_unlocked_level, unlocked_levels.size(), level_stars.size()])

## 重置进度（用于新游戏）
func reset_progress() -> void:
	unlocked_levels = [1]
	max_unlocked_level = 1
	level_stars.clear()
	first_completion.clear()
	unlocked_eras = {1: true}
	# v34：清待播解锁仪式队列——防同会话内"旧档跨级→回标题开新档"时旧仪式弹进新游戏
	_pending_feature_unlocks.clear()
	if DEBUG_LOG:
		pass
		# [LOG-v5.1] print("[LevelProgress] 进度已重置")

## 内部加载（初始化时调用）
## 注意：不再主动读取存档，而是等待 SaveManager 调用 load_state()
func _load_progress() -> void:
	# 进度数据将由 SaveManager.load_game() 通过 load_state() 加载
	# 这里只做初始化日志
	if DEBUG_LOG:
		pass
		# [LOG-v5.1] print("[LevelProgress] 进度管理器已初始化，等待存档加载...")
