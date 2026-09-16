extends SceneTree
func _initialize() -> void:
	var s = load("res://managers/manufacture_manager.gd")
	print("manufacture_manager.gd load -> ", s)
	if s != null:
		var n: Node = s.new()
		print("new() -> ", n)
		if n != null:
			n.free()
	var s2 = load("res://managers/battle/battle_spawn_system.gd")
	print("battle_spawn_system.gd load -> ", s2)
	quit(0)
