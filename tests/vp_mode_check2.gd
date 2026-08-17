extends SceneTree
## 纯引擎对照：SubViewportContainer(stretch) + SubViewport(UPDATE_ONCE) 是否被引擎改写
func _init() -> void:
	var root_n := Node.new()
	root.add_child(root_n)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size = Vector2i(400, 300)
	root_n.add_child(svc)
	var sv := SubViewport.new()
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	sv.size = Vector2i(400, 300)
	svc.add_child(sv)
	print("[VPMODE2] 无container入树: child=", sv.render_target_update_mode)
	await create_timer(1.0).timeout
	print("[VPMODE2] 1秒后: child=", sv.render_target_update_mode, " (container stretch=", svc.stretch, ")")
	quit(0)
