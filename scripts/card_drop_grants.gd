extends RefCounted
class_name CardDropGrants
## 战后/掉落：向背包发放成品掉落卡（蓝图副本回退已移除）

const DefaultCards = preload("res://data/default_cards.gd")
const EnemyCardModMapRef = preload("res://data/enemy_card_mod_map.gd")

## 旧字段 fragment_id：改为随机成品卡，每次 amount 独立抽取并发背包卡
## 2026-09-19 修复：原池 12 个 id 中 9 个 bp_* 蓝图 id 与 3 个命名敌卡（titan_mk2 等）
## 均无法经 DefaultCards.get_card_by_id 解析（缩进 bug 修复后暴露），按稀有度档换真卡。
const LEGACY_FRAGMENT_REWARD_POOLS: Dictionary = {
	"common_fragment": ["ww1_mp18", "ww1_mauser", "ww1_enfield"],
	"rare_fragment": ["ww2_arm_sherman", "cold_arm_t55", "mod_arm_m1a1"],
	"epic_fragment": ["mod_t90", "mod_arty_m270", "fut_arm_hovertank"],
	"legendary_fragment": ["fut_arm_omega", "fut_colossus", "fut_stormcore"],
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


## 敌方风格奖励：规范化 id 后，若有对应卡牌资源则经 DropManager 发掉落卡
## v7.x 胜利面板漏显修复：新增可选 source 参数，非空时记录到 GameManager 本局收集器，
## 供胜利面板"本局缴获与战利品"分区显示。默认空 → 不记录（向后兼容，普通关 pending_drops claim 路径零变化）。
## v7.x 战报一致性修复：只有真正发掉落卡成功（get_card_by_id 命中）才记战报；回退到
## add_blueprint_copy（只解锁蓝图+给研究点，背包无卡）时不记，避免"战报显示但实际没得到卡"。
static func grant_enemy_style_card(bm: Node, card_id: String, _era: int, amount: int, source: String = "") -> void:
	if bm == null or not is_instance_valid(bm):
		return
	var n: int = maxi(1, int(amount))
	var orig_id: String = String(card_id).strip_edges()
	var id: String = orig_id
	if id.is_empty():
		return
	if bm.has_method("should_skip_drop_grant") and bm.should_skip_drop_grant(id):
		return
	if bm.has_method("normalize_storage_id"):
		id = String(bm.normalize_storage_id(id))
	if id.is_empty():
		return
	# v6.32.3: 敌卡 id 救援——drops 表 14 处引用全是 UCT enemy_only 条目（drop_* / fut_* /
	# mod_arm_abrams_mk2 等），get_card_by_id 走玩家侧缓存必然 miss，原路径 100% 跳过刷警告
	# +玩家拿不到掉落（实机日志 2026-09-28 fut_air_regen_frame 实证）。经 EnemyCardModMap
	# 官方对照表换玩家卡重试；战报/背包记录的也是玩家实际拿到的映射后卡。
	if DefaultCards.get_card_by_id(id) == null:
		var mapped: String = EnemyCardModMapRef.get_player_card_id(id)
		if not mapped.is_empty():
			id = mapped
	var dm: Node = _get_drop_manager()
	if dm != null and dm.has_method("grant_dropped_cards_by_id") and DefaultCards.get_card_by_id(id) != null:
		dm.grant_dropped_cards_by_id(id, n)
		if not source.is_empty():
			_record_card_to_collector(id, n, source)
		return
	# 2026-08-22：蓝图副本回退已随蓝图体系移除；无法解析为卡牌资源的 id 静默跳过
	# v6.32.3: 相位师 `*_basic` 缴获平台（fortress/titan/raider/siege 等类型不在
	# EXCLUDED_WAR_PLATFORM_TYPES，steel/flame 相位师每战 2 条漏到此处）——平台本就非卡牌，
	# 静默跳过不算掉落失败（对齐 game_manager 缴获循环里 pdata.is_empty() continue 的先例）
	if not String(orig_id).is_empty() and _is_war_platform_id(orig_id):
		return
	push_warning("CardDropGrants: 掉落 id 无法解析为卡牌，跳过: %s" % id)


## 是否为敌方相位战平台 id（*_basic 等平台定义在 enemy_phase_platforms，非卡牌）
## 延迟 load 防循环依赖（default_cards.get_safe_display_name 同款范式）
static func _is_war_platform_id(card_id: String) -> bool:
	var eq_epe: GDScript = load("res://data/enemy_phase_equipment.gd")
	if eq_epe == null:
		return false
	return not (eq_epe.get_war_platform(card_id) as Dictionary).is_empty()


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

