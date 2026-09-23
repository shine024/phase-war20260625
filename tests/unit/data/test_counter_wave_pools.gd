class_name CounterWavePoolsTest
extends GdUnitTestSuite
## v6.16 反制配波"题面必真"数据锁：所有 counter_bias_tags 关卡的 tag
## 必须在该关实际敌池（get_ids_for_era_at_level 关卡域池）中有 ≥1 匹配——
## 否则战前摘要预告的构成不会在实战出现（v23.2 预警诚实化原则）。
## 教训：v6.16 首挂时 L53 的 backline 在冷战池零匹配，靠本校验抓出。

const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const LevelInformation = preload("res://data/level_information.gd")


func test_all_counter_tags_match_level_pool() -> void:
	var li = LevelInformation.get_shared()
	var checked: int = 0
	for level in range(1, 101):
		var tags: Array = li.get_special_rules(level).get("counter_bias_tags", [])
		if tags.is_empty():
			continue
		checked += 1
		var era: int = int((level - 1) / 20.0)
		var pool: Array = EnemyArchetypes.get_ids_for_era_at_level(era, level)
		assert_bool(not pool.is_empty()).override_failure_message("L%d 关池为空" % level).is_true()
		for t in tags:
			var hits: int = 0
			for aid in pool:
				if (EnemyArchetypes.get_config(String(aid)).get("tags", []) as Array).has(String(t)):
					hits += 1
			assert_int(hits).override_failure_message(
				"L%d 反制 tag '%s' 在关池零匹配（题面必真违约）" % [level, t]).is_greater(0)
	# 防止规则被整体清空后测试静默通过
	assert_int(checked).is_greater_equal(13)


func test_l1_stays_counter_free() -> void:
	assert_bool(LevelInformation.get_shared().get_special_rules(1).has("counter_bias_tags")).is_false()
