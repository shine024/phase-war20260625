extends RefCounted
class_name CardDropGrants
## 战后/掉落：优先向背包发放成品掉落卡；无法解析为 CardResource 时回退为蓝图副本

const DefaultCards = preload("res://data/default_cards.gd")

## 旧字段 fragment_id：改为随机敌方 bp/精英卡，每次 amount 独立抽取并发背包卡
const LEGACY_FRAGMENT_REWARD_POOLS: Dictionary = {
	"common_fragment": ["bp_ww1_001", "bp_ww1_011", "bp_ww2_003"],
	"rare_fragment": ["bp_ww2_004", "bp_cold_002", "bp_modern_006"],
	"epic_fragment": ["bp_modern_010", "bp_near_005", "energy_start_7"],
	"legendary_fragment": ["titan_mk2", "storm_rider", "abrams_mk2"],
}


static func _get_blueprint_manager() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop as SceneTree
		if tree.root != null:
			return tree.root.get_node_or_null("BlueprintManager")
	return null


static func _get_drop_manager() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop as SceneTree
		if tree.root != null:
			return tree.root.get_node_or_null("DropManager")
	return null


## 敌方风格奖励：规范化 id 后，若有对应卡牌资源则经 DropManager 发掉落卡，否则写入蓝图副本
static func grant_enemy_style_card(bm: Node, card_id: String, _era: int, amount: int) -> void:
	if bm == null or not is_instance_valid(bm):
		return
	var n: int = maxi(1, int(amount))
	var id: String = String(card_id).strip_edges()
	if id.is_empty():
		return
	if bm.has_method("should_skip_drop_grant") and bm.should_skip_drop_grant(id):
		return
	if bm.has_method("normalize_storage_id"):
		id = String(bm.normalize_storage_id(id))
	if id.is_empty():
		return
	var dm: Node = _get_drop_manager()
	if dm != null and dm.has_method("grant_dropped_cards_by_id"):
		if DefaultCards.get_card_by_id(id) != null:
			dm.grant_dropped_cards_by_id(id, n)
			return
	if bm.has_method("add_blueprint_copy"):
		bm.add_blueprint_copy(id, n)


## 将旧「蓝图碎片档位」奖励统一转为背包卡牌（与 DailyTaskManager 原池一致）
static func grant_from_legacy_fragment_reward_pool(fragment_id: String, amount: int) -> void:
	var fid := String(fragment_id).strip_edges()
	if fid.is_empty():
		fid = "common_fragment"
	var pool: Variant = LEGACY_FRAGMENT_REWARD_POOLS.get(fid)
	var ids: Array = (pool as Array) if pool != null else (LEGACY_FRAGMENT_REWARD_POOLS["common_fragment"] as Array)
	if ids.is_empty():
		return
	var bm: Node = _get_blueprint_manager()
	var n: int = maxi(1, int(amount))
	for _i in range(n):
		var pick: String = String(ids[randi() % ids.size()])
		grant_enemy_style_card(bm, pick, 0, 1)


## 发放可装备的法则卡到背包（每张 clone 一次，与 DropManager._add_law_card 一致）
static func grant_law_cards_to_backpack(law_id: String, amount: int) -> void:
	var lid: String = String(law_id).strip_edges()
	if lid.is_empty():
		return
	var template: CardResource = DefaultCards.create_law_card_resource(lid)
	if template == null:
		push_warning("CardDropGrants: create_law_card_resource failed: %s" % lid)
		return
	if typeof(SignalBus) == TYPE_NIL:
		return
	# v7.0: 法则卡实例化（独立养成身份）
	var ir: Node = null
	var tree = Engine.get_main_loop()
	if tree and tree.root:
		ir = tree.root.get_node_or_null("InstanceRegistry")
	var n: int = maxi(1, int(amount))
	for _i in range(n):
		var c: CardResource
		if ir != null and ir.has_method("create_instance_from_template"):
			c = ir.create_instance_from_template(template)
		elif template.has_method("clone"):
			c = template.clone() as CardResource
		else:
			c = (template as Resource).duplicate(true) as CardResource
		SignalBus.card_added_to_backpack.emit(c)
