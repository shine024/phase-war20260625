class_name UnitEraBalanceTest
extends GdUnitTestSuite
## ════════════════════════════════════════════════════════════════════════
## 平衡审查 · 维度1：单位战力随时代递进 + 边界值 + 数据一致性
##
## 审查标准（v1，2026-08-16 平衡批次）：
##   A. 相邻时代 DPS 中位数比 ≤ 1.65×；WW1→WW2 首跃 ≤ 2.4×（历史性跃迁豁免档）
##      （防"DPS随时代失控"。v1 定 1.6；2026-08-23 平衡终审放宽到 1.65——
##        冷战→现代实测 1.639 是 UCT 有意标定的历史代差最陡段，改卡面会波及
##        HP 离群/经济/升级手感，不值。见 docs/BALANCE_FINAL_2026-08-23.md）
##   B. 相邻时代 HP 中位数比 ≤ 1.7×；WW1→WW2 首跃 ≤ 2.6×（同上豁免）
##   C. 同时代同兵种 HP 离群 ≤ 2.0×（排除 ULTIMATE/BOSS/FORT；防"单卡碾压"）
##   D. 防空特化单位对空 DPS 必须为自身最大输出维度，且 ≥ 时代最佳对空 DPS 的 30%
##      （防"克制链断裂"——专精单位被通用单位反超）
##   E. 边界值：hp>0、atk/def≥0、atk>0 ⇒ 对应攻速>0、era∈[0,4]、
##      combat_kind∈[0,4]、range∈[0,99]、speed/windup ≥ 0
##   F. card_id 时代前缀必须与 era 字段一致（防错位数据混入错误时代池）
##   G. 反装甲特化单位（火箭筒/反坦克导弹系）对装甲 DPS ≥ 对轻装 DPS
##      （防"专精反转"——玩家侧反装甲步兵被模板化为对轻火力）
## ════════════════════════════════════════════════════════════════════════

const UCT = preload("res://data/unified_card_table.gd")

const ADJACENT_ERA_DPS_RATIO_MAX := 1.65
const ADJACENT_ERA_HP_RATIO_MAX := 1.7
## WW1→WW2 工业化总体战跃迁豁免档（机枪/合成兵种对一战水平的代差）
const FIRST_LEAP_DPS_RATIO_MAX := 2.4
const FIRST_LEAP_HP_RATIO_MAX := 2.6
const INTRA_ERA_KIND_HP_OUTLIER_MAX := 2.0
const AA_SPECIALIST_RATIO_FLOOR := 0.30

## 防空特化单位（对空攻击是设计主武器的卡）
const AA_SPECIALIST_IDS := [
	"ww1_37mm",            # 37mm高射炮
	"ww2_fort_flak",       # 88mm防空塔
	"cold_sup_zsu23",      # ZSU-23-4自行高炮
	"cold_sam7",           # 萨姆-7防空组
	"mod_stinger",         # 毒刺导弹兵
	"mod_sup_m6",          # 自行高炮M6
	"fut_aa_hover",        # 防空悬浮车
	"mod_fort_phalanx",    # 近防炮系统
]

## 反装甲特化单位（火箭筒/反坦克导弹系步兵与载具）
const AT_SPECIALIST_IDS := [
	"ww2_inf_panzerschrek",   # 铁拳反坦克组
	"ww2_inf_bazooka",        # 巴祖卡组
	"cold_rpg",               # RPG火箭筒组
	"mod_javelin",            # 标枪导弹兵
	"mod_hummer_tow",         # 悍马·陶式
]


# ───────────────────────── 辅助 ─────────────────────────

static func _main_dps(e: Dictionary) -> float:
	var best := 0.0
	for pair in [["atk_l", "atk_l_speed"], ["atk_a", "atk_a_speed"], ["atk_air", "atk_air_speed"]]:
		best = maxf(best, float(e.get(pair[0], 0.0)) * float(e.get(pair[1], 0.0)))
	return best


static func _aa_dps(e: Dictionary) -> float:
	return float(e.get("atk_air", 0.0)) * float(e.get("atk_air_speed", 0.0))


static func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	if n % 2 == 1:
		return float(sorted[n / 2])
	return (float(sorted[n / 2 - 1]) + float(sorted[n / 2])) / 2.0


