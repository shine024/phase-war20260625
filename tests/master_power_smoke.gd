# v7.x 单分量战力公式 smoke test
# 验证：相位师总战力 = Σ 每张装备卡经过完整加成后的实战力
#
# 本测试不依赖 GdUnit 框架，直接 extends SceneTree。
# 注：--script 模式下 autoload（InstanceRegistry/BlueprintManager/PhaseInstrumentManager 等）
#     不会初始化，所以玩家侧 compute_player_card_power 无法完整跑通（会因 bpm==null 走兜底）。
#     本测试聚焦于：
#       1) evaluate() 单分量结构（scores 只有 equipment_slots 一键）
#       2) 总分 = equipment_slots（无额外加权）
#       3) 敌方侧 archetype 加成链路（platforms 求和，手动构造 master dict）
#       4) 玩家侧 _player_platform_powers 注入优先级
#       5) STAR_TIERS 阈值连续性 + 星级映射
#       6) compute_display_level 在 [5,30] 且单调（近未来 > 一战）
#
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/master_power_smoke.gd
extends SceneTree

const MasterPowerEvaluator = preload("res://scripts/master_power_evaluator.gd")
const MasterPlatformPower = preload("res://scripts/master_platform_power.gd")
const MasterPlayerAssembler = preload("res://scripts/master_player_assembler.gd")
const PowerTiers = preload("res://data/power_tiers.gd")
const EvolutionHelpers = preload("res://managers/evolution/evolution_helpers.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")


