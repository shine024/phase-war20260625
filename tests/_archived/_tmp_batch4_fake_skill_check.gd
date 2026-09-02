extends SceneTree
## tests/_tmp_batch4_fake_skill_check.gd — 批次4（P1-5 假技能处置）验证
## ① 召唤死链四零（引擎分发/函数/显示分支/技能池定义）
## ② intel_manual_items 死函数删除
## ③ 收集稀有度统计动态化：神话组 total=6（6 张 mythic 卡），五组 total 之和=185
## Usage: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_batch4_fake_skill_check.gd

func _code_only(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var out: Array[String] = []
	for ln in f.get_as_text().split("\n"):
		if String(ln).strip_edges().begins_with("#"):
			continue
		out.append(String(ln))
	f.close()
	return "\n".join(out)

func _initialize() -> void:
	var errs: Array[String] = []

	# ── ① 召唤死链 ──
	var engine_src := _code_only("res://managers/battle/card_periodic_skill_engine.gd")
	var panel_src := _code_only("res://scenes/ui/card_info_panel.gd")
	var skills_src := _code_only("res://data/card_periodic_skills.gd")
	for src_name in [["engine", engine_src], ["panel", panel_src], ["skills", skills_src]]:
		if String(src_name[1]).find("summon") >= 0:
			errs.append("召唤残留: %s" % String(src_name[0]))
	for fp in ["res://managers/battle/card_periodic_skill_engine.gd", "res://scenes/ui/card_info_panel.gd",
			"res://data/card_periodic_skills.gd", "res://data/intel_manual_items.gd",
			"res://managers/card_collection_manager.gd"]:
		if load(fp) == null:
			errs.append("加载失败: " + fp)

	# ── ② intel 死函数 ──
	var intel_src := _code_only("res://data/intel_manual_items.gd")
	if intel_src.find("get_available_blueprints") >= 0:
		errs.append("get_available_blueprints 死函数仍存在")

	# ── ③ 收集统计动态化（行为验证）──
	var CCM = load("res://managers/card_collection_manager.gd")
	var ccm = CCM.new()
	var stats: Dictionary = ccm.get_rarity_collection_stats()
	if int(stats.get("神话", {}).get("total", -1)) != 6:
		errs.append("神话组 total 非 6: %s" % str(stats.get("神话", {})))
	var sum_total: int = 0
	for r in ["普通", "稀有", "史诗", "传说", "神话"]:
		sum_total += int(stats.get(r, {}).get("total", 0))
	if sum_total != 185:
		errs.append("五组 total 之和非 185: %d" % sum_total)
	ccm.free()

	if errs.is_empty():
		print("BATCH4 CHECK: ALL PASS")
		quit(0)
	else:
		for e in errs:
			printerr("FAIL: " + e)
		quit(1)
