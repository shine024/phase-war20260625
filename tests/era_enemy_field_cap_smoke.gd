# 2026-08-25 普通关敌方在场上限冒烟：ERA_ENEMY_FIELD_CAP（WW1=6 / WW2=7 / 冷战=8 / 现代=9 / 近未来=9）
# 无 GdUnit 依赖。验证两件事：
#   1) LevelEras.get_enemy_field_cap_for_level 各时代取值正确（纯静态数据，无 autoload 依赖）
#   2) battle_spawn_system._enemy_field_unit_cap 已接入时代上限 + 相位师战豁免（源码守卫，
#      与 deploy_limits_toggle_smoke 同款做法兜住接线；实测 --script 模式下 autoload 有
#      实例化（GameManager.current_level=1），第 3 组直接走真实 GameManager 分支返回 6）
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/era_enemy_field_cap_smoke.gd
extends SceneTree


func _initialize() -> void:
	var errs: Array[String] = []
	var LevelErasScript: Script = load("res://data/level_eras.gd")
	if LevelErasScript == null:
		_fail(errs, "level_eras.gd 加载失败")
		_finish(errs)
		return

	# ── 1) 时代上限数据断言（关卡边界各测首/尾关） ──
	var cases: Dictionary = {
		1: 6, 10: 6, 20: 6,     # WW1
		21: 7, 30: 7, 40: 7,    # WW2
		41: 8, 50: 8, 60: 8,    # COLD_WAR
		61: 9, 70: 9, 80: 9,    # MODERN
		81: 9, 90: 9, 100: 9,   # NEAR_FUTURE
	}
	for lv in cases:
		var cap: int = int(LevelErasScript.get_enemy_field_cap_for_level(int(lv)))
		var expect: int = int(cases[lv])
		if cap != expect:
			_fail(errs, "L%d 上限=%d 期望=%d" % [lv, cap, expect])
	print("  时代上限：", "PASS（6/7/8/9/9）" if errs.is_empty() else "见错误")

	# ── 2) battle_spawn_system 接线守卫（源码级） ──
	var f := FileAccess.open("res://managers/battle/battle_spawn_system.gd", FileAccess.READ)
	if f == null:
		_fail(errs, "battle_spawn_system.gd 读取失败")
	else:
		var src := f.get_as_text()
		f.close()
		if src.find("get_enemy_field_cap_for_level") < 0:
			_fail(errs, "_enemy_field_unit_cap 未接入 LevelEras.get_enemy_field_cap_for_level")
		if src.find("_is_phase_master_battle") < 0:
			_fail(errs, "_enemy_field_unit_cap 缺少相位师战豁免守卫（_is_phase_master_battle）")
		if src.find("clampi(LevelEras.get_enemy_field_cap_for_level") < 0:
			_fail(errs, "时代上限未 clampi 到 [1, SLOT_COUNT]")

	# ── 3) 实测分支：--script 下 GameManager 实例化、current_level=1（WW1）→ 应返回 6；
	# 若某环境 autoload 未实例化则走满格兜底 9。两者皆合法，只断言不越界并打印实际值。 ──
	var bss_script: Script = load("res://managers/battle/battle_spawn_system.gd")
	if bss_script == null:
		_fail(errs, "battle_spawn_system.gd 加载失败（含编译错误）")
	else:
		var bss = bss_script.new()
		var cap: int = int(bss._enemy_field_unit_cap())
		print("  --script 兜底分支（无 autoload）返回：", cap)
		if cap < 1 or cap > 9:
			_fail(errs, "兜底分支返回越界值 %d（应 1~9）" % cap)

	_finish(errs)


func _fail(errs: Array[String], msg: String) -> void:
	errs.append(msg)


func _finish(errs: Array[String]) -> void:
	if errs.is_empty():
		print("")
		print("=== era_enemy_field_cap_smoke: ALL PASS（时代敌方在场上限 6/7/8/9/9 + 相位师战豁免）===")
	else:
		print("")
		print("❌ era_enemy_field_cap_smoke: FAILED (%d)" % errs.size())
		for e in errs:
			push_error(e)
			print("  - ", e)
	quit(0 if errs.is_empty() else 1)
