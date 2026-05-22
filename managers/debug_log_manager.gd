extends Node
## 统一的调试日志管理器

enum LogLevel { VERBOSE = 0, DEBUG = 1, INFO = 2, WARNING = 3, ERROR = 4 }
enum LogTarget { CONSOLE = 1, FILE = 2, BOTH = 3 }

var current_log_level: int = LogLevel.DEBUG
var log_target: int = LogTarget.BOTH
var log_file_path: String = "user://debug.log"
var log_buffer: Array = []
var buffer_size: int = 50
var last_flush_time: int = 0
var flush_interval: int = 1000
var _log_file: FileAccess = null
var logging_enabled: bool = true
var session_id: String = ""
var run_id: String = ""
var log_channels: Dictionary = {}

func _ready() -> void:
	session_id = _generate_session_id()
	run_id = "default"
	_ensure_log_directory()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var flush_timer := Timer.new()
	flush_timer.wait_time = maxf(0.05, float(flush_interval) / 1000.0)
	flush_timer.timeout.connect(_on_flush_timer_timeout)
	flush_timer.autostart = true
	add_child(flush_timer)

func _on_flush_timer_timeout() -> void:
	flush_log_buffer()

func _exit_tree() -> void:
	flush_log_buffer()
	close_log_file()

func _generate_session_id() -> String:
	var timestamp = Time.get_unix_time_from_system()
	var random = randi() % 10000
	return "%d_%d" % [int(timestamp), random]

func _ensure_log_directory() -> void:
	var log_dir = log_file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(log_dir):
		DirAccess.make_dir_absolute(log_dir)

## 写入日志 - 使用 _write_log 作为函数名避免与内置 log() 冲突
func _write_log(loc: String, msg: String, dt: Dictionary, lvl: int, hyp: String, rid: String) -> void:
	if not logging_enabled:
		return
	if lvl < current_log_level:
		return
	var effective_run_id = rid if not rid.is_empty() else run_id
	var timestamp = Time.get_ticks_msec()
	var log_entry: Dictionary = {
		"sessionId": session_id,
		"runId": effective_run_id,
		"hypothesisId": hyp,
		"location": loc,
		"message": msg,
		"data": dt,
		"timestamp": timestamp,
		"level": _get_level_name(lvl)
	}
	if log_target == LogTarget.CONSOLE or log_target == LogTarget.BOTH:
		_output_to_console(log_entry)
	if log_target == LogTarget.FILE or log_target == LogTarget.BOTH:
		_buffer_log_entry(log_entry)

func _output_to_console(entry: Dictionary) -> void:
	var level_name = entry.get("level", "DEBUG")
	var location = entry.get("location", "")
	var message = entry.get("message", "")
	var output = "[%s] [%s] %s: %s" % [level_name, location, session_id, message]
	match entry.get("level", LogLevel.DEBUG):
		LogLevel.ERROR:
			printerr(output)
		LogLevel.WARNING:
			push_warning(output)
		_:
			print(output)
	var data = entry.get("data", {})
	if not data.is_empty():
		print("  Data: ", data)

func _buffer_log_entry(entry: Dictionary) -> void:
	log_buffer.append(entry)
	if log_buffer.size() >= buffer_size:
		flush_log_buffer()

func flush_log_buffer() -> void:
	if log_buffer.is_empty():
		return
	if _log_file == null:
		_log_file = FileAccess.open(log_file_path, FileAccess.WRITE_READ)
		if _log_file == null:
			printerr("[DebugLogManager] Failed to open log file")
			log_buffer.clear()
			return
		_log_file.seek_end()
	for entry in log_buffer:
		var json_line = JSON.stringify(entry)
		_log_file.store_line(json_line)
	_log_file.flush()
	log_buffer.clear()
	last_flush_time = Time.get_ticks_msec()

func close_log_file() -> void:
	if _log_file != null:
		_log_file.close()
		_log_file = null

func _get_level_name(level: int) -> String:
	match level:
		LogLevel.VERBOSE: return "VERBOSE"
		LogLevel.DEBUG: return "DEBUG"
		LogLevel.INFO: return "INFO"
		LogLevel.WARNING: return "WARNING"
		LogLevel.ERROR: return "ERROR"
		_: return "UNKNOWN"

## 便捷日志函数
func verbose(loc: String, msg: String, dt: Dictionary, hyp: String = "") -> void:
	_write_log(loc, msg, dt, LogLevel.VERBOSE, hyp, "")

func debug(loc: String, msg: String, dt: Dictionary, hyp: String = "") -> void:
	_write_log(loc, msg, dt, LogLevel.DEBUG, hyp, "")

func info(loc: String, msg: String, dt: Dictionary, hyp: String = "") -> void:
	_write_log(loc, msg, dt, LogLevel.INFO, hyp, "")

func warning(loc: String, msg: String, dt: Dictionary, hyp: String = "") -> void:
	_write_log(loc, msg, dt, LogLevel.WARNING, hyp, "")

func error_log(loc: String, msg: String, dt: Dictionary, hyp: String = "") -> void:
	_write_log(loc, msg, dt, LogLevel.ERROR, hyp, "")

func agent_log(loc: String, msg: String, dt: Dictionary, hyp: String = "", rid: String = "") -> void:
	_write_log(loc, msg, dt, LogLevel.DEBUG, hyp, rid)

func set_log_level(level: int) -> void:
	current_log_level = clampi(level, LogLevel.VERBOSE, LogLevel.ERROR)
	info("DebugLogManager", "Log level set to: " + _get_level_name(current_log_level), {})

func set_log_target(target: int) -> void:
	log_target = target
	flush_log_buffer()

func set_run_id(new_run_id: String) -> void:
	run_id = new_run_id

func set_logging_enabled(enabled: bool) -> void:
	logging_enabled = enabled

func is_channel_enabled(channel: String, default_enabled: bool = false) -> bool:
	if not logging_enabled:
		return false
	if log_channels.has(channel):
		return bool(log_channels[channel])
	return default_enabled

func set_channel_enabled(channel: String, enabled: bool) -> void:
	log_channels[channel] = enabled

func get_log_stats() -> Dictionary:
	return {
		"session_id": session_id,
		"run_id": run_id,
		"buffer_size": log_buffer.size(),
		"log_level": _get_level_name(current_log_level),
		"logging_enabled": logging_enabled,
		"log_file_path": log_file_path,
		"channels": log_channels.duplicate(true)
	}