func _initialize() -> void:
	var code := 0
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		code = 1

	print("═══════════════════════════════════════════════════════════")
	print("  v7.x 单分量战力公式验证（Σ 卡战力之和）")
	print("═══════════════════════════════════════════════════════════")

	# ══════════ 1. evaluate() 单分量结构验证 ══════════
	print("\n=== 1. evaluate() 返回单分量结构 ===")
	var test_master: Dictionary = {
		"name": "测试相位师",
		"equipment": {
			"phase_instrument": "steel_guardian_mk2",
			"platforms": ["ww1_inf_rifle", "ww1_sup_mg_nest"],
			"runes": ["attack_01", "attack_02"],
		},
		"stats": {"max_hp": 2000, "unit_limit": 7},
	}
	var ev: Dictionary = MasterPowerEvaluator.evaluate(test_master)
	var scores: Dictionary = ev.get("scores", {})
	var score_keys: Array = scores.keys()
	print("  scores 键: ", score_keys)
	# 应只有 1 个键：equipment_slots
	if score_keys.size() != 1:
		fail.call("单分量公式 scores 应只有 1 键，实际 %d: %s" % [score_keys.size(), str(score_keys)])
	if not scores.has("equipment_slots"):
		fail.call("scores 缺少 equipment_slots 键")
	# total = equipment_slots（无加权）
	var f_val: float = float(scores.get("equipment_slots", 0.0))
	var total_val: float = float(ev.get("total_score", -1.0))
	print("  equipment_slots=%.1f  total_score=%.1f" % [f_val, total_val])
	if absf(total_val - f_val) > 1.0:
		fail.call("总分应=equipment_slots(%.1f)，实际 %.1f" % [f_val, total_val])

	# ══════════ 2. 玩家侧注入优先级（_player_platform_powers）════════
	print("\n=== 2. 玩家侧 _player_platform_powers 注入优先 ===")
	# 模拟 assembler 注入的"加成后卡战力"
	var player_master: Dictionary = {
		"name": "玩家测试",
		"equipment": {
			"phase_instrument": "",
			"platforms": ["fake_card"],  # 应被忽略（优先读 _player_platform_powers）
			"runes": [],
		},
		"_player_platform_powers": [429.0, 350.0, 1200.0],  # 3 张卡加成后战力
		"_player_card_breakdown": [
			{"name": "FT17", "enhance": 5, "power": 429.0},
			{"name": "T72", "enhance": 3, "power": 350.0},
			{"name": "巨神", "enhance": 0, "power": 1200.0},
		],
	}
	var pev: Dictionary = MasterPowerEvaluator.evaluate(player_master)
	var pscores: Dictionary = pev.get("scores", {})
	var pf: float = float(pscores.get("equipment_slots", 0.0))
	var expected_pf: float = 429.0 + 350.0 + 1200.0  # 1979
	print("  玩家 equipment_slots=%.1f（期望 %.1f = 429+350+1200）" % [pf, expected_pf])
	if absf(pf - expected_pf) > 1.0:
		fail.call("玩家 equipment_slots 应=_player_platform_powers 之和(%.1f)，实际 %.1f" % [expected_pf, pf])
	# 验证 card_breakdown 透传到 details（供 UI 用）
	var pbreakdown: Array = pev.get("details", {}).get("card_breakdown", [])
	if pbreakdown.size() != 3:
		fail.call("details.card_breakdown 应透传 3 张卡，实际 %d" % pbreakdown.size())

	# ══════════ 3. 敌方侧 platforms 求和（archetype 加成链）════════
	print("\n=== 3. 敌方侧 platforms 加成链（archetype + master 加成）===")
	# 手动构造一战 vs 近未来相位师（结构对齐 enemy_phase_masters JSON）
	var m_ww1 := {
		"id": "enemy_master_001", "name": "钢铁先锋·马库斯", "faction": "steel", "era": 0,
		"phase_instrument": "steel_guardian_mk1",
		"stats": {"max_hp": 1500, "attack_power": 120, "defense": 80, "energy_regen": 2.0, "unit_limit": 5},
		"equipment": {
			"phase_instrument": "steel_guardian_mk1",
			"platforms": ["ww1_inf_rifle", "ww1_sup_mg_nest"],
			"runes": [],
		},
	}
	var m_fu := {
		"id": "enemy_master_030", "name": "全能相位师·奥米伽", "faction": "all", "era": 4,
		"phase_instrument": "steel_guardian_mk1",
		"stats": {"max_hp": 10000, "attack_power": 1000, "defense": 200, "energy_regen": 8.0, "unit_limit": 15},
		"equipment": {
			"phase_instrument": "steel_guardian_mk1",
			"platforms": ["fut_colossus", "fut_void_reaper"],
			"runes": [],
		},
	}
	var er_ww1: Dictionary = MasterPowerEvaluator.evaluate(m_ww1)
	var er_fu: Dictionary = MasterPowerEvaluator.evaluate(m_fu)
	var total_ww1: float = float(er_ww1.get("total_score", 0.0))
	var total_fu: float = float(er_fu.get("total_score", 0.0))
	print("  master_001(一战): 总战力=%.1f → %d★ %s" % [total_ww1, int(er_ww1.get("stars",0)), str(er_ww1.get("star_name",""))])
	print("  master_030(近未来): 总战力=%.1f → %d★ %s" % [total_fu, int(er_fu.get("stars",0)), str(er_fu.get("star_name",""))])
	if total_ww1 <= 0.0:
		fail.call("master_001 总战力应>0，实际 %.1f" % total_ww1)
	# 单调性：近未来 master stats 远强于一战，加成后战力也应更高
	if total_fu <= total_ww1:
		fail.call("master_030 总战力(%.1f)应 > master_001(%.1f)" % [total_fu, total_ww1])

	# ══════════ 4. 装卡数量影响战力（槽位数语义）════════
	print("\n=== 4. 装卡数量影响战力（槽位多→战力高）===")
	var m_2cards := {
		"name": "2张卡", "era": 0,
		"equipment": {"platforms": ["ww1_inf_rifle", "ww1_sup_mg_nest"], "runes": []},
		"stats": {},
	}
	var m_3cards := m_2cards.duplicate(true)
	(m_3cards["equipment"] as Dictionary)["platforms"] = ["ww1_inf_rifle", "ww1_sup_mg_nest", "ww1_inf_rifle"]
	# 走玩家侧注入路径（精确控制每张卡战力，避免 archetype 查询波动）
	m_2cards["_player_platform_powers"] = [100.0, 200.0]
	m_3cards["_player_platform_powers"] = [100.0, 200.0, 300.0]
	var ev_2: Dictionary = MasterPowerEvaluator.evaluate(m_2cards)
	var ev_3: Dictionary = MasterPowerEvaluator.evaluate(m_3cards)
	print("  2张卡(100+200)=%.1f  3张卡(100+200+300)=%.1f" % [float(ev_2.total_score), float(ev_3.total_score)])
	if float(ev_3.total_score) <= float(ev_2.total_score):
		fail.call("装更多卡战力应更高：3张(%.1f)应>2张(%.1f)" % [float(ev_3.total_score), float(ev_2.total_score)])

	# ══════════ 5. STAR_TIERS 阈值连续性 ══════════
	print("\n=== 5. STAR_TIERS 阈值连续性 ===")
	var prev_max: int = 0
	for tier in MasterPowerEvaluator.STAR_TIERS:
		print("  %d★ %-4s  %d ~ %d" % [
			int(tier.stars), str(tier.name),
			int(tier.min_score), int(tier.max_score)])
		if int(tier.min_score) != prev_max:
			fail.call("%d★ min_score(%d) 应=上一档 max_score(%d)" % [int(tier.stars), int(tier.min_score), prev_max])
		prev_max = int(tier.max_score)

	# ══════════ 6. compute_display_level 在 [5,30] 且单调 ══════════
	print("\n=== 6. compute_display_level 单调性 ===")
	var lvl_ww1: int = EnemyPhaseMasters.compute_display_level(m_ww1)
	var lvl_fu: int = EnemyPhaseMasters.compute_display_level(m_fu)
	print("  master_001 Lv=%d  master_030 Lv=%d" % [lvl_ww1, lvl_fu])
	if lvl_ww1 < 5 or lvl_ww1 > 30:
		fail.call("master_001 Lv=%d 越界 [5,30]" % lvl_ww1)
	if lvl_fu < 5 or lvl_fu > 30:
		fail.call("master_030 Lv=%d 越界 [5,30]" % lvl_fu)
	if lvl_fu <= lvl_ww1:
		fail.call("master_030 Lv(%d)应 > master_001 Lv(%d)" % [lvl_fu, lvl_ww1])

	# ══════════ 7. get_tier_by_stars 映射（掉落梯度依赖）════════
	print("\n=== 7. get_tier_by_stars 映射 ===")
	var tier_cases := {
		1: PowerTiers.Tier.GRUNT, 2: PowerTiers.Tier.VETERAN,
		3: PowerTiers.Tier.ELITE, 4: PowerTiers.Tier.CHAMPION,
		5: PowerTiers.Tier.CHAMPION, 6: PowerTiers.Tier.OVERLORD,
		7: PowerTiers.Tier.OVERLORD, 0: PowerTiers.Tier.GRUNT,
		99: PowerTiers.Tier.OVERLORD,
	}
	for stars in tier_cases:
		if PowerTiers.get_tier_by_stars(stars) != tier_cases[stars]:
			fail.call("get_tier_by_stars(%d) 错误" % stars)
	print("  get_tier_by_stars 9 case 全部正确 ✓")

	# ══════════ 8. 单卡战力公式健全性（build_stats + combat_power）════════
	print("\n=== 8. 单卡战力公式（combat_power_from_unit_stats）===")
	# --script 模式下 UnitStatsTable.build_stats_from_card 可能因 autoload 缺失而失败
	# 此处只做"如果能跑通"的健全性检查
	var ft17 = DefaultCards.get_card_by_id("ww1_ft17")
	if ft17 != null:
		var ft17_stats = UnitStatsTable.build_stats_from_card(ft17, 0)
		if ft17_stats != null:
			var ft17_power: float = EvolutionHelpers.combat_power_from_unit_stats(ft17_stats)
			print("  ww1_ft17 基础战力: %.1f" % ft17_power)
			if ft17_power < 1.0:
				fail.call("ww1_ft17 战力异常: %.1f" % ft17_power)
		else:
			print("  ww1_ft17 build_stats 返回 null（--script 模式 autoload 限制，跳过）")
	else:
		print("  ww1_ft17 卡牌未找到（跳过）")

	print("\n═══════════════════════════════════════════════════════════")
	if code == 0:
		print("✅ 全部 PASS（8 项验证）")
	else:
		print("❌ 存在失败断言，见上方 [FAIL]")
	print("═══════════════════════════════════════════════════════════")
	quit(code)
