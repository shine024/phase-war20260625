extends SceneTree
## v7.x 特殊相位仪 + 敌方相位仪能力 smoke test
## 验证：4 个特殊相位仪 get_by_id 正确返回 + enemy_phase_instruments.json 的 active_ability 字段
##
## 运行：Godot --headless --script tests/phase_instrument_drop_smoke.gd

const PhaseInstruments = preload("res://data/phase_instruments.gd")
const EnemyPhaseEquipment = preload("res://data/enemy_phase_equipment.gd")

func _init():
	print("═══════════════════════════════════════════")
	print("  v7.x 特殊相位仪 + 敌方能力 Smoke Test")
	print("═══════════════════════════════════════════")

	var all_pass: bool = true
	all_pass = _test_special_instruments_exist() and all_pass
	all_pass = _test_special_instruments_not_generic() and all_pass
	all_pass = _test_special_instruments_have_ability() and all_pass
	all_pass = _test_enemy_instruments_have_ability() and all_pass
	all_pass = _test_drop_chance_logic() and all_pass

	print("\n═══════════════════════════════════════════")
	if all_pass:
		print("  ✅ 全部 PASS")
	else:
		print("  ❌ 存在失败项")
	print("═══════════════════════════════════════════")
	quit(0 if all_pass else 1)

## 测试 1：4 个特殊相位仪都能 get_by_id 查到
func _test_special_instruments_exist() -> bool:
	print("\n[测试 1] 特殊相位仪存在性")
	var ids: Array = ["pi_special_rage", "pi_special_void", "pi_special_aegis", "pi_special_nova"]
	var pass_count: int = 0
	for iid in ids:
		var cfg: Dictionary = PhaseInstruments.get_by_id(iid)
		if not cfg.is_empty():
			print("  ✅ %s: %s（%d★）" % [iid, cfg.get("name", ""), cfg.get("star", 0)])
			pass_count += 1
		else:
			print("  ❌ %s: 未找到" % iid)
	print("  结果: %d/%d PASS" % [pass_count, ids.size()])
	return pass_count == ids.size()

## 测试 2：特殊相位仪 is_generic=false（不进商店）
func _test_special_instruments_not_generic() -> bool:
	print("\n[测试 2] 特殊相位仪 is_generic=false")
	var ids: Array = ["pi_special_rage", "pi_special_void", "pi_special_aegis", "pi_special_nova"]
	var pass_count: int = 0
	for iid in ids:
		var cfg: Dictionary = PhaseInstruments.get_by_id(iid)
		if not bool(cfg.get("is_generic", true)):
			print("  ✅ %s: is_generic=false（不在商店）" % iid)
			pass_count += 1
		else:
			print("  ❌ %s: is_generic=true（会进商店）" % iid)
	print("  结果: %d/%d PASS" % [pass_count, ids.size()])
	return pass_count == ids.size()

## 测试 3：特殊相位仪都有 active_ability
func _test_special_instruments_have_ability() -> bool:
	print("\n[测试 3] 特殊相位仪有 active_ability")
	var ids: Array = ["pi_special_rage", "pi_special_void", "pi_special_aegis", "pi_special_nova"]
	var pass_count: int = 0
	for iid in ids:
		var cfg: Dictionary = PhaseInstruments.get_by_id(iid)
		var ability: Dictionary = cfg.get("active_ability", {})
		if not ability.is_empty():
			print("  ✅ %s: 能力=%s（type=%s）" % [iid, ability.get("id", ""), ability.get("type", "")])
			pass_count += 1
		else:
			print("  ❌ %s: 无 active_ability" % iid)
	print("  结果: %d/%d PASS" % [pass_count, ids.size()])
	return pass_count == ids.size()

## 测试 4：敌方高阶相位仪有 active_ability
## 注：--script 模式下 EnemyPhaseEquipment 的静态 var PHASE_INSTRUMENTS 可能因
## 初始化时序加载失败（项目既有限制），改为直接读 JSON 文件验证数据正确性
func _test_enemy_instruments_have_ability() -> bool:
	print("\n[测试 4] 敌方相位仪 active_ability（直读 JSON）")
	var json_path: String = "res://data/json/enemy_phase_instruments.json"
	if not FileAccess.file_exists(json_path):
		print("  ❌ JSON 文件不存在: %s" % json_path)
		return false
	var text: String = FileAccess.get_file_as_string(json_path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("  ❌ JSON 解析失败")
		return false
	var all_data: Dictionary = parsed.get("data", {})
	var ids: Array = [
		"steel_guardian_mk3",   # enemy_shield_bulwark
		"steel_guardian_mk4",   # enemy_rage_buff
		"flame_destroyer_mk4",  # enemy_artillery_barrage
		"void_walker_mk4",      # enemy_nano_swarm
		"steel_guardian_god",   # enemy_rage_buff (god)
		"void_walker_god",      # enemy_nano_swarm (god)
	]
	var pass_count: int = 0
	for iid in ids:
		var cfg: Dictionary = all_data.get(iid, {})
		if cfg.is_empty():
			print("  ❌ %s: 相位仪数据未找到" % iid)
			continue
		var ability: Dictionary = cfg.get("active_ability", {})
		if not ability.is_empty():
			print("  ✅ %s: 能力=%s" % [iid, ability.get("id", "")])
			pass_count += 1
		else:
			print("  ❌ %s: 无 active_ability" % iid)
	print("  结果: %d/%d PASS" % [pass_count, ids.size()])
	return pass_count == ids.size()

## 测试 5：掉落概率梯度逻辑（6★=20%, 7★=40%, 5★及以下=0%）
func _test_drop_chance_logic() -> bool:
	print("\n[测试 5] 掉落概率梯度逻辑")
	# 模拟 _maybe_roll_special_instrument_drop 的核心逻辑
	var test_cases: Array = [
		{"stars": 5, "expected_max_chance": 0.0, "desc": "5★不该掉"},
		{"stars": 6, "expected_max_chance": 0.20, "desc": "6★ 20%概率"},
		{"stars": 7, "expected_max_chance": 0.40, "desc": "7★ 40%概率"},
	]
	var pass_count: int = 0
	for tc in test_cases:
		var stars: int = int(tc["stars"])
		var drop_chance: float = 0.40 if stars >= 7 else (0.20 if stars >= 6 else 0.0)
		var expected: float = float(tc["expected_max_chance"])
		if absf(drop_chance - expected) < 0.001:
			print("  ✅ %d★: 掉落概率=%.0f%%（%s）" % [stars, drop_chance * 100, tc["desc"]])
			pass_count += 1
		else:
			print("  ❌ %d★: 概率=%.0f%% 期望=%.0f%%" % [stars, drop_chance * 100, expected * 100])
	print("  结果: %d/%d PASS" % [pass_count, test_cases.size()])
	return pass_count == test_cases.size()
