# Audit card_icon_path_for + resolve paths for all cards/archetypes
extends SceneTree

const EA = preload("res://data/enemy_archetypes.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const CapturedUnitCards = preload("res://data/captured_unit_cards.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")

const PLACEHOLDER := "res://assets/card_icons/_enemy_placeholder.png"
const SHAPE_KEYS := [
	"hound", "guard", "titan", "fortress", "radar", "scout", "raider",
	"siege", "carrier", "medic", "stealth", "omega_platform", "law", "energy", "unknown",
]

func _audit_card(c: CardResource, shape_fallback: Array, placeholder_paths: Array, vis_player_hits: Array, manifest_hits: Array, missing_tex: Array) -> void:
	if c == null:
		return
	var cid: String = c.card_id
	var path: String = UiAssetLoader.card_icon_path_for(c)
	var tex = UiAssetLoader.load_tex(path)
	var stem := path.get_file().get_basename()
	if path == PLACEHOLDER or stem == "_enemy_placeholder":
		placeholder_paths.append("%s -> %s" % [cid, path])
	elif stem in SHAPE_KEYS or path.ends_with("/law.png") or path.ends_with("/energy.png"):
		shape_fallback.append("%s -> %s (type=%s)" % [cid, path, c.card_type])
	elif path.contains("/units/vis_player_"):
		vis_player_hits.append("%s -> %s" % [cid, path])
	elif path.contains("/units/vis_"):
		manifest_hits.append("%s -> %s" % [cid, path])
	if tex == null:
		missing_tex.append("%s -> %s" % [cid, path])


func _initialize() -> void:
	EA.rebuild_card_to_archetype_lookup()
	CapturedUnitCards.register_into_default_cards_cache()

	var shape_fallback: Array[String] = []
	var placeholder_paths: Array[String] = []
	var vis_player_hits: Array[String] = []
	var manifest_hits: Array[String] = []
	var missing_tex: Array[String] = []

	for c_raw in DefaultCards.create_all():
		_audit_card(c_raw as CardResource, shape_fallback, placeholder_paths, vis_player_hits, manifest_hits, missing_tex)
	for cid_raw in DefaultCards._id_lookup_cache.keys():
		_audit_card(DefaultCards.get_card_by_id(String(cid_raw)), shape_fallback, placeholder_paths, vis_player_hits, manifest_hits, missing_tex)

	print("=== card_icon_path_for audit ===")
	print("cached cards scanned", DefaultCards._id_lookup_cache.size())
	print("vis_player hits", vis_player_hits.size())
	print("vis_enemy/pool hits", manifest_hits.size())
	print("shape/aggregate fallback", shape_fallback.size())
	print("placeholder path", placeholder_paths.size())
	print("missing texture load", missing_tex.size())

	print("\n--- shape fallback (platform/special, first 40) ---")
	var shown := 0
	for s in shape_fallback:
		if "type=0" in s or "type=3" in s:
			print(" ", s)
			shown += 1
			if shown >= 40:
				break

	print("\n--- vis_player hits (first 15) ---")
	for i in mini(15, vis_player_hits.size()):
		print(" ", vis_player_hits[i])

	print("\n--- captured manifest hits (first 15) ---")
	for i in mini(15, manifest_hits.size()):
		print(" ", manifest_hits[i])

	print("\n--- placeholder ---")
	for s in placeholder_paths:
		print(" ", s)

	print("\n--- missing tex ---")
	for s in missing_tex:
		print(" ", s)

	print("\n=== archetypes resolving to placeholder ===")
	var arch_placeholder: Array[String] = []
	for id_raw in EA.get_all_ids():
		var id: String = String(id_raw)
		var cfg: Dictionary = EA.get_config(id)
		var p: String = EA.resolve_card_icon_texture_path(id, cfg, id)
		if p == PLACEHOLDER:
			arch_placeholder.append(id)
	print("count:", arch_placeholder.size())

	quit(0)
