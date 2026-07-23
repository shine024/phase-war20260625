## v8.2 敌人公式简化 smoke test
## 验证经典敌人新公式：hp = base × 档位 × 波数 [× 势力] [× 难度]，def = base × 档位
## 验证相位师产兵档位固定高档（TIER_HIGH）
## 独立运行：D:\godot\Godot_v4.5.1.exe --headless --rendering-driver opengl3 --path . --script tests/v8_formula_smoke.gd
extends SceneTree
const EnemyLoadoutTiers = preload("res://data/enemy_loadout_tiers.gd")

var _pass_count: int = 0
var _fail_count: int = 0


func _init() -> void:
	# ---- 测试1：档位系数数值正确（用户指定 1.30/1.75/2.00）----
	var low_bonus: Dictionary = EnemyLoadoutTiers.get_bonus_for_tier(EnemyLoadoutTiers.TIER_LOW)
	var mid_bonus: Dictionary = EnemyLoadoutTiers.get_bonus_for_tier(EnemyLoadoutTiers.TIER_MID)
	var high_bonus: Dictionary = EnemyLoadoutTiers.get_bonus_for_tier(EnemyLoadoutTiers.TIER_HIGH)
	var low_mul: float = 1.0 + float(low_bonus.get("atk_pct", 0.0))
	var mid_mul: float = 1.0 + float(mid_bonus.get("atk_pct", 0.0))
	var high_mul: float = 1.0 + float(high_bonus.get("atk_pct", 0.0))
	_assert_approx(low_mul, 1.30, 0.001, "低配系数=1.30")
	_assert_approx(mid_mul, 1.75, 0.001, "中配系数=1.75")
	_assert_approx(high_mul, 2.00, 0.001, "高配系数=2.00")

	# ---- 测试2：hp/atk/def 同系数（统一档位）----
	var hp_eq_atk: bool = is_equal_approx(float(low_bonus.get("hp_pct")), float(low_bonus.get("atk_pct")))
	var atk_eq_def: bool = is_equal_approx(float(low_bonus.get("atk_pct")), float(low_bonus.get("def_pct")))
	_assert_true(hp_eq_atk and atk_eq_def, "低配 hp=atk=def 系数（统一档位）")

	# ---- 测试3：高档 enhance_level = 10（满强化）----
	_assert_int(int(high_bonus.get("enhance_level", 0)), 10, "高档 enhance=10（满强化）")

	# ---- 测试4：高档 mod_count=9（满改造）----
	_assert_int(int(high_bonus.get("mod_count", 0)), 9, "高档 mod_count=9（满改造）")

	# ---- 测试5：相位师产兵档位恒高档（无论 era_progress）----
	_assert_int(EnemyLoadoutTiers.get_phase_master_tier(0.1), EnemyLoadoutTiers.TIER_HIGH, "相位师早期=高档")
	_assert_int(EnemyLoadoutTiers.get_phase_master_tier(0.5), EnemyLoadoutTiers.TIER_HIGH, "相位师中期=高档")
	_assert_int(EnemyLoadoutTiers.get_phase_master_tier(0.9), EnemyLoadoutTiers.TIER_HIGH, "相位师后期=高档")

	# ---- 测试6：普通关选档规则（时代前1/3低/中段中/后1/3高）----
	_assert_int(EnemyLoadoutTiers.get_tier_for_level_progress(0.1, false), EnemyLoadoutTiers.TIER_LOW, "普通关前1/3=低配")
	_assert_int(EnemyLoadoutTiers.get_tier_for_level_progress(0.5, false), EnemyLoadoutTiers.TIER_MID, "普通关中段=中配")
	_assert_int(EnemyLoadoutTiers.get_tier_for_level_progress(0.9, false), EnemyLoadoutTiers.TIER_HIGH, "普通关后1/3=高配")

	# ---- 测试7：档位系数 × 波数 公式数值验证（手动算）----
	# base_hp=100，wave1（波数=1.0），无势力
	var w1_hp: float = 1.0 + 0.12 * float(1 - 1)  # wave1 = 1.0
	_assert_approx(100.0 * low_mul * w1_hp, 130.0, 0.01, "低配 wave1: 100×1.30×1.0=130")
	_assert_approx(100.0 * high_mul * w1_hp, 200.0, 0.01, "高配 wave1: 100×2.00×1.0=200")
	# wave5：波数 = 1 + 0.12×4 = 1.48
	var w5_hp: float = 1.0 + 0.12 * 4.0
	_assert_approx(100.0 * high_mul * w5_hp, 296.0, 0.01, "高配 wave5: 100×2.00×1.48=296")

	# ---- 测试8：档位系数比值（高档/低档 = 2.0/1.3 = 1.538）----
	_assert_approx(high_mul / low_mul, 2.0 / 1.3, 0.001, "高档/低档系数比=1.538")

	# ---- 测试9：跨时代档位不变（档位只看时代内进度，不跨时代）----
	# 第1关（一战首关）和第21关（二战首关）都应选低配（时代内前1/3）
	_assert_int(_tier_for_level(1), EnemyLoadoutTiers.TIER_LOW, "第1关（一战首）=低配")
	_assert_int(_tier_for_level(21), EnemyLoadoutTiers.TIER_LOW, "第21关（二战首）=低配")
	# 第81关（近未来首）也应低配
	_assert_int(_tier_for_level(81), EnemyLoadoutTiers.TIER_LOW, "第81关（近未来首）=低配")
	# 第100关（近未来末，时代内 progress=0.95）应高配
	_assert_int(_tier_for_level(100), EnemyLoadoutTiers.TIER_HIGH, "第100关（近未来末）=高配")

	print("\n========== v8.2 公式 smoke test ==========")
	print("PASS: %d  FAIL: %d" % [_pass_count, _fail_count])
	if _fail_count > 0:
		print("❌ 有失败项，请检查上方输出")
	else:
		print("✅ 全部通过")
	quit(0 if _fail_count == 0 else 1)


## 按关卡号算时代内进度选档（复刻 resolver 的 ctx.tier 逻辑）
func _tier_for_level(level: int) -> int:
	var era_local_level: int = ((level - 1) % 20) + 1
	var era_progress: float = float(era_local_level - 1) / 19.0
	return EnemyLoadoutTiers.get_tier_for_level_progress(era_progress, false)


func _assert_approx(actual: float, expected: float, eps: float, label: String) -> void:
	if absf(actual - expected) <= eps:
		_pass_count += 1
		print("  ✅ %s (got %.4f)" % [label, actual])
	else:
		_fail_count += 1
		print("  ❌ %s: expected %.4f, got %.4f" % [label, expected, actual])


func _assert_int(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		_pass_count += 1
		print("  ✅ %s (got %d)" % [label, actual])
	else:
		_fail_count += 1
		print("  ❌ %s: expected %d, got %d" % [label, expected, actual])


func _assert_true(actual: bool, label: String) -> void:
	if actual:
		_pass_count += 1
		print("  ✅ %s" % label)
	else:
		_fail_count += 1
		print("  ❌ %s: expected true" % label)
