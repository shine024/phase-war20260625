extends SceneTree
## v7.0 阶段1 验证：InstanceRegistry 数据模型
## 用法：
##   & Godot --headless --rendering-driver opengl3 --path "." --script "tests/v70_instance_registry_check.gd"

const DefaultCards = preload("res://data/default_cards.gd")

func _initialize() -> void:
	var code: int = 0

	print("════════════════════════════════════════")
	print("  v7.0 阶段1: InstanceRegistry 数据模型验证")
	print("════════════════════════════════════════")

	var passed := 0
	var failed := 0
	var ir: Node = Engine.get_main_loop().root.get_node_or_null("InstanceRegistry")
	if ir == null:
		print("✗ FAIL: InstanceRegistry autoload 未加载")
		quit(1)
		return

	# ── 测试1: 创建实例 + 分配 instance_id ──
	var card_a: CardResource = ir.create_instance("cold_t72")
	if card_a != null and card_a.instance_id == "cold_t72#1":
		print("✓ PASS [T1.1] 创建实例A: instance_id=%s" % card_a.instance_id)
		passed += 1
	else:
		print("✗ FAIL [T1.1] 实例A创建异常: %s" % str(card_a))
		failed += 1
		code = 1

	var card_b: CardResource = ir.create_instance("cold_t72")
	if card_b != null and card_b.instance_id == "cold_t72#2":
		print("✓ PASS [T1.2] 创建实例B: instance_id=%s（序号递增）" % card_b.instance_id)
		passed += 1
	else:
		print("✗ FAIL [T1.2] 实例B创建异常: %s" % str(card_b))
		failed += 1
		code = 1

	# ── 测试2: 实例独立性（养成隔离）──
	# 强化A到Lv5，B应保持Lv0
	card_a.enhance_level = 5
	card_a.mods = [{"id": "arm_07_gun_missile", "level": 1}]
	var re_a: CardResource = ir.get_instance("cold_t72#1")
	var re_b: CardResource = ir.get_instance("cold_t72#2")
	if re_a.enhance_level == 5 and re_b.enhance_level == 0:
		print("✓ PASS [T2.1] 强化隔离: A=Lv%d, B=Lv%d" % [re_a.enhance_level, re_b.enhance_level])
		passed += 1
	else:
		print("✗ FAIL [T2.1] 强化隔离失败: A=Lv%d, B=Lv%d" % [re_a.enhance_level, re_b.enhance_level])
		failed += 1
		code = 1

	if re_a.mods.size() == 1 and re_b.mods.size() == 0:
		print("✓ PASS [T2.2] 改造隔离: A.mods=%d, B.mods=%d" % [re_a.mods.size(), re_b.mods.size()])
		passed += 1
	else:
		print("✗ FAIL [T2.2] 改造隔离失败: A.mods=%d, B.mods=%d" % [re_a.mods.size(), re_b.mods.size()])
		failed += 1
		code = 1

	# ── 测试3: 对象身份隔离（不是同一个引用）──
	if re_a != re_b:
		print("✓ PASS [T3] 对象身份隔离: A和B是不同对象")
		passed += 1
	else:
		print("✗ FAIL [T3] A和B是同一对象引用（隔离失败）")
		failed += 1
		code = 1

	# ── 测试4: 不同 card_id 的序号互不干扰 ──
	var tiger1: CardResource = ir.create_instance("ww2_tiger")
	var tiger2: CardResource = ir.create_instance("ww2_tiger")
	if tiger1.instance_id == "ww2_tiger#1" and tiger2.instance_id == "ww2_tiger#2":
		print("✓ PASS [T4] 不同card_id序号独立: tiger#1=%s, tiger#2=%s" % [tiger1.instance_id, tiger2.instance_id])
		passed += 1
	else:
		print("✗ FAIL [T4] 序号异常: tiger1=%s tiger2=%s" % [tiger1.instance_id, tiger2.instance_id])
		failed += 1
		code = 1

	# ── 测试5: get_card_id_of 解析 ──
	var cid: String = ir.get_card_id_of("cold_t72#3")
	if cid == "cold_t72":
		print("✓ PASS [T5] get_card_id_of: cold_t72#3 → %s" % cid)
		passed += 1
	else:
		print("✗ FAIL [T5] 解析异常: %s" % cid)
		failed += 1
		code = 1

	# ── 测试6: 进化养成数据存取 ──
	ir.set_inherit_bonus("cold_t72#1", 0.35)
	ir.set_evolution_hp_floor("cold_t72#1", 1200.0)
	if absf(ir.get_inherit_bonus("cold_t72#1") - 0.35) < 0.001 and absf(ir.get_evolution_hp_floor("cold_t72#1") - 1200.0) < 0.1:
		print("✓ PASS [T6] 进化养成数据存取: inherit=%.2f hp_floor=%.0f" % [ir.get_inherit_bonus("cold_t72#1"), ir.get_evolution_hp_floor("cold_t72#1")])
		passed += 1
	else:
		print("✗ FAIL [T6] 进化养成数据异常")
		failed += 1
		code = 1

	# ── 测试7: 序列化 → 反序列化（存档往返）──
	var saved: Dictionary = ir.save_state()
	# 模拟重启：清空后重载
	ir.clear_all()
	ir.load_state(saved)
	var reload_a: CardResource = ir.get_instance("cold_t72#1")
	var reload_b: CardResource = ir.get_instance("cold_t72#2")
	if reload_a != null and reload_a.enhance_level == 5 and reload_a.mods.size() == 1:
		print("✓ PASS [T7.1] 存档往返: cold_t72#1 enhance=Lv%d mods=%d（养成不丢失）" % [reload_a.enhance_level, reload_a.mods.size()])
		passed += 1
	else:
		print("✗ FAIL [T7.1] 存档往返A异常: %s" % str(reload_a))
		failed += 1
		code = 1

	if reload_b != null and reload_b.enhance_level == 0:
		print("✓ PASS [T7.2] 存档往返: cold_t72#2 enhance=Lv%d（隔离保持）" % reload_b.enhance_level)
		passed += 1
	else:
		print("✗ FAIL [T7.2] 存档往返B异常: %s" % str(reload_b))
		failed += 1
		code = 1

	if absf(ir.get_inherit_bonus("cold_t72#1") - 0.35) < 0.001:
		print("✓ PASS [T7.3] 存档往返: 进化养成数据 inherit_bonus 保持")
		passed += 1
	else:
		print("✗ FAIL [T7.3] 进化养成数据丢失: inherit=%.3f" % ir.get_inherit_bonus("cold_t72#1"))
		failed += 1
		code = 1

	# ── 测试8: dispose_instance ──
	ir.dispose_instance("cold_t72#2")
	if not ir.has_instance("cold_t72#2") and ir.has_instance("cold_t72#1"):
		print("✓ PASS [T8] dispose: cold_t72#2已销毁, #1保留")
		passed += 1
	else:
		print("✗ FAIL [T8] dispose异常")
		failed += 1
		code = 1

	# ── 测试9: 实例不污染 DefaultCards 单例模板 ──
	var template: CardResource = DefaultCards.get_card_by_id("cold_t72")
	if template.enhance_level == 0 and template.mods.size() == 0 and template.instance_id == "":
		print("✓ PASS [T9] 模板未被污染: enhance=Lv%d mods=%d instance_id='%s'" % [template.enhance_level, template.mods.size(), template.instance_id])
		passed += 1
	else:
		print("✗ FAIL [T9] 模板被污染: enhance=Lv%d mods=%d instance_id='%s'" % [template.enhance_level, template.mods.size(), template.instance_id])
		failed += 1
		code = 1

	# ── 汇总 ──
	print("────────────────────────────────────────")
	print("  结果: %d 通过 / %d 失败" % [passed, failed])
	if failed == 0:
		print("  ★ 阶段1全部通过 — InstanceRegistry 数据模型可用")
	else:
		print("  ✗ 存在失败项")
	print("════════════════════════════════════════")

	quit(code)
