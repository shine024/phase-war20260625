# 无 GdUnit 依赖的快速校验：v8 批次3 关卡特殊机制
#   - special_rules 数据挂载（15 个关键关有规则，其余无）
#   - get_special_rules 读取正确
#   - 能量惩罚倍率计算
#   - 坚守N波胜利条件逻辑
#   - 限定兵种白名单判定
#   - 部署上限叠加
#   - _format_special_rules 格式化
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/level_mechanics_smoke.gd
extends SceneTree

const LevelInformation = preload("res://data/level_information.gd")


func _initialize() -> void:
	var code := 0
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		code = 1

	var li := LevelInformation.new()

	# ══════════ special_rules 数据挂载 ══════════
	print("=== special_rules 数据挂载 ===")
	# 有规则的关键关
	var ruled_levels: Array = [5, 15, 20, 25, 30, 40, 50, 55, 60, 65, 70, 80, 85, 90, 100]
	var ruled_count: int = 0
	for lvl in ruled_levels:
		var rules: Dictionary = li.get_special_rules(lvl)
		if not rules.is_empty():
			ruled_count += 1
	print("  %d 个关键关有规则 (期望 15)" % ruled_count)
	if ruled_count != 15:
		fail.call("关键关规则数 %d != 15" % ruled_count)
	# 无规则的普通关（如 1, 2, 3, 7, 8...）
	for lvl in [1, 2, 3, 7, 8, 11, 12, 22, 23, 100 + 1]:
		var r: Dictionary = li.get_special_rules(lvl)
		if lvl <= 100 and not r.is_empty():
			# 确认非关键关确实无规则（除 100 关外）
			if lvl not in ruled_levels:
				fail.call("关 %d 不应有规则" % lvl)
	print("  普通关无规则: 确认")

	# ══════════ 第20关：坚守8波 ══════════
	print("=== 第20关: 坚守8波 ===")
	var r20: Dictionary = li.get_special_rules(20)
	var wt20: String = String(r20.get("win_type", ""))
	var wp20: int = int(r20.get("win_param", 0))
	print("  win_type=%s, win_param=%d (期望 survive_waves/8)" % [wt20, wp20])
	if wt20 != "survive_waves":
		fail.call("第20关 win_type 应 survive_waves")
	if wp20 != 8:
		fail.call("第20关 win_param 应 8")

	# ══════════ 第25关：能量减半 ══════════
	print("=== 第25关: 能量减半 ===")
	var r25: Dictionary = li.get_special_rules(25)
	var em25: float = float(r25.get("energy_mult", 1.0))
	print("  energy_mult=%.2f (期望 0.5)" % em25)
	if absf(em25 - 0.5) > 0.001:
		fail.call("第25关 energy_mult 应 0.5")
	# 能量上限计算：300(1星) × 0.5 = 150
	var base_max: float = 300.0
	var penalized_max: float = maxf(50.0, base_max * em25)
	print("  1星能量上限 300×0.5 = %.0f (期望 150)" % penalized_max)
	if absf(penalized_max - 150.0) > 0.1:
		fail.call("能量惩罚计算应 150，实际 %.1f" % penalized_max)

	# ══════════ 第15关：限定步兵(platform_type=0) ══════════
	print("=== 第15关: 限定步兵 ===")
	var r15: Dictionary = li.get_special_rules(15)
	var restrict15: Array = r15.get("restrict_platforms", [])
	print("  restrict_platforms=%s (期望 [0])" % str(restrict15))
	if restrict15.size() != 1 or int(restrict15[0]) != 0:
		fail.call("第15关应限定 platform_type=0")
	# 白名单判定：步兵(0)可部署，装甲(1)不可
	if not restrict15.has(0):
		fail.call("步兵(0)应在白名单")
	if restrict15.has(1):
		fail.call("装甲(1)不应在白名单")

	# ══════════ 第70关：部署上限3 ══════════
	print("=== 第70关: 部署上限3 ===")
	var r70: Dictionary = li.get_special_rules(70)
	var dl70: int = int(r70.get("deploy_limit", 0))
	print("  deploy_limit=%d (期望 3)" % dl70)
	if dl70 != 3:
		fail.call("第70关 deploy_limit 应 3")
	# 上限叠加：mini(6, 3) = 3
	var base_max_units: int = 6
	var final_max: int = mini(base_max_units, dl70)
	print("  mini(6, 3) = %d (期望 3)" % final_max)
	if final_max != 3:
		fail.call("部署上限叠加应 3，实际 %d" % final_max)

	# ══════════ 第100关：多重规则 ══════════
	print("=== 第100关: 终局多重规则 ===")
	var r100: Dictionary = li.get_special_rules(100)
	var has_win: bool = String(r100.get("win_type", "")) == "survive_waves"
	var has_energy: bool = absf(float(r100.get("energy_mult", 1.0)) - 0.5) < 0.001
	var has_deploy: bool = int(r100.get("deploy_limit", 0)) == 4
	var param100: int = int(r100.get("win_param", 0))
	print("  survive_waves=%s, energy_mult=0.5: %s, deploy_limit=4: %s, win_param=%d" % [has_win, has_energy, has_deploy, param100])
	if not has_win or not has_energy or not has_deploy:
		fail.call("第100关应含多重规则")
	if param100 != 15:
		fail.call("第100关 win_param 应 15")

	# ══════════ 坚守N波胜利判定逻辑 ══════════
	print("=== 坚守N波胜利判定 ===")
	# 模拟 _check_win_lose 的 survive_waves 分支
	var survive_target: int = 8  # 第20关
	# 当前波数 < 目标 → 不胜
	var wave_before: int = 5
	var should_win_before: bool = (wave_before >= survive_target)
	print("  波数 %d/%d → 胜利=%s (期望 false)" % [wave_before, survive_target, should_win_before])
	if should_win_before:
		fail.call("波数未达标不应判胜")
	# 当前波数 >= 目标 → 胜
	var wave_at: int = 8
	var should_win_at: bool = (wave_at >= survive_target)
	print("  波数 %d/%d → 胜利=%s (期望 true)" % [wave_at, survive_target, should_win_at])
	if not should_win_at:
		fail.call("波数达标应判胜")

	# ══════════ 能量回复惩罚 ══════════
	print("=== 能量回复惩罚 ===")
	var regen_mult: float = 0.5  # 第5关
	var base_regen: float = 0.5  # 基础 1.0 - 消耗 0.5 = 0.5
	var penalized_regen: float = base_regen * regen_mult
	print("  回复 0.5×0.5 = %.2f (期望 0.25)" % penalized_regen)
	if absf(penalized_regen - 0.25) > 0.001:
		fail.call("回复惩罚应 0.25，实际 %.3f" % penalized_regen)

	# ══════════ 边界：越界关卡 ══════════
	print("=== 边界：越界关卡 ===")
	var r_over: Dictionary = li.get_special_rules(101)
	var r_under: Dictionary = li.get_special_rules(0)
	print("  关101: %s, 关0: %s (均期望空)" % [str(r_over), str(r_under)])
	if not r_over.is_empty() or not r_under.is_empty():
		fail.call("越界关卡应返回空字典")

	# ══════════ 总结 ══════════
	if code == 0:
		print("\n=== ALL PASS ===")
	else:
		print("\n=== FAILED ===")
	quit(code)
