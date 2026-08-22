extends Node
## UILazyLoader 实战验证驱动 v2：分步打印 + 看门狗。
##   godot --headless --path . res://tests/ui_lazy_load_driver.tscn

const PANEL_IDS := [
	"backpack", "quest", "store", "faction", "settings",
	"achievement", "help", "modification", "evolution", "growth", "collection",
]

func _ready() -> void:
	print("=== LAZY DRV START ===")
	# 看门狗：20 秒未完成强制正常退出（保证 stdout 刷新）
	var wd := Timer.new()
	wd.wait_time = 20.0
	wd.one_shot = true
	wd.timeout.connect(_watchdog)
	add_child(wd)
	wd.start()

	print("[S1] loading main.tscn ...")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	if main_scene == null:
		print("[FATAL] main.tscn load null")
		get_tree().quit(1)
		return
	print("[S1] loaded OK")

	print("[S2] instantiate main ...")
	var main: Node = main_scene.instantiate()
	print("[S2] instantiate OK")

	print("[S3] add_child(main)（deferred，_ready 内直接 add 会被 busy 拒绝）...")
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	if main.get_parent() == null:
		print("[FATAL] main 未入树")
		get_tree().quit(1)
		return
	get_tree().current_scene = main
	print("[S3] add_child OK, current_scene=%s" % get_tree().current_scene.name)

	for i in 8:
		await get_tree().process_frame
	print("[S4] 8 frames settled, current_scene=%s" % get_tree().current_scene.name)

	var loader: Node = get_node_or_null("/root/UILazyLoader")
	if loader == null:
		print("[FATAL] UILazyLoader 不存在")
		get_tree().quit(1)
		return

	var fails: Array[String] = []
	for pid in PANEL_IDS:
		print("[S5] get_panel(%s) ..." % pid)
		var panel: Control = loader.get_panel(pid)
		if panel == null:
			print("[LAZY-FAIL] %s -> null" % pid)
			fails.append(pid)
		else:
			print("[LAZY-OK]   %s -> %s (parent=%s)" % [pid, panel.name, panel.get_parent().name])
		await get_tree().process_frame

	print("\n===== LAZY SUMMARY =====")
	if fails.is_empty():
		print("ALL %d PANELS OK" % PANEL_IDS.size())
	else:
		print("FAIL %d / %d: %s" % [fails.size(), PANEL_IDS.size(), ", ".join(fails)])
	print("=== LAZY DRV END ===")
	get_tree().quit(1 if not fails.is_empty() else 0)

func _watchdog() -> void:
	print("[WATCHDOG] 20s 超时，强制退出（卡点见最后一条 [S*] 打印）")
	print("=== LAZY DRV END (watchdog) ===")
	get_tree().quit(2)
