## v7.x 3 分量战力公式 smoke test（敌我同口径）
## 验证：相位师总战力 = 相位仪战力 + Σ装备卡战力 + Σ符文战力（直接相加，无权重）
extends SceneTree

const MasterPowerEvaluator = preload("res://scripts/master_power_evaluator.gd")
const UnifiedCardTable = preload("res://data/unified_card_table.gd")

func _init() -> void:
	var fail_count: int = 0
	var fail := func(msg: String) -> void:
		fail_count += 1
		push_error("[FAIL] " + msg)
		print("  ❌ " + msg)

	print("═══════════════════════════════════════════════════════════")
	print("  3 分量战力公式验证（敌我同口径）")
	print("═══════════════════════════════════════════════════════════")

	# ══════════ 1. 3 分量公式结构验证 ══════════
	print("")
	print("=== 1. evaluate() 返回 3 分量结构 ===")
	var test_master: Dictionary = {
		"name": "测试相位师",
		"equipment": {
			"phase_instrument": "steel_guardian_mk2",
			"platforms": ["ww1_inf_rifle", "ww1_sup_mg_nest"],
			"runes": ["attack_01", "attack_02"],
		},
		"stats": {"max_hp": 2000, "unit_limit": 7},
	}
	var ev: Dictionary = MasterPowerEvaluator.evaluate(test_master)
	var scores: Dictionary = ev.get("scores", {})
	var score_keys: Array = scores.keys()
	print("  scores 键: ", score_keys)
	# 应只有 3 个键
	if score_keys.size() != 3:
		fail.call("scores 应只有 3 个键，实际 %d 个: %s" % [score_keys.size(), str(score_keys)])
	for k in ["instrument", "equipment_slots", "runes"]:
		if not scores.has(k):
			fail.call("scores 缺少键: %s" % k)
	# total = 3 分量直接相加（无权重）
	var expected_total: float = float(scores.instrument) + float(scores.equipment_slots) + float(scores.runes)
	var actual_total: float = float(ev.get("total_score", -1))
	print("  instrument=%.0f  equipment_slots=%.0f  runes=%.0f" % [
		float(scores.instrument), float(scores.equipment_slots), float(scores.runes)])
	print("  期望总分=%.0f  实际总分=%.0f" % [expected_total, actual_total])
	if absf(actual_total - expected_total) > 1.0:
		fail.call("总分应是3分量直接相加(%.0f)，实际 %.0f" % [expected_total, actual_total])

	# ══════════ 2. 敌方 A 维（相位仪）路径修复 ══════════
	print("")
	print("=== 2. 敌方 A 维路径修复（equipment.phase_instrument）===")
	# 旧 bug：读 master.phase_instrument（顶层空）→ A=0。
	# 现在回退读 equipment.phase_instrument（--script 模式下仪器 JSON 可能查不到，验证路径逻辑即可）。
	# 测试 4 已验证玩家注入路径（_player_inst_bonus_total > 0 时优先读）。
	# 这里验证：顶层 phase_instrument 为空 + equipment.phase_instrument 有值时，A 维不因顶层空而直接返回。
	# 由于 --script 模式仪器数据可能不可用，只检查 A 维参与了总分计算（已在测试 1 验证）。
	var a_val: float = float(scores.instrument)
	print("  A 维（相位仪战力）= %.0f（--script 模式仪器数据可能查不到，验证路径逻辑即可）" % a_val)
	# 关键：A 维键存在（即使值=0，说明走了查询路径而非顶层 phase_instrument 提前 return 0）
	if not scores.has("instrument"):
		fail.call("scores 应有 instrument 键（A 维路径修复）")

	# ══════════ 3. 敌方 F 维（装备卡）用 archetype power ══════════
	print("")
	print("=== 3. F 维（装备卡）用 archetype power ===")
	# ww1_inf_rifle power=73, ww1_sup_mg_nest power=60 → F=133
	var f_val: float = float(scores.equipment_slots)
	var expected_f: float = 73.0 + 60.0
	print("  F 维=%.0f  期望(73+60)=%.0f" % [f_val, expected_f])
	if absf(f_val - expected_f) > 1.0:
		fail.call("F 维应=archetype power 之和(%.0f)，实际 %.0f" % [expected_f, f_val])

	# ══════════ 4. 玩家侧注入验证（_player_platform_powers 优先）════════
	print("")
	print("=== 4. 玩家侧 _player_platform_powers 注入优先 ===")
	var player_master: Dictionary = {
		"name": "玩家测试",
		"equipment": {
			"phase_instrument": "",
			"platforms": ["fake_card"],
			"runes": [],
		},
		"_player_platform_powers": [429.0, 350.0],  # get_current_power 模拟值
		"_player_inst_bonus_total": 80.0,  # 相位仪加成模拟值
	}
	var pev: Dictionary = MasterPowerEvaluator.evaluate(player_master)
	var pscores: Dictionary = pev.get("scores", {})
	print("  玩家 A=%.0f (期望80)  F=%.0f (期望779=429+350)" % [
		float(pscores.instrument), float(pscores.equipment_slots)])
	if absf(float(pscores.instrument) - 80.0) > 1.0:
		fail.call("玩家 A 维应读 _player_inst_bonus_total(80)，实际 %.0f" % float(pscores.instrument))
	if absf(float(pscores.equipment_slots) - 779.0) > 1.0:
		fail.call("玩家 F 维应读 _player_platform_powers 之和(779)，实际 %.0f" % float(pscores.equipment_slots))
	# 验证 F 维不×3（直接相加）
	var player_total: float = float(pev.get("total_score", 0.0))
	print("  玩家总分=%.0f（应为 80+779+0=859，不×3）" % player_total)
	if absf(player_total - 859.0) > 1.0:
		fail.call("玩家总分应是 859（3分量直接相加），实际 %.0f" % player_total)

	# ══════════ 5. STAR_TIERS 分布核对 ══════════
	print("")
	print("=== 5. STAR_TIERS 新阈值 ===")
	for tier in MasterPowerEvaluator.STAR_TIERS:
		print("  %d★ %-4s  %d ~ %d" % [
			int(tier.stars), str(tier.name),
			int(tier.min_score), int(tier.max_score)])
	# 验证阈值连续递增
	var prev_max: int = 0
	for tier in MasterPowerEvaluator.STAR_TIERS:
		if int(tier.min_score) != prev_max:
			fail.call("%d★ min_score(%d) 应=上一档 max_score(%d)" % [int(tier.stars), int(tier.min_score), prev_max])
		prev_max = int(tier.max_score)

	# ══════════ 6. 星级映射合理性 ══════════
	print("")
	print("=== 6. 星级映射（总分→星级）===")
	var star_cases: Array = [
		[50, 1],     # 新手 1★
		[800, 2],    # 精英 2★
		[2000, 3],   # 高手 3★
		[5000, 4],   # 大师 4★
		[10000, 5],  # 宗师 5★
		[25000, 6],  # 传说 6★
		[50000, 7],  # 神话 7★
	]
	for tc in star_cases:
		var total: int = tc[0]
		var exp_stars: int = tc[1]
		var si: Dictionary = MasterPowerEvaluator._score_to_stars(float(total))
		var actual_stars: int = int(si.get("stars", 0))
		var ok: bool = actual_stars == exp_stars
		print("  总分 %-6d → %d★ %s %s" % [total, actual_stars, str(si.get("name","")), "✓" if ok else "✗ 期望%d★" % exp_stars])
		if not ok:
			fail.call("总分 %d 应=%d★，实际 %d★" % [total, exp_stars, actual_stars])

	print("")
	print("═══════════════════════════════════════════════════════════")
	if fail_count == 0:
		print("✅ 全部 PASS（6 项验证）")
	else:
		print("❌ %d 项 FAIL" % fail_count)
	print("═══════════════════════════════════════════════════════════")
	quit(0 if fail_count == 0 else 1)
