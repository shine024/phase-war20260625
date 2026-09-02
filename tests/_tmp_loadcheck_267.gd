extends SceneTree
func _init() -> void:
	var files := [
		"res://scenes/main.gd",
		"res://scenes/ui/bottom_instrument_bar.gd",
		"res://scripts/systems/main_reward.gd",
	]
	var fail := false
	for f in files:
		var s: Script = load(f)
		if s == null:
			push_error("LOAD FAIL: " + f)
			fail = true
		elif not s.can_instantiate() and not s.is_abstract():
			push_error("COMPILE SUSPECT: " + f)
			fail = true
		else:
			print("OK: ", f)
	quit(1 if fail else 0)
