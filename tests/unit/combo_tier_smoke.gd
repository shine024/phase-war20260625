# v21 P1 多模组合 4 件套（满档）+ 6 行为改写传奇改造 smoke test
# （不依赖 GdUnit，extends SceneTree 直跑，同 tests/unit/aura_range_smoke.gd 范式）
# 验证：
#   1) 6 套路 mod_combo_full / full_mechanisms / desc_full 数据完整
#   2) detect_card_combo_tiers 三态（无/basic/full）+ detect_card_combos 向后兼容
#   3) 6 传奇改造数据完整性（注册表可取、id/唯一效果键/传奇档）
#   4) 消费点源码级接线断言（零弹道路由改动的只读消费）
#
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/unit/combo_tier_smoke.gd
extends SceneTree

const ComboTactics = preload("res://data/combo_tactics.gd")
# v21 P1 教训：注册表/通用改造模块不在 const preload——依赖链拉入 unit_stats_table
#（引用 autoload ModificationRegistry），--script 模式首过解析早于 autoload 注册会产生
# 编译噪音（universal_mods.gd:521 函数内 const preload default_cards 同理）。
# 改为 _initialize（autoload 就绪后）内 load。

const COMBO_IDS := [
	"incendiary_chain", "emp_chain", "nano_field",
	"laser_resonance", "recon_chain", "chem_pollution",
]
const LEGENDARY_IDS := [
	"gen_converted_munitions", "gen_expansion_chamber", "gen_overflow_shield",
	"gen_truestrike_pinpoint", "gen_relay_antenna", "gen_unified_splash",
]


