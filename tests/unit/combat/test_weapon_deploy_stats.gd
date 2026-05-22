class_name WeaponDeployStatsTest
extends GdUnitTestSuite

const GC = preload("res://resources/game_constants.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const BSS = preload("res://managers/battle/battle_spawn_system.gd")
const BM_SCRIPT = preload("res://managers/blueprint_manager.gd")
const BC = preload("res://data/battle_card_v3.gd")

var _bm: Node


func before_test() -> void:
	_bm = Node.new()
	_bm.set_script(BM_SCRIPT)
	add_child(_bm)


func after_test() -> void:
	remove_child(_bm)
	_bm.free()


func test_resolve_combined_uses_multi_weapon_types() -> void:
	var c := CardResource.new()
	c.card_type = GC.CardType.COMBINED
	c.multi_weapon_types = [GC.WeaponType.RIFLE, GC.WeaponType.MG]
	c.default_weapon_type = GC.WeaponType.SMG
	var wts: Array = BSS.resolve_deploy_weapon_types(c)
	assert_int(wts.size()).is_equal(2)
	assert_int(wts[0]).is_equal(GC.WeaponType.RIFLE)
	assert_int(wts[1]).is_equal(GC.WeaponType.MG)


func test_resolve_combined_empty_multi_falls_back_to_default() -> void:
	var c := CardResource.new()
	c.card_type = GC.CardType.COMBINED
	c.default_weapon_type = GC.WeaponType.MG
	var wts: Array = BSS.resolve_deploy_weapon_types(c)
	assert_int(wts.size()).is_equal(1)
	assert_int(wts[0]).is_equal(GC.WeaponType.MG)


func test_resolve_combined_totally_empty_uses_rifle() -> void:
	var c := CardResource.new()
	c.card_type = GC.CardType.COMBINED
	c.default_weapon_type = -1
	var wts: Array = BSS.resolve_deploy_weapon_types(c)
	assert_int(wts.size()).is_equal(1)
	assert_int(wts[0]).is_equal(GC.WeaponType.RIFLE)


func test_resolve_platform_ignores_multi_uses_default_weapon() -> void:
	var c := CardResource.new()
	c.card_type = GC.CardType.PLATFORM
	c.default_weapon_type = GC.WeaponType.SNIPER
	c.multi_weapon_types = [GC.WeaponType.MG]
	var wts: Array = BSS.resolve_deploy_weapon_types(c)
	assert_int(wts.size()).is_equal(1)
	assert_int(wts[0]).is_equal(GC.WeaponType.SNIPER)


func test_apply_growth_scales_all_weapon_slots() -> void:
	var c := CardResource.new()
	c.card_id = "weapon_stats_growth_test"
	c.card_type = GC.CardType.COMBINED
	c.platform_type = GC.PlatformType.GUARD
	c.multi_weapon_types = [GC.WeaponType.RIFLE, GC.WeaponType.MG]
	var wts: Array = BSS.resolve_deploy_weapon_types(c)
	var stats: UnitStats = UnitStatsTable.build_multi_stats(c.platform_type, wts, 0)
	var d0: float = float((stats.weapons[0] as Dictionary)["damage"])
	var d1: float = float((stats.weapons[1] as Dictionary)["damage"])
	var atk0: float = stats.attack_damage
	_bm.blueprint_stars["weapon_stats_growth_test"] = 3
	_bm.apply_growth_to_stats(stats, c, [])
	var expected_mul: float = BC.star_stat_multiplier(3)
	assert_float(stats.attack_damage).is_equal_approx(atk0 * expected_mul, 0.02)
	assert_float(float((stats.weapons[0] as Dictionary)["damage"])).is_equal_approx(d0 * expected_mul, 0.02)
	assert_float(float((stats.weapons[1] as Dictionary)["damage"])).is_equal_approx(d1 * expected_mul, 0.02)
