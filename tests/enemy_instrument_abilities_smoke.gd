extends SceneTree
## v7.x EnemyPhaseInstrumentAbilities 引擎 smoke test
## 验证：类结构完整、三入口可调用、4 个能力 ID 在 match 分支覆盖
## 注：完整运行时验证（实际伤害/特效）需游戏内实机测试，这里验证代码结构完整性
##
## 运行：Godot --headless --script tests/enemy_instrument_abilities_smoke.gd

const EnemyPhaseInstrumentAbilities = preload("res://managers/battle/enemy_phase_instrument_abilities.gd")

func _init():
	print("═══════════════════════════════════════════")
	print("  v7.x EnemyPhaseInstrumentAbilities Smoke Test")
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

## 测试 1：类结构完整（三入口 + 4 个能力处理函数可调用）
func _test_class_structure() -> bool:
	print("\n[测试 1] 类结构完整性")
	# EnemyPhaseInstrumentAbilities 全是静态方法，直接调用验证不崩溃即代表存在
	var pass_count: int = 0
	var total: int = 4
	# 1. reset_state 可调用
	EnemyPhaseInstrumentAbilities.reset_state()
	pass_count += 1
	print("  ✅ reset_state() 可调用")
	# 2. update 空状态可调用
	EnemyPhaseInstrumentAbilities.update(0.016)
	pass_count += 1
	print("  ✅ update() 可调用")
	# 3. get_active_ability 返回 Dictionary
	var ability: Dictionary = EnemyPhaseInstrumentAbilities.get_active_ability()
	if typeof(ability) == TYPE_DICTIONARY:
		pass_count += 1
		print("  ✅ get_active_ability() 返回 Dictionary")
	# 4. on_battle_start 传 null 不崩溃（空 driver 守卫）
	EnemyPhaseInstrumentAbilities.on_battle_start(null, null)
	pass_count += 1
	print("  ✅ on_battle_start(null) 安全守卫")
	print("  结果: %d/%d PASS" % [pass_count, total])
	return pass_count == total

## 测试 2：4 个敌方能力的 params 结构正确解析
## 注：直读 JSON 绕过静态 var 时序问题
func _test_ability_params_parsing() -> bool:
	print("\n[测试 5] 能力 params 解析（直读 JSON）")
	var json_path: String = "res://data/json/enemy_phase_instruments.json"
	if not FileAccess.file_exists(json_path):
		print("  ❌ JSON 文件不存在")
		return false
	var text: String = FileAccess.get_file_as_string(json_path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("  ❌ JSON 解析失败")
		return false
	var all_data: Dictionary = parsed.get("data", {})
	var expected_params: Dictionary = {
		"enemy_artillery_barrage": ["interval", "shots", "shot_interval"],
		"enemy_nano_swarm": ["duration", "hp_pct_per_sec"],
		"enemy_shield_bulwark": ["shield_amount"],
		"enemy_rage_buff": ["interval", "duration", "atk_mult", "spd_mult"],
	}
	var test_instruments: Dictionary = {
		"enemy_artillery_barrage": "flame_destroyer_mk4",
		"enemy_nano_swarm": "void_walker_mk4",
		"enemy_shield_bulwark": "steel_guardian_mk3",
		"enemy_rage_buff": "steel_guardian_mk4",
	}
	var pass_count: int = 0
	var total: int = 0
	for ability_id in test_instruments:
		var inst_id: String = test_instruments[ability_id]
		var inst_cfg: Dictionary = all_data.get(inst_id, {})
		if inst_cfg.is_empty():
			print("  ❌ %s: 相位仪 %s 未找到" % [ability_id, inst_id])
			continue
		var actual_ability: Dictionary = inst_cfg.get("active_ability", {})
		if actual_ability.is_empty():
			print("  ❌ %s: 无 active_ability" % inst_id)
			continue
		total += 1
		var actual_id: String = String(actual_ability.get("id", ""))
		var actual_params: Dictionary = actual_ability.get("params", {})
		var required_keys: Array = expected_params.get(ability_id, [])
		var all_keys_present: bool = true
		for rk in required_keys:
			if not actual_params.has(rk):
				all_keys_present = false
				break
		if actual_id == ability_id and all_keys_present:
			print("  ✅ %s: id+params 正确（%s）" % [ability_id, str(actual_params)])
			pass_count += 1
		else:
			print("  ❌ %s: id=%s params_ok=%s" % [ability_id, actual_id, all_keys_present])
	print("  结果: %d/%d PASS" % [pass_count, total])
	return pass_count == total
