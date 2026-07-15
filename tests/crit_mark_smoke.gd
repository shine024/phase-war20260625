extends SceneTree
## 暴击标注系统（Crit Mark）smoke test
## 运行：/d/godot/Godot_v4.5.1-stable/Godot_v4.5.1-stable_win64_console.exe --headless --path "." --script "tests/crit_mark_smoke.gd"

const UnitStats = preload("res://resources/unit_stats.gd")
const ReconMods = preload("res://data/modification_modules/recon_mods.gd")
const ModRegistry = preload("res://scripts/systems/modification_registry.gd")

func _init():
	print("═══════════════════════════════════════════")
	print("  暴击标注系统 (Crit Mark) Smoke Test")
	print("═══════════════════════════════════════════")
	var all_pass: bool = true
	all_pass = _test_unit_stats_fields() and all_pass
	all_pass = _test_rec14_exists() and all_pass
	all_pass = _test_registry_mapping() and all_pass
	all_pass = _test_apply_crit_mark() and all_pass
	all_pass = _test_crit_mark_bonus_logic() and all_pass
	all_pass = _test_prioritize_crit_marked() and all_pass
	print("\n═══════════════════════════════════════════")
	if all_pass:
		print("  ✅ 全部 PASS")
	else:
		print("  ❌ 存在失败项")
	print("═══════════════════════════════════════════")
	quit(0 if all_pass else 1)

## 测试 1：UnitStats 暴击标注字段存在且默认值正确
func _test_unit_stats_fields() -> bool:
	print("\n[测试 1] UnitStats crit_mark 字段默认值")
	var stats = UnitStats.new()
	var ok: bool = true
	if stats.crit_mark_chance != 0.0:
		print("  ❌ crit_mark_chance 默认值=%f，期望 0.0" % stats.crit_mark_chance); ok = false
	if stats.crit_mark_duration != 5.0:
		print("  ❌ crit_mark_duration 默认值=%f，期望 5.0" % stats.crit_mark_duration); ok = false
	if stats.crit_mark_bonus != 0.50:
		print("  ❌ crit_mark_bonus 默认值=%f，期望 0.50" % stats.crit_mark_bonus); ok = false
	if ok:
		print("  ✅ chance=0.0 duration=5.0 bonus=0.50")
	print("  结果: %s" % ("PASS" if ok else "FAIL"))
	return ok

## 测试 2：rec_14_crit_designator 存在且 effects 正确
func _test_rec14_exists() -> bool:
	print("\n[测试 2] rec_14_crit_designator 数据")
	var cfg: Dictionary = ReconMods.get_mod_data("rec_14_crit_designator")
	if cfg.is_empty():
		print("  ❌ rec_14_crit_designator 未找到"); print("  结果: FAIL"); return false
	var fx: Dictionary = cfg.get("effects", {})
	var ok: bool = absf(float(fx.get("crit_mark_chance", -1.0)) - 0.30) < 0.001 \
		and absf(float(fx.get("crit_mark_bonus", -1.0)) - 0.50) < 0.001 \
		and absf(float(fx.get("crit_mark_duration", -1.0)) - 5.0) < 0.001
	if ok:
		print("  ✅ effects: chance=%.2f bonus=%.2f duration=%.1f" % [fx.crit_mark_chance, fx.crit_mark_bonus, fx.crit_mark_duration])
	else:
		print("  ❌ effects 不正确: %s" % fx)
	print("  结果: %s" % ("PASS" if ok else "FAIL"))
	return ok

