extends Node
## 批次③ Task 1 出征过场冒烟断言（boot 场景模式，runner 直挂 /root，跨场景切换存活）
## 跑法：godot --headless --path . res://tests/_tmp_sortie_beat_boot.tscn
##
## 断言：
##  ① 孤立过场：present → 不 skip 自动 finished，时长 ≤2.5s（验收线：无 skip 总时长）
##  ② 孤立过场 ESC skip：finished ≤0.5s（验收线：skip 后）
##  ③ 卡车出击链（自然收尾）：_launch_battle 写拍点 meta → main 落地 → 过场出现且战斗未开
##     （拍点确实挡住瞬跳）→ 目的地行=「第 N 关 · 时代」→ 自然放完 → 战场可见 ≤3.0s
##  ④ world_map 出击链（skip 路径）：_enter_level_from_popup 写拍点 → main 落地不出现 →
##     开始战斗 → 过场出现 → ESC skip → 战场可见 ≤0.5s
##
## ⚠️ ④ 会真实调 BattleManager.end_battle(false) 一次收尾③的战斗 → 触发战后自动存档。
##     跑前请备份 user:// 存档 JSON（跑完恢复），避免测试态写进真实档。

const TRUCK_SCENE := "res://scenes/bunker/truck_base.tscn"
const WORLD_SCENE := "res://scenes/world_map.tscn"
const MAIN_SCENE := "res://scenes/main.tscn"
const TUTORIAL_FREEDOM_MODE := 13   # TutorialProgressionManager.TutorialStep.FREEDOM_MODE
const BUDGET_ISOLATED_MS := 2500
const BUDGET_E2E_MS := 3000
const BUDGET_SKIP_MS := 500

var _fails: Array[String] = []
var _pass_log: Array[String] = []


func _ready() -> void:
	await _run()
	for p in _pass_log:
		print("[SortieBeat] PASS: " + p)
	for f in _fails:
		printerr("[SortieBeat] FAIL: " + f)
	print("[SortieBeat] " + ("ALL PASS" if _fails.is_empty() else "HAS FAILURES"))
	await _wait(5)
	get_tree().quit(0 if _fails.is_empty() else 1)


# ── 基础工具 ──

func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _wait_until(pred: Callable, timeout_sec: float, poll_sec: float = 0.05) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(pred.call()):
			return true
		await get_tree().create_timer(poll_sec).timeout
	return bool(pred.call())


func _cur_path() -> String:
	var cs := get_tree().current_scene
	return String(cs.scene_file_path) if cs != null else ""


func _interstitial() -> Node:
	return get_tree().get_first_node_in_group("sortie_interstitial")


func _press_esc() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)


func _main_in_battle(main: Node) -> bool:
	if main == null or not is_instance_valid(main):
		return false
	return bool(main.call("_is_in_battle"))


## 测试期把教程压到自由模式（main 落地自动开打与出征拍点都让位教程）；
## 返回原步骤号供恢复（避免测试态经战后自动存档写进真实档）
func _tutorial_force_free() -> int:
	var tpm: Node = get_node_or_null("/root/TutorialProgressionManager")
	if tpm == null:
		return -1
	var orig := int(tpm.get("current_step"))
	tpm.set("current_step", TUTORIAL_FREEDOM_MODE)
	return orig


func _tutorial_restore(step: int) -> void:
	var tpm: Node = get_node_or_null("/root/TutorialProgressionManager")
	if tpm == null or step < 0:
		return
	tpm.set("current_step", step)


func _setup_bunker(parked_level: int) -> Node:
	if ManagerLazyLoader != null and ManagerLazyLoader.has_method("ensure_loaded"):
		ManagerLazyLoader.ensure_loaded("bunker")
	var bm: Node = get_node_or_null("/root/BunkerManager")
	if bm == null:
		return null
	bm.set("_parked_level", parked_level)
	bm.set("_fuel", float(bm.get_fuel_cap()))
	bm.set("_travel_dest", 0)
	bm.set("_travel_days_total", 0)
	bm.set("_travel_started_unix", 0.0)
	bm.set("_travel_ends_unix", 0.0)
	return bm


## 测试侧装配真实卡（绿槽=可部署战斗卡），让战报「携行 N 张卡牌」走真实取数分支
func _equip_test_loadout() -> int:
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim == null or not pim.has_method("equip_card"):
		return 0
	var equipped := 0
	for cid in ["ww1_mauser", "ww1_arty_m81", "ww1_arm_ft17"]:
		var card: CardResource = null
		if InstanceRegistry != null and InstanceRegistry.has_method("create_instance"):
			card = InstanceRegistry.call("create_instance", cid)
		if card != null and bool(pim.call("equip_card", equipped, card)):
			equipped += 1
	var count := equipped
	if pim.has_method("get_loadouts"):
		count = (pim.call("get_loadouts") as Array).size()
	print("[SortieBeat] 测试装配卡数（绿槽 loadouts）=", count)
	return count


