extends SceneTree
## v10 单位AI修复 · 改动文件加载检查（headless --script 模式）
## 用法: Godot --headless --rendering-driver opengl3 --path . --script tests/ai_fix_check.gd
## 逐个 load() 本轮修复涉及的脚本，编译失败（语法/引用错误）即退出码 1。

func _init() -> void:
	var scripts_to_check: Array = [
		"res://scripts/battle/module_effect_handler.gd",
		"res://scripts/battle/combo_engine.gd",
		"res://managers/battle/enemy_master_skill_engine.gd",
		"res://scenes/units/construct_unit.gd",
		"res://managers/battle/card_periodic_skill_engine.gd",
		"res://scenes/units/enemy_unit.gd",
		"res://scripts/battle/unit_status_collector.gd",
		"res://scripts/battle/dot_vfx_manager.gd",
		"res://scripts/battle/construct_unit_ai.gd",
		"res://scenes/units/bullet.gd",
		"res://managers/battle/simple_indirect_projectile_batch.gd",
		"res://scripts/battle/attack_calculator.gd",
		"res://managers/battle/battle_spawn_system.gd",
		"res://scenes/units/enemy_phase_field_driver.gd",
		"res://scripts/battle/mod_aura_handler.gd",
		"res://scripts/battle/faction_skill_effect_handler.gd",
		"res://scenes/units/swarm_enemy_controller.gd",
		"res://scenes/units/swarm_enemy_slot.gd",
		"res://scenes/tools/effect_lab_panel.gd",
	]
	var all_ok := true
	for p in scripts_to_check:
		var s: GDScript = load(p)
		if s == null:
			print("FAIL load: %s" % p)
			all_ok = false
		else:
			print("OK  : %s" % p)
	# 附加断言：AttackCalculator.scale_attack_speeds 存在且可调（H1 统一入口）
	if all_ok:
		var ac: GDScript = load("res://scripts/battle/attack_calculator.gd")
		if not ac.has_method("scale_attack_speeds"):
			print("FAIL: AttackCalculator.scale_attack_speeds missing")
			all_ok = false
		else:
			print("OK  : scale_attack_speeds present")
		var aic: GDScript = load("res://scripts/battle/construct_unit_ai.gd")
		if not aic.has_method("get_attack_delta_scale"):
			print("FAIL: ConstructUnitAI.get_attack_delta_scale missing")
			all_ok = false
		else:
			print("OK  : get_attack_delta_scale present")
	if all_ok:
		print("=== ALL PASS ===")
	else:
		print("=== HAS FAILURES ===")
	quit(0 if all_ok else 1)
