extends Node
## 统一调试日志开关：仅当 agent_logs_enabled 为 true 时写入 user://debug_agent.log
## 在编辑器中可将 agent_logs_enabled 设为 true 以便排查问题

var agent_logs_enabled: bool = false
var _log_path: String = "user://debug_agent.log"

func agent_log(location: String, message: String, data: Dictionary, hypothesis_id: String = "", session_id: String = "", run_id: String = "") -> void:
	if not agent_logs_enabled:
		return
	var payload: Dictionary = {
		"sessionId": session_id,
		"hypothesisId": hypothesis_id,
		"timestamp": Time.get_ticks_msec(),
		"location": location,
		"message": message,
		"data": data,
	}
	if not run_id.is_empty():
		payload["runId"] = run_id
	var line: String = JSON.stringify(payload)
	var f: FileAccess = FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(_log_path, FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(line)
		f.close()
