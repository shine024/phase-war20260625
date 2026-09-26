extends SceneTree
## v6.25 记录5 冒烟:逐个 load() 本轮改动文件(纯 parse 校验,不实例化、不碰 autoload)
## --headless --rendering-driver opengl3 --script tests/_tmp_v625_smoke.gd

func _init() -> void:
	var files := [
		"res://scenes/ui/intelligence_hub_panel.gd",
		"res://managers/toast_manager.gd",
		"res://managers/lore_manager.gd",
		"res://data/intel_reveal_events.gd",
		"res://scripts/systems/modification_registry.gd",
		"res://resources/card_resource.gd",
		"res://scenes/ui/faction_panel.gd",
		"res://scenes/ui/quest_panel.gd",
		"res://scenes/ui/collection_panel.gd",
		"res://scenes/ui/store_panel.gd",
		"res://scenes/bunker/truck_base.gd",
		"res://managers/tutorial_progression_manager.gd",
		"res://scenes/ui/bottom_instrument_bar.gd",
		"res://scenes/ui/leaderboard/leaderboard_panel.gd",
		"res://scenes/ui/leaderboard/faction_row.gd",
		"res://scenes/ui/leaderboard/leaderboard_presenter.gd",
		"res://scenes/ui/achievement_panel.gd",
		"res://scenes/ui/backpack_card_item.gd",
		"res://scenes/ui/backpack_panel.gd",
		"res://scenes/ui/evolution_panel.tscn",
	]
	var fails := 0
	for f in files:
		var res = ResourceLoader.load(f, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null:
			printerr("FAIL load: " + f)
			fails += 1
		else:
			print("ok: " + f)
	# 关键断言
	var reg = ResourceLoader.load("res://scripts/systems/modification_registry.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	# 单边时代规则:band 上限 >= 卡时代即可装(记录5#17)
	assert(reg.is_mod_era_compatible({"era_band": [3, 4]}, 0) == true, "未来改造可装一战卡")
	assert(reg.is_mod_era_compatible({"era_band": [0, 1]}, 3) == false, "旧改造拒装新卡")
	assert(reg.is_mod_era_compatible({"era_band": [2, 3]}, 2) == true, "带内可装")
	assert(reg.is_mod_era_compatible({}, 4) == true, "无 band 全兼容")
	# lore_page 奖励 7 条
	var ev = ResourceLoader.load("res://data/intel_reveal_events.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	var lore_n := 0
	for key in ev.REVEAL_EVENTS:
		for r in ev.REVEAL_EVENTS[key].get("rewards", []):
			if r.get("type", "") == "lore_page":
				lore_n += 1
	assert(lore_n == 7, "7 条 tier-3 lore_page,实际 %d" % lore_n)
	# grant_random_lore 方法存在
	var lm = ResourceLoader.load("res://managers/lore_manager.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	assert(lm.new().has_method("grant_random_lore"), "grant_random_lore 存在")
	print("=== v625 smoke: %d fails ===" % fails)
	if fails == 0:
		print("ALL PASS")
	quit(1 if fails > 0 else 0)
