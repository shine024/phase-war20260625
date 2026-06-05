extends RefCounted
## 诊断脚本：检查所有战斗卡的 icon 解析路径
## 用法: godot --headless --path "." --script scripts/audit_card_icons.gd

const GC := preload("res://resources/game_constants.gd")
const DefaultCards := preload("res://data/default_cards.gd")
const EnemyArchetypes := preload("res://data/enemy_archetypes.gd")
const EnemyUnitManifest := preload("res://data/enemy_unit_manifest.gd")
const EnemyBlueprints := preload("res://data/enemy_blueprints.gd")
const CardResource := preload("res://resources/card_resource.gd")
const EnemyPhaseEquipment := preload("res://data/enemy_phase_equipment.gd")
const UiAssetLoader := preload("res://scripts/ui_asset_loader.gd")

const UNITS_DIR := "res://assets/card_icons/units/"

static func _get_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f:
		var s := f.get_as_text()
		f.close()
		return s
	return ""

static func _file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)

static func _resource_exists(path: String) -> bool:
	return ResourceLoader.exists(path)

static func _main() -> void:
	var all_cards := DefaultCards.get_all_cards()
	print("=== 战斗卡 Icon 诊断 ===")
	print("总计: %d 张" % all_cards.size())
	print()
	
	var mismatch_count := 0
	var ok_count := 0
	var error_count := 0
	var placeholder_count := 0
	
	for card in all_cards:
		if card == null or not (card is CardResource):
			continue
		if card.card_type != GC.CardType.COMBAT_UNIT:
			continue
		
		var card_id := card.card_id
		var platform_id := card.source_platform_id
		var archetype_id := card_id
		
		# 尝试解析图标路径
		var icon_path := UiAssetLoader.card_icon_path_for(card)
		
		var status := "OK"
		var details := ""
		
		if icon_path.is_empty():
			status := "MISSING"
			details = "无解析路径"
			error_count += 1
		elif "_enemy_placeholder" in icon_path:
			status := "PLACEHOLDER"
			details = "使用默认占位图"
			placeholder_count += 1
		elif "/units/" in icon_path:
			# 提取 filename
			var parts := icon_path.split("/")
			var fname := parts[-1].get_basename()
			if fname.begins_with("vis_enemy"):
				status := "ENEMY_VIS"
				details = fname
				mismatch_count += 1
			elif fname.begins_with("vis_player"):
				status := "PLAYER_VIS"
				details = fname
				ok_count += 1
			elif fname.begins_with("foe_"):
				status := "FOE_ALIAS"
				details = fname
				mismatch_count += 1
			else:
				status := "UNITS_FILE"
				details = fname
				ok_count += 1
		elif "/card_icons/" in icon_path and not "units" in icon_path:
			var parts := icon_path.split("/")
			var fname := parts[-1].get_basename()
			status := "ROOT_FILE"
			details = fname
			ok_count += 1
		else:
			status := "OTHER"
			details = icon_path
		
		# 输出有问题的卡
		if status in ["MISSING", "PLACEHOLDER", "ENEMY_VIS", "FOE_ALIAS"]:
			print("  [%s] %s (platform: %s)" % [status, card_id, platform_id])
			print("         path: %s  |  detail: %s" % [icon_path, details])
			# 尝试找正确的映射
			if platform_id:
				var foe_arch := EnemyUnitManifest.archetype_id_for_platform_card(platform_id)
				var icon := EnemyUnitManifest.get_unit_icon_path_for_archetype(foe_arch)
				if not icon.is_empty():
					print("         foe_arch: %s  →  icon: %s" % [foe_arch, icon])
				else:
					# fallback: 用 platform_type 找 PLAYER_MIRROR_ARCHETYPE
					print("         foe_arch 无图标文件，尝试 platform_type 映射")
	
	print()
	print("=== 统计 ===")
	print("  正确 (PLAYER_VIS/ROOT_FILE): %d" % ok_count)
	print("  敌方视觉 (ENEMY_VIS/FOE_ALIAS): %d" % mismatch_count)
	print("  占位图 (PLACEHOLDER): %d" % placeholder_count)
	print("  缺失 (MISSING): %d" % error_count)