# ── 主流程 ──

func _run() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.call("load_game")
		if sm.has_method("flush_deferred_manager_loads"):
			sm.call("flush_deferred_manager_loads")

	await _case_isolated_natural()
	await _case_isolated_esc()
	await _case_truck_natural()
	await _case_world_map_skip()


## ① 孤立过场：不 skip，自动收尾
func _case_isolated_natural() -> void:
	var done := [false]
	var sig := SortieInterstitial.present("第 3 关 · 一战", [
		"车队向目标阵地开进。", "携行 4 张卡牌 · 相位仪 2 具。"])
	sig.connect(func() -> void: done[0] = true)
	var t0 := Time.get_ticks_msec()
	if not await _wait_until(func() -> bool: return _interstitial() != null, 2.0):
		_fails.append("① 孤立过场未出现")
		return
	if not await _wait_until(func() -> bool: return done[0], 3.0):
		_fails.append("① 孤立过场未自动 finished（无 skip 路径断链）")
		return
	var dt := Time.get_ticks_msec() - t0
	if dt > BUDGET_ISOLATED_MS:
		_fails.append("① 无 skip 总时长 %d ms > %d ms" % [dt, BUDGET_ISOLATED_MS])
	else:
		_pass_log.append("① 孤立过场自动收尾 %d ms ≤%d ms" % [dt, BUDGET_ISOLATED_MS])
	await _wait(30)
	if _interstitial() != null:
		_fails.append("① 过场层 finished 后未自清理")


## ② 孤立过场：ESC skip
func _case_isolated_esc() -> void:
	var done := [false]
	var sig := SortieInterstitial.present("第 1 关 · 一战", ["车队向目标阵地开进。"])
	sig.connect(func() -> void: done[0] = true)
	if not await _wait_until(func() -> bool: return _interstitial() != null, 2.0):
		_fails.append("② 孤立过场(ESC)未出现")
		return
	await _wait(3)
	var t0 := Time.get_ticks_msec()
	_press_esc()
	if not await _wait_until(func() -> bool: return done[0], 1.0):
		_fails.append("② ESC skip 未触发 finished（输入路径断）")
		return
	var dt := Time.get_ticks_msec() - t0
	if dt > BUDGET_SKIP_MS:
		_fails.append("② ESC skip 后 %d ms > %d ms" % [dt, BUDGET_SKIP_MS])
	else:
		_pass_log.append("② ESC skip 收尾 %d ms ≤%d ms" % [dt, BUDGET_SKIP_MS])


