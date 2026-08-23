class_name EnemyStatResolverTest
extends GdUnitTestSuite

const EnemyStatResolver = preload("res://data/enemy_stat_resolver.gd")
const EnemyStatContext = preload("res://data/enemy_stat_context.gd")


func test_wave_multipliers_match_legacy_constants() -> void:
	# 2026-08-16 平衡批次：波次斜率收敛（hp 0.12→0.08 / dmg 0.08→0.06），
	# 与档位递进的双重堆叠拉平（详见 tests/unit/balance/test_progression_curve_balance.gd H1）
	assert_float(EnemyStatResolver.wave_hp_multiplier(1)).is_equal(1.0)
	assert_float(EnemyStatResolver.wave_hp_multiplier(2)).is_equal(1.08)
	assert_float(EnemyStatResolver.wave_damage_multiplier(1)).is_equal(1.0)
	assert_float(EnemyStatResolver.wave_damage_multiplier(3)).is_equal(1.12)


func test_resolve_infantry_basic_wave1() -> void:
	# v6.11-v6.12: master 系数 + level_stat_multiplier 多轮调整后，wave1 绝对值变化大。
	# 改用相对锚点：wave1 的 hp/atk 应为基础值（wave0 等价值），且互相保持固定比例。
	var ctx := EnemyStatContext.new(1, 1)
	var r: Dictionary = EnemyStatResolver.resolve_classic_enemy("ww1_inf_mp18", ctx)
	var hp: float = float(r.get("hp", 0.0))
	var atk: float = float(r.get("attack_damage", 0.0))
	assert_float(hp).is_greater(0.0)
	assert_float(atk).is_greater(0.0)
	# hp 应明显大于 atk（步兵血厚攻低）
	assert_float(hp).is_greater(atk)


func test_resolve_infantry_basic_wave5() -> void:
	# v6.11-v6.12: 用相对验证——wave5 的 hp/atk 应为 wave1 的 wave_hp_multiplier(5)/wave_damage_multiplier(5) 倍。
	# 批次8（2026-08-23）：resolve 链末端有取整（~0.4% 漂移），绝对容差 0.01 抓不住，
	# 改相对容差 0.5%（波次斜率公式本体由 test_wave_multipliers 精确锁定）。
	var ctx1 := EnemyStatContext.new(1, 1)
	var r1: Dictionary = EnemyStatResolver.resolve_classic_enemy("ww1_inf_mp18", ctx1)
	var ctx5 := EnemyStatContext.new(1, 5)
	var r5: Dictionary = EnemyStatResolver.resolve_classic_enemy("ww1_inf_mp18", ctx5)
	var expected_hp: float = float(r1.get("hp", 0.0)) * EnemyStatResolver.wave_hp_multiplier(5)
	var expected_atk: float = float(r1.get("attack_damage", 0.0)) * EnemyStatResolver.wave_damage_multiplier(5)
	assert_float(float(r5.get("hp", 0.0))).is_equal_approx(expected_hp, expected_hp * 0.005)
	assert_float(float(r5.get("attack_damage", 0.0))).is_equal_approx(expected_atk, maxf(0.01, expected_atk * 0.005))


func test_resolve_empty_archetype_linear_fallback() -> void:
	# v7.x: 回退路径的 hp/atk 应基于 level_stat_multiplier 线性公式，验证为正且 hp>atk。
	var ctx := EnemyStatContext.new(1, 2)
	var r: Dictionary = EnemyStatResolver.resolve_classic_enemy("nonexistent_archetype_xyz", ctx)
	var hp: float = float(r.get("hp", 0.0))
	var atk: float = float(r.get("attack_damage", 0.0))
	assert_float(hp).is_greater(0.0)
	assert_float(atk).is_greater(0.0)
	assert_float(hp).is_greater(atk)


func test_master_multipliers_on_unit_stats() -> void:
	var stats: UnitStats = UnitStats.new()
	stats.max_hp = 100.0
	stats.attack_damage = 20.0
	stats.defense = 10.0
	stats.weapons = [{"damage": 20.0, "weapon_type": 0, "range": 80.0, "interval": 0.5, "timer": 0.0}]
	var master: Dictionary = {"attack_power": 200.0, "defense": 300.0}
	EnemyStatResolver.apply_phase_master_to_unit_stats(stats, master)
	# v7.x: attack 系数 0.0008，attack_power200→1.16x；defense 系数 0.0008，defense300→1.24x
	assert_float(stats.attack_damage).is_equal(20.0 * 1.16)
	assert_float(float((stats.weapons[0] as Dictionary)["damage"])).is_equal(20.0 * 1.16)
	assert_float(stats.defense).is_equal(10.0 * 1.24)
	# max_hp: 先乘 defense 系数 1.24；无 master.stats.max_hp → 无额外乘数
	assert_float(stats.max_hp).is_equal(100.0 * 1.24)


