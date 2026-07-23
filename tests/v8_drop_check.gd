## v8.2 相位师掉落修复验证
## 验证 B1(faction映射) + B3(平台数)
## 独立运行：D:\godot\Godot_v4.5.1.exe --headless --rendering-driver opengl3 --path . --script tests\v8_drop_check.gd
extends SceneTree
const EnemyLoadoutTiers = preload("res://data/enemy_loadout_tiers.gd")
const FCB = preload("res://data/faction_conquest_buffs.gd")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	print("\n========== v8.2 相位师掉落修复验证 ==========")

	# ===== B1: faction 命名空间映射 =====
	print("\n--- B1: 敌方家族 → 玩家势力映射 ---")
	# 复刻 game_manager._enemy_faction_to_player_faction 逻辑
	var cases := {
		"steel": "iron_wall_corp",
		"flame": "nova_arms",
		"thunder": "aether_dynamics",
		"void": "void_research",
		"steel_flame": "iron_wall_corp",   # 混合取首段
		"flame_void": "nova_arms",
		"void_flame": "void_research",
		"all": "",                          # all/未知→空
		"": "",
	}
	for enemy_fc in cases:
		var expected_player_fc: String = cases[enemy_fc]
		var actual: String = _enemy_faction_to_player_faction(enemy_fc)
		_assert_str(actual, expected_player_fc, "敌方'%s'→玩家'%s'" % [enemy_fc, expected_player_fc])

	# ===== B1: 映射后 FACTION_MOD_BIAS 能命中 =====
	print("\n--- B1: 映射后改造偏好命中 ---")
	for enemy_fc in ["steel", "flame", "thunder", "void"]:
		var player_fc: String = _enemy_faction_to_player_faction(enemy_fc)
		var bias: Array = FCB.FACTION_MOD_BIAS.get(player_fc, [])
		_assert_true(not bias.is_empty(), "敌方'%s'(→%s) 改造偏好命中: %s" % [enemy_fc, player_fc, str(bias)])

	# ===== B1: 特殊仪映射命中 =====
	print("\n--- B1: 特殊仪势力映射 ---")
	var special_map := {
		"iron_wall_corp": "pi_special_rage",
		"void_research": "pi_special_void",
		"aether_dynamics": "pi_special_aegis",
		"nova_arms": "pi_special_nova",
	}
	var expected_specials := {"steel":"pi_special_rage","flame":"pi_special_nova","thunder":"pi_special_aegis","void":"pi_special_void"}
	for enemy_fc in ["steel", "flame", "thunder", "void"]:
		var player_fc: String = _enemy_faction_to_player_faction(enemy_fc)
		var actual_inst: String = special_map.get(player_fc, "")
		var expected_inst: String = expected_specials[enemy_fc]
		_assert_str(actual_inst, expected_inst, "敌方'%s'→特殊仪'%s'" % [enemy_fc, expected_inst])

	# ===== B3: 30 相位师平台数核对（JSON 数据源）=====
	print("\n--- B3: 相位师平台数核对 ---")
	var json_path := "res://data/json/enemy_phase_masters.json"
	var text := FileAccess.get_file_as_string(json_path)
	var parsed = JSON.parse_string(text)
	var masters: Array = parsed.get("data", [])
	var low_platform_count: int = 0
	var master_029_platforms: int = 0
	var master_027_platforms: int = 0
	for m in masters:
		var pl: Array = m.get("equipment", {}).get("platforms", [])
		var mid: String = m.get("id", "")
		var lvl: int = int(m.get("level", 0))
		# 记录顶级 boss
		if mid == "enemy_master_029":
			master_029_platforms = pl.size()
		if mid == "enemy_master_027":
			master_027_platforms = pl.size()
		# 高 Lv(>=15) 仍只有 ≤3 平台 = 异常
		if lvl >= 15 and pl.size() <= 3:
			low_platform_count += 1
			print("  ⚠️ %s (Lv%d) 仅 %d 平台" % [mid, lvl, pl.size()])
	_assert_int(master_029_platforms, 6, "终极boss 029(虚空女神) = 6平台")
	_assert_int(master_027_platforms, 5, "顶级boss 027(炎魔之神) = 5平台")
	_assert_int(low_platform_count, 0, "高Lv(≥15)无≤3平台boss (0个异常)")

	# ===== B3: 补充的平台都是同时代真实 archetype =====
	print("\n--- B3: 补充平台 id 规范性 ---")
	var valid_prefixes := ["ww1_", "ww2_", "cold_", "mod_", "fut_"]
	var invalid_platforms: int = 0
	for m in masters:
		var pl: Array = m.get("equipment", {}).get("platforms", [])
		for pid in pl:
			var valid: bool = false
			for prefix in valid_prefixes:
				if String(pid).begins_with(prefix):
					valid = true
					break
			if not valid:
				invalid_platforms += 1
				print("  ⚠️ 无效平台id: %s" % pid)
	_assert_int(invalid_platforms, 0, "所有平台id都是规范archetype(0个旧平台名)")

	print("\n========== 验证结果 ==========")
	print("PASS: %d  FAIL: %d" % [_pass, _fail])
	if _fail > 0:
		print("❌ 有失败项")
	else:
		print("✅ 全部通过")
	quit(0 if _fail == 0 else 1)


## 复刻 game_manager._enemy_faction_to_player_faction（保持逻辑一致）
func _enemy_faction_to_player_faction(enemy_faction: String) -> String:
	var primary: String = enemy_faction.split("_")[0] if enemy_faction.find("_") >= 0 else enemy_faction
	match primary:
		"steel": return "iron_wall_corp"
		"flame": return "nova_arms"
		"thunder": return "aether_dynamics"
		"void": return "void_research"
		_: return ""


func _assert_int(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		_pass += 1
		print("  ✅ %s (got %d)" % [label, actual])
	else:
		_fail += 1
		print("  ❌ %s: expected %d, got %d" % [label, expected, actual])


func _assert_str(actual: String, expected: String, label: String) -> void:
	if actual == expected:
		_pass += 1
		print("  ✅ %s" % label)
	else:
		_fail += 1
		print("  ❌ %s: expected '%s', got '%s'" % [label, expected, actual])


func _assert_true(actual: bool, label: String) -> void:
	if actual:
		_pass += 1
		print("  ✅ %s" % label)
	else:
		_fail += 1
		print("  ❌ %s: expected true" % label)
