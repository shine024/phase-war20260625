extends Node
## 战斗场景内轻量性能采样：配合编辑器分析器做对照（默认关闭控制台输出，避免 print 尖峰）。
class_name BattlePerformanceMonitor

const INTERVAL_SEC := 3.0
## 设为 true 时每隔 INTERVAL_SEC 向 stdout 打印 Performance 监视器快照（调试用）
const ENABLE_CONSOLE_LOG := false
var _accum: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if not ENABLE_CONSOLE_LOG:
		set_process(false)

func _process(delta: float) -> void:
	_accum += delta
	if _accum < INTERVAL_SEC:
		return
	_accum = 0.0
	_log_sample()

func _log_sample() -> void:
	var fps: float = Engine.get_frames_per_second()
	var proc_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var draw: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var prim: float = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var obj_n: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	if OS.is_debug_build():
		pass  # [LOG-v5.1] print("[BattlePerfMon] FPS=%.1f | process_ms=%.2f physics_ms=%.2f | draw_calls=%.0f primitives=%.0f objects=%.0f" % [fps, proc_ms, phys_ms, draw, prim, obj_n])
