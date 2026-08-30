# v21 P3-B 经济 smoke test（计划 C1 打造 / A4 首杀 / 存档迁移 v8→v9 / C3 词条完整性 + P3-A 词条可复现）
#
# 本测试不依赖 GdUnit 框架，直接 extends SceneTree（风格对齐 tests/master_power_smoke.gd）。
# --script 模式下 autoload 不注册——本测试自建 BasicResourceManager 挂到 /root 下，
# 让 ModificationRegistry.craft_mod 的 get_node_or_null("/root/BasicResourceManager") 真实命中，
# 完整跑通"产能+合金 → 解锁改造"的 sink 链路。
#
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/unit/p3_economy_smoke.gd
extends SceneTree

const BasicResourceManagerScript = preload("res://managers/basic_resource_manager.gd")
const ModificationRegistryScript = preload("res://scripts/systems/modification_registry.gd")
const DayClockScript = preload("res://managers/day_clock.gd")
const SaveMigration = preload("res://scripts/systems/save_migration.gd")
const SaveMigrationV9 = preload("res://scripts/systems/save_migration_v9.gd")
const SaveConstants = preload("res://scripts/systems/save_constants.gd")
const AffixDefinitions = preload("res://data/affix_definitions.gd")
const EnemyLoadoutTiers = preload("res://data/enemy_loadout_tiers.gd")
const DropTablesScript = preload("res://resources/drop_tables.gd")
const SaveManagerScript = preload("res://managers/save_manager.gd")


