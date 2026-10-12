extends Node
## v6.56 试玩全解锁档·三诉求端到端冒烟（场景模式跑，全 autoload 真启动）。
## 复刻 pw_playtest 导出构建的 GameConfig 全解锁档，跑 save_manager._grant_debug_test_stock()，
## 逐项断言：① 技能树全节点已解锁 ② 商店全可买（功勋+四资源保底）③ 改造蓝图+符文全可见。

func _ready() -> void:
	var ok := true

	# 复刻 export 预设 custom_features="pw_playtest" 在 game_config.get_default() 运行时置的档
	var cfg := GameConfig.get_default()
	cfg.feature_gates_enabled = false
	cfg.power_cap_enabled = false
	cfg.debug_no_deploy_limits = true
	cfg.debug_grant_all_blueprints = true
	cfg.mod_consumable_enabled = false
	cfg.debug_skill_tree_free = true
	cfg.debug_mod_ignore_power_tier = true
	cfg.mod_slot_budget_enabled = false

	const SkillTree = preload("res://data/phase_master_skill_tree.gd")
	const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")
	const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")
	const RuneDefs = preload("res://data/runes.gd")
	const ShopResIds = preload("res://data/basic_resources.gd")

	var save := get_node_or_null("/root/SaveManager")
	if save == null:
		printerr("[V656] FAIL: SaveManager autoload 缺失")
		get_tree().quit(1)
		return
	save._grant_debug_test_stock()
	# 让 unlock_node 的 call_deferred(_apply_unlocks) 排空（效果派发/子系统接线在帧末）
	await get_tree().process_frame
	await get_tree().process_frame

	var pmsm: Node = get_node_or_null("/root/PhaseMasterSkillManager")
	var bag: Node = get_node_or_null("/root/IntelItemBag")
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	var brm: Node = get_node_or_null("/root/BasicResourceManager")
	if [pmsm, bag, pim, fsm, brm].any(func(n): return n == null):
		printerr("[V656] FAIL: 关键 autoload 缺失 pmsm=%s bag=%s pim=%s fsm=%s brm=%s" % [pmsm != null, bag != null, pim != null, fsm != null, brm != null])
		get_tree().quit(1)
		return

	# ① 技能树全解锁
	var all_ids: Array = SkillTree.get_all_node_ids()
	var unlocked_cnt := 0
	for nid in all_ids:
		if pmsm.is_unlocked(String(nid)):
			unlocked_cnt += 1
	print("[V656] 技能: 已解锁=", unlocked_cnt, "/", all_ids.size(),
		" (get_available_points=", pmsm.get_available_points(), ")")
	if unlocked_cnt < all_ids.size():
		printerr("[V656] FAIL: 技能未全解锁，还差 ", all_ids.size() - unlocked_cnt, " 个")
		ok = false

	# ② 商店全可买：四资源保底 99999 + 功勋合计保底
	var res_floor_ok := true
	for rid in [ShopResIds.ID_NANO_MATERIALS, ShopResIds.ID_ALLOY,
			ShopResIds.ID_CRYSTAL, ShopResIds.ID_ENERGY_BLOCK]:
		var cur: int = int(brm.get_total(rid))
		print("[V656] 资源 ", rid, " = ", cur)
		if cur < 99999:
			res_floor_ok = false
	var merit_total: int = int(fsm.get_merit_points())
	print("[V656] 功勋合计=", merit_total)
	if not res_floor_ok:
		printerr("[V656] FAIL: 有资源未达 99999 保底")
		ok = false
	if merit_total < 99999:
		printerr("[V656] FAIL: 功勋合计未达保底 ", merit_total)
		ok = false

	# ③ 改造蓝图全可见（排除 enhancement 族）+ 符文全可见
	var mod_bp_total := 0
	var mod_bp_missing: Array = []
	for mod_id in ModificationRegistry.get_all_ids():
		if String(ModificationRegistry.get_data(mod_id).get("source", "")) == "enhancement":
			continue
		mod_bp_total += 1
		var bp: String = BlueprintDefinitions.get_mod_blueprint_id(mod_id)
		if bp.is_empty():
			continue
		if not bag.has_item(bp):
			mod_bp_missing.append(String(mod_id))
	print("[V656] 改造蓝图: 应入包=", mod_bp_total, " 缺=", mod_bp_missing.size())
	if not mod_bp_missing.is_empty():
		printerr("[V656] FAIL: 缺改造蓝图: ", mod_bp_missing.slice(0, 10))
		ok = false

	var rune_total := 0
	var rune_missing: Array = []
	for rune in RuneDefs.ALL_RUNES:
		rune_total += 1
		var rid_rune: String = String(rune.get("id", ""))
		if rid_rune.is_empty() or not pim.has_rune(rid_rune):
			rune_missing.append(rid_rune)
	print("[V656] 符文: 应拥有=", rune_total, " 缺=", rune_missing.size())
	if not rune_missing.is_empty():
		printerr("[V656] FAIL: 缺符文: ", rune_missing.slice(0, 10))
		ok = false

	print("V656_PLAYTEST_FULL_OK" if ok else "V656_PLAYTEST_FULL_FAIL")
	get_tree().quit(0 if ok else 1)
