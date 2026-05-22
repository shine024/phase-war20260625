extends RefCounted
class_name EvolutionGraphBuilder

## 从 UnitLineageConfig 收集进化链单位，按时代分列（情报中心 V3，无连线）

const UnitLineageConfig = preload("res://data/unit_lineage_config.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const CompanyDefinitions = preload("res://data/company_definitions.gd")

const ERA_LABELS: PackedStringArray = ["一战", "二战", "冷战", "现代", "近未来"]


static func infer_era_index(card_id: String) -> int:
	var id: String = String(card_id)
	if id.contains("ww1"):
		return 0
	if id.contains("ww2"):
		return 1
	if id.contains("cold"):
		return 2
	if id.contains("modern"):
		return 3
	return 4


static func get_display_name(card_id: String) -> String:
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	if card != null:
		return String(card.display_name)
	return card_id


static func is_blueprint_unlocked(card_id: String) -> bool:
	if card_id.is_empty():
		return false
	if BlueprintManager == null:
		return false
	if BlueprintManager.has_method("is_blueprint_unlocked"):
		return bool(BlueprintManager.is_blueprint_unlocked(card_id))
	if BlueprintManager.has_method("get_unlocked_blueprint_ids"):
		return (BlueprintManager.get_unlocked_blueprint_ids() as Array).has(card_id)
	return false


static func build() -> Dictionary:
	var node_set: Dictionary = {}

	for source_id in UnitLineageConfig.LINEAGES.keys():
		var sid: String = String(source_id)
		node_set[sid] = true
		var cfg: Dictionary = UnitLineageConfig.LINEAGES[sid]
		var e1: String = String(cfg.get("evolution_1", ""))
		if not e1.is_empty():
			node_set[e1] = true
		var branches: Dictionary = cfg.get("faction_branches", {})
		for faction_id in branches.keys():
			var tid: String = String(branches[faction_id])
			if not tid.is_empty():
				node_set[tid] = true

	var by_era: Array = [[], [], [], [], []]
	for nid in node_set.keys():
		var card_id: String = String(nid)
		var era: int = infer_era_index(card_id)
		(by_era[era] as Array).append({
			"id": card_id,
			"era": era,
			"label": get_display_name(card_id),
			"unlocked": is_blueprint_unlocked(card_id),
			"has_lineage": UnitLineageConfig.has_lineage(card_id),
			"predecessors": get_predecessors(card_id),
			"predecessor_summary": format_predecessor_summary(card_id),
		})
	for era in range(by_era.size()):
		(by_era[era] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("label", "")) < String(b.get("label", ""))
		)

	var nodes: Array[Dictionary] = []
	for era in range(by_era.size()):
		for entry in by_era[era]:
			nodes.append(entry)

	return {
		"nodes": nodes,
		"by_era": by_era,
		"era_labels": ERA_LABELS,
	}


## 可进化出 target_id 的前置单位（反向查表）
static func get_predecessors(target_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if target_id.is_empty():
		return result
	for source_id in UnitLineageConfig.LINEAGES.keys():
		var sid: String = String(source_id)
		var cfg: Dictionary = UnitLineageConfig.LINEAGES[sid]
		var e1: String = String(cfg.get("evolution_1", ""))
		if e1 == target_id:
			result.append({
				"from_id": sid,
				"from_label": get_display_name(sid),
				"kind": "e1",
				"stage_label": "E1 · 同体系",
				"faction_id": "",
			})
		var branches: Dictionary = cfg.get("faction_branches", {})
		for faction_id in branches.keys():
			if String(branches[faction_id]) != target_id:
				continue
			var fid: String = String(faction_id)
			result.append({
				"from_id": sid,
				"from_label": get_display_name(sid),
				"kind": "e2",
				"stage_label": "E2 · %s" % faction_display_name(fid),
				"faction_id": fid,
			})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ak: String = String(a.get("kind", "")) + String(a.get("from_id", ""))
		var bk: String = String(b.get("kind", "")) + String(b.get("from_id", ""))
		return ak < bk
	)
	return result


static func format_predecessor_summary(target_id: String) -> String:
	var preds: Array[Dictionary] = get_predecessors(target_id)
	if preds.is_empty():
		return "初始单位（无前置进化）"
	var parts: PackedStringArray = PackedStringArray()
	for p in preds:
		parts.append("%s（%s）" % [String(p.get("from_label", "")), String(p.get("stage_label", ""))])
	return "、".join(parts)


static func faction_display_name(faction_id: String) -> String:
	if faction_id.is_empty() or faction_id == "base":
		return "基础进化"
	var cfg: Dictionary = CompanyDefinitions.get_by_id(faction_id)
	var name_text: String = String(cfg.get("name", "")).strip_edges()
	return name_text if not name_text.is_empty() else faction_id