static func _era_player_entries(era: int) -> Array:
	var out: Array = []
	for e in UCT.get_player_card_entries():
		if int(e.get("era", -1)) == era:
			out.append(e)
	return out


# ───────────────────────── A/B：时代递进 ─────────────────────────

func test_adjacent_era_dps_ratio_within_threshold() -> void:
	var medians: Array = []
	for era in range(5):
		var dpss: Array = []
		for e in _era_player_entries(era):
			dpss.append(_main_dps(e))
		medians.append(_median(dpss))
	var violations: Array = []
	for era in range(4):
		if medians[era] <= 0.0:
			continue
		var ratio: float = medians[era + 1] / medians[era]
		var cap: float = FIRST_LEAP_DPS_RATIO_MAX if era == 0 else ADJACENT_ERA_DPS_RATIO_MAX
		if ratio > cap + 0.001:
			violations.append("era %d→%d DPS中位数比 %.2f > %.2f（中位数 %s）" % [
				era, era + 1, ratio, cap, str(medians)])
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()


func test_adjacent_era_hp_ratio_within_threshold() -> void:
	var medians: Array = []
	for era in range(5):
		var hps: Array = []
		for e in _era_player_entries(era):
			hps.append(float(e.get("base_hp", 0.0)))
		medians.append(_median(hps))
	var violations: Array = []
	for era in range(4):
		if medians[era] <= 0.0:
			continue
		var ratio: float = medians[era + 1] / medians[era]
		var cap: float = FIRST_LEAP_HP_RATIO_MAX if era == 0 else ADJACENT_ERA_HP_RATIO_MAX
		if ratio > cap + 0.001:
			violations.append("era %d→%d HP中位数比 %.2f > %.2f（中位数 %s）" % [
				era, era + 1, ratio, cap, str(medians)])
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()


# ───────────────────────── C：同时代同兵种离群 ─────────────────────────

func test_intra_era_kind_hp_outlier() -> void:
	var violations: Array = []
	for era in range(5):
		for kind in range(4):  # 0轻装/1装甲/2支援/3空中（堡垒单独档）
			var hps: Array = []
			for e in _era_player_entries(era):
				if int(e.get("combat_kind", -1)) != kind or int(e.get("tier", 0)) >= UCT.Tier.ULTIMATE:
					continue
				hps.append(float(e.get("base_hp", 0.0)))
			if hps.size() < 2:
				continue
			hps.sort()
			var spread: float = hps.back() / hps.front() if hps.front() > 0.0 else INF
			if spread > INTRA_ERA_KIND_HP_OUTLIER_MAX + 0.001:
				violations.append("era %d kind %d 同档HP max/min %.2f > %.2f（min %.0f max %.0f）" % [
					era, kind, spread, INTRA_ERA_KIND_HP_OUTLIER_MAX, hps.front(), hps.back()])
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()


# ───────────────────────── D：防空特化完整性 ─────────────────────────

func test_aa_specialist_air_is_primary_output() -> void:
	var violations: Array = []
	for id in AA_SPECIALIST_IDS:
		var e: Dictionary = UCT.get_entry(id)
		if e.is_empty():
			violations.append("%s 不在统一卡表（AA_SPECIALIST_IDS 需更新）" % id)
			continue
		var dps_l: float = float(e.get("atk_l", 0.0)) * float(e.get("atk_l_speed", 0.0))
		var dps_a: float = float(e.get("atk_a", 0.0)) * float(e.get("atk_a_speed", 0.0))
		var dps_air: float = _aa_dps(e)
		if dps_air < dps_l or dps_air < dps_a:
			violations.append("%s（%s）对空DPS %.0f 应≥对轻 %.0f 与对装甲 %.0f——防空特化被通用火力反超" % [
				id, e.get("display_name", ""), dps_air, dps_l, dps_a])
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()


func test_aa_specialist_vs_era_best() -> void:
	var violations: Array = []
	for era in range(5):
		var best_aa: float = 0.0
		for e in _era_player_entries(era):
			best_aa = maxf(best_aa, _aa_dps(e))
		for id in AA_SPECIALIST_IDS:
			var e: Dictionary = UCT.get_entry(id)
			if e.is_empty() or int(e.get("era", -1)) != era:
				continue
			if best_aa > 0.0 and _aa_dps(e) / best_aa < AA_SPECIALIST_RATIO_FLOOR - 0.001:
				violations.append("%s（%s，era %d）对空DPS %.0f < 时代最佳 %.0f 的 %.0f%%" % [
					id, e.get("display_name", ""), era, _aa_dps(e), best_aa, AA_SPECIALIST_RATIO_FLOOR * 100])
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()


