extends SceneTree
## ═══════════════════════════════════════════════════════════
##  v8.x 技能体系改动 smoke test
##  验证新增/修改的文件能正确加载、class_name 唯一、关键 API 存在
##  运行方式：
##    Godot --headless --script tests/v8_skills_smoke.gd
## ═══════════════════════════════════════════════════════════

const GC = preload("res://resources/game_constants.gd")
const AttackCalculator = preload("res://scripts/battle/attack_calculator.gd")
const TargetSelection = preload("res://scripts/battle/target_selection.gd")
const Tactics = preload("res://data/tactics.gd")
const TacticDetector = preload("res://scripts/battle/tactic_detector.gd")
const CardPeriodicSkills = preload("res://data/card_periodic_skills.gd")
const CardPeriodicSkillEngine = preload("res://managers/battle/card_periodic_skill_engine.gd")
const PhaseMasterSkillTree = preload("res://data/phase_master_skill_tree.gd")
const V8Extension = preload("res://data/phase_master_skill_tree_v8_extension.gd")

func _init():
	var passed := 0
	var failed := 0

	# 测试 1: CombatKind 枚举恢复为 5 值（三维攻防系统封闭）
	print("=== Test 1: CombatKind 三维封闭（5 值）===")
	# v8.x 重构后：ENGINEER/SNIPER 不再是 CombatKind 枚举值，新兵种走标签层
	var has_engineer_enum: bool = GC.CombatKind.keys().has("ENGINEER")
	var has_sniper_enum: bool = GC.CombatKind.keys().has("SNIPER")
	if not has_engineer_enum and not has_sniper_enum:
		print("  PASS: CombatKind 恢复为 5 值（LIGHT/ARMOR/SUPPORT/AIR/FORT），三维系统封闭")
		passed += 1
	else:
		print("  FAIL: CombatKind 仍含 ENGINEER=", has_engineer_enum, " SNIPER=", has_sniper_enum)
		failed += 1

	# 测试 2: card.tags 流动修复验证（静态核对，因 --script 模式下 CardResource 依赖 autoload 无法实例化）
	print("=== Test 2: card.tags → stats.card_tags 流动（静态核对）===")
	# 读取 unit_stats_table.gd 源码，确认 build_stats_from_card 含 card_tags 写入
	var ust_source := FileAccess.get_file_as_string("res://resources/unit_stats_table.gd")
	var has_tags_write: bool = ust_source.find('set_meta("card_tags"') >= 0
	var has_meta_read: bool = ust_source.find('stats.has_meta("card_tags")') >= 0
	if has_tags_write and has_meta_read:
		print("  PASS: build_stats_from_card 写入 card_tags + _apply_v8_unit_type_meta 读取 card_tags（链路完整）")
		passed += 1
	else:
		print("  FAIL: write=", has_tags_write, " read=", has_meta_read)
		failed += 1

	# 测试 3: TAG_COUNTER_RULES 保留（标签硬克制层）
	print("=== Test 3: TAG_COUNTER_RULES 标签层保留 ===")
	if GC.TAG_COUNTER_RULES.size() >= 8:
		print("  PASS: ", GC.TAG_COUNTER_RULES.size(), " 条标签硬克制规则")
		passed += 1
	else:
		print("  FAIL: TAG_COUNTER_RULES 数 = ", GC.TAG_COUNTER_RULES.size())
		failed += 1

	# 测试 4: SNIPER 标签优先级常量
	print("=== Test 4: SNIPER_BOSS_PRIORITY 常量 ===")
	if TargetSelection.CombatKindPriority.SNIPER_BOSS_PRIORITY == -2:
		print("  PASS: SNIPER_BOSS_PRIORITY = -2")
		passed += 1
	else:
		print("  FAIL: SNIPER_BOSS_PRIORITY = ", TargetSelection.CombatKindPriority.SNIPER_BOSS_PRIORITY)
		failed += 1

	# 测试 5: 战法定义加载
	print("=== Test 5: Tactics 定义 ===")
	var all_tactics := Tactics.get_all_tactics()
	if all_tactics.size() == 18:
		print("  PASS: 18 战法定义加载 (", Tactics.BASIC_TACTICS.size(), " 基础 + ", Tactics.ADVANCED_TACTICS.size(), " 高级)")
		passed += 1
	else:
		print("  FAIL: 战法总数 = ", all_tactics.size(), " (期望 18)")
		failed += 1

	# 测试 6: 战法 tactic_pincer 条件完整性
	print("=== Test 6: tactic_pincer 条件 ===")
	var pincer := Tactics.get_tactic("tactic_pincer")
	if not pincer.is_empty() and pincer.has("conditions") and pincer.has("effects"):
		print("  PASS: tactic_pincer 结构完整")
		passed += 1
	else:
		print("  FAIL: tactic_pincer 结构不完整")
		failed += 1

	# 测试 7: TacticDetector 实例化
	print("=== Test 7: TacticDetector 实例化 ===")
	var detector := TacticDetector.new()
	if detector != null and detector.has_method("update") and detector.has_method("get_active_tactics"):
		print("  PASS: TacticDetector 实例化 + API 完整")
		passed += 1
	else:
		print("  FAIL: TacticDetector API 缺失")
		failed += 1

	# 测试 8: 卡片定时技能数据
	print("=== Test 8: CardPeriodicSkills ===")
	var all_skills := CardPeriodicSkills.get_all_skill_ids()
	if all_skills.size() >= 20:
		print("  PASS: ", all_skills.size(), " 个卡片定时技能")
		passed += 1
	else:
		print("  FAIL: 卡片技能数 = ", all_skills.size())
		failed += 1

	# 测试 9: 卡片技能 family 分类
	print("=== Test 9: 卡片技能 family 分类 ===")
	var steel_skills := CardPeriodicSkills.get_skills_by_family("steel")
	var flame_skills := CardPeriodicSkills.get_skills_by_family("flame")
	var thunder_skills := CardPeriodicSkills.get_skills_by_family("thunder")
	var void_skills := CardPeriodicSkills.get_skills_by_family("void")
	if steel_skills.size() >= 5 and flame_skills.size() >= 5 and thunder_skills.size() >= 5 and void_skills.size() >= 5:
		print("  PASS: 4 家族各≥5 技能 (steel=", steel_skills.size(), " flame=", flame_skills.size(), " thunder=", thunder_skills.size(), " void=", void_skills.size(), ")")
		passed += 1
	else:
		print("  FAIL: family 分布不均 steel=", steel_skills.size(), " flame=", flame_skills.size(), " thunder=", thunder_skills.size(), " void=", void_skills.size())
		failed += 1

	# 测试 10: 终极技能标记
	print("=== Test 10: 终极技能标记 ===")
	if CardPeriodicSkills.is_ultimate("cps_steel_storm") and not CardPeriodicSkills.is_ultimate("cps_artillery_coord"):
		print("  PASS: is_ultimate 正确区分")
		passed += 1
	else:
		print("  FAIL: is_ultimate 异常")
		failed += 1

	# 测试 11: CardPeriodicSkillEngine 实例化
	print("=== Test 11: CardPeriodicSkillEngine 实例化 ===")
	var engine := CardPeriodicSkillEngine.new()
	if engine != null and engine.has_method("update") and engine.has_method("on_battle_start"):
		print("  PASS: CardPeriodicSkillEngine 实例化 + API 完整")
		passed += 1
	else:
		print("  FAIL: CardPeriodicSkillEngine API 缺失")
		failed += 1

	# 测试 12: V8Extension 扩展节点数（v9：概念武器段解散，16 个 cw 深层节点归位三系）
	print("=== Test 12: V8Extension 节点数（v9 重分配后 51）===")
	var all_ext := V8Extension.get_all_extension_nodes()
	if all_ext.size() == 51:
		var cmd_count := V8Extension.get_extension_nodes("command").size()
		var fp_count := V8Extension.get_extension_nodes("firepower").size()
		var int_count := V8Extension.get_extension_nodes("intelligence").size()
		var cw_gone := V8Extension.get_extension_nodes("concept_weapon").is_empty()
		if cmd_count == 17 and fp_count == 19 and int_count == 15 and cw_gone:
			print("  PASS: 51 扩展节点 (cmd=", cmd_count, " fp=", fp_count, " int=", int_count, " cw段已删)")
			passed += 1
		else:
			print("  FAIL: 分布 cmd=", cmd_count, " fp=", fp_count, " int=", int_count, " cw段空=", cw_gone)
			failed += 1
	else:
		print("  FAIL: 扩展节点数 = ", all_ext.size(), " (期望 51)")
		failed += 1

	# 测试 13: 主技能树合并扩展节点
	print("=== Test 13: 主技能树合并扩展节点 ===")
	var cmd_skills := PhaseMasterSkillTree.get_skills_for_branch("command")
	# v9：主表 7 节点（含替换后的军团韧性）+ 扩展 17 节点（含归位的 4 个奇点）= 24
	if cmd_skills.size() == 24:
		print("  PASS: command 分支合并后 ", cmd_skills.size(), " 节点")
		passed += 1
	else:
		print("  FAIL: command 分支节点数 = ", cmd_skills.size(), " (期望 24)")
		failed += 1

	# 测试 14: get_skill 支持扩展节点
	print("=== Test 14: get_skill 查询扩展节点 ===")
	var ext_skill := PhaseMasterSkillTree.get_skill("pms_cmd_5")
	if not ext_skill.is_empty() and ext_skill.get("id", "") == "pms_cmd_5":
		print("  PASS: get_skill('pms_cmd_5') 返回扩展节点")
		passed += 1
	else:
		print("  FAIL: get_skill('pms_cmd_5') 未找到")
		failed += 1

	# 测试 15: compute_tag_counter_multiplier 函数可调用
	print("=== Test 15: compute_tag_counter_multiplier API ===")
	var _test_mock := Node.new()
	var _test_result: Dictionary = AttackCalculator.compute_tag_counter_multiplier([], _test_mock)
	_test_mock.free()
	if not _test_result.is_empty() and _test_result.has("mult"):
		print("  PASS: compute_tag_counter_multiplier 可调用 + 返回结构正确")
		passed += 1
	else:
		print("  FAIL: compute_tag_counter_multiplier 异常")
		failed += 1

	# 测试 17: 标签克制数值验证（SNIPER 打 boss 应 +50%）
	print("=== Test 17: SNIPER vs boss 标签克制 ===")
	# 构造模拟目标 Node（用 Node 代替，设 meta target_priority_tag=boss）
	var mock_target := Node.new()
	mock_target.set_meta("target_priority_tag", "boss")
	var tag_result: Dictionary = AttackCalculator.compute_tag_counter_multiplier(["sniper"], mock_target)
	mock_target.free()
	if absf(float(tag_result.get("mult", 0.0)) - 1.5) < 0.001:
		print("  PASS: SNIPER vs boss 倍率 = 1.50 (+50%)")
		passed += 1
	else:
		print("  FAIL: SNIPER vs boss 倍率 = ", tag_result.get("mult", 0.0), " (期望 1.50)")
		failed += 1

	# 测试 18: 标签克制 never_miss 标记（SNIPER 打 boss 应 never_miss=true）
	print("=== Test 18: SNIPER vs boss never_miss 标记 ===")
	var mock_target2 := Node.new()
	mock_target2.set_meta("target_priority_tag", "boss")
	var tag_result2: Dictionary = AttackCalculator.compute_tag_counter_multiplier(["sniper"], mock_target2)
	mock_target2.free()
	if bool(tag_result2.get("never_miss", false)):
		print("  PASS: SNIPER vs boss never_miss = true")
		passed += 1
	else:
		print("  FAIL: SNIPER vs boss never_miss = ", tag_result2.get("never_miss", false))
		failed += 1

	# 测试 19: 无标签时不触发克制（倍率=1.0）
	print("=== Test 19: 无标签克制倍率 ===")
	var mock_target3 := Node.new()
	var tag_result3: Dictionary = AttackCalculator.compute_tag_counter_multiplier([], mock_target3)
	mock_target3.free()
	if absf(float(tag_result3.get("mult", 0.0)) - 1.0) < 0.001:
		print("  PASS: 无标签倍率 = 1.0 (向后兼容)")
		passed += 1
	else:
		print("  FAIL: 无标签倍率 = ", tag_result3.get("mult", 0.0))
		failed += 1

	# 测试 20: STEALTH 打 command 标签克制（+30%）
	print("=== Test 20: STEALTH vs command 标签克制 ===")
	var mock_target4 := Node.new()
	mock_target4.set_meta("target_priority_tag", "command")
	var tag_result4: Dictionary = AttackCalculator.compute_tag_counter_multiplier(["stealth"], mock_target4)
	mock_target4.free()
	if absf(float(tag_result4.get("mult", 0.0)) - 1.3) < 0.001:
		print("  PASS: STEALTH vs command 倍率 = 1.30 (+30%)")
		passed += 1
	else:
		print("  FAIL: STEALTH vs command 倍率 = ", tag_result4.get("mult", 0.0), " (期望 1.30)")
		failed += 1

	# 测试 21: card_skill/tactic unlock_type 在技能树中存在
	print("=== Test 21: card_skill/tactic unlock_type 在技能树中存在 ===")
	var has_card_skill_unlock: bool = false
	var has_tactic_unlock: bool = false
	for branch in PhaseMasterSkillTree.get_all_branches():
		for s in PhaseMasterSkillTree.get_skills_for_branch(branch):
			for u in s.get("unlocks", []):
				if u is Dictionary:
					if String(u.get("type", "")) == "card_skill":
						has_card_skill_unlock = true
					if String(u.get("type", "")) == "tactic":
						has_tactic_unlock = true
	if has_card_skill_unlock and has_tactic_unlock:
		print("  PASS: 技能树含 card_skill 和 tactic 解锁类型")
		passed += 1
	else:
		print("  FAIL: card_skill=", has_card_skill_unlock, " tactic=", has_tactic_unlock)
		failed += 1

	# 测试 22: UnlockLabels 翻译表存在 + 关键兵种机制有翻译
	print("=== Test 22: UnlockLabels 翻译表 ===")
	var UnlockLabelsRef = preload("res://data/unlock_labels.gd")
	var stalker_label: Dictionary = UnlockLabelsRef.get_unlock_label("unit_mechanism", "stalker_stealth")
	var emp_label: Dictionary = UnlockLabelsRef.get_unlock_label("card_skill", "cps_emp_strike")
	var pincer_label: Dictionary = UnlockLabelsRef.get_unlock_label("tactic", "tactic_pincer")
	if not stalker_label.is_empty() and not emp_label.is_empty() and not pincer_label.is_empty():
		print("  PASS: 翻译表覆盖 unit_mechanism/card_skill/tactic")
		print("    stalker_stealth → ", stalker_label.get("name", ""))
		print("    cps_emp_strike → ", emp_label.get("name", ""))
		print("    tactic_pincer → ", pincer_label.get("name", ""))
		passed += 1
	else:
		print("  FAIL: stalker=", not stalker_label.is_empty(), " emp=", not emp_label.is_empty(), " pincer=", not pincer_label.is_empty())
		failed += 1

	# 测试 23: 卡牌标签翻译表（card.tags → 中文）
	print("=== Test 23: 卡牌标签翻译表 ===")
	var stalker_cn: String = UnlockLabelsRef.get_card_tag_label("stalker")
	var sniper_cn: String = UnlockLabelsRef.get_card_tag_label("sniper")
	if stalker_cn == "渗透者" and sniper_cn == "狙击手":
		print("  PASS: 卡牌标签翻译 (stalker→渗透者, sniper→狙击手)")
		passed += 1
	else:
		print("  FAIL: stalker→", stalker_cn, " sniper→", sniper_cn)
		failed += 1

	# 汇总
	print("\n=== 汇总 ===")
	print("PASS: ", passed, " / ", passed + failed)
	print("FAIL: ", failed, " / ", passed + failed)
	if failed == 0:
		print("✅ 全部通过")
	else:
		print("❌ 有失败项")
	quit(0 if failed == 0 else 1)
