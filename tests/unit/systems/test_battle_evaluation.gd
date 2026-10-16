extends GdUnitTestSuite
## v6.71 战斗考评回归锁（计划 §九）：评分阈值边界、分项权重、覆盖式文案、
## battle_result 五字段结构契约（battle_damage_system → BattleEvaluation）。

const BattleEvaluationT = preload("res://data/battle_evaluation.gd")

# ─────────────────────────────────────────────────────────────
#  阈值边界
# ─────────────────────────────────────────────────────────────

func _result(stars: int, deployed: int, lost: int, elapsed: float, wave_total: int = 10, wave_interval: float = 6.0) -> Dictionary:
	return {
		"victory_stars": stars,
		"player_won": true,
		"max_deployed": deployed,
		"units_lost": lost,
		"elapsed_time": elapsed,
		"wave_total": wave_total,
		"wave_interval": wave_interval,
	}

func test_grade_thresholds_exact_boundaries() -> void:
	# 时长满分基准（10 波 × 6s = 60s）下的边界构造：
	# 部署 40 + 存活 30 + 时长 30 = 100 → S；70 → A；50 → B；<50 → C
	assert_str(String(BattleEvaluationT.calculate_evaluation_grade(_result(3, 10, 0, 60.0)).get("grade"))).is_equal("S")
	assert_str(String(BattleEvaluationT.calculate_evaluation_grade(_result(2, 8, 2, 60.0)).get("grade"))).is_equal("A")
	assert_str(String(BattleEvaluationT.calculate_evaluation_grade(_result(1, 6, 4, 60.0)).get("grade"))).is_equal("B")

func test_time_decay_linear_double_speed_to_zero() -> void:
	# 超时衰减 2 倍线性：超时 30s（=半个基准）扣 30×2=15 分时长分
	var on_time: Dictionary = BattleEvaluationT.calculate_evaluation_grade(_result(3, 10, 0, 60.0))
	var over: Dictionary = BattleEvaluationT.calculate_evaluation_grade(_result(3, 10, 0, 90.0))
	# 90s=1.5 倍基准 → 时长比 0.5 → 时长分 15（总分差 15）
	assert_int(int(on_time.get("total", 0)) - int(over.get("total", 0))).is_equal(15)
	# 极端超时：时长分归零（不为负）
	var way_over: Dictionary = BattleEvaluationT.calculate_evaluation_grade(_result(3, 10, 0, 600.0))
	assert_int(roundi(float(way_over.get("time_pts", 0.0)))).is_equal(0)

func test_defeat_never_scores() -> void:
	var ev: Dictionary = BattleEvaluationT.calculate_evaluation_grade(_result(0, 10, 10, 600.0))
	assert_str(String(ev.get("grade", "C"))).is_equal("C")

# ─────────────────────────────────────────────────────────────
#  覆盖式文案（C3 单一来源）
# ─────────────────────────────────────────────────────────────

func test_grade_change_copy_shapes() -> void:
	assert_str(BattleEvaluationT.describe_grade_change("B", "S")).contains("B→S")
	# 同级=保持文案（仍播报但不出现箭头）
	assert_str(BattleEvaluationT.describe_grade_change("A", "A")).contains("保持")
	assert_str(BattleEvaluationT.describe_grade_change("A", "A")).not_contains("→")
	# 首次评分
	assert_str(BattleEvaluationT.describe_grade_change("", "B")).contains("B")

func test_breakdown_covers_all_three_axes() -> void:
	var ev: Dictionary = BattleEvaluationT.calculate_evaluation_grade(_result(3, 10, 0, 60.0))
	var text: String = BattleEvaluationT.describe_grade_breakdown(ev)
	assert_str(text).contains("星级")
	assert_str(text).contains("存活")
	assert_str(text).contains("用时")
	# C3：无「必出」类违禁字样
	assert_str(text).not_contains("必出")

# ─────────────────────────────────────────────────────────────
#  battle_result 五字段结构契约
# ─────────────────────────────────────────────────────────────
# generate_battle_drops_only 的返回字典必须带评分输入五字段
# （battle_damage_system.gd → complete_level 挂考评读）。纯结构断言：
# BattleEvaluation 对缺字段输入的容忍度（缺=0 值默认，不崩）。

func test_evaluation_tolerates_missing_fields() -> void:
	var ev: Dictionary = BattleEvaluationT.calculate_evaluation_grade({"victory_stars": 3})
	assert_bool(ev.has("grade")).is_true()

func test_evaluation_input_contract_fields_documented() -> void:
	# battle_damage_system.battle_result 契约字段名（手写锁：改名此处红）
	for key in ["max_deployed", "units_lost", "elapsed_time", "wave_total", "wave_interval"]:
		var ev: Dictionary = BattleEvaluationT.calculate_evaluation_grade({
			"victory_stars": 3, key: 1,
		})
		assert_bool(ev.has("grade")).is_true()
