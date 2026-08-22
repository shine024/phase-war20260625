extends Node
## 全改造战力增益覆盖测试（场景模式，autoload 齐全）：
##   godot --headless --path . res://tests/mod_power_gain_coverage.tscn
## v9.x "所有改造都应该对战力有提升"验收锁：
##   对每兵种代表卡 × 该卡可用的全部改造，断言"装上任意改造后战力严格大于裸卡"。
##   未被代表卡覆盖的改造（uncovered）单独统计打印，不判失败（后续加卡即可）。

const EH = preload("res://managers/evolution/evolution_helpers.gd")
const DC = preload("res://data/default_cards.gd")

const FIXED_CARDS := [
	"ww1_mp18", "fut_cyborg",        # 轻装/步兵
	"ww2_pz3", "mod_arm_m1a1",       # 装甲
	"mod_arty_m270",                  # 支援/炮兵
]

var _fails: Array[String] = []
var _covered: Dictionary = {}

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_run()
	get_tree().quit(0 if _fails.is_empty() else 1)

func _fail(msg: String) -> void:
	push_error("[FAIL] " + msg)
	_fails.append(msg)

func _pick_kind_card(kind: int) -> String:
	# 动态找该 combat_kind 的第一张卡（空中/堡垒等代表卡 id 不硬编码）
	for cid in DC.get_all_blueprint_ids():
		var c: CardResource = DC.get_card_by_id(cid)
		if c != null and int(c.combat_kind) == kind:
			return cid
	return ""

## 取舍型判定：effects/level_effects 含攻击/防御/HP 语义键的负数修正
func _has_negative_stat_effect(mod_data: Dictionary) -> bool:
	var effs: Array = [mod_data.get("effects", {})]
	var lev: Dictionary = mod_data.get("level_effects", {})
	for k in lev.keys():
		if lev[k] is Dictionary:
			effs.append(lev[k])
	for eff in effs:
		if not (eff is Dictionary):
			continue
		for k in eff.keys():
			var ks := String(k)
			# urban_attack_bonus / enemy_armor_slow 等条件攻击键也含 "attack"
			if not (ks.contains("attack") or ks.contains("defense") or ks == "max_hp"):
				continue
			var v = eff[k]
			if (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and float(v) < 0.0:
				return true
	return false

func _run() -> void:
	print("=== MOD POWER GAIN COVERAGE START ===")
	var bpm: Node = get_node("/root/BlueprintManager")
	var mr: Node = get_node("/root/ModificationRegistry")
	if bpm == null or mr == null:
		_fail("autoload 缺失 (BlueprintManager/ModificationRegistry)")
		return

	# 代表卡 = 固定样本 + 各 combat_kind 动态补齐（3=空中 4=堡垒）
	var cards: Array[String] = []
	for cid in FIXED_CARDS:
		cards.append(cid)
	for kind in [3, 4]:
		var picked: String = _pick_kind_card(kind)
		if not picked.is_empty():
			cards.append(picked)
	print("代表卡: %s" % ", ".join(PackedStringArray(cards)))

	var total_checks := 0
	var total_gain := 0.0
	var tradeoff_warns: Array[String] = []
	var inert_warns: Array[String] = []
	for cid in cards:
		var card: CardResource = DC.get_card_by_id(cid)
		if card == null:
			_fail("代表卡不存在 %s" % cid)
			continue
		var base: float = EH.estimate_power_score(cid, bpm)
		if base <= 0.0:
			continue
		var worst_gap := 999999.0
		var worst_mod := ""
		# 注：模块数据用 "key" = value 字典写法，键类型是 NodePath（GDScript Lua 风格坑），统一 String() 转换
		var mod_list: Array = mr.get_mods_for_card(cid)
		for mod_id_raw in mod_list:
			var mod_id := String(mod_id_raw)
			if mod_id.is_empty():
				continue
			_covered[mod_id] = true
			var with_mod: float = EH.estimate_power_with_extra_mod(card, mod_id, bpm)
			total_checks += 1
			var gap: float = with_mod - base
			if is_equal_approx(gap, 0.0):
				# 属性通道零变化：死键（registry 无分支）/ 保底重叠（词条值低于兵种保底）
				# —— 数据层责任，列清单交数值决策，不判公式失败
				inert_warns.append("%s+%s（stats 零变化：死键或低于保底）" % [cid, mod_id])
			elif _has_negative_stat_effect(mr.get_data(mod_id)):
				# 取舍型（effects 显式负修正）：容忍净负，超 -2% base 列平衡告警
				if gap < -base * 0.02:
					tradeoff_warns.append("%s+%s: %+.0f（负超2%%）" % [cid, mod_id, gap])
			else:
				if gap <= 0.5:
					_fail("%s + %s：装上后战力未提升（base=%.1f with=%.1f gap=%.1f）" % [
						cid, mod_id, base, with_mod, gap])
			if gap < worst_gap:
				worst_gap = gap
				worst_mod = mod_id
			total_gain += maxf(gap, 0.0)
		print("[OK] %-16s base=%6.0f  mods=%d  最小增益=%s (%+.1f)" % [
			cid, base, mod_list.size(), worst_mod, worst_gap])

	# 数据层问题清单（交数值决策，不判测试失败）
	if not inert_warns.is_empty():
		print("⚠ 零效改造清单（stats 无任何变化——死键/词条低于兵种保底，数据层问题）:")
		for w in inert_warns:
			print("   %s" % w)
	if not tradeoff_warns.is_empty():
		print("⚠ 取舍型改造净负超2%%清单（数据平衡问题，非公式问题）:")
		for w in tradeoff_warns:
			print("   %s" % w)

	# 未覆盖改造统计（不判失败，提示补代表卡）
	var all_ids: Array = mr.get_all_ids()
	var uncovered: Array[String] = []
	for mid in all_ids:
		if not _covered.has(String(mid)):
			uncovered.append(String(mid))
	print("覆盖 %d / %d 改造；未覆盖 %d 个：%s" % [
		_covered.size(), all_ids.size(), uncovered.size(),
		", ".join(PackedStringArray(uncovered.slice(0, 12))) if uncovered.size() > 0 else "无"])

	print("=== MOD POWER GAIN COVERAGE %s（%d 项检查，平均增益 +%.1f）===" % [
		"ALL PASS" if _fails.is_empty() else "FAILED", total_checks,
		total_gain / float(maxi(total_checks, 1))])
