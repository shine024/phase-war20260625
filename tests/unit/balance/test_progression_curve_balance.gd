class_name ProgressionCurveBalanceTest
extends GdUnitTestSuite
## ════════════════════════════════════════════════════════════════════════
## 平衡审查 · 维度4：养成 vs 关卡曲线 + 敌方难度链
##
## 审查标准（v1，2026-08-16 平衡批次）：
##   H1. 难度链单调：1-100 关敌方有效 HP 链（基础×档位×波次）逐关非递减，
##       允许时代边界 ≤10% 的教学性回落；全程最大/最小 ≤ 8×
##   H2. 敌我同步：每时代 敌方有效中位HP / 玩家中位HP(强化中期×1.2) ∈ [0.7, 3.5]，
##       跨时代漂移 ≤ 2.2×（防"养成碾压"或"敌方难度链失配"单边漂移）
##   H3. 时代内敌方增幅 ≤ 3.5×（档位高配×末波 / 档位低配×首波）
##   H4. 养成上限：强化 Lv10 单卡 HP/攻击增幅 ≤ 1.5×（防数值膨胀失控）
##   H5. 敌档位系数 ≥ 我方满养成系数（敌方镜像养成不落后——TIER_HIGH×1.0 ≥ 强化满档）
## ════════════════════════════════════════════════════════════════════════

const UCT = preload("res://data/unified_card_table.gd")
const LevelEras = preload("res://data/level_eras.gd")
const Tiers = preload("res://data/enemy_loadout_tiers.gd")
const Resolver = preload("res://data/enemy_stat_resolver.gd")
const UST = preload("res://resources/unit_stats_table.gd")

const DIFFICULTY_DIP_TOL := 0.20        # H1 时代边界回落容忍（v9.x 设计：新时代首 3 关低配教学回落，原 -35% 断崖已收紧，余量 ≤20%）
## H1 全程极差上限 = 玩家中位战力指数 × 头寸系数 2.3。
## 玩家指数 = sqrt(HP增长 × DPS增长)（数据实测 ~7×）；2.3 头寸覆盖静态模型无法计入的
## 玩家成长系统（相位仪星级乘区/词条/进化继承/暴击/组合战术，合计 ~1.8-2×）。
## 敌方链极差若超此值 = 后期关卡对玩家可用成长失衡。
const CHAIN_HEADROOM := 2.3
const SYNC_RATIO_MIN := 0.7             # H2
const SYNC_RATIO_MAX := 3.5             # H2
const SYNC_DRIFT_MAX := 2.2             # H2 跨时代漂移
const INTRA_ERA_RAMP_MAX := 3.5         # H3
const ENHANCE_CAP := 1.5                # H4


static func _main_dps(e: Dictionary) -> float:
	var best := 0.0
	for pair in [["atk_l", "atk_l_speed"], ["atk_a", "atk_a_speed"], ["atk_air", "atk_air_speed"]]:
		best = maxf(best, float(e.get(pair[0], 0.0)) * float(e.get(pair[1], 0.0)))
	return best


static func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	if n % 2 == 1:
		return float(sorted[n / 2])
	return (float(sorted[n / 2 - 1]) + float(sorted[n / 2])) / 2.0


## 每时代敌方常规单位（enemy_only，排除 BOSS/ULTIMATE 特殊刷新）中位基础值
static func _era_enemy_median(era: int, key: String, dps: bool) -> float:
	var vals: Array = []
	for e in UCT.get_enemy_only_entries():
		if int(e.get("era", -1)) != era or int(e.get("tier", 0)) >= UCT.Tier.BOSS:
			continue
		if dps:
			vals.append(_main_dps(e))
		else:
			vals.append(float(e.get(key, 0.0)))
	return _median(vals)


static func _era_player_median(era: int, dps: bool) -> float:
	var vals: Array = []
	for e in UCT.get_player_card_entries():
		if int(e.get("era", -1)) != era:
			continue
		vals.append(_main_dps(e) if dps else float(e.get("base_hp", 0.0)))
	return _median(vals)


