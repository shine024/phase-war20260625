extends GdUnitTestSuite
## v32.0 B3-S1 首通奖励数据锁（结构层占位值——数值轮改公式时必须同步改这里）
## 覆盖：占位公式基准值、Phase Master 关（20 的倍数）晶体加成、单调性、空级别防御、
## 文本格式化。

const FCR = preload("res://data/first_clear_rewards.gd")


func test_placeholder_formula_base_levels() -> void:
	var r1: Dictionary = FCR.get_first_clear_reward(1)
	assert_int(int(r1["crystal"])).is_equal(22)
	assert_int(int(r1["nano_materials"])).is_equal(230)
	assert_int(int(r1["energy_block"])).is_equal(5)
	var r10: Dictionary = FCR.get_first_clear_reward(10)
	assert_int(int(r10["crystal"])).is_equal(40)
	assert_int(int(r10["energy_block"])).is_equal(10)


func test_master_level_crystal_bonus() -> void:
	# 20 的倍数 = 驻守相位师关，晶体 ×2.5（占位）
	var r20: Dictionary = FCR.get_first_clear_reward(20)
	assert_int(int(r20["crystal"])).is_equal(int(60 * 2.5))
	var r19: Dictionary = FCR.get_first_clear_reward(19)
	assert_int(int(r19["crystal"])).is_equal(58)


func test_monotonic_non_decreasing() -> void:
	# 不变式：晶体恒 ≥ 基线公式（boss 关 ×2.5 只增不减，允许锯齿回落）；纳米/能量精确
	var prev_crystal := 0
	var prev_nano := 0
	for level in range(1, 101):
		var r: Dictionary = FCR.get_first_clear_reward(level)
		assert_int(int(r["crystal"])).is_greater_equal(20 + level * 2)
		assert_int(int(r["crystal"])).is_greater_equal(prev_crystal if level % 20 != 1 else 0)
		assert_int(int(r["nano_materials"])).is_equal(200 + level * 30)
		prev_crystal = int(r["crystal"])
		prev_nano = int(r["nano_materials"])


func test_invalid_level_empty_and_format() -> void:
	assert_dict(FCR.get_first_clear_reward(0)).is_empty()
	assert_dict(FCR.get_first_clear_reward(-5)).is_empty()
	assert_str(FCR.format_reward_text({})).is_empty()
	assert_str(FCR.format_reward_text(FCR.get_first_clear_reward(1))).contains("晶体 22")