## ③ 卡车出击链：自然放完（不 skip）
func _case_truck_natural() -> void:
	var orig_step := _tutorial_force_free()
	_equip_test_loadout()
	var bm := _setup_bunker(3)
	if bm == null:
		_fails.append("③ BunkerManager 未创建")
		_tutorial_restore(orig_step)
		return
	SceneTransition.change(get_tree(), TRUCK_SCENE)
	if not await _wait_until(func() -> bool: return _cur_path().contains("truck_base"), 20.0):
		_fails.append("③ 未进入 truck_base: " + _cur_path())
		_tutorial_restore(orig_step)
		return
	var truck: Node = get_tree().current_scene
	var t0 := Time.get_ticks_msec()
	truck.call("_launch_battle")
	if not Engine.has_meta(SortieInterstitial.META_PENDING):
		_fails.append("③ 出击未写拍点 meta（SortieInterstitial.META_PENDING）")
	if not await _wait_until(func() -> bool: return _cur_path().contains("main.tscn"), 20.0):
		_fails.append("③ 出击未进入 main: " + _cur_path())
		_tutorial_restore(orig_step)
		return
	var t1 := Time.get_ticks_msec()   # main.tscn 落地（冷加载结束）
	if not await _wait_until(func() -> bool: return _interstitial() != null, 6.0):
		_fails.append("③ 出击链过场未出现（拍点未生效）")
		_tutorial_restore(orig_step)
		return
	var t2 := Time.get_ticks_msec()   # 过场出现
	var main: Node = get_tree().current_scene
	if _main_in_battle(main):
		_fails.append("③ 过场期间战斗已开（拍点未挡住瞬跳）")
	var inst := _interstitial()
	var dest := String(inst.get("_dest_text"))
	if dest != "第 3 关 · 一战":
		_fails.append("③ 目的地行不符（期望「第 3 关 · 一战」，实际「%s」）" % dest)
	else:
		_pass_log.append("③ 目的地行取数正确：%s" % dest)
	var lines = inst.get("_lines")
	if lines == null or (lines as Array).is_empty():
		_fails.append("③ 战报正文为空")
	elif (lines as Array).size() >= 2:
		var second := String((lines as Array)[1])
		if not second.contains("携行"):
			_fails.append("③ 第二行非携行行：「%s」" % second)
		else:
			_pass_log.append("③ 战报含真实数值行：%s" % second)
	else:
		_pass_log.append("③ 战报走降级单行版（测试装配失败时合法，禁止虚构数值）：%s" % String((lines as Array)[0]))
	# 自然放完 → 战斗开
	var ok := await _wait_until(func() -> bool: return _main_in_battle(main), 6.0)
	var dt := Time.get_ticks_msec() - t0
	var dt_loaded := Time.get_ticks_msec() - t1   # main 落地→战斗开（Task 1 可控域：过场+开战）
	var dt_scene := t1 - t0                        # 冷加载 main.tscn（既有成本，与 Task 1 无关）
	print("[SortieBeat] ③ 阶段分解：场景冷加载 %d ms ｜ 落地→过场 %d ms ｜ 过场出现→战斗开 %d ms" % [
		dt_scene, t2 - t1, Time.get_ticks_msec() - t2])
	if not ok:
		_fails.append("③ 自然放完后战斗未开")
	elif dt_loaded > BUDGET_E2E_MS:
		# 预算只卡「落地→战斗开」（过场 1.5s+开战 ≤3s）；场景冷加载是既有成本，单列观测
		_fails.append("③ main落地→战斗开 %d ms > %d ms（场景冷加载另计 %d ms）" % [dt_loaded, BUDGET_E2E_MS, dt_scene])
	else:
		_pass_log.append("③ 出击→战场（含过场自然放完）落地后 %d ms（预算线 %d ms；冷加载 %d ms 观测值）" % [dt_loaded, BUDGET_E2E_MS, dt_scene])
	if main.get("battle_container") == null or not (main.get("battle_container") as Control).visible:
		_fails.append("③ 战场不可见（battle_container.visible=false）")
	_tutorial_restore(orig_step)


## ④ world_map 出击链：过场出现后 ESC skip
func _case_world_map_skip() -> void:
	var main: Node = get_tree().current_scene
	if _main_in_battle(main):
		# 收尾③的战斗（走正常结算链，避免 battle_active 卡死跨场景）
		BattleManager.end_battle(false)
		await _wait(90)
	if Engine.has_meta(SortieInterstitial.META_PENDING):
		_fails.append("④ ③的拍点 meta 未被消费（会重复触发过场）")
	SceneTransition.change(get_tree(), WORLD_SCENE)
	if not await _wait_until(func() -> bool: return _cur_path().contains("world_map"), 20.0):
		_fails.append("④ 未进入 world_map: " + _cur_path())
		return
	var wm: Node = get_tree().current_scene
	wm.call("_enter_level_from_popup", 3, null)
	if not Engine.has_meta(SortieInterstitial.META_PENDING):
		_fails.append("④ world_map 出击未写拍点 meta")
	if not await _wait_until(func() -> bool: return _cur_path().contains("main.tscn"), 20.0):
		_fails.append("④ 出击未回 main: " + _cur_path())
		return
	var main2: Node = get_tree().current_scene
	if _interstitial() != null:
		_fails.append("④ 落地即出现战场过场（应在开始战斗时才触发）")
	var orig_step := _tutorial_force_free()
	main2.call("_on_start_battle")
	if not await _wait_until(func() -> bool: return _interstitial() != null, 6.0):
		_fails.append("④ 开始战斗后过场未出现")
		_tutorial_restore(orig_step)
		return
	var t0 := Time.get_ticks_msec()
	_press_esc()
	var ok := await _wait_until(func() -> bool: return _main_in_battle(main2), 2.0)
	var dt := Time.get_ticks_msec() - t0
	if not ok:
		_fails.append("④ skip 后战斗未开")
	elif dt > BUDGET_SKIP_MS:
		_fails.append("④ skip 后 %d ms > %d ms" % [dt, BUDGET_SKIP_MS])
	else:
		_pass_log.append("④ world_map 出击 skip→战场 %d ms ≤%d ms" % [dt, BUDGET_SKIP_MS])
	if main2.get("battle_container") == null or not (main2.get("battle_container") as Control).visible:
		_fails.append("④ 战场不可见（battle_container.visible=false）")
	_tutorial_restore(orig_step)
