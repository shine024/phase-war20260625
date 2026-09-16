extends SceneTree
## v35 遗留清理轮 —— --script 兼容验证（autoload 裸引用脚本在 --script 模式编译
## 必失败，是项目已知限制；全项目编译由 tests/_tmp_v35_probe.tscn（真实启动流程）
## 与 gdparse 承担，本脚本只验纯脚本行为 + 场景文本结构。）

var _fails: int = 0

func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK  ", msg)
	else:
		_fails += 1
		printerr("  FAIL ", msg)

func _init() -> void:
	print("=== 1. 纯脚本加载（编译期） ===")
	for p: String in [
		"res://resources/game_constants.gd",
		"res://data/weapon_visual_profiles.gd",
		"res://data/modification_modules/universal_mods.gd",
	]:
		_ok(load(p) != null, "load " + p)

	print("=== 2. main.tscn 结构（文本断言） ===")
	var f := FileAccess.open("res://scenes/main.tscn", FileAccess.READ)
	var txt := f.get_as_text() if f != null else ""
	_ok(txt.contains("load_steps=36"), "load_steps=36（38-2 同步递减）")
	_ok(txt.contains("BattleTopStatusBar") and txt.contains("BattleInfoDisplay"), "墓碑+统计引擎保留")
	_ok(not txt.contains("[node name=\"PlayerSpawnHUD\"") and not txt.contains("[node name=\"EnemySpawnHUD\""), "两死节点已删")
	_ok(not txt.contains("player_spawn_hud.tscn") and not txt.contains("enemy_spawn_hud.tscn"), "两 HUD ext_resource 已摘")

	print("=== 3. 行为断言（Vector2 分量 float32，用 is_equal_approx） ===")
	var WPV: GDScript = load("res://scripts/weapon_projectile_vfx.gd")
	if WPV != null:
		_ok(WPV.proj_quad_size(1).is_equal_approx(Vector2(WPV.proj_scale(1) * 1122.0, WPV.proj_scale(1) * 184.0)), "proj_quad_size(1) 不变")
		_ok(WPV.proj_quad_size(9).is_equal_approx(Vector2(WPV.proj_scale(9) * 1127.0, WPV.proj_scale(9) * 251.0)), "proj_quad_size(9) 不变")
		_ok(WPV.proj_quad_size(2).is_equal_approx(Vector2(WPV.proj_scale(2) * 1127.0, WPV.proj_scale(2) * 251.0)), "proj_quad_size(2) 不变")
		_ok(WPV.proj_quad_size(7).is_equal_approx(Vector2(WPV.proj_scale(7) * 1202.0, WPV.proj_scale(7) * 203.0)), "proj_quad_size(7) 不变")
		_ok(WPV.proj_quad_size(3).is_equal_approx(Vector2(WPV.proj_scale(3) * 1202.0, WPV.proj_scale(3) * 203.0)), "proj_quad_size(3) 不变")
		_ok(WPV.proj_quad_size(0).is_equal_approx(Vector2(WPV.proj_scale(0) * 512.0, WPV.proj_scale(0) * 128.0)), "proj_quad_size(0) 死档回默认")
	var GCc: GDScript = load("res://resources/game_constants.gd")
	_ok(GCc.get("NEW_GAME_STARTER_LAW_SHARD_AMOUNT") == null and GCc.get("NEW_GAME_STARTER_ACTIVE_LAW_IDS") == null, "法则碎片/starter 法则死常量已删")
	_ok(GCc.NEW_GAME_STARTER_RUNE_IDS.size() == 2, "starter 符文常量保留")
	_ok(GCc.is_indirect_weapon_type(1) and GCc.is_indirect_weapon_type(9) and not GCc.is_indirect_weapon_type(0), "is_indirect 判定不受影响")
	var smf := FileAccess.open("res://managers/save_manager.gd", FileAccess.READ).get_as_text()
	_ok(not smf.contains("SK_PHASE_LAW:") and not smf.contains("SK_CHARACTERS:") and not smf.contains("SK_CHALLENGE_RECORDS:"), "save_manager 三个死键别名已删")
	var UM: Dictionary = load("res://data/modification_modules/universal_mods.gd").get_mod_data("gen_23_singularity_core")
	var icon_path: String = str(UM.get("icon", ""))
	_ok(icon_path == "res://assets/ui/icons/mod_icons/mod_special.png" and ResourceLoader.exists(icon_path), "gen_23 图标路径已修且文件存在")
	var WVP: GDScript = load("res://data/weapon_visual_profiles.gd")
	_ok(WVP.resolve_visual_wt("", 1, false) == 0, "敌方 legacy RIFLE 归一 0（回归锁语义不变）")
	_ok(WVP.resolve_visual_wt("", 1, true) == 1, "我方新枚举 INDIRECT 保持")

	print("=== 4. 改动文件残留文本复核 ===")
	var checks := {
		"res://scenes/units/bullet.gd": ["FLAME_STAR_TEX", "_beam_visual_phase", "_impact_spawned"],
		"res://managers/battle/simple_indirect_projectile_batch.gd": ["impact_spawned", "\"speed\":"],
		"res://scripts/battle/vfx_impact_factory.gd": ["normalize_light_kinetic_wt(wt", "_%02x%02x%02x"],
		"res://scripts/weapon_projectile_vfx.gd": ["s * 737", "s * 974"],
		"res://scenes/world_map.gd": ["PhaseLawsData"],
	}
	for p: String in checks:
		var ff := FileAccess.open(p, FileAccess.READ)
		var t := ff.get_as_text() if ff != null else ""
		for bad: String in checks[p]:
			_ok(not t.contains(bad), "%s 无残留 %s" % [p.get_file(), bad])
	var sw := FileAccess.open("res://scenes/units/swarm_enemy_controller.gd", FileAccess.READ).get_as_text()
	_ok(sw.contains("wt_canon") and sw.contains("is_indirect_weapon_type(wt_canon)"), "蜂群曲射前置路由已加")
	var bu := FileAccess.open("res://scenes/units/bullet.gd", FileAccess.READ).get_as_text()
	_ok(bu.contains("func _find_beam_neighbors") and bu.contains("query_enemies"), "bullet 光束邻搜走网格")
	var eu := FileAccess.open("res://scenes/units/enemy_unit.gd", FileAccess.READ).get_as_text()
	_ok(eu.contains("_timing_chk_accum"), "敌攻速巡检节流已加")
	var cg := FileAccess.open("res://scripts/card_grid_unit_visuals.gd", FileAccess.READ).get_as_text()
	_ok(cg.contains("_aim_spr_ref"), "空中瞄准点 sprite 缓存已加")

	print("")
	if _fails == 0:
		print("ALL PASS")
	else:
		printerr("FAILURES: ", _fails)
	quit(1 if _fails > 0 else 0)