## 测试 3：registry 把 crit_mark_chance effect 映射进结果
func _test_registry_mapping() -> bool:
	print("\n[测试 3] modification_registry crit_mark 映射")
	var base: Dictionary = {"crit_mark_chance": 0.0, "crit_mark_bonus": 0.0, "crit_mark_duration": 5.0}
	# 注：apply_with_level 按 id 查注册表取 effects（不从条目自身读 effects），
	# 故用 rec_14_crit_designator 触发 crit_mark_* 映射分支
	var mods: Array = [{"id": "rec_14_crit_designator"}]
	var result: Dictionary = ModRegistry.apply_with_level(base, mods)
	var ok: bool = absf(float(result.get("crit_mark_chance", -1.0)) - 0.30) < 0.001 \
		and absf(float(result.get("crit_mark_bonus", -1.0)) - 0.50) < 0.001 \
		and absf(float(result.get("crit_mark_duration", -1.0)) - 5.0) < 0.001
	if ok:
		print("  ✅ 映射后 chance=%.2f bonus=%.2f duration=%.1f" % [result.crit_mark_chance, result.crit_mark_bonus, result.crit_mark_duration])
	else:
		print("  ❌ 映射失败: %s" % result)
	print("  结果: %s" % ("PASS" if ok else "FAIL"))
	return ok

## 测试 4：_apply_crit_mark 给目标挂 meta（chance=1.0 强制触发）
func _test_apply_crit_mark() -> bool:
	print("\n[测试 4] _apply_crit_mark 施加 meta")
	var MEH = preload("res://scripts/battle/module_effect_handler.gd")
	var stats = UnitStats.new()
	stats.crit_mark_chance = 1.0   # 强制触发
	stats.crit_mark_duration = 5.0
	stats.crit_mark_bonus = 0.50
	var target = Node2D.new()
	var ok: bool = false
	# chance=1.0 → 必挂 meta
	MEH._apply_crit_mark(target, stats)
	if target.has_meta("_crit_marked_until") and target.has_meta("_crit_mark_bonus"):
		var bonus: float = float(target.get_meta("_crit_mark_bonus", 0.0))
		var expire: float = float(target.get_meta("_crit_marked_until", 0.0))
		var now: float = Time.get_ticks_msec() / 1000.0
		if absf(bonus - 0.50) < 0.001 and expire > now:
			print("  ✅ chance=1.0 → 挂 meta，bonus=0.50，expire>now")
			ok = true
		else:
			print("  ❌ meta 值异常 bonus=%.2f expire=%.2f now=%.2f" % [bonus, expire, now])
	else:
		print("  ❌ 未挂 meta")
	# chance=0.0 → 不挂
	stats.crit_mark_chance = 0.0
	target.remove_meta("_crit_marked_until"); target.remove_meta("_crit_mark_bonus")
	MEH._apply_crit_mark(target, stats)
	if not target.has_meta("_crit_marked_until"):
		print("  ✅ chance=0.0 → 不挂 meta")
	else:
		print("  ❌ chance=0.0 却挂了 meta"); ok = false
	target.free()
	print("  结果: %s" % ("PASS" if ok else "FAIL"))
	return ok