func _initialize() -> void:
	# v18 修复惯例：GDScript lambda 按值捕获——用数组持有者传递失败码
	var code := [0]
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		code[0] = 1
	var ok := func(msg: String) -> void:
		print("  ✓ " + msg)

	print("═══════════════════════════════════════════════════════════")
	print("  v21 P3-B 经济系统 smoke（打造 sink / 首杀解锁 / v8→v9 / 词条完整性）")
	print("═══════════════════════════════════════════════════════════")

	# ══════════ 1. 解锁集存取 ══════════
	print("\n=== 1. 解锁集存取（ModificationRegistry 账号级 mod_unlock_state）===")
	var mr = ModificationRegistryScript.new()
	mr.name = "ModificationRegistrySmoke"
	root.add_child(mr)
	if not mr.is_mod_unlocked("gen_05_shield"):
		ok.call("初始未解锁 gen_05_shield")
	else:
		fail.call("gen_05_shield 不应初始解锁")
	if mr.unlock_mod("gen_05_shield", "smoke") and mr.is_mod_unlocked("gen_05_shield"):
		ok.call("unlock_mod → is_mod_unlocked 通过")
	else:
		fail.call("unlock_mod/is_mod_unlocked 失败")
	if not mr.unlock_mod("gen_05_shield", "smoke"):
		ok.call("重复解锁幂等（返回 false）")
	else:
		fail.call("重复解锁应返回 false")
	# save_state → load_state 往返
	var snapshot: Dictionary = mr.save_state()
	if snapshot.get("gen_05_shield", false) == true:
		ok.call("save_state 导出 mod_id→true")
	else:
		fail.call("save_state 缺 gen_05_shield")
	var mr2 = ModificationRegistryScript.new()
	mr2.load_state(snapshot)
	if mr2.is_mod_unlocked("gen_05_shield"):
		ok.call("load_state 恢复解锁集")
	else:
		fail.call("load_state 未恢复解锁集")
	mr2.load_state({})  # 新游戏重置路径
	if mr2.get_unlock_state().is_empty():
		ok.call("load_state({}) 清空解锁集（新档默认值）")
	else:
		fail.call("load_state({}) 应清空解锁集")
	# 解锁集存档键名固定（SaveManager 接线依赖）
	if SaveConstants.SK_MOD_UNLOCK_STATE == "mod_unlock_state":
		ok.call("SK_MOD_UNLOCK_STATE == mod_unlock_state")
	else:
		fail.call("SK_MOD_UNLOCK_STATE 值漂移")

	# ══════════ 2. 打造 sink（产能 + 合金 → 解锁）══════════
	print("\n=== 2. 打造 sink（craft_mod：产能点 + 合金 → 解锁未解锁模块）===")
	# 自建 BasicResourceManager stub（--script 模式 autoload 未注册）。
	# 注意：--script 模式下 get_node_or_null("/root/...") 不可靠（_initialize 阶段树解析受限），
	# 因此 stub 经 craft_mod 的 resource_provider 注入参数传入，不依赖路径解析。
	var brm = BasicResourceManagerScript.new()
	brm.name = "BasicResourceManager"
	root.add_child(brm)
	var cost: Dictionary = ModificationRegistryScript.get_craft_cost("gen_02_digital")
	if cost.has("production") and cost.has("alloy"):
		ok.call("get_craft_cost: 产能 %d + 合金 %d" % [int(cost.production), int(cost.alloy)])
	else:
		fail.call("get_craft_cost 返回异常: %s" % str(cost))
	# 2a. 资源不足 → 拒绝
	var r_fail: Dictionary = mr.craft_mod("gen_02_digital", brm)
	if not bool(r_fail.get("ok", true)):
		ok.call("无产能时 craft_mod 拒绝：%s" % String(r_fail.get("message", "")))
	else:
		fail.call("无产能时 craft_mod 应失败")
	# 2b. 产能够、合金不够 → 拒绝且产能回滚（事务原子性）
	brm.add_production_points(int(cost.production))
	brm.add_resource("alloy", int(cost.alloy) - 1)
	var pp_before: int = brm.get_production_points()
	var r_noalloy: Dictionary = mr.craft_mod("gen_02_digital", brm)
	if not bool(r_noalloy.get("ok", true)) and brm.get_production_points() == pp_before:
		ok.call("合金不足拒绝且产能已回滚（%s）" % String(r_noalloy.get("message", "")))
	else:
		fail.call("合金不足路径应拒绝且回滚产能")
	# 2c. 产能+合金都够 → 解锁成功，两资源按价扣减
	brm.add_production_points(999)  # 补满（add 自带 999 上限钳制）
	brm.add_production_points(-999 + int(cost.production) + 500)  # 精确到 cost+500，验证精确扣减
	brm.add_resource("alloy", 1)  # 补足差额
	var alloy_before: int = brm.get_total("alloy")
	var r_ok: Dictionary = mr.craft_mod("gen_02_digital", brm)
	if bool(r_ok.get("ok", false)) and mr.is_mod_unlocked("gen_02_digital"):
		ok.call("craft_mod 成功解锁 gen_02_digital")
	else:
		fail.call("craft_mod 应成功: %s" % str(r_ok))
	if brm.get_production_points() == int(cost.production) + 500 - int(cost.production):
		ok.call("产能按价扣减 %d" % int(cost.production))
	else:
		fail.call("产能扣减异常: %d" % brm.get_production_points())
	if brm.get_total("alloy") == alloy_before - int(cost.alloy):
		ok.call("合金按价扣减 %d" % int(cost.alloy))
	else:
		fail.call("合金扣减异常: %d" % brm.get_total("alloy"))
	# 2d. 已解锁模块再打造 → 拒绝
	var r_dup: Dictionary = mr.craft_mod("gen_02_digital", brm)
	if not bool(r_dup.get("ok", true)):
		ok.call("重复打造拒绝：%s" % String(r_dup.get("message", "")))
	else:
		fail.call("重复打造应拒绝")
	# 2e. 强化词条不可打造
	var enh_ids: Array = ModificationRegistryScript.get_all_ids()
	var enh_target := ""
	for mid in enh_ids:
		var md: Dictionary = ModificationRegistryScript.get_data(String(mid))
		if String(md.get("source", "")) == "enhancement":
			enh_target = String(mid)
			break
	if enh_target != "":
		if not bool(mr.craft_mod(enh_target, brm).get("ok", true)):
			ok.call("强化词条拒绝打造（%s）" % enh_target)
		else:
			fail.call("强化词条 %s 不应可打造" % enh_target)
	else:
		print("  （跳过 2e：未找到强化词条 id）")

	# ══════════ 3. 相位师首杀解锁 ══════════
	print("\n=== 3. 相位师首杀解锁（A4：每位 master 仅首杀发奖，稀有/传奇加权随机）===")
	var mr3 = ModificationRegistryScript.new()
	var fk1: Dictionary = mr3.unlock_boss_first_kill("enemy_master_001", 0)
	if bool(fk1.get("ok", false)) and not String(fk1.get("mod_id", "")).is_empty():
		ok.call("首杀解锁 %s（era0 兵种池）" % String(fk1.mod_id))
		var picked_data: Dictionary = ModificationRegistryScript.get_data(String(fk1.mod_id))
		if ["rare", "epic", "legendary"].has(String(picked_data.get("rarity", ""))):
			ok.call("解锁稀有度为稀有及以上（%s）" % String(picked_data.get("rarity", "")))
		else:
			fail.call("首杀解锁了非稀有模块：%s" % String(picked_data.get("rarity", "")))
	else:
		fail.call("首杀解锁失败: %s" % str(fk1))
	var fk2: Dictionary = mr3.unlock_boss_first_kill("enemy_master_001", 0)
	if not bool(fk2.get("ok", true)):
		ok.call("同 master 二次击杀不再发奖：%s" % String(fk2.get("message", "")))
	else:
		fail.call("同 master 二次击杀不应重复解锁")
	# 首杀标记在存档快照里可见（first_kill_<master_id> 约定）
	if mr3.save_state().has("first_kill_enemy_master_001"):
		ok.call("首杀标记 first_kill_<master_id> 入解锁集快照")
	else:
		fail.call("首杀标记未入快照")

	# ══════════ 4. 产能结算（DayClock）══════════
	print("\n=== 4. 产能结算（DayClock 每日公式，档位与 P3-A 同源）===")
	# 复用 §2 的 brm（同名节点会被 Godot 改名，重复 add 会破坏 get_node_or_null 解析）
	var dc = DayClockScript.new()
	dc.name = "DayClockSmoke"
	root.add_child(dc)
	# --script 模式下 /root 路径解析不可靠 → 经注入点传入资源管理器（生产路径不设此值，走 autoload）
	dc.production_resource_override = brm
	# --script 模式无 GameManager → 恒低配档 30 点/天（headless 安全路径）
	var rate: int = dc.get_daily_production_rate()
	if rate == 30:
		ok.call("无 GameManager 时日产 30（低配档安全路径）")
	else:
		fail.call("日产应 30，实际 %d" % rate)
	var pp4: int = brm.get_production_points()
	dc.rest_until_dawn()
	if brm.get_production_points() == pp4 + 30:
		ok.call("rest_until_dawn 结算 1 天产能 +30")
	else:
		fail.call("跨天产能应 +%d，实际 %d" % [pp4 + 30, brm.get_production_points()])
	var pp5: int = brm.get_production_points()
	var target: int = dc.current_day + 5
	dc.advance_to_day(target)
	if brm.get_production_points() == pp5 + 5 * 30:
		ok.call("advance_to_day 快进 5 天补 5 天产能（+150）")
	else:
		fail.call("快进产能应 %d，实际 %d" % [pp5 + 5 * 30, brm.get_production_points()])
	# 产能上限钳制
	brm.add_production_points(99999)
	if brm.get_production_points() == 999:
		ok.call("产能上限钳制 999")
	else:
		fail.call("产能上限应 999，实际 %d" % brm.get_production_points())

	# ══════════ 5. 存档迁移 v8→v9 ══════════
	print("\n=== 5. 存档迁移 v8→v9（mod_unlock_state + production_points）===")
	# 5a. 迁移链版本常量一致
	if int(SaveMigration.SAVE_SCHEMA_VERSION) == 9 and int(SaveManagerScript.SAVE_SCHEMA_VERSION) == 9:
		ok.call("SaveMigration / SaveManager SCHEMA_VERSION == 9")
	else:
		fail.call("schema 版本常量不一致: %d / %d" % [int(SaveMigration.SAVE_SCHEMA_VERSION), int(SaveManagerScript.SAVE_SCHEMA_VERSION)])
	# 5b. v8 档 → v9：缺 key 静默补默认，既有数据不动
	var v8_data: Dictionary = {
		"__schema_version": 8,
		"basic_resources": {"total_alloy": 123, "total_nano_materials": 456},
		"blueprint": {"blueprint_mods": {"ww1_mauser#1": []}},
	}
	SaveMigration.migrate_save_data(v8_data, 8)
	if int(v8_data.get("__schema_version", 0)) == 9:
		ok.call("v8 档迁移后 schema_version == 9")
	else:
		fail.call("迁移后版本应为 9，实际 %s" % str(v8_data.get("__schema_version")))
	var mu: Variant = v8_data.get("mod_unlock_state", null)
	if mu is Dictionary and (mu as Dictionary).is_empty():
		ok.call("v8 档补默认 mod_unlock_state = {}")
	else:
		fail.call("mod_unlock_state 默认值异常: %s" % str(mu))
	var br9: Dictionary = v8_data.get("basic_resources", {}) as Dictionary
	if int(br9.get("production_points", -1)) == 0:
		ok.call("v8 档补默认 production_points = 0")
	else:
		fail.call("production_points 默认值异常")
	if int(br9.get("total_alloy", -1)) == 123 and int(br9.get("total_nano_materials", -1)) == 456:
		ok.call("既有资源字段不受迁移影响")
	else:
		fail.call("迁移破坏既有资源字段")
	# 5c. v9 档已有值：迁移不覆盖
	var v9_data: Dictionary = {
		"__schema_version": 9,
		"mod_unlock_state": {"gen_05_shield": true, "first_kill_enemy_master_002": true},
		"basic_resources": {"production_points": 250},
	}
	SaveMigration.migrate_save_data(v9_data, 9)  # 恒等（已是最新）
	if int((v9_data["basic_resources"] as Dictionary).get("production_points", -1)) == 250 \
			and (v9_data["mod_unlock_state"] as Dictionary).has("gen_05_shield"):
		ok.call("v9 档既有值迁移不覆盖")
	else:
		fail.call("迁移覆盖了 v9 既有值")
	# 5d. 新档默认值（空数据直过 V9）
	var empty_data: Dictionary = {}
	SaveMigrationV9.migrate_v8_to_v9(empty_data)
	if empty_data.has("mod_unlock_state") and (empty_data["mod_unlock_state"] as Dictionary).is_empty():
		ok.call("空档 V9 迁移补 mod_unlock_state = {}")
	else:
		fail.call("空档 V9 迁移异常: %s" % str(empty_data))
	if not empty_data.has("basic_resources"):
		ok.call("空档不造空 basic_resources 段（字段级静默跳过惯例）")
	else:
		fail.call("空档不应造 basic_resources 段")
	# 5e. BasicResourceManager 旧档静默补 0 / 新档读回
	var brm5 = BasicResourceManagerScript.new()
	brm5.load_state({"total_alloy": 7})  # v8 旧档无 production_points
	if brm5.get_production_points() == 0 and brm5.get_total("alloy") == 7:
		ok.call("旧档 load_state 缺 production_points 静默补 0")
	else:
		fail.call("旧档 production_points 默认异常")
	brm5.load_state({"production_points": 250})
	if brm5.get_production_points() == 250:
		ok.call("新档 load_state 读回 production_points = 250")
	else:
		fail.call("production_points 读回异常")
	# 5f. ModificationRegistry 经 SaveManager 键装载（直接以根键值调 load_state）
	var mr5 = ModificationRegistryScript.new()
	mr5.load_state(v9_data["mod_unlock_state"] as Dictionary)
	if mr5.is_mod_unlocked("gen_05_shield") and mr5.save_state().has("first_kill_enemy_master_002"):
		ok.call("解锁集含首杀标记整档恢复")
	else:
		fail.call("解锁集恢复不完整")

	# ══════════ 6. 词条定义完整性（C3 build-around）══════════
	print("\n=== 6. 词条定义完整性（5 个 special_mechanic + wired 池过滤）===")
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

	# ══════════ 7. P3-A 同源词条 roll 可复现 + 精材料掉落 ══════════
	print("\n=== 7. P3-A 词条可复现 + 精材料掉落 ===")
	var e1: Dictionary = EnemyLoadoutTiers.roll_loadout_affix_def(15, 3, 0, 0, 0, 2)
	var e2: Dictionary = EnemyLoadoutTiers.roll_loadout_affix_def(15, 3, 0, 0, 0, 2)
	if e1 == e2 and not e1.is_empty():
		ok.call("seeded roll 可复现（同关同波同槽 → 同词条：%s）" % String(e1.get("name", "")))
	else:
		fail.call("同 seed 两次 roll 结果不一致或为空")
	if EnemyLoadoutTiers.LOADOUT_AFFIX_MIN_TIER == 2:
		ok.call("挂词条门槛 = 中配档（TIER_MID=2）")
	else:
		fail.call("LOADOUT_AFFIX_MIN_TIER 应为 2")
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
		print("✅ P3 经济 smoke 全部 PASS（7 项验证）")
	else:
		print("❌ 存在失败断言，见上方 [FAIL]")
	print("═══════════════════════════════════════════════════════════")
	quit(code[0])
