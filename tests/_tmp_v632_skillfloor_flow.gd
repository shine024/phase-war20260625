extends Node
## v6.32.2 试玩技能点保底流程冒烟：真 autoload 环境端到端（场景模式跑，非 --script）。
## 验证 save_manager._grant_debug_test_stock() ⑥ 块：技能点补到全树总花费、幂等不叠加。

func _ready() -> void:
	var ok := true

	# ① 全树总花费（与 save_manager ⑥ 块同口径）
	var tree: Script = preload("res://data/phase_master_skill_tree.gd")
	var total := 0
	var node_count := 0
	for branch in tree.get_all_branches():
		for node in tree.get_skills_for_branch(String(branch)):
			total += int(node.get("cost", 1))
			node_count += 1
	print("[V632FLOW] 技能树节点=", node_count, " 总花费=", total,
		" 满级上限=", tree.max_skill_points_at_phase_field_level(30))
	if total < 180 or node_count < 80:
		printerr("[V632FLOW] FAIL: 技能树规模异常")
		ok = false

	# ② 真管理器：模拟 pw_playtest 全解锁档后调补库
	var pmsm: Node = get_node_or_null("/root/PhaseMasterSkillManager")
	var save: Node = get_node_or_null("/root/SaveManager")
	if pmsm == null or save == null:
		printerr("[V632FLOW] FAIL: autoload 缺失 pmsm=%s save=%s" % [pmsm, save])
		ok = false
	else:
		var bonus_before: int = pmsm.get_bonus_points()
		GameConfig.get_default().debug_grant_all_blueprints = true
		save._grant_debug_test_stock()
		var bonus_after: int = pmsm.get_bonus_points()
		var available: int = pmsm.get_available_points()
		print("[V632FLOW] bonus_before=", bonus_before, " bonus_after=", bonus_after,
			" available=", available, " phase_field_lv=", pmsm._phase_field_level)
		if bonus_after < total:
			printerr("[V632FLOW] FAIL: 保底后点数不足全树花费")
			ok = false
		if available < total:
			printerr("[V632FLOW] FAIL: 可用点数不足全树花费（被 spent 抵扣？）")
			ok = false
		# ③ 幂等：再跑一次不叠加
		save._grant_debug_test_stock()
		var bonus_again: int = pmsm.get_bonus_points()
		print("[V632FLOW] 幂等复跑 bonus=", bonus_again)
		if bonus_again != bonus_after:
			printerr("[V632FLOW] FAIL: 幂等破坏，bonus 发生叠加")
			ok = false
		# ④ 花点模拟：全树顺序解锁应全部成功（前置链跨分支，多轮迭代直到收敛）
		var all_nodes: Array = []
		for branch in tree.get_all_branches():
			for node in tree.get_skills_for_branch(String(branch)):
				all_nodes.append(String(node.get("id", "")))
		var spent_ok := 0
		var spent_fail: Array = []
		for pass_i in range(6):
			var progressed := false
			spent_fail = []
			for nid in all_nodes:
				if pmsm.unlock_node(nid):
					spent_ok += 1
					progressed = true
				elif not String(nid) in pmsm._unlocked_nodes:
					spent_fail.append(String(nid))
			if not progressed:
				break
		print("[V632FLOW] 全树解锁尝试: 成功=", spent_ok, " 失败=", spent_fail)
		if not spent_fail.is_empty():
			printerr("[V632FLOW] FAIL: 有点数仍解锁失败（前置链以外的门？）: ", spent_fail)
			ok = false

	print("V632_FLOW_OK" if ok else "V632_FLOW_FAIL")
	get_tree().quit(0 if ok else 1)
