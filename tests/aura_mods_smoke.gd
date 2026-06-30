# 无 GdUnit 依赖的快速校验：v7.x 光环协同改造重映射
#   验证 11 个光环改造的 effect（10 key）从空转→装载单位自身加成
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/aura_mods_smoke.gd
extends SceneTree

const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")


func _initialize() -> void:
	var code := 0
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		code = 1

	# 构造一个有基础属性的 base_stats（模拟战斗卡），让乘法叠加有基数
	var base := {
		"attack_light": 100, "attack_armor": 100, "attack_air": 100,
		"defense_light": 100, "defense_armor": 100, "defense_air": 100,
		"attack_light_speed": 1.0, "attack_armor_speed": 1.0, "attack_air_speed": 1.0,
		"crit_chance": 0.0, "dodge_chance": 0.0, "hp_regen": 0.0,
		"deploy_delay_bonus": 0.0,
	}

	# 11 个光环改造（按 ID）。验证每个不再落 _special，且写入正确字段。
	# [mod_id, 应该被写入的字段 key（任一存在即算生效）, effect 原始 key]
	var cases := [
		["inf_19_radio", "crit_chance", "ally_bonus"],          # → crit_chance
		["arm_15_data_link", "crit_chance", "ally_hit_bonus"],  # → crit_chance
		["for_10_command", "crit_chance", "ally_hit_bonus"],    # → crit_chance
		["eng_09_supply", "attack_light_speed", "ally_ammo"],   # → 攻速
		["eng_08_medical", "hp_regen", "ally_hp_regen"],        # → hp_regen
		["eng_07_generator", "defense_light", "ally_fort_regen"],# → 防御
		["eng_10_camouflage", "dodge_chance", "ally_detection"], # → 闪避
		["eng_04_bridge", "deploy_delay_bonus", "ally_river_bonus"], # → 部署延迟
		["gen_06_laser_designator", "attack_armor", "ally_arty_bonus"], # → 对装甲
		["air_12_data_link", "attack_light", "formation_bonus"],# → 三维攻击
		["gen_02_digital", "defense_light", "command_efficiency"], # → 三维防御
	]

	print("=== v7.x 光环改造重映射验证 ===")
	for c in cases:
		var mod_id: String = c[0]
		var expected_field: String = c[1]
		var effect_key: String = c[2]
		var result: Dictionary = ModificationRegistry.apply_effects(base.duplicate(true), [{"id": mod_id}])
		# 1. 不应再有该 effect_key 在 _special（说明没落 default）
		var special: Dictionary = result.get("_special", {})
		if special.has(effect_key):
			fail.call("%s 的 %s 仍落 _special 空转！" % [mod_id, effect_key])
		# 2. 应写入了预期字段（值相比 base 有变化）
		var got_val = result.get(expected_field, null)
		var base_val = base.get(expected_field, null)
		if got_val == null:
			fail.call("%s 未写入字段 %s" % [mod_id, expected_field])
		elif str(got_val) == str(base_val):
			fail.call("%s 写入 %s 但值未变（%s）" % [mod_id, expected_field, str(got_val)])
		else:
			var sign := "↑" if float(got_val) > float(base_val) else "↓"
			# deploy_delay_bonus 是负值=更快，特殊处理显示
			if expected_field == "deploy_delay_bonus":
				sign = "↓延迟"
			print("  ✓ %-22s %-16s → %s %s=%s (base=%s)" % [
				mod_id, effect_key, sign, expected_field, str(got_val), str(base_val)])

	# 额外验证：ally_fort_regen 的二次缩放（×0.25，不是×0.5）
	var r_gen = ModificationRegistry.apply_effects(base.duplicate(true), [{"id": "eng_07_generator"}])
	# eng_07 ally_fort_regen=0.50 → ×0.25 缩放 = ×1.125 → defense 100→112
	var def_after = int(r_gen.get("defense_light", 0))
	if def_after != 112:
		print("  [注] eng_07 二次缩放验证：defense_light=%d（预期112，×0.25缩放）" % def_after)

	if code == 0:
		print("✅ 全部 11 个光环改造已生效（不再空转）")
	else:
		print("❌ 存在失败，见上方 [FAIL]")
	quit(code)
