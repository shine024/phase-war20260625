## v7.x 单分量战力公式 smoke test（敌我同口径）
## 验证：相位师总战力 = Σ 每张装备卡加成后战力（单分量，无加权）
## 与 master_power_smoke.gd 互补：本文件聚焦结构 + 注入优先级 + 阈值连续性
extends SceneTree

const MasterPowerEvaluator = preload("res://scripts/master_power_evaluator.gd")


func _init() -> void:
	var fail_count: int = 0
	var fail := func(msg: String) -> void:
		fail_count += 1
		push_error("[FAIL] " + msg)
		print("  ❌ " + msg)

	print("═══════════════════════════════════════════════════════════")
	print("  单分量战力公式验证（Σ 卡战力之和，敌我同口径）")
	print("═══════════════════════════════════════════════════════════")

	# ══════════ 1. 单分量结构验证 ══════════
	print("\n=== 1. evaluate() 返回单分量结构 ===")
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
	# 应只有 1 个键：equipment_slots
	if score_keys.size() != 1:
		fail.call("单分量公式 scores 应只有 1 键，实际 %d 个: %s" % [score_keys.size(), str(score_keys)])
	if not scores.has("equipment_slots"):
		fail.call("scores 缺少 equipment_slots 键")
	# total = equipment_slots（单分量直接相等）
	var f_val: float = float(scores.get("equipment_slots", 0.0))
	var total_val: float = float(ev.get("total_score", -1.0))
	print("  equipment_slots=%.1f  total_score=%.1f" % [f_val, total_val])
	if absf(total_val - f_val) > 1.0:
		fail.call("总分应=equipment_slots(%.1f)，实际 %.1f" % [f_val, total_val])

	# ══════════ 2. 玩家侧注入优先级 ══════════
	print("\n=== 2. 玩家侧 _player_platform_powers 注入优先 ===")
	var player_master: Dictionary = {
		"name": "玩家测试",
		"equipment": {
			"phase_instrument": "",
			"platforms": ["fake_card"],
			"runes": [],
		},
		"_player_platform_powers": [429.0, 350.0],
	}
	var pev: Dictionary = MasterPowerEvaluator.evaluate(player_master)
	var pscores: Dictionary = pev.get("scores", {})
	var pf: float = float(pscores.get("equipment_slots", 0.0))
	var expected_pf: float = 429.0 + 350.0  # 779
	print("  玩家 equipment_slots=%.1f（期望 %.1f = 429+350）" % [pf, expected_pf])
	if absf(pf - expected_pf) > 1.0:
		fail.call("玩家 equipment_slots 应=_player_platform_powers 之和(%.1f)，实际 %.1f" % [expected_pf, pf])

	# ══════════ 3. 空装兜底 ══════════
	print("\n=== 3. 空装兜底（platforms 空时 equipment_slots=0）===")
	var empty_master := {"name": "空", "equipment": {"platforms": []}}
	var eev: Dictionary = MasterPowerEvaluator.evaluate(empty_master)
	var empty_total: float = float(eev.get("total_score", -1.0))
	print("  空装总战力=%.1f" % empty_total)
	if absf(empty_total - 0.0) > 0.01:
		fail.call("空装总战力应=0，实际 %.1f" % empty_total)

	# ══════════ 4. STAR_TIERS 阈值连续递增 ══════════
	print("\n=== 4. STAR_TIERS 阈值连续性 ===")
	var prev_max: int = 0
	for tier in MasterPowerEvaluator.STAR_TIERS:
		print("  %d★ %-4s  %d ~ %d" % [
			int(tier.stars), str(tier.name),
			int(tier.min_score), int(tier.max_score)])
		if int(tier.min_score) != prev_max:
			fail.call("%d★ min_score(%d) 应=上一档 max_score(%d)" % [int(tier.stars), int(tier.min_score), prev_max])
		prev_max = int(tier.max_score)

	# ══════════ 5. 星级映射 ══════════
	print("\n=== 5. 星级映射（总分→星级）===")
	# 阈值取自当前 STAR_TIERS（随阈值校准自动适应）
	var t = MasterPowerEvaluator.STAR_TIERS
	var star_cases: Array = [
		[int(t[0].max_score) - 1, 1],     # 1★ 上限-1
		[int(t[1].min_score), 2],          # 2★ 下限
		[int(t[2].min_score), 3],          # 3★ 下限
		[int(t[3].min_score), 4],          # 4★ 下限
		[int(t[4].min_score), 5],          # 5★ 下限
		[int(t[5].min_score), 6],          # 6★ 下限
		[int(t[6].min_score), 7],          # 7★ 下限
		[999999, 7],                       # 远超上限 clamp 到 7★
	]
	for tc in star_cases:
		var total: int = tc[0]
		var exp_stars: int = tc[1]
		var si: Dictionary = MasterPowerEvaluator._score_to_stars(float(total))
		var actual_stars: int = int(si.get("stars", 0))
		var ok: bool = actual_stars == exp_stars
		print("  总分 %-7d → %d★ %s %s" % [total, actual_stars, str(si.get("name","")), "✓" if ok else "✗ 期望%d★" % exp_stars])
		if not ok:
			fail.call("总分 %d 应=%d★，实际 %d★" % [total, exp_stars, actual_stars])

	print("")
	print("═══════════════════════════════════════════════════════════")
	if fail_count == 0:
		print("✅ 全部 PASS（5 项验证）")
	else:
		print("❌ %d 项 FAIL" % fail_count)
	print("═══════════════════════════════════════════════════════════")
	quit(0 if fail_count == 0 else 1)
