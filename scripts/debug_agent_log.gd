extends RefCounted
class_name DebugAgentLog
## Debug session e402c7 — append NDJSON to project debug-e402c7.log

const LOG_PATH := "res://debug-e402c7.log"
const SESSION_ID := "e402c7"


static func write(hypothesis_id: String, location: String, message: String, data: Dictionary = {}, run_id: String = "pre-fix") -> void:
	var payload := {
		"sessionId": SESSION_ID,
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000,
	}
	var line := JSON.stringify(payload) + "\n"
	var mode := FileAccess.WRITE_READ if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE
	var f := FileAccess.open(LOG_PATH, mode)
	if f == null:
		return
	f.seek_end()
	f.store_string(line)
	f.close()
