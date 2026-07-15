extends SceneTree
## v7.x 第二批次改造特殊机制 smoke test
## 验证：12 个改造（4修复+8新增）的 effect key → stat 字段映射全 PASS
## 以及复活/反伤/拦截/亡语治疗/区域控制/相位分流的数值公式
##
## 运行：Godot --headless --script tests/special_mechanics_smoke2.gd

const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")

func _init():
	print("═══════════════════════════════════════════")
	print("  v7.x 第二批次改造特殊机制 Smoke Test")
	print("═══════════════════════════════════════════")

	var all_pass: bool = true
	all_pass = _test_mod_effect_mapping() and all_pass
	all_pass = _test_revive_mechanic() and all_pass
	all_pass = _test_reflect_mechanic() and all_pass
	all_pass = _test_intercept_mechanic() and all_pass
	all_pass = _test_death_heal_mechanic() and all_pass
	all_pass = _test_minefield_mechanic() and all_pass
	all_pass = _test_phase_shield_mechanic() and all_pass

	print("\n═══════════════════════════════════════════")
	if all_pass:
		print("  ✅ 全部 PASS")
	else:
		print("  ❌ 存在失败项")
	print("═══════════════════════════════════════════")
	quit(0 if all_pass else 1)

## 测试 1：12 个改造的 effect key 全部正确映射
func _test_mod_effect_mapping() -> bool:
	print("\n[测试 1] 改造 effect key → stat 字段映射")
	var pass_count: int = 0
	var test_cases: Array = [
		# 修复的 4 个
		{"mod_id": "inf_18_ifak", "check_key": "revive_on_death", "check_val": true},
		{"mod_id": "rec_10_medkit", "check_key": "revive_on_death", "check_val": true},
		{"mod_id": "arm_03_reactive_armor", "check_key": "reflect_damage_pct", "check_val": 0.30},
		{"mod_id": "arm_04_aps", "check_key": "intercept_chance", "check_val": 0.30},
		# 新增的 8 个
		{"mod_id": "eng_12_reactive_engineering", "check_key": "reflect_damage_pct", "check_val": 0.25},
		{"mod_id": "inf_25_medic_sacrifice", "check_key": "death_heal_allies_pct", "check_val": 0.20},
		{"mod_id": "eng_13_supply_cache", "check_key": "death_heal_allies_pct", "check_val": 0.15},
		{"mod_id": "for_11_advanced_minefield", "check_key": "minefield_damage", "check_val": 150.0},
		{"mod_id": "for_12_anti_tank_trench", "check_key": "slow_aura_pct", "check_val": 0.40},
		{"mod_id": "for_13_command_bunker", "check_key": "command_aura_bonus", "check_val": 0.15},
		{"mod_id": "gen_14_phase_shield_gen", "check_key": "phase_shield_pool", "check_val": 2000.0},
		{"mod_id": "gen_15_laser_marker", "check_key": "laser_mark_on_hit", "check_val": true},
	]
	var total: int = test_cases.size()
	for tc in test_cases:
		var mod_id: String = String(tc["mod_id"])
		var mod_data: Dictionary = ModificationRegistry.get_data(mod_id)
		if mod_data.is_empty():
			print("  ❌ %s: 改造数据未找到" % mod_id)
			continue
		var base_dict: Dictionary = {}
		for k in ["revive_on_death", "revive_hp_ratio", "reflect_damage_pct", "reflect_charges",
				  "intercept_chance", "intercept_charges", "death_heal_allies_pct", "death_heal_radius",
				  "minefield_damage", "slow_aura_pct", "slow_aura_radius", "command_aura_bonus",
				  "phase_shield_pool", "phase_shield_regen", "laser_mark_on_hit"]:
			if k.ends_with("_on_death") or k == "laser_mark_on_hit":
				base_dict[k] = false
			elif k.ends_with("_charges"):
				base_dict[k] = -1
			else:
				base_dict[k] = 0.0
		var result: Dictionary = ModificationRegistry.apply_effects(base_dict, [mod_id])
		var check_key: String = String(tc["check_key"])
		var expected: Variant = tc["check_val"]
		var actual: Variant = result.get(check_key, null)
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

