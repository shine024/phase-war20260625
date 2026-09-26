extends SceneTree
func _init() -> void:
	var l := load("res://scripts/ui_asset_loader.gd")
	for r in ["common","uncommon","rare","epic","legendary","mythic"]:
		var t = l.card_frame_for_rarity(r)
		print("FRAME ", r, " -> ", "OK" if t != null else "NULL")
	quit(0)
