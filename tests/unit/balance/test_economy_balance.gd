class_name EconomyBalanceTest
extends GdUnitTestSuite
## ════════════════════════════════════════════════════════════════════════
## 平衡审查 · 维度2：经济速率（收入曲线 / 水槽压力 / 能量经济 / MOD 上限）
##
## 审查标准（v1，2026-08-16 平衡批次）：
##   E1. 部署能耗差异化：玩家卡 energy_cost 极差 ≥ 1.5× 且最小 ≥ 3
##      （防"群海与终极单位同价"——战中能量无约束力）
##   E2. 收入曲线：1-100 关主收入（基础结算+战后纳米追加）逐关非递减，
##       时代边界跳变 ≤ 2.0×（防断崖通胀/通缩）
##   E3. 改造水槽同步：每时代"中位战力卡满改 9 槽成本 / 10 关收入" ∈ [0.1, 1.5]，
##       跨时代漂移 ≤ 4×（防后期水槽形同虚设——改造免费化通缩）
##   E4. MOD 效果上限：任何单条改造效果
##       攻速类 |v| ≤ 0.5；属性类 |v| ≤ 0.6；概率类 ∈ [0, 0.35]；伤害比例 ≤ 1.5
##   E5. 首关可负担性：era0 第 1 关收入 ≥ 最便宜改造安装费（开局节奏保障）
## ════════════════════════════════════════════════════════════════════════

const UCT = preload("res://data/unified_card_table.gd")
const BasicResources = preload("res://data/basic_resources.gd")
const ModEffects = preload("res://data/mod_effects.gd")

const INCOME_ERA_JUMP_MAX := 2.0
const MOD_SINK_RATIO_MIN := 0.1
const MOD_SINK_RATIO_MAX := 1.5
const MOD_SINK_DRIFT_MAX := 4.0

## 改造模块文件（递归扫描 effects 上限）
const MODULE_FILES := [
	"res://data/modification_modules/infantry_mods.gd",
	"res://data/modification_modules/armor_mods.gd",
	"res://data/modification_modules/artillery_mods.gd",
	"res://data/modification_modules/anti_air_mods.gd",
	"res://data/modification_modules/air_mods.gd",
	"res://data/modification_modules/recon_mods.gd",
	"res://data/modification_modules/engineer_mods.gd",
	"res://data/modification_modules/fort_mods.gd",
	"res://data/modification_modules/universal_mods.gd",
	"res://data/modification_modules/enhancement_mods.gd",
]

## 效果键 → 上限类别
const CAP_SPEED := 0.5      # 攻速/间隔/命中削减（分数）
const CAP_STAT := 0.6       # 攻防/HP 百分比（分数）
const CAP_CHANCE := 0.35    # 概率类
const CAP_RATIO := 1.5      # 伤害比例类
const CAP_ABS_SPEED := 60.0 # 绝对移速加成（px/s）
const SPEED_KEYS := ["attack_interval", "speed_mult", "accuracy_mult"]
const CHANCE_KEYS := ["crit_chance", "dodge_chance", "stun_chance", "double_damage_chance", "crit_bonus"]
const RATIO_KEYS := ["damage_ratio", "splash_pct", "death_explosion"]
const ABS_SPEED_KEYS := ["move_speed", "urban_move_bonus"]
## 批次8（2026-08-23）：属性键双语义——v18.b 改造分层后 uncommon/rare 属性条用
## 固定值（attack_light=8 替换武器面板伤害 / max_hp=60 插板加血 / defense_light=15
## 插板加防，消费端 += 加算），与百分比键同键不同语义。
## |v|>1 判为固定值口径，另设包络上限 = UCT 全玩家卡对应维度最大值
## （单一改造条不该大过游戏里任何一张卡的本征数值；现值远低于包络）。
static var _abs_caps: Dictionary = {}


static func _uct_abs_cap(family: String) -> float:
	if not _abs_caps.has(family):
		var m: float = 0.0
		for e in UCT.get_player_card_entries():
			match family:
				"attack":
					for f in ["atk_l", "atk_a", "atk_air"]:
						m = maxf(m, float(e.get(f, 0.0)))
				"defense":
					for f in ["def_l", "def_a", "def_air"]:
						m = maxf(m, float(e.get(f, 0.0)))
				"hp":
					m = maxf(m, float(e.get("base_hp", 0.0)))
		_abs_caps[family] = m
	return float(_abs_caps[family])
