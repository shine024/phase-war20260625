extends SceneTree
## 可玩性检查配套（临时工具）：L1 战斗 60s 实测帧率/性能采样（opengl3 窗口模式跑）
## 口径：slot 3 QA 档 → 载档 → 挂 main → L1 开战 → 自动部署 → 每 2s 清敌+补驱动器血
##       （保活到采样结束，隔离"战斗提前结束"变量）→ 输出 avg/min/1% low FPS + 监视器摘要
## 退出码恒 0（性能数据只打印，不设门槛）

var _frames := 0
var _worst_sec_fps := 1e9
var _sec_frames := 0
var _sec_acc := 0.0
var _sec_count := 0
var _fps_series: Array[float] = []


func _initialize() -> void:
	_run()


func _frames_wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames_wait(2)
	print("[FpsProbe] boot")
	var sm: Node = root.get_node("/root/SaveManager")
	sm.call("set_slot", 3)
	var loaded: bool = sm.call("load_game")
	print("[FpsProbe] slot=3 load_game=", loaded)
	await _frames_wait(10)

	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _frames_wait(150)
	# 清离线奖励弹窗（同冒烟口径）
	var popup: Node = main.get("popup_layer")
	if popup != null:
		for c in popup.get_children():
			var sc: Script = c.get_script()
			if sc != null and "offline" in String(sc.resource_path):
				c.queue_free()

	var gm: Node = root.get_node("/root/GameManager")
	gm.call("set_current_level", 1)
	var setup: RefCounted = main.get("_battle_setup")
	setup.call("on_start_battle")
	await _frames_wait(45)
	var bm: Node = root.get_node("/root/BattleManager")
	var waited := 0
	while waited < 240:
		if "battle_active" in bm and bool(bm.get("battle_active")):
			break
		await _frames_wait(5)
		waited += 5
	var bar: Node = main.get("bottom_instrument_bar")
	var btn: Button = bar.get("_auto_deploy_btn") if bar != null else null
	if btn != null:
		btn.button_pressed = true
		btn.pressed.emit()
	print("[FpsProbe] battle active=", bool(bm.get("battle_active")), " auto-deploy ON")

	# ── 60s 采样：累计帧数 + 每秒窗口 FPS（取最小值为 worst，尾部 1% 近似 1% low）──
	var t_end: int = Time.get_ticks_msec() + 60_000
	var keep_acc := 0.0
	var first_ts := Time.get_ticks_msec()
	while Time.get_ticks_msec() < t_end:
		await process_frame
		_frames += 1
		var dt: float = root.get_process_delta_time()
		_sec_frames += 1
		_sec_acc += dt
		if _sec_acc >= 1.0:
			var sec_fps: float = float(_sec_frames) / _sec_acc
			_fps_series.append(sec_fps)
			_worst_sec_fps = min(_worst_sec_fps, sec_fps)
			_sec_frames = 0
			_sec_acc = 0.0
			_sec_count += 1
		# QA 保活
		keep_acc += dt
		if keep_acc >= 2.0:
			keep_acc = 0.0
			var bf: Node = gm.get("battle_scene")
			if bf != null and is_instance_valid(bf):
				var eu: Node = bf.get_node_or_null("EnemyUnits")
				if eu != null:
					for e in eu.get_children():
						if is_instance_valid(e):
							e.queue_free()
				var drv: Node = bf.get_node_or_null("PhaseFieldDriver")
				if drv != null and is_instance_valid(drv) and "hp" in drv:
					drv.set("hp", drv.get("max_hp"))

	var wall: float = (Time.get_ticks_msec() - first_ts) / 1000.0
	var avg_fps: float = _frames / wall
	_fps_series.sort()
	var low1: float = _fps_series[maxi(0, int(_fps_series.size() * 0.01))] if not _fps_series.is_empty() else 0.0
	var med: float = _fps_series[int(_fps_series.size() / 2.0)] if not _fps_series.is_empty() else 0.0
	print("[FpsProbe] wall=%.1fs frames=%d" % [wall, _frames])
	print("[FpsProbe] AVG=%.1f  MEDIAN=%.1f  WORST1s=%.1f  LOW1%%=%.1f" % [avg_fps, med, _worst_sec_fps, low1])
	var p := Performance
	print("[FpsProbe] draw_calls=%d objects=%d nodes=%d mem_static=%.1fMB video_mem=%.1fMB orphans=%d" % [
		p.get_monitor(p.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		p.get_monitor(p.OBJECT_COUNT), p.get_monitor(p.OBJECT_NODE_COUNT),
		p.get_monitor(p.MEMORY_STATIC) / 1048576.0,
		p.get_monitor(p.RENDER_VIDEO_MEM_USED) / 1048576.0,
		p.get_monitor(p.OBJECT_ORPHAN_NODE_COUNT)])
	quit(0)
