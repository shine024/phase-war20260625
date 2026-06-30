# 无 GdUnit 依赖的快速校验：v7.x 相位师战力派生系统（第二轮）
#   - 修复 A: 卡牌战力射程项 bug（火炮 range_value=99 不再破元帅）
#   - 重构 B: 相位师 4 分量战力 + 新增 H 维符文 + 重构 F 维载卡
# 注：--script 模式下 EnemyPhaseMasters.ENEMY_MASTERS 不初始化（项目既有限制），
#     故相位师测试用手动构造的真实结构 dict，验证公式逻辑本身。
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/master_power_smoke.gd
extends SceneTree

const MasterPowerEvaluator = preload("res://scripts/master_power_evaluator.gd")
const PowerTiers = preload("res://data/power_tiers.gd")
const EvolutionHelpers = preload("res://managers/evolution/evolution_helpers.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const RankRules = preload("res://data/rank_rules.gd")
const RunewordDefs = preload("res://data/runewords.gd")
const RunewordMatcher = preload("res://managers/runeword_matcher.gd")
const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")


func _initialize() -> void:
	var code := 0
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		code = 1

	# ══════════ 修复 A: 射程项 bug 验证 ══════════
	print("=== 修复 A: 卡牌战力射程项 ===")
	var marshal_thresh: float = float(RankRules.POWER_THRESHOLDS.get("marshal", 1450.0))
	# 火炮卡：range_value=99（attack_range=9900像素，修复前射程项=2178破元帅）
	for card_id in ["ww1_105mm", "ww1_77mm", "ww1_mauser"]:
		var card = DefaultCards.get_card_by_id(card_id)
		if card == null:
			fail.call("卡牌未找到: %s" % card_id)
			continue
		var stats = UnitStatsTable.build_stats_from_card(card, 0)
		if stats == null:
			fail.call("build_stats 失败: %s" % card_id)
			continue
		var power: float = EvolutionHelpers.combat_power_from_unit_stats(stats)
		print("  %s: range_value=%d → 战力=%.1f (元帅=%.0f)" % [card_id, card.range_value, power, marshal_thresh])
		if power >= marshal_thresh:
			fail.call("%s 战力 %.1f 破元帅！射程修复未生效" % [card_id, power])
	# 火炮战力应 > 步兵（射程优势保留但不失控）
	var ap: float = EvolutionHelpers.combat_power_from_unit_stats(UnitStatsTable.build_stats_from_card(DefaultCards.get_card_by_id("ww1_105mm"), 0))
	var ip: float = EvolutionHelpers.combat_power_from_unit_stats(UnitStatsTable.build_stats_from_card(DefaultCards.get_card_by_id("ww1_mauser"), 0))
	if ap <= ip:
		fail.call("火炮战力(%.1f)应 > 步兵(%.1f)" % [ap, ip])

	# ══════════ 重构 B: 相位师 4 分量（手动构造真实结构） ══════════
	print("=== 重构 B: 相位师 4 分量战力 ===")

	# 构造一战相位师（手动构造，结构对齐 enemy_phase_masters 数据）
	var m_ww1 := {
		"id": "enemy_master_001", "name": "钢铁先锋·马库斯", "faction": "steel",
		"phase_instrument": "steel_guardian_mk1",
		"traits": [{"id":"recruit_commander","effects":{"defense_boost":0.10,"deploy_cooldown_reduction":0.05}}],
		"active_spells": [{"effect":"summon_units","params":{"count":3},"cooldown":15.0,"mana_cost":80}],
		"passive_spells": [{"effect":"armor_boost","params":{"bonus":0.15}}],
		"stats": {"max_hp": 1500, "attack_power": 120, "defense": 80, "energy_regen": 2.0, "unit_limit": 5},
		"equipment": {
			"platforms": ["steel_fortress_basic", "steel_titan_basic"],
			"weapons": ["steel_machinegun_basic"],
			"energy_cards": ["steel_energy_basic"],
			"runes": [],   # 稍后填入
		},
	}
	# 用 _derive_runes 直接派生符文（绕过 get_enriched_equipment 的 ENEMY_MASTERS 依赖）
	var runes_ww1: Array = EnemyPhaseMasters._derive_runes(5, "steel", "enemy_master_001")
	(m_ww1["equipment"] as Dictionary)["runes"] = runes_ww1

	# 构造近未来相位师
	var m_fu := {
		"id": "enemy_master_030", "name": "全能相位师·奥米伽", "faction": "all",
		"phase_instrument": "steel_guardian_mk1",
		"traits": [{"id":"master_of_all","effects":{"all_damage_boost":0.50}}],
		"active_spells": [{"effect":"combo_ultimate","params":{"damage":2000},"cooldown":30.0,"mana_cost":300}],
		"passive_spells": [{"effect":"goddess_mastery","params":{"bonus":0.5}}],
		"stats": {"max_hp": 10000, "attack_power": 1000, "defense": 200, "energy_regen": 8.0, "unit_limit": 15},
		"equipment": {
			"platforms": ["steel_fortress_advanced", "steel_titan_advanced"],
			"weapons": ["steel_cannon_advanced"],
			"energy_cards": ["steel_energy_advanced"],
			"runes": [],
		},
	}
	var runes_fu: Array = EnemyPhaseMasters._derive_runes(30, "all", "enemy_master_030")
	(m_fu["equipment"] as Dictionary)["runes"] = runes_fu

	var er_ww1: Dictionary = MasterPowerEvaluator.evaluate(m_ww1)
	var er_fu: Dictionary = MasterPowerEvaluator.evaluate(m_fu)

	# 1. G维空(我方无 stats)→0
	var empty_master := {"id":"t","name":"t","phase_instrument":""}
	var er_empty: Dictionary = MasterPowerEvaluator.evaluate(empty_master)
	if float(er_empty["scores"]["master_stats"]) != 0.0:
		fail.call("G维 无stats应=0")

	# 2. H维单符文 + I维符文之语 都 > 0（拆分后各自独立计分）
	var h_ww1: float = float(er_ww1["scores"]["runes"])
	var h_fu: float = float(er_fu["scores"]["runes"])
	var i_ww1: float = float(er_ww1["scores"].get("runewords", 0.0))
	var i_fu: float = float(er_fu["scores"].get("runewords", 0.0))
	print("  master_001 runes派生: %s → H单符文=%.1f I符文之语=%.1f" % [str(runes_ww1), h_ww1, i_ww1])
	print("  master_030 runes派生: %s → H单符文=%.1f I符文之语=%.1f" % [str(runes_fu), h_fu, i_fu])
	if h_ww1 <= 0.0:
		fail.call("H维 master_001 单符文应>0，实际 %.1f" % h_ww1)
	if h_fu <= 0.0:
		fail.call("H维 master_030 单符文应>0，实际 %.1f" % h_fu)
	if i_ww1 <= 0.0:
		fail.call("I维 master_001 符文之语应>0，实际 %.1f" % i_ww1)
	if i_fu <= 0.0:
		fail.call("I维 master_030 符文之语应>0，实际 %.1f" % i_fu)

	# 3. F维载卡 > 0（敌方平台卡战力）
	var f_ww1: float = float(er_ww1["scores"]["equipment_slots"])
	var f_fu: float = float(er_fu["scores"]["equipment_slots"])
	if f_ww1 <= 0.0:
		fail.call("F维 master_001 载卡应>0")
	if f_fu <= f_ww1:
		fail.call("F维 master_030(%.1f)应 > master_001(%.1f)" % [f_fu, f_ww1])

	# 4. G维近未来 > 一战（时代递进）
	var g_ww1: float = float(er_ww1["scores"]["master_stats"])
	var g_fu: float = float(er_fu["scores"]["master_stats"])
	if g_fu <= g_ww1:
		fail.call("G维 master_030(%.1f)应 > master_001(%.1f)" % [g_fu, g_ww1])

	# 5. compute_display_level 在 [5,30]
	var lvl_ww1: int = EnemyPhaseMasters.compute_display_level(m_ww1)
	var lvl_fu: int = EnemyPhaseMasters.compute_display_level(m_fu)
	if lvl_ww1 < 5 or lvl_ww1 > 30 or lvl_fu < 5 or lvl_fu > 30:
		fail.call("派生Lv越界 ww1=%d fu=%d" % [lvl_ww1, lvl_fu])
	if lvl_fu <= lvl_ww1:
		fail.call("派生Lv master_030(%d)应 > master_001(%d)" % [lvl_fu, lvl_ww1])

	# 6. get_tier_by_stars 映射
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

	# 7. H维公式验证：用 rw_2_01 的 required_runes 必然激活该词
	var rw201: Dictionary = RunewordDefs.get_runeword("rw_2_01")
	var rw_runes: Array = rw201.get("required_runes", [])
	var active: Array = RunewordMatcher.check_active_runewords(rw_runes, rw_runes.size())
	if active.size() < 1:
		fail.call("rw_2_01 required_runes 应激活该词")
	var m_rw := {"id":"t","name":"t","phase_instrument":"","equipment":{"runes":rw_runes,"platforms":[],"weapons":[],"energy_cards":[]}}
	var er_rw: Dictionary = MasterPowerEvaluator.evaluate(m_rw)
	var h_rw: float = float(er_rw["scores"]["runes"])
	var i_rw: float = float(er_rw["scores"].get("runewords", 0.0))
	if h_rw <= 0.0:
		fail.call("rw_2_01 H维单符文应>0，实际 %.1f" % h_rw)
	if i_rw <= 0.0:
		fail.call("rw_2_01 I维符文之语应>0，实际 %.1f" % i_rw)

	# ══════════ 汇总输出 ══════════
	print("=== v7.x 第二轮 校验结果 ===")
	print("[修复A] ww1_105mm 火炮战力: %.1f (修复前破元帅2178+)" % ap)
	print("[重构B] master_001: 总分=%.0f | F载卡=%.0f G本体=%.0f H符文=%.0f I词=%.0f | %s" % [
		float(er_ww1["total_score"]), f_ww1, g_ww1, h_ww1, i_ww1,
		MasterPowerEvaluator.get_stars_display(m_ww1)])
	print("[重构B] master_030: 总分=%.0f | F载卡=%.0f G本体=%.0f H符文=%.0f I词=%.0f | %s" % [
		float(er_fu["total_score"]), f_fu, g_fu, h_fu, i_fu,
		MasterPowerEvaluator.get_stars_display(m_fu)])
	print("[派生Lv] master_001=%d | master_030=%d" % [lvl_ww1, lvl_fu])
	print("[符文之语] rw_2_01 激活=%d个 → H单符文=%.1f I符文之语=%.1f" % [active.size(), h_rw, i_rw])
	if code == 0:
		print("✅ 全部断言通过")
	else:
		print("❌ 存在失败断言，见上方 [FAIL]")
	quit(code)
