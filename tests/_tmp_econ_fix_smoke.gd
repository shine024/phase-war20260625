extends SceneTree
## 2026-09-19 经济/掉落/教程修复批验证冒烟（--script 模式，纯逻辑断言）
## 覆盖：P0-1 fragment 池真卡化发放 / P0-3 kit 双向查 / P1-4 黑门软门状态机 /
## P2-7 首通合金 / P2-8 功勋材料包三方自洽 / P2-13 count_by_prefix /
## P3-14 遗留首通发放已删 / P3-15 掉落池 id 全解析 / P3-21 教程门控豁免查询

const FirstClearRewards = preload("res://data/first_clear_rewards.gd")
const DropTables = preload("res://resources/drop_tables.gd")
const FactionShop = preload("res://managers/faction/faction_shop.gd")
const EndlessBlackgateManager = preload("res://managers/endless_blackgate_manager.gd")
const CardDropGrants = preload("res://scripts/card_drop_grants.gd")
const DefaultCards = preload("res://data/default_cards.gd")

var _pass: int = 0
var _fail: int = 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  ❌ FAIL: " + msg)

func _initialize() -> void:
	print("=== 经济/掉落修复批冒烟 ===")

	# ── P2-7: 首通奖励含合金 ──
	var r1: Dictionary = FirstClearRewards.get_first_clear_reward(1)
	_check(int(r1.get("alloy", -1)) == 17, "首通 L1 合金=17")
	_check(int(r1.get("crystal", -1)) == 22, "首通 L1 晶体=22（回归）")
	_check(String(FirstClearRewards.format_reward_text(r1)).contains("合金 17"), "format_reward_text 含合金")

	# ── P3-15: 掉落池 id 全解析 + 旧 id 清理 ──
	var dt = DropTables.new()
	for pair in [["ww1", dt.ww1_common_drops], ["ww2", dt.ww2_common_drops], ["cold", dt.cold_war_common_drops], ["mod", dt.modern_common_drops], ["fut", dt.near_future_common_drops]]:
		_check((pair[1] as Array).size() > 0, "%s 池非空" % pair[0])
	var era4: Array = DropTables.ERA_BLUEPRINT_IDS[4]
	_check(not era4.has("fut_scout_drone"), "era4 数组已删 fut_scout_drone（跨时代错位）")
	_check(not String(JSON.stringify(DropTables.ERA_BLUEPRINT_IDS)).contains("ww2_tiger"), "era 数组无旧 id ww2_tiger")
	var drops: Array = dt.generate_drops(0, 5, true, 3)
	_check(drops.size() >= 1, "era0 L5 生成掉落 >=1（实际 %d）" % drops.size())

	# ── P0-1: fragment 池真卡化——四档池 id 全部可解析为卡 + 函数调用不炸 ──
	for fid in ["common_fragment", "rare_fragment", "epic_fragment", "legendary_fragment"]:
		var ids: Array = CardDropGrants.LEGACY_FRAGMENT_REWARD_POOLS[fid]
		_check(not (ids as Array).is_empty(), "%s 池非空" % fid)
		for cid in ids:
			_check(DefaultCards.get_card_by_id(String(cid)) != null, "%s 池 id %s 可解析为真卡" % [fid, cid])
	CardDropGrants.grant_from_legacy_fragment_reward_pool("common_fragment", 1)  # 全链路不炸（发放走 DropManager 管线）

	# ── P0-3: kit 双向查（配装表 foe_ 键与裸键都能命中） ──
	var efl = load("res://data/enemy_fixed_loadouts.gd")
	var kit_foe: Array = efl.get_mods_for_tier("foe_ww1_arm_rolls", 1)
	var kit_bare: Array = efl.get_mods_for_tier("ww1_inf_mp18", 1)
	_check(not kit_foe.is_empty(), "配装表 foe_ 键可命中（%d 条）" % kit_foe.size())
	_check(not kit_bare.is_empty(), "配装表裸键可命中（%d 条）" % kit_bare.size())

	# ── P1-4: 黑门软门状态机 ──
	var ebm = EndlessBlackgateManager.new()
	var st0: Dictionary = ebm.get_entry_status()
	_check(int(st0["free_left"]) == 3, "初始免费 3 次")
	_check(bool(ebm.consume_entry_for_begin()), "第 1 次入场")
	_check(bool(ebm.consume_entry_for_begin()), "第 2 次入场")
	_check(bool(ebm.consume_entry_for_begin()), "第 3 次入场")
	_check(not bool(ebm.consume_entry_for_begin()), "第 4 次入场被拒（免费耗尽且无购次）")
	_check(not bool(ebm.get_entry_status()["can_enter"]), "can_enter=false")
	ebm._extra_entries = 1
	_check(bool(ebm.consume_entry_for_begin()), "购次后可入场")
	_check(int(ebm.get_entry_status()["extra_left"]) == 0, "购次消耗")
	ebm.free()

	# ── P2-8: 功勋材料包三方自洽（品名数量 == 功勋价） ──
	for fid in ["iron_wall_corp", "nova_arms", "quantum_logistics", "frontier_union"]:
		var items: Array = FactionShop.get_faction_store_items(fid, 5)
		for it in items:
			if it.item_type == 1:  # StoreItemType.MATERIAL
				var name_str: String = it.display_name if "display_name" in it else str(it.item_id)
				var m := RegEx.create_from_string("x(\\d+)$").search(name_str)
				if m != null:
					_check(int(m.get_string(1)) == int(it.reputation_cost),
						"%s 材料包自洽: %s 价=%d" % [fid, name_str, int(it.reputation_cost)])

	# ── P2-13: IntelItemBag.count_by_prefix（运行时 load，合法蓝图 id） ──
	var bag = load("res://managers/intel_item_bag.gd").new()
	bag.add_item("blueprint_inf_01_submachine_gun", 3)
	bag.add_item("blueprint_inf_02_assault_rifle", 2)
	_check(int(bag.count_by_prefix("blueprint_")) == 5, "count_by_prefix blueprint_=5（实际 %d）" % int(bag.count_by_prefix("blueprint_")))
	_check(int(bag.count_by_prefix("blueprint_evol_")) == 0, "count_by_prefix 排除进化蓝图")
	bag.free()

	# ── P3-14: 遗留首通发放已删（load 运行时实例；函数不存在 + 记账结构保留） ──
	var lpm = load("res://managers/level_progress_manager.gd")
	if lpm != null and lpm.can_instantiate():
		var lpm_i = lpm.new()
		_check(not lpm_i.has_method("_grant_first_completion_rewards"), "_grant_first_completion_rewards 已删")
		lpm_i.complete_level(3, 2)
		_check(bool(lpm_i.first_completion.get(3, false)), "complete_level 仍记账 first_completion")
		_check(lpm_i.get_level_stars(3) == 2, "星级记账回归")
		lpm_i.free()
	else:
		_check(false, "level_progress_manager 编译失败")

	# ── P3-21: 教程门控豁免查询（load 运行时实例） ──
	var tpm_s = load("res://managers/tutorial_progression_manager.gd")
	if tpm_s != null and tpm_s.can_instantiate():
		var tpm = tpm_s.new()
		tpm.current_step = tpm_s.TutorialStep.MODIFICATION
		_check(tpm.is_tutorial_surface("modification"), "教程 MODIFICATION 步豁免 modification")
		_check(tpm.is_tutorial_surface("faction"), "教程链未来步 faction 也豁免")
		_check(not tpm.is_tutorial_surface("affix"), "非教程面不豁免")
		tpm.current_step = tpm_s.TutorialStep.FREEDOM_MODE
		_check(not tpm.is_tutorial_surface("modification"), "教程完成后不豁免")
		tpm.free()
	else:
		_check(false, "tutorial_progression_manager 编译失败")

	# ── P2-10/P3-16: 死代码清理核实（调用形态模式，避免注释文本误报） ──
	var ebm_src := FileAccess.get_file_as_string("res://managers/endless_blackgate_manager.gd")
	_check(not ebm_src.contains(".spend_resource("), "endless_blackgate 无 spend_resource 调用")
	var bm_src := FileAccess.get_file_as_string("res://managers/blueprint_manager.gd")
	_check(not bm_src.contains(".spend_resource("), "blueprint_manager 无 spend_resource 调用")
	var mm_src := FileAccess.get_file_as_string("res://managers/manufacture_manager.gd")
	_check(not mm_src.contains(".spend_resource("), "manufacture_manager 无 spend_resource 调用")
	var dm_src := FileAccess.get_file_as_string("res://managers/drop_manager.gd")
	_check(not dm_src.contains("func set_multiplier"), "set_multiplier 函数已删")
	_check(not dm_src.contains("var _story_reward_multiplier"), "_story_reward_multiplier 成员已删")

	print("=== 结果: %d PASS / %d FAIL ===" % [_pass, _fail])
	print("ECON_FIX_SMOKE_OK" if _fail == 0 else "ECON_FIX_SMOKE_FAILED")
	quit(0 if _fail == 0 else 1)
