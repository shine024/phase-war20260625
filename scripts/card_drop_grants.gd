extends RefCounted
class_name CardDropGrants
## 战后/掉落：优先向背包发放成品掉落卡；无法解析为 CardResource 时回退为蓝图副本

const DefaultCards = preload("res://data/default_cards.gd")

## 旧字段 fragment_id：改为随机敌方 bp/精英卡，每次 amount 独立抽取并发背包卡
const LEGACY_FRAGMENT_REWARD_POOLS: Dictionary = {
	"common_fragment": ["bp_ww1_001", "bp_ww1_011", "bp_ww2_003"],
	"rare_fragment": ["bp_ww2_004", "bp_cold_002", "bp_modern_006"],
		# v7.x: 能量卡移除，epic_fragment 池改为现代精英卡
		"epic_fragment": ["bp_modern_010", "bp_near_005", "bp_modern_011"],
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
	# v7.x: DropManager 已改懒加载，统一在此 ensure（所有调用方一次性受益）
	if ManagerLazyLoader and ManagerLazyLoader.has_method("ensure_loaded"):
		ManagerLazyLoader.ensure_loaded("drop")
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop as SceneTree
		if tree.root != null:
			return tree.root.get_node_or_null("DropManager")
	return null


## 敌方风格奖励：规范化 id 后，若有对应卡牌资源则经 DropManager 发掉落卡，否则写入蓝图副本
## v7.x 胜利面板漏显修复：新增可选 source 参数，非空时记录到 GameManager 本局收集器，
## 供胜利面板"本局缴获与战利品"分区显示。默认空 → 不记录（向后兼容，普通关 pending_drops claim 路径零变化）。
## v7.x 战报一致性修复：只有真正发掉落卡成功（get_card_by_id 命中）才记战报；回退到
## add_blueprint_copy（只解锁蓝图+给研究点，背包无卡）时不记，避免"战报显示但实际没得到卡"。
static func grant_enemy_style_card(bm: Node, card_id: String, _era: int, amount: int, source: String = "") -> void:
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
			# v7.x 战报一致性修复：只有真正发卡成功才记入战报收集器（显示名多层回退，杜绝裸 ID）。
			# 回退蓝图副本不记——蓝图副本只解锁蓝图库+给研究点，背包无卡，不该冒充"缴获卡牌"显示。
			if not source.is_empty():
				_record_card_to_collector(id, n, source)
			return
	if bm.has_method("add_blueprint_copy"):
		bm.add_blueprint_copy(id, n)


## v7.x 胜利面板漏显修复：把卡牌发放记录到 GameManager 本局收集器
static func _record_card_to_collector(card_id: String, count: int, source: String) -> void:
	var gm: Node = _get_game_manager()
	if gm == null or not gm.has_method("collect_battle_card"):
		return
	var display_name: String = DefaultCards.get_safe_display_name(card_id)
	gm.collect_battle_card(card_id, display_name, count, source)


## 获取 GameManager autoload（运行时，编辑器/单测可能为空）
static func _get_game_manager() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop as SceneTree
		if tree.root != null:
			return tree.root.get_node_or_null("GameManager")
	return null


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
