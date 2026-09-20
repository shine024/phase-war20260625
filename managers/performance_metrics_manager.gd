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
## v9.x（3c）：战斗采样 flush 计时改 delta 累加（原每帧 Time.get_ticks_msec；旧 _battle_last_flush_ms 已删）
var _battle_flush_accum: float = 0.0
var _phase_start_ms: Dictionary = {}
var _phase_last_ms: Dictionary = {}

## v6.6: 延迟写入缓冲
var _deferred_write_payload: String = ""
## v32.0 实机验收埋点：观战节奏工具使用率（倍速档位/跳过激活/挂机观战点击）
var event_counters: Dictionary = {}   # name -> int
## v6.19 P2-T2.2 流派成型时刻里程碑（跨会话持久 user://milestones.cfg；试玩验收判据：
## 新档 2 小时内至少触发 1 个，判据文档 docs/试玩验收_长线节点.md）。
## 时间戳口径 = total_ms（进程累计游戏内时长，_process 累加）——v6.19.1 核验修正。
var milestone_events: Array = []      # [{name: String, total_ms: int}]（本会话新触发的事件）
var _milestone_done: Dictionary = {}  # name -> true（跨会话持久，重启不重记）
var _cumulative_playtime_ms: int = 0  # 累计游戏内时长（含历史会话，随里程碑落盘）
var milestone_save_path := "user://milestones.cfg"  # var 便于测试注入临时路径（防覆盖真实档）
## v6.19 P2-T2.3 观战判据场次聚合（battle_started~battle_ended 之间的临时旗标）
var _battle_flags: Dictionary = {}

func count_event(name: String) -> void:
	if name.is_empty():
		return
	event_counters[name] = int(event_counters.get(name, 0)) + 1
	_deferred_flush("counter_" + name)

## v6.19 P2-T2.2: 一次性里程碑记录（跨会话去重——持久化在 user://milestones.cfg，
## 重启不重记；重复调用只记首次）。时间戳 total_ms=累计游戏内时长。
func record_milestone(name: String) -> void:
	if name.is_empty() or _milestone_done.has(name):
		return
	_milestone_done[name] = true
	milestone_events.append({
		"name": name,
		"total_ms": _cumulative_playtime_ms,
	})
	count_event("milestone_" + name)
	_persist_milestones()

## v6.19 P2-T2.3: 本场战斗旗标（倍速>1 / 跳过推演），battle_ended 聚合进 event_counters
func mark_battle_flag(flag: String) -> void:
	if not flag.is_empty():
		_battle_flags[flag] = true

func _ready() -> void:
	_session_started_ms = Time.get_ticks_msec()
	_load_milestones()

func _process(delta: float) -> void:
	_cumulative_playtime_ms += int(maxf(0.0, delta) * 1000.0)

func _load_milestones() -> void:
	var cf := ConfigFile.new()
	if cf.load(milestone_save_path) != OK:
		return
	_cumulative_playtime_ms = int(cf.get_value("playtime", "total_ms", 0))
	var done = cf.get_value("milestones", "done", {})
	if done is Dictionary:
		_milestone_done = done

func _persist_milestones() -> void:
	var cf := ConfigFile.new()
	cf.set_value("playtime", "total_ms", _cumulative_playtime_ms)
	cf.set_value("milestones", "done", _milestone_done)
	cf.save(milestone_save_path)

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
	_battle_flush_accum = 0.0

func sample_battle_frame(delta_sec: float) -> void:
	if not _battle_sampling:
		return
	_battle_frame_ms_samples.append(maxf(0.0, delta_sec * 1000.0))
	# v9.x（3c 性能批次）：每帧 Time.get_ticks_msec() 系统调用 → delta 累加，
	# 语义等价（15s flush 周期），采样粒度不变
	_battle_flush_accum += delta_sec
	# v7.x 性能优化：写盘频率 4s→15s（已 call_deferred 非阻塞，降频进一步减少磁盘 IO 抖动）
	if _battle_flush_accum >= 15.0:
		_battle_flush_accum = 0.0
		_deferred_flush("battle_live")
		_battle_frame_ms_samples.clear()

func end_battle_sampling() -> void:
	if not _battle_sampling:
		return
	_battle_sampling = false
	_battle_frame_ms_samples.clear()
	_phase_start_ms.clear()
	# v6.19 P2-T2.3: 场次聚合——倍速+跳过使用率判据读数口径：
	# 使用率 = battles_sped_or_skipped / battles_total（同场倍速+跳过只计 1，联合计数闭合口径）
	event_counters["battles_total"] = int(event_counters.get("battles_total", 0)) + 1
	for flag in ["spedup", "skipped"]:
		if bool(_battle_flags.get(flag, false)):
			var key: String = "battles_" + flag
			event_counters[key] = int(event_counters.get(key, 0)) + 1
	if bool(_battle_flags.get("spedup", false)) or bool(_battle_flags.get("skipped", false)):
		event_counters["battles_sped_or_skipped"] = int(event_counters.get("battles_sped_or_skipped", 0)) + 1
	_battle_flags.clear()
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
		"event_counters": event_counters.duplicate(),
		"milestone_events": milestone_events.duplicate(true),  # v6.19 P2-T2.2
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
	# P0-4 发行门控：release 构建不向 user:// 写性能采集文件（编辑器/调试构建保持原行为）
	# P0-4 发行门控：release 构建默认不写性能采集文件；v32.0 试玩构建
	#（custom feature "pw_playtest"）解锁采集——实机验收埋点的载体
	if not OS.is_debug_build() and not OS.has_feature("pw_playtest"):
		return
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
	# v32.0: 试玩构建额外落一份到 exe 旁（测试者免翻 APPDATA；写失败静默跳过）
	if OS.has_feature("pw_playtest"):
		var exe_dir := OS.get_executable_path().get_base_dir()
		var f2 := FileAccess.open(exe_dir.path_join("playtest_metrics.json"), FileAccess.WRITE)
		if f2 != null:
			f2.store_string(_deferred_write_payload)
			f2.close()
	_deferred_write_payload = ""
	if DEBUG_LOG:
		pass
		# [LOG-v5.1] print("[PerformanceMetrics] flushed: %s -> %s" % [reason, OUTPUT_PATH])
