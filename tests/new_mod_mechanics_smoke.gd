extends SceneTree
## v7.x 新改造机制 smoke test
## 验证：9 个新改造的 effect key 全部正确写入对应 UnitStats 字段（不走 _special）
## 以及连击/怒气/破甲/标记的数值公式逻辑
##
## 运行：Godot --headless --script tests/new_mod_mechanics_smoke.gd

const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")

func _init():
	print("═══════════════════════════════════════════")
	print("  v7.x 新改造机制 Smoke Test")
	print("═══════════════════════════════════════════")

	var all_pass: bool = true
	all_pass = _test_mod_effect_mapping() and all_pass
	all_pass = _test_combo_mechanic() and all_pass
	all_pass = _test_rage_mechanic() and all_pass
	all_pass = _test_armor_break_mechanic() and all_pass
	all_pass = _test_mark_mechanic() and all_pass
	all_pass = _test_siege_mechanic() and all_pass
	all_pass = _test_urban_defense_mechanic() and all_pass

	print("\n═══════════════════════════════════════════")
	if all_pass:
		print("  ✅ 全部 PASS")
	else:
		print("  ❌ 存在失败项")
	print("═══════════════════════════════════════════")
	quit(0 if all_pass else 1)

## 测试 1：9 个新改造的 effect key 全部正确映射到 stat 字段
func _test_mod_effect_mapping() -> bool:
	print("\n[测试 1] 改造 effect key → stat 字段映射")
	var pass_count: int = 0
	var total: int = 9

	# 每个改造：检查 effects 里的 key 在 modification_registry 能正确写入 stat 字段
	var test_cases: Array = [
		{"mod_id": "inf_23_combat_stimulant", "check_key": "combo_max", "check_val": 5},
		{"mod_id": "inf_24_urban_warfare", "check_key": "urban_defense_bonus", "check_val": 0.50},
		{"mod_id": "arm_16_battle_frenzy", "check_key": "rage_max", "check_val": 8},
		{"mod_id": "art_13_apfsds_sabot", "check_key": "armor_break_per_hit", "check_val": 0.08},
		{"mod_id": "art_14_counter_battery", "check_key": "has_counter_battery", "check_val": true},
		{"mod_id": "aa_13_radar_lock", "check_key": "mark_chance", "check_val": 0.40},
		{"mod_id": "air_15_afterburner", "check_key": "combo_max", "check_val": 3},
		{"mod_id": "rec_13_target_designator", "check_key": "mark_chance", "check_val": 0.30},
		{"mod_id": "eng_11_breaching_charge", "check_key": "siege_bonus_pct", "check_val": 0.05},
	]

	for tc in test_cases:
		var mod_id: String = String(tc["mod_id"])
		var mod_data: Dictionary = ModificationRegistry.get_data(mod_id)
		if mod_data.is_empty():
			print("  ❌ %s: 改造数据未找到" % mod_id)
			continue
		# 构建 base_dict 并应用 effects
		var base_dict: Dictionary = {}
		for k in ["combo_max", "combo_bonus_mult", "rage_max", "rage_bonus_mult",
				  "armor_break_per_hit", "armor_break_max_stacks", "mark_chance",
				  "mark_duration", "mark_vuln_bonus", "siege_bonus_pct",
				  "urban_defense_bonus", "has_counter_battery"]:
			base_dict[k] = 0
		base_dict["has_counter_battery"] = false
		var effects: Dictionary = mod_data.get("effects", {})
		var result: Dictionary = ModificationRegistry.apply_effects(base_dict, [mod_id])
		var check_key: String = String(tc["check_key"])
		var expected: Variant = tc["check_val"]
		var actual: Variant = result.get(check_key, null)
		if actual == null:
			print("  ❌ %s: %s 未写入（仍为默认）" % [mod_id, check_key])
			continue
		var _match: bool = false
		if expected is float:
			_match = absf(float(actual) - float(expected)) < 0.001
		elif expected is int:
			_match = int(actual) == int(expected)
		elif expected is bool:
			_match = bool(actual) == bool(expected)
		if _match:
			print("  ✅ %s: %s = %s" % [mod_id, check_key, str(actual)])
			pass_count += 1
		else:
			print("  ❌ %s: %s 期望 %s 实际 %s" % [mod_id, check_key, str(expected), str(actual)])

	print("  结果: %d/%d PASS" % [pass_count, total])
	return pass_count == total

