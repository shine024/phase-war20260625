extends SceneTree
## ═══════════════════════════════════════════════════════════
##  相位师技能树 + 自动经验升星 smoke test（v8.x）
##  不依赖 GdUnit 框架，用 SceneTree 模式（与 star_config_smoke 一致）
## ═══════════════════════════════════════════════════════════

const SkillTree = preload("res://data/phase_master_skill_tree.gd")
const BattleExperienceConfig = preload("res://data/battle_experience_config.gd")

func _init() -> void:
	var all_pass: bool = true
	print("=== 相位师技能树 + 经验升星 smoke test（v9：3 分支 + 奇点层）===")
	all_pass = _test_skill_tree_data() and all_pass
	all_pass = _test_capstone_layer() and all_pass
	all_pass = _test_experience_config() and all_pass
	all_pass = _test_skill_manager_api() and all_pass
	print("\n=== 结果: %s ===" % ("ALL PASS" if all_pass else "FAILED"))
	quit(0 if all_pass else 1)

## 测试技能树数据完整性
func _test_skill_tree_data() -> bool:
	print("\n[1] 技能树数据完整性（v9：3 分支 + 奇点层）")
	var ok: bool = true
	# 3 分支存在（v9：概念武器分支解散）
	var branches: Array = SkillTree.get_all_branches()
	ok = ok and _assert_eq(branches.size(), 3, "3 分支存在")
	ok = ok and _assert_true(not ("concept_weapon" in branches), "concept_weapon 分支已删除")
	for b in branches:
		var skills: Array = SkillTree.get_skills_for_branch(b)
		ok = ok and _assert_true(skills.size() >= 6, "%s 分支至少6节点（实际%d）" % [b, skills.size()])
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

## 测试 v9 奇点层结构（门关/交叉前置/capstone 标记/相位仪类型清零）
func _test_capstone_layer() -> bool:
	print("\n[2] v9 奇点层结构")
	var ok: bool = true
	# 奇点门关：pms_cw_0 归位智能化，要求三系 tier2 全点亮
	var gate: Dictionary = SkillTree.get_skill("pms_cw_0")
	ok = ok and _assert_false(gate.is_empty(), "奇点解算(pms_cw_0) 存在")
	ok = ok and _assert_eq(SkillTree.get_branch_of("pms_cw_0"), "intelligence", "门关归位智能化")
	var gate_req: Array = gate.get("requires", [])
	ok = ok and _assert_true("pms_cmd_2" in gate_req, "门关前置含指挥 tier2")
	ok = ok and _assert_true("pms_int_2" in gate_req, "门关前置含智能 tier2")
	ok = ok and _assert_true("pms_fp_2" in gate_req, "门关前置含火力 tier2")
	ok = ok and _assert_true(bool(gate.get("capstone", false)), "门关带 capstone 标记")
	# 奇点节点归位抽查
	ok = ok and _assert_eq(SkillTree.get_branch_of("pms_cw_1"), "firepower", "战术核武归位火力")
	ok = ok and _assert_eq(SkillTree.get_branch_of("pms_cw_4"), "command", "护盾投射归位指挥")
	ok = ok and _assert_eq(SkillTree.get_branch_of("pms_cw_8"), "intelligence", "时间迟缓归位智能")
	ok = ok and _assert_eq(SkillTree.get_branch_of("pms_cw_13a"), "firepower", "火焰传导归位火力")
	# 奇点链首全部要求门关（防绕过）
	for chain_root in ["pms_cw_1", "pms_cw_4", "pms_cw_5", "pms_cw_8"]:
		var node: Dictionary = SkillTree.get_skill(chain_root)
		ok = ok and _assert_true("pms_cw_0" in node.get("requires", []), "%s 需奇点解算门关" % chain_root)
	# capstone 节点数 = 15（17 个 cw 节点中，形态进化/能量过载转为常规节点，其余含门关全带标记）
	var capstone_count: int = 0
	for b in SkillTree.get_all_branches():
		for s in SkillTree.get_skills_for_branch(b):
			if bool(s.get("capstone", false)):
				capstone_count += 1
	ok = ok and _assert_eq(capstone_count, 15, "奇点节点数 = 15（实际%d）" % capstone_count)
	# 相位仪类型清零（v9：技能树不再解锁相位仪）
	var pi_unlock_count: int = 0
	for b in SkillTree.get_all_branches():
		for s in SkillTree.get_skills_for_branch(b):
			for u in s.get("unlocks", []):
				if u is Dictionary and u.get("type", "") == "phase_instrument":
					pi_unlock_count += 1
	ok = ok and _assert_eq(pi_unlock_count, 0, "phase_instrument 解锁节点数 = 0")
	# requires 全链可解析（防重分配打错链）
	var all_ids: Dictionary = {}
	for b in SkillTree.get_all_branches():
		for s in SkillTree.get_skills_for_branch(b):
			all_ids[s.get("id", "")] = true
	var dangling: Array = []
	for b in SkillTree.get_all_branches():
		for s in SkillTree.get_skills_for_branch(b):
			for req in s.get("requires", []):
				if not all_ids.has(req):
					dangling.append("%s→%s" % [s.get("id", ""), req])
	ok = ok and _assert_true(dangling.is_empty(), "全部 requires 可解析（悬空: %s）" % str(dangling))
	return ok

