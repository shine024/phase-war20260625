extends Node
## v35 清理批 —— autoload 全量环境下编译探针（--script 模式无法编译裸 autoload 引用脚本）
func _ready() -> void:
	var fails: int = 0
	var files: Array[String] = [
		"res://scenes/units/bullet.gd",
		"res://scenes/units/enemy_unit.gd",
		"res://scenes/units/swarm_enemy_controller.gd",
		"res://scripts/battle/vfx_impact_factory.gd",
		"res://managers/battle/simple_indirect_projectile_batch.gd",
		"res://scripts/battle/dot_vfx_manager.gd",
		"res://scripts/card_grid_unit_visuals.gd",
		"res://managers/save_manager.gd",
		"res://scenes/world_map.gd",
		"res://scenes/units/construct_unit.gd",
		"res://scripts/battle/fort_shield_aura.gd",
	]
	for p in files:
		var s: Variant = load(p)
		if s == null:
			fails += 1
			printerr("PROBE FAIL load ", p)
		else:
			print("PROBE OK ", p)
	# main.tscn 真实例化（墓碑手术验证）
	var main_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if main_scene == null:
		fails += 1
		printerr("PROBE FAIL main.tscn load")
	else:
		var inst := main_scene.instantiate()
		if inst == null:
			fails += 1
			printerr("PROBE FAIL main.tscn instantiate")
		else:
			var ok1 := inst.get_node_or_null("HudLayer/BattleTopStatusBar/BattleInfoDisplay") != null
			var dead1 := inst.get_node_or_null("HudLayer/BattleTopStatusBar/PlayerSpawnHUD") == null
			var dead2 := inst.get_node_or_null("HudLayer/BattleTopStatusBar/EnemySpawnHUD") == null
			print("PROBE main.tscn BattleInfoDisplay=", ok1, " spawnHUDs_removed=", dead1 and dead2)
			if not (ok1 and dead1 and dead2):
				fails += 1
			inst.free()
	print("PROBE RESULT ", "ALL_PASS" if fails == 0 else "FAILS=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
