extends SceneTree

func _init() -> void:
	var loader := load("res://scripts/ui_asset_loader.gd")
	var manifest := load("res://data/enemy_unit_manifest.gd")
	for uid in ["cold_inf_m60", "drop_overclock_matrix", "ww2_arm_tiger"]:
		var p: String = String(loader.card_icon_path_for_card_id(uid))
		print("ICON ", uid, " -> ", p, " exists=", not p.is_empty() and FileAccess.file_exists(p))
		var vp: String = String(manifest.visual_id_for_archetype(uid))
		print("ICON ", uid, " visual_id=", vp)
	quit(0)
