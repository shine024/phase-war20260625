class_name FactionContributionReworkTest
extends GdUnitTestSuite
## v6.22 批4 回归锁：贡献驱动改版（docs/势力重构_贡献驱动改版_2026-09-22.md）
##
## 锁五件事：
## 1. 占领/战争符号在核心脚本清零（剥注释后断言，删除注记不豁免代码体）
## 2. 新目标类型接线（reach_intel 助手 / salvage_items 上报链）
## 3. 僵尸任务已清（json 无 attack/defend、reach_reputation 新轴 ≥1200、无负贡献/旧奖励键）
## 4. 生成器新模板（7 家全覆盖、三类九型、产出契约）
## 5. 旧档死键读档不炸（faction_event_manager.load_state 静默忽略 loyalty/history/bonus）

const QuestDefsScript = preload("res://data/quest_definitions.gd")
const FactionQuestGeneratorScript = preload("res://data/faction_quest_generator.gd")
const FactionEventManagerScript = preload("res://managers/faction/faction_event_manager.gd")

const _CORE_SCRIPTS: Array[String] = [
	"res://managers/faction_system_manager.gd",
	"res://managers/faction/faction_event_manager.gd",
	"res://managers/quest_manager.gd",
	"res://scenes/world_map.gd",
	"res://scenes/ui/store_panel.gd",
	"res://data/faction_quest_generator.gd",
	"res://data/faction_war_events.gd",
	"res://scripts/systems/intel_discovery_manager.gd",
]
const _DEAD_SYMBOLS: Array[String] = [
	"attack_faction", "defend_faction", "get_level_occupation",
	"transfer_occupation", "FactionConquestBuffs", "CompanyStore",
	"occupation_changed", "FACTION_RELATIONS", "calculate_conquest_reaction",
	"faction_bonus_duration", "get_quest_progress_for_mission",
]


func _code_of(path: String) -> String:
	var sc: Script = load(path)
	assert_that(sc).is_not_null()
	var out: PackedStringArray = PackedStringArray()
	for line in sc.source_code.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


func test_dead_symbols_removed_from_core_scripts() -> void:
	for p in _CORE_SCRIPTS:
		var code: String = _code_of(p)
		for sym in _DEAD_SYMBOLS:
			assert_bool(code.contains(sym)).is_false()


func test_new_target_types_wired() -> void:
	var qm: Script = load("res://managers/quest_manager.gd")
	var methods: Array = qm.get_script_method_list()
	var names: PackedStringArray = PackedStringArray()
	for m in methods:
		names.append(String(m.get("name", "")))
	assert_bool(names.has("notify_items_salvaged")).is_true()
	assert_bool(names.has("_get_archetype_intel_percent")).is_true()
	var gll: Script = load("res://scripts/battle/ground_loot_layer.gd")
	assert_str(gll.source_code).contains("_notify_salvage")


func test_zombie_quests_cleared() -> void:
	var f := FileAccess.open("res://data/json/quest_definitions.json", FileAccess.READ)
	assert_that(f).is_not_null()
	var doc: Dictionary = JSON.parse_string(f.get_as_text())
	var quests: Array = doc.get("data", [])
	assert_int(quests.size()).is_greater(50)
	for q in quests:
		var otype: String = String(q.get("objective_type", ""))
		assert_bool(otype == "attack_faction" or otype == "defend_faction").is_false()
		if otype == "reach_reputation":
			assert_int(int(q.get("target", 0))).is_greater_equal(1200)
		var rw: Dictionary = q.get("rewards", {})
		assert_bool(rw.has("company_rep")).is_false()
		var frep: Dictionary = rw.get("faction_rep", {})
		for fid in frep:
			assert_int(int(frep[fid])).is_greater_equal(0)


func test_generator_covers_all_factions_with_new_templates() -> void:
	var themes: Dictionary = FactionQuestGeneratorScript.FACTION_THEMES
	assert_int(themes.size()).is_equal(7)
	var allowed: Array[String] = [
		"win_battles", "kill_enemies", "collect_cards", "enhance", "buy_items",
		"reach_intel", "salvage_items", "clear_level", "clear_boss_count",
	]
	for fid in themes:
		# 每家多掷若干次，覆盖类型池并校验产出契约
		for i in 24:
			var def: Dictionary = FactionQuestGeneratorScript.generate_quest(String(fid), 5)
			assert_int(def.size()).is_greater(0)
			var otype: String = String(def.get("objective_type", ""))
			assert_bool(otype in allowed).is_true()
			var frep: Dictionary = def.get("rewards", {}).get("faction_rep", {})
			for k in frep:
				assert_int(int(frep[k])).is_greater(0)
		# v6.22.4: reach_intel 断言改确定性直调（原 24 抽撞 11/89 权重是 ~4% flaky，曾偶发误报）
		var rid: Dictionary = FactionQuestGeneratorScript._build_quest_def("reach_intel", String(fid), 5, themes[fid], 1)
		assert_int(rid.size()).is_greater(0)
		var rt: Dictionary = rid.get("target", {})
		assert_str(String(rt.get("archetype_id", ""))).is_not_empty()
		assert_int(int(rt.get("target", 0))).is_greater(0)


func test_event_manager_load_ignores_legacy_dead_keys() -> void:
	var fem: Node = FactionEventManagerScript.new()
	# 旧档死键（loyalty/event_history/active_bonus_events）静默忽略；活键正常恢复
	fem.load_state({
		"battle_count_since_last": 3,
		"loyalty": {"iron_wall_corp": 90.0},
		"event_history": [{"id": "old"}],
		"active_bonus_events": {"iron_wall_corp": {"bonus": {}, "remaining": 2}},
		"active_event": {"template": {"name": "x"}, "name": "旧未决事件"},
	})
	assert_int(int(fem.get("battle_count_since_last"))).is_equal(3)
	assert_that(fem.get("active_event")).is_not_null()
	assert_bool(Dictionary(fem.get("active_event")).is_empty()).is_false()
	assert_bool(fem.has_method("get_loyalty")).is_false()
	assert_bool(fem.has_method("apply_bonus_event")).is_false()
	fem.free()


func test_event_templates_use_collaboration_background() -> void:
	var fwe: Script = load("res://data/faction_war_events.gd")
	var templates: Array = fwe.EVENT_TEMPLATES
	assert_int(templates.size()).is_equal(6)
	for t in templates:
		var name_str: String = String(t.get("name", ""))
		assert_bool(name_str.contains("进攻")).is_false()
		assert_bool(name_str.contains("防守")).is_false()
		assert_bool(name_str.contains("领地")).is_false()
