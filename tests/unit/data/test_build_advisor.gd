extends GdUnitTestSuite
## v32.0 B2-2 战前构筑建议单测：数量上限（≤3）、类型（String 数组）、
## 教学关（L1 必须无条目——特殊规则从第 5 关才介入且 L1 无环境条目）、
## 规则键优先于环境条（构造带 no_heal 规则的伪关不可行——数据只读，
## 改走 get_build_tips 对真实数据的结构性断言）。

const Advisor = preload("res://data/build_advisor.gd")
const LevelInformation = preload("res://data/level_information.gd")


func test_returns_string_array_capped_at_three() -> void:
	for level in [5, 25, 45, 65, 85, 100]:
		var tips: Array = Advisor.get_build_tips(level)
		assert_bool(tips.size() <= 3).is_true()
		for t in tips:
			assert_str(String(t)).is_not_empty()


func test_l1_tutorial_level_has_no_tips() -> void:
	# L1 教程关：无特殊规则条目（教程约束）且无环境条目 → 建议为空
	assert_array(Advisor.get_build_tips(1)).is_empty()


func test_rules_priority_before_env() -> void:
	# 若某关同时有规则与环境建议，规则条目必须排在前面
	var li = LevelInformation.get_shared()
	for level in range(2, 101):
		var rules: Dictionary = li.get_special_rules(level)
		if rules.has("no_heal") or rules.has("no_mods") or rules.has("first_strike"):
			var tips: Array = Advisor.get_build_tips(level)
			if tips.size() >= 2:
				var first: String = String(tips[0])
				assert_bool(
					first.begins_with("本场禁疗") or first.begins_with("本场改造失效")
					or first.begins_with("敌方先手")).is_true()
			break


func test_no_mods_rule_produces_tip() -> void:
	# 数据锁：限定兵种/禁改造类规则关（v30.5 记载 L15 限兵种）——
	# 逐关扫描找规则关并断言对应建议出现（若存在）
	var li = LevelInformation.get_shared()
	for level in range(2, 101):
		var rules: Dictionary = li.get_special_rules(level)
		if rules.has("no_mods"):
			var tips: Array = Advisor.get_build_tips(level)
			assert_bool(tips.size() > 0).is_true()
			break


func test_v616_counter_wave_tip() -> void:
	# v6.16 反制配波：counter_bias_tags 关必须给出针对性构筑建议（规则条最高优先级）
	var li = LevelInformation.get_shared()
	for level in [33, 43, 48, 53, 63, 83, 89]:
		var tips: Array = Advisor.get_build_tips(level)
		assert_bool(tips.size() > 0).override_failure_message("L%d 反制关无建议" % level).is_true()
		assert_str(String(tips[0])).contains("敌方")
