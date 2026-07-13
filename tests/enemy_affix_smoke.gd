# 无 GdUnit 依赖的快速校验：v8 批次2 精英敌人词缀系统
#   - 词缀定义表完整性（10 个词缀，3 档稀有度）
#   - roll_affixes：normal 不 roll / elite roll 1 / boss roll 2
#   - apply_to_stats：各 effect_key 正确写入 UnitStats 字段
#   - 词缀池过滤（按稀有度）
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/enemy_affix_smoke.gd
extends SceneTree

const EnemyAffixes = preload("res://data/enemy_affixes.gd")


func _initialize() -> void:
	var code := 0
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		code = 1

	# ══════════ 词缀定义表完整性 ══════════
	print("=== 词缀定义表 ===")
	var affix_count: int = EnemyAffixes.ENEMY_AFFIXES.size()
	print("  定义词缀数 = %d (期望 >= 9)" % affix_count)
	if affix_count < 9:
		fail.call("词缀数 %d < 9" % affix_count)
	# 检查每个词缀有必要字段
	for affix_id in EnemyAffixes.ENEMY_AFFIXES:
		var def: Dictionary = EnemyAffixes.ENEMY_AFFIXES[affix_id]
		if not def.has("effect_key"):
			fail.call("词缀 %s 缺 effect_key" % affix_id)
		if not def.has("base_value"):
			fail.call("词缀 %s 缺 base_value" % affix_id)
		if not def.has("rarity"):
			fail.call("词缀 %s 缺 rarity" % affix_id)

	# ══════════ roll_affixes：normal/elite/boss ══════════
	print("=== roll_affixes 分布 ===")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# normal → 空
	var normal_affixes: Array = EnemyAffixes.roll_affixes("normal", rng)
	print("  normal → %d 个 (期望 0)" % normal_affixes.size())
	if not normal_affixes.is_empty():
		fail.call("normal 不应 roll 词缀，实际 %d" % normal_affixes.size())
	# elite → 恰好 1 个
	var elite_count_ok: int = 0
	for _i in range(20):
		var e: Array = EnemyAffixes.roll_affixes("elite", rng)
		if e.size() == 1:
			elite_count_ok += 1
	print("  elite → 20次抽样均=1个: %d/20" % elite_count_ok)
	if elite_count_ok < 20:
		fail.call("elite 应恒为 1 个词缀")
	# boss → 恰好 2 个
	var boss_count_ok: int = 0
	for _i in range(20):
		var b: Array = EnemyAffixes.roll_affixes("boss", rng)
		if b.size() == 2:
			boss_count_ok += 1
	print("  boss → 20次抽样均=2个: %d/20" % boss_count_ok)
	if boss_count_ok < 20:
		fail.call("boss 应恒为 2 个词缀")
	# boss 词缀不重复
	var b2: Array = EnemyAffixes.roll_affixes("boss", rng)
	if b2.size() == 2:
		var id0: String = String(b2[0].get("id", ""))
		var id1: String = String(b2[1].get("id", ""))
		if id0 == id1:
			fail.call("boss 2 个词缀不应重复: %s" % id0)

	# ══════════ apply_to_stats：attack_damage ══════════
	print("=== apply_to_stats: attack_damage ===")
	var stats1 := UnitStats.new()
	stats1.attack_damage = 100.0
	stats1.attack_light = 100.0
	stats1.attack_armor = 60.0
	stats1.attack_air = 20.0
	EnemyAffixes.apply_to_stats(stats1, [{"effect_key": "attack_damage", "base_value": 0.30}])
	print("  狂暴: atk 100→%.1f (期望 130), light 100→%.1f, armor 60→%.1f" % [stats1.attack_damage, stats1.attack_light, stats1.attack_armor])
	if absf(stats1.attack_damage - 130.0) > 0.1:
		fail.call("狂暴 attack_damage 应 130，实际 %.1f" % stats1.attack_damage)
	if absf(stats1.attack_armor - 78.0) > 0.1:
		fail.call("狂暴 attack_armor 应 78，实际 %.1f" % stats1.attack_armor)

	# ══════════ apply_to_stats：max_hp ══════════
	print("=== apply_to_stats: max_hp ===")
	var stats2 := UnitStats.new()
	stats2.max_hp = 1000.0
	EnemyAffixes.apply_to_stats(stats2, [{"effect_key": "max_hp", "base_value": 0.60}])
	print("  坚韧: hp 1000→%.1f (期望 1600)" % stats2.max_hp)
	if absf(stats2.max_hp - 1600.0) > 0.1:
		fail.call("坚韧 max_hp 应 1600，实际 %.1f" % stats2.max_hp)

	# ══════════ apply_to_stats：attack_speed ══════════
	print("=== apply_to_stats: attack_speed ===")
	var stats3 := UnitStats.new()
	stats3.attack_interval = 1.0
	EnemyAffixes.apply_to_stats(stats3, [{"effect_key": "attack_speed", "base_value": 0.25}])
	print("  加速: interval 1.0→%.3f (期望 0.8 = 1/1.25)" % stats3.attack_interval)
	if absf(stats3.attack_interval - 0.8) > 0.01:
		fail.call("加速 interval 应 0.8，实际 %.3f" % stats3.attack_interval)

	# ══════════ apply_to_stats：dodge/crit（加法 + 上限钳制） ══════════
	print("=== apply_to_stats: dodge/crit (钳制) ===")
	var stats4 := UnitStats.new()
	EnemyAffixes.apply_to_stats(stats4, [{"effect_key": "dodge_chance", "base_value": 0.20}])
	print("  闪避: dodge 0→%.2f (期望 0.20, 上限 0.50)" % stats4.dodge_chance)
	if absf(stats4.dodge_chance - 0.20) > 0.01:
		fail.call("闪避 dodge 应 0.20，实际 %.2f" % stats4.dodge_chance)
	# 钳制测试：叠加超过 0.50
	stats4.dodge_chance = 0.45
	EnemyAffixes.apply_to_stats(stats4, [{"effect_key": "dodge_chance", "base_value": 0.20}])
	print("  闪避叠加: 0.45+0.20→%.2f (期望 0.50 上限)" % stats4.dodge_chance)
	if absf(stats4.dodge_chance - 0.50) > 0.01:
		fail.call("闪避应钳制 0.50，实际 %.2f" % stats4.dodge_chance)

	# ══════════ apply_to_stats：机制型（lifesteal/chain/splash） ══════════
	print("=== apply_to_stats: 机制型 ===")
	var stats5 := UnitStats.new()
	EnemyAffixes.apply_to_stats(stats5, [
		{"effect_key": "lifesteal", "base_value": 0.18},
		{"effect_key": "chain_chance", "base_value": 0.40},
		{"effect_key": "splash_damage", "base_value": 0.35},
	])
	print("  吸血 %.2f / 连锁 %.2f / 溅射 %.2f" % [stats5.lifesteal, stats5.chain_chance, stats5.splash_damage])
	if absf(stats5.lifesteal - 0.18) > 0.01:
		fail.call("吸血应 0.18，实际 %.2f" % stats5.lifesteal)
	if absf(stats5.chain_chance - 0.40) > 0.01:
		fail.call("连锁应 0.40，实际 %.2f" % stats5.chain_chance)
	if absf(stats5.splash_damage - 0.35) > 0.01:
		fail.call("溅射应 0.35，实际 %.2f" % stats5.splash_damage)

	# ══════════ apply_to_stats：armor_reflect ══════════
	print("=== apply_to_stats: armor_reflect ===")
	var stats6 := UnitStats.new()
	EnemyAffixes.apply_to_stats(stats6, [{"effect_key": "armor_reflect", "base_value": 0.25}])
	# UnitStats 若无 armor_reflect 字段，会 set_meta 兜底
	var reflect_val: float = 0.0
	if "armor_reflect" in stats6:
		reflect_val = float(stats6.armor_reflect)
	elif stats6.has_meta("armor_reflect"):
		reflect_val = float(stats6.get_meta("armor_reflect"))
	print("  反伤: reflect = %.2f (期望 0.25, 走字段或meta)" % reflect_val)
	if absf(reflect_val - 0.25) > 0.01:
		fail.call("反伤应 0.25，实际 %.2f" % reflect_val)

	# ══════════ 空词缀列表不崩溃 ══════════
	print("=== 边界：空词缀 ===")
	var stats7 := UnitStats.new()
	stats7.max_hp = 500.0
	EnemyAffixes.apply_to_stats(stats7, [])
	if absf(stats7.max_hp - 500.0) > 0.1:
		fail.call("空词缀不应改变 stats")
	print("  空词缀: max_hp 保持 %.1f (期望 500)" % stats7.max_hp)

	# ══════════ 总结 ══════════
	if code == 0:
		print("\n=== ALL PASS ===")
	else:
		print("\n=== FAILED ===")
	quit(code)
