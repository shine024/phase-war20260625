extends Node
## v27 世界地图黑门入口冒烟：world_map.tscn 实例化无错 + 黑门标记构建 + 未解锁态
## 跑法：godot --headless --rendering-driver opengl3 --path . res://tests/v27_world_map_blackgate_smoke.tscn

var _errs: Array[String] = []


func _ready() -> void:
	await _run()
	for e in _errs:
		printerr("[v27] FAIL: " + e)
	if _errs.is_empty():
		print("[v27] WORLDMAP-SMOKE PASS")
	get_tree().quit(0 if _errs.is_empty() else 1)


func _run() -> void:
	var packed: PackedScene = load("res://scenes/world_map.tscn") as PackedScene
	if packed == null:
		_errs.append("world_map.tscn 加载失败")
		return
	var wm: Node = packed.instantiate()
	get_tree().root.add_child.call_deferred(wm)
	for i in 30:
		await get_tree().process_frame
	if not is_instance_valid(wm):
		_errs.append("world_map 实例化后即被释放")
		return
	# 黑门热区存在（方案 11 构建分支）
	var gate: Node = _find_recursive(wm, "BlackGateEntry")
	if gate == null:
		_errs.append("BlackGateEntry 热区未构建")
		return
	print("[v27] 黑门热区: visible=%s modulate.a=%.2f tooltip=%s" % [
		str(gate.visible), float(gate.modulate.a), str(gate.tooltip_text)])
	var lbl: Node = _find_recursive(wm, "GateMarker")
	if lbl == null:
		_errs.append("终局巨环 GateMarker 缺失（既有回归）")
	# 解锁判定函数可调用（未解锁/已解锁两态都不崩）
	var unlocked: bool = bool(wm.call("_is_blackgate_unlocked"))
	print("[v27] 黑门解锁态（测试环境存档相关）: ", str(unlocked))
	wm.queue_free()
	await get_tree().process_frame


func _find_recursive(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for c in node.get_children():
		var r: Node = _find_recursive(c, name)
		if r != null:
			return r
	return null
