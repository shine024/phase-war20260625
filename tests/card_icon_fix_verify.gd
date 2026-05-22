# Verification: platform cards + player battlefield archetype mapping
extends SceneTree

const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const GC = preload("res://resources/game_constants.gd")

const PLACEHOLDER := "res://assets/card_icons/_enemy_placeholder.png"
const OUT := "res://tests/card_icon_fix_verify_output.txt"

const PLATFORM_SAMPLES := [
	["platform_ww1_light", "vis_player_001"],
	["platform_cold_light", "vis_player_013"],
	["platform_modern_light", "vis_player_019"],
	["omega_platform", "vis_player_029"],
	["bulwark", "vis_player_030"],
]

func _initialize() -> void:
	var lines: PackedStringArray = []
	var failures := 0
	lines.append("=== card_icon_fix_verify ===")
	lines.append("Time: " + Time.get_datetime_string_from_system())

	# UI path: platform cards -> vis_player
	for pair in PLATFORM_SAMPLES:
		var cid: String = pair[0]
		var expect_vis: String = pair[1]
		var card = DefaultCards.get_card_by_id(cid)
		var path: String = UiAssetLoader.card_icon_path_for(card)
		var tex = UiAssetLoader.load_tex(path)
		var ok := path.contains("/units/%s.png" % expect_vis) and tex != null
		if not ok:
			failures += 1
		lines.append("%s UI: expect %s | got %s | tex=%s | %s" % [
			cid, expect_vis, path, tex != null, "OK" if ok else "FAIL"
		])

	# hound aggregate still loadable (shape fallback safety)
	var hound_tex = UiAssetLoader.load_tex("res://assets/card_icons/hound.png")
	lines.append("hound.png load: %s" % ("OK" if hound_tex != null else "FAIL"))
	if hound_tex == null:
		failures += 1

	# All 100 archetypes resolve to units/, not placeholder
	var arch_bad := 0
	var arch_placeholder := 0
	for id_raw in EnemyArchetypes.get_all_ids():
		var id: String = String(id_raw)
		var cfg: Dictionary = EnemyArchetypes.get_config(id)
		var p: String = EnemyArchetypes.resolve_card_icon_texture_path(id, cfg, id)
		if p == PLACEHOLDER:
			arch_placeholder += 1
		elif not p.contains("/units/"):
			arch_bad += 1
	lines.append("archetypes total=100 placeholder=%d non_units=%d" % [arch_placeholder, arch_bad])
	if arch_placeholder > 0 or arch_bad > 0:
		failures += 1

	# Player battlefield mapping: platform_card_id -> foe_* with manifest icon
	for pair in PLATFORM_SAMPLES:
		var platform_cid: String = pair[0]
		var foe_arch: String = EnemyUnitManifest.archetype_id_for_platform_card(platform_cid)
		var manifest_p: String = EnemyUnitManifest.get_unit_icon_path_for_archetype(foe_arch)
		var ok2 := not manifest_p.is_empty() and UiAssetLoader.load_tex(manifest_p) != null
		if not ok2:
			failures += 1
		lines.append("battle map %s -> %s -> %s | %s" % [
			platform_cid, foe_arch, manifest_p, "OK" if ok2 else "FAIL"
		])

	# Platform blueprint ids: no shape fallback for default platforms
	var shape_fallback := 0
	var vis_player_hits := 0
	var missing_tex := 0
	DefaultCards._ensure_card_cache()
	for cid_raw in DefaultCards._id_lookup_cache.keys():
		var c = DefaultCards.get_card_by_id(String(cid_raw))
		if c == null or c.card_type != GC.CardType.PLATFORM:
			continue
		if String(c.card_id).begins_with("bp_"):
			continue
		var path: String = UiAssetLoader.card_icon_path_for(c)
		var tex = UiAssetLoader.load_tex(path)
		if tex == null:
			missing_tex += 1
		elif path.contains("/units/vis_player_"):
			vis_player_hits += 1
		elif path.contains("/units/vis_"):
			pass
		else:
			shape_fallback += 1
	lines.append("default platform cards vis_player=%d shape_fallback=%d missing_tex=%d" % [
		vis_player_hits, shape_fallback, missing_tex
	])
	if shape_fallback > 0 or missing_tex > 0:
		failures += 1

	lines.append("")
	lines.append("RESULT: %s (failures=%d)" % ["PASS" if failures == 0 else "FAIL", failures])

	var text := ""
	for i in range(lines.size()):
		text += lines[i]
		if i + 1 < lines.size():
			text += "\n"
	print(text)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
	quit(1 if failures > 0 else 0)
