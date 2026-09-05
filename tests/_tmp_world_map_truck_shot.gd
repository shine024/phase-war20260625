extends Node
## v26.12c 世界地图卡车标记实机验证（临时工具）：构建/定位/时代贴图/移动 tween/截图
## 跑法：godot --path . res://tests/_tmp_world_map_truck_shot.tscn（带窗口，2 秒自退）

const OUT := "res://.godot/agent_tools/world_map_truck.png"
var _errs: Array[String] = []


func _ready() -> void:
	await _run()
	for e in _errs:
		printerr("[TruckMap] FAIL: " + e)
	if _errs.is_empty():
		print("[TruckMap] PASS")
	get_tree().quit(0 if _errs.is_empty() else 1)


func _run() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		print("[TruckMap] load_game=", sm.call("load_game"))
	var gm: Node = get_node_or_null("/root/GameManager")
	var start_lv: int = int(gm.get("current_level"))
	var packed: PackedScene = load("res://scenes/world_map.tscn") as PackedScene
	if packed == null:
		_errs.append("world_map.tscn 加载失败")
		return
	var wm: Node = packed.instantiate()
	get_tree().root.add_child.call_deferred(wm)
	for i in 40:
		await get_tree().process_frame
	var marker: Node = _find_recursive(wm, "TruckMarker")
	if marker == null:
		_errs.append("TruckMarker 未构建")
		return
	var tex: Texture2D = marker.get("texture_normal")
	print("[TruckMap] pos=", marker.get("position"), " size=", marker.get("size"),
		" tex=", tex.resource_path.get_file() if tex != null else "null")
	var pos0: Vector2 = marker.get("position")
	# 模拟进度推进：跳到第 10 关（跨时代，必然移动+换车），再回原位
	gm.call("set_current_level", 10)
	for i in 70:
		await get_tree().process_frame
	var pos1: Vector2 = marker.get("position")
	var tex2: Texture2D = marker.get("texture_normal")
	print("[TruckMap] moved: ", pos0, " -> ", pos1, " tex=", tex2.resource_path.get_file() if tex2 != null else "null")
	if pos0.distance_to(pos1) < 40.0:
		_errs.append("卡车未移动（距离 %.1f）" % pos0.distance_to(pos1))
	if tex2 != null and not "era1" in tex2.resource_path:
		_errs.append("时代贴图未切换: " + tex2.resource_path.get_file())
	# 截图（非 headless 才有真画面）
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			img.save_png(ProjectSettings.globalize_path(OUT))
			print("[TruckMap] screenshot -> ", OUT)


func _find_recursive(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for c in root.get_children():
		var r := _find_recursive(c, node_name)
		if r != null:
			return r
	return null
