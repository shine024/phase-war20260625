class_name FeatureUnlockScheduleTest
extends GdUnitTestSuite
## v34 渐进解锁回归锁（data/feature_unlock_schedule.gd + LevelProgressManager 门控链）
## 契约：
## - 节奏表（v37 实机验收轮调改）：evolution=intelligence=2（制造+情报提前，配新档
##   起始卡同族 25% 情报地板）/ afk=5 / modification=6（改造推后）/ faction=store=10 /
##   affix=12 / 旁路六件（quest/achievement/collection/leaderboard/hero_archive/memorial）=15
## - is_feature_unlocked：总开关关=全开；教程已完成=全开（老档兜底）；否则按
##   max_unlocked_level 阈值；未知键不设防
## - 跨级信号：complete_level 触达节奏表关卡 → SignalBus.feature_unlocked 恰发该批键
##   且入 LPM 待播队列；重打旧关不重弹（prev_max 守卫）

const FUS = preload("res://data/feature_unlock_schedule.gd")


func test_schedule_levels_mild_curve() -> void:
	assert_int(FUS.unlock_level_for("evolution")).is_equal(2)
	assert_int(FUS.unlock_level_for("intelligence")).is_equal(2)
	assert_int(FUS.unlock_level_for("afk")).is_equal(5)
	assert_int(FUS.unlock_level_for("modification")).is_equal(6)
	assert_int(FUS.unlock_level_for("faction")).is_equal(10)
	assert_int(FUS.unlock_level_for("store")).is_equal(10)
	assert_int(FUS.unlock_level_for("affix")).is_equal(12)
	for key in ["quest", "achievement", "collection", "leaderboard", "hero_archive", "memorial"]:
		assert_int(FUS.unlock_level_for(key)).is_equal(15)
	# 未知键 = 常开不设防
	assert_int(FUS.unlock_level_for("backpack")).is_equal(0)
	assert_bool(FUS.has_key("backpack")).is_false()


func test_open_set_by_max_level() -> void:
	# L1 新档：节奏表全锁（常开集不在表内）
	assert_array(FUS.unlocked_keys_at_max_level(1)).is_empty()
	# L2：制造+情报双开（v37 提前——配开局情报地板，首战通关即可制造）
	var at2: Array = FUS.unlocked_keys_at_max_level(2)
	assert_int(at2.size()).is_equal(2)
	assert_bool(at2.has("evolution")).is_true()
	assert_bool(at2.has("intelligence")).is_true()
	# L5：制造+情报+挂机（改造已推后到 L6）
	var at5: Array = FUS.unlocked_keys_at_max_level(5)
	assert_int(at5.size()).is_equal(3)
	assert_bool(at5.has("modification")).is_false()
	assert_bool(at5.has("afk")).is_true()
	# L15：全部 13 键开放
	assert_int(FUS.unlocked_keys_at_max_level(15).size()).is_equal(FUS.SCHEDULE.size())
	# keys_unlocked_at：L2 恰好新开 evolution+intelligence；L6 恰好新开 modification
	var fresh2: Array = FUS.keys_unlocked_at(2)
	assert_int(fresh2.size()).is_equal(2)
	var fresh6: Array = FUS.keys_unlocked_at(6)
	assert_int(fresh6.size()).is_equal(1)
	assert_bool(fresh6.has("modification")).is_true()


func _lpm() -> Node:
	return get_node_or_null("/root/LevelProgressManager")


func _tutorial() -> Node:
	return get_node_or_null("/root/TutorialProgressionManager")


