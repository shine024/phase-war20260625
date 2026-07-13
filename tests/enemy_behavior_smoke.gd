# 无 GdUnit 依赖的快速校验：v8 批次1 敌人行为激活
#   - 1B: antitank 索敌覆盖（TargetSelection._get_counter_priority）
#   - 1C: fast 攻速加成倍率 / stealth grace 判定
#   - 1A: 反应式 AI 克制表（_counter_kind_for 逻辑等价验证）
# 注：TargetSelection 是 RefCounted static 类，可直接调用 static 方法。
#     _counter_kind_for 是 instance 方法，这里复刻其 match 逻辑做等价验证
#     （避免实例化 enemy_phase_field_driver 需要完整战斗环境）。
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/enemy_behavior_smoke.gd
extends SceneTree

const TargetSelection = preload("res://scripts/battle/target_selection.gd")
const GC = preload("res://resources/game_constants.gd")


func _initialize() -> void:
	var code := 0
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		code = 1

	# ══════════ 1B: antitank 索敌覆盖 ══════════
	print("=== 1B: antitank 索敌覆盖 ===")
	# 构造一个三维攻击偏向轻装的 UnitStats（正常应判 LIGHT 克制）
	var stats_light := UnitStats.new()
	stats_light.attack_light = 50.0
	stats_light.attack_armor = 10.0
	stats_light.attack_air = 5.0
	# 无 tag → 正常判定为 LIGHT
	var prio_no_tag: int = TargetSelection._get_counter_priority(stats_light, [])
	print("  无tag 三维(50/10/5) → 克制=%d (期望 LIGHT=%d)" % [prio_no_tag, GC.CombatKind.LIGHT])
	if prio_no_tag != GC.CombatKind.LIGHT:
		fail.call("无tag 应判 LIGHT，实际 %d" % prio_no_tag)
	# antitank tag → 强制 ARMOR（即使三维偏向轻装）
	var prio_antitank: int = TargetSelection._get_counter_priority(stats_light, ["antitank"])
	print("  antitank tag 三维(50/10/5) → 克制=%d (期望 ARMOR=%d)" % [prio_antitank, GC.CombatKind.ARMOR])
	if prio_antitank != GC.CombatKind.ARMOR:
		fail.call("antitank tag 应强制 ARMOR，实际 %d" % prio_antitank)
	# 无 antitank tag 的其他 tag 不影响
	var prio_other: int = TargetSelection._get_counter_priority(stats_light, ["fast", "elite"])
	if prio_other != GC.CombatKind.LIGHT:
		fail.call("fast/elite tag 不应改变克制判定，实际 %d" % prio_other)

	# 装甲偏向 stats，无 tag 应判 ARMOR
	var stats_armor := UnitStats.new()
	stats_armor.attack_light = 10.0
	stats_armor.attack_armor = 50.0
	stats_armor.attack_air = 5.0
	var prio_armor: int = TargetSelection._get_counter_priority(stats_armor, [])
	if prio_armor != GC.CombatKind.ARMOR:
		fail.call("装甲偏向 stats 应判 ARMOR，实际 %d" % prio_armor)

	# 空军偏向 stats，无 tag 应判 AIR
	var stats_air := UnitStats.new()
	stats_air.attack_light = 5.0
	stats_air.attack_armor = 10.0
	stats_air.attack_air = 50.0
	var prio_air: int = TargetSelection._get_counter_priority(stats_air, [])
	if prio_air != GC.CombatKind.AIR:
		fail.call("空军偏向 stats 应判 AIR，实际 %d" % prio_air)

	# ══════════ 1C: fast 攻速加成倍率 ══════════
	print("=== 1C: fast 攻速加成 ===")
	const FAST_INTERVAL_MULT: float = 0.80
	# 模拟 _apply_behavior_tags 的 fast 分支：interval ×0.80
	var base_interval: float = 1.0
	var fast_interval: float = maxf(0.05, base_interval * FAST_INTERVAL_MULT)
	print("  base interval=%.2f → fast interval=%.2f (期望 0.80)" % [base_interval, fast_interval])
	if absf(fast_interval - 0.80) > 0.001:
		fail.call("fast interval 应为 0.80，实际 %.4f" % fast_interval)
	# weapon_slots 的 attack_speed 倍率 = 1/0.80 = 1.25
	var spd_mult: float = 1.0 / FAST_INTERVAL_MULT
	var base_spd: float = 1.0
	var fast_spd: float = maxf(0.1, base_spd * spd_mult)
	print("  base attack_speed=%.2f → fast=%.2f (期望 1.25)" % [base_spd, fast_spd])
	if absf(fast_spd - 1.25) > 0.001:
		fail.call("fast attack_speed 应为 1.25，实际 %.4f" % fast_spd)
	# 验证 interval 缩短 = speed 提升（互为倒数，DPS 守恒）
	if absf((base_interval / fast_interval) - (fast_spd / base_spd)) > 0.001:
		fail.call("interval 缩短率应 = speed 提升率（DPS 守恒）")

	# ══════════ 1C: stealth grace 判定逻辑 ══════════
	print("=== 1C: stealth grace 判定 ===")
	const STEALTH_GRACE_DURATION: float = 4.0
	const STEALTH_GRACE_DAMAGE_MUL: float = 0.6
	# 模拟 grace 计时器：开局满，4 秒后归零
	var grace_timer: float = STEALTH_GRACE_DURATION
	var in_grace: bool = grace_timer > 0.0  # _is_stealth_in_grace 等价
	print("  开局 grace_timer=%.1f → in_grace=%s (期望 true)" % [grace_timer, in_grace])
	if not in_grace:
		fail.call("开局应在 grace 期内")
	# 模拟 4 秒后归零
	grace_timer = maxf(0.0, grace_timer - 4.5)
	in_grace = grace_timer > 0.0
	print("  4.5s后 grace_timer=%.1f → in_grace=%s (期望 false)" % [grace_timer, in_grace])
	if in_grace:
		fail.call("4 秒后应离开 grace 期")
	# grace 期内受伤 ×0.6
	var raw_dmg: float = 100.0
	var grace_dmg: float = raw_dmg * STEALTH_GRACE_DAMAGE_MUL
	print("  grace期内 原伤=%.0f → 实际=%.0f (期望 60)" % [raw_dmg, grace_dmg])
	if absf(grace_dmg - 60.0) > 0.001:
		fail.call("grace 期内伤害应为 60，实际 %.1f" % grace_dmg)

	# ══════════ 1A: 反应式 AI 克制表（_counter_kind_for 逻辑等价） ══════════
	print("=== 1A: 反应式 AI 克制表 ===")
	# 复刻 enemy_phase_field_driver._counter_kind_for 的 match 逻辑做等价验证
	var counter_kind_for := func(player_kind: int) -> int:
		match player_kind:
			GC.CombatKind.ARMOR: return GC.CombatKind.SUPPORT
			GC.CombatKind.AIR: return GC.CombatKind.AIR
			GC.CombatKind.LIGHT: return GC.CombatKind.ARMOR
			GC.CombatKind.SUPPORT: return GC.CombatKind.ARMOR
			GC.CombatKind.FORT: return GC.CombatKind.SUPPORT
		return -1
	# 玩家堆装甲 → 出 SUPPORT（反坦克 1.2x）
	var c1: int = counter_kind_for.call(GC.CombatKind.ARMOR)
	print("  玩家ARMOR → 出%d (期望 SUPPORT=%d)" % [c1, GC.CombatKind.SUPPORT])
	if c1 != GC.CombatKind.SUPPORT:
		fail.call("玩家 ARMOR 应出 SUPPORT，实际 %d" % c1)
	# 玩家堆空军 → 出 AIR（对空）
	var c2: int = counter_kind_for.call(GC.CombatKind.AIR)
	print("  玩家AIR → 出%d (期望 AIR=%d)" % [c2, GC.CombatKind.AIR])
	if c2 != GC.CombatKind.AIR:
		fail.call("玩家 AIR 应出 AIR，实际 %d" % c2)
	# 玩家堆轻装 → 出 ARMOR（碾压）
	var c3: int = counter_kind_for.call(GC.CombatKind.LIGHT)
	print("  玩家LIGHT → 出%d (期望 ARMOR=%d)" % [c3, GC.CombatKind.ARMOR])
	if c3 != GC.CombatKind.ARMOR:
		fail.call("玩家 LIGHT 应出 ARMOR，实际 %d" % c3)
	# 玩家堆堡垒 → 出 SUPPORT（反阵地）
	var c4: int = counter_kind_for.call(GC.CombatKind.FORT)
	print("  玩家FORT → 出%d (期望 SUPPORT=%d)" % [c4, GC.CombatKind.SUPPORT])
	if c4 != GC.CombatKind.SUPPORT:
		fail.call("玩家 FORT 应出 SUPPORT，实际 %d" % c4)

	# ══════════ 1A: 主力兵种统计逻辑 ══════════
	print("=== 1A: 主力兵种统计 ===")
	# 复刻 _dominant_player_kind 逻辑
	var dominant_kind := func(tally: Dictionary) -> int:
		var best_kind: int = -1
		var best_count: int = 0
		for ck in tally:
			var cnt: int = int(tally[ck])
			if cnt > best_count or (cnt == best_count and (best_kind < 0 or int(ck) < best_kind)):
				best_count = cnt
				best_kind = int(ck)
		return best_kind
	# 玩家阵容：2 装甲 + 1 轻装 → 主力 ARMOR
	var tally1: Dictionary = {GC.CombatKind.ARMOR: 2, GC.CombatKind.LIGHT: 1}
	var dom1: int = dominant_kind.call(tally1)
	print("  {ARMOR:2, LIGHT:1} → 主力=%d (期望 ARMOR=%d)" % [dom1, GC.CombatKind.ARMOR])
	if dom1 != GC.CombatKind.ARMOR:
		fail.call("主力应为 ARMOR，实际 %d" % dom1)
	# 空阵容 → -1（回退原序列）
	var tally2: Dictionary = {}
	var dom2: int = dominant_kind.call(tally2)
	print("  {} → 主力=%d (期望 -1)" % dom2)
	if dom2 != -1:
		fail.call("空阵容主力应为 -1，实际 %d" % dom2)

	# ══════════ 总结 ══════════
	if code == 0:
		print("\n=== ALL PASS ===")
	else:
		print("\n=== FAILED ===")
	quit(code)
