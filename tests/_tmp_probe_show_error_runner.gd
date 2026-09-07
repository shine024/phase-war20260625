extends Node
## 探针 runner：①SignalBus 是否有 show_error 信号 ②低燃料拒绝路径复现 world_map.gd:1820 的裸 emit
## ③world_map.gd 能否编译加载（证明编译不报、只在运行时炸）

func _ready() -> void:
	await get_tree().process_frame

	var names: Array = []
	for s in SignalBus.get_signal_list():
		names.append(String(s["name"]))
	print("[Probe] SignalBus has show_error signal: ", "show_error" in names)
	print("[Probe] SignalBus has show_toast signal: ", "show_toast" in names)

	# world_map.gd 编译加载验证
	var wm_script: GDScript = load("res://scenes/world_map.gd")
	print("[Probe] world_map.gd loaded: ", wm_script != null, " can_instantiate=", wm_script.can_instantiate() if wm_script != null else false)

	# 低燃料拒绝路径（复现玩家：燃料 12、安全储备 10 → 出车必拒）
	if ManagerLazyLoader != null and ManagerLazyLoader.has_method("ensure_loaded"):
		ManagerLazyLoader.ensure_loaded("bunker")
	var bm: Node = get_node_or_null("/root/BunkerManager")
	if bm == null:
		print("[Probe] FAIL: BunkerManager 未创建")
		_finish(1)
		return
	bm.set("_fuel", 12.0)
	bm.set("_parked_level", 1)
	var res: Dictionary = bm.call("start_travel", 60)
	print("[Probe] start_travel ok=", bool(res.get("ok", false)), " reason=", str(res.get("reason", "")))
	if not bool(res.get("ok", false)):
		print("[Probe] >>> 执行 world_map.gd:1820 同款裸 emit（下一条应为 SCRIPT ERROR 且无 UNREACHABLE）")
		SignalBus.show_error.emit(str(res.get("reason", "")))
		print("[Probe] UNREACHABLE —— emit 没炸才会打印到这行")
	_finish(0)

func _finish(code: int) -> void:
	await get_tree().process_frame
	get_tree().quit(code)
