# 排查：shader-only / battlefield-only 谁导致 quit 挂死（临时工具）
extends SceneTree
func _initialize() -> void:
	var which := OS.get_environment("BISECT_WHAT")
	print("[Bisect2] loading: ", which)
	var r = load(which)
	print("[Bisect2] loaded=", r != null)
	quit(0)
