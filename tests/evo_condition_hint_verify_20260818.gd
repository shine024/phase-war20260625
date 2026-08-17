extends SceneTree
## 2026-08-18 进化条件指引验证：直接加载 CardEvolutionManager（全 class_name 依赖，无 autoload），
## 实测 _skill_tree_era_hint 对各时代卡的输出文案。
## 运行：Godot_console.exe --headless --path . --script tests/evo_condition_hint_verify_20260818.gd

func _init() -> void:
	var pass_cnt := 0
	var fail_cnt := 0
	var CEM = load("res://managers/evolution/card_evolution_manager.gd")
	var ok_load: bool = CEM != null
	print("[LOAD] card_evolution_manager.gd 编译:", "OK" if ok_load else "FAIL")
	if not ok_load:
		quit(1)
		return
	if ok_load: pass_cnt += 1

	# 各时代的技能树指引文案（era 0-4）
	for era in range(5):
		var hint: String = CEM._skill_tree_era_hint(era)
		print("[HINT] era %d → %s" % [era, hint])

	# 断言1：era 0（一战）应点名「形态进化」（tier5）与「护盾投射」（tier10）
	var h0: String = CEM._skill_tree_era_hint(0)
	var ok0: bool = h0.contains("形态进化") and h0.contains("护盾投射") and h0.contains("指挥分支")
	print("[ASSERT] era0 指引含形态进化+护盾投射+指挥分支:", " PASS" if ok0 else " FAIL")
	if ok0: pass_cnt += 1
	else: fail_cnt += 1

	# 断言2：era 1-4 只能靠「护盾投射」（全时代），不应点名形态进化（仅一战）
	for era in [1, 2, 3, 4]:
		var h: String = CEM._skill_tree_era_hint(era)
		var okn: bool = h.contains("护盾投射") and not h.contains("形态进化")
		print("[ASSERT] era%d 指引仅护盾投射:" % era, " PASS" if okn else " FAIL %s" % h)
		if okn: pass_cnt += 1
		else: fail_cnt += 1

	# 断言3：文案带「技能树点亮」行动词（指路面而非陈述句）
	var okv: bool = CEM._skill_tree_era_hint(2).contains("技能树点亮")
	print("[ASSERT] 文案含行动指引:", " PASS" if okv else " FAIL")
	if okv: pass_cnt += 1
	else: fail_cnt += 1

	print("[RESULT] PASS=%d FAIL=%d" % [pass_cnt, fail_cnt])
	quit(1 if fail_cnt > 0 else 0)
