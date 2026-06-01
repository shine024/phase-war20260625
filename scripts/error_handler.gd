extends Node
## 统一错误处理系统：提供错误恢复、用户友好提示和日志记录

## 错误级别
enum ErrorLevel {
	INFO,     # 信息：不影响游戏运行
	WARNING,  # 警告：可能影响功能但可继续
	ERROR,    # 错误：影响功能但可恢复
	CRITICAL  # 严重：无法恢复，需要重启
}

## 错误信息
class ErrorInfo extends RefCounted:
	var level: ErrorLevel
	var code: String
	var message: String
	var context: Dictionary
	var timestamp: float

	func _init(p_level: ErrorLevel, p_code: String, p_message: String, p_context: Dictionary = {}):
		level = p_level
		code = p_code
		message = p_message
		context = p_context
		timestamp = Time.get_unix_time_from_system()

## 错误处理回调
var _error_callbacks: Array[Callable] = []

## 错误历史（最多保存100条）
var _error_history: Array[ErrorInfo] = []

## 是否显示用户提示
var show_user_notifications: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "ErrorHandler"

## 注册错误回调
func register_error_callback(callback: Callable) -> void:
	if not callback.is_valid():
		push_error("[ErrorHandler] 无效的回调函数")
		return

	_error_callbacks.append(callback)

## 报告错误
func report_error(level: ErrorLevel, code: String, message: String, context: Dictionary = {}) -> void:
	var error_info = ErrorInfo.new(level, code, message, context)

	# 添加到历史
	_error_history.append(error_info)
	if _error_history.size() > 100:
		_error_history.pop_front()

	# 记录日志
	_log_error(error_info)

	# 通知回调
	for callback in _error_callbacks:
		if callback.is_valid():
			callback.call(error_info)

	# 显示用户提示
	if show_user_notifications:
		_show_user_notification(error_info)

## 便捷方法
func report_info(code: String, message: String, context: Dictionary = {}) -> void:
	report_error(ErrorLevel.INFO, code, message, context)

func report_warning(code: String, message: String, context: Dictionary = {}) -> void:
	report_error(ErrorLevel.WARNING, code, message, context)

func report_error_code(code: String, message: String, context: Dictionary = {}) -> void:
	report_error(ErrorLevel.ERROR, code, message, context)

func report_critical(code: String, message: String, context: Dictionary = {}) -> void:
	report_error(ErrorLevel.CRITICAL, code, message, context)

## 内部方法
func _log_error(error_info: ErrorInfo) -> void:
	var level_str = ErrorLevel.keys()[error_info.level]
	var log_msg = "[%s] %s: %s" % [level_str, error_info.code, error_info.message]

	match error_info.level:
		ErrorLevel.INFO:
			pass  # INFO 级别静默处理
		ErrorLevel.WARNING:
			push_warning(log_msg)
		ErrorLevel.ERROR, ErrorLevel.CRITICAL:
			push_error(log_msg)

	# 如果有上下文，也记录
	if not error_info.context.is_empty() and error_info.level >= ErrorLevel.WARNING:
		push_warning("  上下文: %s" % error_info.context)

func _show_user_notification(error_info: ErrorInfo) -> void:
	# 只对WARNING及以上级别显示通知
	if error_info.level < ErrorLevel.WARNING:
		return

	var user_msg = _get_user_friendly_message(error_info)

	var nm = get_node_or_null("/root/NotificationManager")
	if nm and nm.has_method("show_notification"):
		var level_str = ErrorLevel.keys()[error_info.level]
		nm.show_notification({
			"title": level_str,
			"message": user_msg,
			"type": level_str.to_lower(),
			"duration": 8.0 if error_info.level >= ErrorLevel.ERROR else 5.0
		})
	else:
		push_warning("[用户通知] %s" % user_msg)

func _get_user_friendly_message(error_info: ErrorInfo) -> String:
	# 根据错误代码生成用户友好的消息
	match error_info.code:
		"MANAGER_NOT_FOUND":
			return "游戏系统初始化失败，请重启游戏"
		"SAVE_FAILED":
			return "存档失败，请检查存储空间"
		"LOAD_FAILED":
			return "读档失败，文件可能损坏"
		"BATTLE_ERROR":
			return "战斗发生错误，将返回主菜单"
		_:
			return error_info.message

## 获取错误历史
func get_error_history() -> Array[ErrorInfo]:
	return _error_history.duplicate()

## 获取最近的错误
func get_recent_errors(count: int = 10) -> Array[ErrorInfo]:
	var start = max(0, _error_history.size() - count)
	return _error_history.slice(start)

## 清除错误历史
func clear_history() -> void:
	_error_history.clear()

## 获取错误统计
func get_error_stats() -> Dictionary:
	var stats = {
		"total": _error_history.size(),
		"by_level": {}
	}

	for error_info in _error_history:
		var level_str = ErrorLevel.keys()[error_info.level]
		if not stats.by_level.has(level_str):
			stats.by_level[level_str] = 0
		stats.by_level[level_str] += 1

	return stats
