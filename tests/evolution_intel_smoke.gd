# v9.x 进化情报可见性 smoke test
# 背景：进化面板"进化情报没列清楚，玩家不知道如何达成"。本轮修复：
#   1) 锁定目标可点击 → 详情面板完整条件列表 + detail 指引可达
#   2) badge 显示全部未满足条件计数（等N项）+ tooltip 概览
#   3) 数据层补 power/enhance/mods 三条件 detail 指引
#   4) 未揭示的情报隐藏分支在进化树末尾列出揭示条件与进度
#
# 本测试不依赖 GdUnit，直接 extends SceneTree（--script 模式 autoload 不初始化，
# 运行时链路只做源码/静态数据断言）。
#
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/evolution_intel_smoke.gd
extends SceneTree

const IntelEvolutionBranches = preload("res://data/intel_evolution_branches.gd")

var _code := 0


func _fail(msg: String) -> void:
	push_error("[FAIL] " + msg)
	_code = 1


func _initialize() -> void:
	print("═══════════════════════════════════════════════════════════")
	print("  v9.x 进化情报可见性验证")
	print("═══════════════════════════════════════════════════════════")

	# ══════════ 1. 四个改动文件全部编译通过（load 即编译）══════════
	var panel_script: GDScript = load("res://scenes/ui/evolution_panel.gd")
	if panel_script == null:
		_fail("evolution_panel.gd 编译失败")
	var cem_script: GDScript = load("res://managers/evolution/card_evolution_manager.gd")
	if cem_script == null:
		_fail("card_evolution_manager.gd 编译失败")
	var iem_script: GDScript = load("res://scripts/systems/intel_evolution_manager.gd")
	if iem_script == null:
		_fail("intel_evolution_manager.gd 编译失败")
	if _code == 0:
		print("[OK] 4 个改动文件编译通过")

	# ══════════ 2. 面板/manager 新增方法存在（源码级检查）══════════
	var panel_src: String = FileAccess.get_file_as_string("res://scenes/ui/evolution_panel.gd")
	for m in ["func _append_hidden_intel_hints", "func _count_unmet_conditions",
			"func _unmet_summary_text", "btn.pressed.connect(func(): _on_target_selected"]:
		if not panel_src.contains(m):
			_fail("evolution_panel 缺少新方法/接线: %s" % m)
	if panel_src.contains("btn.disabled = not can_evo"):
		_fail("evolution_panel 仍存在 btn.disabled = not can_evo（锁定目标不可点击，回归）")
	var iem_src: String = FileAccess.get_file_as_string("res://scripts/systems/intel_evolution_manager.gd")
	if not iem_src.contains("func get_requirement_progress"):
		_fail("intel_evolution_manager 缺少 get_requirement_progress")
	if _code == 0:
		print("[OK] 新增方法齐全：隐藏分支提示/未满足计数/概览文本/进度查询/锁定目标可点击")

	# ══════════ 3. enemy_type 中文映射覆盖全部分支需求键 ══════════
	# 防 v7.x B7 类事故（heavy_armor_mat 死键导致进度永远凑不齐）再现
	for bid in IntelEvolutionBranches.get_all_branch_ids():
		var reqs: Dictionary = IntelEvolutionBranches.get_intel_requirements(bid)
		for et in reqs.keys():
			var display: String = IntelEvolutionBranches.get_enemy_type_display(String(et))
			if display == String(et):
				_fail("分支 %s 的情报类型 %s 无中文显示名（ENEMY_TYPE_DISPLAY 缺键）" % [bid, et])
	var d_inf: String = IntelEvolutionBranches.get_enemy_type_display("infantry")
	if d_inf != "步兵系":
		_fail("get_enemy_type_display(infantry) 应为 步兵系，实际 %s" % d_inf)
	if _code == 0:
		print("[OK] enemy_type 中文映射覆盖全部分支情报条件键")

	# ══════════ 4. 源卡→隐藏分支查询链路（面板提示的数据基础）══════════
	var how_brs: Array = IntelEvolutionBranches.get_branches_for_card("fut_howitzer")
	var has_cross := false
	for b in how_brs:
		if String(b.get("branch_id", "")) == "IB_CROSS_ARTILLERY_AIR":
			has_cross = true
	if not has_cross:
		_fail("fut_howitzer 的分支列表缺少 IB_CROSS_ARTILLERY_AIR（终阶卡隐藏分支提示数据源）")
	if _code == 0:
		print("[OK] 源卡→隐藏分支查询链路正常（fut_howitzer→空中炮艇路线）")

	# ══════════ 5. 判定层 detail 指引文案标记 ══════════
	var cem_src: String = FileAccess.get_file_as_string("res://managers/evolution/card_evolution_manager.gd")
	for marker in ["综合评分", "上阵参战", "改造」面板", "击败精英/Boss"]:
		if not cem_src.contains(marker):
			_fail("card_evolution_manager 缺少 detail 指引标记: %s" % marker)
	if _code == 0:
		print("[OK] power/enhance/mods 三条件已补 detail 达成指引（图纸指引在位）")

	print("═══════════════════════════════════════════════════════════")
	if _code == 0:
		print("  ALL PASS — 进化情报可见性修复验证通过")
	else:
		print("  FAILED — 见上方 [FAIL] 行")
	print("═══════════════════════════════════════════════════════════")
	quit(_code)
