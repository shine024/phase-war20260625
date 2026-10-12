extends Node
## v6.65 记录6#5 目检探针（场景式，真窗口渲染）：行军中大地图渗透红点。
## 复刻用户场景：停靠 40、行军去 100、目的地侧渗透 97/100（出发侧 42 应仍被滤）。
## 修复前过滤锚=parked 40 → 零红点；修复后锚=dest 100 → 红点可见。
## 截图落 res://.godot/v665_probe/travel_incursions.png

func _ready() -> void:
	_run()

func _run() -> void:
	print("[probe] step1: stub bunker/endless")
	print("[probe] mll=", get_node_or_null("/root/ManagerLazyLoader"), " bm0=", get_node_or_null("/root/BunkerManager"), " ebm0=", get_node_or_null("/root/EndlessBlackgateManager"))
	var bm: Node = get_node_or_null("/root/BunkerManager")
	var ebm: Node = get_node_or_null("/root/EndlessBlackgateManager")
	if bm == null or ebm == null:
		var mll: Node = get_node_or_null("/root/ManagerLazyLoader")
		if mll != null and mll.has_method("ensure_loaded"):
			mll.ensure_loaded("bunker")
			mll.ensure_loaded("endless")
		# 启动期 _instantiate_manager 走 call_deferred 挂树——等帧再取（探针铁律：
		# 懒加载管理器 ensure 后不等于立即可 get_node）
		for i in range(3):
			await get_tree().process_frame
		bm = get_node_or_null("/root/BunkerManager")
		ebm = get_node_or_null("/root/EndlessBlackgateManager")
	if bm == null or ebm == null:
		print("[probe] FAIL: managers missing mll=", get_node_or_null("/root/ManagerLazyLoader") != null, " bm=", bm, " ebm=", ebm)
		get_tree().quit(1)
		return
	bm.set("_parked_level", 40)
	bm.set("_travel_dest", 100)
	bm.set("_travel_ends_unix", Time.get_unix_time_from_system() + 3600.0)
	ebm.set("gate_cleared_once", false)
	ebm.set("incursions", [
		{"host_level": 97, "seed": 1001, "spawned_day": 1},
		{"host_level": 100, "seed": 1002, "spawned_day": 1},
		{"host_level": 42, "seed": 1003, "spawned_day": 1},
	])
	print("[probe] step2: instantiate world_map")
	var scene: PackedScene = load("res://scenes/world_map.tscn")
	var wm: Node = scene.instantiate()
	get_tree().root.add_child(wm)
	for i in range(12):
		await get_tree().process_frame
	print("[probe] step3: dump markers")
	var scroll: ScrollContainer = wm.get_node_or_null("Margin/VBox/ScrollContainer")
	var canvas: Control = scroll.get_node_or_null("MapCanvas") if scroll != null else null
	var holder: Control = canvas.get_node_or_null("IncursionMarkers") if canvas != null else null
	print("[probe] canvas=", canvas != null, " holder=", holder != null)
	if holder != null:
		for c in holder.get_children():
			print("[probe] marker: ", c.name, " pos=", (c as Control).position)
	print("[probe] step4: screenshot")
	var img: Image = get_viewport().get_texture().get_image()
	var dir := DirAccess.open("res://.godot")
	if dir != null and not dir.dir_exists("v665_probe"):
		dir.make_dir("v665_probe")
	var err := img.save_png("res://.godot/v665_probe/travel_incursions.png")
	print("[probe] save err=", err)
	ebm.set("incursions", [])
	bm.set("_travel_dest", 0)
	bm.set("_travel_ends_unix", 0.0)
	print("[probe] done")
	get_tree().quit(0)
