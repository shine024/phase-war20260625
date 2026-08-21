extends SceneTree
## v10 解题式玩法 smoke test：关卡战术主题系统（题面）验证
## 运行：Godot --headless --script tests/level_themes_smoke.gd
## 不依赖 GdUnit（GdUnit4 在 4.5.1 有兼容性问题，与 master_power_smoke 同模式）

const LevelTacticalThemes = preload("res://data/level_tactical_themes.gd")
const LevelSpawnSequences = preload("res://data/level_spawn_sequences.gd")

var _fail_count: int = 0


func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		_fail_count += 1
		print("  FAIL: %s" % msg)


func _initialize() -> void:
	print("=== LevelTacticalThemes Smoke Test ===")

	# 1. 主题分配确定性：同关恒同主题
	print("[1] 确定性")
	var t1: String = LevelTacticalThemes.get_theme_id_for_level(50)
	var t2: String = LevelTacticalThemes.get_theme_id_for_level(50)
	_assert(t1 == t2, "同关（50）两次查询同主题: %s" % t1)

	# 2. 8 主题覆盖率
	print("[2] 覆盖率")
	var dist: Dictionary = {}
	for lv in range(1, 101):
		var tid: String = LevelTacticalThemes.get_theme_id_for_level(lv)
		dist[tid] = int(dist.get(tid, 0)) + 1
	print("    分布: %s" % str(dist))
	_assert(dist.size() >= 6, "100 关至少覆盖 6/8 主题（实际 %d）" % dist.size())

	# 3. 教学关固定 SWARM_RUSH
	print("[3] 教学关")
	for lv in [1, 21, 41, 61, 81]:
		var tid: String = LevelTacticalThemes.get_theme_id_for_level(lv)
		_assert(tid == LevelTacticalThemes.SWARM_RUSH, "时代首关 Lv%d = 蜂群冲锋（实际 %s）" % [lv, tid])

	# 4. 一战（1-20）无 AIR_SUPREMACY
	print("[4] 时代约束")
	var ww1_has_air: bool = false
	for lv in range(1, 21):
		if LevelTacticalThemes.get_theme_id_for_level(lv) == LevelTacticalThemes.AIR_SUPREMACY:
			ww1_has_air = true
			break
	_assert(not ww1_has_air, "一战（1-20）无空中压制主题（池内无 aircraft archetype）")

	# 5. 相邻关主题去重
	print("[5] 相邻去重")
	var adjacent_same: int = 0
	for lv in range(2, 101):
		if LevelTacticalThemes.get_theme_id_for_level(lv) == LevelTacticalThemes.get_theme_id_for_level(lv - 1):
			adjacent_same += 1
	_assert(adjacent_same == 0, "相邻关不同主题（重复 %d 处）" % adjacent_same)

	# 6. roll_wave_bias 输出合法性
	print("[6] 波次 bias")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in range(50):
		var tags: Array = LevelTacticalThemes.roll_wave_bias(LevelTacticalThemes.ARMOR_PUSH, rng)
		_assert(tags is Array, "roll_wave_bias 返回 Array（第 %d 次）" % i)
		if not (tags is Array):
			break
	print("    （50 次合法性抽样完成）")

	# 7. get_wave_spec 带 theme_id 且 bias 与主题一致
	print("[7] 序列 spec")
	var spec50: Dictionary = LevelSpawnSequences.get_wave_spec(50, 2)
	_assert(not spec50.is_empty(), "Lv50 wave2 spec 非空")
	_assert(String(spec50.get("theme_id", "")) == LevelTacticalThemes.get_theme_id_for_level(50),
		"spec.theme_id 与主题分配一致（%s）" % String(spec50.get("theme_id", "")))
	var comp: Dictionary = spec50.get("composition", {})
	var comp_sum: float = float(comp.get("basic", 0.0)) + float(comp.get("elite", 0.0)) + float(comp.get("boss", 0.0))
	_assert(absf(comp_sum - 1.0) < 0.05, "composition 归一化（和=%.3f）" % comp_sum)

	# 8. AIR_SUPREMACY 主题的 bias 含 aircraft
	print("[8] 主题 bias 语义")
	var air_bias_found: bool = false
	for lv in range(21, 101):
		if LevelTacticalThemes.get_theme_id_for_level(lv) == LevelTacticalThemes.AIR_SUPREMACY:
			var seq: Array = LevelSpawnSequences.get_sequence_for_level(lv)
			var aircraft_waves: int = 0
			for s in seq:
				var bt: Array = s.get("archetype_bias_tags", [])
				if bt.has("aircraft"):
					aircraft_waves += 1
			print("    Lv%d（空中压制）%d/%d 波 bias=aircraft" % [lv, aircraft_waves, seq.size()])
			if aircraft_waves > 0:
				air_bias_found = true
			break
	_assert(air_bias_found, "空中压制主题关存在 aircraft bias 波")

	# 9. get_theme_display 结构完整
	print("[9] 显示接口")
	var disp: Dictionary = LevelTacticalThemes.get_theme_display(50)
	_assert(disp.has("name") and not String(disp.get("name", "")).is_empty(), "display.name 非空")
	_assert(disp.has("threat") and not String(disp.get("threat", "")).is_empty(), "display.threat 非空")
	_assert(disp.has("advice") and not String(disp.get("advice", "")).is_empty(), "display.advice 非空")

	# 10. tags_to_display 中文映射
	print("[10] tag 显示")
	var td: String = LevelTacticalThemes.tags_to_display(["armored", "tank"])
	_assert(td == "装甲", "armored+tank → 装甲（实际 %s）" % td)
	var td_empty: String = LevelTacticalThemes.tags_to_display([])
	_assert(td_empty == "混合", "空 tags → 混合（实际 %s）" % td_empty)

	print("=== 结果: %s（失败 %d 项）===" % ["全部通过" if _fail_count == 0 else "存在失败", _fail_count])
	quit(0 if _fail_count == 0 else 1)
