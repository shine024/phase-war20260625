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
	# v7.3: 许可证系统已移除（get_mod_permit_rule 已删除），跳过该断言
	if StarConfig.get_max_mod_times("common") != 3:
		push_error("common max mod times expected 3")
		code = 1
	# v6.8: 我方单位时代缩放已移除——GUARD 平台 hp=110、RIFLE damage=14，任何时代都不再放大。
	# era1 与 era0 数值应完全相同（验证缩放确实已移除，而非旧的 110×1.15=126.5 / 14×1.20=16.8）。
	var st_e1: UnitStats = UnitStatsTable.build_multi_stats(1, [1], 1)  # GUARD, RIFLE, era1
	if not is_equal_approx(st_e1.max_hp, 110.0):
		push_error("era1 guard hp expected 110.0 (时代缩放已移除) got %s" % str(st_e1.max_hp))
		code = 1
	if not is_equal_approx(st_e1.attack_light, 14.0):
		push_error("era1 rifle damage expected 14.0 (时代缩放已移除) got %s" % str(st_e1.attack_light))
		code = 1
	var st_e0: UnitStats = UnitStatsTable.build_multi_stats(1, [1], 0)  # GUARD, RIFLE, era0
	if not is_equal_approx(st_e0.max_hp, 110.0):
		push_error("era0 guard hp expected 110.0 got %s" % str(st_e0.max_hp))
		code = 1
	if code == 0:
		print("star_config_smoke: OK")
	quit(code)
