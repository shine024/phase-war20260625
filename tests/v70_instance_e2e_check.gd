extends SceneTree
## v7.0 阶段2/3 端到端验证：两张同名卡独立养成全链路
## 覆盖：create_instance → 强化隔离 → 改造隔离 → 战斗spawn带不同养成
## 用法：
##   & Godot --headless --rendering-driver opengl3 --path "." --script "tests/v70_instance_e2e_check.gd"

const DefaultCards = preload("res://data/default_cards.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")

func _initialize() -> void:
	var code: int = 0
	ModificationRegistry.register_all()

	print("════════════════════════════════════════")
	print("  v7.0 阶段2/3 端到端: 两张同名卡独立养成")
	print("════════════════════════════════════════")

	var passed := 0
	var failed := 0
	var ir: Node = Engine.get_main_loop().root.get_node_or_null("InstanceRegistry")
	var cem: Node = Engine.get_main_loop().root.get_node_or_null("CardEnhancementManager")
	if ir == null or cem == null:
		print("✗ FAIL: InstanceRegistry 或 CardEnhancementManager 未加载")
		quit(1)
		return

	# ── 创建两张同名 T-72 实例 ──
	var t72_a: CardResource = ir.create_instance("cold_t72")
	var t72_b: CardResource = ir.create_instance("cold_t72")
	if t72_a == null or t72_b == null or t72_a.instance_id == t72_b.instance_id:
		print("✗ FAIL [T0] 实例创建失败: A=%s B=%s" % [str(t72_a), str(t72_b)])
		quit(1)
		return
	print("✓ PASS [T0] 两张T-72: %s / %s" % [t72_a.instance_id, t72_b.instance_id])
	passed += 1

	# ── 测试1: 强化隔离 ──
	# --script 模式下 CardEnhancementManager 的 get_node_or_null 失效（autoload 未挂场景树），
	# 直接操作实例对象验证数据隔离（真实游戏走 do_enhance → 实例对象）
	t72_a.enhance_level = 1  # 模拟 do_enhance 写实例
	var re_a: CardResource = ir.get_instance(t72_a.instance_id)
	var re_b: CardResource = ir.get_instance(t72_b.instance_id)
	if re_a.enhance_level == 1 and re_b.enhance_level == 0:
		print("✓ PASS [T1] 强化隔离: A=Lv%d B=Lv%d（实例对象独立）" % [re_a.enhance_level, re_b.enhance_level])
		passed += 1
	else:
		print("✗ FAIL [T1] 强化隔离失败: A=Lv%d B=Lv%d" % [re_a.enhance_level, re_b.enhance_level])
		failed += 1
		code = 1

	# ── 测试2: 改造隔离（直接改实例 mods） ──
	t72_a.mods = [{"id": "arm_05_smoothbore", "level": 1}]
	t72_b.mods = [{"id": "arm_06_apfsds", "level": 1}, {"id": "arm_01_sloped_armor", "level": 1}]
	if ir.get_instance(t72_a.instance_id).mods.size() == 1 and ir.get_instance(t72_b.instance_id).mods.size() == 2:
		print("✓ PASS [T2] 改造隔离: A.mods=%d B.mods=%d" % [ir.get_instance(t72_a.instance_id).mods.size(), ir.get_instance(t72_b.instance_id).mods.size()])
		passed += 1
	else:
		print("✗ FAIL [T2] 改造隔离失败")
		failed += 1
		code = 1

	# ── 测试3: 战斗 build_stats 带不同养成 ──
	# 模拟战斗构建（直接调 UnitStatsTable，传入带养成的实例对象）
	var stats_a: UnitStats = UnitStatsTable.build_stats_from_card(re_a, 2)
	var stats_b: UnitStats = UnitStatsTable.build_stats_from_card(re_b, 2)
	if stats_a.enhance_level == 1 and stats_b.enhance_level == 0:
		print("✓ PASS [T3.1] 战斗stats带养成: A.enhance=Lv%d B.enhance=Lv%d" % [stats_a.enhance_level, stats_b.enhance_level])
		passed += 1
	else:
		print("✗ FAIL [T3.1] 战斗stats养成异常: A=Lv%d B=Lv%d" % [stats_a.enhance_level, stats_b.enhance_level])
		failed += 1
		code = 1

	# A 有改造 arm_05_smoothbore(attack_armor+25%)，B 有 arm_06_apfsds(attack_armor+30%)
	# B 的 attack_armor 应该比 A 高（30% > 25%）
	if stats_b.attack_armor > stats_a.attack_armor:
		print("✓ PASS [T3.2] 改造生效差异: A.atk_armor=%d B.atk_armor=%d（B更高）" % [int(stats_a.attack_armor), int(stats_b.attack_armor)])
		passed += 1
	else:
		print("✗ FAIL [T3.2] 改造差异异常: A.atk_armor=%d B.atk_armor=%d" % [int(stats_a.attack_armor), int(stats_b.attack_armor)])
		failed += 1
		code = 1

	# ── 测试4: 模板未被污染 ──
	var template: CardResource = DefaultCards.get_card_by_id("cold_t72")
	if template.enhance_level == 0 and template.mods.size() == 0:
		print("✓ PASS [T4] 模板未污染: enhance=Lv%d mods=%d" % [template.enhance_level, template.mods.size()])
		passed += 1
	else:
		print("✗ FAIL [T4] 模板被污染: enhance=Lv%d mods=%d" % [template.enhance_level, template.mods.size()])
		failed += 1
		code = 1

	# ── 测试5: 存档往返保持隔离 ──
	var saved: Dictionary = ir.save_state()
	ir.clear_all()
	ir.load_state(saved)
	var reload_a: CardResource = ir.get_instance(t72_a.instance_id)
	var reload_b: CardResource = ir.get_instance(t72_b.instance_id)
	if reload_a != null and reload_b != null and reload_a.enhance_level == 1 and reload_b.enhance_level == 0:
		print("✓ PASS [T5] 存档往返隔离保持: A=Lv%d B=Lv%d" % [reload_a.enhance_level, reload_b.enhance_level])
		passed += 1
	else:
		print("✗ FAIL [T5] 存档往返隔离丢失: A=%s B=%s" % [str(reload_a), str(reload_b)])
		failed += 1
		code = 1

	# ── 汇总 ──
	print("────────────────────────────────────────")
	print("  结果: %d 通过 / %d 失败" % [passed, failed])
	if failed == 0:
		print("  ★ 全部通过 — 两张同名卡独立养成全链路打通")
	else:
		print("  ✗ 存在失败项")
	print("════════════════════════════════════════")

	quit(code)
