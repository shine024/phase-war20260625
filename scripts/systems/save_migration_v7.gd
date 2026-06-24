## 存档迁移 v6 → v7
## 清除废弃字段：card_battle_stars（战力星级系统②已合并到强化等级①）

class_name SaveMigrationV7
extends RefCounted

## 执行 v6 → v7 迁移：清除战力星级数据
static func migrate_v6_to_v7(data: Dictionary, debug_log: bool = false) -> void:
	_clean_card_battle_stars(data, debug_log)

## 清除 card_battle_stars（战力星级系统已废弃，加成合并到 enhance_level）
static func _clean_card_battle_stars(data: Dictionary, debug_log: bool) -> void:
	if not data.has("blueprint") or not data["blueprint"] is Dictionary:
		return
	var bp: Dictionary = data["blueprint"]
	if bp.has("card_battle_stars"):
		if debug_log:
			var count: int = bp["card_battle_stars"].size() if bp["card_battle_stars"] is Dictionary else 0
			push_warning("[SaveMigrationV7] 清除废弃 card_battle_stars (%d 条目)" % count)
		bp.erase("card_battle_stars")