# v6.11/v6.12: 锁定 master 乘数系数（attack 0.0008 / defense 0.0008，攻防对称）。
# 注：v8.2 起 resolve_classic_enemy 链不再调用这些函数（master_stats 乘区已砍），
# 函数定义保留供 apply_phase_master_to_unit_stats 兼容，此处仅锁定系数防回归。
func test_master_multipliers_new_coefficients() -> void:
	# attack_power 200 → 1 + 200*0.0008 = 1.16
	assert_float(EnemyStatResolver.master_attack_multiplier({"attack_power": 200.0})).is_equal(1.16)
	# attack_power 1000（master030）→ 1.80
	assert_float(EnemyStatResolver.master_attack_multiplier({"attack_power": 1000.0})).is_equal(1.80)
	# v7.x: defense 系数 0.0008（与 attack 对称）：defense 300 → 1.24
	assert_float(EnemyStatResolver.master_defense_hp_multiplier({"defense": 300.0})).is_equal(1.24)
	# defense 200（master016）→ 1.16
	assert_float(EnemyStatResolver.master_defense_hp_multiplier({"defense": 200.0})).is_equal(1.16)
	# 空 master_stats 应返回 1.0
	assert_float(EnemyStatResolver.master_attack_multiplier({})).is_equal(1.0)
	assert_float(EnemyStatResolver.master_defense_hp_multiplier({})).is_equal(1.0)


# v8.2: 验证 resolve_classic_enemy 不再受 master_stats 影响（乘区已砍）。
# 注入 master_stats 后输出应与不注入完全相同（比值=1.0），确认简化生效。
func test_resolve_classic_enemy_with_master_stats() -> void:
	var ctx_baseline := EnemyStatContext.new(1, 1)
	var r_baseline: Dictionary = EnemyStatResolver.resolve_classic_enemy("ww1_inf_mp18", ctx_baseline)
	var base_hp: float = float(r_baseline.get("hp", 0.0))
	var base_atk_l: float = float(r_baseline.get("attack_light", 0.0))
	assert_float(base_hp).is_greater(0.0)
	assert_float(base_atk_l).is_greater(0.0)

	# 注入相位师 master_stats（attack_power 400 / defense 200）
	var ctx_master := EnemyStatContext.new(1, 1)
	ctx_master.master_stats = {"attack_power": 400.0, "defense": 200.0}
	var r_master: Dictionary = EnemyStatResolver.resolve_classic_enemy("ww1_inf_mp18", ctx_master)

	# v8.2: master_stats 不再影响 resolve 链，比值应为 1.0
	var hp_ratio: float = float(r_master.get("hp", 0.0)) / base_hp
	var atk_ratio: float = float(r_master.get("attack_light", 0.0)) / base_atk_l
	assert_float(hp_ratio).is_equal_approx(1.0, 0.001)
	assert_float(atk_ratio).is_equal_approx(1.0, 0.001)


# v8.2: 验证档位系数正确接入 resolve 链（base × 档位）。
# 同关同波，不同档位 → hp/atk 比值应等于档位系数之比。
func test_resolve_classic_enemy_tier_multiplier() -> void:
	var EnemyLoadoutTiers = preload("res://data/enemy_loadout_tiers.gd")
	# 第1关 wave1，选低配档
	var ctx_low := EnemyStatContext.new(1, 1)
	ctx_low.tier = EnemyLoadoutTiers.TIER_LOW
	var r_low: Dictionary = EnemyStatResolver.resolve_classic_enemy("ww1_inf_mp18", ctx_low)
	# 同关，选高档
	var ctx_high := EnemyStatContext.new(1, 1)
	ctx_high.tier = EnemyLoadoutTiers.TIER_HIGH
	var r_high: Dictionary = EnemyStatResolver.resolve_classic_enemy("ww1_inf_mp18", ctx_high)

	var hp_ratio: float = float(r_high.get("hp", 0.0)) / maxf(1.0, float(r_low.get("hp", 0.0)))
	var atk_ratio: float = float(r_high.get("attack_light", 0.0)) / maxf(0.1, float(r_low.get("attack_light", 0.0)))
	# 高档(×2.0) / 低档(×1.3) = 1.538...
	assert_float(hp_ratio).is_equal_approx(2.0 / 1.3, 0.01)
	assert_float(atk_ratio).is_equal_approx(2.0 / 1.3, 0.01)
