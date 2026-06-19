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
## 统一的三维攻防格式：轻甲空攻击/防御，与战场显示一致
## v6.0: 增加武器名称显示
static func _format_combat_stats_summary(stats: UnitStats, cur_hp: float = -1.0) -> String:
	if stats == null:
		return ""
	var hp_text: String
	if cur_hp >= 0.0:
		hp_text = "HP %d/%d" % [int(cur_hp), int(stats.max_hp)]
	else:
		hp_text = "HP %d" % int(stats.max_hp)
	
	# 获取武器名称
	var weapon_names: Array[String] = ["", "", ""]
	if not stats.weapon_slots.is_empty():
		for i in range(min(stats.weapon_slots.size(), 3)):
			var w = stats.weapon_slots[i]
			if w is WeaponResource and w.enabled:
				weapon_names[i] = w.display_name
	
	# 三维攻击/防御：轻/甲/空
	var atk_light: float = stats.attack_light if stats.attack_light > 0.001 else 0.0
	var atk_armor: float = stats.attack_armor if stats.attack_armor > 0.001 else 0.0
	var atk_air: float = stats.attack_air if stats.attack_air > 0.001 else 0.0
	
	var def_light: float = stats.defense_light if stats.defense_light > 0.001 else 0.0
	var def_armor: float = stats.defense_armor if stats.defense_armor > 0.001 else 0.0
	var def_air: float = stats.defense_air if stats.defense_air > 0.001 else 0.0
	
	# 格式：HP 100｜攻 武器名10/武器名5/武器名8｜防 3/5/2｜射程 120｜攻速 1.0/0.8/1.2｜移速 80
	var spd_light: float = stats.attack_light_speed if stats.attack_light_speed > 0.001 else 0.0
	var spd_armor: float = stats.attack_armor_speed if stats.attack_armor_speed > 0.001 else 0.0
	var spd_air: float = stats.attack_air_speed if stats.attack_air_speed > 0.001 else 0.0
	
	# 构建攻击部分（包含武器名）
	var atk_part: String
	if weapon_names[0].is_empty() and weapon_names[1].is_empty() and weapon_names[2].is_empty():
		atk_part = "%d/%d/%d" % [int(atk_light), int(atk_armor), int(atk_air)]
	else:
		var a0: String = weapon_names[0] + "%d" % atk_light if not weapon_names[0].is_empty() else "%d" % atk_light
		var a1: String = weapon_names[1] + "%d" % atk_armor if not weapon_names[1].is_empty() else "%d" % atk_armor
		var a2: String = weapon_names[2] + "%d" % atk_air if not weapon_names[2].is_empty() else "%d" % atk_air
		atk_part = "%s/%s/%s" % [a0, a1, a2]

	var line: String = "%s｜攻 %s｜防 %d/%d/%d｜射程 %d｜攻速 %.1f/%.1f/%.1f｜移速 %d" % [
		hp_text,
		atk_part,
		int(def_light), int(def_armor), int(def_air),
		int(stats.attack_range),
		spd_light, spd_armor, spd_air,
		int(stats.move_speed),
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
		# v5.0: 使用新的 build_stats_from_card 方法，不再检查已弃用的 platform_type
		var stats: UnitStats = UnitStatsTable.build_stats_from_card(card, era)
		if bm and bm.has_method("apply_growth_to_stats"):
			bm.apply_growth_to_stats(stats, card, [])
		if am and am.has_method("apply_affixes_to_stats"):
			am.apply_affixes_to_stats(stats, card, [])
		return "战斗中：" + _format_combat_stats_summary(stats)

	return ""
