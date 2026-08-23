class_name MasterPowerDistributionTest
extends GdUnitTestSuite
## 临时探针：跑 v7.x 单分量公式在 30 个真实敌方相位师上的战力分布
## 用于标定 STAR_TIERS 阈值 + compute_display_level 区间
## 跑法：godot --headless -s addons/gdunit4/bin/GdUnitCmdTool.gd -- --ignoreHeadlessMode -a res://tests/unit/managers/test_master_power_distribution.gd

const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")
const MasterPowerEvaluator = preload("res://scripts/master_power_evaluator.gd")


func test_print_enemy_power_distribution() -> void:
	var masters: Array = EnemyPhaseMasters.ENEMY_MASTERS
	print("\n=== v7.x 单分量公式：敌方相位师战力分布（n=%d）===" % masters.size())

	var era_names: Dictionary = {0:"WW1", 1:"WW2", 2:"COLD", 3:"MODERN", 4:"FUTURE"}
	var by_era: Dictionary = {0:[], 1:[], 2:[], 3:[], 4:[]}
	var all_totals: Array = []
	var t001_total: float = -1.0
	var t030_total: float = -1.0

	for m in masters:
		var er: Dictionary = MasterPowerEvaluator.evaluate(m)
		var total: float = float(er.get("total_score", 0.0))
		var mid := str(m.get("id", ""))
		var stats_d: Dictionary = m.get("stats", {})
		var era: int = int(m.get("era", stats_d.get("era", 0)))
		var plats: Array = m.get("equipment", {}).get("platforms", [])
		all_totals.append(total)
		by_era[era].append(total)
		if mid == "enemy_master_001":
			t001_total = total
		elif mid == "enemy_master_030":
			t030_total = total
		print("  [%-7s] %-18s plats=%d  total=%10.1f  → %d★ %s" % [
			era_names.get(era, "?"), mid, plats.size(),
			total, int(er.get("stars", 0)), str(er.get("star_name", "")),
		])

	print("\n=== 按时代分布 ===")
	for era in [0, 1, 2, 3, 4]:
		var arr: Array = by_era[era]
		if arr.is_empty():
			continue
		var mn: float = arr.min()
		var mx: float = arr.max()
		var s: float = 0.0
		for v in arr:
			s += float(v)
		var avg: float = s / float(arr.size())
		print("  %-7s n=%d  min=%10.1f  max=%10.1f  avg=%10.1f" % [
			era_names[era], arr.size(), mn, mx, avg])

	var sorted_totals: Array = all_totals.duplicate()
	sorted_totals.sort()
	var n: int = sorted_totals.size()
	print("\n=== 全表分位数 ===")
	print("  min=%.1f  p25=%.1f  median=%.1f  p75=%.1f  max=%.1f" % [
		float(sorted_totals[0]),
		float(sorted_totals[maxi(0, n / 4)]),
		float(sorted_totals[n / 2]),
		float(sorted_totals[mini(n - 1, 3 * n / 4)]),
		float(sorted_totals[n - 1]),
	])

	# 基本健全性断言（确保公式真的在算，不是全 0）
	assert_int(masters.size()).is_greater(0)
	var max_total: float = float(sorted_totals[n - 1])
	assert_float(max_total).is_greater(0.0)
	# 单调性：近未来强师(m030) 总战力应 > 一战师(m001)
	print("  单调性: m001=%.1f  m030=%.1f" % [t001_total, t030_total])
	assert_float(t001_total).is_greater(0.0)
	assert_float(t030_total).is_greater(t001_total)
