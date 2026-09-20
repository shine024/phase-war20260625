extends SceneTree
## v6.17.2 boss 套路演练：对全部敌方相位师跑 套路识别/配置/补位/补兵延迟，只读诊断。
var problems: Array = []

func _initialize() -> void:
	var Patterns = load("res://data/enemy_phase_master_patterns.gd")
	var EMST = load("res://data/enemy_master_skill_tree.gd")
	var masters: Dictionary = EMST.MASTER_NODES
	var pattern_count: Dictionary = {}
	# ① 数据检查：MASTER_PATTERN_MAP 必须覆盖全部 master（权威表 6 套路 × 6 人）
	var mapped: Dictionary = Patterns.MASTER_PATTERN_MAP
	for mid in masters:
		if not mapped.has(String(mid)):
			problems.append("%s 未在 MASTER_PATTERN_MAP 中（将走 none 兜底）" % mid)
	for mid2 in mapped:
		if not masters.has(String(mid2)):
			problems.append("MASTER_PATTERN_MAP 含未知 master: %s" % mid2)
	# ② 行为演练：6 个套路各走补位规则（规则1 死者同款 / 套路 preferred / 随机兜底）与延迟
	var synth_pool := ["fut_inf_cyborg", "fut_arm_titan_mk2", "fut_sup_ps9", "fut_fort_ion"]
	var lookup := func(_id: String) -> Dictionary: return {}
	for pid in Patterns.PATTERNS.keys():
		pattern_count[pid] = pattern_count.get(pid, 0) + 1
		var pc: Dictionary = Patterns.get_pattern_config(String(pid))
		if pc.is_empty():
			problems.append("套路 %s 配置为空" % pid)
		var picked: String = Patterns.pick_respawn_platform(String(pid), synth_pool,
			"fut_arm_titan_mk2", 1, [], lookup)
		if picked != "fut_arm_titan_mk2":
			problems.append("套路 %s 规则1（死者同款优先）失效: 返回 %s" % [pid, picked])
		var picked2: String = Patterns.pick_respawn_platform(String(pid), synth_pool,
			"", 1, [], lookup)
		if picked2.is_empty() or not synth_pool.has(picked2):
			problems.append("套路 %s 兜底补位失效: 返回 %s" % [pid, picked2])
		var d: float = Patterns.compute_respawn_delay(String(pid), [3.0, 4.0, 5.0])
		if d < 0.0 or d > 60.0:
			problems.append("套路 %s 补兵延迟越界: %s" % [pid, d])
	print("套路演练分布:", pattern_count)
	if problems.is_empty():
		print("BOSS_PATTERN_OK")
	else:
		print("BOSS_PATTERN_ISSUES %d" % problems.size())
		for p in problems:
			print("  [P] ", p)
	quit(0 if problems.is_empty() else 1)

func _collect_ids(cfg) -> Array:
	var out: Array = []
	var stack := [cfg]
	while not stack.is_empty():
		var cur = stack.pop_back()
		if cur is Dictionary:
			for k in cur:
				stack.append(cur[k])
		elif cur is Array:
			for v in cur:
				stack.append(v)
		elif cur is String and ((cur as String).begins_with("fut_") or (cur as String).contains("_inf_") or (cur as String).contains("_arm_")):
			if not out.has(cur):
				out.append(cur)
	return out
