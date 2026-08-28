# 相位师技能树 · 电路板主板 smoke test（v22 方案3）
# 验证：面板/主板构建、74 芯片摆位、81 条走线、三态换装、
#       选中探针栏、解锁链路（真管理器）、点数不足失败路径、总览弹层
#
# 注：--script 模式下本项目 autoload 实际可用（2026-08-27 实测，
#     master_power_smoke 旧注释"不初始化"已过时）——直接驱动真
#     PhaseMasterSkillManager：reset_to_defaults() 清态 + level 6（10 点预算）。
#     本测试全程内存态，不落档。
#
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/phase_master_skill_board_smoke.gd
extends SceneTree

const SkillTree = preload("res://data/phase_master_skill_tree.gd")
const Board = preload("res://scenes/ui/phase_master_skill_board.gd")


func _initialize() -> void:
	var code := [0]
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		code[0] = 1
	var ok := func(cond: bool, msg: String) -> void:
		if cond:
			print("  [ok] " + msg)
		else:
			fail.call(msg)

	print("═══════════════════════════════════════════════════════════")
	print("  相位师技能树 · 电路板主板 smoke（v22 方案3）")
	print("═══════════════════════════════════════════════════════════")

	# ══ 1. 数据拓扑基线 ══
	print("\n=== 1. 数据拓扑基线 ===")
	var total := 0
	for b in ["command", "intelligence", "firepower"]:
		var n: int = SkillTree.get_skills_for_branch(b).size()
		total += n
		print("  %s: %d 节点" % [b, n])
	ok.call(total == 74, "全树 74 节点（实际 %d）" % total)

	# ══ 2. 真管理器清态 + 面板构建 ══
	print("\n=== 2. 面板构建 ===")
	var mgr: Node = root.get_node_or_null("PhaseMasterSkillManager")
	ok.call(mgr != null, "PhaseMasterSkillManager autoload 可用")
	if mgr == null:
		print("  无法继续，退出")
		quit(1)
		return
	mgr.reset_to_defaults()
	mgr.set_phase_field_level(6)   # Lv6 = 10 点预算

	var scene := load("res://scenes/ui/phase_master_skill_panel.tscn")
	if scene == null:
		push_error("[FAIL] 面板场景加载失败")
		quit(1)
		return
	var panel = scene.instantiate()
	root.add_child(panel)
	await process_frame

	var board: Node = panel.get_node("MainVBox/BoardScroll").get_child(0)
	ok.call(board != null and board.get_chip_count() == 74, "主板 74 芯片（实际 %s）" % [str(board.get_chip_count()) if board else "无板"])
	ok.call(board.get_edge_count() == 81, "走线 81 条（实际 %s）" % str(board.get_edge_count()))

	# 芯片均在画布内
	var in_bounds := true
	var geo: Dictionary = board.get("_node_geo")
	for nid in geo:
		var g: Dictionary = geo[nid]
		if g["x"] < 0 or g["y"] < 0 or g["x"] + Board.CHIP > Board.BOARD_W or g["y"] + Board.CHIP > Board.BOARD_H:
			in_bounds = false
			print("    越界: ", nid, " @", g["x"], ",", g["y"])
	ok.call(in_bounds, "全部芯片在画布内")

	# 三轨 t0 起点（单节点行槽位居中 → slot 1，x = lane_x + SLOT_PITCH）
	ok.call(int(geo["pms_cmd_0"]["x"]) == Board.lane_x(0) + Board.SLOT_PITCH, "指挥轨 t0 居中 x=%d" % (Board.lane_x(0) + Board.SLOT_PITCH))
	ok.call(int(geo["pms_int_0"]["x"]) == Board.lane_x(1) + Board.SLOT_PITCH, "智能轨 t0 居中 x=%d" % (Board.lane_x(1) + Board.SLOT_PITCH))
	ok.call(int(geo["pms_fp_0"]["x"]) == Board.lane_x(2) + Board.SLOT_PITCH, "火力轨 t0 居中 x=%d" % (Board.lane_x(2) + Board.SLOT_PITCH))
	ok.call(int(geo["pms_cw_0"]["lane"]) == 1, "奇点解算在智能轨（星型汇聚中心）")
	# 4 芯片最宽行不越轨（火力 t7）
	var t7_max_x := 0
	for nid in geo:
		if geo[nid]["lane"] == 2 and int(geo[nid]["tier"]) == 7:
			t7_max_x = maxi(t7_max_x, int(geo[nid]["x"]))
	ok.call(t7_max_x + Board.CHIP <= Board.lane_x(2) + Board.LANE_W, "火力 t7 四芯片行在轨内（最右 x=%d）" % t7_max_x)
	# 器件封装风格 = 解锁内容类型（差异化轴）
	ok.call(geo["pms_cmd_1a"]["chip"].get("chip_style") == Board.ChipStyle.QFN, "数值节点=QFN 方片")
	ok.call(geo["pms_fp_1a"]["chip"].get("chip_style") == Board.ChipStyle.MODULE, "兵种能力节点=MODULE 八角")
	ok.call(geo["pms_cmd_7a"]["chip"].get("chip_style") == Board.ChipStyle.DIP, "战法节点=DIP 双列")
	ok.call(geo["pms_fp_6"]["chip"].get("chip_style") == Board.ChipStyle.CAN, "卡片技能节点=CAN 圆罐")
	ok.call(geo["pms_cw_2"]["chip"].get("chip_style") == Board.ChipStyle.QFP, "进化节点=QFP 双框")

	# ══ 3. 三态换装 ══
	print("\n=== 3. 三态换装 ===")
	mgr.unlock_node("pms_cmd_0")
	mgr.unlock_node("pms_cmd_1a")
	panel._refresh()
	await process_frame
	var cmd0_chip = geo["pms_cmd_0"]["chip"]
	ok.call(cmd0_chip.get("state") == Board.ChipState.POWERED, "已解锁芯片 = POWERED（实际 %s）" % str(cmd0_chip.get("state")))
	var cmd2_chip = geo["pms_cmd_2"]["chip"]   # 前置 cmd_1a 已解锁 → STANDBY
	ok.call(cmd2_chip.get("state") == Board.ChipState.STANDBY, "前置满足芯片 = STANDBY（实际 %s）" % str(cmd2_chip.get("state")))
	var cw0_chip = geo["pms_cw_0"]["chip"]      # 缺三系 tier2 → LOCKED
	ok.call(cw0_chip.get("state") == Board.ChipState.LOCKED, "跨系前置未满足 = LOCKED（实际 %s）" % str(cw0_chip.get("state")))
	var powered_n: int = board.count_unlocked(mgr)
	ok.call(powered_n == 2, "count_unlocked=2（实际 %d）" % powered_n)
	# 走线层：cmd_0→1a/1b、cmd_1a→cmd_2 源已解锁 → 通电
	var trace_layer = board.get("_trace_layer")
	var lit_n := 0
	for ed in trace_layer.get("_draw_list"):
		if ed["lit"]:
			lit_n += 1
	ok.call(lit_n >= 3, "通电走线 ≥3 条（实际 %d）" % lit_n)

	# ══ 4. 选中 + 探针栏 ══
	print("\n=== 4. 选中与探针栏 ===")
	panel._on_chip_selected("pms_cw_1")   # 战术核武（奇点，锁）
	await process_frame
	var name_label: Label = panel.get("_probe_name")
	var name_txt: String = name_label.text if name_label != null else ""
	ok.call("战术核武" in name_txt, "探针栏名称=战术核武（实际 %s）" % name_txt)
	var req_label: Label = panel.get("_probe_req")
	var req_txt: String = req_label.text if req_label != null else ""
	ok.call("前置未满足" in req_txt, "探针栏点名跨系前置（%s）" % req_txt)
	var btn: Button = panel.get("_probe_action_btn")
	ok.call(btn != null and btn.visible and btn.disabled, "通电按钮禁用（前置不满足）")

	# ══ 5. 解锁链路（通电 cmd_2）══
	print("\n=== 5. 解锁链路（通电 cmd_2）===")
	panel._on_chip_selected("pms_cmd_2")
	await process_frame
	panel._on_unlock_pressed("pms_cmd_2")
	await process_frame
	await process_frame
	ok.call(mgr.is_unlocked("pms_cmd_2"), "cmd_2 解锁成功")
	ok.call(geo["pms_cmd_2"]["chip"].get("state") == Board.ChipState.POWERED, "cmd_2 芯片换装 POWERED")
	var action_label: Label = panel.get("_probe_action_label")
	var act_txt: String = action_label.text if action_label != null else ""
	ok.call("已通电" in act_txt, "探针栏显示 ✓已通电（实际 %s）" % act_txt)

	# 失败路径：点数不足（预算 10，已花 4 + 火力链 5 = 9，fp_3 需 2 点）
	panel._on_chip_selected("pms_fp_0")
	await process_frame
	panel._on_unlock_pressed("pms_fp_0")
	panel._on_unlock_pressed("pms_fp_1a")
	panel._on_unlock_pressed("pms_fp_1b")
	panel._on_unlock_pressed("pms_fp_2")
	await process_frame
	await process_frame
	ok.call(mgr.get_spent_points() == 9, "点数花到 9（实际 %d）" % mgr.get_spent_points())
	panel._on_chip_selected("pms_fp_3")
	await process_frame
	var req2: Label = panel.get("_probe_req")
	var req2_txt: String = req2.text if req2 != null else ""
	ok.call("技能点不足" in req2_txt, "点数不足提示（%s）" % req2_txt)

	# ══ 6. 总览弹层 ══
	print("\n=== 6. 总览弹层 ===")
	panel._toggle_summary()
	await process_frame
	var overlay: PanelContainer = panel.get("_summary_overlay")
	ok.call(overlay != null and overlay.visible, "总览弹层打开")
	ok.call(panel.get("_summary_container").get_child_count() > 0, "总览内容已填充")
	panel._toggle_summary()
	ok.call(not overlay.visible, "总览弹层收起")

	# ══ 7. 跳转下一节点 ══
	print("\n=== 7. 跳转下一节点 ===")
	# 当前态：unlocked={cmd_0,1a,2,fp_0,1a,1b,2}，spent=9 avail=1
	# standby 候选：cmd_1b(t1)/int_0(t0) → tier 深者优先 = cmd_1b
	var nxt: Dictionary = board.find_next(mgr)
	ok.call(String(nxt.get("id", "")) == "pms_cmd_1b" and String(nxt.get("kind", "")) == "standby",
			"下一节点=集结号令 pms_cmd_1b（standby，同类 tier 最深）（实际 %s/%s）" % [nxt.get("id", ""), nxt.get("kind", "")])
	# 花掉最后 1 点 → 无 standby，回落 no_points：cmd_3(t3,lane0) 胜过 fp_3(t3,lane2)/int_0(t0)
	mgr.unlock_node("pms_cmd_1b")
	var nxt2: Dictionary = board.find_next(mgr)
	ok.call(String(nxt2.get("id", "")) == "pms_cmd_3" and String(nxt2.get("kind", "")) == "no_points",
			"无 standby 时回落 no_points=军团韧性 pms_cmd_3（实际 %s/%s）" % [nxt2.get("id", ""), nxt2.get("kind", "")])
	# 面板跳转链路：选中 + 探针栏显示点数不足
	panel._on_next_node_pressed()
	await process_frame
	var jump_name: Label = panel.get("_probe_name")
	var jump_txt: String = jump_name.text if jump_name != null else ""
	ok.call("军团韧性" in jump_txt, "跳转后探针栏=军团韧性（实际 %s）" % jump_txt)
	var jump_req: Label = panel.get("_probe_req")
	var jump_req_txt: String = jump_req.text if jump_req != null else ""
	ok.call("技能点不足" in jump_req_txt, "跳转后探针栏提示点数不足（%s）" % jump_req_txt)

	print("\n═══════════════════════════════════════════════════════════")
	if code[0] == 0:
		print("  ALL PASS")
	else:
		print("  存在失败项，见上方 [FAIL]")
	print("═══════════════════════════════════════════════════════════")
	# 还原管理器（防污染同进程后续测试）
	mgr.reset_to_defaults()
	panel.queue_free()
	await process_frame
	quit(code[0])
