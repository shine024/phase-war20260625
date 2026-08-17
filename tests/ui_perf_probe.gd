extends Node
## ═══════════════════════════════════════════════════════════
##  非战斗 UI 性能探针 v3 —— 归因版
##  实测结论（v1/v2）：主界面空闲 proc_ms avg ~154 / p95 ~595，约 14FPS。
##  本版目标：找出空闲烧帧的具体节点/脚本。
##   A. 空闲基线（60帧）
##   B. 全树枚举：列出所有 is_processing/is_physics_processing 的节点 + 运行中 Timer
##   C. 二分停处理：对 /root 与 /root/Main 的直接子节点做减半禁用二分，
##      proc_ms 显著下降的子树逐层下钻，输出"罪魁"路径
##  运行：Godot_console.exe --rendering-driver opengl3 --path . res://tests/ui_perf_probe.tscn
## ═══════════════════════════════════════════════════════════

const MAIN_SCENE := "res://scenes/main.tscn"
const BOOT_WAIT_SEC := 3.0
const MEASURE_FRAMES := 25
const SETTLE_FRAMES := 6
const IMPROVE_RATIO := 0.12  # 禁用后 proc 降 12% 以上才算"有贡献"

enum Phase { BOOT, IDLE_BASE, ENUMERATE, BISECT, DONE }

var _main: Node = null
var _phase: int = Phase.BOOT
var _phase_frame: int = 0
var _boot_msec: int = 0

var _proc_ms: Array[float] = []
var _frame_ms: Array[float] = []
var _last_tick_usec: int = 0
var _skip_first: bool = true
var _bisect_queue: Array = []
var _bisect_started: bool = false
var _base_proc: float = 0.0

func _ready() -> void:
	var main_packed: PackedScene = load(MAIN_SCENE)
	_main = main_packed.instantiate()
	_add_main_deferred.call_deferred()