func test_is_feature_unlocked_level_threshold() -> void:
	var lpm: Node = _lpm()
	if lpm == null or not lpm.has_method("is_feature_unlocked"):
		print("  LPM autoload 不在，跳过")
		return
	var gates_bak := GameConfig.get_default().feature_gates_enabled
	var tm: Node = _tutorial()
	var tm_step_bak = null
	GameConfig.get_default().feature_gates_enabled = true
	# 教程视为未完成（阈值路径生效）
	if tm != null:
		tm_step_bak = tm.current_step
		tm.current_step = 1  # INTRO_WELCOME ≠ FREEDOM_MODE
	var max_bak: int = lpm.max_unlocked_level
	# v37 节奏：evolution/intelligence 在 L2，modification 推到 L6——双档各验一次
	lpm.max_unlocked_level = 1
	assert_bool(lpm.is_feature_unlocked("evolution")).is_false()
	lpm.max_unlocked_level = 2
	assert_bool(lpm.is_feature_unlocked("evolution")).is_true()
	lpm.max_unlocked_level = 5
	assert_bool(lpm.is_feature_unlocked("modification")).is_false()
	lpm.max_unlocked_level = 6
	assert_bool(lpm.is_feature_unlocked("modification")).is_true()
	# 未知键不设防
	assert_bool(lpm.is_feature_unlocked("backpack")).is_true()
	# 教程完成 → 全开兜底（老档兼容）
	if tm != null:
		tm.current_step = 13  # FREEDOM_MODE
		lpm.max_unlocked_level = 1
		assert_bool(lpm.is_feature_unlocked("modification")).is_true()
		tm.current_step = tm_step_bak
	# 总开关关 → 一键回退全开
	GameConfig.get_default().feature_gates_enabled = false
	lpm.max_unlocked_level = 1
	assert_bool(lpm.is_feature_unlocked("affix")).is_true()
	# 还原
	GameConfig.get_default().feature_gates_enabled = gates_bak
	lpm.max_unlocked_level = max_bak


func test_unlock_signal_and_pending_queue_on_level_cross() -> void:
	var lpm: Node = _lpm()
	if lpm == null or not lpm.has_method("complete_level"):
		print("  LPM autoload 不在，跳过")
		return
	var gates_bak := GameConfig.get_default().feature_gates_enabled
	var tm: Node = _tutorial()
	var tm_step_bak = null
	GameConfig.get_default().feature_gates_enabled = true
	if tm != null:
		tm_step_bak = tm.current_step
		tm.current_step = 13  # FREEDOM_MODE（教程态不影响信号/队列路径，但保持口径一致）
	var state_bak: Dictionary = lpm.save_state()
	lpm.reset_progress()
	# 预填首通记录——跳过 _grant_first_completion_rewards，避免污染全局 BasicResourceManager
	lpm.first_completion = {1: true, 2: true, 3: true, 4: true, 5: true, 6: true}
	_lpm_consume(lpm)
	var fired: Array = []
	var cb := func(key: String) -> void: fired.append(key)
	SignalBus.feature_unlocked.connect(cb)
	# 通关第 1 关（解锁第 2 关 → 节奏表 L2 批）：制造+情报双键同拍发射并入队（v37 提前批）
	lpm.complete_level(1, 3)
	assert_array(fired).is_equal(["evolution", "intelligence"])
	var pending: Array = _lpm_consume(lpm)
	assert_int(pending.size()).is_equal(2)
	assert_str(String(pending[0]["key"])).is_equal("evolution")
	assert_str(String(pending[0]["title"])).is_equal("制造中心")
	assert_str(String(pending[1]["key"])).is_equal("intelligence")
	# 重打 L1（星级刷新）：不重复解锁/不重弹
	lpm.complete_level(1, 3)
	assert_int(fired.size()).is_equal(2)
	assert_array(_lpm_consume(lpm)).is_empty()
	# 通关第 4 关（解锁第 5 关）：恰发挂机；第 5 关（解锁第 6 关）：恰发改造（v37 推后）
	lpm.complete_level(2, 3)
	lpm.complete_level(3, 3)
	fired.clear()
	lpm.complete_level(4, 3)
	assert_array(fired).is_equal(["afk"])
	fired.clear()
	lpm.complete_level(5, 3)
	assert_array(fired).is_equal(["modification"])
	SignalBus.feature_unlocked.disconnect(cb)
	# 还原
	lpm.load_state(state_bak)
	if tm != null:
		tm.current_step = tm_step_bak
	GameConfig.get_default().feature_gates_enabled = gates_bak


func _lpm_consume(lpm: Node) -> Array:
	if lpm.has_method("consume_pending_feature_unlocks"):
		return lpm.consume_pending_feature_unlocks()
	return []
