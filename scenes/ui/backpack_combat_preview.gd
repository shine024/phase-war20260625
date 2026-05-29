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


## 统一的三维攻防格式：轻甲空攻击/防御，与战场显示一致
static func _format_combat_stats_summary(stats: UnitStats, cur_hp: float = -1.0) -> String:
	if stats == null:
		return ""
	var hp_text: String
	if cur_hp >= 0.0:
		hp_text = "HP %.0f/%.0f" % [cur_hp, stats.max_hp]
	else:
		hp_text = "HP %.0f" % stats.max_hp
	
	# 三维攻击/防御：轻/甲/空
	var atk_light: float = stats.attack_light if stats.attack_light > 0.001 else 0.0
	var atk_armor: float = stats.attack_armor if stats.attack_armor > 0.001 else 0.0
	var atk_air: float = stats.attack_air if stats.attack_air > 0.001 else 0.0
	
	var def_light: float = stats.defense_light if stats.defense_light > 0.001 else 0.0
	var def_armor: float = stats.defense_armor if stats.defense_armor > 0.001 else 0.0
	var def_air: float = stats.defense_air if stats.defense_air > 0.001 else 0.0
	
	# 格式：HP 100｜攻 10/5/8｜防 3/5/2｜射程 120｜攻速 1.0｜移速 80
	var line: String = "%s｜攻 %.0f/%.0f/%.0f｜防 %.0f/%.0f/%.0f｜射程 %.0f｜攻速 %.2f｜移速 %.0f" % [
		hp_text,
		atk_light, atk_armor, atk_air,
		def_light, def_armor, def_air,
		stats.attack_range,
		stats.attack_interval,
		stats.move_speed,
	]
	return line

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

	# 只处理战斗卡
	if card.card_type == GC.CardType.COMBAT_UNIT:
		# 处理战斗单位卡（有底盘）
		if card.platform_type >= 0:
			var wts: Array = []
			for t in card.multi_weapon_types:
				wts.append(int(t))
			if wts.is_empty() and card.default_weapon_type >= 0:
				wts.append(card.default_weapon_type)
			
			if wts.is_empty():
				return ""
			
			var stats: UnitStats = UnitStatsTable.build_multi_stats(card.platform_type, wts, era)
			if bm and bm.has_method("apply_growth_to_stats"):
				bm.apply_growth_to_stats(stats, card, [])
			if am and am.has_method("apply_affixes_to_stats"):
				am.apply_affixes_to_stats(stats, card, [])
			return "战斗中：" + _format_combat_stats_summary(stats)
		
		# 处理武器卡（无底盘）
		elif card.weapon_type >= 0:
			var wbase: Dictionary = UnitStatsTable.get_weapon_base(card.weapon_type, era)
			var stats_w := UnitStats.new()
			stats_w.attack_light = float(wbase["damage"])
			stats_w.attack_armor = float(wbase["damage"])
			stats_w.attack_air = float(wbase["damage"])
			stats_w.attack_range = float(wbase["range"])
			stats_w.attack_interval = float(wbase["interval"])
			if bm and bm.has_method("apply_growth_to_stats"):
				bm.apply_growth_to_stats(stats_w, null, [card])
			if am and bm.has_method("apply_affixes_to_stats"):
				am.apply_affixes_to_stats(stats_w, null, [card])
			# 武器卡：只显示攻击相关
			return "战斗中：攻 %.0f/%.0f/%.0f｜射程 %.0f｜攻速 %.2f" % [
				stats_w.attack_light, stats_w.attack_armor, stats_w.attack_air,
				stats_w.attack_range, stats_w.attack_interval,
			]
	
	return ""