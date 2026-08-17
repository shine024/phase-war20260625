extends Node
## 尖峰示波器 v2：对照实验锁定非战斗空闲卡顿源
## A. 10s 基线（预热 8s 后再测）
## B. 10s 停用 HudLayer 全体处理（process_mode=DISABLED，渲染不变）
## C. 逐个停用 HudLayer 内 processing 子节点，各 6s
## 每阶段输出：fps / 平均帧耗 / >50ms 尖峰次数
## 运行：Godot_console.exe --rendering-driver opengl3 --path . res://tests/ui_spike_probe.tscn

const MAIN_SCENE := "res://scenes/main.tscn"
const WARMUP_SEC := 8.0
const PHASE_SEC := 10.0
const CHILD_PHASE_SEC := 6.0
const SPIKE_MS := 50.0

var _main: Node = null
var _boot_msec: int = 0
var _last_tick: int = 0
var _phase := "WARM"
var _phase_start: int = 0
var _frames: Array[float] = []
var _spikes: int = 0
var _cand_idx: int = 0
var _cands: Array = []

func _ready() -> void:
	_main = load(MAIN_SCENE).instantiate()
	_add_main.call_deferred()

func _add_main() -> void:
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_boot_msec = Time.get_ticks_msec()
	_last_tick = Time.get_ticks_usec()
	_phase_start = _boot_msec
	print("[SPIKE] boot ok，预热 ", WARMUP_SEC, "s")

func _process(_d: float) -> void:
	if _main == null:
		return
	var now_usec: int = Time.get_ticks_usec()
	var wall_ms: float = float(now_usec - _last_tick) / 1000.0
	_last_tick = now_usec
	var now_msec: int = Time.get_ticks_msec()
	var elapsed: float = float(now_msec - _boot_msec) / 1000.0
	_frames.append(wall_ms)
	if wall_ms > SPIKE_MS:
		_spikes += 1
	if _phase == "WARM" and _frames.size() % 30 == 0:
		print("[SPIKE] WARM t=%5.1fs | 最近30帧 max %7.1f avg %6.1f | 累计>%.0fms %d次" % [
			elapsed, _max(_frames.slice(_frames.size() - 30)), _avg(_frames.slice(_frames.size() - 30)), SPIKE_MS, _spikes])

	match _phase:
		"WARM":
			if elapsed >= WARMUP_SEC:
				_enter("A_baseline", PHASE_SEC)
		"A_baseline":
			if _done(now_msec):
				_report("A 基线")
				var hud: Node = _main.get_node_or_null("HudLayer")
				if hud != null:
					hud.process_mode = Node.PROCESS_MODE_DISABLED
					_enter("B_hud_off", PHASE_SEC)
				else:
					_finish()
		"B_hud_off":
			if _done(now_msec):
				_report("B HudLayer处理全停")
				var hud: Node = _main.get_node_or_null("HudLayer")
				hud.process_mode = Node.PROCESS_MODE_INHERIT
				var vp: Node = _main.get_node_or_null("BattleContainer/SubViewportContainer/SubViewport")
				var mode_name: String = "null"
				if vp is SubViewport:
					mode_name = str((vp as SubViewport).render_target_update_mode)
				print("[SPIKE] SubViewport 运行时 update_mode = ", mode_name, "（0=DISABLED 1=ONCE 2=VISIBLE 3=PARENT_VISIBLE 4=ALWAYS）")
				if vp is SubViewport:
					(vp as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
				_enter("B2_vp_disabled", PHASE_SEC)
		"B2_vp_disabled":
			if _done(now_msec):
				_report("B2 SubViewport渲染禁用")
				# 全部可见层隐藏：窗口近乎全空
				for layer_name in ["HudLayer", "PopupLayer", "InfoPanelLayer", "CardGridBattleHud", "BattleContainer"]:
					var layer: Node = _main.get_node_or_null(layer_name)
					if layer is CanvasItem:
						(layer as CanvasItem).visible = false
				_enter("B3_empty_window", PHASE_SEC)
		"B3_empty_window":
			if _done(now_msec):
				_report("B3 空窗口(全层隐藏)")
				for layer_name in ["HudLayer", "PopupLayer", "InfoPanelLayer", "CardGridBattleHud", "BattleContainer"]:
					var layer: Node = _main.get_node_or_null(layer_name)
					if layer is CanvasItem:
						(layer as CanvasItem).visible = true
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
				_enter("B4_vsync_off", 5.0)
		"B4_vsync_off":
			if _done(now_msec):
				_report("B4 恢复全部+关vsync(5s)")
				_finish()
		"C_child":
			if _cand_idx >= _cands.size():
				_finish()
				return
			if _frames.is_empty() or _phase_just_started(now_msec):
				pass
			if _done(now_msec):
				var c: Node = _cands[_cand_idx]
				_report("C 停用 " + str(c.name) + " 期间")
				c.process_mode = Node.PROCESS_MODE_INHERIT
				_cand_idx += 1
				if _cand_idx >= _cands.size():
					_finish()
				else:
					_enter("C_child", CHILD_PHASE_SEC)

func _phase_just_started(_now: int) -> bool:
	return false

func _enter(p: String, sec: float) -> void:
	_phase = p
	_phase_start = Time.get_ticks_msec()
	_phase_sec = sec
	_frames.clear()
	_spikes = 0
	if p == "C_child" and _cand_idx < _cands.size():
		(_cands[_cand_idx] as Node).process_mode = Node.PROCESS_MODE_DISABLED

var _phase_sec: float = 0.0

func _done(now_msec: int) -> bool:
	return float(now_msec - _phase_start) / 1000.0 >= _phase_sec

func _report(label: String) -> void:
	if _frames.is_empty():
		print("[SPIKE] ", label, " 无样本")
		return
	print("[SPIKE] %-28s | %4d帧 %4.1ffps | wall avg %5.1f p95 %6.1f max %6.1f | >%.0fms尖峰 %2d次" % [
		label, _frames.size(), float(_frames.size()) / (_phase_sec),
		_avg(_frames), _pct(_frames, 0.95), _max(_frames), SPIKE_MS, _spikes])

func _collect_processing_children(path: String) -> Array:
	var out: Array = []
	var parent: Node = _main.get_node_or_null(path)
	if parent == null:
		return out
	for c in parent.get_children():
		if c is Node and (c.is_processing() or c.is_physics_processing()):
			out.append(c)
	return out

func _finish() -> void:
	print("[SPIKE] done.")
	get_tree().quit()

func _avg(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s: float = 0.0
	for v in a:
		s += float(v)
	return s / float(a.size())

func _max(a: Array) -> float:
	var m: float = 0.0
	for v in a:
		m = maxf(m, float(v))
	return m

func _pct(a: Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	var s: Array = []
	for v in a:
		s.append(float(v))
	s.sort()
	return s[clampi(int(float(s.size()) * p), 0, s.size() - 1)]