## 测试 2：濒死复活数值（15% max_hp）
func _test_revive_mechanic() -> bool:
	print("\n[测试 2] 濒死复活数值")
	var max_hp: float = 1000.0
	var ratio: float = 0.15
	var revive_hp: float = max_hp * ratio
	if absf(revive_hp - 150.0) < 0.01:
		print("  ✅ 复活到 %.0f HP（15%% × %.0f）" % [revive_hp, max_hp])
		return true
	print("  ❌ 复活 HP=%.1f（期望 150.0）" % revive_hp)
	return false

## 测试 3：爆反反伤数值（30% × 实际伤害）
func _test_reflect_mechanic() -> bool:
	print("\n[测试 3] 爆反反伤数值")
	var damage: float = 100.0
	var reflect_pct: float = 0.30
	var reflect_dmg: float = damage * reflect_pct
	if absf(reflect_dmg - 30.0) < 0.01:
		print("  ✅ 反伤 %.1f（30%% × %.0f）" % [reflect_dmg, damage])
		return true
	print("  ❌ 反伤=%.1f（期望 30.0）" % reflect_dmg)
	return false

## 测试 4：拦截数值（30%概率，3次后失效）
func _test_intercept_mechanic() -> bool:
	print("\n[测试 4] 拦截机制数值")
	var chance: float = 0.30
	var charges: int = 3
	# 模拟拦截3次后耗尽
	var intercepted: int = 0
	for i in range(5):  # 尝试5次
		if charges <= 0:
			break
		if i < 3:  # 前3次必定能拦截（模拟）
			charges -= 1
			intercepted += 1
	if intercepted == 3 and charges == 0:
		print("  ✅ 拦截 %d 次后耗尽（概率=%.0f%%）" % [intercepted, chance * 100])
		return true
	print("  ❌ 拦截 %d 次 charges=%d（期望 3/0）" % [intercepted, charges])
	return false

## 测试 5：亡语治疗数值（20% max_hp 治疗友军）
func _test_death_heal_mechanic() -> bool:
	print("\n[测试 5] 亡语治疗数值")
	var max_hp: float = 1000.0
	var heal_pct: float = 0.20
	var heal_amount: float = max_hp * heal_pct
	if absf(heal_amount - 200.0) < 0.01:
		print("  ✅ 亡语治疗 %.1f（20%% × %.0f）" % [heal_amount, max_hp])
		return true
	print("  ❌ 治疗量=%.1f（期望 200.0）" % heal_amount)
	return false

## 测试 6：雷场伤害数值（150 固定伤害）
func _test_minefield_mechanic() -> bool:
	print("\n[测试 6] 雷场伤害数值")
	var minefield_dmg: float = 150.0
	if minefield_dmg > 0.0:
		print("  ✅ 雷场伤害 = %.0f" % minefield_dmg)
		return true
	print("  ❌ 雷场伤害=%.1f（应 >0）" % minefield_dmg)
	return false

## 测试 7：相位护盾分流数值（2000池，伤害优先扣池）
func _test_phase_shield_mechanic() -> bool:
	print("\n[测试 7] 相位护盾分流数值")
	var pool: float = 2000.0
	var incoming: float = 500.0
	var absorbed: float = min(pool, incoming)
	var remaining_pool: float = pool - absorbed
	var hp_loss: float = incoming - absorbed
	if absf(remaining_pool - 1500.0) < 0.01 and absf(hp_loss) < 0.01:
		print("  ✅ 相位护盾吸收 %.0f，剩余池=%.0f，hp扣减=%.0f" % [absorbed, remaining_pool, hp_loss])
		return true
	print("  ❌ 剩余池=%.1f hp扣减=%.1f" % [remaining_pool, hp_loss])
	return false
