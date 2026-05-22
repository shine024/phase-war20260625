extends Node
## @deprecated v3 — 法则碎片已移除；数据在 PhaseLawManager 知识值中。
## 保留本脚本仅供旧存档迁移与少量兼容调用。

const PhaseLaws = preload("res://data/phase_laws.gd")
const GameConstants = preload("res://resources/game_constants.gd")

signal shards_changed

func grant_new_game_starter_law_shards() -> void:
	grant_new_game_starter_knowledge()

func grant_new_game_starter_knowledge() -> void:
	var plm: Node = get_node_or_null("/root/PhaseLawManager")
	if plm == null or not plm.has_method("add_knowledge"):
		return
	var amount: int = GameConstants.NEW_GAME_STARTER_LAW_SHARD_AMOUNT
	for law_id in GameConstants.get_all_new_game_starter_law_ids():
		var law: Dictionary = PhaseLaws.get_by_id(law_id)
		if law.is_empty():
			continue
		var kind: String = PhaseLawManager.knowledge_key_for_law_id(law_id)
		plm.add_knowledge(kind, amount)

func add_law_shard(law_id: String, amount: int = 1) -> void:
	var plm: Node = get_node_or_null("/root/PhaseLawManager")
	if plm == null or not plm.has_method("add_knowledge"):
		return
	var kind: String = PhaseLawManager.knowledge_key_for_law_id(law_id)
	plm.add_knowledge(kind, max(1, amount) * 3)
	emit_signal("shards_changed")

func get_shard_count(_law_id: String) -> int:
	return 0

func get_shard_required(law_id: String) -> int:
	var law: Dictionary = PhaseLaws.get_by_id(law_id)
	if law.is_empty():
		return 999999
	var req: Dictionary = law.get("research_req", {})
	var total: int = 0
	for k in req:
		total += int(req[k])
	return maxi(1, total)

func can_unlock_law(law_id: String) -> bool:
	var plm: Node = get_node_or_null("/root/PhaseLawManager")
	if plm and plm.has_method("can_research_law"):
		return plm.can_research_law(law_id)
	return false

func consume_shards_for_unlock(law_id: String) -> bool:
	var plm: Node = get_node_or_null("/root/PhaseLawManager")
	if plm and plm.has_method("research_law"):
		return plm.research_law(law_id)
	return false

func save_state() -> Dictionary:
	return {}

func load_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	var plm: Node = get_node_or_null("/root/PhaseLawManager")
	if plm == null or not plm.has_method("add_knowledge"):
		return
	if data.has("law_shards") and data["law_shards"] is Dictionary:
		for k in data["law_shards"]:
			var law_id: String = String(k)
			var count: int = int(data["law_shards"][k])
			if count <= 0:
				continue
			var kind: String = PhaseLawManager.knowledge_key_for_law_id(law_id)
			plm.add_knowledge(kind, count * 5)
