extends SceneTree
## ═══════════════════════════════════════════════════════════
##  相位师技能树 + 自动经验升星 smoke test（v8.x）
##  不依赖 GdUnit 框架，用 SceneTree 模式（与 star_config_smoke 一致）
## ═══════════════════════════════════════════════════════════

const SkillTree = preload("res://data/phase_master_skill_tree.gd")
const BattleExperienceConfig = preload("res://data/battle_experience_config.gd")

func _init() -> void:
	var all_pass: bool = true
	print("=== 相位师技能树 + 经验升星 smoke test ===")
	all_pass = _test_skill_tree_data() and all_pass
	all_pass = _test_experience_config() and all_pass
	all_pass = _test_skill_manager_api() and all_pass
	print("\n=== 结果: %s ===" % ("ALL PASS" if all_pass else "FAILED"))
	quit(0 if all_pass else 1)

## 测试技能树数据完整性
func _test_skill_tree_data() -> bool:
	print("\n[1] 技能树数据完整性")
	var ok: bool = true
	# 4 分支存在
	var branches: Array = SkillTree.get_all_branches()
	ok = ok and _assert_eq(branches.size(), 4, "4 分支存在")
	for b in branches:
		var skills: Array = SkillTree.get_skills_for_branch(b)
		ok = ok and _assert_true(skills.size() >= 4, "%s 分支至少4节点（实际%d）" % [b, skills.size()])
	# get_skill 查询
	var cmd0: Dictionary = SkillTree.get_skill("pms_cmd_0")
	ok = ok and _assert_false(cmd0.is_empty(), "get_skill(pms_cmd_0) 非空")
	ok = ok and _assert_eq(SkillTree.get_branch_of("pms_cmd_0"), "command", "get_branch_of")
	# 中文名
	ok = ok and _assert_eq(SkillTree.get_branch_display_name("firepower"), "火力", "分支中文名")
	# 技能点曲线
	ok = ok and _assert_true(SkillTree.max_skill_points_at_phase_field_level(5) > 0, "Lv5 有技能点")
	ok = ok and _assert_eq(SkillTree.max_skill_points_at_phase_field_level(1), 0, "Lv1 无技能点")
	return ok

## 测试经验配置
func _test_experience_config() -> bool:
	print("\n[2] 经验升星配置")
	var ok: bool = true
	# 阈值升星
	ok = ok and _assert_eq(BattleExperienceConfig.get_star_level_for_exp(0), 0, "0经验=0星")
	ok = ok and _assert_eq(BattleExperienceConfig.get_star_level_for_exp(100), 1, "100经验=1星")
	ok = ok and _assert_eq(BattleExperienceConfig.get_star_level_for_exp(500), 3, "500经验=3星（阈值[0,100,250,500,...]）")
	ok = ok and _assert_eq(BattleExperienceConfig.get_star_level_for_exp(9500), 9, "9500经验=9星")
	ok = ok and _assert_eq(BattleExperienceConfig.get_star_level_for_exp(99999), 9, "超限=9星(满)")
	# 下一星经验
	ok = ok and _assert_eq(BattleExperienceConfig.get_exp_for_next_star(0), 100, "0星→1星需100")
	ok = ok and _assert_eq(BattleExperienceConfig.get_exp_for_next_star(9), -1, "9星已满级")
	# 进度：0星区间[0,100)，75经验进度=75/100=0.75
	ok = ok and _assert_true(absf(BattleExperienceConfig.get_star_progress(75) - 0.75) < 0.01, "75经验进度≈0.75")
	return ok

## 测试技能树 manager API（需要 autoload 环境，这里测静态逻辑）
func _test_skill_manager_api() -> bool:
	print("\n[3] 技能树 manager 静态逻辑")
	var ok: bool = true
	# 测试前置依赖逻辑（从数据层验证 requires 链）
	var fp0: Dictionary = SkillTree.get_skill("pms_fp_0")
	ok = ok and _assert_true(fp0.get("requires", []).is_empty(), "fp_0 无前置")
	var fp1a: Dictionary = SkillTree.get_skill("pms_fp_1a")
	ok = ok and _assert_true("pms_fp_0" in fp1a.get("requires", []), "fp_1a 前置含 fp_0")
	# 测试解锁内容字段完整性
	var cw4: Dictionary = SkillTree.get_skill("pms_cw_4")
	var unlocks: Array = cw4.get("unlocks", [])
	ok = ok and _assert_true(unlocks.size() >= 2, "cw_4 至少2个解锁内容")
	var has_special_card: bool = false
	var has_evolution: bool = false
	for u in unlocks:
		if u is Dictionary:
			if u.get("type") == "special_card":
				has_special_card = true
			if u.get("type") == "evolution":
				has_evolution = true
	ok = ok and _assert_true(has_special_card, "cw_4 解锁特殊卡")
	ok = ok and _assert_true(has_evolution, "cw_4 解锁进化")
	# 测试 effects stat_bonus 完整性
	var fp4: Dictionary = SkillTree.get_skill("pms_fp_4")
	var fx: Dictionary = fp4.get("effects", {})
	ok = ok and _assert_true(fx.has("stat_bonus"), "fp_4 有 stat_bonus")
	ok = ok and _assert_true(float(fx.stat_bonus.get("atk_light", 0)) > 0, "fp_4 atk_light>0")
	return ok

# ─────────────────────────────────────────────
#  断言辅助
# ─────────────────────────────────────────────
func _assert_eq(actual, expected, msg: String) -> bool:
	if actual == expected:
		print("  ✓ %s" % msg)
		return true
	print("  ✗ %s（期望 %s，实际 %s）" % [msg, str(expected), str(actual)])
	return false

func _assert_true(cond: bool, msg: String) -> bool:
	if cond:
		print("  ✓ %s" % msg)
		return true
	print("  ✗ %s" % msg)
	return false

func _assert_false(cond: bool, msg: String) -> bool:
	return _assert_true(not cond, msg)
