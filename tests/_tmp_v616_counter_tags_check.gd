extends SceneTree
## v6.16 反制配波"题面必真"校验：每个 counter_bias_tags 关卡的 tag
## 必须在该关实际敌池（get_ids_for_era_at_level 关卡域池）中有 ≥1 匹配，
## 否则战前摘要预告的构成不会在实战出现（v23.2 预警诚实化原则）。

const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const LevelInfo = preload("res://data/level_information.gd")

func _init() -> void:
	var fails: Array[String] = []
	var li = LevelInfo.get_shared()
	for level in range(1, 101):
		var rules: Dictionary = li.get_special_rules(level)
		var tags: Array = rules.get("counter_bias_tags", [])
		if tags.is_empty():
			continue
		var era: int = int((level - 1) / 20.0)
		var pool: Array = EnemyArchetypes.get_ids_for_era_at_level(era, level)
		if pool.is_empty():
			fails.append("L%d: 关池为空" % level)
			continue
		# 逐 tag 统计池内匹配数（合并 tag 至少 1 个命中即合法，逐 tag 也报告）
		for t in tags:
			var hits: int = 0
			for aid in pool:
				if (EnemyArchetypes.get_config(String(aid)).get("tags", []) as Array).has(t):
					hits += 1
			print("L%-3d %-10s 命中 %d/%d" % [level, t, hits, pool.size()])
			if hits == 0:
				fails.append("L%d tag '%s' 在关池零匹配" % [level, t])
	if fails.is_empty():
		print("COUNTER_TAGS_OK")
	else:
		for f in fails:
			print("FAIL: " + f)
		quit(1)
	quit(0)
