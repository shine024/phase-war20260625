extends SceneTree
## ═══════════════════════════════════════════════════════════
##  冒烟测试：卡片定时技能 source_tag 派生
##
##  验证：
##    ① FACTION_TO_FAMILY 七条阵营→家族映射 + 空/未知 faction 返空
##    ② compute_source_tags_for_stats 各 source_tag 命中
##       （artillery/fort/engineer/ecm/sniper/stalker+stealth/flame/thunder/void）
##    ③ steel 不作为 tag 输出（无卡片技能用 steel 做 source_tag）
##    ④ null stats 安全返回空数组
##    ⑤ 引擎 _try_trigger 的 source_tag 匹配语义（Array `in` 操作）
##
##  运行：
##    Godot_v4.5.1-stable_win64.exe --headless --rendering-driver opengl3 \
##      --path "." --script "tests/card_source_tags_smoke.gd"
## ═══════════════════════════════════════════════════════════

const CPS = preload("res://data/card_periodic_skills.gd")
const GC = preload("res://resources/game_constants.gd")
const UnitStats = preload("res://resources/unit_stats.gd")


func _initialize() -> void:
	var errs: Array[String] = []

	# ① faction → family 映射
	if CPS.get_family_for_faction("nova_arms") != "flame": errs.append("nova_arms→flame 失败")
	if CPS.get_family_for_faction("void_research") != "void": errs.append("void_research→void 失败")
	if CPS.get_family_for_faction("aether_dynamics") != "thunder": errs.append("aether_dynamics→thunder 失败")
	if CPS.get_family_for_faction("helix_recon") != "thunder": errs.append("helix_recon→thunder 失败")
	if CPS.get_family_for_faction("frontier_union") != "thunder": errs.append("frontier_union→thunder 失败")
	if CPS.get_family_for_faction("iron_wall_corp") != "steel": errs.append("iron_wall_corp→steel 失败")
	if CPS.get_family_for_faction("quantum_logistics") != "steel": errs.append("quantum_logistics→steel 失败")
	if CPS.get_family_for_faction("") != "": errs.append("空 faction 应返回空串")
	if CPS.get_family_for_faction("unknown_faction") != "": errs.append("未知 faction 应返回空串")

	# ② compute_source_tags_for_stats 各 tag 命中
	# artillery（UnitSubType.ARTILLERY）
	var s := UnitStats.new()
	s.unit_subtype = GC.UnitSubType.ARTILLERY
	if not ("artillery" in CPS.compute_source_tags_for_stats(s)): errs.append("ARTILLERY 子类应命中 artillery tag")
	# fort（CombatKind.FORT）
	s = UnitStats.new()
	s.combat_kind = GC.CombatKind.FORT
	if not ("fort" in CPS.compute_source_tags_for_stats(s)): errs.append("FORT 主类应命中 fort tag")
	# engineer / ecm / sniper
	s = UnitStats.new()
	s.set_meta("is_engineer", true)
	if not ("engineer" in CPS.compute_source_tags_for_stats(s)): errs.append("is_engineer meta 应命中 engineer tag")
	s = UnitStats.new()
	s.set_meta("is_ecm", true)
	if not ("ecm" in CPS.compute_source_tags_for_stats(s)): errs.append("is_ecm meta 应命中 ecm tag")
	s = UnitStats.new()
	s.set_meta("is_sniper", true)
	if not ("sniper" in CPS.compute_source_tags_for_stats(s)): errs.append("is_sniper meta 应命中 sniper tag")
	# stalker + stealth（bullet.gd 兜底集超集，防回归）
	s = UnitStats.new()
	s.set_meta("is_stalker", true)
	var st_tags := CPS.compute_source_tags_for_stats(s)
	if not ("stalker" in st_tags) or not ("stealth" in st_tags):
		errs.append("is_stalker meta 应同时命中 stalker+stealth（bullet.gd 超集）")
	# family（模拟 _apply_law_family_meta 写入 law_family meta）
	s = UnitStats.new()
	s.set_meta("law_family", "flame")
	if not ("flame" in CPS.compute_source_tags_for_stats(s)): errs.append("law_family=flame 应命中 flame tag")
	s = UnitStats.new()
	s.set_meta("law_family", "thunder")
	if not ("thunder" in CPS.compute_source_tags_for_stats(s)): errs.append("law_family=thunder 应命中 thunder tag")
	s = UnitStats.new()
	s.set_meta("law_family", "void")
	if not ("void" in CPS.compute_source_tags_for_stats(s)): errs.append("law_family=void 应命中 void tag")

	# ③ steel 不应作为 tag 输出（无卡片技能用 steel 做 source_tag）
	s = UnitStats.new()
	s.set_meta("law_family", "steel")
	if "steel" in CPS.compute_source_tags_for_stats(s): errs.append("law_family=steel 不应输出 steel tag")

	# ④ null stats 安全
	if not CPS.compute_source_tags_for_stats(null).is_empty(): errs.append("null stats 应返回空数组")

	# ⑤ 引擎 _try_trigger 的 source_tag 匹配语义（_behavior_tags_cached 由 compute_source_tags_for_stats 填充）
	var artillery_stats := UnitStats.new()
	artillery_stats.unit_subtype = GC.UnitSubType.ARTILLERY
	var cached_tags: Array = CPS.compute_source_tags_for_stats(artillery_stats)
	# 引擎逻辑：if source_tag in _behavior_tags_cached → tag_count++
	if not ("artillery" in cached_tags): errs.append("引擎 artillery source_tag 匹配失败（artillery 技能无法触发）")

	# 汇总
	if errs.is_empty():
		print("[card_source_tags_smoke] ALL PASS")
		quit(0)
	else:
		for e in errs:
			push_error(e)
		print("[card_source_tags_smoke] FAIL: %d" % errs.size())
		quit(1)
