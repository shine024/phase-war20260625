extends Node
## v27 黑门无限模式 — 真实战斗驱动测试（场景模式，autoload 全量）
## 跑法：godot --headless --rendering-driver opengl3 --path . res://tests/v27_endless_battle_driver.tscn
##
## 覆盖：
##   1. start_endless_battle → go_to_battle → 无尽开战（endless 开关/波次 HUD 口径/裂隙 override）
##   2. 波次构成：常规波全 xeno / 第 5 波精英 / 第 10 波首领
##   3. 单位机制：灵能护盾吸收 / 共感增益 / 死亡爆裂 / 拟时者回溯
##   4. 结算链：end_battle(false) → 分数/星髓/排行榜提交（best_waves 更新）

const XenoUnits = preload("res://data/xeno_units.gd")
const BattleEnvEffects = preload("res://data/battle_env_effects.gd")

var _log: Array = []
var _errs: Array[String] = []


func _ready() -> void:
	await _run()
	_report()
	get_tree().quit(0 if _errs.is_empty() else 1)


func _pl(s: String) -> void:
	_log.append(s)


func _fail(s: String) -> void:
	_errs.append(s)
	_pl("[FAIL] " + s)


func _ok(s: String) -> void:
	_pl("  ✓ " + s)


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _run() -> void:
	# ── 1. 主场景实例化 ──
	var main_packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if main_packed == null:
		_fail("main.tscn 加载失败")
		return
	var main: Node = main_packed.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait_frames(90)

	var gm: Node = get_tree().root.get_node_or_null("/root/GameManager")
	var bm: Node = get_tree().root.get_node_or_null("/root/BattleManager")
	if gm == null or bm == null:
		_fail("autoload 缺失 gm=%s bm=%s" % [gm != null, bm != null])
		return
	if gm.get("battle_scene") == null:
		await _wait_frames(90)
	if gm.get("battle_scene") == null:
		_fail("battle_scene 未就绪")
		return
	var bf: Node = gm.get("battle_scene")

	# ── 2. 无尽开战（真实链路：标记 → go_to_battle 消费 begin_run）──
	_pl("═══ 1. 无尽开战链路 ═══")
	gm.set_current_level(100)
	gm.start_endless_battle()
	if not bool(gm.call("is_endless_battle")):
		_fail("start_endless_battle 未置挂起标记")
	gm.go_to_battle()
	await _wait_frames(30)
	if not bool(bm.get("battle_active")):
		await _wait_frames(90)
	if not bool(bm.get("battle_active")):
		_fail("battle_active 未置位（无尽开战失败）")
		return
	var bss = bm.get("_spawn_system")
	if bss == null:
		_fail("_spawn_system 不可达")
		return
	if not bss.is_endless_mode():
		_fail("spawn 系统 endless 模式未开启")
	else:
		_ok("spawn 系统 endless 模式开启")
	if int(bm.get_enemy_wave_total()) != 0:
		_fail("HUD 口径波次总数应为 0（无尽无终波），实际 %d" % int(bm.get_enemy_wave_total()))
	else:
		_ok("HUD 口径波次总数=0（无进度点分支）")
	if BattleEnvEffects.get_rift_override().is_empty():
		_fail("裂隙环境 override 未置位（begin_run 未生效）")
	else:
		_ok("裂隙环境 override = %s" % BattleEnvEffects.get_rift_override())

	# ── 3. 波次构成 ──
	_pl("═══ 2. 波次构成 ═══")
	await _wait_sec(2.5)  # 首波部署（虚影期）
	var field_ids: Array = _alive_enemy_archetypes(bf)
	if field_ids.is_empty():
		await _wait_sec(3.0)
		field_ids = _alive_enemy_archetypes(bf)
	_pl("首波落场: %s" % str(field_ids))
	for aid in field_ids:
		if not String(aid).begins_with("xeno_"):
			_fail("无尽首波出现非星冥单位: %s" % aid)
	if not field_ids.is_empty():
		_ok("首波全部星冥（%d 个）" % field_ids.size())

	# 第 5 波：精英/王牌
	await _clear_field(bf, bss)
	bss.set("enemy_wave_index", 4)
	bss.spawn_card_grid_enemy_wave(100)
	await _wait_frames(3)
	var w5: Array = _alive_enemy_archetypes(bf)
	var w5_elite: bool = false
	for aid in w5:
		if String(aid) in XenoUnits.get_ids_for_role("elite") or String(aid) in XenoUnits.get_ids_for_role("ace"):
			w5_elite = true
	_pl("第 5 波: %s" % str(w5))
	if w5.is_empty():
		_fail("第 5 波未落场")
	elif w5_elite:
		_ok("第 5 波为精英/王牌构成")
	else:
		_fail("第 5 波无精英/王牌：%s" % str(w5))

	# 第 10 波：首领
	await _clear_field(bf, bss)
	bss.set("enemy_wave_index", 9)
	bss.spawn_card_grid_enemy_wave(100)
	await _wait_frames(3)
	var w10: Array = _alive_enemy_archetypes(bf)
	var w10_boss: bool = false
	for aid in w10:
		if String(aid) in XenoUnits.get_ids_for_role("boss"):
			w10_boss = true
	_pl("第 10 波: %s" % str(w10))
	if w10.is_empty():
		_fail("第 10 波未落场")
	elif w10_boss:
		_ok("第 10 波含首领")
	else:
		_fail("第 10 波无首领：%s" % str(w10))

	# ── 4. 单位机制 ──
	_pl("═══ 3. 星冥机制 ═══")
	await _test_psi_shield(bf, bss)
	await _test_communion(bf, bss)
	await _test_death_burst(bf, bss)
	await _test_mimic_rewind(bf, bss)

	# ── 5. 结算链 ──
	_pl("═══ 4. 结算链 ═══")
	bss.set("enemy_wave_index", 12)  # 拉到 12 波（星髓 20）
	bm.end_battle(false)
	await _wait_sec(2.0)
	var ebm: Node = get_tree().root.get_node_or_null("/root/EndlessBlackgateManager")
	if ebm == null:
		_fail("EndlessBlackgateManager 未加载")
	else:
		if int(ebm.get("best_waves")) < 10:
			_fail("best_waves=%d（应 ≥10，结算未跑或波次读取失败）" % int(ebm.get("best_waves")))
		else:
			_ok("best_waves=%d / best_score=%d" % [int(ebm.get("best_waves")), int(ebm.get("best_score"))])
		var brm: Node = get_tree().root.get_node_or_null("/root/BasicResourceManager")
		if brm != null and brm.has_method("get_total"):
			var marrow: int = int(brm.get_total("star_marrow"))
			if marrow < 20:
				_fail("星髓入账 %d（12 波里程碑应 ≥20）" % marrow)
			else:
				_ok("星髓入账 %d" % marrow)
		if bool(gm.call("is_endless_battle")):
			_fail("结算后 _is_endless_battle 未清除")
		else:
			_ok("结算后标记清除")
	if BattleEnvEffects.get_rift_override() != "":
		_fail("结算后裂隙 override 未清除")
	else:
		_ok("结算后裂隙 override 清除")


