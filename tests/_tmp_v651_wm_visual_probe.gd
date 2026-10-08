extends Node
## v6.51 临时视觉探针：真实渲染大地图，目检三件——
## ① 渗透红点（跨窗宿主可见+脉动+层级）；② 燃料 chip 的"第N天"前缀；③ 图例红点行。
## 跑法：godot --path . res://tests/_tmp_v643_wm_visual.tscn（窗口化，非 headless）
## 截图落 res://.godot/v651_shots/。宿主 17（窗外 13 关）应显示=半径放宽生效；
## 宿主 45（>16）应不显示=过滤仍生效。

func _ready() -> void:
	var dir := DirAccess.open("res://.godot")
	if dir != null and not dir.dir_exists("v651_shots"):
		dir.make_dir("v651_shots")
	var mll := get_node_or_null("/root/ManagerLazyLoader")
	if mll != null and mll.has_method("ensure_loaded"):
		mll.ensure_loaded("bunker")
		mll.ensure_loaded("endless")
	var bm := get_node_or_null("/root/BunkerManager")
	if bm != null:
		bm.set("_parked_level", 30)
	var ebm := get_node_or_null("/root/EndlessBlackgateManager")
	if ebm != null:
		ebm.set("gate_cleared_once", false)
		ebm.set("incursions", [
			{"host_level": 17, "seed": 11, "spawned_day": 1},
			{"host_level": 32, "seed": 12, "spawned_day": 1},
			{"host_level": 45, "seed": 13, "spawned_day": 1},
		])
	var wm: Node = load("res://scenes/world_map.tscn").instantiate()
	add_child(wm)
	for i in range(10):
		await get_tree().process_frame
	# ⚠️ 桩必须在懒加载管理器的存档初始化落稳之后再直写（v6.41.2 同款探针铁律：
	# ensure_loaded 后管理器 _ready/存档 flush 会把早设的字段复位成存档值）——
	# 先强制 flush 所有延迟加载，杜绝 load_state 晚到覆盖桩
	var sm := get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("flush_deferred_manager_loads"):
		sm.call("flush_deferred_manager_loads")
	for i in range(2):
		await get_tree().process_frame
	# 懒加载节点是延迟挂树——flush 后重新获取（_ready 期取到的引用是 null）
	bm = get_node_or_null("/root/BunkerManager")
	ebm = get_node_or_null("/root/EndlessBlackgateManager")
	print("[V643_VISUAL] bm=", bm, " ebm=", ebm)
	if bm != null:
		bm.set("_parked_level", 30)
	if ebm != null:
		ebm.set("gate_cleared_once", false)
		ebm.set("incursions", [
			{"host_level": 17, "seed": 11, "spawned_day": 1},
			{"host_level": 32, "seed": 12, "spawned_day": 1},
			{"host_level": 45, "seed": 13, "spawned_day": 1},
		])
	# 走正规 current_level 变化链重建（窗口/chip/出击键/红点一并刷新）
	wm.call("_on_truck_level_changed", 30)
	for i in range(6):
		await get_tree().process_frame
	print("[V643_VISUAL] anchor=", wm.call("_truck_anchor_level"),
		" parked=", bm.get_parked_level() if bm != null else -1,
		" incursions=", (ebm.get("incursions") as Array).size() if ebm != null else -1)
	# 整图视图
	await _shot("world_map_full")
	# 2× 放大看红点/芯片细节
	if wm.has_method("_center_view_on_level"):
		wm.call("_center_view_on_level", 30, 2.0)
	for i in range(4):
		await get_tree().process_frame
	await _shot("world_map_zoom2x")
	# 模拟行军到站（同窗 current_level 变化 → 标示应迁移到 32）
	if bm != null:
		bm.set("_parked_level", 32)
	if GameManager != null:
		GameManager.current_level = 32
	wm.call("_on_truck_level_changed", 32)
	for i in range(6):
		await get_tree().process_frame
	await _shot("world_map_arrived32")
	# 渗透红点特写：居中 32 关、最大倍率；打印每个标记的画布坐标与透明度
	var scroll: ScrollContainer = wm.get_node_or_null("Margin/VBox/ScrollContainer")
	var canvas: Control = scroll.get_node_or_null("MapCanvas") if scroll != null else null
	if canvas != null:
		var holder: Control = canvas.get_node_or_null("IncursionMarkers")
		if holder != null:
			for c in holder.get_children():
				print("[V643_VISUAL] marker ", c.name, " pos=", c.position,
					" z=", c.get_index(), " modulate=", c.modulate)
		print("[V643_VISUAL] holder_idx=", holder.get_index() if holder != null else -1,
			" truck_idx=", canvas.get_node_or_null("TruckMarker").get_index()
			if canvas.get_node_or_null("TruckMarker") != null else -1)
	if wm.has_method("_center_view_on_level"):
		wm.call("_center_view_on_level", 32, 2.8)
	for i in range(4):
		await get_tree().process_frame
	await _shot("world_map_incursion_closeup")
	print("[V643_VISUAL] done")
	get_tree().quit(0)

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://.godot/v651_shots/%s.png" % shot_name
	var err := img.save_png(path)
	print("[V643_VISUAL] %s -> %s (err=%d)" % [shot_name, path, err])
