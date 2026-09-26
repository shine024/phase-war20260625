extends SceneTree
## v6.24 商店测试补库冒烟（--script 直跑，无 autoload）：
## ① 两改动文件可编译加载；② FSM.debug_ensure_shop_test_stock 行为断言：
##    贡献抬满 MAX_REPUTATION / 功勋抬到 SHOP_TEST_MERIT_FLOOR / 只抬不降 / 开关关闭早退。

func _initialize() -> void:
	var errs := 0
	var fsm_script: Script = load("res://managers/faction_system_manager.gd")
	if fsm_script == null:
		print("[smoke][FAIL] faction_system_manager.gd 编译失败")
		quit(1)
		return
	var save_script: Script = load("res://managers/save_manager.gd")
	if save_script == null:
		print("[smoke][FAIL] save_manager.gd 编译失败")
		quit(1)
		return

	# 打开测试补库开关（正式构建默认 false；pw_playtest 构建运行期置 true）
	var cfg: GameConfig = GameConfig.get_default()
	cfg.debug_grant_all_blueprints = true

	var fsm: Node = fsm_script.new()
	fsm._all_faction_ids = ["iron_wall_corp", "nova_arms", "aether_dynamics",
		"quantum_logistics", "helix_recon", "void_research", "solaris_biological"]
	for fid in fsm._all_faction_ids:
		fsm.faction_reputation[fid] = 5000
		fsm.merit_by_faction[fid] = 100
	fsm.debug_ensure_shop_test_stock()
	for fid in fsm._all_faction_ids:
		var rep: int = int(fsm.faction_reputation.get(fid, 0))
		var merit: int = int(fsm.merit_by_faction.get(fid, 0))
		if rep < FactionReputation.MAX_REPUTATION:
			print("[smoke][FAIL] %s 贡献未抬满: %d" % [fid, rep]); errs += 1
		if merit < fsm.SHOP_TEST_MERIT_FLOOR:
			print("[smoke][FAIL] %s 功勋未达保底: %d" % [fid, merit]); errs += 1

	# 只抬不降：已有更高值不被拉低
	fsm.merit_by_faction["iron_wall_corp"] = 123456
	fsm.debug_ensure_shop_test_stock()
	if int(fsm.merit_by_faction["iron_wall_corp"]) != 123456:
		print("[smoke][FAIL] 只抬不降语义被违反"); errs += 1

	# 开关关闭（正式构建）：应早退零影响
	cfg.debug_grant_all_blueprints = false
	fsm.merit_by_faction["nova_arms"] = 5
	fsm.faction_reputation["nova_arms"] = 10
	fsm.debug_ensure_shop_test_stock()
	if int(fsm.merit_by_faction["nova_arms"]) != 5 or int(fsm.faction_reputation["nova_arms"]) != 10:
		print("[smoke][FAIL] flag=false 应早退不改动"); errs += 1

	print("V624_SHOP_TEST_SMOKE_%s errs=%d" % ["OK" if errs == 0 else "FAIL", errs])
	quit(0 if errs == 0 else 1)