func _alive_enemy_archetypes(bf: Node) -> Array:
	var out: Array = []
	var eu: Node = bf.get_node_or_null("EnemyUnits")
	if eu == null:
		return out
	for c in eu.get_children():
		if c.get("archetype_id") != null and float(c.get("hp")) > 0.0:
			var aid: String = str(c.archetype_id)
			if not out.has(aid):
				out.append(aid)
	return out


func _clear_field(bf: Node, bss) -> void:
	var eu: Node = bf.get_node_or_null("EnemyUnits")
	if eu != null:
		for c in eu.get_children():
			c.queue_free()
	await _wait_frames(4)
	bss.sync_enemy_unit_count_from_field()


func _spawn_xeno_direct(bf: Node, bss, xid: String) -> Node:
	var unit: Node = bss.call("_create_enemy_unit_with_id", xid)
	if unit == null:
		return null
	bss.spawn_enemy_unit_on_card_grid(unit, -1)
	await _wait_frames(2)
	return unit


func _test_psi_shield(bf: Node, bss) -> void:
	var unit: Node = await _spawn_xeno_direct(bf, bss, "xeno_zealot")
	if unit == null:
		_fail("xeno_zealot 生成失败")
		return
	var shield_before: float = float(unit.get("_psi_shield"))
	var hp_before: float = float(unit.get("hp"))
	if shield_before <= 0.0:
		_fail("xeno_zealot 灵能护盾未初始化（_psi_shield=%.1f）" % shield_before)
		return
	unit.take_damage(shield_before * 0.5, null)
	var shield_after: float = float(unit.get("_psi_shield"))
	var hp_after: float = float(unit.get("hp"))
	if absf(hp_after - hp_before) > 0.01:
		_fail("盾未吸收：hp %.1f → %.1f（盾 %.1f → %.1f）" % [hp_before, hp_after, shield_before, shield_after])
	elif shield_after >= shield_before:
		_fail("盾值未下降 %.1f → %.1f" % [shield_before, shield_after])
	else:
		_ok("护盾吸收：盾 %.0f→%.0f，血 %.0f 不动" % [shield_before, shield_after, hp_before])
	# 盾延迟再生：未到 5s 不回，模拟时间到后回
	unit.take_damage(1.0, null)
	unit.set("_psi_shield_last_hit_msec", Time.get_ticks_msec() - 6000)
	unit.call("_update_psi_shield", 1.0)
	var shield_regen: float = float(unit.get("_psi_shield"))
	if shield_regen <= shield_after:
		_fail("护盾延迟再生未生效 %.1f → %.1f" % [shield_after, shield_regen])
	else:
		_ok("护盾延迟再生：%.0f → %.0f（+10%%/s）" % [shield_after, shield_regen])
	unit.queue_free()