## 绝对值/计数/时序/乘数展示/非平衡敏感键（不按分数扫描）
const SKIP_KEYS := ["deploy_speed_bonus", "range_bonus", "stun_duration", "hp_regen_pct",
	"energy_refund_pct", "shield_pct", "armor_break_resist", "condition_slot", "slot",
	"required_level", "weapon_type", "slot_weapon_type", "power_mult", "cost_research",
	"cost_install", "attack_range", "range_value", "deploy_speed", "active", "speed",
	"energy_reduction", "id", "name", "desc", "type", "condition_type",
	"attack_multiplier", "windup", "ally_river_bonus", "armor_break_stacks",
	"emp_true_damage_bonus"]


static func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	if n % 2 == 1:
		return float(sorted[n / 2])
	return (float(sorted[n / 2 - 1]) + float(sorted[n / 2])) / 2.0


## 单关主收入模型：基础结算纳米 + 战后纳米追加（game_manager 公式 10+3L+L^1.15）
## + 胜利保底纳米中值（drop_tables 时代表 × 关卡缩放中值 1.25）
static func _battle_income_nano(level: int) -> float:
	var drops: Dictionary = BasicResources.get_drops_for_level(level)
	var basic: float = float(drops.get("nano_materials", 0))
	var gm_bonus: float = 10.0 + level * 3.0 + float(int(pow(level, 1.15)))
	var era: int = clampi(int((level - 1) / 20.0), 0, 4)
	var guarantee_mid: float = [40.0, 65.0, 85.0, 105.0, 130.0][era] * 1.25
	return basic + gm_bonus + guarantee_mid


## 满改 9 槽成本（blueprint_manager 2026-08-16 修复后公式：
## Σ max(60,power)×0.5×(1+0.2k), k=0..8 = 8.1×max(60,power)）
static func _full_mod_cost(power: int) -> float:
	return 8.1 * maxf(60.0, float(power))


# ───────────────────────── E1：部署能耗差异化 ─────────────────────────

func test_deploy_energy_differentiated() -> void:
	var violations: Array = []
	var costs: Array = []
	for e in UCT.get_player_card_entries():
		var card: CardResource = UCT.build_card_resource(String(e["card_id"]))
		if card == null:
			continue
		costs.append(float(card.energy_cost))
	costs.sort()
	var span: float = costs.back() / costs.front() if costs.front() > 0.0 else INF
	if costs.front() < 3.0:
		violations.append("最小部署能耗 %.0f < 3" % costs.front())
	if span < 1.5:
		violations.append("部署能耗极差 %.2f < 1.5（全卡同价，能量经济无约束力；min %.0f max %.0f）" % [
			span, costs.front(), costs.back()])
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()


# ───────────────────────── E2：收入曲线 ─────────────────────────

func test_income_curve_monotonic_with_bounded_era_jumps() -> void:
	var violations: Array = []
	for level in range(1, 100):
		var curr: float = _battle_income_nano(level + 1)
		var prev: float = _battle_income_nano(level)
		var ratio: float = curr / prev if prev > 0.0 else INF
		if curr < prev - 0.5:
			violations.append("第 %d→%d 关收入回落 %.0f→%.0f" % [level, level + 1, prev, curr])
		if level % 20 == 0 and ratio > INCOME_ERA_JUMP_MAX:
			violations.append("时代边界 %d→%d 收入跳变 %.2f > %.2f" % [level, level + 1, ratio, INCOME_ERA_JUMP_MAX])
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()


# ───────────────────────── E3：改造水槽同步 ─────────────────────────

func test_mod_sink_vs_income_sync() -> void:
	var violations: Array = []
	var ratios: Array = []
	for era in range(5):
		var powers: Array = []
		for e in UCT.get_player_card_entries():
			if int(e.get("era", -1)) == era:
				powers.append(int(e.get("power", 10)))
		var med_power: int = int(_median(powers))
		var sink: float = _full_mod_cost(med_power)
		var mid_level: int = era * 20 + 10
		var income10: float = 0.0
		for l in range(mid_level - 4, mid_level + 6):
			income10 += _battle_income_nano(l)
		var ratio: float = sink / income10 if income10 > 0.0 else INF
		ratios.append(ratio)
		if ratio < MOD_SINK_RATIO_MIN or ratio > MOD_SINK_RATIO_MAX:
			violations.append("era %d 满改成本/10关收入 = %.2f 超出 [%.2f, %.2f]（中位战力 %d，成本 %.0f，收入 %.0f）" % [
				era, ratio, MOD_SINK_RATIO_MIN, MOD_SINK_RATIO_MAX, med_power, sink, income10])
	var drift: float = ratios.max() / ratios.min() if ratios.min() > 0.0 else INF
	if drift > MOD_SINK_DRIFT_MAX:
		violations.append("水槽压力跨时代漂移 %.2f > %.2f（%s）" % [drift, MOD_SINK_DRIFT_MAX, str(ratios)])
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()