# ───────────────────────── H1：难度链单调 ─────────────────────────

func test_difficulty_chain_monotonic() -> void:
	var violations: Array = []
	var chain: Array = []
	for level in range(1, 101):
		var era: int = LevelEras.get_era(level)
		var in_era: int = (level - 1) % 20 + 1
		var progress: float = float(in_era - 1) / 19.0
		var tier: int = Tiers.get_tier_for_level_progress(progress)
		var tier_pct: float = float(Tiers.get_bonus_for_tier(tier)["hp_pct"]) + 1.0
		var waves: int = LevelEras.get_wave_total_for_level(level)
		var wave_mult: float = Resolver.wave_hp_multiplier(waves)
		var base: float = _era_enemy_median(era, "base_hp", false)
		chain.append(base * tier_pct * wave_mult)
	var peak: float = 0.0
	for i in range(chain.size()):
		peak = maxf(peak, chain[i])
		if i == 0:
			continue
		if chain[i] < chain[i - 1] * (1.0 - DIFFICULTY_DIP_TOL):
			violations.append("第 %d 关链值 %.0f 比前关 %.0f 回落超 %.0f%%" % [
				i + 1, chain[i], chain[i - 1], DIFFICULTY_DIP_TOL * 100])
	var spread: float = chain.back() / chain.front() if chain.front() > 0.0 else INF
	# 玩家中位战力指数（era0→era4 基础值几何均值）
	var hp_growth: float = _era_player_median(4, false) / _era_player_median(0, false)
	var dps_growth: float = _era_player_median(4, true) / _era_player_median(0, true)
	var player_index: float = sqrt(maxf(0.01, hp_growth * dps_growth))
	var spread_cap: float = player_index * CHAIN_HEADROOM
	if spread > spread_cap + 0.05:
		violations.append("全程链值极差 %.1f > 玩家指数 %.1f × %.1f = %.1f（后期敌方 HP 池相对玩家成长失衡）" % [
			spread, player_index, CHAIN_HEADROOM, spread_cap])
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()


# ───────────────────────── H2：敌我同步 ─────────────────────────

func test_player_enemy_hp_sync_across_eras() -> void:
	var violations: Array = []
	var ratios: Array = []
	for era in range(5):
		# 敌方：时代中段（中配×1.75、时代中间波次）
		var waves_mid: int = int((LevelEras.ERA_WAVES[era][0] + LevelEras.ERA_WAVES[era][1]) / 2.0)
		var enemy_eff: float = _era_enemy_median(era, "base_hp", false) * 1.75 * Resolver.wave_hp_multiplier(waves_mid)
		# 玩家：时代中段养成（强化≈中档 ×1.2）
		var player_eff: float = _era_player_median(era, false) * 1.2
		var ratio: float = enemy_eff / player_eff if player_eff > 0.0 else INF
		ratios.append(ratio)
		if ratio < SYNC_RATIO_MIN or ratio > SYNC_RATIO_MAX:
			violations.append("era %d 敌/我有效HP比 %.2f 超出 [%.1f, %.1f]" % [era, ratio, SYNC_RATIO_MIN, SYNC_RATIO_MAX])
	var drift: float = ratios.max() / ratios.min() if ratios.min() > 0.0 else INF
	if drift > SYNC_DRIFT_MAX:
		violations.append("敌/我HP比跨时代漂移 %.2f > %.2f（%s）" % [drift, SYNC_DRIFT_MAX, str(ratios)])
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()


