extends RefCounted
## 读取 PerformanceMetricsManager 输出并执行阈值检查

const DEFAULT_PATH := "user://performance_baseline.json"

static func check_gate(path: String = DEFAULT_PATH) -> Dictionary:
	var result := {
		"ok": false,
		"reasons": [],
		"snapshot": {},
	}
	if not FileAccess.file_exists(path):
		result.reasons.append("missing metrics file: %s" % path)
		return result
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		result.reasons.append("failed to open metrics file")
		return result
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		result.reasons.append("invalid json payload")
		return result
	var payload: Dictionary = parsed
	var snap: Dictionary = payload.get("snapshot", {})
	result.snapshot = snap

	var tti_ms: int = int(snap.get("tti_ms", -1))
	var backpack_ms: int = int(snap.get("backpack_first_open_ms", -1))
	var p50_ms: float = float(snap.get("battle_p50_ms", 0.0))
	var p95_ms: float = float(snap.get("battle_p95_ms", 0.0))

	if tti_ms < 0 or tti_ms > 2500:
		result.reasons.append("tti gate failed: %s" % tti_ms)
	if backpack_ms < 0 or backpack_ms > 450:
		result.reasons.append("backpack first-open gate failed: %s" % backpack_ms)
	if p50_ms > 16.7:
		result.reasons.append("battle p50 gate failed: %.2f" % p50_ms)
	if p95_ms > 25.0:
		result.reasons.append("battle p95 gate failed: %.2f" % p95_ms)

	result.ok = result.reasons.is_empty()
	return result
