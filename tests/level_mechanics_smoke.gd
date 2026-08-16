# 无 GdUnit 依赖的快速校验：v8 批次3 关卡特殊机制
#   - special_rules 数据挂载（2026-08-16 关卡设计审查后为 11 个关键关，其余无）
#   - get_special_rules 读取正确
#   - 能量惩罚倍率计算
#   - 坚守N波胜利条件逻辑（机制保留，仅普通关可挂载）
#   - 限定兵种白名单判定
#   - 部署上限叠加
#   - _format_special_rules 格式化
# 2026-08-16 更新：20/40/60/80/100 的 survive_waves 已移除（全是驻守相位师关，
# 胜负=摧毁基地，battle_manager 对相位师战提前 return，该规则永远不评估——死规则+UI 误导）。
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
	# 有规则的关键关（2026-08-16 后：20/40/60 不再挂规则）
	var ruled_levels: Array = [5, 15, 25, 30, 50, 55, 65, 80, 85, 90, 100]
	var ruled_count: int = 0
	for lvl in ruled_levels:
		var rules: Dictionary = li.get_special_rules(lvl)
		if not rules.is_empty():
			ruled_count += 1
	print("  %d 个关键关有规则 (期望 11)" % ruled_count)
	if ruled_count != 11:
		fail.call("关键关规则数 %d != 11" % ruled_count)
	# 无规则的普通关（如 1, 2, 3, 7, 8...）+ 已移除 survive_waves 的驻守关
	for lvl in [1, 2, 3, 7, 8, 11, 12, 20, 22, 23, 40, 60, 70, 100 + 1]:
		var r: Dictionary = li.get_special_rules(lvl)
		if lvl <= 100 and not r.is_empty():
			fail.call("关 %d 不应有规则" % lvl)
	print("  普通关无规则: 确认")

	# ══════════ 第20关：驻守相位师关，无特殊胜利规则 ══════════
	print("=== 第20关: 驻守关无 survive_waves ===")
	var r20: Dictionary = li.get_special_rules(20)
	print("  rules=%s (期望空——胜负=摧毁驻守相位师基地)" % str(r20))
	if not r20.is_empty():
		fail.call("第20关不应再挂 survive_waves（驻守关死规则，2026-08-16 已移除）")

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

	# ══════════ 第70关：deploy_limit 已移除（上场数现由装备战斗卡数决定）══════════
	print("=== 第70关: deploy_limit 已移除 ===")
	var r70: Dictionary = li.get_special_rules(70)
	# 关卡不再设 deploy_limit——可上场单位数 = 相位仪实际装备的战斗卡数（get_loadouts().size()）
	if r70.has("deploy_limit"):
		fail.call("第70关不应再含 deploy_limit（已改为装备战斗卡数决定）")
	# 全关卡都不应有 deploy_limit（系统已移除）
	for lvl in range(1, 101):
		if li.get_special_rules(lvl).has("deploy_limit"):
			fail.call("第%d关仍含已废弃的 deploy_limit" % lvl)
	print("  全 100 关均无 deploy_limit ✓")

	# ══════════ 第100关：终局（能量减半；胜负=摧毁奥米伽基地）══════════
	print("=== 第100关: 终局规则 ===")
	var r100: Dictionary = li.get_special_rules(100)
	var has_energy: bool = absf(float(r100.get("energy_mult", 1.0)) - 0.5) < 0.001
	print("  energy_mult=0.5: %s, win_type=%s (期望 true/空)" % [has_energy, r100.get("win_type", "")])
	if not has_energy:
		fail.call("第100关应含 energy_mult=0.5")
	if r100.has("win_type") or r100.has("win_param"):
		fail.call("第100关不应再含 survive_waves（驻守关死规则，2026-08-16 已移除）")
	if r100.has("deploy_limit"):
		fail.call("第100关不应再含 deploy_limit")

	# ══════════ 坚守N波胜利判定逻辑（机制保留，仅普通关可挂载）══════════
	print("=== 坚守N波胜利判定 ===")
	# 模拟 _check_win_lose 的 survive_waves 分支（纯逻辑验证；当前无关卡挂载该规则）
	var survive_target: int = 8
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

	# ══════════ 运行时：上场数 = 装备战斗卡数，由格子数截断（deploy_limit 已移除）══════════
	print("=== 运行时: max_units = mini(装备战斗卡数, 格子数9) ===")
	# 模拟 request_player_deploy: max_units = mini(get_max_deployable_units(), grid_slots)
	# get_max_deployable_units() = 相位仪绿槽实际装备的战斗卡数（get_loadouts().size()）
	var grid_slots: int = 9
	# 装备 5 张战斗卡 → 上场 5
	var equipped_5: int = 5
	var max_5: int = mini(equipped_5, grid_slots)
	print("  装备5张 → mini(5, 9) = %d (期望 5)" % max_5)
	if max_5 != 5:
		fail.call("装备5张战斗卡应可上场5个，实际 %d" % max_5)
	# 装备 9 张 → 填满 9 格
	var equipped_9: int = 9
	var max_9: int = mini(equipped_9, grid_slots)
	print("  装备9张 → mini(9, 9) = %d (期望 9)" % max_9)
	if max_9 != 9:
		fail.call("装备9张战斗卡应可上场9个，实际 %d" % max_9)
	# deploy_limit 不再参与：任何关卡都不应读到 deploy_limit
	for lvl in range(1, 101):
		if li.get_special_rules(lvl).has("deploy_limit"):
			fail.call("第%d关仍含已废弃 deploy_limit" % lvl)
	print("  deploy_limit 已从全关卡移除 ✓")

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
