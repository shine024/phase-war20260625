extends SceneTree
## v6.19 竞品反思修订批 加载冒烟（--script 模式，不启动全部 autoload）
## 断言：改动脚本可编译加载 + pity 文案口径/黑门常量/遭遇规则常量/里程碑 API 正确。

func _initialize() -> void:
	print("SMOKES0 initialize entered")
	var errs: Array[String] = []

	# 1) 全部改动脚本可编译加载
	for p: String in [
		"res://data/manufacture_pools.gd",
		"res://data/mod_manufacture.gd",
		"res://data/build_advisor.gd",
		"res://scenes/ui/evolution_panel.gd",
		"res://scenes/ui/intelligence_hub_panel.gd",
		"res://scenes/ui/bottom_instrument_bar.gd",
		"res://scenes/ui/top_hud_bar.gd",
		"res://scenes/world_map.gd",
		"res://managers/game_manager.gd",
		"res://managers/manufacture_manager.gd",
		"res://managers/blueprint_manager.gd",
		"res://managers/performance_metrics_manager.gd",
		"res://managers/battle/battle_spectacle.gd",
		"res://scripts/battle/combo_engine.gd",
	]:
		if load(p) == null:
			errs.append("load fail: " + p)
	print("SMOKES1 loads done")

	# 2) pity 文案：数值读常量、任何 pity 值无"必出"字样（宪法 C3：软保底非必出）
	var pools := load("res://data/manufacture_pools.gd")
	var modman := load("res://data/mod_manufacture.gd")
	for pity in [0, 1, 2, 3, 7]:
		var t1: String = pools.describe_card_pity(pity)
		var t2: String = modman.describe_box_pity(pity)
		if t1.is_empty() or t2.is_empty():
			errs.append("pity text empty at %d" % pity)
		if t1.contains("必出") or t2.contains("必出"):
			errs.append("pity text contains 必出 at %d" % pity)
	if not pools.describe_card_pity(2).contains("还差 1 次"):
		errs.append("card pity mid-text missing 还差 1 次")
	if not pools.describe_card_pity(3).contains("已激活"):
		errs.append("card pity active-text missing 已激活")
	if not modman.describe_box_pity(0).contains("传说"):
		errs.append("box pity text missing 传说")
	print("SMOKES2 pity text done")

	# 3) 黑门常量（world_map 黑门弹窗文案数据源——文案改常量自动跟随）
	var ebr := load("res://managers/endless_blackgate_manager.gd")
	if int(ebr.FREE_ENTRIES_PER_DAY) != 3:
		errs.append("FREE_ENTRIES_PER_DAY != 3")
	if int(ebr.ENERGY_PER_EXTRA_ENTRY) != 60:
		errs.append("ENERGY_PER_EXTRA_ENTRY != 60")
	if int(ebr.WEEKLY_MARROW_CAP) != 400:
		errs.append("WEEKLY_MARROW_CAP != 400")
	print("SMOKES3 gate consts done")

	# 4) 遭遇规则常量具名化（game_manager——情报舱分区与 advisor 共用）
	var gm := load("res://managers/game_manager.gd")
	if int(gm.PHASE_MASTER_GRACE_LEVELS) != 10:
		errs.append("GRACE != 10")
	if int(gm.PHASE_MASTER_DROUGHT_TRIGGER) != 5:
		errs.append("DROUGHT_TRIGGER != 5")
	if absf(float(gm.PHASE_MASTER_DROUGHT_STEP) - 0.10) > 0.001:
		errs.append("DROUGHT_STEP != 0.10")
	if absf(float(gm.PHASE_MASTER_ENCOUNTER_CAP) - 0.5) > 0.001:
		errs.append("CAP != 0.5")
	var gcr := load("res://resources/game_constants.gd")
	if absf(float(gcr.PHASE_MASTER_ENCOUNTER_CHANCE) - 0.15) > 0.001:
		errs.append("BASE CHANCE != 0.15")
	print("SMOKES4 encounter consts done")

	# 5) 里程碑 API：跨会话去重 + 持久化回读 + 累计时长口径（v6.19.1 核验修正）
	var pmm := load("res://managers/performance_metrics_manager.gd")
	var tmp_path := "user://milestones_v619_smoke_tmp.cfg"
	var inst = pmm.new()
	inst.milestone_save_path = tmp_path  # 注入临时路径，防覆盖真实档
	inst.record_milestone("smoke_ms")
	inst.record_milestone("smoke_ms")  # 重放安全：只记首次
	if inst.milestone_events.size() != 1:
		errs.append("milestone dedup fail")
	elif int(inst.milestone_events[0].get("total_ms", -1)) < 0:
		errs.append("milestone total_ms negative")
	inst.mark_battle_flag("spedup")
	inst.begin_battle_sampling()
	inst.end_battle_sampling()
	if int(inst.event_counters.get("battles_total", 0)) != 1:
		errs.append("battles_total != 1")
	if int(inst.event_counters.get("battles_sped_or_skipped", 0)) != 1:
		errs.append("battles_sped_or_skipped union fail")
	inst.free()
	# 持久化回读：新实例从同一路径载入应继承 done 集
	var inst2 = pmm.new()
	inst2.milestone_save_path = tmp_path
	inst2._load_milestones()
	if not inst2._milestone_done.has("smoke_ms"):
		errs.append("milestone persistence roundtrip fail")
	inst2.free()
	print("SMOKES5 milestone api done")

	# 6) 递增概率数学（具名常量公式 ≡ 旧内联公式：drought≥5 起 +0.10/关，上限 0.5）
	var check_pairs := {4: 0.15, 5: 0.25, 6: 0.35, 7: 0.45, 8: 0.50, 12: 0.50}
	for d: int in check_pairs:
		var got := 0.15
		if d >= int(gm.PHASE_MASTER_DROUGHT_TRIGGER):
			got = minf(float(gm.PHASE_MASTER_ENCOUNTER_CAP),
				0.15 + (d - int(gm.PHASE_MASTER_DROUGHT_TRIGGER) + 1) * float(gm.PHASE_MASTER_DROUGHT_STEP))
		if absf(got - float(check_pairs[d])) > 0.001:
			errs.append("escalation drought=%d got=%.2f want=%.2f" % [d, got, float(check_pairs[d])])
	print("SMOKES6 escalation math done")

	if errs.is_empty():
		print("V619_SMOKE_OK")
	else:
		for e in errs:
			push_error("[V619_SMOKE] " + e)
		print("V619_SMOKE_FAIL count=%d" % errs.size())
	quit(0 if errs.is_empty() else 1)
