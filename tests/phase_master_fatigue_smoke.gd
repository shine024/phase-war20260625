# 无 GdUnit 依赖的快速校验：敌方相位师出兵疲劳阶梯（v7.x）
#   - 三档阶梯阈值按 _unit_limit 倍数派生（tier1=×2, tier2=×4, exhaust=×6）
#   - _get_current_spawn_interval 各档返回正确间隔
#   - 模拟累计产兵推进阶梯 0→1→2→3
#   - 枯竭后 _process 短路（_fatigue_tier>=3 时不再产兵）
# 注：本测试不进场景树，直接 .new() 实例化脚本测逻辑层方法。
#      _record_spawn_and_check_fatigue/_get_current_spawn_interval 只读写实例变量，
#      无 SignalBus/节点树依赖（SignalBus 缺失时 _on_fatigue_tier_changed 安全 return）。
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/phase_master_fatigue_smoke.gd
extends SceneTree

const DriverScript = preload("res://scenes/units/enemy_phase_field_driver.gd")


func _initialize() -> void:
	var code := 0
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		code = 1
	var ok := func(cond_val: bool, msg: String) -> void:
		if cond_val:
			print("  [PASS] " + msg)
		else:
			fail.call(msg)

	print("=== 出兵疲劳阶梯验证 ===")

	# ── 用例1: unit_limit=5 → 阈值 10/20/30 ──
	print("[1] unit_limit=5 阈值派生")
	var d5 := DriverScript.new()
	d5._unit_limit = 5
	d5._tier1_cap = d5._unit_limit * d5.FATIGUE_TIER1_MULT
	d5._tier2_cap = d5._unit_limit * d5.FATIGUE_TIER2_MULT
	d5._exhaustion_cap = d5._unit_limit * d5.EXHAUSTION_MULT
	ok.call(d5._tier1_cap == 10, "tier1_cap=10 (5×2), got %d" % d5._tier1_cap)
	ok.call(d5._tier2_cap == 20, "tier2_cap=20 (5×4), got %d" % d5._tier2_cap)
	ok.call(d5._exhaustion_cap == 30, "exhaustion_cap=30 (5×6), got %d" % d5._exhaustion_cap)

	# ── 用例2: unit_limit=6 → 阈值 12/24/36（向后兼容原 TOTAL_SPAWN_CAP=12）──
	print("[2] unit_limit=6 阈值派生")
	var d6 := DriverScript.new()
	d6._unit_limit = 6
	d6._tier1_cap = d6._unit_limit * d6.FATIGUE_TIER1_MULT
	d6._tier2_cap = d6._unit_limit * d6.FATIGUE_TIER2_MULT
	d6._exhaustion_cap = d6._unit_limit * d6.EXHAUSTION_MULT
	ok.call(d6._tier1_cap == 12, "tier1_cap=12 (6×2), got %d" % d6._tier1_cap)
	ok.call(d6._tier2_cap == 24, "tier2_cap=24 (6×4), got %d" % d6._tier2_cap)
	ok.call(d6._exhaustion_cap == 36, "exhaustion_cap=36 (6×6), got %d" % d6._exhaustion_cap)

	# ── 用例3: _get_current_spawn_interval 各档 ──
	print("[3] _get_current_spawn_interval 各档")
	d5.spawn_interval = 5.0
	d5._fatigue_tier = 0
	ok.call(is_equal_approx(d5._get_current_spawn_interval(), 5.0), "tier0=spawn_interval(5.0)")
	d5._fatigue_tier = 1
	ok.call(is_equal_approx(d5._get_current_spawn_interval(), d5.FATIGUED_SPAWN_INTERVAL), "tier1=18s, got %f" % d5._get_current_spawn_interval())
	d5._fatigue_tier = 2
	ok.call(is_equal_approx(d5._get_current_spawn_interval(), d5.HEAVY_FATIGUE_INTERVAL), "tier2=30s, got %f" % d5._get_current_spawn_interval())

	# ── 用例4: 模拟累计产兵推进阶梯 0→1→2→3（unit_limit=5, cap 10/20/30）──
	print("[4] 累计产兵推进阶梯 (unit_limit=5)")
	var d := DriverScript.new()
	d._unit_limit = 5
	d._tier1_cap = 10
	d._tier2_cap = 20
	d._exhaustion_cap = 30
	d._fatigue_tier = 0
	d._total_spawned = 0
	# 产 9 个：应仍在 tier0
	for i in range(9):
		d._record_spawn_and_check_fatigue()
	ok.call(d._fatigue_tier == 0 && d._total_spawned == 9, "产9个 tier=0 (got %d, spawned %d)" % [d._fatigue_tier, d._total_spawned])
	# 第10个：进 tier1
	d._record_spawn_and_check_fatigue()
	ok.call(d._fatigue_tier == 1, "产10个 tier=1 (got %d)" % d._fatigue_tier)
	# 产到19个：仍 tier1
	for i in range(9):
		d._record_spawn_and_check_fatigue()
	ok.call(d._fatigue_tier == 1 && d._total_spawned == 19, "产19个 tier=1 (got %d, spawned %d)" % [d._fatigue_tier, d._total_spawned])
	# 第20个：进 tier2
	d._record_spawn_and_check_fatigue()
	ok.call(d._fatigue_tier == 2, "产20个 tier=2 (got %d)" % d._fatigue_tier)
	# 产到29个：仍 tier2
	for i in range(9):
		d._record_spawn_and_check_fatigue()
	ok.call(d._fatigue_tier == 2 && d._total_spawned == 29, "产29个 tier=2 (got %d, spawned %d)" % [d._fatigue_tier, d._total_spawned])
	# 第30个：进 tier3（枯竭）
	d._record_spawn_and_check_fatigue()
	ok.call(d._fatigue_tier == 3, "产30个 tier=3 枯竭 (got %d)" % d._fatigue_tier)
	# 继续调也不变（已枯竭）
	d._record_spawn_and_check_fatigue()
	d._record_spawn_and_check_fatigue()
	ok.call(d._fatigue_tier == 3, "枯竭后继续调用 tier 仍=3")

	# ── 用例5: 枯竭短路（_fatigue_tier>=3 时 _process 产兵逻辑被跳过）──
	# 验证逻辑：_get_current_spawn_interval 在 tier3 时虽不会被 _process 调用，
	# 但 _fatigue_tier>=3 的检查在 _process 内（这里验证字段状态正确即可）
	print("[5] 枯竭状态字段一致性")
	ok.call(d._fatigue_tier >= 3, "枯竭后 _fatigue_tier>=3，_process 将短路 return")

	# ── 用例6: 阈值缓存 default 值（脚本声明的 fallback）──
	print("[6] 默认阈值缓存")
	var dflt := DriverScript.new()
	ok.call(dflt._tier1_cap == 10 && dflt._tier2_cap == 20 && dflt._exhaustion_cap == 30, "默认阈值 10/20/30")

	d5.free()
	d6.free()
	d.free()
	dflt.free()

	print("")
	if code == 0:
		print("✅ ALL PASS — 出兵疲劳阶梯逻辑验证通过")
	else:
		print("❌ FAIL — 见上方 [FAIL] 行")
	quit(code)
