class_name EnemyStatResolverTest
extends GdUnitTestSuite

const EnemyStatResolver = preload("res://data/enemy_stat_resolver.gd")
const EnemyStatContext = preload("res://data/enemy_stat_context.gd")


func test_wave_multipliers_match_legacy_constants() -> void:
	assert_float(EnemyStatResolver.wave_hp_multiplier(1)).is_equal(1.0)
	assert_float(EnemyStatResolver.wave_hp_multiplier(2)).is_equal(1.12)
	assert_float(EnemyStatResolver.wave_damage_multiplier(1)).is_equal(1.0)
	assert_float(EnemyStatResolver.wave_damage_multiplier(3)).is_equal(1.16)


func test_resolve_infantry_basic_wave1() -> void:
	var ctx := EnemyStatContext.new(1, 1)
	var r: Dictionary = EnemyStatResolver.resolve_classic_enemy("enemy_ww1_infantry_basic", ctx)
	assert_float(float(r.get("hp", 0.0))).is_equal(40.0)
	assert_float(float(r.get("attack_damage", 0.0))).is_equal(8.0)


func test_resolve_infantry_basic_wave5() -> void:
	var ctx := EnemyStatContext.new(1, 5)
	var r: Dictionary = EnemyStatResolver.resolve_classic_enemy("enemy_ww1_infantry_basic", ctx)
	var expected_hp: float = 40.0 * EnemyStatResolver.wave_hp_multiplier(5)
	var expected_atk: float = 8.0 * EnemyStatResolver.wave_damage_multiplier(5)
	assert_float(float(r.get("hp", 0.0))).is_equal(expected_hp)
	assert_float(float(r.get("attack_damage", 0.0))).is_equal(expected_atk)


func test_resolve_empty_archetype_linear_fallback() -> void:
	var ctx := EnemyStatContext.new(1, 2)
	var r: Dictionary = EnemyStatResolver.resolve_classic_enemy("nonexistent_archetype_xyz", ctx)
	assert_float(float(r.get("hp", 0.0))).is_equal(60.0 + 2.0 * 15.0)
	assert_float(float(r.get("attack_damage", 0.0))).is_equal(10.0 + 2.0 * 2.0)


func test_master_multipliers_on_unit_stats() -> void:
	var stats: UnitStats = UnitStats.new()
	stats.max_hp = 100.0
	stats.attack_damage = 20.0
	stats.weapons = [{"damage": 20.0, "weapon_type": 0, "range": 80.0, "interval": 0.5, "timer": 0.0}]
	var master: Dictionary = {"attack_power": 200.0, "defense": 300.0}
	EnemyStatResolver.apply_phase_master_to_unit_stats(stats, master)
	assert_float(stats.attack_damage).is_equal(20.0 * 1.1)
	assert_float(float((stats.weapons[0] as Dictionary)["damage"])).is_equal(20.0 * 1.1)
	assert_float(stats.max_hp).is_equal(100.0 * (1.0 + 300.0 * 0.0003))


# v6.11: 锁定 master 乘数新系数（0.0005 / 0.0003），防止回归到 v6.2 的 0.002/0.0001。
# 旧系数 0.002 使 master030(attack_power1000)→3.0x 过猛，且与叠加的排名加成冲突。
func test_master_multipliers_new_coefficients() -> void:
	# attack_power 200 → 1 + 200*0.0005 = 1.10
	assert_float(EnemyStatResolver.master_attack_multiplier({"attack_power": 200.0})).is_equal(1.10)
	# attack_power 1000（master030）→ 1.50（v6.2 的 0.002 会是 3.0，过猛）
	assert_float(EnemyStatResolver.master_attack_multiplier({"attack_power": 1000.0})).is_equal(1.50)
	# defense 300 → 1 + 300*0.0003 = 1.09
	assert_float(EnemyStatResolver.master_defense_hp_multiplier({"defense": 300.0})).is_equal(1.09)
	# defense 200（master016）→ 1.06（v6.2 的 0.0001 仅 1.02，防御属性几乎无效）
	assert_float(EnemyStatResolver.master_defense_hp_multiplier({"defense": 200.0})).is_equal(1.06)
	# 空 master_stats 应返回 1.0（普通波次行为）
	assert_float(EnemyStatResolver.master_attack_multiplier({})).is_equal(1.0)
	assert_float(EnemyStatResolver.master_defense_hp_multiplier({})).is_equal(1.0)


# v6.11: 验证 resolve_classic_enemy 在 master_stats 非空时，m_atk/m_hp 真正生效。
# 这是「相位师影响普通敌兵」的核心修复点：修复前 make_default_context 从不注入 master_stats，
# 导致经典敌兵/蜂群的 m_atk/m_hp 恒为 1.0。此处用裸 EnemyStatContext 直接验证乘区接入。
# （make_default_context 的注入逻辑依赖 BattleManager 运行时环境，由集成测试覆盖。）
func test_resolve_classic_enemy_with_master_stats() -> void:
	# 第1关、第1波，enemy_ww1_infantry_basic
	# 注：archetype 基础值可能被运行时 manifest 合并改写，故用「无master基准 vs 有master」的比值验证，
	# 比值应精确等于 m_atk/m_hp，与绝对值无关。
	var ctx_baseline := EnemyStatContext.new(1, 1)
	var r_baseline: Dictionary = EnemyStatResolver.resolve_classic_enemy("enemy_ww1_infantry_basic", ctx_baseline)
	var base_hp: float = float(r_baseline.get("hp", 0.0))
	var base_atk_l: float = float(r_baseline.get("attack_light", 0.0))
	assert_float(base_hp).is_greater(0.0)
	assert_float(base_atk_l).is_greater(0.0)

	# 注入相位师 master_stats（attack_power 400 / defense 200，对应 master016 量级）
	var ctx_master := EnemyStatContext.new(1, 1)
	ctx_master.master_stats = {"attack_power": 400.0, "defense": 200.0}
	var r_master: Dictionary = EnemyStatResolver.resolve_classic_enemy("enemy_ww1_infantry_basic", ctx_master)

	# m_atk = 1 + 400*0.0005 = 1.20；m_hp = 1 + 200*0.0003 = 1.06
	# 用比值验证：master战后 / 基准 应精确等于乘数
	var hp_ratio: float = float(r_master.get("hp", 0.0)) / base_hp
	var atk_ratio: float = float(r_master.get("attack_light", 0.0)) / base_atk_l
	assert_float(hp_ratio).is_equal(1.06)
	assert_float(atk_ratio).is_equal(1.20)
