extends Node
## v6.14.7 修复端到端探针（可删）：①部署次数池兑底 ②直入卡制造 roll
## 随场景跑完整 autoload 环境，断言全过打印 PROBE-OK，任何失败 PROBE-FAIL。

class MockPI extends Node:
	var los: Array = []
	func get_loadouts() -> Array:
		return los

func _check(cond: bool, tag: String) -> void:
	if cond:
		print("  PASS: " + tag)
	else:
		push_error("PROBE-FAIL: " + tag)
		print("  FAIL: " + tag)

func _ready() -> void:
	var UCT = load("res://data/unified_card_table.gd")
	var MP = load("res://data/manufacture_pools.gd")
	print("== 1. deploy_uses 兑底 ==")
	var BSS = load("res://managers/battle/battle_spawn_system.gd").new()
	var pi := MockPI.new()
	# a) 缴获卡（captured_ 前缀，应剥前缀命中真身条目）
	var cap: CardResource = UCT.build_card_resource("ww1_inf_storm_e")
	cap.card_id = "captured_ww1_inf_storm_e"
	cap.instance_id = ""
	# b) fe_ 势力卡（UCT 全域查不到，应走 combat_kind 基线）
	var GC = load("res://resources/game_constants.gd")
	var fe := CardResource.new()
	fe.card_id = "fe_iron_wall_bastion"
	fe.combat_kind = GC.CombatKind.FORT
	fe.instance_id = ""
	pi.los = [{"platform": cap}, {"platform": fe}]
	BSS._phase_instrument = pi
	BSS._signal_bus = null
	BSS._reset_deploy_uses()
	_check(BSS._has_deploy_uses("captured_ww1_inf_storm_e"), "缴获卡入池可部署 (uses=%d)" % BSS._deploy_uses_remaining.get("captured_ww1_inf_storm_e", -1))
	_check(BSS._has_deploy_uses("fe_iron_wall_bastion"), "fe_ 卡入池可部署 (uses=%d)" % BSS._deploy_uses_remaining.get("fe_iron_wall_bastion", -1))
	_check(int(BSS._get_deploy_uses_total("captured_ww1_inf_storm_e")) > 0, "total 查询同样兑底")
	_check(int(BSS._deploy_uses_remaining.get("captured_ww1_inf_storm_e", -1)) == UCT.get_deploy_uses(UCT.get_entry("ww1_inf_storm_e"), cap), "缴获卡次数=真身条目口径")

	print("== 2. 直入卡制造 roll ==")
	var mll: Node = get_node_or_null("/root/ManagerLazyLoader")
	if mll != null:
		mll.ensure_loaded("manufacture")
	# 挂树可能走 call_deferred，等两帧让节点进树且 _ready 建好配方索引
	await get_tree().process_frame
	await get_tree().process_frame
	var mm: Node = get_node_or_null("/root/ManufactureManager")
	_check(mm != null, "ManufactureManager 懒加载成功")
	if mm != null:
		var direct := ""
		for rid in mm.get_recipe_ids():
			if mm.is_direct_pool_card(String(rid)):
				var c: CardResource = load("res://data/default_cards.gd").get_card_by_id(String(rid))
				if c != null and int(c.era) == 0:
					direct = String(rid)
					break
		_check(direct != "", "找到 era0 直入卡样本: " + direct)
		if direct != "":
			_check(mm.is_direct_pool_card(direct), "is_direct_pool_card")
			_check(absf(float(mm.get_intel_base(direct))) < 0.001, "get_intel_base==0（复现条件）")
			_check(absf(float(mm._pool_base(direct)) - MP.GATE_RECIPE) < 0.001, "_pool_base==白板档 0.25")
			var r_old: String = MP.roll_rarity(0.0, 0, 1.0)
			var r_new: String = MP.roll_rarity(float(mm._pool_base(direct)), 0, 1.0)
			_check(r_old == "", "旧行为复现：裸 intel roll 空（修前必失败）")
			_check(r_new != "", "新行为：_pool_base roll 成功（rarity=%s）" % r_new)
			_check(not mm.get_effective_pool(direct).is_empty(), "UI 有效池非空（预览与 roll 同源）")
			# 端到端：补资源后真实 manufacture
			var BRM: Node = get_node_or_null("/root/BasicResourceManager")
			_check(BRM != null, "BasicResourceManager 就绪")
			if BRM != null:
				BRM.add_resource("nano_materials", 500)
				BRM.add_resource("energy_block", 200)
			var res: Dictionary = mm.manufacture(direct)
			_check(bool(res.get("ok", false)), "manufacture() 端到端成功 (%s)" % str(res.get("reason_zh", "")))
	print("PROBE-DONE")
	get_tree().quit(0)
