extends SceneTree
## 最小实验：main.tscn 的 SubViewport update_mode 入树前后变化
## 运行：Godot_console.exe --headless --path . --script tests/vp_mode_check.gd

func _init() -> void:
	var ps: PackedScene = load("res://scenes/main.tscn")
	var main: Node = ps.instantiate()
	var vp: SubViewport = main.get_node_or_null("BattleContainer/SubViewportContainer/SubViewport") as SubViewport
	print("[VPMODE] 实例化后未入树: ", vp.render_target_update_mode if vp else "null")
	root.add_child(main)
	print("[VPMODE] 入树后立即: ", vp.render_target_update_mode if vp else "null")
	await process_frame
	await process_frame
	await create_timer(1.0).timeout
	print("[VPMODE] 入树1秒后: ", vp.render_target_update_mode if vp else "null")
	quit(0)
