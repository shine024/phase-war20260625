# 无 GdUnit 依赖的快速校验：相位场属性点分配 UI 接口契约（v8.x）
# 验证：①4 个新方法在源码中定义 ②新信号在 SignalBus 注册 ③关键常量正确
# 注：PhaseInstrumentManager 依赖 autoload（SignalBus 等），--script 模式下 new() 会报依赖错，
#     故用源文件文本解析验证「定义存在」，而非实例化。运行时数值留实机验证。
#     分配算法逻辑已用独立脚本验证（7 项全 PASS）。
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/phase_field_allocation_smoke.gd
extends SceneTree


func _initialize() -> void:
	var code := 0
	var errs: Array[String] = []

	# ── ① 4 个分配方法在 manager 源码中定义 ──
	var pim_src := _read_file("res://managers/phase_instrument_manager.gd")
	if pim_src.is_empty():
		errs.append("无法读取 phase_instrument_manager.gd")
	else:
		var required_methods := [
			"func can_allocate_phase_field_point(",
			"func allocate_phase_field_point(",
			"func refund_phase_field_point(",
			"func reset_phase_field_allocations(",
		]
		for m in required_methods:
			if pim_src.find(m) < 0:
				errs.append("缺少方法定义: %s" % m)
		# emit 调用存在（分配后发信号）
		if pim_src.find("phase_field_points_changed") < 0:
			errs.append("manager 未 emit phase_field_points_changed")
		# get_phase_field_total_bonus / apply_phase_field_bonus_to_unit_stats 存在（生效入口）
		if pim_src.find("func get_phase_field_total_bonus(") < 0:
			errs.append("缺少 get_phase_field_total_bonus")
		if pim_src.find("func apply_phase_field_bonus_to_unit_stats(") < 0:
			errs.append("缺少 apply_phase_field_bonus_to_unit_stats")

	# ── ② PHASE_FIELD_GROWTH_RULES 4 维齐全 + per_point 正值 ──
	if not pim_src.is_empty():
		var expected_keys := ["atk_pct", "def_pct", "hp_pct", "energy_output_pct"]
		for k in expected_keys:
			if pim_src.find('"%s"' % k) < 0:
				errs.append("GROWTH_RULES 缺少维度: %s" % k)
		# 验证每点收益数值（正数）
		if pim_src.find('"per_point": 0.02') < 0 or pim_src.find('"per_point": 0.03') < 0:
			errs.append("per_point 数值异常（应含 0.02 和 0.03）")

	# ── ③ SignalBus 注册了 phase_field_points_changed 信号 ──
	var sb_src := _read_file("res://scripts/signal_bus.gd")
	if sb_src.is_empty():
		errs.append("无法读取 signal_bus.gd")
	elif sb_src.find("signal phase_field_points_changed") < 0:
		errs.append("SignalBus 未注册 phase_field_points_changed 信号")

	# ── ④ selector 面板连接了信号 + 有分配回调 ──
	var sel_src := _read_file("res://scenes/ui/phase_instrument_selector.gd")
	if sel_src.is_empty():
		errs.append("无法读取 phase_instrument_selector.gd")
	else:
		if sel_src.find("phase_field_points_changed") < 0:
			errs.append("selector 未监听 phase_field_points_changed 信号")
		if sel_src.find("_on_allocate_pressed") < 0:
			errs.append("selector 缺少 _on_allocate_pressed 回调")
		if sel_src.find("_on_refund_pressed") < 0:
			errs.append("selector 缺少 _on_refund_pressed 回调")
		if sel_src.find("_on_reset_allocations_pressed") < 0:
			errs.append("selector 缺少 _on_reset_allocations_pressed 回调")

	# 输出结果
	if errs.is_empty():
		print("")
		print("╔══════════════════════════════════════════════════════╗")
		print("║  ✅ phase_field_allocation_smoke: ALL PASS           ║")
		print("╠══════════════════════════════════════════════════════╣")
		print("║  manager: 4 方法定义 + emit + 生效入口齐全 ✅       ║")
		print("║  GROWTH_RULES: 4 维 + per_point(0.02/0.03) ✅       ║")
		print("║  SignalBus: phase_field_points_changed 已注册 ✅    ║")
		print("║  selector: 信号监听 + 3 回调齐全 ✅                ║")
		print("║  注: 运行时数值验证需游戏内实机                     ║")
		print("╚══════════════════════════════════════════════════════╝")
	else:
		print("")
		print("❌ phase_field_allocation_smoke: FAILED (%d errors)" % errs.size())
		for e in errs:
			push_error(e)
			print("  - ", e)
		code = 1
	quit(code)


func _read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var content := f.get_as_text()
	f.close()
	return content
