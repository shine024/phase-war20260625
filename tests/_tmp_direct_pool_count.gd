extends SceneTree
func _init() -> void:
	var mm = load("res://managers/manufacture_manager.gd").new()
	var ids: Array = mm.get_recipe_ids()
	var direct: Array = []
	var gated: Array = []
	for cid in ids:
		if mm.is_direct_pool_card(str(cid)):
			direct.append(str(cid))
		else:
			gated.append(str(cid))
	print("[direct-pool] catalog_total=", ids.size(), " direct=", direct.size(), " gated=", gated.size())
	print("[direct-pool] direct_ids=", direct)
	quit()
