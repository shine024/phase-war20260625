## tests/_tmp_parse_check_v2717.gd — v27.17/18 批次改动的脚本解析冒烟
## Usage: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_parse_check_v2717.gd
extends SceneTree

func _init() -> void:
	var targets := [
		"res://scenes/bunker/truck_base.gd",
		"res://scenes/bunker/bunker_reward_bubble.gd",
		"res://scenes/bunker/ui/hero_archive_panel.gd",
		"res://scenes/bunker/ui/memorial_wall.gd",
		"res://scenes/ui/help_panel.gd",
		"res://managers/drop_manager.gd",
		"res://managers/battle/battle_damage_system.gd",
		"res://resources/drop_tables.gd",
	]
	var failed := 0
	for p in targets:
		var s: Variant = load(p)
		if s == null:
			print("PARSE_FAIL ", p)
			failed += 1
		else:
			print("PARSE_OK ", p)
	print("RESULT failed=%d total=%d" % [failed, targets.size()])
	quit(1 if failed > 0 else 0)
