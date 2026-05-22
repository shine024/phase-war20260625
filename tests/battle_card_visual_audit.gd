# 审计：战斗平台卡 → 敌方原型反查 + EnemyArchetypes.resolve_card_icon_texture_path 能否解析到贴图
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/battle_card_visual_audit.gd
extends SceneTree

const GC = preload("res://resources/game_constants.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const EnemyBlueprints = preload("res://data/enemy_blueprints.gd")
const DefaultCards = preload("res://data/default_cards.gd")

const MIRROR_BY_PLATFORM: Dictionary = {
	GC.PlatformType.HOUND: "enemy_ww1_infantry_basic",
	GC.PlatformType.GUARD: "enemy_ww2_infantry",
	GC.PlatformType.TITAN: "elite_ww1_armored",
	GC.PlatformType.FORTRESS: "enemy_ww1_mg_nest",
	GC.PlatformType.RADAR: "enemy_modern_stryker",
	GC.PlatformType.SCOUT: "enemy_cold_btr",
	GC.PlatformType.RAIDER: "enemy_future_hovertank",
	GC.PlatformType.SIEGE: "enemy_ww1_mortar",
	GC.PlatformType.CARRIER: "enemy_cold_m113",
	GC.PlatformType.MEDIC: "enemy_modern_marine",
	GC.PlatformType.STEALTH: "elite_future_spectre",
	GC.PlatformType.OMEGA_PLATFORM: "enemy_future_mech",
}


func _has_any_visual(archetype_id: String) -> bool:
	var cfg: Dictionary = EnemyArchetypes.get_config(archetype_id)
	if cfg.is_empty():
		return false
	return not EnemyArchetypes.resolve_card_icon_texture_path(archetype_id, cfg, archetype_id).is_empty()


func _initialize() -> void:
	EnemyArchetypes.rebuild_card_to_archetype_lookup()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== battle_card_visual_audit ===")
	lines.append("Time: " + Time.get_datetime_string_from_system())

	var rev_hit: Array[String] = []
	var rev_miss_platform: Array[String] = []
	var rev_miss_weapon: Array[String] = []
	var asset_ok: Array[String] = []
	var asset_bad: Array[String] = []

	var ids: Array[String] = []
	for id_raw in EnemyBlueprints.get_all_enemy_blueprint_ids():
		ids.append(String(id_raw))
	ids.sort()
	for cid in DefaultCards.get_all_blueprint_ids():
		var s: String = String(cid)
		if s.begins_with("platform_") or s == "omega_platform":
			if not ids.has(s):
				ids.append(s)
	ids.sort()

	for card_id in ids:
		var card = DefaultCards.get_card_by_id(card_id)
		if card == null:
			lines.append("[NO_CARD] %s" % card_id)
			continue
		if card.card_type != GC.CardType.PLATFORM and card.card_type != GC.CardType.COMBINED:
			if card.card_type == GC.CardType.WEAPON:
				rev_miss_weapon.append(card_id)
			continue

		var arch: String = EnemyArchetypes.get_visual_archetype_id_for_card(card_id)
		var check_arch: String = arch
		if arch.is_empty():
			check_arch = String(MIRROR_BY_PLATFORM.get(int(card.platform_type), ""))
			rev_miss_platform.append("%s -> mirror:%s" % [card_id, check_arch])
		else:
			rev_hit.append("%s -> %s" % [card_id, arch])

		if check_arch.is_empty():
			asset_bad.append("%s | NO_ARCHETYPE" % card_id)
			continue

		if int(card.platform_type) == int(GC.PlatformType.OMEGA_PLATFORM):
			if ResourceLoader.exists("res://assets/unit_sprites/omega_platform.png"):
				asset_ok.append("%s | omega_static_png" % card_id)
			else:
				asset_bad.append("%s | omega_png_missing" % card_id)
			continue

		if _has_any_visual(check_arch):
			asset_ok.append("%s | arch=%s" % [card_id, check_arch])
		else:
			asset_bad.append("%s | arch=%s | no_card_icon_or_sprite_path_resolved" % [card_id, check_arch])

	lines.append("")
	lines.append("--- counts ---")
	lines.append("EnemyBlueprints+default platform ids scanned: %d" % ids.size())
	lines.append("PLATFORM/COMBINED cards: %d" % (rev_hit.size() + rev_miss_platform.size()))
	lines.append("  drops反查命中 (revhit): %d" % rev_hit.size())
	lines.append("  反查空→platform镜像兜底: %d" % rev_miss_platform.size())
	lines.append("  WEAPON blueprint (非部署平台): %d" % rev_miss_weapon.size())
	lines.append("  有可用精灵/静态图(asset_ok): %d" % asset_ok.size())
	lines.append("  缺资源或无数值原型(asset_bad): %d" % asset_bad.size())

	lines.append("")
	lines.append("--- revhit (sample up to 40) ---")
	for i in mini(40, rev_hit.size()):
		lines.append("  " + rev_hit[i])
	if rev_hit.size() > 40:
		lines.append("  ... +" + str(rev_hit.size() - 40))

	lines.append("")
	lines.append("--- fallback mirror (sample up to 40) ---")
	for i in mini(40, rev_miss_platform.size()):
		lines.append("  " + rev_miss_platform[i])
	if rev_miss_platform.size() > 40:
		lines.append("  ... +" + str(rev_miss_platform.size() - 40))

	lines.append("")
	lines.append("--- asset_bad (full) ---")
	for s in asset_bad:
		lines.append("  " + s)

	lines.append("")
	lines.append("--- weapon blueprint ids (informational) ---")
	for i in mini(30, rev_miss_weapon.size()):
		lines.append("  " + rev_miss_weapon[i])
	if rev_miss_weapon.size() > 30:
		lines.append("  ... +" + str(rev_miss_weapon.size() - 30))

	var out_path: String = "res://tests/battle_card_visual_audit_output.txt"
	var joined: String = ""
	for i in range(lines.size()):
		joined += lines[i]
		if i + 1 < lines.size():
			joined += "\n"
	print(joined)
	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(joined)
		f.close()
		print("\n[WROTE] ", out_path)
	else:
		push_error("failed write " + out_path)

	quit(0)
