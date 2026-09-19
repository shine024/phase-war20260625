extends SceneTree
## v37 实机验收修复批4 加载冒烟（--script 模式，不启动全部 autoload）
## 断言：改动脚本可编译加载 + 节奏表/掉落乘区/掉落视觉/教程文案关键值正确。

func _initialize() -> void:
	var errs: Array[String] = []

	# 1) 全部改动脚本可编译加载
	for p: String in [
		"res://data/feature_unlock_schedule.gd",
		"res://scripts/systems/intel_manual.gd",
		"res://managers/save_manager.gd",
		"res://data/level_eras.gd",
		"res://scripts/battle/ground_loot_layer.gd",
		"res://scenes/main.gd",
		"res://scenes/bunker/truck_base.gd",
		"res://scenes/ui/bottom_function_bar.gd",
		"res://managers/tutorial_progression_manager.gd",
		"res://scenes/intro/comic_intro.gd",
		"res://scenes/intro/dream_battle.gd",
		"res://scenes/ui/help_panel.gd",
	]:
		if load(p) == null:
			errs.append("load fail: " + p)

	# 2) 节奏表新阈值（v37：制造/情报 L2，改造 L6）
	var fus := load("res://data/feature_unlock_schedule.gd")
	if int(fus.unlock_level_for("evolution")) != 2:
		errs.append("evolution unlock != 2")
	if int(fus.unlock_level_for("intelligence")) != 2:
		errs.append("intelligence unlock != 2")
	if int(fus.unlock_level_for("modification")) != 6:
		errs.append("modification unlock != 6")
	if int(fus.unlock_level_for("afk")) != 5:
		errs.append("afk unlock != 5")

	# 3) WW1 掉落乘区 0.85→0.70（Era.WW1 = 0）
	var le := load("res://data/level_eras.gd")
	if absf(float(le.ERA_DROP_MULTIPLIER[0]) - 0.70) > 0.001:
		errs.append("WW1 drop mult != 0.70")

	# 4) 掉落视觉：货币档缩小 + 常量在位
	var gll := load("res://scripts/battle/ground_loot_layer.gd")
	var nano: Array = gll.CURRENCY_PX_NANO
	var batt: Array = gll.CURRENCY_PX_BATTERY
	if absf(float(nano[0]) - 14.0) > 0.001 or absf(float(nano[2]) - 23.0) > 0.001:
		errs.append("CURRENCY_PX_NANO 未缩小")
	if absf(float(batt[0]) - 16.0) > 0.001 or absf(float(batt[2]) - 26.0) > 0.001:
		errs.append("CURRENCY_PX_BATTERY 未缩小")

	# 5) 情报地板 API + 配方门常量
	var im = load("res://scripts/systems/intel_manual.gd").new()
	if not im.has_method("grant_intel_floor"):
		errs.append("IntelManual.grant_intel_floor 缺失")
	else:
		im.grant_intel_floor("pw_smoke_arch", 0.25)
		if absf(float(im.get_intel_progress("pw_smoke_arch")) - 0.25) > 0.0001:
			errs.append("grant_intel_floor 未抬到 0.25")
		im.grant_intel_floor("pw_smoke_arch", 0.10)
		if absf(float(im.get_intel_progress("pw_smoke_arch")) - 0.25) > 0.0001:
			errs.append("grant_intel_floor 会降级（应只抬不降）")
	im.free()
	var mp := load("res://data/manufacture_pools.gd")
	if absf(float(mp.GATE_RECIPE) - 0.25) > 0.0001:
		errs.append("GATE_RECIPE != 0.25")
	if int(mp.get_pool_tier(0.25)) != 1:
		errs.append("get_pool_tier(0.25) != 1")

	# 6) 教程文案关键值（ENHANCEMENT=4 技能树步 / FIRST_BATTLE=7 含 HUD 指认 / TRUCK_BASE=14）
	var tpm = load("res://managers/tutorial_progression_manager.gd").new()
	tpm._initialize_tutorial_data()
	var tdata: Dictionary = tpm.tutorial_data
	if String(tdata[4].get("title", "")) != "相位师技能树":
		errs.append("ENHANCEMENT 步标题未改：技能树")
	if String(tdata[4].get("action_text", "")) != "打开技能树":
		errs.append("ENHANCEMENT 步按钮文案未改")
	if String(tdata[7].get("description", "")).find("底部左") < 0:
		errs.append("FIRST_BATTLE 步缺战斗 HUD 指认文案")
	if String(tdata[14].get("description", "")).find("技能树") < 0:
		errs.append("TRUCK_BASE 步未指向技能树")
	tpm.free()

	# 7) 底栏技能键文案
	var bfb := load("res://scenes/ui/bottom_function_bar.gd")
	var found := false
	for cfg in bfb.BTN_CONFIGS:
		if String(cfg[0]) == "progression" and String(cfg[1]) == "技能":
			found = true
	if not found:
		errs.append("底栏 progression 键未改「技能」")

	if errs.is_empty():
		print("V37_SMOKE_OK")
		quit(0)
	else:
		for e in errs:
			printerr("V37_SMOKE_FAIL: " + e)
		quit(1)
