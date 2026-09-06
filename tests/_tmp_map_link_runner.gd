extends Node
## v26.18 卡车↔战区地图链路 E2E 执行体（直挂 /root——current_scene 会被
## SceneTransition 换掉，本节点必须活在场景树根部才能跑完全程）
## 跑法：godot --rendering-driver opengl3 --path . res://tests/_tmp_truck_map_link_boot.tscn
## ① 进卡车 ② 顶栏链路 _open_world_map → world_map + from_truck 标记 ③ 地图返回 → 回卡车 + 标记清理
## 额外截一张卡车顶栏图（核对"战区地图"按钮），退出码非 0 = 有断言失败

var _fails: Array[String] = []


func _ready() -> void:
	await _run()
	for f in _fails:
		printerr("[MapLink] FAIL: " + f)
	print("[MapLink] " + ("ALL PASS" if _fails.is_empty() else "HAS FAILURES"))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _cur_path() -> String:
	var cs := get_tree().current_scene
	return String(cs.scene_file_path) if cs != null else ""


func _run() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.call("load_game")
		if sm.has_method("flush_deferred_manager_loads"):
			sm.call("flush_deferred_manager_loads")

	# 1. 进卡车
	SceneTransition.change(get_tree(), "res://scenes/bunker/truck_base.tscn")
	await _wait(40)
	if not _cur_path().contains("truck_base"):
		_fails.append("未进入 truck_base: " + _cur_path())
		return
	await _wait(10)
	await _shot("maplink_truck_topbar")
	print("[MapLink] step1 truck OK")

	# 2. 卡车 → 战区地图（顶栏按钮同一处理函数）
	get_tree().current_scene.call("_open_world_map")
	await _wait(90)
	if not _cur_path().contains("world_map"):
		_fails.append("truck._open_world_map 未切到 world_map: " + _cur_path())
		return
	if not Engine.has_meta("world_map_from_truck"):
		_fails.append("world_map_from_truck 标记未设置")
	print("[MapLink] step2 open-map OK")

	# 3. 地图 ESC/返回 → 回卡车（不是 main），标记清理
	get_tree().current_scene.call("_on_back_to_title")
	await _wait(90)
	if not _cur_path().contains("truck_base"):
		_fails.append("地图返回未回 truck_base: " + _cur_path())
		return
	if Engine.has_meta("world_map_from_truck"):
		_fails.append("返回后 from_truck 标记未清理")
	print("[MapLink] step3 back-to-truck OK")


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(ProjectSettings.globalize_path("res://.godot/agent_tools/%s.png" % tag))
		print("[MapLink] shot %s" % tag)
