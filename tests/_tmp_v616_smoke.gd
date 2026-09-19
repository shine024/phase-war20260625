extends SceneTree
## v6.16 改造爽感批次冒烟（--script 模式）：加载全部改动文件 + 核心断言。
## 通过判据：最后打印 V616_SMOKE_OK。

const ModBreakpoints = preload("res://data/mod_breakpoints.gd")
const ModManager = preload("res://managers/evolution/mod_manager.gd")
const ModRegistry = preload("res://scripts/systems/modification_registry.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const LevelInfo = preload("res://data/level_information.gd")
const Advisor = preload("res://data/build_advisor.gd")
const GameCfg = preload("res://resources/game_config.gd")

func _init() -> void:
	var fails: Array[String] = []

	# ── 1. 断点档位 ──
	if int(ModBreakpoints.resolve(0.45)["tier"]) != 2:
		fails.append("breakpoint tier@0.45 != 2")
	if absf(float(ModBreakpoints.resolve(0.45)["speed_mult"]) - 1.12) > 0.001:
		fails.append("breakpoint mult@0.45 != 1.12")

	# ── 2. 武器槽消费（含 stats 同调） ──
	var stats := UnitStats.new()
	stats.attack_light_speed = 1.5
	stats.attack_armor_speed = 1.0
	stats.attack_air_speed = 1.0
	var w := WeaponResource.new()
	w.enabled = true
	w.attack_speed = 1.0
	w.windup = 0.2
	w.damage = 100.0
	UnitStatsTable._sync_mod_speed_ratio_to_weapon_slots(stats, [w, null, null], [1.0, 1.0, 1.0])
	if absf(float(w.attack_speed) - 1.5 * 1.12) > 0.002:
		fails.append("weapon speed %.3f != %.3f" % [float(w.attack_speed), 1.5 * 1.12])
	if absf(float(w.windup) - 0.1) > 0.002:
		fails.append("windup %.3f != 0.1" % float(w.windup))
	if absf(float(stats.attack_light_speed) - 1.5 * 1.12) > 0.002:
		fails.append("stats side not synced")

	# ── 3. 槽位预算 ──
	var c := CardResource.new()
	c.rarity = "mythic"
	c.combat_kind = 4
	if ModManager.get_max_mod_slots_for_card(c) != 12:
		fails.append("mythic fort slots %d != 12" % ModManager.get_max_mod_slots_for_card(c))
	c.rarity = "common"
	c.combat_kind = 0
	if ModManager.get_max_mod_slots_for_card(c) != 6:
		fails.append("common light slots != 6")

	# ── 4. 注册表：稀有度收敛 + 家族索引 + 门槛件 ──
	ModRegistry.register_all()
	var counts: Dictionary = {}
	for mid in ModRegistry.get_all_ids():
		var r: String = String(ModRegistry.get_data(mid).get("rarity", "?"))
		counts[r] = int(counts.get(r, 0)) + 1
	if int(counts.get("legendary", -1)) != 39:
		fails.append("legendary %d != 39" % int(counts.get("legendary", -1)))
	if int(counts.get("epic", -1)) != 88:
		fails.append("epic %d != 88" % int(counts.get("epic", -1)))
	if ModRegistry.get_all_ids().size() != 249:
		fails.append("total != 249")
	if not ModRegistry.is_family_mod("inf_05_ap_ammo"):
		fails.append("inf_05 should be family mod")
	if ModRegistry.is_family_mod("enh_dmg_up"):
		fails.append("enh_dmg_up should NOT be family mod")
	for kid in ModRegistry.KEYSTONE_IDS:
		var kd: Dictionary = ModRegistry.get_data(kid)
		if kd.is_empty() or not bool(kd.get("keystone", false)):
			fails.append("keystone %s missing/flag" % kid)
	# 统一装药 0.70 溅射 + 主目标代价
	var us: Dictionary = ModRegistry.get_data("gen_unified_splash")
	if absf(float(us.get("effects", {}).get("splash_damage", 0.0)) - 0.70) > 0.001:
		fails.append("unified splash != 0.70")

	# ── 5. 反制配波挂载 + 顾问 ──
	var li = LevelInfo.get_shared()
	if not (li.get_special_rules(33).get("counter_bias_tags", []) as Array).has("armored"):
		fails.append("L33 counter armored missing")
	if not li.get_special_rules(1).is_empty():
		fails.append("L1 should stay rule-free")
	var tips: Array = Advisor.get_build_tips(43)
	if tips.is_empty() or not String(tips[0]).contains("装甲"):
		fails.append("L43 advisor tip missing: %s" % str(tips))

	# ── 6. GameConfig 开关存在且默认开 ──
	var cfg := GameCfg.get_default()
	if not cfg.mod_breakpoints_enabled or not cfg.mod_slot_budget_enabled:
		fails.append("switches not default-on")

	# ── 结果 ──
	if fails.is_empty():
		print("V616_SMOKE_OK")
	else:
		for f2 in fails:
			print("SMOKE_FAIL: " + f2)
		push_error("v616 smoke failed: %d issues" % fails.size())
	quit(0 if fails.is_empty() else 1)
