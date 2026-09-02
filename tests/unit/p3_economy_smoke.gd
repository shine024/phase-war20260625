# 经济 smoke test（词条完整性 C3 + P3-A 同源词条可复现 + 精材料掉落）
#
# v25.3（2026-08-31 系统收敛）：原 §1-§5（账号解锁集 / craft_mod 打造 sink / 相位师首杀 /
# DayClock 产能结算 / v8→v9 迁移补 key）已随"产能点+解锁集+首杀"整链退役删除——
# 该链无任何 UI/门禁消费方，属幻影系统。历史版本见 git。
#
# 本测试不依赖 GdUnit 框架，直接 extends SceneTree（风格对齐 tests/master_power_smoke.gd）。
#
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/unit/p3_economy_smoke.gd
extends SceneTree

const AffixDefinitions = preload("res://data/affix_definitions.gd")
const EnemyLoadoutTiers = preload("res://data/enemy_loadout_tiers.gd")
const DropTablesScript = preload("res://resources/drop_tables.gd")


func _initialize() -> void:
	# v18 修复惯例：GDScript lambda 按值捕获——用数组持有者传递失败码
	var code := [0]
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		code[0] = 1
	var ok := func(msg: String) -> void:
		print("  ✓ " + msg)

	print("═══════════════════════════════════════════════════════════")
	print("  经济系统 smoke（词条完整性 / seeded roll / 精材料掉落）")
	print("═══════════════════════════════════════════════════════════")

	# ══════════ 1. 词条定义完整性（C3 build-around）══════════
	print("\n=== 1. 词条定义完整性（5 个 special_mechanic + wired 池过滤）===")
	var sm_ids: Array = ["sm_kill_triage", "sm_intercept_guard", "sm_crit_ensure_hit", "sm_fullhp_onslaught", "sm_double_tap"]
	for sid in sm_ids:
		var def: Dictionary = AffixDefinitions.get_definition(String(sid))
		if def.is_empty():
			fail.call("缺词条定义: %s" % sid)
			continue
		if String(def.get("affix_type", "")) != "special_mechanic":
			fail.call("%s affix_type 应为 special_mechanic" % sid)
		if String(AffixDefinitions.get_mutation_description(String(sid))).is_empty():
			fail.call("%s 缺 MUTATION_TABLE 条目" % sid)
	ok.call("5 个 sm_* 词条定义 + affix_type + 变异条目齐全")
	# wired 旗标：前 2 条已接执行，后 3 条待接（不进 roll 池）
	if bool(AffixDefinitions.get_definition("sm_kill_triage").get("wired", false)) \
			and bool(AffixDefinitions.get_definition("sm_intercept_guard").get("wired", false)):
		ok.call("sm_kill_triage / sm_intercept_guard wired=true")
	else:
		fail.call("已接线条目 wired 应为 true")
	for sid in ["sm_crit_ensure_hit", "sm_fullhp_onslaught", "sm_double_tap"]:
		if bool(AffixDefinitions.get_definition(String(sid)).get("wired", true)):
			fail.call("%s 应为 wired=false（挂点待接）" % sid)
	ok.call("3 条待接词条 wired=false")
	if AffixDefinitions.is_affix_wired("crit_chance"):
		ok.call("历史词条 wired 缺省视为 true（is_affix_wired 兼容）")
	else:
		fail.call("历史词条 wired 缺省应为 true")
	# roll 池排除 wired=false（反复抽 400 次两类型池）
	var unwired_leak := false
	for i in range(400):
		for ct in [0, 1]:
			var rid := String(AffixDefinitions.roll_random_affix_id(ct))
			if rid in ["sm_crit_ensure_hit", "sm_fullhp_onslaught", "sm_double_tap"]:
				unwired_leak = true
			var rid2 := String(AffixDefinitions.roll_unlocked_affix_id(ct, "legendary", []))
			if rid2 in ["sm_crit_ensure_hit", "sm_fullhp_onslaught", "sm_double_tap"]:
				unwired_leak = true
	if not unwired_leak:
		ok.call("roll 池 400×2 次抽样无 wired=false 泄漏")
	else:
		fail.call("roll 池泄漏了未接线词条")
	# kill_repair / intercept_chance 执行链：affix_manager 有 apply 分支（文本断言，参照 _tmp_lifesteal 风格）
	var am_src: String = FileAccess.get_file_as_string("res://managers/affix_manager.gd")
	if am_src.contains("\"intercept_chance\":"):
		ok.call("affix_manager 已接 intercept_chance apply 分支")
	else:
		fail.call("affix_manager 缺 intercept_chance 分支（相位格挡会空转）")
	if am_src.contains("\"kill_repair\":"):
		ok.call("affix_manager kill_repair 分支在位（战场急救消费链）")
	else:
		fail.call("affix_manager 缺 kill_repair 分支")
	# 敌方词条池白名单不含无敌方消费分支的键
	if not EnemyLoadoutTiers.LOADOUT_AFFIX_SUPPORTED_KEYS.has("intercept_chance") \
			and not EnemyLoadoutTiers.LOADOUT_AFFIX_SUPPORTED_KEYS.has("attack_interval"):
		ok.call("敌方词条池白名单排除 intercept_chance/attack_interval（无敌方消费分支）")
	else:
		fail.call("敌方白名单含无敌方消费分支的键")

	# ══════════ 2. P3-A 同源词条 roll 可复现 + 精材料掉落 ═════════
	print("\n=== 2. P3-A 词条可复现 + 精材料掉落 ===")
	var e1: Dictionary = EnemyLoadoutTiers.roll_loadout_affix_def(15, 3, 0, 0, 0, 2)
	var e2: Dictionary = EnemyLoadoutTiers.roll_loadout_affix_def(15, 3, 0, 0, 0, 2)
	if e1 == e2 and not e1.is_empty():
		ok.call("seeded roll 可复现（同关同波同槽 → 同词条：%s）" % String(e1.get("name", "")))
	else:
		fail.call("同 seed 两次 roll 结果不一致或为空")
	# v26: 挂词条门槛升到精英档（TIER_ELITE=3）——新兵/老兵的强度表达由配装改造承担
	if EnemyLoadoutTiers.LOADOUT_AFFIX_MIN_TIER == EnemyLoadoutTiers.TIER_ELITE:
		ok.call("挂词条门槛 = 精英档（TIER_ELITE=%d）" % EnemyLoadoutTiers.TIER_ELITE)
	else:
		fail.call("LOADOUT_AFFIX_MIN_TIER 应为 TIER_ELITE(3)")
	# 高档位关卡掉落含精材料（era2 第 12 关 → in_era 12 → 档位 3）
	var dt = DropTablesScript.new()
	var drops: Array = dt.generate_drops(2, 32, true, 2)
	var has_refined := false
	for d in drops:
		if d != null and d is DropTablesScript.DropResult:
			var res = d as DropTablesScript.DropResult
			if String(res.drop.item_id) == "alloy" and (res.drop.metadata as Dictionary).get("refined", false):
				has_refined = true
				break
	if has_refined:
		ok.call("高档位关卡掉落含精炼合金（复用 alloy 货币 + refined 标记）")
	else:
		fail.call("高档位关卡应追加精材料掉落")
	var boss_drops: Array = dt.generate_boss_drops(2, "steel")
	var boss_refined := false
	for d in boss_drops:
		if d != null and d is DropTablesScript.DropResult:
			var res2 = d as DropTablesScript.DropResult
			if String(res2.drop.item_id) == "alloy" and (res2.drop.metadata as Dictionary).get("refined", false):
				boss_refined = true
				break
	if boss_refined:
		ok.call("Boss 掉落含精炼合金（恒高配档）")
	else:
		fail.call("Boss 掉落应含精材料")

	print("\n═══════════════════════════════════════════════════════════")
	if code[0] == 0:
		print("✅ 经济 smoke 全部 PASS（2 项验证）")
	else:
		print("❌ 存在失败断言，见上方 [FAIL]")
	print("═══════════════════════════════════════════════════════════")
	quit(code[0])
