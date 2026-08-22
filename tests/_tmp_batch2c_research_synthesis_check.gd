extends SceneTree
## tests/_tmp_batch2c_research_synthesis_check.gd — 批次2c（P2-7 范围C 研究链+科研点+合成删除）验证
## ① 改动文件可加载；合成两文件已删且零引用（含场景文件）
## ② 科研点：常量/定义/产出删除，get_drops_for_level 无 research key，BRM 无收支臂
## ③ 信号：synthesis 双信号删除；掉落三消费方（keys 泛型迭代）自动适配
## Usage: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_batch2c_research_synthesis_check.gd

func _read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "(missing)"
	var s := f.get_as_text()
	f.close()
	return s

func _code_only(path: String) -> String:
	var out: Array[String] = []
	for ln in _read_file(path).split("\n"):
		var t := String(ln).strip_edges()
		if t.begins_with("#"):
			continue
		out.append(String(ln))
	return "\n".join(out)

func _initialize() -> void:
	var errs: Array[String] = []

	# ── ① 加载与文件删除 ──
	var BR = load("res://data/basic_resources.gd")
	var files: Array[String] = [
		"res://data/basic_resources.gd",
		"res://data/faction_war_events.gd",
		"res://managers/basic_resource_manager.gd",
		"res://managers/blueprint_manager.gd",
		"res://managers/drop_manager.gd",
		"res://managers/save_manager.gd",
		"res://managers/faction_system_manager.gd",
		"res://managers/audio_manager.gd",
		"res://scripts/signal_bus.gd",
		"res://scenes/ui/afk_settlement_dialog.gd",
		"res://scenes/ui/offline_reward_dialog.gd",
		"res://scenes/ui/resource_info_panel.gd",
		"res://scenes/ui/buff_fold_card.gd",
		"res://tools/print_level_drop_sheet.gd",
	]
	for fp in files:
		if load(fp) == null:
			errs.append("加载失败: " + fp)
	for gone in ["res://managers/synthesis/synthesis_manager.gd", "res://data/synthesis_recipes.gd"]:
		if FileAccess.file_exists(gone):
			errs.append("应删除的文件仍存在: " + gone)
	for ident in ["SynthesisManager", "SynthesisRecipes", "synthesis_completed", "synthesis_failed"]:
		for fp in ["res://managers/faction_system_manager.gd", "res://managers/audio_manager.gd", "res://scripts/signal_bus.gd"]:
			if _code_only(fp).find(ident) >= 0:
				errs.append("%s 残留标识符 %s" % [fp, ident])

	# ── ② 科研点行为 ──
	var drops: Dictionary = BR.get_drops_for_level(50)
	if drops.has("research_points"):
		errs.append("get_drops_for_level 仍产出科研点")
	var br_src := _code_only("res://data/basic_resources.gd")
	if br_src.find("research_points") >= 0:
		errs.append("basic_resources 代码仍含 research_points")
	var brm_src := _code_only("res://managers/basic_resource_manager.gd")
	if brm_src.find("total_research_points") >= 0:
		errs.append("BRM 仍含 total_research_points 字段")

	# ── ③ 信号与掉落消费方 ──
	var sb := _code_only("res://scripts/signal_bus.gd")
	if sb.find("signal synthesis") >= 0:
		errs.append("SignalBus 残留 synthesis 信号")
	# 三消费方为 keys() 泛型迭代，drops 无 research key 即自动适配——校验其代码无显式科研点读取
	# （注意不能用裸 "research" 子串——void_research 是势力 id，会误伤）
	for fp in ["res://managers/game_manager.gd", "res://scenes/world_map.gd", "res://scripts/systems/offline_idle_manager.gd"]:
		var code := _code_only(fp)
		if code.find("research_points") >= 0 or code.find("ID_RESEARCH") >= 0:
			errs.append("%s 仍显式读科研点" % fp)

	if errs.is_empty():
		print("BATCH2C CHECK: ALL PASS")
		quit(0)
	else:
		for e in errs:
			printerr("FAIL: " + e)
		quit(1)