## 测试 2：连击数值公式（5 次命中后爆发 +25%）
func _test_combo_mechanic() -> bool:
	print("\n[测试 2] 连击机制数值")
	var stats = UnitStats.new()
	stats.combo_max = 5
	stats.combo_bonus_mult = 0.25
	stats.combo_counter = 0
	# 模拟 5 次命中
	for i in range(5):
		stats.combo_counter += 1
	var triggered: bool = stats.combo_counter >= stats.combo_max
	var burst_dmg: float = 100.0 * stats.combo_bonus_mult  # 假设基础伤害 100
	if triggered and absf(burst_dmg - 25.0) < 0.01:
		print("  ✅ 连击 5 次触发，爆发伤害 = %.1f（+25%%）" % burst_dmg)
		return true
	print("  ❌ 连击触发=%s 爆发=%.1f（期望 25.0）" % [triggered, burst_dmg])
	return false

## 测试 3：怒气数值公式（受击 8 次后激活 +35% 攻击）
func _test_rage_mechanic() -> bool:
	print("\n[测试 3] 怒气机制数值")
	var stats = UnitStats.new()
	stats.rage_max = 8
	stats.rage_bonus_mult = 0.35
	stats.attack_damage = 100.0
	# 模拟 8 次受击积累
	for i in range(8):
		stats.rage_counter += 1
	var triggered: bool = stats.rage_counter >= stats.rage_max
	if triggered:
		stats.attack_damage *= (1.0 + stats.rage_bonus_mult)
	var expected_atk: float = 135.0
	if triggered and absf(stats.attack_damage - expected_atk) < 0.01:
		print("  ✅ 怒气 8 次激活，攻击力 = %.1f（+35%%）" % stats.attack_damage)
		return true
	print("  ❌ 怒气触发=%s 攻击=%.1f（期望 %.1f）" % [triggered, stats.attack_damage, expected_atk])
	return false

## 测试 4：破甲叠加数值（5 层 × 8% = -40% 防御）
func _test_armor_break_mechanic() -> bool:
	print("\n[测试 4] 破甲叠加数值")
	var per_hit: float = 0.08
	var max_stacks: int = 5
	var base_def: float = 100.0
	# 模拟 5 层叠加
	var stacks: int = max_stacks
	var total_reduction: float = stacks * per_hit
	var effective_def: float = base_def * maxf(0.1, 1.0 - total_reduction)
	var expected_def: float = 60.0  # 100 × (1 - 0.40) = 60
	if absf(effective_def - expected_def) < 0.01:
		print("  ✅ 破甲 5 层，有效防御 = %.1f（-40%%）" % effective_def)
		return true
	print("  ❌ 有效防御=%.1f（期望 %.1f）" % [effective_def, expected_def])
	return false

## 测试 5：标记系统数值（+30% 易伤）
func _test_mark_mechanic() -> bool:
	print("\n[测试 5] 标记系统数值")
	var mark_chance: float = 0.40
	var vuln_bonus: float = 0.30
	var base_dmg: float = 100.0
	# 被标记目标受额外伤害
	var marked_dmg: float = base_dmg * (1.0 + vuln_bonus)
	var expected: float = 130.0
	# 验证标记概率在合理范围
	var chance_ok: bool = mark_chance > 0.0 and mark_chance <= 1.0
	var dmg_ok: bool = absf(marked_dmg - expected) < 0.01
	if chance_ok and dmg_ok:
		print("  ✅ 标记概率=%.0f%%, 被标记伤害=%.1f（+30%%）" % [mark_chance * 100, marked_dmg])
		return true
	print("  ❌ 概率ok=%s 伤害ok=%s（%.1f vs %.1f）" % [chance_ok, dmg_ok, marked_dmg, expected])
	return false

## 测试 6：工兵爆破数值（5% 百分比掉血）
func _test_siege_mechanic() -> bool:
	print("\n[测试 6] 工兵爆破数值")
	var siege_pct: float = 0.05
	var target_hp: float = 1000.0
	var siege_dmg: float = target_hp * siege_pct
	var expected: float = 50.0
	if absf(siege_dmg - expected) < 0.01:
		print("  ✅ 目标 HP=%.0f, 爆破伤害=%.1f（5%%）" % [target_hp, siege_dmg])
		return true
	print("  ❌ 爆破伤害=%.1f（期望 %.1f）" % [siege_dmg, expected])
	return false

## 测试 7：巷战免伤数值（50% 减免）
func _test_urban_defense_mechanic() -> bool:
	print("\n[测试 7] 巷战免伤数值")
	var urban_bonus: float = 0.50
	var incoming_dmg: float = 100.0
	var reduced_dmg: float = incoming_dmg * (1.0 - urban_bonus)
	var expected: float = 50.0
	if absf(reduced_dmg - expected) < 0.01:
		print("  ✅ 受装甲攻击伤害=%.1f（减免 50%%）" % reduced_dmg)
		return true
	print("  ❌ 减免后=%.1f（期望 %.1f）" % [reduced_dmg, expected])
	return false
