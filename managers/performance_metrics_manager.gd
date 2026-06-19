extends Node
## 运行时性能采集器（中低配 PC 对标）
## 采集三项核心指标：
## 1) 主界面 TTI（首次可交互）
## 2) 背包首开耗时
## 3) 战斗帧时间 P50 / P95

const OUTPUT_PATH := "user://performance_baseline.json"
const DEBUG_LOG := false

var _session_started_ms: int = 0
var _tti_ms: int = -1
var _backpack_open_start_ms: int = -1
var _backpack_first_open_ms: int = -1

var _battle_sampling: bool = false
var _battle_frame_ms_samples: Array[float] = []
var _battle_last_flush_ms: int = 0
var _phase_start_ms: Dictionary = {}
var _phase_last_ms: Dictionary = {}

## v6.6: 延迟写入缓冲
var _deferred_write_payload: String = ""

func _ready() -> void:
	_session_started_ms = Time.get_ticks_msec()
	_battle_last_flush_ms = _session_started_ms

func mark_main_interactive() -> void:
	if _tti_ms >= 0:
		return
	_tti_ms = max(0, Time.get_ticks_msec() - _session_started_ms)
	_deferred_flush("tti")

func mark_backpack_open_begin() -> void:
	if _backpack_first_open_ms >= 0:
		return
	if _backpack_open_start_ms < 0:
		_backpack_open_start_ms = Time.get_ticks_msec()

func mark_backpack_open_ready() -> void:
	if _backpack_first_open_ms >= 0:
		return
	if _backpack_open_start_ms < 0:
		return
	_backpack_first_open_ms = max(0, Time.get_ticks_msec() - _backpack_open_start_ms)
	_backpack_open_start_ms = -1
	_deferred_flush("backpack_first_open")

func begin_battle_sampling() -> void:
	_battle_sampling = true
	_battle_frame_ms_samples.clear()

func sample_battle_frame(delta_sec: float) -> void:
	if not _battle_sampling:
		return
	_battle_frame_ms_samples.append(maxf(0.0, delta_sec * 1000.0))
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _battle_last_flush_ms >= 4000:
		_battle_last_flush_ms = now_ms
		_deferred_flush("battle_live")
		_battle_frame_ms_samples.clear()

func end_battle_sampling() -> void:
	if not _battle_sampling:
		return
	_battle_sampling = false
	_battle_frame_ms_samples.clear()
	_phase_start_ms.clear()
	_deferred_flush("battle_end")

func get_snapshot() -> Dictionary:
	return {
		"session_started_ms": _session_started_ms,
		"tti_ms": _tti_ms,
		"backpack_first_open_ms": _backpack_first_open_ms,
		"battle_frame_count": _battle_frame_ms_samples.size(),
		"battle_p50_ms": _percentile(_battle_frame_ms_samples, 50.0),
		"battle_p95_ms": _percentile(_battle_frame_ms_samples, 95.0),
		"battle_avg_ms": _average(_battle_frame_ms_samples),
		"phase_last_ms": _phase_last_ms.duplicate(true),
	}

func begin_phase(phase_name: String) -> void:
	if phase_name.is_empty():
		return
	_phase_start_ms[phase_name] = Time.get_ticks_msec()

func end_phase(phase_name: String) -> void:
	if phase_name.is_empty():
		return
	if not _phase_start_ms.has(phase_name):
		return
	var elapsed: int = max(0, Time.get_ticks_msec() - int(_phase_start_ms[phase_name]))
	_phase_last_ms[phase_name] = elapsed
	_phase_start_ms.erase(phase_name)
	_deferred_flush("phase_" + phase_name)

func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sum: float = 0.0
	for v in values:
		sum += v
	return sum / float(values.size())

func _percentile(values: Array[float], p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var idx: int = int(clampf(p, 0.0, 100.0) / 100.0 * float(sorted.size() - 1))
	return sorted[idx]

## v6.6: 延迟磁盘写入：通过 call_deferred 将 I/O 移出当前帧，避免阻塞战斗结算
func _deferred_flush(reason: String) -> void:
	var payload: Dictionary = {
		"timestamp_ms": Time.get_ticks_msec(),
		"reason": reason,
		"snapshot": get_snapshot(),
	}
	# 将序列化和 I/O 延迟到帧末，避免同步阻塞
	_deferred_write_payload = JSON.stringify(payload, "\t")
	call_deferred("_do_write_flush", reason)

func _do_write_flush(reason: String) -> void:
	if _deferred_write_payload.is_empty():
		return
	var f: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if f == null:
		_deferred_write_payload = ""
		return
	f.store_string(_deferred_write_payload)
	_deferred_write_payload = ""
	if DEBUG_LOG:
		pass
		# [LOG-v5.1] print("[PerformanceMetrics] flushed: %s -> %s" % [reason, OUTPUT_PATH])