## 测试经验配置
func _test_experience_config() -> bool:
	print("\n[3] 经验升级配置（v18.c：星级→30级等级制）")
	var ok: bool = true
	# 阈值升级（th[i]=升到 Lvi 的累计经验；对外钳制最小 Lv1）
	ok = ok and _assert_eq(BattleExperienceConfig.get_card_level_for_exp(0), 1, "0经验=Lv1（初始态钳制）")
	ok = ok and _assert_eq(BattleExperienceConfig.get_card_level_for_exp(10), 1, "10经验=Lv1（首个阈值在60）")
	ok = ok and _assert_eq(BattleExperienceConfig.get_card_level_for_exp(60), 2, "60经验=Lv2")
	ok = ok and _assert_eq(BattleExperienceConfig.get_card_level_for_exp(2960), 10, "2960经验=Lv10")
	ok = ok and _assert_eq(BattleExperienceConfig.get_card_level_for_exp(50770), 30, "50770经验=Lv30（满级）")
	ok = ok and _assert_eq(BattleExperienceConfig.get_card_level_for_exp(99999), 30, "超限=Lv30(满)")
	# 下一级经验
	ok = ok and _assert_eq(BattleExperienceConfig.get_exp_for_next_level(1), 60, "Lv1→Lv2需60")
	ok = ok and _assert_eq(BattleExperienceConfig.get_exp_for_next_level(30), -1, "Lv30已满级")
	# 进度：Lv1区间[0,60)，30经验进度=30/60=0.5
	ok = ok and _assert_true(absf(BattleExperienceConfig.get_level_progress(30) - 0.5) < 0.01, "30经验进度≈0.5")
	# 废弃别名等价
	ok = ok and _assert_eq(BattleExperienceConfig.get_star_level_for_exp(60), BattleExperienceConfig.get_card_level_for_exp(60), "废弃别名等价")
	return ok

## 测试技能树 manager API（需要 autoload 环境，这里测静态逻辑）
func _test_skill_manager_api() -> bool:
	print("\n[4] 技能树 manager 静态逻辑")
	var ok: bool = true
	# 测试前置依赖逻辑（从数据层验证 requires 链）
	var fp0: Dictionary = SkillTree.get_skill("pms_fp_0")
	ok = ok and _assert_true(fp0.get("requires", []).is_empty(), "fp_0 无前置")
	var fp1a: Dictionary = SkillTree.get_skill("pms_fp_1a")
	ok = ok and _assert_true("pms_fp_0" in fp1a.get("requires", []), "fp_1a 前置含 fp_0")
	# 测试解锁内容字段完整性（v9：cw_4 护盾投射归位指挥系，解锁机制+全时代进化）
	var cw4: Dictionary = SkillTree.get_skill("pms_cw_4")
	var unlocks: Array = cw4.get("unlocks", [])
	ok = ok and _assert_true(unlocks.size() >= 2, "cw_4 至少2个解锁内容")
	var has_shield_mechanism: bool = false
	var has_evolution: bool = false
	for u in unlocks:
		if u is Dictionary:
			if u.get("type") == "unit_mechanism" and u.get("id") == "shield_projector":
				has_shield_mechanism = true
			if u.get("type") == "evolution":
				has_evolution = true
	ok = ok and _assert_true(has_shield_mechanism, "cw_4 解锁护盾投射机制")
	ok = ok and _assert_true(has_evolution, "cw_4 解锁进化")
	# 相位仪节点已替换为数值节点（v9）
	var cmd3: Dictionary = SkillTree.get_skill("pms_cmd_3")
	ok = ok and _assert_eq(cmd3.get("name", ""), "军团韧性", "cmd_3 已替换为军团韧性")
	ok = ok and _assert_true(cmd3.get("effects", {}).has("stat_bonus"), "cmd_3 有 stat_bonus")
	var fp2: Dictionary = SkillTree.get_skill("pms_fp_2")
	ok = ok and _assert_eq(fp2.get("name", ""), "弹道改良", "fp_2 已替换为弹道改良")
	ok = ok and _assert_true(fp2.get("effects", {}).has("stat_bonus"), "fp_2 有 stat_bonus")
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
