# 无 GdUnit 依赖的快速校验：v7.x 敌方曲射/空射索敌链路
# 1) GC.legacy_weapon_to_new_weapon_type 映射正确性（legacy→新枚举）
# 2) TargetSelection.select_target 三种差异化选敌（直射/曲射/空射）
# 3) GC.legacy_weapon_to_new_weapon_type 与 is_indirect_weapon_type 曲射口径一致
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/enemy_targeting_smoke.gd
extends SceneTree

const GC = preload("res://resources/game_constants.gd")
const TargetSelection = preload("res://scripts/battle/target_selection.gd")


# 轻量 mock 单位：模拟 UnitStats 的索敌相关字段 + Node2D 位置
class MockUnit extends Node2D:
	var stats: UnitStats = null
	var hp: float = 100.0
	func _init(p_stats: UnitStats, pos: Vector2, p_hp: float = 100.0) -> void:
		stats = p_stats
		hp = p_hp
		global_position = pos


func _make_stats(ck: int, atk_l: float, atk_a: float, atk_air: float) -> UnitStats:
	var s := UnitStats.new()
	s.combat_kind = ck
	s.attack_light = atk_l
	s.attack_armor = atk_a
	s.attack_air = atk_air
	return s


func _initialize() -> void:
	var code := 0

	# === 1. legacy_weapon_to_new_weapon_type 映射 ===
	# 直射类 legacy 值 → DIRECT
	for legacy in [0, 1, 2, 4, 5, 6, 8, 10]:  # SMG/RIFLE/MG/PISTOL/SHOTGUN/SNIPER/LASER/OMEGA
		var mapped := GC.legacy_weapon_to_new_weapon_type(legacy, false)
		if mapped != GC.WeaponType.DIRECT:
			push_error("legacy %d non-aircraft expected DIRECT(%d) got %d" % [legacy, GC.WeaponType.DIRECT, mapped])
			code = 1
	# 曲射类 legacy 值 → INDIRECT
	for legacy in [3, 7, 9, 11]:  # ROCKET/FLAK/MISSILE/RAIL
		var mapped := GC.legacy_weapon_to_new_weapon_type(legacy, false)
		if mapped != GC.WeaponType.INDIRECT:
			push_error("legacy %d non-aircraft expected INDIRECT(%d) got %d" % [legacy, GC.WeaponType.INDIRECT, mapped])
			code = 1
	# is_aircraft=true → AERIAL（无论 legacy 值）
	for legacy in [0, 3, 7, 9]:
		var mapped := GC.legacy_weapon_to_new_weapon_type(legacy, true)
		if mapped != GC.WeaponType.AERIAL:
			push_error("legacy %d aircraft expected AERIAL(%d) got %d" % [legacy, GC.WeaponType.AERIAL, mapped])
			code = 1

	# === 2. is_indirect_weapon_type 与映射口径一致 ===
	# 凡是映射到 INDIRECT 的非 aircraft legacy 值，is_indirect 也应为 true
	for legacy in [3, 7, 9]:
		var mapped := GC.legacy_weapon_to_new_weapon_type(legacy, false)
		if mapped == GC.WeaponType.INDIRECT and not GC.is_indirect_weapon_type(legacy):
			push_error("口径不一致: legacy %d 映射 INDIRECT 但 is_indirect=false" % legacy)
			code = 1
	# 注意 RAIL(11) 映射 INDIRECT 但 is_indirect 不含 11（索敌需要差异化但渲染层不视作曲射）——属设计意图，仅打印不报错
	if GC.legacy_weapon_to_new_weapon_type(11, false) == GC.WeaponType.INDIRECT and not GC.is_indirect_weapon_type(11):
		print("note: RAIL(11) maps to INDIRECT for targeting but not in is_indirect_weapon_type (design intent)")

	# === 3. TargetSelection.select_target 差异化选敌 ===
	# 构造场景：我方有一个轻装(近)、一个装甲(远)单位
	var light_stats := _make_stats(GC.CombatKind.LIGHT, 10, 5, 5)
	var armor_stats := _make_stats(GC.CombatKind.ARMOR, 5, 10, 5)
	var light_unit := MockUnit.new(light_stats, Vector2(100, 0))
	var armor_unit := MockUnit.new(armor_stats, Vector2(500, 0))
	var candidates := [light_unit, armor_unit]

	# 直射(DIRECT=0)：选最近 → light_unit (100 比 500 近)
	var attacker := MockUnit.new(light_stats, Vector2(0, 0))
	var t_direct := TargetSelection.select_target(attacker, candidates, GC.WeaponType.DIRECT)
	if t_direct != light_unit:
		push_error("DIRECT expected nearest(light_unit) got %s" % str(t_direct))
		code = 1

	# 曲射(INDIRECT=1)：attacker 对装甲克制(attack_armor最高) → 选 armor_unit 即使更远
	var anti_armor_stats := _make_stats(GC.CombatKind.LIGHT, 5, 20, 5)
	var attacker_indirect := MockUnit.new(anti_armor_stats, Vector2(0, 0))
	var t_indirect := TargetSelection.select_target(attacker_indirect, candidates, GC.WeaponType.INDIRECT)
	if t_indirect != armor_unit:
		push_error("INDIRECT expected counter(armor_unit) got %s" % str(t_indirect))
		code = 1

	# 空射(AERIAL=2)：优先打空中目标。加一个 AIR 单位(最远)
	var air_stats := _make_stats(GC.CombatKind.AIR, 5, 5, 10)
	var air_unit := MockUnit.new(air_stats, Vector2(800, 0))
	var candidates_with_air := [light_unit, armor_unit, air_unit]
	var t_aerial := TargetSelection.select_target(attacker, candidates_with_air, GC.WeaponType.AERIAL)
	if t_aerial != air_unit:
		push_error("AERIAL expected air target got %s" % str(t_aerial))
		code = 1

	# 空射无空中目标时回退到最近
	var t_aerial_fallback := TargetSelection.select_target(attacker, candidates, GC.WeaponType.AERIAL)
	if t_aerial_fallback != light_unit:
		push_error("AERIAL fallback(no air) expected nearest(light_unit) got %s" % str(t_aerial_fallback))
		code = 1

	# === 4. 空候选回退 null ===
	var t_empty := TargetSelection.select_target(attacker, [], GC.WeaponType.DIRECT)
	if t_empty != null:
		push_error("empty candidates expected null got %s" % str(t_empty))
		code = 1

	# 清理
	light_unit.queue_free()
	armor_unit.queue_free()
	air_unit.queue_free()
	attacker.queue_free()
	attacker_indirect.queue_free()

	if code == 0:
		print("enemy_targeting_smoke: OK")
	quit(code)
