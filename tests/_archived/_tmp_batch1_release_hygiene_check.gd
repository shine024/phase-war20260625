extends SceneTree
## tests/_tmp_batch1_release_hygiene_check.gd — 批次1（P0-4+P0-5）验证
## ① GameConfig：死开关已删、reset 漏项已补（运行时行为验证）
## ② PerformanceMetricsManager：_deferred_flush 带 OS.is_debug_build() 发行门控（源文本断言，
##    release 分支需导出模板才能真跑，此处锁源码形态）
## Usage: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_batch1_release_hygiene_check.gd

func _read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s

func _initialize() -> void:
	var errs: Array[String] = []

	# ── ① GameConfig 运行时行为 ──
	var GameConfigScript := load("res://resources/game_config.gd")
	var cfg = GameConfigScript.new()

	# 死开关已删除（get 返回 null 且源码无定义）
	if cfg.get("enable_debug_logs") != null or cfg.get("enable_performance_stats") != null:
		errs.append("死开关字段仍存在")
	var cfg_src := _read_file("res://resources/game_config.gd")
	if cfg_src.find("enable_debug_logs") >= 0 or cfg_src.find("enable_performance_stats") >= 0:
		errs.append("源码仍残留 enable_debug_logs/enable_performance_stats")

	# debug_no_deploy_limits 默认 false（生产安全）
	if cfg.debug_no_deploy_limits != false:
		errs.append("debug_no_deploy_limits 默认值非 false")
	var dflt = GameConfigScript.get_default()
	if dflt.debug_no_deploy_limits != false:
		errs.append("get_default().debug_no_deploy_limits 非 false")

	# reset_to_defaults 补齐两个漏项：脏化字段后重置应回默认值
	cfg.debug_no_deploy_limits = true
	cfg.cross_row_direct_damage_mult = 0.11
	cfg.reset_to_defaults()
	if cfg.debug_no_deploy_limits != false:
		errs.append("reset_to_defaults 未重置 debug_no_deploy_limits")
	if absf(cfg.cross_row_direct_damage_mult - 0.70) > 0.0001:
		errs.append("reset_to_defaults 未重置 cross_row_direct_damage_mult（期望 0.70，得 %f）" % cfg.cross_row_direct_damage_mult)

	# ── ② PerformanceMetricsManager 发行门控（源文本断言）──
	var pm_src := _read_file("res://managers/performance_metrics_manager.gd")
	if pm_src.find("if not OS.is_debug_build():") < 0:
		errs.append("performance_metrics_manager 缺 OS.is_debug_build() 门控")
	var gate_idx := pm_src.find("if not OS.is_debug_build():")
	var flush_idx := pm_src.find("func _deferred_flush(")
	if gate_idx < 0 or flush_idx < 0 or gate_idx < flush_idx or gate_idx - flush_idx > 200:
		errs.append("门控不在 _deferred_flush 函数体开头附近")
	# 顺带确认类可加载（语法层）
	load("res://managers/performance_metrics_manager.gd")

	if errs.is_empty():
		print("BATCH1 CHECK: ALL PASS (5 assertions)")
		quit(0)
	else:
		for e in errs:
			printerr("FAIL: " + e)
		quit(1)