# ───────────────────────── E4：MOD 效果上限 ─────────────────────────

func _scan_effect_caps(container, source: String, violations: Array) -> void:
	if container == null:
		return
	if container is Dictionary:
		for key in container.keys():
			var val = container[key]
			var key_str := str(key)
			if val is Dictionary:
				_scan_effect_caps(val, source + "." + key_str, violations)
				continue
			if val is Array:
				for item in val:
					if item is Dictionary:
						_scan_effect_caps(item, source + "." + key_str, violations)
				continue
			if not (val is float or val is int):
				continue
			if key_str in SKIP_KEYS:
				continue
			var v: float = float(val)
			if key_str in SPEED_KEYS:
				if absf(v) > CAP_SPEED + 0.001:
					violations.append("%s.%s = %.2f 超攻速类上限 %.2f" % [source, key_str, v, CAP_SPEED])
			elif key_str in ABS_SPEED_KEYS:
				if absf(v) > CAP_ABS_SPEED + 0.001:
					violations.append("%s.%s = %.1f 超绝对移速上限 %.0f px/s" % [source, key_str, v, CAP_ABS_SPEED])
			elif key_str in CHANCE_KEYS:
				if v < -0.001 or v > CAP_CHANCE + 0.001:
					violations.append("%s.%s = %.2f 超概率类上限 %.2f" % [source, key_str, v, CAP_CHANCE])
			elif key_str in RATIO_KEYS:
				if absf(v) > CAP_RATIO + 0.001:
					violations.append("%s.%s = %.2f 超比例类上限 %.2f" % [source, key_str, v, CAP_RATIO])
			elif (key_str.begins_with("attack_") or key_str.begins_with("defense_") \
					or key_str.begins_with("move_speed") or key_str.begins_with("max_hp") \
					or key_str.begins_with("light_") or key_str.begins_with("armor_") \
					or key_str.begins_with("air_") or key_str.begins_with("ground_") \
					or key_str.ends_with("_mult") or key_str.ends_with("_bonus") \
					or key_str.ends_with("_penalty") or key_str.ends_with("_mult_pct")):
				# 批次8：属性键双语义分类（见 _uct_abs_cap 注释）
				var fam: String = ""
				if absf(v) > 1.0:
					if key_str.begins_with("attack_"):
						fam = "attack"
					elif key_str.begins_with("defense_"):
						fam = "defense"
					elif key_str.begins_with("max_hp"):
						fam = "hp"
				var cap: float = _uct_abs_cap(fam) if fam != "" else CAP_STAT
				if absf(v) > cap + 0.001:
					violations.append("%s.%s = %.2f 超%s %.2f" % [
						source, key_str, v,
						"固定值上限（UCT %s 包络）" % fam if fam != "" else "属性类上限", cap])


func test_mod_effect_caps() -> void:
	var violations: Array = []
	for path in MODULE_FILES:
		var mod_res: Resource = load(path)
		if mod_res == null or not (mod_res is GDScript):
			violations.append("模块文件加载失败：%s" % path)
			continue
		var data: Variant = (mod_res as GDScript).get("DATA")
		if data is Dictionary:
			_scan_effect_caps(data, path.get_file(), violations)
	_scan_effect_caps(ModEffects.MOD_DATA, "mod_effects.gd", violations)
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()


# ───────────────────────── E5：首关可负担性 ─────────────────────────

func test_first_level_affords_cheapest_mod() -> void:
	var violations: Array = []
	# era0 最便宜卡 = 最低战力
	var min_power: int = 1 << 30
	for e in UCT.get_player_card_entries():
		if int(e.get("era", -1)) == 0:
			min_power = mini(min_power, int(e.get("power", 10)))
	if min_power == 1 << 30:
		min_power = 18
	var cheapest_mod: float = 0.5 * maxf(60.0, float(min_power))
	var income_l1: float = _battle_income_nano(1)
	if income_l1 < cheapest_mod:
		violations.append("era0 首关收入 %.0f < 最便宜改造费 %.0f（开局节奏受阻）" % [income_l1, cheapest_mod])
	assert_array(violations).override_failure_message("\n" + "\n".join(violations)).is_empty()