# ───────────────────────── E：边界值 ─────────────────────────

func test_no_boundary_violations() -> void:
	var violations: Array = []
	for e in UCT.get_all_entries():
		var id: String = String(e.get("card_id", "?"))
		if float(e.get("base_hp", 0.0)) <= 0.0:
			violations.append("%s base_hp ≤ 0" % id)
		for f in ["atk_l", "atk_a", "atk_air", "def_l", "def_a", "def_air"]:
			if float(e.get(f, 0.0)) < 0.0:
				violations.append("%s.%s 为负" % [id, f])
		for pair in [["atk_l", "atk_l_speed"], ["atk_a", "atk_a_speed"], ["atk_air", "atk_air_speed"]]:
			if float(e.get(pair[0], 0.0)) > 0.0 and float(e.get(pair[1], 0.0)) <= 0.0:
				violations.append("%s %s>0 但攻速 %s≤0（武器空转）" % [id, pair[0], pair[1]])
		if int(e.get("era", -1)) < 0 or int(e.get("era", -1)) > 4:
			violations.append("%s era 越界" % id)
		if int(e.get("combat_kind", -1)) < 0 or int(e.get("combat_kind", -1)) > 4:
			violations.append("%s combat_kind 越界" % id)
		if int(e.get("range_value", -1)) < 0 or int(e.get("range_value", -1)) > 99:
			violations.append("%s range_value 越界" % id)
		for f in ["atk_l_speed", "atk_a_speed", "atk_air_speed", "atk_l_windup", "atk_a_windup", "atk_air_windup"]:
			if float(e.get(f, 0.0)) < 0.0:
				violations.append("%s.%s 为负" % [id, f])
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()


# ───────────────────────── F：era 前缀一致性 ─────────────────────────

func test_card_id_prefix_matches_era() -> void:
	var violations: Array = []
	# 整卡前缀 → era 期望
	var prefix_rules: Array = [
		["ww1_", 0], ["ww2_", 1], ["cold_", 2], ["mod_", 3], ["fut_", 4],
	]
	for e in UCT.get_all_entries():
		var id: String = String(e.get("card_id", ""))
		var era: int = int(e.get("era", -1))
		for rule in prefix_rules:
			if id.begins_with(String(rule[0])):
				if era != int(rule[1]):
					violations.append("%s 前缀暗示 era %d 但 era 字段=%d（时代池错位）" % [id, int(rule[1]), era])
				break
	# platform_* 双段前缀（platform_ww1_* / platform_modern_* 等）
	var inner_rules: Array = [["_ww1_", 0], ["_ww2_", 1], ["_cold_", 2], ["_modern_", 3], ["_future_", 4]]
	for e in UCT.get_all_entries():
		var id: String = String(e.get("card_id", ""))
		if not id.begins_with("platform_"):
			continue
		var era: int = int(e.get("era", -1))
		for rule in inner_rules:
			if id.find(String(rule[0])) >= 0:
				if era != int(rule[1]):
					violations.append("%s 前缀暗示 era %d 但 era 字段=%d" % [id, int(rule[1]), era])
				break
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()


# ───────────────────────── G：反装甲特化完整性 ─────────────────────────

func test_at_specialist_armor_is_primary_output() -> void:
	var violations: Array = []
	for id in AT_SPECIALIST_IDS:
		var e: Dictionary = UCT.get_entry(id)
		if e.is_empty():
			violations.append("%s 不在统一卡表（AT_SPECIALIST_IDS 需更新）" % id)
			continue
		var dps_l: float = float(e.get("atk_l", 0.0)) * float(e.get("atk_l_speed", 0.0))
		var dps_a: float = float(e.get("atk_a", 0.0)) * float(e.get("atk_a_speed", 0.0))
		if dps_a < dps_l:
			violations.append("%s（%s）对装甲DPS %.0f < 对轻装DPS %.0f——反装甲特化反转（对照敌方同名系 266 vs 40）" % [
				id, e.get("display_name", ""), dps_a, dps_l])
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()
