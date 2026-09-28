extends SceneTree
## 记录5#1 冒烟：卡片技能触发条件文案（--script 直跑，不依赖 autoload）
## 验证：4 改动文件可编译 + get_trigger_condition 各分支断言

func _init() -> void:
	var fails: Array[String] = []

	# 1) 四文件编译
	for p in [
		"res://data/card_periodic_skills.gd",
		"res://data/unlock_labels.gd",
		"res://scenes/ui/phase_master_skill_panel.gd",
		"res://scenes/ui/card_info_panel.gd",
	]:
		var s = load(p)
		if s == null:
			fails.append("load 失败: %s" % p)
		else:
			print("OK load: ", p)

	# 2) get_trigger_condition 分支断言
	var CPS = load("res://data/card_periodic_skills.gd")

	var cond_railgun: String = CPS.get_trigger_condition("cps_railgun")
	if cond_railgun != "需场上狙击在场":
		fails.append("railgun 条件异常: %s" % cond_railgun)

	var cond_storm: String = CPS.get_trigger_condition("cps_steel_storm")
	if cond_storm != "无需特定兵种，友军进场即触发":
		fails.append("steel_storm(空tag) 条件异常: %s" % cond_storm)

	var cond_flame: String = CPS.get_trigger_condition("cps_burn_city")
	if cond_flame != "需场上火炮（或激活火焰势力）在场":
		fails.append("burn_city(flame) 条件异常: %s" % cond_flame)

	var cond_thunder: String = CPS.get_trigger_condition("cps_chain_lightning")
	if cond_thunder != "需场上防空/电子战（或激活雷霆势力）在场":
		fails.append("chain_lightning(thunder) 条件异常: %s" % cond_thunder)

	var cond_void: String = CPS.get_trigger_condition("cps_time_rewind")
	if cond_void != "需场上狙击/渗透（或激活虚空势力）在场":
		fails.append("time_rewind(void) 条件异常: %s" % cond_void)

	var cond_unknown: String = CPS.get_trigger_condition("nonexistent_id")
	if cond_unknown != "无需特定兵种，友军进场即触发":
		fails.append("未知 id 条件异常: %s" % cond_unknown)

	# 3) 全部 21 个 cps 的条件非空且不含裸 tag 名
	for sid in CPS.get_all_skill_ids():
		var c: String = CPS.get_trigger_condition(sid)
		if c.is_empty():
			fails.append("条件为空: %s" % sid)
		if "source_tag" in c or "_x" in c:
			fails.append("条件含裸内部键名: %s -> %s" % [sid, c])

	# 4) unlock_labels.get_unlocked_summary 的 card_skill desc 附条件
	var UL = load("res://data/unlock_labels.gd")
	# pms_fp_9a → cps_railgun
	var summary: Array = UL.get_unlocked_summary(["pms_fp_9a"])
	var found := false
	for item in summary:
		if String(item.get("id", "")) == "cps_railgun":
			found = true
			var d: String = String(item.get("desc", ""))
			if not d.contains("需场上狙击在场"):
				fails.append("总览 desc 未附条件: %s" % d)
	if not found:
		fails.append("总览未含 cps_railgun 条目")

	if fails.is_empty():
		print("V632_RECORD5_SMOKE_OK (all assertions passed)")
	else:
		for f in fails:
			printerr("FAIL: ", f)
		print("V632_RECORD5_SMOKE_FAILED (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
