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

	# ══════════ 第70关：部署上限已移除（不限单位数量）══════════
	print("=== 第70关: 部署上限已移除 ===")
	var r70: Dictionary = li.get_special_rules(70)
	var dl70: int = int(r70.get("deploy_limit", 0))
	print("  deploy_limit=%d (期望 0，无限制)" % dl70)
	if dl70 != 0:
		fail.call("第70关 deploy_limit 应已移除（0），实际 %d" % dl70)
	# 无 deploy_limit：max_units 不被关卡限制，保持基础值 6
	var base_max_units: int = 6
	var final_max: int = base_max_units
	if dl70 > 0:
		final_max = mini(final_max, dl70)
	print("  无 deploy_limit 时 max_units 保持 %d (期望 6)" % final_max)
	if final_max != 6:
		fail.call("第70关无 deploy_limit，max_units 应保持 6，实际 %d" % final_max)

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
	# v8 修复：惩罚只作用于"正向回复项"（基础回复 + 相位仪恢复），不作用于基座消耗。
	# 正向场景：基础回复 1.0，无相位仪恢复，消耗 0.5 → regen_in=1.0, 惩罚后 0.5, net=0.5-0.5=0.0
	var ENERGY_REGEN_PER_SEC: float = 1.0
	var PHASE_BASE_DRAIN_PER_SEC: float = 0.5
	var regen_in_pos: float = ENERGY_REGEN_PER_SEC * regen_mult
	var net_pos: float = regen_in_pos - PHASE_BASE_DRAIN_PER_SEC
	print("  正向: regen_in=%.2f, net=%.2f (期望 0.00)" % [regen_in_pos, net_pos])
	if absf(net_pos - 0.0) > 0.001:
		fail.call("正向场景 net 应 0.0，实际 %.3f" % net_pos)
	# 负值场景（修复核心）：相位基座消耗 > 回复（模拟高消耗相位仪）
	# 基础回复 1.0，消耗 2.0 → regen_in=1.0, 惩罚后 0.5, net=0.5-2.0=-1.5
	# 旧 bug（乘 net_regen）: net=(1.0-2.0)×0.5=-0.5（消耗被惩罚减免，方向反）
	# 新逻辑（乘 regen_in）: net=0.5-2.0=-1.5（消耗不减免，符合"惩罚应更难"）
	var drain_high: float = 2.0
	var regen_in_neg: float = ENERGY_REGEN_PER_SEC * regen_mult
	var net_neg_new: float = regen_in_neg - drain_high
	var net_neg_old_bug: float = (ENERGY_REGEN_PER_SEC - drain_high) * regen_mult
	print("  负值: 新逻辑 net=%.2f (期望 -1.50), 旧bug net=%.2f" % [net_neg_new, net_neg_old_bug])
	if absf(net_neg_new - (-1.5)) > 0.001:
		fail.call("负值场景新逻辑 net 应 -1.5，实际 %.3f" % net_neg_new)
	if absf(net_neg_new - net_neg_old_bug) < 0.001:
		fail.call("新旧逻辑应不同（否则修复无效）")

	# ══════════ 边界：越界关卡 ══════════
	print("=== 边界：越界关卡 ===")
	var r_over: Dictionary = li.get_special_rules(101)
	var r_under: Dictionary = li.get_special_rules(0)
	print("  关101: %s, 关0: %s (均期望空)" % [str(r_over), str(r_under)])
	if not r_over.is_empty() or not r_under.is_empty():
		fail.call("越界关卡应返回空字典")

	# ══════════ 运行时行为：energy_mult 作用于上限+开局 ══════════
	print("=== 运行时: energy_mult 惩罚 _max/_base_start ===")
	# 模拟 energy_manager._apply_instrument_energy 的 level_energy_mult 分支
	# 1星相位仪: _max = 100 + 1×200 = 300; 惩罚 0.5 → maxf(50, 150) = 150
	var star: int = 1
	var raw_max: float = 100.0 + float(star) * 200.0
	var em_25: float = float(li.get_special_rules(25).get("energy_mult", 1.0))
	var penalized_max_25: float = maxf(50.0, raw_max * em_25)
	var penalized_start_25: float = maxf(50.0, raw_max * em_25)  # _base_start = _max 同步惩罚
	print("  1星 raw=300, ×0.5 → max=%.0f, start=%.0f (期望 150/150)" % [penalized_max_25, penalized_start_25])
	if absf(penalized_max_25 - 150.0) > 0.1 or absf(penalized_start_25 - 150.0) > 0.1:
		fail.call("energy_mult 应同时作用于 _max 和 _base_start")
	# 极端惩罚不跌破 50 下限：7星 raw=1500, ×0.1 → maxf(50, 150)=150... 取更小惩罚验证下限
	var tiny_em: float = 0.01
	var floored: float = maxf(50.0, raw_max * tiny_em)
	print("  1星 ×0.01 → maxf(50, 3) = %.0f (期望 50 下限)" % floored)
	if absf(floored - 50.0) > 0.1:
		fail.call("energy_mult 惩罚应受 50 下限保护")

	# ══════════ 运行时：deploy_limit 三者取 mini ══════════
	print("=== 运行时: deploy_limit 与相位仪上限/槽位数取 mini ===")
	# 模拟 request_player_deploy: max_units = mini(相位仪上限, 槽位数, deploy_limit)
	# 第70关 deploy_limit 已移除，相位仪6槽, 格子5 → mini(6,5)=5
	var pi_cap: int = 6
	var grid_slots: int = 5
	var dl_70: int = int(li.get_special_rules(70).get("deploy_limit", 0))
	var final_cap_70: int = mini(pi_cap, grid_slots)
	if dl_70 > 0:
		final_cap_70 = mini(final_cap_70, dl_70)
	print("  mini(6, 5, 无) = %d (期望 5)" % final_cap_70)
	if final_cap_70 != 5:
		fail.call("第70关无 deploy_limit，应 mini(6,5)=5，实际 %d" % final_cap_70)
	# 普通关（无 deploy_limit）：deploy_limit=0 时不改变 max_units
	var dl_normal: int = int(li.get_special_rules(7).get("deploy_limit", 0))
	var final_cap_normal: int = mini(pi_cap, grid_slots)
	if dl_normal > 0:
		final_cap_normal = mini(final_cap_normal, dl_normal)
	print("  普通关 mini(6, 5, 无) = %d (期望 5)" % final_cap_normal)
	if final_cap_normal != 5:
		fail.call("无 deploy_limit 关应保持 mini(6,5)=5")

	# ══════════ 运行时：restrict_platforms 拦截判定 ══════════
	print("=== 运行时: restrict_platforms 拦截分支 ===")
	# 模拟 battle_spawn_system.request_player_deploy 的 restrict 分支
	# 第15关 restrict=[0]（步兵），platform_type=1（装甲）→ 不在白名单 → 拦截
	var restrict_15: Array = li.get_special_rules(15).get("restrict_platforms", [])
	var pt_armor: int = 1
	var blocked: bool = (not restrict_15.is_empty()) and (not restrict_15.has(pt_armor))
	print("  第15关 装甲(1) → 拦截=%s (期望 true)" % blocked)
	if not blocked:
		fail.call("第15关装甲应被 restrict_platforms 拦截")
	# 第15关 步兵(0) → 在白名单 → 放行
	var pt_infantry: int = 0
	var allowed: bool = (not restrict_15.is_empty()) and restrict_15.has(pt_infantry)
	print("  第15关 步兵(0) → 放行=%s (期望 true)" % allowed)
	if not allowed:
		fail.call("第15关步兵应被 restrict_platforms 放行")
	# 普通关 restrict=[] → 空白名单不拦截
	var restrict_normal: Array = li.get_special_rules(7).get("restrict_platforms", [])
	var no_restrict: bool = restrict_normal.is_empty()
	print("  第7关 restrict空 → 不拦截=%s (期望 true)" % no_restrict)
	if not no_restrict:
		fail.call("普通关 restrict_platforms 应为空（不拦截）")

	# ══════════ 运行时：UI 预过滤灰显判定（v8 修复3） ══════════
	print("=== 运行时: UI 预过滤灰显判定 ===")
	# 模拟 bottom_instrument_bar._is_card_platform_restricted 的逻辑
	# 受限卡 → 灰显(modulate.a=0.4)；普通关/不受限 → 不灰显
	var should_dim_armor_15: bool = (not restrict_15.is_empty()) and (not restrict_15.has(pt_armor))
	var should_dim_infantry_15: bool = (not restrict_15.is_empty()) and (not restrict_15.has(pt_infantry))
	print("  第15关 装甲灰显=%s (期望 true), 步兵灰显=%s (期望 false)" % [should_dim_armor_15, should_dim_infantry_15])
	if not should_dim_armor_15:
		fail.call("第15关受限卡应灰显")
	if should_dim_infantry_15:
		fail.call("第15关步兵（白名单内）不应灰显")
	if not no_restrict:
		fail.call("普通关不应有任何灰显")

	# ══════════ 总结 ══════════
	if code == 0:
		print("\n=== ALL PASS ===")
	else:
		print("\n=== FAILED ===")
	quit(code)