func _test_communion(bf: Node, bss) -> void:
	var unit: Node = await _spawn_xeno_direct(bf, bss, "xeno_swarmling")
	if unit == null:
		_fail("xeno_swarmling 生成失败")
		return
	var atk_base: float = float(unit.get("attack_damage"))
	# 3 个共感节点桩（组计数读 hp/is_deploy_ghost 属性 + 组员身份）
	var stubs: Array = []
	for i in range(3):
		var s := GDScript.new()
		s.source_code = "extends Node2D\nvar hp := 100.0\nvar is_deploy_ghost := false\n"
		s.reload()
		var stub := Node2D.new()
		stub.set_script(s)
		bf.get_node("EnemyUnits").add_child(stub)
		stub.add_to_group("enemy_units")
		stub.add_to_group("xeno_communion_nodes")
		stubs.append(stub)
	unit.call("_update_communion", 0.6)  # 首采样 + 一次刷新
	var atk_boosted: float = float(unit.get("attack_damage"))
	var expect: float = atk_base * (1.0 + 0.08 * 3.0)
	if absf(atk_boosted - expect) > 0.5:
		_fail("共感增益 %.1f → %.1f（期望 %.1f = ×1.24）" % [atk_base, atk_boosted, expect])
	else:
		_ok("共感增益 ×1.24：%.0f → %.0f（3 节点）" % [atk_base, atk_boosted])
	# 节点全灭 → 增益回落
	for stub in stubs:
		stub.queue_free()
	await _wait_frames(3)
	unit.call("_update_communion", 0.6)
	var atk_fallback: float = float(unit.get("attack_damage"))
	if absf(atk_fallback - atk_base) > 0.5:
		_fail("节点清除后增益未回落 %.1f（期望回 %.1f）" % [atk_fallback, atk_base])
	else:
		_ok("节点清除 → 增益回落 %.0f" % atk_fallback)
	unit.queue_free()


func _test_death_burst(bf: Node, bss) -> void:
	var unit: Node = await _spawn_xeno_direct(bf, bss, "xeno_dragoon")
	if unit == null:
		_fail("xeno_dragoon 生成失败")
		return
	# 玩家单位桩（带 take_damage 记录）
	var s := GDScript.new()
	s.source_code = """
extends Node2D
var hp := 500.0
var is_deploy_ghost := false
var last_hit := 0.0
func take_damage(d, _a) -> void:
	last_hit = float(d)
	hp -= float(d)
"""
	s.reload()
	var victim := Node2D.new()
	victim.set_script(s)
	bf.get_node("PlayerUnits").add_child(victim)
	victim.add_to_group("player_units")
	victim.global_position = unit.global_position + Vector2(40, 0)
	unit.call("_die")
	await _wait_frames(2)
	if float(victim.get("last_hit")) <= 0.0:
		_fail("死亡爆裂未命中近旁玩家单位（last_hit=0）")
	else:
		_ok("死亡爆裂命中 %.0f 伤害" % float(victim.get("last_hit")))
	victim.queue_free()


func _test_mimic_rewind(bf: Node, bss) -> void:
	var unit: Node = await _spawn_xeno_direct(bf, bss, "xeno_mimic")
	if unit == null:
		_fail("xeno_mimic 生成失败")
		return
	var max_hp: float = float(unit.get("max_hp"))
	unit.set("hp", 1.0)
	unit.call("_die")
	await _wait_frames(2)
	var hp_after: float = float(unit.get("hp"))
	if absf(hp_after - max_hp * 0.5) > 1.0:
		_fail("拟时者回溯失败：hp=%.1f（期望 %.1f）" % [hp_after, max_hp * 0.5])
	else:
		_ok("拟时者回溯：1.0 → %.0f（半血复活）" % hp_after)
	# 第二次死亡应真死（每场一次）：hp 预置异值，若又触发回溯会被重置为半血
	unit.set("hp", 100.0)
	unit.call("_die")
	await _wait_frames(2)
	if not bool(unit.get("_is_dying")):
		_fail("第二次死亡未进入死亡锁（_is_dying=false）")
	elif absf(float(unit.get("hp")) - max_hp * 0.5) < 1.0:
		_fail("回溯触发了第二次（hp 被重置为半血 %.1f）" % float(unit.get("hp")))
	else:
		_ok("回溯仅一次：第二次死亡生效（hp=%.0f，死亡锁保持）" % float(unit.get("hp")))


func _report() -> void:
	print("".join([]))
	for l in _log:
		print(l)
	print("════════════════════════════")
	if _errs.is_empty():
		print("[v27] ENDLESS-DRIVER ALL PASS")
	else:
		for e in _errs:
			printerr("[v27] FAIL: " + e)
		printerr("[v27] ENDLESS-DRIVER %d FAILURES" % _errs.size())
