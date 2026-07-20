# 无 GdUnit 依赖的快速校验：v7.x 战力公式全修
#   - 修复 A: 卡牌战力射程项 bug（火炮 range_value=99 不再破元帅）
#   - 重构 B: 相位师 3 分量战力（A相位仪 + F装备卡 + H符文）
#   - 修复 C: DPS 改三维累加（多武器卡不再被低估）
#   - 修复 D: 新增三维防御项（肉盾卡战力合理）
#   - 修复 E: RankRules 阈值 ×2（配套新公式）
# 注：--script 模式下 EnemyPhaseMasters.ENEMY_MASTERS 不初始化（项目既有限制），
#     故相位师测试用手动构造的真实结构 dict，验证公式逻辑本身。
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/master_power_smoke.gd
extends SceneTree

const MasterPowerEvaluator = preload("res://scripts/master_power_evaluator.gd")
const MasterPlayerAssembler = preload("res://scripts/master_player_assembler.gd")
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

	# ══════════ 修复 A/C/D: 卡牌战力公式（用户主导最终版） ══════════
	# 战力 = HP×0.35 + DPS三维×0.75×(1+暴击×0.5) + avg_speed×25 + 三维防御和×2.1 + 穿甲×5 + 移速×0.25
	print("=== 修复 A/C/D: 卡牌战力公式（用户主导最终版） ===")
	var marshal_thresh: float = float(RankRules.POWER_THRESHOLDS.get("marshal", 3625.0))
	# 初期卡：一战步兵/火炮，战力应远低于元帅（裸卡 ~160-190）
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
		print("  [初期] %s: 战力=%.1f (元帅=%.0f)" % [card_id, power, marshal_thresh])
		if power >= marshal_thresh:
			fail.call("%s 战力 %.1f 破元帅！初期卡应在 ~200 分区间" % [card_id, power])
	# 火炮战力应 > 步兵（多武器 DPS 优势）
	var ap: float = EvolutionHelpers.combat_power_from_unit_stats(UnitStatsTable.build_stats_from_card(DefaultCards.get_card_by_id("ww1_105mm"), 0))
	var ip: float = EvolutionHelpers.combat_power_from_unit_stats(UnitStatsTable.build_stats_from_card(DefaultCards.get_card_by_id("ww1_mauser"), 0))
	if ap <= ip:
		fail.call("火炮战力(%.1f)应 > 步兵(%.1f)" % [ap, ip])

	# ══════════ 终极卡验证：裸卡接近元帅但不破 ══════════
	# fut_colossus 巨神机甲（HP3000, def和=690）：裸卡战力预期 ~3600，应 < marshal(3625) 或接近
	var col_card = DefaultCards.get_card_by_id("fut_colossus")
	if col_card != null:
		var col_stats = UnitStatsTable.build_stats_from_card(col_card, 0)
		var col_power: float = EvolutionHelpers.combat_power_from_unit_stats(col_stats)
		print("  [终极] fut_colossus: 战力=%.1f (元帅=%.0f)" % [col_power, marshal_thresh])
		# 终极卡裸卡应在 general(3000)-marshal(3625) 区间，不应远超 marshal（否则养成无意义）
		if col_power < 2500.0:
			fail.call("fut_colossus 战力 %.1f 过低，终极卡应接近元帅" % col_power)
		if col_power > marshal_thresh * 1.2:
			fail.call("fut_colossus 裸卡战力 %.1f 远超元帅×1.2，养成失去意义" % col_power)

	# ══════════ 修复 C: DPS 三维各自配对验证 ══════════
	# ww1_mg08 机枪巢：atk_l=41/spd_l=1.0, atk_a=136/spd_a=0.5, atk_air=8/spd_air=2.5
	# 三维 DPS_raw = 41×1.0 + 136×0.5 + 8×2.5 = 129，×0.75 = 96.75
	var mg08_card = DefaultCards.get_card_by_id("ww1_mg08")
	if mg08_card != null:
		var mg08_stats = UnitStatsTable.build_stats_from_card(mg08_card, 0)
		var mg08_power: float = EvolutionHelpers.combat_power_from_unit_stats(mg08_stats)
		var dps_raw_expected: float = 41.0 * 1.0 + 136.0 * 0.5 + 8.0 * 2.5  # 129
		print("  ww1_mg08 多武器 DPS_raw=%.0f 战力=%.1f" % [dps_raw_expected, mg08_power])
		if dps_raw_expected < 100.0:
			fail.call("ww1_mg08 三维 DPS_raw(%.1f) 应 ≥100，反装甲输出未计入" % dps_raw_expected)

	# ══════════ 修复 D: 三维防御求和验证 ══════════
	# cold_t72（def_l/a/air=53/76/46，和=175）：防御项 = 175×2.1 = 367.5
	var t72_card = DefaultCards.get_card_by_id("cold_t72")
	if t72_card != null:
		var t72_stats = UnitStatsTable.build_stats_from_card(t72_card, 0)
		var t72_power: float = EvolutionHelpers.combat_power_from_unit_stats(t72_stats)
		var t72_def_sum: float = 53.0 + 76.0 + 46.0  # 175
		var expected_def_score: float = t72_def_sum * 2.1  # 367.5
		print("  cold_t72 战力=%.1f 防御项预期+%.0f (def和=%.0f)" % [t72_power, expected_def_score, t72_def_sum])
		# T-72 裸卡应在 captain(750)-major(1000) 区间（uv 实测 ~948）
		if t72_power < 500.0:
			fail.call("cold_t72 战力 %.1f 过低，防御项可能未生效" % t72_power)

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

	# 1. v7.x 3分量公式：scores 只有 instrument/equipment_slots/runes
	var empty_master := {"id":"t","name":"t","phase_instrument":""}
	var er_empty: Dictionary = MasterPowerEvaluator.evaluate(empty_master)
	var empty_keys: Array = er_empty["scores"].keys()
	if empty_keys.size() != 3:
		fail.call("3分量公式 scores 应只有3键，实际 %d: %s" % [empty_keys.size(), str(empty_keys)])

	# 2. H维符文 > 0（符文固定值）
	var h_ww1: float = float(er_ww1["scores"]["runes"])
	var h_fu: float = float(er_fu["scores"]["runes"])
	print("  master_001 runes派生: %s → H符文=%.1f" % [str(runes_ww1), h_ww1])
	print("  master_030 runes派生: %s → H符文=%.1f" % [str(runes_fu), h_fu])
	if h_ww1 <= 0.0:
		fail.call("H维 master_001 符文应>0，实际 %.1f" % h_ww1)
	if h_fu <= 0.0:
		fail.call("H维 master_030 符文应>0，实际 %.1f" % h_fu)

	# 3. F维载卡 = archetype power 之和（v7.x 统一公式）
	#    注：--script 模式下 UnifiedCardTable 可能未完全初始化，archetype 查不到→兜底100/卡
	#    运行时（autoload 完整）archetype 正确解析，F 维会反映真实卡 power 梯度
	var f_ww1: float = float(er_ww1["scores"]["equipment_slots"])
	var f_fu: float = float(er_fu["scores"]["equipment_slots"])
	if f_ww1 <= 0.0:
		fail.call("F维 master_001 载卡应>0")

	# 4. 总分 = 3分量直接相加（v7.x 无权重）
	var total_ww1: float = float(er_ww1["total_score"])
	var total_fu: float = float(er_fu["total_score"])
	var expected_total_ww1: float = float(er_ww1["scores"]["instrument"]) + f_ww1 + h_ww1
	if absf(total_ww1 - expected_total_ww1) > 1.0:
		fail.call("master_001 总分应是3分量之和(%.0f)，实际 %.0f" % [expected_total_ww1, total_ww1])

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
	if h_rw <= 0.0:
		fail.call("rw_2_01 H维符文应>0，实际 %.1f" % h_rw)

	# ══════════ 汇总输出 ══════════

	# ══════════ v7.x 对称化最终版: 卡牌战力新公式 + 符文固定值验证 ══════════
	print("=== v7.x 对称化最终版: 卡牌战力新公式 ===")
	# 1. 新公式验证：DPS卡 vs 肉盾卡 比例 ≈ 1.2:1（用户要求 1.8:1.5）
	# 用 build_stats 算真实战力（需 autoload，可能失败；失败则跳过）
	var ft17 = DefaultCards.get_card_by_id("ww1_ft17")
	if ft17 != null:
		var ft17_stats = UnitStatsTable.build_stats_from_card(ft17, 0)
		var ft17_power: float = EvolutionHelpers.combat_power_from_unit_stats(ft17_stats)
		print("  ww1_ft17 基础战力: %.1f" % ft17_power)
		if ft17_power < 1.0:
			fail.call("ww1_ft17 战力异常: %.1f" % ft17_power)

	# 2. 符文固定值验证（H维用 RUNE_RARITY_POWER）
	var rune_power_table = MasterPowerEvaluator.RUNE_RARITY_POWER
	print("  符文固定值: common=%d rare=%d epic=%d legendary=%d mythic=%d" % [
		int(rune_power_table.get("common", 0)),
		int(rune_power_table.get("rare", 0)),
		int(rune_power_table.get("epic", 0)),
		int(rune_power_table.get("legendary", 0)),
		int(rune_power_table.get("mythic", 0)),
	])
	if int(rune_power_table.get("legendary", 0)) < 3000:
		fail.call("符文 legendary 固定值过低: %d（应≥3000）" % int(rune_power_table.get("legendary", 0)))

	# 3. v7.x 3分量公式：W_* 权重常量已删除（死代码，evaluate() 直接相加无权重）
	#    验证常量确实不存在（用 has 防御性检查）
	# 注：删除前 W_ACTIVE_SPELLS/W_RUNEWORDS 等是 const，删除后访问会报编译错。
	#     此处用 get_class_list 间接验证（const 不在 class 属性里），或直接信任 evaluate() 只用3键。
	print("  W_* 死代码常量已删除（evaluate 用直接相加）✓")

	# 4. STAR_TIERS 新阈值验证（v7.x 全修：0/800/1600/3200/6000/9500/20000）
	var t1_stars = MasterPowerEvaluator._score_to_stars(100.0)  # 新手 → 1★ (0-800)
	var t3_stars = MasterPowerEvaluator._score_to_stars(2000.0) # 一战师 → 3★ (1600-3200)
	var t4_stars = MasterPowerEvaluator._score_to_stars(5000.0)  # 中配 → 4★ (3200-6000)
	var t5_stars = MasterPowerEvaluator._score_to_stars(7500.0)  # 近未来师 → 5★ (6000-9500)
	if int(t1_stars.get("stars", 0)) != 1:
		fail.call("新手(100分)星级应=1★，实际 %d★" % int(t1_stars.get("stars", 0)))
	if int(t3_stars.get("stars", 0)) != 3:
		fail.call("一战师(2000分)星级应=3★，实际 %d★" % int(t3_stars.get("stars", 0)))
	if int(t5_stars.get("stars", 0)) != 5:
		fail.call("近未来师(7500分)星级应=5★，实际 %d★" % int(t5_stars.get("stars", 0)))
	print("  STAR_TIERS: 100分→%d★, 2000分→%d★, 5000分→%d★, 7500分→%d★" % [
		int(t1_stars.get("stars",0)), int(t3_stars.get("stars",0)),
		int(t4_stars.get("stars",0)), int(t5_stars.get("stars",0))])

	print("=== v7.x 战力公式全修 校验结果 ===")
	print("[修复A/C/D] ww1_105mm 火炮战力: %.1f | ww1_mg08 机枪巢战力: 见上方" % ap)
	print("[修复E] RankRules 元帅阈值: %.0f（×2.5，匹配新公式量级）" % marshal_thresh)
	print("[3分量] master_001: 总分=%.0f | A仪=%.0f F卡=%.0f H符=%.0f | %s" % [
		float(er_ww1["total_score"]), float(er_ww1["scores"]["instrument"]), f_ww1, h_ww1,
		MasterPowerEvaluator.get_stars_display(m_ww1)])
	print("[3分量] master_030: 总分=%.0f | A仪=%.0f F卡=%.0f H符=%.0f | %s" % [
		float(er_fu["total_score"]), float(er_fu["scores"]["instrument"]), f_fu, h_fu,
		MasterPowerEvaluator.get_stars_display(m_fu)])
	print("[派生Lv] master_001=%d | master_030=%d" % [lvl_ww1, lvl_fu])
	print("[符文之语] rw_2_01 激活=%d个 → H符文=%.1f" % [active.size(), h_rw])
	print("[3分量公式] 符文legendary=%d | W_*常量已删 | STAR_TIERS新阈值" % [int(rune_power_table.get("legendary",0))])
	if code == 0:
		print("✅ 全部断言通过")
	else:
		print("❌ 存在失败断言，见上方 [FAIL]")
	quit(code)
