extends SceneTree
## 定向编译验证（一次性）：load 本轮改动的 UI 面板与支撑脚本，抓语义级编译错误
## Usage: godot --headless --path . --script tests/_tmp_panel_load_check.gd

func _initialize() -> void:
	var targets := [
		"res://scenes/ui/modification_panel.gd",
		"res://scenes/ui/card_info_panel.gd",
		"res://scenes/ui/backpack_panel.gd",
		"res://data/mod_era_bands.gd",
		"res://data/enemy_fixed_loadouts.gd",
		"res://data/enemy_loadout_tiers.gd",
		"res://scenes/world_map.gd",
		"res://scripts/master_platform_power.gd",
		"res://managers/battle/simple_indirect_projectile_batch.gd",
		"res://scripts/battle/construct_unit_ai.gd",
		"res://resources/card_resource.gd",
		"res://resources/unit_stats_table.gd",
		"res://scripts/systems/modification_registry.gd",
		"res://scripts/card_grid_damage.gd",
		"res://scenes/units/construct_unit.gd",
		"res://scenes/units/enemy_unit.gd",
	]
	var bad := 0
	for t in targets:
		var s = load(t)
		if s == null:
			print("COMPILE-FAIL ", t)
			bad += 1
		else:
			print("OK ", t)
	if bad == 0:
		print("PANEL-LOAD ALL OK")
	else:
		print("PANEL-LOAD FAILURES: ", bad)
	quit(1 if bad > 0 else 0)
