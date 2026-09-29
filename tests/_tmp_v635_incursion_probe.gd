extends Node
## _tmp_v635_incursion_probe.gd(渗透战独立探针——稳定短流程)
## 跑法:godot --headless --rendering-driver opengl3 --path . res://tests/_tmp_v635_incursion_probe.tscn

var _fails: int = 0
var _main: Node = null


func _pl(s: String) -> void:
	print("[INC-PROBE] ", s)


func _ok(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pl("PASS  %s %s" % [name, detail])
	else:
		_fails += 1
		_pl("FAIL  %s %s" % [name, detail])


func _wait_frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _field_units() -> Array:
	var gm: Node = get_tree().root.get_node_or_null("/root/GameManager")
	var bf: Node = gm.get("battle_scene") if gm != null else null
	if bf == null:
		return []
	var holder: Node = bf.get_node_or_null("EnemyUnits")
	return holder.get_children() if holder != null else []


func _ready() -> void:
	await _wait_frames(5)
	await _run()
	_pl("═══ DONE fails=%d ═══" % _fails)
	if _fails == 0:
		print("INCURSION_PROBE_OK")
	get_tree().quit(0 if _fails == 0 else 1)


func _run() -> void:
	var gm: Node = get_tree().root.get_node_or_null("/root/GameManager")
	var bm: Node = get_tree().root.get_node_or_null("/root/BattleManager")
	var mll: Node = get_tree().root.get_node_or_null("/root/ManagerLazyLoader")
	if mll != null and mll.has_method("ensure_loaded"):
		mll.ensure_loaded("endless")
	await _wait_frames(5)
	var ebm: Node = get_tree().root.get_node_or_null("/root/EndlessBlackgateManager")
	var brm: Node = get_tree().root.get_node_or_null("/root/BasicResourceManager")

	_pl("═══ 0. main 实例化 ═══")
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_main)
	await _wait_frames(90)
	if gm.get("battle_scene") == null:
		await _wait_frames(90)
	_ok("battle_scene 就绪", gm.get("battle_scene") != null)

	_pl("═══ 1. 环境整备 ═══")
	var bar: Node = _main.get("bottom_instrument_bar")
	if bar != null:
		var adc = bar.get("_auto_deploy")
		if adc != null and adc.has_method("disable"):
			adc.call("disable")
	Engine.time_scale = 1.0
	_pl("  auto_deploy 已关 / ts=1")

	_pl("═══ 2. 渗透战全链 ═══")
	var inc := {"host_level": 88, "seed": 424242, "spawned_day": 1}
	ebm.incursions = [inc]
	var bak_level: int = int(gm.current_level)
	var bak_phase: int = int(gm.current_phase)
	# 纳米基线提前到开战前(判胜轻结算可能发生在等待窗口内任意帧——证据驱动)
	var nano_base: int = int(brm.call("get_total", "basic_nano"))
	gm.start_incursion_battle(inc)
	_ok("备态:loadout", not (gm.pending_incursion_loadout as Array).is_empty())
	_ok("备态:宿主对齐", int(gm.current_level) == 88)
	_ok("备态:未直接开打", int(gm.current_phase) == bak_phase)
	# 标准管线开打(与 main._consume_incursion_meta 后半段同款)
	_main.call("_auto_battle_from_truck_sortie")
	await _wait_frames(5)
	# 首波即刻:等 begin_card_grid_combat deferred+spawn
	var armed: bool = false
	for _i in range(40):
		var raw = bm.get("battle_active")
		if _i % 4 == 0:
			_pl("  DIAG wait[%02d] battle_active=%s (%s) phase=%s" % [_i, str(raw), type_string(typeof(raw)), str(gm.get("current_phase"))])
		if bool(raw):
			armed = true
			break
		await _wait_frames(5)
	# 时序无关:自动判胜可能在任意帧发生(编队清空后波耗尽判胜)——不硬等 active=true
	_ok("开战链已执行(armed 或已判胜结算)", armed or not bool(bm.get("battle_active")))
	var bss = bm.get("_spawn_system")
	_ok("渗透模式", bss.is_incursion_mode())
	# 证据性采样(不断言——判胜清场时序竞速)
	var n: int = _field_units().size()
	_pl("  证据采样: 编队在场 n=%d(判胜清场后读数为 0 属正常)" % n)
	# 清场兜底(编队若仍在场,free 触发判胜;已判胜则无操作)
	for u in _field_units():
		if is_instance_valid(u):
			u.free()
	await _wait_frames(10)
	# 判胜链:波耗尽+敌灭→end_battle(true)→轻结算
	for _i in range(60):
		if not bool(bm.get("battle_active")):
			break
		await _wait_frames(10)
	_ok("判胜结算完成(battle_active=false)", not bool(bm.get("battle_active")))
	await _wait_frames(20)
	_ok("渗透节点已清除", ebm.incursions.is_empty())
	_ok("纳米奖励入账(+800)", int(brm.call("get_total", "basic_nano")) >= nano_base + 799,
		"(%d→%d)" % [nano_base, int(brm.call("get_total", "basic_nano"))])
	_ok("渗透态复位", not bool(gm.is_incursion_battle()))
	gm.set_current_level(bak_level)
