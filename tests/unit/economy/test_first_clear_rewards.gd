extends GdUnitTestSuite
## 首通奖励数据锁（2026-10-08 收益感批公式——调数值必须同步这里）
## 背景：v32 线性占位公式 L100 首通≈2 分钟后期流水，推关无收益感（实机主诉）。
## 新公式 = BASE × depth(0.7→2.0) × era_mult[3,5,8.5,14,24] × 相位师关×2.5。
## 锚点：L100 首通≈8 场常规收入；L99→L100 相位跳变 2.5×；era 交替有可见回落。
## 同时锁里程碑大奖声明（20 倍数关：成品卡+epic+ 蓝图；L100 加星髓 150）。

const FCR = preload("res://data/first_clear_rewards.gd")


func test_anchor_values() -> void:
	# 锚点值（公式变更必须重审这组数）：
	# L1:  m=0.713×3.0=2.14  → nano 855
	# L20: m=0.96×3.0×2.5=7.2 → nano 2880
	# L99: m=1.987×24=47.688 → nano 19075
	# L100: m=2.0×24×2.5=120 → nano 48000 / crystal 4200 / alloy 4800 / energy 1440
	var r1: Dictionary = FCR.get_first_clear_reward(1)
	assert_int(int(r1["nano_materials"])).is_equal(855)
	assert_int(int(r1["crystal"])).is_equal(74)
	var r20: Dictionary = FCR.get_first_clear_reward(20)
	assert_int(int(r20["nano_materials"])).is_equal(2879)
	var r100: Dictionary = FCR.get_first_clear_reward(100)
	assert_int(int(r100["nano_materials"])).is_equal(48000)
	assert_int(int(r100["crystal"])).is_equal(4200)
	assert_int(int(r100["alloy"])).is_equal(4800)
	assert_int(int(r100["energy_block"])).is_equal(1440)


func test_phase_master_jump_at_era_end() -> void:
	# L99→L100 相位师关 2.5 倍跳变（时代高潮可感知）
	var r99: Dictionary = FCR.get_first_clear_reward(99)
	var r100: Dictionary = FCR.get_first_clear_reward(100)
	assert_float(float(r100["nano_materials"]) / float(r99["nano_materials"])).is_equal_approx(2.5, 0.05)


func test_era_step_visible() -> void:
	# 时代跳变：era 首关即便回吐相位加成，仍应明显厚于上一时代中段（梯度感核心）
	var r19: Dictionary = FCR.get_first_clear_reward(19)
	var r21: Dictionary = FCR.get_first_clear_reward(21)
	assert_int(int(r21["nano_materials"])).is_greater(int(1.5 * float(r19["nano_materials"])))
	var r79: Dictionary = FCR.get_first_clear_reward(79)
	var r81: Dictionary = FCR.get_first_clear_reward(81)
	assert_int(int(r81["nano_materials"])).is_greater(int(1.5 * float(r79["nano_materials"])))


func test_monotonic_within_era_and_late_game_heavier() -> void:
	# 同时代内不递减（深度系数单调）；era 边界允许回落（上时代相位关 ×2.5）；后期显著厚于前期
	var prev := 0
	for level in range(1, 101):
		var r: Dictionary = FCR.get_first_clear_reward(level)
		if level % 20 != 1:
			assert_int(int(r["nano_materials"])).is_greater_equal(prev)
		prev = int(r["nano_materials"])
	var r10: Dictionary = FCR.get_first_clear_reward(10)
	assert_int(int(FCR.get_first_clear_reward(90)["nano_materials"])).is_greater(int(8.0 * float(r10["nano_materials"])))


func test_milestone_bonus_declaration() -> void:
	# 20 倍数关=里程碑大奖（卡+epic+ 蓝图声明）；非 20 倍数=空
	assert_dict(FCR.get_milestone_bonus(19)).is_empty()
	assert_dict(FCR.get_milestone_bonus(21)).is_empty()
	var b20: Dictionary = FCR.get_milestone_bonus(20)
	assert_int(int(b20["bonus_card_id"])).is_equal(0)
	assert_str(String(b20["bonus_blueprint_min_rarity"])).is_equal("epic")
	assert_bool(b20.has("star_marrow")).is_false()
	var b100: Dictionary = FCR.get_milestone_bonus(100)
	assert_int(int(b100["star_marrow"])).is_equal(150)


func test_invalid_level_empty_and_format() -> void:
	assert_dict(FCR.get_first_clear_reward(0)).is_empty()
	assert_dict(FCR.get_first_clear_reward(-5)).is_empty()
	assert_str(FCR.format_reward_text({})).is_empty()
	assert_str(FCR.format_reward_text(FCR.get_first_clear_reward(1))).contains("晶体 74")
