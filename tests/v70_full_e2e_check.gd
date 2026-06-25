extends SceneTree
## v7.0 全链路验证：实例化养成完整流程
## 覆盖：制造多张同名卡 → 强化面板操作 → 改造面板操作 → 战斗spawn → 存档往返
## 用法：
##   & Godot --headless --rendering-driver opengl3 --path "." --script "tests/v70_full_e2e_check.gd"

const DefaultCards = preload("res://data/default_cards.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")

func _initialize() -> void:
	var code: int = 0
	ModificationRegistry.register_all()

	print("════════════════════════════════════════")
	print("  v7.0 全链路: 实例化养成完整流程")
	print("════════════════════════════════════════")

	var passed := 0
	var failed := 0
	var ir: Node = Engine.get_main_loop().root.get_node_or_null("InstanceRegistry")
	if ir == null:
		print("✗ FAIL: InstanceRegistry 未加载")
		quit(1)
		return

	# ── 测试1: 制造3张同名 T-72，确认3个独立实例 ──
	var ids: Array = []
	for i in range(3):
		var c: CardResource = ir.create_instance("cold_t72")
		if c != null and not c.instance_id.is_empty():
			ids.append(c.instance_id)
	if ids.size() == 3 and ids[0] != ids[1] and ids[1] != ids[2]:
		print("✓ PASS [T1] 制造3张T-72: %s" % str(ids))
		passed += 1
	else:
		print("✗ FAIL [T1] 实例创建异常: %s" % str(ids))
		failed += 1
		code = 1

	# ── 测试2: 第1张强化Lv2、第2张强化Lv5、第3张保持Lv0 ──
	ir.get_instance(ids[0]).enhance_level = 2
	ir.get_instance(ids[1]).enhance_level = 5
	var lvl0: int = ir.get_instance(ids[0]).enhance_level
	var lvl1: int = ir.get_instance(ids[1]).enhance_level
	var lvl2: int = ir.get_instance(ids[2]).enhance_level
	if lvl0 == 2 and lvl1 == 5 and lvl2 == 0:
		print("✓ PASS [T2] 三张独立强化: Lv%d / Lv%d / Lv%d" % [lvl0, lvl1, lvl2])
		passed += 1
	else:
		print("✗ FAIL [T2] 强化隔离失败: Lv%d / Lv%d / Lv%d" % [lvl0, lvl1, lvl2])
		failed += 1
		code = 1

	# ── 测试3: 第1张装改造 arm_05(attack_armor+25%)，其他无改造 ──
	ir.get_instance(ids[0]).mods = [{"id": "arm_05_smoothbore", "level": 1}]
	var m0: int = ir.get_instance(ids[0]).mods.size()
	var m1: int = ir.get_instance(ids[1]).mods.size()
	var m2: int = ir.get_instance(ids[2]).mods.size()
	if m0 == 1 and m1 == 0 and m2 == 0:
		print("✓ PASS [T3] 改造隔离: mods=%d/%d/%d" % [m0, m1, m2])
		passed += 1
	else:
		print("✗ FAIL [T3] 改造隔离失败: %d/%d/%d" % [m0, m1, m2])
		failed += 1
		code = 1

	# ── 测试4: 战斗 build_stats 各自带各自养成 ──
	var s0: UnitStats = UnitStatsTable.build_stats_from_card(ir.get_instance(ids[0]), 2)
	var s1: UnitStats = UnitStatsTable.build_stats_from_card(ir.get_instance(ids[1]), 2)
	var s2: UnitStats = UnitStatsTable.build_stats_from_card(ir.get_instance(ids[2]), 2)
	if s0.enhance_level == 2 and s1.enhance_level == 5 and s2.enhance_level == 0:
		print("✓ PASS [T4] 战斗stats带各自养成: Lv%d/%d/%d" % [s0.enhance_level, s1.enhance_level, s2.enhance_level])
		passed += 1
	else:
		print("✗ FAIL [T4] 战斗stats养成异常: Lv%d/%d/%d" % [s0.enhance_level, s1.enhance_level, s2.enhance_level])
		failed += 1
		code = 1
	# s0 有改造(attack_armor+25%强化加成)，s1/s2 无改造但s1强化更高
	# s0 vs s2: s0强化Lv2+s0有改造 > s2强化Lv0无改造
	if s0.attack_armor > s2.attack_armor:
		print("✓ PASS [T4.1] 改造+强化生效: s0.atk_armor=%d > s2.atk_armor=%d" % [int(s0.attack_armor), int(s2.attack_armor)])
		passed += 1
	else:
		print("✗ FAIL [T4.1] 改造强化异常: s0=%d s2=%d" % [int(s0.attack_armor), int(s2.attack_armor)])
		failed += 1
		code = 1

	# ── 测试5: 模板永不污染 ──
	var tpl: CardResource = DefaultCards.get_card_by_id("cold_t72")
	if tpl.enhance_level == 0 and tpl.mods.size() == 0 and tpl.instance_id == "":
		print("✓ PASS [T5] 模板干净: enhance=Lv%d mods=%d iid='%s'" % [tpl.enhance_level, tpl.mods.size(), tpl.instance_id])
		passed += 1
	else:
		print("✗ FAIL [T5] 模板被污染: enhance=Lv%d mods=%d iid='%s'" % [tpl.enhance_level, tpl.mods.size(), tpl.instance_id])
		failed += 1
		code = 1

	# ── 测试6: dispose 一张后其他不受影响 ──
	ir.dispose_instance(ids[1])
	if not ir.has_instance(ids[1]) and ir.has_instance(ids[0]) and ir.has_instance(ids[2]):
		# 验证剩余实例养成还在
		var r0: CardResource = ir.get_instance(ids[0])
		var r2: CardResource = ir.get_instance(ids[2])
		if r0.enhance_level == 2 and r2.enhance_level == 0:
			print("✓ PASS [T6] dispose隔离: #1已删, #0=Lv%d #2=Lv%d 保持" % [r0.enhance_level, r2.enhance_level])
			passed += 1
		else:
			print("✗ FAIL [T6] dispose后养成丢失: #0=Lv%d #2=Lv%d" % [r0.enhance_level, r2.enhance_level])
			failed += 1
			code = 1
	else:
		print("✗ FAIL [T6] dispose异常")
		failed += 1
		code = 1

	# ── 测试7: 完整存档往返 ──
	var saved: Dictionary = ir.save_state()
	ir.clear_all()
	ir.load_state(saved)
	var ra: CardResource = ir.get_instance(ids[0])
	var rc: CardResource = ir.get_instance(ids[2])
	if ra != null and rc != null and ra.enhance_level == 2 and ra.mods.size() == 1 and rc.enhance_level == 0:
		print("✓ PASS [T7] 存档往返: #0=Lv%d mods=%d, #2=Lv%d（养成+改造全保留）" % [ra.enhance_level, ra.mods.size(), rc.enhance_level])
		passed += 1
	else:
		print("✗ FAIL [T7] 存档往返丢失: #0=%s #2=%s" % [str(ra), str(rc)])
		failed += 1
		code = 1

	# ── 汇总 ──
	print("────────────────────────────────────────")
	print("  结果: %d 通过 / %d 失败" % [passed, failed])
	if failed == 0:
		print("  ★ 全部通过 — 3张同名卡完全独立养成（强化/改造/战斗/存档全隔离）")
	else:
		print("  ✗ 存在失败项")
	print("════════════════════════════════════════")

	quit(code)