func _add_main_deferred() -> void:
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_boot_msec = Time.get_ticks_msec()
	print("[PROBE] boot: main.tscn added，等待 ", BOOT_WAIT_SEC, "s")

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	match _phase:
		Phase.BOOT:
			if Time.get_ticks_msec() - _boot_msec > int(BOOT_WAIT_SEC * 1000.0):
				_enter(Phase.IDLE_BASE)
		Phase.IDLE_BASE:
			if _sample(now, MEASURE_FRAMES):
				_base_proc = _avg(_proc_ms)
				print("[PROBE] A_idle | proc_ms avg %s p95 %s max %s | frame_ms avg %s | nodes %d" % [
					_fmt(_avg(_proc_ms)), _fmt(_pct(_proc_ms, 0.95)), _fmt(_max(_proc_ms)),
					_fmt(_avg(_frame_ms)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
				_enter(Phase.ENUMERATE)
		Phase.ENUMERATE:
			_enumerate_processing_nodes()
			_enter(Phase.BISECT)
		Phase.BISECT:
			if not _bisect_started:
				_bisect_started = true
				_do_all_bisect()  # fire-and-forget 协程，内部自驱
		Phase.DONE:
			pass

func _enter(p: int) -> void:
	_phase = p
	_phase_frame = 0
	_proc_ms.clear()
	_frame_ms.clear()
	_skip_first = true

func _sample(now_usec: int, frames: int) -> bool:
	if _skip_first:
		_skip_first = false
		_last_tick_usec = now_usec
		return false
	_frame_ms.append(float(now_usec - _last_tick_usec) / 1000.0)
	_last_tick_usec = now_usec
	_proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_phase_frame += 1
	return _phase_frame >= frames

# ── B: 全树枚举每帧工作者 ─────────────────────────────────
func _enumerate_processing_nodes() -> void:
	var workers: Array = []
	var running_timers: Array = []
	_walk(get_tree().root, workers, running_timers)
	print("[PROBE] B_enumerate | 全树 processing 节点数=", workers.size(), " 运行中Timer=", running_timers.size())
	for w in workers:
		print("   PROC  ", w)

func _walk(n: Node, out_workers: Array, out_timers: Array) -> void:
	if n != self:
		if n is Timer and not (n as Timer).is_stopped():
			out_timers.append(n)
		else:
			var proc: bool = n.is_processing()
			var phys: bool = n.is_physics_processing()
			if proc or phys:
				var script_path: String = ""
				if n.get_script() != null:
					script_path = str(n.get_script().resource_path)
				var tag: String = ("P" if proc else "") + ("F" if phys else "")
				out_workers.append("[%s] %s  <-  %s" % [tag, str(n.get_path()), script_path])
	for c in n.get_children():
		_walk(c, out_workers, out_timers)

# ── C: 二分禁用定位（异步协程自驱）─────────────────────────
func _do_all_bisect() -> void:
	await get_tree().process_frame
	_seed_bisect()
	while not _bisect_queue.is_empty():
		var task: Dictionary = _bisect_queue.pop_front()
		var scope: Node = get_node_or_null(String(task["scope"]))
		if scope == null:
			continue
		var base: float = await _measure_proc_avg()
		if base <= 0.5:
			continue
		var children: Array = []
		for c in scope.get_children():
			if c == self:
				continue
			if c is Node:
				children.append(c)
		if children.is_empty():
			continue
		for c in children:
			c.process_mode = Node.PROCESS_MODE_DISABLED
		var all_off: float = await _measure_proc_avg()
		for c in children:
			c.process_mode = Node.PROCESS_MODE_INHERIT
		var saved: float = base - all_off
		print("[PROBE] C_bisect scope=%s children=%d | base %s -> 全禁 %s（省 %s ms/帧，%.0f%%）" % [
			task["note"], children.size(), _fmt(base), _fmt(all_off), _fmt(saved),
			100.0 * saved / maxf(base, 0.001)])
		if saved < base * IMPROVE_RATIO:
			continue
		# 有显著贡献：分组减半下钻到 ≤8 个候选，再逐个禁用排序
		var hot: Array = await _narrow_hot(children, base, saved)
		var ranked: Array = []
		for c in hot:
			var prev_mode: int = c.process_mode
			c.process_mode = Node.PROCESS_MODE_DISABLED
			var off: float = await _measure_proc_avg()
			c.process_mode = prev_mode
			ranked.append({"node": c, "saved": base - off})
		ranked.sort_custom(func(a, b): return float(a["saved"]) > float(b["saved"]))
		for r in ranked:
			var n: Node = r["node"]
			if float(r["saved"]) < base * 0.05:
				break
			var script_path: String = ""
			if n.get_script() != null:
				script_path = str(n.get_script().resource_path)
			print("   HOT  %s  省 %s ms/帧  <-  %s" % [str(n.get_path()), _fmt(float(r["saved"])), script_path])
		# 最热节点若自身省 ≥25% 且有子树，继续下钻一层
		var top: Node = ranked[0]["node"]
		if float(ranked[0]["saved"]) >= base * 0.25 and top.get_child_count() > 0:
			_bisect_queue.append({"scope": str(top.get_path()), "note": "下钻 " + str(top.name)})
	print("[PROBE] done.")
	_phase = Phase.DONE
	get_tree().quit()

## 减半下钻：返回最热的候选集合（≤8 个）
func _narrow_hot(children: Array, base: float, group_saved: float) -> Array:
	var pool: Array = children
	var target: float = group_saved
	while pool.size() > 8:
		var half_a: Array = pool.slice(0, pool.size() / 2)
		var half_b: Array = pool.slice(pool.size() / 2, pool.size())
		for c in half_a:
			c.process_mode = Node.PROCESS_MODE_DISABLED
		var off_a: float = await _measure_proc_avg()
		for c in half_a:
			c.process_mode = Node.PROCESS_MODE_INHERIT
		var save_a: float = base - off_a
		if save_a >= target * 0.5:
			pool = half_a
			target = save_a
		else:
			pool = half_b
			target = maxf(target - save_a, base * 0.05)
	return pool

func _seed_bisect() -> void:
	_bisect_queue.append({"scope": str(_main.get_path()), "note": "Main 子树"})
	_bisect_queue.append({"scope": "/root", "note": "autoload 全体"})

func _measure_proc_avg() -> float:
	_proc_ms.clear()
	_skip_first = true
	var f := 0
	while f < MEASURE_FRAMES:
		await get_tree().process_frame
		_proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		f += 1
	for _i in range(SETTLE_FRAMES):
		await get_tree().process_frame
	return _avg(_proc_ms)

# ── 统计 ──────────────────────────────────────────────────
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
	var idx: int = clampi(int(float(s.size()) * p), 0, s.size() - 1)
	return s[idx]

func _fmt(v: float) -> String:
	return "%.1f" % v