## 测试 6：_prioritize_crit_marked 远程优先选被标注目标
func _test_prioritize_crit_marked() -> bool:
	print("\n[测试 6] _prioritize_crit_marked 索敌优先")
	var TS = preload("res://scripts/battle/target_selection.gd")
	# mock attacker：远程（attack_range=300 >= 250）
	# plain Node2D 不支持 set("stats", ...)，需挂脚本定义 stats 属性
	var mock_script = GDScript.new()
	mock_script.source_code = "extends Node2D\nvar stats"
	mock_script.reload()
	var attacker = Node2D.new()
	attacker.set_script(mock_script)
	var stats = UnitStats.new()
	stats.attack_range = 300.0
	attacker.set("stats", stats)
	# 3 个 target：t1 带未过期 crit_mark，t2/t3 无
	var t1 = Node2D.new(); t1.set_meta("_crit_marked_until", Time.get_ticks_msec() / 1000.0 + 5.0)
	var t2 = Node2D.new()
	var t3 = Node2D.new()
	var enemies: Array = [t1, t2, t3]
	var ok: bool = true
	# 远程 attacker → 仅返回被标注的 t1
	var filtered_remote = TS._prioritize_crit_marked(attacker, enemies)
	if filtered_remote.size() == 1 and filtered_remote[0] == t1:
		print("  ✅ 远程(attack_range=300): 过滤出唯一被标注目标")
	else:
		print("  ❌ 远程过滤异常 size=%d" % filtered_remote.size()); ok = false
	# 近战 attacker（attack_range=100 < 250）→ 原样返回全部
	stats.attack_range = 100.0
	var filtered_melee = TS._prioritize_crit_marked(attacker, enemies)
	if filtered_melee.size() == 3:
		print("  ✅ 近战(attack_range=100): 原样返回 3 个")
	else:
		print("  ❌ 近战过滤异常 size=%d" % filtered_melee.size()); ok = false
	# 远程但无任何标注 → 原样返回
	stats.attack_range = 300.0
	t1.remove_meta("_crit_marked_until")
	var filtered_none = TS._prioritize_crit_marked(attacker, enemies)
	if filtered_none.size() == 3:
		print("  ✅ 远程但无标注: 原样返回 3 个")
	else:
		print("  ❌ 无标注过滤异常 size=%d" % filtered_none.size()); ok = false
	attacker.free(); t1.free(); t2.free(); t3.free()
	print("  结果: %s" % ("PASS" if ok else "FAIL"))
	return ok

## 测试 5：暴击标注加成判定逻辑（复刻 bullet.gd 的 effective_crit 叠加条件）
func _test_crit_mark_bonus_logic() -> bool:
	print("\n[测试 5] crit_mark 暴击加成判定")
	var target = Node2D.new()
	var ok: bool = true
	# 场景 A：未过期标注 → effective_crit += bonus
	var base_crit: float = 0.10
	var bonus: float = 0.50
	target.set_meta("_crit_marked_until", Time.get_ticks_msec() / 1000.0 + 5.0)
	target.set_meta("_crit_mark_bonus", bonus)
	var eff_a: float = base_crit
	if target.has_meta("_crit_marked_until") and Time.get_ticks_msec() / 1000.0 < float(target.get_meta("_crit_marked_until", 0.0)):
		eff_a += float(target.get_meta("_crit_mark_bonus", 0.0))
	if absf(eff_a - 0.60) > 0.001:
		print("  ❌ 未过期场景: effective=%.2f 期望 0.60" % eff_a); ok = false
	else:
		print("  ✅ 未过期标注: effective_crit 0.10 → %.2f" % eff_a)
	# 场景 B：过期标注 → 不加成
	target.set_meta("_crit_marked_until", Time.get_ticks_msec() / 1000.0 - 1.0)
	var eff_b: float = base_crit
	if target.has_meta("_crit_marked_until") and Time.get_ticks_msec() / 1000.0 < float(target.get_meta("_crit_marked_until", 0.0)):
		eff_b += float(target.get_meta("_crit_mark_bonus", 0.0))
	if absf(eff_b - 0.10) > 0.001:
		print("  ❌ 过期场景: effective=%.2f 期望 0.10" % eff_b); ok = false
	else:
		print("  ✅ 过期标注: effective_crit 保持 0.10")
	# 场景 C：无标注 → 不加成
	target.remove_meta("_crit_marked_until"); target.remove_meta("_crit_mark_bonus")
	var eff_c: float = base_crit
	if target.has_meta("_crit_marked_until") and Time.get_ticks_msec() / 1000.0 < float(target.get_meta("_crit_marked_until", 0.0)):
		eff_c += float(target.get_meta("_crit_mark_bonus", 0.0))
	if absf(eff_c - 0.10) > 0.001:
		print("  ❌ 无标注场景: effective=%.2f 期望 0.10" % eff_c); ok = false
	else:
		print("  ✅ 无标注: effective_crit 保持 0.10")
	target.free()
	print("  结果: %s" % ("PASS" if ok else "FAIL"))
	return ok
