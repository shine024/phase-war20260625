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
	# 时代缩放：GUARD(_PLATFORM_BASE hp=110) × era_hp_multiplier，RIFLE(_WEAPON_BASE dmg=14) × era_damage_multiplier
	# era_hp_multiplier(e) = 1.0 + e × 0.15  → era1: 110×1.15 = 126.5
	# era_damage_multiplier = [1.00, 1.20, 1.40, 1.65, 1.80]  → era1: 14×1.20 = 16.8
	var st_e1: UnitStats = UnitStatsTable.build_multi_stats(1, [1], 1)  # GUARD, RIFLE
	if not is_equal_approx(st_e1.max_hp, 126.5):
		push_error("era1 guard hp expected 126.5 got %s" % str(st_e1.max_hp))
		code = 1
	# 新的多维战斗系统：使用 attack_light 字段
	if not is_equal_approx(st_e1.attack_light, 16.8):
		push_error("era1 rifle damage expected 16.8 got %s" % str(st_e1.attack_light))
		code = 1
	var st_e0: UnitStats = UnitStatsTable.build_multi_stats(1, [1], 0)  # GUARD, RIFLE
	if not is_equal_approx(st_e0.max_hp, 110.0):
		push_error("era0 guard hp expected 110.0 got %s" % str(st_e0.max_hp))
		code = 1
	if code == 0:
		print("star_config_smoke: OK")
	quit(code)
