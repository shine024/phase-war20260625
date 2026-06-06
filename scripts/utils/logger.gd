extends Node
## 统一日志框架 - v5.1
## 替代散落的 print() 调用，支持日志级别控制

enum LogLevel {
	DEBUG = 0,
	INFO = 1,
	WARN = 2,
	ERROR = 3,
	NONE = 4,  # 完全静默
}

## 当前日志级别（生产环境设为 INFO 或 WARN）
var log_level: int = LogLevel.INFO

## 是否在日志前添加时间戳
var show_timestamp: bool = false

## 模块前缀（可选）
var _module_prefix: String = ""

func _init() -> void:
	# 检测是否为 debug 模式（Godot debug build）
	if OS.is_debug_build():
		log_level = LogLevel.DEBUG
	else:
		log_level = LogLevel.INFO

func set_module(prefix: String) -> void:
	_module_prefix = prefix

func debug(msg: String) -> void:
	if log_level <= LogLevel.DEBUG:
		_output("[DBG]", msg)

func info(msg: String) -> void:
	if log_level <= LogLevel.INFO:
		_output("[INF]", msg)

func warn(msg: String) -> void:
	if log_level <= LogLevel.WARN:
		push_warning(_format("[WRN]", msg))

func error(msg: String) -> void:
	if log_level <= LogLevel.ERROR:
		push_error(_format("[ERR]", msg))

func _output(tag: String, msg: String) -> void:
	print(_format(tag, msg))

func _format(tag: String, msg: String) -> String:
	var prefix: String = ""
	if show_timestamp:
		prefix = "[%s] " % Time.get_time_string_from_system()
	if not _module_prefix.is_empty():
		prefix += "[%s] " % _module_prefix
	return "%s%s %s" % [prefix, tag, msg]


## ─── 静态便捷接口（无需实例化） ───

static var _instance: RefCounted = null

static func _get_instance() -> RefCounted:
	if _instance == null:
		_instance = new()
	return _instance

static func d(msg: String) -> void:
	_get_instance().debug(msg)

static func i(msg: String) -> void:
	_get_instance().info(msg)

static func w(msg: String) -> void:
	_get_instance().warn(msg)

static func e(msg: String) -> void:
	_get_instance().error(msg)
