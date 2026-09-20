extends SceneTree
## dump: unit_anims 目录名 → 卡图路径映射（走游戏自身的 manifest 解析）

func _initialize() -> void:
	var Manifest = load("res://data/enemy_unit_manifest.gd")
	var dir := DirAccess.open("res://assets/effects/unit_anims")
	var out := {}
	if dir != null:
		dir.list_dir_begin()
		var d := dir.get_next()
		while d != "":
			if dir.current_is_dir() and not d.begins_with("."):
				var p := String(Manifest.get_unit_icon_path_for_archetype(d))
				var entry := {"icon": p}
				if p.contains("vis_enemy_"):
					var idx := p.get_file().trim_prefix("vis_enemy_").trim_suffix(".png")
					entry["enemy"] = "res://assets/card_icons/enemy/vis_enemy_%s.png" % idx
					entry["player"] = "res://assets/card_icons/player/vis_player_%s.png" % idx
				out[d] = entry
			d = dir.get_next()
		dir.list_dir_end()
	var f := FileAccess.open("res://.godot/anim_icon_map.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("dumped ", out.size(), " entries")
	quit(0)
