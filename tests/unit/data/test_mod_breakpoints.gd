class_name ModBreakpointsTest
extends GdUnitTestSuite
## v6.16 攻速断点阶梯回归锁：档位解析 + 武器槽消费（敌我同构单一消费点）+ 总开关。
## 真身：data/mod_breakpoints.gd + unit_stats_table._sync_mod_speed_ratio_to_weapon_slots。

const ModBreakpoints = preload("res://data/mod_breakpoints.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const GameCfg = preload("res://resources/game_config.gd")


func test_tier_thresholds() -> void:
	# 阈值边界：0.20/0.40/0.70/1.10（含=跨档，差 0.001=未跨）
	assert_int(int(ModBreakpoints.resolve(0.0)["tier"])).is_equal(0)
	assert_int(int(ModBreakpoints.resolve(0.199)["tier"])).is_equal(0)
	assert_int(int(ModBreakpoints.resolve(0.20)["tier"])).is_equal(1)
	assert_int(int(ModBreakpoints.resolve(0.399)["tier"])).is_equal(1)
	assert_int(int(ModBreakpoints.resolve(0.40)["tier"])).is_equal(2)
	assert_int(int(ModBreakpoints.resolve(0.70)["tier"])).is_equal(3)
	assert_int(int(ModBreakpoints.resolve(1.10)["tier"])).is_equal(4)
	assert_int(int(ModBreakpoints.resolve(2.0)["tier"])).is_equal(4)
	# 档位乘区单调递增（跨档跳变的数值基础）
	var prev_mult: float = 1.0
	for g in [0.20, 0.40, 0.70, 1.10]:
		var m: float = float(ModBreakpoints.resolve(g)["speed_mult"])
		assert_bool(m > prev_mult).is_true()
		prev_mult = m
	# 满档后 next_threshold = -1
	assert_float(float(ModBreakpoints.resolve(1.5)["next_threshold"])).is_equal(-1.0)


func test_describe_for_ui() -> void:
	assert_str(ModBreakpoints.describe_for_ui(0.45)).contains("II 连射")
	assert_str(ModBreakpoints.describe_for_ui(0.10)).contains("未达断点")
	assert_str(ModBreakpoints.describe_for_ui(0.10)).contains("还差")


func _make_weapon(speed: float, windup: float) -> WeaponResource:
	var w := WeaponResource.new()
	w.enabled = true
	w.attack_speed = speed
	w.windup = windup
	w.damage = 100.0
	return w


func test_weapon_slot_consumption() -> void:
	# 构造 stats/槽位，直接调消费点：factor=1.5（gain 0.5 → T2：×1.12、windup×0.5）
	var stats := UnitStats.new()
	stats.attack_light_speed = 1.5
	stats.attack_armor_speed = 1.0
	stats.attack_air_speed = 1.0
	var w := _make_weapon(1.0, 0.2)
	UnitStatsTable._sync_mod_speed_ratio_to_weapon_slots(
		stats, [w, null, null], [1.0, 1.0, 1.0])
	assert_float(w.attack_speed).is_equal_approx(1.5 * 1.12, 0.001)
	assert_float(w.windup).is_equal_approx(0.1, 0.001)
	# stats 侧同步乘档位乘区（HUD/派生槽同口径）
	assert_float(stats.attack_light_speed).is_equal_approx(1.5 * 1.12, 0.001)


func test_no_mods_no_bonus() -> void:
	# 无改造（factor=1）→ 档位 0，速度/蓄力不动
	var stats := UnitStats.new()
	stats.attack_light_speed = 1.0
	var w := _make_weapon(1.0, 0.2)
	UnitStatsTable._sync_mod_speed_ratio_to_weapon_slots(
		stats, [w, null, null], [1.0, 1.0, 1.0])
	assert_float(w.attack_speed).is_equal(1.0)
	assert_float(w.windup).is_equal(0.2)


func test_speed_cap_still_binds() -> void:
	# 3.0 速度帽不被断点绕过（极端堆叠 clamp 生效）
	var stats := UnitStats.new()
	stats.attack_light_speed = 2.6  # gain 1.6 → T4 ×1.35
	var w := _make_weapon(2.5, 0.2)
	UnitStatsTable._sync_mod_speed_ratio_to_weapon_slots(
		stats, [w, null, null], [1.0, 1.0, 1.0])
	assert_float(w.attack_speed).is_equal(3.0)


func test_switch_restores_continuous_multiplication() -> void:
	# 总开关 false = 连续乘区旧口径（无档位加成、无蓄力削减）
	var cfg := GameCfg.get_default()
	var saved: bool = cfg.mod_breakpoints_enabled
	cfg.mod_breakpoints_enabled = false
	var stats := UnitStats.new()
	stats.attack_light_speed = 1.5
	var w := _make_weapon(1.0, 0.2)
	UnitStatsTable._sync_mod_speed_ratio_to_weapon_slots(
		stats, [w, null, null], [1.0, 1.0, 1.0])
	assert_float(w.attack_speed).is_equal_approx(1.5, 0.001)
	assert_float(w.windup).is_equal(0.2)
	cfg.mod_breakpoints_enabled = saved
