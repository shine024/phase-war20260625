## 存档迁移 v4 → v5
## 清除废弃字段：blueprint_stars、旧 star_level 引用

class_name SaveMigrationV5
extends RefCounted

## 执行 v4 → v5 迁移：清除废弃字段 + 数据完整性校验
static func migrate_v4_to_v5(data: Dictionary, debug_log: bool = false) -> void:
	_clean_blueprint_stars(data, debug_log)
	_clean_legacy_blueprint_levels(data, debug_log)
	_validate_blueprint_integrity(data, debug_log)

## 清除 blueprint_stars（星级系统已废弃，由 enhance_level 替代）
static func _clean_blueprint_stars(data: Dictionary, debug_log: bool) -> void:
	if not data.has("blueprint") or not data["blueprint"] is Dictionary:
		return
	var bp: Dictionary = data["blueprint"]
	if bp.has("blueprint_stars"):
		if debug_log:
			var count: int = bp["blueprint_stars"].size() if bp["blueprint_stars"] is Dictionary else 0
			push_warning("[SaveMigrationV5] 清除废弃 blueprint_stars (%d 条目)" % count)
		bp.erase("blueprint_stars")

## 清除旧版 blueprint_levels 残留（v1/v2 格式）
static func _clean_legacy_blueprint_levels(data: Dictionary, debug_log: bool) -> void:
	if not data.has("blueprint") or not data["blueprint"] is Dictionary:
		return
	var bp: Dictionary = data["blueprint"]
	if bp.has("blueprint_levels"):
		if debug_log:
			push_warning("[SaveMigrationV5] 清除废弃 blueprint_levels")
		bp.erase("blueprint_levels")
	if bp.has("fragments"):
		if debug_log:
			push_warning("[SaveMigrationV5] 清除废弃 fragments")
		bp.erase("fragments")

## 校验蓝图数据完整性，确保关键字段存在
static func _validate_blueprint_integrity(data: Dictionary, debug_log: bool) -> void:
	if not data.has("blueprint") or not data["blueprint"] is Dictionary:
		return
	var bp: Dictionary = data["blueprint"]

	if not bp.has("unlocked"):
		bp["unlocked"] = []
	if not bp.has("blueprint_copies"):
		bp["blueprint_copies"] = {}
	if not bp.has("blueprint_mods"):
		bp["blueprint_mods"] = {}

	# 校验 blueprint_mods 中每个卡牌的改造数组格式
	var mods: Dictionary = bp.get("blueprint_mods", {})
	for card_id in mods.keys():
		var mod_array = mods[card_id]
		if not mod_array is Array:
			mods[card_id] = []
			continue
		# 过滤无效条目
		var valid_mods: Array = []
		for mod_entry in mod_array:
			if mod_entry is Dictionary and mod_entry.has("id"):
				var mod_id: String = str(mod_entry["id"])
				if not mod_id.is_empty():
					valid_mods.append(mod_entry)
			elif mod_entry is String and not mod_entry.is_empty():
				valid_mods.append({id = mod_entry})
		mods[card_id] = valid_mods

	# 校验 blueprint_copies 数值合法性
	var copies: Dictionary = bp.get("blueprint_copies", {})
	for card_id in copies.keys():
		var val = copies[card_id]
		if not val is int or val < 0:
			copies[card_id] = 0
