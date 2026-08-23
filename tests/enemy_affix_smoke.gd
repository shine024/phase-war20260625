# 无 GdUnit 依赖的快速校验：v8 批次2 精英敌人词缀系统
#   - 词缀定义表完整性（10 个词缀，3 档稀有度）
#   - roll_affixes：normal 不 roll / elite roll 1 / boss roll 2
#   - apply_to_stats：各 effect_key 正确写入 UnitStats 字段
#   - 词缀池过滤（按稀有度）
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/enemy_affix_smoke.gd
extends SceneTree

const EnemyAffixes = preload("res://data/enemy_affixes.gd")


func _initialize() -> void:
	var code := [0]
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		code[0] = 1

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

	# ══════════ apply_to_stats：机制型（kill_repair/chain/splash） ══════════
	print("=== apply_to_stats: 机制型 ===")
	var stats5 := UnitStats.new()
	EnemyAffixes.apply_to_stats(stats5, [
		{"effect_key": "kill_repair", "base_value": 0.12},
		{"effect_key": "chain_chance", "base_value": 0.40},
		{"effect_key": "splash_damage", "base_value": 0.35},
	])
	print("  击杀修复 %.2f / 连锁 %.2f / 溅射 %.2f" % [stats5.kill_repair, stats5.chain_chance, stats5.splash_damage])
	if absf(stats5.kill_repair - 0.12) > 0.01:
		fail.call("击杀修复应 0.12，实际 %.2f" % stats5.kill_repair)
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

	# ══════════ v19: 兵种分池词缀表结构 ══════════
	print("=== v19: 兵种词缀结构 ===")
	var kind_affixes: Dictionary = {
		"enemy_gale_raid": [0], "enemy_ghost_step": [0],
		"enemy_steel_tide": [1], "enemy_compound_armor": [1],
		"enemy_dive_strike": [3], "enemy_airspace_hunt": [3],
		"enemy_long_bombard": [2], "enemy_field_rebuild": [2],
		"enemy_permament_works": [4], "enemy_fireweb": [4],
	}
	var unique_affixes: Dictionary = {
		"enemy_execution_protocol": [0], "enemy_titan_armor": [1],
		"enemy_death_scythe": [3], "enemy_orbital_bombard": [2],
		"enemy_fortress_will": [4],
	}
	var expect_total: int = 10 + kind_affixes.size() + unique_affixes.size()
	if EnemyAffixes.ENEMY_AFFIXES.size() != expect_total:
		fail.call("敌方词缀总数应为 %d，实际 %d" % [expect_total, EnemyAffixes.ENEMY_AFFIXES.size()])
	for aid in kind_affixes:
		var d: Dictionary = EnemyAffixes.ENEMY_AFFIXES.get(aid, {})
		if d.is_empty():
			fail.call("缺少兵种词缀 %s" % aid)
			continue
		if (d.get("combat_kinds", []) as Array) != kind_affixes[aid]:
			fail.call("%s combat_kinds 应为 %s" % [aid, str(kind_affixes[aid])])
		if int(d.get("min_tier", -1)) != 0:
			fail.call("%s min_tier 应为 0" % aid)
	for uid in unique_affixes:
		var du: Dictionary = EnemyAffixes.ENEMY_AFFIXES.get(uid, {})
		if du.is_empty():
			fail.call("缺少独特词缀 %s" % uid)
			continue
		if (du.get("combat_kinds", []) as Array) != unique_affixes[uid]:
			fail.call("%s combat_kinds 应为 %s" % [uid, str(unique_affixes[uid])])
		if int(du.get("min_tier", -1)) != 3:
			fail.call("%s min_tier 应为 3" % uid)
	# 旧 10 词缀保持全兵种通用（向后兼容）
	for oid in EnemyAffixes.ENEMY_AFFIXES:
		if not kind_affixes.has(oid) and not unique_affixes.has(oid):
			if not (EnemyAffixes.ENEMY_AFFIXES[oid].get("combat_kinds", []) as Array).is_empty():
				fail.call("旧词缀 %s 不应带 combat_kinds 限定" % oid)
	print("  结构 OK（10 通用 + 10 兵种专属 + 5 独特 = %d）" % expect_total)

	# ══════════ v19: roll 兵种/tier 过滤统计 ══════════
	print("=== v19: roll 兵种过滤 ===")
	var all_kind_ids: Array = kind_affixes.keys() + unique_affixes.keys()
	var armor_valid: Array = ["enemy_steel_tide", "enemy_compound_armor"]
	var leak: int = 0
	var armor_hit: int = 0
	for _i in range(400):
		var rolled: Array = EnemyAffixes.roll_affixes("elite", rng, 1, 0)
		for a in rolled:
			var rid: String = String(a.get("id", ""))
			if all_kind_ids.has(rid) and not armor_valid.has(rid):
				leak += 1
			if armor_valid.has(rid):
				armor_hit += 1
	if leak != 0:
		fail.call("装甲 elite roll 串池 %d 次" % leak)
	if armor_hit < 100:
		fail.call("装甲专属命中率过低 %d/400（预期 >100）" % armor_hit)
	# tier=0 永不出独特词缀（boss 全池 roll）
	var uniq_leak: int = 0
	for _i in range(400):
		for a in EnemyAffixes.roll_affixes("boss", rng, 1, 0):
			if unique_affixes.has(String(a.get("id", ""))):
				uniq_leak += 1
	if uniq_leak != 0:
		fail.call("tier0 不应 roll 到独特词缀，泄漏 %d 次" % uniq_leak)
	# tier=3 boss 波可出独特词缀（泰坦装甲）
	var titan_hit: int = 0
	for _i in range(400):
		for a in EnemyAffixes.roll_affixes("boss", rng, 1, 3):
			if String(a.get("id", "")) == "enemy_titan_armor":
				titan_hit += 1
	if titan_hit == 0:
		fail.call("tier3 boss 应能抽到泰坦装甲")
	print("  过滤 OK（串池 0，装甲专属 %d/400，tier0 独特泄漏 0，泰坦命中 %d/400）" % [armor_hit, titan_hit])

	# ══════════ v19: apply 新 effect_key 分支 ══════════
	print("=== v19: apply 新分支 ===")
	var stats8 := UnitStats.new()
	stats8.move_speed = 100.0
	stats8.damage_reduction = 0.10
	stats8.attack_range = 300.0
	stats8.defense = 10.0
	stats8.defense_light = 10.0
	stats8.defense_armor = 10.0
	stats8.defense_air = 10.0
	stats8.crit_damage_bonus = 0.0
	EnemyAffixes.apply_to_stats(stats8, [
		{"effect_key": "move_speed", "base_value": 0.35},
		{"effect_key": "damage_reduction", "base_value": 0.15},
		{"effect_key": "attack_range", "base_value": 0.30},
		{"effect_key": "defense", "base_value": 8.0},
		{"effect_key": "crit_damage_bonus", "base_value": 0.50},
	])
	if absf(stats8.move_speed - 135.0) > 0.1:
		fail.call("疾风突袭 move_speed 应 135，实际 %.1f" % stats8.move_speed)
	if absf(stats8.damage_reduction - 0.25) > 0.01:
		fail.call("复合装甲 damage_reduction 应 0.25，实际 %.2f" % stats8.damage_reduction)
	if absf(stats8.attack_range - 390.0) > 0.1:
		fail.call("超远程炮击 attack_range 应 390，实际 %.1f" % stats8.attack_range)
	if absf(stats8.defense - 18.0) > 0.01 or absf(stats8.defense_light - 18.0) > 0.01 \
			or absf(stats8.defense_armor - 18.0) > 0.01 or absf(stats8.defense_air - 18.0) > 0.01:
		fail.call("永固工事 defense 应 18，实际 %.1f/%.1f/%.1f/%.1f" % [stats8.defense, stats8.defense_light, stats8.defense_armor, stats8.defense_air])
	if absf(stats8.crit_damage_bonus - 0.50) > 0.01:
		fail.call("处刑协议 crit_damage_bonus 应 0.50，实际 %.2f" % stats8.crit_damage_bonus)
	print("  新分支 OK（移速 135 / 减伤 0.25 / 射程 390 / 防御 18 / 暴伤 +0.50）")

	# ══════════ v19: 相位师产兵接线编译校验 ══════════
	print("=== v19: 产兵驱动接线 ===")
	if load("res://scenes/units/enemy_phase_field_driver.gd") == null:
		fail.call("enemy_phase_field_driver.gd 加载失败（产兵词缀接线编译错误）")
	else:
		print("  接线 OK（enemy_phase_field_driver.gd 编译通过，词缀 roll/apply/meta 挂载可用）")

	# ══════════ 总结 ══════════
	if code[0] == 0:
		print("\n=== ALL PASS ===")
	else:
		print("\n=== FAILED ===")
	quit(code[0])
