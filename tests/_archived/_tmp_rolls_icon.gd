extends SceneTree
func _initialize() -> void:
	var UCT = load("res://data/unified_card_table.gd")
	var UAL = load("res://scripts/ui_asset_loader.gd")
	for cid in ["ww1_arm_rolls", "ww1_arm_rolls_mk2"]:
		var card: CardResource = UCT.build_card_resource(cid)
		if card == null:
			print(cid, " -> CARD NULL")
			continue
		print(cid, " -> ", UAL.card_icon_path_for(card))
	quit(0)
