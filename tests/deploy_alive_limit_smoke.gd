# v20.11 规则冒烟：相位仪每卡限 1 个在场（上限 = equipped_count × phantom 倍率）
# 无 GdUnit 依赖，桩仪器 + 假单位节点直接驱动 _reach_alive_limit_for_card。
# 注意：battle_spawn_system.gd 引用 autoload 名（BattleManager 等），--script 模式早期 preload
# 会在 autoload 注册前编译而报 Identifier not found——必须在 _initialize 内运行时 load()。
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/deploy_alive_limit_smoke.gd
extends SceneTree

const BASE_ID := "ww1_arm_ft17"

var BSS: Script
var DC: Script


class StubInstrument extends Node:
	var loadouts: Array = []
	var ability: Dictionary = {}

	func get_loadouts() -> Array:
		return loadouts

	func get_active_ability() -> Dictionary:
		return ability


class FakeUnit extends Node2D:
	var _is_dying: bool = false


func _initialize() -> void:
	var errs: Array[String] = []
	BSS = load("res://managers/battle/battle_spawn_system.gd")
	DC = load("res://data/default_cards.gd")
	if BSS == null or DC == null:
		_fail(errs, "脚本加载失败 BSS=%s DC=%s" % [BSS != null, DC != null])
		_finish(errs)
		return
	var bss = BSS.new()
	var instr := StubInstrument.new()
	var units_root := Node2D.new()
	root.add_child(instr)
	root.add_child(units_root)
	bss._phase_instrument = instr
	bss._player_units_node = units_root

	if DC.get_card_by_id(BASE_ID) == null:
		_fail(errs, "模板卡 %s 不存在，换一张存在的卡再跑" % BASE_ID)
		_finish(errs)
		return

	# ── 用例组 ──
	_check(errs, bss, "0装备+0在场 → 放行", {}, [], false)
	_check(errs, bss, "1装备+0在场 → 放行", {"equip": 1}, [], false)
	_check(errs, bss, "1装备+1在场 → 拦截（每卡限1核心用例）", {"equip": 1}, [false], true)
	_check(errs, bss, "2装备(同名两槽)+1在场 → 放行（每槽各1）", {"equip": 2}, [false], false)
	_check(errs, bss, "2装备+2在场 → 拦截", {"equip": 2}, [false, false], true)
	_check(errs, bss, "1装备+1死亡淡出中 → 放行（dying 不计存活）", {"equip": 1}, [true], false)
	# phantom_clone ×2：能力语义"同卡可放2个"
	var phantom := {"id": "phantom_clone", "params": {"deploy_count": 2}}
	_check(errs, bss, "幻影×2：1装备+1在场 → 放行（克隆名额）", {"equip": 1, "ability": phantom}, [false], false)
	_check(errs, bss, "幻影×2：1装备+2在场 → 拦截", {"equip": 1, "ability": phantom}, [false, false], true)

	_finish(errs)


## cfg: equip=装备槽数, ability=get_active_ability 返回值；dying_flags: 每个在场单位是否 _is_dying
func _check(errs: Array[String], bss, label: String, cfg: Dictionary, dying_flags: Array, expect_block: bool) -> void:
	var instr: StubInstrument = bss._phase_instrument
	var units_root: Node2D = bss._player_units_node
	for c in units_root.get_children():
		units_root.remove_child(c)
		c.queue_free()
	instr.loadouts.clear()
	for i in range(int(cfg.get("equip", 0))):
		instr.loadouts.append({"platform": DC.get_card_by_id(BASE_ID), "slot_index": i})
	instr.ability = cfg.get("ability", {})
	for dying in dying_flags:
		var u := FakeUnit.new()
		u.set_meta("source_card_id", BASE_ID)
		u._is_dying = dying
		units_root.add_child(u)
	var blocked: bool = bss._reach_alive_limit_for_card(BASE_ID, BASE_ID + "#1")
	print("  %s → %s" % [label, "拦截" if blocked else "放行"])
	if blocked != expect_block:
		_fail(errs, label)


func _fail(errs: Array[String], msg: String) -> void:
	errs.append(msg)


func _finish(errs: Array[String]) -> void:
	if errs.is_empty():
		print("")
		print("=== deploy_alive_limit_smoke: ALL PASS（v20.11 每卡限1 × 幻影倍率）===")
	else:
		print("")
		print("❌ deploy_alive_limit_smoke: FAILED (%d)" % errs.size())
		for e in errs:
			push_error(e)
			print("  - ", e)
	quit(0 if errs.is_empty() else 1)
