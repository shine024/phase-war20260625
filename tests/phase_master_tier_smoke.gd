## 相位师产兵 tier smoke test（v26 重写：get_phase_master_tier 恒 TIER_LEGENDARY——
## v8.2 起已是常数，本 smoke 旧"递进"断言与实现脱节，按 v26 四档口径重写）
## 验证：恒传奇档 + 驻守 19 关覆盖 + rune_count/enhance 派生 + 相位仪 green 完整性
extends SceneTree

const EnemyLoadoutTiers = preload("res://data/enemy_loadout_tiers.gd")
const PhaseMasterGarrison = preload("res://data/phase_master_garrison.gd")

func _init() -> void:
	var fail_count: int = 0
	var fail := func(msg: String) -> void:
		fail_count += 1
		push_error("[FAIL] " + msg)
		print("  ❌ " + msg)

	print("=== 1. get_phase_master_tier 恒传奇档（v26）===")
	for prog in [0.0, 0.5, 0.75, 1.0]:
		var t: int = EnemyLoadoutTiers.get_phase_master_tier(prog)
		print("  progress=%.2f → tier=%d" % [prog, t])
		if t != EnemyLoadoutTiers.TIER_LEGENDARY:
			fail.call("progress %.2f 应恒为 TIER_LEGENDARY(4)，实际 %d" % [prog, t])

	print("")
	print("=== 2. 驻守 19 关 era_progress 分布 ===")
	# 驻守关：10,15,20,25,...,100。验证 era_progress 计算 + tier 派生
	var garrison_levels: Array = PhaseMasterGarrison.get_all_garrison_levels()
	print("  驻守关数：%d" % garrison_levels.size())
	if garrison_levels.size() != 19:
		fail.call("驻守关应为 19 个，实际 %d" % garrison_levels.size())
	for lvl in garrison_levels:
		var era_local: int = ((int(lvl) - 1) % 20) + 1
		var prog: float = float(era_local - 1) / 19.0
		var tier: int = EnemyLoadoutTiers.get_phase_master_tier(prog)
		if tier != EnemyLoadoutTiers.TIER_LEGENDARY:
			fail.call("L%d 相位师档位应恒传奇" % int(lvl))
	print("  全部 %d 驻守关 → TIER_LEGENDARY(传奇满配) ✓" % garrison_levels.size())

	print("")
	print("=== 3. tier → enhance_level / rune_count 派生 ===")
	var vet_bonus: Dictionary = EnemyLoadoutTiers.get_bonus_for_tier(EnemyLoadoutTiers.TIER_VETERAN)
	var leg_bonus: Dictionary = EnemyLoadoutTiers.get_bonus_for_tier(EnemyLoadoutTiers.TIER_LEGENDARY)
	print("  老兵:  enhance=%d rune_count=%d atk+%.0f%% hp+%.0f%%" % [
		int(vet_bonus.get("enhance_level", 0)), int(vet_bonus.get("rune_count", 0)),
		float(vet_bonus.get("atk_pct", 0))*100, float(vet_bonus.get("hp_pct", 0))*100])
	print("  传奇:  enhance=%d rune_count=%d atk+%.0f%% hp+%.0f%%" % [
		int(leg_bonus.get("enhance_level", 0)), int(leg_bonus.get("rune_count", 0)),
		float(leg_bonus.get("atk_pct", 0))*100, float(leg_bonus.get("hp_pct", 0))*100])
	if int(vet_bonus.get("enhance_level", 0)) >= int(leg_bonus.get("enhance_level", 0)):
		fail.call("老兵 enhance_level 应 < 传奇")
	if int(vet_bonus.get("rune_count", 0)) >= int(leg_bonus.get("rune_count", 0)):
		fail.call("老兵 rune_count 应 < 传奇")

	print("")
	print("=== 4. 统一池敌方相位仪 slot_counts.green 完整性 ===")
	# v7.x: 读统一池验证 26 敌方款都有 slot_counts.green（替代旧 JSON unit_capacity）
	var PhaseInstruments = load("res://data/phase_instruments.gd")
	var enemy_ids: Array = ["pi_steel_01","pi_steel_02","pi_steel_03","pi_steel_04","pi_steel_05",
		"pi_flame_01","pi_flame_02","pi_flame_03","pi_flame_04","pi_flame_05",
		"pi_thunder_01","pi_thunder_02","pi_thunder_03","pi_thunder_04","pi_thunder_05",
		"pi_void_01","pi_void_02","pi_void_03","pi_void_04","pi_void_05",
		"pi_steelflame_01","pi_thundersteel_01","pi_voidflame_01","pi_steelthunder_01","pi_flamevoid_01",
		"pi_omega_01"]
	var green_count: int = 0
	var missing: Array = []
	var green_values: Array = []
	for iid in enemy_ids:
		var inst: Dictionary = PhaseInstruments.get_by_id(iid)
		if inst.is_empty():
			missing.append(iid)
			continue
		var sc: Dictionary = inst.get("slot_counts", {})
		var g: int = int(sc.get("green", 0))
		if g > 0:
			green_count += 1
			green_values.append(g)
		else:
			missing.append(iid)
	print("  有 slot_counts.green 的敌方相位仪：%d / %d" % [green_count, enemy_ids.size()])
	if enemy_ids.size() != 26:
		fail.call("敌方相位仪应为 26，实际 %d" % enemy_ids.size())
	if green_count != enemy_ids.size():
		fail.call("缺失 slot_counts.green：%s" % str(missing))
	var min_g: int = green_values.min() if not green_values.is_empty() else 0
	var max_g: int = green_values.max() if not green_values.is_empty() else 0
	print("  green 范围：%d ~ %d" % [min_g, max_g])
	if min_g < 1 or max_g > 9:
		fail.call("green 范围异常：%d~%d（应在 1~9）" % [min_g, max_g])

	print("")
	print("=== 5. era_progress 公式核对（与 battle_spawn_system 一致）===")
	# 抽几个关卡核对 era_progress 计算
	var test_cases: Array = [
		# [level, expected_era_local]（相位师恒传奇，era_local 仅核对进度公式）
		[10, 10], [20, 20], [35, 15], [45, 5], [100, 20],
	]
	for tc in test_cases:
		var lv: int = tc[0]
		var exp_local: int = tc[1]
		var era_local: int = ((lv - 1) % 20) + 1
		var prog: float = float(era_local - 1) / 19.0
		var tier: int = EnemyLoadoutTiers.get_phase_master_tier(prog)
		var ok: bool = (era_local == exp_local and tier == EnemyLoadoutTiers.TIER_LEGENDARY)
		print("  L%-3d era_local=%-2d prog=%.2f tier=%d %s" % [
			lv, era_local, prog, tier, "✓" if ok else "✗"])
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
