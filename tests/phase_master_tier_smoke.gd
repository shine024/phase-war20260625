## v7.x 相位师产兵 tier 递进 smoke test
## 验证：get_phase_master_tier 按时代进度递进 + 驻守 19 关分布 + rune_count 限量
extends SceneTree

const EnemyLoadoutTiers = preload("res://data/enemy_loadout_tiers.gd")
const PhaseMasterGarrison = preload("res://data/phase_master_garrison.gd")

func _init() -> void:
	var fail_count: int = 0
	var fail := func(msg: String) -> void:
		fail_count += 1
		push_error("[FAIL] " + msg)
		print("  ❌ " + msg)

	print("=== 1. get_phase_master_tier 按时代进度递进 ===")
	# 时代早期 (era_progress < 0.70) → TIER_MID
	var t_early: int = EnemyLoadoutTiers.get_phase_master_tier(0.0)
	var t_mid: int = EnemyLoadoutTiers.get_phase_master_tier(0.5)
	# 时代后期 (era_progress >= 0.70) → TIER_HIGH
	var t_late: int = EnemyLoadoutTiers.get_phase_master_tier(0.75)
	var t_boss: int = EnemyLoadoutTiers.get_phase_master_tier(1.0)
	print("  early(0.0)=%d  mid(0.5)=%d  late(0.75)=%d  boss(1.0)=%d" % [t_early, t_mid, t_late, t_boss])
	if t_early != EnemyLoadoutTiers.TIER_MID:
		fail.call("early 应为 TIER_MID(2)，实际 %d" % t_early)
	if t_mid != EnemyLoadoutTiers.TIER_MID:
		fail.call("mid 应为 TIER_MID(2)，实际 %d" % t_mid)
	if t_late != EnemyLoadoutTiers.TIER_HIGH:
		fail.call("late 应为 TIER_HIGH(3)，实际 %d" % t_late)
	if t_boss != EnemyLoadoutTiers.TIER_HIGH:
		fail.call("boss 应为 TIER_HIGH(3)，实际 %d" % t_boss)
	# 相位师最低保障不低于 TIER_MID（不跌到 LOW）
	if t_early == EnemyLoadoutTiers.TIER_LOW:
		fail.call("相位师早期不应跌到 TIER_LOW")

	print("")
	print("=== 2. 驻守 19 关 era_progress 分布 ===")
	# 驻守关：10,15,20,25,...,100。验证 era_progress 计算 + tier 派生
	var garrison_levels: Array = PhaseMasterGarrison.get_all_garrison_levels()
	print("  驻守关数：%d" % garrison_levels.size())
	if garrison_levels.size() != 19:
		fail.call("驻守关应为 19 个，实际 %d" % garrison_levels.size())
	var tier_dist: Dictionary = {}
	for lvl in garrison_levels:
		var era_local: int = ((int(lvl) - 1) % 20) + 1
		var prog: float = float(era_local - 1) / 19.0
		var tier: int = EnemyLoadoutTiers.get_phase_master_tier(prog)
		tier_dist[tier] = int(tier_dist.get(tier, 0)) + 1
		print("  L%-3d era_local=%-2d progress=%.2f → tier=%d (%s)" % [
			int(lvl), era_local, prog, tier,
			"MID中配" if tier == EnemyLoadoutTiers.TIER_MID else "HIGH高配"
		])
	print("  分布：%s" % str(tier_dist))
	# 应同时存在 MID 和 HIGH（不能全是 HIGH）
	if not tier_dist.has(EnemyLoadoutTiers.TIER_MID):
		fail.call("驻守关 tier 分布无 TIER_MID（递进失效，仍全是 HIGH）")
	if not tier_dist.has(EnemyLoadoutTiers.TIER_HIGH):
		fail.call("驻守关 tier 分布无 TIER_HIGH")

	print("")
	print("=== 3. tier → enhance_level / rune_count 派生 ===")
	var mid_bonus: Dictionary = EnemyLoadoutTiers.get_bonus_for_tier(EnemyLoadoutTiers.TIER_MID)
	var high_bonus: Dictionary = EnemyLoadoutTiers.get_bonus_for_tier(EnemyLoadoutTiers.TIER_HIGH)
	print("  MID:  enhance=%d rune_count=%d atk+%.0f%% hp+%.0f%%" % [
		int(mid_bonus.get("enhance_level", 0)), int(mid_bonus.get("rune_count", 0)),
		float(mid_bonus.get("atk_pct", 0))*100, float(mid_bonus.get("hp_pct", 0))*100])
	print("  HIGH: enhance=%d rune_count=%d atk+%.0f%% hp+%.0f%%" % [
		int(high_bonus.get("enhance_level", 0)), int(high_bonus.get("rune_count", 0)),
		float(high_bonus.get("atk_pct", 0))*100, float(high_bonus.get("hp_pct", 0))*100])
	# MID < HIGH（递进方向正确）
	if int(mid_bonus.get("enhance_level", 0)) >= int(high_bonus.get("enhance_level", 0)):
		fail.call("MID enhance_level 应 < HIGH")
	if int(mid_bonus.get("rune_count", 0)) >= int(high_bonus.get("rune_count", 0)):
		fail.call("MID rune_count 应 < HIGH")

	print("")
	print("=== 4. 相位仪 unit_capacity 完整性 ===")
	# 读 JSON 验证 26 条都有 unit_capacity
	var json_path: String = "res://data/json/enemy_phase_instruments.json"
	var text: String = FileAccess.get_file_as_string(json_path)
	var parsed: Variant = JSON.parse_string(text)
	var data: Dictionary = parsed.get("data", {}) if parsed is Dictionary else {}
	var cap_count: int = 0
	var missing_cap: Array = []
	for iid in data:
		var inst: Dictionary = data[iid]
		if inst.has("unit_capacity"):
			cap_count += 1
		else:
			missing_cap.append(iid)
	print("  有 unit_capacity 的相位仪：%d / %d" % [cap_count, data.size()])
	if data.size() != 26:
		fail.call("相位仪总数应为 26，实际 %d" % data.size())
	if cap_count != data.size():
		fail.call("缺失 unit_capacity 的相位仪：%s" % str(missing_cap))
	# capacity 范围校验（应在 3~6）
	var cap_values: Array = []
	for iid in data:
		cap_values.append(int(data[iid].get("unit_capacity", 0)))
	var min_cap: int = cap_values.min() if not cap_values.is_empty() else 0
	var max_cap: int = cap_values.max() if not cap_values.is_empty() else 0
	print("  capacity 范围：%d ~ %d" % [min_cap, max_cap])
	if min_cap < 3 or max_cap > 6:
		fail.call("capacity 范围异常：%d~%d（应在 3~6）" % [min_cap, max_cap])

	print("")
	print("=== 5. era_progress 公式核对（与 battle_spawn_system 一致）===")
	# 抽几个关卡核对 era_progress 计算
	var test_cases: Array = [
		# [level, expected_era_local, expected_progress_tier]
		[10, 10, EnemyLoadoutTiers.TIER_MID],   # WW1 中期 era_local=10, prog=0.47 < 0.70 → MID
		[20, 20, EnemyLoadoutTiers.TIER_HIGH],  # WW1 末/Boss era_local=20, prog=1.0 ≥ 0.70 → HIGH
		[35, 15, EnemyLoadoutTiers.TIER_HIGH],  # WW2 后期 era_local=15, prog=0.74 ≥ 0.70 → HIGH
		[45, 5,  EnemyLoadoutTiers.TIER_MID],   # COLD 早期 era_local=5, prog=0.21 < 0.70 → MID
		[100, 20, EnemyLoadoutTiers.TIER_HIGH], # FUTURE 末/Boss prog=1.0 → HIGH
	]
	for tc in test_cases:
		var lv: int = tc[0]
		var exp_local: int = tc[1]
		var exp_tier: int = tc[2]
		var era_local: int = ((lv - 1) % 20) + 1
		var prog: float = float(era_local - 1) / 19.0
		var tier: int = EnemyLoadoutTiers.get_phase_master_tier(prog)
		var ok: bool = (era_local == exp_local and tier == exp_tier)
		print("  L%-3d era_local=%-2d prog=%.2f tier=%d %s" % [
			lv, era_local, prog, tier, "✓" if ok else "✗ 期望 era_local=%d tier=%d" % [exp_local, exp_tier]])
		if not ok:
			fail.call("L%d era_local/tier 不匹配" % lv)

	print("")
	print("════════════════════════════════════════")
	if fail_count == 0:
		print("✅ 全部 PASS（5 项验证）")
	else:
		print("❌ %d 项 FAIL" % fail_count)
	print("════════════════════════════════════════")
	quit(0 if fail_count == 0 else 1)
