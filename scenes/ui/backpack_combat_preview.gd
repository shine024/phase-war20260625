extends RefCounted
## 背包 UI：根据当前关卡时代 + 养成/词条/军衔估算「战斗中」HP/攻等一行摘要（与 battle_spawn 部署口径一致，不含相位仪战场加成）

const GC = preload("res://resources/game_constants.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")


## 与战场部署一致：按当前关卡所属时代缩放武器伤害/射程与平台生命（见 BattleCardV3 / battle_spawn_system）
static func _preview_battle_era() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return 0
	var gm: Node = tree.root.get_node_or_null("GameManager")
	if gm != null and "current_level" in gm:
		return GC.get_era_for_level(int(gm.current_level))
	return 0


static func build_line(card: CardResource) -> String:
	if card == null:
		return ""
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return ""
	var root: Node = tree.root
	var mll: Node = root.get_node_or_null("ManagerLazyLoader")
	if mll and mll.has_method("ensure_loaded"):
		mll.ensure_loaded("affix")
	var bm: Node = root.get_node_or_null("BlueprintManager")
	var am: Node = root.get_node_or_null("AffixManager")
	var era: int = _preview_battle_era()

	if card.card_type == GC.CardType.COMBAT_UNIT:
		if card.platform_type < 0:
			return ""
		var wt: int = card.default_weapon_type
		if wt < 0:
			wt = 1  # RIFLE
		var stats: UnitStats = UnitStatsTable.build_multi_stats(card.platform_type, [wt], era)
		if bm and bm.has_method("apply_growth_to_stats"):
			bm.apply_growth_to_stats(stats, card, [])
		if am and am.has_method("apply_affixes_to_stats"):
			am.apply_affixes_to_stats(stats, card, [])
		return "战斗中：HP %.0f｜攻 %.0f｜防 %.0f｜射程 %.0f｜攻速 %.2f" % [
			stats.max_hp, stats.attack_damage, stats.defense, stats.attack_range, stats.attack_interval,
		]

	if card.card_type == GC.CardType.COMBAT_UNIT:
		if card.weapon_type < 0:
			return ""
		var wbase: Dictionary = UnitStatsTable.get_weapon_base(card.weapon_type, era)
		var stats_w := UnitStats.new()
		stats_w.attack_damage = float(wbase["damage"])
		stats_w.attack_range = float(wbase["range"])
		stats_w.attack_interval = float(wbase["interval"])
		if bm and bm.has_method("apply_growth_to_stats"):
			bm.apply_growth_to_stats(stats_w, null, [card])
		if am and am.has_method("apply_affixes_to_stats"):
			am.apply_affixes_to_stats(stats_w, null, [card])
		return "战斗中：攻 %.0f｜防 %.0f｜射程 %.0f｜攻速 %.2f" % [
			stats_w.attack_damage, UnitStatsTable.get_weapon_defense(card.weapon_type), stats_w.attack_range, stats_w.attack_interval,
		]

	if card.card_type == GC.CardType.COMBAT_UNIT:
		if card.platform_type < 0:
			return ""
		var wts: Array = []
		for t in card.multi_weapon_types:
			wts.append(int(t))
		if wts.is_empty() and card.default_weapon_type >= 0:
			wts.append(card.default_weapon_type)
		if wts.is_empty():
			return ""
		var stats_c: UnitStats = UnitStatsTable.build_multi_stats(card.platform_type, wts, era)
		if bm and bm.has_method("apply_growth_to_stats"):
			bm.apply_growth_to_stats(stats_c, card, [])
		if am and am.has_method("apply_affixes_to_stats"):
			am.apply_affixes_to_stats(stats_c, card, [])
		return "战斗中：HP %.0f｜攻 %.0f｜防 %.0f｜射程 %.0f｜攻速 %.2f" % [
			stats_c.max_hp, stats_c.attack_damage, stats_c.defense, stats_c.attack_range, stats_c.attack_interval,
		]

	return ""