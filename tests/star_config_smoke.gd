# 无 GdUnit 依赖的快速校验：蓝图 v3 经济 + UnitStatsTable 时代缩放（BattleCardV3）
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/star_config_smoke.gd
extends SceneTree

const StarConfig = preload("res://data/blueprint_star_config.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const GC = preload("res://resources/game_constants.gd")


func _initialize() -> void:
	var code := 0
	var common_total: int = 0
	for star in range(1, StarConfig.MAX_STAR_LEVEL):
		common_total += StarConfig.get_research_cost_for_next_star(star, "common")
	if common_total != 3310:
		push_error("common star research total expected 3310 got %d" % common_total)
		code = 1
	var mythic_total: int = 0
	for star in range(1, StarConfig.MAX_STAR_LEVEL):
		mythic_total += StarConfig.get_research_cost_for_next_star(star, "mythic")
	if mythic_total != 26480:
		push_error("mythic star research total expected 26480 got %d" % mythic_total)
		code = 1
	if StarConfig.get_mod_cost("common", 0) != 200 or StarConfig.get_mod_cost("rare", 2) != 800:
		push_error("mod flat costs mismatch")
		code = 1
	if int(StarConfig.get_mod_permit_rule(2).get("general", 0)) != 2:
		push_error("third mod general permits expected 2")
		code = 1
	if StarConfig.get_max_mod_times("common") != 3:
		push_error("common max mod times expected 3")
		code = 1
	# 时代：平台 HP ×(1+0.15×era)，步枪伤害 ×(1+0.25×era)（era=1 时守卫 100→115，步枪 8→10）
	var st_e1: UnitStats = UnitStatsTable.build_multi_stats(GC.PlatformType.GUARD, [GC.WeaponType.RIFLE], 1)
	if not is_equal_approx(st_e1.max_hp, 115.0):
		push_error("era1 guard hp expected 115 got %s" % str(st_e1.max_hp))
		code = 1
	if not is_equal_approx(st_e1.attack_damage, 15.0):
		push_error("era1 rifle damage expected 15 got %s" % str(st_e1.attack_damage))
		code = 1
	var st_e0: UnitStats = UnitStatsTable.build_multi_stats(GC.PlatformType.GUARD, [GC.WeaponType.RIFLE], 0)
	if not is_equal_approx(st_e0.max_hp, 100.0):
		push_error("era0 guard hp expected 100 got %s" % str(st_e0.max_hp))
		code = 1
	if code == 0:
		print("star_config_smoke: OK")
	quit(code)
