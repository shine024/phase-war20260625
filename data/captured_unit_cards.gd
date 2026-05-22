extends RefCounted
class_name CapturedUnitCards
## 100 张缴获成品卡（captured_*）：击杀敌人后进背包，可部署。
## 由模板 platform_* / 特殊平台卡克隆，display_name 与 EnemyUnitManifest 对齐。

const DefaultCards = preload("res://data/default_cards.gd")
const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const GC = preload("res://resources/game_constants.gd")

static var _cache_built: bool = false


static func register_into_default_cards_cache() -> void:
	if _cache_built:
		return
	DefaultCards._ensure_card_cache()
	for row in EnemyUnitManifest.get_entries():
		if row is not Dictionary:
			continue
		var drop_id: String = String(row.get("drop_card_id", ""))
		var template_id: String = _resolve_template_card_id(row)
		var display_name: String = String(row.get("display_name", ""))
		if drop_id.is_empty() or template_id.is_empty():
			continue
		if DefaultCards._id_lookup_cache.has(drop_id):
			continue
		var card: CardResource = _build_captured_card(drop_id, template_id, display_name, row)
		if card == null:
			continue
		DefaultCards._all_cards_cache.append(card)
		DefaultCards._id_lookup_cache[drop_id] = card
	_cache_built = true


static func _build_captured_card(
	drop_id: String,
	template_id: String,
	display_name: String,
	row: Dictionary
) -> CardResource:
	var template: CardResource = DefaultCards.get_card_by_id(template_id)
	if template == null:
		return null
	var c: CardResource
	if template.has_method("clone"):
		c = template.clone() as CardResource
	else:
		c = (template as Resource).duplicate(true) as CardResource
	if c == null:
		return null
	c.card_id = drop_id
	if not display_name.is_empty():
		c.display_name = display_name
	c.is_dropped_card = true
	c.type_line = _captured_type_line(c, int(row.get("era", 0)))
	return c


static func _resolve_template_card_id(row: Dictionary) -> String:
	var tid: String = String(row.get("template_card_id", ""))
	if not tid.is_empty() and DefaultCards.get_card_by_id(tid) != null:
		return tid
	var era: int = int(row.get("era", 0))
	var aid: String = String(row.get("archetype_id", ""))
	var tier: String = "frontline"
	if aid.begins_with("boss_"):
		tier = "boss"
	elif aid.begins_with("elite_"):
		tier = "elite"
	var kind: int = 1
	if tier == "frontline" and (aid.contains("infantry") or aid.contains("marine") or aid.contains("drone")):
		kind = 0
	elif tier == "boss" or aid.contains("tank") or aid.contains("panther") or aid.contains("abrams"):
		kind = 1
	elif aid.contains("mg") or aid.contains("mortar") or aid.contains("mlrs") or aid.contains("nest"):
		kind = 2
	elif aid.contains("medic") or aid.contains("carrier") or aid.contains("m113"):
		kind = 3
	return EnemyUnitManifest._template_platform_for_pool(era, kind)


static func _captured_type_line(card: CardResource, era: int) -> String:
	var era_label: String = ["一战", "二战", "冷战", "现代", "近未来"][clampi(era, 0, 4)]
	var role: String = "缴获平台"
	if card.card_type == GC.CardType.PLATFORM:
		role = "缴获平台"
	return "%s — %s" % [era_label, role]
