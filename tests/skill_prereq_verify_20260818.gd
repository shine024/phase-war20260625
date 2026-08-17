extends SceneTree
## 2026-08-18 技能树前置提示修复验证：用真实存档状态（save_slot_1）模拟
## _format_missing_requires 的输出，确认跨分支前置被正确点名。
## 运行：Godot_console.exe --headless --path . --script tests/skill_prereq_verify_20260818.gd

const SkillTree = preload("res://data/phase_master_skill_tree.gd")

## save_slot_1.json /phase_master_skill/unlocked_nodes 快照（2026-08-18）
const SAVE_UNLOCKED := ["pms_fp_0", "pms_fp_1a", "pms_fp_2", "pms_fp_3", "pms_fp_4",
	"pms_fp_5", "pms_fp_6", "pms_fp_7a", "pms_fp_7b", "pms_fp_8", "pms_fp_9c",
	"pms_fp_9a", "pms_fp_9b", "pms_fp_10", "pms_fp_11", "pms_fp_12"]

func _init() -> void:
	var pass_cnt := 0
	var fail_cnt := 0

	# 复刻 phase_master_skill_panel._format_missing_requires 的逻辑
	# （面板脚本依赖 autoload 无法在 --script 模式加载，此处用同一算法验证输出）
	var mgr := {"unlocked": SAVE_UNLOCKED}  # 模拟 manager.is_unlocked

	var cases := {
		"pms_cw_1": "战术核武",
		"pms_cw_0": "奇点解算（门关）",
		"pms_cw_6": "焚城（核武后续）",
		"pms_fp_9b": "超视距打击（已满足前置）",
	}
	for nid: String in cases:
		var node: Dictionary = SkillTree.get_skill(nid)
		var missing: Array = []
		for req in node.get("requires", []):
			if not (String(req) in mgr["unlocked"]):
				var rn: Dictionary = SkillTree.get_skill(String(req))
				missing.append("%s（%s分支）" % [rn.get("name", req),
					SkillTree.get_branch_display_name(SkillTree.get_branch_of(String(req)))])
		var text: String = "、".join(missing)
		print("[%s] %s → 前置未满足：%s" % [nid, cases[nid], text if not text.is_empty() else "（无）"])

	# 断言：战术核武缺的必须点名"奇点解算（智能化分支）"
	var cw1: Dictionary = SkillTree.get_skill("pms_cw_1")
	var miss_cw1: Array = []
	for req in cw1.get("requires", []):
		if not (String(req) in SAVE_UNLOCKED):
			miss_cw1.append(String(req))
	var ok1: bool = miss_cw1 == ["pms_cw_0"]
	print("[ASSERT] 战术核武缺失前置 = [pms_cw_0]:", " PASS" if ok1 else " FAIL %s" % str(miss_cw1))
	ok1 = ok1 and SkillTree.get_branch_of("pms_cw_0") == "intelligence"
	print("[ASSERT] pms_cw_0 位于智能化分支:", " PASS" if ok1 else " FAIL")
	if ok1: pass_cnt += 1
	else: fail_cnt += 1

	# 断言：从存档状态出发，点亮门关链路后战术核武可解锁（数据可达性）
	var extended: Array = SAVE_UNLOCKED.duplicate()
	for gate_req in ["pms_cmd_0", "pms_cmd_1a", "pms_cmd_2", "pms_int_0", "pms_int_1a", "pms_int_2", "pms_cw_0"]:
		extended.append(gate_req)
	var cw1_reqs: Array = cw1.get("requires", [])
	var all_met: bool = true
	for req in cw1_reqs:
		if not (String(req) in extended):
			all_met = false
	print("[ASSERT] 补齐三系tier2+门关后战术核武前置全满足:", " PASS" if all_met else " FAIL")
	if all_met: pass_cnt += 1
	else: fail_cnt += 1

	# 断言：点数够（52可用 ≥ 门关链10 + 核武4）
	var cost_total: int = 0
	for nid2 in ["pms_cmd_0", "pms_cmd_1a", "pms_cmd_2", "pms_int_0", "pms_int_1a", "pms_int_2", "pms_cw_0", "pms_cw_1"]:
		cost_total += int(SkillTree.get_skill(nid2).get("cost", 1))
	var affordable: bool = cost_total <= 52
	print("[ASSERT] 门关+核武总耗点(%d) ≤ 可用52:" % cost_total, " PASS" if affordable else " FAIL")
	if affordable: pass_cnt += 1
	else: fail_cnt += 1

	print("[RESULT] PASS=%d FAIL=%d" % [pass_cnt, fail_cnt])
	quit(1 if fail_cnt > 0 else 0)
