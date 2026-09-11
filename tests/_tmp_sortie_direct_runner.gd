extends Node
## v26.30 出击=进战场 E2E：
## ① 基地顶栏出击（_launch_battle）→ main.tscn + 战斗已开（on_start_battle 链）
##   + **未**自动弹战区地图（旧 v22.3 语义的回归锁）
## ② 行驶中出击被拦（提示卡，不切场景）
## 退出码非 0 = 有断言失败
##
## ⚠️ 教程门：main 落地自动开战分支有教程豁免（教程未完成不抢焦点，设计如此）——
## 本测试强制教程跳到 FREEDOM_MODE 再验链路；批次③ Task 1 后出击链含 ≤1.8s 出征
## 过场（可 skip），等待改条件等待不卡帧数。

const TUTORIAL_FREEDOM_MODE := 13   # TutorialProgressionManager.TutorialStep.FREEDOM_MODE

var _fails: Array[String] = []


func _ready() -> void:
	await _run()
	for f in _fails:
		printerr("[Sortie] FAIL: " + f)
	print("[Sortie] " + ("ALL PASS" if _fails.is_empty() else "HAS FAILURES"))
	get_tree().quit(0 if _fails.is_empty() else 1)


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


func _cur_path() -> String:
	var cs := get_tree().current_scene
	return String(cs.scene_file_path) if cs != null else ""


func _run() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.call("load_game")
		if sm.has_method("flush_deferred_manager_loads"):
			sm.call("flush_deferred_manager_loads")
	if ManagerLazyLoader != null and ManagerLazyLoader.has_method("ensure_loaded"):
		ManagerLazyLoader.ensure_loaded("bunker")
	var bm: Node = get_node_or_null("/root/BunkerManager")
	if bm == null:
		_fails.append("BunkerManager 未创建")
		return

	# ── A. 行驶中拦截：出击=提示卡，不切场景 ──
	SceneTransition.change(get_tree(), "res://scenes/bunker/truck_base.tscn")
	await _wait(50)
	if not _cur_path().contains("truck_base"):
		_fails.append("未进入 truck_base: " + _cur_path())
		return
	bm.set("_travel_dest", 5)
	bm.set("_travel_days_total", 1)
	bm.set("_travel_started_unix", Time.get_unix_time_from_system())
	bm.set("_travel_ends_unix", Time.get_unix_time_from_system() + 30.0)
	var truck: Node = get_tree().current_scene
	truck.call("_launch_battle")
	await _wait(20)
	if not _cur_path().contains("truck_base"):
		_fails.append("行驶中出击切走了场景（应提示不切）: " + _cur_path())
	else:
		print("[Sortie] A 行驶中拦截 OK（提示卡+留在基地）")
	bm.set("_travel_dest", 0)
	bm.set("_travel_days_total", 0)
	bm.set("_travel_started_unix", 0.0)
	bm.set("_travel_ends_unix", 0.0)

	# ── B. 停靠态出击：直达 main + 战斗自动开 + 不自动弹地图 ──
	var orig_step := _tutorial_force_free()
	bm.set("_parked_level", 1)
	bm.set("_fuel", float(bm.get_fuel_cap()))
	await _wait(5)
	truck.call("_launch_battle")
	if not _cur_path().contains("truck_base"):
		_fails.append("停靠态出击留在基地（应切场景）")
	if not await _wait_until(func() -> bool: return _cur_path().contains("main"), 20.0):
		_fails.append("出击未进入 main: " + _cur_path())
		_tutorial_restore(orig_step)
		return
	var main: Node = get_tree().current_scene
	# 批次③ Task 1 后：出击链含出征过场（≤1.8s）才开战，条件等待不卡帧数
	var in_battle: bool = await _wait_until(func() -> bool:
		return bool(main.call("_is_in_battle")) if main.has_method("_is_in_battle") else false,
		15.0)
	if not in_battle:
		_fails.append("出击落地后战斗未自动开始（on_start_battle 链断）")
	else:
		print("[Sortie] B 出击直达战斗 OK（in_battle=true）")
	# 回归锁：旧 v22.3 语义会在落地后自动弹战区地图（MapOverlay 可见）
	var overlay = main.get_node_or_null("PopupLayer/MapOverlay")
	var map_shown: bool = overlay != null and overlay.visible
	if map_shown:
		_fails.append("出击落地自动弹出了战区地图（旧 v22.3 语义回归）")
	else:
		print("[Sortie] B2 未自动弹地图 OK")
	if Engine.has_meta("launch_from_bunker"):
		print("[Sortie] launch_from_bunker meta 保留（供返回标题→回基地）")
	_tutorial_restore(orig_step)
