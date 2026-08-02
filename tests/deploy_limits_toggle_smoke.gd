# 无 GdUnit 依赖的快速校验：部署限制测试开关（v8.x）
# 验证：①开关字段存在且默认 false ②3 个限制校验被 _no_limits 包裹 ③get_remaining_deployable_count 开关短路
# 用源文件文本解析（不依赖 autoload）。
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/deploy_limits_toggle_smoke.gd
extends SceneTree


func _initialize() -> void:
	var code := 0
	var errs: Array[String] = []

	# ── ① GameConfig 开关字段存在 + 默认 false ──
	var cfg_src := _read_file("res://resources/game_config.gd")
	if cfg_src.is_empty():
		errs.append("无法读取 game_config.gd")
	else:
		if cfg_src.find("debug_no_deploy_limits") < 0:
			errs.append("GameConfig 缺少 debug_no_deploy_limits 字段")
		# 默认值应为 false（生产安全）
		if cfg_src.find("debug_no_deploy_limits: bool = false") < 0:
			errs.append("debug_no_deploy_limits 默认值应 = false")
		# get_default 里也要设 false
		if cfg_src.find("debug_no_deploy_limits = false") < 0:
			errs.append("get_default() 未设置 debug_no_deploy_limits = false")

	# ── ② battle_spawn_system 的 3 个限制校验被 _no_limits 包裹 ──
	var bs_src := _read_file("res://managers/battle/battle_spawn_system.gd")
	if bs_src.is_empty():
		errs.append("无法读取 battle_spawn_system.gd")
	else:
		# preload GameConfig
		if bs_src.find('const GameConfig = preload("res://resources/game_config.gd")') < 0:
			errs.append("battle_spawn_system 未 preload GameConfig")
		# _no_limits 变量定义
		if bs_src.find("GameConfig.get_default().debug_no_deploy_limits") < 0:
			errs.append("未读取 debug_no_deploy_limits 开关")
		# 3 个校验块的条件
		# a) 总数上限校验（if not _no_limits: 包住 live_count 检查）
		if bs_src.find("if not _no_limits:") < 0:
			errs.append("总数上限校验未用 _no_limits 包裹")
		# b) 同卡存活上限（if not _no_limits and _reach_alive_limit_for_card）
		if bs_src.find("if not _no_limits and _reach_alive_limit_for_card") < 0:
			errs.append("同卡存活上限校验未用 _no_limits 包裹")
		# c) 兵种白名单（if not _no_limits and not _restrict.is_empty()）
		if bs_src.find("if not _no_limits and not _restrict.is_empty()") < 0:
			errs.append("兵种白名单校验未用 _no_limits 包裹")
		# d) get_remaining_deployable_count 短路返回 999
		var cnt_idx := bs_src.find("func get_remaining_deployable_count()")
		if cnt_idx < 0:
			errs.append("缺少 get_remaining_deployable_count")
		else:
			# 在该函数之后的 200 字符内找开关短路
			var after := bs_src.substr(cnt_idx, 400)
			if after.find("debug_no_deploy_limits") < 0 or after.find("return 999") < 0:
				errs.append("get_remaining_deployable_count 未加开关短路")

	# 输出结果
	if errs.is_empty():
		print("")
		print("╔══════════════════════════════════════════════════════╗")
		print("║  ✅ deploy_limits_toggle_smoke: ALL PASS             ║")
		print("╠══════════════════════════════════════════════════════╣")
		print("║  GameConfig.debug_no_deploy_limits 存在+默认false ✅ ║")
		print("║  3 个限制校验被 _no_limits 包裹:                     ║")
		print("║    ①总数上限 ②同卡存活 ③兵种白名单 ✅              ║")
		print("║  get_remaining_deployable_count 开关短路(999) ✅     ║")
		print("║  使用: 测试时把开关改 true 即可自由放兵             ║")
		print("╚══════════════════════════════════════════════════════╝")
	else:
		print("")
		print("❌ deploy_limits_toggle_smoke: FAILED (%d errors)" % errs.size())
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
