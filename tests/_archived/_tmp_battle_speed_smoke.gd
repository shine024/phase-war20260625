extends SceneTree
## v32.0 B1-1 smoke：改动文件 load 解析 + BattleTimeState 行为断言（无 GdUnit 依赖）
## 用法：godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_battle_speed_smoke.gd

func _initialize() -> void:
	var failures: Array[String] = []

	# 1) 改动文件全部可解析加载（真实 Godot parser，绕开 gdtoolkit 误报）
	for path in [
		"res://scripts/battle/battle_time_state.gd",
		"res://managers/battle/battle_spectacle.gd",
		"res://scenes/ui/top_hud_bar.gd",
		"res://managers/audio_manager.gd",
		"res://scripts/combat_feedback.gd",
		"res://scenes/title_screen.gd",
		"res://scripts/battle/vfx_impact_factory.gd",
		"res://scenes/ui/afk_panel.gd",
		"res://scripts/battle/battle_unit_record.gd",
		"res://scenes/units/construct_unit.gd",
		"res://scenes/units/enemy_unit.gd",
		"res://managers/battle/battle_manager.gd",
		"res://scenes/ui/mvp_panel.gd",
		"res://managers/audio_manager.gd",
	]:
		var s = load(path)
		if s == null:
			failures.append("load 失败: " + path)
		else:
			print("  load ok: ", path)

	var BTS = load("res://scripts/battle/battle_time_state.gd")

	# 2) 行为断言
	if BTS.snap_scale(9.9) != 4.0:
		failures.append("snap_scale(9.9) != 4.0")
	if BTS.snap_scale(2.6) != 3.0:
		failures.append("snap_scale(2.6) != 3.0")

	BTS.enter_fast_forward()
	if not BTS.ff_active:
		failures.append("enter_fast_forward 后 ff_active != true")
	if Engine.time_scale != BTS.FF_TIME_SCALE:
		failures.append("FF time_scale != %s (got %s)" % [BTS.FF_TIME_SCALE, Engine.time_scale])
	if Engine.max_physics_steps_per_frame != BTS.FF_MAX_PHYSICS_STEPS:
		failures.append("FF physics steps != 16")
	BTS.exit_fast_forward(2.0)
	if Engine.time_scale != 2.0 or Engine.max_physics_steps_per_frame != 8:
		failures.append("exit_fast_forward 未恢复到 2x/8 步")
	BTS.restore_neutral()
	if Engine.time_scale != 1.0 or BTS.ff_active:
		failures.append("restore_neutral 未回到 1x 中性态")

	# 3) 持久化往返（临时文件，测后删）
	BTS.user_scale = 3.0
	BTS.save_pref()
	BTS.user_scale = 1.0
	BTS.reset_pref_cache()
	if BTS.load_pref() != 3.0:
		failures.append("偏好持久化往返失败")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://battle_speed.cfg"))
	BTS.reset_pref_cache()
	BTS.user_scale = 1.0

	# 4) 工厂守卫抽样：极速推演期间 spawn 不产生节点
	var ff_guard_calls := 0
	if BTS.has_method("enter_fast_forward"):
		BTS.enter_fast_forward()
		var factory = load("res://scripts/battle/vfx_impact_factory.gd")
		# 守卫是静态早退，无树时也应安全（parent 传 null 即可触达守卫行）
		factory.spawn_crit_aura(null, Vector2.ZERO)
		factory.spawn_smoke_column(null, Vector2.ZERO)
		BTS.restore_neutral()
		ff_guard_calls += 1
	print("  ff guard probe calls: ", ff_guard_calls)

	if failures.is_empty():
		print("BATTLE SPEED SMOKE: ALL PASS")
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: " + f)
		print("BATTLE SPEED SMOKE: FAILED (%d)" % failures.size())
		quit(1)
