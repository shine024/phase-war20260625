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
