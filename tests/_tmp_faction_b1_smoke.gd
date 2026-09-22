extends SceneTree
## v6.22 批1 冒烟（§4.12 step 3）：加载改动文件 + 断言关键契约（--script 模式，不启 autoload）

var _fails: Array[String] = []
var _ok: int = 0

func _check(cond: bool, tag: String) -> void:
	if cond:
		_ok += 1
	else:
		_fails.append(tag)

func _code(s: Script) -> String:
	# 剥离注释行（v6.22 删除注记不参与死链断言）
	var out: PackedStringArray = []
	for line in s.source_code.split("
"):
		var t: String = line.strip_edges()
		if t.begins_with("#"):
			continue
		out.append(line)
	return "
".join(out)

func _has_method_of(s: Script, name: String) -> bool:
	for m in s.get_script_method_list():
		if String(m.get("name", "")) == name:
			return true
	return false

func _has_prop_of(s: Script, name: String) -> bool:
	for p in s.get_script_property_list():
		if String(p.get("name", "")) == name:
			return true
	return false

func _initialize() -> void:
	# 1. FSM：占领链死、历史辖区/功勋活
	var fsm: Script = load("res://managers/faction_system_manager.gd")
	_check(fsm != null, "fsm_load")
	_check(not _has_method_of(fsm, "on_level_conquered"), "fsm_no_on_level_conquered")
	_check(_has_method_of(fsm, "get_level_historical_faction"), "fsm_has_get_level_historical_faction")
	_check(_has_method_of(fsm, "get_historical_levels"), "fsm_has_get_historical_levels")
	_check(_has_method_of(fsm, "add_merit"), "fsm_has_add_merit")
	_check(not _has_method_of(fsm, "transfer_occupation"), "fsm_no_transfer_occupation")
	_check(not _has_method_of(fsm, "get_territory_count"), "fsm_no_get_territory_count")
	_check(not _has_prop_of(fsm, "faction_variants_unlocked"), "fsm_no_variants_var")

	# 2. FactionReputation：征服反应死、阈值轴保留
	var fr: Script = load("res://managers/faction/faction_reputation.gd")
	_check(fr != null, "fr_load")
	_check(not _has_method_of(fr, "calculate_conquest_reaction"), "fr_no_conquest_reaction")
	_check(_has_prop_of(fr, "LEVEL_THRESHOLDS") or fr.LEVEL_THRESHOLDS.size() >= 8, "fr_has_thresholds")

	# 3. CompanyDefinitions：FACTION_MOD_BIAS 搬家到位
	var cd: Script = load("res://data/company_definitions.gd")
	_check(cd != null, "cd_load")
	_check(cd.FACTION_MOD_BIAS.size() == 7, "cd_bias_7")
	_check(String(cd.FACTION_MOD_BIAS.get("iron_wall_corp", [""])[0]) == "armor", "cd_bias_iron_wall")

	# 4. enemy_stat_context：faction 字段死
	var esc: Script = load("res://data/enemy_stat_context.gd")
	_check(not _has_prop_of(esc, "faction_buff"), "ctx_no_faction_buff")
	_check(not _has_prop_of(esc, "faction_id"), "ctx_no_faction_id")
	_check(not _has_prop_of(esc, "faction_level"), "ctx_no_faction_level")

	# 5. 敌方数值链零势力乘区
	var esr: Script = load("res://data/enemy_stat_resolver.gd")
	_check(esr != null, "esr_load")
	_check(not _code(esr).contains("FactionConquestBuffs"), "esr_no_fcb")

	# 6. intel_discovery_manager：无 occupation 上下文
	var idm: Script = load("res://scripts/systems/intel_discovery_manager.gd")
	_check(idm != null, "idm_load")
	_check(not _code(idm).contains("_occupation_drop_context"), "idm_no_occ_ctx")

	# 7. 关键 UI/管理器可编译 + 死链断言
	for p in ["res://scenes/ui/store_panel.gd", "res://scenes/world_map.gd", "res://managers/quest_manager.gd", "res://managers/faction/faction_event_manager.gd", "res://managers/achievement/achievement_rewards.gd", "res://scenes/main.gd", "res://scenes/ui/faction_panel.gd", "res://scenes/ui/leaderboard/leaderboard_data.gd", "res://scenes/ui/leaderboard/leaderboard_panel.gd"]:
		var sc: Script = load(p)
		_check(sc != null and not sc.source_code.is_empty(), "load_ok:" + p)
	var sp: Script = load("res://scenes/ui/store_panel.gd")
	_check(not _code(sp).contains("CompanyStore"), "store_no_companystore")
	var fem: Script = load("res://managers/faction/faction_event_manager.gd")
	_check(not _code(fem).contains("loyalty"), "fem_no_loyalty")
	_check(not _code(fem).contains("bonus_event_active"), "fem_no_bonus_signal")
	var qm: Script = load("res://managers/quest_manager.gd")
	_check(not _code(qm).contains("notify_law_researched"), "qm_no_law_notify")
	_check(not _code(qm).contains("is_mission_quest"), "qm_no_mission_fns")
	var wm: Script = load("res://scenes/world_map.gd")
	_check(not _code(wm).contains("territory_btn"), "wm_no_territory_btn")
	_check(not _code(wm).contains("_occupation_dirty"), "wm_no_dirty")

	# 8. 已删文件确认不存在
	for gone in ["res://data/faction_conquest_buffs.gd", "res://data/company_store.gd", "res://data/faction_status.gd", "res://managers/faction/faction_card_generator.gd", "res://data/faction_card_bonuses.gd", "res://scenes/ui/occupation_panel.gd"]:
		_check(not ResourceLoader.exists(gone), "gone:" + gone)

	if _fails.is_empty():
		print("FACTION_B1_SMOKE_OK (%d asserts)" % _ok)
	else:
		print("FACTION_B1_SMOKE_FAIL: ", " | ".join(_fails))
	quit(1 if not _fails.is_empty() else 0)
