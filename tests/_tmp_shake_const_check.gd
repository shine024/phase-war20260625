extends SceneTree
## _tmp：HIT_SHAKE_KEYS 收敛值断言（v6.15b）
func _initialize() -> void:
	var h := load("res://scripts/battle/unit_shared_helpers.gd")
	var keys: Array = h.get("HIT_SHAKE_KEYS")
	var ok: bool = keys.size() == 4 and absf(keys[0] - 0.90) < 0.001 and absf(keys[1] - 1.06) < 0.001
	print("SHAKE_KEYS=", keys)
	print("SHAKE_CONST_OK" if ok else "SHAKE_CONST_FAILED")
	quit(0 if ok else 1)