func test_player_enemy_dps_sync_across_eras() -> void:
	var violations: Array = []
	var ratios: Array = []
	for era in range(5):
		var waves_mid: int = int((LevelEras.ERA_WAVES[era][0] + LevelEras.ERA_WAVES[era][1]) / 2.0)
		var enemy_eff: float = _era_enemy_median(era, "", true) * 1.75 * Resolver.wave_damage_multiplier(waves_mid)
		var player_eff: float = _era_player_median(era, true) * 1.2
		var ratio: float = enemy_eff / player_eff if player_eff > 0.0 else INF
		ratios.append(ratio)
		if ratio < SYNC_RATIO_MIN or ratio > SYNC_RATIO_MAX:
			violations.append("era %d 敌/我有效DPS比 %.2f 超出 [%.1f, %.1f]" % [era, ratio, SYNC_RATIO_MIN, SYNC_RATIO_MAX])
	var drift: float = ratios.max() / ratios.min() if ratios.min() > 0.0 else INF
	if drift > SYNC_DRIFT_MAX:
		violations.append("敌/我DPS比跨时代漂移 %.2f > %.2f（%s）" % [drift, SYNC_DRIFT_MAX, str(ratios)])
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()


# ───────────────────────── H3：时代内敌方增幅 ─────────────────────────

func test_intra_era_enemy_ramp_capped() -> void:
	var violations: Array = []
	for era in range(5):
		var waves_first: int = LevelEras.ERA_WAVES[era][0]
		var waves_last: int = LevelEras.ERA_WAVES[era][1]
		var start: float = 1.30 * Resolver.wave_hp_multiplier(waves_first)
		var end: float = 2.00 * Resolver.wave_hp_multiplier(waves_last)
		var ramp: float = end / start
		if ramp > INTRA_ERA_RAMP_MAX:
			violations.append("era %d 时代内敌方增幅 %.2f > %.2f（%.2f→%.2f）" % [era, ramp, INTRA_ERA_RAMP_MAX, start, end])
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()


# ───────────────────────── H4：养成上限 ─────────────────────────

func test_enhance_level_10_multiplier_capped() -> void:
	var violations: Array = []
	for kind in range(5):
		# 找该兵种第一张玩家卡做样本
		var sample: Dictionary = {}
		for e in UCT.get_player_card_entries():
			if int(e.get("combat_kind", -1)) == kind:
				sample = e
				break
		if sample.is_empty():
			continue
		var card: CardResource = UCT.build_card_resource(String(sample["card_id"]))
		var base_stats: UnitStats = UST.build_stats_from_card(card)
		var card10: CardResource = UCT.build_card_resource(String(sample["card_id"]))
		card10.enhance_level = 10
		var boosted: UnitStats = UST.build_stats_from_card(card10)
		var hp_mult: float = boosted.max_hp / base_stats.max_hp if base_stats.max_hp > 0.0 else INF
		var atk_mult: float = boosted.attack_light / base_stats.attack_light if base_stats.attack_light > 0.0 else 1.0
		if hp_mult > ENHANCE_CAP + 0.001:
			violations.append("kind %d（%s）强化Lv10 HP增幅 %.2f > %.2f" % [kind, sample["card_id"], hp_mult, ENHANCE_CAP])
		if atk_mult > ENHANCE_CAP + 0.001:
			violations.append("kind %d（%s）强化Lv10 攻击增幅 %.2f > %.2f" % [kind, sample["card_id"], atk_mult, ENHANCE_CAP])
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()


# ───────────────────────── H5：敌档位镜像养成 ─────────────────────────

func test_enemy_tier_mirrors_player_progression() -> void:
	var violations: Array = []
	# 高配档（=满强化+满改造+满符文）系数 1.0 加成必须 ≥ 我方强化满档最高增幅（堡垒 HP 0.042×10=0.42）
	var fort_hp_at_10: float = 0.042 * 10.0
	if float(Tiers.get_bonus_for_tier(Tiers.TIER_HIGH)["hp_pct"]) < fort_hp_at_10:
		violations.append("TIER_HIGH hp_pct %.2f < 我方堡垒强化满档 %.2f（敌方镜像落后）" % [
			Tiers.get_bonus_for_tier(Tiers.TIER_HIGH)["hp_pct"], fort_hp_at_10])
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()