func _initialize() -> void:
	# v18 教训：GDScript lambda 按值捕获局部变量，用数组持有者传导失败
	var code := [0]
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		code[0] = 1
	var ok := func(msg: String) -> void:
		print("  [PASS] " + msg)
	# 源码读取器（lambda 持有，供接线断言用）
	var src_holder := {}
	var _src := func(path: String) -> String:
		if src_holder.has(path):
			return String(src_holder[path])
		var f := FileAccess.open(path, FileAccess.READ)
		var s := f.get_as_text() if f != null else ""
		src_holder[path] = s
		return s

	print("═══════════════════════════════════════════════════════════")
	print("  v21 P1 多模组合 4 件套 + 行为改写传奇改造验证")
	print("═══════════════════════════════════════════════════════════")

	# ══════════ 1. 6 套路满档字段完整性 ══════════
	print("\n=== 1. 6 套路 mod_combo_full / full_mechanisms / desc_full ===")
	for cid in COMBO_IDS:
		var def: Dictionary = ComboTactics.COMBOS.get(cid, {})
		if def.is_empty():
			fail.call("套路 %s 缺定义" % cid)
			continue
		var full_list: Array = def.get("mod_combo_full", [])
		if full_list.is_empty():
			fail.call("套路 %s 缺 mod_combo_full" % cid)
			continue
		# 满档列表必须是配套列表的子集（同一批 id）
		var mod_ids: Array = def.get("mod_ids", [])
		var subset: bool = true
		for fid in full_list:
			if not mod_ids.has(fid):
				subset = false
		if not subset:
			fail.call("套路 %s mod_combo_full 含配套列表外的 id" % cid)
			continue
		if String(def.get("desc_full", "")).is_empty():
			fail.call("套路 %s 缺 desc_full" % cid)
			continue
		if (def.get("full_mechanisms", []) as Array).is_empty():
			fail.call("套路 %s 缺 full_mechanisms" % cid)
			continue
		ok.call("%s 满档字段完整（%d 件套 → %s）" % [cid, full_list.size(), str(def.get("full_mechanisms"))])

	# ══════════ 2. 档位检测三态 ══════════
	print("\n=== 2. detect_card_combo_tiers / detect_card_combos ===")
	var inc: Dictionary = ComboTactics.COMBOS[ComboTactics.COMBO_INCENDIARY]
	var inc_ids: Array = inc.get("mod_ids", [])
	var t0: Dictionary = ComboTactics.detect_card_combo_tiers([])
	if t0.is_empty():
		ok.call("空改造列表 → 空 tier 表")
	else:
		fail.call("空改造列表不应有 tier")
	var basic_mods: Array = [inc_ids[0], inc_ids[1]]   # 2 件 → basic
	var t1: Dictionary = ComboTactics.detect_card_combo_tiers(basic_mods)
	if t1.get(ComboTactics.COMBO_INCENDIARY, "") == ComboTactics.TIER_BASIC:
		ok.call("2 件配套 → basic")
	else:
		fail.call("2 件配套应为 basic，实得 %s" % str(t1))
	# 3 件（缺 1）→ 仍 basic（不满档误触发防护）
	var t2: Dictionary = ComboTactics.detect_card_combo_tiers([inc_ids[0], inc_ids[1], inc_ids[2]])
	if t2.get(ComboTactics.COMBO_INCENDIARY, "") == ComboTactics.TIER_BASIC:
		ok.call("3/4 件 → basic（缺一不满档）")
	else:
		fail.call("3/4 件应为 basic，实得 %s" % str(t2))
	# 4 件全 → full
	var t3: Dictionary = ComboTactics.detect_card_combo_tiers(inc_ids.duplicate())
	if t3.get(ComboTactics.COMBO_INCENDIARY, "") == ComboTactics.TIER_FULL:
		ok.call("集齐 4 件 → full")
	else:
		fail.call("集齐 4 件应为 full，实得 %s" % str(t3))
	# 满档机制提取
	var fmechs: Array = ComboTactics.get_full_mechanisms([ComboTactics.COMBO_INCENDIARY])
	if fmechs.has("incendiary_death_seed"):
		ok.call("get_full_mechanisms 提取 incendiary_death_seed")
	else:
		fail.call("get_full_mechanisms 缺 incendiary_death_seed，实得 %s" % str(fmechs))
	# 旧 API 向后兼容：仍返回 Array，2 件即激活
	var legacy: Array = ComboTactics.detect_card_combos(basic_mods)
	if legacy is Array and legacy.has(ComboTactics.COMBO_INCENDIARY):
		ok.call("detect_card_combos 仍返回 Array 且 2 件激活（向后兼容）")
	else:
		fail.call("detect_card_combos 行为变化：%s" % str(legacy))

	# ══════════ 3. 6 传奇改造数据完整性 ══════════
	print("\n=== 3. 6 行为改写传奇改造 ===")
	var ModRegistry: Script = load("res://scripts/systems/modification_registry.gd")
	var UniversalMods: Script = load("res://data/modification_modules/universal_mods.gd")
	ModRegistry.register_all()
	for lid in LEGENDARY_IDS:
		var data: Dictionary = ModRegistry.get_data(lid)
		if data.is_empty():
			fail.call("改造 %s 注册表取不到" % lid)
			continue
		for key in ["id", "name", "name_en", "prototype", "description", "rarity", "effects", "conflict_group", "cost_research", "cost_install", "applicable_types"]:
			if not data.has(key):
				fail.call("改造 %s 缺字段 %s" % [lid, key])
		if String(data.get("rarity", "")) != "legendary":
			fail.call("改造 %s 应为 legendary" % lid)
		if (data.get("effects", {}) as Dictionary).is_empty():
			fail.call("改造 %s effects 为空" % lid)
	var um_all: Array = UniversalMods.DATA.keys()
	var um_legend_count: int = 0
	for k in um_all:
		if String(UniversalMods.DATA[k].get("rarity", "")) == "legendary" and String(k).begins_with("gen_"):
			um_legend_count += 1
	if um_legend_count >= 6:
		ok.call("universal_mods 传奇 gen_ 条目 ≥6（实得 %d）" % um_legend_count)
	else:
		fail.call("universal_mods 传奇 gen_ 条目不足 6（实得 %d）" % um_legend_count)
	# 关键效果键
	var key_expect := {
		"gen_converted_munitions": "converted_munitions",
		"gen_expansion_chamber": "expansion_chamber",
		"gen_overflow_shield": "overflow_to_shield",
		"gen_truestrike_pinpoint": "dodge_ignore",
		"gen_relay_antenna": "relay_antenna",
	}
	for lid2 in key_expect.keys():
		var d2: Dictionary = ModRegistry.get_data(String(lid2))
		if (d2.get("effects", {}) as Dictionary).has(key_expect[lid2]):
			ok.call("%s 携带效果键 %s" % [lid2, key_expect[lid2]])
		else:
			fail.call("%s 缺效果键 %s" % [lid2, key_expect[lid2]])
	var us: Dictionary = ModRegistry.get_data("gen_unified_splash")
	if float((us.get("effects", {}) as Dictionary).get("splash_damage", 0.0)) > 0.0:
		ok.call("gen_unified_splash 携带 splash_damage（注册表既有键，cap 0.8）")
	else:
		fail.call("gen_unified_splash 缺 splash_damage")
	# 全模块注册总数实测锁定（与 tests/unit/data/modification_modules_test.gd 同口径 190：
	# 184 + 6 传奇）。此处同步断言，防止两处口径漂移。
	var total_ids: int = (ModRegistry.get_all_ids() as Array).size()
	if total_ids == 190:
		ok.call("注册表总数实测 = 190（184+6，与 GdUnit 断言同口径）")
	else:
		fail.call("注册表总数应 190，实得 %d（若增删改造请同步两处断言）" % total_ids)

	# ══════════ 4. 消费点源码级接线断言 ══════════
	print("\n=== 4. 消费点接线（源码级）===")
	# 4.1 unit_stats_table：combo_tiers meta + 中继天线 range_override
	var ust: String = _src.call("res://resources/unit_stats_table.gd")
	if ust.contains("detect_card_combo_tiers") and ust.contains("combo_tiers"):
		ok.call("unit_stats_table 写 combo_tiers meta")
	else:
		fail.call("unit_stats_table 缺 combo_tiers 接线")
	if ust.contains("gen_relay_antenna") and ust.contains("range_override"):
		ok.call("unit_stats_table 中继天线 range_override=-1 接线")
	else:
		fail.call("unit_stats_table 缺中继天线接线")
	# 4.2 combo_engine：满档扫描 + 三个满档机制分支
	var ce: String = _src.call("res://scripts/battle/combo_engine.gd")
	for token in ["_scan_full_tiers", "nano_decay_half", "emp_reflect_stun", "chem_cross_column", "incendiary_death_seed", "is_combo_full", "on_units_changed"]:
		if ce.contains(token):
			ok.call("combo_engine 接线 %s" % token)
		else:
			fail.call("combo_engine 缺 %s" % token)
	# 4.3 combo_field_state：衰减系数
	var cfs: String = _src.call("res://scripts/battle/combo_field_state.gd")
	if cfs.contains("decay_scale"):
		ok.call("combo_field_state 支持 decay_scale")
	else:
		fail.call("combo_field_state 缺 decay_scale")
	# 4.4 bullet：反射次数+1 / 弱点全队共享（只读消费，不动路由）
	var bl: String = _src.call("res://scenes/units/bullet.gd")
	if bl.contains("beam_reflect_plus1"):
		ok.call("bullet 消费 beam_reflect_plus1")
	else:
		fail.call("bullet 缺 beam_reflect_plus1")
	if bl.contains("weakpoint_team_share"):
		ok.call("bullet 消费 weakpoint_team_share")
	else:
		fail.call("bullet 缺 weakpoint_team_share")
	# 4.5 attack_calculator：维度转换
	var ac: String = _src.call("res://scripts/battle/attack_calculator.gd")
	for token2 in ["_has_converted_munitions", "convert_defense_dimension", "converted_munitions"]:
		if ac.contains(token2):
			ok.call("attack_calculator 接线 %s" % token2)
		else:
			fail.call("attack_calculator 缺 %s" % token2)
	# 4.6 受击侧三处接线（enemy_unit × 2 / swarm × 2 / construct_unit heal）
	var eu: String = _src.call("res://scenes/units/enemy_unit.gd")
	if eu.contains("convert_defense_dimension") and eu.contains("get_attacker_dodge_ignore"):
		ok.call("enemy_unit.take_damage 接转换+闪避无视")
	else:
		fail.call("enemy_unit.take_damage 接线缺失")
	var sw: String = _src.call("res://scenes/units/swarm_enemy_slot.gd")
	if sw.contains("convert_defense_dimension") and sw.contains("get_attacker_dodge_ignore"):
		ok.call("swarm_enemy_slot.take_damage 接转换+闪避无视")
	else:
		fail.call("swarm_enemy_slot.take_damage 接线缺失")
	var cu: String = _src.call("res://scenes/units/construct_unit.gd")
	if cu.contains("overflow_to_shield"):
		ok.call("construct_unit.heal 接溢流护盾")
	else:
		fail.call("construct_unit.heal 缺溢流护盾")
	# 4.7 扩容弹舱
	var tai: String = _src.call("res://scripts/battle/target_selection.gd")
	var cai: String = _src.call("res://scripts/battle/construct_unit_ai.gd")
	if tai.contains("select_expansion_target") and cai.contains("_try_expansion_shot") and cai.contains("_expansion_extra_firing"):
		ok.call("扩容弹舱：选目标 + 递归守卫接线")
	else:
		fail.call("扩容弹舱接线缺失")
	# 4.8 统一装药（仅曲射 batch；bullet 兜底不动）
	var ib: String = _src.call("res://managers/battle/simple_indirect_projectile_batch.gd")
	if ib.contains("splash_ratio") and ib.contains("splash_damage"):
		ok.call("曲射 batch 溅射比例读 shooter splash_damage（回退 0.5）")
	else:
		fail.call("曲射 batch 缺统一装药接线")
	# 4.9 中继天线只读边界：P0 三文件不得被改动（守卫性断言——内容应不含 v21 P1 标记）
	for ro in ["res://scripts/battle/mod_aura_handler.gd", "res://data/aura_data.gd", "res://managers/aura_manager.gd"]:
		var ros: String = _src.call(ro)
		if ros.contains("v21 P1"):
			fail.call("只读文件被改动：%s" % ro)
		else:
			ok.call("只读边界保持：%s" % ro)

	# ══════════ 收尾 ══════════
	print("\n═══════════════════════════════════════════════════════════")
	if code[0] == 0:
		print("  ✅ 全部通过")
	else:
		print("  ❌ 存在失败项（见 [FAIL]）")
	print("═══════════════════════════════════════════════════════════")
	quit(int(code[0]))
