# Temporary: audit all enemy archetypes for icon path + texture size
extends SceneTree

const EA = preload("res://data/enemy_archetypes.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const GC = preload("res://resources/game_constants.gd")

func _initialize() -> void:
	var bad: Array[String] = []
	var big: Array[String] = []
	var ok := 0
	for id_raw in EA.get_all_ids():
		var id: String = String(id_raw)
		var cfg: Dictionary = EA.get_config(id)
		var p: String = EA.resolve_card_icon_texture_path(id, cfg, id)
		if p.is_empty():
			bad.append(id)
			continue
		ok += 1
		var t: Texture2D = load(p) as Texture2D
		if t != null and (t.get_width() > 768 or t.get_height() > 768):
			big.append("%s %dx%d %s" % [id, t.get_width(), t.get_height(), p])

	print("=== archetype icons ===")
	print("ok=%d bad=%d oversized=%d" % [ok, bad.size(), big.size()])
	for s in bad:
		print("MISSING: ", s)
	for s in big:
		print("OVERSIZED: ", s)

	var plat_bad: Array[String] = []
	for cid_raw in DefaultCards.get_all_blueprint_ids():
		var cid: String = String(cid_raw)
		if not cid.begins_with("platform_") and cid != "omega_platform":
			continue
		var c = DefaultCards.get_card_by_id(cid)
		if c == null or c.card_type != GC.CardType.PLATFORM:
			continue
		var path: String = UiAssetLoader.card_icon_path_for(c)
		var tex: Texture2D = UiAssetLoader.load_tex(path)
		if tex == null:
			plat_bad.append("%s -> %s" % [cid, path])

	print("")
	print("=== platform card_icon_path_for (UiAssetLoader) ===")
	print("missing=%d" % plat_bad.size())
	for s in plat_bad:
		print("  ", s)

	quit(0)
