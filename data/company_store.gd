extends RefCounted
class_name CompanyStore

const _ITEMS_JSON_PATH := "res://data/json/company_store.json"
static var ITEMS: Array = _load_json_array(_ITEMS_JSON_PATH, LEGACY_ITEMS)

static func _load_json_array(path: String, fallback: Array) -> Array:
	if not FileAccess.file_exists(path):
		return fallback
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema_version", 0)) != 1:
		return fallback
	var data = parsed.get("data", fallback)
	return data if typeof(data) == TYPE_ARRAY else fallback

## 公司商店配置：每家公司可售卖的卡牌（含敌方 bp_*；许可函等素材）
##
## 条目字段：
## - company_id: 所属公司
## - card_id: 卡牌 id（DefaultCards permit_*）
## - fragment_amount: 购买一次获得的张数（沿用字段名，语义为「卡牌数量」）
## - price_nano_materials: 花费的纳米材料
## - required_rep: 购买所需的公司贡献度（公司声望）

const CompanyDefs = preload("res://data/company_definitions.gd")

const LEGACY_ITEMS: Array[Dictionary] = []

static func get_items_for_company(company_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	const DefaultCards = preload("res://data/default_cards.gd")
	const UnitIdMigration = preload("res://data/unit_id_migration_config.gd")
	
	for it in ITEMS:
		if String(it.get("company_id", "")) == company_id:
			var entry: Dictionary = it.duplicate(true)
			var card_id: String = String(entry.get("card_id", ""))
			
			# 无武器版：过滤已失效卡牌（典型是 weapon_* / omega_cannon / 旧合成卡）。
			# permit_*、蓝图材料等非卡牌ID保留。
			if card_id.begins_with("weapon_") or card_id == "omega_cannon" or card_id.begins_with("syn_"):
				continue
			if card_id.begins_with("permit_card_weapon_"):
				continue
			
			if not card_id.begins_with("permit_") and not card_id.is_empty():
				# 先用原始ID查找
				var c: CardResource = DefaultCards.get_card_by_id(card_id)
				
				# 如果找不到，尝试用ID迁移表映射旧ID→新ID
				if c == null and UnitIdMigration.UNIT_ID_MIGRATION_MAP.has(card_id):
					var migrated_id: String = String(UnitIdMigration.UNIT_ID_MIGRATION_MAP[card_id])
					c = DefaultCards.get_card_by_id(migrated_id)
					if c != null:
						# 迁移成功：更新entry中的card_id为新ID
						entry["card_id"] = migrated_id
				
				# 如果迁移后仍找不到，跳过此条目
				if c == null:
					continue
			
			result.append(entry)
	return result

static func get_default_company_id() -> String:
	var all_companies: Array[Dictionary] = CompanyDefs.get_all()
	if all_companies.size() > 0:
		return String(all_companies[0].get("id", ""))
	return ""
