extends SceneTree
## v7.x 统一相位仪能力引擎 smoke test（owner-aware 单引擎）
## 验证：PhaseInstrumentAbilities 类结构 + ENEMY owner 入口 + 统一池 ability params
## 注：完整运行时验证（实际伤害/特效）需游戏内实机测试
##
## 运行：Godot --headless --script tests/enemy_instrument_abilities_smoke.gd

const PhaseInstrumentAbilities = preload("res://managers/battle/phase_instrument_abilities.gd")
const PhaseInstruments = preload("res://data/phase_instruments.gd")

func _init():
	print("═══════════════════════════════════════════")
	print("  v7.x PhaseInstrumentAbilities Smoke (owner-aware)")
	print("═══════════════════════════════════════════")

	var all_pass: bool = true
	all_pass = _test_class_structure() and all_pass
	all_pass = _test_ability_params_parsing() and all_pass

	print("\n═══════════════════════════════════════════")
	if all_pass:
		print("  ✅ 全部 PASS")
	else:
		print("  ❌ 存在失败项")
	print("═══════════════════════════════════════════")
	quit(0 if all_pass else 1)

## 测试 1：单引擎结构 + ENEMY owner 入口可调用
func _test_class_structure() -> bool:
	print("\n[测试 1] 单引擎结构完整性（ENEMY owner）")
	var pass_count: int = 0
	var total: int = 4
	PhaseInstrumentAbilities.reset_battle_state()
	pass_count += 1
	print("  ✅ reset_state() 可调用")
	PhaseInstrumentAbilities.update(0.016)
	pass_count += 1
	print("  ✅ update() 可调用")
	var ability: Dictionary = PhaseInstrumentAbilities.get_active_ability(PhaseInstrumentAbilities.Owner.ENEMY)
	if typeof(ability) == TYPE_DICTIONARY:
		pass_count += 1
		print("  ✅ get_active_ability(ENEMY) 返回 Dictionary")
	PhaseInstrumentAbilities.on_battle_start(null, null, PhaseInstrumentAbilities.Owner.ENEMY)
	pass_count += 1
	print("  ✅ on_battle_start(null,null,ENEMY) 安全守卫")
	print("  结果: %d/%d PASS" % [pass_count, total])
	return pass_count == total

## 测试 2：统一池敌方款 ability params 结构正确（裸 id，无 enemy_ 前缀）
func _test_ability_params_parsing() -> bool:
	print("\n[测试 2] 统一池敌方款 ability params（裸 id）")
	# 6 款带 ability 的敌方相位仪取 4 款验证（统一池 pi_ id）
	var cases: Dictionary = {
		"pi_steel_03": {"ability_id": "mega_shield", "params": ["shield_amount"]},
		"pi_steel_04": {"ability_id": "rage_buff", "params": ["interval", "duration", "atk_mult", "spd_mult"]},
		"pi_flame_04": {"ability_id": "artillery_barrage", "params": ["interval", "shots", "shot_interval"]},
		"pi_void_04": {"ability_id": "nano_swarm", "params": ["duration", "hp_pct_per_sec"]},
	}
	var pass_count: int = 0
	var total: int = cases.size()
	for inst_id in cases:
		var inst: Dictionary = PhaseInstruments.get_by_id(inst_id)
		if inst.is_empty():
			print("  ❌ %s: 未找到" % inst_id)
			continue
		var ab: Dictionary = inst.get("active_ability", {})
		if ab.is_empty():
			print("  ❌ %s: 无 active_ability" % inst_id)
			continue
		var exp: Dictionary = cases[inst_id]
		var actual_id: String = String(ab.get("id", ""))
		var actual_params: Dictionary = ab.get("params", {})
		var required: Array = exp["params"]
		var all_keys: bool = true
		for rk in required:
			if not actual_params.has(rk):
				all_keys = false
				break
		if actual_id == String(exp["ability_id"]) and all_keys:
			print("  ✅ %s: id=%s params 正确" % [inst_id, actual_id])
			pass_count += 1
		else:
			print("  ❌ %s: id=%s params_ok=%s" % [inst_id, actual_id, all_keys])
	print("  结果: %d/%d PASS" % [pass_count, total])
	return pass_count == total
